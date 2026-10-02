// MicroarrAI admin — live log viewer, idle logout, page visibility.
// Loaded at the end of <body>, after Shiny's own scripts.
(function () {
  var MAX_LINES = 3000;
  var IDLE_MS = 30 * 60 * 1000;

  // ---- live log viewer -------------------------------------------------------
  function level(line) {
    if (/^(Warning: )?Error in |^Error[: ]/.test(line)) return 'err';
    if (/^Warning|^\[telemetry\] write failed/.test(line)) return 'warn';
    return '';
  }

  function applyFilter(view) {
    var q = view.dataset.q || '', lv = view.dataset.level || 'all';
    for (var el = view.firstElementChild; el; el = el.nextElementSibling) {
      var okLevel = lv === 'all' || el.classList.contains(lv);
      el.hidden = !(okLevel && (!q || el.textContent.toLowerCase().indexOf(q) !== -1));
    }
  }

  Shiny.addCustomMessageHandler('log_lines', function (m) {
    var view = document.getElementById(m.view);
    if (!view) return;
    if (m.reset) view.innerHTML = '';
    var atBottom = view.scrollTop + view.clientHeight >= view.scrollHeight - 40;
    var frag = document.createDocumentFragment();
    m.lines.forEach(function (line) {
      var div = document.createElement('div');
      div.className = 'logline ' + level(line);
      div.textContent = line;  // never innerHTML: logs can contain user-supplied text
      frag.appendChild(div);
    });
    view.appendChild(frag);
    while (view.childElementCount > MAX_LINES) view.removeChild(view.firstElementChild);
    applyFilter(view);
    if (atBottom || m.reset) view.scrollTop = view.scrollHeight;
  });

  document.addEventListener('input', function (e) {
    if (!e.target.matches('.log-search')) return;
    var view = document.getElementById(e.target.dataset.view);
    view.dataset.q = e.target.value.toLowerCase();
    applyFilter(view);
  });

  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.log-level button');
    if (!btn) return;
    var group = btn.parentElement;
    group.querySelectorAll('button').forEach(function (b) { b.classList.toggle('active', b === btn); });
    var view = document.getElementById(group.dataset.view);
    view.dataset.level = btn.dataset.level;
    applyFilter(view);
  });

  // ---- login: Enter submits ---------------------------------------------------
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && (e.target.id === 'user' || e.target.id === 'pass')) {
      Shiny.setInputValue('pass', document.getElementById('pass').value);
      Shiny.setInputValue('user', document.getElementById('user').value);
      document.getElementById('login').click();
    }
  });

  // ---- idle logout (30 min) -----------------------------------------------------
  var last = Date.now();
  ['mousemove', 'keydown', 'click', 'scroll'].forEach(function (ev) {
    document.addEventListener(ev, function () { last = Date.now(); }, { passive: true });
  });
  setInterval(function () {
    if (document.getElementById('logout') && Date.now() - last > IDLE_MS) {
      Shiny.setInputValue('idle_logout', Date.now(), { priority: 'event' });
      last = Date.now();
    }
  }, 60 * 1000);

  // ---- pause live polling while the browser tab is hidden -----------------------
  function sendVisibility() { Shiny.setInputValue('page_visible', !document.hidden); }
  document.addEventListener('visibilitychange', sendVisibility);
  $(document).on('shiny:connected', sendVisibility);
})();
