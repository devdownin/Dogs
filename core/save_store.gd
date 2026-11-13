class_name SaveStore
extends RefCounted
## Sauvegardes locales, sans compte ni réseau.
##
## Deux fichiers : la campagne, et la mission en cours (identifiant + journal de commandes).
## Écriture atomique : fichier temporaire, puis renommage ; la version précédente est
## conservée en .bak et sert de repli si le fichier principal est illisible.

const FORMAT := 1
const CAMPAIGN := "user://campaign.json"
const MISSION := "user://mission.json"


static func write(path: String, payload: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK


## Contenu du fichier, ou de sa copie .bak s'il est illisible ; {} si aucun des deux.
static func read(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(p)) == OK and json.data is Dictionary:
			return json.data
	return {}


static func erase(path: String) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


# ---------------------------------------------------------------- campagne


static func load_campaign() -> Campaign:
	return Campaign.from_dict(read(CAMPAIGN))


static func save_campaign(c: Campaign) -> bool:
	return write(CAMPAIGN, c.to_dict())


# ---------------------------------------------------------------- mission en cours


## Les commandes portent des cases (Vector2i) : on les écrit sous forme « E5 ».
static func save_mission(mission_id: String, log: Array[Dictionary]) -> bool:
	var cmds: Array = []
	for cmd in log:
		var c := {}
		for k: String in cmd:
			var v: Variant = cmd[k]
			if v is Vector2i:
				c[k] = "-" if v.x < 0 else Cells.name_of(v)
			else:
				c[k] = v
		cmds.append(c)
	return write(MISSION, {"format": FORMAT, "mission": mission_id, "log": cmds})


## {mission, log} avec les cases reconverties, ou {} si rien d'exploitable.
static func load_mission() -> Dictionary:
	var d := read(MISSION)
	if int(d.get("format", 0)) != FORMAT or not d.has("mission"):
		return {}
	var log: Array[Dictionary] = []
	for c: Dictionary in d.get("log", []):
		var cmd := c.duplicate()
		for k in ["dest", "target"]:
			if cmd.has(k):
				cmd[k] = Vector2i(-1, -1) if cmd[k] == "-" else Cells.parse(cmd[k])
		log.append(cmd)
	return {"mission": d["mission"], "log": log}
