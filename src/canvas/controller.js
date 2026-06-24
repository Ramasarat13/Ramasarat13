import { fabric } from 'fabric'
import { useStore } from '../store/useStore'
import { applyEffectsToImage } from './effects'

// Module-level singleton that wraps a Fabric.js canvas and exposes imperative
// methods to the React layer. The Fabric canvas is the source of truth for
// geometry; layer metadata is mirrored into the Zustand store for the UI.

let canvas = null
let suspendHistory = false
let history = { past: [], future: [], labels: [] }
const HISTORY_LIMIT = 50
let uid = 0
const nextId = () => `ly_${Date.now().toString(36)}_${uid++}`
const SERIALIZE_PROPS = ['id', 'name', 'locked', 'effects', 'adjustments', 'layerType', 'maskShape']

const TYPE_LABEL = { image: 'Image', text: 'Text', shape: 'Shape' }

function store() {
  return useStore.getState()
}

// ---- Selection control styling (accent handles) ----
function styleControls() {
  fabric.Object.prototype.set({
    transparentCorners: false,
    cornerColor: '#c8f04a',
    cornerStrokeColor: '#14160a',
    cornerStyle: 'circle',
    cornerSize: 10,
    borderColor: '#c8f04a',
    borderScaleFactor: 1.5,
    rotatingPointOffset: 28,
    padding: 2,
  })
}

export const controller = {
  // ---------- lifecycle ----------
  init(el) {
    if (canvas) return canvas
    styleControls()
    const { project } = store()
    canvas = new fabric.Canvas(el, {
      width: project.width,
      height: project.height,
      backgroundColor: project.background,
      preserveObjectStacking: true,
      selection: true,
      fireRightClick: true,
      stopContextMenu: true,
    })

    canvas.on('object:added', () => !suspendHistory && this.commit('Add layer'))
    canvas.on('object:removed', () => !suspendHistory && this.commit('Delete layer'))
    canvas.on('object:modified', (e) => {
      this.syncLayers()
      if (!suspendHistory) this.commit(this.modifyLabel(e))
    })
    canvas.on('selection:created', () => this.syncSelection())
    canvas.on('selection:updated', () => this.syncSelection())
    canvas.on('selection:cleared', () => this.syncSelection())
    canvas.on('object:moving', (e) => this.handleSnap(e))
    canvas.on('object:scaling', () => this.syncSelection())
    canvas.on('object:rotating', () => this.syncSelection())
    canvas.on('mouse:up', () => this.clearGuides())
    canvas.on('text:changed', () => {
      store().bumpRev()
    })
    // Explicitly enter editing on double-click (robust under CSS-scaled canvas).
    canvas.on('mouse:dblclick', (e) => {
      const t = e.target
      if (t && (t.type === 'textbox' || t.type === 'i-text') && !t.locked && !t.isEditing) {
        t.enterEditing()
        if (t.hiddenTextarea) t.hiddenTextarea.focus()
        canvas.renderAll()
      }
    })
    canvas.on('text:editing:exited', () => {
      this.syncLayers()
      this.commit('Edit text')
    })

    // When any web font finishes loading, re-measure + re-render text so it
    // doesn't stay stuck in the fallback typeface.
    if (typeof document !== 'undefined' && document.fonts) {
      document.fonts.addEventListener('loadingdone', () => {
        if (!canvas) return
        canvas.getObjects().forEach((o) => {
          if (o.type === 'textbox' || o.type === 'i-text') o.initDimensions?.()
        })
        canvas.requestRenderAll()
      })
    }

    this.applyBackground(project.background)
    this.commit('New poster', true)
    return canvas
  },

  dispose() {
    if (canvas) {
      canvas.dispose()
      canvas = null
    }
    history = { past: [], future: [], labels: [] }
  },

  get() {
    return canvas
  },

  modifyLabel(e) {
    const t = e?.target
    if (!t) return 'Edit layer'
    const action = t.__action || 'Move'
    return `${action} ${t.name || 'layer'}`
  },

  // ---------- history ----------
  snapshot() {
    const json = canvas.toJSON(SERIALIZE_PROPS)
    // Image filters are rebuilt from `effects` + `adjustments` on restore, so we
    // strip the serialized `filters` array. Custom filters (Duotone, Dither, …)
    // aren't registered with Fabric's revival map and would break loadFromJSON.
    if (json.objects) {
      json.objects.forEach((o) => {
        if (o.filters) delete o.filters
      })
    }
    return JSON.stringify(json)
  },

  commit(label = 'Edit', isInitial = false) {
    if (!canvas) return
    const snap = this.snapshot()
    if (!isInitial) {
      history.past.push({ snap, label })
      if (history.past.length > HISTORY_LIMIT + 1) history.past.shift()
      history.future = []
    } else {
      history.past = [{ snap, label }]
      history.future = []
    }
    this.syncLayers()
    this.pushHistoryState()
  },

  pushHistoryState() {
    store().setHistoryState({
      canUndo: history.past.length > 1,
      canRedo: history.future.length > 0,
    })
  },

  undo() {
    if (history.past.length <= 1) return
    const current = history.past.pop()
    history.future.push(current)
    const prev = history.past[history.past.length - 1]
    this.restore(prev.snap)
  },

  redo() {
    if (!history.future.length) return
    const next = history.future.pop()
    history.past.push(next)
    this.restore(next.snap)
  },

  restore(snap) {
    suspendHistory = true
    canvas.loadFromJSON(snap, () => {
      // re-apply image adjustments + effects after deserialize
      canvas.getObjects().forEach((o) => {
        if (o.layerType === 'image') {
          applyEffectsToImage(o, o.effects)
        }
      })
      canvas.renderAll()
      suspendHistory = false
      this.syncLayers()
      this.syncSelection()
      this.pushHistoryState()
    })
  },

  historyList() {
    return history.past.map((h, i) => ({ index: i, label: h.label }))
  },

  jumpTo(index) {
    if (index < 0 || index >= history.past.length) return
    const target = history.past[index]
    // everything after `index` moves to future (reverse order)
    const removed = history.past.splice(index + 1)
    history.future.push(...removed.reverse())
    this.restore(target.snap)
  },

  // ---------- sync to store ----------
  syncLayers() {
    if (!canvas) return
    const objs = canvas.getObjects()
    // top of stack first for the panel
    const layers = objs
      .map((o) => ({
        id: o.id,
        name: o.name,
        type: o.layerType || 'shape',
        visible: o.visible !== false,
        locked: !!o.locked,
        effects: o.effects || [],
      }))
      .reverse()
    store().setLayers(layers)
  },

  syncSelection() {
    if (!canvas) return
    const active = canvas.getActiveObjects()
    store().setSelectedIds(active.map((o) => o.id).filter(Boolean))
  },

  // ---------- naming ----------
  autoName(type) {
    const base = TYPE_LABEL[type] || 'Layer'
    const existing = canvas.getObjects().filter((o) => (o.name || '').startsWith(base))
    return `${base} ${existing.length + 1}`
  },

  // ---------- add layers ----------
  centerOn(obj) {
    obj.set({
      left: canvas.getWidth() / 2,
      top: canvas.getHeight() / 2,
      originX: 'center',
      originY: 'center',
    })
  },

  addImageFromUrl(url, opts = {}) {
    fabric.Image.fromURL(
      url,
      (img) => {
        const maxW = canvas.getWidth() * 0.7
        const maxH = canvas.getHeight() * 0.7
        const scale = Math.min(maxW / img.width, maxH / img.height, 1)
        img.scale(scale)
        img.set({
          id: nextId(),
          name: this.autoName('image'),
          layerType: 'image',
          effects: [],
          adjustments: { brightness: 0, contrast: 0, saturation: 0, hue: 0 },
          ...opts,
        })
        this.centerOn(img)
        canvas.add(img)
        canvas.setActiveObject(img)
        canvas.renderAll()
      },
      { crossOrigin: 'anonymous' }
    )
  },

  addText(text = 'Your text here', opts = {}) {
    const tb = new fabric.Textbox(text, {
      id: nextId(),
      name: this.autoName('text'),
      layerType: 'text',
      effects: [],
      editable: true,
      fontFamily: 'Inter',
      fontSize: Math.round(canvas.getWidth() * 0.06),
      fill: '#111111',
      width: canvas.getWidth() * 0.6,
      textAlign: 'left',
      ...opts,
    })
    this.centerOn(tb)
    canvas.add(tb)
    canvas.setActiveObject(tb)
    canvas.renderAll()
    return tb
  },

  addTextStack(blocks) {
    // blocks: [{text, size, weight}], stacked vertically as a group
    const objs = []
    let top = 0
    blocks.forEach((b) => {
      const tb = new fabric.Textbox(b.text, {
        id: nextId(),
        name: this.autoName('text'),
        layerType: 'text',
        effects: [],
        fontFamily: 'DM Sans',
        fontWeight: b.weight || 'normal',
        fontSize: b.size,
        fill: '#111111',
        top,
        left: 0,
        width: canvas.getWidth() * 0.7,
      })
      objs.push(tb)
      top += b.size * 1.4 + 12
    })
    const group = new fabric.Group(objs, {
      id: nextId(),
      name: this.autoName('text'),
      layerType: 'text',
      effects: [],
    })
    this.centerOn(group)
    canvas.add(group)
    canvas.setActiveObject(group)
    canvas.renderAll()
  },

  addShape(shape) {
    const w = canvas.getWidth()
    const size = w * 0.25
    const common = {
      id: nextId(),
      name: this.autoName('shape'),
      layerType: 'shape',
      effects: [],
      fill: '#c8f04a',
      originX: 'center',
      originY: 'center',
      left: w / 2,
      top: canvas.getHeight() / 2,
    }
    let obj
    switch (shape) {
      case 'rect':
        obj = new fabric.Rect({ ...common, width: size, height: size * 0.7 })
        break
      case 'roundRect':
        obj = new fabric.Rect({ ...common, width: size, height: size * 0.7, rx: 24, ry: 24 })
        break
      case 'circle':
        obj = new fabric.Circle({ ...common, radius: size / 2 })
        break
      case 'triangle':
        obj = new fabric.Triangle({ ...common, width: size, height: size })
        break
      case 'line':
        obj = new fabric.Line([0, 0, size, 0], {
          ...common,
          fill: undefined,
          stroke: '#c8f04a',
          strokeWidth: 8,
        })
        break
      case 'star':
        obj = new fabric.Polygon(starPoints(5, size / 2, size / 4), common)
        break
      case 'hexagon':
        obj = new fabric.Polygon(polygonPoints(6, size / 2), common)
        break
      case 'diamond':
        obj = new fabric.Polygon(
          [
            { x: 0, y: -size / 2 },
            { x: size / 2, y: 0 },
            { x: 0, y: size / 2 },
            { x: -size / 2, y: 0 },
          ],
          common
        )
        break
      case 'arrow':
        obj = new fabric.Polygon(arrowPoints(size), common)
        break
      default:
        obj = new fabric.Rect({ ...common, width: size, height: size })
    }
    canvas.add(obj)
    canvas.setActiveObject(obj)
    canvas.renderAll()
  },

  // ---------- background ----------
  applyBackground(value) {
    // value: hex string OR { type:'gradient', ... } OR { type:'pattern', ... }
    if (typeof value === 'string') {
      canvas.setBackgroundColor(value, () => canvas.renderAll())
      store().setProject({ background: value })
    } else if (value && value.type === 'gradient') {
      const grad = makeGradient(value, canvas.getWidth(), canvas.getHeight())
      canvas.setBackgroundColor(grad, () => canvas.renderAll())
      store().setProject({ background: value })
    } else if (value && value.type === 'pattern') {
      applyPatternBackground(canvas, value)
      store().setProject({ background: value })
    }
    if (!suspendHistory) this.commit('Change background')
  },

  // ---------- selected object helpers ----------
  active() {
    return canvas?.getActiveObject() || null
  },

  selectById(id, additive = false) {
    const obj = canvas.getObjects().find((o) => o.id === id)
    if (!obj) return
    if (additive) {
      const current = canvas.getActiveObjects()
      const sel = new fabric.ActiveSelection([...current, obj], { canvas })
      canvas.setActiveObject(sel)
    } else {
      canvas.setActiveObject(obj)
    }
    canvas.renderAll()
  },

  selectAll() {
    const objs = canvas.getObjects().filter((o) => o.visible !== false && !o.locked)
    if (!objs.length) return
    const sel = new fabric.ActiveSelection(objs, { canvas })
    canvas.setActiveObject(sel)
    canvas.renderAll()
  },

  updateActive(patch, label) {
    const obj = this.active()
    if (!obj) return
    if (label) obj.__action = label
    obj.set(patch)
    obj.setCoords()
    canvas.renderAll()
    this.syncSelection()
    this.commit(label || `Edit ${obj.name || 'layer'}`)
  },

  // live update without committing history (for slider/dial drag)
  liveUpdate(patch) {
    const obj = this.active()
    if (!obj) return
    obj.set(patch)
    obj.setCoords()
    canvas.renderAll()
    store().bumpRev()
  },

  commitLive(label) {
    this.commit(label || 'Edit layer')
  },

  // ---------- layer operations ----------
  byId(id) {
    return canvas.getObjects().find((o) => o.id === id)
  },

  toggleVisibility(id) {
    const o = this.byId(id)
    if (!o) return
    o.visible = o.visible === false
    canvas.discardActiveObject()
    canvas.renderAll()
    this.commit(`${o.visible ? 'Show' : 'Hide'} ${o.name}`)
  },

  toggleLock(id) {
    const o = this.byId(id)
    if (!o) return
    o.locked = !o.locked
    o.set({
      selectable: !o.locked,
      evented: !o.locked,
      lockMovementX: o.locked,
      lockMovementY: o.locked,
    })
    if (o.locked) canvas.discardActiveObject()
    canvas.renderAll()
    this.commit(`${o.locked ? 'Lock' : 'Unlock'} ${o.name}`)
  },

  renameLayer(id, name) {
    const o = this.byId(id)
    if (!o) return
    o.name = name
    this.commit('Rename layer')
  },

  deleteSelected() {
    const objs = canvas.getActiveObjects()
    if (!objs.length) return
    objs.forEach((o) => canvas.remove(o))
    canvas.discardActiveObject()
    canvas.renderAll()
    this.commit('Delete layer')
  },

  duplicateSelected() {
    const obj = this.active()
    if (!obj) return
    obj.clone(
      (clone) => {
        clone.set({
          id: nextId(),
          name: this.autoName(obj.layerType),
          left: (obj.left || 0) + 24,
          top: (obj.top || 0) + 24,
        })
        if (obj.effects) clone.effects = JSON.parse(JSON.stringify(obj.effects))
        canvas.add(clone)
        canvas.setActiveObject(clone)
        if (clone.layerType === 'image' && clone.effects?.length) {
          applyEffectsToImage(clone, clone.effects)
        }
        canvas.renderAll()
        this.commit('Duplicate layer')
      },
      SERIALIZE_PROPS
    )
  },

  reorder(fromId, toIndexFromTop) {
    // panel is top-first; convert to fabric stack index (bottom-first)
    const o = this.byId(fromId)
    if (!o) return
    const total = canvas.getObjects().length
    const targetStackIndex = total - 1 - toIndexFromTop
    canvas.moveTo(o, Math.max(0, Math.min(total - 1, targetStackIndex)))
    canvas.renderAll()
    this.commit('Reorder layers')
  },

  bringToFront() {
    const o = this.active()
    if (o) {
      o.bringToFront()
      canvas.renderAll()
      this.commit('Move to front')
    }
  },
  sendToBack() {
    const o = this.active()
    if (o) {
      o.sendToBack()
      canvas.renderAll()
      this.commit('Move to back')
    }
  },
  bringForward() {
    const o = this.active()
    if (o) {
      o.bringForward()
      canvas.renderAll()
      this.commit('Move up')
    }
  },
  sendBackward() {
    const o = this.active()
    if (o) {
      o.sendBackwards()
      canvas.renderAll()
      this.commit('Move down')
    }
  },

  groupSelected() {
    const active = canvas.getActiveObject()
    if (!active || active.type !== 'activeSelection') return
    active.toGroup()
    const g = canvas.getActiveObject()
    g.set({ id: nextId(), name: this.autoName('shape'), layerType: 'shape', effects: [] })
    canvas.renderAll()
    this.commit('Group layers')
  },

  flip(axis) {
    const o = this.active()
    if (!o) return
    if (axis === 'h') o.set('flipX', !o.flipX)
    else o.set('flipY', !o.flipY)
    canvas.renderAll()
    this.commit(`Flip ${axis === 'h' ? 'horizontal' : 'vertical'}`)
  },

  // ---------- alignment (for active selection) ----------
  align(mode) {
    const sel = canvas.getActiveObject()
    if (!sel || sel.type !== 'activeSelection') return
    const objs = sel.getObjects()
    const w = sel.width
    const h = sel.height
    objs.forEach((o) => {
      const ow = o.getScaledWidth()
      const oh = o.getScaledHeight()
      switch (mode) {
        case 'left': o.set('left', -w / 2); break
        case 'center-h': o.set('left', -ow / 2); break
        case 'right': o.set('left', w / 2 - ow); break
        case 'top': o.set('top', -h / 2); break
        case 'middle': o.set('top', -oh / 2); break
        case 'bottom': o.set('top', h / 2 - oh); break
        default: break
      }
      o.setCoords()
    })
    canvas.renderAll()
    this.commit('Align layers')
  },

  distribute(axis) {
    const sel = canvas.getActiveObject()
    if (!sel || sel.type !== 'activeSelection') return
    const objs = [...sel.getObjects()]
    const key = axis === 'h' ? 'left' : 'top'
    objs.sort((a, b) => a[key] - b[key])
    if (objs.length < 3) return
    const first = objs[0][key]
    const last = objs[objs.length - 1][key]
    const step = (last - first) / (objs.length - 1)
    objs.forEach((o, i) => {
      o.set(key, first + step * i)
      o.setCoords()
    })
    canvas.renderAll()
    this.commit('Distribute layers')
  },

  // ---------- snapping & smart guides ----------
  handleSnap(e) {
    const o = e.target
    if (!o) return
    const threshold = 6 / (store().zoom || 1)
    const cw = canvas.getWidth()
    const ch = canvas.getHeight()
    const bounds = o.getBoundingRect(true)
    const cx = bounds.left + bounds.width / 2
    const cy = bounds.top + bounds.height / 2

    const guides = []
    // canvas centers + edges
    const xTargets = [
      { pos: 0, type: 'edge' },
      { pos: cw / 2, type: 'center' },
      { pos: cw, type: 'edge' },
    ]
    const yTargets = [
      { pos: 0, type: 'edge' },
      { pos: ch / 2, type: 'center' },
      { pos: ch, type: 'edge' },
    ]
    // other objects
    canvas.getObjects().forEach((other) => {
      if (other === o) return
      const b = other.getBoundingRect(true)
      xTargets.push({ pos: b.left }, { pos: b.left + b.width / 2 }, { pos: b.left + b.width })
      yTargets.push({ pos: b.top }, { pos: b.top + b.height / 2 }, { pos: b.top + b.height })
    })

    for (const t of xTargets) {
      if (Math.abs(cx - t.pos) < threshold) {
        o.left += t.pos - cx
        guides.push({ x: t.pos })
        break
      }
    }
    for (const t of yTargets) {
      if (Math.abs(cy - t.pos) < threshold) {
        o.top += t.pos - cy
        guides.push({ y: t.pos })
        break
      }
    }
    this.drawGuides(guides)
    store().bumpRev()
  },

  drawGuides(guides) {
    const ctx = canvas.getSelectionContext()
    canvas.clearContext(ctx)
    canvas.renderAll()
    const vt = canvas.viewportTransform
    ctx.save()
    ctx.strokeStyle = '#c8f04a'
    ctx.lineWidth = 1
    guides.forEach((g) => {
      ctx.beginPath()
      if (g.x !== undefined) {
        const x = g.x * vt[0] + vt[4]
        ctx.moveTo(x, 0)
        ctx.lineTo(x, canvas.getHeight() * vt[3] + vt[5])
      } else if (g.y !== undefined) {
        const y = g.y * vt[3] + vt[5]
        ctx.moveTo(0, y)
        ctx.lineTo(canvas.getWidth() * vt[0] + vt[4], y)
      }
      ctx.stroke()
    })
    ctx.restore()
  },

  clearGuides() {
    if (!canvas) return
    canvas.renderAll()
  },

  // ---------- effects ----------
  setEffects(id, effects) {
    const o = id ? this.byId(id) : this.active()
    if (!o) return
    o.effects = effects
    if (o.layerType === 'image') applyEffectsToImage(o, effects)
    canvas.renderAll()
    this.syncLayers()
    this.commit('Update effects')
  },

  // ---------- shape mask (crop image/shape into a vector silhouette) ----------
  setMask(shape) {
    const o = this.active()
    if (!o) return
    o.maskShape = shape
    if (!shape || shape === 'none') {
      o.clipPath = null
    } else {
      // clipPath lives in the object's own (unscaled) coordinate space, centred
      const w = o.width
      const h = o.height
      const s = Math.min(w, h)
      const common = { originX: 'center', originY: 'center', left: 0, top: 0 }
      let clip
      switch (shape) {
        case 'circle':
          clip = new fabric.Circle({ ...common, radius: s / 2 })
          break
        case 'rounded':
          clip = new fabric.Rect({ ...common, width: w, height: h, rx: s * 0.12, ry: s * 0.12 })
          break
        case 'triangle':
          clip = new fabric.Triangle({ ...common, width: w, height: h })
          break
        case 'hexagon':
          clip = new fabric.Polygon(polygonPoints(6, s / 2), common)
          break
        case 'diamond':
          clip = new fabric.Polygon(
            [
              { x: 0, y: -h / 2 },
              { x: w / 2, y: 0 },
              { x: 0, y: h / 2 },
              { x: -w / 2, y: 0 },
            ],
            common
          )
          break
        case 'star':
          clip = new fabric.Polygon(starPoints(5, s / 2, s / 4), common)
          break
        case 'isometric':
          // a rhombus / isometric tile (2:1 diamond)
          clip = new fabric.Polygon(
            [
              { x: 0, y: -h / 2 },
              { x: w / 2, y: 0 },
              { x: 0, y: h / 2 },
              { x: -w / 2, y: 0 },
            ],
            { ...common, scaleY: 0.58 }
          )
          break
        case 'parallelogram': {
          const skew = w * 0.22
          clip = new fabric.Polygon(
            [
              { x: -w / 2 + skew, y: -h / 2 },
              { x: w / 2, y: -h / 2 },
              { x: w / 2 - skew, y: h / 2 },
              { x: -w / 2, y: h / 2 },
            ],
            common
          )
          break
        }
        default:
          clip = null
      }
      o.clipPath = clip
    }
    canvas.renderAll()
    this.commit(shape && shape !== 'none' ? `Mask to ${shape}` : 'Remove mask')
  },

  // ---------- canvas size ----------
  resizeCanvas(width, height) {
    canvas.setWidth(width)
    canvas.setHeight(height)
    store().setProject({ width, height })
    // re-apply gradient/pattern bg to new dimensions
    const bg = store().project.background
    if (typeof bg === 'object') this.applyBackground(bg)
    canvas.renderAll()
    this.commit('Resize canvas')
  },

  // ---------- zoom ----------
  // The Fabric canvas always renders at full poster resolution; zoom is applied
  // as a CSS transform on the wrapper (handled in CanvasStage). This keeps
  // exports crisp regardless of on-screen zoom.
  setZoomTo(zoom) {
    zoom = Math.max(0.1, Math.min(4, Math.round(zoom * 100) / 100))
    store().setZoom(zoom)
  },

  // ---------- export ----------
  exportImage({ format = 'png', quality = 0.92, multiplier = 1, selectionOnly = false }) {
    const wasGrid = store().showGrid
    canvas.discardActiveObject()
    canvas.renderAll()
    let opts = { format: format === 'jpeg' ? 'jpeg' : format, quality, multiplier }
    if (selectionOnly) {
      const obj = this.active()
      if (obj) {
        const b = obj.getBoundingRect()
        opts = { ...opts, left: b.left, top: b.top, width: b.width, height: b.height }
      }
    }
    if (format === 'svg') {
      return { svg: canvas.toSVG() }
    }
    return { dataUrl: canvas.toDataURL(opts) }
  },
}

// ---------- geometry helpers ----------
function polygonPoints(sides, radius, rotation = -Math.PI / 2) {
  const pts = []
  for (let i = 0; i < sides; i++) {
    const a = rotation + (i * 2 * Math.PI) / sides
    pts.push({ x: radius * Math.cos(a), y: radius * Math.sin(a) })
  }
  return pts
}

function starPoints(spikes, outer, inner) {
  const pts = []
  let rot = -Math.PI / 2
  const step = Math.PI / spikes
  for (let i = 0; i < spikes; i++) {
    pts.push({ x: Math.cos(rot) * outer, y: Math.sin(rot) * outer })
    rot += step
    pts.push({ x: Math.cos(rot) * inner, y: Math.sin(rot) * inner })
    rot += step
  }
  return pts
}

function arrowPoints(size) {
  const s = size
  return [
    { x: -s / 2, y: -s / 8 },
    { x: s / 6, y: -s / 8 },
    { x: s / 6, y: -s / 3 },
    { x: s / 2, y: 0 },
    { x: s / 6, y: s / 3 },
    { x: s / 6, y: s / 8 },
    { x: -s / 2, y: s / 8 },
  ]
}

function makeGradient(value, w, h) {
  const stops = value.stops.map((s) => ({ offset: s.offset, color: s.color }))
  if (value.gradType === 'radial') {
    return new fabric.Gradient({
      type: 'radial',
      coords: { x1: w / 2, y1: h / 2, r1: 0, x2: w / 2, y2: h / 2, r2: Math.max(w, h) / 2 },
      colorStops: stops,
    })
  }
  const angle = ((value.angle || 0) * Math.PI) / 180
  const x1 = w / 2 - (Math.cos(angle) * w) / 2
  const y1 = h / 2 - (Math.sin(angle) * h) / 2
  const x2 = w / 2 + (Math.cos(angle) * w) / 2
  const y2 = h / 2 + (Math.sin(angle) * h) / 2
  return new fabric.Gradient({
    type: 'linear',
    coords: { x1, y1, x2, y2 },
    colorStops: stops,
  })
}

function applyPatternBackground(canvas, value) {
  const tile = document.createElement('canvas')
  const scale = value.scale || 32
  tile.width = scale
  tile.height = scale
  const ctx = tile.getContext('2d')
  ctx.fillStyle = value.bg || '#ffffff'
  ctx.fillRect(0, 0, scale, scale)
  ctx.strokeStyle = value.fg || '#111111'
  ctx.fillStyle = value.fg || '#111111'
  ctx.lineWidth = Math.max(1, scale / 16)
  switch (value.pattern) {
    case 'dots':
      ctx.beginPath()
      ctx.arc(scale / 2, scale / 2, scale / 6, 0, Math.PI * 2)
      ctx.fill()
      break
    case 'grid':
      ctx.strokeRect(0, 0, scale, scale)
      break
    case 'diagonal':
      ctx.beginPath()
      ctx.moveTo(0, scale)
      ctx.lineTo(scale, 0)
      ctx.stroke()
      break
    case 'crosshatch':
      ctx.beginPath()
      ctx.moveTo(0, scale)
      ctx.lineTo(scale, 0)
      ctx.moveTo(0, 0)
      ctx.lineTo(scale, scale)
      ctx.stroke()
      break
    case 'checker':
      ctx.fillRect(0, 0, scale / 2, scale / 2)
      ctx.fillRect(scale / 2, scale / 2, scale / 2, scale / 2)
      break
    case 'triangles':
      ctx.beginPath()
      ctx.moveTo(scale / 2, 0)
      ctx.lineTo(scale, scale)
      ctx.lineTo(0, scale)
      ctx.closePath()
      ctx.fill()
      break
    default:
      break
  }
  const pattern = new fabric.Pattern({ source: tile, repeat: 'repeat' })
  canvas.setBackgroundColor(pattern, () => canvas.renderAll())
}
