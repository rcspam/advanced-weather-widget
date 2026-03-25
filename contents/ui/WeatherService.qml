/**
 * WeatherService.qml — Weather API service layer
 *
 * Usage in main.qml:
 *   WeatherService { id: weatherService; weatherRoot: root }
 *
 * Providers are split into separate files under providers/.
 */
import QtQuick
import org.kde.plasma.plasmoid

import "js/weather.js" as W
import "providers/openMeteo.js" as OpenMeteoJS
import "providers/openWeather.js" as OpenWeatherJS
import "providers/weatherApi.js" as WeatherApiJS
import "providers/metNo.js" as MetNoJS

QtObject {
    id: service

    // ── Public interface ──────────────────────────────────────────────────
    /** Reference to the PlasmoidItem root — set from main.qml */
    property var weatherRoot

    // ── Config mirrors (accessible from non-pragma JS providers) ──────────
    readonly property real latitude: Plasmoid.configuration.latitude
    readonly property real longitude: Plasmoid.configuration.longitude
    readonly property string timezone: (Plasmoid.configuration.timezone || "").trim()
    readonly property int forecastDays: Plasmoid.configuration.forecastDays
    readonly property real altitude: Plasmoid.configuration.altitude

    // ── Private: API key helpers ─────────────────────────────────────────
    function _owKey() {
        return (Plasmoid.configuration.owApiKey || "").trim();
    }
    function _waKey() {
        return (Plasmoid.configuration.waApiKey || "").trim();
    }

    // ── Public methods ────────────────────────────────────────────────────

    /** Full weather refresh — current + daily forecast */
    function refreshNow() {
        var r = weatherRoot;
        if (!r.hasSelectedTown) {
            r.loading = false;
            r.updateText = "";
            r.temperatureC = NaN;
            r.apparentC = NaN;
            r.windKmh = NaN;
            r.windDirection = NaN;
            r.pressureHpa = NaN;
            r.humidityPercent = NaN;
            r.visibilityKm = NaN;
            r.dewPointC = NaN;
            r.sunriseTimeText = "--";
            r.sunsetTimeText = "--";
            r.weatherCode = -1;
            r.isDay = -1;
            r.dailyData = [];
            r.hourlyData = [];
            return;
        }
        r.loading = true;

        var provider = Plasmoid.configuration.weatherProvider || "adaptive";
        var chain = (provider === "adaptive")
            ? ["openMeteo", "openWeather", "weatherApi", "metno"]
            : [provider];

        _tryProvider(chain, 0);
    }

    /** Hourly data fetch for a specific date string (yyyy-MM-dd) */
    function fetchHourlyForDate(dateStr) {
        var provider = Plasmoid.configuration.weatherProvider || "adaptive";
        var ap = (provider === "adaptive") ? "openMeteo" : provider;

        if (ap === "openMeteo") {
            OpenMeteoJS.fetchHourly(service, dateStr);
            return;
        }
        if (ap === "openWeather") {
            OpenWeatherJS.fetchHourly(service, W, dateStr);
            return;
        }
        if (ap === "weatherApi") {
            WeatherApiJS.fetchHourly(service, W, dateStr);
            return;
        }
        if (ap === "metno") {
            MetNoJS.fetchHourly(service, W, dateStr);
            return;
        }
        weatherRoot.hourlyData = [];
    }

    // ── Private: provider chain ───────────────────────────────────────────

    property var _failed: []

    function _formatUpdateText(p) {
        var t = Qt.formatTime(new Date(), Qt.locale().timeFormat(Locale.ShortFormat));
        var name, url;
        if (p === "openWeather") {
            name = "OpenWeather";
            url = "https://openweathermap.org";
        } else if (p === "weatherApi") {
            name = "WeatherAPI.com";
            url = "https://www.weatherapi.com";
        } else if (p === "metno") {
            name = "MET Norway";
            url = "https://www.met.no";
        } else {
            name = "Open-Meteo";
            url = "https://open-meteo.com";
        }
        return i18n("Updated %1", t)
            + " \u00B7 " + i18n("Weather provider:")
            + " <a href='" + url + "'>" + name + "</a>";
    }

    function _providerLabel(p) {
        if (p === "openWeather")
            return "OpenWeather";
        if (p === "weatherApi")
            return "WeatherAPI.com";
        if (p === "metno")
            return "met.no";
        return "Open-Meteo";
    }

    function _tryProvider(chain, idx) {
        if (idx >= chain.length) {
            weatherRoot.loading = false;
            var names = chain.map(function (p) {
                return _providerLabel(p);
            });
            weatherRoot.updateText = i18n("Failed: %1", names.join(", "));
            _failed = [];
            return;
        }
        var p = chain[idx];
        if (p === "openWeather") {
            OpenWeatherJS.fetchCurrent(service, W, chain, idx);
            return;
        }
        if (p === "weatherApi") {
            WeatherApiJS.fetchCurrent(service, W, chain, idx);
            return;
        }
        if (p === "metno") {
            MetNoJS.fetchCurrent(service, W, chain, idx);
            return;
        }
        OpenMeteoJS.fetchCurrent(service, chain, idx); // default
    }

    // ─── Sunrise/sunset fallback for providers that don't supply it ─────────

    /**
     * Fetches today's sunrise and sunset from Open-Meteo and writes them
     * into weatherRoot.  Called after met.no succeeds so night-icon logic
     * and isNightTime() work correctly even without a primary API for these.
     */
    function _fetchSunTimesOpenMeteo() {
        var r = weatherRoot;
        var tz = (Plasmoid.configuration.timezone || "").trim();
        var today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        var url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude="  + Plasmoid.configuration.latitude
            + "&longitude=" + Plasmoid.configuration.longitude
            + "&timezone="  + encodeURIComponent(tz.length > 0 ? tz : "auto")
            + "&daily=sunrise,sunset"
            + "&start_date=" + today
            + "&end_date="   + today;
        var req = new XMLHttpRequest();
        req.open("GET", url);
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE)
                return;
            if (req.status !== 200)
                return;  // leave "--" in place — better than crashing
            try {
                var d = JSON.parse(req.responseText);
                if (d.daily && d.daily.sunrise && d.daily.sunrise.length > 0)
                    r.sunriseTimeText = Qt.formatTime(new Date(d.daily.sunrise[0]), "HH:mm");
                if (d.daily && d.daily.sunset && d.daily.sunset.length > 0)
                    r.sunsetTimeText = Qt.formatTime(new Date(d.daily.sunset[0]), "HH:mm");
            } catch (e) {}
        };
        req.send();
    }
}
