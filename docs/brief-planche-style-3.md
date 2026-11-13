# Dogs of Gods — Brief de la planche de style n° 3 « Carte en jeu »

> **Version :** 1.1 — 13 novembre 2026 (palette « craie » validée, cf. `planche-assets.png`)
> **Destinataire :** illustrateur ou pipeline de génération suivi d'une retouche manuelle.
> **Documents liés :** `dogs-gdd-v2-regles-campagne.md` (règles), `dogs-spec-technique-v2.md` (pipeline graphique), planches n° 1 et n° 2 (`1000039185.png`, `1000039186.png`).

## 1. But de la planche

Les planches n° 1 et n° 2 fixent le décor. Celle-ci doit prouver que **le jeu se lit** : unités, brouillard, territoire et intentions des Gardiens posés sur une carte alignée sur la grille. Elle sert de cible visuelle à la tranche verticale (jalon 2) et tranche trois questions :

1. Une case suffit-elle à identifier son terrain ?
2. Le turquoise (Meute) et le violet (Gardiens) tiennent-ils sur le désert ocre-gris, le canyon rouille et les bassins gris-bleu ?
3. Les sept unités se distinguent-elles à la taille réelle du téléphone ?

Ce n'est pas une illustration d'ambiance : c'est une **capture d'écran idéale** de la carte, sans interface autour.

## 2. Format

| Élément | Valeur |
|---|---|
| Grille | 10 × 10 cases carrées, vue de dessus |
| Résolution | 2560 × 2560 px (256 px par case, soit le double de la cible en jeu) |
| Point de vue | Grille carrée à l'écran ; reliefs et unités peints en oblique trois-quarts, comme sur les planches n° 1 et n° 2 |
| Lumière | Unique, venant du nord-ouest ; ombres portées courtes vers le sud-est |
| Livraison | Fichier en calques (§7) + export aplati PNG |

## 3. Carte logique imposée

La composition part de cette grille, pas l'inverse. Le nord est en haut ; colonnes A à J, lignes 1 à 10.

```
      A  B  C  D  E  F  G  H  I  J
  1   R  R  .  M  M  M  .  .  R  R
  2   R  .  .  M  X  M  .  .  .  R
  3   .  .  .  .  r  .  .  R  .  .
  4   .  R  .  .  .  .  .  R  .  .
  5   C  C  C  G  C  C  C  .  R  .
  6   .  .  .  .  .  .  .  .  .  .
  7   .  R  .  .  N  .  .  .  B  B
  8   .  R  .  .  .  .  .  .  B  B
  9   .  .  .  .  .  .  R  .  .  .
 10   .  .  b  .  .  .  .  .  .  R
```

| Signe | Terrain | Consigne de dessin |
|---|---|---|
| `.` | Plaine désertique | Sol ocre-gris crayeux craquelé, quasi plat ; aucun relief qui pourrait passer pour de la rocaille |
| `R` | Rocaille | Crêtes ardoise, **entièrement contenues dans la case** ; le pic peut dépasser vers le haut de 30 % au plus |
| `M` | Mésa | Plateau surélevé d'un seul tenant (D1–F2), falaise visible côté sud |
| `r` | Rampe | Seul accès à la mésa, clairement praticable |
| `C` | Canyon | Faille rouille sombre continue de A5 à G5, bords nets alignés sur les cases |
| `G` | Gué | Passage évident dans le canyon (éboulis ou pont naturel) |
| `B` | Bassin cristallin | Gris-bleu glacé, plaques géométriques, bloc 2 × 2 |
| `X` | Ruine | Arche brisée sur la mésa, objectif de la scène |
| `N` | Nœud | Borne technique ancienne, ici **capturée** : lueur turquoise |
| `b` | Balise d'atterrissage | Petit équipement humain, turquoise, modeste face aux ruines |

**Règle absolue :** aucun élément à cheval sur deux cases de types différents. Une case masquée par le relief d'une autre est un défaut.

## 4. Unités à placer

Les sept unités figurent une fois chacune. Hauteur d'une unité : 1 à 1,3 case. Chacune a une ombre portée au sol et un liseré de faction.

### La Meute — quadrupèdes scientifiques, liseré turquoise

| Unité | Case | Silhouette à obtenir | Pose |
|---|---|---|---|
| Éclaireur | I5 | Fin, haut sur pattes, mât de capteurs | Tapi dans la rocaille, à demi dissimulé |
| Technicien | D7 | Trapu, bras manipulateur replié sur le dos | Bras tendu vers le nœud E7 |
| Protecteur | D6 | Large, bas, plaques frontales | **Sélectionné** (anneau ivoire), face au gué |
| Intercepteur | F6 | Profilé, avant-train en pointe | En arrêt, tourné vers le nord |

Ce sont des drones de laboratoire reconvertis : coques claires usées, marquages de mission, aucune allure militaire.

### Les Gardiens — machines anciennes, liseré violet

| Unité | Case | Silhouette à obtenir | Pose |
|---|---|---|---|
| Sentinelle | F2 | Colonne fixe verticale, œil unique | Sur la mésa, regard vers le sud-ouest |
| Patrouilleur | C4 | Tripode élancé, plus haut que les drones | En marche vers l'est |
| Régulateur | G4 | Masse basse et large, bouclier frontal marqué | Face au sud, dos visiblement vulnérable |

Même famille de formes que les ruines (pierre grise, géométrie stricte, joints lumineux violets) : ils appartiennent à la planète, pas à une armée.

**Test de silhouette :** remplies en noir et réduites à 80 px de haut, les sept unités restent reconnaissables entre elles.

## 5. États de jeu à montrer

Tous présents simultanément, chacun sur son calque.

| État | Zone | Rendu |
|---|---|---|
| Brouillard « inconnu » | H1–J3 | Voile sombre bleu nuit `#1E2329`, opaque, bord irrégulier et légèrement animé ; rien ne transparaît |
| Brouillard « exploré, non observé » | A1–B4 | Décor visible mais désaturé et assombri d'un tiers ; aucune unité |
| Territoire recolorié | C1–G4 | Motif géométrique violet incrusté dans le sol (trame de lignes fines qui suit la grille), translucide : le terrain reste identifiable dessous |
| Territoire relié | Rayon 2 autour de E7 et de C10 | Filet turquoise discret au sol, bord lumineux ; plus léger que la recoloration |
| Cône de la Sentinelle | De F2 vers le sud-ouest, 4 cases | Hachures violettes sur les cases surveillées |
| Ronde du Patrouilleur | C4 → F4 → F3 → C3 → C4 | Pointillé violet, flèche sur le prochain déplacement |
| Aura du Régulateur | Cases adjacentes à G4 | Motif violet plus dense, en cours de propagation |
| Sélection et trajet | D6 → D5 | Anneau ivoire `#EADFC8`, trajet ivoire, case d'arrivée marquée |
| Cases atteignables | Autour de D6 | Voile ivoire très léger |
| Grille | Partout | Trait fin, visible à 20 % ; plus marqué sous la sélection |

Le croisement à réussir : en D5, le gué est à la fois sur le trajet ivoire et à la limite du territoire violet. La lecture doit rester immédiate.

## 6. Palette

| Usage | Couleur |
|---|---|
| Désert | Ocre-gris crayeux `#B2987A`, ombres `#806858` |
| Mésa | Ocre pâle `#D6C8B0` |
| Rocaille, ruines | Ardoise `#606A7A` (clair `#9EA8B2`, ombre `#303848`) |
| Canyon | Rouille sombre `#702C26` → `#2C161E` |
| Bassins | Gris-bleu glacé `#A4BEC8`, arêtes `#E0EAEC` |
| Coques de la Meute | Blanc cassé usé `#E0DACC` |
| Pierre des Gardiens | Gris pierre `#707684`, ombre `#3A3E4E` |
| Trait | Encre bleu nuit `#161A24` |
| **Meute, relié** | Turquoise lumineux, base `#1FA38F` éclaircie, émissif |
| **Gardiens, recolorié, danger** | Violet, base `#C49BEA`, plus saturé pour les hachures |
| **Sélection, trajet** | Ivoire `#EADFC8` |

Ocre, rouille et gris-bleu sont **interdits** pour toute information de jeu. Turquoise et violet n'apparaissent nulle part dans le décor naturel.

**Matière :** couleurs désaturées et froides, voiles gris-bleu sur le sol, grain de craie ou de pastel sec, trait d'encre fin ; ambiance minérale et mélancolique inspirée de la bande dessinée de science-fiction européenne. Seules les lueurs de faction sont saturées. Référence : `docs/art/planche-assets.png`, générée par `tools/gen_art.py`.

## 7. Calques à livrer

1. Sol
2. Reliefs hauts (parties qui passent devant les unités)
3. Émission (lueurs des ruines, du nœud, de la balise)
4. Unités, une par calque, avec ombre séparée
5. Territoire recolorié
6. Territoire relié
7. Intentions des Gardiens (cône, ronde, aura)
8. Sélection, trajet, cases atteignables
9. Brouillard (deux états séparés)
10. Grille

Les calques 5 à 10 seront refaits en shader dans le jeu : ils servent ici de référence d'intensité et de motif.

## 8. Critères d'acceptation

- [ ] Chaque case est identifiable seule, recadrée à 256 × 256 px.
- [ ] La planche réduite à 480 × 480 px (taille réelle sur téléphone) reste lisible : on compte les sept unités et on distingue les deux factions.
- [ ] En niveaux de gris, Meute et Gardiens se distinguent par la forme et la luminosité.
- [ ] Simulation de daltonisme (deutéranopie, protanopie) : les hachures et les motifs suffisent sans la couleur.
- [ ] Aucun relief à cheval sur deux types de terrain ; aucune case masquée.
- [ ] Les trois états du brouillard (inconnu, exploré, observé) se différencient au premier regard.
- [ ] Le décor seul (calques 1 à 3) est cohérent avec les planches n° 1 et n° 2.
- [ ] Aucune symétrie ni élément dupliqué.

## 9. Méthode recommandée

1. Partir du gabarit de grille fourni (`gabarit-planche-3.png`), pas d'une page blanche.
2. Peindre ou générer **le décor seul** en s'appuyant sur le gabarit (génération guidée par image, force modérée), puis retoucher à la main l'alignement de chaque case.
3. Produire **les unités séparément**, sur fond neutre, puis les incruster. Une génération d'un seul bloc ne respecte ni la grille ni les positions.
4. Dessiner les surcouches (territoire, intentions, brouillard) en vectoriel par-dessus.

### Amorce de consigne pour le décor (étape 2)

```
Top-down tactical game map, square grid 10x10, hand-painted digital illustration,
terrain features drawn in three-quarter oblique view, each feature fully contained
inside its grid cell. Desaturated chalky ochre-grey cracked desert plain, slate-grey rocky ridges, one
raised mesa plateau with a ramp on its south side and a broken stone arch ruin on
top, a dark rust canyon crossing the map from the west edge with a single rocky ford,
a cold grey-blue crystalline basin in the east. Melancholic mineral European comic-book science-fiction, dry pastel and chalk texture,
cold muted palette, fine ink linework,
monumental ancient ruins, worn materials. Single light from the north-west, short
shadows. No units, no characters, no grid lines, no text, no symmetry, no purple,
no teal.
```

### Amorce de consigne pour une unité (étape 3, à décliner)

```
Single quadruped scientific exploration drone, three-quarter top-down view,
hand-painted digital illustration, off-white worn hull with mission markings,
compact readable silhouette, soft teal emissive accents, neutral flat grey
background, short shadow toward the south-east, no text.
```

Pour les Gardiens : remplacer par « ancient autonomous stone-and-metal machine, strict geometric shapes, glowing violet seams ».
