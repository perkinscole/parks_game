class_name HUD
extends CanvasLayer
## All on-screen UI: top stats bar, build toolbar, management panels,
## notifications, getting-started checklist and the inspector.

signal tool_selected(tool)
signal overlay_selected(mode: String)
signal jump_to(tile: Vector2i)

const INK := Color("2f3e2f")
const CREAM := Color("fdf6e3")
const GREEN := Color("3f8f5a")
const KIND_COLORS := {"good": Color("3f8f5a"), "warn": Color("e0a030"), "bad": Color("d9534f"), "info": Color("4a90d9")}

class Glyph extends Control:
	var kind := "coin"
	func _init(k: String, sz: float = 20.0) -> void:
		kind = k
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match kind:
			"coin":
				Art.circ(self, r, 0.5, 0.5, 0.45, Color("e0a82e"))
				Art.circ(self, r, 0.5, 0.5, 0.34, Color("f6d44d"))
				Art.box(self, r, 0.45, 0.25, 0.55, 0.75, Color("b98516"))
			"people":
				Art.circ(self, r, 0.5, 0.28, 0.2, Color("e9b98f"))
				Art.box(self, r, 0.25, 0.5, 0.75, 0.95, Color("4a90d9"))
			"star":
				var pts := PackedVector2Array()
				for i in 10:
					var a := -PI / 2.0 + i * PI / 5.0
					var rad := 0.48 if i % 2 == 0 else 0.2
					pts.append(Art.P(r, 0.5 + cos(a) * rad, 0.52 + sin(a) * rad))
				draw_colored_polygon(pts, Color("f2b632"))
			"leaf":
				Art.ellipse(self, Art.P(r, 0.5, 0.5), size.x * 0.3, size.y * 0.44, Color("4fae58"))
				Art.line(self, r, 0.5, 0.15, 0.5, 0.95, Color("2f6e45"), 0.07)
			"shield":
				Art.poly(self, r, [0.12, 0.12, 0.88, 0.12, 0.88, 0.55, 0.5, 0.95, 0.12, 0.55], Color("d9534f"))
				Art.box(self, r, 0.43, 0.25, 0.57, 0.7, Color.WHITE)
				Art.box(self, r, 0.28, 0.4, 0.72, 0.54, Color.WHITE)
			"flask":
				Art.poly(self, r, [0.4, 0.08, 0.6, 0.08, 0.6, 0.4, 0.9, 0.92, 0.1, 0.92, 0.4, 0.4], Color("cfe8f5"))
				Art.poly(self, r, [0.32, 0.6, 0.68, 0.6, 0.86, 0.9, 0.14, 0.9], Color("7e6bc4"))
			"sun":
				Art.circ(self, r, 0.5, 0.5, 0.3, Color("f2b632"))
				for i in 8:
					var a := i * PI / 4.0
					Art.line(self, r, 0.5 + cos(a) * 0.38, 0.5 + sin(a) * 0.38, 0.5 + cos(a) * 0.48, 0.5 + sin(a) * 0.48, Color("f2b632"), 0.07)
			"clock":
				Art.circ(self, r, 0.5, 0.5, 0.46, Color("4a90d9"))
				Art.circ(self, r, 0.5, 0.5, 0.36, Color.WHITE)
				Art.line(self, r, 0.5, 0.5, 0.5, 0.24, INK, 0.07)
				Art.line(self, r, 0.5, 0.5, 0.7, 0.56, INK, 0.07)
			"check":
				Art.circ(self, r, 0.5, 0.5, 0.46, GREEN)
				draw_polyline(PackedVector2Array([Art.P(r, 0.26, 0.52), Art.P(r, 0.44, 0.7), Art.P(r, 0.76, 0.32)]), Color.WHITE, size.x * 0.12)
			"todo":
				draw_arc(size * 0.5, size.x * 0.4, 0, TAU, 20, Color("b9ad8f"), size.x * 0.1)

class ToolButton extends Button:
	var tool
	var cost_text := ""
	var locked := false
	func _draw() -> void:
		var s := minf(size.x - 16.0, size.y - 28.0)
		var r := Rect2(Vector2((size.x - s) * 0.5, 8.0), Vector2(s, s))
		Art.structure(self, tool, r)
		var f := get_theme_default_font()
		var wd := f.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(f, Vector2((size.x - wd) * 0.5, size.y - 6.0), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5c6b55"))
		if locked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.93, 0.85, 0.7))

var game: Game
var font: Font
var root: Control
var current_tool = null
var panel_id := ""
var stat := {}
var speed_buttons: Array[Button] = []
var tool_row: HBoxContainer
var cat_buttons: Array[Button] = []
var cat_index := 0
var hint_label: Label
var side: PanelContainer
var side_title: Label
var side_body: VBoxContainer
var toasts: VBoxContainer
var objectives: PanelContainer
var obj_box: VBoxContainer
var inspector: PanelContainer
var inspector_label: Label
var _refresh := 0.0
var _panel_refresh := 0.0


func setup(g: Game, f: Font) -> void:
	game = g
	font = f
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_top()
	_build_toolbar()
	_build_side()
	_build_misc()
	game.toast.connect(_on_toast)
	_show_category(0)
	_update_stats()
	_update_objectives()


func _sb(bg: Color, radius: int = 10, border: Color = Color.TRANSPARENT, bw: int = 0, pad: float = 8.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 15
	var panel := _sb(Color(CREAM, 0.97), 14, Color("c9b98a"), 2, 10.0)
	panel.shadow_color = Color(0, 0, 0, 0.18)
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(0, 2)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_color("font_color", "Label", INK)
	th.set_stylebox("normal", "Button", _sb(Color("efe3c2"), 9, Color("d3c296"), 1, 6.0))
	th.set_stylebox("hover", "Button", _sb(Color("f8efd4"), 9, Color("b9a56f"), 1, 6.0))
	th.set_stylebox("pressed", "Button", _sb(Color("bfe3b4"), 9, GREEN, 2, 6.0))
	th.set_stylebox("disabled", "Button", _sb(Color("e8e2d2"), 9, Color("d9d2bd"), 1, 6.0))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", INK)
	th.set_color("font_disabled_color", "Button", Color("a39f8f"))
	th.set_stylebox("background", "ProgressBar", _sb(Color("e2d8ba"), 6, Color.TRANSPARENT, 0, 0.0))
	th.set_stylebox("fill", "ProgressBar", _sb(GREEN, 6, Color.TRANSPARENT, 0, 0.0))
	var tip := _sb(Color("2f3e2f"), 8, Color.TRANSPARENT, 0, 8.0)
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", Color("fdf6e3"))
	th.set_font_size("font_size", "TooltipLabel", 14)
	return th


func _label(text: String, size: int = 15, col: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _para(text: String, size: int = 13, col: Color = Color("5c6b55")) -> Label:
	var l := _label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _bar(v: float, col: Color = GREEN) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.value = clampf(v, 0.0, 1.0)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(80, 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", _sb(col, 6, Color.TRANSPARENT, 0, 0.0))
	return b


func _health_color(v: float) -> Color:
	if v >= 0.7: return GREEN
	if v >= 0.45: return Color("e0a030")
	return Color("d9534f")


# ------------------------------------------------------------------ top bar

func _chip(parent: Control, key: String, glyph: String, tip: String, minw: float) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	var gl := Glyph.new(glyph)
	gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(gl)
	var l := _label("", 16)
	l.custom_minimum_size.x = minw
	h.add_child(l)
	parent.add_child(h)
	stat[key] = l


func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 6
	root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	bar.add_child(h)
	_chip(h, "money", "coin", "Park funds", 78)
	_chip(h, "date", "clock", "Season, day and time. A year has four 6-day seasons; summer is busiest.", 215)
	_chip(h, "visitors", "people", "Visitors in the park right now", 34)
	_chip(h, "stars", "star", "Visitor rating (out of 5). Better ratings bring more visitors.", 30)
	_chip(h, "eco", "leaf", "Ecosystem health, as far as your researchers can tell. Shows ? until ecologists have surveyed the park.", 44)
	_chip(h, "weather", "sun", "Today's weather", 70)
	_chip(h, "safety", "shield", "Visitor safety record", 44)
	_chip(h, "research", "flask", "Research points to spend on new techniques", 30)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var labels := ["II", ">", ">>", ">>>"]
	var speeds := [0, 1, 2, 4]
	for i in 4:
		var b := _button(labels[i], func(): set_speed(speeds[i]), ["Pause (Space)", "Normal speed (1)", "Fast (2)", "Very fast (3)"][i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(40, 0)
		b.set_meta("speed", speeds[i])
		h.add_child(b)
		speed_buttons.append(b)

	var menu := HBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.offset_top = 58
	menu.offset_right = -8
	menu.add_theme_constant_override("separation", 4)
	root.add_child(menu)
	for id in ["Park", "Wildlife", "Staff", "Research", "Grants", "Finances"]:
		menu.add_child(_button(id, func(): toggle_panel(id)))
	var ov := OptionButton.new()
	ov.focus_mode = Control.FOCUS_NONE
	ov.tooltip_text = "Map overlay"
	for name in ["View: Normal", "View: Habitat", "View: Scenery", "View: Disturbance"]:
		ov.add_item(name)
	ov.item_selected.connect(func(i): overlay_selected.emit(["", "habitat", "scenery", "disturb"][i]))
	ov.add_theme_stylebox_override("normal", _sb(Color("efe3c2"), 9, Color("d3c296"), 1, 6.0))
	ov.add_theme_stylebox_override("hover", _sb(Color("f8efd4"), 9, Color("b9a56f"), 1, 6.0))
	ov.add_theme_stylebox_override("pressed", _sb(Color("f8efd4"), 9, Color("b9a56f"), 1, 6.0))
	ov.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		ov.add_theme_color_override(c, INK)
	menu.add_child(ov)


func set_speed(s: int) -> void:
	game.speed = s
	for b in speed_buttons:
		b.set_pressed_no_signal(b.get_meta("speed") == s)


# ------------------------------------------------------------------ toolbar

func _build_toolbar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wrap.offset_bottom = -6
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("separation", 4)
	root.add_child(wrap)

	hint_label = _label("", 14, Color.WHITE)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.12, 0.9))
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hint_label)

	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wrap.add_child(bar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	bar.add_child(v)
	var cats := HBoxContainer.new()
	cats.alignment = BoxContainer.ALIGNMENT_CENTER
	cats.add_theme_constant_override("separation", 4)
	v.add_child(cats)
	for i in D.CATEGORIES.size():
		var b := _button(D.CATEGORIES[i].name, func(): _show_category(i))
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 14)
		cats.add_child(b)
		cat_buttons.append(b)
	tool_row = HBoxContainer.new()
	tool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_row.add_theme_constant_override("separation", 6)
	tool_row.custom_minimum_size = Vector2(450, 76)
	v.add_child(tool_row)


func _show_category(i: int) -> void:
	cat_index = i
	for k in cat_buttons.size():
		cat_buttons[k].set_pressed_no_signal(k == i)
	for c in tool_row.get_children():
		c.queue_free()
	for tool in D.CATEGORIES[i].tools:
		var b := ToolButton.new()
		b.tool = tool
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(70, 76)
		var def: Dictionary = D.BUILD[tool] if tool is int else D.TOOLS[tool]
		b.cost_text = D.money(def.cost)
		var unit := ""
		if tool is String or tool == D.B.ROAD or tool == D.B.TRAIL or tool == D.B.PARKING:
			unit = " per tile"
		b.tooltip_text = "%s  (%s%s)\n%s" % [def.name, D.money(def.cost), unit, def.desc]
		if tool is int and def.upkeep > 0.9:
			b.tooltip_text += "\nUpkeep: %s/day" % D.money(def.upkeep)
		b.locked = tool is String and tool == "plant" and not game.has_tech("restore")
		b.button_pressed = _same_tool(tool, current_tool)
		b.pressed.connect(func(): select_tool(null if _same_tool(tool, current_tool) else tool))
		tool_row.add_child(b)


func _same_tool(a, b) -> bool:
	return typeof(a) == typeof(b) and a == b


func select_tool(tool) -> void:
	if tool is String and tool == "plant" and not game.has_tech("restore"):
		game.say("Planting native trees requires the Native Restoration research.", "info")
		tool = null
	current_tool = tool
	for c in tool_row.get_children():
		if c is ToolButton:
			c.set_pressed_no_signal(_same_tool(c.tool, tool))
	tool_selected.emit(tool)


# --------------------------------------------------------------- side panel

func _build_side() -> void:
	side = PanelContainer.new()
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side.offset_left = -348
	side.offset_right = -8
	side.offset_top = 98
	side.offset_bottom = -150
	side.visible = false
	root.add_child(side)
	var v := VBoxContainer.new()
	side.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	side_title = _label("", 20, GREEN)
	side_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(side_title)
	head.add_child(_button(" x ", func(): toggle_panel(panel_id)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 14)
	scroll.add_child(pad)
	side_body = VBoxContainer.new()
	side_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_body.add_theme_constant_override("separation", 6)
	pad.add_child(side_body)


func toggle_panel(id: String) -> void:
	if panel_id == id:
		panel_id = ""
		side.visible = false
		return
	panel_id = id
	side.visible = true
	side_title.text = id
	_fill_panel()


func _head(text: String) -> void:
	side_body.add_child(_label(text, 16, Color("6b4a2f")))


func _kv(k: String, v: String, col: Color = INK) -> void:
	var h := HBoxContainer.new()
	var a := _label(k, 14, Color("5c6b55"))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(_label(v, 14, col))
	side_body.add_child(h)


func _kbar(k: String, v: float, text: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var a := _label(k, 14, Color("5c6b55"))
	a.custom_minimum_size.x = 120
	h.add_child(a)
	h.add_child(_bar(v, _health_color(v)))
	var t := _label(text, 14)
	t.custom_minimum_size.x = 44
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(t)
	side_body.add_child(h)


func _fill_panel() -> void:
	for c in side_body.get_children():
		side_body.remove_child(c)
		c.queue_free()
	match panel_id:
		"Park": _panel_park()
		"Wildlife": _panel_wildlife()
		"Staff": _panel_staff()
		"Research": _panel_research()
		"Grants": _panel_grants()
		"Finances": _panel_finances()


func _panel_park() -> void:
	var g := game
	_kv("Status", "Open" if g.open else "Closed", GREEN if g.open else Color("d9534f"))
	_kbar("Visitor rating", g.stars / 5.0, "%.1f" % g.stars)
	if g.eco.understanding() >= 0.08:
		_kbar("Ecosystem (est.)", g.eco.health / 100.0, _eco_text())
	else:
		_kv("Ecosystem", "unknown: no research yet", Color("b5553f"))
	_kbar("Safety", g.safety / 100.0, "%d%%" % int(g.safety))
	_head("Visitors")
	_kv("In the park now", str(g.visitors.people_count()))
	_kv("Arrived today", str(g.visitors_today))
	_kv("Cars turned away (no parking)", str(g.turned_away_today), Color("d9534f") if g.turned_away_today > 0 else INK)
	_kv("Expected cars per day", str(int(g.demand)))
	_kv("Parking spaces", str(g.world.lot_tiles.size() * 2))
	_kv("All-time visitors", str(g.total_visitors))
	_head("Park condition")
	_kv("Littered tiles", str(g.world.litter_tiles.size()), Color("d9534f") if g.world.litter_tiles.size() > 10 else INK)
	var inv := g.eco.seen_invasive_count()
	_kv("Known invasive patches", str(inv), Color("d9534f") if inv > 0 else INK)
	if not g.world.fire_tiles.is_empty():
		_kv("Tiles on fire", str(g.world.fire_tiles.size()), Color("d9534f"))
	_kv("Trail length", "%d tiles" % g.world.trail_tiles.size())
	_kv("Serious incidents", str(g.serious_incidents))
	_head("What visitors are saying")
	var keys := g.comments.keys()
	keys.sort_custom(func(a, b): return g.comments[a] > g.comments[b])
	if keys.is_empty():
		side_body.add_child(_para("No comments yet."))
	for i in mini(7, keys.size()):
		side_body.add_child(_para("\"%s\"  x%d" % [keys[i], int(ceil(g.comments[keys[i]]))]))
	_head("Attractions")
	var any := false
	for s in g.world.structures.values():
		if s.kind in D.ATTRACTIONS:
			any = true
			var note := "" if not s.access.is_empty() else "  (no path!)"
			_kv(s.name + note, "appeal %d%%, %d visits" % [int(float(s.quality) * 100.0), s.visits], Color("d9534f") if note != "" else INK)
	if not any:
		side_body.add_child(_para("Nothing built yet. Overlooks, picnic areas and visitor centers give people a reason to come."))


func _eco_text() -> String:
	var u := game.eco.understanding()
	if u < 0.08:
		return "?"
	if u < 0.5:
		return "~%d%%" % (int(round(game.eco.health / 10.0)) * 10)
	return "%d%%" % int(game.eco.health)


func _panel_wildlife() -> void:
	var e := game.eco
	var u := e.understanding()
	var has_station := game.world.count_kind(D.B.RESEARCH) > 0
	if u < 0.08:
		side_body.add_child(_para("You know almost nothing about this ecosystem yet. Build a Research Station and hire ecologists: everything on this page comes from their field surveys. Without them, species can decline or invasives can spread unnoticed.", 14, Color("b5553f")))
	else:
		_kbar("Ecosystem (est.)", e.health / 100.0, _eco_text())
		if u >= 0.3:
			_kbar("Habitat", e.habitat_ratio, "%d%%" % int(e.habitat_ratio * 100.0))
		if e.known(e.sp_index("trout")) >= 1 or e.known(e.sp_index("salamander")) >= 1:
			_kbar("Water quality", e.water_quality, "%d%%" % int(e.water_quality * 100.0))
		else:
			side_body.add_child(_para("Water quality: unknown. Survey the shorelines."))
	_kbar("Understanding", u, "%d%%" % int(u * 100.0))
	side_body.add_child(_para("Field surveys completed: %d. Knowledge fades if monitoring stops." % e.surveys))
	_head("Weather and climate")
	var wtxt: String = D.WEATHER[game.weather].name
	if game.drought:
		wtxt += ", drought"
	_kv("Today", wtxt)
	if has_station:
		_kv("Forecast for tomorrow", D.WEATHER[game.weather_next].name)
		_kv("Warming since opening", "+%.2f degrees" % game.climate)
	else:
		side_body.add_child(_para("A Research Station adds a weather station: forecasts and climate records."))
	var titles := {"animal": "Animals", "insect": "Insects", "plant": "Plants"}
	for group in ["animal", "insect", "plant"]:
		_head(titles[group])
		for i in D.SPECIES.size():
			var sp: Dictionary = D.SPECIES[i]
			if sp.kind != group:
				continue
			var lvl := e.known(i)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			var a := _label(sp.name if lvl > 0 else "Unstudied species", 14, INK if lvl > 0 else Color("9aa392"))
			a.custom_minimum_size.x = 138
			h.add_child(a)
			if lvl == 0:
				h.add_child(_label("no data", 13, Color("9aa392")))
				side_body.add_child(h)
				continue
			var v := e.ratio(i)
			if lvl == 1:
				v = round(v * 4.0) / 4.0 # rough impressions only
			h.add_child(_bar(minf(v, 1.0), _health_color(v) if v <= 1.25 else Color("e0a030")))
			var st := _label(e.status(i) if lvl == 2 else "unsure", 13, _health_color(v))
			st.custom_minimum_size.x = 86
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(st)
			side_body.add_child(h)
			if lvl == 1:
				side_body.add_child(_para("Early impressions only. %s More surveys in its habitat will firm this up." % sp.desc, 12))
			else:
				var count := "%d colonies" % int(round(e.pops[i])) if sp.id == "orchid" else ("%d%% of natural abundance" % int(v * 100.0) if group != "animal" else "about %d animals" % int(round(e.pops[i])))
				var arrow := "rising" if e.trend[i] > 0.05 else ("falling" if e.trend[i] < -0.05 else "steady")
				side_body.add_child(_para("%s, %s. %s" % [count, arrow, D.NOTES[sp.id]], 12))


func _panel_staff() -> void:
	var st := game.staffing
	_kv("Daily wages", D.money(st.daily_wages()))
	for role in D.STAFF.keys():
		var def: Dictionary = D.STAFF[role]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var a := _label("%s   %d / %d" % [def.name, st.count(role), st.capacity(role)], 16, Color("6b4a2f"))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		var fire_cb := func():
			st.fire(role)
			_fill_panel()
		var minus := _button(" - ", fire_cb, "Let one go")
		minus.disabled = st.count(role) == 0
		h.add_child(minus)
		var hire_cb := func():
			var why: String = st.hire(role)
			if why != "":
				game.say(why, "info")
			_fill_panel()
		var plus := _button(" Hire ", hire_cb, "%s per day" % D.money(def.wage))
		h.add_child(plus)
		side_body.add_child(h)
		side_body.add_child(_para("%s  %s/day each. Based at a %s." % [def.desc, D.money(def.wage), D.BUILD[def.home].name]))
	_head("Team")
	if st.staff.is_empty():
		side_body.add_child(_para("No staff yet. Build a Ranger Station or Research Station, then hire here."))
	for s in st.staff:
		var doing := "idle"
		match s.job:
			"patrol": doing = "on patrol"
			"fire": doing = "fighting a wildfire"
			"rescue": doing = "responding to an emergency"
			"clean": doing = "collecting litter"
			"weed": doing = "removing invasives"
			"survey": doing = "surveying wildlife"
			"rest": doing = "heading back to base"
		_kv("%s (%s)" % [s.name, D.STAFF[s.role].name], doing)


func _panel_research() -> void:
	_kv("Research points", "%d" % int(game.research), Color("7e6bc4"))
	side_body.add_child(_para("Ecologists produce research every hour and from field surveys. Healthier ecosystems yield more."))
	for t in D.TECHS:
		var done: bool = game.has_tech(t.id)
		var h := HBoxContainer.new()
		var a := _label(t.name, 16, GREEN if done else Color("6b4a2f"))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		if done:
			h.add_child(Glyph.new("check", 20))
		else:
			var unlock_cb := func():
				game.unlock_tech(t.id)
				_show_category(cat_index)
				_fill_panel()
			var b := _button(" Unlock: %d " % t.cost, unlock_cb)
			b.disabled = game.research < t.cost
			h.add_child(b)
		side_body.add_child(h)
		side_body.add_child(_para(t.desc))
	_discoveries()


func _discoveries() -> void:
	_head("Discoveries (%d)" % game.discoveries.size())
	if game.discoveries.is_empty():
		side_body.add_child(_para("Nothing yet. Ecologists in the field notice how species, visitors, weather and your decisions affect one another."))
	for k in range(game.discoveries.size() - 1, -1, -1):
		var d: Dictionary = game.discoveries[k]
		side_body.add_child(_label(d.title, 14, GREEN))
		side_body.add_child(_para(d.text, 12))


func _panel_grants() -> void:
	var gr := game.grants
	_kv("Grants completed", str(gr.completed))
	_head("Active (%d / %d)" % [gr.active.size(), Grants.MAX_ACTIVE])
	if gr.active.is_empty():
		side_body.add_child(_para("No active grants. Accept an offer below."))
	for a in gr.active:
		side_body.add_child(_label("%s   %s" % [a.title, D.money(a.reward)], 15, GREEN))
		side_body.add_child(_para("%s\n%s. %d days left." % [a.desc, gr.progress(a), maxi(0, int(a.deadline) - game.day)]))
	_head("Offers")
	if gr.offers.is_empty():
		side_body.add_child(_para("No offers right now. New ones arrive every couple of days."))
	for i in gr.offers.size():
		var o: Dictionary = gr.offers[i]
		var h := HBoxContainer.new()
		var a := _label("%s   %s" % [o.title, D.money(o.reward)], 15, Color("6b4a2f"))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(a)
		var accept_cb := func():
			gr.accept(i)
			_fill_panel()
		var b := _button(" Accept ", accept_cb)
		b.disabled = gr.active.size() >= Grants.MAX_ACTIVE
		h.add_child(b)
		side_body.add_child(h)
		side_body.add_child(_para("%s  You get %d days. Offer expires in %d." % [o.desc, o.days, maxi(0, int(o.expires) - game.day)]))


func _panel_finances() -> void:
	var g := game
	_kv("Balance", D.money(g.money), GREEN if g.money >= 0 else Color("d9534f"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var a := _label("Entry fee per car", 15)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var less := func():
		g.set_fee(g.fee - 1)
		_fill_panel()
	h.add_child(_button(" - ", less))
	var f := _label(D.money(g.fee), 17, GREEN)
	f.custom_minimum_size.x = 40
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(f)
	var more := func():
		g.set_fee(g.fee + 1)
		_fill_panel()
	h.add_child(_button(" + ", more))
	side_body.add_child(h)
	side_body.add_child(_para("Visitors think about %s is fair for this park. Charge more and fewer come (and they grumble); the more there is to see, the more they will pay." % D.money(g.fair_fee)))
	for pair in [["Today so far", g.ledger], ["Yesterday", g.ledger_prev]]:
		_head(pair[0])
		var led: Dictionary = pair[1]
		var total := 0.0
		var keys := led.keys()
		keys.sort_custom(func(x, y): return led[x] > led[y])
		for k in keys:
			if absf(led[k]) < 0.5:
				continue
			total += led[k]
			_kv(k, D.money(led[k]), GREEN if led[k] > 0 else Color("b5553f"))
		_kv("Net", D.money(total), GREEN if total >= 0 else Color("d9534f"))


# ------------------------------------------------- toasts, checklist, inspector

func _build_misc() -> void:
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toasts.offset_left = 8
	toasts.offset_bottom = -8
	toasts.custom_minimum_size.x = 330
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 4)
	root.add_child(toasts)

	objectives = PanelContainer.new()
	objectives.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objectives.offset_left = 8
	objectives.offset_top = 58
	objectives.custom_minimum_size.x = 300
	root.add_child(objectives)
	obj_box = VBoxContainer.new()
	obj_box.add_theme_constant_override("separation", 3)
	objectives.add_child(obj_box)

	inspector = PanelContainer.new()
	inspector.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	inspector.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	inspector.grow_vertical = Control.GROW_DIRECTION_BEGIN
	inspector.offset_right = -8
	inspector.offset_bottom = -8
	inspector.custom_minimum_size.x = 290
	inspector.visible = false
	inspector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(inspector)
	inspector_label = _para("", 13, INK)
	inspector_label.custom_minimum_size.x = 270
	inspector.add_child(inspector_label)


func set_inspector(text: String) -> void:
	inspector.visible = text != ""
	if inspector_label.text != text:
		inspector_label.text = text
		inspector.size = Vector2.ZERO
	_place_inspector.call_deferred()


func _place_inspector() -> void:
	inspector.size = inspector.get_combined_minimum_size()
	inspector.position = root.size - inspector.size - Vector2(8, 8)


func _on_toast(text: String, kind: String, tile: Vector2i) -> void:
	var p := PanelContainer.new()
	var col: Color = KIND_COLORS.get(kind, KIND_COLORS.info)
	var sb := _sb(Color(CREAM, 0.97), 10, col, 0, 7.0)
	sb.border_width_left = 6
	sb.border_color = col
	p.add_theme_stylebox_override("panel", sb)
	var l := _para(text, 13, INK)
	l.custom_minimum_size.x = 300
	p.add_child(l)
	if tile.x >= 0:
		p.tooltip_text = "Click to go there"
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var click := func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				jump_to.emit(tile)
		p.gui_input.connect(click)
	else:
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	while toasts.get_child_count() > 5:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _update_objectives() -> void:
	var w := game.world
	var road_n := 0
	for b in w.build:
		if b == D.B.ROAD:
			road_n += 1
	var steps := [
		["Extend the road from the highway", road_n >= 6],
		["Place an Entrance Gate on the road", w.count_kind(D.B.GATE) > 0],
		["Build a Parking Lot beside the road", w.lot_tiles.size() >= 4],
		["Lay a Trail from the parking lot", w.trail_tiles.size() >= 8],
		["Build a Scenic Overlook on the trail", w.count_kind(D.B.OVERLOOK) > 0],
		["Add a Restroom and a Trash bin", w.count_kind(D.B.RESTROOM) > 0 and w.count_kind(D.B.BIN) > 0],
		["Build a Ranger Station and hire a ranger", game.staffing.count("ranger") > 0],
		["Build a Research Station and hire an ecologist", game.staffing.count("eco") > 0],
		["Accept a grant (Grants menu)", game.grants.active.size() + game.grants.completed > 0],
	]
	var all_done := true
	for s in steps:
		if not s[1]:
			all_done = false
	if all_done:
		objectives.visible = false
		return
	for c in obj_box.get_children():
		obj_box.remove_child(c)
		c.queue_free()
	obj_box.add_child(_label("Getting started", 16, GREEN))
	var first_open := true
	for s in steps:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var gl := Glyph.new("check" if s[1] else "todo", 16)
		gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(gl)
		var col := Color("9aa392") if s[1] else (INK if first_open else Color("7d8a76"))
		h.add_child(_label(s[0], 13, col))
		if not s[1]:
			first_open = false
		obj_box.add_child(h)
	objectives.reset_size()


func _update_stats() -> void:
	var g := game
	stat.money.text = D.money(g.money)
	stat.money.add_theme_color_override("font_color", INK if g.money >= 0 else Color("d9534f"))
	stat.date.text = g.date_text()
	stat.visitors.text = str(g.visitors.people_count())
	stat.stars.text = "%.1f" % g.stars
	stat.eco.text = _eco_text()
	stat.eco.add_theme_color_override("font_color", _health_color(g.eco.health / 100.0) if g.eco.health < 70.0 and g.eco.understanding() >= 0.08 else INK)
	stat.weather.text = str(D.WEATHER[g.weather].name) + (" (drought)" if g.drought else "")
	stat.safety.text = "%d%%" % int(g.safety)
	stat.research.text = str(int(g.research))
	for b in speed_buttons:
		b.set_pressed_no_signal(b.get_meta("speed") == g.speed)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_update_stats()
	_panel_refresh -= delta
	if _panel_refresh <= 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_panel_refresh = 1.0
		_update_objectives()
		if side.visible:
			_fill_panel()
