extends Node3D
## Scene root: wires the simulation to the 3D views and handles the orbit
## camera, building tools and inspection.

const LINEAR := [D.B.ROAD, D.B.TRAIL]
const TERRA := ["raise", "lower", "level", "smooth"]

var game: Game
var world: World
var land: Terrain3D
var agents: Agents3D
var hud: HUD
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var rain: GPUParticles3D
var snow: GPUParticles3D
var _overcast := 0.0
var zoom_goal := 26.0
var quality := 1
var _lod_timer := 0.0
var _last_mouse := Vector2(-1, -1)
var _last_cam := Transform3D()
var _args := {}
var menu: CanvasLayer
var menu_status: Label
var font: Font

# orbit camera
var target := Vector3.ZERO
var yaw := 0.0
var pitch := 0.5
var dist := 30.0

# overlays drawn on the terrain
var cursor_mesh: MeshInstance3D
var overlay_mesh: MeshInstance3D
var ghost: MeshInstance3D
var ghost_mat: StandardMaterial3D
var overlay_mode := ""
var _overlay_timer := 0.0

var tool = null
var hover := Vector2i()
var drag_start := Vector2i(-1, -1)
var dragging := false
var orbiting := false
var mid_pan := false
var sculpting := false
var brush := 2.5
var _level_h := 0.0
var _sculpt_timer := 0.0
var _sculpted := false
var _route_key := []
var _route: Array[Vector2i] = []
# the camera eases toward where the controls point it
var _s_target := Vector3.ZERO
var _s_yaw := 0.0
var _s_pitch := 0.5
var _s_ready := false
var left_pan := false
var pan_moved := 0.0
var sel_tile := Vector2i(-1, -1)
var _inspect_timer := 0.0
var _shot := ""
var _shot_frames := 0


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var base = load("res://fonts/Inter-Medium.otf")
	font = base if base != null else ThemeDB.fallback_font
	_args = args
	if args.has("load") and Game.has_save():
		start_game(0, Game.read_save())
	elif args.is_empty() or args.has("menu"):
		_show_menu()
	else:
		start_game(int(args.get("seed", "0")), {})


# ----------------------------------------------------------------- main menu

func _menu_button(text: String, cb: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 54)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.09, 0.11, 0.78)
	normal.set_corner_radius_all(6)
	normal.border_color = Color(1, 1, 1, 0.25)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(10)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.16, 0.2, 0.22, 0.9)
	var off: StyleBoxFlat = normal.duplicate()
	off.bg_color = Color(0.07, 0.09, 0.11, 0.4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color("f2f5f6"))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.pressed.connect(cb)
	return b


func _show_menu() -> void:
	menu = CanvasLayer.new()
	menu.layer = 20
	add_child(menu)
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 0.75, 1.0])
	grad.colors = PackedColorArray([Color("16263d"), Color("3f6f8c"), Color("e6a36a"), Color("27402c")])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	menu.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	menu.add_child(box)
	var title := Label.new()
	title.text = "WILDLANDS"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color("fff8e6"))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.12, 0.6))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Build and care for a national park"
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color("f3e9cf"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	box.add_child(gap)
	var saved := Game.read_save()
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_theme_constant_override("separation", 12)
	box.add_child(holder)
	holder.add_child(_menu_button("New Park", func(): _menu_start(0, {})))
	var load_text := "Load Game"
	if not saved.is_empty():
		load_text = "Load Game  (day %d, %s)" % [saved.day, D.money(saved.money)]
	holder.add_child(_menu_button(load_text, func(): _menu_start(0, saved), not saved.is_empty()))
	holder.add_child(_menu_button("Quit", func(): get_tree().quit()))
	menu_status = Label.new()
	menu_status.text = "Every new park is a different randomly generated landscape."
	menu_status.add_theme_font_override("font", font)
	menu_status.add_theme_font_size_override("font_size", 16)
	menu_status.add_theme_color_override("font_color", Color("f3e9cf"))
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(menu_status)


func _menu_start(seed_val: int, save: Dictionary) -> void:
	if game != null:
		return
	menu_status.text = "Surveying the land..." if save.is_empty() else "Loading your park..."
	await get_tree().process_frame
	await get_tree().process_frame
	start_game(seed_val, save)
	menu.queue_free()
	menu = null


func start_game(seed_val: int, save: Dictionary) -> void:
	var args := _args
	if not save.is_empty():
		seed_val = save.seed
	if seed_val == 0:
		seed_val = int(Time.get_unix_time_from_system()) % 1000000 + 1

	game = Game.new()
	add_child(game)
	game.setup(seed_val)
	if not save.is_empty():
		game.load_game(save)
	world = game.world

	var we := WorldEnvironment.new()
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 12.0
	var sky_res := Sky.new()
	sky_res.sky_material = sky_mat
	sky_res.process_mode = Sky.PROCESS_MODE_REALTIME
	sky_res.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# haze you can see the light fall through
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.9, 0.93, 1.0)
	env.volumetric_fog_anisotropy = 0.65
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 2.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.92
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_density = 0.0006
	env.fog_aerial_perspective = 0.7
	# mist pools in the valleys, so ridges rise out of it one behind another
	env.fog_height = 3.0
	env.fog_height_density = 0.012
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 240.0
	sun.light_angular_distance = 0.6
	add_child(sun)

	rain = _make_precip(2600, Vector2(0.025, 0.55), Color(0.75, 0.85, 1.0, 0.45), 26.0)
	snow = _make_precip(1800, Vector2(0.04, 0.04), Color(1, 1, 1, 0.85), 3.5)

	land = Terrain3D.new()
	add_child(land)
	land.setup(world, font)
	agents = Agents3D.new()
	add_child(agents)
	agents.setup(game, land)

	overlay_mesh = _flat_mesh_instance()
	cursor_mesh = _flat_mesh_instance()
	ghost = MeshInstance3D.new()
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.vertex_color_use_as_albedo = true
	ghost_mat.vertex_color_is_srgb = true
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost.material_override = ghost_mat
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.visible = false
	add_child(ghost)

	cam = Camera3D.new()
	cam.fov = 48.0
	cam.near = 0.3
	cam.far = 3000.0
	add_child(cam)
	cam.make_current()
	# start at the park entrance, looking north into the park
	target = Vector3(world.entry.x + 0.5, 0.0, world.entry.y - 5.0)
	dist = 26.0
	pitch = 0.62
	_update_camera()

	hud = HUD.new()
	add_child(hud)
	hud.setup(game, font)
	hud.set_speed(1)
	hud.tool_selected.connect(func(t): tool = t; dragging = false)
	hud.overlay_selected.connect(_set_overlay)
	hud.jump_to.connect(func(t): target = Vector3(t.x + 0.5, 0, t.y + 0.5))
	hud.menu_action.connect(_on_menu_action)
	zoom_goal = dist
	_apply_quality(_load_quality())
	hud.set_quality(quality)
	if save.is_empty():
		game.say("Welcome, Superintendent! This wild land is yours to protect and share. The highway passes the south edge: build your park road north from the glowing marker.", "good")
	else:
		game.say("Welcome back. The park reopens this morning.", "good")
	game.say("Camera: drag to move, right-drag (or Alt-drag) to orbit, scroll or pinch to zoom. Keys: WASD move, Q/E turn, R/F tilt, +/- zoom. Trees turn see-through while you build; hold T to see through them any time.", "info")

	_dev_hooks(args)


## Graphics presets: 0 = performance, 1 = balanced, 2 = quality.
func _apply_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	var vp := get_viewport()
	vp.scaling_3d_scale = [0.6, 0.8, 1.0][quality]
	vp.msaa_3d = Viewport.MSAA_2X if quality == 2 else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if quality == 2 else Viewport.SCREEN_SPACE_AA_FXAA
	env.ssao_enabled = quality >= 1
	env.volumetric_fog_enabled = quality >= 1
	land.set_tree_detail([0.0, 24.0, 40.0][quality])
	env.glow_enabled = quality >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 8192][quality], true)
	agents.detail = [0.35, 0.7, 1.0][quality]
	land.set_grass_enabled(quality >= 1)
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.save("user://wildlands_settings.cfg")


func _load_quality() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("user://wildlands_settings.cfg") == OK:
		return int(cfg.get_value("graphics", "quality", 1))
	return 1


func _on_menu_action(what: String) -> void:
	if what == "north":
		yaw = 0.0
		return
	if what == "help":
		game.say("Move: drag, WASD or middle-drag.  Orbit: right-drag, Alt-drag or Shift-drag, Q/E to turn, R/F to tilt, Home faces north.  Zoom: scroll, pinch, +/-.  Build: pick a tool, click or drag; right-click or Esc cancels.  Terrain tools: hold the mouse, [ ] changes brush size.  T sees through trees.  Space pauses, 1-3 set speed.", "info")
		return
	match what:
		"zoom_in": zoom_goal /= 1.35
		"zoom_out": zoom_goal *= 1.35
		"quality0": _apply_quality(0)
		"quality1": _apply_quality(1)
		"quality2": _apply_quality(2)
		"save":
			game.say("Game saved." if game.save_game() else "Could not write the save file.", "good")
		"menu":
			game.save_game()
			get_tree().reload_current_scene()


func _set_overlay(m: String) -> void:
	if (m == "habitat" or m == "disturb") and world.count_kind(D.B.RESEARCH) == 0:
		game.say("Habitat and disturbance maps come from field research. Build a Research Station first.", "info")
		m = ""
	overlay_mode = m
	_overlay_timer = 0.0


func _flat_mesh_instance() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# -------------------------------------------------------------------- camera

func _update_camera() -> void:
	target.x = clampf(target.x, 0.0, World.W)
	target.z = clampf(target.z, 0.0, World.H)
	var ground_y := land.top_at(target.x, target.z)
	# follow the terrain smoothly, but never let the view sink into a hillside
	target.y = ground_y if absf(ground_y - target.y) > 2.0 else lerpf(target.y, ground_y, 0.12)
	pitch = clampf(pitch, 0.1, 1.5)
	dist = clampf(dist, 2.5, 320.0)
	var k := clampf(get_process_delta_time() * 14.0, 0.0, 1.0)
	if not _s_ready or _shot != "" or _s_target.distance_to(target) > 70.0:
		_s_ready = true
		k = 1.0
	_s_target = _s_target.lerp(target, k)
	_s_yaw = lerpf(_s_yaw, yaw, k)
	_s_pitch = lerpf(_s_pitch, pitch, k)
	var offset := Vector3(sin(_s_yaw) * cos(_s_pitch), sin(_s_pitch), cos(_s_yaw) * cos(_s_pitch)) * dist
	cam.position = _s_target + offset
	# keep the lens out of the hillside when orbiting low
	var floor_y := land.top_at(clampf(cam.position.x, 0.0, World.W), clampf(cam.position.z, 0.0, World.H)) + 0.6
	if cam.position.x >= 0.0 and cam.position.z >= 0.0 and cam.position.x <= World.W and cam.position.z <= World.H and cam.position.y < floor_y:
		cam.position.y = floor_y
	cam.look_at(_s_target, Vector3.UP)


func _make_precip(amount: int, size: Vector2, col: Color, speed: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 22.0 / speed if speed > 10.0 else 5.5
	p.preprocess = p.lifetime
	p.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 0.5, 34)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0 if speed > 10.0 else 12.0
	pm.initial_velocity_min = speed * 0.85
	pm.initial_velocity_max = speed
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = size
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = col
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if speed > 10.0 else BaseMaterial3D.BILLBOARD_ENABLED
	qm.billboard_keep_scale = true
	quad.material = qm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	add_child(p)
	return p


func _mix(a: Color, b: Color, c: Color, day: float, glow: float) -> Color:
	# a = night, b = golden hour, c = midday
	return a.lerp(c, day).lerp(b, glow)


## Moves the sun across the sky and sets the mood for the time of day.
func _update_sky() -> void:
	var hour := game.minutes / 60.0
	var p := clampf((hour - 5.5) / 15.0, 0.0, 1.0) # 5:30 sunrise .. 20:30 sunset
	var up := sin(p * PI) # sun height, 0 at the horizon
	var day := smoothstep(0.0, 0.1, up)
	var glow := (1.0 - smoothstep(0.1, 0.45, up)) * smoothstep(0.0, 0.08, up)
	var night := 1.0 - day
	if day > 0.02:
		sun.rotation = Vector3(deg_to_rad(-(13.0 + 40.0 * up)), deg_to_rad(lerpf(105.0, -105.0, p)), 0.0)
		sun.light_color = Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.74, 0.5), glow)
		sun.light_energy = (1.25 + 0.45 * glow) * day * (1.0 - 0.62 * _overcast)
	else:
		sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(40.0), 0.0)
		sun.light_color = Color(0.55, 0.66, 1.0)
		sun.light_energy = 0.32 * smoothstep(0.98, 1.0, night) + 0.0001
	# sky light, with a floor of plain fill so dawn, dusk and night stay readable
	env.ambient_light_sky_contribution = 0.35 + 0.4 * day * (1.0 - glow)
	env.ambient_light_color = _mix(Color(0.2, 0.26, 0.42), Color(0.72, 0.6, 0.6), Color(0.62, 0.7, 0.82), day, glow)
	env.ambient_light_energy = lerpf(0.6, 1.0, day) + 0.35 * glow
	var sky_top := _mix(Color(0.02, 0.03, 0.09), Color(0.22, 0.3, 0.55), Color(0.2, 0.42, 0.78), day, glow)
	var sky_hor := _mix(Color(0.08, 0.11, 0.22), Color(0.98, 0.62, 0.42), Color(0.68, 0.8, 0.92), day, glow)
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_hor
	sky_mat.ground_horizon_color = sky_hor
	sky_mat.ground_bottom_color = sky_hor.darkened(0.5)
	land.water_mat.set_shader_parameter("sky_col", sky_hor.lerp(sky_top, 0.45))
	env.fog_light_color = sky_hor.lerp(Color(0.6, 0.68, 0.78), 0.4 * day)
	land.set_night(smoothstep(0.35, 0.9, night + glow * 0.5 + _overcast * 0.25))
	# weather: clouds, rain and snow
	# weather is regional: show whatever is happening where the camera is looking
	var view_tile := Vector2i(clampi(int(target.x), 0, World.W - 1), clampi(int(target.z), 0, World.H - 1))
	var wx: String = game.weather_at(view_tile)
	hud.view_tile = view_tile
	var wet: bool = wx == "rain" or wx == "storm" or wx == "snow"
	_overcast = move_toward(_overcast, 1.0 if wet else 0.0, 0.01)
	var grey := Color(0.5, 0.54, 0.6) * (0.35 + 0.65 * day)
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(grey, _overcast)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(grey * 1.15, _overcast)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	env.fog_light_color = env.fog_light_color.lerp(grey, _overcast)
	# haze thins as the camera pulls back, so the whole park stays clear from above
	var clear := clampf(45.0 / dist, 0.1, 1.0)
	# distance haze stays even from high up: far ranges fade to blue, which is what reads as scale
	env.fog_density = lerpf(0.0032, 0.006 if wx != "snow" else 0.01, _overcast) * maxf(clear, 0.45)
	env.fog_height_density = lerpf(0.012 + 0.02 * glow, 0.03, _overcast) * maxf(clear, 0.3)
	env.volumetric_fog_density = lerpf(0.0035 + 0.006 * glow, 0.02, _overcast) * clear
	env.volumetric_fog_albedo = Color(0.9, 0.93, 1.0).lerp(Color(1.0, 0.8, 0.62), glow)
	if wx == "heat":
		env.fog_light_color = env.fog_light_color.lerp(Color(0.9, 0.8, 0.6), 0.4)
	rain.emitting = wx == "rain" or wx == "storm"
	snow.emitting = wx == "snow"
	var above := target + Vector3(0, 13.0 + dist * 0.15, 0)
	rain.position = above
	snow.position = above
	land.climate = game.climate


func _pan(screen_delta: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var k := dist * 0.00135
	target += (-right * screen_delta.x + fwd * screen_delta.y) * k


## Where the mouse ray meets the terrain (or water surface), in tile space.
func _ray_ground(screen: Vector2):
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if dir.y >= -0.01:
		return null
	var step := maxf(0.3, dist * 0.006)
	var prev := from
	var p := from
	for k in 1500:
		p += dir * step
		var inside := p.x >= 0.0 and p.z >= 0.0 and p.x < World.W and p.z < World.H
		var ground := land.top_at(p.x, p.z) if inside else -1.6
		if p.y <= ground:
			if not inside:
				return null
			for b in 8:
				var mid := (prev + p) * 0.5
				if mid.y <= land.top_at(mid.x, mid.z):
					p = mid
				else:
					prev = mid
			return p
		prev = p
	return null


func _update_hover() -> void:
	var hit = _ray_ground(get_viewport().get_mouse_position())
	if hit != null:
		hover = Vector2i(clampi(int(hit.x), 0, World.W - 1), clampi(int(hit.z), 0, World.H - 1))


# --------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if game == null:
		return
	# trackpads: pinch to zoom, two-finger scroll to zoom as well
	if event is InputEventMagnifyGesture:
		zoom_goal /= event.factor
		return
	if event is InputEventPanGesture:
		# two fingers: zoom; with Shift or Alt held: orbit
		if event.shift_pressed or event.alt_pressed:
			yaw -= event.delta.x * 0.04
			pitch += event.delta.y * 0.03
		else:
			zoom_goal *= 1.0 + event.delta.y * 0.03
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_goal /= 1.12
					# zoom toward what the pointer is on
					var hit = _ray_ground(event.position)
					if hit != null and zoom_goal > 2.6:
						target = target.lerp(Vector3(hit.x, target.y, hit.z), 0.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: zoom_goal *= 1.12
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					orbiting = true
					pan_moved = 0.0
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					mid_pan = true
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_update_hover()
					if event.alt_pressed or event.shift_pressed:
						# Alt or Shift + drag orbits, for trackpads and one-button mice
						orbiting = true
						pan_moved = 99.0
					elif tool == null:
						left_pan = true
						pan_moved = 0.0
					elif tool is String and tool in TERRA:
						sculpting = true
						_sculpt_timer = 0.0
						_level_h = world.height[World.ti(hover)]
					elif _is_single():
						_place_single()
					else:
						dragging = true
						drag_start = hover
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: hud.set_speed(0 if game.speed > 0 else 1)
			KEY_1: hud.set_speed(1)
			KEY_2: hud.set_speed(2)
			KEY_3: hud.set_speed(4)
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: zoom_goal /= 1.3
			KEY_MINUS, KEY_KP_SUBTRACT: zoom_goal *= 1.3
			KEY_BRACKETLEFT: brush = maxf(1.0, brush - 0.5)
			KEY_BRACKETRIGHT: brush = minf(6.0, brush + 0.5)
			KEY_HOME, KEY_N: yaw = 0.0
			KEY_ESCAPE:
				dragging = false
				hud.select_tool(null)
				sel_tile = Vector2i(-1, -1)
				agents.selected = null


## Releases and drags are handled here so they still arrive when the mouse
## ends up over the UI.
func _input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventMouseMotion:
		if orbiting:
			yaw -= event.relative.x * 0.007
			pitch += event.relative.y * 0.006
			pan_moved += event.relative.length()
		elif left_pan or mid_pan:
			_pan(event.relative)
			pan_moved += event.relative.length()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			mid_pan = false
		if event.button_index == MOUSE_BUTTON_LEFT:
			if sculpting:
				sculpting = false
				if _sculpted:
					_sculpted = false
					world.rebuild_nav()
					world.recompute_fields()
					game.update_appeal()
			elif orbiting and pan_moved >= 99.0:
				orbiting = false
			elif left_pan:
				left_pan = false
				if pan_moved < 6.0:
					_inspect_click(event.position)
			elif dragging:
				_update_hover()
				_apply_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if orbiting:
				orbiting = false
				if pan_moved < 6.0:
					if dragging:
						dragging = false
					else:
						hud.select_tool(null)


func _process(delta: float) -> void:
	if game == null:
		return
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x += 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x -= 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y -= 1
	if mv != Vector2.ZERO:
		_pan(mv * delta * 520.0)
	var orbit: Vector2 = hud.cam_orbit
	if Input.is_key_pressed(KEY_Q): orbit.x -= 1.0
	if Input.is_key_pressed(KEY_E): orbit.x += 1.0
	if Input.is_key_pressed(KEY_R): orbit.y += 1.0
	if Input.is_key_pressed(KEY_F): orbit.y -= 1.0
	yaw += orbit.x * delta * 1.5
	pitch += orbit.y * delta * 0.9
	if sculpting:
		_sculpt_timer -= delta
		if _sculpt_timer <= 0.0:
			_sculpt_timer = 0.07
			var moved := game.terraform(hover, tool, brush, _level_h)
			if moved > 0:
				_sculpted = true
			elif moved < 0:
				sculpting = false
				game.say("Not enough money for earthworks.", "warn")
	zoom_goal = clampf(zoom_goal, 2.5, 320.0)
	dist = lerpf(dist, zoom_goal, clampf(delta * 10.0, 0.0, 1.0))
	_update_camera()
	# only re-pick the ground when the view or the mouse has actually moved
	var mouse := get_viewport().get_mouse_position()
	if mouse != _last_mouse or cam.global_transform != _last_cam:
		_last_mouse = mouse
		_last_cam = cam.global_transform
		_update_hover()
	# level of detail: shadows only reach as far as is useful at this zoom
	var reach: float = clampf(dist * 2.2 + 30.0, 50.0, [110.0, 180.0, 260.0][quality])
	sun.directional_shadow_max_distance = reach
	agents.cam_pos = cam.global_position
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.4
		land.update_lod(target, reach)
	land.set_trees_ghosted(tool != null or Input.is_key_pressed(KEY_T))

	_update_sky()

	land.set_season(game.season())
	_update_cursor()
	_overlay_timer -= delta
	if _overlay_timer <= 0.0:
		_overlay_timer = 3.0
		_rebuild_overlay()
	_inspect_timer -= delta
	if _inspect_timer <= 0.0:
		_inspect_timer = 0.25
		_update_inspector()

	if _shot != "":
		_shot_frames -= 1
		if _shot_frames <= 0:
			get_viewport().get_texture().get_image().save_png(_shot)
			print("saved ", _shot)
			get_tree().quit()


# ------------------------------------------------------------------ building

func _is_single() -> bool:
	return tool is int and not (tool in LINEAR) and tool != D.B.PARKING


func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cur := a
	out.append(cur)
	var x_first: bool = abs(b.x - a.x) >= abs(b.y - a.y)
	for pass_i in 2:
		var horizontal := x_first if pass_i == 0 else not x_first
		if horizontal:
			while cur.x != b.x:
				cur.x += signi(b.x - cur.x)
				out.append(cur)
		else:
			while cur.y != b.y:
				cur.y += signi(b.y - cur.y)
				out.append(cur)
	return out


func _rect(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			out.append(Vector2i(x, y))
	return out


## A walking route from a to b that climbs gently: on a steep hillside it
## zigzags instead of going straight up. Dijkstra over the tiles around the
## two ends, where every step costs more the steeper it is.
func _switchback(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if _route_key == [a, b]:
		return _route
	_route_key = [a, b]
	_route = [] as Array[Vector2i]
	var pad := 10
	var x0 := maxi(0, mini(a.x, b.x) - pad)
	var y0 := maxi(0, mini(a.y, b.y) - pad)
	var bw := mini(World.W - 1, maxi(a.x, b.x) + pad) - x0 + 1
	var bh := mini(World.H - 1, maxi(a.y, b.y) + pad) - y0 + 1
	if bw * bh > 6000 or not World.inb(a.x, a.y) or not World.inb(b.x, b.y):
		_route = _line(a, b)
		return _route
	var cost := PackedFloat32Array()
	cost.resize(bw * bh)
	cost.fill(1e9)
	var from := PackedInt32Array()
	from.resize(bw * bh)
	from.fill(-1)
	var open := {} # node -> true, a small frontier scanned for its minimum
	var s := (a.y - y0) * bw + (a.x - x0)
	var goal := (b.y - y0) * bw + (b.x - x0)
	cost[s] = 0.0
	open[s] = true
	var steps := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not open.is_empty():
		var cur := -1
		var best := 1e9
		for k: int in open:
			if cost[k] < best:
				best = cost[k]
				cur = k
		open.erase(cur)
		if cur == goal:
			break
		var cx := cur % bw + x0
		var cy := cur / bw + y0
		var ch: float = world.height[World.idx(cx, cy)]
		for d: Vector2i in steps:
			var nx := cx + d.x
			var ny := cy + d.y
			if nx < x0 or ny < y0 or nx >= x0 + bw or ny >= y0 + bh:
				continue
			var t := Vector2i(nx, ny)
			var kind := world.build[World.idx(nx, ny)]
			var walkable: bool = kind == D.B.TRAIL or kind == D.B.ROAD or kind == D.B.PARKING
			if not walkable and world.can_build(D.B.TRAIL, t) != "":
				continue
			var grade := absf(world.height[World.idx(nx, ny)] - ch)
			var over := maxf(0.0, grade - 0.3)
			var c := best + (0.6 if walkable else 1.0) + over * over * 26.0 + over * 3.0
			var ni := (ny - y0) * bw + (nx - x0)
			if c < cost[ni]:
				cost[ni] = c
				from[ni] = cur
				open[ni] = true
	if from[goal] < 0 and goal != s:
		return _route
	var cur2 := goal
	while cur2 >= 0:
		_route.append(Vector2i(cur2 % bw + x0, cur2 / bw + y0))
		cur2 = from[cur2]
	_route.reverse()
	return _route


func _brush_tiles(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := int(ceil(brush))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dy).length() <= brush:
				out.append(c + Vector2i(dx, dy))
	return out


func _drag_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if tool is String and tool == "switchback":
		return _switchback(a, b)
	if tool is int and tool in LINEAR:
		return _line(a, b)
	return _rect(a, b)


func _tile_ok(t: Vector2i) -> bool:
	if not World.inb(t.x, t.y):
		return false
	var i := World.ti(t)
	if tool is int:
		return world.can_build(tool, t) == ""
	if tool in TERRA:
		return world.can_terraform(t)
	match tool:
		"switchback": return world.can_build(D.B.TRAIL, t) == ""
		"bulldoze": return world.build[i] != D.B.NONE and t != world.entry
		"weed": return world.invasive[i] > 0.0 and world.inv_seen[i] == 1
		"plant":
			var ter := world.terrain[i]
			return world.build[i] == D.B.NONE and world.trees[i] == 0 and (ter == D.T.GRASS or ter == D.T.FOREST or ter == D.T.MEADOW) \
				and not world.landmark_at.has(i) and world.rare[i] <= 0.0
	return false


func _tile_quad(m: MeshBuilder, t: Vector2i, col: Color, lift: float, parts: int = 2) -> void:
	var floor_y: float = world.wlevel[World.ti(t)]
	var step := 1.0 / parts
	for j in parts:
		for i in parts:
			var pts: Array[Vector3] = []
			for c in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var px: float = t.x + (i + c.x) * step
				var pz: float = t.y + (j + c.y) * step
				pts.append(Vector3(px, maxf(land.height_at(px, pz), floor_y) + lift, pz))
			m.tri(pts[0], pts[1], pts[2], col, Vector3.UP)
			m.tri(pts[0], pts[2], pts[3], col, Vector3.UP)


func _update_cursor() -> void:
	var m := MeshBuilder.new()
	ghost.visible = false
	if tool == null:
		if sel_tile.x >= 0:
			_tile_quad(m, sel_tile, Color(1, 1, 1, 0.4), 0.09, 4)
		hud.hint_label.text = ""
		cursor_mesh.mesh = m.commit()
		return
	var good_col := Color(0.3, 1.0, 0.5, 0.5)
	var bad_col := Color(1.0, 0.25, 0.2, 0.55)
	var cost := 0
	var good := 0
	var why := ""
	if _is_single():
		why = world.can_build(tool, hover)
		cost = world.cost_at(tool, hover)
		for t in world.footprint(tool, hover):
			if World.inb(t.x, t.y):
				_tile_quad(m, t, good_col if why == "" else bad_col, 0.09, 4)
		var sz: Vector2i = D.BUILD[tool].size
		var cx := hover.x + sz.x * 0.5
		var cz := hover.y + sz.y * 0.5
		ghost.mesh = Models.structure(tool)
		ghost.position = Vector3(cx, maxf(land.surface_at(cx, cz), land.water_at(cx, cz)) + 0.05, cz)
		ghost_mat.albedo_color = Color(0.8, 1.0, 0.85, 0.75) if why == "" else Color(1.0, 0.45, 0.4, 0.6)
		ghost.visible = true
	else:
		var tiles: Array[Vector2i] = _drag_tiles(drag_start, hover) if dragging else ([hover] as Array[Vector2i])
		if tool is String and tool in TERRA:
			tiles = _brush_tiles(hover)
		for t in tiles:
			var ok := _tile_ok(t)
			if World.inb(t.x, t.y):
				_tile_quad(m, t, good_col if ok else bad_col, 0.09, 2 if tiles.size() > 30 else 4)
			if ok:
				good += 1
				cost += world.cost_at(tool, t) if tool is int else int(D.TOOLS[tool].cost)
	cursor_mesh.mesh = m.commit()
	var def: Dictionary = D.BUILD[tool] if tool is int else D.TOOLS[tool]
	var text := "%s: %s" % [def.name, D.money(cost)]
	if _is_single():
		if why != "":
			text = "%s: %s" % [def.name, why]
		elif tool == D.B.OVERLOOK or tool == D.B.CAMP or tool == D.B.PICNIC:
			text += "   Scenery here: %d%%" % int(world.scenic(hover) * 100.0)
		elif tool == D.B.HIDE:
			text += "   Wildlife here: %d%%" % int(game.eco.wildlife_score(hover) * 100.0)
	elif tool is String and tool in TERRA:
		text = "%s   Hold to shape the ground.  [ ]  brush size %.1f   Slope here: %d%%" % [def.name, brush, int(world.slope_at(hover) * 100.0)]
	elif dragging and tool is String and tool == "switchback":
		var steep := 0.0
		for k in range(1, _route.size()):
			steep = maxf(steep, absf(world.height[World.ti(_route[k])] - world.height[World.ti(_route[k - 1])]))
		text += "  (%d tiles, steepest step %d%%)" % [good, int(steep * 100.0)]
	elif dragging:
		text += "  (%d tiles)" % good
	else:
		text += "   Drag to build. Right-click to cancel."
	if cost > game.money:
		text += "   Not enough money!"
	hud.hint_label.text = text


func _place_single() -> void:
	var why := game.try_build(tool, hover)
	if why != "":
		game.say("Can't build there: %s." % why, "info")


func _apply_drag() -> void:
	dragging = false
	var built := 0
	world.defer_nav = true
	for t in _drag_tiles(drag_start, hover):
		if not _tile_ok(t):
			continue
		if tool is int:
			var why := game.try_build(tool, t, true)
			if why == "Not enough money":
				game.say("Not enough money to finish building.", "warn")
				break
			if why == "":
				built += 1
		else:
			var done := false
			match tool:
				"switchback":
					var why2 := game.try_build(D.B.TRAIL, t, true)
					if why2 == "Not enough money":
						game.say("Not enough money to finish the trail.", "warn")
						break
					done = why2 == ""
				"bulldoze": done = game.bulldoze(t)
				"plant": done = game.plant_tree(t)
				"weed": done = game.weed(t)
			if done:
				built += 1
	world.defer_nav = false
	if built > 0:
		world.rebuild_nav()
		game.update_appeal()


func _rebuild_overlay() -> void:
	var m := MeshBuilder.new()
	if overlay_mode != "":
		for y in World.H:
			for x in World.W:
				var i := World.idx(x, y)
				var col := Color.TRANSPARENT
				match overlay_mode:
					"habitat":
						var v := world.quality[i]
						col = Color("d9534f").lerp(Color("f2c14e"), clampf(v * 2.0, 0.0, 1.0)).lerp(Color("2f9e55"), clampf(v * 2.0 - 1.0, 0.0, 1.0))
						col.a = 0.6
					"scenery":
						var v := clampf(world.scenic(Vector2i(x, y)) / 1.1, 0.0, 1.0)
						col = Color("5b4a8a").lerp(Color("f08a5d"), clampf(v * 2.0, 0.0, 1.0)).lerp(Color("fff3a0"), clampf(v * 2.0 - 1.0, 0.0, 1.0))
						col.a = 0.6
					"disturb":
						col = Color(0.85, 0.2, 0.15, clampf(world.disturb[i], 0.0, 1.0) * 0.75)
				if col.a > 0.02:
					_tile_quad(m, Vector2i(x, y), col, 0.1)
	overlay_mesh.mesh = m.commit()


# ----------------------------------------------------------------- inspector

func _inspect_click(screen: Vector2) -> void:
	var a = agents.pick(cam, screen)
	agents.selected = a
	sel_tile = Vector2i(-1, -1)
	if a == null:
		var hit = _ray_ground(screen)
		if hit != null:
			sel_tile = Vector2i(clampi(int(hit.x), 0, World.W - 1), clampi(int(hit.z), 0, World.H - 1))
	_update_inspector()


func _mood(sat: float) -> String:
	if sat >= 80.0: return "delighted"
	if sat >= 62.0: return "happy"
	if sat >= 45.0: return "content"
	if sat >= 30.0: return "unimpressed"
	return "miserable"


func _update_inspector() -> void:
	var sel = agents.selected
	if sel is Visitors.Group:
		var state := "Walking the trails"
		match sel.state:
			Visitors.S.DRIVE_IN: state = "Driving in"
			Visitors.S.DRIVE_OUT: state = "Heading home"
			Visitors.S.DWELL:
				state = "Taking a break"
				if sel.dwell_sid != 0 and world.structures.has(sel.dwell_sid):
					state = "At %s" % world.structures[sel.dwell_sid].name
			Visitors.S.WAIT_HELP: state = "In trouble, waiting for a ranger!"
		var text := "%s\n%s, %d %s\n%s\nMood: %s (%d)" % [sel.name, sel.vt.name, sel.n, "person" if sel.n == 1 else "people", state, _mood(sel.sat), int(sel.sat)]
		if sel.last_thought != "":
			text += "\n\"%s\"" % sel.last_thought
		hud.set_inspector(text)
	elif sel is Ecology.Animal:
		var sp: Dictionary = D.SPECIES[sel.sp]
		var lvl := game.eco.known(sel.sp)
		var info := "Not yet studied. Ecologists surveying this habitat will learn more."
		if lvl == 1:
			info = "Early impressions only. " + str(sp.desc)
		elif lvl == 2:
			info = "About %d in the park (%s). %s" % [int(round(game.eco.pops[sel.sp])), game.eco.status(sel.sp).to_lower(), D.NOTES[sp.id]]
		hud.set_inspector("%s\nCurrently: %s\n%s" % [sp.name, sel.doing, info])
	elif sel is Staffing.Staff:
		hud.set_inspector("%s, %s\n%s\nJobs completed: %d" % [sel.name, D.STAFF[sel.role].name, D.STAFF[sel.role].desc, sel.done])
	elif sel_tile.x >= 0:
		var i := World.ti(sel_tile)
		var lines: Array[String] = []
		if world.landmark_at.has(i):
			lines.append("%s (landmark)" % world.landmark_at[i].name)
			lines.append("Overlooks within 4 tiles of a landmark are far more scenic.")
		if world.sid[i] != 0 and world.structures.has(world.sid[i]):
			var s: Dictionary = world.structures[world.sid[i]]
			lines.append(str(s.name))
			if s.kind in D.ATTRACTIONS:
				lines.append("Appeal %d%%, %d visits, %d here now" % [int(float(s.quality) * 100.0), s.visits, s.visitors])
			if s.access.is_empty() and s.kind != D.B.GATE:
				lines.append("Not connected to a trail or road!")
		elif world.build[i] != D.B.NONE:
			lines.append(str(D.BUILD[world.build[i]].name))
		lines.append(D.TERRAIN_NAMES[world.terrain[i]])
		if world.count_kind(D.B.RESEARCH) > 0:
			lines.append("Habitat %d%%   Scenery %d%%   Disturbance %d%%" % [int(world.quality[i] * 100.0), int(world.scenic(sel_tile) * 100.0), int(world.disturb[i] * 100.0)])
		else:
			lines.append("Scenery %d%%   (habitat data needs a Research Station)" % int(world.scenic(sel_tile) * 100.0))
		if world.rare[i] > 0.0:
			lines.append("Lady's slipper orchid colony (health %d%%)" % int(world.rare[i] * 100.0))
		if world.fire[i] > 0:
			lines.append("On fire!")
		elif world.burned[i] > 0:
			lines.append("Burn scar, recovering (%d days)" % world.burned[i])
		if world.invasive[i] > 0.0 and world.inv_seen[i] == 1:
			lines.append("Invasive %s (%d%% cover)" % ["milfoil" if world.is_water(world.terrain[i]) else "thistle", int(world.invasive[i] * 100.0)])
		if world.litter[i] > 0:
			lines.append("Litter: %d pieces" % world.litter[i])
		hud.set_inspector("\n".join(lines))
	else:
		hud.set_inspector("")


# ------------------------------------------------------- dev / testing hooks
# Run with e.g.:  godot -- --autoplay --days=6 --shot=/tmp/a.png
# to build a small demo park, fast-forward it and save a screenshot.

func _dev_hooks(args: Dictionary) -> void:
	if args.has("stats"):
		_terrain_stats()
		var gcount := 0
		for k in land._regions:
			gcount += land._regions[k]["grass"].instance_count
		print("grass tufts ", gcount, "  grass nodes ", land._grass_nodes.size(), " visible ", land._grass_nodes[0].visible if land._grass_nodes.size() > 0 else false)
	if args.has("autoplay"):
		_demo_park()
	var days := int(args.get("days", "0"))
	var hours := float(args.get("hours", "0"))
	if days > 0 or hours > 0.0:
		var target_day := game.day + days
		var guard := 0
		while game.day < target_day and guard < 2000000:
			game.step(0.066)
			guard += 1
		var steps := int(hours * 6.0 / 0.066)
		for k in steps:
			game.step(0.066)
		_report()
	if args.has("terra"): # dx,dy from the entrance: raise a mound there, then level a pad beside it
		var tc: PackedStringArray = args.terra.split(",")
		var tt := world.entry + Vector2i(int(tc[0]), int(tc[1]))
		for k in 30:
			game.terraform(tt, "raise", 3.0, 0.0)
		for k in 20:
			game.terraform(tt + Vector2i(7, 0), "level", 2.5, world.height[World.ti(tt + Vector2i(7, 0))])
	if args.has("switch"): # x0,y0,x1,y1 in tiles: lay a switchback trail
		var sc: PackedStringArray = args["switch"].split(",")
		tool = "switchback"
		var route := _switchback(world.entry + Vector2i(int(sc[0]), int(sc[1])), world.entry + Vector2i(int(sc[2]), int(sc[3])))
		print("switchback tiles ", route.size())
		for t in route:
			game.try_build(D.B.TRAIL, t, true)
		tool = null
		world.rebuild_nav()
	if args.has("cam"): # tileX,tileY[,distance[,yawDegrees[,pitchDegrees]]]
		var c: PackedStringArray = args.cam.split(",")
		target = Vector3(float(c[0]), 0, float(c[1]))
		if c.size() > 2: dist = float(c[2])
		if c.size() > 3: yaw = deg_to_rad(float(c[3]))
		if c.size() > 4: pitch = deg_to_rad(float(c[4]))
	if args.has("camrel"): # same, relative to the park entrance
		var c2: PackedStringArray = args.camrel.split(",")
		target = Vector3(world.entry.x + float(c2[0]), 0, world.entry.y + float(c2[1]))
		if c2.size() > 2: dist = float(c2[2])
		if c2.size() > 3: yaw = deg_to_rad(float(c2[3]))
		if c2.size() > 4: pitch = deg_to_rad(float(c2[4]))
	if args.has("follow"): # point the camera at the first animal of a species, e.g. --follow=elk
		for an in game.eco.animals:
			if D.SPECIES[an.sp].id == args.follow:
				target = Vector3(an.pos.x / D.TILE, 0, an.pos.y / D.TILE)
				dist = float(args.get("dist", "3.0"))
				pitch = 0.6
				break
	if args.has("landmark"): # point the camera at a landmark, e.g. --landmark=falls
		for lm in world.landmarks:
			if lm.kind == args.landmark:
				target = Vector3(lm.tile.x + 0.5, 0, lm.tile.y + 0.5)
				dist = float(args.get("dist", "12"))
				pitch = 0.5
	zoom_goal = dist
	if args.has("panel"):
		hud.toggle_panel(args.panel)
	if args.has("overlay"):
		overlay_mode = args.overlay
	if args.has("weather"):
		game.weather = args.weather
		for z in game.zone_weather.size():
			game.zone_weather[z] = args.weather
		_overcast = 1.0 if args.weather in ["rain", "storm", "snow"] else 0.0
	if args.has("season"):
		game.day += int(args.season) * D.DAYS_PER_SEASON
	if args.has("fire"):
		for k in 40:
			var ft := Vector2i(int(target.x) + game.rng.randi_range(-4, 4), int(target.z) + game.rng.randi_range(-4, 4))
			game.eco.ignite(ft)
	if args.has("speed"):
		hud.set_speed(int(args.speed))
	if args.has("uitest"):
		await _ui_test()
	if args.has("shot"):
		_shot = args.shot
		_shot_frames = int(args.get("frames", "12"))
	elif args.has("quit"):
		get_tree().quit()


func _report() -> void:
	print("--- day %d  money %s  stars %.2f  eco %.1f  safety %.0f  appeal %.1f  demand %.0f  fair fee %.1f" % [
		game.day, D.money(game.money), game.stars, game.eco.health, game.safety, game.appeal, game.demand, game.fair_fee])
	print("visitors total %d  yesterday %d  now %d  litter %d  invasive %d  serious %d  research %.0f" % [
		game.total_visitors, game.visitors_yesterday, game.visitors.people_count(), world.litter_tiles.size(),
		world.invasive_tiles.size(), game.serious_incidents, game.research_total])
	var sp := ""
	for i in D.SPECIES.size():
		sp += "%s %d%%  " % [D.SPECIES[i].id, int(game.eco.ratio(i) * 100.0)]
	print(sp)
	print("ledger yesterday: ", game.ledger_prev)
	print("comments: ", game.comments)
	for k in game.sat_by_type:
		print("  sat %s: %.0f" % [k, game.sat_by_type[k][0] / game.sat_by_type[k][1]])
	print("staff done: ", game.staffing.staff.map(func(s): return "%s %d" % [s.role, s.done]))
	print("weather ", game.weather, " drought ", game.drought, " climate ", game.climate, " understanding %.2f" % game.eco.understanding(), " surveys ", game.eco.surveys, " discoveries ", game.discoveries.map(func(d): return d.id))
	print("grants: active ", game.grants.active.size(), " done ", game.grants.completed)


func _demo_park() -> void:
	game.money = 80000.0
	var e := world.entry
	for k in range(3, 11):
		game.try_build(D.B.ROAD, e + Vector2i(0, -k), true)
	game.try_build(D.B.GATE, e + Vector2i(0, -2), true)
	for y in range(-10, -7):
		for x in range(1, 5):
			game.try_build(D.B.PARKING, e + Vector2i(x, y), true)
	var hub := e + Vector2i(5, -9)
	game.try_build(D.B.TRAIL, hub, true)
	for k in range(1, 4):
		game.try_build(D.B.TRAIL, hub + Vector2i(k, 0), true)
	game.try_build(D.B.VISITOR_CENTER, hub + Vector2i(1, -2), true)
	game.try_build(D.B.RESTROOM, hub + Vector2i(0, 1), true)
	game.try_build(D.B.BIN, hub + Vector2i(1, 1), true)
	game.try_build(D.B.PICNIC, hub + Vector2i(2, 1), true)
	game.try_build(D.B.TRAILHEAD, hub + Vector2i(3, 1), true)
	game.try_build(D.B.SNACK, hub + Vector2i(0, -1), true)
	game.try_build(D.B.RANGER, e + Vector2i(-3, -8), true)
	game.try_build(D.B.RESEARCH, e + Vector2i(-3, -5), true)
	game.try_build(D.B.CAMP, e + Vector2i(-6, -11), true)
	for k in range(1, 5):
		game.try_build(D.B.TRAIL, e + Vector2i(-k, -10), true)
	var start := hub + Vector2i(3, 0)
	var marks: Array = world.landmarks.duplicate()
	marks.sort_custom(func(a, b): return Vector2(a.tile - start).length() < Vector2(b.tile - start).length())
	var made := 0
	for lm in marks:
		if made >= 3:
			break
		var goal := Vector2i(-1, -1)
		var lt: Vector2i = lm.tile
		for r in range(1, 5):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var t := lt + Vector2i(dx, dy)
					if goal.x < 0 and World.inb(t.x, t.y) and not world.staff_nav.is_point_solid(t) and world.can_build(D.B.TRAIL, t) == "":
						goal = t
		if goal.x < 0:
			continue
		var path := world.staff_nav.get_id_path(start, goal)
		if path.is_empty():
			continue
		for t in path:
			game.try_build(D.B.TRAIL, t, true)
		for d in World.DIRS:
			if game.try_build(D.B.OVERLOOK, goal + d, true) == "":
				break
		game.try_build(D.B.BIN, path[path.size() / 2] + Vector2i(1, 0), true)
		game.try_build(D.B.SIGN, path[path.size() / 3] + Vector2i(0, 1), true)
		made += 1
	for role in ["ranger", "ranger", "maint", "maint", "eco", "eco"]:
		game.staffing.hire(role)
	game.grants.accept(0)
	game.update_appeal()
	print("demo park: structures ", world.structures.size(), " trails ", world.trail_tiles.size(), " open ", game.open)


# Drives the real input path with synthetic mouse events.
func _screen(t: Vector2i) -> Vector2:
	return cam.unproject_position(land.tile_center(t))


func _mouse(pos: Vector2, pressed, button: int = MOUSE_BUTTON_LEFT) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)
	get_viewport().warp_mouse(pos)
	await get_tree().process_frame
	if pressed != null:
		var mb := InputEventMouseButton.new()
		mb.position = pos
		mb.global_position = pos
		mb.button_index = button
		mb.pressed = pressed
		Input.parse_input_event(mb)
		await get_tree().process_frame
	await get_tree().process_frame


func _click_tool(index: int, category: int) -> void:
	var cb: Button = hud.cat_buttons[category]
	var c := cb.get_global_rect().get_center()
	await _mouse(c, true)
	await _mouse(c, false)
	await get_tree().process_frame
	var b: Control = hud.tool_row.get_child(index)
	c = b.get_global_rect().get_center()
	await _mouse(c, true)
	await _mouse(c, false)


func _count(kind: int) -> int:
	var n := 0
	for b in world.build:
		if b == kind:
			n += 1
	return n


func _ui_test() -> void:
	for k in 5:
		await get_tree().process_frame
	var e := world.entry
	target = Vector3(e.x + 0.5, 0.0, e.y - 6.0)
	dist = 40.0
	pitch = 1.1
	for k in 20:
		await get_tree().process_frame
	var roads := _count(D.B.ROAD)
	await _click_tool(0, 0)
	print("tool after clicking Road button: ", tool)
	await _mouse(_screen(e + Vector2i(0, -3)), true)
	await _mouse(_screen(e + Vector2i(0, -6)), null)
	await _mouse(_screen(e + Vector2i(0, -9)), false)
	print("roads built by drag: ", _count(D.B.ROAD) - roads, " (expect 7)")
	await _click_tool(3, 0)
	await _mouse(_screen(e + Vector2i(0, -2)), true)
	await _mouse(_screen(e + Vector2i(0, -2)), false)
	print("gates: ", world.count_kind(D.B.GATE), " (expect 1)")
	await _click_tool(2, 0)
	await _mouse(_screen(e + Vector2i(1, -9)), true)
	await _mouse(_screen(e + Vector2i(3, -7)), false)
	print("parking tiles: ", world.lot_tiles.size(), " (expect 9)")
	await _click_tool(1, 0)
	await _mouse(_screen(e + Vector2i(4, -8)), true)
	await _mouse(_screen(e + Vector2i(9, -12)), false)
	print("trail tiles: ", world.trail_tiles.size(), " (expect 10)")
	await _click_tool(0, 2)
	await _mouse(_screen(e + Vector2i(9, -13)), true)
	await _mouse(_screen(e + Vector2i(9, -13)), false)
	print("overlooks: ", world.count_kind(D.B.OVERLOOK), " open: ", game.open, " money: ", game.money)
	await _mouse(_screen(e + Vector2i(-4, -6)), true, MOUSE_BUTTON_RIGHT)
	await _mouse(_screen(e + Vector2i(-4, -6)), false, MOUSE_BUTTON_RIGHT)
	print("tool after right-click: ", tool)
	await _mouse(_screen(e + Vector2i(9, -13)), true)
	await _mouse(_screen(e + Vector2i(9, -13)), false)
	print("inspector: ", hud.inspector_label.text.replace("\n", " | "))
	await _click_tool(0, 1)
	await _mouse(_screen(e + Vector2i(-4, -6)), null)
	hud.set_speed(4)
	for k in 40:
		await get_tree().process_frame
	print("after a while: visitors ", game.visitors.people_count(), " ", game.date_text())


func _terrain_stats() -> void:
	var counts := {}
	var bio := {}
	var water := 0
	var river := 0
	var hi := 0.0
	for i in world.terrain.size():
		counts[world.terrain[i]] = counts.get(world.terrain[i], 0) + 1
		bio[world.biome[i]] = bio.get(world.biome[i], 0) + 1
		if world.wlevel[i] != World.NO_WATER:
			water += 1
		hi = maxf(hi, world.height[i])
	var n := float(world.terrain.size())
	var line := "terrain:"
	for k in counts:
		line += " %s %d%%" % [D.TERRAIN_NAMES[k], int(counts[k] * 100.0 / n)]
	print(line)
	line = "biomes:"
	for k in bio:
		line += " %s %d%%" % [D.BIOME_NAMES[k], int(bio[k] * 100.0 / n)]
	print(line, "  water tiles ", water, "  highest ", snappedf(hi, 0.1), "  entry ", world.entry, "  landmarks ", world.landmarks.map(func(l): return l.kind))
