'use strict';
// Unit tests for the temperature layer of the MapLibre map (glue-temp-layer.js),
// on a fake adapter, a fake map, a fake DOM and the real temperature math.
// Run: node --test scripts/librewxr-map-src/tests/*.test.js
const test = require('node:test');
const assert = require('node:assert/strict');

global.WidgetWind = require('../glue-wind.js');
global.WidgetTemp = require('../glue-temp.js');
const WidgetOpenData = require('../glue-wind-open.js');
require('../glue-temp-layer.js');
const T = global.WidgetTemp;
const { WindField, WindSource } = global.WidgetWind;

// Each performance.now() call is 1 ms later: a 4 ms slice draws a few rows.
let clock = 0;
Object.defineProperty(globalThis, 'performance', { value: { now: () => (clock += 1) }, configurable: true });
let rafQueue = [];
global.requestAnimationFrame = (f) => rafQueue.push(f);
function flushRaf() { for (let i = 0; i < 100000 && rafQueue.length; i++) rafQueue.shift()(); }
const tick = () => new Promise((r) => setTimeout(r, 0));
async function settle() { for (let i = 0; i < 10; i++) { await tick(); flushRaf(); } }

function element(tag) {
  const el = {
    tag, style: {}, children: [], innerHTML: '', className: '', id: '', width: 0, height: 0, removed: false, image: null,
    appendChild(c) { this.children.push(c); return c; },
    remove() { this.removed = true; },
    getContext() {
      return {
        fillStyle: '', fillRect() {}, clearRect() {},
        createImageData: (w, h) => ({ width: w, height: h, data: new Uint8ClampedArray(w * h * 4) }),
        putImageData: (img) => { el.image = img; },
      };
    },
  };
  return el;
}
const container = element('div');
global.document = { createElement: element, getElementById: (id) => (id === 'lv-map' ? container : null) };

const NOW = Date.parse('2026-10-30T12:00:00Z');
const EUROPE = { west: -10, south: 35, east: 30, north: 60 };

function fakeMap(zoom) {
  const handlers = {};
  return {
    zoom,
    on: (e, f) => { (handlers[e] = handlers[e] || []).push(f); },
    off: (e, f) => { handlers[e] = (handlers[e] || []).filter((h) => h !== f); },
    fire: (e) => (handlers[e] || []).slice().forEach((f) => f()),
    getZoom() { return this.zoom; },
    getContainer: () => ({ clientWidth: 100, clientHeight: 50 }),
  };
}

function fakeAdapter(bounds) {
  return {
    bounds, images: [], opacities: [], cleared: 0,
    getBounds() { return this.bounds; },
    setTempImage(canvas, coords, opacity) { this.images.push({ image: canvas.image, coords, opacity }); },
    setTempOpacity(o) { this.opacities.push(o); },
    clearTemp() { this.cleared++; },
  };
}

/** The file: 6.3 °C everywhere; the model's ground at 2076 m everywhere. */
function fakeOpen(opts = {}) {
  const grid = WidgetOpenData.toScalarGrid(new Float32Array(12).fill(6.3), 3, 4, NOW);
  const surface = WidgetOpenData.toScalarGrid(new Float32Array(12).fill(2076), 3, 4, null);
  return {
    res: 0.25,
    keptTemp: async () => (opts.fail ? null : grid),
    loadTemp: async () => (opts.fail ? null : { grid, changed: false }),
    loadSurface: async () => (opts.noSurface ? null : surface),
  };
}

/** Elevation tiles: `height` everywhere once ensure() has resolved, if lazy. */
function fakeDem(height, lazy) {
  const d = { loaded: !lazy, resolve: null };
  d.ensure = () => (d.loaded ? Promise.resolve() : new Promise((r) => { d.resolve = () => { d.loaded = true; r(); }; }));
  d.elevationAtWorld = () => (d.loaded ? height : NaN);
  return d;
}

/** An API grid over bounds: 10 °C half an hour ago, 12 °C in half an hour, ground at 1000 m. */
function apiEntry(bounds) {
  const spec = WindField.gridSpec(bounds);
  const points = [];
  for (let i = 0; i < spec.lats.length * spec.lons.length; i++) {
    points.push({ elevation: 1000, hourly: { time: [NOW / 1000 - 1800, NOW / 1000 + 1800],
      wind_speed_10m: [1, 1], wind_direction_10m: [270, 270], temperature_2m: [10, 12] } });
  }
  return { spec, fetchedAt: NOW, grid: WindField.buildGrid(spec, points) };
}

const stubSource = (entry) => ({ calls: 0, best: () => entry, ensure() { this.calls++; return Promise.resolve(entry); }, now: () => NOW });

const OPTS = { stops: T.DEFAULT_STOPS, step: 5, unit: 'C', opacity: 45, fetchDelayMs: 0, now: () => NOW };

/** The colors of an image, as "r,g,b,a" strings. */
function colors(img) {
  const set = new Set();
  for (let i = 0; i < img.data.length; i += 4) set.add(Array.from(img.data.slice(i, i + 4)).join(','));
  return [...set];
}
function colorOf(tC, step = 5, unit = 'C') {
  const lut = T.buildLut(T.DEFAULT_STOPS, step, unit), i = T.lutIndex(tC) * 3;
  return [lut[i], lut[i + 1], lut[i + 2], 255].join(',');
}

test('wide view: drawn from the file, corrected with the model height', async () => {
  const adapter = fakeAdapter(EUROPE);
  const layer = new T.TempLayer(adapter, stubSource(null), fakeOpen(), fakeDem(4792), OPTS);
  layer.addTo(fakeMap(4));
  await settle();
  const last = adapter.images[adapter.images.length - 1];
  assert.deepEqual(colors(last.image), [colorOf(T.correct(6.3, 2076, 4792))]);
  assert.equal(last.opacity, 0.45);
  assert.equal(layer.isDrawing(), true);
});

test('zoomed in: drawn from the API grid, no second request when the wind already has it', async () => {
  const bounds = { west: 6.80, south: 45.80, east: 6.95, north: 45.87 };
  const log = [];
  const fetch = (url) => {
    log.push(url);
    const count = url.split('latitude=')[1].split('&')[0].split(',').length;
    const pts = [];
    for (let i = 0; i < count; i++) {
      pts.push({ elevation: 1000, hourly: { time: [NOW / 1000 - 1800, NOW / 1000 + 1800],
        wind_speed_10m: [1, 1], wind_direction_10m: [270, 270], temperature_2m: [10, 12] } });
    }
    return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(pts) });
  };
  const source = new WindSource({ fetch, storage: null, now: () => NOW });
  const map = fakeMap(10);
  await source.ensure({ bounds, zoom: map.zoom + 1 });          // the wind layer's request
  const before = log.length;
  const adapter = fakeAdapter(bounds);
  new T.TempLayer(adapter, source, fakeOpen(), fakeDem(1000), OPTS).addTo(map);
  await settle();
  assert.equal(log.length, before, 'no request of its own');
  assert.deepEqual(colors(adapter.images[adapter.images.length - 1].image), [colorOf(11)]);
});

test('no open data: the API grid draws every zoom', async () => {
  const adapter = fakeAdapter(EUROPE);
  new T.TempLayer(adapter, stubSource(apiEntry(EUROPE)), fakeOpen({ fail: true }), fakeDem(1000), OPTS).addTo(fakeMap(4));
  await settle();
  assert.ok(adapter.images.length > 0);
  assert.deepEqual(colors(adapter.images[adapter.images.length - 1].image), [colorOf(11)]);
});

test('drawing is sliced and a new move cancels it', async () => {
  const adapter = fakeAdapter(EUROPE);
  const map = fakeMap(4);
  new T.TempLayer(adapter, stubSource(null), fakeOpen(), fakeDem(4792), OPTS).addTo(map);
  for (let i = 0; i < 10; i++) await tick();        // data in, drawing queued
  assert.ok(rafQueue.length > 0, 'a drawing waits for the next frame');
  rafQueue.shift()();                                 // one slice only
  assert.equal(adapter.images.length, 0, 'nothing pushed before the last row');
  adapter.bounds = { west: 0, south: 40, east: 40, north: 65 };
  map.fire('moveend');
  await settle();
  assert.equal(adapter.images.length, 1, 'only the new view is pushed');
  assert.equal(adapter.images[0].coords[0][0], -4);   // west 0 minus 10 % of 40
});

test('a view across the antimeridian draws without holes', async () => {
  const adapter = fakeAdapter({ west: 170, south: -30, east: 190, north: -10 });
  new T.TempLayer(adapter, stubSource(null), fakeOpen(), fakeDem(0), OPTS).addTo(fakeMap(5));
  await settle();
  const img = adapter.images[adapter.images.length - 1].image;
  assert.deepEqual(colors(img), [colorOf(T.correct(6.3, 2076, 0))]);
});

test('the DEM arrives later: one more draw, corrected', async () => {
  const adapter = fakeAdapter(EUROPE);
  const dem = fakeDem(4792, true);
  new T.TempLayer(adapter, stubSource(null), fakeOpen(), dem, OPTS).addTo(fakeMap(4));
  await settle();
  assert.deepEqual(colors(adapter.images[adapter.images.length - 1].image), [colorOf(6.3)]);
  const count = adapter.images.length;
  dem.resolve();
  await settle();
  assert.equal(adapter.images.length, count + 1);
  assert.deepEqual(colors(adapter.images[adapter.images.length - 1].image), [colorOf(T.correct(6.3, 2076, 4792))]);
});

test('setOpacity changes the layer only, no redraw', async () => {
  const adapter = fakeAdapter(EUROPE);
  const layer = new T.TempLayer(adapter, stubSource(null), fakeOpen(), fakeDem(0), OPTS);
  layer.addTo(fakeMap(4));
  await settle();
  const count = adapter.images.length;
  layer.setOpacity(80);
  await settle();
  assert.deepEqual(adapter.opacities, [0.8]);
  assert.equal(adapter.images.length, count);
});

test('setPalette, setStep and setUnit redraw and remake the legend', async () => {
  const adapter = fakeAdapter(EUROPE);
  const layer = new T.TempLayer(adapter, stubSource(null), fakeOpen(), fakeDem(0), OPTS);
  layer.addTo(fakeMap(4));
  await settle();
  const legend = container.children[container.children.length - 1];
  assert.equal(legend.id, 'lv-temp-legend');
  assert.ok(legend.innerHTML.includes('°C'));
  layer.setUnit('F');
  await settle();
  assert.ok(legend.innerHTML.includes('°F'));
  assert.ok(legend.innerHTML.includes('>100<'), 'Fahrenheit ticks');
  let count = adapter.images.length;
  layer.setStep(0);
  await settle();
  assert.equal(adapter.images.length, count + 1);
  count = adapter.images.length;
  layer.setPalette([{ t: 0, color: '#000000' }, { t: 10, color: '#ffffff' }]);
  await settle();
  assert.equal(adapter.images.length, count + 1);
  // Still in Fahrenheit: 0 to 10 °C is 32 to 50 °F, one tick at 40.
  assert.ok(legend.innerHTML.includes('>40<') && !legend.innerHTML.includes('>100<'), 'ticks follow the palette');
});

test('remove clears the layer and the legend', async () => {
  const adapter = fakeAdapter(EUROPE);
  const map = fakeMap(4);
  const layer = new T.TempLayer(adapter, stubSource(null), fakeOpen(), fakeDem(0), OPTS);
  layer.addTo(map);
  await settle();
  const legend = container.children[container.children.length - 1];
  const count = adapter.images.length;
  layer.remove();
  map.fire('moveend');
  await settle();
  assert.equal(adapter.cleared, 1);
  assert.equal(legend.removed, true);
  assert.equal(adapter.images.length, count);
});

test('the API held back: tries again once it allows, then draws the view grid', async () => {
  const bounds = { west: 6.80, south: 45.80, east: 6.95, north: 45.87 };
  const fine = apiEntry(bounds);
  let calls = 0;
  const source = {
    blockedUntil: NOW - 1000, ttlMs: 3600e3,
    best: () => null,
    ensure() { calls++; return Promise.resolve(calls === 1 ? null : fine); },   // held back first, then the grid
    now: () => NOW,
  };
  const adapter = fakeAdapter(bounds);
  new T.TempLayer(adapter, source, fakeOpen(), fakeDem(1000), Object.assign({}, OPTS, { retryMinMs: 0 })).addTo(fakeMap(10));
  for (let i = 0; i < 5; i++) { await new Promise((r) => setTimeout(r, 5)); await settle(); }
  assert.equal(calls, 2);
  assert.deepEqual(colors(adapter.images[adapter.images.length - 1].image), [colorOf(11)]);
});

test('world view: a move that keeps the whole world in view draws nothing new', async () => {
  const adapter = fakeAdapter({ west: -170, south: -60, east: 170, north: 70 });
  const map = fakeMap(2);
  new T.TempLayer(adapter, stubSource(null), fakeOpen(), fakeDem(0), OPTS).addTo(map);
  await settle();
  const count = adapter.images.length;
  assert.ok(count > 0);
  adapter.bounds = { west: -120, south: -50, east: 150, north: 75 };
  map.fire('moveend');
  await settle();
  assert.equal(adapter.images.length, count);
});

test('world view: a move while the world is being drawn lets that drawing finish', async () => {
  const adapter = fakeAdapter({ west: -170, south: -60, east: 170, north: 70 });
  const map = fakeMap(2);
  new T.TempLayer(adapter, stubSource(null), fakeOpen(), fakeDem(0), OPTS).addTo(map);
  for (let i = 0; i < 10; i++) await tick();        // data in, the world drawing queued
  rafQueue.shift()();                                 // one slice of it
  adapter.bounds = { west: -120, south: -50, east: 150, north: 75 };
  map.fire('moveend');
  await settle();
  assert.equal(adapter.images.length, 1);
});
