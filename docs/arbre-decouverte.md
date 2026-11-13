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
- **Doute :** à mesure qu'elle comprend que les Gardiens combattent les IA (traque du signal, *Silence radio*, chute expliquée), ses rapports de cycle deviennent hésitants ; à partir du deuxième cran, elle recommande elle-même de réveiller l'équipage, et l'écran marque les réveils « recommandés par ATHENA ».
- **Atout d'orbite :** comme le vaisseau survole la planète, certains résultats agissent avant la mission (relevé orbital d'une partie de la carte).

## 5. Les branches

Cinq branches. Les trois premières renforcent la Meute ; la quatrième sert la compréhension du monde et la jauge **Savoir** ; la cinquième réveille l'équipage (§6 bis).

| Branche | Thème | Découvertes typiques |
|---|---|---|
| **Observation** | Voir avant d'être vu | Observations de Gardiens, échantillons de territoire |
| **Liaison** | Tenir le réseau | Nœuds examinés, cristaux de bassin |
| **Ingénierie** | Adapter les drones | Débris de Gardiens, bases techniques |
| **Xénologie** | Comprendre les bâtisseurs et les Gardiens | Bases de connaissances, chroniques |

## 6. Hypothèses (version 1)

Durée en cycles ; coût en Données. Valeurs de départ, à équilibrer (ramenées le 13 novembre 2026 à l'échelle des gains de l'Acte I : 3 à 4 Données par mission).

| Id | Hypothèse | Requiert | Cycles | Données | Effet |
|---|---|---|---:|---:|---|
| OBS-1 | Relevé orbital | Étape « Observation » du vaisseau | 1 | 3 | Avant chaque mission, une bande de la carte (20 %) est déjà explorée |
| OBS-2 | Rythme des veilleurs | Observation : cycle complet d'une Sentinelle (M4) | 1 | 4 | Le prochain pivot de chaque Sentinelle observée est affiché |
| OBS-3 | Signature violette | Échantillon de sol recolorié (M3) | 2 | 5 | Le territoire recolorié est visible même dans le brouillard inconnu |
| OBS-4 | Sonde profonde | OBS-2 ; base « Ceux qui veillent » (III-2) | 2 | 8 | La Sonde révèle une croix de 5 cases de rayon 2 au lieu de 3 × 3 |
| OBS-6 | Sondage du sous-sol | Un souffle sous la base (M6) ; étape « Recherche » du vaisseau | 2 | 5 | Ouvre l'Hypogée, le complexe souterrain de l'Acte III (GDD §7.4) |
| OBS-5 | Silence radio | Ils traquent ce qui parle à ATHENA (M5) ; essai de silence radio (M6) | 1 | 4 | Un drone peut couper sa liaison : invisible aux Gardiens, mais aveugle et sans action jusqu'à la reconnexion (GDD §3.5) |
| LIA-1 | Relais embarqué | Observation : nœud capturé (II-2) | 1 | 4 | Module *Relais embarqué* : portée de Liaison 6 |
| LIA-2 | Résonance cristalline | Échantillon de cristal de bassin (II-4a) | 2 | 5 | En bordure de bassin, Liaison +2 (règle du GDD §3.2, désormais à débloquer) |
| LIA-3 | Protocole des nœuds | LIA-1 ; base « Une voix sans destinataire » (III-1) | 2 | 8 | Un nœud capturé résiste 2 tours à la recoloration même coupé de la balise |
| ING-1 | Chenilles de rocaille | Échantillon de rocaille (M2) | 1 | 3 | Module *Chenilles* : rocaille au coût 1 |
| ING-2 | Blindage ablatif | Débris de Gardien (premier Gardien neutralisé) | 1 | 4 | Module *Blindage ablatif* : ignore le premier dégât de chaque mission |
| ING-3 | Impulsion stabilisée | ING-2 ; base « Le dernier protocole » (III-6) | 2 | 8 | Recharge de l'Impulsion : 2 tours au lieu de 3 |
| XEN-1 | Grammaire des ruines | Chronique « La première chronique » (M6) | 1 | 3 | Le contenu d'une base de connaissances est annoncé avant son ouverture |
| XEN-2 | Mémoire des jardins | XEN-1 ; base des Jardins géométriques (II-2) | 2 | 5 | Les Gardiens dormants (III-2) affichent leur seuil de réveil |
| XEN-3a | Les Gardiens protègent | XEN-2 ; chronique A de « Deux versions » (III-3) | 3 | 8 | Ouvre une branche de dialogue dans IV-2 ; jauge Concorde +1 |
| XEN-3b | Les Gardiens ont causé la chute | XEN-2 ; chronique B de « Deux versions » (III-3) | 3 | 8 | Ouvre une faiblesse de l'Arbitre (IV-5) ; jauge Emprise +1 |
| XEN-3r | Révision : la chronique A était falsifiée | XEN-3a ; base du relais maître (IV-2) | 3 | 8 | ATHENA corrige sa conclusion ; ouvre la faiblesse de l'Arbitre ; Savoir +1 |
| XEN-L | La clé des liés | *Chronique des liés* (III) ; Pia (CRW-2) et Xenon (CRW-3) éveillés | 2 | 8 | Les liés sont reconnus comme bâtisseurs : accès scellés ouverts, ordres donnés aux Gardiens (GDD §7.6) |
| XEN-4 | La langue de l'Arbitre | XEN-3b ou XEN-3r ; base du relais maître (IV-2) | 3 | 10 | Une phase de l'Arbitre peut être négociée au lieu d'être combattue |

**Vérité du récit (décidée le 13 novembre 2026) : les Gardiens ont causé la chute des bâtisseurs.** La chronique B dit vrai ; la chronique A est une version réécrite par les Gardiens eux-mêmes.

XEN-3a et XEN-3b restent **exclusives** : le joueur choisit quelle chronique extraire dans « Deux versions », et ATHENA conclut sur ce qu'elle a. Choisir A n'est pas une impasse mais une **fausse piste** : la base du relais maître (IV-2) contredit la chronique A, et XEN-3r permet de réviser la conclusion. Le prix est le temps (3 cycles d'étude en plus, en fin de campagne) et les effets de XEN-3a, qui restent acquis. Le quatrième dénouement (Savoir complet, GDD §7.6) exige XEN-1, XEN-2, XEN-3b ou XEN-3r, et XEN-4.

## 6 bis. Équipage : réveiller les dormeurs (validé le 13 novembre 2026)

Les caissons ont souffert du transit : impossible de réveiller qui que ce soit sans risque avant qu'ATHENA ait compris la panne. Le réveil devient donc une **cinquième branche**, étudiée comme les autres.

**Coût permanent :** chaque membre réveillé consomme du support vital, soit **−1 Énergie de déploiement par mission**. Réveiller tôt donne des voix et des avantages, mais déploie moins de drones. Seul le responsable des systèmes compense ce coût.

| Id | Réveil | Requiert | Cycles | Données | Avantage |
|---|---|---|---:|---:|---|
| CRW-0 | Diagnostic des caissons | Étape « Recherche » du vaisseau (fin d'Acte I) | 2 | 5 | Rend les réveils possibles |
| CRW-1 | Paul, médecin | CRW-0 | 2 | 4 | Les réveils suivants prennent 1 cycle de moins |
| CRW-2 | Pia, opératrice de la Meute | CRW-1 ; débris de Gardien | 2 | 5 | Un vétéran choisit entre trois traits au lieu de deux |
| CRW-3 | Xenon, responsable des systèmes | CRW-1 ; étape « Liaison » | 2 | 5 | +1 Énergie par mission (annule son propre coût) |
| CRW-4 | Moonji, xénologue | CRW-1 ; base des Jardins géométriques | 2 | 5 | Les hypothèses de Xénologie prennent 1 cycle de moins |
| CRW-5 | Flores, commandante | CRW-2, CRW-3 et CRW-4 | 3 | 8 | Ouvre des options de décision dans IV-2 et IV-4 |
| CRW-6 | Hermes, pilote | CRW-1 ; étape « Navigation » | 2 | 8 | « Fenêtre de transit » (V-1) dure 2 tours de plus |

Les rôles reprennent les personnages du récit (commandante, responsable des systèmes, xénologue, opératrice de la Meute) ; médecin et pilote complètent les six. La « voix du bord » du récit est ATHENA.

**Voix :** chaque dormeur réveillé prend la parole dans les comptes rendus de son domaine ; ATHENA reste la voix des faits et des probabilités. Avant le réveil, on n'entend ces personnages que dans leurs journaux d'avant le transit, ce qui permet de les présenter au joueur avant qu'il choisisse qui réveiller.

## 7. Effets sur le reste du jeu

- **Économie :** les Données servent désormais d'abord à la recherche ; la contrainte réelle devient le **temps** d'ATHENA (une seule étude à la fois jusqu'à la fin de l'Acte I).
- **Missions :** une ruine majeure contient au plus une base de connaissances. Les relevés « ouvrir la base sans dépasser *Avertissement* » deviennent naturels.
- **Atlas :** chaque piste ouverte signale les secteurs où chercher. Rejouer un secteur pour une découverte manquée est permis.
- **Jauge Savoir :** comptée en hypothèses de Xénologie confirmées et chroniques complétées.
- **Format des missions :** nouveau point d'intérêt `knowledge_base` (propriété `discovery`) et nouvel effet de campagne `discoveries` (voir `format-missions.md`).

## 8. Questions ouvertes

1. **Motif de la chute (décidé le 13 novembre 2026) :** les Gardiens l'ont provoquée pour empêcher les IA des bâtisseurs de prendre le contrôle de leur vie. Conséquences proposées dans le GDD §7.6. XEN-4 (négocier avec l'Arbitre) n'exige pas la commandante réveillée.
