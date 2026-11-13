class_name BoardView
extends Control
## Carte en aplats du prototype. Ne fait que dessiner l'état fourni par `main`
## et signaler la case touchée ; aucune règle ici.

signal cell_tapped(cell: Vector2i)

const TILE_NAME := {
	".": "plain",
	"R": "rock",
	"M": "mesa",
	"r": "ramp",
	"C": "canyon",
	"G": "ford",
	"B": "basin",
	"X": "ruin"
}
const TILE_VARIANTS := {
	"plain": 4,
	"rock": 3,
	"mesa": 3,
	"ramp": 1,
	"canyon": 3,
	"ford": 1,
	"basin": 3,
	"ruin": 1,
	"fog": 3
}
const SPRITES := [
	"scout", "technician", "protector", "interceptor", "sentinel", "patroller", "regulator"
]
const CLIFF := Color("3a3038")
const PACK := Color("2fe0c8")
const GUARD := Color("a85af0")
const IVORY := Color("eadfc8")
const FOG := Color("1e2329")

## Taille de case visée au zoom initial, en unités d'affichage (2 unités ≈ 1 dp sur un
## téléphone de 360 dp de large). 96 ≈ 48 dp ; 140 ≈ 70 dp. Le zoom minimal montre toute la carte.
const TARGET_CELL := 96.0
const MAX_CELL := 140.0
const DRAG_THRESHOLD := 14.0  # au-delà, un toucher devient un glissement
const WHEEL_STEP := 1.15

var main: Node  # fournit def, game, selected, preview, mode, show_danger, reveal_all

var _tiles: Dictionary[String, Array] = {}
var _sprites: Dictionary[String, Texture2D] = {}
var _cs := 0.0  # taille d'une case
var _cam := Vector2.ZERO  # point de la carte (en cases) au centre de la vue
var _pending_focus := Vector2(-1, -1)
var _pressing := false
var _dragging := false
var _multi := false
var _press_pos := Vector2.ZERO
var _touches: Dictionary[int, Vector2] = {}
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_resized)
	for tile_name: String in TILE_VARIANTS:
		var list: Array[Texture2D] = []
		for v: int in TILE_VARIANTS[tile_name]:
			list.append(load("res://assets/terrain/%s_%d.png" % [tile_name, v]))
		_tiles[tile_name] = list
	for sprite_name: String in SPRITES:
		_sprites[sprite_name] = load("res://assets/units/%s.png" % sprite_name)
	for feature_name: String in ["node", "beacon"]:
		_sprites[feature_name] = load("res://assets/features/%s.png" % feature_name)


func _tile(tile_name: String, p: Vector2i) -> Texture2D:
	var list: Array = _tiles[tile_name]
	return list[posmod(p.x * 7 + p.y * 13 + p.x * p.y * 3, list.size())]


## Sprite posé sur une case : un peu plus haut que la case, pieds en bas, socle de faction.
func _sprite(sprite_name: String, p: Vector2i, faction: Color, tint: Color) -> void:
	var r := cell_rect(p)
	var s := r.size.x
	var base := r.get_center() + Vector2(0, s * 0.3)
	draw_set_transform(base, 0.0, Vector2(1.0, 0.42))
	draw_arc(Vector2.ZERO, s * 0.4, 0, TAU, 40, faction, maxf(3.0, s * 0.05))
	draw_set_transform(Vector2.ZERO)
	var size := s * 1.12
	var at := Vector2(r.get_center().x - size / 2.0, r.end.y - size * 0.98)
	draw_texture_rect(_sprites[sprite_name], Rect2(at, Vector2(size, size)), false, tint)


# ---------------------------------------------------------------- vue


## Recadre au zoom initial, centré sur `focus` (en cases). Différé si la taille est encore nulle.
func reset_view(focus: Vector2) -> void:
	_pending_focus = focus
	if size.x > 0.0 and size.y > 0.0:
		_apply_pending()


func min_cell() -> float:
	return minf(size.x / main.def.width, size.y / main.def.height)


func max_cell() -> float:
	return maxf(MAX_CELL, min_cell())


func cell_size() -> float:
	return _cs


func origin() -> Vector2:
	return size / 2.0 - _cam * _cs


func cell_rect(p: Vector2i) -> Rect2:
	var a := (origin() + Vector2(p) * _cs).floor()
	var b := (origin() + Vector2(p + Vector2i.ONE) * _cs).floor()
	return Rect2(a, b - a)


func cell_at(pos: Vector2) -> Vector2i:
	if _cs <= 0.0:
		return Vector2i(-1, -1)
	var c := Vector2i(((pos - origin()) / _cs).floor())
	return c if main.def.inside(c) else Vector2i(-1, -1)


## Zoome d'un facteur en gardant fixe le point de l'écran `focus`.
func zoom_at(factor: float, focus: Vector2) -> void:
	var world := (focus - origin()) / _cs
	_cs = clampf(_cs * factor, min_cell(), max_cell())
	_cam = world - (focus - size / 2.0) / _cs
	_clamp_cam()
	queue_redraw()


func pan_by(delta: Vector2) -> void:
	_cam -= delta / _cs
	_clamp_cam()
	queue_redraw()


func center_on(cell: Vector2i) -> void:
	_cam = Vector2(cell) + Vector2(0.5, 0.5)
	_clamp_cam()
	queue_redraw()


## Vrai si la case est entièrement visible.
func is_visible_cell(p: Vector2i) -> bool:
	return Rect2(Vector2.ZERO, size).encloses(cell_rect(p))


func _apply_pending() -> void:
	_cs = clampf(TARGET_CELL, min_cell(), max_cell())
	_cam = _pending_focus
	_pending_focus = Vector2(-1, -1)
	_clamp_cam()
	queue_redraw()


func _on_resized() -> void:
	if main == null or main.def == null or size.x <= 0.0 or size.y <= 0.0:
		return
	if _pending_focus.x >= 0.0 or _cs <= 0.0:
		_apply_pending()
	else:
		_cs = clampf(_cs, min_cell(), max_cell())
		_clamp_cam()
		queue_redraw()


func _clamp_cam() -> void:
	var dims := Vector2(main.def.width, main.def.height)
	var half := size / 2.0 / _cs
	for axis in 2:
		if dims[axis] <= half[axis] * 2.0:
			_cam[axis] = dims[axis] / 2.0
		else:
			_cam[axis] = clampf(_cam[axis], half[axis], dims[axis] - half[axis])


# ---------------------------------------------------------------- gestes
# Un doigt : toucher bref = case touchée ; glisser = déplacer la carte.
# Deux doigts : pincer = zoom, déplacer = défilement. Souris : molette = zoom.
# Le toucher est émis au relâchement, et jamais après un glissement ou un pincement.


func _gui_input(event: InputEvent) -> void:
	if _cs <= 0.0:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(
				WHEEL_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_STEP,
				mb.position
			)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_press_pos = mb.position
				if _touches.size() <= 1:
					_multi = false
			elif _pressing:
				_pressing = false
				if not _dragging and not _multi:
					var c := cell_at(mb.position)
					if c.x >= 0:
						cell_tapped.emit(c)
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _pressing or _touches.size() >= 2:
			return
		if not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			pan_by(mm.relative)
		accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() >= 2:
				_multi = true
				_dragging = true
				_start_pinch()
		else:
			_touches.erase(st.index)
			if _touches.size() >= 2:
				_start_pinch()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var pts := _touches.values()
			var a: Vector2 = pts[0]
			var b: Vector2 = pts[1]
			var mid := (a + b) / 2.0
			var dist := a.distance_to(b)
			if _pinch_dist > 0.0 and dist > 0.0:
				zoom_at(dist / _pinch_dist, mid)
				pan_by(mid - _pinch_mid)
			_pinch_dist = dist
			_pinch_mid = mid
			accept_event()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.factor, mg.position)
		accept_event()
	elif event is InputEventPanGesture:
		pan_by(-(event as InputEventPanGesture).delta * 20.0)
		accept_event()


func _start_pinch() -> void:
	var pts := _touches.values()
	_pinch_dist = (pts[0] as Vector2).distance_to(pts[1])
	_pinch_mid = ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0


func _draw() -> void:
	if main == null or main.game == null or _cs < 4.0:
		return
	var game: GameState = main.game
	var def: MissionDef = main.def
	var s := cell_size()
	var all: bool = main.reveal_all
	var intents: Dictionary = (
		game.intents() if main.show_danger else {"watched": {}, "routes": {}, "attacks": []}
	)
	var probing: bool = main.mode == "probe" and main.selected != ""
	var reach: Dictionary = {}
	if probing:
		reach = game.probe_targets(main.selected)
	elif main.selected != "":
		reach = game.reachable(main.selected)

	for y in def.height:
		for x in def.width:
			var p := Vector2i(x, y)
			var r := cell_rect(p)
			var known: bool = all or game.revealed.has(p)
			if not known:
				draw_texture_rect(_tile("fog", p), r, false)
				draw_rect(r, Color(0, 0, 0, 0.35), false, 1.0)
				continue
			draw_texture_rect(_tile(TILE_NAME[def.terrain(p)], p), r, false)
			var below := p + Vector2i(0, 1)
			if def.elevated.has(p) and def.terrain(p) != "r" and not def.elevated.has(below):
				draw_rect(Rect2(r.position.x, r.end.y - s * 0.14, s, s * 0.14), CLIFF)
				draw_line(
					Vector2(r.position.x, r.end.y - s * 0.14),
					Vector2(r.end.x, r.end.y - s * 0.14),
					IVORY.darkened(0.15),
					2.0
				)
			if game.recolored.has(p):
				draw_rect(r, Color(GUARD, 0.38))
				draw_rect(r.grow(-s * 0.22), Color(GUARD, 0.7), false, 1.5)
			if def.extraction.has(p):
				draw_rect(r.grow(-2), Color(PACK, 0.9), false, 3.0)
			if probing and not reach.has(p):
				draw_rect(r, Color(0, 0, 0, 0.45))  # hors de portée de la Sonde
			elif not probing and reach.has(p):
				draw_rect(r, Color(IVORY, 0.28))
			if intents["watched"].has(p):
				_hatch(r, Color(GUARD.darkened(0.35), 0.95))
			if not (all or game.current_vision.has(p)):
				draw_rect(r, Color(FOG, 0.5))
			draw_rect(r, Color(0, 0, 0, 0.25), false, 1.0)

	for fid: String in def.features:
		var f: Dictionary = def.features[fid]
		if not (all or game.revealed.has(f["pos"])):
			continue
		var done: bool = game.interacted.has(fid)
		var kind: String = "beacon" if String(f.get("kind", "")) == "beacon" else "node"
		if def.terrain(f["pos"]) == "X":
			var c := cell_rect(f["pos"]).get_center()
			draw_arc(c, s * 0.42, 0, TAU, 32, Color(IVORY, 0.3 if done else 0.9), 3.0)
		else:
			_sprite(kind, f["pos"], PACK if done else Color(IVORY, 0.7), Color.WHITE)

	for gid: String in intents["routes"]:
		var route: Array = intents["routes"][gid]
		var from: Vector2 = cell_rect(game.guards[gid]["pos"]).get_center()
		for p: Vector2i in route:
			var to := cell_rect(p).get_center()
			draw_dashed_line(from, to, GUARD.darkened(0.3), 4.0, s * 0.15)
			from = to

	for p: Vector2i in game.probed:
		_dashed_rect(cell_rect(p).grow(-s * 0.1), PACK, s)

	if probing and main.preview.x >= 0:
		for p in game.probe_area(main.preview):
			draw_rect(cell_rect(p), Color(PACK, 0.3))
		draw_rect(_area_rect(game.probe_area(main.preview)), PACK, false, 5.0)
	elif main.preview.x >= 0 and main.selected != "":
		var from: Vector2 = cell_rect(game.units[main.selected]["pos"]).get_center()
		for p in game.path_to(main.selected, main.preview):
			var to := cell_rect(p).get_center()
			draw_line(from, to, IVORY, 6.0)
			from = to
		draw_rect(cell_rect(main.preview).grow(-3), IVORY, false, 4.0)

	for gid: String in game.guards:
		var g: Dictionary = game.guards[gid]
		if not (all or game.current_vision.has(g["pos"])):
			continue
		var gc := cell_rect(g["pos"]).get_center()
		if g["type"] == "sentinel":
			var dir := Vector2(MissionDef.DIRS[g["facing"]]).normalized()
			draw_line(gc, gc + dir * s * 0.7, GUARD, 5.0)
		_sprite(g["type"], g["pos"], GUARD, Color.WHITE)
		_pips(g["pos"], g["hp"], GameState.GUARD_HP[g["type"]], GUARD)
		if g["stunned"]:  # figé par une Impulsion : croix ivoire sur la case
			var gr := cell_rect(g["pos"]).grow(-s * 0.18)
			var w := maxf(3.0, s * 0.05)
			draw_line(gr.position, gr.end, IVORY, w)
			draw_line(Vector2(gr.end.x, gr.position.y), Vector2(gr.position.x, gr.end.y), IVORY, w)

	for uid: String in game.units:
		var u: Dictionary = game.units[uid]
		if u["status"] == "extracted":
			continue
		var spent: bool = u["moved"] and u["acted"]
		var tint := Color.WHITE
		if u["status"] == "disabled":
			tint = Color(0.45, 0.45, 0.5)
		elif spent:
			tint = Color(0.68, 0.7, 0.74)
		if uid == main.selected:
			var c := cell_rect(u["pos"]).get_center() + Vector2(0, s * 0.3)
			draw_set_transform(c, 0.0, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, s * 0.5, 0, TAU, 40, IVORY, maxf(4.0, s * 0.07))
			draw_set_transform(Vector2.ZERO)
		if u["silent"]:
			tint.a = 0.45  # en silence radio : invisible pour les Gardiens, aveugle pour ATHENA
		_sprite(u["type"], u["pos"], PACK.darkened(0.35) if spent else PACK, tint)
		var r := cell_rect(u["pos"])
		if u["silent"]:
			_dashed_rect(r.grow(-s * 0.06), IVORY, s)
		if u["rampart"]:
			draw_rect(r.grow(-s * 0.04), PACK, false, maxf(3.0, s * 0.05))
		if u["braced"]:
			var b := r.position + Vector2(s * 0.12, s * 0.12)
			draw_polyline(
				PackedVector2Array([b, b + Vector2(s * 0.08, s * 0.08), b + Vector2(s * 0.16, 0)]),
				IVORY,
				3.0
			)
		_pips(u["pos"], maxi(0, u["hp"]), GameState.UNITS[u["type"]][1], PACK)
		if u["elan"] and not u["acted"]:  # Élan prêt : chevrons turquoise
			var e := r.position + Vector2(r.size.x * 0.72, r.size.x * 0.12)
			for i in 2:
				var o := e + Vector2(0, i * s * 0.08)
				var pts := PackedVector2Array(
					[o, o + Vector2(s * 0.08, -s * 0.06), o + Vector2(s * 0.16, 0)]
				)
				draw_polyline(pts, PACK, 3.0)

	# Coups annoncés : trait violet du Gardien vers sa cible, dégâts inscrits sur la cible.
	var font := ThemeDB.fallback_font
	for at: Dictionary in intents["attacks"]:
		var from := cell_rect(at["from"]).get_center()
		var to := cell_rect(game.units[at["unit"]]["pos"]).get_center()
		draw_line(from, to, GUARD, maxf(4.0, s * 0.06))
		var tip := to - (to - from).normalized() * s * 0.32
		draw_circle(tip, s * 0.16, GUARD)
		var txt := "-%d" % at["damage"]
		var fs := int(s * 0.22)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(
			font, tip + Vector2(-w / 2.0, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs
		)


## Intégrité sous l'unité : une encoche par point, pleine ou vide.
func _pips(p: Vector2i, hp: int, max_hp: int, col: Color) -> void:
	var r := cell_rect(p)
	var w := r.size.x * 0.12
	var gap := w * 0.35
	var total := max_hp * w + (max_hp - 1) * gap
	var x := r.get_center().x - total / 2.0
	var y := r.end.y - r.size.x * 0.1
	for i in max_hp:
		var box := Rect2(x + i * (w + gap), y, w, r.size.x * 0.06)
		draw_rect(box, Color(0, 0, 0, 0.6))
		if i < hp:
			draw_rect(box.grow(-1), col)
	return


func _area_rect(cells: Array[Vector2i]) -> Rect2:
	var r := cell_rect(cells[0])
	for p in cells:
		r = r.merge(cell_rect(p))
	return r


func _dashed_rect(r: Rect2, col: Color, s: float) -> void:
	var dash := s * 0.12
	var pts := [
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
		r.position
	]
	for i in 4:
		draw_dashed_line(pts[i], pts[i + 1], col, 3.0, dash)


func _hatch(r: Rect2, col: Color) -> void:
	var s := r.size.x
	var step := s / 5.0
	var k := step
	while k < s:
		draw_line(r.position + Vector2(k, 0), r.position + Vector2(0, k), col, 2.0)
		draw_line(r.position + Vector2(s, k), r.position + Vector2(k, s), col, 2.0)
		k += step
	draw_line(r.position + Vector2(s, 0), r.position + Vector2(0, s), col, 2.0)
