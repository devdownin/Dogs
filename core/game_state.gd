class_name GameState
extends RefCounted
## État d'une mission en cours et règles qui le font évoluer.
##
## Le joueur n'agit que par trois commandes : move(), action(), end_player_turn().
## Chaque commande valide, applique, puis ajoute des événements à `events` ; la
## présentation les lit et les anime sans jamais modifier l'état.
## Aucun hasard : rejouer les mêmes commandes donne le même état.
##
## Périmètre du jalon 1 : déplacement, vision, détection, alerte, territoire,
## objectifs et déclencheurs. Combat, modules et Liaison viendront avec les
## missions qui les utilisent.

const UNITS := {
	# mouvement, intégrité, vision
	"scout": [5, 2, 4],
	"technician": [3, 2, 2],
	"protector": [3, 4, 2],
	"interceptor": [4, 3, 3]
}
const PATROLLER_MOVE := 4
const PATROLLER_SIGHT := 2
const ALERTS: Array[String] = ["watch", "warning", "interception", "lockdown"]
const INTERFACE_KINDS: Array[String] = ["signal_source", "relay_point", "beacon", "node"]
const PROBE_RANGE := 5  # distance maximale entre l'Éclaireur et le centre de la zone
const PROBE_RADIUS := 1  # zone de 3 × 3

var def: MissionDef
var units: Dictionary[String, Dictionary] = {}
var guards: Dictionary[String, Dictionary] = {}
var recolored: Dictionary[Vector2i, bool] = {}
var revealed: Dictionary[Vector2i, bool] = {}
var current_vision: Dictionary[Vector2i, bool] = {}
var probed: Dictionary[Vector2i, bool] = {}  # zone sondée, observée jusqu'au prochain tour
var observed_guards: Dictionary[String, bool] = {}
var interacted: Dictionary[String, bool] = {}
var flags: Dictionary[String, bool] = {}
var terrains_entered: Dictionary[String, bool] = {}
var territory_entered := false
var end_turn_on_recolored := false
var countdowns: Dictionary[String, int] = {}
var expired: Dictionary[String, bool] = {}
var advance: Dictionary = {}
var extraction_open := true
var alert_enabled := true
var alert := 0
var alert_max := 0
var quiet_phases := 0
var turn := 0
var completed_turns := 0
var result := ""  # "", "victory", "failure", "retreat"
var result_turn := -1
var last_error := ""
var events: Array[Dictionary] = []

var _fired: Dictionary[String, bool] = {}
var _seq: Dictionary[String, int] = {}


func _init(mission: MissionDef) -> void:
	def = mission
	var d := def.data
	for u: Dictionary in d["deployment"]["units"]:
		units[u["id"]] = {
			"type": u["type"],
			"pos": Cells.parse(u["cell"]),
			"hp": UNITS[u["type"]][1],
			"status": "active",
			"moved": false,
			"acted": false
		}
	for g: Dictionary in d["guardians"]:
		var route: Array[Vector2i] = []
		for c: String in g.get("route", []):
			route.append(Cells.parse(c))
		guards[g["id"]] = {
			"type": g["type"],
			"pos": Cells.parse(g["cell"]),
			"cycle": g.get("facing_cycle", []),
			"facing": g.get("facing", "S"),
			"route": route,
			"mode": g.get("route_mode", "loop"),
			"ri": 0,
			"dirn": 1
		}
	for p in Cells.expand(d["map"].get("territory", {}).get("recolored", [])):
		recolored[p] = true
	alert_enabled = d["alert"].get("enabled", true)
	alert = ALERTS.find(d["alert"]["initial"])
	alert_max = alert
	_refresh_vision()


# ---------------------------------------------------------------- lecture


func active_units() -> Array[String]:
	var out: Array[String] = []
	for id in units:
		if units[id]["status"] == "active":
			out.append(id)
	return out


func alert_name() -> String:
	return ALERTS[alert]


## Cases atteignables par un drone ce tour-ci : {case: coût}.
func reachable(uid: String) -> Dictionary[Vector2i, int]:
	var u := units[uid]
	var out: Dictionary[Vector2i, int] = {}
	if u["status"] != "active" or u["moved"]:
		return out
	var dist: Dictionary = def.paths(u["pos"], _guard_cells())["dist"]
	var occ := _occupied(uid)
	for p: Vector2i in dist:
		if dist[p] <= UNITS[u["type"]][0] and not occ.has(p) and p != u["pos"]:
			out[p] = dist[p]
	return out


## Trajet qu'emprunterait un drone vers `dest` (vide si hors de portée).
func path_to(uid: String, dest: Vector2i) -> Array[Vector2i]:
	if not reachable(uid).has(dest):
		return []
	var res := def.paths(units[uid]["pos"], _guard_cells())
	return MissionDef.trace(res["prev"], units[uid]["pos"], dest)


## Actions possibles pour un drone à sa position actuelle : [{kind, target, feature}].
func available_actions(uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var u := units[uid]
	if u["status"] != "active" or u["acted"] or not result.is_empty():
		return out
	for fid in def.features:
		var f := def.features[fid]
		if interacted.has(fid) or Cells.manhattan(f["pos"], u["pos"]) != 1:
			continue
		if f["kind"] in INTERFACE_KINDS:
			if u["type"] == "technician":
				out.append({"kind": "interface", "target": f["pos"], "feature": fid})
		elif f["kind"] in ["anomaly", "fragment_cache"]:
			out.append({"kind": "interact", "target": f["pos"], "feature": fid})
	if u["type"] == "scout":
		out.append({"kind": "probe", "target": Vector2i(-1, -1), "feature": ""})
	if extraction_open and def.extraction.has(u["pos"]):
		out.append({"kind": "extract", "target": Vector2i(-1, -1), "feature": ""})
	return out


## Centres de Sonde possibles pour un Éclaireur. Pas de ligne de vue requise.
func probe_targets(uid: String) -> Dictionary[Vector2i, bool]:
	var out: Dictionary[Vector2i, bool] = {}
	var u := units[uid]
	if u["type"] != "scout" or u["status"] != "active" or u["acted"]:
		return out
	for y in def.height:
		for x in def.width:
			if Cells.manhattan(u["pos"], Vector2i(x, y)) <= PROBE_RANGE:
				out[Vector2i(x, y)] = true
	return out


## Cases couvertes par une Sonde centrée sur `center`.
func probe_area(center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-PROBE_RADIUS, PROBE_RADIUS + 1):
		for dx in range(-PROBE_RADIUS, PROBE_RADIUS + 1):
			var p := center + Vector2i(dx, dy)
			if def.inside(p):
				out.append(p)
	return out


## Ce que les Gardiens observés surveilleront à leur prochaine phase.
## C'est exactement ce que guardian_phase() appliquera : l'affichage ne ment jamais.
func intents() -> Dictionary:
	var watched: Dictionary[Vector2i, bool] = {}
	var routes: Dictionary[String, Array] = {}
	for gid in guards:
		if not observed_guards.has(gid):
			continue
		var g := guards[gid]
		if g["type"] == "sentinel":
			watched.merge(def.cone(g["pos"], _sentinel_facing(g, turn)))
		elif g["type"] == "patroller" and not g["route"].is_empty():
			var wp := _next_waypoint(g)
			var path := _patrol_path(g, g["route"][wp[0]])
			routes[gid] = path
			var end: Vector2i = g["pos"] if path.is_empty() else path[-1]
			watched.merge(def.vision(end, PATROLLER_SIGHT))
	return {"watched": watched, "routes": routes}


func records() -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = {}
	for r: Dictionary in def.data["objectives"]["records"]:
		out[r["id"]] = _cond(r["condition"], "rec." + r["id"])
	return out


# ---------------------------------------------------------------- commandes


func start_turn() -> void:
	turn += 1
	probed.clear()
	_refresh_vision()
	for id in units:
		units[id]["moved"] = false
		units[id]["acted"] = false
	_emit({"type": "turn_started", "turn": turn})
	_check()


func move(uid: String, dest: Vector2i) -> bool:
	if not _can_command(uid):
		return false
	var u := units[uid]
	if u["moved"]:
		return _refuse("%s s'est déjà déplacé" % uid)
	var res := def.paths(u["pos"], _guard_cells())
	var dist: Dictionary = res["dist"]
	if not dist.has(dest):
		return _refuse("%s : %s inaccessible" % [uid, Cells.name_of(dest)])
	if dist[dest] > UNITS[u["type"]][0]:
		return _refuse("%s : %s coûte %d" % [uid, Cells.name_of(dest), dist[dest]])
	if _occupied(uid).has(dest):
		return _refuse("%s : %s occupée" % [uid, Cells.name_of(dest)])
	var path := MissionDef.trace(res["prev"], u["pos"], dest)
	for p in path:
		terrains_entered[def.terrain(p)] = true
		if recolored.has(p):
			territory_entered = true
		revealed.merge(def.vision(p, UNITS[u["type"]][2]))
	u["pos"] = dest
	u["moved"] = true
	_emit({"type": "unit_moved", "unit": uid, "path": path})
	_refresh_vision()
	_check()
	return true


## kind : "interact", "interface", "probe" ou "extract". `target` : case du point d'intérêt
## ou centre de la Sonde.
func action(uid: String, kind: String, target := Vector2i(-1, -1)) -> bool:
	if not _can_command(uid):
		return false
	var u := units[uid]
	if u["acted"]:
		return _refuse("%s a déjà agi" % uid)
	match kind:
		"extract":
			if not extraction_open or not def.extraction.has(u["pos"]):
				return _refuse("%s : rappel impossible ici" % uid)
			u["status"] = "extracted"
			_emit({"type": "unit_extracted", "unit": uid})
		"probe":
			if not probe_targets(uid).has(target):
				return _refuse("%s : sonde impossible en %s" % [uid, Cells.name_of(target)])
			for p in probe_area(target):
				probed[p] = true
			_emit({"type": "probe_launched", "unit": uid, "center": target})
		"interact", "interface":
			var fid := ""
			for id in def.features:
				if def.features[id]["pos"] == target:
					fid = id
			if fid.is_empty() or Cells.manhattan(target, u["pos"]) != 1:
				return _refuse(
					"%s : pas de point d'intérêt adjacent en %s" % [uid, Cells.name_of(target)]
				)
			if def.features[fid]["kind"] in INTERFACE_KINDS and u["type"] != "technician":
				return _refuse("%s : ce point exige le Technicien" % uid)
			interacted[fid] = true
			_emit({"type": "feature_activated", "unit": uid, "feature": fid})
		_:
			return _refuse("action inconnue %s" % kind)
	u["acted"] = true
	_refresh_vision()
	_check()
	return true


func end_player_turn() -> void:
	if not result.is_empty():
		return
	for id in active_units():
		if recolored.has(units[id]["pos"]):
			end_turn_on_recolored = true
	_check()
	if not result.is_empty():
		return
	_guardian_phase()
	completed_turns += 1
	var deadline := int(def.data["objectives"]["main"].get("deadline_turn", 0))
	if deadline > 0 and completed_turns >= deadline:
		_finish("failure")
	_check()


# ---------------------------------------------------------------- phase des Gardiens


func _guardian_phase() -> void:
	var watched: Dictionary[Vector2i, bool] = {}
	var detected: Dictionary[Vector2i, bool] = {}
	var unit_at: Dictionary[Vector2i, String] = {}
	for id in active_units():
		unit_at[units[id]["pos"]] = id
	for gid in guards:
		var g := guards[gid]
		if g["type"] == "patroller" and not g["route"].is_empty():
			var wp := _next_waypoint(g)
			g["ri"] = wp[0]
			g["dirn"] = wp[1]
			var walked: Array[Vector2i] = []
			for p in _patrol_path(g, g["route"][g["ri"]]):
				if unit_at.has(p):
					detected[p] = true  # un drone barre la route
					break
				g["pos"] = p
				walked.append(p)
			_emit({"type": "guardian_moved", "guardian": gid, "path": walked})
			watched.merge(def.vision(g["pos"], PATROLLER_SIGHT))
		elif g["type"] == "sentinel":
			g["facing"] = _sentinel_facing(g, turn)
			_emit({"type": "guardian_turned", "guardian": gid, "facing": g["facing"]})
			watched.merge(def.cone(g["pos"], g["facing"]))
	for p: Vector2i in unit_at:
		var u := units[unit_at[p]]
		var near_guard := false
		for gid in guards:
			if Cells.manhattan(p, guards[gid]["pos"]) == 1:
				near_guard = true
		var hidden: bool = (
			u["type"] == "scout" and def.terrain(p) in MissionDef.BLOCKS_LOS and not near_guard
		)
		if (watched.has(p) and not hidden) or (recolored.has(p) and not guards.is_empty()):
			detected[p] = true
	if alert_enabled and not guards.is_empty():
		if not detected.is_empty():
			quiet_phases = 0
			_set_alert(alert + 1)
			_emit({"type": "units_detected", "cells": detected.keys()})
		else:
			quiet_phases += 1
			if quiet_phases >= 3 and alert > 0:
				quiet_phases = 0
				alert -= 1
				_emit({"type": "alert_changed", "level": alert_name()})
	if not advance.is_empty():
		var front := -1
		for p: Vector2i in recolored:
			front = maxi(front, p.y)
		front += 1
		if advance["direction"] == "S" and front < def.height:
			var row: Array[Vector2i] = []
			for x in def.width:
				recolored[Vector2i(x, front)] = true
				row.append(Vector2i(x, front))
			_emit({"type": "territory_advanced", "cells": row})
		for id in active_units():
			var u := units[id]
			if recolored.has(u["pos"]):
				u["hp"] -= int(advance.get("damage", 1))
				_emit({"type": "unit_damaged", "unit": id, "hp": u["hp"]})
				if u["hp"] <= 0:
					u["status"] = "disabled"
					_emit({"type": "unit_disabled", "unit": id})
	for cid: String in countdowns.keys():
		countdowns[cid] -= 1
		if countdowns[cid] <= 0:
			countdowns.erase(cid)
			expired[cid] = true
			_emit({"type": "countdown_expired", "id": cid})
	_refresh_vision()


func _sentinel_facing(g: Dictionary, phase: int) -> String:
	var cycle: Array = g["cycle"]
	return g["facing"] if cycle.is_empty() else cycle[(phase - 1) % cycle.size()]


## Renvoie [indice du prochain point de ronde, sens].
func _next_waypoint(g: Dictionary) -> Array[int]:
	var n: int = g["route"].size()
	var ri: int = g["ri"]
	var dirn: int = g["dirn"]
	if g["mode"] == "loop":
		return [(ri + 1) % n, 1]
	if ri + dirn < 0 or ri + dirn >= n:
		dirn = -dirn
	return [ri + dirn, dirn]


func _patrol_path(g: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var res := def.paths(g["pos"])
	if not res["dist"].has(target) or target == g["pos"]:
		return []
	var path := MissionDef.trace(res["prev"], g["pos"], target)
	return path.slice(0, PATROLLER_MOVE)


# ---------------------------------------------------------------- conditions, déclencheurs, fin


func _check() -> void:
	for tr: Dictionary in def.data["triggers"]:
		var tid: String = tr["id"]
		if _fired.has(tid) and tr.get("once", true):
			continue
		if _cond(tr["when"], "t." + tid):
			_fired[tid] = true
			for a: Dictionary in tr["do"]:
				_act(a)
	if not result.is_empty():
		return
	var obj: Dictionary = def.data["objectives"]
	if _cond(obj["main"]["condition"], "main"):
		_finish("victory")
	elif obj.has("failure") and _cond(obj["failure"], "fail"):
		_finish("failure")
	elif active_units().is_empty():
		var all_disabled := true
		for id in units:
			if units[id]["status"] != "disabled":
				all_disabled = false
		_finish("failure" if all_disabled else "retreat")


func _finish(res: String) -> void:
	if result.is_empty():
		result = res
		result_turn = turn
		_emit({"type": "mission_ended", "result": res, "turn": turn})


func _act(a: Dictionary) -> void:
	match a["type"]:
		"set_flag":
			flags[a["name"]] = true
		"start_countdown":
			countdowns[a["id"]] = int(a["turns"])
		"territory_advance":
			advance = a
		"close_extraction":
			extraction_open = false
			for id in active_units():
				units[id]["status"] = "disabled"
				_emit({"type": "unit_disabled", "unit": id})
		"set_alert":
			_set_alert(ALERTS.find(a["level"]))
		"end_mission":
			_finish(a["result"])
	# Toutes les actions, y compris celles de pure présentation (bulles, répliques,
	# mises en évidence), sont transmises telles quelles à l'interface.
	_emit({"type": "script_action", "action": a})


func _set_alert(level: int) -> void:
	var before := alert
	alert = mini(level, ALERTS.size() - 1)
	alert_max = maxi(alert_max, alert)
	if alert != before:
		_emit({"type": "alert_changed", "level": alert_name()})


func _match_unit(selector: String, uid: String) -> bool:
	return selector == "any" or selector == uid or selector == units[uid]["type"]


func _cond(c: Dictionary, path: String) -> bool:
	if c.has("all"):
		var ok := true
		for i in c["all"].size():
			if not _cond(c["all"][i], "%s.a%d" % [path, i]):
				ok = false
		return ok
	if c.has("any"):
		var ok := false
		for i in c["any"].size():
			if _cond(c["any"][i], "%s.o%d" % [path, i]):
				ok = true
		return ok
	if c.has("not"):
		return not _cond(c["not"], path + ".n")
	if c.has("sequence"):
		var steps: Array = c["sequence"]
		var i: int = _seq.get(path, 0)
		while i < steps.size() and _cond(steps[i], "%s.s%d" % [path, i]):
			i += 1
		_seq[path] = i
		return i == steps.size()
	match c["type"]:
		"turn_start":
			return turn >= int(c["turn"])
		"turn_end":
			return completed_turns >= int(c["turn"])
		"max_turns":
			return result_turn >= 0 and result_turn <= int(c["value"])
		"unit_in":
			var cells := Cells.expand(c["cells"])
			for id in active_units():
				if _match_unit(c["unit"], id) and units[id]["pos"] in cells:
					return true
			return false
		"all_units_extracted":
			var any_extracted := false
			for id in units:
				if units[id]["status"] == "active":
					return false
				if units[id]["status"] == "extracted":
					any_extracted = true
			return any_extracted
		"unit_extracted", "unit_disabled":
			var wanted := "extracted" if c["type"] == "unit_extracted" else "disabled"
			for id in units:
				if _match_unit(c["unit"], id) and units[id]["status"] == wanted:
					return true
			return false
		"no_unit_disabled":
			for id in units:
				if units[id]["status"] == "disabled":
					return false
			return true
		"interacted":
			return interacted.has(c["feature"])
		"feature_revealed":
			return revealed.has(def.features[c["feature"]]["pos"])
		"cells_revealed":
			for p in Cells.expand(c["cells"]):
				if not revealed.has(p):
					return false
			return true
		"reveal_ratio_at_least":
			return float(revealed.size()) / (def.width * def.height) >= float(c["value"])
		"terrain_entered":
			return terrains_entered.has(c["terrain"])
		"territory_revealed":
			for p: Vector2i in recolored:
				if revealed.has(p):
					return true
			return false
		"territory_entered":
			return territory_entered
		"never_end_turn_on":
			return not end_turn_on_recolored
		"unit_end_turn_on":
			return end_turn_on_recolored
		"guardian_observed":
			var gid: String = c.get("guardian", "any")
			return not observed_guards.is_empty() if gid == "any" else observed_guards.has(gid)
		"alert_at_least":
			return alert >= ALERTS.find(c["level"])
		"alert_never_above":
			return alert_max <= ALERTS.find(c["level"])
		"countdown_expired":
			return expired.has(c["countdown"])
		"flag":
			return flags.has(c["name"])
	push_error("Condition inconnue : %s" % c["type"])
	return false


# ---------------------------------------------------------------- utilitaires


func _can_command(uid: String) -> bool:
	last_error = ""
	if not result.is_empty():
		return _refuse("la mission est terminée")
	if not units.has(uid) or units[uid]["status"] != "active":
		return _refuse("%s n'est pas disponible" % uid)
	return true


func _refuse(reason: String) -> bool:
	last_error = reason
	return false


func _emit(e: Dictionary) -> void:
	events.append(e)


func _guard_cells() -> Dictionary[Vector2i, bool]:
	var out: Dictionary[Vector2i, bool] = {}
	for gid in guards:
		out[guards[gid]["pos"]] = true
	return out


func _occupied(exclude: String) -> Dictionary[Vector2i, bool]:
	var out := _guard_cells()
	for id in active_units():
		if id != exclude:
			out[units[id]["pos"]] = true
	return out


func _refresh_vision() -> void:
	current_vision.clear()
	for id in active_units():
		current_vision.merge(def.vision(units[id]["pos"], UNITS[units[id]["type"]][2]))
	current_vision.merge(probed)
	revealed.merge(current_vision)
	for gid in guards:
		if current_vision.has(guards[gid]["pos"]):
			observed_guards[gid] = true
