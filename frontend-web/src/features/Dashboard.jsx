import { useCallback, useState } from 'react'
import { api } from '../services/api'
import { useResource } from '../hooks/useResource'
import { Card, Empty, ReservationSummary, Resource } from '../components/shared'
import { date, keyOf, label, money } from '../components/format'

function Metric({ title, value }) {
  return <article className="cs-card cs-metric"><h3>{title}</h3><strong>{value ?? 'Indisponible'}</strong></article>
}
function savings(impact) {
  if (impact.recoveredOrders > 0 && impact.missingSavings >= impact.recoveredOrders) return 'Indisponible'
  return money(impact.savings)
}
function Periods({ impact, role }) {
  const [period, setPeriod] = useState('weekly')
  const periods = impact[period] ?? []
  const max = Math.max(1, ...periods.map(item => item.portions))
  const format = new Intl.DateTimeFormat('fr-FR', {
    ...(period === 'weekly' ? { day: 'numeric', month: 'short' } : { month: 'short', year: 'numeric' }), timeZone: 'UTC',
  })
  return <Card>
    <h3>Impact par période</h3>
    <label>Période<select value={period} onChange={event => setPeriod(event.target.value)}>
      <option value="weekly">Semaines</option><option value="monthly">Mois</option>
    </select></label>
    {periods.length ? <ul className="cs-chart">{periods.map(item => <li key={item.start}>
      <span>{format.format(new Date(item.start))}</span>
      <span className="cs-chart-track"><span style={{ width: (item.portions * 100 / max) + '%' }} /></span>
      <span>{item.portions} portion(s) · {item.recoveredOrders} commande(s)
        {role === 'student' && ' · ' + savings(item)}
        {role === 'admin' && ' · ' + item.participatingShops + ' commerce(s)'}</span>
    </li>)}</ul> : <Empty>Aucune période disponible.</Empty>}
  </Card>
}

export default function Dashboard({ role, pointsOnly = false }) {
  const state = useResource(useCallback(() => api.dashboard(role), [role]))
  return <section><h2>{pointsOnly ? 'Mes EcoPoints' : role === 'admin' ? 'Impact global' : 'Tableau de bord et impact'}</h2>
    <button onClick={state.reload} disabled={state.pending}>Actualiser le tableau de bord</button>
    <Resource state={state}>{({ data }) => {
      const impact = data.impact
      if (pointsOnly) return <Points points={data.ecoPoints} />
      return <>
        <div className="cs-grid">
          {role === 'admin' && <>
            <Metric title="Utilisateurs" value={data.users?.total} />
            <Metric title="Commerces" value={data.shops?.total} />
            <Metric title="Commerces en attente" value={data.shops?.byStatus?.pending} />
          </>}
          {role !== 'student' && <Metric title="Offres" value={data.offers?.total} />}
          <Metric title="Réservations" value={data.reservations?.total} />
          <Metric title="Commandes récupérées" value={impact?.recoveredOrders} />
          <Metric title="Portions sauvées" value={impact?.portions} />
          {role === 'admin' && <Metric title="Commerces participants" value={impact?.participatingShops} />}
          {role === 'student' && <>
            <Metric title="Économies réalisées" value={impact && savings(impact)} />
            <Metric title="EcoPoints" value={data.ecoPoints?.total} />
          </>}
          {role === 'merchant' && <>
            <Metric title="Statut du commerce" value={data.shop && label(data.shop.status)} />
            <Metric title="Paiements enregistrés" value={money(data.revenue?.paid?.total)} />
            {Number.isFinite(data.revenue?.paid?.byMode?.mock) &&
              <Metric title="Dont paiements simulés" value={money(data.revenue.paid.byMode.mock)} />}
          </>}
        </div>
        {role === 'student' && impact?.missingSavings > 0 && <p className="cs-muted">
          Prix initial indisponible pour {impact.missingSavings} réservation(s).
        </p>}
        {impact ? <Periods impact={impact} role={role} /> : <Empty>Statistiques d’impact indisponibles.</Empty>}
        {data.recentReservations && <section><h3>Réservations récentes</h3>
          {data.recentReservations.length ? <div className="cs-grid">{data.recentReservations.map(item =>
            <Card key={keyOf(item)}><ReservationSummary reservation={item} /></Card>)}</div> : <Empty />}
        </section>}
        {data.topOffers && <section><h3>Meilleures offres</h3>
          {data.topOffers.length ? <ul className="cs-chart">{data.topOffers.map(item =>
            <li key={keyOf(item)}>{item.offerName} · {item.quantityReserved} portion(s) réservée(s)</li>)}</ul> : <Empty />}
        </section>}
      </>
    }}</Resource>
  </section>
}
function Points({ points }) {
  if (!points) return <Empty>Solde EcoPoints indisponible.</Empty>
  return <>
    <Metric title="Solde EcoPoints" value={points.total} />
    {Number.isFinite(points.perItem) && <p>{points.perItem} points par portion récupérée après validation du retrait.</p>}
    <h3>Historique des points</h3>
    {points.history?.length ? <ul className="cs-chart">{points.history.map(item =>
      <li key={item.reservationId}>{date(item.date)} · +{item.points} EcoPoints · {item.reservationId}</li>
    )}</ul> : <Empty>Aucun point attribué.</Empty>}
  </>
}
