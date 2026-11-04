// === WIND LEVEL SPIKE (test page only, injected by build-test.py after the humidity spike) ===
// The wind of the animation at 10 m or at 700 hPa (about 3000 m, the flow
// that steers the rain), the two levels the radar's wind offers. Each level
// has its own field, store key and pictures (kept under 'wind:<level>' while
// another is shown), so a new level fades in over the old one, as the
// pollutants do. Close in, the layer reads the API grids, which hold both
// levels already. window.windSetLevel(id), windLevels.
var WindLevelSpike = (function () {
  'use strict';
  var LEVELS = [['10m', '10 m'], ['700hPa', '700 hPa']];
  var current = '10m';
  var base = WidgetAnim.FIELDS.wind;

  var fields = { '10m': base };
  function fieldOf(level) {
    if (fields[level]) return fields[level];
    var f = {};
    for (var k in base) f[k] = base[k];
    f.store = 'wind-' + level + '-0.25';
    f.vars = ['wind_u_component_' + level, 'wind_v_component_' + level];
    f.read = function (e, t) {
      var g = WidgetOpenData.toGrid(e.data[0], e.data[1], e.ny, e.nx, t, level);
      return { meta: { lats: g.lats, lons: g.lons, res: g.res }, parts: [g.u[0], g.v[0]].map(base.packPart) };
    };
    return (fields[level] = f);
  }
  // pruneStore keeps the store keys of FIELDS only: every level is listed
  // under a name of its own, so the pictures of the one not shown stay.
  LEVELS.forEach(function (l) { WidgetAnim.FIELDS['wind@' + l[0]] = fieldOf(l[0]); });
  ANIM_KEYS.wind = function () { return 'wind:' + current; };

  // The layer of glue-controls, at the level chosen.
  ANIM_LAYERS.wind = function (m) {
    var layer = _widgetAdapter.createWindLayer(anim.api, null, _windDem, {
      fps: windFps, maxFps: windMaxFps, relief: WIND_RELIEF, theme: currentTheme(), level: current,
      lineWidth: windLineWidth, palette: windPalette, density: windDensity, manual: true
    });
    if (!layer) return null;
    layer.addTo(m);
    layer.settle();
    return layer;
  };

  /** Another level: the wind layer goes off and comes back at it, the new
      level fading in over the old one once its first picture is in. */
  window.windSetLevel = function (id) {
    if (!LEVELS.some(function (l) { return l[0] === id; }) || id === current) return current;
    var on = anim && anim.group.track('wind');
    if (on) window.animSetLayer('wind', false);
    current = id;
    WidgetAnim.FIELDS.wind = fieldOf(id);
    if (on) window.animSetLayer('wind', true);
    return current;
  };
  window.windLevels = function () { return LEVELS; };
  window.windLevel = function () { return current; };

  return { LEVELS: LEVELS, fieldOf: fieldOf };
})();
