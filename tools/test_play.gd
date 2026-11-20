extends SceneTree

func _wait(sec: float) -> void:
	var t: float = 0.0
	while t < sec:
		if g != null and g.speed > 0.5 and not g.digging:
			g.speed = 1.0 / Engine.time_scale
		await create_timer(0.25).timeout
		t += 0.25

var g: Node

func _init() -> void:
	await process_frame
	g = root.get_node("Game")
	Engine.time_scale = 4.0
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	main.hud.show_title(false)
	await main._begin_play()
	print("play state: ", main.state)
	await _wait(1.0)
	# déjeuner jour 1 avec gâteau
	g.minutes = 749.0
	await _wait(2.0)
	print("phase: ", g.phase, " tray: ", main.cell.tray.visible, " cake: ", main.cell.cake.visible)
	main._on_tap("cake")
	await _wait(5.0)
	print("has_spoon: ", g.has_spoon)
	main._on_tap("tray")
	await _wait(7.0)
	print("duty_done after eat: ", g.duty_done)
	# poster + cuillère
	await _wait(1.0)
	main._on_tap("poster")
	await _wait(4.0)
	print("poster_moved: ", g.poster_moved)
	main._on_spoon()
	# nuit : gardien endormi
	g.minutes = 1300.0
	await _wait(6.0)
	print("phase: ", g.phase, " guard mode: ", main.guard.mode)
	main._on_dig_hold(true)
	g.speed = 1.0 / Engine.time_scale
	var t: float = 0.0
	while g.dig < 30.0 and t < 40.0 and main.state == "play":
		await _wait(0.5)
		t += 0.5
	print("dig: ", g.dig, " susp: ", g.suspicion, " strikes: ", g.strikes)
	main._on_dig_hold(false)
	# test punition
	g.suspicion = 100.0
	await _wait(8.0)
	print("strikes after caught: ", g.strikes, " dig: ", g.dig, " poster_moved: ", g.poster_moved, " state: ", main.state)
	# test devoir manqué : passer toutes les phases
	g.minutes = 929.0
	await _wait(5.0)
	g.minutes = 975.0
	await _wait(10.0)
	print("strikes after missed pee: ", g.strikes, " state: ", main.state)
	# test fin
	g.strikes = 0
	main.state = "play"
	main.in_caught = false
	g.running = true
	g.dig = 99.9
	g.poster_moved = true
	g.spoon_equipped = true
	g.minutes = 1300.0
	main.guard.set_mode("doze")
	main._on_dig_hold(true)
	await _wait(6.0)
	print("final state: ", main.state)
	quit()
