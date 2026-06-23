import { useEffect, useState } from 'react'

export function Section({ title, children, right }) {
  return (
    <div className="prop-section">
      <div className="prop-section-head">
        <h3 className="section-title">{title}</h3>
        {right}
      </div>
      {children}
    </div>
  )
}

// Controlled number field that reflects an external value but allows free typing.
export function NumField({ label, value, onChange, min, max, step = 1, suffix }) {
  const [local, setLocal] = useState(String(Math.round(value)))
  useEffect(() => setLocal(String(Math.round(value))), [value])
  const commit = () => {
    let v = parseFloat(local)
    if (isNaN(v)) v = value
    if (min !== undefined) v = Math.max(min, v)
    if (max !== undefined) v = Math.min(max, v)
    onChange(v)
  }
  return (
    <label className="field">
      {label && <span className="field-label">{label}</span>}
      <div className="num-wrap">
        <input
          className="num-input"
          type="number"
          value={local}
          step={step}
          min={min}
          max={max}
          onChange={(e) => setLocal(e.target.value)}
          onBlur={commit}
          onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()}
        />
        {suffix && <span className="num-suffix">{suffix}</span>}
      </div>
    </label>
  )
}

// Range slider with live (no-history) updates while dragging, commit on release.
export function RangeField({ label, value, min, max, step = 1, onLive, onCommit, format }) {
  const [v, setV] = useState(value)
  useEffect(() => setV(value), [value])
  return (
    <label className="field">
      <div className="range-head">
        <span className="field-label">{label}</span>
        <span className="range-val">{format ? format(v) : v}</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={v}
        onChange={(e) => {
          const nv = Number(e.target.value)
          setV(nv)
          onLive?.(nv)
        }}
        onMouseUp={() => onCommit?.(v)}
        onTouchEnd={() => onCommit?.(v)}
      />
    </label>
  )
}

export function ColorField({ label, value, onChange }) {
  return (
    <label className="field">
      {label && <span className="field-label">{label}</span>}
      <div className="color-field">
        <span className="color-chip" style={{ background: value }}>
          <input type="color" value={toHex(value)} onChange={(e) => onChange(e.target.value)} />
        </span>
        <input
          className="input"
          value={value}
          onChange={(e) => onChange(e.target.value)}
        />
      </div>
    </label>
  )
}

export function SelectField({ label, value, options, onChange }) {
  return (
    <label className="field">
      {label && <span className="field-label">{label}</span>}
      <select className="input" value={value} onChange={(e) => onChange(e.target.value)}>
        {options.map((o) => {
          const [val, lbl] = Array.isArray(o) ? o : [o, o]
          return <option key={val} value={val}>{lbl}</option>
        })}
      </select>
    </label>
  )
}

function toHex(c) {
  if (typeof c === 'string' && c.startsWith('#')) return c.slice(0, 7)
  return '#000000'
}
