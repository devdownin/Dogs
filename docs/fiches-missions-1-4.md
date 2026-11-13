# Dogs of Gods — Fiches des missions 1 à 6 (prototype)

> **Version :** 1.2 — 13 novembre 2026 (Missions 5 et 6 : combat, Intercepteur, silence radio)
> **Rôle :** contenu jouable du prototype : six missions, sans graphisme définitif.
> **Documents liés :** `dogs-gdd-v2-regles-campagne.md` (règles), `dogs-spec-technique-v2.md` (architecture), `brief-planche-style-3.md` (la carte de la Mission 4 reprend celle de la planche).
> **Vérification :** les coûts de trajet cités ont été calculés par script sur les grilles ci-dessous. Les durées et l'intérêt de jeu restent à confirmer manette en main.

## 0. Précisions de règles nécessaires au prototype

Ces points complètent le GDD (§3.5) ; ils y sont reportés.

1. **Quand un drone est-il vu ?** Uniquement pendant la phase des Gardiens. Traverser une case surveillée pendant son propre tour est sans risque ; **y terminer son tour** ne l'est pas. La zone affichée est exactement celle qui sera surveillée à la prochaine phase des Gardiens.
2. **Intentions.** Elles ne s'affichent que pour les Gardiens actuellement observés. Explorer sert donc à lire l'adversaire.
3. **Cône de la Sentinelle** (portée 4). Face à un axe : à la distance *d* devant elle, les cases jusqu'à *d − 1* de côté. Face à une diagonale : les cases du quadrant, axes exclus, à 4 pas au plus. Depuis une mésa, elle voit par-dessus la rocaille.
4. **Patrouilleur.** Voit les cases à 2 pas de sa **position d'arrivée**. Pendant son trajet, il ne détecte qu'un drone qui lui barre la route.
5. **Interagir et Interface** s'exercent sur une case adjacente.
6. **Extraction.** Sur une case d'extraction, l'action *Rappel* fait quitter la carte au drone. Elle consomme l'action du tour.

> **Données :** ces six missions existent au format de fichier du jeu ([format-missions.md](format-missions.md), fichiers dans `data/missions/`), avec une solution de référence rejouée automatiquement pour chacune.

### Légende commune

`.` plaine (1) · `R` rocaille (2) · `M` mésa · `r` rampe · `C` canyon · `G` gué · `B` bassin · `X` ruine (2) · `b` atterrissage et extraction · `v` plaine recoloriée

Nord en haut ; colonnes en lettres, lignes en chiffres. Déplacements : Éclaireur 5, Technicien 3.

---

## Mission 1 — « Sol inconnu »

| | |
|---|---|
| Acte, type, carte | I, reconnaissance, 8 × 8 |
| Situation | Première descente. Aucune carte, aucun repère. |
| Question posée | Qu'y a-t-il autour de nous ? |
| **Règle introduite** | Déplacement, coûts de terrain, brouillard |
| Déploiement | 2 Éclaireurs imposés, en A7 et A8 |
| Durée visée | 6 à 8 tours, 5 minutes |

```
      A  B  C  D  E  F  G  H
  1   R  R  .  .  .  M  M  M
  2   .  .  .  R  .  r  M  M
  3   .  R  .  .  .  .  R  .
  4   .  .  .  C  C  .  .  .
  5   .  .  .  C  .  .  R  .
  6   .  R  .  .  .  .  .  .
  7   b  .  .  .  R  .  .  B
  8   b  .  .  .  .  .  B  B
```

- **Objectif principal :** amener un Éclaireur au point haut H1, puis ramener les deux drones en A7–A8.
- **Relevé 1 :** révéler 90 % de la carte.
- **Relevé 2 :** terminer en 8 tours.
- **Gardiens :** aucun.
- **Repère d'équilibrage :** A7 → H1 coûte 13, soit 3 tours aller et 3 retour. Le second Éclaireur a donc le temps de cartographier l'ouest : le joueur découvre seul l'intérêt de se séparer.

| Déclencheur | Événement |
|---|---|
| Tour 1 | Bulle : toucher un drone, toucher une case, confirmer |
| Première entrée en rocaille | Bulle : coût 2, la rocaille masque la vue |
| Tour 3 | ATHENA : la balise d'atterrissage n'intéresse personne ; ce sont les drones que quelque chose observe (premier indice) |
| Éclaireur en H1 | La vision depuis la mésa dévoile un large secteur ; des fragments manufacturés brillent en D2. Réplique d'ATHENA. |
| Retour des deux drones | Fin. Dernier plan : une silhouette immobile hors carte, au nord. |

- **Échec :** impossible (aucune menace). Le repli avant H1 termine la mission sans récompense.
- **Récompenses :** 2 Matériaux ; +1 Donnée par relevé.
- **Effets de campagne :** secteur « Plateau d'arrivée » ouvert sur l'Atlas.
- **Découverte vérifiable :** des matériaux manufacturés sont mêlés au relief.

---

## Mission 2 — « Échos dans la poussière »

| | |
|---|---|
| Acte, type, carte | I, étude, 8 × 8 |
| Situation | Un signal répétitif émane d'un champ de ruines. |
| Question posée | Qui a bâti cela ? |
| **Règle introduite** | Interagir ; le Technicien et son *Interface* |
| Déploiement | 2 Éclaireurs et 1 Technicien imposés, en B8, C8, D8 |
| Durée visée | 6 à 9 tours, 7 minutes |

```
      A  B  C  D  E  F  G  H
  1   .  .  R  .  .  X  X  .
  2   .  a  .  .  R  X  s  .
  3   R  .  .  .  .  .  .  R
  4   .  .  R  R  .  .  a  .
  5   .  .  .  .  .  R  .  .
  6   C  C  G  C  .  .  .  .
  7   .  .  .  .  .  R  .  .
  8   .  b  b  b  .  .  .  B
```

`a` anomalie (Interagir, tout drone) · `s` source du signal (*Interface*, Technicien seul)

- **Objectif principal :** examiner les deux anomalies, analyser la source, ramener le Technicien en B8–D8 avant la fin du tour 12 (fenêtre de transmission du vaisseau).
- **Relevé 1 :** terminer en 8 tours.
- **Relevé 2 :** révéler les trois cases de ruine.
- **Gardiens :** aucun.
- **Repère d'équilibrage :** le Technicien met 3 tours pour atteindre G3 (coût 8), agit au 3e, rentre en 3 : 6 tours si rien n'est perdu. Les Éclaireurs atteignent une anomalie en 2 tours (coût 7). La leçon : le drone lent décide du rythme, les rapides préparent sa route.

| Déclencheur | Événement |
|---|---|
| Tour 1 | Présentation du Technicien : lent, fragile, indispensable |
| Première anomalie examinée | Bulle : Interagir sur une case adjacente |
| Source analysée | Le signal change de rythme. Réplique : il répond à quelque chose. |
| Tour 10 | Avertissement : la fenêtre se ferme dans 2 tours |

- **Échec :** Technicien hors de la zone à la fin du tour 12. Données perdues, mission à rejouer.
- **Récompenses :** 3 Données, 1 Matériau ; étape **Observation** du vaisseau.
- **Effets de campagne :** première hypothèse inscrite aux chroniques (marquée « hypothèse »).
- **Découverte vérifiable :** la géométrie des structures n'est pas naturelle.

---

## Mission 3 — « Une couleur de trop »

| | |
|---|---|
| Acte, type, carte | I, étude puis repli, 10 × 10 |
| Situation | Au nord, le sol est quadrillé d'un motif régulier. |
| Question posée | Qu'est-ce qui transforme ce terrain ? |
| **Règle introduite** | Territoire recolorié ; repli sous compte à rebours |
| Déploiement | 2 Éclaireurs et 1 Technicien, en D10, E10, F10 |
| Durée visée | 8 à 10 tours, 10 minutes |

```
      A  B  C  D  E  F  G  H  I  J
  1   v  v  v  v  v  v  v  v  v  v
  2   v  v  v  X  v  v  v  v  R  v
  3   v  v  v  v  v  v  v  v  v  v
  4   m  .  .  R  .  p  .  .  .  m
  5   .  R  .  .  .  .  .  R  .  .
  6   .  .  .  C  C  .  .  .  .  .
  7   .  .  .  .  C  C  .  R  .  .
  8   R  .  .  .  .  .  .  .  .  .
  9   .  .  R  .  .  .  .  .  B  B
 10   .  .  .  b  b  b  .  .  B  B
```

`m` borne de frontière à observer · `p` point de pose du relais de mesure

- **Objectif principal :** observer les bornes A4 et J4, poser le relais en F4 (*Interface*), puis extraire les trois drones.
- **La réaction :** dès la pose, ou dès qu'un drone termine un tour sur une case `v`, la zone recoloriée **avance d'une ligne vers le sud** à chaque phase des Gardiens. Un drone qui s'y trouve alors perd 1 INT. Cinq tours après le début de la réaction, l'extraction se ferme.
- **Relevé 1 :** aucun drone ne termine un tour sur une case recoloriée.
- **Relevé 2 :** observer la ruine D2 sans entrer dans la zone.
- **Gardiens :** aucun visible. La planète elle-même réagit.
- **Repère d'équilibrage :** le Technicien atteint F5 en 3 tours (coût 7, détour par l'est du canyon) et pose au 3e. Le retour prend 3 tours ; la recoloration le suit à deux lignes d'écart. La marge est réelle mais visible à l'écran : tension sans piège.
- **La décision :** l'ordre des opérations. Poser d'abord lance le compte à rebours alors que les Éclaireurs sont loin ; observer d'abord coûte des tours mais sécurise le repli.

| Déclencheur | Événement |
|---|---|
| Première case `v` révélée | Bulle : sur ce sol, vous êtes vus |
| Relais posé | Le motif pulse et commence à avancer. Compteur de 5 tours affiché. ATHENA : il s'est mis en mouvement quand le relais s'est connecté à elle. |
| Chaque avancée | La ligne qui sera recouverte au tour suivant est annoncée |
| Dernier drone extrait | Fin. Le motif s'arrête à la ligne atteinte. |

- **Repli partiel :** les drones extraits sont saufs ; ceux restés à la fermeture sont hors service (récupérés contre des Matériaux).
- **Échec :** relais non posé à la fermeture.
- **Récompenses :** 3 Données, 1 Fragment.
- **Effets de campagne :** la « recoloration » entre officiellement aux chroniques ; la ligne atteinte reste visible sur l'Atlas.
- **Découverte vérifiable :** la transformation suit un cycle et réagit à l'intrusion.

---

## Mission 4 — « Le veilleur »

| | |
|---|---|
| Acte, type, carte | I, infiltration, 10 × 10 (carte de la planche n° 3) |
| Situation | Une machine immobile garde une balise sur un plateau ; une autre fait sa ronde. |
| Question posée | Que cherchent-elles à voir ? |
| **Règle introduite** | Intentions visibles ; jauge d'alerte. Nouvel actif : *Sonde* |
| Déploiement | 2 Éclaireurs et 1 Technicien, en B10, C10, D10 |
| Durée visée | 6 à 10 tours, 12 minutes |

```
      A  B  C  D  E  F  G  H  I  J
  1   R  R  .  M  o  M  v  .  R  R
  2   R  .  .  M  X  S  v  .  .  R
  3   .  .  .  .  r  .  v  R  .  .
  4   .  R  P  .  .  .  .  R  .  .
  5   C  C  C  G  C  C  C  .  R  .
  6   .  .  .  .  .  .  .  .  .  .
  7   .  R  .  .  .  .  .  .  B  B
  8   .  R  .  .  .  .  .  .  B  B
  9   .  .  .  .  .  .  R  .  .  .
 10   .  b  b  b  .  .  .  .  .  R
```

`o` balise (objectif, sur la mésa) · `S` Sentinelle · `P` Patrouilleur (départ C4) · la ruine E2 est sur la mésa et se traverse (coût 2)

- **Objectif principal :** *Interface* du Technicien sur la balise E1, depuis une case adjacente.
- **Relevé 1 :** rester au cran *Veille* toute la mission.
- **Relevé 2 :** révéler 80 % de la carte.
- **Cran d'alerte initial :** *Veille*.

**Gardiens.**

| Gardien | Comportement, par phase des Gardiens |
|---|---|
| Sentinelle F2 | Cycle de regard : sud, sud-ouest, sud, sud-est, puis recommence |
| Patrouilleur | Aller-retour sur la ligne 4 : C4 → G4 aux phases impaires, G4 → C4 aux phases paires |

**Solution de référence sans alerte (4 tours).**

| Tour | Technicien | Pourquoi c'est sûr |
|---|---|---|
| 1 | D10 → D7 | Hors de toute portée |
| 2 | D7 → D6 | Phase paire : la Sentinelle regarde au sud-ouest, D6 est trop loin ; le Patrouilleur revient en C4, à 3 pas |
| 3 | D6 → D3 par le gué (coût 3) | Phase impaire : la Sentinelle regarde au sud, D3 est hors du cône ; le Patrouilleur finit en G4, à 4 pas |
| 4 | D3 → E3 → E2 (coût 3), puis *Interface* | Mission réussie avant la phase suivante |

- **Les pièges à lire :** attendre en D6 un tour de trop (vu par la Sentinelle regardant au sud) ; s'arrêter sur le gué ou en D4 (sur la route du Patrouilleur) ; passer par l'est (cases recoloriées G1–G3).
- **Rôle des Éclaireurs :** observer les deux Gardiens pour que leurs intentions s'affichent. Un Éclaireur tapi dans la rocaille I5 reste *Discret* (B4 est un piège : adjacent à la ronde) ; la *Sonde* révèle la mésa depuis le sud du canyon (exemple rejoué : Éclaireur en E6 au tour 2, Sonde centrée sur E2, puis repli en E7 avant la phase 3 ; rester en E6 est un piège, la Sentinelle y regarde au tour 3).
- **Si l'alerte monte :** à *Avertissement*, le Patrouilleur quitte sa ronde vers la dernière position vue ; la mission reste gagnable en l'attirant ailleurs avec un Éclaireur. À *Interception*, la Sentinelle tire (1 dégât, portée 3).

| Déclencheur | Événement |
|---|---|
| Premier Gardien observé | Bulle : les hachures violettes montrent ce qu'il surveillera |
| Tour 2 | Bulle : *Sonde* disponible |
| Premier cran d'alerte franchi | Réplique d'ATHENA : « Vous êtes détectés. Aucune attaque. » |
| *Interface* sur la balise | La Sentinelle se tourne vers la balise, pas vers le drone. Fin. |

- **Échec :** Technicien hors service. Aucun combat requis ni possible à ce stade.
- **Récompenses :** 3 Données, 1 Fragment ; +1 Donnée par relevé.
- **Effets de campagne :** fiche « Sentinelle » et « Patrouilleur » ouvertes dans l'Atlas ; Concorde +1 si *Veille* tenue.
- **Découverte vérifiable :** le Gardien distingue les objets du terrain et hiérarchise ce qu'il regarde.

---

## Mission 5 — « Le prix d'un signal »

| | |
|---|---|
| Acte, type, carte | I, défense, 10 × 10 |
| Situation | Un relais intact pourrait joindre l'*Asterion*. L'émission attirera les machines. |
| Question posée | Combien de temps tenir, et à quel prix ? |
| **Règle introduite** | Combat sans hasard ; Protecteur (*Rempart*, *Ancrage*) ; *Se tapir* ; *Réparer* |
| Déploiement | 2 Éclaireurs, 1 Technicien, 1 Protecteur, en B10, D10, E10, G10 |
| Durée visée | 4 à 6 tours, 10 minutes |

```
      A  B  C  D  E  F  G  H  I  J
  1   R  .  .  .  .  .  .  .  R  R
  2   .  P1 R  .  .  .  .  .  .  .
  3   .  .  .  .  .  R  .  .  .  .
  4   .  R  .  .  X  .  .  .  R  .
  5   .  .  .  R  o  .  .  .  .  .
  6   .  .  .  .  .  .  .  R  P2 .
  7   B  B  .  .  .  .  .  .  .  .
  8   B  B  .  R  .  .  .  .  R  .
  9   .  .  .  .  .  .  R  .  .  .
 10   .  b  .  b  b  .  b  .  .  R
```

`o` relais (ruine E5, se traverse, coût 2) · `P1` Patrouilleur B2 ↔ H2 · `P2` Patrouilleur I6 ↔ I2

- **Objectif principal :** *Interface* du Technicien sur le relais, puis Technicien à côté du relais (D5, F5 ou E6) quand l'émission se termine, 3 phases plus tard.
- **Relevé 1 :** aucun drone hors service. **Relevé 2 :** ne neutraliser aucun Gardien (Concorde +1).
- **Échec :** Technicien hors service, ou émission non tenue au tour 10.
- **À l'activation :** alerte à *Avertissement* ; les deux Patrouilleurs foncent vers le relais.

**Solution de référence (4 tours, les deux relevés).** Tour 1 : approche (Technicien E8, Protecteur E7). Tour 2 : le Protecteur monte sur le relais E5 et se tapit ; le Technicien passe en E6 et active le relais. Tours 3 et 4 : le Protecteur se tapit, le Technicien le répare. Les Patrouilleurs s'arrêtent contre le Protecteur (*Ancrage*) et ne frappent que lui : 1 dégât chacun, compensé en partie par la réparation. Le Protecteur finit à 1 point.

- **Pièges rejoués :** émettre sans couverture (le Patrouilleur met le Technicien hors service dès la phase 2) ; frapper au lieu de se tapir (le Protecteur tombe ; le Technicien peut le relever).
- **Découverte vérifiable :** les Gardiens ne visent pas le relais mais ce qui parlait à ATHENA (découverte « Ils traquent ce qui parle à ATHENA » ; ouvre l'hypothèse *Silence radio*).
- **Récompenses :** 4 Données, 2 Matériaux ; +1 Donnée par relevé ; étape « Liaison » du vaisseau.

---

## Mission 6 — « La première chronique »

| | |
|---|---|
| Acte, type, carte | I, récupération, 12 × 12 |
| Situation | Une base de connaissances intacte, au cœur d'un champ recolorié. |
| Question posée | Peut-on entrer sans être vu ? |
| **Règle introduite** | Intercepteur (*Impulsion*, *Élan*) ; essai de *Silence radio*, accordé par la mission |
| Déploiement | Éclaireur, Technicien, Intercepteur, Protecteur, en B11, C11, D11, E11 |
| Durée visée | 10 à 12 tours, 15 minutes |

```
      A  B  C  D  E  F  G  H  I  J  K  L
  1   R  R  v  v  X  o  X  v  v  c  R  R
  2   R  .  v  v  X  p  X  v  v  v  R  R
  3   .  .  R  v  v  v  v  v  R  v  .  .
  4   .  .  v  v  v  v  v  v  v  v  R  .
  5   .  R  v  v  v  v  v  v  v  v  .  .
  6   .  .  .  R  .  .  .  .  R  .  .  .
  7   C  C  C  C  G  C  C  C  C  C  .  .
  8   .  .  .  .  .  .  .  .  .  .  .  .
  9   .  R  .  .  .  .  .  .  .  R  .  .
 10   .  .  .  .  R  .  .  .  .  .  B  B
 11   .  b  b  b  b  .  .  .  .  .  B  B
 12   .  .  .  .  .  .  .  .  R  .  .  .
```

`v` sol recolorié (C1:J5) · `o` base de connaissances F1 · `p` poche F2, seule case du champ qui n'est pas recoloriée · `c` cache de fragments J1 · Patrouilleurs : ligne 8 (A8 ↔ L8) et ligne 3 (C3 ↔ I3)

- **Objectif principal :** ouvrir la base (*Interface* du Technicien), puis rappeler le Technicien.
- **Relevé 1 :** rester en *Veille*. **Relevé 2 :** pousser jusqu'au cache J1.
- **Échec :** Technicien hors service, ou mission non terminée au tour 16.
- **La contrainte :** depuis le sud du champ, la poche est à 4 cases ; le Technicien doit finir au moins un tour sur le sol violet, où tout drone relié est vu. En silence radio, il traverse sans être vu, mais il doit se reconnecter pour agir, et la poche n'est hors de vue qu'une phase sur deux.

**Solution de référence (11 tours, Veille tenue).** Le Technicien franchit le gué quand le Patrouilleur du sud est loin, coupe sa liaison en entrant dans le champ, attend un tour, se reconnecte dans la poche à une phase sûre. L'Intercepteur, passé par l'est (K7, L7), fige le Patrouilleur du nord par une *Impulsion* depuis K3 pendant l'ouverture de la base. Retour en silence, reconnexion en D9, rappel en D11.

- **Pièges rejoués :** finir un tour sur le sol violet sans couper la liaison (détection immédiate) ; à l'inverse, la force paie aussi : l'Intercepteur lancé en ligne droite (D11 → D8) frappe à 3 dégâts et neutralise un Patrouilleur d'un coup, au prix d'un cran d'alerte.
- **Découverte vérifiable :** un registre de décisions dont aucune n'est signée par une personne (découverte « La première chronique », qui ouvre *Grammaire des ruines*).
- **Effets :** essai de silence radio consigné (il faut ensuite étudier *Silence radio* pour en disposer dans les missions suivantes) ; Concorde +1 si *Veille* tenue.
- **Récompenses :** 4 Données, 1 Matériau, 1 Fragment ; +1 Donnée par relevé.

---

## Ce que le prototype doit apprendre

| Question | Mission | Signe de réussite |
|---|---|---|
| La commande à trois touchers est-elle naturelle ? | 1 | Aucune bulle relue |
| Le drone lent crée-t-il de la planification, pas de l'ennui ? | 2 | Le joueur envoie les Éclaireurs devant sans qu'on le lui dise |
| Le compte à rebours est-il tendu sans être injuste ? | 3 | Échec au premier essai rare, relevé 1 raté fréquent |
| Les intentions visibles suffisent-elles à créer la réflexion ? | 4 | Le joueur attend volontairement un tour |
| Le combat annoncé se lit-il comme une énigme plutôt qu'un échange de coups ? | 5 | Le joueur se tapit et répare au lieu de frapper |
| Le silence radio est-il un vrai choix (voir ou être vu) ? | 6 | Le joueur se reconnecte au bon moment sans aide |
| La règle « vu seulement en fin de tour » est-elle comprise ? | 4 | Aucune détection jugée arbitraire |

Si la Mission 4 n'est pas intéressante en aplats, aucun graphisme ne la sauvera : c'est le test décisif du jalon 1.
