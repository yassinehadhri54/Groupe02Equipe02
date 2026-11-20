# CampusSave — Backend (Node.js / Express / Firebase)

CampusSave met en relation les étudiants de l'ESSECT avec les restaurants et cafétérias proches pour réduire le gaspillage alimentaire. Les commerçants publient leurs invendus à prix réduit, les étudiants réservent, paient en ligne et récupèrent leur commande avec un QR code.

Ce backend est **l'API unique** utilisée par l'application **Web (React.js)** et l'application **Mobile (Flutter)**. Les deux clients partagent donc les mêmes données Firestore.

| Rôle | Peut… |
|---|---|
| **Étudiant** (`student`) | consulter et rechercher les offres, réserver, payer, obtenir un QR code, annuler, voir son dashboard |
| **Commerçant** (`merchant`) | inscrire sa boutique, publier, modifier et supprimer ses offres, confirmer ou refuser les réservations, scanner les QR codes, voir son dashboard |
| **Administrateur** (`admin`) | lister les utilisateurs, approuver ou rejeter les boutiques, voir les statistiques globales |

---

## 1. Technologies

| Technologie | Utilisation |
|---|---|
| Node.js + Express 5 | API REST |
| Firebase Authentication | Comptes et jetons d'identité (ID tokens) |
| Firebase Firestore | Base de données (SDK Admin) |
| Firebase Cloud Messaging | Notifications push |
| Konnect (mode test) | Paiement électronique, avec un mode `mock` pour le développement |
| `qrcode` | Génération des QR codes |
| `axios` | Appels à Konnect et à Firebase Auth REST |

## 2. Structure

```
backend/
├── config/          firebase.js (SDK Admin), konnect.js (mode de paiement)
├── middlewares/     authMiddleware.js (vérifie le token Firebase), roleMiddleware.js (rôles)
├── routes/          une route par module (auth, users, shops, offers, reservations, payments, dashboard, notifications)
├── controllers/     validation des requêtes et codes HTTP
├── services/        logique métier et accès à Firestore
├── utils/           offerFields.js (formats d'offre), validation.js (URL, horaires)
├── server.js        point d'entrée
└── .env.example     variables d'environnement à copier dans .env
```

## 3. Installation

**Prérequis :** Node.js 18 ou plus, et un accès au projet Firebase `compussave-57447`.

```bash
cd backend
npm install
cp .env.example .env        # sous Windows : copy .env.example .env
```

Ensuite, remplissez `.env` :

1. **Clé du compte de service Firebase.** Dans la console Firebase : *Paramètres du projet → Comptes de service → Générer une nouvelle clé privée*. Placez le fichier JSON **en dehors du projet** et indiquez son chemin absolu dans `GOOGLE_APPLICATION_CREDENTIALS`.
2. **`FIREBASE_WEB_API_KEY`** : *Paramètres du projet → Général → Clé API Web*.
3. **`PAYMENT_MODE=mock`** pour développer. Pour Konnect, mettez `sandbox` et ajoutez `KONNECT_API_KEY` et `KONNECT_WALLET_ID`, à récupérer sur dashboard.sandbox.konnect.network.

> ⚠️ Ne commitez jamais `.env` ni le fichier JSON du compte de service : ils sont exclus par `.gitignore`.

## 4. Lancement

```bash
npm run dev     # développement (nodemon, redémarre à chaque modification)
npm start       # production
```

Vérification :

- `GET http://localhost:5000/api/health` → `CampusSave Backend is running`
- `GET http://localhost:5000/api/firebase-test` → `Firebase connected successfully!`

## 5. Authentification

1. `POST /api/auth/login` renvoie `tokens.idToken`.
2. Envoyez ce token dans chaque requête protégée : `Authorization: Bearer <idToken>`.
3. Le rôle et le statut viennent toujours de Firestore. Ce que le client envoie n'est jamais utilisé.

Pour une route protégée :

- **401** : token absent, invalide, expiré ou révoqué (après un logout) ;
- **403** : le rôle n'a pas accès à cette route.

## 6. Routes de l'API

Base : `http://localhost:5000/api`

### Authentification — `/api/auth`
| Méthode | Route | Accès | Body |
|---|---|---|---|
| POST | `/register` | public | `fullName, email, password (≥ 8), role ("student" ou "merchant")` |
| POST | `/login` | public | `email, password` |
| GET | `/me` | connecté | — |
| POST | `/logout` | connecté | `fcmToken` (optionnel) : révoque les sessions **sur tous les appareils** |

### Utilisateurs — `/api/users`
| Méthode | Route | Accès | Body |
|---|---|---|---|
| GET | `/profile` | connecté | — |
| PUT | `/profile` | connecté | `fullName`, `phone`, `photoURL` (le rôle, le statut et l'email ne sont pas modifiables) |
| GET | `/` | admin | — |
| GET | `/:id` | admin | — |

### Boutiques — `/api/shops`
| Méthode | Route | Accès | Body |
|---|---|---|---|
| POST | `/register` | commerçant | `name, address, phone, email?, description?` (statut initial `pending`) |
| GET | `/my-shop` | commerçant | — |
| PUT | `/my-shop` | commerçant | `name, address, phone, email, description` |
| GET | `/?status=pending` | admin | — |
| PUT | `/:id/approve` | admin | — (la boutique et le compte du commerçant sont mis à jour ensemble) |
| PUT | `/:id/reject` | admin | — |

### Offres — `/api/offers`
| Méthode | Route | Accès | Body / paramètres |
|---|---|---|---|
| GET | `/` | public | Recherche : `q`, `product`, `shop`, `category`, `shopId`, `maxPrice` |
| GET | `/:id` | public | — |
| POST | `/` | commerçant avec boutique approuvée | `name, category, originalPrice, discountPrice, quantity, pickupStart, pickupEnd, description?, imageURL?` |
| GET | `/merchant/my-offers` | commerçant | — |
| PUT | `/:id` | commerçant propriétaire | champs à modifier |
| DELETE | `/:id` | commerçant propriétaire | — |

Règles de validation :

- `discountPrice` doit être inférieur à `originalPrice` ;
- `quantity` est un entier positif ;
- `pickupStart` et `pickupEnd` utilisent le format `HH:MM` ou `YYYY-MM-DDTHH:MM`, et le début doit être avant la fin ;
- `imageURL` est une URL http(s).

La recherche ignore les majuscules et les accents. Seules les offres des boutiques approuvées sont listées.

### Réservations — `/api/reservations`
| Méthode | Route | Accès | Body |
|---|---|---|---|
| POST | `/` | étudiant | `offerId, quantity` (prix calculé par le serveur, stock réservé dans une transaction) |
| GET | `/my-reservations` | étudiant | — |
| PUT | `/:id/cancel` | étudiant propriétaire | — (seulement si la réservation est `pending` et non payée ; le stock est restitué) |
| GET | `/:id/qr` | étudiant propriétaire | — (seulement après paiement ; renvoie l'image du QR code) |
| GET | `/merchant` | commerçant | — |
| PUT | `/:id/status` | commerçant de la boutique | `status` : `confirmed` (si payée) ou `rejected` (si non payée) |
| POST | `/verify-qr` | commerçant de la boutique | `token` (contenu du QR code) : passe la réservation à `completed` |

### Paiements — `/api/payments`
| Méthode | Route | Accès | Body |
|---|---|---|---|
| POST | `/initiate` | étudiant | `reservationId` (en sandbox, renvoie `payUrl`, la page de paiement Konnect) |
| POST | `/:id/verify` | étudiant | — (sandbox : interroge Konnect pour obtenir le vrai statut) |
| POST | `/:id/confirm-mock` | étudiant | — (mode `mock` uniquement) |
| POST | `/:id/cancel` | étudiant | — (mock : immédiat ; sandbox : seulement après l'expiration du lien) |
| GET | `/my-payments` | étudiant | — |
| GET | `/:id` | étudiant propriétaire | — |
| GET | `/webhook?payment_ref=…` | public (appelé par Konnect) | — (le statut est toujours revérifié auprès de Konnect) |

### Tableaux de bord — `/api/dashboard`
| Méthode | Route | Accès | Contenu |
|---|---|---|---|
| GET | `/student` | étudiant | réservations par statut, total payé, produits sauvés, argent économisé, dernières réservations |
| GET | `/merchant` | commerçant | boutique, offres, réservations par statut, revenus payés, top offres |
| GET | `/admin` | admin | utilisateurs, boutiques, offres, réservations et volume payé (aucune donnée personnelle) |

### Notifications — `/api/notifications`
| Méthode | Route | Accès | Body |
|---|---|---|---|
| POST | `/token` | connecté | `token` : token FCM de l'appareil (à envoyer après le login) |
| DELETE | `/token` | connecté | `token` |
| GET | `/` | connecté | — (50 dernières notifications) |
| PUT | `/:id/read` | destinataire | — |

Notifications envoyées automatiquement : nouvelle réservation et annulation (au commerçant), confirmation, refus et retrait (à l'étudiant), paiement confirmé (aux deux).

## 7. Cycle de vie d'une réservation

```
Offre disponible
  → Étudiant réserve ................ status: pending,   paymentStatus: unpaid   (stock réservé)
  → Étudiant initie le paiement ..... paymentStatus: pending
      → paiement abandonné/expiré ... paymentStatus: unpaid/failed → peut repayer ou annuler
  → Paiement confirmé ............... paymentStatus: paid
  → Commerçant confirme ............. status: confirmed
  → Étudiant affiche son QR code
  → Commerçant scanne le QR ......... status: completed  (QR à usage unique)

Autres issues : l'étudiant annule ou le commerçant refuse (seulement si la réservation n'est pas payée)
→ status: cancelled / rejected, et le stock est restitué.
```

## 8. Paiement

- **`PAYMENT_MODE=mock`** : aucun appel externe. `confirm-mock` simule un paiement réussi. Réservé au développement et aux démonstrations.
- **`PAYMENT_MODE=sandbox`** : mode test de Konnect. `initiate` crée le paiement chez Konnect et renvoie `payUrl`. La réservation n'est marquée `paid` que lorsque **Konnect lui-même** répond `completed`, avec le bon montant (en millimes) et la devise TND. Ce contrôle passe par `/verify` ou par le webhook.
- Le montant est toujours calculé par le serveur. Un statut de paiement envoyé par le client n'est jamais pris en compte.

## 9. Sécurité

- Le token Firebase est vérifié sur chaque route protégée, y compris la révocation après un logout.
- Les rôles sont lus dans Firestore, et la propriété des ressources est vérifiée (boutique, offre, réservation, paiement, notification).
- Les prix, montants et stocks sont gérés côté serveur. Les opérations critiques passent par des **transactions Firestore** : réservation, annulation, paiement, QR, approbation de boutique.
- Le QR code contient un token aléatoire de 32 octets. Seul son hash SHA-256 est stocké, et il est à usage unique.
- Les secrets restent hors du dépôt (`.env`, clé du compte de service). Les tokens FCM ne sont jamais renvoyés par l'API.

## 10. Limites connues

- Les offres créées par un autre client utilisent d'autres noms de champs (`title`, `discountedPrice`, `imageUrl`, `merchantId`, statut `active`). Le backend accepte les deux formats (voir `utils/offerFields.js`), mais l'équipe devrait n'en garder qu'un.
- Le fichier `firestore.rules` autorise encore tous les accès clients jusqu'au 16/12/2026. Si React et Flutter passent uniquement par cette API, il faut le verrouiller.
- Le webhook Konnect a besoin d'une URL publique. En local, utilisez `/verify`.
- La photo d'une offre est une URL : il n'y a pas d'upload de fichier.
