# Dogs of Gods — Arbre de découverte scientifique

> **Version :** 1.1 — 13 novembre 2026 (équipage en stase, IA nommée ATHENA)
> **Remplace :** la « Recherche » de `dogs-gdd-v2-regles-campagne.md` §5 (trois branches de quatre paliers payées en Données).
> **Données :** `data/research/discoveries.json`, `data/research/tree.json` (vérifiés par `tools/validate.py`).

## 1. Principe

L'*Asterion* est resté **en orbite**, sous le contrôle de son **IA de bord, ATHENA**. Les **six membres d'équipage sont en stase** et ne peuvent pas être réveillés en début de partie : ATHENA est la seule voix active du vaisseau. La Meute rapporte des découvertes depuis le sol ; ATHENA en tire des **hypothèses** et les étudie entre deux missions. Le joueur choisit quoi étudier, pas ce qui se découvre.

Trois règles :

1. **On ne recherche que ce qu'on a vu.** Chaque hypothèse exige des découvertes précises faites sur le terrain. Sans elles, elle reste cachée.
2. **L'IA prend du temps.** Une hypothèse demande des Données et un nombre de **cycles** (un cycle = une mission jouée). ATHENA étudie une hypothèse à la fois, deux après l'étape « Recherche » du vaisseau.
3. **Un résultat change une règle.** Jamais un pourcentage : un module, une capacité, une information affichée, un accès narratif.

C'est la traduction directe du récit (§13 de `spexdogs_revised.md`) : la recherche avance par hypothèses que les découvertes confirment, nuancent ou invalident.

## 2. Les découvertes

| Nature | Origine | Exemple |
|---|---|---|
| **Base de connaissances** | Ruines : le Technicien l'ouvre par *Interface* (à l'Acte III, en deux temps : ouvrir, puis extraire avant le Rappel) | Base des Jardins géométriques |
| **Échantillon** | Prélevé par *Interagir* sur un terrain ou un débris | Cristal de bassin, sol recolorié |
| **Observation** | Condition remplie en mission, sans action dédiée | Cycle complet d'une Sentinelle observé |
| **Chronique** | Récompense de mission | « La première chronique » (M6) |

Une découverte est **définitive** : acquise une fois, elle reste, même en cas d'échec ou de repli après son obtention. Les bases de connaissances sont la source principale de l'arbre : la plupart des ruines majeures en contiennent une, parfois gardée.

## 3. Ce que voit le joueur

Chaque hypothèse a quatre états :

| État | Condition | Affichage |
|---|---|---|
| **Inconnue** | Aucune découverte requise acquise | Absente de l'écran |
| **Piste** | Au moins une découverte requise acquise | Silhouette grisée ; liste des découvertes manquantes, décrites sans gâcher (« une base de connaissances au-delà du canyon ») |
| **Étudiable** | Toutes les découvertes et hypothèses parentes acquises | Coût en Données, durée en cycles, effet annoncé |
| **Confirmée** | Étude terminée | Effet actif ; courte note d'ATHENA |

L'arbre se dessine donc au fil de l'exploration : il n'existe pas d'écran rempli de cases verrouillées dès le départ. Une piste est aussi un **objectif d'exploration** : l'Atlas marque les secteurs où une découverte manquante est probable.

## 4. ATHENA

- **Seule à bord :** c'est elle qui donne les ordres de mission, rend compte des pannes et commente les découvertes. Les voix de l'équipage n'existent au départ que sous forme de journaux enregistrés avant le transit.
- **Voix :** elle parle en probabilités et distingue fait observé, hypothèse et inconnu (§6 du récit). Ses notes de résultat font 2 lignes au plus.
- **Initiative :** à la fin d'une mission, elle propose l'hypothèse qu'elle juge la plus utile pour la suivante ; le joueur garde le choix.
- **Abandon :** une étude interrompue garde ses cycles acquis.
- **Hypothèses exclusives :** certaines découvertes se contredisent (Acte III, « Deux versions »). ATHENA ne peut en confirmer qu'une : le choix du joueur oriente les dénouements.
- **Atout d'orbite :** comme le vaisseau survole la planète, certains résultats agissent avant la mission (relevé orbital d'une partie de la carte).

## 5. Les branches

Quatre branches. Les trois premières renforcent la Meute ; la quatrième sert la compréhension du monde et la jauge **Savoir**.

| Branche | Thème | Découvertes typiques |
|---|---|---|
| **Observation** | Voir avant d'être vu | Observations de Gardiens, échantillons de territoire |
| **Liaison** | Tenir le réseau | Nœuds examinés, cristaux de bassin |
| **Ingénierie** | Adapter les drones | Débris de Gardiens, bases techniques |
| **Xénologie** | Comprendre les bâtisseurs et les Gardiens | Bases de connaissances, chroniques |

## 6. Hypothèses (version 1)

Durée en cycles ; coût en Données. Valeurs de départ, à équilibrer.

| Id | Hypothèse | Requiert | Cycles | Données | Effet |
|---|---|---|---:|---:|---|
| OBS-1 | Relevé orbital | Étape « Observation » du vaisseau | 1 | 10 | Avant chaque mission, une bande de la carte (20 %) est déjà explorée |
| OBS-2 | Rythme des veilleurs | Observation : cycle complet d'une Sentinelle (M4) | 1 | 15 | Le prochain pivot de chaque Sentinelle observée est affiché |
| OBS-3 | Signature violette | Échantillon de sol recolorié (M3) | 2 | 20 | Le territoire recolorié est visible même dans le brouillard inconnu |
| OBS-4 | Sonde profonde | OBS-2 ; base « Ceux qui veillent » (III-2) | 2 | 30 | La Sonde révèle une croix de 5 cases de rayon 2 au lieu de 3 × 3 |
| LIA-1 | Relais embarqué | Observation : nœud capturé (II-2) | 1 | 15 | Module *Relais embarqué* : portée de Liaison 6 |
| LIA-2 | Résonance cristalline | Échantillon de cristal de bassin (II-4a) | 2 | 20 | En bordure de bassin, Liaison +2 (règle du GDD §3.2, désormais à débloquer) |
| LIA-3 | Protocole des nœuds | LIA-1 ; base « Une voix sans destinataire » (III-1) | 2 | 30 | Un nœud capturé résiste 2 tours à la recoloration même coupé de la balise |
| ING-1 | Chenilles de rocaille | Échantillon de rocaille (M2) | 1 | 10 | Module *Chenilles* : rocaille au coût 1 |
| ING-2 | Blindage ablatif | Débris de Gardien (premier Gardien neutralisé) | 1 | 15 | Module *Blindage ablatif* : ignore le premier dégât de chaque mission |
| ING-3 | Impulsion stabilisée | ING-2 ; base « Le dernier protocole » (III-6) | 2 | 30 | Recharge de l'Impulsion : 2 tours au lieu de 3 |
| XEN-1 | Grammaire des ruines | Chronique « La première chronique » (M6) | 1 | 10 | Le contenu d'une base de connaissances est annoncé avant son ouverture |
| XEN-2 | Mémoire des jardins | XEN-1 ; base des Jardins géométriques (II-2) | 2 | 20 | Les Gardiens dormants (III-2) affichent leur seuil de réveil |
| XEN-3a | Les Gardiens protègent | XEN-2 ; chronique A de « Deux versions » (III-3) | 3 | 30 | Ouvre une branche de dialogue dans IV-2 ; jauge Concorde +1 |
| XEN-3b | Les Gardiens ont causé la chute | XEN-2 ; chronique B de « Deux versions » (III-3) | 3 | 30 | Ouvre une faiblesse de l'Arbitre (IV-5) ; jauge Emprise +1 |
| XEN-4 | La langue de l'Arbitre | XEN-3a ou XEN-3b ; base du relais maître (IV-2) | 3 | 40 | Une phase de l'Arbitre peut être négociée au lieu d'être combattue |

XEN-3a et XEN-3b sont **exclusives**. Le quatrième dénouement (Savoir complet, GDD §7.6) exige XEN-1, XEN-2, l'une des XEN-3 et XEN-4.

## 7. Effets sur le reste du jeu

- **Économie :** les Données servent désormais d'abord à la recherche ; la contrainte réelle devient le **temps** d'ATHENA (une seule étude à la fois jusqu'à la fin de l'Acte I).
- **Missions :** une ruine majeure contient au plus une base de connaissances. Les relevés « ouvrir la base sans dépasser *Avertissement* » deviennent naturels.
- **Atlas :** chaque piste ouverte signale les secteurs où chercher. Rejouer un secteur pour une découverte manquée est permis.
- **Jauge Savoir :** comptée en hypothèses de Xénologie confirmées et chroniques complétées.
- **Format des missions :** nouveau point d'intérêt `knowledge_base` (propriété `discovery`) et nouvel effet de campagne `discoveries` (voir `format-missions.md`).

## 8. Questions ouvertes

1. **Réveil de l'équipage :** impossible en début de partie. Proposition : le réveil devient un objectif de campagne (une hypothèse d'Ingénierie par dormeur, ou une étape du vaisseau), chaque membre réveillé apportant une voix et un avantage. À valider.
2. **Exclusivité XEN-3 :** choix définitif, ou ATHENA peut-elle revenir sur sa conclusion en fin d'Acte IV contre un coût élevé ?
