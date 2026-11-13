class_name ResearchView
extends PanelContainer
## Écran d'ATHENA : arbre de découverte et équipage.
## N'affiche que ce que la Meute a rendu visible (pistes, hypothèses étudiables, études,
## confirmées). Démarrer une étude passe par Campaign ; la scène principale sauvegarde.

signal study_started(id: String)
signal closed

const BRANCH_KEYS := {
	"observation": "RES_BRANCH_OBSERVATION",
	"link": "RES_BRANCH_LINK",
	"engineering": "RES_BRANCH_ENGINEERING",
	"xenology": "RES_BRANCH_XENOLOGY",
	"crew": "RES_BRANCH_CREW"
}
const STATE_COLORS := {
	"lead": Color("8a8f98"),
	"available": Color("EADFC8"),
	"studying": Color("2fe0c8"),
	"confirmed": Color("2fe0c8"),
	"excluded": Color("5a5f68")
}

var campaign: Campaign
var _header: Label
var _list: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14181d")
	style.set_content_margin_all(20)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var title := _label(34, BoardView.IVORY)
	title.text = "ATHENA"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := Button.new()
	back.text = tr("UI_BACK")
	back.custom_minimum_size = Vector2(160, 72)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(func() -> void: closed.emit())
	top.add_child(back)
	_header = _label(24, Color("b8bcc4"))
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)


func show_campaign(c: Campaign) -> void:
	campaign = c
	_rebuild()
	visible = true


func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var c := campaign
	_header.text = (
		tr("RES_HEADER")
		% [
			c.data,
			c.studying.size(),
			c.lanes(),
			tr("STAGE_" + c.ship_stage.to_upper()),
			c.crew_awake(),
			6 - c.crew_awake()
		]
	)
	var shown := 0
	for branch: String in Campaign.BRANCHES:
		var ids: Array[String] = []
		for id: String in c.hypotheses:
			if c.hypotheses[id]["branch"] == branch and c.state(id) != "hidden":
				ids.append(id)
		if ids.is_empty():
			continue
		var head := _label(28, BoardView.PACK)
		head.text = tr(BRANCH_KEYS[branch])
		_list.add_child(head)
		for id in ids:
			_list.add_child(_card(id))
			shown += 1
	if shown == 0:
		var empty := _label(24, Color("b8bcc4"))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = tr("RES_EMPTY")
		_list.add_child(empty)


func _card(id: String) -> Control:
	var c := campaign
	var h := c.hypotheses[id]
	var st := c.state(id)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1e2329")
	style.border_color = STATE_COLORS.get(st, Color.GRAY)
	style.set_border_width_all(2 if st in ["available", "studying"] else 1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := _label(26, STATE_COLORS.get(st, Color.GRAY))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = "%s — %s" % [tr(h["title_key"]), tr("RES_STATE_" + st.to_upper())]
	box.add_child(title)
	var detail := _label(22, Color("c8ccd2"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match st:
		"lead":
			var names := PackedStringArray()
			for d in c.missing_discoveries(id):
				names.append(tr(c.discovery_defs[d]["title_key"]))
			detail.text = (
				tr("RES_MISSING") % ", ".join(names) if not names.is_empty() else tr("RES_PARENTS")
			)
		"studying":
			detail.text = (
				tr(h["title_key"] + "_FX")
				+ "\n"
				+ tr("RES_PROGRESS") % [c.studying[id], c.cycles_needed(id)]
			)
		_:
			detail.text = tr(h["title_key"] + "_FX")
	box.add_child(detail)
	if st == "available":
		var row := HBoxContainer.new()
		box.add_child(row)
		var cost := _label(22, Color("b8bcc4"))
		cost.text = tr("RES_COST") % [int(h["data_cost"]), c.cycles_needed(id)]
		cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cost)
		var b := Button.new()
		b.text = tr("RES_STUDY")
		b.custom_minimum_size = Vector2(180, 64)
		b.add_theme_font_size_override("font_size", 24)
		var refusal := c.study_refusal(id)
		b.disabled = not refusal.is_empty()
		if not refusal.is_empty():
			b.tooltip_text = tr(refusal)
			cost.text += "  ·  " + tr(refusal)
		b.pressed.connect(_study.bind(id))
		row.add_child(b)
	return panel


func _study(id: String) -> void:
	if campaign.start_study(id):
		study_started.emit(id)
	_rebuild()


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
