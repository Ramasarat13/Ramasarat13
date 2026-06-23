import { useState } from 'react'
import { controller } from '../../canvas/controller'
import { applyEffectsToImage } from '../../canvas/effects'
import { Section, NumField, RangeField, SelectField, ColorField } from './controls'
import EffectsSection from './EffectsSection'
import Icon from '../Icon'

const BLEND_MODES = [
  ['source-over', 'Normal'], ['multiply', 'Multiply'], ['screen', 'Screen'],
  ['overlay', 'Overlay'], ['soft-light', 'Soft Light'], ['hard-light', 'Hard Light'],
  ['darken', 'Darken'], ['lighten', 'Lighten'], ['color-dodge', 'Color Dodge'],
  ['color-burn', 'Color Burn'],
]

export default function ImageProperties({ obj, shapeMode = false }) {
  return (
    <>
      <TransformSection obj={obj} />
      <AppearanceSection obj={obj} />
      {shapeMode ? <ShapeFillSection obj={obj} /> : <AdjustmentsSection obj={obj} />}
      <EffectsSection obj={obj} />
    </>
  )
}

export function TransformSection({ obj }) {
  const [lockRatio, setLockRatio] = useState(true)
  const w = Math.round(obj.getScaledWidth())
  const h = Math.round(obj.getScaledHeight())
  const ratio = w / h

  const setW = (nw) => {
    const scaleX = nw / obj.width
    if (lockRatio) {
      const nh = nw / ratio
      controller.updateActive({ scaleX, scaleY: nh / obj.height }, 'Resize')
    } else {
      controller.updateActive({ scaleX }, 'Resize')
    }
  }
  const setH = (nh) => {
    const scaleY = nh / obj.height
    if (lockRatio) {
      const nw = nh * ratio
      controller.updateActive({ scaleY, scaleX: nw / obj.width }, 'Resize')
    } else {
      controller.updateActive({ scaleY }, 'Resize')
    }
  }

  return (
    <Section title="Transform">
      <div className="grid-2">
        <NumField label="X" value={obj.left} onChange={(v) => controller.updateActive({ left: v }, 'Move')} />
        <NumField label="Y" value={obj.top} onChange={(v) => controller.updateActive({ top: v }, 'Move')} />
      </div>
      <div className="grid-2-lock">
        <NumField label="W" value={w} min={1} onChange={setW} />
        <button className={`btn icon ratio-mini ${lockRatio ? 'active' : ''}`} title="Lock aspect ratio" onClick={() => setLockRatio((v) => !v)}>
          <Icon name="chain" size={14} />
        </button>
        <NumField label="H" value={h} min={1} onChange={setH} />
      </div>
      <div className="rotate-row">
        <NumField label="Rotation" value={obj.angle || 0} suffix="°" onChange={(v) => controller.updateActive({ angle: v }, 'Rotate')} />
        <RotationDial angle={obj.angle || 0} />
      </div>
      <div className="flip-row">
        <button className="btn" onClick={() => controller.flip('h')}><Icon name="flipH" size={14} /> Flip H</button>
        <button className="btn" onClick={() => controller.flip('v')}><Icon name="flipV" size={14} /> Flip V</button>
      </div>
    </Section>
  )
}

function RotationDial({ angle }) {
  const onDrag = (e) => {
    const dial = e.currentTarget
    const move = (ev) => {
      const r = dial.getBoundingClientRect()
      const cx = r.left + r.width / 2
      const cy = r.top + r.height / 2
      let a = (Math.atan2(ev.clientY - cy, ev.clientX - cx) * 180) / Math.PI + 90
      if (a < 0) a += 360
      controller.liveUpdate({ angle: Math.round(a) })
    }
    const up = () => {
      window.removeEventListener('mousemove', move)
      window.removeEventListener('mouseup', up)
      controller.commitLive('Rotate')
    }
    window.addEventListener('mousemove', move)
    window.addEventListener('mouseup', up)
  }
  return (
    <div className="rotate-dial" onMouseDown={onDrag} title="Drag to rotate">
      <div className="dial-pointer" style={{ transform: `rotate(${angle}deg)` }} />
    </div>
  )
}

export function AppearanceSection({ obj }) {
  return (
    <Section title="Appearance">
      <RangeField
        label="Opacity"
        value={Math.round((obj.opacity ?? 1) * 100)}
        min={0}
        max={100}
        format={(v) => `${v}%`}
        onLive={(v) => controller.liveUpdate({ opacity: v / 100 })}
        onCommit={() => controller.commitLive('Change opacity')}
      />
      <SelectField
        label="Blend mode"
        value={obj.globalCompositeOperation || 'source-over'}
        options={BLEND_MODES}
        onChange={(v) => controller.updateActive({ globalCompositeOperation: v }, 'Change blend mode')}
      />
    </Section>
  )
}

function ShapeFillSection({ obj }) {
  const isLine = obj.type === 'line'
  return (
    <Section title="Fill">
      {!isLine && (
        <ColorField label="Fill color" value={typeof obj.fill === 'string' ? obj.fill : '#cccccc'} onChange={(c) => controller.updateActive({ fill: c }, 'Change fill')} />
      )}
      <ColorField label="Stroke color" value={obj.stroke || '#000000'} onChange={(c) => controller.updateActive({ stroke: c }, 'Change stroke')} />
      <NumField label="Stroke width" value={obj.strokeWidth || 0} min={0} onChange={(v) => controller.updateActive({ strokeWidth: v }, 'Change stroke')} />
    </Section>
  )
}

function AdjustmentsSection({ obj }) {
  const adj = obj.adjustments || { brightness: 0, contrast: 0, saturation: 0, hue: 0 }
  const set = (key, v, commit) => {
    obj.adjustments = { ...adj, [key]: v }
    applyEffectsToImage(obj, obj.effects)
    controller.get().renderAll()
    if (commit) controller.commitLive('Adjust image')
  }
  return (
    <Section title="Image adjustments">
      <RangeField label="Brightness" value={adj.brightness} min={-100} max={100} onLive={(v) => set('brightness', v)} onCommit={(v) => set('brightness', v, true)} />
      <RangeField label="Contrast" value={adj.contrast} min={-100} max={100} onLive={(v) => set('contrast', v)} onCommit={(v) => set('contrast', v, true)} />
      <RangeField label="Saturation" value={adj.saturation} min={-100} max={100} onLive={(v) => set('saturation', v)} onCommit={(v) => set('saturation', v, true)} />
      <RangeField label="Hue rotate" value={adj.hue} min={0} max={360} format={(v) => `${v}°`} onLive={(v) => set('hue', v)} onCommit={(v) => set('hue', v, true)} />
    </Section>
  )
}
