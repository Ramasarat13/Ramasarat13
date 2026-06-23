import { useStore } from '../store/useStore'
import Icon from './Icon'

const SHORTCUTS = [
  ['V', 'Select tool'],
  ['T', 'Text tool'],
  ['G', 'Grab / pan tool'],
  ['Cmd Z', 'Undo'],
  ['Cmd Shift Z', 'Redo'],
  ['Cmd D', 'Duplicate layer'],
  ['Delete', 'Delete layer'],
  ['[ / ]', 'Move layer down / up'],
  ['Cmd A', 'Select all layers'],
  ['Cmd G', 'Group layers'],
  ['Cmd E', 'Open export panel'],
  ['Space + drag', 'Pan canvas'],
  ['Ctrl + scroll', 'Zoom canvas'],
  ['?', 'Show this help'],
]

export default function ShortcutsOverlay() {
  const setUI = useStore((s) => s.setUI)
  const close = () => setUI({ shortcutsOpen: false })
  return (
    <div className="modal-overlay" onMouseDown={close}>
      <div className="shortcuts-modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="font-modal-head">
          <h3 className="section-title"><Icon name="keyboard" size={15} /> Keyboard shortcuts</h3>
          <button className="btn icon" onClick={close}><Icon name="close" /></button>
        </div>
        <div className="shortcuts-grid">
          {SHORTCUTS.map(([keys, label]) => (
            <div key={label} className="shortcut-item">
              <span className="shortcut-label">{label}</span>
              <span className="shortcut-keys">
                {keys.split(' ').map((k, i) => <kbd key={i} className="kbd">{k}</kbd>)}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
