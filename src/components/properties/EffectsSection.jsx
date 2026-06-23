import { useRef, useState } from 'react'
import { controller } from '../../canvas/controller'
import { EFFECT_DEFS, defaultEffect, applyEffectsToImage } from '../../canvas/effects'
import { Section, RangeField, SelectField, ColorField } from './controls'
import Icon from '../Icon'

export default function EffectsSection({ obj }) {
  const [drawer, setDrawer] = useState(false)
  const [expanded, setExpanded] = useState(null)
  const effects = obj.effects || []
  const dragIndex = useRef(null)

  const update = (next) => controller.setEffects(obj.id, next)

  const addEffect = (type) => {
    const fx = defaultEffect(type)
    update([...effects, fx])
    setExpanded(fx.id)
    setDrawer(false)
  }

  const patchParam = (id, key, value, commit) => {
    const next = effects.map((e) => (e.id === id ? { ...e, params: { ...e.params, [key]: value } } : e))
    if (commit) update(next)
    else {
      // live preview without committing history
      obj.effects = next
      applyEffectsToImage(obj, next)
      controller.get().renderAll()
    }
  }

  return (
    <Section
      title="Effects"
      right={
        <button className="btn icon" title="Add effect" onClick={() => setDrawer((v) => !v)}>
          <Icon name="plus" size={14} />
        </button>
      }
    >
      {effects.length === 0 && <p className="hint">No effects yet. Click + to add one.</p>}

      <div className="fx-stack">
        {effects.map((fx, i) => {
          const def = EFFECT_DEFS[fx.type]
          const intensityKey = def.params.intensity ? 'intensity' : def.params.opacity ? 'opacity' : null
          return (
            <div
              key={fx.id}
              className={`fx-row ${fx.enabled ? '' : 'disabled'}`}
              draggable
              onDragStart={() => (dragIndex.current = i)}
              onDragOver={(e) => e.preventDefault()}
              onDrop={() => {
                if (dragIndex.current !== null && dragIndex.current !== i) {
                  const next = [...effects]
                  const [moved] = next.splice(dragIndex.current, 1)
                  next.splice(i, 0, moved)
                  update(next)
                }
                dragIndex.current = null
              }}
            >
              <div className="fx-head">
                <span className="fx-drag"><Icon name="drag" size={12} /></span>
                <button className="fx-name" onClick={() => setExpanded(expanded === fx.id ? null : fx.id)}>
                  {def.label}
                </button>
                <button className="layer-icon-btn" title="Toggle" onClick={() => update(effects.map((e) => e.id === fx.id ? { ...e, enabled: !e.enabled } : e))}>
                  <Icon name={fx.enabled ? 'eye' : 'eyeOff'} size={13} />
                </button>
                <button className="layer-icon-btn danger" title="Remove" onClick={() => update(effects.filter((e) => e.id !== fx.id))}>
                  <Icon name="trash" size={13} />
                </button>
              </div>

              {intensityKey && expanded !== fx.id && (
                <input
                  type="range"
                  className="fx-quick"
                  min={0}
                  max={100}
                  value={fx.params[intensityKey]}
                  onChange={(e) => patchParam(fx.id, intensityKey, Number(e.target.value))}
                  onMouseUp={(e) => patchParam(fx.id, intensityKey, Number(e.target.value), true)}
                />
              )}

              {expanded === fx.id && (
                <div className="fx-params">
                  {Object.entries(def.params).map(([key, p]) => (
                    <EffectParam key={key} fxId={fx.id} pKey={key} p={p} value={fx.params[key]} onChange={patchParam} />
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {drawer && (
        <div className="fx-drawer">
          <div className="fx-drawer-head">
            <span>Add effect</span>
            <button className="layer-icon-btn" onClick={() => setDrawer(false)}><Icon name="close" size={14} /></button>
          </div>
          <div className="fx-drawer-grid">
            {Object.entries(EFFECT_DEFS).map(([type, def]) => (
              <button key={type} className="fx-add-cell" onClick={() => addEffect(type)}>
                <Icon name="sparkles" size={16} />
                <span>{def.label}</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </Section>
  )
}

function EffectParam({ fxId, pKey, p, value, onChange }) {
  if (p.type === 'range') {
    return (
      <RangeField
        label={p.label}
        value={value}
        min={p.min}
        max={p.max}
        onLive={(v) => onChange(fxId, pKey, v)}
        onCommit={(v) => onChange(fxId, pKey, v, true)}
      />
    )
  }
  if (p.type === 'select') {
    return <SelectField label={p.label} value={value} options={p.options} onChange={(v) => onChange(fxId, pKey, v, true)} />
  }
  if (p.type === 'color') {
    return <ColorField label={p.label} value={value} onChange={(v) => onChange(fxId, pKey, v, true)} />
  }
  if (p.type === 'seed') {
    return (
      <div className="field">
        <span className="field-label">{p.label}</span>
        <button className="btn dice-btn" onClick={(e) => {
          e.currentTarget.classList.remove('rolled')
          void e.currentTarget.offsetWidth
          e.currentTarget.classList.add('rolled')
          onChange(fxId, pKey, Math.floor(Math.random() * 9999) + 1, true)
        }}>
          <Icon name="dice" size={15} /> Re-randomize
        </button>
      </div>
    )
  }
  return null
}
