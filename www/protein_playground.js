/* ===========================================================================
 * protein_playground.js — linked 2D(D3) + 3D(3Dmol) protein explorer.
 *
 * One dataset (both isotypes x both groups + per-peptide FDR) drives every view:
 *   Colour by: Expression | Δ(caso−tolerante) | IgE−IgG4
 *   Biomarkers filtered by an FDR slider.
 * Hovering a residue in the strip / 2D / 3D highlights it everywhere and shows a
 * rich tooltip (full AA name, position, biomarker, fold change, expression, PTM,
 * disulfide partner).
 * =========================================================================== */
(function () {
  const AA = {
    A: "Alanine", R: "Arginine", N: "Asparagine", D: "Aspartate", C: "Cysteine",
    E: "Glutamate", Q: "Glutamine", G: "Glycine", H: "Histidine", I: "Isoleucine",
    L: "Leucine", K: "Lysine", M: "Methionine", F: "Phenylalanine", P: "Proline",
    S: "Serine", T: "Threonine", W: "Tryptophan", Y: "Tyrosine", V: "Valine"
  };
  const ISO_COL = { IgE: "#00897b", IgG4: "#c62828" };
  const DIV_RANGE = ["#2166ac", "#f7f7f7", "#b2182b"];   // RdBu diverging
  const NA_COL = "#e2e2e2", SIG_COL = "#7d898d", BM_COL = "#ff6b35";
  const PTM_COL = "#c026d3", SS_COL = "#e6b800", HILITE = "#ffd60a";

  const PV = {
    idx: {}, posInfo: {}, posList: [], disulfides: [], ssPartner: {},
    isotypes: [], groups: [], chain: "A", pdb: null, uniprot: null,
    v: { isotype: "IgE", group: "caso", mode: "expr", fdr: 0.05, surface: false, biomarkers: true },
    viewer: null, loadedKey: null, hl: null, seq: null, div: null, lastXY: { x: 0, y: 0 }
  };
  window.PV = PV;

  const key = (iso, grp, pos) => iso + "|" + grp + "|" + pos;
  const row = (iso, grp, pos) => PV.idx[key(iso, grp, pos)];
  const exprOf = (iso, grp, pos) => { const r = row(iso, grp, pos); return r ? r.expr : null; };

  // -------- values & scales (mode aware) --------
  function valueAt(pos) {
    const v = PV.v;
    if (v.mode === "expr") return exprOf(v.isotype, v.group, pos);
    if (v.mode === "dgroup") {
      const a = exprOf(v.isotype, PV.groups[0], pos), b = exprOf(v.isotype, PV.groups[1], pos);
      return (a == null || b == null) ? null : a - b;
    }
    const e = exprOf("IgE", v.group, pos), g = exprOf("IgG4", v.group, pos);   // diso
    return (e == null || g == null) ? null : e - g;
  }
  function rebuildScales() {
    const v = PV.v;
    const expVals = PV.posList.map(p => exprOf(v.isotype, v.group, p)).filter(x => x != null);
    const em = d3.max(expVals, Math.abs) || 1;
    PV.seq = d3.scaleLinear().domain([0, em]).range(["#ffffff", ISO_COL[v.isotype]]).clamp(true);
    const dm = d3.max(PV.posList.map(p => Math.abs(valueAt(p) || 0))) || 1;
    PV.div = d3.scaleDiverging().domain([-dm, 0, dm]).interpolator(d3.interpolateRgbBasis(DIV_RANGE));
    PV._dm = dm; PV._em = em;
  }
  function colorAt(pos) {
    if (PV.posInfo[pos] && PV.posInfo[pos].is_signal) return SIG_COL;
    const val = valueAt(pos);
    if (val == null) return NA_COL;
    return PV.v.mode === "expr" ? PV.seq(val) : PV.div(val);
  }
  function isBiomarker(pos) {
    const r = row(PV.v.isotype, PV.v.group, pos);
    // padj may be absent (real pipeline): then show the selected biomarker regardless
    return PV.v.biomarkers && r && r.is_biomarker && (r.padj == null || r.padj <= PV.v.fdr);
  }
  function foldChange(pos) {
    const a = exprOf(PV.v.isotype, PV.groups[0], pos), b = exprOf(PV.v.isotype, PV.groups[1], pos);
    return (a == null || b == null) ? null : a - b;
  }

  // serpentine layout (port of R posiciones)
  function posiciones(n, altura, pte) {
    let x = 0, y = 0, e = "SN"; const res = [];
    for (let i = 0; i < n; i++) {
      if (e === "SN") { y += 1; res.push({ x, y }); if (y === altura) e = "SA"; continue; }
      if (e === "SA") { x += .5; y += .5; res.push({ x, y }); if (y === altura + pte) e = "DA"; continue; }
      if (e === "DA") { x += .5; y -= .5; res.push({ x, y }); if (y === altura) e = "DN"; continue; }
      if (e === "DN") { y -= 1; res.push({ x, y }); if (y === 0) e = "DB"; continue; }
      if (e === "DB") { x += .5; y -= .5; res.push({ x, y }); if (y === -pte) e = "SB"; continue; }
      if (e === "SB") { x += .5; y += .5; res.push({ x, y }); if (y === 0) e = "SN"; continue; }
    }
    return res;
  }

  // ---------------------------------------------------------------- tooltip
  function tip() {
    let t = d3.select("body").select(".pv-tip");
    if (t.empty()) t = d3.select("body").append("div").attr("class", "pv-tip");
    return t;
  }
  function showTip(pos) {
    const info = PV.posInfo[pos]; if (!info) return;
    const r = row(PV.v.isotype, PV.v.group, pos);
    const fc = foldChange(pos), ss = PV.ssPartner[pos];
    tip().html(
      "<b>" + (AA[info.aa] || info.aa) + " " + pos + "</b>" +
      "<br>Biomarker: " + (isBiomarker(pos) ? ("Yes" + (r && r.padj != null ? " (FDR " + r.padj.toExponential(1) + ")" : "")) : "No") +
      "<br>Fold change (caso−tol): " + (fc == null ? "NA" : fc.toFixed(2)) +
      "<br>Expression (" + PV.v.isotype + "/" + PV.v.group + "): " + (r && r.expr != null ? r.expr.toFixed(2) : "NA") +
      (info.mod ? "<br><span style='color:#e7a6f5'>PTM: " + info.mod + "</span>" : "") +
      (ss ? "<br><span style='color:#ffe08a'>Disulfide ↔ Cys" + ss + "</span>" : "") +
      (info.is_signal ? "<br>Signal peptide" : "")
    ).style("left", (PV.lastXY.x + 14) + "px").style("top", (PV.lastXY.y - 8) + "px")
      .transition().duration(80).style("opacity", 1);
  }
  function hideTip() { tip().transition().duration(120).style("opacity", 0); }
  document.addEventListener("mousemove", e => { PV.lastXY = { x: e.pageX, y: e.pageY }; });

  // ---------------------------------------------------------------- top strip
  function buildStrip() {
    d3.select("#pv-strip").html("").selectAll(".pv-aa").data(PV.posList).join("div")
      .attr("class", p => "pv-aa" + (isBiomarker(p) ? " bm" : ""))
      .text(p => PV.posInfo[p].aa)
      .on("mouseenter", (e, p) => highlight(p)).on("mouseleave", clearHighlight);
  }

  // ------------------------------------------------------------------ 2D snake
  function build2D() {
    const coords = posiciones(PV.posList.length, 17, 1);
    const xy = {}; PV.posList.forEach((p, i) => xy[p] = coords[i]);
    const step = 11, r = 4.6, pad = 9;
    const xs = coords.map(c => c.x), ys = coords.map(c => c.y);
    const W = (Math.max(...xs) - Math.min(...xs)) * step + pad * 2 + 14;
    const H = (Math.max(...ys) - Math.min(...ys)) * step + pad * 2;
    const sx = p => (xy[p].x - Math.min(...xs)) * step + pad + 7;
    const sy = p => H - ((xy[p].y - Math.min(...ys)) * step + pad);

    const svg = d3.select("#pv-2d").html("").append("svg")
      .attr("viewBox", `0 0 ${W} ${H}`).attr("preserveAspectRatio", "xMidYMid meet")
      .attr("width", "100%").attr("height", "100%");

    svg.append("path").attr("fill", "none").attr("stroke", "#c4c8d0").attr("stroke-width", 1)
      .attr("d", d3.line().x(sx).y(sy)(PV.posList));

    const ss = PV.disulfides.filter(p => xy[p[0]] && xy[p[1]]);
    svg.selectAll(".ss").data(ss).join("line")
      .attr("x1", p => sx(p[0])).attr("y1", p => sy(p[0])).attr("x2", p => sx(p[1])).attr("y2", p => sy(p[1]))
      .attr("stroke", SS_COL).attr("stroke-width", 1.5).attr("stroke-dasharray", "3,2");

    const ptm = PV.posList.filter(p => PV.posInfo[p].mod);
    svg.selectAll(".ptm-l").data(ptm).join("line")
      .attr("x1", sx).attr("y1", sy).attr("x2", p => sx(p) + 8).attr("y2", p => sy(p) - 6)
      .attr("stroke", "#555").attr("stroke-width", 1);
    svg.selectAll(".ptm-d").data(ptm).join("circle")
      .attr("cx", p => sx(p) + 8).attr("cy", p => sy(p) - 6).attr("r", 2.6)
      .attr("fill", PTM_COL).attr("stroke", "#fff").attr("stroke-width", 0.7);

    const g = svg.selectAll(".pv-node").data(PV.posList).join("g").attr("class", "pv-node")
      .attr("transform", p => `translate(${sx(p)},${sy(p)})`).style("cursor", "pointer")
      .on("mouseenter", (e, p) => highlight(p)).on("mouseleave", clearHighlight);
    // biomarker halo lives INSIDE the node group so hovering it triggers the tooltip
    g.filter(isBiomarker).append("circle")
      .attr("r", r + 2.6).attr("fill", BM_COL).attr("opacity", 0.35);
    g.append("circle").attr("r", r).attr("fill", colorAt)
      .attr("stroke", p => isBiomarker(p) ? BM_COL : "#191c32").attr("stroke-width", p => isBiomarker(p) ? 1.3 : 0.4);
    g.append("text").text(p => PV.posInfo[p].aa).attr("text-anchor", "middle").attr("dy", "0.34em")
      .attr("font-size", "5px").attr("font-weight", "bold").attr("fill", "#191c32")
      .style("pointer-events", "none");
  }

  // ---------------------------------------------------------------- legend
  function legend() {
    const host = d3.select("#pv-legend").html("");
    const diverging = PV.v.mode !== "expr";
    const w = 150, h = 10, id = "pv-grad";
    const svg = host.append("svg").attr("width", w + 60).attr("height", 34);
    const defs = svg.append("defs").append("linearGradient").attr("id", id);
    const stops = diverging ? [[0, DIV_RANGE[0]], [50, DIV_RANGE[1]], [100, DIV_RANGE[2]]]
      : [[0, "#ffffff"], [100, ISO_COL[PV.v.isotype]]];
    stops.forEach(s => defs.append("stop").attr("offset", s[0] + "%").attr("stop-color", s[1]));
    svg.append("rect").attr("x", 20).attr("y", 4).attr("width", w).attr("height", h)
      .attr("fill", "url(#" + id + ")").attr("stroke", "#ccc");
    const lab = diverging ? ["−" + PV._dm.toFixed(1), "0", "+" + PV._dm.toFixed(1)] : ["0", "", PV._em.toFixed(1)];
    [0, w / 2, w].forEach((x, i) => svg.append("text").attr("x", 20 + x).attr("y", 28)
      .attr("text-anchor", "middle").attr("font-size", "10px").attr("fill", "#3a4050").text(lab[i]));
    svg.append("text").attr("x", 20 + w + 6).attr("y", 13).attr("font-size", "10px").attr("fill", "#3a4050")
      .text(diverging ? (PV.v.mode === "dgroup" ? "Δ groups" : "IgE−IgG4") : "expr");

    host.append("div").style("margin-top", "4px").style("font-size", "11px").html(
      "<span style='color:" + BM_COL + "'>●</span> biomarker &nbsp;" +
      "<span style='color:" + SIG_COL + "'>■</span> signal &nbsp;" +
      "<span style='color:" + PTM_COL + "'>●</span> PTM &nbsp;" +
      "<span style='color:" + SS_COL + "'>—</span> disulfide");
  }

  // ---------------------------------------------------------------------- 3D
  const sel = pos => ({ resi: pos, chain: PV.chain });
  function colorResidues() {
    const v = PV.viewer; if (!v) return;
    v.setStyle({}, {});
    v.setStyle({ chain: PV.chain }, { cartoon: { color: "#dddddd" } });
    PV.posList.forEach(p => v.setStyle(sel(p), { cartoon: { color: colorAt(p) } }));
    PV.posList.filter(isBiomarker).forEach(p => v.addStyle(sel(p), { stick: { radius: 0.3, color: BM_COL } }));
  }
  function addDisulfides() {
    const v = PV.viewer; if (!v) return;
    PV.disulfides.forEach(p => {
      try {
        const a = v.getModel().selectedAtoms({ resi: p[0], chain: PV.chain, atom: "CA" })[0];
        const b = v.getModel().selectedAtoms({ resi: p[1], chain: PV.chain, atom: "CA" })[0];
        if (a && b) v.addCylinder({ start: { x: a.x, y: a.y, z: a.z }, end: { x: b.x, y: b.y, z: b.z }, radius: 0.18, color: SS_COL, dashed: true });
      } catch (e) {}
    });
  }
  function colorMap() { const m = {}; PV.posList.forEach(p => m[p] = colorAt(p)); return m; }
  function updateSurface() {
    const v = PV.viewer; if (!v) return;
    v.removeAllSurfaces();
    if (PV.v.surface) v.addSurface($3Dmol.SurfaceType.VDW,
      { opacity: 0.7, colorscheme: { prop: "resi", map: colorMap() } }, { chain: PV.chain });
    v.render();
  }
  function structureDone() { if (window.Shiny) Shiny.setInputValue("pv_structure_loaded", Date.now(), { priority: "event" }); }
  function applyStructure() {
    colorResidues(); addDisulfides();
    PV.viewer.setHoverDuration(60);
    PV.viewer.setHoverable({}, true,
      a => { if (a && a.chain === PV.chain) highlight(a.resi); }, () => clearHighlight());
    PV.viewer.zoomTo({ chain: PV.chain }); updateSurface(); PV.viewer.render();
    structureDone();
  }
  function rebuild3D() {
    if (!window.$3Dmol) { setTimeout(rebuild3D, 200); return; }
    const k = PV.uniprot || PV.pdb;
    if (PV.viewer && PV.loadedKey === k) { colorResidues(); addDisulfides(); updateSurface(); PV.viewer.render(); return; }
    const el = document.getElementById("pv-3d"); el.innerHTML = "";
    PV.viewer = $3Dmol.createViewer(el, { backgroundColor: "white" });
    PV.loadedKey = k;
    if (PV.uniprot) {
      // AlphaFold publishes different model versions per entry — try newest first
      const versions = ["v6", "v4", "v3", "v2", "v1"];
      const tryOne = i => {
        if (i >= versions.length) { el.innerHTML = "<div style='padding:18px;color:#888;font:13px system-ui'>Could not load AlphaFold structure for " + PV.uniprot + "</div>"; structureDone(); return; }
        fetch("https://alphafold.ebi.ac.uk/files/AF-" + PV.uniprot + "-F1-model_" + versions[i] + ".pdb")
          .then(r => { if (!r.ok) throw new Error(r.status); return r.text(); })
          .then(txt => { PV.viewer.addModel(txt, "pdb"); applyStructure(); })
          .catch(() => tryOne(i + 1));
      };
      tryOne(0);
    } else {
      $3Dmol.download("pdb:" + PV.pdb, PV.viewer, {}, applyStructure);
    }
  }
  function hi3D(pos) { const v = PV.viewer; if (!v) return; v.addStyle(sel(pos), { sphere: { radius: 1.5, color: HILITE } }); v.render(); }
  function clr3D(pos) {
    const v = PV.viewer; if (!v || pos == null) return;
    v.setStyle(sel(pos), { cartoon: { color: colorAt(pos) } });
    if (isBiomarker(pos)) v.addStyle(sel(pos), { stick: { radius: 0.3, color: BM_COL } });
    v.render();
  }

  // ----------------------------------------------------------- cross highlight
  function highlight(pos) {
    if (PV.hl === pos) { showTip(pos); return; }
    if (PV.hl != null) clearHighlight();
    PV.hl = pos;
    d3.select("#pv-strip").selectAll(".pv-aa").classed("hl", p => p === pos);
    d3.select("#pv-2d").selectAll(".pv-node").select("circle")
      .attr("stroke", p => p === pos ? HILITE : (isBiomarker(p) ? BM_COL : "#191c32"))
      .attr("stroke-width", p => p === pos ? 2.4 : (isBiomarker(p) ? 1.3 : 0.4));
    hi3D(pos); showTip(pos);
  }
  function clearHighlight() {
    if (PV.hl == null) return;
    const prev = PV.hl; PV.hl = null;
    d3.select("#pv-strip").selectAll(".pv-aa").classed("hl", false);
    d3.select("#pv-2d").selectAll(".pv-node").select("circle")
      .attr("stroke", p => isBiomarker(p) ? BM_COL : "#191c32").attr("stroke-width", p => isBiomarker(p) ? 1.3 : 0.4);
    clr3D(prev); hideTip();
  }

  function redraw2D() { rebuildScales(); buildStrip(); build2D(); legend(); }
  function redrawAll() { redraw2D(); rebuild3D(); }

  // ------------------------------------------------------------- Shiny wiring
  if (window.Shiny) {
    Shiny.addCustomMessageHandler("loadProtein", function (m) {
      PV.idx = {}; PV.posInfo = {}; PV.posList = [];
      m.data.forEach(r => {
        PV.idx[key(r.isotype, r.group, r.pos)] = r;
        if (!PV.posInfo[r.pos]) { PV.posInfo[r.pos] = { aa: r.aa, is_signal: r.is_signal, mod: r.mod, peptide: r.peptide }; PV.posList.push(r.pos); }
      });
      PV.posList.sort((a, b) => a - b);
      PV.disulfides = (m.disulfides || []).map(p => Array.isArray(p) ? p : [p[0], p[1]]);
      PV.ssPartner = {}; PV.disulfides.forEach(p => { PV.ssPartner[p[0]] = p[1]; PV.ssPartner[p[1]] = p[0]; });
      PV.isotypes = m.isotypes; PV.groups = m.groups; PV.chain = m.chain || "A";
      PV.pdb = m.pdb; PV.uniprot = m.uniprot || null;
      if (m.view) PV.v = Object.assign(PV.v, m.view);
      redrawAll();
      setTimeout(structureDone, 30000);   // safety: never leave a loader stuck

    });
    Shiny.addCustomMessageHandler("setView", function (v) {
      PV.v = Object.assign(PV.v, v);
      redrawAll();
    });
  }
})();
