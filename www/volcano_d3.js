/* ===========================================================================
 * volcano_d3.js — native D3 volcano plot, fully client-side reactive.
 *
 * Status (Up/Down/NS), the Y metric (FDR vs p-value) and the threshold lines
 * are all recomputed in the browser from the current view, so moving a slider
 * or switching the axis recolours/relabels instantly (no server round-trip).
 *
 * Shiny -> JS:
 *   volcanoData {rows:[{peptide,isotype,log2FC,p,padj,neglog10_p,neglog10_padj,
 *                       nA,nB}], view}
 *   volcanoView {padjThr, lfcThr, yaxis:"padj"|"pval", facet, isotypes:[...]}
 * =========================================================================== */
(function () {
  const V = {
    rows: [],
    view: { padjThr: 0.05, lfcThr: 0.5, yaxis: "padj", facet: true, isotypes: ["IgE", "IgG4"] }
  };
  const COL = { Up: "#17a589", Down: "#e74c3c", NS: "#9CA3AF" };

  // significance uses the SAME metric shown on the axis (raw p or FDR)
  const sigOf = d => (V.view.yaxis === "pval" ? d.p : d.padj);
  const statusOf = d => {
    const s = sigOf(d);
    if (s == null || isNaN(s)) return "NS";
    if (s <= V.view.padjThr && d.log2FC >= V.view.lfcThr) return "Up";
    if (s <= V.view.padjThr && d.log2FC <= -V.view.lfcThr) return "Down";
    return "NS";
  };
  const yOf = d => (V.view.yaxis === "pval" ? d.neglog10_p : d.neglog10_padj);
  // threshold line sits at the slider value on whichever metric is displayed
  const thresholdY = () => -Math.log10(V.view.padjThr);

  function tip() {
    let t = d3.select("body").select(".volcano-tip");
    if (t.empty()) t = d3.select("body").append("div").attr("class", "volcano-tip")
      .style("position", "absolute").style("pointer-events", "none").style("opacity", 0)
      .style("background", "rgba(25,28,50,.94)").style("color", "#fff").style("padding", "8px 10px")
      .style("border-radius", "6px").style("font", "12px/1.5 'Space Grotesk', system-ui, sans-serif")
      .style("z-index", 10000).style("max-width", "240px");
    return t;
  }

  function drawPanel(host, rows, title, width) {
    const yLab = V.view.yaxis === "pval" ? "-log10(p-value)" : "-log10(FDR, BH)";
    const m = { t: 30, r: 16, b: 44, l: 52 }, h = 470;
    const w = Math.max(width, 260);
    const iw = w - m.l - m.r, ih = h - m.t - m.b;

    const yv = rows.map(yOf).filter(Number.isFinite);
    const xv = rows.map(d => d.log2FC).filter(Number.isFinite);
    const xmax = Math.max(1, ...xv.map(Math.abs)) * 1.05;
    const x = d3.scaleLinear().domain([-xmax, xmax]).range([0, iw]);
    const y = d3.scaleLinear().domain([0, (d3.max(yv) || 1) * 1.08]).range([ih, 0]);

    const svg = host.append("svg").attr("width", w).attr("height", h);
    const g = svg.append("g").attr("transform", `translate(${m.l},${m.t})`);

    g.append("g").attr("transform", `translate(0,${ih})`).call(d3.axisBottom(x).ticks(6));
    g.append("g").call(d3.axisLeft(y).ticks(6));
    g.append("text").attr("x", iw / 2).attr("y", ih + 36).attr("text-anchor", "middle")
      .attr("font-size", 12).attr("fill", "#3a4050").text("Mean difference (B − A)");
    g.append("text").attr("transform", "rotate(-90)").attr("x", -ih / 2).attr("y", -38)
      .attr("text-anchor", "middle").attr("font-size", 12).attr("fill", "#3a4050").text(yLab);
    if (title) g.append("text").attr("x", iw / 2).attr("y", -12).attr("text-anchor", "middle")
      .attr("font-size", 13).attr("font-weight", 600).attr("fill", "#191c32").text(title);

    // threshold guides
    const ty = y(thresholdY());
    g.append("line").attr("x1", 0).attr("x2", iw).attr("y1", ty).attr("y2", ty)
      .attr("stroke", "#888").attr("stroke-dasharray", "4,3");
    [-V.view.lfcThr, V.view.lfcThr].forEach(v =>
      g.append("line").attr("x1", x(v)).attr("x2", x(v)).attr("y1", 0).attr("y2", ih)
        .attr("stroke", "#888").attr("stroke-dasharray", "4,3"));

    const t = tip();
    g.selectAll("circle").data(rows.filter(d => Number.isFinite(yOf(d)))).join("circle")
      .attr("cx", d => x(d.log2FC)).attr("cy", d => y(yOf(d))).attr("r", 3.6)
      .attr("fill", d => COL[statusOf(d)]).attr("opacity", 0.85)
      .attr("stroke", "#191c32").attr("stroke-width", 0.3)
      .on("mousemove", (e, d) => t.html(
        "<b>" + d.peptide + "</b><br>Isotype: " + d.isotype +
        "<br>Mean diff: " + d.log2FC.toFixed(2) + " · " + statusOf(d) +
        "<br>p: " + (d.p == null ? "NA" : d.p.toExponential(2)) +
        " · FDR: " + (d.padj == null ? "NA" : d.padj.toExponential(2)) +
        "<br>nA: " + d.nA + "  nB: " + d.nB)
        .style("left", (e.pageX + 12) + "px").style("top", (e.pageY - 10) + "px")
        .transition().duration(60).style("opacity", 1))
      .on("mouseleave", () => t.transition().duration(120).style("opacity", 0));
  }

  function legend(host) {
    const l = host.append("div").style("text-align", "center").style("margin-top", "4px")
      .style("font", "12px 'Space Grotesk', system-ui, sans-serif");
    [["Up", COL.Up], ["Down", COL.Down], ["NS", COL.NS]].forEach(s =>
      l.append("span").style("margin", "0 10px")
        .html("<span style='color:" + s[1] + "'>●</span> " + s[0]));
  }

  function render() {
    const host = d3.select("#volcano-d3"); if (host.empty()) return;
    host.html("");
    const rows = V.rows.filter(d => V.view.isotypes.indexOf(d.isotype) !== -1);
    const isos = Array.from(new Set(rows.map(d => d.isotype)));
    const total = host.node().clientWidth || 900;

    if (V.view.facet && isos.length > 1) {
      const row = host.append("div").style("display", "flex").style("gap", "10px");
      const pw = (total - 10 * (isos.length - 1)) / isos.length;
      isos.forEach(iso => {
        const cell = row.append("div");
        drawPanel(cell, rows.filter(d => d.isotype === iso), iso, pw);
      });
    } else {
      drawPanel(host, rows, isos.join(" + "), total);
    }
    legend(host);
  }

  if (window.Shiny) {
    Shiny.addCustomMessageHandler("volcanoData", function (m) {
      V.rows = m.rows || [];
      if (m.view) V.view = Object.assign(V.view, m.view);
      render();
    });
    Shiny.addCustomMessageHandler("volcanoView", function (m) {
      V.view = Object.assign(V.view, m);
      render();
    });
    // redraw on container resize (responsive)
    let rt; window.addEventListener("resize", function () { clearTimeout(rt); rt = setTimeout(render, 150); });
  }
})();
