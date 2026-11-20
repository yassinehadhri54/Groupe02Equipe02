# Tests Postman — CampusSave API

- `collections/CampusSave-API.postman_collection.json` : 116 requêtes réparties en 12 dossiers, chacune avec ses tests automatiques.
- `environments/CampusSave-local.postman_environment.json` : variables, **sans aucun mot de passe ni token**.

## 1. Importer

1. Dans Postman : **Import**, puis glissez les deux fichiers JSON.
2. En haut à droite, sélectionnez l'environnement **« CampusSave - local »**.
3. Lancez le backend (`npm run dev` dans `backend/`) avec **`PAYMENT_MODE=mock`**.

## 2. Remplir les comptes de test

Dans l'environnement, remplissez la colonne **Current value**. Elle reste sur votre PC et n'est jamais exportée.

| Variable | Compte |
|---|---|
| `studentEmail` / `studentPassword` | un étudiant de test |
| `student2Email` / `student2Password` | un **autre** étudiant (tests de propriété, puis logout) |
| `merchantEmail` / `merchantPassword` | le commerçant **propriétaire de l'offre `offerId`** (boutique approuvée) |
| `merchant2Email` / `merchant2Password` | un **autre** commerçant |
| `adminEmail` / `adminPassword` | l'administrateur |
| `offerId` | une offre du commerçant ci-dessus, avec au moins 2 unités en stock (par défaut `TqeoTGH3imTHIVSekMVd`) |

> ⚠️ N'exportez pas l'environnement après l'avoir rempli, et ne commitez jamais de mot de passe.

## 3. Lancer

Utilisez le **Collection Runner** (clic droit sur la collection → *Run*), dans l'ordre des dossiers :

| Dossier | Ce qu'il fait | Modifie des données ? |
|---|---|---|
| 00 Santé | serveur et Firebase | non |
| 01 Auth | connecte les 5 comptes et enregistre les tokens | non |
| 02 Utilisateurs | profil, rôles, 403 / 404 | ⚠️ change le nom et le téléphone de l'étudiant de test |
| 03 Boutiques | lecture, 403 / 404 / 409 | non |
| 04 Offres | liste, recherche, filtres, validations, propriété (2ᵉ commerçant → 403) | non |
| 05 Annulation | réservation → annulation → stock restitué | ⚠️ crée une réservation (annulée) |
| 06 Paiement / QR | réservation → paiement mock (annulé puis refait) → confirmation → QR → retrait | ⚠️ consomme **1 unité** de l'offre |
| 07 Refus | réservation → refus du commerçant → stock restitué | ⚠️ crée une réservation (refusée) |
| 08 Dashboards | 3 dashboards + 403 entre rôles | non |
| 09 Notifications | notifications créées par 05 à 07, lecture, token FCM de test | ⚠️ marque une notification comme lue |
| 10 Admin : suspension | suspend puis réactive l'étudiant 2 et l'autre commerçant (dont sa boutique), refus 400 / 403 / 404 / 409 | ⚠️ les deux comptes sont **temporairement suspendus** puis réactivés, et doivent se reconnecter |
| 11 Logout | logout de l'étudiant 2, puis l'ancien token → 401 | ⚠️ déconnecte l'étudiant 2 sur tous ses appareils |

Les tokens Firebase expirent après **1 heure**. Si vous obtenez des 401 inattendus, relancez le dossier **01**.

## 4. Lire les résultats

Chaque requête vérifie le code HTTP et le contenu de la réponse : prix réduit appliqué, stock diminué puis restitué, statuts, absence de données sensibles… Une ligne rouge dans le Runner indique la requête et le test qui a échoué.
