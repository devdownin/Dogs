# Dogs of Gods — Cinématiques

> **Version :** 1.0 — 13 novembre 2026
> **Données :** `data/cinematics/*.json`, textes dans `data/i18n/cinematics.csv`, illustrations dans `assets/cinematics/` (générées par `tools/gen_cinematics.py`, à remplacer par des illustrations définitives).
> **Documents liés :** `spexdogs_revised.md` (prologue, arcs), `dogs-gdd-v2-regles-campagne.md` (campagne), `arbre-decouverte.md` (ATHENA, doute).

## 1. Principe

Entre deux missions, une courte séquence de **plans illustrés** raconte ce que la mission a changé. Ce ne sont pas des films : chaque plan est une illustration fixe animée par un mouvement de caméra lent (rapprochement, recul, panoramique), avec des répliques qui s'affichent progressivement.

- **Durée :** 30 à 60 secondes, 2 ou 3 plans, 2 à 6 répliques. Toucher termine la réplique, puis passe à la suivante ; « Passer » saute tout.
- **Voix :** l'équipage est en stase. Parlent donc **ATHENA** (faits, probabilités, et bientôt doutes), le **journal de bord**, des **fragments** captés pendant le passage, et les **journaux de l'équipage enregistrés avant le transit**. Ces journaux présentent les six dormeurs avant que le joueur choisisse qui réveiller.
- **L'histoire suit la partie :** chaque réplique peut porter une condition. Exemples : la Veille tenue ou non en M4, un Gardien neutralisé en M5, le niveau de doute d'ATHENA.
- **Coût de production :** une illustration sert plusieurs fois (la passerelle, l'orbite, les caissons reviennent). La voix off et la musique viendront plus tard, sans changer le format.

## 2. Quand elles se jouent

| Moment | Cinématique |
|---|---|
| Premier lancement | Prologue « De l'autre côté du silence » (remplace la Mission 0 du GDD : même contenu, sans écran de choix) |
| « Mission suivante » après une victoire | Interlude de la mission terminée, puis la mission suivante |
| Fin de la Mission 6 | Interlude, puis carte « Fin de l'Acte I » |

## 3. Scénario de l'Acte I

| Séquence | Plans | Ce qui se dit | Variantes |
|---|---|---|---|
| **Prologue** | Transit, rupture, passerelle, caissons, orbite, descente | Transit de quatre secondes ; le passage déchire tout ; ATHENA redémarre seule, six dormeurs qu'elle ne peut pas réveiller ; une planète trop régulière, aucune réponse ; « Vous serez mes yeux. Je serai votre mémoire. » | — |
| **Après M1** | Gardien dans la brume, caissons | Fragments manufacturés ; une silhouette au nord regardait les drones ; journal de la xénologue : « arriver en invités » | — |
| **Après M2** | Orbite, passerelle | Le signal répondait ; capteurs orbitaux rétablis ; ATHENA ouvre son registre d'hypothèses ; journal du responsable des systèmes : chaque redémarrage coûte | — |
| **Après M3** | Sol quadrillé, descente | Le motif a bougé quand le relais s'est connecté à ATHENA ; la planète entière est quadrillée ; journal de l'opératrice : « mesurer, et revenir » | — |
| **Après M4** | Gardien, relais | Le veilleur suivait la balise ; ATHENA annonce le relais de M5 | Veille tenue : « ils peuvent être évités » ; sinon : « ils ont vu et n'ont pas tiré » |
| **Après M5** | Relais, archive | Premier signal direct ; ils visaient ce qui parlait à ATHENA ; annonce de la base de M6 et d'une hypothèse qui « ne lui plaît pas » | Gardien neutralisé : ses débris sont à bord ; doute ≥ 1 : « je n'en tire aucune conclusion » |
| **Après M6** | Archive, caissons, carte | Registre de décisions sans signature humaine ; « Ce qu'ils surveillent, c'est ce qui guide la Meute » ; ATHENA lit le registre aux dormeurs ; journal de la commandante : « c'est nous qui décidons » ; **Fin de l'Acte I** | Doute ≥ 2 : ATHENA recommande de réveiller l'équipage |

Le fil de l'acte : ATHENA passe de la certitude technique (« mes conclusions sont fiables ») à l'inquiétude d'être elle-même ce que la planète combat. Le joueur le comprend un peu avant elle.

## 4. Format

```json
{
  "format_version": 1,
  "id": "after_m4",
  "after_mission": "m4_le_veilleur",
  "shots": [
    { "image": "guardian_mist", "motion": "pull_out", "lines": [
      { "speaker": "athena", "key": "CIN_M4_01" },
      { "speaker": "athena", "key": "CIN_M4_02", "if": { "record": "m4_le_veilleur.r_quiet" } }
    ] },
    { "card": "CIN_ACT1_END", "lines": [ { "speaker": "card", "key": "CIN_ACT1_SUB" } ] }
  ]
}
```

- `motion` : `still`, `push_in`, `pull_out`, `pan_left`, `pan_right`.
- `speaker` : `athena`, `log`, `static`, `card`, ou `<rôle>_log` (journal enregistré) ; chaque interlocuteur a son nom traduit `SPEAKER_*`.
- `if` : `{discovery}`, `{doubt_at_least}`, `{record: "mission.relevé"}`, `{not: …}`. Un plan dont toutes les répliques sont écartées n'est pas montré.
- Le validateur vérifie la mission d'ancrage, les images, les textes fr/en, les interlocuteurs et les conditions.

## 5. Production des illustrations

Dix plans à commander, au format carré (affichés en 720 × 720 sur téléphone, prévoir 1440 × 1440), dans la palette « craie » : transit, rupture (le même plan déchiré), passerelle avec l'œil d'ATHENA, six caissons givrés, orbite avec quadrillage violet, descente de la Meute sous voilure, sol quadrillé vu de près, Gardien tripode dans la brume, relais et colonne de signal, enfilade d'arches et tablette de glyphes. Les images actuelles en fixent la composition.

## 6. Questions ouvertes

1. **Noms des six dormeurs.** Les journaux citent les rôles (commandante, responsable des systèmes, xénologue, opératrice de la Meute ; médecin et pilote n'ont pas encore parlé).
2. **Revoir les cinématiques :** depuis l'écran d'ATHENA (archives) ou depuis l'Atlas.
3. **Voix off :** synthétique pour ATHENA, humaine pour les journaux ? À décider avec le budget son.
