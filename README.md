# CampusSave

CampusSave permet aux commerces de proposer leurs invendus aux étudiants. Le site React et l’application Flutter utilisent la même API Express. Les retraits validés créditent les EcoPoints.

| Dossier | Contenu |
| --- | --- |
| `backend/` | Express, Firebase Admin SDK, authentification, réservations, paiements et tableaux de bord |
| `frontend-web/` | React, Vite, Leaflet et tests Vitest |
| `frontend-mobile/` | Flutter et tests Dart |
| `postman/` | Collections pour les contrôles API |

## Lancer le projet

Installer Node.js et npm compatibles avec les dépendances verrouillées, Flutter, le SDK Android, un JDK compatible Gradle et un émulateur Android.

1. Dans `backend`, lancer `npm ci`. Copier `.env.example` vers `.env` et renseigner les valeurs locales. Utiliser les Application Default Credentials du projet Firebase QA autorisé. Renseigner `GOOGLE_CLOUD_PROJECT` si nécessaire et `FIREBASE_WEB_API_KEY` pour la connexion. Conserver tout fichier de clé hors du dépôt. Garder `PAYMENT_MODE=mock`. Lancer `npm start` sur `http://localhost:5000`. Tester `GET /api/health` et `GET /api/firebase-test`.
2. Dans `frontend-web`, lancer `npm ci` puis `npm run dev -- --port 5173 --strictPort`. Le site est accessible sur `http://localhost:5173`. L’API par défaut est `http://localhost:5000`. Utiliser `VITE_API_URL` dans `.env.local` si nécessaire. Les variables `VITE_*` sont publiques dans le bundle.
3. Dans `frontend-mobile`, lancer `flutter pub get` puis `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:5000`. Sur Windows, si les liens symboliques des plugins de bureau bloquent la préparation Android, exécuter `$env:FLUTTER_WINDOWS = 'false'` dans cette session PowerShell avant `flutter pub get`. Ce réglage concerne le processus courant.

L’API accepte les origines cross-origin et vérifie les jetons et les permissions côté serveur. Les règles Firestore versionnées refusent l’accès direct depuis les clients. Firebase Admin accède aux données avec les identifiants du serveur.

## Tester

- Backend avec `npm test`.
- React avec `npm run lint`, `npm run build` et `npm test`. Exécuter les tests React isolément si la machine est saturée.
- Flutter avec `flutter analyze`, `flutter test` et `flutter build apk --debug`.

## Parcours

L’étudiant consulte le catalogue, réserve, paie en mode Mock et présente son QR de retrait. Le commerçant gère son commerce et ses offres, confirme les réservations et valide les retraits. L’administrateur gère les comptes, approuve les commerces et modère les offres de façon réversible. Les deux applications conservent la préférence de thème.

Campus Radar affiche les commerces approuvés à proximité. Surprise Basket ajoute les paniers et leurs informations alimentaires. EcoPoints attribue 10 points par portion retirée. Impact Dashboard présente les retraits, les portions et leur évolution.

## Limites

Les économies proviennent du prix initial enregistré sur la réservation. Sans ce prix, le retrait reste compté et les économies sont signalées comme indisponibles ou partielles. Les lectures d’agrégats Firestore peuvent être lentes. Vérifier le résultat d’une écriture qui a dépassé son délai avant de la relancer. Le scan web nécessite une caméra autorisée dans un contexte sécurisé. La validation croisée réelle nécessite des comptes QA et une autorisation d’écriture distincte.
