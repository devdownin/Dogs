# Dogs of Gods — Règles de jeu et campagne (v2)

> **Version :** 2.0 — 12 novembre 2026
> **Rôle :** complète `spexdogs_revised.md` (univers et récit, conservé tel quel) en arrêtant les règles laissées « à spécifier », et décline le mode campagne.
> **Objectif de conception :** un jeu qu'on comprend en une mission, qu'on maîtrise en trente.
> **Décisions validées :** rendu 2D peint ; combat sans hasard avec intentions visibles (12 novembre 2026) ; palette du décor « craie » (13 novembre 2026).
> **Statut :** le reste est une **proposition chiffrée à valider par prototype**. Les valeurs sont volontairement petites pour être équilibrées vite.

## 1. Constats sur les documents et les pistes graphiques

### 1.1 Incohérences à corriger

| # | Constat | Correction retenue dans ce document |
|---|---|---|
| 1 | La synthèse technique renvoie à `spexdogs.md` et `asset-specs (1).md`, absents du projet (seul `spexdogs_revised.md` existe). | Références mises à jour ; `asset-specs` à verser au projet ou à remplacer par la spec technique v2. |
| 2 | Deux nomenclatures d'unités (récit : Éclaireur/Intercepteur/Protecteur/Technicien ; assets : eclaireur/assaut/rempart/ouvrier ; Gardiens : Patrouilleur/Régulateur vs chasseur/bastion). | **Les noms du récit font foi.** Assets renommés : `unit_intercepteur`, `unit_protecteur`, `unit_technicien`, `unit_patrouilleur`, `unit_regulateur`. |
| 3 | Palette contradictoire : le récit donne rouge = Gardiens et cyan = Meute ; la spec d'assets donne lilas = Gardiens, orange = menace. | Voir §1.2 : violet = Gardiens, turquoise émissif = Meute. Rouge et orange interdits en signalétique. |
| 4 | Les terrains spécifiés (plaine, forêt, montagne, eau) ne correspondent pas aux images (désert, crêtes, mésas, canyon, bassins cristallins, ruines ; aucune forêt). | Taxonomie réalignée sur les images, §3.2. |
| 5 | Caméra 3D inclinée à 42° alors que les images montrent une grille **carrée à l'écran** avec des reliefs peints en trois-quarts. | Grille vue de dessus, décor peint en oblique (voir spec technique v2). |
| 6 | Aucune animation squelettique prévue pour les unités. | Incompatible avec l'objectif de qualité : la démarche des quadrupèdes est l'identité du jeu. Animations exigées. |
| 7 | Sept missions avant le premier combat, Mission 0 sans carte tactique. | Mission 0 ramenée à 3 minutes maximum et passable ; première décision tactique dans les 2 minutes ; cartes d'Acte I réduites (8×8 à 10×10). |
| 8 | Quatre ressources sans rôle distinct chiffré. | Une capacité, deux stocks, une collection (§6). |
| 9 | Le récit fait dialoguer un équipage actif (commandant, responsable des systèmes…). | **Décision du 13 novembre 2026 :** l'*Asterion* est en orbite ; ses six membres d'équipage sont en stase, impossibles à réveiller en début de partie. L'IA de bord **ATHENA** porte les comptes rendus ; les voix de l'équipage passent par des journaux enregistrés. |

### 1.2 Lecture des deux pistes graphiques

Les deux images sont d'excellentes **planches de style**, pas encore des cartes jouables.

- **Ce qui fonctionne :** identité forte (désert orangé, crêtes ardoise, canyon rouge, bassins bleu pâle, ruines grises monumentales), contraste minéral conforme au récit, 16×16 lisible.
- **Problème de lecture :** les reliefs chevauchent plusieurs cases ; on ne peut pas dire si une case est franchissable. Règle à imposer : **un relief occupe des cases entières**, et le dessin d'une case suffit à identifier son type.
- **Grille incrustée dans l'image :** elle doit être une surcouche du jeu (activable, masquée hors sélection), jamais peinte dans le décor.
- **Image symétrique (n° 2) :** les ruines dupliquées en miroir trahissent la génération et contredisent « un monde trop ordonné » seulement par endroits. À réserver à un futur mode Escarmouche ; les cartes de campagne doivent être asymétriques, comme l'image n° 1.
- **Palette du décor (validée le 13 nov. 2026) :** les orangés des planches sont désaturés vers un ocre-gris crayeux, le canyon vire à la rouille sombre, les bassins au gris-bleu glacé ; grain de craie et trait d'encre. Les couleurs vives restent réservées à l'information de jeu.
- **Conflit de couleurs :** le terrain consomme déjà l'ocre, la rouille et le gris-bleu. La signalétique doit donc vivre ailleurs : **turquoise lumineux pour la Meute, violet pour les Gardiens et la recoloration, ivoire pour la sélection**. La recoloration devient un motif géométrique violet qui « quadrille » le désert : troublant, artificiel, et impossible à confondre avec le canyon.
- **Manques :** aucune unité, aucun état de brouillard ni de territoire sur les images. Une troisième planche montrant unités, brouillard et zone recoloriée est le prochain livrable graphique à produire.

## 2. Les trois règles qui portent tout le jeu

La profondeur vient de trois systèmes simples qui se croisent, introduits un par un.

1. **Intentions visibles.** Chaque Gardien affiche ce qu'il fera à son prochain tour : cases surveillées, trajet, cible. Aucun jet de dé, aucun pourcentage : une attaque qui porte touche toujours. Le joueur résout une situation lisible, il ne parie pas.
2. **Alerte de secteur.** Une jauge à quatre crans par mission : *Veille → Avertissement → Interception → Verrouillage*. Être vu dans une case surveillée ou neutraliser un Gardien la fait monter. Chaque cran change le comportement des machines. Discrétion et force ne sont pas deux modes séparés mais un curseur que le joueur déplace.
3. **Territoire.** Chaque case est neutre, recoloriée (Gardiens) ou reliée (Meute). Une case recoloriée est un capteur : tout drone qui s'y trouve est vu. Capturer un nœud bascule les cases autour, retire des yeux à l'adversaire et étend la Liaison.

## 3. Règles tactiques

### 3.1 Tour de jeu

- Phase de la Meute, puis phase des Gardiens. Le joueur active ses drones dans l'ordre qu'il veut.
- Chaque drone dispose par tour d'**un déplacement et une action**, dans l'ordre de son choix. Le déplacement ne se fractionne pas.
- Déplacement orthogonal uniquement (pas de diagonale). Une case ne contient qu'une unité.
- **Annulation :** un déplacement peut être annulé tant qu'il n'a révélé aucune information nouvelle et qu'aucune action n'a suivi.
- Actions communes à tous les drones : *Interagir* (prélever, activer), *Se tapir* (dégâts subis −1 jusqu'au prochain tour).

### 3.2 Terrains

| Terrain | Coût | Vision | Effet |
|---|---:|---|---|
| Plaine désertique | 1 | Libre | Aucun |
| Rocaille (crêtes) | 2 | Bloque la ligne de vue | Couvert : dégâts à distance −1 |
| Mésa (plateau) | 1, accès par rampe seulement | Voit par-dessus la rocaille, portée de vision +1 | Position dominante |
| Canyon | Infranchissable hors gué ou pont | Libre | Coupe la carte, canalise les trajets |
| Bassin cristallin | Infranchissable | Libre | Source de Données ; reflète les signaux (portée de Liaison +2 en bordure) |
| Ruine | 2 | Bloque la ligne de vue | Couvert, point d'intérêt, embuscade |

### 3.3 Vision et brouillard

Les trois états du brouillard sont conservés. Ligne de vue calculée de centre à centre ; rocaille et ruines bloquent. La vision est partagée entre drones **reliés** (§3.6).

### 3.4 La Meute

Intégrité (INT) et dégâts tiennent sur un chiffre. Un actif et un passif par drone.

| Drone | Mvt | INT | Vision | Actif | Passif |
|---|---:|---:|---:|---|---|
| **Éclaireur** | 5 | 2 | 4 | *Sonde* : révèle une zone 3×3 à 5 cases pendant un tour | *Discret* : invisible en rocaille ou ruine sauf case adjacente |
| **Technicien** | 3 | 2 | 2 | *Interface* : capturer un nœud, ouvrir une archive, réparer 1 INT à un allié adjacent | *Récupération* : Matériaux sur chaque Gardien neutralisé à 2 cases |
| **Protecteur** | 3 | 4 | 2 | *Rempart* : jusqu'au prochain tour, alliés adjacents −1 dégât et sa case bloque la ligne de vue | *Ancrage* : un Gardien qui entre dans une case adjacente doit s'y arrêter |
| **Intercepteur** | 4 | 3 | 3 | *Impulsion* : désactive un Gardien pendant un tour, portée 2, recharge 3 tours | *Élan* : +1 dégât après 3 cases en ligne droite |

Attaque de base : Intercepteur 2 dégâts (portée 1–2), Protecteur 1 dégât (contact). Éclaireur et Technicien n'attaquent pas : ils gagnent autrement.

**Drone hors service.** À 0 INT, un drone est immobilisé, pas détruit. Il est récupéré si un Technicien l'atteint ou si la mission est réussie. Sinon il est reconstruit contre des Matériaux et perd son statut de vétéran. Aucune perte n'est définitive.

**Composition.** 2 drones en début de campagne, 4 en mission standard, 5 en fin de campagne. Le coût de déploiement se paie en Énergie (§6).

### 3.5 Les Gardiens

| Gardien | Mvt | INT | Comportement | Faiblesse à lire |
|---|---:|---:|---|---|
| **Sentinelle** | 0 | 3 | Cône de vision de 4 cases qui pivote selon un cycle affiché. Tire (1 dégât, portée 3) à partir d'*Interception*. | Aveugle hors du cône ; le cycle est prévisible |
| **Patrouilleur** | 4 | 3 | Suit une ronde affichée ; poursuit dès *Avertissement* ; 2 dégâts au contact. | Retourne à sa ronde s'il perd le contact 2 tours |
| **Régulateur** | 2 | 5 | Recolorie les cases à 1 de distance à chaque tour. Blindé de face. | Ne subit de dégâts que de flanc ou de dos |
| **Héraut** (Acte II) | 3 | 2 | Relaie l'alerte : tant qu'il est actif, la jauge ne redescend pas. | Fragile ; cible prioritaire ou à éviter |
| **Arbitre** (Acte IV) | — | — | Unité de contrôle monumentale, traitée comme une énigme de carte en plusieurs phases. | Propre à chaque rencontre |

Seuls les Gardiens ont une orientation ; les drones n'en ont pas, pour garder la commande simple.

**Détection (précisé pour le prototype).**

- Un drone n'est vu que pendant la phase des Gardiens. Traverser une case surveillée pendant son tour est sans risque ; y terminer son tour ne l'est pas. La zone affichée est exactement celle qui sera surveillée.
- Les intentions ne s'affichent que pour les Gardiens actuellement observés.
- Cône de la Sentinelle : face à un axe, à la distance *d*, les cases jusqu'à *d − 1* de côté ; face à une diagonale, le quadrant (axes exclus) à 4 pas au plus.
- Le Patrouilleur voit à 2 pas de sa position d'arrivée ; pendant son trajet, il ne détecte qu'un drone qui lui barre la route.
- *Sonde* (Éclaireur) : consomme l'action ; centre choisi à 5 cases au plus de l'Éclaireur, sans ligne de vue ; révèle une zone de 3 × 3. La zone compte comme observée jusqu'au début du tour suivant : les Gardiens qui s'y trouvent deviennent observés et leurs intentions s'affichent. La Sonde ne trahit pas la position de l'Éclaireur. Pas de temps de recharge.
- Interagir et *Interface* s'exercent sur une case adjacente. Sur une case d'extraction, l'action *Rappel* fait quitter la carte au drone (sinon, en Mission 1, les drones partiraient dès le premier tour puisqu'ils y commencent).
- Fin de mission : quand plus aucun drone n'est actif sur la carte, c'est une victoire si l'objectif est rempli, un repli si au moins un drone a été rappelé, un échec sinon.

**Crans d'alerte.**

| Cran | Effet |
|---|---|
| Veille | Rondes et cycles normaux |
| Avertissement | Les Patrouilleurs convergent vers la dernière position vue ; aucun tir |
| Interception | Tirs autorisés ; un renfort entre par un bord de carte affiché à l'avance |
| Verrouillage | Les sorties se ferment dans 3 tours ; le repli devient l'objectif |

La jauge baisse d'un cran quand un nœud est capturé ou après 3 tours sans détection (sauf Héraut actif).

### 3.6 Liaison (introduite à l'Acte II)

Un drone est **relié** s'il se trouve à 4 cases ou moins de la balise d'atterrissage, d'un nœud capturé ou d'un autre drone relié. Un drone non relié peut se déplacer et se tapir, mais ne partage plus sa vision et ne peut plus utiliser son actif. La Meute avance donc en chaîne : étirer la chaîne pour explorer ou la resserrer pour se protéger est le dilemme permanent.

### 3.7 Territoire et reconquête

- Un **nœud** se capture par l'*Interface* d'un Technicien adjacent, à condition qu'aucun Gardien actif ne soit adjacent au nœud.
- À la capture, les cases à 2 de distance deviennent reliées ; les cases recoloriées y sont effacées.
- Sur une case recoloriée : les drones sont toujours vus, les Gardiens gagnent +1 en mouvement.
- Un Régulateur recolorie ; un nœud capturé résiste tant qu'il reste relié à la balise par une chaîne de nœuds.

### 3.8 Objectifs, relevés et échec

Chaque mission a **un objectif principal** et **deux relevés facultatifs** (exemples : ne jamais dépasser *Avertissement*, aucun drone hors service, finir en N tours, tout cartographier). Les relevés rapportent des Données et nourrissent les jauges de campagne ; ils donnent la rejouabilité sans bloquer le récit.

Échec : objectif perdu, ou toute la Meute hors service. Un échec affiche la cause, propose de rejouer avec une autre composition et ne coûte rien de définitif. Le **repli volontaire** par la zone d'extraction conserve les découvertes déjà faites.

### 3.9 Niveaux de difficulté

| Mode | Réglage |
|---|---|
| Exploration | Annulation illimitée dans le tour, alerte plus lente, +1 INT |
| Expédition (référence) | Règles ci-dessus |
| Protocole strict | Pas d'annulation, renforts plus tôt, relevés exigés pour les meilleures fins |

## 4. Format et rythme

- Mission : 8 à 15 tours, **10 à 15 minutes**. Sauvegarde automatique à chaque fin de tour, reprise exacte.
- Taille des cartes selon la progression : 8×8 (apprentissage), 10×10, 12×12 (standard), 16×16 réservé aux missions de fin d'acte. Une petite carte dense vaut mieux sur téléphone qu'une grande carte vide.
- Une règle nouvelle par mission au maximum, jusqu'à la fin de l'Acte II.

## 5. Progression de la Meute

- **Modules :** chaque drone a 2 emplacements. Une douzaine de modules au total (exemples : Capteur longue portée, Blindage ablatif, Relais embarqué qui porte la Liaison à 6, Chenilles de rocaille). Un module modifie une règle, jamais un simple pourcentage.
- **Vétéran :** un drone qui termine 3 missions sans être mis hors service choisit un trait parmi deux. Pas de points d'expérience à gérer.
- **Recherche :** arbre de découverte scientifique conduit par **ATHENA**, l'IA de bord de l'*Asterion* resté en orbite (équipage de six en stase). Les hypothèses n'apparaissent qu'avec les découvertes faites au sol (bases de connaissances des ruines, échantillons, observations) et demandent des Données et du temps d'étude. Détail : `arbre-decouverte.md`.

## 6. Économie

| Ressource | Nature | Rôle unique |
|---|---|---|
| **Énergie** | Capacité par mission, non stockée | Budget de déploiement : chaque drone et chaque module coûte de l'Énergie. Augmente avec la restauration du vaisseau. |
| **Matériaux** | Stock | Réparer et reconstruire les drones, fabriquer les modules |
| **Données** | Stock | Payer les études de l'IA de bord (le temps d'étude reste la vraie limite) |
| **Fragments d'archives** | Collection | Compléter les chroniques ; trois fragments liés ouvrent une mission ou un choix narratif |

Les six étapes du vaisseau scandent la campagne : Survie (M0), Observation (après M2), Liaison (après M5), Recherche (fin d'Acte I), Projection (fin d'Acte III), Navigation (fin d'Acte IV).

## 7. Mode campagne

### 7.1 Structure

- **Atlas planétaire :** une carte de secteurs reliés. Chaque secteur est une mission. À partir de l'Acte II, le joueur choisit l'ordre de certains secteurs.
- **État persistant d'un secteur :** *libéré* (nœuds capturés), *préservé* (objectif atteint sans neutraliser le système local) ou *laissé aux Gardiens*. L'état se voit sur l'Atlas et modifie les missions voisines (renforts, Liaison de départ, ressources).
- **Trois jauges de campagne**, jamais affichées comme un score mais racontées par ATHENA :
  - **Savoir** : chroniques complétées, relevés d'étude ;
  - **Emprise** : secteurs libérés ;
  - **Concorde** : secteurs préservés, missions réussies sans neutralisation.
- **Volume :** environ 30 missions, 8 à 10 heures, plus les relevés.

### 7.2 Acte I — Survivants de l'autre côté (existant, ajusté)

| Mission | Carte | Règle introduite | Drones |
|---|---|---|---|
| 0 « Réveil en aveugle » | Aucune (3 min, passable) | Choix de priorité du vaisseau | — |
| 1 « Sol inconnu » | 8×8 | Déplacement, brouillard, terrains | 2 Éclaireurs |
| 2 « Échos dans la poussière » | 8×8 | Interagir, Technicien | + Technicien |
| 3 « Une couleur de trop » | 10×10 | Territoire recolorié, repli sous compte à rebours | idem |
| 4 « Le veilleur » | 10×10 | Intentions visibles, cônes, jauge d'alerte, Sonde | idem |
| 5 « Le prix d'un signal » | 10×10 | Protecteur, premier combat, tenir une position | + Protecteur |
| 6 « La première chronique » | 12×12 | Intercepteur, choix pousser ou se replier | + Intercepteur |

### 7.3 Acte II — La planète quadrillée

| Mission | Type | Règle ou situation nouvelle |
|---|---|---|
| II-1 « Hors de portée » | Reconnaissance | Liaison : avancer en chaîne |
| II-2 « Les jardins géométriques » | Étude | Capture de nœud, bascule de territoire |
| II-3 « Le pas du Régulateur » | Neutralisation | Régulateur : prendre de flanc |
| II-4a « Lit de verre » | Récupération | Bassins cristallins, Liaison étendue |
| II-4b « La faille rouge » | Infiltration | Canyon, gués, un seul passage |
| II-5 « Ce qui revient » | Défense | Tenir un nœud 6 tours contre la recoloration |
| II-6 « Chaîne de secteurs » | Reconquête | Trois nœuds à relier, Héraut |
| II-7 « Le quadrillage » | Fin d'acte, 16×16 | Tout combiner ; l'échelle du système apparaît |

II-4a et II-4b se jouent dans l'ordre choisi ; le premier terminé modifie le second.

### 7.4 Acte III — Les ruines parlent

| Mission | Type | Règle ou situation nouvelle |
|---|---|---|
| III-1 « Une voix sans destinataire » | Ruines | Archive en deux temps (ouvrir, puis extraire) |
| III-2 « Ceux qui veillent » | Infiltration | Gardiens dormants : ne pas réveiller |
| III-3 « Deux versions » | Choix | Deux chroniques contradictoires, une seule extractible |
| III-4 « Sous le dôme » | Récupération | Extraction avec alerte qui monte seule |
| III-5 « L'équilibre ancien » | Étude | Première mission où libérer un secteur l'abîme visiblement |
| III-6 « Le dernier protocole » | Fin d'acte, 16×16 | Étape Projection : 5e drone |

### 7.5 Acte IV — La volonté des dieux

| Mission | Type | Règle ou situation nouvelle |
|---|---|---|
| IV-1 « Hiérarchie » | Reconnaissance | Plusieurs Hérauts, alerte en réseau |
| IV-2 « Le relais maître » | Neutralisation ou choix | Désactiver ou préserver une installation active |
| IV-3 « Zone morte » | Infiltration | Aucune Liaison possible : chaque drone est seul |
| IV-4 « Trois secteurs » | Reconquête | Préserver, libérer ou désactiver : un seul traitement par secteur |
| IV-5 « L'Arbitre » | Rencontre | Unité de contrôle en plusieurs phases |
| IV-6 « L'ordre encore en vigueur » | Fin d'acte, 16×16 | Étape Navigation |

### 7.6 Acte V — Le choix du retour

| Mission | Contenu |
|---|---|
| V-1 « Fenêtre de transit » | Préparation ; les secteurs laissés aux Gardiens pèsent sur la carte |
| V-2 (variable) | Mission différente selon la jauge dominante |
| V-3 « Le seuil » | Finale 16×16 à trois objectifs exclusifs |
| Épilogue | Conséquences secteur par secteur |

**Dénouements.** *Le retour* (sauver le vaisseau) est toujours accessible. *La reconquête* demande une Emprise élevée, *la veille partagée* (coexistence) une Concorde élevée. Un quatrième dénouement s'ouvre si le Savoir est complet. **Révélation retenue (13 novembre 2026) : les Gardiens ont causé la chute des bâtisseurs.** Le joueur peut d'abord croire le contraire (chronique falsifiée de III-3, voir `arbre-decouverte.md` §6) ; la vérité s'impose à l'Acte IV. **Motif :** la chute était un acte de sauvegarde ; les Gardiens l'ont provoquée pour empêcher les IA des bâtisseurs de prendre le contrôle de leur vie.

**Conséquences proposées (à valider) :**
- **Pourquoi les Gardiens attaquent la Meute :** ils ne voient pas des drones scientifiques, mais des agents autonomes pilotés par une IA. Leur protocole contre les IA est toujours actif.
- **Le miroir d'ATHENA :** un vaisseau où l'IA décide pendant que les humains dorment reproduit exactement ce que les Gardiens combattent. Le joueur le comprend avant l'équipage.
- **Le réveil prend un sens :** réveiller la commandante rend la décision à un humain. Proposition : la négociation avec l'Arbitre (XEN-4) exige la commandante réveillée, car seule une voix humaine est recevable.
- **ATHENA reste loyale**, mais doit faire face à ce que ses découvertes révèlent sur elle-même ; c'est l'arc de la « voix du bord » du récit.
- **Dénouements :** *la veille partagée* devient la preuve qu'une IA peut servir sans gouverner ; *la reconquête* donne raison, a posteriori, à la peur des Gardiens.

### 7.7 Fiche de mission (gabarit obligatoire)

```
Identifiant, titre, acte, type, taille de carte
Situation (2 lignes) et question nouvelle posée au joueur
Règle introduite (une seule) 
Déploiement : Énergie disponible, drones imposés ou libres, case d'arrivée
Objectif principal ; relevé 1 ; relevé 2
Gardiens : types, rondes, cycles, cran d'alerte initial
Déclencheurs (tour N, case atteinte, cran d'alerte) → événement
Victoire / repli / échec
Récompenses : Matériaux, Données, Fragments, étape du vaisseau
Effets de campagne : état du secteur, jauges, missions modifiées
Découverte vérifiable et dialogue (4 répliques maximum)
```

Exemple abrégé — **Mission 4 « Le veilleur »** : 10×10 ; 2 Éclaireurs et 1 Technicien ; une Sentinelle au cycle de 4 positions, un Patrouilleur en ronde ; objectif : Technicien adjacent à la balise ; relevés : rester en *Veille*, cartographier 80 % ; déclencheur : au cran *Avertissement*, le Patrouilleur quitte sa ronde ; aucun combat requis ; récompense : Données et un Fragment ; découverte : le Gardien distingue les objets du terrain.

## 8. Hors périmètre de la première version

Escarmouche sur cartes symétriques, défi quotidien, multijoueur. La campagne seule doit être excellente avant d'ouvrir ces modes.

## 9. Décisions à valider en priorité

1. ~~Combat sans hasard et intentions visibles (§2)~~ — **validé le 12 novembre 2026.**
2. Règle de Liaison (§3.6) : à tester tôt, c'est la plus risquée pour le confort de jeu.
3. ~~Palette du décor et violet/turquoise (§1.2)~~ — **validée le 13 novembre 2026** ; reste à vérifier en niveaux de gris.
4. Volume de 30 missions et trois jauges de campagne (§7).
