extends Node3D
## Runs the three-wave siege of Liberty Lane.

signal wave_started(wave_index: int, wave_total: int)
signal wave_cleared(wave_index: int)
signal arena_cleared()

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@export var wave_sizes: Array[int] = [5, 8, 12]
@export var spawn_interval: float = 0.6
@export var wave_pause: float = 2.5
@export var start_delay: float = 2.0
@export_range(0.0, 1.0) var gnome_ratio: float = 0.7
@export var spawn_ring_radius: float = 24.0
@export var spawn_point_count: int = 6
## Optional list of angles (radians) to place spawn markers at; when empty the
## markers are distributed evenly. main.gd fills this with the gaps between houses.
@export var custom_angles: Array[float] = []

@export_group("Lawn Gnome Rusher")
@export var gnome_speed: float = 11.0
@export var gnome_health: int = 15
@export var gnome_damage: int = 5
@export var gnome_scale: float = 0.6

@export_group("Mall Cop Brute")
@export var brute_speed: float = 4.0
@export var brute_health: int = 120
@export var brute_damage: int = 25
@export var brute_scale: float = 1.5

var current_wave: int = 0
var alive_enemies: int = 0

var _spawn_points: Array[Marker3D] = []
var _running: bool = false


func _ready() -> void:
	for child in get_children():
		if child is Marker3D:
			_spawn_points.append(child as Marker3D)
	if _spawn_points.is_empty():
		_create_default_spawn_points()


func start() -> void:
	if _running:
		return
	_running = true
	_run_waves()


func _create_default_spawn_points() -> void:
	var angles: Array[float] = custom_angles.duplicate()
	if angles.is_empty():
		for i in spawn_point_count:
			angles.append(TAU * float(i) / float(spawn_point_count))
	for i in angles.size():
		var marker := Marker3D.new()
		marker.name = "SpawnPoint%d" % (i + 1)
		var angle: float = angles[i]
		marker.position = Vector3(cos(angle) * spawn_ring_radius, 1.5, sin(angle) * spawn_ring_radius)
		add_child(marker)
		_spawn_points.append(marker)


func _run_waves() -> void:
	await get_tree().create_timer(start_delay).timeout
	for wave_index in wave_sizes.size():
		current_wave = wave_index + 1
		wave_started.emit(current_wave, wave_sizes.size())
		var count: int = wave_sizes[wave_index]
		for i in count:
			if not is_inside_tree():
				return
			_spawn_one()
			await get_tree().create_timer(spawn_interval).timeout
		while alive_enemies > 0:
			await get_tree().create_timer(0.25).timeout
			if not is_inside_tree():
				return
		wave_cleared.emit(current_wave)
		if wave_index < wave_sizes.size() - 1:
			await get_tree().create_timer(wave_pause).timeout
	arena_cleared.emit()


func _spawn_one() -> void:
	if _spawn_points.is_empty():
		return
	var marker: Marker3D = _spawn_points[randi() % _spawn_points.size()]
	var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
	if randf() < gnome_ratio:
		_configure_gnome(enemy)
	else:
		_configure_brute(enemy)
	enemy.connect("died", _on_enemy_died)
	get_tree().current_scene.add_child(enemy)
	var jitter := Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	enemy.global_position = marker.global_position + jitter
	alive_enemies += 1


func _configure_gnome(enemy: CharacterBody3D) -> void:
	enemy.set("move_speed", gnome_speed)
	enemy.set("max_health", gnome_health)
	enemy.set("melee_damage", gnome_damage)
	enemy.set("body_scale", gnome_scale)
	enemy.set("body_color", Color(0.85, 0.15, 0.12))
	enemy.set("has_gnome_hat", true)
	enemy.set("hat_color", Color(0.9, 0.1, 0.1))


func _configure_brute(enemy: CharacterBody3D) -> void:
	enemy.set("move_speed", brute_speed)
	enemy.set("max_health", brute_health)
	enemy.set("melee_damage", brute_damage)
	enemy.set("body_scale", brute_scale)
	enemy.set("body_color", Color(0.09, 0.14, 0.38))
	enemy.set("has_gnome_hat", false)


func _on_enemy_died(_enemy: Node3D) -> void:
	alive_enemies = maxi(alive_enemies - 1, 0)
