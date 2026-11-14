# Dogs of Gods — Format des fichiers de mission

> **Version :** 1.0 (format_version 1) — 12 novembre 2026
> **Documents liés :** `fiches-missions-1-4.md` (contenu), `dogs-gdd-v2-regles-campagne.md` (règles), `dogs-spec-technique-v2.md` (architecture).
> **Code :** ce dépôt (cœur de règles dans `core/`, données dans `data/`, outils dans `tools/`).

## 1. Choix

| Question | Décision | Raison |
|---|---|---|
| Format source | **JSON**, une mission par fichier | Lisible, comparable dans Git, validable hors de Godot par un schéma |
| Chargement | Lu par un `MissionLoader` qui produit une ressource typée `MissionDef` | Le reste du jeu ne manipule jamais de JSON brut |
| Logique de mission | **Vocabulaire fermé** de conditions et d'actions, pas de script | Rejouable, testable, sans risque d'exécuter du code depuis les données |
| Textes | Clés de traduction, CSV `keys,fr,en` | Format natif de Godot ; aucun texte dans les missions |
| Garantie | Validateur + rejeu d'une solution par mission en intégration continue | Un changement d'équilibrage qui casse une mission fait échouer la construction |

Le vocabulaire fermé est la contrainte principale : si une mission a besoin d'un comportement nouveau, on ajoute un type de condition ou d'action au cœur de règles (et au simulateur), on ne l'écrit pas dans la mission.

## 2. Conventions

- **Cases :** `A1` à `P16`, colonne en lettre, ligne en chiffre, nord en haut. Une plage s'écrit `A1:J3` (rectangle inclusif).
- **Identifiants :** `minuscules_et_chiffres`. Clés de texte : `MAJUSCULES`.
- **Carte :** une chaîne par ligne, cases séparées par des espaces, terrain seulement.

| Signe | Terrain | Coût |
|---|---|---:|
| `.` | Plaine | 1 |
| `R` | Rocaille | 2 |
| `M` | Mésa (surélevée) | 1 |
| `r` | Rampe (seul passage entre sol et mésa) | 1 |
| `C` | Canyon | — |
| `G` | Gué | 1 |
| `B` | Bassin cristallin | — |
| `X` | Ruine | 2 |

Ce qui n'est pas du terrain vit dans des couches séparées : `elevated` (cases surélevées autres que `M`, par exemple une ruine sur la mésa), `territory.recolored` et `territory.linked`, `features` (points d'intérêt).

## 3. Structure d'un fichier

| Champ | Contenu |
|---|---|
| `format_version` | `1` |
| `id`, `act`, `order`, `title_key`, `type`, `rule_introduced` | Identité de la mission |
| `map` | `width`, `height`, `rows`, `elevated`, `territory`, `features` |
| `deployment` | `energy` (`null` = imposé), `units` (id, type, case), `extraction` |
| `guardians` | id, type, case ; `facing` ou `facing_cycle` (Sentinelle) ; `route` et `route_mode` `loop` ou `ping_pong` (Patrouilleur) |
| `alert` | `initial` ; `enabled: false` pour les missions sans Gardiens |
| `objectives` | `main` (condition, `deadline_turn` facultatif), `records` (2 au plus), `failure`, `retreat_allowed` |
| `triggers` | `id`, `when` (condition), `do` (actions), `once` (vrai par défaut) |
| `rewards` | Matériaux, Données, Fragments, `per_record`, `ship_stage` |
| `campaign_effects` | `open_sector`, `chronicle`, `codex`, `gauge`, `sector_state`, `discoveries` (`ids`) ; `if_record` pour conditionner à un relevé |
| Point `knowledge_base` | Base de connaissances d'une ruine ; `discovery` = découverte accordée à l'ouverture (voir `arbre-decouverte.md`) |

Types de points d'intérêt : `anomaly`, `point_of_interest`, `fragment_cache` (tout drone) ; `signal_source`, `relay_point`, `beacon`, `node` (Technicien, *Interface*) ; `boundary_marker` (à observer seulement).

## 4. Conditions

**Combinateurs :** `all`, `any`, `not`, `sequence`. `sequence` mémorise sa progression : chaque étape doit devenir vraie après la précédente (exemple : atteindre le sommet, *puis* rappeler la Meute).

| Type | Paramètres | Vrai quand |
|---|---|---|
| `turn_start` / `turn_end` | `turn` | Le tour N a commencé / est terminé |
| `max_turns` | `value` | Mission finie en N tours au plus (relevés) |
| `unit_in` | `unit`, `cells` | Une unité correspondante est sur l'une des cases |
| `unit_extracted`, `unit_disabled` | `unit` | — |
| `all_units_extracted` | — | Plus aucun drone actif, au moins un rappelé |
| `no_unit_disabled` | — | Aucun drone hors service |
| `interacted` | `feature` | Le point a été activé |
| `feature_revealed`, `cells_revealed` | `feature` / `cells` | Déjà vu au moins une fois |
| `reveal_ratio_at_least` | `value` | Part de la carte révélée |
| `terrain_entered` | `terrain` | Un drone a traversé ce terrain |
| `territory_revealed`, `territory_entered` | `territory` | — |
| `unit_end_turn_on` / `never_end_turn_on` | `territory` | Un drone a fini (n'a jamais fini) un tour sur ce territoire |
| `guardian_observed` | `guardian` (ou `any`) | Gardien vu au moins une fois |
| `alert_at_least` / `alert_never_above` | `level` | Cran actuel / cran maximal atteint |
| `countdown_expired` | `countdown` | — |
| `flag` | `name` | Drapeau posé par `set_flag` |
| `guardian_neutralized` | `guardian` (ou `any`) | Gardien neutralisé |
| `no_guardian_neutralized` | — | Aucun Gardien neutralisé (relevés) |

`unit` accepte un identifiant (`tec`), un type (`technician`) ou `any`.

## 5. Actions

| Type | Paramètres | Effet |
|---|---|---|
| `show_tip` | `key` | Bulle d'aide |
| `dialogue` | `lines` : `speaker`, `key` | Répliques (4 au plus par mission) |
| `highlight`, `camera_focus` | `feature` / `cell` | Mise en évidence |
| `cinematic` | `key` | Courte séquence de fin |
| `set_flag` | `name` | — |
| `start_countdown` | `id`, `turns`, `label_key` | Décrémenté à chaque phase des Gardiens |
| `territory_advance` | `territory`, `direction`, `rows_per_phase`, `damage` | Le territoire avance à chaque phase ; dégâts aux drones atteints |
| `close_extraction` | — | Les drones encore actifs passent hors service |
| `set_alert` | `level` | Force un cran |
| `guardian_order` | `guardian` (ou `all`), paramètres | Ordre scénarisé : `face_cell` (présentation), `chase_cell` (les Patrouilleurs foncent vers la case) |
| `end_mission` | `result` | Fin forcée |

## 6. Ordre d'évaluation

1. Début de tour : déclencheurs.
2. Après chaque commande du joueur : déclencheurs, puis objectif principal (victoire), puis `failure`, puis fin si plus aucun drone actif.
3. Fin du tour du joueur : enregistrement des cases de fin de tour, déclencheurs.
4. Phase des Gardiens : déplacements, regards, détection, alerte, avancée du territoire, comptes à rebours ; puis `deadline_turn`, déclencheurs, fins.
5. Les relevés sont évalués une fois la mission terminée.

Les déclencheurs passent avant la victoire : une cinématique liée à la condition de victoire est donc jouée.

## 7. Rejeux

Un rejeu liste, tour par tour, les commandes d'une partie et le résultat attendu :

```json
{
  "mission": "m4_le_veilleur",
  "turns": [
    [ { "unit": "tec", "move": "D7" } ],
    [ { "unit": "tec", "move": "D6" } ],
    [ { "unit": "tec", "move": "D3" } ],
    [ { "unit": "tec", "move": "E2", "act": "interface", "target": "E1" } ]
  ],
  "expect": { "result": "victory", "turn": 4, "alert_max": "watch", "records": { "r_quiet": true } }
}
```

`move` donne la destination (le trajet le moins coûteux est recalculé et vérifié) ; `act` vaut `interact`, `interface`, `probe` (avec `target` = centre de la zone), `extract`, `attack` (`target` = Gardien), `brace`, `rampart` ou `repair` (`target` = allié). `"result": null` sert aux pièges : on vérifie seulement que l'alerte monte.

`rules` (facultatif) liste les règles débloquées par la campagne pour ce rejeu (ex. `["radio_silence"]`, qui permet `silence` et `reconnect`).

`expect.state` (facultatif) fixe l'état final : `units` → `[case, intégrité, statut]`, `guardians` → `[case, intégrité]` ou `"neutralized"`. Il est vérifié des deux côtés, comme l'égalité entre coups annoncés et coups portés à chaque phase.

## 8. État actuel

| Rejeu | Résultat |
|---|---|
| M1, M2, M3 référence | Victoire au tour 6 |
| M4 référence | Victoire au tour 4, alerte maximale *Veille* |
| M4 piège « attente en D6 » | Détection à la phase 3 |
| M4 piège « arrêt sur le gué » | Détection à la phase 3 |
| M4 avec Sonde | Victoire au tour 4, alerte maximale *Veille* |
| M4 piège « rester après la Sonde » | Détection de l'Éclaireur en E6 à la phase 3 |
| M5 référence | Victoire au tour 4, les deux relevés |
| M5 « frapper au lieu de se tapir » | Victoire au tour 4, Protecteur hors service |
| M5 piège « émettre sans couverture » | Échec à la phase 2 |
| M4 en silence radio | Victoire au tour 6, alerte *Veille* malgré l'attente sous le regard de la Sentinelle |
| M4 piège « se reconnecter sous le regard » | Détection en D6 à la phase 3 |

Test de non-régression : décaler d'un cran le regard de la Sentinelle fait échouer la référence M4. Les solutions de référence ne remportent pas tous les relevés (M2 ruines, M3 ruine, M4 carte), qui restent donc des défis.

**À surveiller :** en M1, la référence révèle déjà 92 % de la carte sans effort particulier ; le relevé « 90 % » est probablement trop facile.

## 9. Côté Godot (réalisé)

Le projet Godot 4.7 (GDScript typé) de ce dépôt contient le chargeur et le cœur de règles.

| Fichier | Rôle |
|---|---|
| `core/mission_loader.gd` | Lit le JSON, vérifie `format_version`, la grille et les cases de départ |
| `core/mission_def.gd` | Carte : trajets, ligne de vue, vision, cônes |
| `core/game_state.gd` | État de partie ; commandes `move`, `action`, `end_player_turn` ; phase des Gardiens ; objectifs et déclencheurs |
| `tests/run_replays.gd` | Rejoue `data/replays` sans affichage |

- Les huit rejeux passent dans Godot 4.7 sans affichage, avec le même état final que le simulateur Python (cases révélées, relevés, alerte, position des Gardiens).
- Un test vérifie sur 8 phases que `intents()` annonce exactement ce que la phase des Gardiens exécute.
- Chaque commande ajoute des événements (`unit_moved`, `units_detected`, `alert_changed`, `script_action`…) que la présentation animera.
- Départage des trajets de coût égal : coût, puis colonne, puis ligne. Il est identique des deux côtés et doit le rester.
- **Scène jouable en aplats** (`ui/`) : missions 1 à 4, commande à trois touchers, affichage des cases surveillées, annulation, bilan avec relevés, Sonde (ciblage à deux touchers), zoom et défilement (pincer, glisser, molette ; zoom initial ≈ 48 dp par case, zoom minimal = carte entière). Testée par touchers simulés (`tests/run_ui.gd`) et vérifiée sur captures d'écran.
- L'annulation et, plus tard, la sauvegarde reposent sur le journal de commandes : l'état est reconstruit en le rejouant.
- Intégration continue fournie (`.github/workflows/ci.yml`) : validateur Python, puis rejeux dans Godot.

## 10. Limites actuelles

- Le combat est en place des deux côtés (M5). Modules, *Impulsion* et *Élan* arriveront avec l'Intercepteur (M6).
- La Liaison (Acte II) n'est pas encore dans le format.
- Les règles exactes de vision (distance de Manhattan, ligne de vue centre à centre, rocaille et ruines bloquantes, +1 depuis la mésa) sont celles du code actuel ; elles doivent être confirmées en jeu.

### Jeu de tuiles de Surface

Le champ optionnel `tileset: "surface"` sélectionne le manifeste
`assets/terrain/surface/manifest.json`. La disposition et les règles viennent de
`map.rows` et `map.elevated`. Le champ est activé sur M1 et M4 pour la revue.
