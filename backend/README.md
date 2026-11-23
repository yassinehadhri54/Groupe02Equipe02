# CampusSave — Backend (Node.js / Express / Firebase)

CampusSave met en relation les étudiants de l'ESSECT avec les restaurants et cafétérias proches pour réduire le gaspillage alimentaire. Les commerçants publient leurs invendus à prix réduit, les étudiants réservent, paient en ligne et récupèrent leur commande avec un QR code.

Ce backend est **l'API unique** utilisée par l'application **Web (React.js)** et l'application **Mobile (Flutter)**. Les deux clients partagent donc les mêmes données Firestore.

| Rôle | Peut… |
|---|---|
| **Étudiant** (`student`) | consulter et rechercher les offres, réserver, payer, obtenir un QR code, annuler, voir son dashboard |
| **Commerçant** (`merchant`) | inscrire sa boutique, publier, modifier et supprimer ses offres, confirmer ou refuser les réservations, scanner les QR codes, voir son dashboard |
| **Administrateur** (`admin`) | lister, suspendre et réactiver les utilisateurs, approuver ou rejeter les boutiques, voir les statistiques globales |

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
| `nodemailer` | Envoi du reçu de paiement par e-mail (SMTP) |

## 2. Structure

```
backend/
├── config/          firebase.js (SDK Admin), konnect.js (mode de paiement)
├── middlewares/     authMiddleware.js (vérifie le token Firebase), roleMiddleware.js (rôles)
├── routes/          une route par module (auth, users, shops, offers, reservations, payments, dashboard, notifications)
├── controllers/     validation des requêtes et codes HTTP
├── services/        logique métier et accès à Firestore ; konnect.js parle à Konnect ; emailService.js et receiptService.js envoient le reçu par e-mail
├── utils/           offerFields.js (formats d'offre), validation.js (URL, horaires)
├── tests/           tests automatiques hors ligne (npm test)
├── firestore.rules  règles de sécurité Firestore par rôle
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
3. **`KONNECT_MOCK=true`** pour développer (page de paiement simulée). Pour le vrai Konnect en mode test, mettez `KONNECT_MOCK=false` et ajoutez `KONNECT_API_KEY` et `KONNECT_WALLET_ID`, à récupérer sur dashboard.sandbox.konnect.network.

> ⚠️ Ne commitez jamais `.env` ni le fichier JSON du compte de service : ils sont exclus par `.gitignore`.

## 4. Lancement

```bash
npm run dev     # développement (nodemon, redémarre à chaque modification)
npm start       # production
npm test        # tests automatiques hors ligne (faux Firestore, faux Konnect, faux FCM)
```

Les tests n'ont besoin ni de clé Firebase, ni d'Internet, et n'écrivent rien dans la vraie base. Ils couvrent les paiements (page simulée, webhook, sandbox, panne de Konnect), les notifications et EcoPoints, les paniers surprise, la déconnexion, la suspension, les validations, et les accès concurrents (modification d'offre pendant une réservation, double inscription de boutique).

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
| POST | `/register` | public | `fullName (2 à 100 caractères), email, password (≥ 8), role ("student" ou "merchant")` |
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
| PUT | `/:id/status` | admin | `status` : `suspended` ou `active` |

**Suspension :** le compte Firebase est désactivé et ses sessions sont révoquées. L'utilisateur ne peut plus se connecter (403 « This account has been suspended. »), et ses tokens existants sont refusés. La boutique d'un commerçant suspendu passe aussi en `suspended` : ses offres disparaissent et ne peuvent plus être réservées. **La réactivation** restaure les statuts précédents. Un admin ne peut ni se suspendre lui-même ni suspendre un autre admin.

### Boutiques — `/api/shops`
| Méthode | Route | Accès | Body |
|---|---|---|---|
| POST | `/register` | commerçant | `name (2-100), address (2-200), phone (8 à 15 chiffres), email?, description? (≤ 1000), latitude?, longitude?` (statut initial `pending`, une seule boutique par commerçant) |
| GET | `/my-shop` | commerçant | — |
| PUT | `/my-shop` | commerçant | `name, address, phone, email, description, latitude, longitude` |
| GET | `/nearby?lat=&lng=&radius=&limit=&withOffers=` | public | **Campus Radar** : boutiques approuvées autour d'une position (voir ci-dessous) |
| GET | `/?status=pending` | admin | — |
| PUT | `/:id/approve` | admin | — (la boutique et le compte du commerçant sont mis à jour ensemble) |
| PUT | `/:id/reject` | admin | — |

### Offres — `/api/offers`
| Méthode | Route | Accès | Body / paramètres |
|---|---|---|---|
| GET | `/` | public | Recherche : `q`, `product`, `shop`, `category`, `shopId`, `maxPrice`, `type` (`standard` ou `surprise_basket`) |
| GET | `/surprise-baskets` | public | Paniers surprise uniquement (mêmes filtres) |
| GET | `/:id` | public | — |
| POST | `/` | commerçant avec boutique approuvée | `name, category, originalPrice, discountPrice, quantity, pickupStart, pickupEnd, description?, imageURL?, offerType?, basketItems?` |
| POST | `/surprise-baskets` | commerçant avec boutique approuvée | `originalPrice` (valeur estimée), `discountPrice`, `quantity, pickupStart, pickupEnd, basketItems?, name?, category?, description?, imageURL?` |
| GET | `/merchant/my-offers` | commerçant | — |
| PUT | `/:id` | commerçant propriétaire | champs à modifier |
| DELETE | `/:id` | commerçant propriétaire | — (suppression douce : l'offre passe à `deleted`, disparaît de la liste et ne peut plus être réservée ; ses réservations restent annulables) |

Règles de validation :

- `discountPrice` doit être inférieur à `originalPrice` ;
- `quantity` est un entier positif ;
- `pickupStart` et `pickupEnd` utilisent le format `HH:MM` ou `YYYY-MM-DDTHH:MM`, et le début doit être avant la fin ;
- `imageURL` est une URL http(s).

La recherche ignore les majuscules et les accents.

**Seules les offres réservables sont listées** :
- la boutique est approuvée ;
- l'offre est en statut `available` ou `active` ;
- elle n'est pas épuisée ;
- elle n'est **pas expirée**, c'est-à-dire que son `pickupEnd` daté (`YYYY-MM-DDTHH:MM`) n'est pas dépassé.

Les autres règles liées aux horaires :
- Une offre au format `HH:MM` correspond à un créneau quotidien sans date : elle n'expire pas.
- Le détail d'une offre indique `isExpired` et `isSoldOut`.
- Une offre expirée ne peut pas être réservée (400).
- Une offre ne peut pas être créée, ni déplacée, vers un horaire déjà passé.

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
| POST | `/init` (ou `/initiate`) | étudiant | `reservationId` → renvoie `payUrl`, la page de paiement (Konnect ou page simulée) |
| POST | `/:id/verify` | étudiant | — (interroge Konnect pour obtenir le vrai statut) |
| GET | `/mock-checkout/:ref` | public (navigateur) | — (mode simulé uniquement : la fausse page Konnect avec le bouton « Payer ») |
| POST | `/:id/confirm-mock` | étudiant | — (mode simulé uniquement : paiement direct sans la page, pour Postman) |
| POST | `/:id/cancel` | étudiant | — (mock : immédiat ; sandbox : seulement après l'expiration du lien) |
| POST | `/:id/receipt/retry` | étudiant propriétaire | — (renvoie le reçu par e-mail s'il a échoué ; un reçu déjà envoyé n'est jamais renvoyé) |
| GET | `/my-payments` | étudiant | — |
| GET | `/:id` | étudiant propriétaire | — |
| GET | `/webhook?payment_ref=…` | public (appelé par Konnect) | — (le statut est toujours revérifié auprès de Konnect) |

### Tableaux de bord — `/api/dashboard`
| Méthode | Route | Accès | Contenu |
|---|---|---|---|
| GET | `/student` | étudiant | réservations par statut, total payé, impact (produits sauvés, argent économisé), **EcoPoints**, dernières réservations |
| GET | `/merchant` | commerçant | boutique, offres (dont `byType`), réservations par statut, paniers surprise vendus, revenus payés, top offres |
| GET | `/admin` | admin | utilisateurs, boutiques, offres (dont `byType`), réservations, volume payé et **impact de la plateforme** (aucune donnée personnelle) |

**Bonus du cahier des charges :**
- **EcoPoints** : 10 points par produit récupéré, ajoutés quand le commerçant valide le QR code (une seule fois, dans la même transaction). Stockés dans `users/{uid}.ecoPoints` et dans `ecoPointsEarned` de la réservation.
- **Impact Dashboard** : produits sauvés, argent économisé, EcoPoints et paniers surprise récupérés, pour l'étudiant (`/student` → `impact`, `ecoPoints`) et pour toute la plateforme (`/admin` → `impact`).
- **Surprise Basket** : panier d'invendus dont le contenu exact est une surprise (voir ci-dessous).
- **Campus Radar** : localisation des restaurants et cafétérias à proximité (voir ci-dessous).

#### Bonus Campus Radar

Le commerçant renseigne la position de sa boutique (`latitude`, `longitude`, deux nombres à fournir ensemble : −90 à 90 et −180 à 180) à l'inscription ou dans `PUT /my-shop`. L'application mobile envoie la position GPS de l'étudiant à `GET /api/shops/nearby` (route publique, comme la liste des offres).

| Paramètre | Sens |
|---|---|
| `lat`, `lng` | **obligatoires** : position de l'étudiant |
| `radius` | rayon en km (2 par défaut, 50 au maximum) |
| `limit` | nombre maximum de boutiques (50 par défaut, 100 au maximum) |
| `withOffers=true` | garde seulement les boutiques qui ont une offre réservable |

La réponse liste les boutiques **approuvées avec une position** dans le rayon, de la plus proche à la plus éloignée : `shopId, name, address, phone, description, latitude, longitude, distanceMeters, distanceKm, offersCount, surpriseBasketsCount`. `offersCount` ne compte que les offres réservables maintenant (ni expirées, ni épuisées, ni supprimées). Aucune donnée privée du commerçant n'est renvoyée. Pour afficher les offres d'une boutique : `GET /api/offers?shopId=<shopId>`.

> Les boutiques créées avant ce bonus n'ont pas de position : elles n'apparaissent sur le radar qu'après un `PUT /api/shops/my-shop` avec `latitude` et `longitude`.

#### Bonus Surprise Basket

Un panier surprise est une **offre de type `surprise_basket`**. Il passe par le même parcours qu'une offre normale : réservation, paiement Konnect, confirmation, QR code, EcoPoints et notifications.

| Champ | Sens pour un panier |
|---|---|
| `offerType` | `"surprise_basket"` (fixé à la création, non modifiable) ; les autres offres sont `"standard"` |
| `originalPrice` | valeur estimée du panier |
| `discountPrice` | prix payé par l'étudiant : **au plus 50 % de la valeur estimée** |
| `basketItems` | facultatif : ce que le panier peut contenir (10 éléments max., 1 à 60 caractères chacun) |
| `name`, `category` | facultatifs : « Panier surprise » par défaut |

- `POST /api/offers/surprise-baskets` crée un panier ; `POST /api/offers` avec `"offerType": "surprise_basket"` fait la même chose.
- `GET /api/offers/surprise-baskets` ou `GET /api/offers?type=surprise_basket` liste les paniers ; `?type=standard` les exclut.
- La recherche `q` lit aussi le contenu du panier.
- La réservation garde `offerType`. Les dashboards comptent les paniers : `impact.surpriseBasketsRescued` (étudiant et admin), `surpriseBasketsSold` (commerçant) et `offers.byType`.

Exemple :

```json
POST /api/offers/surprise-baskets
{
  "originalPrice": 15,
  "discountPrice": 5,
  "quantity": 3,
  "pickupStart": "18:00",
  "pickupEnd": "20:00",
  "basketItems": ["viennoiseries", "sandwich", "dessert du jour"]
}
```

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
  → Commerçant scanne le QR ......... status: completed  (QR à usage unique, +10 EcoPoints par produit)

Autres issues : l'étudiant annule ou le commerçant refuse (seulement si la réservation n'est pas payée)
→ status: cancelled / rejected, et le stock est restitué.
```

## 8. Paiement

Le code : `services/konnect.js` parle à Konnect (création du lien, lecture du statut) ; `routes/paymentRoutes.js` déclare `/init`, `/webhook` et la page de paiement simulée.

| Mode | Réglage dans `.env` | Fonctionnement |
|---|---|---|
| Simulé | `KONNECT_MOCK=true` | Le backend affiche une **fausse page de paiement** avec un bouton « Payer ». Pas de compte Konnect ni d'Internet. |
| Konnect sandbox | `KONNECT_MOCK=false` + clés | La vraie page Konnect, en mode test. |

Parcours d'un paiement (identique dans les deux modes) :

1. L'étudiant réserve → `status: pending`, `paymentStatus: unpaid` (en attente de paiement).
2. Il clique sur « Payer » → l'app appelle `POST /api/payments/init` avec `reservationId`.
3. Le backend demande un paiement à Konnect : montant en millimes (6,500 DT → 6500), numéro de paiement (`orderId`) et adresse du webhook.
4. Konnect répond avec `payUrl` → l'app ouvre cette page et l'étudiant paie.
5. Konnect appelle le webhook `GET /api/payments/webhook?payment_ref=…`.
6. Le backend redemande le statut à Konnect : seul `completed`, avec le bon montant et la devise TND, est accepté. Le navigateur et l'appel du webhook ne sont jamais crus sur parole.
7. Payé → `paymentStatus: paid`, l'étudiant et le commerçant reçoivent une notification, le **reçu est envoyé par e-mail** à l'étudiant (voir « Reçu par e-mail »), et le QR code devient disponible (`GET /api/reservations/:id/qr`).

- **Mode simulé** : la page `payUrl` est servie par le backend (`/api/payments/mock-checkout/<référence aléatoire>`). « Payer » joue le rôle de Konnect : il marque le paiement comme réussi côté « Konnect », puis appelle le vrai webhook. Depuis un téléphone, mettez l'IP du PC dans `PUBLIC_BASE_URL` (ex. `http://192.168.1.10:5000`). `confirm-mock` reste disponible pour Postman.
- **Konnect sandbox** : Konnect ne peut pas joindre `localhost`. Sans `KONNECT_WEBHOOK_URL` public, l'app appelle `POST /:id/verify` au retour de la page de paiement.
- Le montant est toujours calculé par le serveur. Un statut de paiement envoyé par le client n'est jamais pris en compte.

### Reçu par e-mail

Après un paiement **confirmé par Konnect** (webhook ou `/verify`, jamais sur la foi de la page de retour du navigateur), l'étudiant reçoit un e-mail HTML « CampusSave – Payment Confirmation & Electronic Receipt » : nom, numéro de réservation, boutique, offre, quantité, prix unitaire, total payé, statut *Confirmed* et date. Aucun numéro de carte, jeton, référence Konnect ni identifiant SMTP n'y figure.

**Configuration** : renseignez dans `.env` (modèle dans `.env.example`) `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` et `EMAIL_FROM`. Avec Gmail : `smtp.gmail.com`, port `587`, et un *mot de passe d'application* comme `SMTP_PASS`. Pour tester sans vrai serveur, utilisez par exemple [Mailtrap](https://mailtrap.io) (SMTP de test) ou `npx maildev`. Sans ces variables, le serveur démarre et les paiements fonctionnent : le reçu est simplement marqué `failed`.

**Suivi** (sur le document `payments`, pas de nouvelle collection) :

| Champ | Sens |
|---|---|
| `receiptEmailStatus` | `pending` (dû, écrit dans la même transaction que `paid`) → `sending` (envoi en cours) → `sent` ou `failed` |
| `receiptSentAt` | date d'envoi |
| `receiptEmailError` | cause courte et sûre en cas d'échec (jamais l'erreur SMTP brute) |
| `receiptEmailAttempts` | nombre de tentatives (5 maximum pour les renvois manuels) |

**Garanties** :
- Un seul e-mail par paiement : l'envoi « réserve » le paiement dans une transaction (`sending`). Deux webhooks simultanés, ou webhook + `/verify`, n'envoient qu'un e-mail.
- Si l'e-mail échoue (SMTP en panne, adresse absente…), le paiement et la réservation restent `paid`. L'étudiant peut redemander le reçu avec `POST /api/payments/:id/receipt/retry`.
- Le reçu n'est jamais envoyé pour un paiement `pending`, `failed`, `cancelled` ou `expired`.

## 9. Sécurité

- Le token Firebase est vérifié sur chaque route protégée, y compris la révocation après un logout.
- Les rôles sont lus dans Firestore, et la propriété des ressources est vérifiée (boutique, offre, réservation, paiement, notification).
- Les prix, montants et stocks sont gérés côté serveur. Les opérations critiques passent par des **transactions Firestore** : réservation, annulation, paiement, QR, approbation de boutique.
- Le QR code contient un token aléatoire de 32 octets. Seul son hash SHA-256 est stocké, et il est à usage unique.
- Les secrets restent hors du dépôt (`.env`, clé du compte de service). Les tokens FCM ne sont jamais renvoyés par l'API.

## 10. Limites connues

- Les offres créées par un autre client utilisent d'autres noms de champs (`title`, `discountedPrice`, `imageUrl`, `merchantId`, statut `active`). Le backend accepte les deux formats (voir `utils/offerFields.js`), mais l'équipe devrait n'en garder qu'un.
- **Règles Firestore** : `firestore.rules` contient maintenant des règles par rôle (lecture selon le rôle et la propriété, aucune écriture directe des clients : tout passe par l'API). Elles ne sont actives qu'après `firebase deploy --only firestore:rules`. Avant de les déployer, vérifiez qu'aucun client (React, Flutter) n'écrit encore directement dans Firestore, sinon ses écritures seront refusées.
- Konnect sandbox : le webhook a besoin d'une URL publique. En local, utilisez `/verify`.
- Reçu par e-mail : l'adresse utilisée est celle saisie à l'inscription (non vérifiée par Firebase). Il n'y a pas de renvoi automatique en arrière-plan : un reçu `failed` est renvoyé à la demande de l'étudiant.
- La photo d'une offre est une URL : il n'y a pas d'upload de fichier.
