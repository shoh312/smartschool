import { useEffect, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { LangSwitch, useT } from '../i18n'
import { Ill, type IllName } from '../ui/illustrations'
import { IcBell, IcBook, IcCamera, IcChart, IcCheck, IcNext, IcShield, IcSparkles, IcUsers } from '../ui/icons'
import { startDemo } from './auth/Login'

/**
 * The public front page at /web/: what SmartFlow is, for whom, and two ways
 * in (sign in, or the demo that needs no server). Everything below the fold
 * fades up as it scrolls into view; nothing here talks to the API.
 */
export function Landing() {
  const { t } = useT()
  useReveal()

  return (
    <div className="ld">
      <header className="ld-nav">
        <div className="ld-wrap row" style={{ justifyContent: 'space-between' }}>
          <a href="#top" className="row">
            <div className="brand-mark">S</div>
            <div><div className="brand-name">SmartFlow</div><div className="brand-sub">CICT Academy</div></div>
          </a>
          <nav className="ld-links">
            <a href="#features">{t('ld_nav_features')}</a>
            <a href="#how">{t('ld_nav_how')}</a>
            <a href="#roles">{t('ld_nav_roles')}</a>
            <a href="#security">{t('ld_nav_security')}</a>
          </nav>
          <div className="row">
            <LangSwitch />
            <Link to="/login" className="btn soft ld-hide-sm">{t('sign_in')}</Link>
            <button className="btn primary" onClick={() => startDemo('director')}>{t('ld_try_demo')}</button>
          </div>
        </div>
      </header>

      <section className="ld-hero" id="top">
        <div className="ld-glow a" /><div className="ld-glow b" />
        <div className="ld-wrap ld-hero-grid">
          <div className="ld-hero-copy">
            <span className="ld-eyebrow"><IcSparkles /> {t('ld_eyebrow')}</span>
            <h1>{t('ld_hero_title')}</h1>
            <p>{t('ld_hero_body')}</p>
            <div className="row wrap" style={{ gap: 12, marginTop: 30 }}>
              <Link to="/login" className="btn primary lg">{t('ld_hero_cta')} <IcNext /></Link>
              <button className="btn soft lg" onClick={() => startDemo('director')}>{t('ld_try_demo')}</button>
            </div>
            <div className="ld-note"><Ill name="phone_sms" size={46} /> {t('ld_hero_note')}</div>
          </div>
          <Mock />
        </div>
        <div className="ld-wrap ld-stats reveal">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="ld-stat"><b>{t(`ld_stat${i}_v`)}</b><span>{t(`ld_stat${i}_l`)}</span></div>
          ))}
        </div>
      </section>

      <Section id="features" title={t('ld_features_t')} sub={t('ld_features_sub')}>
        <div className="ld-features">
          {([['door_check', 'f1'], ['notebook', 'f2'], ['homework', 'f3'], ['family', 'f4'], ['trophy', 'f5'], ['shield', 'f6']] as [IllName, string][]).map(([ill, k], i) => (
            <div key={k} className="ld-feature reveal" style={{ transitionDelay: `${i * 60}ms` }}>
              <Ill name={ill} size={96} />
              <h3>{t(`ld_${k}_t`)}</h3>
              <p>{t(`ld_${k}_b`)}</p>
            </div>
          ))}
        </div>
      </Section>

      <Section id="how" title={t('ld_how_t')} sub={t('ld_how_sub')} dark>
        <div className="ld-steps">
          {[IcCamera, IcSparkles, IcBook, IcBell].map((Ic, i) => (
            <div key={i} className="ld-step reveal" style={{ transitionDelay: `${i * 90}ms` }}>
              <div className="ld-step-n"><Ic /><span>{i + 1}</span></div>
              <h3>{t(`ld_s${i + 1}_t`)}</h3>
              <p>{t(`ld_s${i + 1}_b`)}</p>
            </div>
          ))}
        </div>
      </Section>

      <Section id="roles" title={t('ld_roles_t')} sub={t('ld_roles_sub')}>
        <div className="grid c3 ld-roles">
          <Role title={t('role_director')} ill="school" items={['d1', 'd2', 'd3', 'd4'].map((k) => t(`ld_${k}`))} web app t={t} />
          <Role title={t('role_teacher')} ill="book" items={['t1', 't2', 't3', 't4'].map((k) => t(`ld_${k}`))} web app t={t} delay={80} />
          <Role title={t('ld_role_parent')} ill="family" items={['p1', 'p2', 'p3', 'p4'].map((k) => t(`ld_${k}`))} app t={t} delay={160} />
        </div>
      </Section>

      <Section id="security" title={t('ld_sec_t')} sub={t('ld_sec_sub')}>
        <div className="ld-sec">
          <div className="ld-sec-art reveal"><Ill name="shield" size={300} /></div>
          <div className="col" style={{ gap: 14 }}>
            {[IcShield, IcUsers, IcChart].map((Ic, i) => (
              <div key={i} className="ld-sec-row reveal" style={{ transitionDelay: `${i * 80}ms` }}>
                <span className="ld-sec-ic"><Ic /></span>
                <div><h3>{t(`ld_sec${i + 1}_t`)}</h3><p>{t(`ld_sec${i + 1}_b`)}</p></div>
              </div>
            ))}
          </div>
        </div>
      </Section>

      <section className="ld-section">
        <div className="ld-wrap">
          <div className="ld-cta reveal">
            <div className="ld-glow c" />
            <div className="grow">
              <h2>{t('ld_cta_t')}</h2>
              <p>{t('ld_cta_b')}</p>
              <div className="row wrap" style={{ gap: 10, marginTop: 22 }}>
                <button className="btn lg ld-btn-white" onClick={() => startDemo('director')}>{t('ld_try_demo')}</button>
                <Link to="/login" className="btn lg ld-btn-ghost">{t('sign_in')}</Link>
              </div>
            </div>
            <Ill name="school" size={260} className="ld-cta-art" />
          </div>
        </div>
      </section>

      <footer className="ld-foot">
        <div className="ld-wrap row" style={{ justifyContent: 'space-between' }}>
          <span className="small muted">{t('ld_footer')}</span>
          <span className="small faint">© {new Date().getFullYear()} SmartFlow</span>
        </div>
      </footer>
    </div>
  )
}

function Section({ id, title, sub, dark, children }: { id: string; title: string; sub: string; dark?: boolean; children: ReactNode }) {
  return (
    <section id={id} className={'ld-section' + (dark ? ' dark' : '')}>
      <div className="ld-wrap">
        <div className="ld-head reveal"><h2>{title}</h2><p>{sub}</p></div>
        {children}
      </div>
    </section>
  )
}

function Role({ title, ill, items, web, app, t, delay = 0 }: { title: string; ill: IllName; items: string[]; web?: boolean; app?: boolean; t: (k: string) => string; delay?: number }) {
  return (
    <div className="ld-role reveal" style={{ transitionDelay: `${delay}ms` }}>
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <Ill name={ill} size={84} />
        <div className="row" style={{ gap: 6 }}>
          {web && <span className="chip brand">{t('ld_platform_web')}</span>}
          {app && <span className="chip">{t('ld_platform_app')}</span>}
        </div>
      </div>
      <h3>{title}</h3>
      <ul>{items.map((x) => <li key={x}><IcCheck />{x}</li>)}</ul>
    </div>
  )
}

/** A still life of the director's screen, drawn in DOM so it stays crisp and translates with the page. */
function Mock() {
  const { t } = useT()
  const pupils: [string, 'mint' | 'amber' | 'rose', string][] = [
    ['Исмоилов И.', 'mint', t('ld_mock_came')], ['Раҳимова Н.', 'mint', t('ld_mock_came')],
    ['Каримов С.', 'amber', t('ld_mock_late')], ['Назарова М.', 'rose', t('ld_mock_absent')],
  ]
  const grid = [[9, 8, 0, 10, 9], [7, 8, 9, 0, 8], [10, 9, 9, 8, 10], [6, 0, 7, 8, 7]]
  const bars = [62, 74, 58, 81, 88, 79, 92]
  return (
    <div className="ld-mock">
      <div className="ld-mock-bar"><i /><i /><i /><span>smartflow · /web</span></div>
      <div className="ld-mock-body">
        <aside>
          <div className="row" style={{ gap: 8, marginBottom: 14 }}><div className="brand-mark" style={{ width: 26, height: 26, borderRadius: 8, fontSize: 12 }}>S</div><b style={{ fontSize: 11 }}>SmartFlow</b></div>
          {[1, 2, 3, 4, 5].map((i) => <div key={i} className={'ld-mock-nav' + (i === 1 ? ' on' : '')} />)}
        </aside>
        <main>
          <div className="ld-mock-hero">
            <div><b>BackEnd #1 · Room 3</b><span>{t('ld_mock_live')}</span></div>
            <span className="chip" style={{ background: 'rgba(255,255,255,.18)', color: '#fff' }}><i className="live-dot" style={{ background: '#fff' }} /> LIVE</span>
          </div>
          <div className="ld-mock-grid">
            <div className="ld-mock-card">
              {pupils.map(([n, c, s]) => (
                <div key={n} className="ld-mock-row"><span className="ld-mock-av">{n[0]}</span><span className="grow ellipsis">{n}</span><span className={'chip ' + c}>{s}</span></div>
              ))}
            </div>
            <div className="ld-mock-card">
              <div className="tiny bold muted" style={{ marginBottom: 6 }}>{t('ld_mock_journal')}</div>
              <div className="ld-mock-j">
                {grid.flat().map((v, i) => <span key={i} className={v === 0 ? 'ab' : v >= 9 ? 'g9' : v >= 7 ? 'g7' : 'g5'}>{v === 0 ? 'ғ' : v}</span>)}
              </div>
            </div>
          </div>
          <div className="ld-mock-card">
            <div className="row" style={{ justifyContent: 'space-between', marginBottom: 8 }}><span className="tiny bold muted">{t('ld_mock_avg')}</span><b style={{ fontSize: 13, color: 'var(--brand)' }}>8.4</b></div>
            <div className="ld-mock-bars">{bars.map((h, i) => <i key={i} style={{ height: `${h}%`, animationDelay: `${i * 80}ms` }} />)}</div>
          </div>
        </main>
      </div>
      <div className="ld-mock-toast">
        <Ill name="bell" size={44} />
        <div><b>{t('ld_mock_notify')}</b><span>{t('ld_mock_notify_body')}</span></div>
      </div>
    </div>
  )
}

/** Adds .in to every .reveal element the first time it scrolls into view. */
function useReveal() {
  useEffect(() => {
    const els = Array.from(document.querySelectorAll<HTMLElement>('.ld .reveal'))
    if (!('IntersectionObserver' in window)) { els.forEach((e) => e.classList.add('in')); return }
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => { if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target) } })
    }, { threshold: 0.15 })
    els.forEach((e) => io.observe(e))
    return () => io.disconnect()
  }, [])
}
