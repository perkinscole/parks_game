extends Node3D
## Scene root: wires the simulation to the 3D views and handles the orbit
## camera, building tools and inspection.

const LINEAR := [D.B.ROAD, D.B.TRAIL]

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
	var seed_val := int(args.get("seed", "0"))
	if seed_val == 0:
		seed_val = int(Time.get_unix_time_from_system()) % 1000000 + 1

	var base = load("res://fonts/Fredoka.ttf")
	if base != null:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
		font = fv
	else:
		font = ThemeDB.fallback_font

	game = Game.new()
	add_child(game)
	game.setup(seed_val)
	world = game.world

	var we := WorldEnvironment.new()
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 12.0
	var sky_res := Sky.new()
	sky_res.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 2.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 130.0
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
	cam.fov = 42.0
	cam.near = 0.3
	cam.far = 500.0
	add_child(cam)
	cam.make_current()
	target = Vector3(world.entry.x + 0.5, 0.0, world.entry.y - 9.0)
	_update_camera()

	hud = HUD.new()
	add_child(hud)
	hud.setup(game, font)
	hud.set_speed(1)
	hud.tool_selected.connect(func(t): tool = t; dragging = false)
	hud.overlay_selected.connect(_set_overlay)
	hud.jump_to.connect(func(t): target = Vector3(t.x + 0.5, 0, t.y + 0.5))
	game.say("Welcome, Superintendent! This wild land is yours to protect and share. Follow the Getting Started list to open the park.", "good")
	game.say("Camera: drag to move, right-drag to orbit, scroll to zoom (or WASD, Q/E). Click anything to inspect it.", "info")

	_dev_hooks(args)


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
	target.y = lerpf(target.y, maxf(land.height_at(target.x, target.z), 0.0), 0.12)
	pitch = clampf(pitch, 0.16, 1.45)
	dist = clampf(dist, 4.0, 110.0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + offset
	cam.look_at(target, Vector3.UP)


func _make_precip(amount: int, size: Vector2, col: Color, speed: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 22.0 / speed if speed > 10.0 else 5.5
	p.preprocess = p.lifetime
	p.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 0.5, 26)
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
	var day := smoothstep(0.0, 0.22, up)
	var glow := (1.0 - smoothstep(0.1, 0.45, up)) * smoothstep(0.0, 0.08, up)
	var night := 1.0 - day
	if day > 0.02:
		sun.rotation = Vector3(deg_to_rad(-(7.0 + 44.0 * up)), deg_to_rad(lerpf(105.0, -105.0, p)), 0.0)
		sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.62, 0.36), glow)
		sun.light_energy = (1.05 + 0.5 * glow) * day * (1.0 - 0.62 * _overcast)
	else:
		sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(40.0), 0.0)
		sun.light_color = Color(0.55, 0.66, 1.0)
		sun.light_energy = 0.32 * smoothstep(0.98, 1.0, night) + 0.0001
	env.ambient_light_color = _mix(Color(0.2, 0.26, 0.45), Color(0.6, 0.5, 0.55), Color(0.5, 0.6, 0.8), day, glow)
	env.ambient_light_energy = 0.4 - 0.08 * day
	sky_mat.sky_top_color = _mix(Color(0.02, 0.03, 0.09), Color(0.22, 0.3, 0.55), Color(0.2, 0.42, 0.78), day, glow)
	sky_mat.sky_horizon_color = _mix(Color(0.08, 0.11, 0.22), Color(0.98, 0.62, 0.42), Color(0.68, 0.8, 0.92), day, glow)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = sky_mat.sky_horizon_color.darkened(0.3)
	env.fog_light_color = sky_mat.sky_horizon_color.lerp(Color(0.6, 0.68, 0.78), 0.4 * day)
	land.set_night(smoothstep(0.35, 0.9, night + glow * 0.5 + _overcast * 0.25))
	# weather: clouds, rain and snow
	var wet: bool = game.weather == "rain" or game.weather == "storm" or game.weather == "snow"
	_overcast = move_toward(_overcast, 1.0 if wet else 0.0, 0.01)
	var grey := Color(0.5, 0.54, 0.6) * (0.35 + 0.65 * day)
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(grey * 0.8, _overcast)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(grey, _overcast)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	env.fog_light_color = env.fog_light_color.lerp(grey, _overcast)
	env.fog_density = lerpf(0.0022, 0.011 if game.weather != "snow" else 0.016, _overcast)
	env.ambient_light_energy += 0.12 * _overcast
	if game.weather == "heat":
		env.fog_light_color = env.fog_light_color.lerp(Color(0.9, 0.8, 0.6), 0.4)
	rain.emitting = game.weather == "rain" or game.weather == "storm"
	snow.emitting = game.weather == "snow"
	var above := target + Vector3(0, 13.0, 0)
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
	var step := 0.3
	var prev := from
	var p := from
	for k in 1500:
		p += dir * step
		var inside := p.x >= 0.0 and p.z >= 0.0 and p.x < World.W and p.z < World.H
		var ground := maxf(land.height_at(p.x, p.z), 0.0) if inside else -1.6
		if p.y <= ground:
			if not inside:
				return null
			for b in 8:
				var mid := (prev + p) * 0.5
				if mid.y <= maxf(land.height_at(mid.x, mid.z), 0.0):
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
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: dist /= 1.1
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: dist *= 1.1
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					orbiting = true
					pan_moved = 0.0
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_update_hover()
					if tool == null:
						left_pan = true
						pan_moved = 0.0
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
			KEY_ESCAPE:
				dragging = false
				hud.select_tool(null)
				sel_tile = Vector2i(-1, -1)
				agents.selected = null


## Releases and drags are handled here so they still arrive when the mouse
## ends up over the UI.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if orbiting:
			yaw -= event.relative.x * 0.007
			pitch += event.relative.y * 0.006
			pan_moved += event.relative.length()
		elif left_pan:
			_pan(event.relative)
			pan_moved += event.relative.length()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if left_pan:
				left_pan = false
				if pan_moved < 6.0:
					_inspect_click(event.position)
			elif dragging:
				_update_hover()
				_apply_drag()
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if orbiting:
				orbiting = false
				if event.button_index == MOUSE_BUTTON_RIGHT and pan_moved < 6.0:
					if dragging:
						dragging = false
					else:
						hud.select_tool(null)


func _process(delta: float) -> void:
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x += 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x -= 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y -= 1
	if mv != Vector2.ZERO:
		_pan(mv * delta * 520.0)
	if Input.is_key_pressed(KEY_Q): yaw -= delta * 1.4
	if Input.is_key_pressed(KEY_E): yaw += delta * 1.4
	_update_camera()
	_update_hover()

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


func _drag_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	if tool is int and tool in LINEAR:
		return _line(a, b)
	return _rect(a, b)


func _tile_ok(t: Vector2i) -> bool:
	if not World.inb(t.x, t.y):
		return false
	var i := World.ti(t)
	if tool is int:
		return world.can_build(tool, t) == ""
	match tool:
		"bulldoze": return world.build[i] != D.B.NONE and t != world.entry
		"weed": return world.invasive[i] > 0.0 and world.inv_seen[i] == 1
		"plant":
			var ter := world.terrain[i]
			return world.build[i] == D.B.NONE and world.trees[i] == 0 and (ter == D.T.GRASS or ter == D.T.FOREST or ter == D.T.MEADOW) \
				and not world.landmark_at.has(i) and world.rare[i] <= 0.0
	return false


func _tile_quad(m: MeshBuilder, t: Vector2i, col: Color, lift: float, parts: int = 2) -> void:
	var water := world.is_water(world.terrain[World.ti(t)])
	var floor_y := 0.0 if water else -9.0
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
		ghost.position = Vector3(cx, maxf(land.surface_at(cx, cz), 0.0) + 0.05, cz)
		ghost_mat.albedo_color = Color(0.8, 1.0, 0.85, 0.75) if why == "" else Color(1.0, 0.45, 0.4, 0.6)
		ghost.visible = true
	else:
		var tiles: Array[Vector2i] = _drag_tiles(drag_start, hover) if dragging else ([hover] as Array[Vector2i])
		for t in tiles:
			var ok := _tile_ok(t)
			if World.inb(t.x, t.y):
				_tile_quad(m, t, good_col if ok else bad_col, 0.09, 4)
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
	if args.has("cam"): # tileX,tileY[,distance[,yawDegrees[,pitchDegrees]]]
		var c: PackedStringArray = args.cam.split(",")
		target = Vector3(float(c[0]), 0, float(c[1]))
		if c.size() > 2: dist = float(c[2])
		if c.size() > 3: yaw = deg_to_rad(float(c[3]))
		if c.size() > 4: pitch = deg_to_rad(float(c[4]))
	if args.has("panel"):
		hud.toggle_panel(args.panel)
	if args.has("overlay"):
		overlay_mode = args.overlay
	if args.has("weather"):
		game.weather = args.weather
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
	target = Vector3(e.x + 0.5, 0.0, e.y - 4.0)
	dist = 34.0
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
