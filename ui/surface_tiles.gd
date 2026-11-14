class_name SurfaceTiles
extends RefCounted
## Textures Surface et raccords issus de la grille logique de la mission.

const DIRECTORY := "res://assets/terrain/surface/"
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const EDGE_BITS := [1, 2, 4, 8]

var _names: Dictionary
var _variants: Dictionary
var _bordered: Array
var _textures: Dictionary[String, Texture2D] = {}


func load_manifest() -> bool:
	var manifest: Variant = MissionLoader.load_json(DIRECTORY + "manifest.json")
	if not manifest is Dictionary:
		return false
	_names = manifest["terrain"]
	_variants = manifest["variants"]
	_bordered = manifest["edge_terrains"]
	return true


func base(mission: MissionDef, cell: Vector2i) -> Texture2D:
	var terrain := mission.terrain(cell)
	var tile: String = _names[terrain]
	if terrain == "r":
		return _texture(tile, _ramp_orientation(mission, cell))
	if terrain == "G":
		return _texture(tile, _ford_orientation(mission, cell))
	if terrain == "X" and mission.elevated.has(cell):
		tile = "mesa"
	return _texture(tile, _variant(tile, cell))


func ruin_high(mission: MissionDef, cell: Vector2i) -> Texture2D:
	if mission.terrain(cell) == "X" and mission.elevated.has(cell):
		return _texture("ruin_high", _variant("ruin", cell))
	return null


func border(mission: MissionDef, cell: Vector2i) -> Texture2D:
	var terrain := mission.terrain(cell)
	var family: String = (
		"mesa" if mission.elevated.has(cell) and terrain != "r" else _names[terrain]
	)
	if family not in _bordered:
		return null
	var mask := 0
	for i in DIRECTIONS.size():
		var neighbor := cell + DIRECTIONS[i]
		if not mission.inside(neighbor):
			mask |= EDGE_BITS[i]
			continue
		var other := mission.terrain(neighbor)
		if family == "mesa":
			if not mission.elevated.has(neighbor) and other != "r":
				mask |= EDGE_BITS[i]
		elif other != terrain and not (family == "canyon" and other == "G"):
			mask |= EDGE_BITS[i]
	if mask == 0:
		return null
	var key := "%s_edge_%02d" % [family, mask]
	if key not in _textures:
		_textures[key] = load(DIRECTORY + key + ".png")
	return _textures[key]


func _variant(family: String, cell: Vector2i) -> int:
	var count := int(_variants[family])
	# Mélange distinct à chaque position, sans motifs de répétition par rangée.
	var seed_value := (cell.x + 1) * 374761393 + (cell.y + 1) * 668265263
	seed_value = (seed_value ^ (seed_value >> 13)) * 1274126177
	return posmod(seed_value ^ (seed_value >> 16), count)


func _texture(family: String, index: int) -> Texture2D:
	var key := "%s_%d" % [family, index]
	if key not in _textures:
		_textures[key] = load(DIRECTORY + key + ".png")
	return _textures[key]


func _ramp_orientation(mission: MissionDef, cell: Vector2i) -> int:
	if mission.elevated.has(cell + Vector2i.LEFT) or mission.elevated.has(cell + Vector2i.RIGHT):
		return 1
	return 0


func _ford_orientation(mission: MissionDef, cell: Vector2i) -> int:
	for direction in [Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + direction
		if mission.inside(neighbor) and mission.terrain(neighbor) == "C":
			return 1
	return 0
