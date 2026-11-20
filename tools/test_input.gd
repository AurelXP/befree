extends SceneTree
## Test d'entrées réelles : glisser pour regarder, bouton de navigation.
## Lancer avec xvfb (voir README) : le glisser passe par le vrai pipeline d'événements.

func _w(s: float) -> void:
	await create_timer(s).timeout

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
	print("input_enabled=", pl.input_enabled, " yaw_off before=", pl._yaw_off)
	_mouse(Vector2(640, 400), true)
	await process_frame
	for i in 10:
		_move(Vector2(640 + i * 20, 400), Vector2(20, 0))
		await process_frame
	_mouse(Vector2(840, 400), false)
	await process_frame
	print("yaw_off after drag=", pl._yaw_off)
	# bouton de navigation "Table"
	var target: Button = null
	for b in main.hud.nav_box.get_children():
		if b is Button and b.text == "Table":
			target = b
	var c: Vector2 = target.get_global_rect().get_center()
	_mouse(c, true)
	await process_frame
	_mouse(c, false)
	await _w(1.5)
	print("station after nav click=", pl.station)
	quit()
