// Footer wordmark: a giant "Hermes" in Hermes Sans, shaded like a line engraving. Horizontal rules run across the
// band; inside the letters they thicken on the side facing away from a light that drifts slowly, so the word looks cut
// into the page. Colours come from the live theme. It runs only while on screen and holds one still frame under
// reduced motion. Without WebGL the plain word stays.
(function () {
  var band = document.querySelector('.word-band'), canvas = band && band.querySelector('canvas');
  var gl = canvas && canvas.getContext('webgl', { antialias: false, premultipliedAlpha: false });
  if (!gl || !gl.getExtension('OES_standard_derivatives')) return;

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

  // The headline's family, Hermes Sans
  var family = getComputedStyle(document.querySelector('.hero h1') || document.body).fontFamily;
  var WORD = 'Hermes';

  // The word is drawn once per size into two 2D canvases: sharp, and blurred for the shading.
  function bake() {
    var w = canvas.width, h = canvas.height, sharp = document.createElement('canvas'), blur = document.createElement('canvas');
    sharp.width = blur.width = w; sharp.height = blur.height = h;
    var c = sharp.getContext('2d');
    c.fillStyle = '#000'; c.fillRect(0, 0, w, h);
    var size = h * 1.05;
    c.font = '700 ' + size + 'px ' + family;
    var ink = c.measureText(WORD), fit = (w * 0.9) / (ink.actualBoundingBoxLeft + ink.actualBoundingBoxRight || ink.width);
    if (fit < 1) { size *= fit; c.font = '700 ' + size + 'px ' + family; }
    c.fillStyle = '#fff'; c.textAlign = 'center'; c.textBaseline = 'alphabetic';
    c.fillText(WORD, w / 2, h * 0.86);
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
  if (document.fonts) document.fonts.ready.then(function () { size(); draw(performance.now()); });
  window.addEventListener('resize', function () { size(); draw(performance.now()); });
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function () { colours(); draw(performance.now()); });
  new IntersectionObserver(function (e) { onScreen = e[0].isIntersecting; kick(); }).observe(canvas);
})();
