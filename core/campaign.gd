class_name Campaign
extends RefCounted
## État de campagne : ressources, étape du vaisseau, découvertes et études d'ATHENA.
##
## Règles (voir docs/arbre-decouverte.md) :
## - une hypothèse n'apparaît qu'une fois au moins une de ses conditions remplie (piste) ;
## - elle s'étudie quand toutes sont remplies, contre des Données ;
## - chaque mission jouée, quelle qu'en soit l'issue, fait avancer chaque étude d'un cycle ;
## - ATHENA mène une étude à la fois, deux à partir de l'étape « Recherche » du vaisseau.
## Aucune lecture ni écriture de fichier ici : voir SaveStore.

const FORMAT := 1
const TREE_PATH := "res://data/research/tree.json"
const DISCOVERIES_PATH := "res://data/research/discoveries.json"
const STAGES: Array[String] = [
	"survival", "observation", "link", "research", "projection", "navigation"
]
const BRANCHES: Array[String] = ["observation", "link", "engineering", "xenology", "crew"]

var data := 0
var materials := 0
var fragments := 0
var ship_stage := "survival"
var gauges: Dictionary[String, int] = {}
var discoveries: Dictionary[String, bool] = {}
var confirmed: Dictionary[String, bool] = {}
var studying: Dictionary[String, int] = {}  # hypothèse → cycles déjà accomplis
var completed: Dictionary[String, Dictionary] = {}  # mission → {result, records}

var hypotheses: Dictionary[String, Dictionary] = {}  # ordre du fichier conservé
var discovery_defs: Dictionary[String, Dictionary] = {}
var _lanes := {"initial": 1, "after_ship_stage": {}}


func _init() -> void:
	var tree: Dictionary = MissionLoader.load_json(TREE_PATH)
	for h: Dictionary in tree.get("hypotheses", []):
		hypotheses[h["id"]] = h
	_lanes = tree.get("lanes", _lanes)
	var disc: Dictionary = MissionLoader.load_json(DISCOVERIES_PATH)
	for d: Dictionary in disc.get("discoveries", []):
		discovery_defs[d["id"]] = d


# ---------------------------------------------------------------- arbre


func lanes() -> int:
	var n: int = _lanes.get("initial", 1)
	var after: Dictionary = _lanes.get("after_ship_stage", {})
	for stage: String in after:
		if stage_reached(stage):
			n = maxi(n, int(after[stage]))
	return n


func stage_reached(stage: String) -> bool:
	return STAGES.find(ship_stage) >= STAGES.find(stage)


## "hidden", "lead" (piste), "available", "studying", "confirmed" ou "excluded".
func state(id: String) -> String:
	var h := hypotheses[id]
	if confirmed.has(id):
		return "confirmed"
	if studying.has(id):
		return "studying"
	var ex: String = h.get("exclusive_with", "")
	if not ex.is_empty() and (confirmed.has(ex) or studying.has(ex)):
		return "excluded"
	var parts := _requirement_parts(id)
	var met := 0
	for ok: bool in parts:
		if ok:
			met += 1
	if not parts.is_empty() and met == parts.size():
		return "available"
	return "lead" if met > 0 else "hidden"


## Découvertes qui manquent encore à une hypothèse.
func missing_discoveries(id: String) -> Array[String]:
	var out: Array[String] = []
	for d: String in hypotheses[id]["requires"].get("discoveries", []):
		if not discoveries.has(d):
			out.append(d)
	return out


## Raison du refus, ou chaîne vide si l'étude peut commencer.
func study_refusal(id: String) -> String:
	match state(id):
		"confirmed", "studying":
			return "RES_ALREADY"
		"excluded":
			return "RES_EXCLUDED"
		"hidden", "lead":
			return "RES_LOCKED"
	if studying.size() >= lanes():
		return "RES_NO_LANE"
	if data < int(hypotheses[id]["data_cost"]):
		return "RES_NO_DATA"
	return ""


func start_study(id: String) -> bool:
	if not study_refusal(id).is_empty():
		return false
	data -= int(hypotheses[id]["data_cost"])
	studying[id] = 0
	return true


## Durée effective d'une étude, réveils d'équipage compris.
func cycles_needed(id: String) -> int:
	var h := hypotheses[id]
	var n := int(h["cycles"])
	if h["branch"] == "crew" and confirmed.has("crew_medic") and id != "crew_medic":
		n -= 1
	if h["branch"] == "xenology" and confirmed.has("crew_xenologist"):
		n -= 1
	return maxi(1, n)


func crew_awake() -> int:
	var n := 0
	for id: String in confirmed:
		if hypotheses.has(id) and hypotheses[id]["effect"].get("type", "") == "crew_wake":
			n += 1
	return n


# ---------------------------------------------------------------- fin de mission


## Applique l'issue d'une mission. Renvoie un résumé pour l'affichage :
## {data, materials, discoveries: [], confirmed: [], stage}.
func apply_mission(def: MissionDef, game: GameState) -> Dictionary:
	var d := def.data
	var won := game.result == "victory"
	var recs := game.records()
	var summary := {
		"data": 0,
		"materials": 0,
		"discoveries": [] as Array[String],
		"confirmed": [] as Array[String],
		"stage": ""
	}
	var won_recs: Dictionary = {}
	for k: String in recs:
		won_recs[k] = recs[k] and won
	var prev: Dictionary = completed.get(d["id"], {})
	completed[d["id"]] = {
		"result": "victory" if won or prev.get("result", "") == "victory" else game.result,
		"records": won_recs
	}
	if won:
		var r: Dictionary = d.get("rewards", {})
		var gained_data := int(r.get("data", 0))
		var gained_mat := int(r.get("materials", 0))
		var per: Dictionary = r.get("per_record", {})
		for k: String in won_recs:
			if won_recs[k]:
				gained_data += int(per.get("data", 0))
				gained_mat += int(per.get("materials", 0))
		data += gained_data
		materials += gained_mat
		fragments += int(r.get("fragments", 0))
		summary["data"] = gained_data
		summary["materials"] = gained_mat
		var stage: String = r.get("ship_stage", "")
		if not stage.is_empty() and not stage_reached(stage):
			ship_stage = stage
			summary["stage"] = stage
		for e: Dictionary in d.get("campaign_effects", []):
			if e.has("if_record") and not won_recs.get(e["if_record"], false):
				continue
			match e["type"]:
				"discoveries":
					for id: String in e["ids"]:
						_discover(id, summary)
				"gauge":
					gauges[e["gauge"]] = gauges.get(e["gauge"], 0) + int(e.get("delta", 1))
	# Un Gardien neutralisé laisse toujours des débris à analyser, même en cas de repli.
	if not game.neutralized.is_empty():
		_discover("debris_guardian", summary)
	_tick(summary)
	return summary


func _discover(id: String, summary: Dictionary) -> void:
	if discovery_defs.has(id) and not discoveries.has(id):
		discoveries[id] = true
		summary["discoveries"].append(id)


## Un cycle d'étude par mission jouée.
func _tick(summary: Dictionary) -> void:
	for id: String in studying.keys():
		studying[id] += 1
		if studying[id] >= cycles_needed(id):
			studying.erase(id)
			confirmed[id] = true
			summary["confirmed"].append(id)
			var eff: Dictionary = hypotheses[id]["effect"]
			if eff.get("type", "") == "campaign" and eff.has("gauge"):
				gauges[eff["gauge"]] = gauges.get(eff["gauge"], 0) + int(eff.get("value", 1))


# ---------------------------------------------------------------- sérialisation


func to_dict() -> Dictionary:
	return {
		"format": FORMAT,
		"data": data,
		"materials": materials,
		"fragments": fragments,
		"ship_stage": ship_stage,
		"gauges": gauges,
		"discoveries": discoveries.keys(),
		"confirmed": confirmed.keys(),
		"studying": studying,
		"completed": completed
	}


static func from_dict(d: Dictionary) -> Campaign:
	var c := Campaign.new()
	if int(d.get("format", 0)) != FORMAT:
		return c
	c.data = int(d.get("data", 0))
	c.materials = int(d.get("materials", 0))
	c.fragments = int(d.get("fragments", 0))
	c.ship_stage = d.get("ship_stage", "survival")
	for k: String in d.get("gauges", {}):
		c.gauges[k] = int(d["gauges"][k])
	for id: String in d.get("discoveries", []):
		c.discoveries[id] = true
	for id: String in d.get("confirmed", []):
		if c.hypotheses.has(id):
			c.confirmed[id] = true
	for id: String in d.get("studying", {}):
		if c.hypotheses.has(id):
			c.studying[id] = int(d["studying"][id])
	for id: String in d.get("completed", {}):
		c.completed[id] = d["completed"][id]
	return c


# ---------------------------------------------------------------- utilitaires


func _requirement_parts(id: String) -> Array[bool]:
	var req: Dictionary = hypotheses[id]["requires"]
	var parts: Array[bool] = []
	for dsc: String in req.get("discoveries", []):
		parts.append(discoveries.has(dsc))
	for p: String in req.get("hypotheses", []):
		parts.append(confirmed.has(p))
	var any: Array = req.get("any_hypothesis", [])
	if not any.is_empty():
		var ok := false
		for p: String in any:
			if confirmed.has(p):
				ok = true
		parts.append(ok)
	if req.has("ship_stage"):
		parts.append(stage_reached(req["ship_stage"]))
	return parts
