extends SceneTree
## Rejoue toutes les parties de data/replays et compare au résultat attendu.
## Usage : godot --headless --path . -s tests/run_replays.gd
## Code de sortie : 0 si tout passe, 1 sinon.

const MISSIONS := "res://data/missions/"
const REPLAYS := "res://data/replays/"


func _init() -> void:
	var failed := 0
	var files := DirAccess.get_files_at(REPLAYS)
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var problems := _run(REPLAYS + f)
		print(
			(
				"%s %s%s"
				% [
					"OK " if problems.is_empty() else "KO ",
					f,
					"" if problems.is_empty() else " : " + "; ".join(problems)
				]
			)
		)
		if not problems.is_empty():
			failed += 1
	failed += _check_intents()
	print("%d échec(s)" % failed)
	quit(1 if failed > 0 else 0)


func _run(path: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var rep: Dictionary = MissionLoader.load_json(path)
	var def := MissionLoader.load_mission(MISSIONS + rep["mission"] + ".json")
	if def == null:
		return PackedStringArray(["mission introuvable ou invalide"])
	var g := GameState.new(def)
	for cmds: Array in rep["turns"]:
		g.start_turn()
		for c: Dictionary in cmds:
			if not g.result.is_empty():
				break
			if c.has("move") and not g.move(c["unit"], Cells.parse(c["move"])):
				return PackedStringArray(["commande refusée : " + g.last_error])
			if c.has("act"):
				var target := Cells.parse(c["target"]) if c.has("target") else Vector2i(-1, -1)
				if not g.action(c["unit"], c["act"], target):
					return PackedStringArray(["commande refusée : " + g.last_error])
		if not g.result.is_empty():
			break
		g.end_player_turn()
		if not g.result.is_empty():
			break
	var expect: Dictionary = rep["expect"]
	var wanted: String = "" if expect["result"] == null else expect["result"]
	if g.result != wanted:
		problems.append("résultat « %s », attendu « %s »" % [g.result, wanted])
	if expect.has("turn") and g.result_turn != int(expect["turn"]):
		problems.append("fin au tour %d, attendu %d" % [g.result_turn, int(expect["turn"])])
	if expect.has("alert_max") and GameState.ALERTS[g.alert_max] != expect["alert_max"]:
		problems.append(
			"alerte max %s, attendue %s" % [GameState.ALERTS[g.alert_max], expect["alert_max"]]
		)
	var recs := g.records()
	for k: String in expect.get("records", {}):
		if recs.get(k) != expect["records"][k]:
			problems.append("relevé %s = %s" % [k, recs.get(k)])
	return problems


## Garantie centrale du jeu : ce que intents() annonce avant la phase des Gardiens
## est exactement ce qui se produit pendant cette phase.
func _check_intents() -> int:
	var def := MissionLoader.load_mission(MISSIONS + "m4_le_veilleur.json")
	var g := GameState.new(def)
	g.observed_guards = {"sen1": true, "pat1": true}
	var bad := 0
	for t in 8:
		g.start_turn()
		var announced: Dictionary = g.intents()
		g.end_player_turn()
		var actual: Dictionary[Vector2i, bool] = {}
		actual.merge(def.cone(g.guards["sen1"]["pos"], g.guards["sen1"]["facing"]))
		actual.merge(def.vision(g.guards["pat1"]["pos"], GameState.PATROLLER_SIGHT))
		var route: Array = announced["routes"]["pat1"]
		if announced["watched"] != actual or route[-1] != g.guards["pat1"]["pos"]:
			bad += 1
	print(
		(
			"%s intentions annoncées = intentions exécutées (M4, 8 phases)"
			% ["OK " if bad == 0 else "KO "]
		)
	)
	return bad
