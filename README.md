# Dogs of Gods — prototype jouable

Projet Godot 4.7 (GDScript typé, moteur de rendu Compatibility). Ouvrir le projet et lancer (F5) :
les missions 1 à 5 sont jouables, en portrait, à la souris ou au doigt. La partie est sauvegardée
après chaque commande et reprend à l'identique au lancement suivant.

**Jouer :** toucher un drone, toucher une case (aperçu du trajet), toucher encore pour confirmer.
**Carte :** glisser un doigt pour la déplacer, pincer pour zoomer (molette à la souris). Un toucher n'est
compté qu'au relâchement, et jamais après un glissement.
**Sonde :** sélectionner un Éclaireur, bouton « Sonde », toucher le centre de la zone (les cases hors
de portée sont assombries), toucher encore pour lancer.
**Combat (M5) :** les coups que les Gardiens porteront sont annoncés (trait violet, dégâts chiffrés).
*Se tapir*, *Rempart* et *Réparer* les réduisent ou les compensent ; *Frapper* vise un Gardien à portée.
**ATHENA :** l'IA de bord étudie les hypothèses ouvertes par les découvertes (un cycle par mission jouée).
*Silence radio* (une fois étudié) rend un drone invisible aux Gardiens, mais aveugle jusqu'à sa reconnexion.
Les boutons d'action apparaissent selon la position du drone. « Danger » affiche les cases que les
Gardiens déjà observés surveilleront ; « Tout voir » lève le brouillard pour les essais.

```
core/cells.gd            Notation des cases ("D7", "A1:J3")
core/mission_def.gd      Carte d'une mission : trajets, ligne de vue, vision, cônes
core/mission_loader.gd   Lecture et contrôle d'un fichier de mission
core/game_state.gd       État de partie, commandes du joueur, phase des Gardiens, combat, objectifs
core/campaign.gd         Campagne : ressources, découvertes, études d'ATHENA
core/save_store.gd       Sauvegardes locales (écriture atomique, copie de secours)
data/missions/           Missions 1 à 5
data/research/           Arbre de découverte et découvertes
data/replays/            Solutions de référence et pièges
data/i18n/missions.csv   Textes fr/en
data/schema/             Schéma JSON des missions
ui/main.tscn, main.gd    Scène jouable : touchers → commandes, événements → affichage
ui/board_view.gd         Dessin de la carte (tuiles et sprites de assets/, générés par tools/gen_art.py)
ui/research_view.gd      Écran d'ATHENA
tests/run_replays.gd     Rejoue tout data/replays dans le cœur GDScript
tests/run_campaign.gd    Campagne, arbre et sauvegardes
tests/run_ui.gd          Joue la scène par touchers simulés
tools/                   Validateur et simulateur de référence (Python)
```

## Lancer les tests

```
python3 -I tools/validate.py data
godot --headless --path . --import
godot --headless --path . -s tests/run_replays.gd
godot --headless --path . -s tests/run_campaign.gd
godot --headless --path . -s tests/run_ui.gd
```

L'étape `--import` est nécessaire une fois : elle enregistre les classes (`GameState`, `MissionDef`…)
et compile les traductions. Au tout premier import, Godot signale des fichiers `.translation`
absents : ils sont créés par ce même import, le message disparaît ensuite.

## Utiliser le cœur depuis une scène

```gdscript
var def := MissionLoader.load_mission("res://data/missions/m4_le_veilleur.json")
var game := GameState.new(def)
game.start_turn()
var cases := game.reachable("tec")        # {case: coût}
var annonce := game.intents()             # cases surveillées et rondes à venir
if not game.move("tec", Cells.parse("D7")):
    print(game.last_error)
game.end_player_turn()
for e in game.events:                     # à animer, puis vider
    print(e)
```

Le cœur ne dépend d'aucun nœud. La présentation lit `events` et n'écrit jamais dans l'état.

## Deux implémentations, un seul comportement

`tools/sim.py` et `core/game_state.gd` appliquent les mêmes règles et rejouent les mêmes fichiers.
Toute règle modifiée dans l'un doit l'être dans l'autre ; les rejeux détectent l'écart.

## Android

Deux préréglages d'export (`export_presets.cfg`) :

| Préréglage | Produit | Signature | Usage |
|---|---|---|---|
| Android APK test | `build/dogs-of-gods-test.apk` | clé de débogage | installation directe sur un téléphone |
| Android AAB Play | `build/dogs-of-gods.aab` | clé d'envoi Play | Play Console (via Gradle) |

Réglages communs : `org.dogsofgods.prototype` (provisoire), version 0.1.0 (code 1), arm64 seulement,
API cible 36, API minimale 24 (défaut Godot), portrait, plein écran, aucune permission.
Les bibliothèques natives de Godot 4.7 sont alignées sur 16 Ko (vérifié : segments ELF à 0x4000).

### Construire

Prérequis : Godot 4.7 et ses modèles d'export, SDK Android (`build-tools;36.1.0`, `platforms;android-36`), JDK 17+.

```
GODOT=/chemin/godot ANDROID_HOME=/chemin/sdk JAVA_HOME=/chemin/jdk tools/build_android.sh apk

# AAB : fournir la clé d'envoi, qui ne doit jamais entrer dans le dépôt
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/chemin/upload.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
tools/build_android.sh aab
```

### Installer l'APK de test

Activer les options pour les développeurs et le débogage USB, puis `adb install -r build/dogs-of-gods-test.apk`,
ou copier le fichier sur le téléphone et l'ouvrir (autoriser l'installation depuis cette source).

### Intégration continue

`.github/workflows/android.yml` lance les tests puis construit l'APK à chaque poussée sur `main`,
et l'AAB sur une étiquette `v*` si ces secrets du dépôt existent :

| Secret | Contenu |
|---|---|
| `ANDROID_UPLOAD_KEYSTORE_BASE64` | `base64 -w0 upload.keystore` |
| `ANDROID_UPLOAD_KEY_ALIAS` | alias de la clé |
| `ANDROID_UPLOAD_KEYSTORE_PASSWORD` | mot de passe |

### Avant le premier envoi sur le Play Store

1. Choisir l'identifiant définitif (`package/unique_name`) : il ne pourra plus changer.
2. Créer la clé d'envoi et la conserver hors du dépôt, avec une sauvegarde.
3. Trancher l'API minimale (24 par défaut ; la spécification envisage 26 à 28).
