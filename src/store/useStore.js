import { create } from 'zustand'

let toastId = 0

export const useStore = create((set, get) => ({
  // ---- App phase ----
  phase: 'setup', // 'setup' | 'editor'

  // ---- Project / canvas ----
  project: {
    name: 'Untitled poster',
    width: 1080,
    height: 1080,
    background: '#ffffff',
  },

  // ---- Layers (mirror of fabric objects, top of array = top of stack) ----
  layers: [],
  selectedIds: [],
  rev: 0, // bumped whenever the active object's geometry/props change

  // ---- Viewport ----
  zoom: 1,
  showGrid: false,
  showRulers: false,
  units: 'px',

  // ---- History ----
  history: { past: [], future: [], labels: [] },
  canUndo: false,
  canRedo: false,

  // ---- UI ----
  ui: {
    fontPickerOpen: false,
    exportOpen: false,
    shortcutsOpen: false,
    paletteOpen: false,
    historyOpen: false,
    leftTab: 'layers', // 'layers' | 'assets'
    assetsTab: 'images', // 'images' | 'shapes' | 'backgrounds'
    activeTool: 'select', // 'select' | 'text' | 'pan'
  },

  // ---- Asset library ----
  uploadedImages: [], // { id, url, name }
  savedPalettes: [], // array of arrays of hex

  // ---- Toasts ----
  toasts: [],

  // ===== Actions =====
  startProject: (project) =>
    set({ phase: 'editor', project: { ...get().project, ...project } }),

  setProject: (patch) => set({ project: { ...get().project, ...patch } }),

  setLayers: (layers) => set({ layers }),
  setSelectedIds: (ids) => set({ selectedIds: ids, rev: get().rev + 1 }),
  bumpRev: () => set((s) => ({ rev: s.rev + 1 })),

  setZoom: (zoom) => set({ zoom }),
  toggleGrid: () => set((s) => ({ showGrid: !s.showGrid })),
  toggleRulers: () => set((s) => ({ showRulers: !s.showRulers })),
  setUnits: (units) => set({ units }),

  setUI: (patch) => set((s) => ({ ui: { ...s.ui, ...patch } })),

  setHistoryState: ({ canUndo, canRedo }) => set({ canUndo, canRedo }),

  addUploadedImage: (img) =>
    set((s) => ({ uploadedImages: [img, ...s.uploadedImages] })),

  savePalette: (palette) =>
    set((s) => ({ savedPalettes: [palette, ...s.savedPalettes].slice(0, 12) })),

  pushToast: (message, kind = 'info') => {
    const id = ++toastId
    set((s) => ({ toasts: [...s.toasts, { id, message, kind }] }))
    setTimeout(() => {
      set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }))
    }, 4200)
    return id
  },
  dismissToast: (id) =>
    set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
}))
