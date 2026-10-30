// ==========================================================================
// Glue script 2f: the temperature layer of the MapLibre map.
// The 2 m temperature comes the way the wind does: far out, the open-data
// file (the model's own field, no API call); closer, the API grids that the
// wind fetches too, in the same request. Each pixel is brought from the
// height the data are valid at (the model's ground, or the API point's) to
// its own, read in the Terrarium tiles, at 6.5 °C per km. The picture is
// drawn in a canvas in slices of a few ms, then handed to the adapter, which
// shows it right over the base map, under the radar.
// ==========================================================================
WidgetTemp.TempLayer = (function () {
  'use strict';
  var WindField = WidgetWind.WindField;
  var DEG = Math.PI / 180;
  var MAX_LAT = 85.0511;
  var SLICE_MS = 4;           // longest slice of drawing per frame
  var MARGIN = 0.1;           // drawn around the view on each side, so a short pan shows no edge
  var WORLD_ZOOM = 4;         // below it (MapLibre zoom), one picture of the whole world
  var WORLD_PX = 2048;        // its size, and the most a view picture gets
  var RECHECK_MS = 600000;    // a newer file now and then; latest.json at most every 10 min anyway
  var LEGEND_PX = 240;

  function mercY(lat) { return Math.log(Math.tan(Math.PI / 4 + lat * DEG / 2)); }
  function latOfMercY(y) { return (2 * Math.atan(Math.exp(y)) - Math.PI / 2) / DEG; }

  /** The box drawn for a view (degrees), or the whole world when zoomed out. */
  function drawBox(bounds, zoom) {
    if (zoom < WORLD_ZOOM || bounds.east - bounds.west >= 360) {
      return { w: -180, e: 180, s: -MAX_LAT, n: MAX_LAT, world: true };
    }
    var mw = (bounds.east - bounds.west) * MARGIN, mh = (bounds.north - bounds.south) * MARGIN;
    return {
      w: bounds.west - mw, e: bounds.east + mw,
      s: Math.max(-MAX_LAT, bounds.south - mh), n: Math.min(MAX_LAT, bounds.north + mh), world: false
    };
  }

  /** Zoom of the elevation tiles: about one tile pixel for two screen
      pixels, a handful of tiles for the whole world. */
  function demZoom(zoom, world) {
    var z = Math.min(12, Math.max(0, Math.round(zoom)));
    return world ? Math.min(2, z) : z;
  }

  function TempLayer(adapter, source, openData, dem, options) {
    options = options || {};
    this._adapter = adapter;
    this._source = source;
    this._open = openData || null;
    this._dem = dem || null;
    this.options = {
      stops: options.stops || WidgetTemp.DEFAULT_STOPS,
      step: WidgetTemp.normStep(options.step),
      unit: WidgetTemp.normUnit(options.unit),
      opacity: WidgetTemp.normOpacity(options.opacity),
      fetchDelayMs: options.fetchDelayMs == null ? 600 : options.fetchDelayMs,
      retryMinMs: options.retryMinMs == null ? 1000 : options.retryMinMs
    };
    this._now = options.now || function () { return Date.now(); };
    this._map = null;
    this._token = 0;          // view of the last reset
    this._job = 0;            // drawing under way
    this._drawn = false;
    this._mode = null;        // 'file' | 'api'
    this._fileGrid = null;
    this._fileState = this._open ? 'loading' : 'failed';
    this._surface = null;
    this._lut = null;
    this._legend = null;
    this._worldKey = null;    // what the whole-world picture on the map was drawn from
  }

  TempLayer.prototype = {
    addTo: function (map) {
      var self = this;
      this._map = map;
      this._canvas = document.createElement('canvas');
      this._ctx = this._canvas.getContext('2d');
      this._lut = WidgetTemp.buildLut(this.options.stops, this.options.step, this.options.unit);
      this._legend = document.createElement('div');
      this._legend.id = 'lv-temp-legend';
      (document.getElementById('lv-map') || map.getContainer()).appendChild(this._legend);
      this._renderLegend();
      this._onMoveEnd = function () { self._reset(); };
      map.on('moveend', this._onMoveEnd);
      map.on('resize', this._onMoveEnd);
      if (this._open) {
        var open = this._open;
        open.keptTemp().then(function (grid) {
          if (grid && !self._fileGrid) self._fileIn(grid, true);
          return open.loadTemp();
        }).then(function (res) {
          if (res) self._fileIn(res.grid, res.changed);
          else if (!self._fileGrid) {
            self._fileState = 'failed';
            self._reset();
          }
        });
        open.loadSurface().then(function (surface) {
          if (!self._map || !surface) return;
          self._surface = surface;
          if (self._mode === 'file') self._reset();
        });
        this._recheck = setInterval(function () {
          open.loadTemp().then(function (res) { if (res && res.changed) self._fileIn(res.grid, true); });
        }, RECHECK_MS);
        // Under Node (tests) the timer must not keep the process alive.
        if (this._recheck && this._recheck.unref) this._recheck.unref();
      }
      this._reset();
      return this;
    },

    remove: function () {
      this._token++;
      this._job++;
      if (this._fetchTimer) { clearTimeout(this._fetchTimer); this._fetchTimer = null; }
      if (this._recheck) { clearInterval(this._recheck); this._recheck = null; }
      if (!this._map) return;
      this._map.off('moveend', this._onMoveEnd);
      this._map.off('resize', this._onMoveEnd);
      this._adapter.clearTemp();
      if (this._legend) this._legend.remove();
      this._legend = null;
      this._map = null;
    },

    /** True once a picture is on the map. */
    isDrawing: function () { return this._drawn; },

    /** Opacity in percent: only the layer changes, nothing is redrawn. */
    setOpacity: function (percent) {
      this.options.opacity = WidgetTemp.normOpacity(percent);
      if (this._map) this._adapter.setTempOpacity(this.options.opacity / 100);
    },

    setPalette: function (stops) { this.options.stops = stops || WidgetTemp.DEFAULT_STOPS; this._recolor(); },
    setStep: function (step) { this.options.step = WidgetTemp.normStep(step); this._recolor(); },
    setUnit: function (unit) { this.options.unit = WidgetTemp.normUnit(unit); this._recolor(); },

    /** Draw again (the projection changed). */
    refresh: function () { this._reset(); },

    _recolor: function () {
      if (!this._map) return;
      this._lut = WidgetTemp.buildLut(this.options.stops, this.options.step, this.options.unit);
      this._renderLegend();
      this._reset();
    },

    _renderLegend: function () {
      var o = this.options, ticks = WidgetTemp.legendTicks(o.stops, o.unit);
      this._legend.innerHTML = '<div class="lv-temp-ticks">' + ticks.map(function (k) {
        return '<span style="left:' + (k.pos * 100).toFixed(2) + '%">' + k.label + '</span>';
      }).join('') + '</div><span class="lv-temp-unit">°' + o.unit + '</span>';
      var bar = document.createElement('canvas'), g = bar.getContext('2d'), lut = this._lut;
      var lo = o.stops[0].t, hi = o.stops[o.stops.length - 1].t;
      bar.width = LEGEND_PX;
      bar.height = 10;
      bar.className = 'lv-temp-bar';
      for (var x = 0; x < LEGEND_PX; x++) {
        var i = WidgetTemp.lutIndex(lo + (x + 0.5) / LEGEND_PX * (hi - lo)) * 3;
        g.fillStyle = 'rgb(' + lut[i] + ',' + lut[i + 1] + ',' + lut[i + 2] + ')';
        g.fillRect(x, 0, 1, 10);
      }
      this._legend.appendChild(bar);
    },

    _view: function () {
      var b = this._adapter.getBounds();
      return {
        bounds: { west: b.west, south: Math.max(-85, b.south), east: b.east, north: Math.min(85, b.north) },
        zoom: this._map.getZoom() + 1   // the wind's grids count zoom levels of 256 px tiles
      };
    },

    _setMode: function (mode) {
      if (mode === this._mode) return;
      this._mode = mode;
      console.log('[temp] source: ' + (mode === 'file' ? 'open data' : 'API'));
    },

    _fileIn: function (grid, changed) {
      var first = this._fileState !== 'ready';
      this._fileGrid = grid;
      this._fileState = 'ready';
      if (!this._map || (!first && !changed)) return;
      if (this._mode === 'api' && WindField.wantApi(WindField.gridSpec(this._view().bounds), this._open.res)) return;
      this._reset();
    },

    /** Far out the file; closer, or when the file failed, the API grids. */
    _reset: function () {
      if (!this._map) return;
      var self = this, token = ++this._token, view = this._view();
      if (this._fetchTimer) { clearTimeout(this._fetchTimer); this._fetchTimer = null; }
      if (this._open && this._fileState !== 'failed' && !WindField.wantApi(WindField.gridSpec(view.bounds), this._open.res)) {
        this._setMode('file');
        // Still on its way: _fileIn() draws.
        if (this._fileState === 'ready') this._draw(view, this._fileField(), false);
        return;
      }
      this._setMode('api');
      // Draw at once with the best grid at hand, then make sure the data
      // cover the view: one request serves the wind and the temperature.
      var best = this._source.best(view);
      var drawn = best && best.grid && best.grid.temp ? best : null;
      if (drawn) this._draw(view, this._apiField(drawn.grid), false);
      this._fetchTimer = setTimeout(function () {
        self._fetchTimer = null;
        self._ensureFor(view, token, drawn);
      }, drawn ? this.options.fetchDelayMs : 0);
    },

    /** Get an API grid for the view of reset `token` and draw it unless it
        is the one on the map; when the source holds back (the interval
        between requests, a failure), ask again once it allows, as the wind
        does. */
    _ensureFor: function (view, token, drawn) {
      var self = this;
      this._source.ensure(view).then(function (entry) {
        if (token !== self._token || !self._map) return;
        var now = self._source.now(), next = WindField.afterEnsure(view, entry, now, self._source.ttlMs);
        if (next.draw && entry !== drawn && entry.grid.temp) {
          drawn = entry;
          self._draw(view, self._apiField(entry.grid), false);
        }
        if (!next.retry) return;
        var wait = Math.max(self.options.retryMinMs, (self._source.blockedUntil || 0) - now + 200);
        self._fetchTimer = setTimeout(function () {
          self._fetchTimer = null;
          if (token === self._token && self._map) self._ensureFor(view, token, drawn);
        }, wait);
      });
    },

    /** The file's temperature, with the model's ground height when it matches. */
    _fileField: function () {
      var g = this._fileGrid, s = this._surface;
      return { grid: g, values: g.values, elev: s && s.values.length === g.values.length ? s.values : null };
    },

    /** An API grid's temperature at the present time, with its points' heights. */
    _apiField: function (grid) {
      var tw = WindField.timeWeights(grid.times, this._now() / 1000);
      var a = grid.temp[tw.i], b = grid.temp[Math.min(tw.i + 1, grid.temp.length - 1)];
      var values = new Float32Array(a.length);
      for (var k = 0; k < a.length; k++) values[k] = a[k] + (b[k] - a[k]) * tw.frac;
      return { grid: grid, values: values, elev: grid.elev };
    },

    /** Draw a field over the view, a few rows per frame; the picture goes to
        the adapter once complete. A new draw cancels this one. Pixels whose
        elevation tile is not in yet are left uncorrected, and once the tiles
        are in, the view is drawn once more (afterDem). */
    _draw: function (view, field, afterDem) {
      var self = this, map = this._map, dem = this._dem, lut = this._lut;
      var box = drawBox(view.bounds, map.getZoom()), c = map.getContainer();
      var W = box.world ? WORLD_PX : Math.max(1, Math.min(WORLD_PX, Math.round(c.clientWidth * (1 + 2 * MARGIN))));
      var H = box.world ? WORLD_PX : Math.max(1, Math.min(WORLD_PX, Math.round(c.clientHeight * (1 + 2 * MARGIN))));
      var z = demZoom(map.getZoom(), box.world), size = 256 * Math.pow(2, z);
      // The whole-world picture does not depend on the view: a move that
      // keeps it draws nothing new (the globe turning, a pan far out).
      var w = this._worldKey;
      if (box.world && !afterDem && w && w.values === field.values && w.elev === field.elev && w.lut === lut && w.z === z) return;
      this._worldKey = box.world ? { values: field.values, elev: field.elev, lut: lut, z: z } : null;
      var job = ++this._job;
      var demReady = field.elev && dem ? dem.ensure({ west: box.w, south: box.s, east: box.e, north: box.n }, z) : null;
      var img = this._ctx.createImageData(W, H), px = img.data;
      var yN = mercY(box.n), yS = mercY(box.s);
      var lons = new Float64Array(W), wxs = new Float64Array(W), x;
      for (x = 0; x < W; x++) {
        lons[x] = box.w + (x + 0.5) / W * (box.e - box.w);
        wxs[x] = (((lons[x] + 180) / 360 * size) % size + size) % size;
      }
      var row = 0, missing = false;
      var slice = function () {
        if (job !== self._job || !self._map) return;
        var t0 = performance.now();
        for (; row < H; row++) {
          if (performance.now() - t0 >= SLICE_MS) { requestAnimationFrame(slice); return; }
          var lat = latOfMercY(yN + (row + 0.5) / H * (yS - yN));
          var wy = WindField.worldPx(lat, 0, z).y;
          for (x = 0; x < W; x++) {
            var o = (row * W + x) * 4, t = WidgetTemp.sampleScalar(field.grid, field.values, lat, lons[x]);
            if (!isFinite(t)) { px[o + 3] = 0; continue; }
            if (field.elev) {
              var zPix = dem ? dem.elevationAtWorld(wxs[x], wy, z) : NaN;
              if (!isFinite(zPix)) missing = true;
              t = WidgetTemp.correct(t, WidgetTemp.sampleScalar(field.grid, field.elev, lat, lons[x]), zPix);
            }
            var i = WidgetTemp.lutIndex(t) * 3;
            px[o] = lut[i]; px[o + 1] = lut[i + 1]; px[o + 2] = lut[i + 2]; px[o + 3] = 255;
          }
        }
        // Sized only now: MapLibre uploads a canvas source whose size changed.
        self._canvas.width = W;
        self._canvas.height = H;
        self._ctx.putImageData(img, 0, 0);
        self._adapter.setTempImage(self._canvas, [[box.w, box.n], [box.e, box.n], [box.e, box.s], [box.w, box.s]],
          self.options.opacity / 100);
        self._drawn = true;
        if (missing && demReady && !afterDem) {
          demReady.then(function () { if (job === self._job && self._map) self._draw(view, field, true); });
        }
      };
      requestAnimationFrame(slice);
    }
  };

  return TempLayer;
})();
