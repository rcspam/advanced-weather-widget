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
 * pressureGauge.js — Canvas drawing for the expandable Pressure card.
 *
 * Draws a semicircular dial over the sea-level pressure range (970–1040 hPa)
 * with a coloured progress arc and a marker dot at the current reading.
 */
.pragma library

var LO = 970;
var HI = 1040;

/** Normalised 0..1 position of an hPa value on the gauge. */
function progress(hpa) {
    if (hpa === undefined || hpa === null || isNaN(hpa)) return 0.5;
    return Math.max(0, Math.min(1, (hpa - LO) / (HI - LO)));
}

/** Qualitative band key for an hPa value: "low" | "normal" | "high". */
function band(hpa) {
    if (hpa === undefined || hpa === null || isNaN(hpa)) return "normal";
    if (hpa < 1000) return "low";
    if (hpa > 1025) return "high";
    return "normal";
}

/**
 * @param ctx        2D canvas context
 * @param cw, ch     canvas size
 * @param hpa        pressure in hPa, may be NaN
 * @param isDark     dark theme flag
 * @param accentCss  accent colour (CSS string) for the progress arc / marker
 */
function drawPressureGauge(ctx, cw, ch, hpa, isDark, accentCss) {
    ctx.clearRect(0, 0, cw, ch);
    if (cw <= 0 || ch <= 0) return;

    var cx = cw / 2;
    var baseY = ch - 20;
    var r = Math.min(cx - 24, baseY - 6);
    if (r <= 4) return;

    var trackCol = isDark ? "rgba(255,255,255,0.13)" : "rgba(0,0,0,0.11)";
    var accent   = accentCss || (isDark ? "#4ecdc4" : "#007070");

    // Track (semicircle, left → right over the top)
    ctx.beginPath();
    ctx.arc(cx, baseY, r, Math.PI, 2 * Math.PI, false);
    ctx.lineWidth = 6;
    ctx.lineCap = "round";
    ctx.strokeStyle = trackCol;
    ctx.stroke();

    // Progress arc up to the current value
    var t = progress(hpa);
    var ang = Math.PI * (1 + t);
    if (t > 0) {
        ctx.beginPath();
        ctx.arc(cx, baseY, r, Math.PI, ang, false);
        ctx.lineWidth = 6;
        ctx.lineCap = "round";
        ctx.strokeStyle = accent;
        ctx.stroke();
    }

    // Marker dot
    var dx = cx + Math.cos(ang) * r;
    var dy = baseY + Math.sin(ang) * r;
    ctx.beginPath();
    ctx.arc(dx, dy, 6, 0, 2 * Math.PI);
    ctx.fillStyle = accent;
    ctx.fill();
    ctx.beginPath();
    ctx.arc(dx, dy, 6, 0, 2 * Math.PI);
    ctx.lineWidth = 2;
    ctx.strokeStyle = isDark ? "rgba(20,20,20,0.85)" : "rgba(255,255,255,0.95)";
    ctx.stroke();

    // End-scale labels
    ctx.font = "10px sans-serif";
    ctx.fillStyle = isDark ? "rgba(255,255,255,0.5)" : "rgba(0,0,0,0.5)";
    ctx.textBaseline = "top";
    ctx.textAlign = "center";
    ctx.fillText("" + LO, cx - r, baseY + 5);
    ctx.fillText("" + HI, cx + r, baseY + 5);
}
