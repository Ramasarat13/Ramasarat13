import { useEffect, useMemo, useRef, useState } from 'react'
import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'
import { POPULAR_FONTS, ALL_FONTS, FONTS_BY_STYLE, loadGoogleFont } from '../data/fonts'
import Icon from './Icon'

const TABS = ['Popular', 'All Google Fonts', 'Browse by Style']
const VARIANTS = [
  { label: 'Regular', weight: 'normal', style: 'normal' },
  { label: 'Medium', weight: 500, style: 'normal' },
  { label: 'Bold', weight: 'bold', style: 'normal' },
  { label: 'Italic', weight: 'normal', style: 'italic' },
  { label: 'Bold Italic', weight: 'bold', style: 'italic' },
]

export default function FontPickerModal() {
  const setUI = useStore((s) => s.setUI)
  const pushToast = useStore((s) => s.pushToast)
  const [tab, setTab] = useState('Popular')
  const [query, setQuery] = useState('')
  const [sample, setSample] = useState('The quick brown fox')
  const current = controller.active()
  const [selected, setSelected] = useState(current?.fontFamily || 'Inter')

  const close = () => setUI({ fontPickerOpen: false })

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    const list = tab === 'Popular' ? POPULAR_FONTS : ALL_FONTS
    if (!q) return list
    return list.filter((f) => f.toLowerCase().includes(q))
  }, [query, tab])

  async function applyFont(family) {
    try {
      await loadGoogleFont(family, [400, 500, 700])
      setSelected(family)
      const obj = controller.active()
      if (obj) {
        obj.set('fontFamily', family)
        obj.initDimensions?.()
        obj.setCoords()
        controller.get().requestRenderAll()
      }
      controller.updateActive({ fontFamily: family }, `Change font to ${family}`)
    } catch (e) {
      pushToast("Couldn't load this font. Try another.", 'error')
    }
  }

  function applyVariant(v) {
    controller.updateActive({ fontWeight: v.weight, fontStyle: v.style }, 'Change variant')
  }

  return (
    <div className="modal-overlay" onMouseDown={close}>
      <div className="font-modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="font-modal-head">
          <div className="font-search">
            <Icon name="search" size={15} />
            <input
              className="font-search-input"
              placeholder="Search fonts…"
              value={query}
              autoFocus
              onChange={(e) => setQuery(e.target.value)}
            />
          </div>
          <div className="sample-edit">
            <span className="field-label">Preview</span>
            <input className="input" value={sample} onChange={(e) => setSample(e.target.value)} />
          </div>
          <button className="btn icon" onClick={close} title="Close"><Icon name="close" /></button>
        </div>

        <div className="font-tabs">
          {TABS.map((t) => (
            <button key={t} className={`font-tab ${tab === t ? 'active' : ''}`} onClick={() => setTab(t)}>{t}</button>
          ))}
        </div>

        {selected && (
          <div className="variant-row">
            <span className="field-label">Variants of {selected}:</span>
            {VARIANTS.map((v) => (
              <button key={v.label} className="variant-pill" onClick={() => applyVariant(v)}>{v.label}</button>
            ))}
          </div>
        )}

        <div className="font-modal-body">
          {tab === 'Browse by Style' ? (
            Object.entries(FONTS_BY_STYLE).map(([style, fonts]) => (
              <div key={style} className="style-block">
                <h4 className="style-title">{style}</h4>
                <div className="style-row">
                  {fonts
                    .filter((f) => !query || f.toLowerCase().includes(query.toLowerCase()))
                    .map((f) => (
                      <FontCard key={f} font={f} sample={sample} selected={selected === f} onUse={applyFont} compact />
                    ))}
                </div>
              </div>
            ))
          ) : (
            <div className="font-list">
              {filtered.map((f) => (
                <FontCard key={f} font={f} sample={sample} selected={selected === f} onUse={applyFont} />
              ))}
              {filtered.length === 0 && <p className="panel-empty">No fonts match “{query}”.</p>}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function FontCard({ font, sample, selected, onUse, compact }) {
  const ref = useRef(null)
  const [loaded, setLoaded] = useState(false)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        loadGoogleFont(font, [400, 700]).then(() => setLoaded(true)).catch(() => setLoaded(false))
        io.disconnect()
      }
    })
    io.observe(el)
    return () => io.disconnect()
  }, [font])

  return (
    <div ref={ref} className={`font-card ${compact ? 'compact' : ''} ${selected ? 'selected' : ''}`}>
      <div className="font-card-top">
        <span className="font-card-name">{font}</span>
        {selected && <span className="font-check"><Icon name="check" size={14} /></span>}
      </div>
      <div className="font-card-sample" style={{ fontFamily: loaded ? `"${font}"` : 'inherit' }}>
        {sample || 'The quick brown fox'}
      </div>
      <button className="font-use-btn" onClick={() => onUse(font)}>Use font</button>
    </div>
  )
}
