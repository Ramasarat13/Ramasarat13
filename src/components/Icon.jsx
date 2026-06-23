// Lightweight inline SVG icon set. Stroke icons inherit currentColor.
const paths = {
  // platform / preset icons
  instagram: <><rect x="3" y="3" width="18" height="18" rx="5" /><circle cx="12" cy="12" r="4" /><circle cx="17.5" cy="6.5" r="0.6" fill="currentColor" /></>,
  x: <path d="M4 4l16 16M20 4L4 20" />,
  linkedin: <><rect x="3" y="3" width="18" height="18" rx="3" /><path d="M7 10v7M7 7v.01M11 17v-4a2 2 0 014 0v4" /></>,
  facebook: <path d="M14 8h2V5h-2a3 3 0 00-3 3v2H9v3h2v6h3v-6h2l1-3h-3V8a1 1 0 011-1z" />,
  youtube: <><rect x="3" y="6" width="18" height="12" rx="3" /><path d="M11 9.5l4 2.5-4 2.5z" fill="currentColor" /></>,
  print: <><rect x="6" y="3" width="12" height="6" /><rect x="4" y="9" width="16" height="8" rx="1" /><rect x="7" y="14" width="10" height="6" /></>,
  card: <><rect x="3" y="6" width="18" height="12" rx="2" /><path d="M6 14h5M6 11h8" /></>,
  presentation: <><rect x="3" y="4" width="18" height="12" rx="1" /><path d="M12 16v4M8 20h8" /></>,
  custom: <><path d="M12 5v14M5 12h14" /></>,
  // ui icons
  eye: <><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z" /><circle cx="12" cy="12" r="3" /></>,
  eyeOff: <><path d="M3 3l18 18M10.6 10.6a3 3 0 004 4M9.9 5.1A9.5 9.5 0 0112 5c6.5 0 10 7 10 7a17 17 0 01-3.2 3.9M6.6 6.6A17 17 0 002 12s3.5 7 10 7a9.5 9.5 0 003.1-.5" /></>,
  lock: <><rect x="5" y="11" width="14" height="9" rx="2" /><path d="M8 11V8a4 4 0 018 0v3" /></>,
  unlock: <><rect x="5" y="11" width="14" height="9" rx="2" /><path d="M8 11V8a4 4 0 017.9-1" /></>,
  image: <><rect x="3" y="3" width="18" height="18" rx="2" /><circle cx="8.5" cy="8.5" r="1.5" /><path d="M21 15l-5-5L5 21" /></>,
  type: <path d="M4 6h16M12 6v14M9 20h6" />,
  shapes: <><rect x="3" y="13" width="8" height="8" rx="1" /><circle cx="17" cy="17" r="4" /><path d="M9 3l5 8H4z" /></>,
  trash: <><path d="M4 7h16M9 7V5a2 2 0 012-2h2a2 2 0 012 2v2M6 7l1 13h10l1-13" /></>,
  copy: <><rect x="9" y="9" width="11" height="11" rx="2" /><path d="M5 15V5a2 2 0 012-2h10" /></>,
  undo: <path d="M9 14L4 9l5-5M4 9h11a5 5 0 010 10h-3" />,
  redo: <path d="M15 14l5-5-5-5M20 9H9a5 5 0 000 10h3" />,
  plus: <path d="M12 5v14M5 12h14" />,
  minus: <path d="M5 12h14" />,
  fit: <path d="M4 9V5a1 1 0 011-1h4M20 9V5a1 1 0 00-1-1h-4M4 15v4a1 1 0 001 1h4M20 15v4a1 1 0 01-1 1h-4" />,
  grid: <><path d="M3 9h18M3 15h18M9 3v18M15 3v18" /></>,
  ruler: <><rect x="3" y="8" width="18" height="8" rx="1" /><path d="M7 8v3M11 8v4M15 8v3M19 8v4" /></>,
  download: <path d="M12 3v12m0 0l-4-4m4 4l4-4M4 19h16" />,
  flipH: <path d="M12 3v18M7 8l-4 4 4 4M17 8l4 4-4 4" />,
  flipV: <path d="M3 12h18M8 7l4-4 4 4M8 17l4 4 4-4" />,
  chain: <><path d="M9 12a3 3 0 013-3h2a3 3 0 010 6h-1" /><path d="M15 12a3 3 0 01-3 3h-2a3 3 0 010-6h1" /></>,
  search: <><circle cx="11" cy="11" r="7" /><path d="M21 21l-4-4" /></>,
  check: <path d="M5 12l5 5L20 6" />,
  close: <path d="M6 6l12 12M18 6L6 18" />,
  dice: <><rect x="4" y="4" width="16" height="16" rx="3" /><circle cx="9" cy="9" r="1" fill="currentColor" /><circle cx="15" cy="15" r="1" fill="currentColor" /><circle cx="12" cy="12" r="1" fill="currentColor" /></>,
  sparkles: <path d="M12 3l1.8 4.2L18 9l-4.2 1.8L12 15l-1.8-4.2L6 9l4.2-1.8zM18 14l.9 2.1L21 17l-2.1.9L18 20l-.9-2.1L15 17l2.1-.9z" />,
  history: <><path d="M3 12a9 9 0 109-9 9 9 0 00-7 3.5M3 4v4h4" /><path d="M12 8v4l3 2" /></>,
  layers: <path d="M12 3l9 5-9 5-9-5 9-5zM3 13l9 5 9-5M3 17l9 5 9-5" />,
  alignLeft: <path d="M4 4v16M8 8h10M8 16h6" />,
  alignCenterH: <path d="M12 4v16M7 8h10M9 16h6" />,
  alignRight: <path d="M20 4v16M6 8h10M10 16h8" />,
  alignTop: <path d="M4 4h16M8 8v10M16 8v6" />,
  alignMiddle: <path d="M4 12h16M8 7v10M16 9v6" />,
  alignBottom: <path d="M4 20h16M8 6v10M16 10v6" />,
  distH: <path d="M4 4v16M20 4v16M12 8v8" />,
  distV: <path d="M4 4h16M4 20h16M8 12h8" />,
  keyboard: <><rect x="2" y="6" width="20" height="12" rx="2" /><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10" /></>,
  drag: <><circle cx="9" cy="6" r="1" fill="currentColor" /><circle cx="9" cy="12" r="1" fill="currentColor" /><circle cx="9" cy="18" r="1" fill="currentColor" /><circle cx="15" cy="6" r="1" fill="currentColor" /><circle cx="15" cy="12" r="1" fill="currentColor" /><circle cx="15" cy="18" r="1" fill="currentColor" /></>,
}

export default function Icon({ name, size = 16, strokeWidth = 1.7, style, className }) {
  const p = paths[name]
  if (!p) return null
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      style={style}
      className={className}
      aria-hidden="true"
    >
      {p}
    </svg>
  )
}
