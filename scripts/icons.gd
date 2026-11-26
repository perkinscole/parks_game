class_name Icons
extends Node
## Build-menu pictures. Each building's real 3D model is photographed once
## into a small off-screen viewport, so the button shows exactly what you get.

static var tex := {} # building kind -> Texture2D


func build(shared_mat: Material) -> void:
	for kind: int in D.BUILD:
		if kind == D.B.ROAD or kind == D.B.TRAIL or kind == D.B.PARKING or tex.has(kind):
			continue
		var name := str(D.B.keys()[kind]).to_lower()
		var mi := MeshInstance3D.new()
		var ext := Models.external(name)
		if ext != null:
			mi.mesh = ext
			mi.transform = Models.fit(ext, 1.0, true)
		else:
			mi.mesh = Models.structure(kind)
			mi.material_override = shared_mat
		if mi.mesh == null:
			mi.free()
			continue
		var vp := SubViewport.new()
		vp.size = Vector2i(160, 160)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		vp.add_child(mi)
		var box: AABB = mi.transform * mi.mesh.get_aabb()
		var centre := box.get_center()
		var reach := maxf(box.size.y, maxf(box.size.x, box.size.z))
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = reach * 1.35
		cam.position = centre + Vector3(0.75, 0.6, 1.0).normalized() * (reach * 4.0)
		vp.add_child(cam)
		cam.look_at_from_position(cam.position, centre, Vector3.UP)
		var key := DirectionalLight3D.new()
		key.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(35.0), 0.0)
		key.light_energy = 1.35
		vp.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(-120.0), 0.0)
		fill.light_energy = 0.4
		fill.light_color = Color(0.75, 0.85, 1.0)
		vp.add_child(fill)
		var we := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.75, 0.8, 0.9)
		e.ambient_light_energy = 0.75
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		we.environment = e
		vp.add_child(we)
		tex[kind] = vp.get_texture()
