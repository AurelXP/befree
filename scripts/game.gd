extends Node
## État global du jeu BeFree (autoload "Game") : horloge, emploi du temps, progression.

signal phase_changed(phase: String, kind: String)
signal toast(text: String)
signal strike_added(n: int)
signal caught(reason: String)
signal game_over
signal escaped
signal state_reset

const MINUTES_PER_SEC: float = 2.0
const MAX_STRIKES: int = 3
const DIG_RATE: float = 1.4

## [minute de début, phase, type]
const SCHEDULE: Array = [
	[0, "night", ""],
	[330, "free", ""],
	[480, "meal", "breakfast"],
	[525, "free", ""],
	[570, "inspect", ""],
	[600, "free", ""],
	[630, "pee", ""],
	[670, "free", ""],
	[750, "meal", "lunch"],
	[795, "free", ""],
	[930, "pee", ""],
	[970, "free", ""],
	[1020, "inspect", ""],
	[1050, "free", ""],
	[1110, "meal", "dinner"],
	[1155, "free", ""],
	[1290, "night", ""],
]

var running: bool = false
var minutes: float = 450.0
var day: int = 1
var speed: float = 1.0
var phase: String = "free"
var kind: String = ""
var duty_done: bool = true

var strikes: int = 0
var dig: float = 0.0
var suspicion: float = 0.0
var has_spoon: bool = false
var spoon_equipped: bool = false
var poster_moved: bool = false
var digging: bool = false
var cake_given: bool = false

var _idx: int = -1


func reset() -> void:
	running = false
	minutes = 450.0
	day = 1
	speed = 1.0
	phase = "free"
	kind = ""
	duty_done = true
	strikes = 0
	dig = 0.0
	suspicion = 0.0
	has_spoon = false
	spoon_equipped = false
	poster_moved = false
	digging = false
	cake_given = false
	_idx = -1
	state_reset.emit()


func start() -> void:
	running = true
	_update_phase()


func is_night() -> bool:
	return phase == "night"


func time_string() -> String:
	var h: int = int(minutes) / 60
	var m: int = int(minutes) % 60
	return "%02d:%02d" % [h, m]


func add_strike() -> void:
	strikes += 1
	strike_added.emit(strikes)
	if strikes >= MAX_STRIKES:
		running = false
		game_over.emit()


func finish_duty() -> void:
	duty_done = true


func _process(delta: float) -> void:
	if not running:
		return
	minutes += delta * MINUTES_PER_SEC * speed
	if minutes >= 1440.0:
		minutes -= 1440.0
		day += 1
	_update_phase()


func _update_phase() -> void:
	var idx: int = 0
	for i in SCHEDULE.size():
		if minutes >= float(SCHEDULE[i][0]):
			idx = i
	if idx == _idx:
		return
	var first: bool = _idx == -1
	var prev_phase: String = phase
	var prev_done: bool = duty_done
	_idx = idx
	phase = SCHEDULE[idx][1]
	kind = SCHEDULE[idx][2]
	if not first and (prev_phase == "meal" or prev_phase == "pee") and not prev_done:
		caught.emit("duty")
	duty_done = not (phase == "meal" or phase == "pee")
	phase_changed.emit(phase, kind)
