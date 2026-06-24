import { useMemo, useState } from 'react'
import { useStore } from '../store/useStore'
import { PRESETS, SIZE_MIN, SIZE_MAX } from '../data/presets'
import Icon from './Icon'

export default function SetupScreen() {
  const startProject = useStore((s) => s.startProject)
  const [selected, setSelected] = useState(0) // Instagram Post default
  const [customW, setCustomW] = useState(1080)
  const [customH, setCustomH] = useState(1350)
  const [lockRatio, setLockRatio] = useState(false)
  const ratio = useMemo(() => customW / customH, [lockRatio]) // captured when toggled on

  const preset = PRESETS[selected]
  const isCustom = !!preset.custom

  const clamp = (v) => Math.max(SIZE_MIN, Math.min(SIZE_MAX, v || SIZE_MIN))

  function handleW(v) {
    const w = Number(v)
    setCustomW(v)
    if (lockRatio && w) setCustomH(Math.round(clamp(w) / ratio))
  }
  function handleH(v) {
    const h = Number(v)
    setCustomH(v)
    if (lockRatio && h) setCustomW(Math.round(clamp(h) * ratio))
  }

  function start() {
    const width = isCustom ? clamp(Number(customW)) : preset.w
    const height = isCustom ? clamp(Number(customH)) : preset.h
    const name = isCustom ? 'Custom poster' : preset.name
    startProject({ width, height, name, background: '#ffffff' })
  }

  const valid = !isCustom || (Number(customW) >= SIZE_MIN && Number(customH) >= SIZE_MIN)

  return (
    <div className="setup-shell">
      <div className="grain-overlay static" aria-hidden="true" />
      <header className="setup-logo">
        <Logo />
      </header>

      <div className="setup-modal">
        <h1 className="setup-headline">What are you making today?</h1>
        <p className="setup-sub">Pick a size to start — you can always change it later.</p>

        <div className="preset-grid">
          {PRESETS.map((p, i) => (
            <button
              key={p.name}
              className={`preset-card ${selected === i ? 'selected' : ''}`}
              onClick={() => setSelected(i)}
              onDoubleClick={() => !p.custom && (setSelected(i), start())}
            >
              <span className="preset-icon">
                <Icon name={p.icon} size={20} />
              </span>
              <span className="preset-name">{p.name}</span>
              <span className="preset-dims">
                {p.custom ? 'User-defined' : `${p.w} × ${p.h} px`}
              </span>
            </button>
          ))}
        </div>

        {isCustom && (
          <div className="custom-row">
            <div className="field">
              <span className="field-label">Width (px)</span>
              <input
                className="num-input"
                type="number"
                min={SIZE_MIN}
                max={SIZE_MAX}
                value={customW}
                onChange={(e) => handleW(e.target.value)}
              />
            </div>
            <button
              className={`btn icon ratio-lock ${lockRatio ? 'active' : ''}`}
              title="Lock aspect ratio"
              onClick={() => setLockRatio((v) => !v)}
            >
              <Icon name="chain" size={16} />
            </button>
            <div className="field">
              <span className="field-label">Height (px)</span>
              <input
                className="num-input"
                type="number"
                min={SIZE_MIN}
                max={SIZE_MAX}
                value={customH}
                onChange={(e) => handleH(e.target.value)}
              />
            </div>
          </div>
        )}

        <button className="btn accent start-cta" disabled={!valid} onClick={start}>
          Start designing →
        </button>
      </div>
    </div>
  )
}

export function Logo({ size = 18 }) {
  return (
    <div className="logo" style={{ fontSize: size }}>
      <span className="logo-mark">
        <Icon name="sparkles" size={size} />
      </span>
      <span className="logo-text">PosterCraft</span>
    </div>
  )
}
