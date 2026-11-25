import axios from 'axios'

export const tokenKey = 'campussave_token'
const http = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:5000',
  timeout: 22000,
})
http.interceptors.request.use((request) => {
  const token = localStorage.getItem(tokenKey)
  if (token && !['/api/auth/login', '/api/auth/register'].includes(request.url)) {
    request.headers.Authorization = 'Bearer ' + token
  }
  return request
})
http.interceptors.response.use(response => response, error => {
  if (error.response?.status === 401 && !['/api/auth/login', '/api/auth/register'].includes(error.config?.url)
    && error.config?.headers?.Authorization === 'Bearer ' + localStorage.getItem(tokenKey)) {
    localStorage.removeItem(tokenKey)
    window.dispatchEvent(new Event('campussave:expired'))
  }
  return Promise.reject(error)
})

const request = (method, url, options = {}) =>
  http.request({ method, url: '/api' + url, ...options }).then(response => response.data)
const get = (path, params) => request('get', path, { params })
const post = (path, data) => request('post', path, { data })
const put = (path, data) => request('put', path, { data })
const id = encodeURIComponent
export const api = {
  login: data => post('/auth/login', data),
  register: data => post('/auth/register', data),
  me: () => get('/auth/me'),
  logout: () => post('/auth/logout'),
  profile: () => get('/users/profile'),
  updateProfile: data => put('/users/profile', data),
  catalog: filters => get('/offers', filters),
  offer: key => get('/offers/' + id(key)),
  nearby: params => get('/shops/nearby', params),
  myShop: () => get('/shops/my-shop'),
  saveShop: (data, exists) => exists ? put('/shops/my-shop', data) : post('/shops/register', data),
  merchantOffers: () => get('/offers/merchant/my-offers'),
  saveOffer: (data, key) => key ? put('/offers/' + id(key), data) : post('/offers', data),
  deleteOffer: key => request('delete', '/offers/' + id(key)),
  reserve: data => post('/reservations', data),
  myReservations: () => get('/reservations/my-reservations'),
  merchantReservations: () => get('/reservations/merchant'),
  cancel: key => put('/reservations/' + id(key) + '/cancel'),
  reservationStatus: (key, status) => put('/reservations/' + id(key) + '/status', { status }),
  qr: key => get('/reservations/' + id(key) + '/qr'),
  verifyQr: token => post('/reservations/verify-qr', { token }),
  paymentConfig: () => get('/payments/config'),
  initiatePayment: reservationId => post('/payments/initiate', { reservationId }),
  payment: key => get('/payments/' + id(key)),
  confirmPayment: key => post('/payments/' + id(key) + '/confirm-mock'),
  dashboard: role => get('/dashboard/' + id(role)),
  users: () => get('/users'),
  user: key => get('/users/' + id(key)),
  userStatus: (key, status) => put('/users/' + id(key) + '/status', { status }),
  shops: status => get('/shops', { status }),
  shopReview: (key, decision) => put('/shops/' + id(key) + '/' + decision),
  adminOffers: filters => get('/admin/offers', filters),
  adminOffer: key => get('/admin/offers/' + id(key)),
  moderate: (key, data) => put('/admin/offers/' + id(key) + '/moderation', data),
}

const errors = {
  400: 'Vérifiez les informations saisies.',
  401: 'Identifiants invalides ou session expirée.',
  403: 'Votre compte ne peut pas effectuer cette action.',
  404: 'Cette ressource est introuvable.',
  409: 'La ressource a changé. Actualisez avant de continuer.',
}
export function errorMessage(error, writing = false) {
  const status = error.response?.status
  if (!status) {
    if (writing) return 'Résultat incertain. Actualisez les données et vérifiez le résultat avant de réessayer.'
    return 'Impossible de joindre le serveur. Vérifiez votre connexion puis réessayez.'
  }
  if (status >= 500) return writing
    ? 'Le serveur a rencontré une erreur. Vérifiez le résultat avant de réessayer.'
    : 'Le serveur a rencontré une erreur. Réessayez dans un instant.'
  const details = error.response?.data?.message
  return [errors[status], typeof details === 'string' && details].filter(Boolean).join(' ')
    || 'Cette action a échoué.'
}
