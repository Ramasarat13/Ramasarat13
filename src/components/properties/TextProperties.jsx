import { useStore } from '../../store/useStore'
import { controller } from '../../canvas/controller'
import { Section, NumField, RangeField, ColorField, SelectField } from './controls'
import { TransformSection, AppearanceSection } from './ImageProperties'
import EffectsSection from './EffectsSection'
import Icon from '../Icon'

const ALIGN = [['left', 'alignLeft'], ['center', 'alignCenterH'], ['right', 'alignRight'], ['justify', 'distH']]
const WEIGHTS = [['normal', 'Regular'], ['500', 'Medium'], ['600', 'Semibold'], ['bold', 'Bold'], ['800', 'Extrabold']]

export default function TextProperties({ obj }) {
  const setUI = useStore((s) => s.setUI)
  const isGroup = obj.type === 'group'

  if (isGroup) {
    return (
      <>
        <Section title="Text group">
          <p className="hint">Double-click on canvas to edit the text blocks inside this group.</p>
        </Section>
        <TransformSection obj={obj} />
        <AppearanceSection obj={obj} />
      </>
    )
  }

  const upd = (patch, label) => controller.updateActive(patch, label)

  return (
    <>
      <Section title="Content">
        <textarea
          className="input"
          rows={3}
          value={obj.text}
          onChange={(e) => { obj.set('text', e.target.value); controller.get().renderAll() }}
          onBlur={() => controller.commitLive('Edit text')}
        />
        <p className="hint">Tip: double-click the text on the canvas to edit inline.</p>
      </Section>

      <Section title="Font">
        <button className="font-picker-btn" onClick={() => setUI({ fontPickerOpen: true })}>
          <span style={{ fontFamily: `"${obj.fontFamily}"` }}>{obj.fontFamily}</span>
          <Icon name="search" size={14} />
        </button>
        <div className="grid-2">
          <NumField label="Size" value={obj.fontSize} min={1} onChange={(v) => upd({ fontSize: v }, 'Change font size')} />
          <SelectField label="Weight" value={String(obj.fontWeight || 'normal')} options={WEIGHTS} onChange={(v) => upd({ fontWeight: v }, 'Change weight')} />
        </div>
        <div className="grid-2">
          <NumField label="Line height" value={Math.round((obj.lineHeight || 1.16) * 100) / 100} step={0.05} onChange={(v) => upd({ lineHeight: v }, 'Line height')} />
          <NumField label="Letter spacing" value={Math.round((obj.charSpacing || 0) / 10)} onChange={(v) => upd({ charSpacing: v * 10 }, 'Letter spacing')} />
        </div>
        <div className="field">
          <span className="field-label">Alignment</span>
          <div className="seg-control">
            {ALIGN.map(([val, icon]) => (
              <button key={val} className={`seg ${obj.textAlign === val ? 'active' : ''}`} onClick={() => upd({ textAlign: val }, 'Align text')}>
                <Icon name={icon} size={14} />
              </button>
            ))}
          </div>
        </div>
      </Section>

      <Section title="Color">
        <ColorField label="Text color" value={typeof obj.fill === 'string' ? obj.fill : '#111111'} onChange={(c) => upd({ fill: c }, 'Text color')} />
        <ColorField label="Background fill" value={obj.textBackgroundColor || '#ffffff'} onChange={(c) => upd({ textBackgroundColor: c }, 'Text background')} />
        {obj.textBackgroundColor && (
          <button className="btn" style={{ width: '100%' }} onClick={() => upd({ textBackgroundColor: '' }, 'Clear text background')}>
            Remove background fill
          </button>
        )}
      </Section>

      <TransformSection obj={obj} />
      <AppearanceSection obj={obj} />
      <EffectsSection obj={obj} />
    </>
  )
}
