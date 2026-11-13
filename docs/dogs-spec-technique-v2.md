# Dogs of Gods — Spécification technique (v2)

> **Version :** 2.0 — 12 novembre 2026
> **Remplace :** `spectec-dogs.md` (v1.0), dont elle reprend le périmètre en tranchant les points ouverts.
> **Documents liés :** `spexdogs_revised.md` (récit), `dogs-gdd-v2-regles-campagne.md` (règles et campagne).
> **Limite :** `asset-specs (1).md`, cité par la v1, n'est pas dans le projet et n'a pas pu être relu. Les budgets de triangles « selon l'asset bible » ne sont donc pas vérifiés.
> **Décisions validées (12 novembre 2026) :** carte en 2D peinte, abandon de la 3D temps réel ; combat sans hasard (aucun générateur aléatoire dans le cœur de règles).
> **Convention :** **[Décision]** = recommandation ferme ; **[À prototyper]** = à confirmer par mesure sur appareil.

## 1. Résumé des remises en cause

| Sujet | v1 | v2 | Raison |
|---|---|---|---|
| Rendu de la carte | 3D low-poly sans textures, caméra à 42° | **2D en couches, décor peint, grille vue de dessus** | C'est ce que montrent les pistes graphiques ; qualité visée atteignable par une petite équipe ; bien plus léger sur mobile |
| Unités | Modèles 3D sans animation | **Sprites pré-rendus depuis des modèles 3D animés** | La démarche des quadrupèdes est l'identité du jeu |
| Mode 2D | Repli | **Mode principal** ; le 3D temps réel est abandonné | Un seul pipeline à maintenir |
| Moteur | Godot 4.7 | **Godot 4.7 conservé** | Voir §2 |
| Cible de fluidité | ≤ 33 ms au repos sur Pixel 8 | **60 i/s sur Pixel 8, 30 i/s garantis sur un appareil d'entrée de gamme, rendu à la demande au repos** | 33 ms sur un Pixel 8 est une cible trop basse pour de la 2D |
| Appareil de référence | Pixel 8 seul | **Pixel 8 + un appareil modeste (4 Go de RAM)** | Un seul appareil haut de gamme ne dit rien du parc Android |
| Règles | Mêlées à la présentation (non précisé) | **Cœur de règles déterministe, isolé, testable sans affichage** | Sauvegarde, annulation, IA et tests en découlent |
| Sauvegarde, comptes | Non précisés | **Hors ligne d'abord, sauvegarde à chaque tour, synchronisation facultative** | §6 |

## 2. Moteur

**[Décision] Godot 4.7, GDScript à typage statique.**

- Godot 4.7 est sorti en version stable en juin 2026 ; cette version stabilise notamment l'environnement de compilation Android (export Gradle).
- Atouts pour ce projet : pipeline 2D natif, moteur libre et sans redevance, exécutable léger, export Android éprouvé, `AStarGrid2D` et `TileMapLayer` intégrés.
- Alternatives écartées : **Unity 6** (meilleur outillage de services mobiles, mais licence et poids injustifiés pour un jeu 2D au tour par tour sans service en ligne) ; **Defold** (excellent en 2D mobile, mais outillage d'édition de cartes et de données moins riche) ; **natif Kotlin** (aucun outillage de jeu).
- Figer la version mineure pour toute la production ; ne monter de version qu'entre deux jalons.

**[À prototyper] Moteur de rendu.** Commencer avec **Compatibility** (OpenGL ES 3) : c'est le plus large en compatibilité et le plus économe pour de la 2D. Passer à **Mobile** (Vulkan) uniquement si un effet indispensable l'exige, après mesure sur l'appareil modeste.

## 3. Architecture logicielle

```
core/         Règles pures : état, commandes, événements. Aucun nœud, aucun rendu.
ai/           Décision des Gardiens, lit l'état, produit des commandes.
data/         Ressources : unités, terrains, modules, missions, dialogues.
presentation/ Carte, sprites, effets, caméra. Rejoue les événements du cœur.
ui/           Écrans, ATH, gestes.
services/     Sauvegarde, synchronisation, localisation, réglages, audio.
tests/        Tests unitaires et rejeux de missions.
```

**[Décision] Cœur déterministe piloté par commandes.**

- L'état d'une mission est une structure de données sérialisable. Toute action est une **commande** (`Déplacer`, `Agir`, `FinDeTour`) validée puis appliquée, qui émet des **événements** (`UnitéDéplacée`, `CaseRévélée`, `AlerteMontée`).
- La présentation ne modifie jamais l'état : elle anime la liste d'événements. On peut donc accélérer ou passer les animations sans risque.
- Conséquences directes : annulation (pile de commandes), sauvegarde en cours de mission (état + journal), rejeu, simulation sans affichage pour l'équilibrage.
- Le combat étant sans hasard (voir GDD §2), l'état suffit ; si de l'aléa est ajouté un jour, il passera par un générateur à graine stocké dans l'état.

**Algorithmes.**

| Besoin | Solution |
|---|---|
| Cases atteignables | Dijkstra sur la grille (256 cases au plus : coût négligeable) |
| Trajets | `AStarGrid2D`, voisinage orthogonal, coûts par terrain |
| Ligne de vue | Tracé de Bresenham centre à centre ; cache invalidé par événement |
| Brouillard, territoire, danger | Tableaux d'octets par case, transmis au rendu sous forme de petites textures |
| Liaison | Parcours en largeur depuis la balise et les nœuds |

**IA des Gardiens.** Machine à états par unité (ronde, alerte, poursuite, verrouillage) pilotée par la jauge d'alerte du secteur, entièrement déterministe. L'intention du prochain tour est calculée **à la fin du tour des Gardiens** et stockée dans l'état : c'est elle que l'interface affiche, et elle que l'IA exécute. Ce qui est montré est donc toujours ce qui se produit. Budget : tour complet des Gardiens calculé en moins de 50 ms, animé en moins de 4 s (accélérable).

**Données.** Unités, terrains, modules en ressources Godot ; missions selon le gabarit de fiche du GDD (§7.7), avec carte logique, rondes, déclencheurs et récompenses. Aucune valeur d'équilibrage dans le code.

## 4. Pipeline graphique

### 4.1 Carte

**[Décision] Carte en couches 2D, la logique d'abord.**

1. **Concevoir la grille logique** dans Godot (`TileMapLayer` de types de terrain). La carte est jouable en aplats avant toute peinture.
2. **Exporter un gabarit** (image de la grille colorée par type) qui sert de guide de composition.
3. **Peindre le décor** par-dessus le gabarit, dans le style des planches de référence. Règle stricte : un relief occupe des cases entières ; le dessin d'une case suffit à identifier son type.
4. **Importer** en couches : sol, reliefs hauts (dessinés au-dessus des unités pour la profondeur), masque d'émission (lueurs des ruines et des nœuds).
5. **Valider** : lecture à 31 dp, en niveaux de gris, avec brouillard et recoloration actifs.

- Résolution : 128 px par case, soit 2048×2048 pour une carte 16×16. En ASTC 6×6, environ 1,9 Mo par carte ; une trentaine de cartes tiennent sous 60 Mo.
- La **grille** est une surcouche de shader, jamais peinte.
- **Brouillard, recoloration, zones de danger et Liaison** : un shader lit de petites textures de données (une valeur par case), interpolées et bruitées pour des bords organiques. La recoloration est un motif géométrique violet animé ; la reconquête, sa dissolution progressive. Coût négligeable, effet fort.
- Si des planches sont produites avec une aide générative, prévoir une retouche manuelle systématique (alignement sur la grille, suppression des répétitions) et une bible de style pour tenir la cohérence sur 30 cartes.

**Variante économique [À prototyper].** Un jeu de tuiles peintes à raccords automatiques au lieu d'une peinture par carte : coût par mission bien moindre, rendu moins singulier. Possible compromis : peintures uniques pour les missions de fin d'acte, tuiles pour le reste.

### 4.2 Unités

**[Décision] Sprites pré-rendus depuis des modèles 3D.** Les modèles `.glb` déjà prévus restent la source ; ils sont rigés, animés, puis rendus en feuilles de sprites sous l'angle oblique du décor.

- 4 orientations ; animations : attente, marche, action, impact, hors service ; 8 images par cycle environ.
- Sprite de 192 px pour une case de 128 px (débordement autorisé vers le haut).
- Liseré de faction (turquoise ou violet) et ombre portée au sol obligatoires pour détacher l'unité du décor.
- Silhouettes distinctes en noir pur à 31 dp : c'est le critère d'acceptation.

Alternative écartée pour l'instant : unités 3D temps réel composées sur la carte 2D (rotations plus fluides, mais complexité et coût de rendu supérieurs).

### 4.3 Palette

| Usage | Couleur | Remarque |
|---|---|---|
| Meute, Liaison | Turquoise lumineux (base `#1FA38F`, éclairci et émissif) | Absent du terrain |
| Gardiens, recoloration, danger | Violet (base `#C49BEA`, plus saturé pour les alertes) | Absent du terrain |
| Sélection, trajets | Ivoire `#EADFC8` | |
| Interface, fond | `#1E2329` | |
| Décor (validé le 13 nov. 2026) | Ocre-gris `#B2987A`, ardoise `#606A7A`, rouille `#702C26`, gris-bleu `#A4BEC8`, encre `#161A24` | Désaturé, grain de craie ; détail dans le brief de la planche n° 3 |
| **Interdits en signalétique** | Ocre, rouille, gris-bleu | Déjà pris par désert, canyon, bassins |

`#FF6A3D` (« menace » de la v1) disparaît : invisible sur le désert. Les graphismes du prototype sont générés par `tools/gen_art.py` (déterministe) en attendant les illustrations définitives. Toute information portée par la couleur l'est aussi par une forme ou un motif (hachures de danger, icône d'intention), ce qui couvre le daltonisme sans mode séparé.

### 4.4 Interface, illustrations, son

- Icônes SVG monochromes 24×24 conservées. Cibles tactiles de 48 dp minimum.
- Illustrations peintes de chroniques conservées ; même palette que la carte pour l'unité visuelle.
- Musique en couches synchronisées dont le mixage suit la jauge d'alerte (flux interactifs de Godot). Format Ogg Vorbis.

## 5. Interface tactile

| Geste | Effet |
|---|---|
| Toucher un drone | Sélection ; affiche cases atteignables et cases dangereuses |
| Toucher une case | Aperçu du trajet et de ce qui sera vu ou déclenché |
| Toucher de nouveau | Confirmation |
| Appui long | Fiche de l'unité ou du terrain |
| Pincer, glisser à deux doigts | Zoom et déplacement de la carte |
| Bouton « Danger » | Affiche toutes les cases surveillées au prochain tour |
| Bouton « Annuler » | Annule le dernier déplacement s'il n'a rien révélé |

- Portrait prioritaire (jeu à une main, actions en bas d'écran), paysage pris en charge.
- Fin de tour confirmée s'il reste des drones inactifs.
- Affichage bord à bord, encoches et zones de geste respectées, geste de retour prédictif géré, écrans pliables et tablettes pris en charge par mise en page adaptative.

## 6. Sauvegarde et services

**[Décision] Hors ligne d'abord, sans compte obligatoire.**

- Sauvegarde automatique à chaque fin de tour et à chaque mise en arrière-plan de l'application. La reprise restitue le tour exact.
- Écriture atomique (fichier temporaire puis renommage), copie de la sauvegarde précédente conservée, format versionné avec migrations.
- Deux fichiers : campagne (progression, Atlas, Meute) et mission en cours (état + journal de commandes).
- **Réalisé (13 novembre 2026) :** `core/save_store.gd` et `core/campaign.gd`. Le journal de mission est écrit après chaque commande (et à la mise en arrière-plan), la campagne à chaque fin de mission et à chaque étude lancée ; écriture atomique avec copie `.bak` de secours ; la reprise rejoue le journal et repart d'une mission neuve si les données ont changé. Testé par `tests/run_campaign.gd` et `tests/run_ui.gd`.
- **Synchronisation facultative** par les parties enregistrées de Google Play Jeux, via le plugin communautaire Godot dédié. La limite de 3 Mo par sauvegarde est très au-dessus du besoin. En cas de conflit entre appareil et nuage, le joueur choisit ; jamais d'écrasement silencieux.
- Aucune télémétrie par défaut. Suivi de stabilité par les indicateurs de la console Play, sans SDK tiers. Toute mesure d'usage est soumise à consentement.
- Localisation français et anglais dès le premier jalon (fichiers de traduction, aucune chaîne dans le code).

## 7. Conformité Android et Google Play

- **Niveau d'API cible :** 36 (Android 16), exigé pour les nouvelles applications et les mises à jour depuis le 31 août 2026.
- **Pages mémoire de 16 Ko :** obligatoire pour les applications ciblant Android 15 et plus qui embarquent du code natif. Vérifier le moteur **et chaque plugin** dans l'explorateur de bundles de la console Play, et tester sur un émulateur 16 Ko.
- **Niveau d'API minimal :** à arbitrer entre 26 et 28 selon la couverture voulue **[À prototyper]**.
- Format AAB, signature par Play, arm64 uniquement en production.
- Taille : viser moins de 150 Mo installés pour éviter toute livraison d'assets à la demande.
- Modèle économique **à décider** ; recommandation : prologue et Acte I gratuits, achat unique du reste, sans publicité, cohérent avec un jeu narratif et sans collecte de données.

### 7.1 État réalisé (12 novembre 2026)

| Point | Valeur vérifiée sur les paquets produits |
|---|---|
| API cible / compilation | 36 / 36 (défaut du modèle Godot 4.7) |
| API minimale | 24 (défaut Godot) — **décision ouverte** : 26 à 28 envisagés |
| Architecture | arm64-v8a seule |
| Pages de 16 Ko | Segments ELF alignés sur 0x4000 dans l'APK et l'AAB |
| Permissions | Aucune |
| Orientation, affichage | Portrait, plein écran ; l'interface évite encoches et barres système (zone sûre) |
| Taille | APK de test 27 Mo, AAB 27,6 Mo |
| Identifiant | `org.dogsofgods.prototype` — **provisoire**, à fixer avant le premier envoi |

Construction : `tools/build_android.sh` (APK de test ou AAB) et `.github/workflows/android.yml`. La clé d'envoi Play n'est jamais versionnée ; elle est fournie par des secrets.

## 8. Budgets de performance

| Mesure | Pixel 8 | Appareil modeste |
|---|---|---|
| Fluidité en animation | 60 i/s | 30 i/s |
| Au repos | Rendu à la demande, aucun calcul continu | idem |
| Démarrage à froid | < 3 s | < 6 s |
| Chargement d'une mission | < 1,5 s | < 3 s |
| Calcul du tour des Gardiens | < 50 ms | < 150 ms |
| Mémoire | < 400 Mo | < 400 Mo |
| Session de 30 min | Aucune hausse sensible de température ; batterie < 8 % | — |

Textures en ASTC, atlas par famille, effets limités à deux passes de shader plein écran au maximum.

## 9. Qualité et outillage

- **Tests unitaires** du cœur de règles (GdUnit4 ou GUT) : chaque règle du GDD a son test.
- **Rejeux de mission :** pour chaque mission, le journal de commandes d'une partie gagnante est rejoué en intégration continue. Si un changement d'équilibrage rend une mission impossible, le test échoue.
- **Simulation sans affichage** pour mesurer durée moyenne et marge de victoire par mission.
- **Intégration continue :** export automatique, tests, publication sur la piste interne de Play.
- **Galerie d'assets** conservée, étendue aux contrôles en niveaux de gris et à 31 dp.
- Écran de débogage : états du brouillard, intentions, jauge d'alerte, Liaison.

## 10. Jalons proposés

| Jalon | Contenu | Critère de sortie |
|---|---|---|
| 1. Cœur | Règles, IA, Missions 1 à 4 en aplats | Les trois règles piliers sont amusantes sans graphisme |
| 2. Tranche verticale | Mission 4 en qualité finale : carte peinte, sprites animés, shaders, son | Niveau visuel validé sur les deux appareils |
| 3. Acte I | Missions 0 à 6, sauvegarde, progression du vaisseau | Jouable de bout en bout par des testeurs |
| 4. Campagne | Actes II à V, Atlas, dénouements | Tous les rejeux passent |
| 5. Sortie | Localisation, accessibilité, conformité Play | Test fermé puis ouvert |

Ne produire aucune carte définitive avant la fin du jalon 2 : c'est lui qui fixe le coût réel d'une mission.

## 11. Risques

| Risque | Parade |
|---|---|
| Coût de 30 cartes peintes | Variante à tuiles (§4.1) ; décision au jalon 2 |
| Cohérence graphique entre cartes | Bible de style, gabarit de grille, retouche systématique |
| Règle de Liaison jugée contraignante | Testée au jalon 1 ; repli : simple bonus au lieu d'une restriction |
| Plugins natifs non conformes (16 Ko, API cible) | Vérification à chaque montée de version ; limiter les plugins au strict nécessaire |
| Volume d'animations des unités | 4 orientations seulement ; réutilisation du squelette quadrupède |

## 12. Sources

- [Godot 4.7 — notes de version](https://godotengine.org/releases/4.7/)
- [Android Developers — prise en charge des pages de 16 Ko](https://developer.android.com/guide/practices/page-sizes)
- [Exigence de niveau d'API cible 36 (synthèse)](https://swiftspeed.app/sdk-target-android-api-level)
- [Android Developers — sauvegarde dans le nuage Play Jeux](https://developer.android.com/games/pgs/savedgames)
- [Plugin Google Play Games Services pour Godot](https://store.godotengine.org/asset/jacob-ibanez-sanchez/google-play-games-services-for-godot/)
