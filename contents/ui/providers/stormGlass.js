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
 * stormGlass.js — StormGlass current + hourly fetcher
 *
 * Non-pragma JS — accesses config via service properties.
 * StormGlass provides hourly marine and weather data. No native weather code
 * is returned, so we derive a WMO code from cloud cover, precipitation, and
 * temperature.
 * Docs: https://docs.stormglass.io/
 */

/**
 * Derives a WMO weather code from cloud cover, precipitation, and temp.
 * StormGlass does not provide a native weather condition code.
 */
function _deriveWmoCode(cloudCover, precipitation, temp) {
    var cc = (cloudCover !== undefined && cloudCover !== null && !isNaN(cloudCover)) ? cloudCover : 0;
    var pr = (precipitation !== undefined && precipitation !== null && !isNaN(precipitation)) ? precipitation : 0;
    var t  = (temp !== undefined && temp !== null && !isNaN(temp)) ? temp : 10;

    if (pr > 0.1) {
        if (t <= 0) {
            if (pr > 2) return 75;   // heavy snow
            if (pr > 0.5) return 73; // moderate snow
            return 71;               // light snow
        }
        if (pr > 7.5) return 65;     // heavy rain
        if (pr > 2.5) return 63;     // moderate rain
        return 61;                   // light rain
    }
    if (cc > 80) return 3;           // overcast
    if (cc > 50) return 2;           // partly cloudy
    if (cc > 20) return 1;           // mainly clear
    return 0;                        // clear
}

/**
 * Extracts the StormGlass "sg" source value from a multi-source object.
 * Falls back to the first available source if "sg" is missing.
 */
function _val(obj) {
    if (obj === undefined || obj === null) return NaN;
    if (typeof obj === "number") return obj;
    if (obj.sg !== undefined) return obj.sg;
    // Fallback: use first available source
    var keys = Object.keys(obj);
    if (keys.length > 0) return obj[keys[0]];
    return NaN;
}

function fetchCurrent(service, W, chain, idx) {
    var gen = service._refreshGen;
    var r = service.weatherRoot;
    var key = service._sgKey();
    if (!key) {
        service._tryProvider(chain, idx + 1);
        return;
    }

    var params = "airTemperature,humidity,pressure,windSpeed,windDirection,"
        + "visibility,precipitation,snowDepth,cloudCover,dewPointTemperature";

    var url = "https://api.stormglass.io/v2/weather/point"
        + "?lat=" + service.latitude
        + "&lng=" + service.longitude
        + "&params=" + params;

    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.setRequestHeader("Authorization", key);
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
        if (!d.hours || d.hours.length === 0) {
            service._tryProvider(chain, idx + 1);
            return;
        }

        // Find the hour closest to now
        var now = Date.now();
        var bestIdx = 0;
        var bestDiff = Math.abs(new Date(d.hours[0].time).getTime() - now);
        for (var i = 1; i < d.hours.length; i++) {
            var diff = Math.abs(new Date(d.hours[i].time).getTime() - now);
            if (diff < bestDiff) {
                bestDiff = diff;
                bestIdx = i;
            }
        }

        var c = d.hours[bestIdx];
        var temp = _val(c.airTemperature);
        var cc = _val(c.cloudCover);
        var precip = _val(c.precipitation);

        r.temperatureC = temp;
        r.apparentC = NaN; // StormGlass does not provide apparent temperature
        r.humidityPercent = _val(c.humidity);
        // StormGlass wind is in m/s — convert to km/h
        var ws = _val(c.windSpeed);
        r.windKmh = !isNaN(ws) ? ws * 3.6 : NaN;
        r.windDirection = _val(c.windDirection);
        r.pressureHpa = _val(c.pressure);
        r.dewPointC = _val(c.dewPointTemperature);
        // StormGlass visibility is in km
        r.visibilityKm = _val(c.visibility);
        r.precipMmh = precip;
        r.uvIndex = NaN; // not available in StormGlass basic weather
        // StormGlass snowDepth is in meters — convert to cm
        var sd = _val(c.snowDepth);
        r.snowDepthCm = !isNaN(sd) ? sd * 100 : NaN;
        r.weatherCode = _deriveWmoCode(cc, precip, temp);
        r.isDay = -1; // will be set by sun times fallback
        r.locationUtcOffsetMins = 0;

        // Sunrise/sunset — not provided, use Open-Meteo fallback
        r.sunriseTimeText = "--";
        r.sunsetTimeText = "--";

        // Build daily forecast by aggregating hourly data
        var dayMap = {};
        for (var j = 0; j < d.hours.length; j++) {
            var h = d.hours[j];
            var dt = new Date(h.time);
            var ds = Qt.formatDate(dt, "yyyy-MM-dd");
            if (!dayMap[ds]) {
                dayMap[ds] = {
                    day: Qt.formatDate(dt, "ddd"),
                    dateStr: ds,
                    maxC: -Infinity,
                    minC: Infinity,
                    maxPrecip: 0,
                    avgCC: 0,
                    avgTemp: 0,
                    count: 0
                };
            }
            var entry = dayMap[ds];
            var ht = _val(h.airTemperature);
            if (!isNaN(ht)) {
                if (ht > entry.maxC) entry.maxC = ht;
                if (ht < entry.minC) entry.minC = ht;
                entry.avgTemp += ht;
            }
            var hp = _val(h.precipitation);
            if (!isNaN(hp) && hp > entry.maxPrecip) entry.maxPrecip = hp;
            var hcc = _val(h.cloudCover);
            if (!isNaN(hcc)) entry.avgCC += hcc;
            entry.count++;
        }

        var nd = [];
        var dateKeys = Object.keys(dayMap).sort();
        var maxD = Math.min(service.forecastDays, dateKeys.length);
        for (var k = 0; k < maxD; k++) {
            var de = dayMap[dateKeys[k]];
            var avgCC = de.count > 0 ? de.avgCC / de.count : 0;
            var avgTemp = de.count > 0 ? de.avgTemp / de.count : 10;
            nd.push({
                day: de.day,
                dateStr: de.dateStr,
                maxC: de.maxC === -Infinity ? NaN : de.maxC,
                minC: de.minC === Infinity ? NaN : de.minC,
                code: _deriveWmoCode(avgCC, de.maxPrecip, avgTemp),
                precipMm: de.maxPrecip > 0 ? de.maxPrecip : NaN,
                snowCm: NaN
            });
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
        r.updateText = service._formatUpdateText("stormGlass");

        // No native alerts — fall back to MeteoAlarm / NWS
        service._fetchAlertsIfNeeded();

        // Fetch sun times from Open-Meteo
        service._fetchSunTimesOpenMeteo();

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
    var key = service._sgKey();
    if (!key) {
        r.hourlyData = [];
        return;
    }

    var params = "airTemperature,humidity,windSpeed,windDirection,precipitation,cloudCover";

    var url = "https://api.stormglass.io/v2/weather/point"
        + "?lat=" + service.latitude
        + "&lng=" + service.longitude
        + "&params=" + params;

    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.setRequestHeader("Authorization", key);
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
        if (d.hours) {
            d.hours.forEach(function (h) {
                var dt = new Date(h.time);
                var hDateStr = Qt.formatDate(dt, "yyyy-MM-dd");
                if (hDateStr !== dateStr) return;

                var t = _val(h.airTemperature);
                var cc = _val(h.cloudCover);
                var pr = _val(h.precipitation);
                var ws = _val(h.windSpeed);

                arr.push({
                    hour: Qt.formatTime(dt, "HH:mm"),
                    tempC: t,
                    code: _deriveWmoCode(cc, pr, t),
                    windKmh: !isNaN(ws) ? ws * 3.6 : NaN,
                    windDeg: _val(h.windDirection),
                    humidity: (function() { var v = _val(h.humidity); return !isNaN(v) ? Math.round(v) : NaN; })(),
                    precipProb: NaN, // not available from StormGlass
                    precipMm: pr
                });
            });
        }
        r.hourlyData = arr;
    };
    req.send();
}
