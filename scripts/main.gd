extends Node3D
## "Liberty Lane Cul-de-sac" - arena, lighting, HUD and wave flow are assembled
## at runtime from Kenney's suburban + car kits, so there are no fragile scene
## files to rot. Ground/road/flag geometry is CSG because no kit covers it.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const SPAWNER_SCRIPT := preload("res://scripts/spawner.gd")

const SUBURB := "res://assets/suburban/"
const CARS := "res://assets/cars/"

@export_group("Arena")
@export var arena_size: float = 60.0
@export var culdesac_radius: float = 12.0
@export var wall_height: float = 9.0
@export var house_ring_radius: float = 22.0
@export var spawn_ring_radius: float = 25.0

@export_group("Asset scale")
## Kenney's suburban kit is built at roughly 1/8 scale, the car kit at 1/1.6.
@export var building_scale: float = 8.0
@export var fence_scale: float = 4.0
@export var prop_scale: float = 8.0
@export var car_scale: float = 1.6

@export_group("Colors")
@export var grass_color: Color = Color(0.32, 0.56, 0.24)
@export var asphalt_color: Color = Color(0.17, 0.17, 0.19)
@export var sidewalk_color: Color = Color(0.72, 0.72, 0.68)
@export var wall_color: Color = Color(0.4, 0.5, 0.33)

const HOUSE_MODELS: Array[String] = [
	"building-type-a.glb",
	"building-type-e.glb",
	"building-type-c.glb",
	"building-type-g.glb",
	"building-type-b.glb",
]

var player: CharacterBody3D
var hud: CanvasLayer
var spawner: Node3D

var _arena: Node3D
var _house_angles: Array[float] = []


func _ready() -> void:
	randomize()
	_build_environment()
	_build_arena()
	_build_hud()
	_build_player()
	_build_spawner()
	hud.call("show_banner", "LIBERTY LANE", 1.6)
	spawner.call("start")


# --- Environment --------------------------------------------------------

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.18, 0.45, 0.88)
	sky_material.sky_horizon_color = Color(0.74, 0.86, 0.98)
	sky_material.ground_bottom_color = Color(0.28, 0.4, 0.22)
	sky_material.ground_horizon_color = Color(0.7, 0.82, 0.95)
	sky_material.sun_angle_max = 16.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.84, 0.94)
	env.fog_density = 0.0016
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.97, 0.88)
	sun.shadow_enabled = true
	add_child(sun)


# --- Arena --------------------------------------------------------------

func _build_arena() -> void:
	_arena = Node3D.new()
	_arena.name = "Arena"
	add_child(_arena)

	_ground()
	_walls()
	_flagpole()
	_houses()
	_props()


func _ground() -> void:
	_box(grass_color, Vector3(arena_size, 1.0, arena_size), Vector3(0.0, -0.5, 0.0), true, "Grass")

	var sidewalk := _cylinder(sidewalk_color, culdesac_radius + 2.0, 0.24, Vector3(0.0, 0.01, 0.0), false)
	sidewalk.name = "Sidewalk"
	var asphalt := _cylinder(asphalt_color, culdesac_radius, 0.3, Vector3(0.0, 0.06, 0.0), false)
	asphalt.name = "Asphalt"

	var road := _box(asphalt_color, Vector3(9.0, 0.3, arena_size * 0.5), Vector3.ZERO, false, "Road")
	road.position = Vector3(0.0, 0.06, arena_size * 0.25 - 2.0)

	var stripe_color := Color(0.92, 0.8, 0.2)
	for i in 6:
		_box(stripe_color, Vector3(0.4, 0.1, 2.2),
			Vector3(0.0, 0.22, float(i) * 4.5 + culdesac_radius), false, "Stripe%d" % i)


func _walls() -> void:
	var half := arena_size * 0.5
	var t := 1.0
	_box(wall_color, Vector3(arena_size + t * 2.0, wall_height, t), Vector3(0.0, wall_height * 0.5, -half), true, "WallNorth")
	_box(wall_color, Vector3(arena_size + t * 2.0, wall_height, t), Vector3(0.0, wall_height * 0.5, half), true, "WallSouth")
	_box(wall_color, Vector3(t, wall_height, arena_size + t * 2.0), Vector3(-half, wall_height * 0.5, 0.0), true, "WallWest")
	_box(wall_color, Vector3(t, wall_height, arena_size + t * 2.0), Vector3(half, wall_height * 0.5, 0.0), true, "WallEast")


func _flagpole() -> void:
	var pole := _cylinder(Color(0.86, 0.86, 0.88), 0.16, 14.0, Vector3(0.0, 7.0, 0.0), true)
	pole.name = "Flagpole"
	var pole_base := _cylinder(Color(0.6, 0.6, 0.62), 1.4, 0.6, Vector3(0.0, 0.3, 0.0), true)
	pole_base.name = "FlagpoleBase"

	var flag := Node3D.new()
	flag.name = "Flag"
	_arena.add_child(flag)
	flag.position = Vector3(1.85, 12.2, 0.0)

	var stripe_colors: Array[Color] = [Color(0.78, 0.09, 0.15), Color(0.97, 0.97, 0.97)]
	for i in 6:
		var stripe := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.4, 0.32, 0.08)
		stripe.mesh = mesh
		stripe.material_override = _material(stripe_colors[i % 2])
		stripe.position = Vector3(0.0, -float(i) * 0.32, 0.0)
		flag.add_child(stripe)

	var canton := MeshInstance3D.new()
	var canton_mesh := BoxMesh.new()
	canton_mesh.size = Vector3(1.4, 1.0, 0.12)
	canton.mesh = canton_mesh
	canton.material_override = _material(Color(0.05, 0.16, 0.45))
	canton.position = Vector3(-1.0, -0.48, 0.0)
	flag.add_child(canton)


func _houses() -> void:
	var count := HOUSE_MODELS.size()
	for i in count:
		var angle := TAU * float(i) / float(count) + 0.4
		_house_angles.append(angle)
		var origin := Vector3(cos(angle) * house_ring_radius, 0.0, sin(angle) * house_ring_radius)
		var yaw := -angle + PI * 0.5

		var house := _model(SUBURB + HOUSE_MODELS[i], origin, yaw, building_scale, true)
		house.name = "House%d" % (i + 1)

		var lot := Node3D.new()
		lot.name = "Lot%d" % (i + 1)
		_arena.add_child(lot)
		lot.position = origin
		lot.rotation.y = yaw

		# Walkway + picket fence facing the cul-de-sac (house local -Z).
		_child_model(lot, SUBURB + "path-long.glb", Vector3(0.0, 0.02, -6.5), 0.0, prop_scale, false)
		_child_model(lot, SUBURB + "path-short.glb", Vector3(0.0, 0.02, -9.0), 0.0, prop_scale, false)
		_child_model(lot, SUBURB + "driveway-long.glb", Vector3(5.5, 0.02, -7.5), 0.0, prop_scale, false)
		# Short picket runs flanking the walkway. Deliberately NOT a continuous
		# barrier: enemies need open lanes from the spawn ring to the circle.
		for side: float in [-1.0, 1.0]:
			_child_model(lot, SUBURB + "fence-1x4.glb",
				Vector3(side * 7.0, 0.0, -5.5), 0.0, fence_scale, true)
		_child_model(lot, SUBURB + "tree-large.glb", Vector3(-5.6, 0.0, -2.5), randf() * TAU, prop_scale, true)
		_child_model(lot, SUBURB + "tree-small.glb", Vector3(5.6, 0.0, -2.5), randf() * TAU, prop_scale, true)
		_child_model(lot, SUBURB + "planter.glb", Vector3(-3.4, 0.0, -3.6), 0.0, prop_scale, true)


func _props() -> void:
	# Cars parked around the circle, nosed toward the houses.
	var parked: Array[String] = ["sedan.glb", "suv.glb", "van.glb", "taxi.glb", "truck.glb"]
	for i in parked.size():
		var angle := TAU * float(i) / float(parked.size()) + 1.0
		var pos := Vector3(cos(angle) * (culdesac_radius - 2.6), 0.0, sin(angle) * (culdesac_radius - 2.6))
		_model(CARS + parked[i], pos, -angle, car_scale, true)

	# The Mall Cop motor pool, parked at the mouth of the road.
	_model(CARS + "police.glb", Vector3(-3.4, 0.0, 17.0), PI, car_scale, true)
	_model(CARS + "police.glb", Vector3(3.4, 0.0, 20.0), PI, car_scale, true)
	_model(CARS + "garbage-truck.glb", Vector3(-11.0, 0.0, 13.0), 1.2, car_scale, true)
	_model(CARS + "delivery.glb", Vector3(12.0, 0.0, -14.0), 2.2, car_scale, true)

	# Cover: cones and crates scattered over the asphalt.
	for i in 10:
		var angle := randf() * TAU
		var radius := randf_range(3.5, culdesac_radius - 1.0)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var model := CARS + ("cone.glb" if i % 3 != 0 else "box.glb")
		_model(model, pos, randf() * TAU, car_scale, i % 3 == 0)

	for i in 6:
		var angle := randf() * TAU
		var radius := randf_range(culdesac_radius + 4.0, house_ring_radius - 5.0)
		_model(SUBURB + "tree-small.glb",
			Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), randf() * TAU, prop_scale, true)


# --- Player, HUD, waves -------------------------------------------------

func _build_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0.0, 1.2, culdesac_radius - 1.5)
	player.rotation.y = 0.0
	player.connect("health_changed", _on_player_health_changed)
	player.connect("damaged", _on_player_damaged)
	hud.call("set_health", player.get("health"))


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(HUD_SCRIPT)
	add_child(hud)


func _build_spawner() -> void:
	spawner = Node3D.new()
	spawner.name = "Spawner"
	spawner.set_script(SPAWNER_SCRIPT)
	spawner.set("spawn_ring_radius", spawn_ring_radius)
	# Spawn in the lanes between houses so enemies get a clear run at the player.
	# This must happen before add_child(), because markers are built in _ready().
	var offsets: Array[float] = []
	var step := TAU / float(maxi(_house_angles.size(), 1))
	for angle: float in _house_angles:
		offsets.append(angle + step * 0.5)
	spawner.set("custom_angles", offsets)
	add_child(spawner)
	spawner.connect("wave_started", _on_wave_started)
	spawner.connect("arena_cleared", _on_arena_cleared)


func _on_player_health_changed(value: int) -> void:
	hud.call("set_health", value)


func _on_player_damaged() -> void:
	hud.call("flash_damage")


func _on_wave_started(index: int, total: int) -> void:
	hud.call("set_wave", index, total)
	hud.call("show_banner", "WAVE %d" % index, 1.2)


func _on_arena_cleared() -> void:
	hud.call("show_banner", "CUL-DE-SAC LIBERATED!", 6.0)
	_play_stream("res://assets/audio/victory.wav")


func _play_stream(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path)
	if stream == null:
		return
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


# --- Model + primitive helpers -----------------------------------------

func _model(path: String, pos: Vector3, yaw: float, model_scale: float, collide: bool) -> Node3D:
	return _child_model(_arena, path, pos, yaw, model_scale, collide)


func _child_model(parent: Node3D, path: String, pos: Vector3, yaw: float,
		model_scale: float, collide: bool) -> Node3D:
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = yaw
	holder.scale = Vector3.ONE * model_scale

	if not ResourceLoader.exists(path):
		push_warning("Missing model: %s" % path)
		return holder
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Model is not a scene: %s" % path)
		return holder
	var instance := packed.instantiate()
	holder.add_child(instance)
	if collide:
		_add_collision(instance)
	return holder


func _add_collision(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).create_trimesh_collision()
	for child in node.get_children():
		if child is StaticBody3D:
			continue
		_add_collision(child)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _box(color: Color, size: Vector3, pos: Vector3, collide: bool, node_name: String) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = node_name
	box.size = size
	box.material = _material(color)
	box.use_collision = collide
	_arena.add_child(box)
	box.position = pos
	return box


func _cylinder(color: Color, radius: float, height: float, pos: Vector3, collide: bool) -> CSGCylinder3D:
	var cyl := CSGCylinder3D.new()
	cyl.radius = radius
	cyl.height = height
	cyl.sides = 24
	cyl.material = _material(color)
	cyl.use_collision = collide
	_arena.add_child(cyl)
	cyl.position = pos
	return cyl
