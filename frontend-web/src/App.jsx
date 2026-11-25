import { lazy, Suspense, useCallback, useEffect, useRef, useState } from 'react'
import { api, errorMessage, tokenKey } from './services/api'
import { useAction } from './hooks/useResource'
import { Dialog, Failure } from './components/shared'
import { label } from './components/format'
import { Catalog, Profile, StudentReservations } from './features/Student'
import Merchant from './features/Merchant'
import Admin from './features/Admin'
import Dashboard from './features/Dashboard'
import './App.css'
import './CampusSave.css'

const Radar = lazy(() => import('./features/Radar'))
const menus = {
  public: [['home', 'Accueil'], ['catalog', 'Nos offres'], ['radar', 'Campus Radar']],
  student: [['home', 'Accueil'], ['catalog', 'Nos offres'], ['radar', 'Campus Radar'], ['bookings', 'Mes réservations'],
    ['dashboard', 'Impact'], ['points', 'EcoPoints'], ['profile', 'Mon profil']],
  merchant: [['dashboard', 'Tableau de bord'], ['shop', 'Mon commerce'], ['offers', 'Mes offres'],
    ['bookings', 'Réservations'], ['pickup', 'Vérifier un retrait']],
  admin: [['dashboard', 'Tableau de bord'], ['users', 'Utilisateurs'], ['shops', 'Commerces'], ['offers', 'Modération des offres']],
}
const defaultPage = role => ['merchant', 'admin'].includes(role) ? 'dashboard' : 'home'
const validUser = user => user && (user.role === 'merchant' && ['pending', 'rejected'].includes(user.status) ||
  ['student', 'merchant', 'admin'].includes(user.role) && user.status === 'active')

export default function App() {
  const [theme, setTheme] = useState(() => localStorage.getItem('campussave_theme') === 'dark' ? 'dark' : 'light')
  const [user, setUser] = useState(null)
  const [checking, setChecking] = useState(() => Boolean(localStorage.getItem(tokenKey)))
  const [checkError, setCheckError] = useState(null)
  const [notice, setNotice] = useState('')
  const [auth, setAuth] = useState(null)
  const [page, setPage] = useState(() => location.hash.slice(1))
  const [shopId, setShopId] = useState(null)
  const generation = useRef(0)
  const logoutAction = useAction()
  const focus = useRef(null)
  const role = user?.role ?? 'public'
  const menu = menus[role]
  const active = menu.some(([value]) => value === page) ? page : defaultPage(role)
  const pendingMerchant = role === 'merchant' && user.status !== 'active'

  function navigate(next, shop = null) {
    setShopId(shop)
    setPage(next)
    if (location.hash !== '#' + next) history.pushState(null, '', '#' + next)
    window.scrollTo({ top: 0 })
    focus.current?.focus({ preventScroll: true })
  }
  const restore = useCallback(async () => {
    const current = ++generation.current
    const token = localStorage.getItem(tokenKey)
    if (!token) return
    try {
      const { user } = await api.me()
      if (generation.current !== current || localStorage.getItem(tokenKey) !== token) return
      if (!validUser(user)) {
        localStorage.removeItem(tokenKey)
        setUser(null)
        setNotice('Ce compte ne peut pas accéder à CampusSave.')
      } else setUser(user)
    } catch (error) {
      if (generation.current !== current) return
      if ([401, 403, 404].includes(error.response?.status)) {
        localStorage.removeItem(tokenKey)
        setUser(null)
        setNotice(errorMessage(error))
      } else setCheckError(errorMessage(error))
    } finally {
      if (generation.current === current) setChecking(false)
    }
  }, [])
  useEffect(() => {
    let active = true
    function expired() {
      generation.current++
      setChecking(false)
      setCheckError(null)
      setUser(null)
      setNotice('Votre session a expiré. Connectez-vous à nouveau.')
    }
    const invalidate = () => { generation.current++ }
    const updatePage = () => { setPage(location.hash.slice(1)); setShopId(null) }
    window.addEventListener('campussave:expired', expired)
    window.addEventListener('hashchange', updatePage)
    queueMicrotask(() => { if (active) void restore() })
    return () => {
      active = false
      invalidate()
      window.removeEventListener('campussave:expired', expired)
      window.removeEventListener('hashchange', updatePage)
    }
  }, [restore])
  useEffect(() => {
    document.documentElement.dataset.theme = theme
    localStorage.setItem('campussave_theme', theme)
  }, [theme])
  function refreshSession() {
    setChecking(true)
    setCheckError(null)
    void restore()
  }
  function signedIn(user) {
    setNotice('')
    setCheckError(null)
    setUser(user)
    setAuth(null)
    navigate(defaultPage(user.role))
  }
  function logout() {
    void logoutAction.run(async () => {
      try { await api.logout() } catch {
        setNotice('Session fermée sur ce navigateur. La révocation des autres sessions reste à vérifier.')
      } finally {
        generation.current++
        localStorage.removeItem(tokenKey)
        localStorage.removeItem('campussave_user')
        setUser(null)
        navigate('home')
      }
    })
  }
  const themeLabel = theme === 'dark' ? 'Activer le mode jour' : 'Activer le mode nuit'
  const openLogin = () => setAuth('login')
  return <div className="app">
    <a className="cs-skip" href="#contenu" onClick={event => { event.preventDefault(); focus.current?.focus() }}>Aller au contenu</a>
    <header className="navbar cs-navbar">
      <a href={'#' + defaultPage(role)} className="logo" onClick={event => { event.preventDefault(); navigate(defaultPage(role)) }}>
        Campus<span>Save</span></a>
      <nav aria-label="Navigation principale">{menu.filter(([key]) => !pendingMerchant || key === 'shop').map(([key, title]) =>
        <a key={key} href={'#' + key} aria-current={active === key ? 'page' : undefined}
          onClick={event => { event.preventDefault(); navigate(key) }}>{title}</a>)}</nav>
      <div className="nav-buttons">
        <button className="cs-theme" onClick={() => setTheme(value => value === 'light' ? 'dark' : 'light')}
          title={themeLabel} aria-label={themeLabel}><span key={theme} aria-hidden="true">{theme === 'dark' ? '☾' : '☀'}</span></button>
        {user ? <>
          <span className="user-welcome">{user.fullName} · {label(role)}</span>
          <button className="login-btn" disabled={logoutAction.pending} onClick={logout}>Déconnexion</button>
        </> : <>
          <button className="login-btn" onClick={openLogin} disabled={checking}>Connexion</button>
          <button className="signup-btn" onClick={() => setAuth('register')} disabled={checking}>Inscription</button>
        </>}
      </div>
    </header>
    <main id="contenu" ref={focus} tabIndex="-1">
      {notice && <p className="cs-notice" role="status">{notice}</p>}
      {checking ? <div className="cs-shell cs-loading" role="status">Vérification de la session…</div> :
        checkError ? <div className="cs-shell"><Failure message={checkError} /><button onClick={refreshSession}>Réessayer</button>
          <button onClick={openLogin}>Se reconnecter</button></div> :
        <>
          {active === 'home' && <Landing navigate={navigate} student={role === 'student'} />}
          {['home', 'catalog'].includes(active) && <Catalog key={shopId ?? 'catalog'} user={user} login={openLogin}
            shopId={shopId} onReserved={() => setNotice('Réservation enregistrée. Retrouvez-la dans Mes réservations.')} />}
          {active === 'radar' && <div className="cs-shell"><Suspense fallback={<p role="status">Chargement de la carte…</p>}>
            <Radar onShop={key => navigate('catalog', key)} />
          </Suspense></div>}
          {!['home', 'catalog', 'radar'].includes(active) && <div className="cs-shell role-dashboard">
            {active === 'dashboard' && !pendingMerchant && <Dashboard key={role} role={role} />}
            {role === 'student' && active === 'points' && <Dashboard role={role} pointsOnly />}
            {role === 'student' && active === 'bookings' && <StudentReservations />}
            {role === 'student' && active === 'profile' && <Profile onSaved={setUser} />}
            {role === 'merchant' && (active !== 'dashboard' || pendingMerchant) && <Merchant page={pendingMerchant ? 'shop' : active} onRefreshSession={refreshSession} awaitingApproval={pendingMerchant} />}
            {role === 'admin' && active !== 'dashboard' && <Admin page={active} user={user} />}
          </div>}
        </>}
    </main>
    {auth && <Auth mode={auth} setMode={setAuth} onSignedIn={signedIn} />}
    <footer className="footer"><p>© {new Date().getFullYear()} CampusSave · Chaque repas compte.</p></footer>
  </div>
}

function Landing({ navigate, student }) {
  return <section className="hero" id="accueil">
    <div className="hero-content">
      <span className="hero-tag">🌱 Ensemble contre le gaspillage alimentaire</span>
      <h1>Sauvez des repas,<br /><span>pas votre budget.</span></h1>
      <p>Découvrez des repas délicieux à prix réduits près de votre campus et participez à la lutte contre le gaspillage alimentaire.</p>
      <div className="hero-buttons">
        <button className="primary-btn" onClick={() => navigate('catalog')}>Découvrir les offres →</button>
        {student && <button className="secondary-btn" onClick={() => navigate('bookings')}>Mes réservations</button>}
      </div>
    </div>
    <div className="hero-visual"><div className="food-placeholder">
      <span aria-hidden="true">🥗</span><h3>Bien manger, moins dépenser.</h3><p>Chaque repas compte !</p>
    </div></div>
  </section>
}

function Auth({ mode, setMode, onSignedIn }) {
  const action = useAction()
  const [message, setMessage] = useState('')
  const register = mode === 'register'
  const switchMode = next => { setMessage(''); setMode(next) }
  return <Dialog title={register ? 'Créer un compte' : 'Connexion'} onClose={() => { if (!action.pending) setMode(null) }}>
    <form key={mode} onSubmit={event => {
      event.preventDefault()
      const fields = Object.fromEntries(new FormData(event.currentTarget))
      void action.run(async () => {
        if (register) {
          await api.register(fields)
          setMode('login')
          setMessage(fields.role === 'merchant'
            ? 'Compte créé. Connectez-vous pour enregistrer votre commerce.'
            : 'Compte créé. Vous pouvez maintenant vous connecter.')
          return
        }
        const { tokens } = await api.login(fields)
        if (!tokens?.idToken) throw new Error()
        localStorage.setItem(tokenKey, tokens.idToken)
        localStorage.removeItem('campussave_user')
        try {
          const { user } = await api.me()
          if (!validUser(user)) {
            setMessage('Ce compte ne peut pas accéder à CampusSave.')
            localStorage.removeItem(tokenKey)
            return
          }
          onSignedIn(user)
        } catch (error) {
          localStorage.removeItem(tokenKey)
          throw error
        }
      })
    }}>
      {register && <>
        <label>Nom complet<input name="fullName" autoComplete="name" required /></label>
        <label>Type de compte<select name="role"><option value="student">Étudiant</option><option value="merchant">Commerçant</option></select></label>
      </>}
      <label>E-mail<input name="email" type="email" autoComplete="email" required /></label>
      <label>Mot de passe<input name="password" type="password" autoComplete={register ? 'new-password' : 'current-password'}
        minLength={register ? 8 : undefined} required /></label>
      {message && <p role="status">{message}</p>}
      <Failure message={action.error} />
      <div className="cs-actions">
        <button className="cs-primary" disabled={action.pending}>{register ? 'S’inscrire' : 'Se connecter'}</button>
        <button type="button" disabled={action.pending} onClick={() => switchMode(register ? 'login' : 'register')}>
          {register ? 'J’ai déjà un compte' : 'Créer un compte'}
        </button>
      </div>
    </form>
  </Dialog>
}
