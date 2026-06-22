/* ===========================================================================
 * venn_d3.js — interactive feature-overlap (Venn) for the ML consensus panel.
 *
 * 2–3 models  -> proper circle Venn; hovering any region shows its peptides.
 * 4+ models   -> interactive intersection list (4-circle Venns are unreadable),
 *                each row hoverable for its peptides.
 *
 * Shiny -> JS:  vennData {sets:[{name, features:[...]}], colors:[...]}
 * =========================================================================== */
(function () {
  const FONT = "'Space Grotesk', system-ui, sans-serif";

  // circle layouts + region centroids (viewBox 500x400). keys = sorted 1-based idx
  const LAYOUT = {
    2: {
      circles: [{ x: 195, y: 200, r: 115 }, { x: 305, y: 200, r: 115 }],
      labels: [{ x: 120, y: 70 }, { x: 380, y: 70 }],
      regions: { "1": [135, 200], "2": [365, 200], "12": [250, 200] }
    },
    3: {
      circles: [{ x: 190, y: 175, r: 105 }, { x: 310, y: 175, r: 105 }, { x: 250, y: 270, r: 105 }],
      labels: [{ x: 110, y: 70 }, { x: 390, y: 70 }, { x: 250, y: 390 }],
      regions: {
        "1": [145, 140], "2": [355, 140], "3": [250, 320],
        "12": [250, 130], "13": [180, 240], "23": [320, 240], "123": [250, 205]
      }
    }
  };

  function tip() {
    let t = d3.select("body").select(".venn-tip");
    if (t.empty()) t = d3.select("body").append("div").attr("class", "venn-tip")
      .style("position", "absolute").style("pointer-events", "none").style("opacity", 0)
      .style("background", "rgba(25,28,50,.94)").style("color", "#fff").style("padding", "8px 10px")
      .style("border-radius", "6px").style("font", "12px/1.5 " + FONT)
      .style("z-index", 10000).style("max-width", "260px");
    return t;
  }
  function showTip(e, title, members) {
    const list = members.slice(0, 25).join(", ") + (members.length > 25 ? " …" : "");
    tip().html("<b>" + title + "</b> · " + members.length +
      "<br><span style='opacity:.85'>" + (members.length ? list : "—") + "</span>")
      .style("left", (e.pageX + 12) + "px").style("top", (e.pageY - 10) + "px")
      .transition().duration(60).style("opacity", 1);
  }
  const hideTip = () => tip().transition().duration(120).style("opacity", 0);

  // group features by which sets contain them -> { "1":[..], "12":[..], ... }
  function regionsOf(sets) {
    const all = {};
    sets.forEach((s, i) => s.features.forEach(f => {
      (all[f] = all[f] || []).push(i + 1);
    }));
    const reg = {};
    Object.keys(all).forEach(f => {
      const key = all[f].sort((a, b) => a - b).join("");
      (reg[key] = reg[key] || []).push(f);
    });
    return reg;
  }
  const comboName = (key, sets) => key.split("").map(i => sets[+i - 1].name).join(" ∩ ");

  function drawVenn(host, sets, colors) {
    const n = sets.length, L = LAYOUT[n];
    const reg = regionsOf(sets);
    const svg = host.append("svg").attr("viewBox", "0 0 500 400")
      .attr("width", "100%").attr("style", "max-height:430px");

    L.circles.forEach((c, i) => svg.append("circle")
      .attr("cx", c.x).attr("cy", c.y).attr("r", c.r)
      .attr("fill", colors[i % colors.length]).attr("fill-opacity", 0.32)
      .attr("stroke", colors[i % colors.length]).attr("stroke-width", 2));
    L.labels.forEach((p, i) => svg.append("text").attr("x", p.x).attr("y", p.y)
      .attr("text-anchor", "middle").attr("font", "600 15px " + FONT)
      .attr("fill", "#191c32").text(sets[i].name));

    Object.keys(L.regions).forEach(key => {
      const members = reg[key] || [], pos = L.regions[key];
      const g = svg.append("g").attr("transform", "translate(" + pos[0] + "," + pos[1] + ")")
        .style("cursor", members.length ? "pointer" : "default");
      g.append("circle").attr("r", 22).attr("fill", "transparent");  // hit area
      g.append("text").attr("text-anchor", "middle").attr("dy", "0.35em")
        .attr("font", "700 16px " + FONT).attr("fill", "#191c32").text(members.length);
      if (members.length) g
        .on("mousemove", e => showTip(e, comboName(key, sets), members))
        .on("mouseleave", hideTip);
    });
  }

  function drawList(host, sets, colors) {
    const reg = regionsOf(sets);
    const keys = Object.keys(reg).sort((a, b) => reg[b].length - reg[a].length);
    host.append("div").style("font", "600 13px " + FONT).style("color", "#8a8f98")
      .style("margin-bottom", "8px").text("Intersections (" + sets.length + " models)");
    const rows = host.append("div").style("display", "flex").style("flex-direction", "column").style("gap", "4px");
    keys.forEach(key => {
      const members = reg[key];
      const row = rows.append("div")
        .style("display", "flex").style("justify-content", "space-between").style("align-items", "center")
        .style("padding", "8px 10px").style("border-radius", "6px").style("cursor", "pointer")
        .style("background", key.length > 1 ? "rgba(24,188,156,0.10)" : "#f4f6f8")
        .style("font", "13px " + FONT)
        .on("mousemove", e => showTip(e, comboName(key, sets), members))
        .on("mouseleave", hideTip);
      row.append("span").html(key.split("").map(i =>
        "<span style='color:" + colors[(+i - 1) % colors.length] + "'>●</span> " + sets[+i - 1].name).join(" ∩ "));
      row.append("span").style("font-weight", 700).text(members.length);
    });
  }

  if (window.Shiny) {
    Shiny.addCustomMessageHandler("vennData", function (m) {
      const host = d3.select("#venn-d3"); if (host.empty()) return;
      host.html("");
      const sets = (m.sets || []).filter(s => s.features && s.features.length);
      const colors = m.colors || ["#1F78B4", "#18BC9C", "#CCBE93", "#E31A1C"];
      if (sets.length < 2) { host.append("div").style("color", "#888").style("font", "13px " + FONT)
        .text("Select at least two models to compare."); return; }
      if (sets.length <= 3) drawVenn(host, sets, colors);
      else drawList(host, sets, colors);
    });
  }
})();
