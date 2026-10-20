// Footer band: Hermes' things in a row (wing, caduceus, winged helmet, winged sandal, letter, purse), cut like a line
// engraving in plain 2D canvas. Faint rules run across the band; inside the glyphs they thicken, and thicken again on
// the edge facing away from the light, so the glyphs look cut into the page. Drawn once per size and theme.
// ponytail: was a WebGL shader with a drifting light; it rendered as a black box on iPhone, so it is static now.
(function () {
  var band = document.querySelector('.word-band'), canvas = band && band.querySelector('canvas');
  if (!canvas) return;

  var mark = new Image(), tints = {};
  mark.src = 'mark.svg';

  // Each glyph is drawn white on a 100 unit square.
  function feather(c, x, y, angle, len, w) { c.save(); c.translate(x, y); c.rotate(angle); c.beginPath(); c.ellipse(len / 2, 0, len / 2, w, 0, 0, 7); c.fill(); c.restore(); }
  function wing(c, x, y, s, flip) {
    c.save(); c.translate(x, y); c.scale(flip ? -s : s, s);
    for (var i = 0; i < 5; i++) feather(c, 0, 0, -0.15 - i * 0.3, 26 + 14 * Math.sin(1 + i * 0.5), 5.5);
    c.restore();
  }
  var GLYPHS = [
    function (c) { // wing: the brand mark itself
      if (!mark.complete || !mark.naturalWidth) return;
      var key = c.fillStyle;
      if (!tints[key]) {
        var t = document.createElement('canvas'); t.width = t.height = 400;
        var tc = t.getContext('2d'); tc.drawImage(mark, 0, 0, 400, 400);
        tc.globalCompositeOperation = 'source-in'; tc.fillStyle = key; tc.fillRect(0, 0, 400, 400);
        tints[key] = t;
      }
      c.drawImage(tints[key], -6, -6, 112, 112);
    },
    function (c) { // caduceus
      c.fillRect(46, 18, 8, 78); c.beginPath(); c.arc(50, 14, 7, 0, 7); c.fill();
      wing(c, 44, 22, 0.75, true); wing(c, 56, 22, 0.75, false);
      c.lineWidth = 6; c.lineCap = 'round';
      [1, -1].forEach(function (k) { c.beginPath(); for (var t = 0; t <= 1.001; t += 0.02) { var yy = 30 + t * 56, xx = 50 + k * 15 * Math.sin(t * Math.PI * 2.5) * (1 - t * 0.35); t ? c.lineTo(xx, yy) : c.moveTo(xx, yy); } c.stroke(); });
    },
    function (c) { // winged helmet
      c.beginPath(); c.ellipse(50, 72, 40, 9, 0, 0, 7); c.fill();
      c.beginPath(); c.ellipse(50, 70, 25, 32, 0, Math.PI, 0); c.fill();
      wing(c, 30, 54, 0.48, true); wing(c, 70, 54, 0.48, false);
    },
    function (c) { // winged sandal
      c.save(); c.translate(54, 72); c.rotate(-0.06);
      c.beginPath(); c.roundRect(-40, 0, 80, 14, 7); c.fill();
      c.lineWidth = 7;
      for (var i = 0; i < 3; i++) { c.beginPath(); c.ellipse(-8 + i * 16, 2, 20 - i * 4, 22 - i * 5, 0, Math.PI, 0); c.stroke(); }
      c.restore(); wing(c, 22, 64, 0.6, true);
    },
    function (c) { // letter
      c.beginPath(); c.roundRect(14, 28, 72, 48, 6); c.fill();
      c.globalCompositeOperation = 'destination-out'; c.lineWidth = 6; c.lineJoin = 'round';
      c.beginPath(); c.moveTo(18, 32); c.lineTo(50, 56); c.lineTo(82, 32); c.stroke();
      c.globalCompositeOperation = 'source-over';
    },
    function (c) { // purse
      c.beginPath(); c.ellipse(50, 64, 30, 26, 0, 0, 7); c.fill();
      c.beginPath(); c.moveTo(38, 40); c.lineTo(30, 20); c.lineTo(50, 30); c.lineTo(70, 20); c.lineTo(62, 40); c.closePath(); c.fill();
      c.fillRect(36, 38, 28, 6);
    }
  ];
  // Lays the glyphs out evenly across a w by h 2D context, in the given colour: one row, or two on a narrow band.
  function grid(w, h) {
    var n = GLYPHS.length, rows = w < h * 3 ? 2 : 1, per = Math.ceil(n / rows);
    return { rows: rows, per: per, cell: Math.min(h / rows * 0.86, w / per) };
  }
  function paint(c, w, h, colour) {
    var g = grid(w, h), gap = (w - g.cell * g.per) / g.per, rowH = h / g.rows;
    GLYPHS.forEach(function (draw, i) {
      var col = i % g.per, row = Math.floor(i / g.per);
      c.save(); c.translate(gap / 2 + col * (g.cell + gap), row * rowH + (rowH - g.cell) / 2 + rowH * 0.04); c.scale(g.cell / 100, g.cell / 100);
      c.fillStyle = c.strokeStyle = colour; draw(c); c.restore();
    });
  }

  var ctx = canvas.getContext('2d');
  if (!ctx) return;
  function layer(w, h) { var c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
  // Horizontal rules `t` px thick, one every `pitch` px, kept only where `mask` is drawn (everywhere when null).
  function rules(w, h, pitch, t, colour, mask) {
    var c = layer(w, h), x = c.getContext('2d');
    x.fillStyle = colour;
    for (var y = 0; y < h; y += pitch) x.fillRect(0, Math.round(y + (pitch - t) / 2), w, Math.max(1, Math.round(t)));
    if (mask) { x.globalCompositeOperation = 'destination-in'; x.drawImage(mask, 0, 0); }
    return c;
  }
  var drawnW = 0;
  function draw() {
    var dpr = Math.min(window.devicePixelRatio || 1, 2), w = Math.round(canvas.clientWidth * dpr), h = Math.round(canvas.clientHeight * dpr);
    if (!w || !h) return;
    drawnW = w; canvas.width = w; canvas.height = h;
    var colour = getComputedStyle(band).color, pitch = Math.min(5 * dpr, Math.max(3 * dpr, grid(w, h).cell / 22)), s = Math.max(2, h * 0.014);
    var glyphs = layer(w, h); paint(glyphs.getContext('2d'), w, h, '#fff');
    // the shadow side: glyph pixels whose neighbour down and right is outside the glyph (light from the top left)
    var shade = layer(w, h), sc = shade.getContext('2d');
    sc.drawImage(glyphs, 0, 0); sc.globalCompositeOperation = 'destination-out'; sc.drawImage(glyphs, -s, -s);
    ctx.globalAlpha = 0.28; ctx.drawImage(rules(w, h, pitch, dpr * 0.75, colour, null), 0, 0);
    ctx.globalAlpha = 1; ctx.drawImage(rules(w, h, pitch, pitch * 0.32, colour, glyphs), 0, 0);
    ctx.drawImage(rules(w, h, pitch, pitch * 0.6, colour, shade), 0, 0);
    // fade out toward the legal line
    var g = ctx.createLinearGradient(0, h * 0.88, 0, h);
    g.addColorStop(0, '#000'); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.globalCompositeOperation = 'destination-in'; ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = 'source-over';
  }
  band.classList.add('live');
  draw();
  mark.addEventListener('load', draw);
  // iOS fires resize as the toolbar slides; only a width change needs a redraw
  window.addEventListener('resize', function () { if (Math.round(canvas.clientWidth * Math.min(window.devicePixelRatio || 1, 2)) !== drawnW) draw(); });
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', draw);
})();
