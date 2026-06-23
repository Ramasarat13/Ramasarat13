import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'
import ExportPanel from './ExportPanel'
import CanvasProperties from './properties/CanvasProperties'
import ImageProperties from './properties/ImageProperties'
import TextProperties from './properties/TextProperties'

export default function RightPanel() {
  const exportOpen = useStore((s) => s.ui.exportOpen)
  const selectedIds = useStore((s) => s.selectedIds)
  useStore((s) => s.rev) // re-render on geometry changes

  if (exportOpen) {
    return (
      <aside className="panel right-panel">
        <ExportPanel />
      </aside>
    )
  }

  const obj = controller.active()
  let content
  if (!obj || selectedIds.length === 0) {
    content = <CanvasProperties />
  } else if (selectedIds.length > 1) {
    content = <MultiSelectInfo count={selectedIds.length} />
  } else if (obj.layerType === 'text') {
    content = <TextProperties obj={obj} />
  } else if (obj.layerType === 'image') {
    content = <ImageProperties obj={obj} />
  } else {
    content = <ImageProperties obj={obj} shapeMode />
  }

  return <aside className="panel right-panel"><div className="panel-scroll">{content}</div></aside>
}

function MultiSelectInfo({ count }) {
  return (
    <div className="prop-section">
      <p className="section-title">{count} layers selected</p>
      <p className="panel-empty" style={{ padding: '8px 0' }}>
        Use the alignment and distribution tools in the top bar, or group them with <span className="kbd">Cmd G</span>.
      </p>
    </div>
  )
}
