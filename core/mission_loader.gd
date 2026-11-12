class_name MissionLoader
extends RefCounted
## Charge un fichier de mission JSON et refuse ce que le jeu ne saurait pas jouer.
## La validation complète (schéma, traductions, rejeux) reste faite en intégration continue.

const FORMAT_VERSION := 1


static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Fichier illisible : %s" % path)
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("%s : JSON invalide ligne %d (%s)" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


static func load_mission(path: String) -> MissionDef:
	var d: Variant = load_json(path)
	if not d is Dictionary:
		return null
	if int(d.get("format_version", 0)) != FORMAT_VERSION:
		push_error("%s : format_version %s non pris en charge" % [path, d.get("format_version")])
		return null
	var errors := check(d)
	if not errors.is_empty():
		for e in errors:
			push_error("%s : %s" % [path, e])
		return null
	return MissionDef.new(d)


static func check(d: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	var m: Dictionary = d["map"]
	var rows: Array = m["rows"]
	if rows.size() != int(m["height"]):
		errs.append("grille : %d lignes, %d attendues" % [rows.size(), int(m["height"])])
		return errs
	for i in rows.size():
		var cells: PackedStringArray = (rows[i] as String).split(" ")
		if cells.size() != int(m["width"]):
			errs.append("grille : ligne %d sans %d cases" % [i + 1, int(m["width"])])
			return errs
		for c in cells:
			if not MissionDef.COST.has(c):
				errs.append("grille : terrain inconnu « %s » ligne %d" % [c, i + 1])
	var def := MissionDef.new(d)
	for u: Dictionary in d["deployment"]["units"]:
		if not GameState.UNITS.has(u["type"]):
			errs.append("unité %s : type inconnu %s" % [u["id"], u["type"]])
		var p := Cells.parse(u["cell"])
		if not def.inside(p) or MissionDef.COST[def.terrain(p)] < 0:
			errs.append("unité %s : case de départ invalide" % u["id"])
	for g: Dictionary in d["guardians"]:
		var p := Cells.parse(g["cell"])
		if not def.inside(p):
			errs.append("Gardien %s : case hors carte" % g["id"])
	return errs
