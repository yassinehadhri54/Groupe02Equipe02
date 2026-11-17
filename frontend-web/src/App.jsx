
import { useState } from 'react'
import './App.css'

function App() {
  const [activeCategory, setActiveCategory] = useState('Tous')
  const [selectedOffer, setSelectedOffer] = useState(null)
  const [quantity, setQuantity] = useState(1)
  const [reservationSuccess, setReservationSuccess] = useState(false)
  const [reservations, setReservations] = useState([])

  // Liste des offres alimentaires
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

  // Filtrer les offres
  const filteredOffers = offers.filter((offer) => {
    return activeCategory === 'Tous' ||
      offer.category === activeCategory
  })

  // Calculer le prix total
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

  // Confirmer et enregistrer une réservation
  const handleReservation = () => {
    if (!selectedOffer || quantity < 1 || quantity > selectedOffer.portions) {
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

    setReservations((previous) => [
      newReservation,
      ...previous
    ])

    setSelectedOffer(null)
    setReservationSuccess(true)
  }

  // Annuler une réservation
  const handleCancelReservation = (reservationId) => {
    const confirmCancel = window.confirm(
      'Voulez-vous vraiment annuler cette réservation ?'
    )

    if (!confirmCancel) return

    setReservations((previousReservations) =>
      previousReservations.map((reservation) =>
        reservation.id === reservationId
          ? { ...reservation, status: 'Annulée' }
          : reservation
      )
    )
  }

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
          <a href="#reservations">Mes réservations</a>
          <a href="#comment">Comment ça marche</a>
        </nav>

        <div className="nav-buttons">
          <button className="login-btn">Connexion</button>
          <button className="signup-btn">Inscription</button>
        </div>
      </header>

      {/* Hero Section */}
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
              onClick={() => {
                document.getElementById('offres')?.scrollIntoView({
                  behavior: 'smooth'
                })
              }}
            >
              Découvrir les offres →
            </button>

            <button
              className="secondary-btn"
              onClick={() => {
                document.getElementById('reservations')?.scrollIntoView({
                  behavior: 'smooth'
                })
              }}
            >
              Mes réservations
            </button>
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

      {/* Offers Section */}
      <section className="offers" id="offres">

        <div className="section-heading">
          <span>LES BONNES AFFAIRES</span>
          <h2>Les offres du moment</h2>
          <p>
            Des repas de qualité à petits prix,
            disponibles près de vous.
          </p>
        </div>

        {/* Category Filters */}
        <div className="category-filters">
          {['Tous', 'Sandwichs', 'Pizzas', 'Salades'].map((category) => (
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

        {/* Number of results */}
        <p className="offers-count">
          <strong>{filteredOffers.length}</strong>{' '}
          {filteredOffers.length > 1
            ? 'offres disponibles'
            : 'offre disponible'}
        </p>

        {/* Food Cards */}
        <div className="offers-container">

          {filteredOffers.length > 0 ? (
            filteredOffers.map((offer) => (
              <div className="offer-card" key={offer.id}>

                <div className="food-image">
                  <img
                    src={offer.image}
                    alt={offer.name}
                  />

                  <span className="discount">
                    {offer.discount}
                  </span>
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

                  {/* Disponibilité */}
                  <div className="portions-info">
                    <div className="portions-text">
                      <span>📦 Disponibilité</span>
                      <strong>{offer.portions} portions</strong>
                    </div>

                    <div className="portions-bar">
                      <div
                        className="portions-progress"
                        style={{
                          width: `${Math.min(
                            offer.portions / 10 * 100,
                            100
                          )}%`
                        }}
                      ></div>
                    </div>
                  </div>

                  {/* Horaires de retrait */}
                  <div className="pickup-info">
                    <span>🕒 Heure de retrait</span>
                    <strong>{offer.pickup}</strong>
                  </div>

                  <button
                    onClick={() => {
                      setSelectedOffer(offer)
                      setQuantity(1)
                    }}
                  >
                    Réserver maintenant
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

      {/* Reservation History */}
      <section className="reservations-section" id="reservations">

        <div className="section-heading">
          <span>VOTRE ESPACE</span>
          <h2>Mes réservations</h2>
          <p>
            Retrouvez toutes vos réservations effectuées sur CampusSave.
          </p>
        </div>

        {reservations.length > 0 ? (
          <div className="reservations-list">

            {reservations.map((reservation) => (
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
                    {reservation.status === 'Annulée' ? '✕' : '✓'}
                    {' '}
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
                    onClick={() => handleCancelReservation(reservation.id)}
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
            <p>
              Vos prochaines réservations apparaîtront ici.
            </p>

            <button
              onClick={() => {
                document.getElementById('offres')?.scrollIntoView({
                  behavior: 'smooth'
                })
              }}
            >
              Découvrir les offres
            </button>
          </div>
        )}

      </section>

      {/* Reservation Modal */}
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
                  onClick={() => setQuantity(
                    Math.min(selectedOffer.portions, quantity + 1)
                  )}
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

      {/* Reservation Success Message */}
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
                document.getElementById('reservations')?.scrollIntoView({
                  behavior: 'smooth'
                })
              }}
            >
              Voir mes réservations
            </button>

          </div>
        </div>
      )}

      {/* Footer */}
      <footer className="footer" id="comment">
        <h2>CampusSave</h2>

        <p>
          Ensemble, réduisons le gaspillage alimentaire.
        </p>

        <small>
          © 2026 CampusSave. Tous droits réservés.
        </small>
      </footer>

    </div>
  )
}

export default App
