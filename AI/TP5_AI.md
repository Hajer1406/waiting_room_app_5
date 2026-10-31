# 🤖 Utilisation de l'Intelligence Artificielle — TP5

Ce document décrit comment l'intelligence artificielle a été utilisée comme assistant de développement au cours du **Workshop 5 : Building Offline-First Queue App with Geolocation** sur l'application **Waiting Room**.

---

## 1. Informations sur l'Agent et l'Environnement

| Champ | Valeur |
| :--- | :--- |
| **Agent IA** | Antigravity (Google DeepMind) |
| **Modèles utilisés** | Claude Sonnet 4.6 (Thinking) & Gemini 3.8 Flash |
| **Environnement / IDE** | Antigravity IDE (Architecture VS Code) sur Windows 11 |
| **Projet** | `waiting_room_app` (Flutter 3.x / Dart) |
| **Date de réalisation** | 31 octobre 2026 |

---

## 2. Objectifs du Workshop 5

Le TP5 vise à transformer l'application de salle d'attente connectée en une application **résiliente aux pannes réseau (Offline-First)** tout en enrichissant le contexte métier par la **géolocalisation** des clients :

1. **Persistance locale avec SQLite** : Enregistrer immédiatement les clients dans une base de données embarquée (`sqflite`).
2. **Synchronisation distante (Supabase)** : Gérer un statut de synchronisation (`is_synced`) et pousser les données vers Supabase en arrière-plan sans bloquer l'interface.
3. **Capture de la géolocalisation** : Intégrer `geolocator` pour récupérer la latitude et la longitude lors de l'enregistrement d'un client.
4. **Clean Architecture & TDD (Test-Driven Development)** : Concevoir des services injectables et découplés, accompagnés de tests unitaires et de mocks.
5. **Gestion multiplateforme** : Assurer la robustesse de l'application sur Mobile (Android), Desktop (Windows) et Web (Chrome).

---

## 3. Résumé Chronologique des Discussions et Échanges avec Antigravity

Cette section retrace l'intégralité des échanges interactifs, des diagnostics de bugs, des partages de captures d'écran et des solutions apportées en pair-programming :

### 3.1 Cadrage initial et décomposition du Workshop 5
* **Message de l'étudiant** : Partage du sujet complet du TP (*« Workshop 5: Building Offline-First Queue App with Geolocation »*) et demande d'accompagnement méthodique étape par étape.
* **Analyse d'Antigravity** :
  - Décomposition du TP en 3 axes fondamentaux : Offline-First avec SQLite, Géolocalisation avec gestion des permissions, et Tests TDD.
  - Mise à jour de `pubspec.yaml` avec les packages requis (`sqflite`, `path_provider`, `path`, `geolocator`, `uuid`, `sqflite_common_ffi`).
  - Implémentation du service SQLite `LocalQueueService` et du service de position `GeolocationService`.

### 3.2 Résolution du blocage des liens symboliques Windows
* **Situation** : Des erreurs de compilation et de génération de code surviennent en raison des restrictions de droits de Windows sur la création des liens symboliques (*symlinks*).
* **Conseil d'Antigravity** : Recommandation d'activer le **Mode Développeur Windows** dans les paramètres système de Windows 11 afin de déverrouiller les permissions de création de symlinks sans nécessiter d'élévation administrateur permanente.
* **Action de l'étudiant** : Envoi d'une capture d'écran des *Paramètres Windows > Système > Espace développeurs* attestant de l'activation réussie du Mode développeur.
* **Résultat** : Déblocage complet du pipeline d'outillage Flutter.

### 3.3 Diagnostic du spinner infini sur Chrome Web (`MissingPluginException`)
* **Constat de l'étudiant** : Après avoir lancé l'application sur Chrome (`flutter run -d chrome`), l'étudiant saisit un nom (« hajer ») et clique sur **Add**. Le bouton affiche un indicateur circulaire qui tourne indéfiniment sans ajouter le client.
* **Diagnostic d'Antigravity** :
  1. Le package `sqflite` est nativement prévu pour Android et iOS ; sur Chrome Web, l'appel à `openDatabase` lève une `MissingPluginException`.
  2. La méthode `_submitClient()` dans `main.dart` ne disposait pas d'un bloc `finally`, empêchant la réinitialisation de `_isLoading = false` en cas d'erreur.
* **Actions correctives apportées** :
  - Ajout d'un système de stockage in-memory de repli (*in-memory fallback*) dans `LocalQueueService` lorsque l'application s'exécute sur le Web (`kIsWeb`).
  - Sécurisation du formulaire dans `main.dart` avec `try / catch / finally` pour garantir l'arrêt systématique du spinner.

### 3.4 Amélioration du rendu visuel de la géolocalisation
* **Constat de l'étudiant** : Capture d'écran montrant 5 clients dans la file d'attente, mais avec un rectangle blanc non imprimable (*tofu glyph*) à la place de l'émoji `📍`, causé par l'absence de glyphe adapté dans la police système du navigateur.
* **Correction d'Antigravity** :
  - Remplacement de l'émoji par de véritables icônes Material Design : `Icons.location_on` (bleue) en cas de capture réussie, et `Icons.location_off` (grise) avec la mention `Location not captured` en cas d'indisponibilité.
  - Observation que pour le client « fadi », les coordonnées **`36.8300, 10.3100`** ont été enregistrées avec succès.

### 3.5 Élucidation de la question : « pourquoi location not captured »
* **Question explicite de l'étudiant** : *« pourquoi location not captured »*.
* **Explications fournies par Antigravity** :
  1. **Latence réseau sur PC** : Contrairement aux téléphones équipés de puces GPS satellites dédiées, les PC utilisent la triangulation Wi-Fi via Google Location Services, qui peut nécessiter entre 6 et 8 secondes selon la charge réseau. Le timeout initial de 5s était parfois dépassé.
  2. **Autorisations Chrome** : Mise en évidence de l'icône de position 📍 dans la barre d'adresse du navigateur.
  3. **Paramètres Windows** : Nécessité d'autoriser l'accès à la localisation dans les paramètres de confidentialité de Windows.
* **Optimisations** : Augmentation du timeout à 12 secondes et protection `!kIsWeb` pour éviter les méthodes non supportées sur le Web.

### 3.6 Validation des permissions de localisation dans Chrome
* **Action de l'étudiant** : Partage d'une capture d'écran montrant le pop-up Chrome : *« Accès à la position autorisé — Ce site a accès à votre position »*.
* **Conseil d'Antigravity** : Confirmation que le navigateur autorise bien l'accès, invitation à valider par **OK** et à actualiser la page (F5 ou hot restart `R`).

### 3.7 Gestion Offline-First de l'erreur `Failed to fetch` sur Next Client
* **Constat de l'étudiant** : Capture d'écran montrant que la géolocalisation fonctionne parfaitement pour « hadil » (**`36.8300, 10.3100`** avec repère bleu), mais qu'une bannière rouge d'erreur est apparue :  
  `Erreur : ClientException: Failed to fetch, uri=https://...supabase.co/rest/v1/clients?id=...`.
* **Diagnostic d'Antigravity** : L'erreur est survenue lors d'un clic sur **Next Client**. L'ancienne méthode `removeClient()` attendait la réponse réseau de Supabase de façon bloquante ; en cas d'instabilité réseau ou de travail hors ligne, elle déclenchait une exception.
* **Correction architecturale (Offline-First)** :
  - Modification de `removeClient()` : le client est retiré instantanément de l'état local et de SQLite (la suppression locale réussit toujours).
  - La requête distante Supabase est tentée en arrière-plan sans bloquer l'UI ni afficher de message d'erreur rouge intrusif.

---

## 4. Étapes du TP et Implémentations Réalisées

### Étape 1 : Configuration des Dépendances (`pubspec.yaml`)
- `sqflite: ^2.3.0`, `path_provider: ^2.1.1`, `path: ^1.8.3`
- `geolocator: ^11.0.0`, `uuid: ^4.0.0`
- Dépendances de test : `sqflite_common_ffi: ^2.3.0+2`, `mockito: ^5.4.0`, `build_runner: ^2.4.0`

### Étape 2 : Service de Persistance Locale (`LocalQueueService`)
- Table SQLite `local_clients` avec colonnes `id`, `name`, `lat`, `lng`, `created_at`, `is_synced`.
- Méthodes asynchrones : insertion locale, lecture ordonnée, extraction des non-synchronisés, mise à jour du flag `is_synced`, suppression.
- Fallback in-memory transparent sur Chrome Web.

### Étape 3 : Service de Géolocalisation (`GeolocationService`)
- Permissions `ACCESS_FINE_LOCATION` et `ACCESS_COARSE_LOCATION` dans `AndroidManifest.xml`.
- Vérification des permissions et activation du service.
- Mode de repli propre renvoyant `null` si le GPS est refusé, garantissant que l'enregistrement du client n'échoue jamais.

### Étape 4 : Modèle Client et QueueProvider Offline-First
- Modèle `Client` enrichi avec sérialisation complète.
- Cycle d'ajout offline-first : écriture locale immédiate → notification UI → synchronisation Supabase en tâche de fond (`unawaited`).
- Suppression offline-first : retrait local prioritaire sans blocage réseau.

### Étape 5 : Interface Utilisateur (`main.dart`)
- Affichage visuel du statut GPS avec icônes Material (`location_on` / `location_off`).
- Formulaire sécurisé (`try / finally`) pour fiabiliser le spinner de chargement.
- Bouton *Next Client* actif et fonctionnel.

### Étape 6 : Validation TDD (10/10 Tests Réussis ✅)
1. **`test/local_queue_service_test.dart` (4/4 passés)** :
   - Insertion locale SQLite in-memory.
   - Filtrage des non-synchronisés (`getUnsyncedClients`).
   - Mise à jour du flag (`markClientAsSynced`).
   - Tri par date (`created_at`).
2. **`test/queue_provider_geolocation_test.dart` (6/6 passés)** :
   - Ajout avec position GPS accordée.
   - Ajout avec position refusée (fallback `null`).
   - Rejet des noms vides.
   - Sauvegarde avec `is_synced = 0`.
   - Suppression locale via `removeClient`.
   - Défilement de la file via `nextClient`.

---

## 5. Synthèse des Problèmes et Solutions Techniques

| Problème / Blocage | Cause identifiée par l'IA | Résolution apportée |
| :--- | :--- | :--- |
| **Liens symboliques Windows** | Restrictions de sécurité de l'OS sur les symlinks. | Activation du Mode Développeur dans Windows 11. |
| **Bouton d'ajout bloqué en chargement infini sur Chrome** | `sqflite` sans pilote Web (`MissingPluginException`) et absence de `finally`. | Fallback in-memory dans `LocalQueueService` et bloc `finally` dans `main.dart`. |
| **Glyphes carrés (tofu) à l'écran** | Police système ne supportant pas l'émoji texte `📍`. | Remplacement par `Icons.location_on` et `Icons.location_off`. |
| **`Location not captured` intermittent sur PC** | Délai de triangulation Wi-Fi sur PC (6 à 8s) dépassant le timeout de 5s. | Augmentation du timeout à 12s et vérification de l'autorisation Chrome. |
| **Bannière rouge `Failed to fetch` sur Next Client** | `removeClient()` bloquait sur l'attente du réseau Supabase. | Suppression locale prioritaire et synchronisation distante silencieuse. |

---

## 6. Rôle et Valeur Ajoutée de l'IA

L'IA a agi comme **architecte logiciel et mentor en débogage temps réel** :
- **Pédagogie et méthodologie** : Explication claire du paradigme *Offline-First* (sauvegarde locale prioritaire, synchronisation asynchrone, tolérance aux pannes réseau).
- **Diagnostic visuel immédiat** : Analyse des captures d'écran (spinners bloqués, barres d'adresse Chrome, pop-ups de permissions, bannières d'erreur).
- **Assurance qualité logicielle** : Écriture et maintien de 10 tests unitaires automatisés validés à 100%.
- **Rigueur architecturale** : Respect de la Clean Architecture et de l'inversion des dépendances pour une testabilité optimale.

---

> **Note d'intégrité académique** : L'IA a servi d'outil d'assistance, d'analyse et de diagnostic. L'ensemble des manipulations système (activation du mode développeur, autorisations navigateur Chrome) et la validation visuelle sur l'application ont été exécutés par l'étudiant.
