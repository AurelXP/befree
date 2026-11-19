class_name Cinematic
extends Node
## Cinématique d'intro (l'histoire de Théo) et scène de fin (le tunnel).

var cell: Cell
var guard: Guard
var player: Player
var hud: Hud
var skipped: bool = false
var _shot_tween: Tween


func setup(c: Cell, g: Guard, p: Player, h: Hud) -> void:
	cell = c
	guard = g
	player = p
	hud = h


func _on_skip() -> void:
	skipped = true
	if _shot_tween != null and _shot_tween.is_valid():
		_shot_tween.kill()
	hud.clear_subtitle()


func _cam_lerp(t: float, fp: Vector3, fl: Vector3, tp: Vector3, tl: Vector3) -> void:
	var pos: Vector3 = fp.lerp(tp, t)
	var look: Vector3 = fl.lerp(tl, t)
	player.cam.position = pos
	if not pos.is_equal_approx(look):
		player.cam.look_at(look, Vector3.UP)


func _wait(sec: float) -> void:
	var t: float = 0.0
	while t < sec and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()


## Un plan : mouvement de caméra + sous-titre.
func _beat(text: String, fp: Vector3, fl: Vector3, tp: Vector3, tl: Vector3, dur: float) -> void:
	if skipped:
		return
	_shot_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shot_tween.tween_method(_cam_lerp.bind(fp, fl, tp, tl), 0.0, 1.0, dur)
	if text != "":
		hud.say(text, 0.0)
	await _wait(dur)


func intro() -> void:
	skipped = false
	player.input_enabled = false
	player.cinematic = true
	player.hands.visible = false
	hud.set_gameplay_visible(false)
	hud.letterbox(true)
	hud.set_skip_visible(true)
	hud.skip_pressed.connect(_on_skip, CONNECT_ONE_SHOT)
	await hud.fade_to(1.0, 0.01)

	# Plan 1 : le couloir, Gaston qui dort
	guard.set_mode("doze")
	hud.fade_to(0.0, 1.5)
	await _beat("Paris, 2026.\nThéo Marchand, 27 ans, est condamné à 25 ans de prison pour un braquage qu'il n'a jamais commis.",
		Vector3(-3.2, 1.9, -6.8), Vector3(0.6, 1.4, -3.4), Vector3(-1.2, 1.7, -4.9), Vector3(0.6, 1.5, -3.4), 9.0)

	# Plan 2 : Gaston, la matraque
	guard.set_mode("cycle")
	await _beat("Ici, tout est réglé comme une horloge : repas, toilettes, inspections.\nEt Gaston, le gardien, ne rate jamais rien. Enfin... presque jamais.",
		Vector3(-1.0, 1.4, -0.8), Vector3(0.6, 1.5, -3.4), Vector3(0.3, 1.3, -2.4), Vector3(0.6, 1.35, -3.45), 9.0)

	# Plan 3 : la cellule
	await _beat("Dans quelques jours, c'est mon anniversaire.\nMa sœur Léa m'a promis un gâteau. Et Léa ne fait jamais rien comme tout le monde.",
		Vector3(1.8, 1.6, 1.7), Vector3(-1.4, 0.7, 0.2), Vector3(1.0, 1.5, -0.2), Vector3(1.98, 1.3, 0.2), 9.0)

	# Plan 4 : le gâteau
	if not skipped:
		cell.show_tray("lunch", true)
	await _beat("Une cuillère. Un mur. Du temps.\nIl m'en faudra beaucoup... mais je me suis juré de sortir d'ici.",
		Vector3(0.9, 1.7, -0.1), Vector3(1.6, 0.95, -0.9), Vector3(1.0, 1.35, -0.6), Vector3(1.6, 0.98, -0.95), 8.0)

	# Carton-titre
	hud.clear_subtitle()
	await hud.fade_to(1.0, 0.8)
	if not skipped:
		hud.say("B E F R E E\nÉvade-toi.", 1.2)
		await _wait(3.2)
	hud.clear_subtitle()
	cell.tray.visible = false
	cell.cake.visible = false
	if hud.skip_pressed.is_connected(_on_skip):
		hud.skip_pressed.disconnect(_on_skip)
	hud.set_skip_visible(false)
	hud.letterbox(false)
	player.snap_to("center")
	player.cinematic = false
	player.hands.visible = true
	guard.set_mode("cycle")


func ending() -> void:
	player.cinematic = true
	player.hands.visible = false
	hud.letterbox(true)
	cell.set_poster_moved(true, false)
	_shot_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_shot_tween.tween_method(_cam_lerp.bind(Vector3(1.35, 1.45, 0.2), Vector3(2.0, 1.3, 0.2), Vector3(2.15, 1.3, 0.2), Vector3(3.6, 1.3, 0.2)), 0.0, 1.0, 3.2)
	await get_tree().create_timer(1.6).timeout
	hud.fade_to(1.0, 1.6, Color(1, 1, 1))
	await get_tree().create_timer(1.8).timeout
	hud.say("Le tunnel débouche derrière le mur d'enceinte.\nThéo court vers la forêt, sans se retourner.", 2.2)
	await get_tree().create_timer(5.0).timeout
	hud.letterbox(false)
	hud.clear_subtitle()
