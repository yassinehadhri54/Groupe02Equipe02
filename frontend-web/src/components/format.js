export const keyOf = item => item?.reservationId ?? item?.id ?? item?.offerId ?? item?.shopId ?? item?.uid
export const money = amount => Number.isFinite(amount)
  ? new Intl.NumberFormat('fr-TN', { maximumFractionDigits: 3 }).format(amount) + ' DT'
  : 'Indisponible'
export function date(value) {
  if (!value) return 'Indisponible'
  if (typeof value === 'string' && /^\d{2}:\d{2}$/.test(value)) return value
  const stamp = value._seconds ?? value.seconds
  const parsed = new Date(typeof stamp === 'number' ? stamp * 1000 : value)
  return Number.isNaN(parsed.getTime()) ? 'Indisponible' :
    new Intl.DateTimeFormat('fr-FR', { dateStyle: 'medium', timeStyle: 'short' }).format(parsed)
}
const states = {
  active: 'Actif', available: 'Disponible', deleted: 'Supprimée', processing: 'En cours', inactive: 'Inactif', expired: 'Expirée', sold_out: 'Épuisée',
  suspended: 'Suspendu', approved: 'Approuvé', pending: 'En attente', rejected: 'Refusé',
  confirmed: 'Confirmée', completed: 'Récupérée', cancelled: 'Annulée',
  paid: 'Payé', unpaid: 'Non payé', failed: 'Échec', refunded: 'Remboursé',
  student: 'Étudiant', merchant: 'Commerçant', admin: 'Administrateur',
}
export const label = status => states[status] ?? status ?? 'Indisponible'
