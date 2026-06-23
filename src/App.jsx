import { useStore } from './store/useStore'
import SetupScreen from './components/SetupScreen'
import Editor from './components/Editor'
import Toasts from './components/Toasts'

export default function App() {
  const phase = useStore((s) => s.phase)
  return (
    <>
      {phase === 'setup' ? <SetupScreen /> : <Editor />}
      <Toasts />
    </>
  )
}
