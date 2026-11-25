import { useCallback, useState } from 'react'
import { api } from '../services/api'
import { useResource } from '../hooks/useResource'
import { Card, Confirm, Dialog, Empty, OfferSummary, Resource } from '../components/shared'
import { date, keyOf, label } from '../components/format'

export default function Admin({ page, user }) {
  if (page === 'users') return <Users user={user} />
  if (page === 'shops') return <Shops />
  return <Offers />
}

const normalized = value => String(value ?? '').toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '')
function Options({ values }) {
  return values.map(value => <option key={value} value={value}>{label(value)}</option>)
}
function Users({ user }) {
  const state = useResource(api.users)
  const [filters, setFilters] = useState({})
  const [selected, setSelected] = useState('')
  return <section><h2>Utilisateurs</h2>
    <form className="cs-filters" onSubmit={event => {
      event.preventDefault(); setFilters(Object.fromEntries(new FormData(event.currentTarget)))
    }}>
      <label>Nom ou e-mail<input name="q" type="search" /></label>
      <label>Rôle<select name="role"><option value="">Tous</option><Options values={['student', 'merchant', 'admin']} /></select></label>
      <label>Statut<select name="status"><option value="">Tous</option><Options values={['active', 'pending', 'suspended', 'rejected']} /></select></label>
      <button>Filtrer les utilisateurs</button>
    </form>
    <Resource state={state}>{({ users = [] }) => {
      const results = users.filter(entry => (!filters.role || entry.role === filters.role) &&
        (!filters.status || entry.status === filters.status) && normalized([entry.fullName, entry.email].join(' ')).includes(normalized(filters.q)))
      return results.length ? <div className="cs-grid">{results.map(entry => <Card key={keyOf(entry)}>
        <h3>{entry.fullName}</h3><p>{entry.email}</p><p>{label(entry.role)} · {label(entry.status)}</p>
        <button onClick={() => setSelected(keyOf(entry))}>Voir le profil de {entry.fullName}</button>
      </Card>)}</div> : <Empty>Aucun utilisateur pour ces critères.</Empty>
    }}</Resource>
    {selected && <UserDetail uid={selected} owner={keyOf(user)} close={() => setSelected('')} reload={state.reload} />}
  </section>
}
function UserDetail({ uid, owner, close, reload }) {
  const state = useResource(useCallback(() => api.user(uid), [uid]))
  const [decision, setDecision] = useState(false)
  return <Dialog title="Détail utilisateur" onClose={close}>
    <Resource state={state}>{({ user }) => <>
      <h3>{user.fullName}</h3><p>{user.email}</p><p>{label(user.role)} · {label(user.status)}</p>
      {user.phone && <p>{user.phone}</p>}
      <p>Date de création : {date(user.createdAt)}</p>
      {user.role !== 'admin' && owner !== uid &&
        <button onClick={() => setDecision(true)}>{user.status === 'suspended' ? 'Réactiver le compte' : 'Suspendre le compte'}</button>}
      {decision && <Confirm title={user.status === 'suspended' ? 'Réactiver ce compte ?' : 'Suspendre ce compte ?'}
        onClose={() => setDecision(false)} onConfirm={async () => {
          await api.userStatus(uid, user.status === 'suspended' ? 'active' : 'suspended')
          void reload(); void state.reload()
        }}><p>{user.fullName}</p></Confirm>}
    </>}</Resource>
  </Dialog>
}

function Shops() {
  const [status, setStatus] = useState('')
  const [decision, setDecision] = useState(null)
  const state = useResource(useCallback(() => api.shops(status || undefined), [status]))
  return <section><h2>Commerces</h2>
    <label className="cs-filter-single">Statut<select value={status} onChange={event => setStatus(event.target.value)}>
      <option value="">Tous</option><Options values={['pending', 'approved', 'rejected', 'suspended']} />
    </select></label>
    <Resource state={state}>{({ data }) => data?.length ? <div className="cs-grid">{data.map(item => <Card key={keyOf(item)}>
      <h3>{item.name}</h3><p>{item.address}</p><p>{item.description}</p><p>{item.phone} {item.email}</p>
      <p>Approbation : {label(item.status)}</p>
      <div className="cs-actions">
        {['pending', 'rejected'].includes(item.status) && <button onClick={() => setDecision([item, 'approve'])}>Approuver</button>}
        {['pending', 'approved'].includes(item.status) && <button onClick={() => setDecision([item, 'reject'])}>Refuser</button>}
      </div>
    </Card>)}</div> : <Empty>Aucun commerce pour ce statut.</Empty>}</Resource>
    {decision && <Confirm title={decision[1] === 'approve' ? 'Approuver ce commerce ?' : 'Refuser ce commerce ?'}
      onClose={() => setDecision(null)} onConfirm={async () => {
        await api.shopReview(keyOf(decision[0]), decision[1]); void state.reload()
      }}><p>{decision[0].name}</p></Confirm>}
  </section>
}
function Offers() {
  const [filters, setFilters] = useState({})
  const [selected, setSelected] = useState('')
  const state = useResource(useCallback(() => api.adminOffers(filters), [filters]))
  return <section><h2>Modération des offres</h2>
    <form className="cs-filters" onSubmit={event => {
      event.preventDefault()
      setFilters(Object.fromEntries([...new FormData(event.currentTarget)].map(([key, value]) => [key, value.trim()]).filter(([, value]) => value)))
    }}>
      <label>Recherche<input name="q" type="search" maxLength="100" /></label>
      <label>Catégorie<input name="category" maxLength="100" /></label>
      <label>Statut<select name="status"><option value="">Tous</option><Options values={['available', 'active', 'expired', 'sold_out', 'deleted']} /></select></label>
      <label>Modération<select name="adminDisabled"><option value="">Toutes</option><option value="true">Désactivées</option><option value="false">Non désactivées</option></select></label>
      <button>Filtrer les offres</button>
    </form>
    <Resource state={state}>{({ data }) => data?.length ? <div className="cs-grid">{data.map(item =>
      <OfferSummary key={keyOf(item)} offer={item} onOpen={() => setSelected(keyOf(item))} />
    )}</div> : <Empty>Aucune offre pour ces critères.</Empty>}</Resource>
    {selected && <Moderation id={selected} close={() => setSelected('')} reload={state.reload} />}
  </section>
}
function Moderation({ id, close, reload }) {
  const state = useResource(useCallback(() => api.adminOffer(id), [id]))
  const [confirm, setConfirm] = useState(false)
  const [reason, setReason] = useState('')
  return <Dialog title="Détail et modération de l’offre" onClose={close}>
    <Resource state={state}>{({ data: { offer, shop } }) => <>
      <OfferSummary offer={offer} />
      <p>{offer.description}</p>
      <p>Retrait : {date(offer.pickupStart)} – {date(offer.pickupEnd)}</p>
      {shop && <p>Commerce : {shop.name} · {label(shop.status)}<br />{shop.address}</p>}
      {offer.moderationHistory?.length > 0 && <ul>{offer.moderationHistory.map((entry, index) =>
        <li key={entry.id ?? index}>{date(entry.createdAt)} · {entry.adminDisabled ? 'Désactivation' : 'Réactivation'}
          {entry.reason && ' · ' + entry.reason}</li>)}</ul>}
      {offer.status !== 'deleted' && <button onClick={() => { setReason(''); setConfirm(true) }}>
        {offer.adminDisabled ? 'Réactiver l’offre' : 'Désactiver l’offre'}
      </button>}
      {confirm && <Confirm title={offer.adminDisabled ? 'Réactiver cette offre ?' : 'Désactiver cette offre ?'}
        onClose={() => setConfirm(false)} onConfirm={async () => {
          const trimmed = reason.trim()
          await api.moderate(id, { adminDisabled: !offer.adminDisabled, ...(trimmed && { reason: trimmed }) })
          void state.reload(); void reload()
        }}>
        <p>{offer.adminDisabled ? 'Les contrôles de stock, de créneau et de statut du commerce restent applicables.' :
          'Le catalogue public masquera cette offre et les nouvelles réservations seront bloquées.'}</p>
        <label>Motif (facultatif)<textarea maxLength="500" value={reason} onChange={event => setReason(event.target.value)} /></label>
      </Confirm>}
    </>}</Resource>
  </Dialog>
}
