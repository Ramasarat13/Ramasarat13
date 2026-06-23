import { useStore } from '../store/useStore'
import Icon from './Icon'

export default function Toasts() {
  const toasts = useStore((s) => s.toasts)
  const dismiss = useStore((s) => s.dismissToast)
  return (
    <div className="toast-stack">
      {toasts.map((t) => (
        <div key={t.id} className={`toast ${t.kind}`} onClick={() => dismiss(t.id)}>
          <Icon name={t.kind === 'error' ? 'close' : t.kind === 'success' ? 'check' : 'sparkles'} size={14} />
          <span>{t.message}</span>
        </div>
      ))}
    </div>
  )
}
