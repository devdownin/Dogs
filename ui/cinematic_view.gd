class_name CinematicView
extends Control
## Lecteur de cinématiques : plans illustrés animés lentement (zoom, panoramique), répliques
## d'ATHENA et journaux de l'équipage en texte progressif. Toucher : finir la réplique, puis
## passer à la suivante. « Passer » saute toute la cinématique.
##
## Les répliques portent des conditions évaluées sur la campagne (Campaign.check) : la même
## cinématique raconte ce que le joueur a réellement fait.

signal finished

const DIR := "res://data/cinematics/"
const IMAGES := "res://assets/cinematics/%s.webp"
const CHARS_PER_SECOND := 45.0
const SHOT_SECONDS := 14.0

var _shots: Array[Dictionary] = []  # plans retenus, répliques déjà filtrées
var _shot := -1
var _line := -1
var _frame: Control
var _image: TextureRect
var _card: Label
var _speaker: Label
var _text: Label
var _hint: Label
var _motion: Tween
var _typing: Tween


## Cinématique jouée après une mission, ou {} s'il n'y en a pas.
static func for_mission(mission_id: String) -> Dictionary:
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			var d: Dictionary = MissionLoader.load_json(DIR + f)
			if d.get("after_mission", "") == mission_id:
				return d
	return {}


static func by_id(id: String) -> Dictionary:
	return MissionLoader.load_json(DIR + id + ".json")


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("0b0d12")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_frame = Control.new()
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_image)
	_card = _label(40, Color("EADFC8"))
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_card)
	_speaker = _label(22, Color("2fe0c8"))
	add_child(_speaker)
	_text = _label(30, Color("EADFC8"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_text)
	_hint = _label(20, Color(1, 1, 1, 0.35))
	_hint.text = tr("UI_TAP_CONTINUE")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)
	var skip := Button.new()
	skip.text = tr("UI_SKIP")
	skip.custom_minimum_size = Vector2(160, 64)
	skip.add_theme_font_size_override("font_size", 24)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(-180, 24)
	skip.pressed.connect(_end)
	add_child(skip)
	resized.connect(_layout)


## Lance une cinématique. Renvoie faux si elle ne contient rien à dire pour cette campagne.
func play(cinematic: Dictionary, campaign: Campaign) -> bool:
	_shots.clear()
	for shot: Dictionary in cinematic.get("shots", []):
		var lines: Array[Dictionary] = []
		for ln: Dictionary in shot.get("lines", []):
			if campaign.check(ln.get("if", {})):
				lines.append(ln)
		if not lines.is_empty() or shot.has("card"):
			var kept := shot.duplicate()
			kept["lines"] = lines
			_shots.append(kept)
	if _shots.is_empty():
		return false
	visible = true
	_shot = -1
	_next_shot()
	return true


## Avance d'un cran : termine la réplique en cours, sinon passe à la suivante.
func advance() -> void:
	if _typing != null and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		return
	var lines: Array = _shots[_shot]["lines"]
	if _line + 1 < lines.size():
		_show_line(_line + 1)
	else:
		_next_shot()


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (
		(
			event is InputEventMouseButton
			and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT
		)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tap and visible and _shot >= 0:
		advance()
		accept_event()


func _next_shot() -> void:
	_shot += 1
	if _shot >= _shots.size():
		_end()
		return
	var shot := _shots[_shot]
	var is_card := shot.has("card")
	_frame.visible = not is_card
	_card.visible = is_card
	if is_card:
		_card.text = tr(shot["card"])
	else:
		_image.texture = load(IMAGES % shot["image"])
		_start_motion(shot.get("motion", "still"))
	_layout()
	_line = -1
	if (shot["lines"] as Array).is_empty():
		_speaker.text = ""
		_text.text = ""
	else:
		_show_line(0)


func _show_line(i: int) -> void:
	_line = i
	var ln: Dictionary = _shots[_shot]["lines"][i]
	var who: String = ln["speaker"]
	_speaker.text = "" if who == "card" else tr("SPEAKER_" + who.to_upper())
	_text.text = tr(ln["key"])
	_text.visible_ratio = 0.0
	if _typing != null:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(
		_text, "visible_ratio", 1.0, maxf(0.4, _text.text.length() / CHARS_PER_SECOND)
	)


## Mouvements de caméra lents sur l'image : la scène vit sans animation dessinée.
func _start_motion(kind: String) -> void:
	if _motion != null:
		_motion.kill()
	var from := {"scale": 1.08, "x": 0.0}
	var to := {"scale": 1.08, "x": 0.0}
	match kind:
		"push_in":
			from = {"scale": 1.0, "x": 0.0}
			to = {"scale": 1.18, "x": 0.0}
		"pull_out":
			from = {"scale": 1.18, "x": 0.0}
			to = {"scale": 1.0, "x": 0.0}
		"pan_left":
			from = {"scale": 1.15, "x": 0.06}
			to = {"scale": 1.15, "x": -0.06}
		"pan_right":
			from = {"scale": 1.15, "x": -0.06}
			to = {"scale": 1.15, "x": 0.06}
	_apply_motion(0.0, from, to)
	_motion = create_tween()
	_motion.tween_method(_apply_motion.bind(from, to), 0.0, 1.0, SHOT_SECONDS).set_trans(
		Tween.TRANS_SINE
	)


func _apply_motion(t: float, from: Dictionary, to: Dictionary) -> void:
	var side := _frame.size.x
	var sc: float = lerpf(from["scale"], to["scale"], t)
	var shift: float = lerpf(from["x"], to["x"], t) * side
	_image.size = Vector2(side, side) * sc
	_image.position = (Vector2(side, side) - _image.size) / 2.0 + Vector2(shift, 0)


func _layout() -> void:
	var w := size.x
	var top := 110.0
	_frame.position = Vector2(0, top)
	_frame.size = Vector2(w, minf(w, size.y * 0.55))
	_card.position = Vector2(40, size.y * 0.3)
	_card.size = Vector2(w - 80, size.y * 0.2)
	var y := top + _frame.size.y + 28.0
	if _card.visible:
		y = size.y * 0.55
	_speaker.position = Vector2(32, y)
	_speaker.size = Vector2(w - 64, 30)
	_text.position = Vector2(32, y + 40)
	_text.size = Vector2(w - 64, size.y - y - 120)
	_hint.position = Vector2(32, size.y - 70)
	_hint.size = Vector2(w - 64, 30)


func _end() -> void:
	if _motion != null:
		_motion.kill()
	if _typing != null:
		_typing.kill()
	visible = false
	_shot = -1
	finished.emit()


func _label(font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
