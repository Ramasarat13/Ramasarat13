import { fabric } from 'fabric'

// ---- Effect metadata used by the Effects picker UI ----
export const EFFECT_DEFS = {
  dither: {
    label: 'Dither',
    params: {
      algorithm: { type: 'select', label: 'Algorithm', options: ['Ordered', 'Floyd-Steinberg', 'Atkinson'], default: 'Ordered' },
      intensity: { type: 'range', label: 'Intensity', min: 0, max: 100, default: 60 },
      colorMode: { type: 'select', label: 'Color mode', options: ['Monochrome', '2-color', 'Full color'], default: 'Monochrome' },
      scale: { type: 'range', label: 'Scale (px)', min: 1, max: 8, default: 1 },
    },
  },
  halftone: {
    label: 'Halftone',
    params: {
      dotSize: { type: 'range', label: 'Dot size', min: 2, max: 24, default: 6 },
      angle: { type: 'range', label: 'Angle', min: 0, max: 180, default: 45 },
      shape: { type: 'select', label: 'Shape', options: ['Circle', 'Line', 'Cross'], default: 'Circle' },
      fg: { type: 'color', label: 'Foreground', default: '#111111' },
      bg: { type: 'color', label: 'Background', default: '#ffffff' },
    },
  },
  glitch: {
    label: 'Glitch',
    params: {
      slice: { type: 'range', label: 'Slice shift', min: 0, max: 100, default: 30 },
      rgb: { type: 'range', label: 'RGB split', min: 0, max: 40, default: 10 },
      seed: { type: 'seed', label: 'Seed', default: 1 },
      intensity: { type: 'range', label: 'Intensity', min: 0, max: 100, default: 50 },
    },
  },
  grain: {
    label: 'Grain / Film noise',
    params: {
      size: { type: 'range', label: 'Grain size', min: 1, max: 6, default: 1 },
      opacity: { type: 'range', label: 'Opacity', min: 0, max: 100, default: 40 },
      blend: { type: 'select', label: 'Blend', options: ['Overlay', 'Soft Light', 'Screen'], default: 'Overlay' },
    },
  },
  pattern: {
    label: 'Pattern',
    params: {
      pattern: { type: 'select', label: 'Pattern', options: ['Grid', 'Dots', 'Diagonal Lines', 'Cross-hatch', 'Checkerboard', 'Triangles'], default: 'Dots' },
      fg: { type: 'color', label: 'Foreground', default: '#111111' },
      scale: { type: 'range', label: 'Scale (px)', min: 6, max: 64, default: 16 },
      opacity: { type: 'range', label: 'Opacity', min: 0, max: 100, default: 40 },
    },
  },
  vignette: {
    label: 'Vignette',
    params: {
      radius: { type: 'range', label: 'Radius', min: 0, max: 100, default: 60 },
      softness: { type: 'range', label: 'Softness', min: 0, max: 100, default: 50 },
      color: { type: 'color', label: 'Color', default: '#000000' },
    },
  },
  duotone: {
    label: 'Color duotone',
    params: {
      shadow: { type: 'color', label: 'Shadow', default: '#1a1a40' },
      highlight: { type: 'color', label: 'Highlight', default: '#c8f04a' },
      intensity: { type: 'range', label: 'Intensity', min: 0, max: 100, default: 100 },
    },
  },
  blur: {
    label: 'Blur',
    params: {
      blurType: { type: 'select', label: 'Type', options: ['Gaussian', 'Motion', 'Radial'], default: 'Gaussian' },
      amount: { type: 'range', label: 'Amount', min: 0, max: 100, default: 20 },
    },
  },
}

export function defaultEffect(type) {
  const def = EFFECT_DEFS[type]
  const params = {}
  Object.entries(def.params).forEach(([k, v]) => (params[k] = v.default))
  return { id: `fx_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 6)}`, type, enabled: true, params }
}

function hexToRgb(hex) {
  const h = hex.replace('#', '')
  const n = parseInt(h.length === 3 ? h.split('').map((c) => c + c).join('') : h, 16)
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}

// ===== Custom Fabric 2D filters =====

const Duotone = fabric.util.createClass(fabric.Image.filters.BaseFilter, {
  type: 'Duotone',
  initialize(o = {}) {
    this.shadow = o.shadow || '#000000'
    this.highlight = o.highlight || '#ffffff'
    this.intensity = o.intensity ?? 1
  },
  applyTo2d(options) {
    const d = options.imageData.data
    const s = hexToRgb(this.shadow)
    const h = hexToRgb(this.highlight)
    const k = this.intensity
    for (let i = 0; i < d.length; i += 4) {
      const lum = (0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]) / 255
      for (let c = 0; c < 3; c++) {
        const duo = s[c] + (h[c] - s[c]) * lum
        d[i + c] = d[i + c] * (1 - k) + duo * k
      }
    }
  },
})

const Vignette = fabric.util.createClass(fabric.Image.filters.BaseFilter, {
  type: 'Vignette',
  initialize(o = {}) {
    this.radius = o.radius ?? 0.6
    this.softness = o.softness ?? 0.5
    this.color = o.color || '#000000'
  },
  applyTo2d(options) {
    const { imageData } = options
    const { width, height, data } = imageData
    const col = hexToRgb(this.color)
    const cx = width / 2
    const cy = height / 2
    const maxD = Math.sqrt(cx * cx + cy * cy)
    const inner = this.radius * maxD
    const soft = Math.max(1, this.softness * maxD)
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const dist = Math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        let v = (dist - inner) / soft
        v = Math.max(0, Math.min(1, v))
        if (v > 0) {
          const i = (y * width + x) * 4
          for (let c = 0; c < 3; c++) data[i + c] = data[i + c] * (1 - v) + col[c] * v
        }
      }
    }
  },
})

const Dither = fabric.util.createClass(fabric.Image.filters.BaseFilter, {
  type: 'Dither',
  initialize(o = {}) {
    this.algorithm = o.algorithm || 'Ordered'
    this.intensity = o.intensity ?? 0.6
    this.colorMode = o.colorMode || 'Monochrome'
    this.scale = o.scale || 1
  },
  applyTo2d(options) {
    const { imageData } = options
    const { width, height, data } = imageData
    const levels = this.colorMode === 'Full color' ? 4 : 2
    const quant = (v) => Math.round((v / 255) * (levels - 1)) / (levels - 1) * 255
    const k = this.intensity
    if (this.algorithm === 'Ordered') {
      const m = [
        [0, 8, 2, 10],
        [12, 4, 14, 6],
        [3, 11, 1, 9],
        [15, 7, 13, 5],
      ]
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const i = (y * width + x) * 4
          const t = (m[Math.floor(y / this.scale) % 4][Math.floor(x / this.scale) % 4] / 16 - 0.5) * 64
          for (let c = 0; c < 3; c++) {
            const orig = data[i + c]
            const dithered = quant(orig + t)
            data[i + c] = orig * (1 - k) + dithered * k
          }
        }
      }
    } else {
      const diffusion = this.algorithm === 'Atkinson' ? 'atkinson' : 'fs'
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const i = (y * width + x) * 4
          for (let c = 0; c < 3; c++) {
            const orig = data[i + c]
            const q = quant(orig)
            const err = (orig - q) * k
            data[i + c] = orig * (1 - k) + q * k
            if (diffusion === 'fs') {
              spread(data, width, height, x + 1, y, c, (err * 7) / 16)
              spread(data, width, height, x - 1, y + 1, c, (err * 3) / 16)
              spread(data, width, height, x, y + 1, c, (err * 5) / 16)
              spread(data, width, height, x + 1, y + 1, c, (err * 1) / 16)
            } else {
              const e = err / 8
              spread(data, width, height, x + 1, y, c, e)
              spread(data, width, height, x + 2, y, c, e)
              spread(data, width, height, x - 1, y + 1, c, e)
              spread(data, width, height, x, y + 1, c, e)
              spread(data, width, height, x + 1, y + 1, c, e)
              spread(data, width, height, x, y + 2, c, e)
            }
          }
        }
      }
    }
  },
})

function spread(data, w, h, x, y, c, err) {
  if (x < 0 || x >= w || y < 0 || y >= h) return
  const i = (y * w + x) * 4 + c
  data[i] += err
}

const Glitch = fabric.util.createClass(fabric.Image.filters.BaseFilter, {
  type: 'Glitch',
  initialize(o = {}) {
    this.slice = o.slice ?? 0.3
    this.rgb = o.rgb ?? 10
    this.seed = o.seed ?? 1
    this.intensity = o.intensity ?? 0.5
  },
  applyTo2d(options) {
    const { imageData } = options
    const { width, height, data } = imageData
    const src = new Uint8ClampedArray(data)
    let seed = this.seed * 9301 + 49297
    const rand = () => {
      seed = (seed * 9301 + 49297) % 233280
      return seed / 233280
    }
    const sliceCount = Math.floor(2 + this.intensity * 20)
    const maxShift = this.slice * width
    for (let s = 0; s < sliceCount; s++) {
      const y0 = Math.floor(rand() * height)
      const sh = Math.floor((rand() - 0.5) * maxShift)
      const hgt = Math.floor(rand() * (height / sliceCount))
      for (let y = y0; y < Math.min(height, y0 + hgt); y++) {
        for (let x = 0; x < width; x++) {
          const sx = (x + sh + width) % width
          const di = (y * width + x) * 4
          const si = (y * width + sx) * 4
          data[di] = src[si]
          data[di + 1] = src[si + 1]
          data[di + 2] = src[si + 2]
        }
      }
    }
    // RGB channel split
    const off = Math.round(this.rgb)
    if (off > 0) {
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const i = (y * width + x) * 4
          const rx = Math.min(width - 1, x + off)
          const bx = Math.max(0, x - off)
          data[i] = src[(y * width + rx) * 4]
          data[i + 2] = src[(y * width + bx) * 4 + 2]
        }
      }
    }
  },
})

const Grain = fabric.util.createClass(fabric.Image.filters.BaseFilter, {
  type: 'Grain',
  initialize(o = {}) {
    this.size = o.size ?? 1
    this.opacity = o.opacity ?? 0.4
    this.blend = o.blend || 'Overlay'
  },
  applyTo2d(options) {
    const { imageData } = options
    const { width, height, data } = imageData
    const op = this.opacity
    for (let y = 0; y < height; y += this.size) {
      for (let x = 0; x < width; x += this.size) {
        const n = (Math.random() - 0.5) * 255 * op
        for (let dy = 0; dy < this.size && y + dy < height; dy++) {
          for (let dx = 0; dx < this.size && x + dx < width; dx++) {
            const i = ((y + dy) * width + (x + dx)) * 4
            for (let c = 0; c < 3; c++) {
              let v = data[i + c]
              if (this.blend === 'Screen') v = 255 - ((255 - v) * (255 - (128 + n))) / 255
              else if (this.blend === 'Soft Light') v = v + n * 0.5
              else v = v + n // Overlay-ish additive
              data[i + c] = Math.max(0, Math.min(255, v))
            }
          }
        }
      }
    }
  },
})

const Halftone = fabric.util.createClass(fabric.Image.filters.BaseFilter, {
  type: 'Halftone',
  initialize(o = {}) {
    this.dotSize = o.dotSize ?? 6
    this.angle = o.angle ?? 45
    this.shape = o.shape || 'Circle'
    this.fg = o.fg || '#111111'
    this.bg = o.bg || '#ffffff'
  },
  applyTo2d(options) {
    const { imageData } = options
    const { width, height, data } = imageData
    const tmp = document.createElement('canvas')
    tmp.width = width
    tmp.height = height
    const ctx = tmp.getContext('2d')
    ctx.fillStyle = this.bg
    ctx.fillRect(0, 0, width, height)
    ctx.fillStyle = this.fg
    ctx.strokeStyle = this.fg
    const step = this.dotSize
    const ang = (this.angle * Math.PI) / 180
    const src = data
    for (let y = 0; y < height; y += step) {
      for (let x = 0; x < width; x += step) {
        const i = (y * width + x) * 4
        const lum = (0.299 * src[i] + 0.587 * src[i + 1] + 0.114 * src[i + 2]) / 255
        const r = (1 - lum) * (step / 2)
        if (r < 0.3) continue
        const cx = x + step / 2
        const cy = y + step / 2
        if (this.shape === 'Circle') {
          ctx.beginPath()
          ctx.arc(cx, cy, r, 0, Math.PI * 2)
          ctx.fill()
        } else if (this.shape === 'Line') {
          ctx.save()
          ctx.translate(cx, cy)
          ctx.rotate(ang)
          ctx.fillRect(-step / 2, -r / 2, step, r)
          ctx.restore()
        } else {
          ctx.save()
          ctx.translate(cx, cy)
          ctx.rotate(ang)
          ctx.fillRect(-r, -1, r * 2, 2)
          ctx.fillRect(-1, -r, 2, r * 2)
          ctx.restore()
        }
      }
    }
    const out = ctx.getImageData(0, 0, width, height).data
    for (let i = 0; i < data.length; i++) data[i] = out[i]
  },
})

const PatternOverlay = fabric.util.createClass(fabric.Image.filters.BaseFilter, {
  type: 'PatternOverlay',
  initialize(o = {}) {
    this.pattern = o.pattern || 'Dots'
    this.fg = o.fg || '#111111'
    this.scale = o.scale || 16
    this.opacity = o.opacity ?? 0.4
  },
  applyTo2d(options) {
    const { imageData } = options
    const { width, height, data } = imageData
    const fg = hexToRgb(this.fg)
    const s = this.scale
    const op = this.opacity
    const hit = (x, y) => {
      const mx = x % s
      const my = y % s
      switch (this.pattern) {
        case 'Dots':
          return (mx - s / 2) ** 2 + (my - s / 2) ** 2 < (s / 5) ** 2
        case 'Grid':
          return mx < 2 || my < 2
        case 'Diagonal Lines':
          return (x + y) % s < 2
        case 'Cross-hatch':
          return (x + y) % s < 2 || (x - y + height) % s < 2
        case 'Checkerboard':
          return (Math.floor(x / s) + Math.floor(y / s)) % 2 === 0
        case 'Triangles':
          return my > mx
        default:
          return false
      }
    }
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (hit(x, y)) {
          const i = (y * width + x) * 4
          for (let c = 0; c < 3; c++) data[i + c] = data[i + c] * (1 - op) + fg[c] * op
        }
      }
    }
  },
})

// ===== Build a Fabric filter from an effect descriptor =====
function buildFilter(effect) {
  const p = effect.params
  const F = fabric.Image.filters
  switch (effect.type) {
    case 'blur':
      if (p.blurType === 'Motion') return new F.Convolute({ matrix: motionKernel(p.amount) })
      return new F.Blur({ blur: (p.amount / 100) * 0.5 })
    case 'duotone':
      return new Duotone({ shadow: p.shadow, highlight: p.highlight, intensity: p.intensity / 100 })
    case 'vignette':
      return new Vignette({ radius: p.radius / 100, softness: p.softness / 100, color: p.color })
    case 'dither':
      return new Dither({ algorithm: p.algorithm, intensity: p.intensity / 100, colorMode: p.colorMode, scale: p.scale })
    case 'glitch':
      return new Glitch({ slice: p.slice / 100, rgb: p.rgb, seed: p.seed, intensity: p.intensity / 100 })
    case 'grain':
      return new Grain({ size: p.size, opacity: p.opacity / 100, blend: p.blend })
    case 'halftone':
      return new Halftone({ dotSize: p.dotSize, angle: p.angle, shape: p.shape, fg: p.fg, bg: p.bg })
    case 'pattern':
      return new PatternOverlay({ pattern: p.pattern, fg: p.fg, scale: p.scale, opacity: p.opacity / 100 })
    default:
      return null
  }
}

function motionKernel(amount) {
  // simple 5x5 horizontal motion blur scaled by amount
  const w = Math.max(0, Math.min(1, amount / 100))
  const k = 1 / 5
  return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, k * w, k * w, 1 - w + k * w, k * w, k * w, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
}

// Build adjustment filters (brightness/contrast/saturation/hue) from img.adjustments
function adjustmentFilters(adj = {}) {
  const F = fabric.Image.filters
  const out = []
  if (adj.brightness) out.push(new F.Brightness({ brightness: adj.brightness / 100 }))
  if (adj.contrast) out.push(new F.Contrast({ contrast: adj.contrast / 100 }))
  if (adj.saturation) out.push(new F.Saturation({ saturation: adj.saturation / 100 }))
  if (adj.hue) out.push(new F.HueRotation({ rotation: (adj.hue / 360) * 2 - 1 }))
  return out
}

// Rebuild the filter pipeline for an image from its adjustments + effects.
export function applyEffectsToImage(img, effects) {
  if (!img || img.layerType !== 'image') return
  const adj = adjustmentFilters(img.adjustments)
  const fx = (effects || [])
    .filter((e) => e.enabled)
    .map(buildFilter)
    .filter(Boolean)
  img.filters = [...adj, ...fx]
  try {
    img.applyFilters()
  } catch (e) {
    /* WebGL/2D fallback handled by fabric */
  }
}
