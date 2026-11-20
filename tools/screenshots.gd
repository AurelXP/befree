extends SceneTree
## Captures du jeu (xvfb + rendu logiciel) -> /tmp/befree_shots/s_*.png

var g: Node

func _w(s: float) -> void:
	await create_timer(s).timeout

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/befree_shots/s_%s.png" % name)

func _init() -> void:
	await process_frame
	g = root.get_node("Game")
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _w(1.0)
	await _shot("0_title")
	main.hud.show_title(false)
	await main._begin_play()
	await _w(1.5)
	await _shot("1_cell")
	# cour
	main.player.teleport(Vector3(2.2, 0.05, -12.0), 0.0)
	await _w(1.0)
	await _shot("2_yard")
	# cantine, repas
	g.minutes = 779.5
	await _w(1.0)
	main.player.teleport(Vector3(22.8, 0.05, -21.0), -PI * 0.5 * -1.0)
	main.player.yaw = PI * -0.5 * -1.0
	main.player.yaw = -PI * 0.5 * -1.0
	await _w(1.2)
	await _shot("3_cantine")
	# dialogue Marco
	main.player.teleport(Vector3(-5.2, 0.05, -31.6), PI * 0.5)
	await _w(0.6)
	main._on_action_down()
	await _w(0.8)
	await _shot("4_shop")
	main._on_dialog_choice("close")
	# garde : poursuite
	main.player.teleport(Vector3(0.0, 0.05, -5.0), 0.0)
	g.minutes = 400.0
	await _w(0.5)
	main.guard.position = Vector3(0, 0, -9)
	main.player.yaw = PI
	await _w(1.0)
	await _shot("5_guard")
	# jardin
	main.player.teleport(Vector3(-12.5, 0.05, -22.0), PI * 0.5)
	await _w(1.0)
	await _shot("6_garden")
	quit()
