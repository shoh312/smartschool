import { useState } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import { saveSession } from '../api/client'
import { isDemo } from '../api/demo'
import type { Session } from '../api/types'
import { useT } from '../i18n'
import { IcBell, IcBook, IcCalendar, IcCamera, IcChart, IcGrid, IcHome, IcLayers, IcLogout, IcSettings, IcUser, IcUsers } from './icons'
import { Confirm } from './kit'

export function Shell({ session }: { session: Session }) {
  const { t } = useT()
  const [out, setOut] = useState(false)
  const director = session.role === 'director'
  const items = director
    ? [
        { to: '/', icon: IcHome, label: t('nav_home'), end: true },
        { to: '/classes', icon: IcGrid, label: t('nav_classes') },
        { to: '/students', icon: IcUsers, label: t('nav_students') },
        { to: '/teachers', icon: IcUser, label: t('nav_teachers') },
        { to: '/cameras', icon: IcCamera, label: t('nav_cameras') },
        { to: '/analytics', icon: IcChart, label: t('nav_analytics') },
        { to: '/announcements', icon: IcBell, label: t('nav_announcements') },
        { to: '/calendar', icon: IcCalendar, label: t('nav_calendar') },
        { to: '/settings', icon: IcSettings, label: t('nav_settings') },
      ]
    : [
        { to: '/', icon: IcHome, label: t('nav_home'), end: true },
        { to: '/materials', icon: IcLayers, label: t('nav_materials') },
        { to: '/diary', icon: IcBook, label: t('nav_diary') },
        { to: '/calendar', icon: IcCalendar, label: t('nav_calendar') },
        { to: '/announcements', icon: IcBell, label: t('nav_announcements') },
        { to: '/settings', icon: IcSettings, label: t('nav_settings') },
      ]
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark">S</div>
          <div>
            <div className="brand-name">SmartFlow</div>
            <div className="brand-sub">{director ? t('role_director') : t('role_teacher')}{isDemo() && <span className="chip amber" style={{ height: 20, marginLeft: 6, padding: '0 7px', fontSize: 10.5 }}>DEMO</span>}</div>
          </div>
        </div>
        <nav className="nav">
          {items.map((it) => (
            <NavLink key={it.to} to={it.to} end={it.end} className={({ isActive }) => 'nav-item' + (isActive ? ' active' : '')}>
              <it.icon /> <span>{it.label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-foot">
          <div className="me">
            <div className="avatar sm">{session.fullName.split(' ').map((w) => w[0]).slice(0, 2).join('')}</div>
            <div className="grow">
              <div className="me-name">{session.fullName}</div>
              <div className="me-role">{session.subject || session.email}</div>
            </div>
            <button className="btn ghost icon sm" title={t('sign_out')} onClick={() => setOut(true)}><IcLogout /></button>
          </div>
        </div>
      </aside>
      <main className="main">
        <Outlet />
      </main>
      {out && <Confirm title={t('sign_out')} body={t('sign_out_q')} onNo={() => setOut(false)} onYes={() => saveSession(null)} />}
    </div>
  )
}

export function TopBar({ title, sub, children, back }: { title: string; sub?: string; children?: React.ReactNode; back?: () => void }) {
  return (
    <div className="topbar">
      {back && <button className="btn ghost icon" onClick={back}><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round"><path d="M19 12H5" /><path d="M12 19l-7-7 7-7" /></svg></button>}
      <div>
        <h1>{title}</h1>
        {sub && <div className="sub">{sub}</div>}
      </div>
      <div className="grow" />
      {children}
    </div>
  )
}
