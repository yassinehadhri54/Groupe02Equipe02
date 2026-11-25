import { useCallback, useState } from 'react'
import { MapContainer, Marker, Popup, TileLayer, useMap } from 'react-leaflet'
import L from 'leaflet'
import marker from 'leaflet/dist/images/marker-icon.png'
import 'leaflet/dist/leaflet.css'
import { api } from '../services/api'
import { useResource } from '../hooks/useResource'
import { Card, Empty, Failure, Resource } from '../components/shared'
import { keyOf } from '../components/format'

const tunis = [36.8065, 10.1815]
const pin = L.icon({ iconUrl: marker, iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [0, -35] })

function SearchResults({ state, onShop }) {
  return <Resource state={state}>{({ data: shops = [] }) => shops.length ?
    <div className="cs-grid">{shops.map(shop => <Card key={keyOf(shop)}>
      <h3>{shop.name}</h3><p>{shop.address}</p>
      <p>{new Intl.NumberFormat('fr-FR').format(shop.distanceKm ?? shop.distanceMeters / 1000)} km · {shop.offersCount} offre(s)</p>
      <button onClick={() => onShop(keyOf(shop))}>Offres de {shop.name}</button>
    </Card>)}</div> : <Empty>Aucun commerce approuvé dans ce rayon.</Empty>}</Resource>
}
function SelectCenter({ onCenter }) {
  const map = useMap()
  return <button className="cs-map-center" type="button" onClick={() => {
    const point = map.getCenter()
    onCenter([point.lat, point.lng])
  }}>Rechercher au centre de la carte</button>
}
function RadarMap({ center, radius, onShop, onCenter }) {
  const load = useCallback(() => api.nearby({ lat: center[0], lng: center[1], radius }), [center, radius])
  const state = useResource(load)
  return <>
    <MapContainer className="cs-map" key={center.join(',')} center={center} zoom={13} scrollWheelZoom={false}>
      <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' />
      <SelectCenter onCenter={onCenter} />
      {state.data?.data?.filter(shop => Number.isFinite(shop.latitude) && Number.isFinite(shop.longitude)).map(shop =>
        <Marker key={keyOf(shop)} position={[shop.latitude, shop.longitude]} icon={pin} alt={shop.name}>
          <Popup><strong>{shop.name}</strong><br /><button onClick={() => onShop(keyOf(shop))}>Voir ses offres</button></Popup>
        </Marker>)}
    </MapContainer>
    <SearchResults state={state} onShop={onShop} />
  </>
}
export default function Radar({ onShop }) {
  const [center, setCenter] = useState(tunis)
  const [radius, setRadius] = useState(3)
  const [location, setLocation] = useState({ pending: false })
  function locate() {
    if (!navigator.geolocation) { setLocation({ error: 'La géolocalisation est indisponible. Utilisez la recherche manuelle.' }); return }
    setLocation({ pending: true })
    navigator.geolocation.getCurrentPosition(({ coords }) => {
      setCenter([coords.latitude, coords.longitude])
      setLocation({ pending: false })
    }, () => setLocation({ error: 'Position refusée ou indisponible. Déplacez la carte ou saisissez des coordonnées.' }), { timeout: 10000 })
  }
  return <section><h2>Campus Radar</h2>
    <div className="cs-actions">
      <button disabled={location.pending} onClick={locate}>{location.pending ? 'Localisation…' : 'Utiliser ma position'}</button>
      <label>Rayon<select value={radius} onChange={event => setRadius(Number(event.target.value))}>
        {[1, 3, 5, 10].map(km => <option key={km} value={km}>{km} km</option>)}
      </select></label>
    </div>
    <Failure message={location.error} />
    <form className="cs-filters" onSubmit={event => {
      event.preventDefault()
      const fields = new FormData(event.currentTarget)
      setCenter([Number(fields.get('lat')), Number(fields.get('lng'))])
    }}>
      <label>Latitude<input name="lat" type="number" step="any" min="-90" max="90" defaultValue={tunis[0]} required /></label>
      <label>Longitude<input name="lng" type="number" step="any" min="-180" max="180" defaultValue={tunis[1]} required /></label>
      <button>Rechercher ces coordonnées</button>
    </form>
    <RadarMap center={center} radius={radius} onShop={onShop} onCenter={setCenter} />
  </section>
}
