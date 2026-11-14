class_name M4Motion
extends RefCounted
## État de présentation uniquement. Les commandes et la visibilité restent instantanées.

const FPS := 12.0
const STEP_SECONDS := 0.24
const FRAME_SIZE := 288
const SHEET_COLUMNS := 6
const TYPES := ["scout", "technician", "sentinel", "patroller"]
const CLIPS := {
	"idle": Vector2i(0, 8),
	"walk": Vector2i(8, 8),
	"action": Vector2i(16, 8),
	"hit": Vector2i(24, 4),
	"disabled": Vector2i(28, 7)
}

var reduced := false

var _frames: Dictionary[String, Array] = {}
var _moves: Dictionary[String, Dictionary] = {}
var _actions: Dictionary[String, Dictionary] = {}
var _mirrors: Dictionary[String, bool] = {}
var _clock := 0.0


func load_sheets() -> void:
	for kind: String in TYPES:
		var sheet: Texture2D = load("res://assets/units/m4_motion/" + kind + ".png")
		if sheet == null:
			continue
		var frames: Array[Texture2D] = []
		var end: Vector2i = CLIPS["disabled"]
		for index in end.x + end.y:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			var col := posmod(index, SHEET_COLUMNS)
			var row := floori(float(index) / SHEET_COLUMNS)
			atlas.region = Rect2(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
			atlas.filter_clip = true
			frames.append(atlas)
		_frames[kind] = frames


func reset() -> void:
	_moves.clear()
	_actions.clear()
	_mirrors.clear()
	_clock = 0.0


func advance(delta: float) -> bool:
	if reduced:
		return false
	var frame := floori(_clock * FPS)
	_clock += delta
	return floori(_clock * FPS) != frame


func set_reduced(enabled: bool) -> void:
	reduced = enabled
	reset()


func consume(event: Dictionary, game: GameState, before: Dictionary) -> void:
	if reduced:
		return
	match event["type"]:
		"unit_moved", "guardian_moved":
			var guard: bool = event["type"] == "guardian_moved"
			var id: String = event["guardian"] if guard else event["unit"]
			var actors := game.guards if guard else game.units
			var path: Array = event["path"]
			if path.is_empty() or not before.has(id) or not actors.has(id):
				return
			if not TYPES.has(actors[id]["type"]):
				return
			if guard:
				# Ne jamais révéler via l'animation un itinéraire sous le brouillard.
				if not game.current_vision.has(before[id]):
					return
				for cell: Vector2i in path:
					if not game.current_vision.has(cell):
						_moves.erase(id)
						return
			_moves[id] = {"cells": [before[id]] + path, "start": _clock}
			_face(id, path[0] - before[id])
		"probe_launched", "feature_activated", "unit_braced":
			_act(event["unit"], "action")
		"guardian_turned":
			_act(event["guardian"], "action")
		"unit_attacked":
			_act(event["guardian"], "action")
			_act(event["unit"], "hit")
		"unit_disabled":
			_act(event["unit"], "disabled")
		"unit_repaired":
			_actions.erase(event["unit"])


func _act(id: String, clip: String) -> void:
	_actions[id] = {"clip": clip, "start": _clock}


func _face(id: String, direction: Vector2i) -> void:
	if direction.x != 0:
		_mirrors[id] = direction.x > 0


func position(id: String, final_cell: Vector2i) -> Vector2:
	if not _moves.has(id):
		return Vector2(final_cell)
	var motion := _moves[id]
	var cells: Array = motion["cells"]
	var phase := (_clock - float(motion["start"])) / STEP_SECONDS
	var step := floori(phase)
	if step >= cells.size() - 1:
		_face(id, cells[-1] - cells[-2])
		_moves.erase(id)
		return Vector2(final_cell)
	_face(id, cells[step + 1] - cells[step])
	return Vector2(cells[step]).lerp(Vector2(cells[step + 1]), phase - step)


func frame_for(id: String, kind: String, disabled: bool) -> Texture2D:
	if not _frames.has(kind):
		return null
	var clip := "idle"
	var age := _clock
	if disabled:
		clip = "disabled"
		age = FPS
		if _actions.has(id) and _actions[id]["clip"] == "disabled":
			age = _clock - float(_actions[id]["start"])
	elif _actions.has(id):
		var action := _actions[id]
		age = _clock - float(action["start"])
		var action_clip: String = action["clip"]
		if floori(age * FPS) < CLIPS[action_clip].y:
			clip = action_clip
		else:
			_actions.erase(id)
	if clip == "idle" and _moves.has(id):
		clip = "walk"
		age = _clock - float(_moves[id]["start"])
	var clip_range: Vector2i = CLIPS[clip]
	var index := floori(age * FPS)
	if clip in ["idle", "walk"]:
		index = posmod(index, clip_range.y)
	else:
		index = mini(index, clip_range.y - 1)
	return _frames[kind][clip_range.x + index]


func mirrored(id: String, kind: String) -> bool:
	return kind != "sentinel" and _mirrors.get(id, false)
