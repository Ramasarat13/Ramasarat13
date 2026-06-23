import { useStore } from '../store/useStore'
import { useKeyboard } from '../hooks/useKeyboard'
import TopBar from './TopBar'
import LeftPanel from './LeftPanel'
import RightPanel from './RightPanel'
import CanvasStage from './CanvasStage'
import FontPickerModal from './FontPickerModal'
import ShortcutsOverlay from './ShortcutsOverlay'
import PaletteGenerator from './PaletteGenerator'
import HistoryPanel from './HistoryPanel'

export default function Editor() {
  useKeyboard()
  const ui = useStore((s) => s.ui)
  return (
    <div className="editor-shell">
      <TopBar />
      <div className="editor-body">
        <LeftPanel />
        <CanvasStage />
        <RightPanel />
      </div>
      {ui.historyOpen && <HistoryPanel />}
      {ui.fontPickerOpen && <FontPickerModal />}
      {ui.shortcutsOpen && <ShortcutsOverlay />}
      {ui.paletteOpen && <PaletteGenerator />}
    </div>
  )
}
