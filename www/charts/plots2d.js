/* ===========================================================================
 * charts/plots2d.js — 2D chart types for charts/core.js
 *   scatter    ordination scores (PCA, PCoA, NMDS, PLS-DA, DBSCAN), 95 % ellipses
 *   donut      share per isotype
 *   histogram  one small multiple per isotype, shared x axis
 *   groupdist  violin + box + jittered samples for one peptide
 *   radar      model metrics on a 0–1 scale
 *   heatmap    QC grades, metrics x arrays
 * =========================================================================== */
(function () {
  const C = window.MaiCharts;
  const { arr, rows, el, svg, text, scale, extent, axes, tip, legend, colorMap, fmt, tickFmt, num, INK, MUTED } = C;
  const alpha = (hex, a) => hex + Math.round(a * 255).toString(16).padStart(2, "0");
  const solid = c => (/^#[0-9a-f]{8}$/i.test(c) ? c.slice(0, 7) : c);

  // ---------- scatter ------------------------------------------------------
  const SHAPES = ["circle", "triangle", "square", "diamond", "cross", "star"];
  function marker(g, shape, x, y, r, attrs) {
    if (shape === "circle" || !shape) return el("circle", { cx: x, cy: y, r, ...attrs }, g);
    const pts = {
      triangle: [[0, -1.2], [1.05, 0.65], [-1.05, 0.65]],
      square: [[-0.9, -0.9], [0.9, -0.9], [0.9, 0.9], [-0.9, 0.9]],
      diamond: [[0, -1.25], [1.05, 0], [0, 1.25], [-1.05, 0]],
      cross: [[-0.35, -1], [0.35, -1], [0.35, -0.35], [1, -0.35], [1, 0.35], [0.35, 0.35], [0.35, 1], [-0.35, 1], [-0.35, 0.35], [-1, 0.35], [-1, -0.35], [-0.35, -0.35]],
      star: Array.from({ length: 10 }, (_, i) => { const a = -Math.PI / 2 + i * Math.PI / 5, k = i % 2 ? 0.5 : 1.25; return [k * Math.cos(a), k * Math.sin(a)]; })
    }[shape] || [[0, 0]];
    return el("polygon", { points: pts.map(([a, b]) => `${x + a * r},${y + b * r}`).join(" "), ...attrs }, g);
  }

  // 95 % normal ellipse of a point cloud (chi-square, 2 df = 5.991)
  function ellipse(pts) {
    const n = pts.length; if (n < 3) return null;
    const mx = pts.reduce((s, p) => s + p.x, 0) / n, my = pts.reduce((s, p) => s + p.y, 0) / n;
    let a = 0, b = 0, c = 0;
    pts.forEach(p => { a += (p.x - mx) ** 2; b += (p.x - mx) * (p.y - my); c += (p.y - my) ** 2; });
    a /= n - 1; b /= n - 1; c /= n - 1;
    const tr = (a + c) / 2, det = Math.sqrt(((a - c) / 2) ** 2 + b * b);
    const l1 = tr + det, l2 = Math.max(tr - det, 0), th = Math.atan2(l1 - a, b || 1e-12);
    const k = Math.sqrt(5.991);
    return Array.from({ length: 73 }, (_, i) => {
      const t = (i / 72) * 2 * Math.PI, u = k * Math.sqrt(l1) * Math.cos(t), v = k * Math.sqrt(l2) * Math.sin(t);
      return { x: mx + u * Math.cos(th) - v * Math.sin(th), y: my + u * Math.sin(th) + v * Math.cos(th) };
    });
  }

  C.types.scatter = function (body, spec, st, redraw, host) {
    const d = rows(spec.data), groups = arr(spec.groups), col = colorMap(groups, spec.colors);
    const shapeKeys = d.some(p => p.shape != null) ? [...new Set(d.map(p => p.shape))].sort((a, b) => (a === "Noise") - (b === "Noise") || String(a).localeCompare(b)) : [];
    const shapeOf = s => (shapeKeys.length ? (s === "Noise" ? "cross" : SHAPES[shapeKeys.filter(k => k !== "Noise").indexOf(s) % SHAPES.length]) : "circle");
    const { w, h } = C.size(body, host, shapeKeys.length ? 2 : 1);
    const m = { t: 14, r: 18, b: 50, l: 64 }, iw = w - m.l - m.r, ih = h - m.t - m.b;
    // 95 % ellipses per group, computed once; the axes make room for them
    const ells = spec.ellipse === false ? {} : Object.fromEntries(groups.map(gr => [gr, ellipse(d.filter(p => p.g === gr))]));
    const ellPts = Object.values(ells).filter(Boolean).flat();
    const x = scale(...extent(d.map(p => p.x).concat(ellPts.map(p => p.x)), 0.03), 0, iw);
    const y = scale(...extent(d.map(p => p.y).concat(ellPts.map(p => p.y)), 0.03), ih, 0);
    const s = svg(body, w, h), g = el("g", { transform: `translate(${m.l},${m.t})` }, s);
    axes(g, x, y, iw, ih, spec.xlab, spec.ylab);
    const clip = "c" + Math.random().toString(36).slice(2);
    el("rect", { x: 0, y: 0, width: iw, height: ih }, el("clipPath", { id: clip }, el("defs", {}, s)));
    const layer = el("g", { "clip-path": `url(#${clip})` }, g);
    const shown = d.filter(p => !st.hidden.has(String(p.g)));
    groups.forEach(gr => {
      const e = st.hidden.has(String(gr)) ? null : ells[gr];
      if (e) el("path", { d: "M" + e.map(p => `${x(p.x)},${y(p.y)}`).join("L") + "Z", fill: alpha(solid(col[gr]), 0.1), stroke: alpha(solid(col[gr]), 0.65), "stroke-width": 1.5, "data-g": gr, class: "mai-ell" }, layer);
    });
    const r = shown.length > 400 ? 3.2 : shown.length > 150 ? 4.2 : 5.2;
    shown.forEach(p => {
      const mk = marker(layer, shapeOf(p.shape), x(p.x), y(p.y), r, { fill: alpha(solid(col[p.g]), 0.82), stroke: "#fff", "stroke-width": 1.1, "data-g": p.g, class: "mai-pt" });
      mk.addEventListener("mousemove", e => { mk.setAttribute("stroke", INK); mk.setAttribute("stroke-width", 2); tip.show(e, p.tip || p.id); });
      mk.addEventListener("mouseleave", () => { mk.setAttribute("stroke", "#fff"); mk.setAttribute("stroke-width", 1.1); tip.hide(); });
    });
    st.onFocus = () => s.querySelectorAll("[data-g]").forEach(n => { n.style.opacity = st.focus == null || n.dataset.g === st.focus ? "" : 0.12; });
    legend(host, groups.map(k => ({ key: k, color: solid(col[k]) })), st, redraw, spec.groupTitle);
    if (shapeKeys.length) {
      const box = document.createElement("div"); box.className = "mai-legend static";
      box.innerHTML = `<span class="mai-legend-title">${C.esc(spec.shapeTitle || "Shape")}</span>` + shapeKeys.map(k => {
        const t = document.createElementNS(C.NS, "svg"); t.setAttribute("width", 14); t.setAttribute("height", 14);
        marker(t, shapeOf(k), 7, 7, 5, { fill: "#8a93a6" });
        return `<span>${t.outerHTML}${C.esc(k)}</span>`;
      }).join("");
      host.appendChild(box);
    }
  };

  // ---------- donut --------------------------------------------------------
  C.types.donut = function (body, spec, st, redraw, host) {
    const sl = rows(spec.slices).filter(p => p.value > 0);
    const { w, h } = C.size(body, host);
    const R = Math.min(w, h) / 2 - 12, r0 = R * 0.62, cx = w / 2, cy = h / 2;
    const s = svg(body, w, h), g = el("g", { transform: `translate(${cx},${cy})` }, s);
    const vis = sl.filter(p => !st.hidden.has(p.label)), tot = vis.reduce((a, p) => a + p.value, 0) || 1;
    const arc = (a0, a1, ri, ro) => {
      const p = (a, rr) => `${rr * Math.sin(a)},${-rr * Math.cos(a)}`, big = a1 - a0 > Math.PI ? 1 : 0;
      if (a1 - a0 >= 2 * Math.PI - 1e-6) a1 = a0 + 2 * Math.PI - 1e-4;
      return `M${p(a0, ro)}A${ro},${ro} 0 ${big} 1 ${p(a1, ro)}L${p(a1, ri)}A${ri},${ri} 0 ${big} 0 ${p(a0, ri)}Z`;
    };
    let a = 0;
    vis.forEach(p => {
      const a1 = a + (p.value / tot) * 2 * Math.PI, mid = (a + a1) / 2, pct = (100 * p.value) / tot;
      const path = el("path", { d: arc(a, a1, r0, R), fill: p.color, stroke: "#fff", "stroke-width": 2.5, style: "transition: transform .18s" }, g);
      path.addEventListener("mousemove", e => { path.setAttribute("transform", `translate(${6 * Math.sin(mid)},${-6 * Math.cos(mid)})`); tip.show(e, p.tip || `${p.label}\n${fmt(p.value)} (${pct.toFixed(1)} %)`); });
      path.addEventListener("mouseleave", () => { path.removeAttribute("transform"); tip.hide(); });
      if (pct >= 6) text(g, ((r0 + R) / 2) * Math.sin(mid), -((r0 + R) / 2) * Math.cos(mid) + 4, pct.toFixed(0) + "%", { "text-anchor": "middle", fill: "#fff", "font-weight": 700, "font-size": 12, "pointer-events": "none" });
      a = a1;
    });
    const cv = spec.center && spec.center.value != null ? spec.center.value : vis.reduce((s2, p) => s2 + p.value, 0);
    text(g, 0, 4, typeof cv === "number" ? num(cv) : cv, { "text-anchor": "middle", "font-size": Math.max(16, r0 * 0.38), "font-weight": 700 });
    if (spec.center && spec.center.label) text(g, 0, r0 * 0.38 + 6, spec.center.label, { "text-anchor": "middle", fill: MUTED, "font-size": 11 });
    legend(host, sl.map(p => ({ key: p.label, color: p.color })), st, redraw);
  };

  // ---------- histogram (small multiples) ----------------------------------
  C.types.histogram = function (body, spec, st, redraw, host) {
    const panels = arr(spec.panels).map(p => ({ ...p, values: arr(p.values).filter(Number.isFinite) })).filter(p => p.values.length);
    if (!panels.length) return;
    const { w, h } = C.size(body, host, 0);
    const m = { t: 6, r: 18, b: 42, l: 64 }, iw = w - m.l - m.r, gap = 14;
    const ph = (h - m.t - m.b - gap * (panels.length - 1)) / panels.length;
    const all = panels.flatMap(p => p.values), [lo, hi] = extent(all, 0.01), nb = spec.bins || 40, bw = (hi - lo) / nb;
    const x = scale(lo, hi, 0, iw), s = svg(body, w, h);
    panels.forEach((p, i) => {
      const counts = new Array(nb).fill(0);
      p.values.forEach(v => counts[Math.min(nb - 1, Math.floor((v - lo) / bw))]++);
      const g = el("g", { transform: `translate(${m.l},${m.t + i * (ph + gap)})` }, s);
      const y = scale(0, Math.max(...counts) * 1.1, ph, 0);
      C.ticks(...y.domain, 3).forEach(v => { el("line", { x1: 0, x2: iw, y1: y(v), y2: y(v), stroke: C.GRID }, g); text(g, -8, y(v) + 4, tickFmt(v), { "text-anchor": "end", fill: MUTED, "font-size": 10 }); });
      counts.forEach((c, k) => {
        if (!c) return;
        const b = el("rect", { x: x(lo + k * bw) + 0.5, y: y(c), width: Math.max(1, x(lo + bw) - x(lo) - 1), height: ph - y(c), fill: p.color || "#17a589", rx: 1.5, opacity: 0.85 }, g);
        b.addEventListener("mousemove", e => { b.setAttribute("opacity", 1); tip.show(e, `${p.name}\n${fmt(lo + k * bw)} to ${fmt(lo + (k + 1) * bw)}\n${num(c)} values (${((100 * c) / p.values.length).toFixed(1)} %)`); });
        b.addEventListener("mouseleave", () => { b.setAttribute("opacity", 0.85); tip.hide(); });
      });
      const sorted = [...p.values].sort((a2, b2) => a2 - b2), med = sorted[Math.floor(sorted.length / 2)];
      el("line", { x1: x(med), x2: x(med), y1: 0, y2: ph, stroke: INK, "stroke-dasharray": "4 3", "stroke-width": 1.2 }, g);
      text(g, iw - 4, 14, `${p.name} · n = ${num(p.values.length)} · median ${fmt(med)}`, { "text-anchor": "end", "font-weight": 600, "font-size": 12 });
      el("line", { x1: 0, x2: iw, y1: ph, y2: ph, stroke: "#c9ced8" }, g);
      if (i === panels.length - 1) {
        C.ticks(lo, hi, 7).forEach(v => text(g, x(v), ph + 16, tickFmt(v), { "text-anchor": "middle", fill: MUTED, "font-size": 11 }));
        if (spec.xlab) text(g, iw / 2, ph + 36, spec.xlab, { "text-anchor": "middle", "font-weight": 600 });
      }
    });
  };

  // ---------- groupdist: violin + box + samples ----------------------------
  const quant = (s, q) => { const i = (s.length - 1) * q, a = Math.floor(i); return s[a] + (s[Math.min(a + 1, s.length - 1)] - s[a]) * (i - a); };
  C.types.groupdist = function (body, spec, st, redraw, host) {
    const groups = arr(spec.groups).map(g => ({ ...g, values: arr(g.values), ids: arr(g.ids) }));
    const { w, h } = C.size(body, host);
    const m = { t: 14, r: 18, b: 40, l: 64 }, iw = w - m.l - m.r, ih = h - m.t - m.b;
    const vis = groups.filter(g => !st.hidden.has(g.name));
    const y = scale(...extent(vis.flatMap(g => g.values)), ih, 0), band = iw / Math.max(1, vis.length);
    const s = svg(body, w, h), g0 = el("g", { transform: `translate(${m.l},${m.t})` }, s);
    C.ticks(...y.domain).forEach(v => { el("line", { x1: 0, x2: iw, y1: y(v), y2: y(v), stroke: C.GRID }, g0); text(g0, -8, y(v) + 4, tickFmt(v), { "text-anchor": "end", fill: MUTED, "font-size": 11 }); });
    if (spec.ylab) text(g0, -ih / 2, -46, spec.ylab, { transform: "rotate(-90)", "text-anchor": "middle", "font-weight": 600 });
    vis.forEach((gr, i) => {
      const v = gr.values.map((val, k) => ({ val, id: gr.ids[k] })).filter(p => Number.isFinite(p.val));
      const sorted = v.map(p => p.val).sort((a, b) => a - b), cx = band * (i + 0.5), col = solid(gr.color);
      text(g0, cx, ih + 20, `${gr.name} (n = ${v.length})`, { "text-anchor": "middle", "font-weight": 600 });
      if (!v.length) return;
      const q1 = quant(sorted, 0.25), med = quant(sorted, 0.5), q3 = quant(sorted, 0.75), iqr = q3 - q1;
      const lo = sorted.find(a => a >= q1 - 1.5 * iqr), hi = [...sorted].reverse().find(a => a <= q3 + 1.5 * iqr);
      // violin: Gaussian KDE with Silverman's bandwidth
      const sd = Math.sqrt(sorted.reduce((a, b) => a + (b - med) ** 2, 0) / Math.max(1, sorted.length - 1)) || 1;
      const bw = 1.06 * Math.min(sd, iqr / 1.34 || sd) * sorted.length ** -0.2 || 0.1;
      const grid = Array.from({ length: 50 }, (_, k) => sorted[0] + ((sorted.at(-1) - sorted[0]) * k) / 49);
      const dens = grid.map(t => sorted.reduce((a, b) => a + Math.exp(-0.5 * ((t - b) / bw) ** 2), 0));
      const dmax = Math.max(...dens) || 1, half = Math.min(band * 0.36, 70);
      const path = grid.map((t, k) => `${cx + (dens[k] / dmax) * half},${y(t)}`).concat(grid.slice().reverse().map((t, k) => `${cx - (dens[49 - k] / dmax) * half},${y(t)}`));
      const vio = el("path", { d: "M" + path.join("L") + "Z", fill: alpha(col, 0.16), stroke: alpha(col, 0.7), "stroke-width": 1.3 }, g0);
      vio.addEventListener("mousemove", e => tip.show(e, `${gr.name}\nn = ${v.length}\nmedian ${fmt(med)}\nIQR ${fmt(q1)} to ${fmt(q3)}`));
      vio.addEventListener("mouseleave", () => tip.hide());
      // box
      const bwid = Math.min(band * 0.12, 22);
      el("line", { x1: cx, x2: cx, y1: y(lo), y2: y(q1), stroke: INK, "stroke-width": 1.2 }, g0);
      el("line", { x1: cx, x2: cx, y1: y(q3), y2: y(hi), stroke: INK, "stroke-width": 1.2 }, g0);
      [lo, hi].forEach(t => el("line", { x1: cx - bwid / 3, x2: cx + bwid / 3, y1: y(t), y2: y(t), stroke: INK, "stroke-width": 1.2 }, g0));
      el("rect", { x: cx - bwid / 2, y: y(q3), width: bwid, height: Math.max(1, y(q1) - y(q3)), fill: "#fff", stroke: INK, "stroke-width": 1.3, rx: 3, "pointer-events": "none" }, g0);
      el("line", { x1: cx - bwid / 2, x2: cx + bwid / 2, y1: y(med), y2: y(med), stroke: col, "stroke-width": 3, "pointer-events": "none" }, g0);
      // samples, jittered deterministically so a redraw does not reshuffle them
      v.forEach((p, k) => {
        const out = p.val < lo || p.val > hi, jx = cx + half * 0.55 * (((Math.sin((k + 1) * 12.9898) * 43758.5453) % 1));
        const c = el("circle", { cx: jx, cy: y(p.val), r: out ? 4.5 : 3, fill: out ? "#e74c3c" : alpha(col, 0.75), stroke: "#fff", "stroke-width": 0.8 }, g0);
        c.addEventListener("mousemove", e => { c.setAttribute("r", 6); tip.show(e, `${p.id ?? "sample"}\n${gr.name}\n${spec.ylab || "value"}: ${fmt(p.val)}${out ? "\noutlier (beyond 1.5 IQR)" : ""}`); });
        c.addEventListener("mouseleave", () => { c.setAttribute("r", out ? 4.5 : 3); tip.hide(); });
      });
    });
    legend(host, groups.map(gr => ({ key: gr.name, color: solid(gr.color) })), st, redraw);
  };

  // ---------- radar --------------------------------------------------------
  C.types.radar = function (body, spec, st, redraw, host) {
    const ax = arr(spec.axes), val = arr(spec.values).map(v => (v == null || !isFinite(v) ? null : Math.max(0, Math.min(1, v))));
    const { w, h } = C.size(body, host, 0), R = Math.min(w, h) / 2 - 46, cx = w / 2, cy = h / 2 + 4, n = ax.length;
    const s = svg(body, w, h), g = el("g", { transform: `translate(${cx},${cy})` }, s), col = spec.color || "#667eea";
    const pt = (i, r) => [r * Math.sin((2 * Math.PI * i) / n), -r * Math.cos((2 * Math.PI * i) / n)];
    [0.25, 0.5, 0.75, 1].forEach(r => {
      el("polygon", { points: ax.map((_, i) => pt(i, R * r).join(",")).join(" "), fill: r === 1 ? "#f7f8fb" : "none", stroke: "#dde1e8" }, g);
      const [tx, ty] = pt(0.5, R * r); text(g, tx, ty, `${r * 100}%`, { fill: "#a0a7b4", "font-size": 9, "text-anchor": "middle" });
    });
    ax.forEach((a, i) => {
      el("line", { x1: 0, y1: 0, x2: pt(i, R)[0], y2: pt(i, R)[1], stroke: "#dde1e8" }, g);
      const [lx, ly] = pt(i, R + 20), anchor = Math.abs(lx) < 4 ? "middle" : lx > 0 ? "start" : "end";
      text(g, lx, ly + 4, a, { "text-anchor": anchor, "font-weight": 600, "font-size": 11.5 });
      text(g, lx, ly + 18, val[i] == null ? "n/a" : (val[i] * 100).toFixed(0) + "%", { "text-anchor": anchor, fill: val[i] == null ? "#a0a7b4" : col, "font-size": 11, "font-weight": 700 });
    });
    el("polygon", { points: val.map((v, i) => pt(i, R * (v ?? 0)).join(",")).join(" "), fill: alpha(col, 0.22), stroke: col, "stroke-width": 2.2, "stroke-linejoin": "round" }, g);
    val.forEach((v, i) => {
      if (v == null) return;
      const c = el("circle", { cx: pt(i, R * v)[0], cy: pt(i, R * v)[1], r: 4.5, fill: col, stroke: "#fff", "stroke-width": 1.5 }, g);
      c.addEventListener("mousemove", e => { c.setAttribute("r", 7); tip.show(e, `${ax[i]}\n${(v * 100).toFixed(1)} %`); });
      c.addEventListener("mouseleave", () => { c.setAttribute("r", 4.5); tip.hide(); });
    });
  };

  // ---------- heatmap (QC grades) ------------------------------------------
  C.types.heatmap = function (body, spec, st, redraw, host) {
    const rowsL = arr(spec.rows), cols = arr(spec.cols), cells = rows(spec.cells), pal = spec.colors || {};
    const showCols = spec.colLabels && cols.length <= 60;
    const { w, h } = C.size(body, host);
    const m = { t: 6, r: 10, b: showCols ? 70 : 14, l: 190 }, iw = w - m.l - m.r, ih = h - m.t - m.b;
    const cw = iw / cols.length, ch = ih / rowsL.length, ci = Object.fromEntries(cols.map((c, i) => [c, i])), ri = Object.fromEntries(rowsL.map((r, i) => [r, i]));
    const s = svg(body, w, h), g = el("g", { transform: `translate(${m.l},${m.t})` }, s);
    rowsL.forEach((r, i) => text(g, -10, i * ch + ch / 2 + 4, r, { "text-anchor": "end", "font-weight": 600, "font-size": 11.5 }));
    if (showCols) cols.forEach((c, i) => text(g, i * cw + cw / 2 + 3, ih + 8, c, { transform: `rotate(-90 ${i * cw + cw / 2 + 3} ${ih + 8})`, "text-anchor": "end", fill: MUTED, "font-size": 9 }));
    const hl = el("rect", { y: -2, width: cw, height: ih + 4, fill: "none", stroke: INK, "stroke-width": 2, rx: 2, opacity: 0, "pointer-events": "none" });
    cells.forEach(c => {
      const key = c.grade ?? "na", off = st.hidden.has(key);
      const r = el("rect", { x: ci[c.c] * cw + 0.5, y: ri[c.r] * ch + 0.5, width: Math.max(1, cw - 1), height: ch - 1, rx: Math.min(3, cw / 4), fill: pal[key] || "#dfe4e6", opacity: off ? 0.15 : 1 }, g);
      r.addEventListener("mousemove", e => { hl.setAttribute("x", ci[c.c] * cw); hl.setAttribute("opacity", 1); tip.show(e, c.tip); });
      r.addEventListener("mouseleave", () => { hl.setAttribute("opacity", 0); tip.hide(); });
    });
    g.appendChild(hl);
    legend(host, arr(spec.legend).map(k => ({ key: k, label: spec.legendLabels ? spec.legendLabels[k] : k, color: pal[k] })), st, redraw);
  };
})();

/* ---------- roc: one or more empirical ROC curves ------------------------ */
(function () {
  const C = window.MaiCharts;
  const { arr, el, svg, text, scale, axes, tip, legend } = C;
  C.types.roc = function (body, spec, st, redraw, host) {
    const curves = arr(spec.curves).map(c => ({ ...c, fpr: arr(c.fpr), tpr: arr(c.tpr) }));
    const { w, h } = C.size(body, host);
    const side = Math.min(w - 90, h - 60), m = { t: 10, l: 60 }, ox = Math.max(m.l, (w - side) / 2);
    const x = scale(0, 1, 0, side), y = scale(0, 1, side, 0);
    const s = svg(body, w, h), g = el("g", { transform: `translate(${ox},${m.t})` }, s);
    axes(g, x, y, side, side, "1 − specificity (false positive rate)", "Sensitivity (true positive rate)");
    el("line", { x1: x(0), y1: y(0), x2: x(1), y2: y(1), stroke: "#b8c0cc", "stroke-dasharray": "5 4" }, g);
    const shown = curves.filter(c => !st.hidden.has(c.name));
    shown.forEach(c => {
      const pts = c.fpr.map((f, i) => [x(f), y(c.tpr[i])]);
      if (shown.length === 1) el("path", { d: `M${x(0)},${y(0)}L` + pts.map(p => p.join(",")).join("L") + `L${x(1)},${y(0)}Z`, fill: c.color, opacity: 0.1 }, g);
      const d = "M" + pts.map(p => p.join(",")).join("L");
      el("path", { d, fill: "none", stroke: c.color, "stroke-width": 2.6, "stroke-linejoin": "round", "data-g": c.name }, g);
      const hit = el("path", { d, fill: "none", stroke: "transparent", "stroke-width": 14 }, g);   // easy to hover
      hit.addEventListener("mousemove", e => {
        const r = s.getBoundingClientRect(), mx = e.clientX - r.left - ox, my = e.clientY - r.top - m.t;
        let k = 0, best = Infinity;
        pts.forEach((p, i) => { const dd = (p[0] - mx) ** 2 + (p[1] - my) ** 2; if (dd < best) { best = dd; k = i; } });
        tip.show(e, `${c.name}\nFPR ${c.fpr[k].toFixed(2)} · sensitivity ${c.tpr[k].toFixed(2)}\nAUC ${C.fmt(c.auc)}`);
      });
      hit.addEventListener("mouseleave", () => tip.hide());
    });
    st.onFocus = () => s.querySelectorAll("[data-g]").forEach(n => { n.style.opacity = st.focus == null || n.dataset.g === st.focus ? "" : 0.15; });
    legend(host, curves.map(c => ({ key: c.name, color: c.color,
      label: `${c.name} · AUC ${C.fmt(c.auc)}${c.lo != null ? ` [${C.fmt(c.lo)}–${C.fmt(c.hi)}]` : ""}` })), st, redraw);
  };
})();
