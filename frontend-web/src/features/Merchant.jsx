import { useCallback, useEffect, useRef, useState } from 'react'
import { api } from '../services/api'
import { useAction, useResource } from '../hooks/useResource'
import { Card, Confirm, Dialog, Empty, Failure, OfferSummary, ReservationSummary, Resource } from '../components/shared'
import { date, keyOf, label } from '../components/format'

const readShop = () => api.myShop().catch(error => {
  if (error.response?.status === 404) return { data: null }
  throw error
})

export default function Merchant({ page, onRefreshSession, awaitingApproval }) {
  const shop = useResource(readShop)
  return <Resource state={shop}>{({ data }) => {
    if (page === 'shop' || !data || data.status !== 'approved') return <ShopForm key={keyOf(data) ?? 'new'} shop={data} reload={shop.reload} onRefreshSession={onRefreshSession} awaitingApproval={awaitingApproval} />
    if (page === 'offers') return <MerchantOffers />
    if (page === 'pickup') return <Pickup />
    return <MerchantReservations />
  }}</Resource>
}

function ShopForm({ shop, reload, onRefreshSession, awaitingApproval }) {
  const action = useAction()
  return <section><h2>Mon commerce</h2><Card>
    {shop && <p>Approbation : <strong>{label(shop.status)}</strong></p>}
    {awaitingApproval && shop && <button onClick={onRefreshSession}>Actualiser l’approbation</button>}
    {shop?.status !== 'approved' && <p>L’approbation du commerce est nécessaire pour publier des offres et gérer les retraits.</p>}
    <form onSubmit={event => {
      event.preventDefault()
      const values = Object.fromEntries(new FormData(event.currentTarget))
      const { latitude, longitude, ...fields } = values
      void action.run(async () => {
        if (latitude || longitude) { fields.latitude = latitude; fields.longitude = longitude }
        if (!fields.email) delete fields.email
        await api.saveShop(fields, Boolean(shop))
        void reload()
      })
    }}>
      <label>Nom du commerce<input name="name" defaultValue={shop?.name} required /></label>
      <label>Adresse<input name="address" defaultValue={shop?.address} required /></label>
      <label>Téléphone<input name="phone" type="tel" defaultValue={shop?.phone} required /></label>
      <label>E-mail du commerce<input name="email" type="email" defaultValue={shop?.email} /></label>
      <label>Description<textarea name="description" defaultValue={shop?.description} /></label>
      <div className="cs-filters">
        <label>Latitude<input name="latitude" type="number" min="-90" max="90" step="any" defaultValue={shop?.latitude} /></label>
        <label>Longitude<input name="longitude" type="number" min="-180" max="180" step="any" defaultValue={shop?.longitude} /></label>
      </div>
      <Failure message={action.error} />
      <button className="cs-primary" disabled={action.pending}>{shop ? 'Modifier le commerce' : 'Enregistrer le commerce'}</button>
    </form>
  </Card></section>
}

function MerchantOffers() {
  const state = useResource(api.merchantOffers)
  const [editing, setEditing] = useState(null)
  const [removing, setRemoving] = useState(null)
  const onSaved = () => { setEditing(null); void state.reload() }
  return <section><div className="section-heading"><h2>Mes offres</h2>
    <button className="cs-primary" onClick={() => setEditing({})}>Créer une offre</button></div>
    <Resource state={state}>{({ data }) => data?.length ? <div className="cs-grid">{data.map(item =>
      <div key={keyOf(item)}>
        <OfferSummary offer={item} />
        <div className="cs-actions">
          <button onClick={() => setEditing(item)}>Modifier {item.name}</button>
          {!item.adminDisabled && <button onClick={() => setRemoving(item)}>Supprimer {item.name}</button>}
        </div>
      </div>)}</div> : <Empty>Vous n’avez encore aucune offre.</Empty>}</Resource>
    {editing && <OfferEditor item={editing} close={() => setEditing(null)} onSaved={onSaved} />}
    {removing && <Confirm title="Supprimer cette offre ?" onClose={() => setRemoving(null)}
      onConfirm={async () => { await api.deleteOffer(keyOf(removing)); void state.reload() }}>
      <p>{removing.name}</p>
    </Confirm>}
  </section>
}
function localInput(value) {
  if (!value) return ''
  const seconds = value._seconds ?? value.seconds
  const date = new Date(typeof seconds === 'number' ? seconds * 1000 : value)
  if (Number.isNaN(date.getTime())) return ''
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
}
function OfferEditor({ item, close, onSaved }) {
  const action = useAction()
  const [type, setType] = useState(item.offerType ?? 'standard')
  const [validation, setValidation] = useState(null)
  const legacyWindow = typeof item.pickupStart === 'string' && /^\d{2}:\d{2}$/.test(item.pickupStart)
  const basket = type === 'surprise_basket'
  function submit(event) {
    event.preventDefault()
    const fields = Object.fromEntries(new FormData(event.currentTarget))
    const { basketItems, foodInfo, allergenInfo, originalPrice, discountPrice, quantity, pickupStart, pickupEnd, ...common } = fields
    setValidation(null)
    if (pickupStart >= pickupEnd) { setValidation('Le retrait doit se terminer après son début.'); return }
    if (basket && Number(discountPrice) > Number(originalPrice) / 2) {
      setValidation('Un panier surprise doit coûter au maximum 50 % de sa valeur initiale.'); return
    }
    const payload = { ...common, originalPrice: Number(originalPrice), discountPrice: Number(discountPrice),
      quantity: Number(quantity), pickupStart: legacyWindow ? pickupStart : new Date(pickupStart).toISOString(),
      pickupEnd: legacyWindow ? pickupEnd : new Date(pickupEnd).toISOString() }
    if (basket) Object.assign(payload, { basketItems: basketItems.split('\n').map(item => item.trim()).filter(Boolean), foodInfo, allergenInfo })
    if (!keyOf(item)) payload.offerType = type
    void action.run(async () => { await api.saveOffer(payload, keyOf(item)); onSaved() })
  }
  return <Dialog title={keyOf(item) ? 'Modifier l’offre' : 'Créer une offre'} onClose={() => { if (!action.pending) close() }}>
    {item.adminDisabled && <p className="cs-badge">Désactivée par l’administration</p>}
    <form onSubmit={submit}>
      <label>Type<select value={type} disabled={Boolean(keyOf(item))} onChange={event => setType(event.target.value)}>
        <option value="standard">Classique</option><option value="surprise_basket">Panier surprise</option>
      </select></label>
      <label>Nom de l’offre<input name="name" defaultValue={item.name} required /></label>
      <label>Catégorie<input name="category" defaultValue={item.category} required /></label>
      <label>Description<textarea name="description" defaultValue={item.description} required /></label>
      <div className="cs-filters">
        <label>Prix initial (DT)<input name="originalPrice" type="number" step=".001" min=".001" defaultValue={item.originalPrice} required /></label>
        <label>Prix réduit (DT)<input name="discountPrice" type="number" step=".001" min=".001" defaultValue={item.discountPrice} required /></label>
        <label>Stock total<input name="quantity" type="number" min="1" defaultValue={item.quantity} required /></label>
        <label>Début du retrait<input name="pickupStart" type={legacyWindow ? 'time' : 'datetime-local'} defaultValue={legacyWindow ? item.pickupStart : localInput(item.pickupStart)} required /></label>
        <label>Fin du retrait<input name="pickupEnd" type={legacyWindow ? 'time' : 'datetime-local'} defaultValue={legacyWindow ? item.pickupEnd : localInput(item.pickupEnd)} required /></label>
      </div>
      <label>URL de l’image<input type="url" name="imageURL" defaultValue={item.imageURL} /></label>
      {basket && <>
        <label>Contenu indicatif (un produit par ligne)<textarea name="basketItems" defaultValue={item.basketItems?.join('\n')} /></label>
        <label>Informations alimentaires<textarea name="foodInfo" defaultValue={item.foodInfo} /></label>
        <label>Allergènes<textarea name="allergenInfo" defaultValue={item.allergenInfo} /></label>
      </>}
      <Failure message={validation || action.error} />
      <button className="cs-primary" disabled={action.pending}>Enregistrer l’offre</button>
    </form>
  </Dialog>
}

function MerchantReservations() {
  const state = useResource(api.merchantReservations)
  const [decision, setDecision] = useState(null)
  return <section><h2>Réservations reçues</h2><button onClick={state.reload} disabled={state.pending}>Actualiser les réservations</button>
    <Resource state={state}>{({ data }) => data?.length ? <div className="cs-grid">{data.map(item =>
      <Card key={keyOf(item)}><ReservationSummary reservation={item} />
        {item.studentName && <p>{item.studentName}</p>}
        {item.status === 'pending' && item.paymentStatus === 'paid' &&
          <button onClick={() => setDecision([item, 'confirmed'])}>Confirmer la réservation</button>}
        {item.status === 'pending' && !['paid', 'pending', 'processing'].includes(item.paymentStatus) &&
          <button onClick={() => setDecision([item, 'rejected'])}>Refuser la réservation</button>}
      </Card>)}</div> : <Empty>Aucune réservation reçue.</Empty>}</Resource>
    {decision && <Confirm title={decision[1] === 'confirmed' ? 'Confirmer cette réservation ?' : 'Refuser cette réservation ?'}
      onClose={() => setDecision(null)} onConfirm={async () => {
        await api.reservationStatus(keyOf(decision[0]), decision[1]); void state.reload()
      }}><ReservationSummary reservation={decision[0]} /></Confirm>}
  </section>
}

export function Pickup() {
  const [token, setToken] = useState('')
  const [camera, setCamera] = useState(false)
  const [confirm, setConfirm] = useState(false)
  const [result, setResult] = useState(null)
  const onRead = useCallback(code => { setToken(code); setCamera(false) }, [])
  return <section><h2>Vérifier un retrait</h2><Card>
    <button onClick={() => setCamera(active => !active)}>{camera ? 'Fermer la caméra' : 'Scanner le QR avec la caméra'}</button>
    {camera && <Scanner onRead={onRead} />}
    <form onSubmit={event => { event.preventDefault(); setResult(null); setConfirm(true); setCamera(false) }}>
      <label>Code de retrait<input type="password" value={token} onChange={event => setToken(event.target.value.trim())}
        required autoComplete="off" spellCheck="false" /></label>
      <button className="cs-primary" disabled={!token}>Vérifier le retrait</button>
    </form>
    {result && <p role="status">Retrait validé · Réservation {result.reservationId}
      {result.completedAt && ' · ' + date(result.completedAt)}
      {Number.isFinite(result.ecoPointsEarned) && ' · ' + result.ecoPointsEarned + ' EcoPoints attribués'}</p>}
  </Card>
    {confirm && <Confirm title="Valider définitivement ce retrait ?" onClose={() => setConfirm(false)}
      submitLabel="Valider le retrait" onConfirm={async () => {
        const { data } = await api.verifyQr(token)
        setToken(''); setResult(data)
      }}><p>Présentez le panier au client après confirmation par le serveur.</p></Confirm>}
  </section>
}
function Scanner({ onRead }) {
  const video = useRef(null)
  const available = Boolean(navigator.mediaDevices?.getUserMedia)
  const [error, setError] = useState(null)
  useEffect(() => {
    let stopped = false
    let controls
    const target = video.current
    if (!available) return
    void import('@zxing/browser').then(async ({ BrowserQRCodeReader }) => {
      if (stopped) return
      controls = await new BrowserQRCodeReader().decodeFromConstraints(
        { audio: false, video: { facingMode: { ideal: 'environment' } } }, target, (result, _, stream) => {
          if (!result || stopped) return
          stream.stop()
          onRead(result.getText().trim())
        })
      if (stopped) controls.stop()
    }).catch(() => { if (!stopped) setError('Accès caméra refusé ou indisponible. Saisissez le code manuellement.') })
    return () => { stopped = true; controls?.stop() }
  }, [available, onRead])
  return <><video ref={video} className="cs-scanner" autoPlay muted playsInline aria-label="Aperçu de la caméra" />
    <Failure message={available ? error : 'Caméra indisponible. Saisissez le code manuellement.'} /></>
}
