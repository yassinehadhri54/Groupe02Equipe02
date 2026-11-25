# CampusSave Web

Interface React pour les étudiants, les commerçants et les administrateurs. Les données et les autorisations proviennent de l’API CampusSave.

## Démarrage local

Avec Node.js 22 compatible Vite 8, lancer depuis ce dossier :

```powershell
npm ci
npm run dev -- --port 5173 --strictPort
```

Ouvrir http://localhost:5173. Par défaut, l’API est http://localhost:5000. Pour une autre URL, définir `VITE_API_URL` dans `.env.local`, puis redémarrer Vite. Le backend doit autoriser l’origine du frontend dans sa configuration CORS. Les variables `VITE_*` sont publiques une fois compilées.

Le paiement web nécessite que `GET /api/payments/config` retourne `mode: "mock"`. Le scanner de retrait requiert un contexte sécurisé et une caméra autorisée. La saisie manuelle du code est disponible dans le même écran. Campus Radar permet de rechercher au centre de la carte ou par latitude et longitude.

## Vérifications

```powershell
npm run lint
npm test
npm run build
```

Les tests Vitest simulent l’API. Ils peuvent être exécutés sans compte CampusSave ni accès à Firebase.
