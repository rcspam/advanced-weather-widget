/**
 * openMeteo.js — Open-Meteo current + hourly fetcher
 *
 * Non-pragma JS — accesses config via service properties.
 * Qt global is available; Plasmoid/i18n/Locale are NOT (use service instead).
 */

function fetchCurrent(service, chain, idx) {
    var r = service.weatherRoot;
    var tz = service.timezone;
    var url = "https://api.open-meteo.com/v1/forecast"
        + "?latitude=" + service.latitude
        + "&longitude=" + service.longitude
        + "&timezone=" + encodeURIComponent(tz.length > 0 ? tz : "auto")
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,"
        + "weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,"
        + "dew_point_2m,visibility,is_day"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset";

    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        if (req.status !== 200) {
            service._tryProvider(chain, idx + 1);
            return;
        }
        var d = JSON.parse(req.responseText);
        if (!d.current) {
            service._tryProvider(chain, idx + 1);
            return;
        }
        var c = d.current;
        r.temperatureC = c.temperature_2m;
        r.apparentC = c.apparent_temperature;
        r.humidityPercent = c.relative_humidity_2m;
        r.windKmh = c.wind_speed_10m;
        r.windDirection = isNaN(c.wind_direction_10m) ? NaN : c.wind_direction_10m;
        r.pressureHpa = c.surface_pressure;
        r.dewPointC = c.dew_point_2m;
        r.visibilityKm = c.visibility / 1000.0;
        r.weatherCode = c.weather_code;
        r.isDay = (c.is_day !== undefined) ? c.is_day : -1;
        r.locationUtcOffsetMins = (d.utc_offset_seconds !== undefined)
            ? Math.round(d.utc_offset_seconds / 60) : 0;
        r.sunriseTimeText = (d.daily && d.daily.sunrise && d.daily.sunrise.length > 0)
            ? Qt.formatTime(new Date(d.daily.sunrise[0]), "HH:mm") : "--";
        r.sunsetTimeText = (d.daily && d.daily.sunset && d.daily.sunset.length > 0)
            ? Qt.formatTime(new Date(d.daily.sunset[0]), "HH:mm") : "--";
        var nd = [];
        if (d.daily && d.daily.time) {
            var maxD = Math.min(service.forecastDays, d.daily.time.length);
            for (var i = 0; i < maxD; ++i)
                nd.push({
                    day: Qt.formatDate(new Date(d.daily.time[i]), "ddd"),
                    dateStr: d.daily.time[i],
                    maxC: d.daily.temperature_2m_max[i],
                    minC: d.daily.temperature_2m_min[i],
                    code: d.daily.weather_code[i]
                });
        }
        r.dailyData = nd;
        r.loading = false;
        r.updateText = service._formatUpdateText("openMeteo");
    };
    req.send();
}

function fetchHourly(service, dateStr) {
    var r = service.weatherRoot;
    var tz = service.timezone;
    var url = "https://api.open-meteo.com/v1/forecast?latitude="
        + service.latitude
        + "&longitude=" + service.longitude
        + "&timezone=" + encodeURIComponent(tz.length > 0 ? tz : "auto")
        + "&hourly=temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,relative_humidity_2m,precipitation_probability"
        + "&start_date=" + dateStr + "&end_date=" + dateStr;
    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        if (req.status !== 200) {
            r.hourlyData = [];
            return;
        }
        var d = JSON.parse(req.responseText);
        var arr = [];
        if (d.hourly && d.hourly.time)
            for (var i = 0; i < d.hourly.time.length; ++i)
                arr.push({
                    hour: Qt.formatTime(new Date(d.hourly.time[i]), "HH:mm"),
                    tempC: d.hourly.temperature_2m[i],
                    code: d.hourly.weather_code[i],
                    windKmh: d.hourly.wind_speed_10m[i],
                    windDeg: d.hourly.wind_direction_10m ? d.hourly.wind_direction_10m[i] : NaN,
                    humidity: d.hourly.relative_humidity_2m[i],
                    precipProb: d.hourly.precipitation_probability ? d.hourly.precipitation_probability[i] : NaN
                });
        r.hourlyData = arr;
    };
    req.send();
}
