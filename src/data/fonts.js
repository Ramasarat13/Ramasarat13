// Font catalogue for the Font Picker Modal.
// Fonts are loaded on-demand from Google Fonts (see loadGoogleFont).

export const POPULAR_FONTS = [
  'Inter', 'DM Sans', 'Playfair Display', 'Space Grotesk', 'Bebas Neue',
  'Oswald', 'Montserrat', 'Anton', 'Raleway', 'Abril Fatface', 'Lobster',
  'Pacifico', 'Righteous', 'Poppins', 'Archivo Black', 'Cormorant Garamond',
  'Josefin Sans', 'Caveat', 'Bricolage Grotesque', 'Libre Baskerville',
  'Fraunces', 'Sora', 'Outfit', 'Syne', 'Unbounded', 'Cinzel', 'Teko',
  'Rubik', 'Work Sans', 'Bungee',
]

export const FONTS_BY_STYLE = {
  Display: [
    'Anton', 'Bebas Neue', 'Oswald', 'Archivo Black', 'Teko', 'Bungee',
    'Unbounded', 'Righteous', 'Syne', 'Bricolage Grotesque',
  ],
  Decorative: [
    'Lobster', 'Pacifico', 'Abril Fatface', 'Caveat', 'Cinzel', 'Fraunces',
    'Monoton', 'Press Start 2P', 'Shrikhand', 'Rampart One',
  ],
  'Sans-Serif': [
    'Inter', 'DM Sans', 'Montserrat', 'Poppins', 'Raleway', 'Work Sans',
    'Sora', 'Outfit', 'Rubik', 'Space Grotesk',
  ],
  Serif: [
    'Playfair Display', 'Cormorant Garamond', 'Libre Baskerville', 'Lora',
    'Merriweather', 'EB Garamond', 'Bitter', 'Crimson Text', 'Spectral',
    'Source Serif 4',
  ],
  Monospace: [
    'JetBrains Mono', 'Space Mono', 'IBM Plex Mono', 'Roboto Mono',
    'Fira Code', 'Inconsolata', 'Source Code Pro', 'Cousine', 'Overpass Mono',
    'DM Mono',
  ],
}

// A larger pool that stands in for the "All Google Fonts" tab. In a production
// build this would be fetched from the Google Fonts Developer API; here we ship
// a representative, alphabetised list so the tab is fully functional offline.
export const ALL_FONTS = Array.from(
  new Set([
    ...POPULAR_FONTS,
    ...Object.values(FONTS_BY_STYLE).flat(),
    'Roboto', 'Open Sans', 'Lato', 'Nunito', 'Nunito Sans', 'Quicksand',
    'Mukta', 'Manrope', 'Karla', 'Cabin', 'Dosis', 'PT Sans', 'PT Serif',
    'Noto Sans', 'Noto Serif', 'Hind', 'Heebo', 'Barlow', 'Mulish',
    'DM Serif Display', 'Comfortaa', 'Exo 2', 'Titillium Web', 'Maven Pro',
    'Asap', 'Catamaran', 'Arvo', 'Domine', 'Zilla Slab', 'Yeseva One',
    'Sacramento', 'Dancing Script', 'Great Vibes', 'Satisfy', 'Kanit',
    'Prompt', 'Chivo', 'Red Hat Display', 'Epilogue', 'Onest', 'Gabarito',
    'Schibsted Grotesk', 'Albert Sans', 'Figtree', 'Plus Jakarta Sans',
    'Hanken Grotesk', 'Geist', 'Instrument Sans', 'Familjen Grotesk',
  ]),
).sort((a, b) => a.localeCompare(b))

const loaded = new Set()

// Loads a Google Font on demand by injecting a <link>. Returns a promise that
// resolves when the font face is ready (or rejects on load failure).
export function loadGoogleFont(family, weights = [400, 700]) {
  return new Promise((resolve, reject) => {
    const key = family.toLowerCase()
    if (loaded.has(key)) {
      resolve(family)
      return
    }
    const spec = family.replace(/ /g, '+')
    const wght = weights.join(';')
    const href = `https://fonts.googleapis.com/css2?family=${spec}:wght@${wght}&display=swap`
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = href
    link.onload = async () => {
      loaded.add(key)
      try {
        if (document.fonts && document.fonts.load) {
          await document.fonts.load(`16px "${family}"`)
        }
      } catch (e) {
        /* font ready API best-effort */
      }
      resolve(family)
    }
    link.onerror = () => reject(new Error(`Failed to load font: ${family}`))
    document.head.appendChild(link)
  })
}
