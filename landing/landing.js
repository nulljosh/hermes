// Landing behaviour: fade-up on scroll, and the live window in the hero. The window is the Mac app's own layout
// (app list, per-platform state dots, detail tabs) running on made-up sample apps. Nothing here is needed to read the page.
(function () {
  document.documentElement.classList.add('js');
  var still = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  var C = { live: 'var(--live)', pending: 'var(--pending)', bad: 'var(--bad)', idle: 'var(--idle)' };
  var APPS = [
    { name: 'Lantern', bundle: 'com.example.lantern', v: [['2.4.1', 'iOS', 'live'], ['2.7.0', 'macOS', 'live']], next: 'Nothing to do. Every platform is on sale.', health: 'live' },
    { name: 'Field Notes', bundle: 'com.example.fieldnotes', v: [['1.3.0', 'iOS', 'pending'], ['1.2.9', 'macOS', 'live']], next: 'Wait for App Store review outcome.', health: 'pending' },
    { name: 'Tidepool', bundle: 'com.example.tidepool', v: [['1.0.0', 'iOS', 'bad']], next: 'Resolve blocker: Guideline 2.1, answer App Review in Resolution Center.', health: 'bad' },
    { name: 'Quarry', bundle: 'com.example.quarry', v: [['3.0.0', 'iOS', 'idle'], ['3.0.0', 'macOS', 'idle']], next: 'Attach build 300 and submit for review.', health: 'idle' },
    { name: 'Mosaic', bundle: 'com.example.mosaic', v: [['5.2.0', 'iOS', 'live'], ['5.2.0', 'visionOS', 'pending']], next: 'Wait for visionOS review outcome.', health: 'pending' },
    { name: 'Orbit', bundle: 'com.example.orbit', v: [['0.9.2', 'macOS', 'live']], next: 'Nothing to do. Every platform is on sale.', health: 'live' }
  ];
  var STATE = { live: 'READY_FOR_DISTRIBUTION', pending: 'WAITING_FOR_REVIEW', bad: 'REJECTED', idle: 'PREPARE_FOR_SUBMISSION' };
  var TABS = ['Status', 'Versions', 'Builds', 'TestFlight', 'Reviews', 'Purchases'];

  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function dot(k) { var d = el('i', 'dot'); d.style.background = C[k]; return d; }
  function tile(app, size) { var t = el('span', 'tile', app.name[0]); t.style.width = t.style.height = size + 'px'; t.style.fontSize = Math.round(size * 0.45) + 'px'; return t; }
  function line(k, text) { var v = el('span', 'ver'); v.append(dot(k), el('span', null, text)); return v; }

  function list(main, query) {
    main.replaceChildren();
    var bar = el('div', 'bar'), refresh = el('button', null, '↻'), search = el('input', 'search');
    refresh.setAttribute('aria-label', 'Refresh');
    search.placeholder = 'Search Apps...'; search.value = query || ''; search.setAttribute('aria-label', 'Search apps');
    bar.append(refresh, search);
    var box = el('div', 'list');
    function fill() {
      box.replaceChildren();
      APPS.filter(function (a) { return a.name.toLowerCase().indexOf(search.value.toLowerCase()) >= 0; }).forEach(function (a) {
        var row = el('button', 'row'), text = el('span');
        text.append(el('b', null, a.name));
        a.v.forEach(function (v) { text.append(line(v[2], v[0] + ' on ' + v[1])); });
        row.append(tile(a, 48), text);
        row.addEventListener('click', function () { detail(main, a, 'Status'); });
        box.append(row);
      });
    }
    search.addEventListener('input', fill);
    refresh.addEventListener('click', fill);
    fill();
    main.append(bar, box);
    side(null);
  }

  function detail(main, a, tab) {
    main.replaceChildren();
    var bar = el('div', 'bar detail'), back = el('button', null, '‹'), tabs = el('div', 'tabs');
    back.setAttribute('aria-label', 'Back to apps');
    back.addEventListener('click', function () { list(main); });
    tabs.setAttribute('role', 'tablist');
    TABS.forEach(function (t) {
      var b = el('button', 'tab', t);
      b.setAttribute('role', 'tab'); b.setAttribute('aria-selected', t === tab);
      b.addEventListener('click', function () { detail(main, a, t); });
      tabs.append(b);
    });
    var name = el('b', null, a.name); name.style.fontSize = '16px';
    bar.append(back, tile(a, 32), name, tabs);
    main.append(bar, pane(a, tab));
    side(a);
  }

  function field(label, value) { var d = el('div'); d.append(el('small', null, label), el('span', null, value)); return d; }

  function pane(a, tab) {
    var p = el('div', 'pane');
    if (tab === 'Status') {
      var n = el('div', 'next'); n.append(dot(a.health), el('span', null, a.next));
      var v = a.v[0], links = el('div', 'links');
      ['App Store Connect', 'TestFlight', 'Review'].forEach(function (t) { var l = el('a', null, t); l.href = '#demo'; links.append(l); });
      p.append(n, field('App Store', v[0] + ' · ' + STATE[v[2]] + ' · ' + v[1]), field('Latest build', v[0] + ' · ' + v[0].replace(/\./g, '') + '0 · VALID'), links);
    } else {
      var rows = {
        Versions: a.v.map(function (v) { return [v[2], v[0], v[1] + ' · ' + STATE[v[2]]]; }),
        Builds: [['live', a.v[0][0].replace(/\./g, '') + '0', 'VALID · 2 days ago'], ['live', a.v[0][0].replace(/\./g, '') + '9', 'VALID · last week']],
        TestFlight: [[null, 'Internal', 'Internal group · 4 testers'], [null, 'Friends', 'Public link on · 31 testers']],
        Reviews: [[null, 'Does one thing well · 5', 'Exactly what I needed. Fast and quiet.'], [null, 'Sync please · 4', 'Love it, would pay for iCloud sync.']],
        Purchases: [['live', 'Full unlock', a.bundle + '.unlock · NON_CONSUMABLE · APPROVED']]
      }[tab];
      rows.forEach(function (r) {
        var row = el('div', 'row'), text = el('span');
        text.append(el('b', null, r[1]), el('span', 'ver', r[2]));
        if (r[0]) row.append(dot(r[0]));
        row.append(text);
        p.append(row);
      });
    }
    return p;
  }

  function side(a) {
    document.getElementById('w-title').textContent = a ? a.name : 'Welcome to Hermes';
    document.getElementById('w-sub').textContent = a ? a.bundle : 'Select an app to get started.';
  }

  function ready(fn) { if (document.readyState !== 'loading') fn(); else document.addEventListener('DOMContentLoaded', fn); }
  ready(function () {
    var main = document.getElementById('win-main');
    if (main) list(main);
    var items = Array.prototype.slice.call(document.querySelectorAll('.reveal'));
    if (still || !('IntersectionObserver' in window)) { items.forEach(function (e) { e.classList.add('in'); }); return; }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
    }, { rootMargin: '0px 0px -8% 0px' });
    items.forEach(function (e) { io.observe(e); });
  });
})();

