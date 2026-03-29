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
 * airQuality.js — European Air Quality Index helpers
 *
 * Implements the EU CAQI / Open-Meteo european_aqi scale:
 *   0–25   Good
 *   25–50  Fair
 *   50–75  Moderate
 *   75–100 Poor
 *   100–150 Very Poor
 *   >150   Extremely Poor
 *
 * Per-pollutant sub-index breakpoints follow the CAQI specification:
 *   PM2.5  (µg/m³): 10 / 20 / 25 / 50 / 75 → sub-index 0–150
 *   PM10   (µg/m³): 25 / 50 / 90 / 180 / 270 → sub-index 0–150
 *   NO2    (µg/m³): 40 / 90 / 120 / 230 / 340 → sub-index 0–150
 *   O3     (µg/m³): 60 / 120 / 180 / 240 / 360 → sub-index 0–150
 *   SO2    (µg/m³): 100 / 200 / 350 / 500 / 750 → sub-index 0–150
 *   CO     (mg/m³):  4 /   7 /  11 /  13 /  17 → sub-index 0–150
 *                   (Open-Meteo returns CO in µg/m³ → divide by 1000)
 */

.pragma library

// ─── Band definitions ────────────────────────────────────────────────────────

var BANDS = [
    { max: 25,  label: "Good",           shortLabel: "Good",     color: "#4CAF50", textColor: "#1B5E20", description: "Air quality is satisfactory." },
    { max: 50,  label: "Fair",           shortLabel: "Fair",     color: "#CDDC39", textColor: "#4E6B00", description: "Air quality is acceptable." },
    { max: 75,  label: "Moderate",       shortLabel: "Moderate", color: "#FF9800", textColor: "#7A3500", description: "Air quality is fair." },
    { max: 100, label: "Poor",           shortLabel: "Poor",     color: "#F44336", textColor: "#7F0000", description: "Air quality is poor." },
    { max: 150, label: "Very Poor",      shortLabel: "V.Poor",   color: "#9C27B0", textColor: "#4A0072", description: "Air quality is very poor." },
    { max: 9999,label: "Extremely Poor", shortLabel: "Extreme",  color: "#7B1FA2", textColor: "#1A002A", description: "Air quality is extremely poor." }
];

// ─── Per-pollutant breakpoints ────────────────────────────────────────────────
// Each entry: [c1, c2, c3, c4, c5] concentrations mapping to sub-index
// 0→0, c1→25, c2→50, c3→75, c4→100, c5→150, >c5→150+

var POLLUTANT_BREAKS = {
    pm2_5: [10,   20,   25,   50,   75],
    pm10:  [25,   50,   90,  180,  270],
    no2:   [40,   90,  120,  230,  340],
    o3:    [60,  120,  180,  240,  360],
    so2:   [100, 200,  350,  500,  750],
    co:    [4,     7,   11,   13,   17]   // in mg/m³ (divide µg/m³ by 1000 before passing)
};

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Returns the band object for a given European AQI value (0–150+).
 */
function bandForIndex(aqi) {
    if (isNaN(aqi) || aqi === null) return BANDS[0];
    for (var i = 0; i < BANDS.length; i++) {
        if (aqi < BANDS[i].max) return BANDS[i];
    }
    return BANDS[BANDS.length - 1];
}

/**
 * Returns { label, color, textColor, description } for a given AQI.
 */
function infoForIndex(aqi) {
    return bandForIndex(aqi);
}

/**
 * Returns the EU AQI color hex string for an index value.
 */
function colorForIndex(aqi) {
    return bandForIndex(aqi).color;
}

/**
 * Returns the label string ("Good", "Fair", etc.) for an index value.
 */
function labelForIndex(aqi) {
    return bandForIndex(aqi).label;
}

/**
 * Computes a 0–150 sub-index for a pollutant concentration.
 *
 * @param {string} pollutant  Key in POLLUTANT_BREAKS: "pm2_5", "pm10", "no2", "o3", "so2", "co"
 * @param {number} value      Concentration in native units (CO in mg/m³, others in µg/m³)
 * @returns {number}          Sub-index 0–150 (clamped), or NaN if input is NaN
 */
function subIndex(pollutant, value) {
    if (isNaN(value) || value === null || value === undefined) return NaN;
    var breaks = POLLUTANT_BREAKS[pollutant];
    if (!breaks) return NaN;

    // Linear interpolation between band boundaries
    // Band 0: 0 → 25   (concentration 0 → breaks[0])
    // Band 1: 25 → 50  (breaks[0] → breaks[1])
    // Band 2: 50 → 75  (breaks[1] → breaks[2])
    // Band 3: 75 → 100 (breaks[2] → breaks[3])
    // Band 4: 100 → 150 (breaks[3] → breaks[4])
    // Band 5: >breaks[4] → capped at 150

    var cLo, cHi, iLo, iHi;
    if (value <= 0)           return 0;
    if (value <= breaks[0]) { cLo = 0;          cHi = breaks[0]; iLo = 0;   iHi = 25; }
    else if (value <= breaks[1]) { cLo = breaks[0]; cHi = breaks[1]; iLo = 25;  iHi = 50; }
    else if (value <= breaks[2]) { cLo = breaks[1]; cHi = breaks[2]; iLo = 50;  iHi = 75; }
    else if (value <= breaks[3]) { cLo = breaks[2]; cHi = breaks[3]; iLo = 75;  iHi = 100; }
    else if (value <= breaks[4]) { cLo = breaks[3]; cHi = breaks[4]; iLo = 100; iHi = 150; }
    else                         return 150;

    return iLo + (value - cLo) / (cHi - cLo) * (iHi - iLo);
}

/**
 * Returns the band for a pollutant sub-index value.
 */
function bandForSubIndex(si) {
    return bandForIndex(si);
}

/**
 * Returns a percentage (0–100) for positioning on a 0–150 scale bar.
 */
function scalePercent(value, maxScale) {
    var scale = maxScale || 150;
    return Math.min(100, Math.max(0, value / scale * 100));
}

/**
 * Returns the unit string for a pollutant key.
 */
function unitFor(pollutant) {
    if (pollutant === "co") return "mg/m³";
    return "µg/m³";
}

/**
 * Returns the display name for a pollutant key.
 */
function nameFor(pollutant) {
    switch (pollutant) {
        case "pm2_5": return "PM2.5";
        case "pm10":  return "PM10";
        case "no2":   return "NO₂";
        case "o3":    return "O₃";
        case "so2":   return "SO₂";
        case "co":    return "CO";
    }
    return pollutant;
}
