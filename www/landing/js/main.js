/* ============================================================================
 * MicroarrAI — Frontend Lab
 * Scroll-driven protein storytelling + navbar behavior.
 *
 * PERF MODEL (the important part):
 *   Recoloring a molecular surface on the fly is expensive — NGL rebuilds the
 *   per-vertex color buffer and re-uploads it to the GPU, stalling the main
 *   thread. Doing that mid-scroll always janks.
 *
 *   So instead we PRE-BUILD the three colored surfaces ONCE at load (the cost is
 *   paid while the loading spinner is up, and NGL tessellates in a web worker):
 *       intro      -> neutral grey surface
 *       color      -> expression surface (white -> green)
 *       biomarkers -> expression + orange biomarker patches
 *   A transition is then just a CROSSFADE of each layer's `opacity` (a uniform
 *   update — no geometry/color rebuild, no GPU upload). That can't jank.
 *
 *   `focus` reuses the biomarker layer and only moves the camera.
 * ============================================================================ */

const PROTEIN = 'P02663';            // default structure (kept from the app)
const SPIN = [0, 1, 0, 0.3];         // gentle idle rotation (axis + speed)
const SURFACE_SCALE = 1.3;           // surface resolution (lower = fewer triangles = faster)
const SURFACE_OPACITY = 0.92;        // visible layer opacity
const FADE_MS = 550;                 // crossfade duration between states

// palette (as [r,g,b])
const C_NEUTRAL = [199, 206, 230];   // #c7cee6 — uncolored
const C_SIGNAL  = [125, 137, 141];   // #7d898d — signal peptide
const C_ORANGE  = [255, 107, 53];    // #ff6b35 — biomarkers

const STATE = {
  stage: null, component: null,
  surfs: {},               // kind -> NGL surface representation (pre-built)
  activeKey: null,         // which layer is currently shown
  expression: {},          // resno -> 0..1
  biomarkerSet: new Set(),
  signalLength: 20,
  current: null,           // current scroll stage
  light: false,            // theme
  neutral: C_NEUTRAL.slice(), // intro color (changes with theme so it reads on white)
  raf: null,
};

/* ============================================================
   NGL SETUP
============================================================ */
async function initViewer() {
  STATE.stage = new NGL.Stage('viewport', {
    backgroundColor: '#191c32',
    quality: 'medium',   // 'high' adds geometry detail we don't need here
    sampleLevel: 0,      // disable SSAA supersampling — big perf win while spinning
    tooltip: false,
  });
  window.addEventListener('resize', () => STATE.stage.handleResize());

  try {
    await loadStructure(PROTEIN);
    document.getElementById('sceneLoading').style.display = 'none';
    STATE.stage.setSpin(SPIN.slice(0, 3), SPIN[3]);
    STATE.component.autoView();
    STATE.activeKey = 'intro';
    STATE.current = 'intro';
    setChip('AlphaFold structure · neutral');
  } catch (e) {
    document.getElementById('sceneLoading').innerHTML =
      '<span style="color:#9aa1bd">Could not load structure (offline?)</span>';
    console.error(e);
  }
}

async function loadStructure(uniprot) {
  const urls = [
    `https://alphafold.ebi.ac.uk/files/AF-${uniprot}-F1-model_v6.pdb`,
    `https://alphafold.ebi.ac.uk/files/AF-${uniprot}-F1-model_v4.pdb`,
  ];
  for (const url of urls) {
    try {
      STATE.component = await STATE.stage.loadFile(url, { defaultRepresentation: false });

      let maxRes = 0;
      STATE.component.structure.eachResidue(r => { if (r.resno > maxRes) maxRes = r.resno; });
      buildData(maxRes);

      // pre-build all three colored surfaces; only 'intro' starts visible
      ['intro', 'color', 'biomarkers'].forEach(kind => {
        STATE.surfs[kind] = STATE.component.addRepresentation('surface', {
          color: makeScheme(kind),
          opacity: kind === 'intro' ? SURFACE_OPACITY : 0,
          visible: kind === 'intro',
          surfaceType: 'sas',
          scaleFactor: SURFACE_SCALE,
        });
      });
      return;
    } catch (e) {
      console.warn('Failed:', url, e.message);
    }
  }
  throw new Error('No structure could be loaded');
}

/* synthetic expression + biomarker hotspots (prototype only) */
function buildData(maxRes) {
  for (let i = 1; i <= maxRes; i++) {
    const v = 0.5 + 0.32 * Math.sin(i / 14) + 0.18 * Math.sin(i / 5 + 1.3) + 0.12 * Math.sin(i / 37);
    STATE.expression[i] = Math.max(0, Math.min(1, v));
  }
  Object.entries(STATE.expression)
    .map(([k, v]) => [+k, v]).sort((a, b) => b[1] - a[1])
    .slice(0, Math.min(16, maxRes))
    .forEach(([resno]) => STATE.biomarkerSet.add(resno));
}

// white -> dark green (#00a86b) by expression value t (0..1)
function greenFor(t) {
  return [
    Math.round(255 * (1 - t * 0.996)),
    Math.round(255 - t * (255 - 168)),
    Math.round(255 * (1 - t * 0.581)),
  ];
}

// fixed per-residue color for a given stage (baked into a surface at build time)
function colorAt(kind, resno) {
  if (STATE.signalLength > 0 && resno <= STATE.signalLength) return C_SIGNAL;
  if (kind === 'intro') return STATE.neutral;
  const green = greenFor(STATE.expression[resno] ?? 0);
  if (kind === 'color') return green;
  return STATE.biomarkerSet.has(resno) ? C_ORANGE : green;   // biomarkers
}

function makeScheme(kind) {
  return NGL.ColormakerRegistry.addScheme(function () {
    this.atomColor = function (atom) {
      const c = colorAt(kind, atom.residue.resno);
      return (c[0] << 16) | (c[1] << 8) | c[2];
    };
  });
}

/* ============================================================
   STAGE TRANSITIONS  (opacity crossfade only — no rebuilds)
============================================================ */
function applyStage(stage, force = false) {
  if (!STATE.component) return;
  if (stage === STATE.current && !force) return;
  const prev = STATE.current;
  STATE.current = stage;

  setChip({
    intro: 'AlphaFold structure · neutral',
    color: 'Differential expression mapped',
    biomarkers: 'Candidate biomarkers highlighted',
    focus: 'Zoomed on biomarker region',
  }[stage]);

  const key = stage === 'focus' ? 'biomarkers' : stage;
  if (key !== STATE.activeKey) crossfade(STATE.activeKey, key);

  // camera: only move for focus; restore the wide spinning view when leaving it
  if (stage === 'focus') {
    STATE.stage.setSpin(false);
    STATE.component.autoView([...STATE.biomarkerSet].join(' or '), 1200);
  } else {
    if (prev === 'focus') STATE.component.autoView(1000);
    STATE.stage.setSpin(SPIN.slice(0, 3), SPIN[3]);
  }
}

/* crossfade two pre-built surface layers by animating their opacity uniforms */
function crossfade(fromKey, toKey, dur = FADE_MS) {
  if (STATE.raf) cancelAnimationFrame(STATE.raf);
  const fromRep = STATE.surfs[fromKey];
  const toRep = STATE.surfs[toKey];
  STATE.activeKey = toKey;

  toRep.setVisibility(true);
  toRep.setParameters({ opacity: 0 });

  const start = performance.now();
  const ease = t => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

  const frame = (now) => {
    const p = Math.min(1, (now - start) / dur);
    const e = ease(p);
    toRep.setParameters({ opacity: SURFACE_OPACITY * e });
    if (fromRep) fromRep.setParameters({ opacity: SURFACE_OPACITY * (1 - e) });
    if (p < 1) {
      STATE.raf = requestAnimationFrame(frame);
    } else {
      if (fromRep) { fromRep.setVisibility(false); fromRep.setParameters({ opacity: SURFACE_OPACITY }); }
      STATE.raf = null;
    }
  };
  STATE.raf = requestAnimationFrame(frame);
}

/* ============================================================
   STATUS CHIP
============================================================ */
let chipTimer = null;
function setChip(text) {
  const chip = document.getElementById('sceneChip');
  if (!chip) return;
  chip.textContent = text;
  chip.classList.add('is-visible');
  clearTimeout(chipTimer);
  chipTimer = setTimeout(() => chip.classList.remove('is-visible'), 2600);
}

/* ============================================================
   SCROLL ORCHESTRATION
============================================================ */
function initScroll() {
  const panels = Array.from(document.querySelectorAll('.panel'));
  const links = Array.from(document.querySelectorAll('#navLinks .nav-link'));

  const io = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting && entry.intersectionRatio >= 0.55) {
        const panel = entry.target;
        panel.classList.add('is-active');
        if (panel.dataset.stage) applyStage(panel.dataset.stage);
        links.forEach(l => l.classList.toggle('is-active', l.getAttribute('href') === '#' + panel.id));
      }
    });
  }, { threshold: [0.55] });
  panels.forEach(p => io.observe(p));

  const bar = document.getElementById('progressBar');
  const onScroll = () => {
    const h = document.documentElement;
    const max = h.scrollHeight - h.clientHeight;
    bar.style.width = (max > 0 ? (h.scrollTop / max) * 100 : 0) + '%';
  };
  document.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

/* ============================================================
   THEME (light/dark)
============================================================ */
function setTheme(light) {
  STATE.light = light;
  document.body.classList.toggle('light', light);
  STATE.neutral = light ? [120, 130, 162] : C_NEUTRAL.slice();
  if (STATE.stage) STATE.stage.setParameters({ backgroundColor: light ? '#eef1f6' : '#191c32' });
  if (STATE.surfs.intro) STATE.surfs.intro.setColor(makeScheme('intro')); // recolor neutral layer once
  const btn = document.getElementById('themeToggle');
  if (btn) btn.textContent = light ? '☾' : '☀';
}

/* ============================================================
   NAVBAR
============================================================ */
function initNav() {
  const burger = document.getElementById('navBurger');
  const menu = document.getElementById('mobileMenu');
  if (burger && menu) {
    burger.addEventListener('click', () => menu.classList.toggle('hidden'));
    menu.querySelectorAll('a').forEach(a => a.addEventListener('click', () => menu.classList.add('hidden')));
  }
  const toggle = document.getElementById('themeToggle');
  if (toggle) toggle.addEventListener('click', () => setTheme(!STATE.light));
}

/* ============================================================
   BOOT
============================================================ */
window.addEventListener('DOMContentLoaded', () => {
  initNav();
  initScroll();
  initViewer();
});

// theme switch driven by the parent app navbar (postMessage)
window.addEventListener('message', (e) => {
  const d = e.data;
  if (d && d.type === 'metis-theme') setTheme(!!d.light);
});

window.MA = STATE;
window.applyStage = applyStage;
