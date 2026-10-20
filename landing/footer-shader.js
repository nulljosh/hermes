// Footer band: Hermes' things in a row (wing, caduceus, winged helmet, winged sandal, letter, purse), shaded like a
// line engraving. Horizontal rules run across the band; inside the glyphs they thicken on the side facing away from a
// light that drifts slowly, so they look cut into the page. Colours come from the live theme. It runs only while on
// screen and holds one still frame under reduced motion. Without WebGL the glyphs are drawn flat in the accent.
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
  // Lays the glyphs out evenly across a w by h 2D context, in the given colour.
  function paint(c, w, h, colour) {
    var n = GLYPHS.length, cell = Math.min(h * 0.86, w / n), gap = (w - cell * n) / n;
    c.fillStyle = c.strokeStyle = colour;
    GLYPHS.forEach(function (g, i) {
      c.save(); c.translate(gap / 2 + i * (cell + gap), (h - cell) / 2 + h * 0.04); c.scale(cell / 100, cell / 100);
      c.fillStyle = c.strokeStyle = colour; g(c); c.restore();
    });
  }

  var gl = canvas.getContext('webgl', { antialias: false, premultipliedAlpha: false });
  if (!gl || !gl.getExtension('OES_standard_derivatives')) {
    var flat = canvas.getContext('2d');
    if (!flat) return;
    band.classList.add('live');
    var drawFlat = function () {
      canvas.width = canvas.clientWidth * 2; canvas.height = canvas.clientHeight * 2;
      paint(flat, canvas.width, canvas.height, getComputedStyle(band).color);
    };
    drawFlat(); window.addEventListener('resize', drawFlat); mark.addEventListener('load', drawFlat);
    return;
  }

  var VERT = 'attribute vec2 p; varying vec2 uv; void main(){ uv = p * 0.5 + 0.5; gl_Position = vec4(p, 0.0, 1.0); }';
  var FRAG = [
    '#extension GL_OES_standard_derivatives : enable',
    'precision mediump float;',
    'varying vec2 uv;',
    'uniform sampler2D word; uniform sampler2D soft;',
    'uniform vec2 res; uniform float time; uniform vec3 bg; uniform vec3 ink; uniform float pitch;',
    'void main(){',
    '  vec2 t = vec2(uv.x, 1.0 - uv.y);',
    '  float m = texture2D(word, t).r;',
    // the blurred letters are a height field; its slope against a drifting light gives the shading
    '  vec2 e = vec2(2.0) / res;',
    '  float hx = texture2D(soft, t + vec2(e.x, 0.0)).r - texture2D(soft, t - vec2(e.x, 0.0)).r;',
    '  float hy = texture2D(soft, t + vec2(0.0, e.y)).r - texture2D(soft, t - vec2(0.0, e.y)).r;',
    '  float a = 2.4 + 0.5 * sin(time * 0.25);',
    '  float lit = clamp(0.5 + 6.0 * (hx * cos(a) + hy * sin(a)), 0.0, 1.0);',
    // engraving: one rule every `pitch` px; the darker the spot, the thicker the rule
    '  float v = gl_FragCoord.y / pitch;',
    '  float d = abs(fract(v) - 0.5);',
    '  float w = fwidth(v);',
    '  float dark = mix(0.05, mix(0.48, 0.12, lit), m);',
    '  float line = 1.0 - smoothstep(dark * 0.5 - w, dark * 0.5 + w, d);',
    '  float edge = smoothstep(0.35, 0.5, m) - smoothstep(0.5, 0.65, m);',
    '  float fade = smoothstep(0.0, 0.25, uv.y);',
    '  float k = clamp(line * mix(0.35, 0.95, m) + edge * 0.6, 0.0, 1.0) * fade;',
    '  gl_FragColor = vec4(mix(bg, ink, k), 1.0);',
    '}'
  ].join('\n');

  function shader(type, src) {
    var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s);
    return gl.getShaderParameter(s, gl.COMPILE_STATUS) ? s : null;
  }
  var vs = shader(gl.VERTEX_SHADER, VERT), fs = shader(gl.FRAGMENT_SHADER, FRAG);
  if (!vs || !fs) return;
  var prog = gl.createProgram(); gl.attachShader(prog, vs); gl.attachShader(prog, fs); gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return;
  gl.useProgram(prog);

  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  var loc = gl.getAttribLocation(prog, 'p');
  gl.enableVertexAttribArray(loc); gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
  var u = {};
  ['res', 'time', 'bg', 'ink', 'pitch', 'word', 'soft'].forEach(function (n) { u[n] = gl.getUniformLocation(prog, n); });
  gl.uniform1i(u.word, 0); gl.uniform1i(u.soft, 1);

  function texture(unit) {
    var t = gl.createTexture(); gl.activeTexture(gl.TEXTURE0 + unit); gl.bindTexture(gl.TEXTURE_2D, t);
    [gl.TEXTURE_WRAP_S, gl.TEXTURE_WRAP_T].forEach(function (k) { gl.texParameteri(gl.TEXTURE_2D, k, gl.CLAMP_TO_EDGE); });
    [gl.TEXTURE_MIN_FILTER, gl.TEXTURE_MAG_FILTER].forEach(function (k) { gl.texParameteri(gl.TEXTURE_2D, k, gl.LINEAR); });
    return t;
  }
  var texWord = texture(0), texSoft = texture(1);

  // The glyphs are drawn once per size into two 2D canvases: sharp, and blurred for the shading.
  function bake() {
    var w = canvas.width, h = canvas.height, sharp = document.createElement('canvas'), blur = document.createElement('canvas');
    sharp.width = blur.width = w; sharp.height = blur.height = h;
    var c = sharp.getContext('2d');
    c.fillStyle = '#000'; c.fillRect(0, 0, w, h);
    paint(c, w, h, '#fff');
    var b = blur.getContext('2d');
    b.filter = 'blur(' + Math.max(2, h * 0.025) + 'px)'; b.drawImage(sharp, 0, 0);
    gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, texWord);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, sharp);
    gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, texSoft);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, blur);
  }

  function rgb(prop) {
    var probe = document.createElement('i');
    probe.style.color = 'var(' + prop + ')'; document.body.appendChild(probe);
    var m = getComputedStyle(probe).color.match(/[\d.]+/g); probe.remove();
    return m ? [m[0] / 255, m[1] / 255, m[2] / 255] : [1, 1, 1];
  }
  var dpr = 1, bgc, inkc;
  function size() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(canvas.clientWidth * dpr);
    canvas.height = Math.round(canvas.clientHeight * dpr);
    gl.viewport(0, 0, canvas.width, canvas.height);
    bake();
  }
  function colours() { bgc = rgb('--bg'); inkc = rgb('--accent'); }
  function draw(t) {
    gl.uniform2f(u.res, canvas.width, canvas.height);
    gl.uniform1f(u.time, t / 1000);
    gl.uniform3fv(u.bg, bgc); gl.uniform3fv(u.ink, inkc);
    gl.uniform1f(u.pitch, 5 * dpr); // one rule every 5 css px
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  var still = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var onScreen = false, frame = 0;
  function loop(t) { draw(t); frame = onScreen ? requestAnimationFrame(loop) : 0; }
  function kick() { if (!still && onScreen && !frame) frame = requestAnimationFrame(loop); }
  band.classList.add('live');
  colours(); size(); draw(0);
  mark.addEventListener('load', function () { size(); draw(performance.now()); });
  window.addEventListener('resize', function () { size(); draw(performance.now()); });
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () { colours(); draw(performance.now()); });
  new IntersectionObserver(function (e) { onScreen = e[0].isIntersecting; kick(); }).observe(canvas);
})();
