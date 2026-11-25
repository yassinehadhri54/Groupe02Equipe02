import '@testing-library/jest-dom/vitest'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import App from './App'
import { api, tokenKey } from './services/api'

vi.mock('./services/api', async importOriginal => {
  const module = await importOriginal()
  return { ...module, api: Object.fromEntries(Object.keys(module.api).map(name => [name, vi.fn()])) }
})
vi.mock('react-leaflet', () => ({
  MapContainer: ({ children }) => <div>{children}</div>, Marker: () => null, Popup: () => null,
  TileLayer: () => null, useMap: () => ({ getCenter: () => ({ lat: 36.8, lng: 10.2 }) }),
}))
const student = { uid: 'student', role: 'student', status: 'active', fullName: 'Étudiant QA' }
const merchant = { uid: 'merchant', role: 'merchant', status: 'active', fullName: 'Commerce QA' }
const admin = { uid: 'admin', role: 'admin', status: 'active', fullName: 'Admin QA' }
const offer = { id: 'offer', name: 'Panier QA', shopName: 'Cantine QA', description: 'Selon arrivage', category: 'Repas',
  discountPrice: 5, originalPrice: 12, availableQuantity: 2, quantity: 5, status: 'available',
  offerType: 'surprise_basket', foodInfo: 'Végétarien', allergenInfo: 'Gluten', pickupStart: '17:00', pickupEnd: '19:00' }
const booking = { reservationId: 'booking', offerId: 'offer', offerName: offer.name, quantity: 2, totalPrice: 10,
  status: 'pending', paymentStatus: 'unpaid', pickupStart: offer.pickupStart, pickupEnd: offer.pickupEnd }
const impact = { recoveredOrders: 1, portions: 2, savings: 0, missingSavings: 1,
  participatingShops: 1, weekly: [{ start: '2026-11-23', recoveredOrders: 1, portions: 2, savings: 0, missingSavings: 1 }],
  monthly: [{ start: '2026-11-01', recoveredOrders: 0, portions: 0, savings: 0, missingSavings: 0 }] }
const shop = { id: 'shop', name: 'Cantine QA', status: 'approved' }
const button = name => screen.getByRole('button', { name })
const link = name => screen.getByRole('link', { name })
async function connect(role, page) {
  localStorage.setItem(tokenKey, 'simulated-token')
  api.me.mockResolvedValue({ user: role })
  if (page) history.replaceState(null, '', '#' + page)
  const interaction = userEvent.setup()
  render(<App />)
  await screen.findByText(role.fullName + ' · ' +
    ({ student: 'Étudiant', merchant: 'Commerçant', admin: 'Administrateur' })[role.role])
  return interaction
}

beforeEach(() => {
  vi.resetAllMocks()
  localStorage.clear()
  history.replaceState(null, '', '/')
  window.scrollTo = vi.fn()
  if (!HTMLDialogElement.prototype.showModal) HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute('open', '')
  }
  api.catalog.mockResolvedValue({ data: [offer] })
  api.offer.mockResolvedValue({ data: offer })
  api.dashboard.mockResolvedValue({ data: { impact, ecoPoints: { total: 20, perItem: 10,
    history: [{ reservationId: 'booking', date: '2026-11-23', points: 20 }] } } })
  api.myShop.mockResolvedValue({ data: shop })
  api.myReservations.mockResolvedValue({ data: [booking] })
  api.merchantOffers.mockResolvedValue({ data: [offer] })
})
afterEach(() => cleanup())

describe('Parcours CampusSave simulés', () => {
  it('ignore un faux rôle admin et les liens privés sans session vérifiée', async () => {
    localStorage.setItem('campussave_user', JSON.stringify(admin))
    history.replaceState(null, '', '#users')
    render(<App />)
    expect(await screen.findByRole('heading', { name: 'Panier QA' })).toBeVisible()
    expect(screen.queryByRole('link', { name: 'Utilisateurs' })).toBeNull()
    expect(api.users).not.toHaveBeenCalled()
  })

  it('valide la session auprès du serveur et expire une session révoquée', async () => {
    const user = userEvent.setup()
    api.login.mockResolvedValue({ user: admin, tokens: { idToken: 'simulated-token' } })
    api.me.mockResolvedValue({ user: student })
    render(<App />)
    await user.click(button('Connexion'))
    await user.type(screen.getByLabelText('E-mail'), 'student@example.test')
    await user.type(screen.getByLabelText('Mot de passe'), 'mock-password')
    await user.click(button('Se connecter'))
    expect(await screen.findByRole('link', { name: 'EcoPoints' })).toBeVisible()
    expect(screen.queryByRole('link', { name: 'Utilisateurs' })).toBeNull()
    window.dispatchEvent(new Event('campussave:expired'))
    expect(await screen.findByText(/session a expiré/)).toBeVisible()
  })

  it('lit le catalogue réel, filtre les paniers et ne réserve que le stock disponible', async () => {
    const user = await connect(student)
    await user.selectOptions(screen.getByLabelText('Type'), 'surprise_basket')
    await user.click(button('Filtrer'))
    await waitFor(() => expect(api.catalog).toHaveBeenLastCalledWith({ type: 'surprise_basket', shopId: null }))
    await user.click(await screen.findByRole('button', { name: 'Voir l’offre Panier QA' }))
    const dialog = await screen.findByRole('dialog')
    expect(await within(dialog).findByText('Allergènes : Gluten')).toBeVisible()
    const quantity = within(dialog).getByRole('spinbutton', { name: 'Quantité' })
    expect(quantity).toHaveAttribute('max', '2')
    await user.clear(quantity)
    await user.type(quantity, '2')
    api.reserve.mockResolvedValue({ data: booking })
    await user.click(within(dialog).getByRole('button', { name: 'Confirmer la réservation' }))
    expect(await within(dialog).findByText('Réservation créée.')).toBeVisible()
    expect(api.reserve).toHaveBeenCalledExactlyOnceWith({ offerId: 'offer', quantity: 2 })
  })

  it('empêche les doubles soumissions et confirme uniquement un paiement Mock', async () => {
    const user = await connect(student, 'bookings')
    api.paymentConfig.mockResolvedValue({ data: { mode: 'mock' } })
    api.initiatePayment.mockResolvedValue({ data: { mode: 'mock', paymentId: 'payment' } })
    let complete
    api.confirmPayment.mockImplementation(() => new Promise(resolve => { complete = resolve }))
    await user.click(await screen.findByRole('button', { name: 'Voir la réservation' }))
    await user.click(button('Payer en mode Mock'))
    await user.dblClick(await screen.findByRole('button', { name: 'Confirmer le paiement simulé' }))
    expect(api.initiatePayment).toHaveBeenCalledExactlyOnceWith('booking')
    expect(api.confirmPayment).toHaveBeenCalledExactlyOnceWith('payment')
    complete({ data: { status: 'paid' } })
    expect(await within(screen.getByRole('dialog')).findByText(/Paiement : Payé/)).toBeVisible()
  })

  it('masque l’action de paiement en mode Sandbox', async () => {
    const user = await connect(student, 'bookings')
    api.paymentConfig.mockResolvedValue({ data: { mode: 'sandbox' } })
    await user.click(await screen.findByRole('button', { name: 'Voir la réservation' }))
    await user.click(button('Payer en mode Mock'))
    expect(await screen.findByText(/serveur doit être configuré en mode Mock/)).toBeVisible()
    expect(api.initiatePayment).not.toHaveBeenCalled()
  })

  it('affiche le PNG de retrait fourni par le backend et ne rend pas le token en clair', async () => {
    api.myReservations.mockResolvedValue({ data: [{ ...booking, status: 'confirmed', paymentStatus: 'paid' }] })
    api.qr.mockResolvedValue({ data: { qrCode: 'data:image/png;base64,AAAA', token: 'not-visible' } })
    const user = await connect(student, 'bookings')
    await user.click(await screen.findByRole('button', { name: 'Voir la réservation' }))
    await user.click(button('Afficher le QR de retrait'))
    expect(await screen.findByRole('img', { name: /QR de retrait/ })).toHaveAttribute('src', 'data:image/png;base64,AAAA')
    expect(screen.queryByText('not-visible')).toBeNull()
    expect(api.qr).toHaveBeenCalledExactlyOnceWith('booking')
  })

  it('présente les offres modérées au commerçant et conserve le format des champs en édition', async () => {
    api.merchantOffers.mockResolvedValue({ data: [{ ...offer, adminDisabled: true }] })
    api.saveOffer.mockResolvedValue({ data: offer })
    const user = await connect(merchant, 'offers')
    expect(await screen.findByText('Désactivée par l’administration')).toBeVisible()
    expect(screen.queryByRole('button', { name: /Supprimer/ })).toBeNull()
    await user.click(button('Modifier Panier QA'))
    await user.click(button('Enregistrer l’offre'))
    expect(api.saveOffer).toHaveBeenCalledExactlyOnceWith(expect.objectContaining({
      name: 'Panier QA', discountPrice: 5, imageURL: '', pickupStart: '17:00', allergenInfo: 'Gluten',
    }), 'offer')
    const [payload] = api.saveOffer.mock.calls[0]
    expect(payload).not.toHaveProperty('adminDisabled')
    expect(payload).not.toHaveProperty('offerType')
  })

  it('vérifie un code manuel seulement après confirmation et affiche le résultat du serveur', async () => {
    api.verifyQr.mockResolvedValue({ data: { reservationId: 'booking', status: 'completed' } })
    const user = await connect(merchant, 'pickup')
    await user.type(await screen.findByLabelText('Code de retrait'), 'code-simule')
    await user.click(button('Vérifier le retrait'))
    expect(api.verifyQr).not.toHaveBeenCalled()
    await user.click(button('Valider le retrait'))
    expect(await screen.findByText(/Retrait validé/)).toBeVisible()
    expect(api.verifyQr).toHaveBeenCalledExactlyOnceWith('code-simule')
  })

  it('désactive et réactive une offre avec un motif envoyé uniquement après confirmation', async () => {
    api.adminOffers.mockResolvedValue({ data: [offer] })
    api.adminOffer.mockResolvedValue({ data: { offer, shop } })
    api.moderate.mockImplementation(async (_, payload) => {
      api.adminOffer.mockResolvedValue({ data: { offer: { ...offer, adminDisabled: payload.adminDisabled }, shop } })
    })
    const user = await connect(admin, 'offers')
    await user.click(await screen.findByRole('button', { name: 'Voir l’offre Panier QA' }))
    await user.click(await screen.findByRole('button', { name: 'Désactiver l’offre' }))
    await user.type(screen.getByLabelText('Motif (facultatif)'), 'Contrôle QA')
    expect(api.moderate).not.toHaveBeenCalled()
    await user.click(button('Confirmer'))
    expect(api.moderate).toHaveBeenCalledExactlyOnceWith('offer', { adminDisabled: true, reason: 'Contrôle QA' })
    await user.click(await screen.findByRole('button', { name: 'Réactiver l’offre' }))
    await user.click(button('Confirmer'))
    expect(api.moderate).toHaveBeenLastCalledWith('offer', { adminDisabled: false })
  })

  it('filtre les commerces par rayon et accède aux offres du commerce', async () => {
    api.nearby.mockResolvedValue({ data: [{ ...shop, distanceKm: 1.2, latitude: 36.8, longitude: 10.2, offersCount: 1 }] })
    const user = userEvent.setup()
    render(<App />)
    await user.click(link('Campus Radar'))
    await user.selectOptions(await screen.findByLabelText('Rayon'), '5')
    await waitFor(() => expect(api.nearby).toHaveBeenLastCalledWith({ lat: 36.8065, lng: 10.1815, radius: 5 }))
    await user.click(await screen.findByRole('button', { name: 'Offres de Cantine QA' }))
    await waitFor(() => expect(api.catalog).toHaveBeenLastCalledWith({ shopId: 'shop' }))
  })

  it('charge les EcoPoints et distingue les économies absentes d’un montant nul en français', async () => {
    const user = await connect(student, 'points')
    expect(await screen.findByText(/10 points par portion/)).toBeVisible()
    expect(screen.getByText(/\+20 EcoPoints/)).toBeVisible()
    await user.click(link('Impact'))
    expect(await screen.findByText('23 nov.')).toBeVisible()
    expect(screen.getByText(/prix initial indisponible/i)).toBeVisible()
    await user.selectOptions(screen.getByLabelText('Période'), 'monthly')
    expect(screen.getByText(/nov\. 2026/)).toBeVisible()
    expect(screen.getByText(/0 DT/)).toBeVisible()
  })

  it('relance le tableau d’impact après une panne réseau sans perdre le rôle', async () => {
    api.dashboard.mockRejectedValueOnce(new Error('network timeout'))
    const user = await connect(admin)
    expect(await screen.findByRole('alert')).toHaveTextContent('Impossible de joindre')
    await user.click(button('Réessayer'))
    expect(await screen.findByText('Commerces participants')).toBeVisible()
    expect(api.dashboard).toHaveBeenCalledTimes(2)
  })

  it('réserve l’inscription aux comptes étudiant et commerçant', async () => {
    api.register.mockResolvedValue({ user: { ...merchant, status: 'pending' } })
    const user = userEvent.setup()
    render(<App />)
    await user.click(button('Inscription'))
    expect(screen.queryByRole('option', { name: 'Administrateur' })).toBeNull()
    await user.type(screen.getByLabelText('Nom complet'), 'Commerce simulé')
    await user.selectOptions(screen.getByLabelText('Type de compte'), 'merchant')
    await user.type(screen.getByLabelText('E-mail'), 'merchant@fixture.test')
    await user.type(screen.getByLabelText('Mot de passe'), 'fixture-password')
    await user.click(button('S’inscrire'))
    expect(await screen.findByText(/Connectez-vous pour enregistrer votre commerce/)).toBeVisible()
    expect(api.register).toHaveBeenCalledExactlyOnceWith({
      role: 'merchant', fullName: 'Commerce simulé', email: 'merchant@fixture.test', password: 'fixture-password',
    })
  })

  it('réserve l’espace commerçant non approuvé à l’inscription du commerce', async () => {
    api.myShop.mockRejectedValue({ response: { status: 404 } })
    api.saveShop.mockImplementation(async () => {
      api.myShop.mockResolvedValue({ data: { ...shop, status: 'pending' } })
    })
    const user = await connect({ ...merchant, status: 'pending' }, 'offers')
    expect(screen.queryByRole('link', { name: 'Mes offres' })).toBeNull()
    await user.type(await screen.findByLabelText('Nom du commerce'), shop.name)
    await user.type(screen.getByLabelText('Adresse'), 'Tunis')
    await user.type(screen.getByLabelText('Téléphone'), '12345678')
    await user.click(button('Enregistrer le commerce'))
    expect(await screen.findByText('En attente', { exact: true })).toBeVisible()
    expect(api.saveShop).toHaveBeenCalledWith(expect.objectContaining({ name: shop.name, address: 'Tunis' }), false)
    expect(api.merchantOffers).not.toHaveBeenCalled()
  })

  it('réactive seulement les comptes que le serveur autorise à gérer', async () => {
    api.users.mockResolvedValue({ users: [admin, student] })
    api.user.mockResolvedValue({ user: admin })
    api.userStatus.mockResolvedValue({})
    const user = await connect(admin, 'users')
    await user.click(await screen.findByRole('button', { name: 'Voir le profil de Admin QA' }))
    await within(await screen.findByRole('dialog')).findByText('Admin QA')
    expect(screen.queryByRole('button', { name: 'Suspendre le compte' })).toBeNull()
    await user.click(button('Fermer'))
    api.user.mockResolvedValue({ user: { ...student, status: 'suspended' } })
    await user.click(button('Voir le profil de Étudiant QA'))
    await user.click(await screen.findByRole('button', { name: 'Réactiver le compte' }))
    await user.click(button('Confirmer'))
    expect(api.userStatus).toHaveBeenCalledExactlyOnceWith('student', 'active')
  })

  it('ne relance pas automatiquement un paiement Mock dont la confirmation est incertaine', async () => {
    const user = await connect(student, 'bookings')
    api.paymentConfig.mockResolvedValue({ data: { mode: 'mock' } })
    api.initiatePayment.mockResolvedValue({ data: { mode: 'mock', paymentId: 'payment' } })
    api.confirmPayment.mockRejectedValue(new Error('network timeout'))
    api.payment.mockResolvedValue({ data: { status: 'paid', mode: 'mock' } })
    await user.click(await screen.findByRole('button', { name: 'Voir la réservation' }))
    await user.click(button('Payer en mode Mock'))
    await user.click(await screen.findByRole('button', { name: 'Confirmer le paiement simulé' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Résultat incertain')
    expect(screen.queryByRole('button', { name: 'Confirmer le paiement simulé' })).toBeNull()
    await user.click(button('Vérifier le statut du paiement'))
    expect(await screen.findByText(/Paiement : Payé/)).toBeVisible()
    expect(api.initiatePayment).toHaveBeenCalledTimes(1)
    expect(api.confirmPayment).toHaveBeenCalledTimes(1)
  })

  it('retrouve les données Radar après une erreur réseau et un refus de géolocalisation', async () => {
    api.nearby.mockRejectedValueOnce(new Error('network')).mockResolvedValue({ data: [] })
    const original = Object.getOwnPropertyDescriptor(navigator, 'geolocation')
    Object.defineProperty(navigator, 'geolocation', { configurable: true,
      value: { getCurrentPosition: (_, onError) => onError() } })
    try {
      const user = userEvent.setup()
      render(<App />)
      await user.click(link('Campus Radar'))
      expect(await screen.findByRole('alert')).toHaveTextContent('Impossible de joindre')
      await user.click(button('Réessayer'))
      expect(await screen.findByText('Aucun commerce approuvé dans ce rayon.')).toBeVisible()
      await user.click(button('Utiliser ma position'))
      expect(await screen.findByRole('alert')).toHaveTextContent('Position refusée')
      expect(screen.getByRole('button', { name: 'Rechercher ces coordonnées' })).toBeEnabled()
      expect(api.nearby).toHaveBeenCalledTimes(2)
    } finally {
      if (original) Object.defineProperty(navigator, 'geolocation', original)
      else delete navigator.geolocation
    }
  })

  it('applique les deux thèmes, persiste le choix et conserve la session', async () => {
    const user = await connect(student)
    expect(document.documentElement).toHaveAttribute('data-theme', 'light')
    await user.click(button('Activer le mode nuit'))
    expect(document.documentElement).toHaveAttribute('data-theme', 'dark')
    expect(localStorage.getItem(tokenKey)).toBe('simulated-token')
    cleanup()
    render(<App />)
    expect(await screen.findByRole('button', { name: 'Activer le mode jour' })).toBeVisible()
    await user.click(button('Activer le mode jour'))
    expect(document.documentElement).toHaveAttribute('data-theme', 'light')
  })
})
