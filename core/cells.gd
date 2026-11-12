class_name Cells
extends RefCounted
## Conversion entre la notation des données ("D7", "A1:J3") et les coordonnées de grille.


static func parse(c: String) -> Vector2i:
	return Vector2i(c.unicode_at(0) - 65, int(c.substr(1)) - 1)


static func name_of(p: Vector2i) -> String:
	return "%s%d" % [String.chr(65 + p.x), p.y + 1]


static func expand(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item: String in list:
		if ":" in item:
			var parts := item.split(":")
			var a := parse(parts[0])
			var b := parse(parts[1])
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					out.append(Vector2i(x, y))
		else:
			out.append(parse(item))
	return out


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
