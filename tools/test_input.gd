extends SceneTree
## Test d'entrées réelles (joystick flottant, glisser pour regarder, saut) via le vrai pipeline.
## Nécessite un affichage : xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/test_input.gd

var fails: int = 0

func _w(s: float) -> void:
	await create_timer(s).timeout

func _check(name: String, cond: bool, extra: String = "") -> void:
	print(("OK   " if cond else "FAIL ") + name + ("  " + extra if extra != "" else ""))
	if not cond:
		fails += 1

func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)

func _move(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)

func _init() -> void:
	await process_frame
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _w(0.5)
	main.hud.show_title(false)
	await main._begin_play()
	await _w(0.5)
	var pl: Node = main.player
	_check("entrées activées", pl.input_enabled and main.hud.touch.enabled)

	# joystick : appui à gauche puis glisser vers le haut = avancer
	var z0: float = pl.pos().z
	_mouse(Vector2(200, 500), true)
	await process_frame
	for i in 6:
		_move(Vector2(200, 500 - 15 * (i + 1)), Vector2(0, -15))
		await process_frame
	await _w(0.8)
	var z1: float = pl.pos().z
	_check("joystick : le joueur avance", z1 < z0 - 0.4, "z %.2f -> %.2f" % [z0, z1])
	_mouse(Vector2(200, 410), false)
	await _w(0.4)
	_check("joystick relâché : arrêt", main.hud.touch.move == Vector2.ZERO)

	# regard : glisser dans la moitié droite
	var yaw0: float = pl.yaw
	_mouse(Vector2(900, 300), true)
	await process_frame
	for i in 8:
		_move(Vector2(900 - 20 * (i + 1), 300), Vector2(-20, 0))
		await process_frame
	_mouse(Vector2(740, 300), false)
	await process_frame
	await process_frame
	_check("regard : la caméra tourne", absf(pl.yaw - yaw0) > 0.3, "lacet %.2f -> %.2f" % [yaw0, pl.yaw])

	# saut : clic sur le bouton
	var c: Vector2 = main.hud.jump_btn.get_global_rect().get_center()
	var y0: float = pl.pos().y
	var peak: float = y0
	_mouse(c, true)
	await process_frame
	_mouse(c, false)
	for i in 12:
		await process_frame
		peak = maxf(peak, pl.pos().y)
	_check("saut : le joueur décolle", peak > y0 + 0.2, "hauteur max %.2f" % (peak - y0))
	print("FAILS: ", fails)
	quit(1 if fails > 0 else 0)
