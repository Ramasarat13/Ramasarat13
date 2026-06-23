import { useState } from 'react'
import { useStore } from '../../store/useStore'
import { controller } from '../../canvas/controller'
import { SIZE_MIN, SIZE_MAX } from '../../data/presets'
import { Section, NumField, ColorField } from './controls'
import Icon from '../Icon'

const UNITS = ['px', 'cm', 'in']
// conversion at 96 dpi (screen) for display only
const PER_PX = { px: 1, cm: 2.54 / 96, in: 1 / 96 }

export default function CanvasProperties() {
  const project = useStore((s) => s.project)
  const units = useStore((s) => s.units)
  const setUnits = useStore((s) => s.setUnits)
  const layers = useStore((s) => s.layers)
  const setUI = useStore((s) => s.setUI)
  const [w, setW] = useState(project.width)
  const [h, setH] = useState(project.height)

  const conv = (px) => Math.round(px * PER_PX[units] * 100) / 100

  function applySize() {
    const nw = Math.max(SIZE_MIN, Math.min(SIZE_MAX, w))
    const nh = Math.max(SIZE_MIN, Math.min(SIZE_MAX, h))
    controller.resizeCanvas(nw, nh)
  }

  const clips = layers.length > 0 && (w < project.width || h < project.height)
  const bg = project.background

  return (
    <>
      <Section title="Canvas">
        <label className="field">
          <span className="field-label">Name</span>
          <input className="input" defaultValue={project.name} onBlur={(e) => useStore.getState().setProject({ name: e.target.value })} />
        </label>
        <div className="grid-2">
          <NumField label="Width" value={w} min={SIZE_MIN} max={SIZE_MAX} onChange={setW} suffix="px" />
          <NumField label="Height" value={h} min={SIZE_MIN} max={SIZE_MAX} onChange={setH} suffix="px" />
        </div>
        {clips && <p className="warn-note">Reducing the canvas may clip existing content.</p>}
        <button className="btn" style={{ width: '100%' }} onClick={applySize}>Apply size</button>
        <div className="readout-row">
          <span className="field-label">In {units}</span>
          <span>{conv(project.width)} × {conv(project.height)} {units}</span>
        </div>
      </Section>

      <Section title="Units">
        <div className="seg-control">
          {UNITS.map((u) => (
            <button key={u} className={`seg ${units === u ? 'active' : ''}`} onClick={() => setUnits(u)}>{u}</button>
          ))}
        </div>
      </Section>

      <Section title="Background">
        <ColorField label="Color" value={typeof bg === 'string' ? bg : '#ffffff'} onChange={(c) => controller.applyBackground(c)} />
        <p className="hint">Gradients and patterns are available in the Assets → Backgrounds tab.</p>
        <button className="btn" style={{ width: '100%' }} onClick={() => setUI({ leftTab: 'assets', assetsTab: 'backgrounds' })}>
          Open background options
        </button>
      </Section>

      <Section title="Palette">
        <button className="btn accent" style={{ width: '100%' }} onClick={() => setUI({ paletteOpen: true })}>
          <Icon name="sparkles" size={14} /> Generate palette
        </button>
      </Section>
    </>
  )
}
