
import { useState } from 'react'
import './App.css'

function App() {
  const [activeCategory, setActiveCategory] = useState('Tous')

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

            <button className="secondary-btn">
              En savoir plus
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
          {filteredOffers.length > 1 ? 'offres disponibles' : 'offre disponible'}
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

                  <p>📍 {offer.location}</p>

                  <div className="offer-details">
                    <strong>{offer.price}</strong>
                    <del>{offer.oldPrice}</del>
                  </div>

                  <p>
                    📦 {offer.portions} portions disponibles
                  </p>

                  <p>
                    🕒 Retrait : {offer.pickup}
                  </p>

                  <button>
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
