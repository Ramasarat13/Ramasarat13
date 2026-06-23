// Canvas size presets for Screen 1 (Canvas Setup)
// `icon` is a key resolved by the PresetIcon component.
export const PRESETS = [
  { name: 'Instagram Post', w: 1080, h: 1080, icon: 'instagram' },
  { name: 'Instagram Story', w: 1080, h: 1920, icon: 'instagram' },
  { name: 'Instagram Landscape', w: 1080, h: 566, icon: 'instagram' },
  { name: 'X (Twitter) Post', w: 1200, h: 675, icon: 'x' },
  { name: 'X Header', w: 1500, h: 500, icon: 'x' },
  { name: 'LinkedIn Post', w: 1200, h: 627, icon: 'linkedin' },
  { name: 'LinkedIn Cover', w: 1584, h: 396, icon: 'linkedin' },
  { name: 'Facebook Post', w: 1200, h: 630, icon: 'facebook' },
  { name: 'YouTube Thumbnail', w: 1280, h: 720, icon: 'youtube' },
  { name: 'A4 Print', w: 2480, h: 3508, icon: 'print' },
  { name: 'A3 Print', w: 3508, h: 4961, icon: 'print' },
  { name: 'Business Card', w: 1050, h: 600, icon: 'card' },
  { name: 'Presentation 16:9', w: 1920, h: 1080, icon: 'presentation' },
  { name: 'Custom', w: 1080, h: 1350, icon: 'custom', custom: true },
]

export const SIZE_MIN = 100
export const SIZE_MAX = 8000
