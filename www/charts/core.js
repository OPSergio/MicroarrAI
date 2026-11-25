/* ===========================================================================
 * charts/core.js — native SVG/Canvas charts for MicroarrAI (no ggiraph, no rgl)
 *
 * R sends a spec with renderChart() (R/utils/charts.R); this file owns the
 * Shiny output binding, the shared tooltip, the legend, the PNG/SVG export and
 * the friendly empty/error state. Each chart type registers a draw function in
 * MaiCharts.types (charts/plots2d.js, charts/scatter3d.js).
 * =========================================================================== */
(function () {
  const NS = "http://www.w3.org/2000/svg";
  const FONT = "'Space Grotesk', 'Inter', system-ui, sans-serif";
  const INK = "#191c32", MUTED = "#6b7280", GRID = "#e9ecf1";

  // Shiny serialises length-1 vectors as scalars and data frames as columns
  const arr = v => (Array.isArray(v) ? v : v == null ? [] : [v]);
  const rows = cols => {
    const keys = Object.keys(cols || {}), n = keys.length ? arr(cols[keys[0]]).length : 0;
    return Array.from({ length: n }, (_, i) => Object.fromEntries(keys.map(k => [k, arr(cols[k])[i]])));
  };
  const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const fmt = v => (v == null || !isFinite(v) ? "n/a" : Math.abs(v) >= 100 ? v.toFixed(0) : Math.abs(v) >= 1 ? v.toFixed(2) : v.toPrecision(3));
  // Axis ticks: as short as the step allows (10, 2.5, 0.05), English digits
  const tickFmt = v => (Math.abs(v) < 1e-12 ? "0" : (+v.toPrecision(4)).toLocaleString("en-US", { maximumFractionDigits: 4 }));
  const num = v => Number(v).toLocaleString("en-US");

  function el(tag, attrs = {}, parent) {
    const e = document.createElementNS(NS, tag);
    for (const [k, v] of Object.entries(attrs)) if (v != null) e.setAttribute(k, v);
    if (parent) parent.appendChild(e);
    return e;
  }
  function svg(host, w, h) {
    return el("svg", { width: w, height: h, viewBox: `0 0 ${w} ${h}`, "font-family": FONT, class: "mai-svg" }, host);
  }
  function text(parent, x, y, str, attrs = {}) {
    const t = el("text", { x, y, fill: INK, "font-size": 12, ...attrs }, parent);
    t.textContent = str;
    return t;
  }

  // Nice ticks for a linear axis
  function ticks(lo, hi, n = 5) {
    const span = hi - lo || 1, step0 = span / n, mag = 10 ** Math.floor(Math.log10(step0));
    const step = [1, 2, 2.5, 5, 10].map(m => m * mag).find(s => span / s <= n) || mag * 10;
    const out = [];
    for (let v = Math.ceil(lo / step) * step; v <= hi + step * 1e-9; v += step) out.push(+v.toFixed(10));
    return out;
  }
  function scale(d0, d1, r0, r1) {
    const f = v => r0 + ((v - d0) / (d1 - d0 || 1)) * (r1 - r0);
    f.domain = [d0, d1];
    return f;
  }
  function extent(vals, pad = 0.06) {
    const v = vals.filter(Number.isFinite);
    let lo = Math.min(...v), hi = Math.max(...v);
    if (!v.length) { lo = 0; hi = 1; }
    if (lo === hi) { lo -= 1; hi += 1; }
    const p = (hi - lo) * pad;
    return [lo - p, hi + p];
  }

  // Axes with light grid; returns nothing, draws into g
  function axes(g, x, y, iw, ih, xlab, ylab) {
    ticks(...x.domain).forEach(v => {
      el("line", { x1: x(v), x2: x(v), y1: 0, y2: ih, stroke: GRID }, g);
      text(g, x(v), ih + 16, tickFmt(v), { "text-anchor": "middle", fill: MUTED, "font-size": 11 });
    });
    ticks(...y.domain).forEach(v => {
      el("line", { x1: 0, x2: iw, y1: y(v), y2: y(v), stroke: GRID }, g);
      text(g, -8, y(v) + 4, tickFmt(v), { "text-anchor": "end", fill: MUTED, "font-size": 11 });
    });
    el("rect", { x: 0, y: 0, width: iw, height: ih, fill: "none", stroke: "#d5dae2" }, g);
    if (xlab) text(g, iw / 2, ih + 36, xlab, { "text-anchor": "middle", "font-weight": 600 });
    if (ylab) text(g, -ih / 2, -44, ylab, { transform: "rotate(-90)", "text-anchor": "middle", "font-weight": 600 });
  }

  // One tooltip for the whole page. lines[0] is the title.
  let tipEl;
  const tip = {
    show(e, lines) {
      if (!tipEl) { tipEl = document.createElement("div"); tipEl.className = "mai-tip"; document.body.appendChild(tipEl); }
      const ls = arr(lines).flatMap(l => String(l).split("\n"));
      tipEl.innerHTML = `<b>${esc(ls[0])}</b>` + ls.slice(1).map(l => `<div>${esc(l)}</div>`).join("");
      tipEl.style.opacity = 1;
      const r = tipEl.getBoundingClientRect();
      let left = e.pageX + 14, top = e.pageY + 14;
      if (e.clientX + 14 + r.width > innerWidth - 8) left = e.pageX - r.width - 14;
      if (e.clientY + 14 + r.height > innerHeight - 8) top = e.pageY - r.height - 14;
      tipEl.style.left = left + "px"; tipEl.style.top = top + "px";
    },
    hide() { if (tipEl) tipEl.style.opacity = 0; }
  };

  // Legend chips: hover highlights a group, click hides/shows it
  function legend(host, items, state, redraw, title) {
    if (!items.length) return;
    const box = document.createElement("div");
    box.className = "mai-legend";
    box.innerHTML = (title ? `<span class="mai-legend-title">${esc(title)}</span>` : "") +
      items.map(it => `<button type="button" data-k="${esc(it.key)}" class="${state.hidden.has(it.key) ? "off" : ""}">` +
        `<i style="background:${it.color}"></i>${esc(it.label ?? it.key)}</button>`).join("");
    box.addEventListener("click", e => {
      const b = e.target.closest("button"); if (!b) return;
      const k = b.dataset.k;
      state.hidden.has(k) ? state.hidden.delete(k) : state.hidden.add(k);
      redraw();
    });
    box.addEventListener("mouseover", e => { const b = e.target.closest("button"); state.focus = b ? b.dataset.k : null; state.onFocus && state.onFocus(); });
    box.addEventListener("mouseleave", () => { state.focus = null; state.onFocus && state.onFocus(); });
    host.appendChild(box);
  }

  // Group colours: R sends them; anything missing falls back to this palette
  const PALETTE = ["#1F78B4", "#18BC9C", "#E31A1C", "#FF7F00", "#6A3D9A", "#2C3E50", "#FB9A99", "#B2DF8A", "#CCBE93", "#A6CEE3", "#FDBF6F", "#CAB2D6"];
  function colorMap(groups, given) {
    const m = {};
    arr(groups).forEach((g, i) => { m[g] = (given && given[g]) || PALETTE[i % PALETTE.length]; });
    return m;
  }

  // Export the current chart as PNG (canvas or rendered SVG) or SVG
  function download(name, blob) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob); a.download = name; a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }
  function exportChart(host, kind) {
    const base = (host.id || "chart").replace(/[^\w-]/g, "_");
    const canvas = host.querySelector("canvas"), s = host.querySelector("svg.mai-svg");
    if (kind === "svg" && s) {
      const clone = s.cloneNode(true); clone.setAttribute("xmlns", NS);
      return download(base + ".svg", new Blob([clone.outerHTML], { type: "image/svg+xml" }));
    }
    if (canvas) return canvas.toBlob(b => download(base + ".png", b));
    if (!s) return;
    const w = +s.getAttribute("width"), h = +s.getAttribute("height"), k = 2;
    const img = new Image(), c = document.createElement("canvas");
    c.width = w * k; c.height = h * k;
    const clone = s.cloneNode(true); clone.setAttribute("xmlns", NS);
    img.onload = () => {
      const ctx = c.getContext("2d"); ctx.fillStyle = "#fff"; ctx.fillRect(0, 0, c.width, c.height);
      ctx.drawImage(img, 0, 0, c.width, c.height); c.toBlob(b => download(base + ".png", b));
    };
    img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(clone.outerHTML);
  }

  function message(host, msg, kind = "info") {
    host.innerHTML = `<div class="mai-chart-msg ${kind}"><span>${kind === "error" ? "!" : "i"}</span><p>${esc(msg)}</p></div>`;
  }

  // Draw spec into host, rebuilding the frame (title, toolbar, body, legend)
  function draw(host) {
    const spec = host._spec;
    tip.hide();
    if (!spec) { host.innerHTML = ""; return; }
    if (spec.type === "message") return message(host, spec.text, spec.kind);
    const fn = MaiCharts.types[spec.type];
    if (!fn) return message(host, "Unknown chart type: " + spec.type, "error");
    host.innerHTML = "";
    if (spec.title || spec.subtitle) {
      const h = document.createElement("div"); h.className = "mai-chart-head";
      h.innerHTML = (spec.title ? `<div class="t">${esc(spec.title)}</div>` : "") + (spec.subtitle ? `<div class="s">${esc(spec.subtitle)}</div>` : "");
      host.appendChild(h);
    }
    const bar = document.createElement("div"); bar.className = "mai-chart-tools";
    bar.innerHTML = `<button type="button" data-x="png" title="Download PNG">PNG</button>` + (spec.type === "scatter3d" ? "" : `<button type="button" data-x="svg" title="Download SVG">SVG</button>`);
    bar.addEventListener("click", e => { const b = e.target.closest("button"); if (b) exportChart(host, b.dataset.x); });
    host.appendChild(bar);
    const body = document.createElement("div"); body.className = "mai-chart-body";
    host.appendChild(body);
    host._state = host._state || { hidden: new Set(), focus: null };
    try {
      fn(body, spec, host._state, () => draw(host), host);
    } catch (err) {
      console.error(err);
      message(host, "This chart could not be drawn: " + err.message, "error");
    }
  }

  const MaiCharts = { types: {}, NS, INK, MUTED, GRID, FONT, arr, rows, esc, fmt, tickFmt, num, el, svg, text, ticks, scale, extent, axes, tip, legend, colorMap };
  window.MaiCharts = MaiCharts;

  // Body size: the output's height minus head/legend, the host's width
  MaiCharts.size = (body, host, legendRows = 1) => {
    const head = host.querySelector(".mai-chart-head");
    const h = Math.max(220, host.clientHeight - (head ? head.offsetHeight : 0) - 40 * legendRows);
    return { w: Math.max(260, body.clientWidth || host.clientWidth), h };
  };

  if (!window.Shiny) return;
  const binding = new Shiny.OutputBinding();
  $.extend(binding, {
    find: scope => $(scope).find(".mai-chart"),
    renderValue(host, spec) {
      if (host._spec && spec && host._spec.type !== spec.type) host._state = null;
      if (spec && spec.keepState === false) host._state = null;
      host._spec = spec;
      draw(host);
      if (!host._ro) {
        let lastW = host.clientWidth;
        host._ro = new ResizeObserver(() => {
          if (Math.abs(host.clientWidth - lastW) > 4 && host._spec) { lastW = host.clientWidth; draw(host); }
        });
        host._ro.observe(host);
      }
    },
    renderError(host, err) {
      host._spec = null;
      if (!err || !err.message) { host.innerHTML = ""; return; }
      message(host, err.message, "error");
    },
    clearError() {}
  });
  Shiny.outputBindings.register(binding, "microarrai.chart");
})();
