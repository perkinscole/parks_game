class_name HUD
extends CanvasLayer
## All on-screen UI: top stats bar, build toolbar, management panels,
## notifications, getting-started checklist and the inspector.

signal tool_selected(tool)
signal overlay_selected(mode: String)
signal jump_to(tile: Vector2i)
signal menu_action(what: String)

const INK := Color("f2f6f8")
const PANEL := Color("1c2e3b")
const ACCENT := Color("6fd3ff")
const MONEY := Color("9be36a")
const CREAM := Color("1c2e3b")
const GREEN := Color("7fd18b")
const KIND_COLORS := {"good": Color("7fd18b"), "warn": Color("f2b84b"), "bad": Color("ff6b5e"), "info": Color("6bb6ff")}

class Glyph extends Control:
	var kind := "coin"
	func _init(k: String, sz: float = 20.0) -> void:
		kind = k
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if Icons.pic.has(kind):
			# a photograph of the real model, on a round backing
			draw_circle(size * 0.5, size.x * 0.5, Color("2c4658") if kind.begins_with("face") or kind == "ranger" or kind == "people" else Color(0.16, 0.26, 0.2, 0.9))
			draw_texture_rect(Icons.pic[kind], r, false)
			return
		if Art.glyph(self, kind, r):
			return
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
				Art.line(self, r, 0.5, 0.5, 0.5, 0.24, Color("2f3e2f"), 0.07)
				Art.line(self, r, 0.5, 0.5, 0.7, 0.56, Color("2f3e2f"), 0.07)
			"check":
				Art.circ(self, r, 0.5, 0.5, 0.46, Color("3f8f5a"))
				draw_polyline(PackedVector2Array([Art.P(r, 0.26, 0.52), Art.P(r, 0.44, 0.7), Art.P(r, 0.76, 0.32)]), Color.WHITE, size.x * 0.12)
			"ranger":
				Art.circ(self, r, 0.5, 0.5, 0.5, Color("2f4a3a"))
				Art.box(self, r, 0.22, 0.72, 0.78, 1.0, Color("6f8f5a"))
				Art.circ(self, r, 0.5, 0.52, 0.2, Color("e2b08a"))
				Art.box(self, r, 0.22, 0.34, 0.78, 0.4, Color("7a5a36"))
				Art.poly(self, r, [0.34, 0.36, 0.4, 0.16, 0.6, 0.16, 0.66, 0.36], Color("8a683f"))
				Art.circ(self, r, 0.43, 0.52, 0.025, Color("2a2a2a"))
				Art.circ(self, r, 0.57, 0.52, 0.025, Color("2a2a2a"))
			"todo":
				draw_arc(size * 0.5, size.x * 0.4, 0, TAU, 20, Color("b9ad8f"), size.x * 0.1)

class ToolButton extends Button:
	var tool
	var cost_text := ""
	var label_text := ""
	var locked := false
	var lock_text := ""
	var compact := false # icon only, for the category bar
	func _draw() -> void:
		var s := minf(size.x - 30.0, size.y - 44.0)
		var r := Rect2(Vector2((size.x - s) * 0.5, 7.0), Vector2(s, s))
		if compact:
			s = minf(size.x, size.y) - 14.0
			r = Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		# a little diorama tile: sky above, ground below, the model standing on it
		var tile := Rect2(r.position - Vector2(6, 3), r.size + Vector2(12, 7))
		var sky := StyleBoxFlat.new()
		sky.bg_color = Color("9fc4dc") if not button_pressed else Color("bfe2f7")
		sky.set_corner_radius_all(7)
		sky.border_color = Color("6fd3ff") if button_pressed or is_hovered() else Color(1, 1, 1, 0.16)
		sky.set_border_width_all(2 if button_pressed else 1)
		draw_style_box(sky, tile)
		var turf := StyleBoxFlat.new()
		turf.bg_color = Color("6f9a55")
		turf.corner_radius_bottom_left = 6
		turf.corner_radius_bottom_right = 6
		draw_style_box(turf, Rect2(tile.position + Vector2(1, tile.size.y * 0.68), Vector2(tile.size.x - 2, tile.size.y * 0.32 - 1)))
		if tool is int and Icons.tex.has(tool):
			var big := r.grow(5.0)
			draw_texture_rect(Icons.tex[tool], Rect2(big.position + Vector2(2, 4), big.size), false, Color(0, 0, 0, 0.22))
			draw_texture_rect(Icons.tex[tool], big, false)
		else:
			Art.structure(self, tool, r)
		var f := get_theme_default_font()
		var wd := f.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var nw := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(f, Vector2((size.x - nw) * 0.5, size.y - 20.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e9eef0"))
		draw_string(f, Vector2((size.x - wd) * 0.5, size.y - 6.0), cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f2c879"))
		if locked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.11, 0.78))
			var lw := f.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(f, Vector2((size.x - lw) * 0.5, size.y * 0.45), lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffcf7a"))

var game: Game
var font: Font
var root: Control
var current_tool = null
var view_tile := Vector2i.ZERO
var quality_box: OptionButton
var tray_title: Label
var tray: PanelContainer
var tool_wrap: VBoxContainer
var card: PanelContainer
var card_title: Label
var card_cost: Label
var card_desc: Label
var card_chips: HBoxContainer
var card_after: Label
var issues_box: PanelContainer
var issues_list: VBoxContainer
var _hover_tool = null
var _card_tool = "none"
var _last_money := -1.0
var _toast_side := 0.0
var panel_id := ""
var stat := {}
var speed_buttons: Array[Button] = []
var tool_row: HBoxContainer
var cat_buttons: Array[Button] = []
var cat_index := 0
var hint_label: Label
var cam_orbit := Vector2.ZERO
# story and guided first day
var guide: PanelContainer
var guide_title: Label
var guide_text: Label
var guide_next: Button
var guide_skip: Button
var dim: ColorRect
var _pages: Array = []
var _page := 0
var _guiding := false
var _guide_step := -1
var _pulse := 0.0 # held camera buttons: x turns, y tilts
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
	_build_guide()
	_build_issues()
	game.toast.connect(_on_toast)
	game.leveled.connect(_on_level)
	_show_category(0)
	_update_stats()
	_update_objectives()


func _sb(bg: Color, radius: int = 6, border: Color = Color.TRANSPARENT, bw: int = 0, pad: float = 8.0) -> StyleBoxFlat:
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
	th.default_font_size = 14
	var panel := _sb(Color(CREAM, 0.93), 10, Color(ACCENT, 0.45), 1, 10.0)
	panel.shadow_color = Color(0, 0, 0, 0.18)
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(0, 2)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_color("font_color", "Label", INK)
	th.set_stylebox("normal", "Button", _sb(Color("26404f"), 7, Color(ACCENT, 0.3), 1, 6.0))
	th.set_stylebox("hover", "Button", _sb(Color("2d4a5c"), 7, ACCENT, 1, 6.0))
	th.set_stylebox("pressed", "Button", _sb(Color("2f86ad"), 7, Color.WHITE, 1, 6.0))
	th.set_stylebox("disabled", "Button", _sb(Color("22323d"), 7, Color(1, 1, 1, 0.08), 1, 6.0))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", INK)
	th.set_color("font_disabled_color", "Button", Color("5a666d"))
	th.set_stylebox("background", "ProgressBar", _sb(Color(1, 1, 1, 0.1), 3, Color.TRANSPARENT, 0, 0.0))
	th.set_stylebox("fill", "ProgressBar", _sb(GREEN, 6, Color.TRANSPARENT, 0, 0.0))
	var tip := _sb(Color("14222c"), 8, Color(ACCENT, 0.6), 1, 8.0)
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", Color("e9eef0"))
	th.set_font_size("font_size", "TooltipLabel", 14)
	return th


func _label(text: String, size: int = 15, col: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _para(text: String, size: int = 13, col: Color = Color("a3afb6")) -> Label:
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
	if v >= 0.45: return Color("f2b84b")
	return Color("ff6b5e")


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


## A round icon button, like the info-view buttons in city builders.
func _round_button(glyph: String, tip: String, cb: Callable, size: float = 42.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(size, size)
	var r := int(size / 2.0)
	b.add_theme_stylebox_override("normal", _sb(Color(PANEL, 0.94), r, Color(ACCENT, 0.55), 2, 0.0))
	b.add_theme_stylebox_override("hover", _sb(Color("2d4a5c"), r, ACCENT, 2, 0.0))
	b.add_theme_stylebox_override("pressed", _sb(Color("2f86ad"), r, Color.WHITE, 2, 0.0))
	b.pressed.connect(cb)
	if glyph.length() <= 2:
		b.text = glyph
		b.add_theme_font_size_override("font_size", 20)
	else:
		var fill := 0.84 if Icons.pic.has(glyph) else 0.5
		var gl := Glyph.new(glyph, size * fill)
		gl.position = Vector2.ONE * size * (1.0 - fill) * 0.5
		gl.size = Vector2.ONE * size * fill
		b.add_child(gl)
	return b


func _dropdown(items: Array, tip: String, cb: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.tooltip_text = tip
	for name in items:
		ob.add_item(name)
	ob.item_selected.connect(cb)
	ob.add_theme_stylebox_override("normal", _sb(Color("26404f"), 14, Color(ACCENT, 0.4), 1, 7.0))
	ob.add_theme_stylebox_override("hover", _sb(Color("2d4a5c"), 14, ACCENT, 1, 7.0))
	ob.add_theme_stylebox_override("pressed", _sb(Color("2d4a5c"), 14, ACCENT, 1, 7.0))
	ob.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		ob.add_theme_color_override(c, INK)
	return ob


## Top of the screen: park-health readouts on the left, management buttons
## down the left edge, view and system controls on the right.
func _build_top() -> void:
	var info := PanelContainer.new()
	info.set_anchors_preset(Control.PRESET_TOP_LEFT)
	info.offset_left = 8
	info.offset_top = 8
	info.add_theme_stylebox_override("panel", _sb(Color(PANEL, 0.92), 18, Color(ACCENT, 0.4), 1, 7.0))
	root.add_child(info)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 14)
	info.add_child(ih)
	_chip(ih, "eco", "leaf", "Ecosystem health, as far as your researchers can tell. Shows ? until ecologists have surveyed the park.", 40)
	_chip(ih, "safety", "shield", "Visitor safety record", 40)
	_chip(ih, "research", "flask", "Research points to spend on new techniques", 28)
	_chip(ih, "weather", "sun", "Weather where you are looking. Each part of the park has its own.", 112)

	var rail := VBoxContainer.new()
	rail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rail.offset_left = 8
	rail.offset_top = 58
	rail.add_theme_constant_override("separation", 6)
	root.add_child(rail)
	var panels := [["Park", "star", "Park overview and what visitors are saying"], ["Wildlife", "sp_elk" if Icons.pic.has("sp_elk") else "leaf", "Wildlife, weather and what your researchers know"],
		["Staff", "face_ranger" if Icons.pic.has("face_ranger") else "people", "Hire and manage staff"], ["Research", "b_research" if Icons.pic.has("b_research") else "flask", "Research and discoveries"],
		["Grants", "check", "Grants"], ["Finances", "coin", "Entry fee, income and costs"]]
	for p in panels:
		var id: String = p[0]
		rail.add_child(_round_button(p[1], "%s: %s" % [id, p[2]], func(): toggle_panel(id)))

	var sys := HBoxContainer.new()
	sys.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sys.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	sys.offset_top = 8
	sys.offset_right = -8
	sys.add_theme_constant_override("separation", 6)
	root.add_child(sys)
	sys.add_child(_dropdown(["View: Normal", "View: Habitat", "View: Scenery", "View: Disturbance", "View: Accessibility"], "Info views",
		func(i): overlay_selected.emit(["", "habitat", "scenery", "disturb", "access"][i])))
	quality_box = _dropdown(["Graphics: Fast", "Graphics: Balanced", "Graphics: Best"], "Graphics quality. Choose Fast if the game feels laggy.",
		func(i): menu_action.emit("quality%d" % i))
	sys.add_child(quality_box)
	sys.add_child(_round_button("+", "Zoom in (scroll, pinch, or the + key)", func(): menu_action.emit("zoom_in"), 36.0))
	sys.add_child(_round_button("-", "Zoom out (scroll, pinch, or the - key)", func(): menu_action.emit("zoom_out"), 36.0))
	sys.add_child(_round_button("?", "Show the controls", func(): menu_action.emit("help"), 36.0))
	# camera pad: hold a button to turn or tilt the view
	var pad := GridContainer.new()
	pad.columns = 3
	pad.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	pad.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pad.grow_vertical = Control.GROW_DIRECTION_BOTH
	pad.offset_right = -10
	pad.add_theme_constant_override("h_separation", 4)
	pad.add_theme_constant_override("v_separation", 4)
	root.add_child(pad)
	var cells := [null, ["^", "Tilt up (R)", Vector2(0, 1)], null,
		["<", "Turn left (Q, or right-drag / Alt-drag)", Vector2(-1, 0)], ["N", "Face north (Home)", Vector2.ZERO], [">", "Turn right (E)", Vector2(1, 0)],
		null, ["v", "Tilt down (F)", Vector2(0, -1)], null]
	for cell in cells:
		if cell == null:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(34, 34)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.add_child(gap)
			continue
		var dirv: Vector2 = cell[2]
		var cb := _round_button(cell[0], cell[1], func(): if dirv == Vector2.ZERO: menu_action.emit("north"), 34.0)
		cb.add_theme_font_size_override("font_size", 16)
		if dirv != Vector2.ZERO:
			cb.button_down.connect(func(): cam_orbit = dirv)
			cb.button_up.connect(func(): cam_orbit = Vector2.ZERO)
		pad.add_child(cb)
	var save := _button("Save", func(): menu_action.emit("save"), "Save the park (it also saves by itself every morning)")
	sys.add_child(save)
	sys.add_child(_button("Menu", func(): menu_action.emit("menu"), "Save and return to the main menu"))


func set_quality(level: int) -> void:
	quality_box.select(level)


func set_speed(s: int) -> void:
	game.speed = s
	for b in speed_buttons:
		b.set_pressed_no_signal(b.get_meta("speed") == s)


# ------------------------------------------------------------------ toolbar

## Bottom of the screen: one bar with time controls on the left, build
## categories in the middle and the park's vital numbers on the right. The
## tools of the chosen category open in a tray just above it.
func _build_toolbar() -> void:
	var wrap := VBoxContainer.new()
	wrap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	wrap.offset_bottom = -62
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("separation", 4)
	root.add_child(wrap)
	hint_label = _label("", 14, Color.WHITE)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.14, 0.9))
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(hint_label)
	tool_wrap = wrap
	_build_card(wrap)
	tray = PanelContainer.new()
	tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tray.add_theme_stylebox_override("panel", _sb(Color(PANEL, 0.94), 10, Color(ACCENT, 0.45), 1, 8.0))
	wrap.add_child(tray)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tray.add_child(tv)
	tray_title = _label("", 13, ACCENT)
	tv.add_child(tray_title)
	tool_row = HBoxContainer.new()
	tool_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tool_row.add_theme_constant_override("separation", 6)
	tool_row.custom_minimum_size = Vector2(320, 86)
	tv.add_child(tool_row)

	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := _sb(Color(PANEL, 0.96), 0, Color.TRANSPARENT, 0, 6.0)
	style.border_width_top = 2
	style.border_color = Color(ACCENT, 0.7)
	bar.add_theme_stylebox_override("panel", style)
	root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bar.add_child(h)

	# time
	var labels := ["II", ">", ">>", ">>>"]
	var speeds := [0, 1, 2, 4]
	for i in 4:
		var b := _button(labels[i], func(): set_speed(speeds[i]), ["Pause (Space)", "Normal speed (1)", "Fast (2)", "Very fast (3)"][i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(38, 38)
		b.set_meta("speed", speeds[i])
		h.add_child(b)
		speed_buttons.append(b)
	var date := _label("", 15)
	date.custom_minimum_size.x = 196
	date.tooltip_text = "Season, day and time. A year has four 6-day seasons; summer is busiest."
	date.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(date)
	stat["date"] = date

	var left_gap := Control.new()
	left_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left_gap)
	# build categories
	for i in D.CATEGORIES.size():
		var b := ToolButton.new()
		b.tool = D.CATEGORIES[i].tools[0]
		b.compact = true
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 44)
		b.tooltip_text = D.CATEGORIES[i].name
		b.pressed.connect(func(): _show_category(i))
		h.add_child(b)
		cat_buttons.append(b)
	var right_gap := Control.new()
	right_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right_gap)

	# vital numbers
	_chip(h, "visitors", "people", "Visitors in the park right now", 36)
	_chip(h, "stars", "star", "Visitor rating (out of 5). Better ratings bring more visitors.", 30)
	var money_box := VBoxContainer.new()
	money_box.add_theme_constant_override("separation", -3)
	money_box.custom_minimum_size.x = 120
	money_box.tooltip_text = "Park funds, and today's income minus costs so far"
	var money := _label("", 20, MONEY)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_box.add_child(money)
	var net := _label("", 12, Color("a3afb6"))
	net.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_box.add_child(net)
	h.add_child(money_box)
	stat["money"] = money
	stat["net"] = net


## The card above the build tray: what the thing costs to buy and to keep, and
## which of the park's goals it helps or hurts.
func _build_card(parent: Control) -> void:
	card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size.x = 560
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _sb(Color(PANEL, 0.96), 10, Color(ACCENT, 0.6), 1, 10.0))
	card.visible = false
	parent.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	card_title = _label("", 16, Color.WHITE)
	card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(card_title)
	card_cost = _label("", 14, Color("f2c879"))
	top.add_child(card_cost)
	card_desc = _para("", 13, Color("c5cfd5"))
	card_desc.custom_minimum_size.x = 540
	v.add_child(card_desc)
	card_chips = HBoxContainer.new()
	card_chips.add_theme_constant_override("separation", 6)
	v.add_child(card_chips)
	card_after = _label("", 12, Color("a3afb6"))
	v.add_child(card_after)


func _effect_chip(name: String, v: int) -> Control:
	var p := PanelContainer.new()
	var good := v > 0
	var col := Color("5fd08a") if good else Color("ff8a70")
	p.add_theme_stylebox_override("panel", _sb(Color(col, 0.16), 8, Color(col, 0.7), 1, 5.0))
	var arrows := ("+" if good else "-").repeat(absi(v))
	var l := _label("%s %s" % [name, arrows], 12, col)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _update_card() -> void:
	var tool = _hover_tool if _hover_tool != null else current_tool
	if tool == null:
		card.visible = false
		_card_tool = "none"
		return
	card.visible = true
	var def: Dictionary = D.BUILD[tool] if tool is int else D.TOOLS[tool]
	var per_tile: bool = tool is String or tool == D.B.ROAD or tool == D.B.TRAIL or tool == D.B.PARKING
	var cost: float = def.cost
	# the money line changes as funds do, so it is refreshed every time
	if game.unlock_level(tool) > game.level:
		card_after.text = "Locked. Unlocks when the park becomes a %s (level %d)." % [D.LEVELS[game.unlock_level(tool) - 1].name, game.unlock_level(tool)]
	elif per_tile:
		card_after.text = "You have %s: enough for about %d tiles. The total shows by the pointer as you drag." % [D.money(game.money), int(game.money / maxf(cost, 1.0))]
	elif cost > game.money:
		card_after.text = "You have %s. You need %s more." % [D.money(game.money), D.money(cost - game.money)]
	else:
		card_after.text = "You have %s. After buying: %s." % [D.money(game.money), D.money(game.money - cost)]
	card_after.add_theme_color_override("font_color", Color("ffcf7a") if game.unlock_level(tool) > game.level else (Color("ff8a70") if cost > game.money else Color("a3afb6")))
	if _same_tool(tool, _card_tool):
		return
	_card_tool = tool
	card_title.text = def.name
	var price := "%s%s" % [D.money(cost), " per tile" if per_tile else ""]
	if tool is int and def.upkeep > 0.0:
		price += "   +  %s/day upkeep%s" % [D.money(def.upkeep) if def.upkeep >= 1.0 else "$%.2f" % def.upkeep, " per tile" if per_tile else ""]
	card_cost.text = price
	card_desc.text = def.desc
	for c in card_chips.get_children():
		card_chips.remove_child(c)
		c.queue_free()
	var fx: Array = D.EFFECTS.get(tool, [0, 0, 0, 0, 0])
	var names := ["Visitors", "Nature", "Safety", "Income", "Knowledge"]
	var any := false
	for k in 5:
		if fx[k] != 0:
			card_chips.add_child(_effect_chip(names[k], fx[k]))
			any = true
	if tool is int and def.dist > 0:
		card_chips.add_child(_label("Wildlife avoids it within %d tile%s" % [def.dist, "" if def.dist == 1 else "s"], 12, Color("a3afb6")))
	card_chips.visible = any or (tool is int and def.dist > 0)
	card.size = Vector2(560, 0)


## Money going out or coming in drifts up from the funds figure.
func _money_pop(delta_money: float) -> void:
	var l := _label(("+" if delta_money > 0 else "-") + D.money(absf(delta_money)), 16, MONEY if delta_money > 0 else Color("ff8a70"))
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.1, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	var from: Vector2 = stat.money.global_position + Vector2(stat.money.size.x - 70.0, -22.0)
	l.position = from
	var tw := create_tween()
	tw.tween_property(l, "position", from + Vector2(0, -46), 1.3)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.5)
	tw.tween_callback(l.queue_free)


func _show_category(i: int) -> void:
	cat_index = i
	tray_title.text = D.CATEGORIES[i].name
	for k in cat_buttons.size():
		cat_buttons[k].set_pressed_no_signal(k == i)
	for c in tool_row.get_children():
		c.queue_free()
	for tool in D.CATEGORIES[i].tools:
		var b := ToolButton.new()
		b.tool = tool
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		# a full tray uses narrower buttons so it stays clear of the messages
		b.custom_minimum_size = Vector2(98 if D.CATEGORIES[i].tools.size() <= 5 else (86 if D.CATEGORIES[i].tools.size() == 6 else 80), 86)
		var def: Dictionary = D.BUILD[tool] if tool is int else D.TOOLS[tool]
		b.cost_text = D.money(def.cost)
		b.label_text = def.name if str(def.name).length() <= 13 else str(def.name).substr(0, 12) + "."
		var unit := ""
		if tool is String or tool == D.B.ROAD or tool == D.B.TRAIL or tool == D.B.PARKING:
			unit = " per tile"
		b.tooltip_text = "%s  (%s%s)\n%s" % [def.name, D.money(def.cost), unit, def.desc]
		if tool is int and def.upkeep > 0.9:
			b.tooltip_text += "\nUpkeep: %s/day" % D.money(def.upkeep)
		b.locked = tool is String and tool == "plant" and not game.has_tech("restore")
		if b.locked:
			b.lock_text = "Research"
		if game.unlock_level(tool) > game.level:
			b.locked = true
			b.lock_text = "Level %d" % game.unlock_level(tool)
		b.button_pressed = _same_tool(tool, current_tool)
		b.pressed.connect(func(): select_tool(null if _same_tool(tool, current_tool) else tool))
		b.mouse_entered.connect(func(): _hover_tool = tool)
		b.mouse_exited.connect(func(): if _same_tool(_hover_tool, tool): _hover_tool = null)
		tool_row.add_child(b)


func _same_tool(a, b) -> bool:
	return typeof(a) == typeof(b) and a == b


func select_tool(tool) -> void:
	if tool != null and game.unlock_level(tool) > game.level:
		game.say("That unlocks when the park becomes a %s (level %d). Open the Park panel to see what that takes." % [D.LEVELS[game.unlock_level(tool) - 1].name, game.unlock_level(tool)], "info")
		tool = null
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
	side.offset_top = 54
	side.offset_bottom = -64
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
	side_body.add_child(_label(text, 16, ACCENT))


func _kv(k: String, v: String, col: Color = INK) -> void:
	var h := HBoxContainer.new()
	var a := _label(k, 14, Color("a3afb6"))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(_label(v, 14, col))
	side_body.add_child(h)


func _kbar(k: String, v: float, text: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var a := _label(k, 14, Color("a3afb6"))
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
	_kv("Park level", "%d: %s" % [g.level, D.LEVELS[g.level - 1].name], ACCENT)
	var prog := g.level_progress()
	if prog.is_empty():
		side_body.add_child(_para("The highest level there is."))
	else:
		side_body.add_child(_para("To become a %s:" % D.LEVELS[g.level].name))
		for row in prog:
			var have: float = row[1]
			var need: float = row[2]
			_kbar(row[0], clampf(have / maxf(need, 0.001), 0.0, 1.0), ("%.1f / %.1f" % [have, need]) if need < 10.0 else "%d / %d" % [int(have), int(need)])
	_kv("Status", "Open" if g.open else "Closed", GREEN if g.open else Color("ff6b5e"))
	var share: Array = g.world.access_share()
	if share[1] > 0:
		_kbar("Accessible", float(share[0]) / share[1], "%d / %d" % [share[0], share[1]])
		side_body.add_child(_para("Attractions a wheelchair or stroller can reach from the parking: pavement, docks, and Trail or Built Trail that is not steep. Rough paths and steep climbs shut people out. Each one opened up brings more visitors. See View: Accessibility.", 12))
	_head("Park rules")
	var fh := HBoxContainer.new()
	var fl := _label("Fishing: %s" % ("allowed" if g.fishing else "banned"), 14, GREEN if g.fishing else INK)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(fl)
	var fcb := func():
		g.set_fishing(not g.fishing)
		_fill_panel()
	fh.add_child(_button("Ban" if g.fishing else "Allow", fcb))
	side_body.add_child(fh)
	side_body.add_child(_para("Allowed: anglers buy permits ($9 each a day) and more people come, most of all where there are docks. But every fish they take is one fewer trout for the herons and eagles, and the trout can collapse if too many are taken.", 12))
	_kbar("Visitor rating", g.stars / 5.0, "%.1f" % g.stars)
	if g.eco.understanding() >= 0.08:
		_kbar("Ecosystem (est.)", g.eco.health / 100.0, _eco_text())
	else:
		_kv("Ecosystem", "unknown: no research yet", Color("ff8a70"))
	_kbar("Safety", g.safety / 100.0, "%d%%" % int(g.safety))
	_head("Visitors")
	_kv("In the park now", str(g.visitors.people_count()))
	_kv("Arrived today", str(g.visitors_today))
	_kv("Cars turned away (no parking)", str(g.turned_away_today), Color("ff6b5e") if g.turned_away_today > 0 else INK)
	_kv("Expected cars per day", str(int(g.demand)))
	_kv("Parking spaces", str(g.world.lot_tiles.size() * 2))
	_kv("All-time visitors", str(g.total_visitors))
	_head("Park condition")
	_kv("Littered tiles", str(g.world.litter_tiles.size()), Color("ff6b5e") if g.world.litter_tiles.size() > 10 else INK)
	var inv := g.eco.seen_invasive_count()
	_kv("Known invasive patches", str(inv), Color("ff6b5e") if inv > 0 else INK)
	if not g.world.fire_tiles.is_empty():
		_kv("Tiles on fire", str(g.world.fire_tiles.size()), Color("ff6b5e"))
	_kv("Trail length", "%d tiles" % g.world.trail_tiles.size())
	_kv("Serious incidents", str(g.serious_incidents))
	_kv("Visitor deaths", str(g.deaths), Color("ff6b5e") if g.deaths > 0 else INK)
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
			_kv(s.name + note, "appeal %d%%, %d visits" % [int(float(s.quality) * 100.0), s.visits], Color("ff6b5e") if note != "" else INK)
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
		side_body.add_child(_para("You know almost nothing about this ecosystem yet. Build a Research Station and hire ecologists: everything on this page comes from their field surveys. Without them, species can decline or invasives can spread unnoticed.", 14, Color("ff8a70")))
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
	for z in D.BIOME_NAMES.size():
		var line: String = D.WEATHER[game.zone_weather[z]].name
		if game.zone_dry[z] >= 5 and game.season() != 3:
			line += ", drought"
		if has_station:
			line += "  (tomorrow: %s)" % D.WEATHER[game.zone_next[z]].name.to_lower()
		_kv(D.BIOME_NAMES[z], line)
	if has_station:
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
			var shot := Glyph.new("sp_" + str(sp.id) if lvl > 0 else "unknown_species", 30)
			shot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if lvl == 0:
				shot.modulate = Color(1, 1, 1, 0.0)
			h.add_child(shot)
			var a := _label(sp.name if lvl > 0 else "Unstudied species", 14, INK if lvl > 0 else Color("6f7b82"))
			a.custom_minimum_size.x = 104
			h.add_child(a)
			if lvl == 0:
				h.add_child(_label("no data", 13, Color("6f7b82")))
				side_body.add_child(h)
				continue
			var v := e.ratio(i)
			if lvl == 1:
				v = round(v * 4.0) / 4.0 # rough impressions only
			h.add_child(_bar(minf(v, 1.0), _health_color(v) if v <= 1.25 else Color("f2b84b")))
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
		if Icons.pic.has("face_" + role):
			h.add_child(Glyph.new("face_" + role, 40))
		var a := _label("%s   %d / %d" % [def.name, st.count(role), st.capacity(role)], 16, Color("f2c879"))
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
	_kv("Research points", "%d" % int(game.research), Color("b9a4ff"))
	side_body.add_child(_para("Ecologists produce research every hour and from field surveys. Healthier ecosystems yield more."))
	for t in D.TECHS:
		var done: bool = game.has_tech(t.id)
		var h := HBoxContainer.new()
		var a := _label(t.name, 16, GREEN if done else Color("f2c879"))
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
		var a := _label("%s   %s" % [o.title, D.money(o.reward)], 15, Color("f2c879"))
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
	_kv("Balance", D.money(g.money), GREEN if g.money >= 0 else Color("ff6b5e"))
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
			_kv(k, D.money(led[k]), GREEN if led[k] > 0 else Color("ff8a70"))
		_kv("Net", D.money(total), GREEN if total >= 0 else Color("ff6b5e"))


# ------------------------------------------------- toasts, checklist, inspector

func _build_misc() -> void:
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toasts.offset_left = 8
	toasts.offset_bottom = -64
	toasts.custom_minimum_size.x = 306
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_theme_constant_override("separation", 4)
	root.add_child(toasts)

	objectives = PanelContainer.new()
	objectives.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objectives.offset_left = 62
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
	inspector.position = root.size - inspector.size - Vector2(8, 64)


func _on_toast(text: String, kind: String, tile: Vector2i) -> void:
	# keep the stack short so it never climbs over the side buttons
	while toasts.get_child_count() >= 3:
		var oldest := toasts.get_child(0)
		toasts.remove_child(oldest)
		oldest.queue_free()
	var p := PanelContainer.new()
	var col: Color = KIND_COLORS.get(kind, KIND_COLORS.info)
	var sb := _sb(Color(CREAM, 0.9), 5, col, 0, 7.0)
	sb.border_width_left = 6
	sb.border_color = col
	p.add_theme_stylebox_override("panel", sb)
	var l := _para(text, 13, INK)
	l.custom_minimum_size.x = 280
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
	# title, done, the ranger's advice, toolbar category to point at
	var steps := [
		["Extend the road from the highway", road_n >= 6,
			"Open Roads & Trails in the bar below, pick Road, and drag north from the glowing marker. Roads bring people in, but they also cut habitat in two and put animals under wheels, so keep them short.", 0],
		["Place an Entrance Gate on the road", w.count_kind(D.B.GATE) > 0,
			"Put an Entrance Gate on the road. The gate is where visitors pay the fee that funds every ranger and every survey. You can change the fee in the Park panel.", 0],
		["Build a Parking Lot beside the road", w.lot_tiles.size() >= 4,
			"Drag a Parking Lot next to the road. Each car needs a space, and a full lot turns families away. Pavement sheds oily water though, so keep it back from streams.", 0],
		["Lay a Trail from the parking lot", w.trail_tiles.size() >= 8,
			"Lay a Trail out from the lot. Rough Path is cheapest but dangerous on slopes; Trail is the everyday choice. A good trail gathers footsteps into one line, which spares everything beside it.", 0],
		["Build a Scenic Overlook on the trail", w.count_kind(D.B.OVERLOOK) > 0,
			"Build a Scenic Overlook beside the trail. Watch the scenery score as you move it: high ground and named landmarks score best. This is what people came for.", 2],
		["Add a Restroom and a Trash bin", w.count_kind(D.B.RESTROOM) > 0 and w.count_kind(D.B.BIN) > 0,
			"Add a Restroom and a Trash bin near the lot. Litter is not just ugly: food scraps teach bears to seek out people, and that never ends well for the bear.", 1],
		["Build a Ranger Station and hire a ranger", game.staffing.count("ranger") > 0,
			"Build a Ranger Station from Operations, then hire a ranger in the Staff panel (the person button on the left). Rangers find lost hikers, treat injuries and keep people and wildlife apart.", 3],
		["Build a Research Station and hire an ecologist", game.staffing.count("eco") > 0,
			"Build a Research Station and hire an ecologist. Until they survey the land you are managing blind: every species count, food-web link and invasive weed is hidden until someone goes out and looks.", 3],
		["Accept a grant (Grants menu)", game.grants.active.size() + game.grants.completed > 0,
			"Open Grants (the tick button on the left) and accept one. Grants pay you to hit conservation goals, which is how a careful park can out-earn a crowded one.", -1],
	]
	var all_done := true
	var open_i := -1
	for k in steps.size():
		if not steps[k][1]:
			all_done = false
			if open_i < 0:
				open_i = k
	if _guiding and _pages.is_empty():
		if all_done:
			_guiding = false
			_guide_step = -1
			_show_pages([["The park is open", "That is opening day done, Superintendent. From here the land answers back: seasons turn, droughts and fires come, herds grow or crash, and weeds creep in along your trails. Keep your scientists in the field, read what they find in the Wildlife panel, and build with a light hand. Good luck."]], false)
		elif open_i != _guide_step:
			if _guide_step >= 0:
				game.say("Done: %s." % steps[_guide_step][0], "good")
			_guide_step = open_i
			guide_title.text = "Step %d of %d: %s" % [open_i + 1, steps.size(), steps[open_i][0]]
			guide_text.text = steps[open_i][2]
			guide_next.visible = false
			guide_skip.text = "Hide tips"
			guide.visible = true
			guide.set_meta("cat", steps[open_i][3])
			_fit_guide()
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
		var col := Color("6f7b82") if s[1] else (INK if first_open else Color("8a969d"))
		h.add_child(_label(s[0], 13, col))
		if not s[1]:
			first_open = false
		obj_box.add_child(h)
	objectives.reset_size()


# ------------------------------------------------------------------- issues

func _tile_of(i: int) -> Vector2i:
	return Vector2i(i % World.W, i / World.W)


## Everything currently going wrong, worst first:
## [severity 2 = urgent / 1 = worth fixing, what, why it matters and what to do, where or null]
func _issues() -> Array:
	var g := game
	var w := g.world
	var out: Array = []
	var gates := w.count_kind(D.B.GATE)
	if gates == 0:
		out.append([1, "The park is closed", "Nobody can visit until an Entrance Gate stands on a road. Build one from Roads & Trails.", w.entry])
	elif w.lot_tiles.is_empty():
		out.append([2, "Nowhere to park", "Visitors only come if they can park. Drag a Parking Lot beside the road.", w.entry])
	elif not g._lot_reachable():
		out.append([2, "Cars cannot reach the parking", "The road from the highway does not connect to a lot. Join them up with Road.", w.lot_tiles[0]])
	if not w.fire_tiles.is_empty():
		out.append([2, "Wildfire: %d tiles burning" % w.fire_tiles.size(), "Fire spreads fastest in drought and wind, and visitors nearby are in danger. Rangers fight it; a break in the trees slows it.", _tile_of(w.fire_tiles.keys()[0])])
	if g.money < 0:
		out.append([2, "The park is in debt", "You cannot build while funds are below zero. Raise the entry fee in Finances, accept a grant, or demolish things with high upkeep.", null])
	else:
		var net := 0.0
		for k in g.ledger_prev:
			net += g.ledger_prev[k]
		if net < -1.0 and g.day > 1:
			out.append([1, "Losing %s a day" % D.money(-net), "Yesterday's upkeep and wages were more than the income. Open Finances to see where it goes; more visitors, a fairer fee or a grant will close the gap.", null])
	if g.turned_away_today > 0:
		out.append([1, "%d cars turned away today" % g.turned_away_today, "The parking was full, so those families left without paying. Add parking spaces, but keep them away from streams and wildlife.", w.lot_tiles[0] if not w.lot_tiles.is_empty() else null])
	var orphan = null
	var attractions := 0
	for s in w.structures.values():
		if s.kind in D.ATTRACTIONS:
			attractions += 1
			if s.access.is_empty() and orphan == null:
				orphan = s
	if orphan != null:
		out.append([1, "%s has no path to it" % orphan.name, "Visitors cannot reach it, so it earns nothing. Connect it to a parking lot with a Trail.", orphan.tile])
	if g.open and attractions == 0:
		out.append([1, "Nothing for visitors to do", "People need a reason to come. Build a Scenic Overlook, Picnic Area or Visitor Center on a trail.", null])
	var acc: Array = w.access_share()
	if acc[1] >= 2 and float(acc[0]) / acc[1] < 0.5:
		out.append([1, "Only %d of %d attractions are accessible" % [acc[0], acc[1]], "Wheelchair users and families with strollers cannot reach the rest. Link them to the parking with Trail, Built Trail or Dock on gentle ground; rough paths and steep steps shut people out. View: Accessibility shows where the route breaks.", null])
	if g.fishing and g.eco.understanding() >= 0.08 and g.eco.r("trout") < 0.5:
		out.append([1, "Trout are being fished out", "Anglers are taking more than the streams can replace, and the herons and eagles that eat trout will follow them down. Ban fishing in the Park panel for a season or two.", null])
	if g.safety < 70.0:
		out.append([2 if g.safety < 45.0 else 1, "Safety is at %d%%" % int(g.safety), "Hikers are getting hurt or lost. Hire rangers, put Safety Signage and Trailhead Kiosks on long or steep trails, and avoid steep straight climbs.", null])
	# steep trail nobody has been warned about, and trail a long way from any help
	var steep_t = null
	var steep_n := 0
	var far_t = null
	var far_d := 0.0
	var posts: Array = []
	for s in w.structures.values():
		if s.kind == D.B.RANGER or s.kind == D.B.SAR:
			posts.append(Vector2(s.tile))
	for k in range(0, w.trail_tiles.size(), 3):
		var tt: Vector2i = w.trail_tiles[k]
		var ti := World.ti(tt)
		if w.sign_cover[ti] == 0 and w.trail_grade[ti] in [0, 1, 4] and w.slope_at(tt) > 0.7:
			steep_n += 1
			if steep_t == null:
				steep_t = tt
		var near := 1e9
		for pp: Vector2 in posts:
			near = minf(near, pp.distance_to(Vector2(tt)))
		if near > far_d and near < 1e8:
			far_d = near
			far_t = tt
	if steep_n > 0:
		out.append([1, "Steep trail with no warning signs", "People are climbing ground steep enough to fall on with nothing to warn them. Put Safety Signage there, or rebuild it as a Built Trail or a Switchback.", steep_t])
	if far_d > 45.0 and w.count_kind(D.B.HELIPAD) == 0 and g.open:
		out.append([1, "Trails %d tiles from any help" % int(far_d), "If someone is badly hurt out there, a ranger on foot will not arrive in time. Add call boxes and a hut along the way, and a Rescue Post nearer the far end.", far_t])
	for inc in g.staffing.incidents:
		if inc.severity >= 3:
			out.append([2, "%s: life-threatening" % inc.title, "They can hold on about %d more seconds. %s" % [int(inc.timer), ("Help arrives in about %d seconds." % int(inc.eta)) if inc.eta >= 0.0 else "No rescue team is on the way: only a ranger on foot can reach them."], inc.tile])
			break
	if g.open and g.visitors.people_count() > 0 and g.staffing.count("ranger") == 0:
		out.append([1, "No rangers on duty", "Nobody will find a lost hiker or treat an injury. Build a Ranger Station and hire a ranger in the Staff panel.", null])
	if w.litter_tiles.size() > 10:
		out.append([1, "Litter on %d tiles" % w.litter_tiles.size(), "Litter spoils the scenery and food scraps draw bears toward people. Add Trash bins where people stop and hire maintenance workers.", _tile_of(w.litter_tiles.keys()[0])])
	var know := g.eco.understanding()
	if know < 0.08:
		if g.day > 2:
			out.append([1, "You are managing blind", "With no research, wildlife numbers, invasive plants and the park's health are all unknown. Build a Research Station and hire an ecologist.", null])
	else:
		var seen := -1
		for i: int in w.invasive_tiles.keys():
			if w.inv_seen[i] == 1:
				seen = i
				break
		if seen >= 0:
			out.append([1, "Invasive plants: %d known patch%s" % [g.eco.seen_invasive_count(), "" if g.eco.seen_invasive_count() == 1 else "es"], "They crowd out native plants and spread along trails and roads on boots and tyres. Use Remove Invasives (Land) or let ecologists clear them.", _tile_of(seen)])
		if g.eco.health < 60.0:
			out.append([2 if g.eco.health < 40.0 else 1, "Ecosystem under stress (%s)" % _eco_text(), "Too much disturbance, too little habitat or a broken food web. Check the Wildlife panel and the Disturbance view; fewer roads and more quiet land help it recover.", null])
	if g.stars < 2.5 and g.total_visitors > 20:
		var why := "Read what visitors say in the Park panel."
		var keys := g.comments.keys()
		if not keys.is_empty():
			keys.sort_custom(func(a, b): return g.comments[a] > g.comments[b])
			why = "The most common comment: \"%s\"." % keys[0]
		out.append([1, "Visitors are unhappy (%.1f stars)" % g.stars, why + " Low ratings mean fewer people come.", null])
	out.sort_custom(func(a, b): return a[0] > b[0])
	return out


func _on_level(lv: int) -> void:
	_show_category(cat_index)
	var names: Array = []
	for kind: int in D.BUILD:
		if D.BUILD[kind].get("level", 1) == lv:
			names.append(D.BUILD[kind].name)
	for id: String in D.TOOLS:
		if D.TOOLS[id].get("level", 1) == lv:
			names.append(D.TOOLS[id].name)
	var info: Dictionary = D.LEVELS[lv - 1]
	_show_pages([["Level %d: %s" % [lv, info.name], "%s\n\nNow unlocked: %s." % [info.story, ", ".join(names)]]], false)


func _build_issues() -> void:
	issues_box = PanelContainer.new()
	issues_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	issues_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	issues_box.offset_top = 52
	issues_box.offset_right = -8
	issues_box.custom_minimum_size.x = 300
	issues_box.add_theme_stylebox_override("panel", _sb(Color(PANEL, 0.94), 10, Color("ffb454", 0.6), 1, 8.0))
	issues_box.visible = false
	root.add_child(issues_box)
	issues_list = VBoxContainer.new()
	issues_list.add_theme_constant_override("separation", 4)
	issues_box.add_child(issues_list)


func _update_issues() -> void:
	var list := _issues()
	# while the first-day guide is running, its own steps cover the basics
	if guide.visible and dim.visible:
		list = []
	issues_box.visible = not list.is_empty() and not side.visible
	for c in issues_list.get_children():
		issues_list.remove_child(c)
		c.queue_free()
	if list.is_empty():
		return
	issues_list.add_child(_label("Needs attention (%d)" % list.size(), 13, Color("ffb454")))
	for k in mini(4, list.size()):
		var it: Array = list[k]
		var col := Color("ff6b5e") if it[0] >= 2 else Color("ffb454")
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = ("!! " if it[0] >= 2 else "!  ") + str(it[1]) + ("   (go)" if it[3] != null else "")
		b.add_theme_color_override("font_color", col)
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = str(it[2]) + ("\nClick to go there." if it[3] != null else "")
		b.add_theme_stylebox_override("normal", _sb(Color(col, 0.1), 6, Color(col, 0.35), 1, 5.0))
		b.add_theme_stylebox_override("hover", _sb(Color(col, 0.22), 6, col, 1, 5.0))
		var where = it[3]
		var what: String = it[1]
		var advice: String = it[2]
		b.pressed.connect(func():
			if where != null:
				jump_to.emit(where)
			game.say("%s. %s" % [what, advice], "warn"))
		issues_list.add_child(b)
	if list.size() > 4:
		issues_list.add_child(_label("+ %d more" % (list.size() - 4), 12, Color("a3afb6")))
	issues_box.size = Vector2(300, 0)


# ------------------------------------------------------------ story and guide

func _build_guide() -> void:
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	root.add_child(dim)
	guide = PanelContainer.new()
	guide.add_theme_stylebox_override("panel", _sb(Color(PANEL, 0.97), 12, Color(ACCENT, 0.7), 2, 14.0))
	guide.set_anchors_preset(Control.PRESET_CENTER_TOP)
	guide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	guide.offset_top = 58
	guide.custom_minimum_size.x = 560
	guide.visible = false
	root.add_child(guide)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	guide.add_child(row)
	var face := Glyph.new("ranger", 64)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	col.add_child(_label("Juniper Hale, Chief Ranger", 12, ACCENT))
	guide_title = _label("", 18, Color.WHITE)
	guide_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_title.custom_minimum_size.x = 440
	col.add_child(guide_title)
	guide_text = _para("", 14, Color("d5dde2"))
	guide_text.custom_minimum_size.x = 440
	col.add_child(guide_text)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 8)
	col.add_child(btns)
	guide_skip = _button("Skip tutorial", _guide_skip)
	btns.add_child(guide_skip)
	guide_next = _button("Next", _guide_next)
	btns.add_child(guide_next)


## Opens a new park with its story, then walks through the first day.
func start_story(summit: String, others: String) -> void:
	_guiding = true
	_guide_step = -1
	_show_pages([
		["A new park", "After years of petitions and hearings, the country below %s has been set aside for good. There are no roads here yet, no trails and no rangers: only forest, river and rock%s. And you, its first Superintendent." % [summit, others]],
		["Protect it and share it", "The job has two halves that pull against each other. People have to see this place before they will fight for it. But every road, car and bootprint changes what they came to see. Every choice you make here trades a little of one for the other."],
		["What nobody knows yet", "Right now this land is a blank on the map. How many elk? Do wolves still hunt here? What is creeping in along the creek? You will not know until you build a Research Station and send ecologists out to look. The question mark by the leaf at the top left means just that: unknown."],
		["Opening day", "I'm Juniper Hale. I have walked this ground for twenty years and I'll walk you through the first day. The highway runs along the southern boundary, where the marker is glowing. Let's bring a road in."],
	], true)


func _show_pages(pages: Array, pause: bool) -> void:
	_pages = pages
	_page = 0
	if pause:
		set_speed(0)
	dim.visible = true
	guide.offset_top = 150
	_show_page()


## Wrapped text only knows its height once it has its width, so shrink the
## card to fit a moment later.
func _fit_guide() -> void:
	guide.size = Vector2(560, 0)
	await get_tree().process_frame
	guide.size = Vector2(560, 0)


func _show_page() -> void:
	guide_title.text = _pages[_page][0]
	guide_text.text = _pages[_page][1]
	guide_next.visible = true
	guide_next.text = "Next" if _page < _pages.size() - 1 else ("Begin" if _guiding else "Close")
	guide_skip.text = "Skip tutorial"
	guide_skip.visible = _guiding
	guide.visible = true
	guide.set_meta("cat", -1)
	_fit_guide()


func _guide_next() -> void:
	_page += 1
	if _page < _pages.size():
		_show_page()
		return
	_pages = []
	dim.visible = false
	guide.visible = false
	guide.offset_top = 58
	guide_skip.visible = true
	if game.speed == 0:
		set_speed(1)
	_update_objectives()


func _guide_skip() -> void:
	var was_story := not _pages.is_empty()
	_guiding = false
	_guide_step = -1
	_pages = []
	dim.visible = false
	guide.visible = false
	guide.offset_top = 58
	if was_story and game.speed == 0:
		set_speed(1)


func _update_stats() -> void:
	var g := game
	stat.money.text = D.money(g.money)
	stat.money.add_theme_color_override("font_color", MONEY if g.money >= 0 else Color("ff6b5e"))
	var net := 0.0
	for k in g.ledger:
		net += g.ledger[k]
	stat.net.text = ("+" if net >= 0 else "-") + D.money(absf(net)) + " today"
	stat.net.add_theme_color_override("font_color", Color("a3afb6") if net >= 0 else Color("ff8a70"))
	stat.date.text = g.date_text()
	stat.visitors.text = str(g.visitors.people_count())
	stat.stars.text = "%.1f" % g.stars
	stat.eco.text = _eco_text()
	stat.eco.add_theme_color_override("font_color", _health_color(g.eco.health / 100.0) if g.eco.health < 70.0 and g.eco.understanding() >= 0.08 else INK)
	var here: String = g.weather_at(view_tile)
	stat.weather.text = "%s, %s" % [D.WEATHER[here].name, ["forest", "valley", "wetland", "desert", "alpine"][g.world.biome[World.ti(view_tile)]]]
	stat.safety.text = "%d%%" % int(g.safety)
	stat.research.text = str(int(g.research))
	for b in speed_buttons:
		b.set_pressed_no_signal(b.get_meta("speed") == g.speed)


func _process(delta: float) -> void:
	# the toolbar button the current tip is about glows
	_pulse += delta
	var want: int = guide.get_meta("cat", -1) if guide.visible else -1
	for k in cat_buttons.size():
		cat_buttons[k].modulate = Color.WHITE.lerp(Color(1.5, 1.4, 0.8), 0.5 + 0.5 * sin(_pulse * 5.0)) if k == want and k != cat_index else Color.WHITE
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_update_stats()
		_update_card()
		if _last_money >= 0.0 and absf(game.money - _last_money) >= 10.0:
			_money_pop(game.money - _last_money)
		_last_money = game.money
		# messages sit beside the build tray when there is room, above it when not
		var crowded: bool = tray.global_position.x < toasts.global_position.x + toasts.size.x + 8.0 \
			or (card.visible and card.global_position.x < toasts.global_position.x + toasts.size.x + 8.0)
		var lift := -64.0 if not crowded else -(root.size.y - tool_wrap.global_position.y) - 8.0
		if absf(lift - _toast_side) > 1.0:
			_toast_side = lift
			toasts.offset_bottom = lift
	_panel_refresh -= delta
	if _panel_refresh <= 0.0 and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_panel_refresh = 1.0
		_update_objectives()
		_update_issues()
		if side.visible:
			_fill_panel()
