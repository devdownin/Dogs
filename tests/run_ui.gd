extends SceneTree
## Joue la scène principale par touchers simulés, comme le ferait un joueur.
## Usage : godot --headless --path . -s tests/run_ui.gd [-- --shots dossier]

var main_scene: PackedScene = load("res://ui/main.tscn")
var _failed := 0
var _shots := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--shots":
		_shots = args[1]
	TranslationServer.set_locale("fr")
	_run.call_deferred()


func _run() -> void:
	SaveStore.erase(SaveStore.MISSION)
	SaveStore.erase(SaveStore.CAMPAIGN)
	var main: Control = (main_scene as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	# Mission 4, solution de référence, entièrement par touchers.
	main.load_mission(3)
	await _shot(main, "m4_tour1")
	_tap(main, "D10")
	_check(main.selected == "tec", "toucher un drone le sélectionne")
	_tap(main, "D7")
	_check(
		main.preview == Cells.parse("D7") and main.game.units["tec"]["pos"] == Cells.parse("D10"),
		"premier toucher : aperçu sans déplacement"
	)
	await _shot(main, "m4_apercu")
	_tap(main, "D7")
	_check(
		main.game.units["tec"]["pos"] == Cells.parse("D7"), "second toucher : déplacement confirmé"
	)

	main.end_turn()
	_tap(main, "D7")
	_tap(main, "D6")
	_tap(main, "D6")
	main.end_turn()
	_tap(main, "D6")
	_tap(main, "D3")
	_tap(main, "D3")
	main.end_turn()
	await _shot(main, "m4_tour4")
	_tap(main, "D3")
	_tap(main, "E2")
	_tap(main, "E2")
	var acts: Array = main.game.available_actions("tec")
	var kinds: Array = acts.map(func(a: Dictionary) -> String: return a["kind"])
	_check(kinds == ["interface", "brace"], "Interface et Se tapir proposés près de la balise")
	_check(main._actions.get_child_count() == acts.size(), "un bouton par action possible")
	main.do_action(acts[0])
	_check(
		main.game.result == "victory" and main.game.alert_max == 0,
		"M4 gagnée sans alerte par touchers"
	)
	_check(main._end_panel.visible, "le bilan de mission s'affiche")
	await _shot(main, "m4_bilan")

	# Mission 3 : le compte à rebours et l'avancée du territoire s'affichent.
	main.load_mission(2)
	main.reveal_all = true
	for step: Array in [["F10", "G8"], ["G8", "G5"], ["G5", "F5"]]:
		_tap(main, step[0])
		_tap(main, step[1])
		_tap(main, step[1])
		if step[1] != "F5":
			main.end_turn()
	main.do_action(main.game.available_actions("tec")[0])
	main.end_turn()
	_check(
		main.game.countdowns.has("closure") and "4" in main._status.text,
		"le compte à rebours est affiché"
	)
	_check(main.game.recolored.has(Cells.parse("A4")), "le territoire a avancé d'une ligne")
	await _shot(main, "m3_reaction")

	# Annulation : un aller-retour ne révèle rien au retour, il doit être annulable.
	main.load_mission(3)
	_tap(main, "C10")
	_tap(main, "C7")
	_tap(main, "C7")
	_check(main._undo.disabled, "un déplacement qui révèle des cases n'est pas annulable")
	_tap(main, "D10")
	_tap(main, "D9")
	_tap(main, "D9")
	_check(not main._undo.disabled, "un déplacement qui ne révèle rien est annulable")
	main.undo()
	_check(
		(
			main.game.units["tec"]["pos"] == Cells.parse("D10")
			and main.game.units["sc2"]["pos"] == Cells.parse("C7")
			and not main.game.units["tec"]["moved"]
		),
		"annuler rétablit la position et le droit de se déplacer, sans toucher au reste"
	)
	_check(main._undo.disabled, "on ne peut pas annuler deux fois")

	# Toucher une case hors de portée ne fait rien ; un trajet illégal n'est jamais joué.
	main.load_mission(0)
	_tap(main, "A7")
	_tap(main, "H1")
	_tap(main, "H1")
	_check(
		main.game.units["sc1"]["pos"] == Cells.parse("A7"), "une case hors de portée est ignorée"
	)
	await _shot(main, "m1_depart")

	await _test_zoom(main)
	await _test_probe(main)
	await _test_combat(main)
	main = await _test_resume(main)
	await _test_research(main)
	await _test_silence(main)
	await _test_m6(main)
	SaveStore.erase(SaveStore.MISSION)
	SaveStore.erase(SaveStore.CAMPAIGN)

	print("%d échec(s)" % _failed)
	quit(1 if _failed > 0 else 0)


func _test_zoom(main: Control) -> void:
	var board: BoardView = main._board
	main.reveal_all = false
	main.load_mission(3)
	await process_frame
	await process_frame
	var cs0 := board.cell_size()
	print("   (vue %s, carte %s)" % [root.get_visible_rect().size, board.size])
	_check(
		cs0 >= 90.0 and cs0 <= 100.0,
		"zoom initial : case de %d unités (≈ 48 dp visés)" % roundi(cs0)
	)
	_check(board.is_visible_cell(Cells.parse("D10")), "la vue initiale montre les drones")

	# Un toucher bref sur une case sélectionne bien le drone qui s'y trouve.
	_gesture_tap(board, Cells.parse("D10"))
	_check(main.selected == "tec", "toucher bref : case correcte (D10)")
	_gesture_tap(board, Cells.parse("D10"))

	# Glisser déplace la carte sans toucher de case.
	var cam0 := board._cam
	var p := board.cell_rect(Cells.parse("E9")).get_center()
	_mouse(board, p, true)
	for i in 6:
		_motion(board, p + Vector2(0, 40.0 * (i + 1)), Vector2(0, 40))
	_mouse(board, p + Vector2(0, 240), false)
	_check(board._cam.y < cam0.y and main.selected == "", "glisser fait défiler sans sélectionner")
	_check(
		board.is_visible_cell(Cells.parse("E1")),
		"le défilement permet d'atteindre le nord de la carte"
	)

	# Le défilement est borné : impossible de perdre la carte.
	for i in 30:
		board.pan_by(Vector2(0, 400))
	_check(board.origin().y >= -1.0 and board.origin().y <= 1.0, "défilement borné au bord nord")

	# Pincer : deux doigts qui s'écartent zooment, sans toucher de case.
	var cs1 := board.cell_size()
	var c := board.size / 2.0
	_touch(board, 0, c - Vector2(50, 0), true)
	_touch(board, 1, c + Vector2(50, 0), true)
	_drag(board, 1, c + Vector2(150, 0))
	_touch(board, 1, c + Vector2(150, 0), false)
	_mouse(board, c - Vector2(50, 0), false)
	_touch(board, 0, c - Vector2(50, 0), false)
	_check(
		board.cell_size() > cs1 * 1.3 and main.selected == "",
		"pincer zoome (%d → %d) sans sélectionner" % [roundi(cs1), roundi(board.cell_size())]
	)
	_check(board.cell_size() <= BoardView.MAX_CELL, "zoom maximal respecté")

	# Molette : dézoom jusqu'à voir toute la carte, puis plus loin c'est bloqué.
	for i in 20:
		board.zoom_at(1.0 / BoardView.WHEEL_STEP, c)
	_check(
		is_equal_approx(board.cell_size(), board.min_cell()),
		"zoom minimal = carte entière (%d)" % roundi(board.cell_size())
	)
	_check(
		board.is_visible_cell(Cells.parse("A1")) and board.is_visible_cell(Cells.parse("J10")),
		"au zoom minimal, tout est visible"
	)

	# Après zoom, le toucher vise toujours la bonne case.
	board.zoom_at(1.8, board.cell_rect(Cells.parse("F2")).get_center())
	_check(
		board.cell_at(board.cell_rect(Cells.parse("F2")).get_center()) == Cells.parse("F2"),
		"après zoom centré sur F2, F2 reste sous le doigt"
	)
	await _shot(main, "m4_zoom")


func _test_probe(main: Control) -> void:
	main.load_mission(3)
	_tap(main, "D10")
	_tap(main, "D7")
	_tap(main, "D7")
	_tap(main, "B10")
	_tap(main, "D8")
	_tap(main, "D8")
	main.end_turn()
	_check(not main.game.observed_guards.has("sen1"), "Sentinelle non observée avant la Sonde")
	_tap(main, "D8")
	_tap(main, "E6")
	_tap(main, "E6")
	var acts: Array = main.game.available_actions("sc1")
	var probe: Dictionary = {}
	for a: Dictionary in acts:
		if a["kind"] == "probe":
			probe = a
	_check(not probe.is_empty(), "le bouton Sonde est proposé à l'Éclaireur")
	main.do_action(probe)
	_check(main.mode == "probe", "Sonde : mode ciblage")
	main._board.center_on(Cells.parse("E3"))
	_tap(main, "E1")
	_check(
		main.mode == "probe" and main.preview == Cells.parse("E1"),
		"premier toucher : aperçu de la zone"
	)
	await _shot(main, "m4_sonde_apercu")
	_tap(main, "E1")
	_check(
		main.game.probed.has(Cells.parse("F2")) and main.game.observed_guards.has("sen1"),
		"second toucher : zone sondée, Sentinelle observée"
	)
	_check(main.game.units["sc1"]["acted"] and main.mode == "", "la Sonde consomme l'action")
	_check(
		not main._message.text.begins_with(tr("UI_PROBE_CONFIRM").left(10)),
		"le message de confirmation disparaît après le lancement"
	)
	_check(main.game.intents()["watched"].size() > 0, "les intentions de la Sentinelle s'affichent")
	await _shot(main, "m4_sonde")

	# Hors de portée : le ciblage est annulé, rien n'est consommé.
	_tap(main, "C10")
	main.do_action({"kind": "probe", "target": Vector2i(-1, -1), "feature": ""})
	_tap(main, "J1")
	_check(
		main.mode == "" and not main.game.units["sc2"]["acted"],
		"toucher hors de portée annule le ciblage"
	)

	main.end_turn()
	_check(main.game.probed.is_empty(), "la zone sondée s'efface au tour suivant")


func _gesture_tap(board: BoardView, cell: Vector2i) -> void:
	var p := board.cell_rect(cell).get_center()
	_mouse(board, p, true)
	_mouse(board, p, false)


func _mouse(board: BoardView, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	board._gui_input(e)


func _motion(board: BoardView, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	board._gui_input(e)


func _touch(board: BoardView, index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	board._gui_input(e)
	if index == 0 and pressed:
		_mouse(board, pos, true)  # émulation souris du premier doigt, comme sur Android


func _drag(board: BoardView, index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	board._gui_input(e)


## Mission 5 : le Protecteur tient le relais, les coups annoncés sont ceux portés.
func _test_combat(main: Control) -> void:
	main.load_mission(4)
	main.reveal_all = false
	for cmd: Dictionary in [
		{"t": "move", "unit": "tec", "dest": "E8"},
		{"t": "move", "unit": "pro", "dest": "E7"},
		{"t": "move", "unit": "sc1", "dest": "C6"},
		{"t": "move", "unit": "sc2", "dest": "G7"},
		{"t": "end"},
		{"t": "move", "unit": "pro", "dest": "E5"},
		{"t": "act", "unit": "pro", "kind": "brace", "target": "-"},
		{"t": "move", "unit": "tec", "dest": "E6"},
		{"t": "act", "unit": "tec", "kind": "interface", "target": "E5"},
		{"t": "end"}
	]:
		var c := cmd.duplicate()
		if c.has("dest"):
			c["dest"] = Cells.parse(c["dest"])
		if c.has("target"):
			c["target"] = Vector2i(-1, -1) if c["target"] == "-" else Cells.parse(c["target"])
		main._play(c)
	main.selected = "tec"
	main._refresh()
	var acts: Array = main.game.available_actions("tec")
	var kinds: Array = acts.map(func(a: Dictionary) -> String: return a["kind"])
	_check(kinds.has("repair"), "le Technicien peut réparer le Protecteur blessé")
	var announced: Array = main.game.intents()["attacks"]
	_check(announced.size() == 2, "deux coups annoncés contre le relais")
	await _shot(main, "m5_coups_annonces")
	var before: int = main.game.units["pro"]["hp"]
	main.do_action(acts[kinds.find("repair")])
	_check(main.game.units["pro"]["hp"] == before + 1, "réparer rend 1 point d'intégrité")
	var expected: int = before + 1
	for at: Dictionary in main.game.intents()["attacks"]:
		if at["unit"] == "pro":
			expected -= int(at["damage"])
	main.end_turn()
	_check(main.game.units["pro"]["hp"] == expected, "les coups portés sont ceux annoncés")


## Quitter l'application en pleine mission puis la relancer restitue la partie exacte.
func _test_resume(main: Control) -> Control:
	main.load_mission(3)
	_tap(main, "D10")
	_tap(main, "D7")
	_tap(main, "D7")
	main.end_turn()
	_tap(main, "C10")
	_tap(main, "C8")
	_tap(main, "C8")
	var before := JSON.stringify(
		[main.game.turn, main.game.units, main.game.guards, main.game.revealed.keys()]
	)
	var could_undo: bool = not main._undo.disabled
	main.queue_free()
	await process_frame
	var again: Control = (main_scene as PackedScene).instantiate()
	root.add_child(again)
	await process_frame
	var after := JSON.stringify(
		[again.game.turn, again.game.units, again.game.guards, again.game.revealed.keys()]
	)
	_check(
		again._mission_index == 3 and after == before, "relance : la mission reprend à l'identique"
	)
	_check((not again._undo.disabled) == could_undo, "relance : le droit d'annuler est conservé")
	return again


## Écran d'ATHENA après deux missions : pistes visibles, étude lancée et sauvegardée.
func _test_research(main: Control) -> void:
	var c: Campaign = main.campaign
	c.discoveries["sample_rock"] = true
	c.discoveries["sample_recolored_soil"] = true
	c.discoveries["obs_sentinel_cycle"] = true
	c.ship_stage = "observation"
	c.data = 9
	main.open_research()
	await _shot(main, "athena")
	_check(main._research.visible, "l'écran d'ATHENA s'ouvre")
	main._research._study("ing_1")
	_check(c.studying.has("ing_1") and c.data == 6, "étudier depuis l'écran coûte les Données")
	var saved := SaveStore.load_campaign()
	_check(saved.studying.has("ing_1"), "l'étude lancée est sauvegardée")
	await _shot(main, "athena_etude")
	main._research.closed.emit()
	_check(not main._research.visible, "retour à la carte")


## Silence radio, une fois l'hypothèse confirmée : le drone disparaît des intentions.
func _test_silence(main: Control) -> void:
	var c: Campaign = main.campaign
	c.discoveries["obs_signal_hunt"] = true
	c.confirmed["obs_5"] = true
	main.open_research()
	await _shot(main, "athena_doute")
	main._research.closed.emit()
	main.load_mission(3)
	_tap(main, "D10")
	_tap(main, "D7")
	_tap(main, "D7")
	var kinds: Array = main.game.available_actions("tec").map(
		func(a: Dictionary) -> String: return a["kind"]
	)
	_check(kinds.has("silence"), "« Silence radio » proposé une fois débloqué")
	main.do_action({"kind": "silence", "target": Vector2i(-1, -1)})
	_check(main.game.units["tec"]["silent"], "le Technicien coupe sa liaison")
	main.end_turn()
	_tap(main, "D7")
	_tap(main, "D6")
	_tap(main, "D6")
	main.end_turn()
	main.selected = "tec"
	main._refresh()
	kinds = main.game.available_actions("tec").map(func(a: Dictionary) -> String: return a["kind"])
	_check(kinds == ["reconnect"], "en silence, seule la reconnexion est possible")
	await _shot(main, "m4_silence")
	main.end_turn()
	_check(
		main.game.alert == 0, "en silence, attendre sous le regard de la Sentinelle ne trahit pas"
	)


## Mission 6 : essai de silence radio accordé par la mission, Impulsion de l'Intercepteur.
func _test_m6(main: Control) -> void:
	main.campaign.confirmed.erase("obs_5")
	main.load_mission(5)
	_check(main.game.rules.has("radio_silence"), "M6 accorde le silence radio pour la mission")
	var rep: Dictionary = MissionLoader.load_json("res://data/replays/m6_reference.json")
	var turns: Array = rep["turns"]
	for t in 7:
		for c: Dictionary in turns[t]:
			if c.has("move"):
				main._play({"t": "move", "unit": c["unit"], "dest": Cells.parse(c["move"])})
			if c.has("act"):
				var target := Cells.parse(c["target"]) if c.has("target") else Vector2i(-1, -1)
				main._play({"t": "act", "unit": c["unit"], "kind": c["act"], "target": target})
		if t < 6:
			main._play({"t": "end"})
	_check(main.game.guards["pat2"]["stunned"], "l'Impulsion fige le Patrouilleur")
	_check(main.game.interacted.has("archive"), "la base est ouverte sous couvert de l'Impulsion")
	main.reveal_all = true
	main._refresh()
	await _shot(main, "m6_impulsion")
	main.reveal_all = false
	main.load_mission(5)
	main._play({"t": "end"})
	main._play({"t": "move", "unit": "int", "dest": Cells.parse("D8")})
	_check(main.game.units["int"]["elan"], "trois cases en ligne droite donnent l'Élan")
	main.selected = "int"
	main._refresh()
	await _shot(main, "m6_elan")


func _tap(main: Control, cell: String) -> void:
	main.tap_cell(Cells.parse(cell))


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["OK " if ok else "KO ", what])
	if not ok:
		_failed += 1


func _shot(main: Control, name: String) -> void:
	if _shots.is_empty():
		return
	main._refresh()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [_shots, name])
