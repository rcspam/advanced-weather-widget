// === LOOP SPIKE (test page only, injected by build-test.py after the wind level spike) ===
// Looping or not. With the loop, the first picture follows the last at the
// pace of the others (the Player held the last one 1.5 s), and the step
// buttons go round too: past the last picture to the first, before the
// first to the last. The first two pictures are unpacked ahead while the
// last ones play. Without the loop, the play stops on the last picture,
// and play from there starts again at the first. window.animSetLoop(on),
// animState().loop. Esc in the page is told to the QML side (its help
// panel): the map takes the keys once clicked.
var LoopSpike = (function () {
  'use strict';
  var P = WidgetAnim.Player.prototype, F = WidgetAnim.Frames.prototype;
  var loop = true;

  var gridAt = F.gridAt;
  F.gridAt = function (pos) {
    if (pos > this.times.length - 3) { this._warm(0); this._warm(1); }
    return gridAt.call(this, pos);
  };

  /** The first frame read going dir (1 from the start, -1 from the end) that passes ok(i); -1 when none. */
  function firstFrom(frames, dir, ok) {
    var n = frames.times.length;
    for (var i = dir > 0 ? 0 : n - 1; i >= 0 && i < n; i += dir) if (frames.ready(i) && ok(i)) return i;
    return -1;
  }

  var tick = P._tick;
  P._tick = function () {
    var last = this.frames.times.length - 1;
    if (!this.playing || this.target !== null || this.index < last - 1e-6 || !this._drawn()) return tick.call(this);
    if (!loop) { this.play(false); return; }
    var first = this.nextReady(last);
    if (first >= 0 && first !== last && this.now() >= this.dueAt) this.show(first);
  };

  var play = P.play;
  P.play = function (on) {
    // At the end, without the loop: from the start again.
    if (on && !loop && this.target === null && this.index >= this.frames.times.length - 1 - 1e-6) {
      var first = this.nextReady(this.frames.times.length - 1);
      if (first >= 0) this.target = first;
    }
    play.call(this, on);
  };

  // The steps go round with the loop.
  var step = P.step;
  P.step = function (dir, perFrame) {
    var b = this._base(), last = this.frames.times.length - 1, to = -1;
    if (loop && dir > 0 && b >= last - 1e-6) to = firstFrom(this.frames, 1, function () { return true; });
    else if (loop && dir < 0 && b <= 1e-6) to = firstFrom(this.frames, -1, function () { return true; });
    if (to < 0) return step.call(this, dir, perFrame);
    this.play(false);
    this.seek(to);
  };
  var stepFile = P.stepFile;
  P.stepFile = function (dir) {
    var target = this.target, index = this.index, self = this;
    stepFile.call(this, dir);
    if (!loop || this.target !== target || this.index !== index) return;
    var to = firstFrom(this.frames, dir, function (i) { return self.frames.isFile(i); });
    if (to < 0) return;
    this.play(false);
    this.seek(to);
  };

  window.animSetLoop = function (on) { loop = !!on; return loop; };
  var state = window.animState;
  window.animState = function () {
    var s = state();
    if (s) s.loop = loop;
    return s;
  };

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') console.log('[keys] escape');
  }, true);

  return {};
})();
