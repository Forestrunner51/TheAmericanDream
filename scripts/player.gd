extends CharacterBody3D
## "The Patriot" - fast, slidey 90s-FPS movement plus the Liberty Scattergun.

signal health_changed(value: int)
signal damaged()
signal died()

@export_group("Movement")
@export var max_speed: float = 14.0
@export var ground_acceleration: float = 80.0
@export var air_acceleration: float = 25.0
@export var ground_friction: float = 10.0
@export var jump_velocity: float = 9.5

@export_group("Look")
@export var mouse_sensitivity: float = 0.0022
@export var pitch_limit_degrees: float = 89.0

@export_group("Health")
@export var max_health: int = 100

@export_group("Liberty Scattergun")
@export var pellet_count: int = 8
@export var spread_degrees: float = 6.0
@export var damage_per_pellet: int = 12
@export var fire_cooldown: float = 0.75
@export var weapon_range: float = 120.0
@export var camera_kick_degrees: float = 3.5
@export var camera_kick_recover: float = 0.18
@export var weapon_recoil_distance: float = 0.14
@export var muzzle_flash_time: float = 0.05

@export_group("Audio")
@export var shot_sound_path: String = "res://assets/audio/gunshot.wav"
@export var rack_sound_path: String = "res://assets/audio/hammer_cock.wav"
@export var flesh_hit_sound_path: String = "res://assets/audio/hit_flesh.wav"
@export var world_hit_sound_path: String = "res://assets/audio/ricochet.wav"
@export var hurt_sound_path: String = "res://assets/audio/hit_dirt.wav"

var health: int = 100
var _shoot_timer: float = 0.0
var _gravity: float = 9.8

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/ShotRay

var _weapon_root: Node3D
var _weapon_rest_position: Vector3 = Vector3(0.36, -0.28, -0.62)
var _muzzle_flash: MeshInstance3D
var _muzzle_light: OmniLight3D
var _muzzle_timer: float = 0.0
var _camera_tween: Tween
var _weapon_tween: Tween


func _enter_tree() -> void:
	add_to_group("player")


func _ready() -> void:
	health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	ray.enabled = false
	ray.add_exception(self)
	_build_weapon_model()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	health_changed.emit(health)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(
			head.rotation.x - motion.relative.y * mouse_sensitivity,
			-deg_to_rad(pitch_limit_degrees),
			deg_to_rad(pitch_limit_degrees)
		)
	elif event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)
	_muzzle_timer = maxf(_muzzle_timer - delta, 0.0)
	if _muzzle_timer <= 0.0 and _muzzle_flash.visible:
		_muzzle_flash.visible = false
		_muzzle_light.visible = false

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_pressed("jump"):
		velocity.y = jump_velocity

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var accel := ground_acceleration if is_on_floor() else air_acceleration

	if wish_dir.length_squared() > 0.0:
		horizontal = horizontal.move_toward(wish_dir * max_speed, accel * delta)
	elif is_on_floor():
		horizontal = horizontal.move_toward(Vector3.ZERO, ground_friction * max_speed * delta * 0.5)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	if Input.is_action_pressed("shoot") and _shoot_timer <= 0.0 \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_shoot()


# --- Shooting -----------------------------------------------------------

func _shoot() -> void:
	_shoot_timer = fire_cooldown
	for i in pellet_count:
		_fire_pellet()
	_camera_kick()
	_weapon_recoil()
	_show_muzzle_flash()
	_play_sound("ShootSound")
	_play_2d(shot_sound_path, randf_range(0.92, 1.08))
	_rack_after_shot()


func _fire_pellet() -> void:
	var angle := deg_to_rad(spread_degrees) * sqrt(randf())
	var roll := randf() * TAU
	var local_dir := Vector3(sin(angle) * cos(roll), sin(angle) * sin(roll), -cos(angle))
	ray.target_position = local_dir * weapon_range
	ray.force_raycast_update()
	if not ray.is_colliding():
		return
	var point := ray.get_collision_point()
	var normal := ray.get_collision_normal()
	var collider := ray.get_collider()
	if collider != null and collider.has_method("take_damage"):
		collider.call("take_damage", damage_per_pellet)
		if randf() < 0.3:
			_play_3d(flesh_hit_sound_path, point)
	elif randf() < 0.25:
		_play_3d(world_hit_sound_path, point)
	_spawn_impact(point, normal)


func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 6
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 40.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0.0, -12.0, 0.0)
	particles.scale_amount_min = 0.06
	particles.scale_amount_max = 0.12
	particles.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.2)
	particles.material_override = mat
	get_tree().current_scene.add_child(particles)
	particles.global_position = point + normal * 0.05
	particles.emitting = true
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(particles.queue_free)


func _camera_kick() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	camera.rotation.x = deg_to_rad(camera_kick_degrees)
	_camera_tween = create_tween()
	_camera_tween.tween_property(camera, "rotation:x", 0.0, camera_kick_recover) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _weapon_recoil() -> void:
	if _weapon_tween != null and _weapon_tween.is_valid():
		_weapon_tween.kill()
	_weapon_root.position = _weapon_rest_position + Vector3(0.0, 0.02, weapon_recoil_distance)
	_weapon_tween = create_tween()
	_weapon_tween.tween_property(_weapon_root, "position", _weapon_rest_position, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_muzzle_flash() -> void:
	_muzzle_timer = muzzle_flash_time
	_muzzle_flash.visible = true
	_muzzle_light.visible = true


# --- Damage -------------------------------------------------------------

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health)
	damaged.emit()
	_play_sound("HurtSound")
	_play_2d(hurt_sound_path, randf_range(0.85, 1.0))
	if health <= 0:
		_die()


func _die() -> void:
	died.emit()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().call_deferred("reload_current_scene")


func _rack_after_shot() -> void:
	var delay := get_tree().create_timer(minf(fire_cooldown * 0.45, 0.4))
	delay.timeout.connect(_on_rack_timeout)


func _on_rack_timeout() -> void:
	_play_2d(rack_sound_path, 1.0)


func _play_2d(path: String, pitch: float) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.pitch_scale = pitch
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _play_3d(path: String, at: Vector3) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = stream
	sfx.unit_size = 12.0
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(sfx)
	sfx.global_position = at
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _load_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res := load(path)
	return res as AudioStream


func _play_sound(node_name: String) -> void:
	var node := get_node_or_null(NodePath(node_name))
	if node is AudioStreamPlayer:
		(node as AudioStreamPlayer).play()
	elif node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).play()


# --- Weapon model -------------------------------------------------------

func _build_weapon_model() -> void:
	_weapon_root = Node3D.new()
	_weapon_root.name = "WeaponModel"
	camera.add_child(_weapon_root)
	_weapon_root.position = _weapon_rest_position
	_weapon_root.rotation_degrees = Vector3(0.0, -4.0, 0.0)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.2, 0.08)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.12, 0.14)
	metal.metallic = 0.7
	metal.roughness = 0.35
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.8, 0.62, 0.15)
	brass.metallic = 0.8
	brass.roughness = 0.3

	_add_weapon_box(wood, Vector3(0.09, 0.1, 0.34), Vector3(0.0, -0.02, 0.18))
	_add_weapon_box(wood, Vector3(0.07, 0.16, 0.12), Vector3(0.0, -0.09, 0.32))
	_add_weapon_box(brass, Vector3(0.1, 0.09, 0.08), Vector3(0.0, -0.01, 0.02))

	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.032
	barrel_mesh.bottom_radius = 0.036
	barrel_mesh.height = 0.5
	barrel.mesh = barrel_mesh
	barrel.material_override = metal
	barrel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	barrel.position = Vector3(-0.022, 0.01, -0.24)
	_weapon_root.add_child(barrel)

	var barrel2 := barrel.duplicate() as MeshInstance3D
	barrel2.position = Vector3(0.022, 0.01, -0.24)
	_weapon_root.add_child(barrel2)

	_muzzle_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.09
	flash_mesh.height = 0.18
	_muzzle_flash.mesh = flash_mesh
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.5)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.8, 0.3)
	flash_mat.emission_energy_multiplier = 6.0
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_muzzle_flash.material_override = flash_mat
	_muzzle_flash.position = Vector3(0.0, 0.01, -0.5)
	_muzzle_flash.visible = false
	_weapon_root.add_child(_muzzle_flash)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.85, 0.5)
	_muzzle_light.light_energy = 4.0
	_muzzle_light.omni_range = 6.0
	_muzzle_light.position = Vector3(0.0, 0.01, -0.55)
	_muzzle_light.visible = false
	_weapon_root.add_child(_muzzle_light)


func _add_weapon_box(mat: StandardMaterial3D, size: Vector3, pos: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	_weapon_root.add_child(mesh_instance)
