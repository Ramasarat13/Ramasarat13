import { useEffect } from 'react'
import { useStore } from '../store/useStore'
import { controller } from '../canvas/controller'

// Global keyboard shortcuts for the editor.
export function useKeyboard() {
  const setUI = useStore((s) => s.setUI)
  useEffect(() => {
    function isTyping(e) {
      const t = e.target
      const tag = t.tagName
      return (
        tag === 'INPUT' ||
        tag === 'TEXTAREA' ||
        t.isContentEditable ||
        // fabric inline text editing uses a hidden textarea
        document.querySelector('.canvas-container textarea:focus')
      )
    }

    function onKey(e) {
      const mod = e.metaKey || e.ctrlKey
      // The "?" overlay should still work even outside fields
      if (!mod && e.key === '?') {
        e.preventDefault()
        setUI({ shortcutsOpen: true })
        return
      }
      if (isTyping(e)) return

      const k = e.key.toLowerCase()

      if (mod && k === 'z' && !e.shiftKey) {
        e.preventDefault()
        controller.undo()
        return
      }
      if (mod && (k === 'z' && e.shiftKey || k === 'y')) {
        e.preventDefault()
        controller.redo()
        return
      }
      if (mod && k === 'd') {
        e.preventDefault()
        controller.duplicateSelected()
        return
      }
      if (mod && k === 'a') {
        e.preventDefault()
        controller.selectAll()
        return
      }
      if (mod && k === 'g') {
        e.preventDefault()
        controller.groupSelected()
        return
      }
      if (mod && k === 'e') {
        e.preventDefault()
        setUI({ exportOpen: true })
        return
      }
      if (mod) return // leave other mod combos to the browser

      switch (k) {
        case 'v':
          setUI({ activeTool: 'select' })
          break
        case 't':
          setUI({ activeTool: 'text' })
          controller.addText()
          break
        case 'g':
          setUI({ activeTool: 'pan' })
          break
        case 'delete':
        case 'backspace':
          e.preventDefault()
          controller.deleteSelected()
          break
        case ']':
          controller.bringForward()
          break
        case '[':
          controller.sendBackward()
          break
        case 'escape':
          setUI({ fontPickerOpen: false, exportOpen: false, shortcutsOpen: false, paletteOpen: false })
          break
        default:
          break
      }
    }

    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [setUI])
}
