
import { useState, useEffect } from 'react'
import api from './services/api'
import './App.css'

function App() {
  const [activeCategory, setActiveCategory] = useState('Tous')
  const [selectedOffer, setSelectedOffer] = useState(null)
  const [quantity, setQuantity] = useState(1)
  const [reservationSuccess, setReservationSuccess] = useState(false)
  const [reservations, setReservations] = useState([])

  // Gestion des offres commerçant
  const [merchantOffers, setMerchantOffers] = useState([])
  const [platformOffers, setPlatformOffers] = useState([])
const [platformOffersLoading, setPlatformOffersLoading] = useState(false)
  const [offersLoading, setOffersLoading] = useState(false)
  const [offerMessage, setOfferMessage] = useState('')
  const [offerError, setOfferError] = useState('')
  const [offerSubmitting, setOfferSubmitting] = useState(false)
  const [showOfferForm, setShowOfferForm] = useState(false)
  const [editingOfferId, setEditingOfferId] = useState(null)

  const [offerForm, setOfferForm] = useState({
    title: '',
    description: '',
    category: 'Paniers',
    originalPrice: '',
    discountedPrice: '',
    quantity: '',
    imageUrl: '',
    pickupStart: '',
    pickupEnd: '',
    address: ''
  })

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

// Adapter les offres du backend au format utilisé par les cartes

const realOffers = platformOffers.map(offer => {
  const originalPrice = Number(offer.originalPrice ?? 0)
  const discountedPrice = Number(
    offer.discountedPrice ?? offer.discountPrice ?? 0
  )

  const pickupStart = offer.pickupStart || ''
  const pickupEnd = offer.pickupEnd || ''

  const formatPickupTime = (value) => {
    if (!value) return ''

    if (value.includes('T')) {
      return new Date(value).toLocaleTimeString('fr-FR', {
        hour: '2-digit',
        minute: '2-digit'
      })
    }

    return value
  }

  return {
    ...offer,
    id: offer.id,
    name: offer.title || offer.name || 'Offre alimentaire',
    image: offer.imageUrl || offer.imageURL ||
      'https://placehold.co/600x400?text=CampusSave',
    category: offer.category || 'Autres',
    discount: originalPrice > 0
      ? `-${Math.round((1 - discountedPrice / originalPrice) * 100)}%`
      : '',
    location: offer.address || 'Adresse non renseignée',
    price: `${discountedPrice.toFixed(3)} DT`,
    oldPrice: `${originalPrice.toFixed(3)} DT`,
    portions: Number(
      offer.quantity ?? offer.availableQuantity ?? 0
    ),
    pickup: pickupStart && pickupEnd
      ? `${formatPickupTime(pickupStart)} - ${formatPickupTime(pickupEnd)}`
      : 'À confirmer'
  }
})


// Les étudiants connectés voient les offres réelles
const displayedOffers = currentUser?.role === 'student'
  ? realOffers
  : offers

const filteredOffers = displayedOffers.filter(
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

  // Charger les offres du commerçant connecté
  const fetchMerchantOffers = async () => {
    try {
      setOffersLoading(true)
      setOfferError('')

      const response = await api.get('/api/offers/my')

      setMerchantOffers(response.data.offers || [])
    } catch (error) {
      setOfferError(
        error.response?.data?.message ||
        'Impossible de charger vos offres.'
      )
    } finally {
      setOffersLoading(false)
    }
  }
// Charger les offres de la plateforme
const fetchPlatformOffers = async () => {
  try {
    setPlatformOffersLoading(true)

    const response = await api.get('/api/offers')
    setPlatformOffers(response.data.offers || [])
  } catch (error) {
    console.error('Erreur chargement offres:', error)
    setPlatformOffers([])
  } finally {
    setPlatformOffersLoading(false)
  }
}
  // Réinitialiser le formulaire
  const resetOfferForm = () => {
    setOfferForm({
      title: '',
      description: '',
      category: 'Paniers',
      originalPrice: '',
      discountedPrice: '',
      quantity: '',
      imageUrl: '',
      pickupStart: '',
      pickupEnd: '',
      address: ''
    })

    setEditingOfferId(null)
    setShowOfferForm(false)
  }

  // Créer ou modifier une offre
  const handleOfferSubmit = async (e) => {
    e.preventDefault()

    try {
      setOfferSubmitting(true)
      setOfferError('')
      setOfferMessage('')

      const offerData = {
        ...offerForm,
        originalPrice: Number(offerForm.originalPrice),
        discountedPrice: Number(offerForm.discountedPrice),
        quantity: Number(offerForm.quantity)
      }

      if (editingOfferId) {
        await api.put(`/api/offers/${editingOfferId}`, offerData)
        setOfferMessage('Offre modifiée avec succès.')
      } else {
        await api.post('/api/offers', offerData)
        setOfferMessage('Offre créée avec succès.')
      }

      resetOfferForm()
      await fetchMerchantOffers()
    } catch (error) {
      setOfferError(
        error.response?.data?.message ||
        'Une erreur est survenue lors de l’enregistrement.'
      )
    } finally {
      setOfferSubmitting(false)
    }
  }

  // Préparer la modification d'une offre
  const handleEditOffer = (offer) => {
    setOfferForm({
      title: offer.title || '',
      description: offer.description || '',
      category: offer.category || 'Paniers',
      originalPrice: String(offer.originalPrice ?? ''),
      discountedPrice: String(offer.discountedPrice ?? ''),
      quantity: String(offer.quantity ?? ''),
      imageUrl: offer.imageUrl || '',
      pickupStart: offer.pickupStart || '',
      pickupEnd: offer.pickupEnd || '',
      address: offer.address || ''
    })

    setEditingOfferId(offer.id)
    setShowOfferForm(true)
    setOfferMessage('')
    setOfferError('')
  }

  // Supprimer une offre
  const handleDeleteOffer = async (offerId) => {
    if (!window.confirm('Voulez-vous vraiment supprimer cette offre ?')) {
      return
    }

    try {
      setOfferError('')
      setOfferMessage('')

      await api.delete(`/api/offers/${offerId}`)

      setOfferMessage('Offre supprimée avec succès.')
      if (currentUser?.role === 'admin') {
  await fetchPlatformOffers()
} else {
  await fetchMerchantOffers()
}
    } catch (error) {
      setOfferError(
        error.response?.data?.message ||
        'Impossible de supprimer cette offre.'
      )
    }
  }

  // Charger les offres lorsque le commerçant est actif
  useEffect(() => {
    if (
      currentUser?.role === 'merchant' &&
      currentUser?.status === 'active'
    ) {
      fetchMerchantOffers()
    }
  }, [currentUser])
// Charger les offres pour les étudiants et administrateurs
useEffect(() => {
  if (
    currentUser?.role === 'student' ||
    currentUser?.role === 'admin'
  ) {
    fetchPlatformOffers()
  }
}, [currentUser])
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
      <p>Gérez vos offres alimentaires.</p>
      <strong>
        {merchantOffers.length} offre(s) publiée(s)
      </strong>
    </div>

    <div className="dashboard-card">
      <span>📋</span>
      <h3>Réservations reçues</h3>
      <p>Consultez les réservations des étudiants.</p>
      <strong>À connecter</strong>
    </div>

    <div className="dashboard-card">
      <span>📊</span>
      <h3>Statistiques</h3>
      <p>Suivez vos ventes et les repas sauvés.</p>
      <strong>À connecter</strong>
    </div>
  </div>

  <section className="admin-merchants-section">
    <div className="section-heading">
      <span>GESTION DES OFFRES</span>
      <h2>Mes offres alimentaires</h2>
      <p>Publiez et gérez vos produits sur CampusSave.</p>
    </div>

    <button
      className="confirm-reservation"
      onClick={() => {
        setShowOfferForm(!showOfferForm)
        setEditingOfferId(null)
        setOfferMessage('')
        setOfferError('')
        setOfferForm({
          title: '',
          description: '',
          category: 'Paniers',
          originalPrice: '',
          discountedPrice: '',
          quantity: '',
          imageUrl: '',
          pickupStart: '',
          pickupEnd: '',
          address: ''
        })
      }}
    >
      {showOfferForm ? 'Fermer le formulaire' : '+ Ajouter une offre'}
    </button>

    {offerMessage && (
      <p className="auth-success">{offerMessage}</p>
    )}

    {offerError && (
      <p className="auth-error">{offerError}</p>
    )}

    {showOfferForm && (
      <form
        className="merchant-offer-form"
        onSubmit={handleOfferSubmit}
      >
        <h3>
          {editingOfferId ? 'Modifier mon offre' : 'Nouvelle offre'}
        </h3>

        <label>Nom de l'offre *</label>
        <input
          type="text"
          required
          value={offerForm.title}
          onChange={e => setOfferForm({
            ...offerForm,
            title: e.target.value
          })}
          placeholder="Ex : Panier surprise"
        />

        <label>Description *</label>
        <textarea
          required
          value={offerForm.description}
          onChange={e => setOfferForm({
            ...offerForm,
            description: e.target.value
          })}
          placeholder="Décrivez votre offre..."
        />

        <label>Catégorie *</label>
        <select
          required
          value={offerForm.category}
          onChange={e => setOfferForm({
            ...offerForm,
            category: e.target.value
          })}
        >
          <option value="Paniers">Paniers</option>
          <option value="Repas">Repas</option>
          <option value="Sandwichs">Sandwichs</option>
          <option value="Pâtisseries">Pâtisseries</option>
          <option value="Boissons">Boissons</option>
          <option value="Autres">Autres</option>
        </select>

        <label>Prix initial (DT) *</label>
        <input
          type="number"
          min="0.01"
          step="0.01"
          required
          value={offerForm.originalPrice}
          onChange={e => setOfferForm({
            ...offerForm,
            originalPrice: e.target.value
          })}
        />

        <label>Prix réduit (DT) *</label>
        <input
          type="number"
          min="0"
          step="0.01"
          required
          value={offerForm.discountedPrice}
          onChange={e => setOfferForm({
            ...offerForm,
            discountedPrice: e.target.value
          })}
        />

        <label>Quantité disponible *</label>
        <input
          type="number"
          min="1"
          step="1"
          required
          value={offerForm.quantity}
          onChange={e => setOfferForm({
            ...offerForm,
            quantity: e.target.value
          })}
        />

        <label>URL de l'image</label>
        <input
          type="url"
          value={offerForm.imageUrl}
          onChange={e => setOfferForm({
            ...offerForm,
            imageUrl: e.target.value
          })}
          placeholder="https://..."
        />

        <label>Début du retrait</label>
        <input
          type="datetime-local"
          value={offerForm.pickupStart}
          onChange={e => setOfferForm({
            ...offerForm,
            pickupStart: e.target.value
          })}
        />

        <label>Fin du retrait</label>
        <input
          type="datetime-local"
          value={offerForm.pickupEnd}
          onChange={e => setOfferForm({
            ...offerForm,
            pickupEnd: e.target.value
          })}
        />

        <label>Adresse</label>
        <input
          type="text"
          value={offerForm.address}
          onChange={e => setOfferForm({
            ...offerForm,
            address: e.target.value
          })}
          placeholder="Adresse de récupération"
        />

        <button
          type="submit"
          className="confirm-reservation"
          disabled={offerSubmitting}
        >
          {offerSubmitting
            ? 'Enregistrement...'
            : editingOfferId
              ? 'Enregistrer les modifications'
              : 'Publier mon offre'}
        </button>

        <button
          type="button"
          className="login-btn"
          onClick={resetOfferForm}
        >
          Annuler
        </button>
      </form>
    )}

    <div className="section-heading">
      <h2>Offres publiées</h2>
    </div>

    {offersLoading ? (
      <p>Chargement de vos offres...</p>
    ) : merchantOffers.length === 0 ? (
      <p>Vous n'avez pas encore publié d'offre.</p>
    ) : (
      <div className="reservations-list">
        {merchantOffers.map(offer => (
          <div className="reservation-card" key={offer.id}>
            {offer.imageUrl && (
              <img
                src={offer.imageUrl}
                alt={offer.title}
                style={{
                  width: '100%',
                  maxWidth: '220px',
                  borderRadius: '10px',
                  objectFit: 'cover'
                }}
              />
            )}

         <h3>{offer.title || offer.name}</h3>
            <p>{offer.description}</p>
            <p>Catégorie : {offer.category}</p>
            <p>
              Prix initial : {offer.originalPrice} DT
            </p>
            <p>
              Prix réduit : <strong>{offer.discountedPrice} DT</strong>
            </p>
            <p>Quantité : {offer.quantity}</p>
            <p>Adresse : {offer.address || 'Non renseignée'}</p>
            <p>Statut : {offer.status}</p>

            <div className="admin-merchant-actions">
              <button
                className="confirm-reservation"
                onClick={() => handleEditOffer(offer)}
              >
                Modifier
              </button>

              <button
                className="login-btn"
                onClick={() => handleDeleteOffer(offer.id)}
              >
                Supprimer
              </button>
            </div>
          </div>
        ))}
      </div>
    )}
  </section>
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
  <strong>
    {platformOffersLoading
      ? 'Chargement...'
      : `${platformOffers.length} offre(s) publiée(s)`}
  </strong>
</div>
            <div className="dashboard-card">
              <span>📊</span>
              <h3>Statistiques générales</h3>
              <p>Suivez les activités de CampusSave.</p>
              <strong>Fonctionnalité à connecter</strong>
            </div>
          </div>

          
          {/* Gestion des offres de la plateforme */}
          <section className="admin-merchants-section">
            <div className="section-heading">
              <span>GESTION DES OFFRES</span>
              <h2>Offres publiées</h2>
              <p>
                Consultez les offres et contrôlez les publications des commerçants.
              </p>
              <button
                className="filter-btn"
                onClick={fetchPlatformOffers}
                disabled={platformOffersLoading}
              >
                {platformOffersLoading ? 'Chargement...' : 'Actualiser les offres'}
              </button>
            </div>

            {offerError && (
              <p className="error-message">{offerError}</p>
            )}

            {offerMessage && (
              <p className="success-message">{offerMessage}</p>
            )}

            {platformOffersLoading ? (
              <p>Chargement des offres...</p>
            ) : platformOffers.length === 0 ? (
              <p>Aucune offre publiée pour le moment.</p>
            ) : (
              <div className="reservations-list">
                {platformOffers.map(offer => {
                const merchant = allUsers.find(
  user => user.uid === (offer.merchantId || offer.ownerId)
)

                  return (
                    <div className="reservation-card" key={offer.id}>
                      <div>
                        <h3>{offer.title}</h3>
                        <p>{offer.description}</p>
                        <p>
                          <strong>Catégorie :</strong> {offer.category}
                        </p>
                        <p>
                          <strong>Commerçant :</strong>{' '}
                         {merchant?.fullName || merchant?.name || offer.shopName || 'Commerçant'}
                        </p>
                        <p>
                          <strong>Email :</strong>{' '}
                          {merchant?.email || 'Non disponible'}
                        </p>
                        <p>
  <strong>Prix initial :</strong>{' '}
  {Number(offer.originalPrice ?? 0).toFixed(3)} DT
</p>

<p>
  <strong>Prix réduit :</strong>{' '}
  {Number(offer.discountedPrice ?? offer.discountPrice ?? 0).toFixed(3)} DT
</p>
                        <p>
                          <strong>Quantité :</strong> {offer.quantity ?? offer.availableQuantity ?? 0}
                        </p>
                        <p>
                          <strong>Adresse :</strong>{' '}
                          {offer.address || 'Non renseignée'}
                        </p>
                      </div>

                      <button
                        className="cancel-reservation-btn"
                        onClick={() => handleDeleteOffer(offer.id)}
                      >
                        Supprimer l'offre
                      </button>
                    </div>
                  )
                })}
              </div>
            )}
          </section>

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
  {[
    'Tous',
    ...new Set(displayedOffers.map(offer => offer.category).filter(Boolean))
  ].map(category => (
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
