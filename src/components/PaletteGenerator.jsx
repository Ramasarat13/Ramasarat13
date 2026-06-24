import { useRef, useState } from 'react'
import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'
import Icon from './Icon'

export default function PaletteGenerator() {
  const setUI = useStore((s) => s.setUI)
  const uploaded = useStore((s) => s.uploadedImages)
  const saved = useStore((s) => s.savedPalettes)
  const savePalette = useStore((s) => s.savePalette)
  const pushToast = useStore((s) => s.pushToast)
  const fileRef = useRef(null)
  const [dominant, setDominant] = useState([])
  const [harmony, setHarmony] = useState([])
  const [mode, setMode] = useState('complementary')

  const close = () => setUI({ paletteOpen: false })

  function extractFrom(url) {
    const img = new Image()
    img.crossOrigin = 'anonymous'
    img.onload = () => {
      const colors = dominantColors(img, 5)
      setDominant(colors)
      setHarmony(buildHarmony(colors[0] || '#c8f04a', mode))
    }
    img.onerror = () => pushToast("Couldn't read that image.", 'error')
    img.src = url
  }

  function onUpload(e) {
    const f = e.target.files?.[0]
    if (f) extractFrom(URL.createObjectURL(f))
  }

  function regen(m) {
    setMode(m)
    if (dominant[0]) setHarmony(buildHarmony(dominant[0], m))
  }

  function applyColor(c) {
    const obj = controller.active()
    if (!obj) {
      controller.applyBackground(c)
      pushToast('Applied to canvas background.', 'success')
      return
    }
    if (obj.layerType === 'text') controller.updateActive({ fill: c }, 'Apply palette color')
    else controller.updateActive({ fill: c }, 'Apply palette color')
  }

  return (
    <div className="modal-overlay" onMouseDown={close}>
      <div className="palette-modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="font-modal-head">
          <h3 className="section-title"><Icon name="sparkles" size={15} /> Palette generator</h3>
          <button className="btn icon" onClick={close}><Icon name="close" /></button>
        </div>

        <div className="palette-body">
          <p className="field-label">Extract from an image</p>
          <div className="palette-sources">
            <button className="btn" onClick={() => fileRef.current.click()}><Icon name="image" size={14} /> Upload image</button>
            <input ref={fileRef} type="file" accept="image/*" hidden onChange={onUpload} />
            {uploaded.slice(0, 6).map((img) => (
              <button key={img.id} className="palette-thumb" onClick={() => extractFrom(img.url)}>
                <img src={img.url} alt={img.name} />
              </button>
            ))}
          </div>

          {dominant.length > 0 && (
            <>
              <p className="field-label" style={{ marginTop: 14 }}>Dominant colors</p>
              <Swatches colors={dominant} onPick={applyColor} />
              <button className="btn" style={{ marginTop: 8 }} onClick={() => { savePalette(dominant); pushToast('Palette saved.', 'success') }}>
                Save to my palettes
              </button>

              <p className="field-label" style={{ marginTop: 16 }}>Suggested harmonies</p>
              <div className="seg-control">
                {['complementary', 'analogous', 'triadic'].map((m) => (
                  <button key={m} className={`seg ${mode === m ? 'active' : ''}`} onClick={() => regen(m)}>{m}</button>
                ))}
              </div>
              <Swatches colors={harmony} onPick={applyColor} />
            </>
          )}

          {dominant.length === 0 && <p className="panel-empty">Upload or pick an image to extract a 5-color palette.</p>}

          {saved.length > 0 && (
            <>
              <div className="divider" />
              <p className="field-label">My palettes</p>
              {saved.map((p, i) => <Swatches key={i} colors={p} onPick={applyColor} />)}
            </>
          )}
        </div>
      </div>
    </div>
  )
}

function Swatches({ colors, onPick }) {
  return (
    <div className="palette-swatches">
      {colors.map((c, i) => (
        <button key={i} className="palette-swatch" style={{ background: c }} title={`${c} — click to apply`} onClick={() => onPick(c)}>
          <span className="palette-hex">{c}</span>
        </button>
      ))}
    </div>
  )
}

// ---- color helpers ----
function dominantColors(img, count) {
  const size = 96
  const c = document.createElement('canvas')
  c.width = size
  c.height = size
  const ctx = c.getContext('2d')
  ctx.drawImage(img, 0, 0, size, size)
  const data = ctx.getImageData(0, 0, size, size).data

  // Bucket at a finer resolution (5 bits/channel) keeping the average colour and
  // a "vividness" weight so saturated colours aren't drowned out by flat areas.
  const buckets = {}
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] < 128) continue
    const r = data[i]
    const g = data[i + 1]
    const b = data[i + 2]
    const key = `${r >> 3},${g >> 3},${b >> 3}`
    if (!buckets[key]) buckets[key] = { count: 0, r: 0, g: 0, b: 0 }
    const bk = buckets[key]
    bk.count++
    bk.r += r
    bk.g += g
    bk.b += b
  }

  const list = Object.values(buckets).map((bk) => {
    const r = bk.r / bk.count
    const g = bk.g / bk.count
    const b = bk.b / bk.count
    const max = Math.max(r, g, b)
    const min = Math.min(r, g, b)
    const sat = max === 0 ? 0 : (max - min) / max
    // weight = popularity boosted by saturation so the palette reads vivid
    const weight = bk.count * (1 + sat * 2.5)
    return { r, g, b, weight }
  })

  list.sort((a, b) => b.weight - a.weight)

  // Greedily pick colours that are perceptually distinct from those already chosen.
  const chosen = []
  const minDist = 48
  for (const col of list) {
    if (chosen.length >= count) break
    const far = chosen.every(
      (ch) => Math.hypot(ch.r - col.r, ch.g - col.g, ch.b - col.b) > minDist
    )
    if (far) chosen.push(col)
  }
  // top up if the image is low-contrast and we couldn't find enough distinct ones
  for (const col of list) {
    if (chosen.length >= count) break
    if (!chosen.includes(col)) chosen.push(col)
  }
  return chosen.map((b) => rgbToHex(b.r, b.g, b.b))
}

function rgbToHex(r, g, b) {
  const h = (n) => Math.round(n).toString(16).padStart(2, '0')
  return `#${h(r)}${h(g)}${h(b)}`
}

function hexToHsl(hex) {
  const h = hex.replace('#', '')
  const r = parseInt(h.slice(0, 2), 16) / 255
  const g = parseInt(h.slice(2, 4), 16) / 255
  const b = parseInt(h.slice(4, 6), 16) / 255
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  let hue = 0
  const l = (max + min) / 2
  const d = max - min
  const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1))
  if (d !== 0) {
    if (max === r) hue = ((g - b) / d) % 6
    else if (max === g) hue = (b - r) / d + 2
    else hue = (r - g) / d + 4
    hue *= 60
    if (hue < 0) hue += 360
  }
  return [hue, s, l]
}

function hslToHex(h, s, l) {
  const c = (1 - Math.abs(2 * l - 1)) * s
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1))
  const m = l - c / 2
  let r = 0, g = 0, b = 0
  if (h < 60) [r, g, b] = [c, x, 0]
  else if (h < 120) [r, g, b] = [x, c, 0]
  else if (h < 180) [r, g, b] = [0, c, x]
  else if (h < 240) [r, g, b] = [0, x, c]
  else if (h < 300) [r, g, b] = [x, 0, c]
  else [r, g, b] = [c, 0, x]
  return rgbToHex((r + m) * 255, (g + m) * 255, (b + m) * 255)
}

function buildHarmony(base, mode) {
  const [h, s, l] = hexToHsl(base)
  const mk = (dh, dl = 0) => hslToHex((h + dh + 360) % 360, s, Math.max(0.15, Math.min(0.9, l + dl)))
  switch (mode) {
    case 'complementary':
      return [base, mk(180), mk(0, 0.2), mk(180, -0.2), mk(0, -0.35)]
    case 'analogous':
      return [mk(-60), mk(-30), base, mk(30), mk(60)]
    case 'triadic':
      return [base, mk(120), mk(240), mk(120, 0.2), mk(240, -0.2)]
    default:
      return [base]
  }
}
