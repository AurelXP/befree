extends SceneTree
var g: Node
func _w(s: float) -> void:
	await create_timer(s).timeout
func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/befree_shots/%s.png" % name)
func _init() -> void:
	await process_frame
	g = root.get_node("Game")
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _w(1.0)
	await _shot("s0_title")
	main.hud.show_title(false)
	await main._begin_play()
	await _w(1.5)
	await _shot("s1_center")
	g.has_spoon = true
	g.minutes = 760.0
	main.cell.show_tray("lunch", true)
	await _w(1.5)
	main.player.snap_to("table")
	main.player.hands.set_pose("cake")
	await _w(1.0)
	await _shot("s2_table")
	main.player.snap_to("wall")
	g.poster_moved = true
	main.cell.set_poster_moved(true, false)
	g.spoon_equipped = true
	main.player.hands.set_spoon(true)
	main.player.hands.set_pose("dig")
	main.cell.set_dig(60.0)
	await _w(1.0)
	await _shot("s3_dig")
	main.player.snap_to("center")
	main.player.hands.set_pose("idle")
	await _w(0.5)
	main.guard.set_mode("stand")
	await _w(3.0)
	await _shot("s4_guard")
	quit()
