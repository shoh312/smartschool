import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react'
import { STRINGS } from './strings'

export type Lang = 'tg' | 'ru' | 'en'
const LANGS: Lang[] = ['tg', 'ru', 'en']
const KEY = 'sf.lang'

function initial(): Lang {
  try {
    const s = localStorage.getItem(KEY) as Lang | null
    if (s && LANGS.includes(s)) return s
  } catch {}
  const nav = (navigator.language || 'ru').slice(0, 2)
  if (nav === 'tg' || nav === 'tj') return 'tg'
  if (nav === 'en') return 'en'
  return 'ru'
}

interface Ctx {
  lang: Lang
  setLang: (l: Lang) => void
  t: (key: string, ...args: (string | number)[]) => string
}
const LangCtx = createContext<Ctx>({ lang: 'ru', setLang: () => {}, t: (k) => k })

export function LangProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(initial)
  const setLang = useCallback((l: Lang) => {
    setLangState(l)
    try { localStorage.setItem(KEY, l) } catch {}
  }, [])
  const t = useCallback(
    (key: string, ...args: (string | number)[]) => {
      const row = STRINGS[key]
      let s = row ? row[LANGS.indexOf(lang)] || row[1] || row[0] : key
      args.forEach((a, i) => { s = s.replace(`{${i}}`, String(a)) })
      return s
    },
    [lang],
  )
  const value = useMemo(() => ({ lang, setLang, t }), [lang, setLang, t])
  return <LangCtx.Provider value={value}>{children}</LangCtx.Provider>
}

export function useT() {
  return useContext(LangCtx)
}

export const LOCALE: Record<Lang, string> = { tg: 'tg-TJ', ru: 'ru-RU', en: 'en-GB' }
export const LANG_LABEL: Record<Lang, string> = { tg: 'TJ', ru: 'RU', en: 'EN' }

export function LangSwitch({ light }: { light?: boolean }) {
  const { lang, setLang } = useT()
  return (
    <div className={'lang' + (light ? ' light' : '')}>
      {LANGS.map((l) => (
        <button key={l} className={l === lang ? 'active' : ''} onClick={() => setLang(l)}>
          {LANG_LABEL[l]}
        </button>
      ))}
    </div>
  )
}
