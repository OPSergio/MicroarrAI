# MicroarrAI · Frontend Lab

Aislado del resto de la app a propósito. Aquí se diseña y se itera el nuevo
frontend (landing/index) sin tocar la plataforma Shiny. Cuando una versión esté
buena, se porta a `www/` y se integra como `index.html` / UI de Shiny.

## Qué hay

Landing estilo **21st.dev** (limpio, glass, gradientes) con una **proteína 3D
reactiva al scroll** que sustituye el viejo efecto de "tiles":

| Sección                | `data-stage` | Qué hace la proteína                          |
|------------------------|--------------|-----------------------------------------------|
| Hero / Preprocessing   | `intro`      | Cartoon neutro (sin color), girando suave     |
| Differential analysis  | `color`      | Se colorea por expresión (blanco → verde)     |
| Machine learning       | `biomarkers` | Aparecen los biomarcadores en naranja         |
| 3D visualization / cierre | `focus`   | La cámara hace zoom sobre los biomarcadores   |

Paleta heredada de la app: fondo `#191c32`, verde `#90EE90`, naranja
biomarcadores `#ff6b35`, teal `#18BC9C`.

## Stack

- HTML + **Tailwind Play CDN** (estética 21st.dev hecha a mano, sin build).
- **NGL.js** para la proteína (mismas estructuras AlphaFold que el panel 3D).
- Sin dependencias que instalar. Solo necesita conexión (CDNs + AlphaFold).

## Cómo verlo

```bash
cd frontend-lab
python3 -m http.server 5500
# abrir http://localhost:5500
```

## Notas de implementación

- Las clases de componentes (`.card`, `.btn-primary`, `.nav-link`…) usan
  `@apply` y van **inline** en `<style type="text/tailwindcss">` dentro de
  `index.html`: el Play CDN no compila `@apply` desde `.css` externos.
- `js/main.js` → `applyStage(stage)` controla la proteína; el scroll lo dispara
  vía `IntersectionObserver` leyendo `data-stage` de cada `.panel`.
- **Perf:** las 3 superficies (gris / verde / biomarcadores) se **pre-construyen
  al cargar** con el color horneado; las transiciones solo hacen **crossfade de
  `opacity`** (un uniform), nunca recolorean ni reconstruyen geometría en caliente
  — eso es lo que evita los tirones. Ojo también con `backdrop-blur` sobre el
  canvas que gira: se recalcula cada frame, por eso las cards no lo usan.
- Datos de expresión y biomarcadores son **sintéticos** (solo para la demo).
  Al integrar en Shiny se sustituyen por los reales vía `postMessage`, igual que
  `www/ngl_viewer.html`.

## Pendiente / ideas

- Tailwind por CDN es solo para prototipar; al integrar conviene CSS compilado.
- Migrar el navbar nuevo y el patrón scroll a `R/ui/ui_home.R` + `www/`.
