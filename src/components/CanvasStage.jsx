import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'
import Icon from './Icon'

export default function CanvasStage() {
  const canvasRef = useRef(null)
  const viewportRef = useRef(null)
  const frameRef = useRef(null)
  const project = useStore((s) => s.project)
  const zoom = useStore((s) => s.zoom)
  const showGrid = useStore((s) => s.showGrid)
  const showRulers = useStore((s) => s.showRulers)
  const layers = useStore((s) => s.layers)
  const selectedIds = useStore((s) => s.selectedIds)
  const setUI = useStore((s) => s.setUI)
  const activeTool = useStore((s) => s.ui.activeTool)

  const [toolbar, setToolbar] = useState(null) // {x,y,w}
  const [guides, setGuides] = useState({ v: [], h: [] }) // canvas-space guide positions

  // ---- init fabric once ----
  useEffect(() => {
    const c = controller.init(canvasRef.current)
    const update = () => updateToolbar()
    c.on('after:render', update)
    c.on('selection:cleared', () => setToolbar(null))
    fit() // apply initial zoom now that the canvas exists
    return () => {
      c.off('after:render', update)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ---- fit-to-screen ----
  const fit = () => {
    const vp = viewportRef.current
    if (!vp) return
    const pad = 80
    const z = Math.min(
      (vp.clientWidth - pad) / project.width,
      (vp.clientHeight - pad) / project.height
    )
    controller.setZoomTo(z)
  }

  useLayoutEffect(() => {
    fit()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [project.width, project.height])

  useEffect(() => {
    const onFit = () => fit()
    window.addEventListener('pc-fit', onFit)
    return () => window.removeEventListener('pc-fit', onFit)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [project.width, project.height])

  // ---- toolbar position relative to selected object ----
  function updateToolbar() {
    const c = controller.get()
    const obj = c?.getActiveObject()
    if (!obj || obj.isEditing || !canvasRef.current) {
      setToolbar(null)
      return
    }
    const rect = canvasRef.current.getBoundingClientRect()
    // getBoundingRect() returns element-space coords (already includes the
    // viewport zoom), and there is no CSS transform, so screen = rect + b.
    const b = obj.getBoundingRect()
    setToolbar({
      x: rect.left + b.left + b.width / 2,
      y: rect.top + b.top - 46,
      visible: b.top > 54,
    })
  }

  useEffect(() => {
    updateToolbar()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [zoom, selectedIds, layers])

  // ---- wheel zoom (ctrl / pinch) ----
  useEffect(() => {
    const vp = viewportRef.current
    if (!vp) return
    const onWheel = (e) => {
      if (e.ctrlKey || e.metaKey) {
        e.preventDefault()
        const delta = -e.deltaY * 0.0015
        controller.setZoomTo(zoom * (1 + delta))
      }
    }
    vp.addEventListener('wheel', onWheel, { passive: false })
    return () => vp.removeEventListener('wheel', onWheel)
  }, [zoom])

  // ---- space + drag panning ----
  useEffect(() => {
    const vp = viewportRef.current
    if (!vp) return
    let panning = false
    let spaceDown = false
    let start = null

    const onKeyDown = (e) => {
      if (e.code === 'Space' && !isTyping(e)) {
        spaceDown = true
        vp.style.cursor = 'grab'
      }
    }
    const onKeyUp = (e) => {
      if (e.code === 'Space') {
        spaceDown = false
        vp.style.cursor = ''
      }
    }
    const onDown = (e) => {
      if (spaceDown || activeTool === 'pan') {
        panning = true
        start = { x: e.clientX, y: e.clientY, sl: vp.scrollLeft, st: vp.scrollTop }
        vp.style.cursor = 'grabbing'
        e.preventDefault()
      }
    }
    const onMove = (e) => {
      if (panning && start) {
        vp.scrollLeft = start.sl - (e.clientX - start.x)
        vp.scrollTop = start.st - (e.clientY - start.y)
      }
    }
    const onUp = () => {
      panning = false
      vp.style.cursor = spaceDown ? 'grab' : ''
    }
    window.addEventListener('keydown', onKeyDown)
    window.addEventListener('keyup', onKeyUp)
    vp.addEventListener('mousedown', onDown)
    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
    return () => {
      window.removeEventListener('keydown', onKeyDown)
      window.removeEventListener('keyup', onKeyUp)
      vp.removeEventListener('mousedown', onDown)
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
  }, [activeTool])

  // ---- drag image files directly onto canvas ----
  function onDrop(e) {
    e.preventDefault()
    const file = e.dataTransfer.files?.[0]
    if (file && file.type.startsWith('image/')) {
      const url = URL.createObjectURL(file)
      controller.addImageFromUrl(url)
    } else {
      const url = e.dataTransfer.getData('text/plain')
      if (url) controller.addImageFromUrl(url)
    }
  }

  // ---- rulers: click to add a guide, double-click guide to remove ----
  function addGuide(axis, clientPos) {
    const rect = canvasRef.current.getBoundingClientRect()
    if (axis === 'v') {
      const pos = ((clientPos - rect.left) / rect.width) * project.width
      if (pos >= 0 && pos <= project.width) setGuides((g) => ({ ...g, v: [...g.v, pos] }))
    } else {
      const pos = ((clientPos - rect.top) / rect.height) * project.height
      if (pos >= 0 && pos <= project.height) setGuides((g) => ({ ...g, h: [...g.h, pos] }))
    }
  }

  const frameW = project.width * zoom
  const frameH = project.height * zoom

  return (
    <main className="canvas-area">
      <div className="grain-overlay subtle" aria-hidden="true" />

      {showRulers && (
        <>
          <div className="ruler ruler-top" onClick={(e) => addGuide('v', e.clientX)} title="Click to add a vertical guide">
            <RulerTicks length={frameW} zoom={zoom} axis="h" offset={frameRef.current?.offsetLeft} />
          </div>
          <div className="ruler ruler-left" onClick={(e) => addGuide('h', e.clientY)} title="Click to add a horizontal guide">
            <RulerTicks length={frameH} zoom={zoom} axis="v" offset={frameRef.current?.offsetTop} />
          </div>
          <div className="ruler-corner" />
        </>
      )}

      <div
        className={`canvas-viewport ${showRulers ? 'with-rulers' : ''}`}
        ref={viewportRef}
        onDrop={onDrop}
        onDragOver={(e) => e.preventDefault()}
      >
        <div className="canvas-scaler">
          <div className="canvas-frame" ref={frameRef}>
            <canvas ref={canvasRef} />
            {showGrid && <div className="grid-overlay" aria-hidden="true" />}

            {/* user guides (stored in logical px, drawn at zoom) */}
            {guides.v.map((p, i) => (
              <div
                key={`v${i}`}
                className="user-guide vertical"
                style={{ left: p * zoom }}
                onDoubleClick={() => setGuides((g) => ({ ...g, v: g.v.filter((_, j) => j !== i) }))}
              />
            ))}
            {guides.h.map((p, i) => (
              <div
                key={`h${i}`}
                className="user-guide horizontal"
                style={{ top: p * zoom }}
                onDoubleClick={() => setGuides((g) => ({ ...g, h: g.h.filter((_, j) => j !== i) }))}
              />
            ))}

            {layers.length === 0 && (
              <div className="empty-state">
                <div className="empty-ghost">
                  <Icon name="image" size={40} />
                  <Icon name="type" size={34} />
                </div>
                <p>Add an image or text to get started</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* floating mini-toolbar */}
      {toolbar && toolbar.visible && <MiniToolbar pos={toolbar} />}
    </main>
  )
}

function MiniToolbar({ pos }) {
  const [opacity, setOpacity] = useState(100)
  const [angle, setAngle] = useState(0)
  useEffect(() => {
    const o = controller.active()
    if (o) {
      setOpacity(Math.round((o.opacity ?? 1) * 100))
      setAngle(Math.round(o.angle || 0))
    }
  }, [pos.x, pos.y])
  return (
    <div
      className="mini-toolbar"
      style={{ left: pos.x, top: pos.y, transform: 'translateX(-50%)' }}
    >
      <div className="mini-opacity">
        <span>Opacity</span>
        <input
          type="range"
          min={0}
          max={100}
          value={opacity}
          onChange={(e) => {
            const v = Number(e.target.value)
            setOpacity(v)
            controller.liveUpdate({ opacity: v / 100 })
          }}
          onMouseUp={() => controller.commitLive('Change opacity')}
        />
      </div>
      <div className="mini-sep" />
      <div className="mini-angle" title="Rotation angle">
        <Icon name="redo" size={13} />
        <input
          type="number"
          value={angle}
          onChange={(e) => {
            const v = Number(e.target.value)
            setAngle(v)
            controller.liveUpdate({ angle: v })
          }}
          onBlur={() => controller.commitLive('Rotate')}
          onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()}
        />
        <span>°</span>
      </div>
      <div className="mini-sep" />
      <button className="mini-btn" title="Flip horizontal" onClick={() => controller.flip('h')}>
        <Icon name="flipH" />
      </button>
      <button className="mini-btn" title="Flip vertical" onClick={() => controller.flip('v')}>
        <Icon name="flipV" />
      </button>
      <button className="mini-btn danger" title="Delete" onClick={() => controller.deleteSelected()}>
        <Icon name="trash" />
      </button>
    </div>
  )
}

function RulerTicks({ length, zoom, axis }) {
  // draw labelled ticks every 100 canvas px
  const ticks = []
  const stepCanvas = 100
  const count = Math.ceil(length / (stepCanvas * zoom))
  for (let i = 0; i <= count; i++) {
    const offset = i * stepCanvas * zoom
    ticks.push(
      <span
        key={i}
        className="ruler-tick"
        style={axis === 'h' ? { left: offset } : { top: offset }}
      >
        {i * stepCanvas}
      </span>
    )
  }
  return <>{ticks}</>
}

function isTyping(e) {
  const t = e.target
  return t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable
}
