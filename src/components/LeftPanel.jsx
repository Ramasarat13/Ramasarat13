import { useRef, useState } from 'react'
import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'
import Icon from './Icon'

export default function LeftPanel() {
  const leftTab = useStore((s) => s.ui.leftTab)
  const setUI = useStore((s) => s.setUI)
  return (
    <aside className="panel left-panel">
      <div className="panel-tabs">
        <button className={`panel-tab ${leftTab === 'layers' ? 'active' : ''}`} onClick={() => setUI({ leftTab: 'layers' })}>
          <Icon name="layers" size={14} /> Layers
        </button>
        <button className={`panel-tab ${leftTab === 'assets' ? 'active' : ''}`} onClick={() => setUI({ leftTab: 'assets' })}>
          <Icon name="shapes" size={14} /> Assets
        </button>
      </div>
      <div className="panel-scroll">{leftTab === 'layers' ? <LayersTab /> : <AssetsTab />}</div>
    </aside>
  )
}

/* ---------------- Layers ---------------- */
function LayersTab() {
  const layers = useStore((s) => s.layers)
  const selectedIds = useStore((s) => s.selectedIds)
  const [renaming, setRenaming] = useState(null)
  const [menu, setMenu] = useState(null) // {id, x, y}
  const dragIndex = useRef(null)

  if (!layers.length) {
    return <p className="panel-empty">No layers yet. Add an image, shape, or text from the Assets tab.</p>
  }

  return (
    <div className="layers-list" onClick={() => setMenu(null)}>
      {layers.map((ly, i) => (
        <div
          key={ly.id}
          className={`layer-row ${selectedIds.includes(ly.id) ? 'selected' : ''}`}
          draggable
          onDragStart={() => (dragIndex.current = i)}
          onDragOver={(e) => e.preventDefault()}
          onDrop={() => {
            if (dragIndex.current !== null && dragIndex.current !== i) {
              controller.reorder(layers[dragIndex.current].id, i)
            }
            dragIndex.current = null
          }}
          onClick={(e) => controller.selectById(ly.id, e.shiftKey)}
          onContextMenu={(e) => {
            e.preventDefault()
            controller.selectById(ly.id)
            setMenu({ id: ly.id, x: e.clientX, y: e.clientY })
          }}
        >
          <button
            className="layer-icon-btn"
            title={ly.visible ? 'Hide' : 'Show'}
            onClick={(e) => {
              e.stopPropagation()
              controller.toggleVisibility(ly.id)
            }}
          >
            <Icon name={ly.visible ? 'eye' : 'eyeOff'} size={14} />
          </button>
          <span className="layer-type-icon">
            <Icon name={ly.type === 'image' ? 'image' : ly.type === 'text' ? 'type' : 'shapes'} size={14} />
          </span>
          {renaming === ly.id ? (
            <input
              className="layer-rename"
              autoFocus
              defaultValue={ly.name}
              onBlur={(e) => {
                controller.renameLayer(ly.id, e.target.value || ly.name)
                setRenaming(null)
              }}
              onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()}
              onClick={(e) => e.stopPropagation()}
            />
          ) : (
            <span className="layer-name" onDoubleClick={() => setRenaming(ly.id)}>
              {ly.name}
            </span>
          )}
          {ly.effects?.length > 0 && <span className="layer-fx-badge" title="Has effects">fx</span>}
          <button
            className="layer-icon-btn"
            title={ly.locked ? 'Unlock' : 'Lock'}
            onClick={(e) => {
              e.stopPropagation()
              controller.toggleLock(ly.id)
            }}
          >
            <Icon name={ly.locked ? 'lock' : 'unlock'} size={14} />
          </button>
        </div>
      ))}

      {menu && (
        <ul className="context-menu" style={{ left: menu.x, top: menu.y }}>
          <li onClick={() => { setRenaming(menu.id); setMenu(null) }}>Rename</li>
          <li onClick={() => { controller.selectById(menu.id); controller.duplicateSelected(); setMenu(null) }}>Duplicate</li>
          <li onClick={() => { controller.selectById(menu.id); controller.deleteSelected(); setMenu(null) }}>Delete</li>
          <li className="sep" />
          <li onClick={() => { controller.selectById(menu.id); controller.bringToFront(); setMenu(null) }}>Move to top</li>
          <li onClick={() => { controller.selectById(menu.id); controller.sendToBack(); setMenu(null) }}>Move to bottom</li>
        </ul>
      )}
    </div>
  )
}

/* ---------------- Assets ---------------- */
function AssetsTab() {
  const assetsTab = useStore((s) => s.ui.assetsTab)
  const setUI = useStore((s) => s.setUI)
  return (
    <div className="assets">
      <div className="subtabs">
        {['images', 'shapes', 'backgrounds'].map((t) => (
          <button key={t} className={`subtab ${assetsTab === t ? 'active' : ''}`} onClick={() => setUI({ assetsTab: t })}>
            {t[0].toUpperCase() + t.slice(1)}
          </button>
        ))}
      </div>
      {assetsTab === 'images' && <ImagesTab />}
      {assetsTab === 'shapes' && <ShapesTab />}
      {assetsTab === 'backgrounds' && <BackgroundsTab />}
    </div>
  )
}

const ACCEPTED = ['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml', 'image/gif']
const MAX_BYTES = 20 * 1024 * 1024

function ImagesTab() {
  const inputRef = useRef(null)
  const images = useStore((s) => s.uploadedImages)
  const addUploadedImage = useStore((s) => s.addUploadedImage)
  const pushToast = useStore((s) => s.pushToast)
  const [error, setError] = useState(null)
  const [hovering, setHovering] = useState(false)

  function handleFiles(files) {
    setError(null)
    let bad = false
    Array.from(files).forEach((file) => {
      if (!ACCEPTED.includes(file.type) || file.size > MAX_BYTES) {
        bad = true
        return
      }
      const url = URL.createObjectURL(file)
      addUploadedImage({ id: `img_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`, url, name: file.name })
    })
    if (bad) setError('Only JPG, PNG, WEBP, SVG and GIF files under 20MB are supported.')
  }

  return (
    <div className="assets-section">
      <div
        className={`upload-zone ${hovering ? 'hover' : ''}`}
        onClick={() => inputRef.current.click()}
        onDragOver={(e) => { e.preventDefault(); setHovering(true) }}
        onDragLeave={() => setHovering(false)}
        onDrop={(e) => { e.preventDefault(); setHovering(false); handleFiles(e.dataTransfer.files) }}
      >
        <Icon name="image" size={22} />
        <span>Drop images here or click to browse</span>
        <input
          ref={inputRef}
          type="file"
          accept={ACCEPTED.join(',')}
          multiple
          hidden
          onChange={(e) => handleFiles(e.target.files)}
        />
      </div>
      {error && <p className="inline-error">{error}</p>}
      <div className="thumb-grid">
        {images.map((img) => (
          <button
            key={img.id}
            className="thumb"
            title={img.name}
            draggable
            onDragStart={(e) => e.dataTransfer.setData('text/plain', img.url)}
            onClick={() => controller.addImageFromUrl(img.url)}
          >
            <img src={img.url} alt={img.name} />
            <span className="thumb-add"><Icon name="plus" size={18} /></span>
          </button>
        ))}
      </div>
    </div>
  )
}

const SHAPES = [
  ['rect', 'Rectangle'], ['roundRect', 'Rounded'], ['circle', 'Circle'],
  ['triangle', 'Triangle'], ['star', 'Star'], ['line', 'Line'],
  ['arrow', 'Arrow'], ['hexagon', 'Hexagon'], ['diamond', 'Diamond'],
]

const TEMPLATES = [
  { name: 'Bold headline', blocks: [{ text: 'BIG HEADLINE', size: 96, weight: 'bold' }, { text: 'A short supporting subheading goes here', size: 36 }] },
  { name: 'Event poster', blocks: [{ text: 'You are invited', size: 40 }, { text: 'Summer Festival', size: 110, weight: 'bold' }, { text: 'Saturday · 7pm · Main Square', size: 32 }] },
  { name: 'Quote block', blocks: [{ text: '“Design is intelligence made visible.”', size: 64, weight: 'bold' }, { text: '— Alina Wheeler', size: 30 }] },
]

function ShapesTab() {
  return (
    <div className="assets-section">
      <div className="shape-grid">
        {SHAPES.map(([key, label]) => (
          <button key={key} className="shape-cell" title={label} onClick={() => controller.addShape(key)}>
            <ShapePreview shape={key} />
            <span>{label}</span>
          </button>
        ))}
      </div>
      <div className="divider" />
      <p className="field-label" style={{ marginBottom: 8 }}>Text templates</p>
      <div className="template-list">
        {TEMPLATES.map((t) => (
          <button key={t.name} className="template-card" onClick={() => controller.addTextStack(t.blocks)}>
            <Icon name="type" size={14} />
            <span>{t.name}</span>
          </button>
        ))}
      </div>
    </div>
  )
}

function ShapePreview({ shape }) {
  const c = '#c8f04a'
  const map = {
    rect: <rect x="6" y="12" width="28" height="16" fill={c} />,
    roundRect: <rect x="6" y="12" width="28" height="16" rx="5" fill={c} />,
    circle: <circle cx="20" cy="20" r="11" fill={c} />,
    triangle: <path d="M20 8l12 22H8z" fill={c} />,
    star: <path d="M20 8l3 7 7 .5-5.5 4.5 2 7-6.5-4-6.5 4 2-7L10 15.5 17 15z" fill={c} />,
    line: <rect x="6" y="19" width="28" height="3" rx="1.5" fill={c} />,
    arrow: <path d="M8 18h14v-4l8 6-8 6v-4H8z" fill={c} />,
    hexagon: <path d="M14 9h12l6 11-6 11H14L8 20z" fill={c} />,
    diamond: <path d="M20 8l12 12-12 12L8 20z" fill={c} />,
  }
  return <svg width="40" height="40" viewBox="0 0 40 40">{map[shape]}</svg>
}

function BackgroundsTab() {
  const applyBg = (v) => controller.applyBackground(v)
  const [grad, setGrad] = useState({ type: 'gradient', gradType: 'linear', angle: 90, stops: [{ offset: 0, color: '#c8f04a' }, { offset: 1, color: '#1a1a40' }] })
  const setUI = useStore((s) => s.setUI)

  const SOLIDS = ['#ffffff', '#0f0f10', '#c8f04a', '#ff5470', '#5b8def', '#ffd166', '#f0efe9', '#1a1a40', '#2ec4b6', '#e07a5f']
  const PATTERNS = ['grid', 'dots', 'diagonal', 'crosshatch', 'checker', 'triangles']

  function setStop(i, color) {
    const stops = grad.stops.map((s, j) => (j === i ? { ...s, color } : s))
    const next = { ...grad, stops }
    setGrad(next)
    applyBg(next)
  }
  function addStop() {
    if (grad.stops.length >= 5) return
    const next = { ...grad, stops: [...grad.stops, { offset: 0.5, color: '#ffffff' }] }
    setGrad(next)
    applyBg(next)
  }

  return (
    <div className="assets-section">
      <p className="field-label">Solid color</p>
      <div className="swatch-grid">
        {SOLIDS.map((c) => (
          <button key={c} className="swatch" style={{ background: c }} onClick={() => applyBg(c)} title={c} />
        ))}
        <label className="swatch custom-swatch" title="Custom color">
          <Icon name="plus" size={14} />
          <input type="color" onChange={(e) => applyBg(e.target.value)} />
        </label>
      </div>

      <div className="divider" />
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <p className="field-label" style={{ margin: 0 }}>Gradient</p>
        <select className="input mini" value={grad.gradType} onChange={(e) => { const n = { ...grad, gradType: e.target.value }; setGrad(n); applyBg(n) }}>
          <option value="linear">Linear</option>
          <option value="radial">Radial</option>
        </select>
      </div>
      <div className="grad-stops">
        {grad.stops.map((s, i) => (
          <label key={i} className="grad-stop" style={{ background: s.color }}>
            <input type="color" value={s.color} onChange={(e) => setStop(i, e.target.value)} />
          </label>
        ))}
        <button className="btn icon" onClick={addStop} title="Add stop"><Icon name="plus" size={14} /></button>
      </div>
      {grad.gradType === 'linear' && (
        <div className="field" style={{ marginTop: 8 }}>
          <span className="field-label">Angle {grad.angle}°</span>
          <input type="range" min={0} max={360} value={grad.angle} onChange={(e) => { const n = { ...grad, angle: Number(e.target.value) }; setGrad(n); applyBg(n) }} />
        </div>
      )}

      <div className="divider" />
      <p className="field-label">Patterns</p>
      <div className="pattern-grid">
        {PATTERNS.map((p) => (
          <button key={p} className="pattern-cell" title={p} onClick={() => applyBg({ type: 'pattern', pattern: p, fg: '#111111', bg: '#ffffff', scale: 32 })}>
            <PatternPreview pattern={p} />
          </button>
        ))}
      </div>

      <div className="divider" />
      <button className="btn" style={{ width: '100%' }} onClick={() => setUI({ paletteOpen: true })}>
        <Icon name="sparkles" size={14} /> Generate palette
      </button>
    </div>
  )
}

function PatternPreview({ pattern }) {
  const id = `pp-${pattern}`
  return (
    <svg width="100%" height="38" viewBox="0 0 60 38">
      <rect width="60" height="38" fill="#ffffff" />
      <defs>
        <pattern id={id} width="12" height="12" patternUnits="userSpaceOnUse">
          {pattern === 'dots' && <circle cx="6" cy="6" r="2" fill="#111" />}
          {pattern === 'grid' && <path d="M0 0H12V12" stroke="#111" fill="none" strokeWidth="1" />}
          {pattern === 'diagonal' && <path d="M0 12L12 0" stroke="#111" strokeWidth="1.5" />}
          {pattern === 'crosshatch' && <path d="M0 12L12 0M0 0L12 12" stroke="#111" strokeWidth="1" />}
          {pattern === 'checker' && <><rect width="6" height="6" fill="#111" /><rect x="6" y="6" width="6" height="6" fill="#111" /></>}
          {pattern === 'triangles' && <path d="M6 0L12 12H0z" fill="#111" />}
        </pattern>
      </defs>
      <rect width="60" height="38" fill={`url(#${id})`} />
    </svg>
  )
}
