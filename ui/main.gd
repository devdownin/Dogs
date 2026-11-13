extends Control
## Scène jouable du prototype : carte, commande à trois touchers, intentions, combat,
## sauvegarde et écran d'ATHENA. Toute la logique de jeu est dans GameState et Campaign ;
## cette scène traduit des touchers en commandes et des événements en affichage.
##
## Sauvegarde : le journal de commandes de la mission est écrit après chaque commande,
## la campagne à chaque fin de mission et à chaque étude lancée. La reprise rejoue le
## journal : le cœur étant déterministe, l'état restitué est exact.

const MISSION_DIR := "res://data/missions/"
const MISSION_IDS: Array[String] = [
	"m1_sol_inconnu", "m2_echos_poussiere", "m3_couleur_de_trop", "m4_le_veilleur", "m5_prix_signal"
]
const NONE := Vector2i(-1, -1)

var def: MissionDef
var game: GameState
var campaign: Campaign
var selected := ""
var preview := NONE
var mode := ""  # "" ou "probe" (choix de la zone à sonder)
var show_danger := true
var reveal_all := false

var _mission_index := 0
var _log: Array[Dictionary] = []  # commandes jouées ; permet d'annuler en rejouant
var _events_seen := 0
var _countdown_labels: Dictionary[String, String] = {}
var _applied := false  # issue de mission déjà reportée sur la campagne
var _summary: Dictionary = {}
var _research: ResearchView
var _rules: Array[String] = []  # règles débloquées, figées pour la durée de la mission

var _box: VBoxContainer
var _board: BoardView
var _picker: OptionButton
var _status: Label
var _objective: Label
var _message: Label
var _actions: HFlowContainer
var _undo: Button
var _end_turn: Button
var _end_panel: PanelContainer
var _end_text: Label
var _next: Button


func _ready() -> void:
	campaign = SaveStore.load_campaign()
	_build_ui()
	if not _resume():
		load_mission(0)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		_save_mission()


## Reprend la mission sauvegardée. Faux si rien à reprendre ou si le journal ne se
## rejoue plus (données de mission modifiées depuis) : on repart alors d'une mission neuve.
func _resume() -> bool:
	var saved := SaveStore.load_mission()
	var index := MISSION_IDS.find(saved.get("mission", ""))
	if index < 0:
		return false
	load_mission(index)
	_rules.assign(saved.get("rules", []))
	_new_game()
	_consume_events()
	var log: Array[Dictionary] = saved["log"]
	for cmd in log:
		if not _apply(cmd):
			SaveStore.erase(SaveStore.MISSION)
			load_mission(index)
			return false
		_log.append(cmd)
	_consume_events()
	_message.text = tr("UI_RESUMED")
	_refresh()
	return true


func _save_mission() -> void:
	if game != null and game.result.is_empty() and not _log.is_empty():
		SaveStore.save_mission(MISSION_IDS[_mission_index], _log, _rules)


# ---------------------------------------------------------------- interface


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BoardView.FOG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	_box = box
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

	var top := HBoxContainer.new()
	box.add_child(top)
	_picker = OptionButton.new()
	_picker.custom_minimum_size.y = 64
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.item_selected.connect(load_mission)
	top.add_child(_picker)
	var athena := _button("UI_ATHENA", open_research)
	athena.custom_minimum_size.x = 150
	top.add_child(athena)
	_status = _label(26)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_status)

	_objective = _label(24)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_objective)

	_board = BoardView.new()
	_board.main = self
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.cell_tapped.connect(tap_cell)
	box.add_child(_board)

	_message = _label(24)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y = 100
	_message.add_theme_color_override("font_color", BoardView.IVORY)
	box.add_child(_message)

	_actions = HFlowContainer.new()
	_actions.custom_minimum_size.y = 96
	_actions.add_theme_constant_override("h_separation", 10)
	_actions.add_theme_constant_override("v_separation", 10)
	box.add_child(_actions)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	box.add_child(bottom)
	bottom.add_child(_toggle("UI_DANGER", true, _set_show_danger))
	bottom.add_child(_toggle("UI_DEBUG", false, _set_reveal_all))
	_undo = _button("UI_UNDO", undo)
	bottom.add_child(_undo)
	_end_turn = _button("UI_END_TURN", end_turn)
	_end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_end_turn)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_end_panel = PanelContainer.new()
	_end_panel.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14181d")
	style.border_color = BoardView.IVORY
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28)
	_end_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_end_panel)
	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 16)
	_end_panel.add_child(end_box)
	_end_text = _label(28)
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_box.add_child(_end_text)
	var end_buttons := HBoxContainer.new()
	end_buttons.add_theme_constant_override("separation", 10)
	end_box.add_child(end_buttons)
	var retry := _button("UI_RETRY", func() -> void: load_mission(_mission_index))
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_buttons.add_child(retry)
	_next = _button("UI_NEXT", func() -> void: load_mission(_mission_index + 1))
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_buttons.add_child(_next)
	var end_athena := _button("UI_ATHENA", open_research)
	end_athena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_buttons.add_child(end_athena)

	_research = ResearchView.new()
	_research.visible = false
	_research.closed.connect(func() -> void: _research.visible = false)
	_research.study_started.connect(func(_id: String) -> void: SaveStore.save_campaign(campaign))
	add_child(_research)


func open_research() -> void:
	_research.show_campaign(campaign)


## Garde l'interface hors des encoches et des barres système (plein écran sur Android).
## La zone sûre est donnée en pixels d'écran ; on la convertit en unités d'affichage.
func _apply_safe_area() -> void:
	const MARGIN := 12.0
	var inset := [0.0, 0.0, 0.0, 0.0]  # gauche, haut, droite, bas
	var win := Vector2(DisplayServer.window_get_size())
	if OS.has_feature("mobile") and win.x > 0.0 and win.y > 0.0:
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var k := get_viewport_rect().size / win
		inset = [
			safe.position.x * k.x,
			safe.position.y * k.y,
			(win.x - safe.end.x) * k.x,
			(win.y - safe.end.y) * k.y
		]
	_box.offset_left = MARGIN + maxf(inset[0], 0.0)
	_box.offset_top = MARGIN + maxf(inset[1], 0.0)
	_box.offset_right = -MARGIN - maxf(inset[2], 0.0)
	_box.offset_bottom = -MARGIN - maxf(inset[3], 0.0)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _button(key: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = tr(key)
	b.custom_minimum_size = Vector2(150, 96)  # 48 dp sur un écran de densité 2
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(on_pressed)
	return b


func _toggle(key: String, on: bool, on_toggled: Callable) -> Button:
	var b := _button(key, func() -> void: pass)
	b.toggle_mode = true
	b.button_pressed = on
	b.toggled.connect(on_toggled)
	return b


# ---------------------------------------------------------------- partie


func _set_show_danger(on: bool) -> void:
	show_danger = on
	_refresh()


func _set_reveal_all(on: bool) -> void:
	reveal_all = on
	_refresh()


func load_mission(index: int) -> void:
	_mission_index = clampi(index, 0, MISSION_IDS.size() - 1)
	def = MissionLoader.load_mission(MISSION_DIR + MISSION_IDS[_mission_index] + ".json")
	_picker.clear()
	for id in MISSION_IDS:
		_picker.add_item(id.substr(0, 2).to_upper())
	_picker.select(_mission_index)
	_picker.set_item_text(
		_mission_index, "M%d — %s" % [_mission_index + 1, tr(def.data["title_key"])]
	)
	_log.clear()
	_countdown_labels.clear()
	_rules = campaign.unlocked_rules()
	_applied = false
	_summary = {}
	_message.text = ""
	_new_game()
	var centroid := Vector2.ZERO
	for uid in game.units:
		centroid += Vector2(game.units[uid]["pos"]) + Vector2(0.5, 0.5)
	_board.reset_view(centroid / game.units.size())
	_consume_events()
	_refresh()


func _new_game() -> void:
	game = GameState.new(def, _rules)
	_events_seen = 0
	selected = ""
	preview = NONE
	mode = ""
	game.start_turn()


## Toucher une case : sélectionner un drone, prévisualiser un trajet, ou le confirmer.
func tap_cell(cell: Vector2i) -> void:
	if not game.result.is_empty():
		return
	if mode == "probe":
		_tap_probe(cell)
		return
	for uid in game.active_units():
		if game.units[uid]["pos"] == cell:
			selected = "" if selected == uid else uid
			preview = NONE
			_refresh()
			return
	if selected == "":
		return
	var reach := game.reachable(selected)
	if not reach.has(cell):
		preview = NONE
	elif preview == cell:
		_play({"t": "move", "unit": selected, "dest": cell})
		preview = NONE
	else:
		preview = cell
		_message.text = tr("UI_CONFIRM_MOVE") % reach[cell]
	_refresh()


## Ciblage de la Sonde : premier toucher = aperçu de la zone, second = lancement.
## Toucher hors de portée (ou le drone) annule le ciblage.
func _tap_probe(cell: Vector2i) -> void:
	if not game.probe_targets(selected).has(cell):
		mode = ""
		preview = NONE
		_message.text = ""
	elif preview == cell:
		_message.text = ""
		_play({"t": "act", "unit": selected, "kind": "probe", "target": cell})
		mode = ""
		preview = NONE
	else:
		preview = cell
		_message.text = tr("UI_PROBE_CONFIRM")
	_refresh()


func do_action(a: Dictionary) -> void:
	if a["kind"] == "probe":
		mode = "" if mode == "probe" else "probe"
		preview = NONE
		_message.text = tr("UI_PROBE_TARGET") % GameState.PROBE_RANGE if mode == "probe" else ""
		_refresh()
		return
	_play({"t": "act", "unit": selected, "kind": a["kind"], "target": a["target"]})
	_refresh()


func end_turn() -> void:
	if not game.result.is_empty():
		return
	selected = ""
	preview = NONE
	mode = ""
	_play({"t": "end"})
	_refresh()


## Annule le dernier déplacement s'il n'a rien révélé ni déclenché.
## L'état est reconstruit en rejouant le journal : le cœur est déterministe.
func undo() -> void:
	if _log.is_empty() or not _log[-1].get("undoable", false):
		return
	var keep := _log.slice(0, _log.size() - 1)
	var unit: String = _log[-1]["unit"]
	_log.clear()
	_new_game()
	for cmd in keep:
		_apply(cmd)
		_log.append(cmd)
	_events_seen = game.events.size()
	_save_mission()
	mode = ""
	selected = unit
	_message.text = ""
	_refresh()


func _play(cmd: Dictionary) -> void:
	var revealed := game.revealed.size()
	var observed := game.observed_guards.size()
	var events := game.events.size()
	if not _apply(cmd):
		_message.text = game.last_error
		return
	var scripted := false
	for i in range(events, game.events.size()):
		if game.events[i]["type"] in ["script_action", "mission_ended"]:
			scripted = true
	cmd["undoable"] = (
		cmd["t"] == "move"
		and not scripted
		and game.revealed.size() == revealed
		and game.observed_guards.size() == observed
	)
	_log.append(cmd)
	_consume_events()
	if game.result.is_empty():
		_save_mission()
	elif not _applied:
		_applied = true
		_summary = campaign.apply_mission(def, game)
		SaveStore.save_campaign(campaign)
		SaveStore.erase(SaveStore.MISSION)


func _apply(cmd: Dictionary) -> bool:
	match cmd["t"]:
		"move":
			return game.move(cmd["unit"], cmd["dest"])
		"act":
			return game.action(cmd["unit"], cmd["kind"], cmd["target"])
		"end":
			game.end_player_turn()
			if game.result.is_empty():
				game.start_turn()
			return true
	return false


# ---------------------------------------------------------------- affichage


func _summary_text() -> String:
	if _summary.is_empty():
		return ""
	var out := "\n"
	if int(_summary.get("doubt", -1)) >= 0:
		out += "\n" + tr("ATHENA_NOTE_%d" % _summary["doubt"]) + "\n"
	if _summary["data"] > 0 or _summary["materials"] > 0:
		out += "\n" + tr("UI_GAINS") % [_summary["data"], _summary["materials"]]
	if not (_summary["stage"] as String).is_empty():
		out += "\n" + tr("UI_NEW_STAGE") % tr("STAGE_" + (_summary["stage"] as String).to_upper())
	var names := PackedStringArray()
	for id: String in _summary["discoveries"]:
		names.append(tr(campaign.discovery_defs[id]["title_key"]))
	if not names.is_empty():
		out += "\n" + tr("UI_NEW_DISCOVERIES") % ", ".join(names)
	names = PackedStringArray()
	for id: String in _summary["confirmed"]:
		names.append(tr(campaign.hypotheses[id]["title_key"]))
	if not names.is_empty():
		out += "\n" + tr("UI_CONFIRMED") % ", ".join(names)
	return out


func _consume_events() -> void:
	var lines := PackedStringArray()
	for i in range(_events_seen, game.events.size()):
		var e := game.events[i]
		match e["type"]:
			"units_detected":
				var names := PackedStringArray()
				for c: Vector2i in e["cells"]:
					names.append(Cells.name_of(c))
				lines.append(tr("UI_DETECTED") % ", ".join(names))
			"unit_attacked":
				lines.append(tr("UI_HIT") % [e["unit"], e["damage"], e["guardian"]])
			"unit_disabled":
				lines.append(tr("UI_UNIT_DOWN") % e["unit"])
			"unit_silenced":
				lines.append(tr("UI_SILENCED") % e["unit"])
			"unit_reconnected":
				lines.append(tr("UI_RECONNECTED") % e["unit"])
			"guardian_neutralized":
				lines.append(tr("UI_GUARD_DOWN") % e["guardian"])
			"alert_changed":
				lines.append(tr("UI_ALERT_NOW") % tr("ALERT_" + (e["level"] as String).to_upper()))
			"script_action":
				var a: Dictionary = e["action"]
				match a["type"]:
					"show_tip":
						lines.append(tr(a["key"]))
					"dialogue":
						for ln: Dictionary in a["lines"]:
							lines.append(
								(
									"%s : %s"
									% [
										tr("SPEAKER_" + (ln["speaker"] as String).to_upper()),
										tr(ln["key"])
									]
								)
							)
					"start_countdown":
						_countdown_labels[a["id"]] = tr(a.get("label_key", ""))
	_events_seen = game.events.size()
	if not lines.is_empty():
		_message.text = "\n".join(lines)


func _refresh() -> void:
	var status := tr("UI_TURN") % game.turn
	if game.alert_enabled:
		status += "   " + tr("UI_ALERT") % tr("ALERT_" + game.alert_name().to_upper())
	for cid in game.countdowns:
		status += (
			"\n" + tr("UI_COUNTDOWN") % [_countdown_labels.get(cid, cid), game.countdowns[cid]]
		)
	_status.text = status
	_objective.text = tr(def.data["objectives"]["main"]["text_key"])
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()
	if selected != "" and game.units[selected]["status"] == "active":
		for a in game.available_actions(selected):
			var b := _button("UI_ACT_" + (a["kind"] as String).to_upper(), do_action.bind(a))
			if a["kind"] in ["attack", "repair"]:
				b.text += " " + Cells.name_of(a["target"])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if a["kind"] == "probe":
				b.toggle_mode = true
				b.set_pressed_no_signal(mode == "probe")
			_actions.add_child(b)
	else:
		selected = ""
		mode = ""
	_undo.disabled = _log.is_empty() or not _log[-1].get("undoable", false)
	_end_turn.disabled = not game.result.is_empty()
	_end_panel.visible = not game.result.is_empty()
	if _end_panel.visible:
		var text := (
			"%s\n%s\n"
			% [tr("UI_" + game.result.to_upper()), tr("UI_ENDED_TURN") % game.result_turn]
		)
		var recs := game.records()
		for r: Dictionary in def.data["objectives"]["records"]:
			var ok: bool = recs[r["id"]] and game.result == "victory"
			text += "\n%s  %s" % ["✔" if ok else "✘", tr(r["text_key"])]
		text += _summary_text()
		_end_text.text = text
		_next.visible = game.result == "victory" and _mission_index < MISSION_IDS.size() - 1
	_board.queue_redraw()
