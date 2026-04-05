/*
 * Copyright 2026  Petar Nedyalkov
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * visualCrossing.js — Visual Crossing current + hourly fetcher
 *
 * Non-pragma JS — accesses config via service properties.
 * Visual Crossing Timeline API provides current conditions, daily and hourly forecasts.
 * Uses Dark Sky-compatible icon names.
 * Docs: https://www.visualcrossing.com/resources/documentation/weather-api/
 */

/**
 * Maps a Visual Crossing icon string to a WMO weather code.
 * VC uses an extended Dark Sky-compatible icon set (icons2).
 */
function _iconToWmo(icon) {
    if (!icon) return 2;
    switch (icon) {
        case "clear-day":
        case "clear-night":
            return 0;
        case "partly-cloudy-day":
        case "partly-cloudy-night":
            return 2;
        case "cloudy":
            return 3;
        case "rain":
            return 63;
        case "showers-day":
        case "showers-night":
            return 80;
        case "snow":
            return 73;
        case "snow-showers-day":
        case "snow-showers-night":
            return 85;
        case "sleet":
            return 66;
        case "wind":
            return 2;
        case "fog":
            return 45;
        case "thunder-rain":
        case "thunder-showers-day":
        case "thunder-showers-night":
            return 95;
        case "hail":
            return 99;
        default:
            return 2;
    }
}

/**
 * Determine isDay from the icon string.
 * Returns 1 for day, 0 for night, -1 for unknown.
 */
function _iconIsDay(icon) {
    if (!icon) return -1;
    if (icon.indexOf("-night") >= 0) return 0;
    if (icon.indexOf("-day") >= 0) return 1;
    return -1;
}

function fetchCurrent(service, W, chain, idx) {
    var gen = service._refreshGen;
    var r = service.weatherRoot;
    var key = service._vcKey();
    if (!key) {
        service._tryProvider(chain, idx + 1);
        return;
    }

    var url = "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/"
        + service.latitude + "," + service.longitude
        + "?key=" + encodeURIComponent(key)
        + "&unitGroup=metric"
        + "&include=current,days,alerts"
        + "&iconSet=icons2";

    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        if (service._refreshGen !== gen) return;
        if (req.status !== 200) {
            service._tryProvider(chain, idx + 1);
            return;
        }
        try {
            var d = JSON.parse(req.responseText);
        } catch (e) {
            service._tryProvider(chain, idx + 1);
            return;
        }
        if (!d.currentConditions) {
            service._tryProvider(chain, idx + 1);
            return;
        }

        var c = d.currentConditions;

        r.temperatureC = c.temp;
        r.apparentC = c.feelslike;
        r.humidityPercent = (c.humidity !== undefined) ? c.humidity : NaN;
        r.windKmh = (c.windspeed !== undefined) ? c.windspeed : NaN;
        r.windDirection = (c.winddir !== undefined) ? c.winddir : NaN;
        r.pressureHpa = (c.pressure !== undefined) ? c.pressure : NaN;
        r.dewPointC = (c.dew !== undefined) ? c.dew : NaN;
        r.visibilityKm = (c.visibility !== undefined) ? c.visibility : NaN;
        r.precipMmh = (c.precip !== undefined) ? c.precip : NaN;
        r.uvIndex = (c.uvindex !== undefined) ? c.uvindex : NaN;
        r.snowDepthCm = (c.snowdepth !== undefined) ? c.snowdepth : NaN;
        r.weatherCode = _iconToWmo(c.icon);
        r.isDay = _iconIsDay(c.icon);
        r.locationUtcOffsetMins = (d.tzoffset !== undefined) ? Math.round(d.tzoffset * 60) : 0;

        // Sunrise / sunset from currentConditions (time strings "HH:mm:ss")
        if (c.sunrise) {
            r.sunriseTimeText = c.sunrise.substring(0, 5);
        } else {
            r.sunriseTimeText = "--";
        }
        if (c.sunset) {
            r.sunsetTimeText = c.sunset.substring(0, 5);
        } else {
            r.sunsetTimeText = "--";
        }

        // Daily forecast
        var nd = [];
        if (d.days) {
            var maxD = Math.min(service.forecastDays, d.days.length);
            for (var i = 0; i < maxD; i++) {
                var dd = d.days[i];
                nd.push({
                    day: Qt.formatDate(new Date(dd.datetime + "T12:00:00"), "ddd"),
                    dateStr: dd.datetime,
                    maxC: (dd.tempmax !== undefined) ? dd.tempmax : NaN,
                    minC: (dd.tempmin !== undefined) ? dd.tempmin : NaN,
                    code: _iconToWmo(dd.icon),
                    precipMm: (dd.precip !== undefined) ? dd.precip : NaN,
                    snowCm: (dd.snow !== undefined) ? dd.snow : NaN
                });
            }
        }
        r.dailyData = nd;

        // Air quality not available natively
        r.airQualityIndex = NaN;
        r.airQualityLabel = "";
        r.aqiPm10 = NaN;
        r.aqiPm2_5 = NaN;
        r.aqiCo = NaN;
        r.aqiNo2 = NaN;
        r.aqiSo2 = NaN;
        r.aqiO3 = NaN;
        r.pollenData = [];

        r.loading = false;
        r.updateText = service._formatUpdateText("visualCrossing");

        // Parse alerts if available
        if (d.alerts && d.alerts.length > 0) {
            _parseAlerts(r, d.alerts);
        }

        // Fall back to MeteoAlarm / NWS if no native alerts
        service._fetchAlertsIfNeeded();

        // Fetch air quality from Open-Meteo as fallback
        _fetchAirQualityFallback(service);
    };
    req.send();
}

function _parseAlerts(r, alerts) {
    var parsed = [];
    var now = new Date();
    for (var i = 0; i < alerts.length; i++) {
        var a = alerts[i];
        // Skip expired
        if (a.ends) {
            var exp = new Date(a.ends);
            if (exp < now) continue;
        }

        parsed.push({
            headline: a.headline || a.event || "",
            displayName: a.event || a.headline || "",
            severity: "",
            description: a.description || "",
            event: a.event || "",
            area: "",
            color: "orange",
            awarenessType: 0,
            onset: a.onset || "",
            effective: a.onset || "",
            expires: a.ends || "",
            instruction: "",
            web: a.link || "",
            source: "VisualCrossing",
            action: "",
            senderName: ""
        });
    }

    if (parsed.length > 0) {
        r.weatherAlerts = parsed;
    }
}

function _fetchAirQualityFallback(service) {
    var gen = service._refreshGen;
    var r = service.weatherRoot;
    var tz = service.timezone;
    var url = "https://air-quality-api.open-meteo.com/v1/air-quality"
        + "?latitude=" + service.latitude
        + "&longitude=" + service.longitude
        + "&current=european_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"
        + ",alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
        + "&timezone=" + encodeURIComponent(tz.length > 0 ? tz : "auto");
    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        if (service._refreshGen !== gen) return;
        if (req.status !== 200) return;
        try {
            var d = JSON.parse(req.responseText);
            var c = d.current || {};
            if (c.european_aqi !== undefined) {
                r.airQualityIndex = c.european_aqi;
                if (c.european_aqi <= 20) r.airQualityLabel = "Good";
                else if (c.european_aqi <= 40) r.airQualityLabel = "Fair";
                else if (c.european_aqi <= 60) r.airQualityLabel = "Moderate";
                else if (c.european_aqi <= 80) r.airQualityLabel = "Poor";
                else if (c.european_aqi <= 100) r.airQualityLabel = "Very Poor";
                else r.airQualityLabel = "Hazardous";
            }
            r.aqiPm10  = (c.pm10 !== undefined) ? c.pm10 : NaN;
            r.aqiPm2_5 = (c.pm2_5 !== undefined) ? c.pm2_5 : NaN;
            r.aqiNo2   = (c.nitrogen_dioxide !== undefined) ? c.nitrogen_dioxide : NaN;
            r.aqiSo2   = (c.sulphur_dioxide !== undefined) ? c.sulphur_dioxide : NaN;
            r.aqiO3    = (c.ozone !== undefined) ? c.ozone : NaN;
            r.aqiCo    = (c.carbon_monoxide !== undefined) ? c.carbon_monoxide / 1000.0 : NaN;

            var pollenKeys = [
                { key: "alder", field: "alder_pollen" },
                { key: "birch", field: "birch_pollen" },
                { key: "grass", field: "grass_pollen" },
                { key: "mugwort", field: "mugwort_pollen" },
                { key: "olive", field: "olive_pollen" },
                { key: "ragweed", field: "ragweed_pollen" }
            ];
            var pd = [];
            pollenKeys.forEach(function (p) {
                var v = c[p.field];
                pd.push({ key: p.key, value: (v !== undefined && v !== null) ? v : NaN });
            });
            r.pollenData = pd;
        } catch (e) { /* ignore */ }
    };
    req.send();
}

function fetchHourly(service, W, dateStr) {
    var gen = service._refreshGen;
    var r = service.weatherRoot;
    var key = service._vcKey();
    if (!key) {
        r.hourlyData = [];
        return;
    }

    // Request hours for the specific date only
    var url = "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/"
        + service.latitude + "," + service.longitude
        + "/" + dateStr + "/" + dateStr
        + "?key=" + encodeURIComponent(key)
        + "&unitGroup=metric"
        + "&include=hours"
        + "&iconSet=icons2";

    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        if (service._refreshGen !== gen) return;
        if (req.status !== 200) {
            r.hourlyData = [];
            return;
        }
        try {
            var d = JSON.parse(req.responseText);
        } catch (e) {
            r.hourlyData = [];
            return;
        }

        var arr = [];
        if (d.days && d.days.length > 0 && d.days[0].hours) {
            d.days[0].hours.forEach(function (h) {
                arr.push({
                    hour: h.datetime ? h.datetime.substring(0, 5) : "--",
                    tempC: h.temp,
                    code: _iconToWmo(h.icon),
                    windKmh: (h.windspeed !== undefined) ? h.windspeed : NaN,
                    windDeg: (h.winddir !== undefined) ? h.winddir : NaN,
                    humidity: (h.humidity !== undefined) ? Math.round(h.humidity) : NaN,
                    precipProb: (h.precipprob !== undefined) ? Math.round(h.precipprob) : NaN,
                    precipMm: (h.precip !== undefined) ? h.precip : NaN
                });
            });
        }
        r.hourlyData = arr;
    };
    req.send();
}
