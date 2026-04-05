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
 * tomorrowIo.js — Tomorrow.io current + hourly fetcher
 *
 * Non-pragma JS — accesses config via service properties.
 * Uses the Tomorrow.io Weather API v4 (Realtime + Forecast endpoints).
 * Docs: https://docs.tomorrow.io/reference/welcome
 */

/**
 * Maps a Tomorrow.io weather code to a WMO weather code.
 */
function _codeToWmo(code) {
    if (code === undefined || code === null) return 2;
    switch (code) {
        case 1000: return 0;   // Clear
        case 1100: return 1;   // Mostly Clear
        case 1101: return 2;   // Partly Cloudy
        case 1102: return 3;   // Mostly Cloudy
        case 1001: return 3;   // Cloudy
        case 2000: return 45;  // Fog
        case 2100: return 45;  // Light Fog
        case 4000: return 51;  // Drizzle
        case 4200: return 61;  // Light Rain
        case 4001: return 63;  // Rain
        case 4201: return 65;  // Heavy Rain
        case 5001: return 77;  // Flurries
        case 5100: return 71;  // Light Snow
        case 5000: return 73;  // Snow
        case 5101: return 75;  // Heavy Snow
        case 6000: return 56;  // Freezing Drizzle
        case 6200: return 66;  // Light Freezing Rain
        case 6001: return 66;  // Freezing Rain
        case 6201: return 67;  // Heavy Freezing Rain
        case 7102: return 77;  // Light Ice Pellets
        case 7000: return 77;  // Ice Pellets
        case 7101: return 77;  // Heavy Ice Pellets
        case 8000: return 95;  // Thunderstorm
        default:   return 2;
    }
}

function fetchCurrent(service, W, chain, idx) {
    var gen = service._refreshGen;
    var r = service.weatherRoot;
    var key = service._tioKey();
    if (!key) {
        service._tryProvider(chain, idx + 1);
        return;
    }

    // Step 1: Fetch realtime conditions
    var url = "https://api.tomorrow.io/v4/weather/realtime"
        + "?location=" + service.latitude + "," + service.longitude
        + "&units=metric"
        + "&apikey=" + encodeURIComponent(key);

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
        if (!d.data || !d.data.values) {
            service._tryProvider(chain, idx + 1);
            return;
        }

        var c = d.data.values;

        r.temperatureC = c.temperature;
        r.apparentC = c.temperatureApparent;
        r.humidityPercent = (c.humidity !== undefined) ? c.humidity : NaN;
        // Tomorrow.io metric wind is in m/s — convert to km/h
        r.windKmh = (c.windSpeed !== undefined) ? c.windSpeed * 3.6 : NaN;
        r.windDirection = (c.windDirection !== undefined) ? c.windDirection : NaN;
        r.pressureHpa = (c.pressureSurfaceLevel !== undefined) ? c.pressureSurfaceLevel : NaN;
        r.dewPointC = (c.dewPoint !== undefined) ? c.dewPoint : NaN;
        r.visibilityKm = (c.visibility !== undefined) ? c.visibility : NaN;
        r.precipMmh = (c.precipitationIntensity !== undefined) ? c.precipitationIntensity : NaN;
        r.uvIndex = (c.uvIndex !== undefined) ? c.uvIndex : NaN;
        r.snowDepthCm = NaN;
        r.weatherCode = _codeToWmo(c.weatherCode);
        r.isDay = -1; // will be set from daily forecast sun times
        r.locationUtcOffsetMins = 0;

        // Sunrise/sunset default — will be overwritten by forecast
        r.sunriseTimeText = "--";
        r.sunsetTimeText = "--";

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

        // Step 2: Fetch daily forecast for daily data + sun times
        _fetchForecast(service, W, gen);
    };
    req.send();
}

/**
 * Fetches the daily forecast from Tomorrow.io.
 * Sets dailyData, sunriseTimeText, sunsetTimeText, and isDay.
 */
function _fetchForecast(service, W, gen) {
    var r = service.weatherRoot;
    var key = service._tioKey();

    var url = "https://api.tomorrow.io/v4/weather/forecast"
        + "?location=" + service.latitude + "," + service.longitude
        + "&timesteps=1d"
        + "&units=metric"
        + "&apikey=" + encodeURIComponent(key);

    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        if (service._refreshGen !== gen) return;

        var haveSunTimes = false;

        if (req.status === 200) {
            try {
                var d = JSON.parse(req.responseText);
                var dailyTimeline = d.timelines && d.timelines.daily;
                if (dailyTimeline && dailyTimeline.length > 0) {
                    // Sun times from first day
                    var day0v = dailyTimeline[0].values;
                    if (day0v.sunriseTime) {
                        r.sunriseTimeText = Qt.formatTime(new Date(day0v.sunriseTime), "HH:mm");
                        haveSunTimes = true;
                    }
                    if (day0v.sunsetTime) {
                        r.sunsetTimeText = Qt.formatTime(new Date(day0v.sunsetTime), "HH:mm");
                    }

                    // isDay based on current time vs sun times
                    if (day0v.sunriseTime && day0v.sunsetTime) {
                        var now = new Date();
                        var sr = new Date(day0v.sunriseTime);
                        var ss = new Date(day0v.sunsetTime);
                        r.isDay = (now >= sr && now <= ss) ? 1 : 0;
                    }

                    // Daily forecast
                    var nd = [];
                    var maxD = Math.min(service.forecastDays, dailyTimeline.length);
                    for (var i = 0; i < maxD; i++) {
                        var dd = dailyTimeline[i];
                        var dv = dd.values;
                        nd.push({
                            day: Qt.formatDate(new Date(dd.time), "ddd"),
                            dateStr: Qt.formatDate(new Date(dd.time), "yyyy-MM-dd"),
                            maxC: (dv.temperatureMax !== undefined) ? dv.temperatureMax : NaN,
                            minC: (dv.temperatureMin !== undefined) ? dv.temperatureMin : NaN,
                            code: _codeToWmo(dv.weatherCodeMax !== undefined ? dv.weatherCodeMax : dv.weatherCode),
                            precipMm: NaN,
                            snowCm: NaN
                        });
                    }
                    r.dailyData = nd;
                }
            } catch (e) { /* ignore parse errors */ }
        }

        // If no sun times from forecast, fetch from Open-Meteo
        if (!haveSunTimes) {
            service._fetchSunTimesOpenMeteo();
        }

        // Ensure dailyData is set
        if (!r.dailyData || r.dailyData.length === 0) {
            r.dailyData = [];
        }

        r.loading = false;
        r.updateText = service._formatUpdateText("tomorrowIo");

        // No native alerts — fall back to MeteoAlarm / NWS
        service._fetchAlertsIfNeeded();

        // Fetch air quality from Open-Meteo as fallback
        _fetchAirQualityFallback(service);
    };
    req.send();
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
    var key = service._tioKey();
    if (!key) {
        r.hourlyData = [];
        return;
    }

    var url = "https://api.tomorrow.io/v4/weather/forecast"
        + "?location=" + service.latitude + "," + service.longitude
        + "&timesteps=1h"
        + "&units=metric"
        + "&apikey=" + encodeURIComponent(key);

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
        var hourlyTimeline = d.timelines && d.timelines.hourly;
        if (hourlyTimeline) {
            hourlyTimeline.forEach(function (h) {
                var dt = new Date(h.time);
                var hDateStr = Qt.formatDate(dt, "yyyy-MM-dd");
                if (hDateStr !== dateStr) return;

                var v = h.values;
                arr.push({
                    hour: Qt.formatTime(dt, "HH:mm"),
                    tempC: v.temperature,
                    code: _codeToWmo(v.weatherCode),
                    windKmh: (v.windSpeed !== undefined) ? v.windSpeed * 3.6 : NaN,
                    windDeg: (v.windDirection !== undefined) ? v.windDirection : NaN,
                    humidity: (v.humidity !== undefined) ? Math.round(v.humidity) : NaN,
                    precipProb: (v.precipitationProbability !== undefined) ? Math.round(v.precipitationProbability) : NaN,
                    precipMm: (v.precipitationIntensity !== undefined) ? v.precipitationIntensity : NaN
                });
            });
        }
        r.hourlyData = arr;
    };
    req.send();
}
