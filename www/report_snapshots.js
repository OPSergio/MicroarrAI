/* ===========================================================================
 * report_snapshots.js — pictures of the protein views for the PDF report
 *
 * Every protein shown in the 3D tab is captured (3D structure from 3Dmol, the
 * 2D sequence map rasterised from its SVG) and kept per UniProt accession.
 * Clicking "Report" sends all of them to the server as input$report_snapshots.
 * =========================================================================== */
(function () {
  const snaps = {};

  function svgToPng(svg) {
    return new Promise(resolve => {
      if (!svg) return resolve(null);
      const w = +svg.getAttribute("width") || svg.clientWidth, h = +svg.getAttribute("height") || svg.clientHeight;
      if (!w || !h) return resolve(null);
      const clone = svg.cloneNode(true); clone.setAttribute("xmlns", "http://www.w3.org/2000/svg");
      const img = new Image(), k = Math.min(2, 1600 / w), cv = document.createElement("canvas");
      cv.width = w * k; cv.height = h * k;
      img.onload = () => { const c = cv.getContext("2d"); c.fillStyle = "#fff"; c.fillRect(0, 0, cv.width, cv.height); c.drawImage(img, 0, 0, cv.width, cv.height); resolve(cv.toDataURL("image/png")); };
      img.onerror = () => resolve(null);
      img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(clone.outerHTML);
    });
  }

  async function capture() {
    const PV = window.PV;
    if (!PV || !PV.uniprot) return;
    let view3d = null;
    try { if (PV.viewer) { PV.viewer.render(); view3d = PV.viewer.pngURI(); } } catch (e) { view3d = null; }
    const map2d = await svgToPng(document.querySelector("#pv-2d svg"));
    const sel = document.getElementById("protein_name");
    snaps[PV.uniprot] = {
      accession: PV.uniprot, protein: sel ? sel.value : PV.uniprot, pdb: PV.pdb || "",
      isotype: PV.v.isotype || "", group: PV.v.group || "", mode: PV.v.mode || "", view3d, map2d
    };
  }

  // after a structure loads (and the colours settle), and right before the report opens
  if (window.Shiny) {
    $(document).on("shiny:inputchanged", e => { if (e.name === "pv_structure_loaded") setTimeout(capture, 1500); });
  }
  document.addEventListener("click", async e => {
    if (!e.target.closest("#metis-report-btn")) return;
    e.stopImmediatePropagation();
    await capture();
    Shiny.setInputValue("report_snapshots", JSON.stringify(Object.values(snaps)));   // a string: Shiny would turn a list of objects into a data frame
    Shiny.setInputValue("open_report", Math.random(), { priority: "event" });
  }, true);
})();
