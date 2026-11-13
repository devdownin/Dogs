extends SceneTree
## Campagne, arbre de découverte et sauvegardes, sans affichage.
## Usage : godot --headless --path . -s tests/run_campaign.gd

const MISSIONS := "res://data/missions/"
const REPLAYS := "res://data/replays/"

var _failed := 0


func _init() -> void:
	_test_tree()
	_test_exclusive()
	_test_athena()
	_test_store()
	print("%d échec(s)" % _failed)
	quit(1 if _failed > 0 else 0)


func _test_tree() -> void:
	var c := Campaign.new()
	var visible := 0
	for id: String in c.hypotheses:
		if c.state(id) != "hidden":
			visible += 1
	_check(visible == 0, "au départ, aucune hypothèse n'est visible")
	_check(c.lanes() == 1, "au départ, ATHENA mène une seule étude")

	var s2 := _apply(c, "m2_reference")
	_check(c.discoveries.has("sample_rock"), "M2 rapporte un fragment de rocaille")
	_check(c.ship_stage == "observation" and s2["stage"] == "observation", "M2 : étape Observation")
	_check(c.state("ing_1") == "available", "la rocaille rend « Chenilles » étudiable")
	_check(c.state("obs_1") == "available", "l'étape Observation rend le relevé orbital étudiable")
	_check(c.state("obs_4") == "hidden", "une hypothèse sans aucune condition remplie reste cachée")
	var data_before := c.data
	_check(c.start_study("ing_1"), "lancer une étude")
	_check(c.data == data_before - 3, "l'étude coûte ses Données")
	_check(c.study_refusal("obs_1") == "RES_NO_LANE", "une seule étude à la fois")

	var s3 := _apply(c, "m3_reference")
	_check(
		c.confirmed.has("ing_1") and s3["confirmed"] == ["ing_1"], "une mission jouée = un cycle"
	)
	_check(c.state("obs_3") == "available", "le sol recolorié de M3 ouvre « Signature violette »")

	var again := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	_check(
		JSON.stringify(again.to_dict()) == JSON.stringify(c.to_dict()),
		"la campagne survit à l'écriture et à la relecture"
	)

	var c5 := Campaign.new()
	_apply(c5, "m5_combat")
	_check(not c5.discoveries.has("debris_guardian"), "pas de débris sans Gardien neutralisé")


func _test_exclusive() -> void:
	var c := Campaign.new()
	c.data = 100
	for d in ["chronicle_first", "kb_geometric_gardens", "chronicle_two_versions_a"]:
		c.discoveries[d] = true
	c.discoveries["chronicle_two_versions_b"] = true
	c.confirmed["xen_1"] = true
	c.confirmed["xen_2"] = true
	_check(c.start_study("xen_3a"), "étudier la chronique A")
	_check(c.state("xen_3b") == "excluded", "la chronique B est alors écartée")
	c.studying.erase("xen_3a")
	c.confirmed["xen_3a"] = true
	_check(c.state("xen_3r") == "lead", "la révision reste une piste sans la base du relais maître")
	c.discoveries["kb_master_relay"] = true
	_check(c.state("xen_3r") == "available", "la base du relais maître permet de réviser")
	_check(c.cycles_needed("xen_3r") == 3, "révision : 3 cycles")
	c.confirmed["crew_xenologist"] = true
	_check(c.cycles_needed("xen_3r") == 2, "la xénologue réveillée raccourcit la Xénologie")


func _test_athena() -> void:
	var c := Campaign.new()
	_check(c.athena_doubt() == 0 and c.unlocked_rules().is_empty(), "ATHENA sûre d'elle au départ")
	var s5 := _apply(c, "m5_reference")
	_check(c.discoveries.has("obs_signal_hunt"), "M5 : ils traquent ce qui parle à ATHENA")
	_check(int(s5["doubt"]) == 1, "le bilan de M5 rapporte le premier doute")
	_check(c.state("obs_5") == "available", "« Silence radio » devient étudiable")
	_check(c.start_study("obs_5"), "étudier « Silence radio »")
	var s4 := _apply(c, "m4_reference")
	_check(c.unlocked_rules() == ["radio_silence"], "silence radio débloqué pour les missions")
	_check(c.athena_doubt() == 2 and int(s4["doubt"]) == 2, "second doute : ATHENA se sait visée")
	_check(c.athena_recommends_waking(), "ATHENA recommande de réveiller l'équipage")
	c.confirmed["crew_commander"] = true
	_check(
		not c.athena_recommends_waking(), "plus de recommandation une fois la commandante éveillée"
	)


func _test_store() -> void:
	var path := "user://test_store.json"
	SaveStore.erase(path)
	_check(SaveStore.read(path).is_empty(), "aucun fichier : lecture vide")
	SaveStore.write(path, {"v": 1})
	SaveStore.write(path, {"v": 2})
	_check(int(SaveStore.read(path)["v"]) == 2, "écriture puis relecture")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{tronqué")
	f.close()
	_check(int(SaveStore.read(path)["v"]) == 1, "fichier abîmé : repli sur la copie précédente")
	SaveStore.erase(path)

	var log: Array[Dictionary] = [
		{"t": "move", "unit": "tec", "dest": Vector2i(4, 5)},
		{"t": "act", "unit": "pro", "kind": "brace", "target": Vector2i(-1, -1)},
		{"t": "end"}
	]
	SaveStore.save_mission("m5_prix_signal", log, ["radio_silence"] as Array[String])
	var back := SaveStore.load_mission()
	_check(
		back["rules"] == ["radio_silence"],
		"les règles débloquées sont sauvegardées avec la mission"
	)
	_check(back["mission"] == "m5_prix_signal", "mission en cours retrouvée")
	_check(
		JSON.stringify(back["log"]) == JSON.stringify(log),
		"journal de commandes restitué à l'identique"
	)
	SaveStore.erase(SaveStore.MISSION)


func _apply(c: Campaign, replay: String) -> Dictionary:
	var played := _played(replay)
	return c.apply_mission(played[0], played[1])


## Rejoue un rejeu et renvoie [MissionDef, GameState] terminé.
func _played(replay: String) -> Array:
	var rep: Dictionary = MissionLoader.load_json(REPLAYS + replay + ".json")
	var def := MissionLoader.load_mission(MISSIONS + rep["mission"] + ".json")
	var g := GameState.new(def)
	for cmds: Array in rep["turns"]:
		g.start_turn()
		for cmd: Dictionary in cmds:
			if cmd.has("move"):
				g.move(cmd["unit"], Cells.parse(cmd["move"]))
			if cmd.has("act"):
				var t := Cells.parse(cmd["target"]) if cmd.has("target") else Vector2i(-1, -1)
				g.action(cmd["unit"], cmd["act"], t)
		if not g.result.is_empty():
			break
		g.end_player_turn()
		if not g.result.is_empty():
			break
	return [def, g]


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["OK " if ok else "KO ", what])
	if not ok:
		_failed += 1
