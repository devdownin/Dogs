class_name CombatFeedback
extends Node2D
## Transient map feedback. Combat commands resolve before this node receives their events.

const DAMAGE := Color("f4eee2")
const REPAIR := Color("79e6c2")
const MAX_EFFECTS := 24
const SOUNDS := {
	"pack_shot": preload("res://assets/audio/combat/pack_shot.wav"),
	"guardian_shot": preload("res://assets/audio/combat/guardian_shot.wav"),
	"strike": preload("res://assets/audio/combat/strike.wav"),
	"impact": preload("res://assets/audio/combat/impact.wav"),
	"shield": preload("res://assets/audio/combat/shield.wav"),
	"repair": preload("res://assets/audio/combat/repair.wav"),
	"impulse": preload("res://assets/audio/combat/impulse.wav"),
	"shutdown": preload("res://assets/audio/combat/shutdown.wav")
}

var board: BoardView
var reduced := false
var muted := false:
	set(value):
		muted = value
		if muted:
			_stop_audio()

var _effects: Array[Dictionary] = []
var _voices: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in 6:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -7.0
		add_child(voice)
		_voices.append(voice)
	set_process(false)


func clear() -> void:
	_effects.clear()
	_stop_audio()
	queue_redraw()
	set_process(false)


func present(events: Array[Dictionary], first: int, game: GameState, command: Dictionary) -> void:
	var impact_at: Dictionary[Vector2i, float] = {}
	var incoming := 0
	for i in range(first, events.size()):
		var event := events[i]
		var kind: String = event["type"]
		var unit: Dictionary = game.units.get(event.get("unit", ""), {})
		var guardian: Dictionary = game.guards.get(event.get("guardian", ""), {})
		var cell: Vector2i = unit.get("pos", GameState.NO_CELL)
		if kind in ["guardian_damaged", "guardian_neutralized", "guardian_stunned"]:
			# Une cible neutralisée a déjà été retirée de l'état.
			cell = guardian.get("pos", command.get("target", GameState.NO_CELL))
		if cell == GameState.NO_CELL:
			continue
		match kind:
			"guardian_damaged", "unit_attacked":
				var hostile := kind == "unit_attacked"
				var attacker := guardian if hostile else unit
				var source: Vector2i = attacker.get("pos", GameState.NO_CELL)
				var ranged: bool = attacker.get("type", "") in ["sentinel", "interceptor"]
				var delay := minf(incoming * 0.14, 0.28) if hostile else 0.0
				if hostile:
					incoming += 1
				if source != GameState.NO_CELL and (not hostile or game.current_vision.has(source)):
					var flight := 0.16 if ranged else 0.10
					var accent := BoardView.GUARD if hostile else BoardView.PACK
					var shot := "guardian_shot" if hostile else "pack_shot"
					_add(
						"shot" if ranged else "strike",
						source,
						cell,
						accent,
						delay,
						flight,
						shot if ranged else "strike"
					)
					delay += flight
				impact_at[cell] = delay
				_add("impact", cell, cell, DAMAGE, delay, 0.55, "impact", "−%d" % event["damage"])
			"unit_damaged":
				impact_at[cell] = 0.0
				var damage: int = game.advance.get("damage", 1)
				_add("impact", cell, cell, DAMAGE, 0.0, 0.55, "impact", "−%d" % damage)
			"guardian_neutralized", "unit_disabled":
				var delay: float = impact_at.get(cell, 0.0)
				var accent := BoardView.GUARD if kind == "guardian_neutralized" else DAMAGE
				_add("shutdown", cell, cell, accent, delay + 0.08, 0.62, "shutdown")
			"unit_braced", "rampart_raised":
				var shield := "rampart" if kind == "rampart_raised" else "brace"
				_add(shield, cell, cell, BoardView.PACK, 0.0, 0.40, "shield")
			"unit_repaired":
				var technician: Dictionary = game.units.get(command.get("unit", ""), {})
				_add("repair", technician.get("pos", cell), cell, REPAIR, 0.0, 0.51, "repair", "+1")
			"guardian_stunned":
				_add("impulse", unit.get("pos", cell), cell, BoardView.IVORY, 0.0, 0.43, "impulse")


func _add(
	kind: String,
	source: Vector2i,
	cell: Vector2i,
	color: Color,
	delay: float,
	duration: float,
	cue: String,
	label := ""
) -> void:
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	_effects.append(
		{
			"kind": kind,
			"source": source,
			"cell": cell,
			"color": color,
			"age": -delay,
			"duration": duration,
			"cue": cue,
			"label": label
		}
	)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var played := {}
	for i in range(_effects.size() - 1, -1, -1):
		var effect := _effects[i]
		effect["age"] += delta
		var cue: String = effect["cue"]
		if effect["age"] >= 0.0 and not cue.is_empty():
			if not muted and not played.has(cue):
				_play_sound(cue)
				played[cue] = true
			effect["cue"] = ""
		if effect["age"] >= effect["duration"]:
			_effects.remove_at(i)
	queue_redraw()
	set_process(not _effects.is_empty())


func _play_sound(cue: String) -> void:
	for voice in _voices:
		if not voice.playing:
			voice.stream = SOUNDS[cue]
			voice.play()
			return


func _stop_audio() -> void:
	for voice in _voices:
		voice.stop()


func _draw() -> void:
	if reduced:
		return
	var s := board.cell_size()
	for effect in _effects:
		if effect["age"] < 0.0:
			continue
		var t: float = effect["age"] / effect["duration"]
		var offset := Vector2.UP * s * 0.12
		var origin := board.cell_rect(effect["source"]).get_center() + offset
		var target := board.cell_rect(effect["cell"]).get_center() + offset
		var color: Color = effect["color"]
		var fade := 1.0 - t
		match effect["kind"]:
			"shot":
				var head := origin.lerp(target, t)
				var tail := origin.lerp(target, maxf(0.0, t - 0.27))
				draw_line(tail, head, Color(color, 0.26), s * 0.15, true)
				draw_line(tail, head, color, maxf(2.0, s * 0.047), true)
				draw_circle(head, s * 0.053, DAMAGE, true, -1.0, true)
			"strike":
				var axis := (target - origin).angle()
				var center := origin.lerp(target, minf(1.0, t * 1.2))
				draw_arc(
					center,
					s * 0.26,
					axis - 0.96,
					axis + 0.96,
					16,
					Color(color, fade),
					maxf(2.0, s * 0.09),
					true
				)
			"impact":
				_ring(target, s * lerpf(0.08, 0.48, t), color, fade * 0.85, s)
				if t < 0.23:
					draw_circle(target, s * (0.20 - t * 0.4), Color(color, 1.0 - t * 4.0))
				_sparks(target, s, t, color, 8)
			"shutdown":
				var dust := Color("a29891")
				_ring(target, s * lerpf(0.12, 0.53, t), color, fade * 0.7, s)
				_sparks(target, s, t, dust, 11)
				draw_circle(
					target + Vector2.DOWN * s * 0.12,
					s * (0.1 + t * 0.42),
					Color(dust, fade * 0.18),
					true,
					-1.0,
					true
				)
			"brace", "rampart":
				var radius := s * (0.50 if effect["kind"] == "rampart" else 0.34)
				for i in 4:
					var angle := i * TAU / 4.0 - PI / 4.0
					draw_arc(
						target,
						radius,
						angle - 0.54,
						angle + 0.54,
						12,
						Color(color, fade),
						maxf(2.0, s * 0.04),
						true
					)
			"repair":
				draw_dashed_line(origin, target, Color(color, fade), maxf(2.0, s * 0.028), s * 0.07)
				_ring(target, s * lerpf(0.42, 0.18, t), color, fade, s)
				_sparks(target, s * 0.55, 1.0 - t, Color(color, fade), 6)
			"impulse":
				var pulse := origin.lerp(target, minf(1.0, t * 2.5))
				_ring(pulse, s * (0.13 + t * 0.31), color, fade, s)
				_ring(pulse, s * (0.07 + t * 0.19), color, fade * 0.55, s)
		var label: String = effect["label"]
		if not label.is_empty():
			_label(target, s, t, label, color)


func _ring(center: Vector2, radius: float, color: Color, alpha: float, s: float) -> void:
	draw_arc(center, radius, 0.0, TAU, 24, Color(color, alpha), maxf(1.5, s * 0.032), true)


func _sparks(center: Vector2, s: float, t: float, color: Color, count: int) -> void:
	for i in count:
		var direction := Vector2.from_angle(i * 2.39996)
		var reach := s * (0.15 + 0.085 * (i % 4))
		var head := center + direction * reach * (0.35 + t)
		var tail := head - direction * s * 0.065
		draw_line(tail, head, Color(color, color.a * (1.0 - t)), maxf(1.5, s * 0.026), true)


func _label(target: Vector2, s: float, t: float, label: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := roundi(clampf(s * 0.29, 20.0, 42.0))
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var position := target - Vector2(width * 0.5, s * (0.14 + 0.45 * t))
	var alpha := 1.0 - smoothstep(0.55, 1.0, t)
	draw_string_outline(
		font,
		position,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		5,
		Color(BoardView.FOG, alpha)
	)
	draw_string(
		font, position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha)
	)
