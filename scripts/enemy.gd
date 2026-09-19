extends CharacterBody3D
## One script, two suburban menaces: the Lawn Gnome Rusher and the Mall Cop Brute.

signal died(enemy: Node3D)

@export_group("Stats")
@export var move_speed: float = 11.0
@export var max_health: int = 15
@export var melee_damage: int = 5
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0
## Anti-jam. A chase counts as blocked only when the enemy is touching world
## geometry AND is no closer to the player than its best-ever approach, so a
## player simply outrunning an enemy never trips it.
## First response is a sidestep; if that still fails, the enemy phases - it
## walks straight through the obstruction for `phase_duration` seconds.
## Without this, enemies wedge on fences and parked cars, stay alive forever,
## and the wave gate never opens.
@export var stuck_threshold: float = 0.4
@export var avoid_duration: float = 0.9
@export var phase_after: float = 2.5
@export var phase_duration: float = 1.2

@export_group("Look")
@export var body_scale: float = 0.6
@export var body_color: Color = Color(0.85, 0.15, 0.12)
@export var has_gnome_hat: bool = true
@export var hat_color: Color = Color(0.9, 0.1, 0.1)

@export_group("Audio")
@export var death_sound_path: String = "res://assets/audio/body_fall.wav"
@export var attack_sound_path: String = "res://assets/audio/ui_click.wav"

var health: int = 15

var _player: CharacterBody3D
var _attack_timer: float = 0.0
var _gravity: float = 9.8
var _body_material: StandardMaterial3D
var _flash_timer: float = 0.0
var _squash_tween: Tween
var _stuck_time: float = 0.0
var _avoid_timer: float = 0.0
var _phase_timer: float = 0.0
var _best_distance: float = INF
var _avoid_sign: float = 1.0

@onready var visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _enter_tree() -> void:
	add_to_group("enemies")


func _ready() -> void:
	health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	visual.scale = Vector3.ONE
	scale = Vector3.ONE
	_build_visual()
	_resize_collision()
	var found := get_tree().get_first_node_in_group("player")
	if found is CharacterBody3D:
		_player = found as CharacterBody3D
	_avoid_sign = 1.0 if randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_body_material.albedo_color = body_color
			_body_material.emission_energy_multiplier = 0.0

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _player == null or not is_instance_valid(_player):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	if distance > 0.25:
		var flat_target := Vector3(_player.global_position.x, global_position.y, _player.global_position.z)
		if global_position.distance_to(flat_target) > 0.05:
			look_at(flat_target, Vector3.UP)

	# Phasing: push straight through whatever is in the way, ignoring physics,
	# but keep the current height so we never drop through the ground.
	if _phase_timer > 0.0:
		_phase_timer -= delta
		var escape := to_player.normalized()
		global_position += Vector3(escape.x, 0.0, escape.z) * move_speed * delta
		velocity = Vector3.ZERO
		return

	if distance > attack_range:
		var dir := to_player.normalized()
		if _avoid_timer > 0.0:
			_avoid_timer -= delta
			var side := Vector3(-dir.z, 0.0, dir.x) * _avoid_sign
			dir = (dir * 0.25 + side).normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
		if _attack_timer <= 0.0:
			_attack()

	move_and_slide()
	_update_stuck_state(delta, distance)


func _update_stuck_state(delta: float, distance: float) -> void:
	if distance <= attack_range:
		_stuck_time = 0.0
		_best_distance = distance
		return

	if distance < _best_distance - 0.25:
		_best_distance = distance
		_stuck_time = 0.0
		return

	if not _is_blocked_by_world():
		_stuck_time = 0.0
		return

	_stuck_time += delta
	if _stuck_time > stuck_threshold and _avoid_timer <= 0.0:
		_avoid_timer = avoid_duration
	if _stuck_time > phase_after:
		_stuck_time = 0.0
		_avoid_timer = 0.0
		_phase_timer = phase_duration
		_best_distance = distance


## True when we are pressed against level geometry rather than the player.
func _is_blocked_by_world() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider == null:
			continue
		var node := collider as Node
		if node != null and not node.is_in_group("player"):
			return true
	return false


func _attack() -> void:
	_attack_timer = attack_cooldown
	if _player != null and _player.has_method("take_damage"):
		_player.call("take_damage", melee_damage)
	_lunge()
	_play_3d(attack_sound_path, 1.6 - body_scale * 0.4)


func _lunge() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector3(0.85, 1.25, 0.85), 0.08)
	_squash_tween.tween_property(visual, "scale", Vector3.ONE, 0.12)


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	_squash()
	_flash()
	if health <= 0:
		_die()


func _squash() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	visual.scale = Vector3(1.2, 0.8, 1.2)
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector3.ONE, 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash() -> void:
	_flash_timer = 0.07
	_body_material.albedo_color = Color.WHITE
	_body_material.emission_energy_multiplier = 1.5


func _die() -> void:
	health = 0
	_play_3d(death_sound_path, 1.5 - body_scale * 0.5)
	_spawn_confetti()
	died.emit(self)
	queue_free()


func _spawn_confetti() -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 1.2
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 65.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 9.0
	particles.gravity = Vector3(0.0, -9.0, 0.0)
	particles.scale_amount_min = 0.08
	particles.scale_amount_max = 0.18 * body_scale + 0.1
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.05, 0.1)
	particles.mesh = box

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.78, 0.09, 0.15))
	gradient.set_color(1, Color(0.05, 0.16, 0.45))
	gradient.add_point(0.5, Color.WHITE)
	particles.color_ramp = gradient

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particles.material_override = mat

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(particles)
	particles.global_position = global_position + Vector3(0.0, 1.0 * body_scale, 0.0)
	particles.emitting = true
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(particles.queue_free)


func _play_3d(path: String, pitch: float) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = stream
	sfx.pitch_scale = pitch
	sfx.unit_size = 10.0
	scene_root.add_child(sfx)
	sfx.global_position = global_position + Vector3(0.0, body_scale, 0.0)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


# --- Visuals ------------------------------------------------------------

func _resize_collision() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4 * body_scale
	capsule.height = 1.8 * body_scale
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0.0, 0.9 * body_scale, 0.0)


func _build_visual() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = body_color
	_body_material.emission_enabled = true
	_body_material.emission = Color.WHITE
	_body_material.emission_energy_multiplier = 0.0

	var body := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.4 * body_scale
	capsule_mesh.height = 1.8 * body_scale
	body.mesh = capsule_mesh
	body.material_override = _body_material
	body.position = Vector3(0.0, 0.9 * body_scale, 0.0)
	visual.add_child(body)

	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.98, 0.85, 0.72)
	var face := MeshInstance3D.new()
	var face_mesh := SphereMesh.new()
	face_mesh.radius = 0.22 * body_scale
	face_mesh.height = 0.44 * body_scale
	face.mesh = face_mesh
	face.material_override = face_mat
	face.position = Vector3(0.0, 1.35 * body_scale, -0.28 * body_scale)
	visual.add_child(face)

	if has_gnome_hat:
		var hat_mat := StandardMaterial3D.new()
		hat_mat.albedo_color = hat_color
		var hat := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.34 * body_scale
		cone.height = 0.9 * body_scale
		hat.mesh = cone
		hat.material_override = hat_mat
		hat.position = Vector3(0.0, 1.95 * body_scale, 0.0)
		visual.add_child(hat)

		var beard_mat := StandardMaterial3D.new()
		beard_mat.albedo_color = Color(0.95, 0.95, 0.95)
		var beard := MeshInstance3D.new()
		var beard_mesh := SphereMesh.new()
		beard_mesh.radius = 0.24 * body_scale
		beard_mesh.height = 0.5 * body_scale
		beard.mesh = beard_mesh
		beard.material_override = beard_mat
		beard.position = Vector3(0.0, 1.1 * body_scale, -0.3 * body_scale)
		visual.add_child(beard)
	else:
		var cap_mat := StandardMaterial3D.new()
		cap_mat.albedo_color = Color(0.06, 0.09, 0.25)
		var cap := MeshInstance3D.new()
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.26 * body_scale
		cap_mesh.bottom_radius = 0.3 * body_scale
		cap_mesh.height = 0.2 * body_scale
		cap.mesh = cap_mesh
		cap.material_override = cap_mat
		cap.position = Vector3(0.0, 1.62 * body_scale, 0.0)
		visual.add_child(cap)

		var brim := MeshInstance3D.new()
		var brim_mesh := BoxMesh.new()
		brim_mesh.size = Vector3(0.5, 0.06, 0.3) * body_scale
		brim.mesh = brim_mesh
		brim.material_override = cap_mat
		brim.position = Vector3(0.0, 1.56 * body_scale, -0.3 * body_scale)
		visual.add_child(brim)

		var badge_mat := StandardMaterial3D.new()
		badge_mat.albedo_color = Color(0.95, 0.8, 0.2)
		badge_mat.metallic = 0.8
		var badge := MeshInstance3D.new()
		var badge_mesh := BoxMesh.new()
		badge_mesh.size = Vector3(0.18, 0.18, 0.05) * body_scale
		badge.mesh = badge_mesh
		badge.material_override = badge_mat
		badge.position = Vector3(0.18 * body_scale, 1.15 * body_scale, -0.38 * body_scale)
		visual.add_child(badge)
