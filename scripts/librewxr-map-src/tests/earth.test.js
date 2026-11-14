'use strict';
// Unit tests for glue-earth.js: the Sun's position, the day and night
// image, and the zoom at which the whole Earth fits in the map.
// Run: node --test scripts/librewxr-map-src/tests/*.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const E = require('../glue-earth.js');

function near(actual, expected, tol, what) {
  assert.ok(Math.abs(actual - expected) <= tol, what + ': ' + actual + ' not within ' + tol + ' of ' + expected);
}

test('subsolarPoint: declination and longitude at known instants', () => {
  // June solstice 2026 (21 June 08:24 UTC): the Sun over the Tropic of Cancer.
  near(E.subsolarPoint(new Date('2026-06-21T08:24:00Z')).lat, 23.44, 0.05, 'solstice declination');
  // March equinox 2026 (20 March 14:46 UTC): the Sun over the equator.
  near(E.subsolarPoint(new Date('2026-03-20T14:46:00Z')).lat, 0, 0.05, 'equinox declination');
  // 12:00 UTC on 3 November: equation of time +16.4 min, so solar noon came
  // 16 min early at Greenwich and the Sun is already 4.1 degrees west.
  near(E.subsolarPoint(new Date('2026-11-03T12:00:00Z')).lon, -4.1, 0.2, 'November longitude');
  // 18:00 UTC: a quarter turn later, 90 degrees further west.
  near(E.subsolarPoint(new Date('2026-11-03T18:00:00Z')).lon, -4.1 - 90, 0.2, 'evening longitude');
});

test('sunAltitude: overhead at the subsolar point, under the far side', () => {
  const sun = { lat: 10, lon: 40 };
  near(E.sunAltitude(sun, 10, 40), 90, 1e-5, 'subsolar point');
  near(E.sunAltitude(sun, -10, -140), -90, 1e-5, 'antisolar point');
  near(E.sunAltitude(sun, 0, 130), -E.sunAltitude(sun, 0, -50), 1e-9, 'symmetry');
});

test('wholeEarthZoom: flat, the world fills the height of the map', () => {
  // MapLibre zoom: 512 px for the whole world at zoom 0.
  near(E.wholeEarthZoom('flat', 800, 330), Math.log2(330 / 512), 1e-9, 'flat');
  near(E.wholeEarthZoom('flat', 800, 1024), 1, 1e-9, 'flat, tall map');
});

test('wholeEarthZoom: globe, the globe as seen fills GLOBE_FILL of the smaller side', () => {
  // MapLibre's camera (36.87 degree field of view) stands 1.5 map heights
  // from the point in the middle: a globe of radius R shows as a disc of
  // radius c R / sqrt(c^2 + 2 c R), c = 1.5 h. Its minimum zoom holds the
  // globe's radius, 512 2^z / 2 pi, whatever the latitude in view. The
  // model matches the radius measured on the page (157, 200.8 and 315.6 px
  // at zoom 1.5, 2 and 3 on a 266 px high map).
  for (const [w, h] of [[800, 266], [800, 330], [400, 600]]) {
    const z = E.wholeEarthZoom('globe', w, h);
    const R = 512 * Math.pow(2, z) / (2 * Math.PI), c = 1.5 * h;
    near(c * R / Math.sqrt(c * c + 2 * c * R), Math.min(w, h) * E.GLOBE_FILL / 2, 1e-6, `globe ${w}x${h}`);
  }
  near(E.globeApparentRadius(Math.log2(1.5 * 2 * Math.PI * 230.5 / 512 / 1.5), 266), 157, 0.5, 'measured');
});

test('wholeEarthZoom: no size, no zoom', () => {
  assert.equal(E.wholeEarthZoom('globe', 0, 300), null);
  assert.equal(E.wholeEarthZoom('flat', 800, 0), null);
});

test('sunLightPosition: MapLibre light (anchor map) pointing from the Sun', () => {
  // MapLibre turns the light position [r, azimuthal, polar] into the
  // direction (sin az sin p, -cos az sin p, -cos p) in its globe frame, where
  // a place is (sin lon cos lat, sin lat, cos lon cos lat). Checked on the
  // page: the lit rim of the atmosphere sits over the day side.
  const R = Math.PI / 180;
  for (const sun of [{ lat: 23.4, lon: -60 }, { lat: -11.6, lon: -132.7 }, { lat: 0, lon: 0 }, { lat: 5, lon: 179 }]) {
    const [r, az, p] = E.sunLightPosition(sun);
    assert.equal(r, 1);
    assert.ok(p >= 0 && p <= 180, 'polar within 0..180');
    const dir = [Math.sin(az * R) * Math.sin(p * R), -Math.cos(az * R) * Math.sin(p * R), -Math.cos(p * R)];
    const want = [Math.sin(sun.lon * R) * Math.cos(sun.lat * R), Math.sin(sun.lat * R), Math.cos(sun.lon * R) * Math.cos(sun.lat * R)];
    dir.forEach((v, i) => near(v, want[i], 1e-9, `sun ${sun.lat},${sun.lon} axis ${i}`));
  }
});

/** The whole world as one Web Mercator tile. */
const WORLD = { z: 0, x: 0, y: 0 };

/** Latitude and longitude of the centre of pixel (col, row) of a square Web Mercator world. */
function pixelLatLon(col, row, size) {
  const lon = (col + 0.5) / size * 360 - 180;
  const lat = Math.atan(Math.sinh(Math.PI * (1 - 2 * (row + 0.5) / size))) * 180 / Math.PI;
  return { lat, lon };
}

test('shadeTile: black over the night, as deep as asked, fading in over 18 degrees', () => {
  const sun = { lat: -11.6, lon: 30 }, size = 64, depth = 0.4;
  const img = E.shadeTile(sun, WORLD, size, depth, 0);
  assert.equal(img.length, size * size * 4);
  let night = 0, twilight = 0, day = 0;
  for (let row = 0; row < size; row++) {
    for (let col = 0; col < size; col++) {
      const { lat, lon } = pixelLatLon(col, row, size), h = E.sunAltitude(sun, lat, lon);
      const k = (row * size + col) * 4, a = img[k + 3] / 255;
      const want = h < 0 ? 1 - Math.pow(1 - depth, Math.min(1, -h / 18)) : 0;
      assert.ok(Math.abs(a - want) <= 1.5 / 255, `pixel ${col},${row} at ${h.toFixed(1)} degrees: alpha ${a} for ${want}`);
      if (h < 0) assert.deepEqual([img[k], img[k + 1], img[k + 2]], [0, 0, 0], 'black');
      if (h < -18) night++; else if (h < 0) twilight++; else day++;
    }
  }
  assert.ok(night > 100 && twilight > 100 && day > 100, `${night} ${twilight} ${day}`);
});

test('shadeTile: a light veil over the day, fading in over its first 18 degrees', () => {
  const sun = { lat: 20, lon: -100 }, size = 64, veil = 0.07;
  const img = E.shadeTile(sun, WORLD, size, 0.4, veil);
  for (let row = 0; row < size; row += 3) {
    for (let col = 0; col < size; col += 3) {
      const { lat, lon } = pixelLatLon(col, row, size), h = E.sunAltitude(sun, lat, lon);
      if (h <= 0) continue;
      const k = (row * size + col) * 4, a = img[k + 3] / 255;
      const want = 1 - Math.pow(1 - veil, Math.min(1, h / 18));
      assert.ok(Math.abs(a - want) <= 1.5 / 255, `pixel ${col},${row} at ${h.toFixed(1)} degrees`);
      if (img[k + 3] > 0) assert.deepEqual([img[k], img[k + 1], img[k + 2]], [255, 255, 255], 'white');
    }
  }
});

test('shadeTile: the middle rows of the world tile lie on the equator, the top one near 85 degrees north', () => {
  // Sun over the equator at 0: the antisolar point (equator, 180) is the deepest night.
  const sun = { lat: 0, lon: 0 }, size = 64;
  const img = E.shadeTile(sun, WORLD, size, 0.5, 0);
  const at = (col, row) => img[(row * size + col) * 4 + 3];
  assert.ok(Math.abs(at(size - 1, size / 2) - 0.5 * 255) <= 1, 'deep night at the equator, far east');
  assert.equal(at(size / 2, size / 2), 0, 'noon at the equator');
  assert.ok(pixelLatLon(0, 0, size).lat > 84, 'top row');
});

test('shadeTile: a tile of zoom 1 is a quarter of the world at twice the detail', () => {
  const sun = { lat: 8, lon: -40 }, world = E.shadeTile(sun, WORLD, 64, 0.4, 0.07);
  for (const [x, y] of [[0, 0], [1, 0], [0, 1], [1, 1]]) {
    const tile = E.shadeTile(sun, { z: 1, x, y }, 32, 0.4, 0.07);
    for (let r = 0; r < 32; r += 5) {
      for (let c = 0; c < 32; c += 5) {
        const k = (r * 32 + c) * 4, w = ((y * 32 + r) * 64 + x * 32 + c) * 4;
        assert.deepEqual([...tile.slice(k, k + 4)], [...world.slice(w, w + 4)], `tile ${x},${y} pixel ${c},${r}`);
      }
    }
  }
});

// === Coasts and borders (vendor/coast-borders.bin) ===
test('decodeLines reads the packed lines as GeoJSON, coasts and borders apart', () => {
  // "AWL1", 2 lines; coast (1,2) (1.5,2.25); border (-0.001,0) (0,0.001) (0.002,0.001)
  const bytes = Uint8Array.from([0x41, 0x57, 0x4c, 0x31, 2,
    0, 2, 0xd0, 0x0f, 0xa0, 0x1f, 0xe8, 0x07, 0xf4, 0x03,
    1, 3, 1, 0, 2, 2, 4, 0]);
  const fc = E.decodeLines(bytes.buffer);
  assert.equal(fc.type, 'FeatureCollection');
  assert.deepEqual(JSON.parse(JSON.stringify(fc.features.map((f) => [f.properties.kind, f.geometry.coordinates]))), [
    ['coast', [[1, 2], [1.5, 2.25]]],
    ['border', [[-0.001, 0], [0, 0.001], [0.002, 0.001]]]
  ]);
});

test('decodeLines refuses what is not a lines file', () => {
  assert.throws(() => E.decodeLines(Uint8Array.from([1, 2, 3, 4, 0]).buffer));
});

test('the widget file holds the coasts and borders of the whole Earth', () => {
  const buf = require('node:fs').readFileSync(require('node:path').join(__dirname, '../../../contents/ui/components/vendor/coast-borders.bin'));
  const fc = E.decodeLines(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.length));
  const kinds = { coast: 0, border: 0 };
  let minLat = 90, maxLat = -90, out = 0;
  for (const f of fc.features) {
    kinds[f.properties.kind]++;
    for (const [lon, lat] of f.geometry.coordinates) {
      if (lon < -180 || lon > 180) out++;
      minLat = Math.min(minLat, lat); maxLat = Math.max(maxLat, lat);
    }
  }
  assert.ok(kinds.coast > 1000 && kinds.border > 100, JSON.stringify(kinds));
  assert.equal(out, 0);
  assert.ok(minLat < -80 && maxLat > 80, minLat + ' ' + maxLat);
});

// ---- Space around the globe: sidereal time, the Moon, the camera ----

test('gmst: Greenwich mean sidereal time (Meeus example 12.a)', () => {
  // 1987 April 10, 0h UT: 13h10m46.3668s = 197.693195 degrees.
  near(E.gmst(new Date('1987-04-10T00:00:00Z')), 197.693195, 1e-4, 'GMST');
});

test('sublunarPoint: the Moon of Meeus example 47.a', () => {
  // 1992 April 12, 0h TD: right ascension 134.688470, declination 13.768368.
  const date = new Date('1992-04-12T00:00:00Z');
  const m = E.sublunarPoint(date);
  near(m.lat, 13.768, 0.4, 'declination');
  const lon = ((134.688470 - E.gmst(date) + 540) % 360) - 180;
  near(m.lon, lon, 0.5, 'longitude');
});

test('moonPhase: lit share of the Moon (Meeus example 48.a)', () => {
  const date = new Date('1992-04-12T00:00:00Z');
  near(E.moonPhase(E.subsolarPoint(date), E.sublunarPoint(date)), 0.6786, 0.02, 'illuminated fraction');
  // Same direction: new Moon; opposite: full.
  near(E.moonPhase({ lat: 0, lon: 0 }, { lat: 0, lon: 0 }), 0, 1e-9, 'new');
  near(E.moonPhase({ lat: 0, lon: 0 }, { lat: 0, lon: 180 }), 1, 1e-9, 'full');
});

test('camera: the point in the middle of the map faces the viewer', () => {
  const cam = E.camera(45, 10, 0, 0);
  const p = E.placeVector(45, 10);
  // Looking at the Earth: forward points from the camera to its centre.
  near(cam.fwd[0], -p[0], 1e-12, 'fwd x'); near(cam.fwd[1], -p[1], 1e-12, 'fwd y'); near(cam.fwd[2], -p[2], 1e-12, 'fwd z');
  // A direction straight away from the viewer projects to the middle.
  const mid = E.projectDir(cam, cam.fwd, 100);
  near(mid.x, 0, 1e-9, 'x'); near(mid.y, 0, 1e-9, 'y');
  // Towards the viewer: behind the camera, not drawn.
  assert.equal(E.projectDir(cam, p, 100), null);
});

test('camera: north up, east right, then turned by the bearing', () => {
  // Over the equator at 0, looking at the Earth along -z: a direction
  // past it and north is up the screen, one past it and east to the right.
  const cam = E.camera(0, 0, 0, 0);
  const north = E.projectDir(cam, [0, 1, -1], 100), east = E.projectDir(cam, [1, 0, -1], 100);
  assert.ok(north.y < 0 && Math.abs(north.x) < 1e-9, 'north up: ' + JSON.stringify(north));
  assert.ok(east.x > 0 && Math.abs(east.y) < 1e-9, 'east right: ' + JSON.stringify(east));
  // Bearing 90: east is up.
  const turned = E.camera(0, 0, 90, 0);
  const e2 = E.projectDir(turned, [1, 0, -1], 100);
  assert.ok(e2.y < 0 && Math.abs(e2.x) < 1e-9, 'east up at bearing 90: ' + JSON.stringify(e2));
});

test('starField: same stars for the same seed, spread over the sky', () => {
  const a = E.starField(2000, 7), b = E.starField(2000, 7);
  assert.deepEqual(a, b);
  let north = 0;
  for (let i = 0; i < 2000; i++) if (a[i * 3 + 1] > 0) north++;
  near(north / 2000, 0.5, 0.05, 'half in the northern sky');
});

test('earthRadiusPx: the globe radius that shows a given edge on screen', () => {
  // A sphere of radius R seen from f past its surface, focal length f:
  // edge = f R / sqrt(f^2 + 2 f R).
  const f = 700, R = 300, edge = f * R / Math.sqrt(f * f + 2 * f * R);
  near(E.earthRadiusPx(edge, f), R, 1e-6, 'radius');
});

test('projectPoint: the Earth seen by the camera, a Moon in front and behind', () => {
  const f = 700, R = 300, cam = E.camera(0, 0, 0, 0);
  const pos = E.cameraPosition(cam, E.placeVector(0, 0), R, f);
  // The camera stands f past the surface point in the middle.
  near(pos[2], R + f, 1e-9, 'camera distance');
  const centre = E.projectPoint(cam, pos, [0, 0, 0], f);
  near(centre.x, 0, 1e-9, 'centre x'); near(centre.y, 0, 1e-9, 'centre y');
  near(centre.dist, R + f, 1e-9, 'centre distance');
  // A Moon at 2.4 radii towards the viewer, then away from it.
  const front = E.projectPoint(cam, pos, [0, 0, 2.4 * R], f);
  const back = E.projectPoint(cam, pos, [0, 0, -2.4 * R], f);
  assert.ok(front.dist < centre.dist && back.dist > centre.dist);
  // East of the middle, on the Earth's side plane: right of the globe.
  const east = E.projectPoint(cam, pos, [2.4 * R, 0, 0], f);
  assert.ok(east.x > 0 && Math.abs(east.y) < 1e-9);
  // Behind the camera: null.
  assert.equal(E.projectPoint(cam, pos, [0, 0, 2 * (R + f)], f), null);
});

// A 4 x 2 texture: longitude -180..-90 red, -90..0 green, 0..90 blue,
// 90..180 white; both rows the same.
function stripes() {
  const cols = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255]], data = new Uint8ClampedArray(4 * 2 * 4);
  for (let y = 0; y < 2; y++) for (let x = 0; x < 4; x++) data.set([...cols[x], 255], (y * 4 + x) * 4);
  return { width: 4, height: 2, data };
}
function px(out, size, x, y) { const k = (y * size + x) * 4; return Array.from(out.slice(k, k + 4)); }

test('renderMoon: seen from the Earth, lit from behind the viewer: full, its near side in the middle', () => {
  // Camera looking along -z at a Moon on +z... the Moon at direction (0,0,-1)
  // from the Earth, the camera between them looking at it.
  const cam = { fwd: [0, 0, -1], right: [1, 0, 0], up: [0, 1, 0] };
  const size = 21, out = new Uint8ClampedArray(size * size * 4);
  E.renderMoon(out, size, 10, cam, [0, 0, -1], [0, 0, 1], stripes(), 1);
  const mid = px(out, size, 10, 10);
  // The near side (longitude 0, blue/green border): just right of it east, blue.
  assert.ok(mid[3] === 255, 'opaque middle');
  const east = px(out, size, 14, 10), west = px(out, size, 6, 10);
  assert.ok(east[2] > 150 && east[0] < 50, 'east of the near side blue: ' + east);
  assert.ok(west[1] > 150 && west[0] < 50, 'west of it green: ' + west);
  // Outside the disc: transparent.
  assert.equal(px(out, size, 0, 0)[3], 0);
});

test('renderMoon: the Sun behind the Moon leaves its face dark, faded by `alpha`', () => {
  const cam = { fwd: [0, 0, -1], right: [1, 0, 0], up: [0, 1, 0] };
  const size = 21, out = new Uint8ClampedArray(size * size * 4);
  E.renderMoon(out, size, 10, cam, [0, 0, -1], [0, 0, -1], stripes(), 0.5);
  const mid = px(out, size, 10, 10);
  assert.ok(mid[0] + mid[1] + mid[2] < 60, 'dark: ' + mid);
  assert.ok(Math.abs(mid[3] - 128) <= 1, 'half faded: ' + mid[3]);
  // Lit from the right (east): the right half bright, the left dark.
  E.renderMoon(out, size, 10, cam, [0, 0, -1], [1, 0, 0], stripes(), 1);
  const r = px(out, size, 17, 10), l = px(out, size, 3, 10);
  assert.ok(r[0] + r[1] + r[2] > l[0] + l[1] + l[2] + 100, 'lit right: ' + r + ' vs ' + l);
});
