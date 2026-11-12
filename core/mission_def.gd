class_name MissionDef
extends RefCounted
## Définition immuable d'une mission : carte, points d'intérêt, et géométrie de grille
## (trajets, ligne de vue, vision, cônes). Aucun état de partie ici.

const COST := {".": 1, "R": 2, "X": 2, "M": 1, "r": 1, "G": 1, "C": -1, "B": -1}
const BLOCKS_LOS := ["R", "X"]
const DIRS := {
	"N": Vector2i(0, -1),
	"NE": Vector2i(1, -1),
	"E": Vector2i(1, 0),
	"SE": Vector2i(1, 1),
	"S": Vector2i(0, 1),
	"SW": Vector2i(-1, 1),
	"W": Vector2i(-1, 0),
	"NW": Vector2i(-1, -1)
}
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]

var data: Dictionary
var id: String
var width: int
var height: int
var grid: Array[PackedStringArray] = []
var elevated: Dictionary[Vector2i, bool] = {}
var features: Dictionary[String, Dictionary] = {}
var extraction: Dictionary[Vector2i, bool] = {}


func _init(d: Dictionary) -> void:
	data = d
	id = d["id"]
	var m: Dictionary = d["map"]
	width = int(m["width"])
	height = int(m["height"])
	for row: String in m["rows"]:
		grid.append(row.split(" "))
	for y in height:
		for x in width:
			if grid[y][x] == "M":
				elevated[Vector2i(x, y)] = true
	for p in Cells.expand(m.get("elevated", [])):
		elevated[p] = true
	for f: Dictionary in m.get("features", []):
		var copy := f.duplicate()
		copy["pos"] = Cells.parse(f["cell"])
		features[f["id"]] = copy
	for p in Cells.expand(d["deployment"]["extraction"]):
		extraction[p] = true


func terrain(p: Vector2i) -> String:
	return grid[p.y][p.x]


func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < width and p.y >= 0 and p.y < height


func step_ok(a: Vector2i, b: Vector2i) -> bool:
	if COST[terrain(b)] < 0:
		return false
	if elevated.has(a) != elevated.has(b):
		return terrain(a) == "r" or terrain(b) == "r"
	return true


## Dijkstra depuis `src`. Renvoie {"dist": {case: coût}, "prev": {case: case}}.
## Départage déterministe : coût, puis x, puis y (identique au simulateur de référence).
func paths(src: Vector2i, blocked: Dictionary = {}) -> Dictionary:
	var dist: Dictionary[Vector2i, int] = {src: 0}
	var prev: Dictionary[Vector2i, Vector2i] = {}
	var open: Dictionary[Vector2i, bool] = {src: true}
	while not open.is_empty():
		var p := Vector2i(-1, -1)
		for q: Vector2i in open:
			if (
				p.x < 0
				or dist[q] < dist[p]
				or (dist[q] == dist[p] and (q.x < p.x or (q.x == p.x and q.y < p.y)))
			):
				p = q
		open.erase(p)
		for off in NEIGHBORS:
			var n := p + off
			if not inside(n) or blocked.has(n) or not step_ok(p, n):
				continue
			var nc: int = dist[p] + COST[terrain(n)]
			if nc < dist.get(n, 1 << 30):
				dist[n] = nc
				prev[n] = p
				open[n] = true
	return {"dist": dist, "prev": prev}


## Trajet de `src` (exclu) à `dst` (inclus) à partir du résultat de paths().
static func trace(prev: Dictionary, src: Vector2i, dst: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [dst]
	var p := dst
	while p != src:
		p = prev[p]
		out.append(p)
	out.reverse()
	out.remove_at(0)
	return out


static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while true:
		pts.append(Vector2i(x0, y0))
		if x0 == b.x and y0 == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return pts


func los(a: Vector2i, b: Vector2i, viewer_elevated: bool) -> bool:
	var pts := line(a, b)
	for i in range(1, pts.size() - 1):
		var t := terrain(pts[i])
		if t in BLOCKS_LOS and not (viewer_elevated and t == "R"):
			return false
	return true


func vision(p: Vector2i, radius: int) -> Dictionary[Vector2i, bool]:
	var elev := elevated.has(p)
	var r := radius + (1 if elev else 0)
	var out: Dictionary[Vector2i, bool] = {}
	for y in height:
		for x in width:
			var q := Vector2i(x, y)
			if Cells.manhattan(p, q) <= r and los(p, q, elev):
				out[q] = true
	return out


## Cône d'une Sentinelle, portée 4. Axe : jusqu'à d-1 de côté à la distance d.
## Diagonale : quadrant, axes exclus, 4 pas au plus.
func cone(p: Vector2i, facing: String) -> Dictionary[Vector2i, bool]:
	var d: Vector2i = DIRS[facing]
	var out: Dictionary[Vector2i, bool] = {}
	for y in height:
		for x in width:
			var o := Vector2i(x, y) - p
			var ok := false
			if d.x == 0 or d.y == 0:
				var fwd := o.x * d.x + o.y * d.y
				var side := absi(o.x) if d.x == 0 else absi(o.y)
				ok = fwd >= 1 and fwd <= 4 and side <= fwd - 1
			else:
				ok = o.x * d.x > 0 and o.y * d.y > 0 and absi(o.x) + absi(o.y) <= 4
			if ok and los(p, Vector2i(x, y), elevated.has(p)):
				out[Vector2i(x, y)] = true
	return out
