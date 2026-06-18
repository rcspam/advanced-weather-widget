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
 * windCompass.js — Canvas drawing for the expandable Wind card.
 *
 * Draws a compass ring with cardinal ticks/labels and an arrow pointing
 * toward the wind bearing (0° = North = up), matching the direction
 * convention used by weather.js windDirectionGlyph()/windDirectionSvgStem().
 */
.pragma library

/** 16-point cardinal abbreviation for a bearing in degrees. */
function cardinal(deg) {
    if (deg === undefined || deg === null || isNaN(deg)) return "";
    var names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                 "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    var idx = Math.floor(((deg + 11.25) % 360) / 22.5) % 16;
    return names[idx];
}

/**
 * @param ctx        2D canvas context
 * @param cw, ch     canvas size
 * @param dirDeg     wind bearing in degrees (0 = N), may be NaN
 * @param isDark     dark theme flag
 * @param accentCss  accent colour (CSS string) for the arrow / North marker
 */
function drawWindCompass(ctx, cw, ch, dirDeg, isDark, accentCss) {
    ctx.clearRect(0, 0, cw, ch);
    if (cw <= 0 || ch <= 0) return;

    var cx = cw / 2;
    var cy = ch / 2;
    var r = Math.min(cx, cy) - 16;
    if (r <= 4) return;

    var ringCol  = isDark ? "rgba(255,255,255,0.16)" : "rgba(0,0,0,0.14)";
    var tickCol  = isDark ? "rgba(255,255,255,0.28)" : "rgba(0,0,0,0.26)";
    var labelCol = isDark ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.55)";
    var accent   = accentCss || (isDark ? "#5ea8ff" : "#1a6fcc");

    // Outer ring
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
    ctx.lineWidth = 2;
    ctx.strokeStyle = ringCol;
    ctx.stroke();

    // Ticks every 30°, longer + bolder at the four cardinals
    for (var a = 0; a < 360; a += 30) {
        var br = a * Math.PI / 180;
        var ox = cx + Math.sin(br) * r;
        var oy = cy - Math.cos(br) * r;
        var inner = (a % 90 === 0) ? r - 9 : r - 5;
        var ix = cx + Math.sin(br) * inner;
        var iy = cy - Math.cos(br) * inner;
        ctx.beginPath();
        ctx.moveTo(ox, oy);
        ctx.lineTo(ix, iy);
        ctx.lineWidth = (a % 90 === 0) ? 2 : 1;
        ctx.strokeStyle = tickCol;
        ctx.stroke();
    }

    // Cardinal labels
    ctx.font = "bold 10px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    var lr = r - 18;
    if (lr > 8) {
        var cards = [["N", 0], ["E", 90], ["S", 180], ["W", 270]];
        for (var i = 0; i < cards.length; i++) {
            var cb = cards[i][1] * Math.PI / 180;
            var lx = cx + Math.sin(cb) * lr;
            var ly = cy - Math.cos(cb) * lr;
            ctx.fillStyle = (cards[i][0] === "N") ? accent : labelCol;
            ctx.fillText(cards[i][0], lx, ly);
        }
    }

    // Direction arrow (points toward the bearing; N = up, matching the glyphs)
    if (dirDeg !== undefined && dirDeg !== null && !isNaN(dirDeg)) {
        var ar = dirDeg * Math.PI / 180;
        var ax = Math.sin(ar), ay = -Math.cos(ar); // unit direction vector
        var px = -ay, py = ax;                      // perpendicular
        var tip = r - 6;
        var tail = r - 10;
        var headBack = tip - 13;
        var headW = 7;

        var tipX = cx + ax * tip, tipY = cy + ay * tip;
        var tailX = cx - ax * tail, tailY = cy - ay * tail;
        var backX = cx + ax * headBack, backY = cy + ay * headBack;

        // Shaft
        ctx.beginPath();
        ctx.moveTo(tailX, tailY);
        ctx.lineTo(backX, backY);
        ctx.lineWidth = 3;
        ctx.lineCap = "round";
        ctx.strokeStyle = accent;
        ctx.stroke();

        // Head
        ctx.beginPath();
        ctx.moveTo(tipX, tipY);
        ctx.lineTo(backX + px * headW, backY + py * headW);
        ctx.lineTo(backX - px * headW, backY - py * headW);
        ctx.closePath();
        ctx.fillStyle = accent;
        ctx.fill();

        // Centre hub
        ctx.beginPath();
        ctx.arc(cx, cy, 3, 0, 2 * Math.PI);
        ctx.fillStyle = accent;
        ctx.fill();
    }
}
