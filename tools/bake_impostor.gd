extends SceneTree
## Bakes a detailed tree model into two small cut-out images (side view and
## top view) so that forests can be drawn with a handful of triangles per tree.
##
##   godot --path . -s tools/bake_impostor.gd -- <model.glb> <output name>
##
## Writes models/impostors/<name>_side.png and <name>_top.png.

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- <model.glb> <output name>")
		quit(1)
		return
	_bake(args[0], args[1])


func _bake(path: String, out_name: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		print("could not read ", path)
		quit(1)
		return
	var model: Node3D = doc.generate_scene(state)
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 1024)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	vp.add_child(model)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0)
	sun.light_energy = 0.6
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	cam.make_current()
	await process_frame

	# bounds of everything in the model
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
	var width := maxf(box.size.x, box.size.z)

	# side view: the image is exactly as tall as the tree
	cam.size = box.size.y
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.look_at_from_position(c + Vector3(0, 0, box.size.length() * 2.0), c, Vector3.UP)
	cam.near = 0.01
	cam.far = box.size.length() * 6.0
	for k in 4:
		await process_frame
	var side := vp.get_texture().get_image()
	# keep only the columns the tree actually uses (half the height at most)
	var half_w := int(ceil(width / box.size.y * 512.0))
	half_w = clampi(half_w, 16, 256)
	side = side.get_region(Rect2i(256 - half_w, 0, half_w * 2, 1024))
	side.save_png("res://models/impostors/%s_side.png" % out_name)

	# top view
	vp.size = Vector2i(512, 512)
	cam.size = width
	cam.look_at_from_position(c + Vector3(0, box.size.length() * 2.0, 0), c, Vector3.FORWARD)
	for k in 4:
		await process_frame
	vp.get_texture().get_image().save_png("res://models/impostors/%s_top.png" % out_name)
	print("baked %s: height %.2f width %.2f aspect %.3f" % [out_name, box.size.y, width, width / box.size.y])
	quit()
