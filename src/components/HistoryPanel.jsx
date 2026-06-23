import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'
import Icon from './Icon'

export default function HistoryPanel() {
  useStore((s) => s.canUndo)
  useStore((s) => s.canRedo)
  const setUI = useStore((s) => s.setUI)
  const list = controller.historyList()
  const currentIndex = list.length - 1 // top of past is current state

  return (
    <div className="history-panel">
      <div className="history-head">
        <span className="section-title"><Icon name="history" size={14} /> History</span>
        <button className="btn icon" onClick={() => setUI({ historyOpen: false })}><Icon name="close" size={14} /></button>
      </div>
      <div className="history-list">
        {list
          .slice()
          .reverse()
          .map((h) => (
            <button
              key={h.index}
              className={`history-item ${h.index === currentIndex ? 'current' : ''}`}
              onClick={() => controller.jumpTo(h.index)}
            >
              <span className="history-dot" />
              {h.label}
            </button>
          ))}
      </div>
    </div>
  )
}
