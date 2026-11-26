extends SceneTree
## Renders a top-down picture of a model, with +X to the right and +Z toward
## the bottom of the image, so its facing direction can be read off.
##   godot --path . -s tools/orient_check.gd -- <model.glb> <out.png>

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if args.size() < 2 or doc.append_from_file(args[0], state) != OK:
		print("usage: -- <model.glb> <out.png>")
		quit(1)
		return
	var model: Node3D = doc.generate_scene(state)
	var vp := SubViewport.new()
	vp.size = Vector2i(320, 320)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(model)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	cam.make_current()
	await process_frame
	var box := AABB()
	var first := true
	var stack: Array = [model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and node.mesh != null:
			var b: AABB = node.global_transform * node.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		stack.append_array(node.get_children())
	var c := box.get_center()
	cam.size = maxf(box.size.x, box.size.z) * 1.15
	cam.near = 0.01
	cam.far = box.size.length() * 6.0
	cam.look_at_from_position(c + Vector3(0, box.size.length() * 2.0, 0), c, Vector3.FORWARD)
	for k in 4:
		await process_frame
	vp.get_texture().get_image().save_png(args[1])
	print("size ", box.size)
	quit()
