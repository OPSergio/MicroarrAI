/* ===========================================================================
 * charts/scatter3d.js — interactive 3D ordination scatter on a 2D canvas
 *
 * Shaded spheres sorted back to front, a floor grid with drop lines for depth,
 * group centroids, optional spokes, 95 % ellipsoids per group and, with two
 * groups, the plane that best separates them (Fisher's linear discriminant in
 * the three displayed axes). Drag to rotate, +/− to zoom, double-click to reset.
 * spec: {type:"scatter3d", data:{x,y,z,g,id,tip}, groups, colors, labels:[x,y,z]}
 * =========================================================================== */
(function () {
  const C = window.MaiCharts;
  const { arr, rows, tip, legend, colorMap } = C;
  const solid = c => (/^#[0-9a-f]{8}$/i.test(c) ? c.slice(0, 7) : c);
  const rgb = hex => { const n = parseInt(solid(hex).slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255]; };
  const mix = (c, t, k) => c.map((v, i) => Math.round(v + (t[i] - v) * k));
  const css = (c, a = 1) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;
  const CHI2_3_95 = 7.815;   // 95 % quantile of chi-square with 3 df
  const BOX = 1.08;

  // ---------- small linear algebra (3 x 3) -------------------------------
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const norm = a => { const l = Math.hypot(...a) || 1; return a.map(v => v / l); };
  function mean(pts) { return [0, 1, 2].map(i => pts.reduce((s, p) => s + p[i], 0) / pts.length); }
  function cov(pts, m) {
    const S = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
    pts.forEach(p => { for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) S[i][j] += (p[i] - m[i]) * (p[j] - m[j]); });
    return S.map(r => r.map(v => v / Math.max(1, pts.length - 1)));
  }
  // Jacobi rotations: eigenvalues and eigenvectors of a symmetric matrix
  function eig3(A) {
    const a = A.map(r => r.slice()), V = [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
    for (let it = 0; it < 60; it++) {
      let p = 0, q = 1;
      if (Math.abs(a[0][2]) > Math.abs(a[p][q])) { p = 0; q = 2; }
      if (Math.abs(a[1][2]) > Math.abs(a[p][q])) { p = 1; q = 2; }
      if (Math.abs(a[p][q]) < 1e-14) break;
      const th = (a[q][q] - a[p][p]) / (2 * a[p][q]);
      const t = (th >= 0 ? 1 : -1) / (Math.abs(th) + Math.sqrt(th * th + 1)), c = 1 / Math.sqrt(t * t + 1), s = t * c;
      for (let k = 0; k < 3; k++) { const x = a[k][p], y = a[k][q]; a[k][p] = c * x - s * y; a[k][q] = s * x + c * y; }
      for (let k = 0; k < 3; k++) { const x = a[p][k], y = a[q][k]; a[p][k] = c * x - s * y; a[q][k] = s * x + c * y; }
      for (let k = 0; k < 3; k++) { const x = V[k][p], y = V[k][q]; V[k][p] = c * x - s * y; V[k][q] = s * x + c * y; }
    }
    return [0, 1, 2].map(j => ({ value: Math.max(0, a[j][j]), vector: [V[0][j], V[1][j], V[2][j]] }));
  }
  function inv3(M) {
    const [a, b, c] = M, det = dot(a, cross(b, c));
    if (Math.abs(det) < 1e-12) return null;
    const r0 = cross(b, c), r1 = cross(c, a), r2 = cross(a, b);   // rows of the adjugate, transposed
    return [0, 1, 2].map(i => [r0[i] / det, r1[i] / det, r2[i] / det]);
  }
  // 2D convex hull (monotone chain), used to shade an ellipsoid's silhouette
  function hull(pts) {
    pts = pts.slice().sort((a, b) => a[0] - b[0] || a[1] - b[1]);
    const cr = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
    const lo = [], up = [];
    for (const p of pts) { while (lo.length > 1 && cr(lo[lo.length - 2], lo[lo.length - 1], p) <= 0) lo.pop(); lo.push(p); }
    for (const p of pts.reverse()) { while (up.length > 1 && cr(up[up.length - 2], up[up.length - 1], p) <= 0) up.pop(); up.push(p); }
    return lo.slice(0, -1).concat(up.slice(0, -1));
  }

  function sprite(hex) {
    const S = 64, cv = document.createElement("canvas"); cv.width = cv.height = S;
    const ctx = cv.getContext("2d"), c = rgb(hex);
    const gr = ctx.createRadialGradient(S * 0.36, S * 0.32, S * 0.04, S / 2, S / 2, S / 2);
    gr.addColorStop(0, css(mix(c, [255, 255, 255], 0.7))); gr.addColorStop(0.45, css(c)); gr.addColorStop(1, css(mix(c, [10, 12, 30], 0.45)));
    ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(S / 2, S / 2, S / 2 - 1, 0, 2 * Math.PI); ctx.fill();
    return cv;
  }

  C.types.scatter3d = function (body, spec, st, redraw, host) {
    const d = rows(spec.data), groups = arr(spec.groups), col = colorMap(groups, spec.colors), lab = arr(spec.labels);
    st.view = st.view || { yaw: -0.7, pitch: 0.42, zoom: 1 };
    st.opt = st.opt || { centroids: true, drops: true, spokes: false, ellipsoids: false, plane: false };
    const { w, h } = C.size(body, host);
    const dpr = window.devicePixelRatio || 1;

    // Shared scale keeps the true proportions between the three axes
    const ext = ["x", "y", "z"].map(k => { const v = d.map(p => p[k]).filter(Number.isFinite); return [Math.min(...v), Math.max(...v)]; });
    const span = Math.max(...ext.map(e => e[1] - e[0])) || 1, mid = ext.map(e => (e[0] + e[1]) / 2);
    const P = d.map(p => ({ ...p, w: [0, 1, 2].map(i => (2 * ([p.x, p.y, p.z][i] - mid[i])) / span) }));

    // Per group: centroid, covariance and its 95 % ellipsoid axes
    const G = groups.map(g => {
      const pts = P.filter(p => p.g === g).map(p => p.w);
      const m = pts.length ? mean(pts) : [0, 0, 0], S = pts.length > 3 ? cov(pts, m) : null;
      return { g, n: pts.length, pts, m, S, axes: S ? eig3(S) : null };
    });

    // Fisher discriminant plane w·x = c between the two groups (pooled covariance)
    let plane = null;
    if (groups.length === 2 && G.every(x => x.S)) {
      const Sw = [0, 1, 2].map(i => [0, 1, 2].map(j => (G[0].n - 1) * G[0].S[i][j] + (G[1].n - 1) * G[1].S[i][j] + (i === j ? 1e-6 : 0)));
      const inv = inv3(Sw);
      if (inv) {
        const dm = [0, 1, 2].map(i => G[1].m[i] - G[0].m[i]);
        const wv = norm(inv.map(r => dot(r, dm)));
        const c = dot(wv, [0, 1, 2].map(i => (G[0].m[i] + G[1].m[i]) / 2));
        const right = G[0].pts.filter(p => dot(wv, p) < c).length + G[1].pts.filter(p => dot(wv, p) >= c).length;
        // polygon where the plane cuts the box
        const corners = [];
        for (let i = 0; i < 8; i++) corners.push([i & 1 ? BOX : -BOX, i & 2 ? BOX : -BOX, i & 4 ? BOX : -BOX]);
        const cut = [];
        for (let i = 0; i < 8; i++) for (const bit of [1, 2, 4]) {
          if (i & bit) continue;
          const a = corners[i], b = corners[i | bit], fa = dot(wv, a) - c, fb = dot(wv, b) - c;
          if (fa * fb < 0) { const t = fa / (fa - fb); cut.push(a.map((v, k) => v + t * (b[k] - v))); }
        }
        if (cut.length >= 3) {
          const ctr = mean(cut), u = norm(cross(wv, Math.abs(wv[0]) < 0.9 ? [1, 0, 0] : [0, 1, 0])), v = cross(wv, u);
          cut.sort((p, q) => Math.atan2(dot(p.map((x, k) => x - ctr[k]), v), dot(p.map((x, k) => x - ctr[k]), u)) -
                             Math.atan2(dot(q.map((x, k) => x - ctr[k]), v), dot(q.map((x, k) => x - ctr[k]), u)));
          plane = { poly: cut, accuracy: right / (G[0].n + G[1].n) };
        }
      }
    }

    // Layout: control pills over the canvas (no background: the card shows through)
    const wrap = document.createElement("div"); wrap.className = "mai-3d"; wrap.style.height = h + "px";
    const cv = document.createElement("canvas"); cv.width = w * dpr; cv.height = h * dpr; cv.style.width = w + "px"; cv.style.height = h + "px";
    const ctl = document.createElement("div"); ctl.className = "mai-3d-ctl";
    const pills = [["centroids", "Centroids"], ["drops", "Drop lines"], ["spokes", "Spokes"], ["ellipsoids", "95% ellipsoids"]]
      .concat(plane ? [["plane", "Separating plane"]] : []);
    ctl.innerHTML = pills.map(([k, t]) => `<button type="button" data-o="${k}" class="${st.opt[k] ? "on" : ""}">${t}</button>`).join("") +
      `<span class="sep"></span><button type="button" data-z="1.2" title="Zoom in">+</button><button type="button" data-z="0.833" title="Zoom out">−</button><button type="button" data-reset="1" title="Reset view">Reset</button>`;
    const hint = document.createElement("div"); hint.className = "mai-3d-hint"; hint.textContent = "Drag to rotate · double-click to reset";
    wrap.append(cv, ctl, hint); body.appendChild(wrap);
    const ctx = cv.getContext("2d"); ctx.scale(dpr, dpr);

    const cam = 4.2;
    function project(v) {
      const { yaw, pitch, zoom } = st.view;
      const x1 = v[0] * Math.cos(yaw) - v[1] * Math.sin(yaw), y1 = v[0] * Math.sin(yaw) + v[1] * Math.cos(yaw);
      const z2 = v[2] * Math.cos(pitch) - y1 * Math.sin(pitch), depth = y1 * Math.cos(pitch) + v[2] * Math.sin(pitch);
      const k = (cam / (cam + depth)) * Math.min(w, h) * 0.3 * zoom;
      return { sx: w / 2 + x1 * k, sy: h / 2 - z2 * k + h * 0.03, depth, k };
    }
    const path = (pts, close) => { pts.forEach((v, i) => { const p = project(v); i ? ctx.lineTo(p.sx, p.sy) : ctx.moveTo(p.sx, p.sy); }); if (close) ctx.closePath(); };
    const line = (a, b, stroke, lw = 1) => { ctx.strokeStyle = stroke; ctx.lineWidth = lw; ctx.beginPath(); path([a, b]); ctx.stroke(); };
    const label = (v, t, color = "#3a4050", font = "600 12px") => {
      const p = project(v); ctx.font = `${font} ${C.FONT}`; ctx.textAlign = "center";
      const half = ctx.measureText(t).width / 2 + 6;
      ctx.fillStyle = color; ctx.fillText(t, Math.max(half, Math.min(w - half, p.sx)), Math.max(52, Math.min(h - 8, p.sy)));
    };

    // point of a group's 95 % ellipsoid at latitude u, longitude v
    const ellPoint = (gr, u, v) => {
      const k = Math.sqrt(CHI2_3_95), [a, b, c] = gr.axes;
      const s = [Math.sqrt(a.value) * Math.cos(u) * Math.cos(v), Math.sqrt(b.value) * Math.cos(u) * Math.sin(v), Math.sqrt(c.value) * Math.sin(u)];
      return [0, 1, 2].map(i => gr.m[i] + k * (s[0] * a.vector[i] + s[1] * b.vector[i] + s[2] * c.vector[i]));
    };
    function drawEllipsoid(gr, faded) {
      const c = rgb(col[gr.g]), ring = n => Array.from({ length: n + 1 }, (_, i) => (2 * Math.PI * i) / n);
      const sil = [];   // silhouette: hull of projected surface samples
      for (let i = -6; i <= 6; i++) for (const v of ring(24)) { const p = project(ellPoint(gr, (i / 6) * (Math.PI / 2), v)); sil.push([p.sx, p.sy]); }
      const hl = hull(sil);
      ctx.fillStyle = css(c, faded ? 0.02 : 0.08); ctx.beginPath(); hl.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = css(c, faded ? 0.06 : 0.22); ctx.lineWidth = 1;
      for (let m = 0; m < 6; m++) { ctx.beginPath(); path(ring(48).map(u => ellPoint(gr, u, (m * Math.PI) / 6))); ctx.stroke(); }   // meridians
      for (const u of [-Math.PI / 4, 0, Math.PI / 4]) { ctx.beginPath(); path(ring(48).map(v => ellPoint(gr, u, v))); ctx.stroke(); } // parallels
    }

    let hover = null, proj = [];
    function render() {
      ctx.clearRect(0, 0, w, h);
      const F = -BOX;
      for (let i = -4; i <= 4; i++) {
        const t = (i / 4) * BOX;
        line([t, -BOX, F], [t, BOX, F], i === 0 ? "rgba(25,28,50,.16)" : "rgba(25,28,50,.07)");
        line([-BOX, t, F], [BOX, t, F], i === 0 ? "rgba(25,28,50,.16)" : "rgba(25,28,50,.07)");
      }
      const o = [-BOX, -BOX, F];
      line(o, [1.2, -BOX, F], "#9aa3b5", 1.4); line(o, [-BOX, 1.2, F], "#9aa3b5", 1.4); line(o, [-BOX, -BOX, 1.15], "#9aa3b5", 1.4);
      label([1.38, -BOX, F], lab[0] || "x"); label([-BOX, 1.38, F], lab[1] || "y"); label([-BOX, -BOX, 1.27], lab[2] || "z");

      const vis = P.filter(p => !st.hidden.has(String(p.g)));
      const dim = p => st.focus != null && String(p.g) !== st.focus;
      const shownG = G.filter(gr => !st.hidden.has(String(gr.g)) && gr.n);

      if (st.opt.ellipsoids) shownG.forEach(gr => gr.axes && drawEllipsoid(gr, st.focus != null && String(gr.g) !== st.focus));
      if (st.opt.plane && plane) {
        ctx.fillStyle = "rgba(25,28,50,.07)"; ctx.strokeStyle = "rgba(25,28,50,.5)"; ctx.lineWidth = 1.4; ctx.setLineDash([6, 4]);
        ctx.beginPath(); path(plane.poly, true); ctx.fill(); ctx.stroke(); ctx.setLineDash([]);
        const top = plane.poly.reduce((a, b) => (project(a).sy < project(b).sy ? a : b));
        const p = project(top); ctx.font = `600 11px ${C.FONT}`; ctx.textAlign = "center"; ctx.fillStyle = "#3a4050";
        ctx.fillText(`Separating plane · ${(100 * plane.accuracy).toFixed(0)}% on the correct side`, Math.max(120, Math.min(w - 120, p.sx)), Math.max(60, p.sy - 8));
      }
      if (st.opt.drops) vis.forEach(p => { if (!dim(p)) line(p.w, [p.w[0], p.w[1], F], css(rgb(col[p.g]), 0.18)); });
      if (st.opt.spokes) shownG.forEach(gr => vis.filter(p => p.g === gr.g && !dim(p)).forEach(p => line(p.w, gr.m, css(rgb(col[gr.g]), 0.22))));
      if (st.opt.drops) vis.forEach(p => { const q = project([p.w[0], p.w[1], F]); ctx.fillStyle = css(rgb(col[p.g]), dim(p) ? 0.05 : 0.22); ctx.beginPath(); ctx.ellipse(q.sx, q.sy, 3, 1.6, 0, 0, 2 * Math.PI); ctx.fill(); });

      // back to front; points shrink and fade slightly with distance
      proj = vis.map(p => ({ p, ...project(p.w) })).sort((a, b) => b.depth - a.depth);
      const base = vis.length > 400 ? 4 : vis.length > 150 ? 5.5 : 7;
      proj.forEach(q => {
        const r = base * (q.k / (Math.min(w, h) * 0.3 * st.view.zoom)) * Math.sqrt(st.view.zoom) * (q === hover ? 1.5 : 1);
        ctx.globalAlpha = dim(q.p) ? 0.1 : 0.55 + 0.45 * Math.min(1, Math.max(0, (1.6 - q.depth) / 2.4));
        ctx.drawImage(sprites[q.p.g], q.sx - r, q.sy - r, 2 * r, 2 * r);
        q.r = r;
      });
      ctx.globalAlpha = 1;
      if (hover) { ctx.strokeStyle = "#191c32"; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(hover.sx, hover.sy, hover.r + 2.5, 0, 2 * Math.PI); ctx.stroke(); }

      if (st.opt.centroids) shownG.forEach(gr => {
        const q = project(gr.m), cc = rgb(col[gr.g]);
        ctx.fillStyle = "#fff"; ctx.strokeStyle = css(cc); ctx.lineWidth = 3;
        ctx.beginPath(); ctx.arc(q.sx, q.sy, 9, 0, 2 * Math.PI); ctx.fill(); ctx.stroke();
        ctx.fillStyle = css(cc); ctx.beginPath(); ctx.arc(q.sx, q.sy, 3.5, 0, 2 * Math.PI); ctx.fill();
        ctx.font = `700 12px ${C.FONT}`; ctx.textAlign = "left";
        ctx.lineWidth = 4; ctx.strokeStyle = "rgba(255,255,255,.9)"; ctx.strokeText(String(gr.g), q.sx + 13, q.sy + 4);
        ctx.fillStyle = "#191c32"; ctx.fillText(String(gr.g), q.sx + 13, q.sy + 4);
      });
    }
    const sprites = Object.fromEntries(groups.map(g => [g, sprite(col[g])]));

    // interaction: everything redraws on demand, nothing animates by itself
    let dragging = false, px = 0, py = 0, queued = false;
    const later = () => { if (!queued) { queued = true; requestAnimationFrame(() => { queued = false; render(); }); } };
    cv.addEventListener("pointerdown", e => { dragging = true; px = e.clientX; py = e.clientY; cv.setPointerCapture(e.pointerId); tip.hide(); });
    cv.addEventListener("pointerup", () => { dragging = false; });
    cv.addEventListener("pointermove", e => {
      if (dragging) {
        st.view.yaw += (e.clientX - px) * 0.009;
        st.view.pitch = Math.max(-0.2, Math.min(1.45, st.view.pitch + (e.clientY - py) * 0.007));
        px = e.clientX; py = e.clientY; later(); return;
      }
      const r = cv.getBoundingClientRect(), mx = e.clientX - r.left, my = e.clientY - r.top;
      let best = null;   // front-most point under the cursor
      proj.forEach(q => { if (Math.hypot(q.sx - mx, q.sy - my) <= Math.max(8, q.r || 0) && (!best || q.depth < best.depth)) best = q; });
      if (best !== hover) { hover = best; later(); }
      cv.style.cursor = best ? "pointer" : "grab";
      best ? tip.show(e, best.p.tip || best.p.id) : tip.hide();
    });
    cv.addEventListener("pointerleave", () => { hover = null; tip.hide(); later(); });
    cv.addEventListener("dblclick", () => { st.view = { yaw: -0.7, pitch: 0.42, zoom: 1 }; later(); });
    ctl.addEventListener("click", e => {
      const b = e.target.closest("button"); if (!b) return;
      if (b.dataset.o) { st.opt[b.dataset.o] = !st.opt[b.dataset.o]; b.classList.toggle("on", st.opt[b.dataset.o]); }
      if (b.dataset.z) st.view.zoom = Math.max(0.4, Math.min(4, st.view.zoom * +b.dataset.z));
      if (b.dataset.reset) st.view = { yaw: -0.7, pitch: 0.42, zoom: 1 };
      later();
    });
    st.onFocus = later;

    render();
    legend(host, groups.map(k => ({ key: k, color: solid(col[k]) })), st, redraw, spec.groupTitle);
  };
})();
