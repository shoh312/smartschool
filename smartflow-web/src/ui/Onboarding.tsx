import { useState } from 'react'
import type { Role } from '../api/types'
import { useT } from '../i18n'
import { Ill, type IllName } from './illustrations'

/**
 * A short, one-time welcome shown the first time each role signs in. The slides
 * differ per role; "seen" is remembered per role in localStorage so it never
 * nags. Falls back to nothing if storage is unavailable.
 */
const KEY = 'sf.onboarded.'

const SLIDES: Record<Role, { ill: IllName; title: string; body: string }[]> = {
  director: [
    { ill: 'school', title: 'ob_dir_1_t', body: 'ob_dir_1_b' },
    { ill: 'door_check', title: 'ob_dir_2_t', body: 'ob_dir_2_b' },
    { ill: 'trophy', title: 'ob_dir_3_t', body: 'ob_dir_3_b' },
  ],
  teacher: [
    { ill: 'book', title: 'ob_tea_1_t', body: 'ob_tea_1_b' },
    { ill: 'homework', title: 'ob_tea_2_t', body: 'ob_tea_2_b' },
    { ill: 'clipboard', title: 'ob_tea_3_t', body: 'ob_tea_3_b' },
  ],
  parent: [
    { ill: 'family', title: 'ob_par_1_t', body: 'ob_par_1_b' },
    { ill: 'bell', title: 'ob_par_2_t', body: 'ob_par_2_b' },
    { ill: 'school', title: 'ob_par_3_t', body: 'ob_par_3_b' },
  ],
  student: [
    { ill: 'backpack', title: 'ob_stu_1_t', body: 'ob_stu_1_b' },
    { ill: 'clipboard', title: 'ob_stu_2_t', body: 'ob_stu_2_b' },
    { ill: 'trophy', title: 'ob_stu_3_t', body: 'ob_stu_3_b' },
  ],
}

export function shouldOnboard(role: Role): boolean {
  try { return localStorage.getItem(KEY + role) !== '1' } catch { return false }
}

export function Onboarding({ role, onClose }: { role: Role; onClose: () => void }) {
  const { t } = useT()
  const slides = SLIDES[role]
  const [i, setI] = useState(0)
  const last = i === slides.length - 1
  const s = slides[i]

  function done() { try { localStorage.setItem(KEY + role, '1') } catch {} onClose() }

  return (
    <div className="overlay ob-overlay">
      <div className="ob-card">
        <div className="ob-art"><Ill name={s.ill} size={200} /></div>
        <h2>{t(s.title)}</h2>
        <p>{t(s.body)}</p>
        <div className="ob-dots">
          {slides.map((_, k) => <span key={k} className={'ob-dot' + (k === i ? ' on' : '')} onClick={() => setI(k)} />)}
        </div>
        <div className="ob-actions">
          {!last && <button className="btn ghost" onClick={done}>{t('ob_skip')}</button>}
          <button className="btn primary grow" onClick={() => (last ? done() : setI(i + 1))}>{last ? t('ob_start') : t('ob_next')}</button>
        </div>
      </div>
    </div>
  )
}
