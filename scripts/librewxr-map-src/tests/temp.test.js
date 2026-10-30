'use strict';
// Unit tests for the temperature math of the radar map (glue-temp.js).
// Run: node --test scripts/librewxr-map-src/tests/*.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const T = require('../glue-temp.js');

test('parsePalette: signed and decimal temperatures, 2 to 12 points', () => {
  assert.deepEqual(T.parsePalette('-12.5:2166AC,30:b2182b'), [{ t: -12.5, color: '#2166ac' }, { t: 30, color: '#b2182b' }]);
  assert.equal(T.parsePalette('10:ffffff'), null);                 // one point
  assert.equal(T.parsePalette('10:ffffff,5:000000'), null);       // not ascending
  assert.equal(T.parsePalette('0:fff,10:000000'), null);          // short color
  assert.equal(T.parsePalette(Array(13).fill(0).map((_, i) => i + ':000000').join(',')), null);
  assert.equal(T.parsePalette(''), null);
});

test('formatPalette round-trips DEFAULT_STOPS', () => {
  assert.deepEqual(T.parsePalette(T.formatPalette(T.DEFAULT_STOPS)), T.DEFAULT_STOPS);
});

test('colorAt: ends held, linear in between', () => {
  const s = [{ t: 0, color: '#000000' }, { t: 10, color: '#ff0000' }];
  assert.deepEqual(T.colorAt(s, -5), [0, 0, 0]);
  assert.deepEqual(T.colorAt(s, 5), [128, 0, 0]);     // rounded
  assert.deepEqual(T.colorAt(s, 99), [255, 0, 0]);
});

test('bandCenterC: the middle of the band, in the unit of the widget', () => {
  assert.equal(T.bandCenterC(12, 5, 'C'), 12.5);
  assert.equal(T.bandCenterC(-0.1, 5, 'C'), -2.5);
  assert.equal(T.bandCenterC(12, 0, 'C'), 12);
  // 12 °C = 53.6 °F, band 50-55 °F, middle 52.5 °F = 11.388... °C
  assert.ok(Math.abs(T.bandCenterC(12, 5, 'F') - 11.3889) < 1e-3);
});

test('buildLut and lutIndex: banded colors, clamped ends', () => {
  const lut = T.buildLut(T.DEFAULT_STOPS, 5, 'C');
  const at = (t) => Array.from(lut.slice(T.lutIndex(t) * 3, T.lutIndex(t) * 3 + 3));
  assert.deepEqual(at(10.1), at(14.9));
  assert.notDeepEqual(at(14.9), at(15.1));
  assert.equal(T.lutIndex(-200), 0);
  assert.equal(T.lutIndex(200), T.LUT_SIZE - 1);
});

test('legendTicks: every 10 °C over the palette, every 20 °F in Fahrenheit', () => {
  assert.deepEqual(T.legendTicks(T.DEFAULT_STOPS, 'C').map((k) => k.label), ['-40', '-30', '-20', '-10', '0', '10', '20', '30', '40']);
  assert.equal(T.legendTicks(T.DEFAULT_STOPS, 'C')[4].pos, 0.5);
  assert.deepEqual(T.legendTicks(T.DEFAULT_STOPS, 'F').map((k) => k.label), ['-40', '-20', '0', '20', '40', '60', '80', '100']);
});

test('normStep, normOpacity, normUnit', () => {
  assert.equal(T.normStep('2'), 2); assert.equal(T.normStep(3), 5); assert.equal(T.normStep('0'), 0);
  assert.equal(T.normOpacity('5'), 10); assert.equal(T.normOpacity('x'), 45); assert.equal(T.normOpacity(100), 100);
  assert.equal(T.normUnit('F'), 'F'); assert.equal(T.normUnit('K'), 'C');
});
