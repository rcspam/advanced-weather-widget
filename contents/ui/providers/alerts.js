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
 * alerts.js — Centralized weather alerts fetcher
 *
 * Strategy:
 *   1. MeteoAlarm Atom feeds (38 European countries, no auth)
 *   2. Fallback → MET Norway MetAlerts (lat/lon based, Norway only)
 *
 * Non-pragma JS — accesses config via service properties.
 */

// ISO 3166-1 alpha-2 → MeteoAlarm feed slug
var _isoToSlug = {
    "AD": "andorra",
    "AT": "austria",
    "BA": "bosnia-herzegovina",
    "BE": "belgium",
    "BG": "bulgaria",
    "CH": "switzerland",
    "CY": "cyprus",
    "CZ": "czechia",
    "DE": "germany",
    "DK": "denmark",
    "EE": "estonia",
    "ES": "spain",
    "FI": "finland",
    "FR": "france",
    "GB": "united-kingdom",
    "GR": "greece",
    "HR": "croatia",
    "HU": "hungary",
    "IE": "ireland",
    "IL": "israel",
    "IS": "iceland",
    "IT": "italy",
    "LT": "lithuania",
    "LU": "luxembourg",
    "LV": "latvia",
    "MD": "moldova",
    "ME": "montenegro",
    "MK": "republic-of-north-macedonia",
    "MT": "malta",
    "NL": "netherlands",
    "NO": "norway",
    "PL": "poland",
    "PT": "portugal",
    "RO": "romania",
    "RS": "serbia",
    "SE": "sweden",
    "SI": "slovenia",
    "SK": "slovakia",
    "UA": "ukraine"
};

/**
 * Main entry point — called from WeatherService.refreshNow().
 * Tries MeteoAlarm first, falls back to met.no MetAlerts.
 */
function fetchAlerts(service) {
    var isoCode = (service.countryCode || "").toUpperCase();
    var slug = _isoToSlug[isoCode];

    if (slug) {
        _fetchMeteoAlarm(service, slug, function (ok) {
            if (!ok) {
                _fetchMetNo(service);
            }
        });
    } else {
        // Country code not set — try reverse-geocoding to determine it
        _resolveCountryThenFetch(service);
    }
}

// ── Reverse-geocode fallback for missing countryCode ──────────────────

function _resolveCountryThenFetch(service) {
    var lat = service.latitude;
    var lon = service.longitude;
    if (!lat || !lon) return;

    var req = new XMLHttpRequest();
    req.open("GET",
        "https://nominatim.openstreetmap.org/reverse?lat="
        + encodeURIComponent(lat)
        + "&lon=" + encodeURIComponent(lon)
        + "&format=json&zoom=3&addressdetails=1");
    req.setRequestHeader("User-Agent",
        "AdvancedWeatherWidget/1.0 (KDE Plasma plasmoid)");
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        var isoCode = "";
        if (req.status === 200) {
            try {
                var data = JSON.parse(req.responseText);
                if (data.address && data.address.country_code)
                    isoCode = data.address.country_code.toUpperCase();
            } catch (e) { /* ignore */ }
        }
        var slug = _isoToSlug[isoCode];
        if (slug) {
            _fetchMeteoAlarm(service, slug, function (ok) {
                if (!ok)
                    _fetchMetNo(service);
            });
        } else {
            _fetchMetNo(service);
        }
    };
    req.send();
}

// ── MeteoAlarm Atom feeds ─────────────────────────────────────────────

function _fetchMeteoAlarm(service, slug, callback) {
    var r = service.weatherRoot;
    var feedUrl = "https://feeds.meteoalarm.org/api/v1/warnings/feeds-" + slug;

    // Run feed fetch and local-name lookup in parallel
    var state = { feedData: undefined, localTerms: undefined };

    function _tryComplete() {
        if (state.feedData === undefined || state.localTerms === undefined)
            return;
        if (state.feedData === false) {
            callback(false);
            return;
        }
        try {
            var alerts = _parseMeteoAlarmAlerts(
                state.feedData, service.locationName, state.localTerms);
            r.weatherAlerts = alerts;
            callback(true);
        } catch (e) {
            callback(false);
        }
    }

    // 1) Fetch MeteoAlarm feed
    var req = new XMLHttpRequest();
    req.open("GET", feedUrl);
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        if (req.status !== 200) {
            state.feedData = false;
        } else {
            try {
                state.feedData = JSON.parse(req.responseText);
            } catch (e) {
                state.feedData = false;
            }
        }
        _tryComplete();
    };
    req.send();

    // 2) Fetch local admin names via Nominatim (for non-English area matching)
    _getLocalAdminTerms(service.latitude, service.longitude, function (terms) {
        state.localTerms = terms;
        _tryComplete();
    });
}

function _getLocalAdminTerms(lat, lon, callback) {
    if (!lat || !lon) { callback([]); return; }
    var req = new XMLHttpRequest();
    req.open("GET",
        "https://nominatim.openstreetmap.org/reverse?lat="
        + encodeURIComponent(lat)
        + "&lon=" + encodeURIComponent(lon)
        + "&format=json&zoom=10&addressdetails=1");
    req.setRequestHeader("User-Agent",
        "AdvancedWeatherWidget/1.0 (KDE Plasma plasmoid)");
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE) return;
        var terms = [];
        if (req.status === 200) {
            try {
                var data = JSON.parse(req.responseText);
                if (data.address) {
                    var keys = ["city", "town", "village", "municipality",
                                "county", "state", "state_district",
                                "province", "region"];
                    keys.forEach(function (k) {
                        if (data.address[k])
                            terms.push(data.address[k].toLowerCase());
                    });
                }
            } catch (e) { /* ignore */ }
        }
        callback(terms);
    };
    req.send();
}

function _parseMeteoAlarmAlerts(data, locationName, localTerms) {
    var now = new Date();
    var alerts = [];
    // API returns { warnings: [...] }, not a plain array
    var entries = (data && Array.isArray(data.warnings)) ? data.warnings
                : Array.isArray(data) ? data : [];
    if (!entries.length)
        return alerts;

    // Build search terms from locationName + Nominatim local admin names
    var searchTerms = [];
    var locParts = (locationName || "").split(",");
    locParts.forEach(function (p) {
        var t = p.trim().toLowerCase();
        if (t.length > 2) searchTerms.push(t);
    });
    if (localTerms && localTerms.length > 0) {
        localTerms.forEach(function (t) {
            if (t.length > 2 && searchTerms.indexOf(t) < 0)
                searchTerms.push(t);
        });
    }

    entries.forEach(function (entry) {
        if (!entry.alert || !entry.alert.info)
            return;
        // Only "Actual" alerts — skip "Test", "Exercise", etc.
        if (entry.alert.status && entry.alert.status !== "Actual")
            return;
        var infos = entry.alert.info;
        // Pick English info block if available, otherwise first
        var info = _pickEnglishInfo(infos) || infos[0];
        if (!info)
            return;

        // FIX 1: Normalize responseType to array — CAP spec allows a plain string
        var rtypes = Array.isArray(info.responseType)
            ? info.responseType
            : (info.responseType ? [info.responseType] : []);

        // Skip "AllClear" cancellation notices
        if (rtypes.indexOf("AllClear") >= 0)
            return;

        // Skip expired alerts
        if (info.expires) {
            var exp = new Date(info.expires);
            if (exp < now)
                return;
        }

        // Extract awareness_level and awareness_type from parameters
        var levelName = "", color = "", eventType = "", levelNum = 0;
        if (info.parameter) {
            info.parameter.forEach(function (p) {
                if (p.valueName === "awareness_level" && p.value) {
                    var parts = p.value.split(";");
                    if (parts.length >= 1) levelNum = parseInt(parts[0].trim(), 10) || 0;
                    if (parts.length >= 3) levelName = parts[2].trim();
                    if (parts.length >= 2) color = parts[1].trim().toLowerCase();
                }
                if (p.valueName === "awareness_type" && p.value) {
                    var tp = p.value.split(";");
                    if (tp.length >= 2) eventType = tp[1].trim();
                }
            });
        }

        // Skip green/Minor (level 1) — these are "No Special Awareness Required"
        if (levelNum <= 1 && color === "green")
            return;

        // Strict area filtering — only include alerts whose area matches
        // the user's location (via locationName + Nominatim admin terms)
        var matchedAreas = [];
        if (searchTerms.length > 0 && info.area) {
            info.area.forEach(function (a) {
                if (!a.areaDesc) return;
                var desc = a.areaDesc.toLowerCase();
                for (var i = 0; i < searchTerms.length; i++) {
                    if (_textMatch(desc, searchTerms[i])) {
                        matchedAreas.push(a.areaDesc);
                        break;
                    }
                }
            });
            if (matchedAreas.length === 0)
                return;  // no area match — skip this alert
        }

        // Build formatted display name: "Moderate for Wind"
        var displayName = "";
        if (levelName && eventType)
            displayName = levelName + " for " + eventType;
        else
            displayName = info.headline || info.event || "";

        // FIX 1: Use normalized rtypes array (safe to call .filter on)
        var action = rtypes
            .filter(function (r) { return r !== "AllClear"; })
            .join(", ");

        alerts.push({
            headline: info.headline || info.event || "",
            displayName: displayName,
            severity: info.severity || "",
            description: info.description || "",
            event: info.event || eventType || "",
            area: matchedAreas.join(", "),
            color: color,
            onset: info.onset || info.effective || "",
            expires: info.expires || "",
            source: "MeteoAlarm",
            action: action,
            senderName: info.senderName || ""
        });
    });

    // Deduplicate by displayName — keep the one with the latest expiry
    var seen = {};
    var unique = [];
    alerts.forEach(function (a) {
        var key = a.displayName || a.headline;
        if (!seen[key]) {
            seen[key] = true;
            unique.push(a);
        } else {
            // Replace if this one expires later
            for (var i = 0; i < unique.length; i++) {
                if ((unique[i].displayName || unique[i].headline) === key) {
                    if (a.expires && unique[i].expires && a.expires > unique[i].expires)
                        unique[i] = a;
                    break;
                }
            }
        }
    });
    return unique;
}

function _pickEnglishInfo(infos) {
    for (var i = 0; i < infos.length; ++i) {
        var lang = (infos[i].language || "").toLowerCase();
        if (lang === "en-gb" || lang === "en" || lang.indexOf("en") === 0)
            return infos[i];
    }
    return null;
}

/**
 * Fuzzy text match — handles English ↔ local name variants.
 * Returns true if:
 *   1. needle is a substring of haystack (or vice-versa), OR
 *   2. any word in haystack shares a common prefix ≥ 5 chars with needle
 *      (e.g. "lombardy" ↔ "lombardia", "milan" ↔ "milano")
 */
function _textMatch(haystack, needle) {
    if (haystack.indexOf(needle) >= 0 || needle.indexOf(haystack) >= 0)
        return true;
    if (needle.length < 5) return false;
    var words = haystack.split(/[\s,]+/);
    for (var w = 0; w < words.length; w++) {
        var word = words[w];
        var minLen = Math.min(word.length, needle.length);
        if (minLen < 5) continue;
        var p = 0;
        while (p < minLen && word.charAt(p) === needle.charAt(p)) p++;
        if (p >= 5) return true;
    }
    return false;
}

// ── MET Norway MetAlerts ──────────────────────────────────────────────

function _fetchMetNo(service) {
    var r = service.weatherRoot;
    var url = "https://api.met.no/weatherapi/metalerts/2.0/current.json"
        + "?lat=" + service.latitude
        + "&lon=" + service.longitude
        + "&lang=en";
    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.setRequestHeader("User-Agent",
        "AdvancedWeatherWidget/1.0 github.com/pnedyalkov91/advanced-weather-widget");
    req.onreadystatechange = function () {
        if (req.readyState !== XMLHttpRequest.DONE)
            return;
        if (req.status !== 200) {
            // Both sources failed — leave alerts as-is (already [])
            return;
        }
        try {
            var data = JSON.parse(req.responseText);
            var alerts = _parseMetNoAlerts(data);
            r.weatherAlerts = alerts;
        } catch (e) {
            // Parse error — leave alerts empty
        }
    };
    req.send();
}

function _parseMetNoAlerts(data) {
    var now = new Date();
    var alerts = [];
    if (!data.features || !Array.isArray(data.features))
        return alerts;

    data.features.forEach(function (f) {
        var p = f.properties;
        if (!p)
            return;

        // Only show "Actual" status alerts (skip "Test")
        if (p.status && p.status !== "Actual")
            return;

        // Skip expired alerts
        if (f.when && f.when.interval && f.when.interval.length >= 2) {
            var end = new Date(f.when.interval[1]);
            if (end < now)
                return;
        }

        var color = "";
        var levelName = "";
        if (p.riskMatrixColor)
            color = p.riskMatrixColor.toLowerCase();
        if (p.awareness_level) {
            var parts = p.awareness_level.split(";");
            if (parts.length >= 2 && !color)
                color = parts[1].trim().toLowerCase();
            if (parts.length >= 3)
                levelName = parts[2].trim();
        }

        var displayName = "";
        if (levelName && p.event)
            displayName = levelName + " for " + p.event;
        else
            displayName = p.title || p.eventAwarenessName || "";

        alerts.push({
            headline: p.title || p.eventAwarenessName || "",
            displayName: displayName,
            severity: p.severity || "",
            description: p.description || "",
            event: p.event || "",
            area: p.area || "",
            color: color,
            onset: (f.when && f.when.interval) ? f.when.interval[0] : "",
            expires: (f.when && f.when.interval && f.when.interval.length >= 2)
                ? f.when.interval[1] : "",
            source: "MET Norway",
            action: p.instruction || "",
            senderName: "MET Norway"
        });
    });

    return alerts;
}