import { useState } from 'react'
import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'
import { Section, RangeField } from './properties/controls'
import Icon from './Icon'

const FORMATS = ['png', 'jpeg', 'webp', 'svg']
const SCALES = [1, 2, 3]

export default function ExportPanel() {
  const project = useStore((s) => s.project)
  const setUI = useStore((s) => s.setUI)
  const selectedIds = useStore((s) => s.selectedIds)
  const pushToast = useStore((s) => s.pushToast)
  const [format, setFormat] = useState('png')
  const [quality, setQuality] = useState(92)
  const [scale, setScale] = useState(2)
  const [customScale, setCustomScale] = useState(4)
  const [useCustom, setUseCustom] = useState(false)
  const [crop, setCrop] = useState('full')
  const [filename, setFilename] = useState(project.name.replace(/\s+/g, '-').toLowerCase())
  const [shimmering, setShimmering] = useState(false)

  const lossy = format === 'jpeg' || format === 'webp'
  const hasSelection = selectedIds.length > 0

  function download() {
    setShimmering(true)
    setTimeout(() => setShimmering(false), 900)
    try {
      const multiplier = useCustom ? Number(customScale) || 1 : scale
      const result = controller.exportImage({
        format,
        quality: quality / 100,
        multiplier,
        selectionOnly: crop === 'selection' && hasSelection,
      })
      const a = document.createElement('a')
      if (result.svg) {
        const blob = new Blob([result.svg], { type: 'image/svg+xml' })
        a.href = URL.createObjectURL(blob)
        a.download = `${filename || 'poster'}.svg`
      } else {
        a.href = result.dataUrl
        a.download = `${filename || 'poster'}.${format === 'jpeg' ? 'jpg' : format}`
      }
      document.body.appendChild(a)
      a.click()
      a.remove()
      pushToast('Export complete — check your downloads.', 'success')
    } catch (e) {
      pushToast('Export failed. Try reducing the canvas size or image count.', 'error')
    }
  }

  return (
    <div className="panel-scroll export-panel">
      <div className="export-head">
        <h3 className="section-title">Export</h3>
        <button className="btn icon" onClick={() => setUI({ exportOpen: false })} title="Close"><Icon name="close" /></button>
      </div>

      <Section title="Format">
        <div className="pill-row">
          {FORMATS.map((f) => (
            <button key={f} className={`pill ${format === f ? 'active' : ''}`} onClick={() => setFormat(f)}>{f.toUpperCase()}</button>
          ))}
        </div>
      </Section>

      {lossy && (
        <Section title="Quality">
          <RangeField label="Quality" value={quality} min={10} max={100} format={(v) => `${v}%`} onLive={setQuality} onCommit={setQuality} />
        </Section>
      )}

      {format !== 'svg' && (
        <Section title="Scale">
          <div className="pill-row">
            {SCALES.map((s) => (
              <button key={s} className={`pill ${!useCustom && scale === s ? 'active' : ''}`} onClick={() => { setUseCustom(false); setScale(s) }}>{s}×</button>
            ))}
            <button className={`pill ${useCustom ? 'active' : ''}`} onClick={() => setUseCustom(true)}>Custom</button>
          </div>
          {useCustom && (
            <input className="num-input" type="number" min={1} max={8} step={0.5} value={customScale} onChange={(e) => setCustomScale(e.target.value)} style={{ marginTop: 8 }} />
          )}
          <p className="hint">Output: {Math.round(project.width * (useCustom ? customScale : scale))} × {Math.round(project.height * (useCustom ? customScale : scale))} px</p>
        </Section>
      )}

      <Section title="Canvas crop">
        <div className="seg-control">
          <button className={`seg ${crop === 'full' ? 'active' : ''}`} onClick={() => setCrop('full')}>Full canvas</button>
          <button className={`seg ${crop === 'selection' ? 'active' : ''}`} disabled={!hasSelection} onClick={() => setCrop('selection')}>Selection only</button>
        </div>
      </Section>

      <Section title="Filename">
        <div className="filename-row">
          <input className="input" value={filename} onChange={(e) => setFilename(e.target.value)} />
          <span className="filename-ext">.{format === 'jpeg' ? 'jpg' : format}</span>
        </div>
      </Section>

      <button className={`btn accent export-download ${shimmering ? 'shimmer' : ''}`} onClick={download}>
        <Icon name="download" size={15} /> Download
      </button>

      <button className="btn share-disabled" disabled title="Coming soon">
        Copy shareable link
        <span className="soon-tag">Coming soon</span>
      </button>
    </div>
  )
}
