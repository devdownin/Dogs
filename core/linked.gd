class_name Linked
extends RefCounted
## Règles de la capsule des liés (Pia, guidée par Xenon), appliquées à un GameState.
##
## Les Gardiens ne voient ni ne visent la capsule : ils reconnaissent en elle un lien entre
## deux esprits humains, sans machine au milieu. Elle ouvre les accès scellés et active les
## consoles des bâtisseurs. Le faux pas : un drone relié à ATHENA qui finit son tour à côté
## d'elle la trahit pour le reste de la mission.

const KINDS: Array[String] = ["builder_console"]  # points que seule la capsule active
const ACTIONS: Array[String] = ["unseal", "interact", "interface", "extract", "brace"]


## Actions possibles pour la capsule à sa position actuelle.
static func actions(g: GameState, uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var u := g.units[uid]
	for n: Vector2i in MissionDef.NEIGHBORS:
		var p: Vector2i = u["pos"] + n
		if g.def.inside(p) and g.def.terrain(p) == "S":
			out.append({"kind": "unseal", "target": p, "feature": ""})
	for fid in g.def.features:
		var f := g.def.features[fid]
		if (
			f["kind"] in KINDS
			and not g.interacted.has(fid)
			and Cells.manhattan(f["pos"], u["pos"]) == 1
		):
			out.append({"kind": "interact", "target": f["pos"], "feature": fid})
	out.append({"kind": "brace", "target": GameState.NO_CELL, "feature": ""})
	if g.extraction_open and g.def.extraction.has(u["pos"]):
		out.append({"kind": "extract", "target": GameState.NO_CELL, "feature": ""})
	return out


## Capsules qu'un drone relié touche : elles seront trahies à la fin du tour.
static func pending(g: GameState) -> Array[String]:
	var out: Array[String] = []
	var act := g.active_units()
	for id in act:
		var u := g.units[id]
		if u["type"] != "capsule" or u["exposed"]:
			continue
		for o_id in act:
			var o := g.units[o_id]
			if (
				o["type"] != "capsule"
				and not o["silent"]
				and Cells.manhattan(o["pos"], u["pos"]) == 1
			):
				out.append(id)
				break
	out.sort()
	return out


## Faux pas d'ATHENA : la capsule est trahie pour le reste de la mission, l'alerte monte
## d'un cran et les Patrouilleurs fondent sur elle.
static func betray(g: GameState) -> void:
	for id in pending(g):
		var u := g.units[id]
		u["exposed"] = true
		g.events.append({"type": "capsule_betrayed", "unit": id})
		if g.alert_enabled:
			g.quiet_phases = 0
			g._set_alert(g.alert + 1)
		for gid in g.guards:
			if g.guards[gid]["type"] == "patroller":
				g.guards[gid]["chase"] = u["pos"]
