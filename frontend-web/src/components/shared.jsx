import { useEffect, useRef } from 'react'
import { useAction } from '../hooks/useResource'

import { date, keyOf, label, money } from './format'

export function Failure({ message }) {
  return message ? <p className="cs-error" role="alert">{message}</p> : null
}
export function Resource({ state, children }) {
  if (state.pending) return <div className="cs-loading" role="status">Chargement…</div>
  if (state.error) return <div><Failure message={state.error} /><button onClick={state.reload}>Réessayer</button></div>
  return children(state.data)
}
export function Empty({ children = 'Aucun résultat.' }) {
  return <p className="cs-muted">{children}</p>
}
export function Card({ children, className = '' }) {
  return <article className={'cs-card ' + className}>{children}</article>
}
export function OfferSummary({ offer, onOpen }) {
  return <Card>
    {offer.imageURL && /^https?:\/\//i.test(offer.imageURL) && <img className="cs-offer-image" src={offer.imageURL} alt="" loading="lazy" />}
    <h3>{offer.name}</h3>
    {offer.offerType === 'surprise_basket' && <span className="cs-badge">Panier surprise</span>}
    {offer.adminDisabled && <span className="cs-badge">Désactivée par l’administration</span>}
    <p>{offer.shopName ?? offer.category}</p>
    <p><strong>{money(offer.discountPrice)}</strong> <del>{money(offer.originalPrice)}</del></p>
    <p>{offer.availableQuantity ?? offer.quantity ?? 0} portion(s) disponible(s) · {label(offer.status)}</p>
    {onOpen && <button onClick={onOpen}>Voir l’offre {offer.name}</button>}
  </Card>
}
export function Dialog({ title, onClose, children }) {
  const dialog = useRef(null)
  useEffect(() => { dialog.current.showModal() }, [])
  return <dialog ref={dialog} className="cs-dialog" aria-label={title} onCancel={event => { event.preventDefault(); onClose() }}>
    <header><h2>{title}</h2><button type="button" aria-label="Fermer" onClick={onClose}>×</button></header>
    {children}
  </dialog>
}
export function Confirm({ title, children, onClose, onConfirm, submitLabel = 'Confirmer' }) {
  const action = useAction()
  return <Dialog title={title} onClose={() => { if (!action.pending) onClose() }}>
    {children}
    <Failure message={action.error} />
    <div className="cs-actions">
      <button type="button" onClick={onClose} disabled={action.pending}>Annuler</button>
      <button type="button" className="cs-primary" disabled={action.pending}
        onClick={() => action.run(async () => { await onConfirm(); onClose() })}>
        {action.pending ? 'En cours…' : submitLabel}
      </button>
    </div>
  </Dialog>
}
export function ReservationSummary({ reservation: item }) {
  return <>
    <h3>{item.offerName ?? item.offer?.name ?? 'Réservation'}</h3>
    <p>{item.quantity} portion(s) · {money(item.totalPrice)}</p>
    <p>{label(item.status)} · Paiement : {label(item.paymentStatus)}</p>
    <p>Retrait : {date(item.pickupStart)} – {date(item.pickupEnd)}</p>
    {item.shopName && <p>{item.shopName}</p>}
    <small>Référence : {keyOf(item)}</small>
  </>
}
