
import { useState, useEffect } from 'react'
import api from './services/api'
import './App.css'

function App() {
  const [activeCategory, setActiveCategory] = useState('Tous')
  const [selectedOffer, setSelectedOffer] = useState(null)
  const [quantity, setQuantity] = useState(1)
  const [reservationSuccess, setReservationSuccess] = useState(false)
  const [reservations, setReservations] = useState([])

  // Authentification
  const [authMode, setAuthMode] = useState(null)
  const [currentUser, setCurrentUser] = useState(null)
  const [authChecking, setAuthChecking] = useState(true)
  const [authLoading, setAuthLoading] = useState(false)
  const [authError, setAuthError] = useState('')
  const [authSuccess, setAuthSuccess] = useState('')

  // Gestion des commerçants (Admin)
  const [pendingMerchants, setPendingMerchants] = useState([])
  const [merchantsLoading, setMerchantsLoading] = useState(false)
  const [merchantMessage, setMerchantMessage] = useState('')
  const [merchantActionLoading, setMerchantActionLoading] = useState(null)

  // Gestion des utilisateurs (Admin)
  const [allUsers, setAllUsers] = useState([])
  const [usersLoading, setUsersLoading] = useState(false)
  const [usersMessage, setUsersMessage] = useState('')

  // Formulaire d'authentification
  const [authForm, setAuthForm] = useState({
    fullName: '',
    email: '',
    password: '',
    role: 'student'
  })

  // Vérifier la session
  useEffect(() => {
    const verifySession = async () => {
      const token = localStorage.getItem('campussave_token')

      if (!token) {
        setCurrentUser(null)
        setAuthChecking(false)
        return
      }

      try {
        const response = await api.get('/api/auth/me')

        if (response.data.success && response.data.user) {
          const user = response.data.user

          setCurrentUser(user)
          localStorage.setItem('campussave_user', JSON.stringify(user))
        } else {
          throw new Error('Profil utilisateur introuvable.')
        }
      } catch (error) {
        console.error('Erreur de session:', error)

        localStorage.removeItem('campussave_token')
        localStorage.removeItem('campussave_user')
        setCurrentUser(null)
      } finally {
        setAuthChecking(false)
      }
    }

    verifySession()
  }, [])

  // Charger tous les utilisateurs
  const fetchAllUsers = async () => {
    setUsersLoading(true)
    setUsersMessage('')

    try {
      const response = await api.get('/api/users')

      if (response.data.success) {
        setAllUsers(response.data.users || [])
      } else {
        setUsersMessage('Impossible de récupérer les utilisateurs.')
      }
    } catch (error) {
      console.error('Erreur chargement utilisateurs:', error)
      setUsersMessage(
        error.response?.data?.message ||
        'Impossible de charger les utilisateurs.'
      )
    } finally {
      setUsersLoading(false)
    }
  }

  // Charger les commerçants en attente
  const fetchPendingMerchants = async () => {
    setMerchantsLoading(true)
    setMerchantMessage('')

    try {
      const response = await api.get('/api/users/merchants/pending')

      if (response.data.success) {
        setPendingMerchants(response.data.merchants || [])
      } else {
        setMerchantMessage('Impossible de récupérer les demandes.')
      }
    } catch (error) {
      console.error('Erreur commerçants:', error)
      setMerchantMessage(
        error.response?.data?.message ||
        'Erreur lors du chargement des demandes.'
      )
    } finally {
      setMerchantsLoading(false)
    }
  }

  // Charger les données lorsque l'admin se connecte
  useEffect(() => {
    if (currentUser?.role === 'admin') {
      fetchPendingMerchants()
      fetchAllUsers()
    }
  }, [currentUser])

  // Approuver ou refuser un commerçant
  const handleMerchantAction = async (merchantId, action) => {
    const label = action === 'approve' ? 'approuver' : 'refuser'

    if (!window.confirm(`Voulez-vous vraiment ${label} ce commerçant ?`)) {
      return
    }

    setMerchantActionLoading(merchantId)
    setMerchantMessage('')

    try {
      const response = await api.put(
        `/api/users/${merchantId}/${action}`
      )

      setMerchantMessage(
        response.data.message || 'Opération effectuée avec succès.'
      )

      await fetchPendingMerchants()
      await fetchAllUsers()
    } catch (error) {
      console.error('Erreur action commerçant:', error)
      setMerchantMessage(
        error.response?.data?.message ||
        'Une erreur est survenue.'
      )
    } finally {
      setMerchantActionLoading(null)
    }
  }

  // Offres de démonstration
  const offers = [
    {
      id: 1,
      name: 'Sandwich frais',
      category: 'Sandwichs',
      image: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=700&q=80',
      discount: '-40%',
      location: 'Cafétéria Campus',
      price: '3.000 DT',
      oldPrice: '5.000 DT',
      portions: 8,
      pickup: '12h00 - 14h00'
    },
    {
      id: 2,
      name: 'Pizza individuelle',
      category: 'Pizzas',
      image: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=700&auto=format&fit=crop',
      discount: '-50%',
      location: 'Restaurant Universitaire',
      price: '4.000 DT',
      oldPrice: '8.000 DT',
      portions: 5,
      pickup: '13h00 - 15h00'
    },
    {
      id: 3,
      name: 'Salade composée',
      category: 'Salades',
      image: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=700&auto=format&fit=crop',
      discount: '-30%',
      location: 'Fresh Food',
      price: '3.500 DT',
      oldPrice: '5.000 DT',
      portions: 10,
      pickup: '11h00 - 13h00'
    }
  ]

  const filteredOffers = offers.filter(
    offer => activeCategory === 'Tous' || offer.category === activeCategory
  )

  const totalPrice = selectedOffer
    ? (
        Number(
          selectedOffer.price
            .replace(' DT', '')
            .replace('.', '')
            .replace(',', '.')
        ) * quantity / 1000
      ).toFixed(3)
    : '0.000'

  // Changement des champs du formulaire
  const handleAuthChange = (event) => {
    const { name, value } = event.target

    setAuthForm(previous => ({
      ...previous,
      [name]: value
    }))
  }

  // Ouvrir le formulaire de connexion ou inscription
  const openAuth = (mode) => {
    setAuthMode(mode)
    setAuthError('')
    setAuthSuccess('')

    setAuthForm({
      fullName: '',
      email: '',
      password: '',
      role: 'student'
    })
  }

  // Inscription et connexion
  const handleAuthSubmit = async (event) => {
    event.preventDefault()

    setAuthError('')
    setAuthSuccess('')
    setAuthLoading(true)

    try {
      if (authMode === 'register') {
        await api.post('/api/auth/register', authForm)

        setAuthMode('login')
        setAuthForm(previous => ({
          ...previous,
          password: ''
        }))

        setAuthSuccess(
          'Inscription réussie ! Connectez-vous maintenant.'
        )
      } else {
        const response = await api.post('/api/auth/login', {
          email: authForm.email,
          password: authForm.password
        })

        const { user, tokens } = response.data

        if (!tokens?.idToken || !user) {
          throw new Error('Réponse du serveur invalide.')
        }

        localStorage.setItem('campussave_token', tokens.idToken)
        localStorage.setItem('campussave_user', JSON.stringify(user))

        setCurrentUser(user)
        setAuthMode(null)
        setAuthError('')
        setAuthSuccess('')
      }
    } catch (error) {
      setAuthError(
        error.response?.data?.message ||
        error.message ||
        'Une erreur est survenue. Réessayez.'
      )
    } finally {
      setAuthLoading(false)
    }
  }

  // Déconnexion
  const handleLogout = () => {
    localStorage.removeItem('campussave_token')
    localStorage.removeItem('campussave_user')

    setCurrentUser(null)
    setAuthMode(null)
    setReservations([])
    setPendingMerchants([])
    setAllUsers([])
    setAuthError('')
    setAuthSuccess('')
  }

  // Réservation étudiant
  const handleReservation = () => {
    if (!selectedOffer || quantity < 1 || quantity > selectedOffer.portions) {
      return
    }

    if (!currentUser) {
      setSelectedOffer(null)
      openAuth('login')
      setAuthError('Connectez-vous pour réserver un repas.')
      return
    }

    if (currentUser.role !== 'student') {
      return
    }

    const newReservation = {
      id: Date.now(),
      name: selectedOffer.name,
      location: selectedOffer.location,
      quantity,
      total: totalPrice,
      pickup: selectedOffer.pickup,
      date: new Date().toLocaleString('fr-FR'),
      status: 'Confirmée'
    }

    setReservations(previous => [newReservation, ...previous])
    setSelectedOffer(null)
    setReservationSuccess(true)
  }

  // Annuler une réservation
  const handleCancelReservation = (reservationId) => {
    const confirmCancel = window.confirm(
      'Voulez-vous vraiment annuler cette réservation ?'
    )

    if (!confirmCancel) return

    setReservations(previous =>
      previous.map(reservation =>
        reservation.id === reservationId
          ? { ...reservation, status: 'Annulée' }
          : reservation
      )
    )
  }

  // Défilement vers une section
  const scrollTo = (id) => {
    document.getElementById(id)?.scrollIntoView({
      behavior: 'smooth'
    })
  }

  // Libellés des rôles
  const getRoleLabel = (role) => {
    const roles = {
      admin: 'Administrateur',
      student: 'Étudiant',
      merchant: 'Commerçant'
    }

    return roles[role] || role || 'Non défini'
  }

  // Libellés des statuts
  const getStatusLabel = (status) => {
    const statuses = {
      active: 'Actif',
      pending: 'En attente',
      rejected: 'Refusé',
      inactive: 'Inactif'
    }

    return statuses[status] || status || 'Non défini'
  }

  // Chargement de la session
  if (authChecking) {
    return (
      <div className="app">
        <div className="role-loading">
          <h2>CampusSave</h2>
          <p>Vérification de votre session...</p>
        </div>
      </div>
    )
  }

  // Commerçant en attente de validation
  if (
    currentUser?.role === 'merchant' &&
    currentUser?.status !== 'active'
  ) {
    return (
      <div className="app">
        <header className="navbar">
          <div className="logo">Campus<span>Save</span></div>
          <div className="nav-buttons">
            <button className="login-btn" onClick={handleLogout}>
              Déconnexion
            </button>
          </div>
        </header>

        <main className="role-page">
          <div className="role-card">
            <div className="role-icon">⏳</div>
            <span className="modal-tag">CAMPUSSAVE</span>
            <h1>Compte en attente de validation</h1>
            <p>
              Bonjour {currentUser.fullName},
              votre demande d'inscription en tant que commerçant
              a bien été reçue.
            </p>
            <p>
              Notre équipe doit valider votre compte avant que
              vous puissiez accéder à votre espace commerçant.
            </p>
            <div className="role-status pending">
              En attente de validation
            </div>
            <button className="confirm-reservation" onClick={handleLogout}>
              Se déconnecter
            </button>
          </div>
        </main>
      </div>
    )
  }

  // Espace commerçant actif
  if (
    currentUser?.role === 'merchant' &&
    currentUser?.status === 'active'
  ) {
    return (
      <div className="app">
        <header className="navbar">
          <div className="logo">Campus<span>Save</span></div>
          <div className="nav-buttons">
            <span className="user-welcome">
              Bonjour, {currentUser.fullName}
            </span>
            <button className="login-btn" onClick={handleLogout}>
              Déconnexion
            </button>
          </div>
        </header>

        <main className="role-dashboard">
          <div className="dashboard-heading">
            <span>ESPACE PROFESSIONNEL</span>
            <h1>Tableau de bord commerçant</h1>
            <p>Bienvenue sur votre espace CampusSave.</p>
          </div>

          <div className="dashboard-grid">
            <div className="dashboard-card">
              <span>🍽️</span>
              <h3>Mes offres</h3>
              <p>Gérez vos offres alimentaires et vos produits.</p>
              <strong>Fonctionnalité à connecter</strong>
            </div>

            <div className="dashboard-card">
              <span>📋</span>
              <h3>Réservations reçues</h3>
              <p>Consultez les réservations effectuées par les étudiants.</p>
              <strong>Fonctionnalité à connecter</strong>
            </div>

            <div className="dashboard-card">
              <span>📊</span>
              <h3>Statistiques</h3>
              <p>Suivez vos ventes et les repas sauvés.</p>
              <strong>Fonctionnalité à connecter</strong>
            </div>
          </div>

          <div className="dashboard-notice">
            Votre compte commerçant est actif. Les outils de gestion
            seront disponibles après la connexion des API.
          </div>
        </main>
      </div>
    )
  }

  // Espace administrateur
  if (currentUser?.role === 'admin') {
    return (
      <div className="app">
        <header className="navbar">
          <div className="logo">Campus<span>Save</span></div>

          <div className="nav-buttons">
            <span className="user-welcome">
              Administrateur : {currentUser.fullName}
            </span>

            <button className="login-btn" onClick={handleLogout}>
              Déconnexion
            </button>
          </div>
        </header>

        <main className="role-dashboard">
          <div className="dashboard-heading">
            <span>ADMINISTRATION</span>
            <h1>Tableau de bord administrateur</h1>
            <p>Gérez la plateforme CampusSave.</p>
          </div>

          {/* Cartes statistiques */}
          <div className="dashboard-grid">
            <div className="dashboard-card">
              <span>👥</span>
              <h3>Utilisateurs</h3>
              <p>Consultez les comptes de la plateforme.</p>
              <strong>
                {usersLoading ? 'Chargement...' : `${allUsers.length} utilisateur(s)`}
              </strong>
            </div>

            <div className="dashboard-card">
              <span>⏳</span>
              <h3>Demandes commerçants</h3>
              <p>Validez ou refusez les demandes d'inscription.</p>
              <strong>
                {merchantsLoading
                  ? 'Chargement...'
                  : `${pendingMerchants.length} demande(s) en attente`}
              </strong>
            </div>

            <div className="dashboard-card">
              <span>🍽️</span>
              <h3>Offres alimentaires</h3>
              <p>Consultez et contrôlez les offres de la plateforme.</p>
              <strong>Fonctionnalité à connecter</strong>
            </div>

            <div className="dashboard-card">
              <span>📊</span>
              <h3>Statistiques générales</h3>
              <p>Suivez les activités de CampusSave.</p>
              <strong>Fonctionnalité à connecter</strong>
            </div>
          </div>

          {/* Gestion des commerçants */}
          <section className="admin-merchants-section">
            <div className="section-heading">
              <span>GESTION DES COMMERÇANTS</span>
              <h2>Demandes d'inscription</h2>
              <p>
                Examinez les demandes et choisissez d'approuver ou de refuser.
              </p>
            </div>

            <button
              className="confirm-reservation"
              onClick={fetchPendingMerchants}
              disabled={merchantsLoading}
            >
              {merchantsLoading
                ? 'Chargement...'
                : 'Actualiser les demandes'}
            </button>

            {merchantMessage && (
              <p className="auth-success">{merchantMessage}</p>
            )}

            {merchantsLoading ? (
              <p>Chargement des demandes...</p>
            ) : pendingMerchants.length === 0 ? (
              <p>Aucune demande commerçant en attente.</p>
            ) : (
              <div className="reservations-list">
                {pendingMerchants.map(merchant => (
                  <div className="reservation-card" key={merchant.uid}>
                    <h3>
                      {merchant.fullName || merchant.name || 'Commerçant'}
                    </h3>

                    <p>📧 {merchant.email || 'E-mail non disponible'}</p>
                    <p>📞 {merchant.phone || 'Téléphone non disponible'}</p>
                    <p>Statut : En attente</p>

                    <div className="admin-merchant-actions">
                      <button
                        className="confirm-reservation"
                        disabled={merchantActionLoading === merchant.uid}
                        onClick={() =>
                          handleMerchantAction(merchant.uid, 'approve')
                        }
                      >
                        {merchantActionLoading === merchant.uid
                          ? 'Traitement...'
                          : '✓ Approuver'}
                      </button>

                      <button
                        className="cancel-reservation-btn"
                        disabled={merchantActionLoading === merchant.uid}
                        onClick={() =>
                          handleMerchantAction(merchant.uid, 'reject')
                        }
                      >
                        {merchantActionLoading === merchant.uid
                          ? 'Traitement...'
                          : '✕ Refuser'}
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* Gestion de tous les utilisateurs */}
          <section className="admin-users-section">
            <div className="section-heading">
              <span>GESTION DE LA PLATEFORME</span>
              <h2>Tous les utilisateurs</h2>
              <p>
                Consultez les comptes étudiants, commerçants et administrateurs.
              </p>
            </div>

            <button
              className="confirm-reservation"
              onClick={fetchAllUsers}
              disabled={usersLoading}
            >
              {usersLoading ? 'Chargement...' : 'Actualiser les utilisateurs'}
            </button>

            {usersMessage && (
              <p className="auth-error">{usersMessage}</p>
            )}

            {usersLoading ? (
              <p>Chargement des utilisateurs...</p>
            ) : allUsers.length === 0 ? (
              <p>Aucun utilisateur trouvé.</p>
            ) : (
              <div className="reservations-list">
                {allUsers.map(user => (
                  <div className="reservation-card" key={user.uid}>
                    <div className="reservation-card-header">
                      <h3>
                        {user.fullName || user.name || 'Utilisateur'}
                      </h3>

                      <span className="reservation-status">
                        {getStatusLabel(user.status)}
                      </span>
                    </div>

                    <p>📧 {user.email || 'E-mail non disponible'}</p>

                    <div className="reservation-card-details">
                      <span>
                        Type de compte : <strong>{getRoleLabel(user.role)}</strong>
                      </span>
                    </div>

                    <p>
                      Statut du compte : {getStatusLabel(user.status)}
                    </p>
                  </div>
                ))}
              </div>
            )}
          </section>

          <div className="dashboard-notice">
            Vous êtes connecté en tant qu'administrateur.
            Vous pouvez consulter les utilisateurs et gérer les demandes
            d'inscription des commerçants.
          </div>
        </main>
      </div>
    )
  }

  // Accueil visiteur et étudiant
  return (
    <div className="app">

      {/* Navigation */}
      <header className="navbar">
        <div className="logo">
          Campus<span>Save</span>
        </div>

        <nav>
          <a href="#accueil">Accueil</a>
          <a href="#offres">Nos offres</a>

          {currentUser?.role === 'student' && (
            <a href="#reservations">Mes réservations</a>
          )}

          <a href="#comment">Comment ça marche</a>
        </nav>

        <div className="nav-buttons">
          {currentUser ? (
            <>
              <span className="user-welcome">
                Bonjour, {currentUser.fullName}
              </span>

              <button className="login-btn" onClick={handleLogout}>
                Déconnexion
              </button>
            </>
          ) : (
            <>
              <button
                className="login-btn"
                onClick={() => openAuth('login')}
              >
                Connexion
              </button>

              <button
                className="signup-btn"
                onClick={() => openAuth('register')}
              >
                Inscription
              </button>
            </>
          )}
        </div>
      </header>

      {/* Hero */}
      <section className="hero" id="accueil">
        <div className="hero-content">
          <span className="hero-tag">
            🌱 Ensemble contre le gaspillage alimentaire
          </span>

          <h1>
            Sauvez des repas,
            <br />
            <span>pas votre budget.</span>
          </h1>

          <p>
            Découvrez des repas délicieux à prix réduits
            près de votre campus et participez à la lutte
            contre le gaspillage alimentaire.
          </p>

          <div className="hero-buttons">
            <button
              className="primary-btn"
              onClick={() => scrollTo('offres')}
            >
              Découvrir les offres →
            </button>

            {currentUser?.role === 'student' && (
              <button
                className="secondary-btn"
                onClick={() => scrollTo('reservations')}
              >
                Mes réservations
              </button>
            )}
          </div>

          <div className="hero-stats">
            <div>
              <strong>500+</strong>
              <small>Repas sauvés</small>
            </div>

            <div>
              <strong>50+</strong>
              <small>Commerçants</small>
            </div>

            <div>
              <strong>1000+</strong>
              <small>Étudiants</small>
            </div>
          </div>
        </div>

        <div className="hero-visual">
          <div className="food-placeholder">
            <span>🥗</span>
            <h3>Bien manger, moins dépenser.</h3>
            <p>Chaque repas compte !</p>
          </div>
        </div>
      </section>

      {/* Offres */}
      <section className="offers" id="offres">
        <div className="section-heading">
          <span>LES BONNES AFFAIRES</span>
          <h2>Les offres du moment</h2>
          <p>
            Des repas de qualité à petits prix, disponibles près de vous.
          </p>
        </div>

        <div className="category-filters">
          {['Tous', 'Sandwichs', 'Pizzas', 'Salades'].map(category => (
            <button
              key={category}
              className={
                activeCategory === category
                  ? 'filter-btn active'
                  : 'filter-btn'
              }
              onClick={() => setActiveCategory(category)}
            >
              {category}
            </button>
          ))}
        </div>

        <p className="offers-count">
          <strong>{filteredOffers.length}</strong>{' '}
          {filteredOffers.length > 1
            ? 'offres disponibles'
            : 'offre disponible'}
        </p>

        <div className="offers-container">
          {filteredOffers.length > 0 ? (
            filteredOffers.map(offer => (
              <div className="offer-card" key={offer.id}>
                <div className="food-image">
                  <img src={offer.image} alt={offer.name} />
                  <span className="discount">{offer.discount}</span>
                </div>

                <div className="offer-info">
                  <h3>{offer.name}</h3>
                  <span className="offer-category">
                    {offer.category}
                  </span>

                  <p>📍 {offer.location}</p>

                  <div className="offer-details">
                    <strong>{offer.price}</strong>
                    <del>{offer.oldPrice}</del>
                  </div>

                  <div className="portions-info">
                    <div className="portions-text">
                      <span>📦 Disponibilité</span>
                      <strong>{offer.portions} portions</strong>
                    </div>

                    <div className="portions-bar">
                      <div
                        className="portions-progress"
                        style={{
                          width: `${Math.min(offer.portions / 10 * 100, 100)}%`
                        }}
                      />
                    </div>
                  </div>

                  <div className="pickup-info">
                    <span>🕒 Heure de retrait</span>
                    <strong>{offer.pickup}</strong>
                  </div>

                  <button
                    onClick={() => {
                      if (!currentUser) {
                        openAuth('login')
                        setAuthError(
                          'Connectez-vous en tant qu’étudiant pour réserver.'
                        )
                        return
                      }

                      if (currentUser.role !== 'student') return

                      setSelectedOffer(offer)
                      setQuantity(1)
                    }}
                  >
                    {currentUser?.role === 'student'
                      ? 'Réserver maintenant'
                      : currentUser
                        ? 'Réservation étudiant uniquement'
                        : 'Connectez-vous pour réserver'}
                  </button>
                </div>
              </div>
            ))
          ) : (
            <p className="no-offers">
              Aucune offre disponible dans cette catégorie.
            </p>
          )}
        </div>
      </section>

      {/* Réservations étudiant */}
      {currentUser?.role === 'student' && (
        <section className="reservations-section" id="reservations">
          <div className="section-heading">
            <span>VOTRE ESPACE</span>
            <h2>Mes réservations</h2>
            <p>
              Retrouvez vos réservations effectuées sur CampusSave.
            </p>
          </div>

          {reservations.length > 0 ? (
            <div className="reservations-list">
              {reservations.map(reservation => (
                <div
                  className={`reservation-card ${
                    reservation.status === 'Annulée'
                      ? 'reservation-cancelled'
                      : ''
                  }`}
                  key={reservation.id}
                >
                  <div className="reservation-card-header">
                    <h3>{reservation.name}</h3>

                    <span
                      className={`reservation-status ${
                        reservation.status === 'Annulée'
                          ? 'status-cancelled'
                          : ''
                      }`}
                    >
                      {reservation.status === 'Annulée' ? '✕' : '✓'}{' '}
                      {reservation.status}
                    </span>
                  </div>

                  <p>📍 {reservation.location}</p>

                  <div className="reservation-card-details">
                    <span>📦 {reservation.quantity} portion(s)</span>
                    <strong>{reservation.total} DT</strong>
                  </div>

                  <p>🕒 Retrait : {reservation.pickup}</p>
                  <small>📅 {reservation.date}</small>

                  {reservation.status === 'Confirmée' && (
                    <button
                      className="cancel-reservation-btn"
                      onClick={() =>
                        handleCancelReservation(reservation.id)
                      }
                    >
                      Annuler la réservation
                    </button>
                  )}

                  {reservation.status === 'Annulée' && (
                    <p className="cancelled-message">
                      Cette réservation a été annulée.
                    </p>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="empty-reservations">
              <span>📋</span>
              <h3>Aucune réservation pour le moment</h3>
              <p>Vos prochaines réservations apparaîtront ici.</p>

              <button onClick={() => scrollTo('offres')}>
                Découvrir les offres
              </button>
            </div>
          )}
        </section>
      )}

      {/* Modal réservation */}
      {selectedOffer && (
        <div className="modal-overlay">
          <div className="reservation-modal">
            <button
              className="modal-close"
              onClick={() => setSelectedOffer(null)}
            >
              ×
            </button>

            <span className="modal-tag">CAMPUSSAVE</span>
            <h2>Réserver votre repas</h2>
            <h3>{selectedOffer.name}</h3>
            <p>{selectedOffer.location}</p>

            <div className="modal-price">
              {selectedOffer.price}
            </div>

            <div className="quantity-selector">
              <label>Nombre de portions</label>

              <div>
                <button
                  onClick={() => setQuantity(Math.max(1, quantity - 1))}
                  disabled={quantity <= 1}
                >
                  −
                </button>

                <strong>{quantity}</strong>

                <button
                  onClick={() =>
                    setQuantity(
                      Math.min(selectedOffer.portions, quantity + 1)
                    )
                  }
                  disabled={quantity >= selectedOffer.portions}
                >
                  +
                </button>
              </div>
            </div>

            <div className="total-price">
              <span>Total</span>
              <strong>{totalPrice} DT</strong>
            </div>

            <button
              className="confirm-reservation"
              onClick={handleReservation}
            >
              Confirmer la réservation
            </button>
          </div>
        </div>
      )}

      {/* Succès réservation */}
      {reservationSuccess && (
        <div className="modal-overlay">
          <div className="reservation-modal success-modal">
            <div className="success-icon">✓</div>
            <h2>Réservation confirmée !</h2>
            <p>
              Votre réservation a été enregistrée avec succès.
            </p>

            <button
              className="confirm-reservation"
              onClick={() => {
                setReservationSuccess(false)
                scrollTo('reservations')
              }}
            >
              Voir mes réservations
            </button>
          </div>
        </div>
      )}

      {/* Modal authentification */}
      {authMode && (
        <div className="modal-overlay">
          <div className="reservation-modal auth-modal">
            <button
              className="modal-close"
              onClick={() => {
                setAuthMode(null)
                setAuthError('')
                setAuthSuccess('')
              }}
            >
              ×
            </button>

            <span className="modal-tag">CAMPUSSAVE</span>

            <h2>
              {authMode === 'login'
                ? 'Bienvenue !'
                : 'Créer un compte'}
            </h2>

            <p>
              {authMode === 'login'
                ? 'Connectez-vous à votre espace CampusSave.'
                : 'Rejoignez la communauté CampusSave.'}
            </p>

            {authError && (
              <p className="auth-error">{authError}</p>
            )}

            {authSuccess && (
              <p className="auth-success">{authSuccess}</p>
            )}

            <form onSubmit={handleAuthSubmit}>
              {authMode === 'register' && (
                <>
                  <label>Nom complet</label>

                  <input
                    type="text"
                    name="fullName"
                    value={authForm.fullName}
                    onChange={handleAuthChange}
                    placeholder="Votre nom complet"
                    required
                  />

                  <label>Type de compte</label>

                  <select
                    name="role"
                    value={authForm.role}
                    onChange={handleAuthChange}
                  >
                    <option value="student">Étudiant</option>
                    <option value="merchant">Commerçant</option>
                  </select>
                </>
              )}

              <label>Adresse e-mail</label>

              <input
                type="email"
                name="email"
                value={authForm.email}
                onChange={handleAuthChange}
                placeholder="exemple@email.com"
                required
              />

              <label>Mot de passe</label>

              <input
                type="password"
                name="password"
                value={authForm.password}
                onChange={handleAuthChange}
                placeholder="8 caractères minimum"
                minLength={8}
                required
              />

              <button
                className="confirm-reservation"
                type="submit"
                disabled={authLoading}
              >
                {authLoading
                  ? 'Veuillez patienter...'
                  : authMode === 'login'
                    ? 'Se connecter'
                    : "S'inscrire"}
              </button>
            </form>

            <p className="auth-switch">
              {authMode === 'login'
                ? 'Vous n’avez pas de compte ?'
                : 'Vous avez déjà un compte ?'}
              {' '}

              <button
                type="button"
                onClick={() =>
                  openAuth(
                    authMode === 'login' ? 'register' : 'login'
                  )
                }
              >
                {authMode === 'login'
                  ? "S'inscrire"
                  : 'Se connecter'}
              </button>
            </p>
          </div>
        </div>
      )}

      {/* Footer */}
      <footer className="footer" id="comment">
        <h2>CampusSave</h2>
        <p>
          Ensemble, réduisons le gaspillage alimentaire.
        </p>
        <small>© 2026 CampusSave. Tous droits réservés.</small>
      </footer>
    </div>
  )
}

export default App
