import { useState } from 'react'
import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'
import { Logo } from './SetupScreen'
import Icon from './Icon'

const ALIGN = [
  ['alignLeft', 'left', 'Align left'],
  ['alignCenterH', 'center-h', 'Align center'],
  ['alignRight', 'right', 'Align right'],
  ['alignTop', 'top', 'Align top'],
  ['alignMiddle', 'middle', 'Align middle'],
  ['alignBottom', 'bottom', 'Align bottom'],
]

export default function TopBar() {
  const project = useStore((s) => s.project)
  const setProject = useStore((s) => s.setProject)
  const zoom = useStore((s) => s.zoom)
  const showGrid = useStore((s) => s.showGrid)
  const showRulers = useStore((s) => s.showRulers)
  const toggleGrid = useStore((s) => s.toggleGrid)
  const toggleRulers = useStore((s) => s.toggleRulers)
  const canUndo = useStore((s) => s.canUndo)
  const canRedo = useStore((s) => s.canRedo)
  const selectedIds = useStore((s) => s.selectedIds)
  const setUI = useStore((s) => s.setUI)
  const [editing, setEditing] = useState(false)

  const multi = selectedIds.length >= 2
  const z = Math.round(zoom * 100)

  function fit() {
    window.dispatchEvent(new CustomEvent('pc-fit'))
  }

  return (
    <header className="topbar">
      <div className="topbar-left">
        <Logo size={16} />
        <div className="topbar-divider" />
        {editing ? (
          <input
            className="title-input"
            autoFocus
            defaultValue={project.name}
            onBlur={(e) => {
              setProject({ name: e.target.value || 'Untitled poster' })
              setEditing(false)
            }}
            onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()}
          />
        ) : (
          <button className="title-btn" onClick={() => setEditing(true)} title="Click to rename">
            {project.name}
          </button>
        )}
      </div>

      <div className="topbar-center">
        {multi && (
          <div className="align-tools">
            {ALIGN.map(([icon, mode, title]) => (
              <button key={mode} className="btn icon" title={title} onClick={() => controller.align(mode)}>
                <Icon name={icon} />
              </button>
            ))}
            <div className="topbar-divider" />
            <button className="btn icon" title="Distribute horizontally" onClick={() => controller.distribute('h')}>
              <Icon name="distH" />
            </button>
            <button className="btn icon" title="Distribute vertically" onClick={() => controller.distribute('v')}>
              <Icon name="distV" />
            </button>
          </div>
        )}
        {!multi && (
          <div className="zoom-controls">
            <button className="btn icon" title="Zoom out" onClick={() => controller.setZoomTo(zoom - 0.1)}>
              <Icon name="minus" />
            </button>
            <span className="zoom-readout">{z}%</span>
            <button className="btn icon" title="Zoom in" onClick={() => controller.setZoomTo(zoom + 0.1)}>
              <Icon name="plus" />
            </button>
            <button className="btn icon" title="Fit to screen" onClick={fit}>
              <Icon name="fit" />
            </button>
            <div className="topbar-divider" />
            <button className={`btn icon ${showGrid ? 'active' : ''}`} title="Toggle grid" onClick={toggleGrid}>
              <Icon name="grid" />
            </button>
            <button className={`btn icon ${showRulers ? 'active' : ''}`} title="Toggle rulers" onClick={toggleRulers}>
              <Icon name="ruler" />
            </button>
          </div>
        )}
      </div>

      <div className="topbar-right">
        <button className="btn icon" title="History" onClick={() => setUI({ historyOpen: !useStore.getState().ui.historyOpen })}>
          <Icon name="history" />
        </button>
        <button className="btn icon" title="Keyboard shortcuts (?)" onClick={() => setUI({ shortcutsOpen: true })}>
          <Icon name="keyboard" />
        </button>
        <div className="topbar-divider" />
        <button className="btn icon" title="Undo (Cmd+Z)" disabled={!canUndo} onClick={() => controller.undo()}>
          <Icon name="undo" />
        </button>
        <button className="btn icon" title="Redo (Cmd+Shift+Z)" disabled={!canRedo} onClick={() => controller.redo()}>
          <Icon name="redo" />
        </button>
        <button className="btn accent export-btn" onClick={() => setUI({ exportOpen: true })}>
          <Icon name="download" size={15} />
          Export
        </button>
      </div>
    </header>
  )
}
