import { useCallback, useState } from 'react'
import { api } from '../services/api'
import { useAction, useResource } from '../hooks/useResource'
import { Card, Confirm, Dialog, Empty, Failure, OfferSummary, ReservationSummary, Resource } from '../components/shared'
import { date, keyOf, money } from '../components/format'

export function Catalog({ user, shopId, login, onReserved }) {
  const [filters, setFilters] = useState({})
  const [selection, setSelection] = useState(null)
  const load = useCallback(() => api.catalog({ ...filters, shopId }), [filters, shopId])
  const state = useResource(load)
  function search(event) {
    event.preventDefault()
    const fields = new FormData(event.currentTarget)
    setFilters(Object.fromEntries([...fields].filter(([, value]) => String(value).trim())))
  }
  return <section className="offers" id="offres">
    <div className="section-heading"><h2>Offres disponibles</h2><p>Réserve à prix réduit et récupère ton panier sur le campus.</p></div>
    <form className="cs-filters" onSubmit={search}>
      <label>Recherche<input name="q" placeholder="Produit ou commerce" type="search" /></label>
      <label>Catégorie<input name="category" /></label>
      <label>Prix maximum (DT)<input name="maxPrice" type="number" min="0" step=".01" /></label>
      <label>Type<select name="type"><option value="">Tous</option><option value="standard">Classique</option><option value="surprise_basket">Panier surprise</option></select></label>
      <button className="cs-primary">Filtrer</button>
    </form>
    <Resource state={state}>{result => {
      const offers = (result.data ?? []).filter(offer => !offer.adminDisabled)
      return offers.length ? <div className="cs-grid">{offers.map(offer =>
        <OfferSummary key={keyOf(offer)} offer={offer} onOpen={() => setSelection(keyOf(offer))} />)}</div>
        : <Empty>Aucune offre disponible pour ces critères.</Empty>
    }}</Resource>
    {selection && <OfferDetail id={selection} user={user} login={login} close={() => setSelection(null)}
      onReserved={item => { void state.reload(); onReserved(item) }} />}
  </section>
}

function OfferDetail({ id, user, login, close, onReserved }) {
  const load = useCallback(() => api.offer(id), [id])
  const state = useResource(load)
  const action = useAction()
  const [quantity, setQuantity] = useState('1')
  const [receipt, setReceipt] = useState(null)
  return <Dialog title="Détail de l’offre" onClose={() => { if (!action.pending) close() }}>
    {receipt ? <>
      <p role="status">Réservation créée.</p><ReservationSummary reservation={receipt} />
      <button onClick={close}>Continuer</button>
    </> : <Resource state={state}>{({ data: offer }) => <>
      <OfferSummary offer={offer} />
      <p>{offer.description}</p>
      <p>Retrait : {date(offer.pickupStart)} – {date(offer.pickupEnd)}</p>
      {offer.offerType === 'surprise_basket' && <div>
        <p>Contenu indicatif : {offer.basketItems?.join(', ') || 'Non renseigné'}</p>
        <p>Informations alimentaires : {offer.foodInfo || 'Non renseignées'}</p>
        <p>Allergènes : {offer.allergenInfo || 'Non renseignés'}</p>
      </div>}
      <Failure message={action.error} />
      {offer.adminDisabled || offer.isExpired || offer.isSoldOut || !(offer.availableQuantity > 0) || !['active', 'available'].includes(offer.status) ? <Empty>Offre indisponible.</Empty> :
        user?.role === 'student' ? <form onSubmit={event => {
          event.preventDefault()
          void action.run(async () => {
            const { data } = await api.reserve({ offerId: id, quantity: Number(quantity) })
            const item = { offerName: offer.name, pickupStart: offer.pickupStart, pickupEnd: offer.pickupEnd, ...data }
            setReceipt(item)
            onReserved(item)
          })
        }}>
          <label>Quantité<input type="number" value={quantity} min="1" max={offer.availableQuantity} required
            onChange={event => setQuantity(event.target.value)} /></label>
          <p>Total : <strong>{quantity ? money(Number(quantity) * offer.discountPrice) : '—'}</strong></p>
          <button className="cs-primary" disabled={action.pending}>Confirmer la réservation</button>
        </form> : <button onClick={() => { close(); login() }}>Se connecter pour réserver</button>}
    </>}</Resource>}
  </Dialog>
}

export function StudentReservations() {
  const state = useResource(api.myReservations)
  const [selection, setSelection] = useState(null)
  const [cancel, setCancel] = useState(null)
  return <section><h2>Mes réservations</h2><button onClick={state.reload} disabled={state.pending}>Actualiser les réservations</button>
    <Resource state={state}>{({ data }) => data?.length ? <div className="cs-grid">
      {[...data].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)).map(item => <Card key={keyOf(item)}><ReservationSummary reservation={item} />
        <div className="cs-actions">
          <button onClick={() => setSelection(item)}>Voir la réservation</button>
          {item.status === 'pending' && !['paid', 'pending', 'processing'].includes(item.paymentStatus) &&
            <button onClick={() => setCancel(item)}>Annuler la réservation</button>}
        </div></Card>)}
    </div> : <Empty>Vous n’avez encore aucune réservation.</Empty>}</Resource>
    {selection && <ReservationDetail item={selection} close={() => { setSelection(null); void state.reload() }} />}
    {cancel && <Confirm title="Annuler cette réservation ?" onClose={() => setCancel(null)}
      submitLabel="Confirmer l’annulation" onConfirm={async () => { await api.cancel(keyOf(cancel)); void state.reload() }}>
      <ReservationSummary reservation={cancel} />
    </Confirm>}
  </section>
}
function ReservationDetail({ item, close }) {
  const action = useAction()
  const [qr, setQr] = useState(null)
  const [pay, setPay] = useState(false)
  const [paid, setPaid] = useState(false)
  return <Dialog title="Détail de la réservation" onClose={() => { if (!action.pending) close() }}>
    <ReservationSummary reservation={paid ? { ...item, paymentStatus: 'paid' } : item} />
    {item.status === 'pending' && ['unpaid', 'pending', 'failed'].includes(item.paymentStatus) && !paid &&
      <button className="cs-primary" onClick={() => setPay(true)}>Payer en mode Mock</button>}
    {pay && !paid && <MockPayment id={keyOf(item)} action={action} onPaid={() => setPaid(true)} />}
    {item.status === 'confirmed' && item.paymentStatus === 'paid' && <>
      <button disabled={action.pending || qr !== null} onClick={() => action.run(async () => {
        const { data } = await api.qr(keyOf(item))
        if (!/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(data.qrCode)) throw new Error()
        setQr(data.qrCode)
      })}>Afficher le QR de retrait</button>
      {qr && <img className="cs-qr" src={qr} alt="QR de retrait à présenter au commerçant" />}
    </>}
    <Failure message={action.error} />
  </Dialog>
}

function MockPayment({ id, onPaid, action }) {
  const mode = useResource(api.paymentConfig)
  const [paymentId, setPaymentId] = useState('')
  const [uncertain, setUncertain] = useState(false)
  async function pay() {
    let key = paymentId
    try {
      if (!key) {
        const { data } = await api.initiatePayment(id)
        if (data.mode !== 'mock' || !data.paymentId) throw new Error()
        key = data.paymentId
        setPaymentId(key)
      }
      const { data } = await api.confirmPayment(key)
      if (data.status !== 'paid') throw new Error()
      onPaid()
    } catch (error) {
      if (!error.response || error.response.status >= 500 || error.response.status === 409) setUncertain(true)
      throw error
    }
  }
  return <Resource state={mode}>{({ data }) => data?.mode === 'mock' ? <div className="cs-actions">
    {!uncertain && <button className="cs-primary" disabled={action.pending} onClick={() => action.run(pay)}>
      Confirmer le paiement simulé
    </button>}
    {uncertain && paymentId && <button disabled={action.pending} onClick={() => action.run(async () => {
      const { data: payment } = await api.payment(paymentId)
      if (payment.status === 'paid' || payment.status === 'success') onPaid()
      else if (payment.status === 'pending' && payment.mode === 'mock') setUncertain(false)
    })}>Vérifier le statut du paiement</button>}
  </div> : <Empty>Paiement indisponible : le serveur doit être configuré en mode Mock.</Empty>}</Resource>
}

export function Profile({ onSaved }) {
  const state = useResource(api.profile)
  const action = useAction()
  const [saved, setSaved] = useState(false)
  return <section><h2>Mon profil</h2><Resource state={state}>{({ user }) =>
    <Card><p>{user.email}</p><form onSubmit={event => {
      event.preventDefault()
      const data = Object.fromEntries(new FormData(event.currentTarget))
      if (!data.phone.trim()) delete data.phone
      void action.run(async () => { const result = await api.updateProfile(data); onSaved(result.user); setSaved(true) })
    }}>
      <label>Nom complet<input name="fullName" defaultValue={user.fullName ?? user.name} required /></label>
      <label>Téléphone<input name="phone" type="tel" defaultValue={user.phone} /></label>
      <label>URL de la photo<input name="photoURL" type="url" defaultValue={user.photoURL} /></label>
      <Failure message={action.error} />
      {saved && <p role="status">Profil enregistré.</p>}
      <button className="cs-primary" disabled={action.pending}>Enregistrer le profil</button>
    </form></Card>
  }</Resource></section>
}
