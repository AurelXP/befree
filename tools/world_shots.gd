extends SceneTree
## Captures de la carte (sans le jeu) : xvfb + rendu logiciel. Sortie : /tmp/befree_shots/w_*.png

func _w(s: float) -> void:
	await create_timer(s).timeout

func _init() -> void:
	await process_frame
	var world := World.new()
	root.add_child(world)
	world.build()
	world.set_tod(12.0 * 60.0, false)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 120.0
	root.add_child(cam)
	cam.current = true
	var shots: Array = [
		["yard", Vector3(2.2, 1.7, -8.5), Vector3(2.2, 1.5, -30.0)],
		["yard2", Vector3(2.0, 1.7, -22.0), Vector3(-12.0, 1.0, -34.0)],
		["cantine", Vector3(10.5, 1.7, -21.0), Vector3(24.0, 1.0, -21.0)],
		["cantine2", Vector3(11.0, 1.7, -14.0), Vector3(16.0, 0.8, -26.0)],
		["garden", Vector3(-11.8, 1.7, -22.0), Vector3(-22.0, 1.0, -22.0)],
		["overview", Vector3(0.0, 22.0, 12.0), Vector3(0.0, 0.0, -30.0)],
		["corridor", Vector3(0.0, 1.6, 0.8), Vector3(1.5, 1.4, -8.0)],
	]
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		await _w(0.5)
		await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png("/tmp/befree_shots/w_%s.png" % s[0])
	quit()
