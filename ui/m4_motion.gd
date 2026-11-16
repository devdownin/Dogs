class_name M4Motion
extends RefCounted
## État de présentation uniquement. Les commandes et la visibilité restent instantanées.

const FPS := 12.0
const STEP_SECONDS := 0.24
const DRONE_STEP_SECONDS := {"scout": 0.36, "technician": 0.48}
const DRONE_WALK_FRAMES := 12
const DRONE_CYCLES_PER_CELL := 2.0
const DRONE_EASE_CELLS := 0.24
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
var _directions: Dictionary[String, Vector2i] = {}
var _clock := 0.0


func load_sheets() -> void:
	for kind: String in TYPES:
		var extra_walk_frames := _extra_walk_frames(kind)
		_load_sheet(kind, extra_walk_frames)
		if kind != "sentinel":
			_load_sheet(kind + "_n", extra_walk_frames)
			_load_sheet(kind + "_s", extra_walk_frames)


func _extra_walk_frames(kind: String) -> int:
	return DRONE_WALK_FRAMES - CLIPS["walk"].y if DRONE_STEP_SECONDS.has(kind) else 0


func _load_sheet(name: String, extra_walk_frames: int) -> void:
	var sheet: Texture2D = load("res://assets/units/m4_motion/" + name + ".png")
	if sheet == null:
		return
	var frames: Array[Texture2D] = []
	var end: Vector2i = CLIPS["disabled"]
	for index in end.x + end.y + extra_walk_frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		var col := posmod(index, SHEET_COLUMNS)
		var row := floori(float(index) / SHEET_COLUMNS)
		atlas.region = Rect2(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
		atlas.filter_clip = true
		frames.append(atlas)
	_frames[name] = frames


func reset() -> void:
	_moves.clear()
	_actions.clear()
	_directions.clear()
	_clock = 0.0


func advance(delta: float) -> bool:
	if reduced:
		return false
	var frame := floori(_clock * FPS)
	_clock += delta
	var redraw := floori(_clock * FPS) != frame
	for id: String in _moves.keys():
		var route := _moves[id]
		if _clock >= float(route["end"]):
			var cells: Array = route["cells"]
			_face(id, cells[-1] - cells[-2])
			_moves.erase(id)
			redraw = true
		elif route["drone"]:
			redraw = true  # La translation est continue, même entre deux poses.
	return redraw


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
			var kind: String = actors[id]["type"]
			if not TYPES.has(kind):
				return
			if guard:
				# Ne jamais révéler via l'animation un itinéraire sous le brouillard.
				if not game.current_vision.has(before[id]):
					return
				for cell: Vector2i in path:
					if not game.current_vision.has(cell):
						_moves.erase(id)
						return
			var cells: Array = [before[id]] + path
			var seconds: float = DRONE_STEP_SECONDS.get(kind, STEP_SECONDS)
			_moves[id] = {
				"cells": cells,
				"start": _clock,
				"end": _clock + path.size() * seconds,
				"step_seconds": seconds,
				"drone": DRONE_STEP_SECONDS.has(kind)
			}
			_face(id, path[0] - before[id])
		"probe_launched", "feature_activated", "unit_braced":
			var id: String = event["unit"]
			_act(id, "action", _moves.get(id, {}).get("end", _clock))
		"guardian_turned":
			_act(event["guardian"], "action")
		"unit_attacked":
			_act(event["guardian"], "action")
			_act(event["unit"], "hit")
		"unit_disabled":
			_moves.erase(event["unit"])
			_act(event["unit"], "disabled")
		"unit_repaired":
			_actions.erase(event["unit"])
		"unit_extracted":
			_moves.erase(event["unit"])
			_actions.erase(event["unit"])


func _act(id: String, clip: String, start := -1.0) -> void:
	_actions[id] = {"clip": clip, "start": maxf(_clock, start)}


func _face(id: String, direction: Vector2i) -> void:
	_directions[id] = direction


func position(id: String, final_cell: Vector2i) -> Vector2:
	if not _moves.has(id):
		return Vector2(final_cell)
	var motion := _moves[id]
	var cells: Array = motion["cells"]
	var distance := _route_progress(motion)
	var step := mini(floori(distance), cells.size() - 2)
	_face(id, cells[step + 1] - cells[step])
	return Vector2(cells[step]).lerp(Vector2(cells[step + 1]), distance - step)


func _route_progress(motion: Dictionary) -> float:
	var last: float = motion["cells"].size() - 1
	var distance := clampf(
		(_clock - float(motion["start"])) / float(motion["step_seconds"]), 0, last
	)
	if not motion["drone"]:
		return distance
	if distance < DRONE_EASE_CELLS:
		return _ease_endpoint(distance)
	if last - distance < DRONE_EASE_CELLS:
		return last - _ease_endpoint(last - distance)
	return distance


func _ease_endpoint(distance: float) -> float:
	var t := distance / DRONE_EASE_CELLS
	return DRONE_EASE_CELLS * t * t * (2.0 - t)


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
		var action_age := _clock - float(action["start"])
		var action_clip: String = action["clip"]
		if floori(action_age * FPS) >= CLIPS[action_clip].y:
			_actions.erase(id)
		elif action_age >= 0.0:
			clip = action_clip
			age = action_age
	var extra_walk_frames := _extra_walk_frames(kind)
	var frame_position := age * FPS
	if clip == "idle" and _moves.has(id):
		clip = "walk"
		var motion := _moves[id]
		frame_position = (_clock - float(motion["start"])) * FPS
		if motion["drone"]:
			frame_position = _route_progress(motion) * DRONE_CYCLES_PER_CELL * DRONE_WALK_FRAMES
	var clip_range: Vector2i = CLIPS[clip]
	if clip == "walk":
		clip_range.y += extra_walk_frames
	elif clip != "idle":
		clip_range.x += extra_walk_frames
	var index := floori(frame_position)
	if clip in ["idle", "walk"]:
		index = posmod(index, clip_range.y)
	else:
		index = mini(index, clip_range.y - 1)
	var sheet := kind
	match _directions.get(id, Vector2i.ZERO):
		Vector2i.UP:
			sheet += "_n"
		Vector2i.DOWN:
			sheet += "_s"
	var frames: Array = _frames.get(sheet, _frames[kind])
	return frames[clip_range.x + index]


func mirrored(id: String, kind: String) -> bool:
	var direction: Vector2i = _directions.get(id, Vector2i.ZERO)
	return kind != "sentinel" and direction.x > 0
