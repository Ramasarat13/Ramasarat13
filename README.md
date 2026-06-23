# PosterCraft

A browser-based poster builder for non-designers — beautiful, print- and
social-ready posters with no design experience required. Fluid like Figma,
approachable like Canva, with a dark creative-studio personality of its own.

![PosterCraft](https://img.shields.io/badge/canvas-Fabric.js-c8f04a) ![React](https://img.shields.io/badge/react-18-1a1a1c)

## Stack

- **React 18 + Vite** — UI and build
- **Fabric.js** — canvas compositing engine (layers, text, images, transforms, filters)
- **Zustand** — app/layer/history/selection state
- **Google Fonts** — loaded on-demand in the font picker

## Getting started

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # production bundle in dist/
npm run preview  # serve the production build
```

## Features

**Canvas setup** — 13 social/print presets plus custom sizing with an aspect-ratio
lock (100–8000px), each animating into the editor.

**Editor** — three-column studio layout (Layers/Assets · Canvas · Properties) with
an editable project title, zoom controls, fit-to-screen, grid and ruler toggles,
undo/redo, and a context-sensitive properties panel.

**Canvas** — Fabric-powered selection with accent-colored handles, drag/scale/
rotate, snap-to guides (canvas centers, edges, other layers), CSS-scaled zoom
(10–400%) that keeps exports crisp, space-drag panning, an 8px grid overlay,
draggable rulers/guides, an empty-state ghost, and a floating mini-toolbar
(opacity, flip, delete).

**Layers** — visibility/lock toggles, inline rename, drag-to-reorder, right-click
context menu (rename/duplicate/delete/move), shift multi-select, accent selection
border.

**Assets** — multi-image upload (JPG/PNG/WEBP/SVG/GIF, 20MB cap) with drag-to-
canvas, a 9-shape vector library, solid/gradient/pattern backgrounds, and
pre-built text templates.

**Properties** — transform (X/Y/W/H with ratio lock, rotation dial, flip),
appearance (opacity, 10 blend modes), live image adjustments (brightness/
contrast/saturation/hue), and full text controls (font, size, weight, line
height, letter spacing, alignment, color, background fill).

**Effects** — a stackable, reorderable effect pipeline: Dither (Ordered/
Floyd-Steinberg/Atkinson), Halftone, Glitch (with a re-randomize dice),
Grain, Patterns, Vignette, Color Duotone, and Blur — all implemented as
Fabric 2D image filters.

**Font picker** — searchable modal with Popular, All Google Fonts, and Browse-by-
Style tabs, live in-font previews (loaded lazily via IntersectionObserver),
editable sample text, variant pills, and a selected-font checkmark.

**Palette generator** — extracts a 5-color dominant palette from any image and
suggests complementary/analogous/triadic harmonies; click a swatch to apply,
and save palettes for reuse.

**Export** — PNG/JPEG/WEBP/SVG, quality control, 1×/2×/3×/custom retina scaling,
full-canvas or selection-only crop, editable filename, and a shimmer-then-
download button.

**Workflow** — alignment & distribution tools (2+ layers), a clickable 50-step
history panel, toast notifications, and full keyboard shortcuts (press `?`).

## Project structure

```
src/
  canvas/
    controller.js   # Fabric singleton: layers, history, transforms, export
    effects.js      # custom 2D image filters + effect metadata
  components/
    properties/     # context-sensitive right-panel sections
    ...             # setup, editor shell, panels, modals
  data/             # size presets + font catalogue
  store/            # Zustand store
  styles/           # design tokens + app styles
```
