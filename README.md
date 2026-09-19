# The American Dream — *Liberty Lane Cul-de-sac*

A vertical slice of a fast, satirical, 90s-style boomer shooter built in **Godot 4.8**.
One arena, one weapon, two enemy types, three waves.

> Tone note: this is cartoon suburbia — lawn gnomes and mall cops, a 1950s
> Sunday-circular gone wrong. It isn't aimed at any real group.

---

## Running it

1. Open `project.godot` in Godot 4.2+ (developed and verified on **4.8.dev3**).
2. Let the editor finish importing `assets/` on first open (a few seconds).
3. Press **F5** / Play. The main scene is already set to `res://scenes/main.tscn`.

The mouse is captured on start. **Esc** releases it; **click** recaptures.

## Controls

| Action | Key |
|---|---|
| Move | `W` `A` `S` `D` |
| Jump | `Space` (hold to bunny-hop) |
| Fire the Liberty Scattergun | Left Mouse |
| Release / recapture mouse | `Esc` / Left Mouse |

Movement is deliberately quick: 14 m/s top speed, high ground acceleration and
low air acceleration, so **air-strafing works** — hold a direction in the air and
swing the mouse to carry speed around corners.

---

## What's in the box

```
project.godot            main scene, InputSetup autoload, gravity
scenes/main.tscn         empty Node3D + main.gd (arena is built in code)
scenes/player.tscn       CharacterBody3D, Head, Camera3D, ShotRay
scenes/enemy.tscn        CharacterBody3D, CollisionShape3D, Visual
scripts/main.gd          arena, lighting, environment, HUD + wave wiring
scripts/player.gd        movement, mouse look, shotgun, game feel, health
scripts/enemy.gd         both enemy variants, driven by @export stats
scripts/spawner.gd       spawn markers, three waves, alive-enemy tracking
scripts/hud.gd           health, crosshair, wave counter, banner, damage flash
scripts/input_setup.gd   autoload that guarantees the input actions exist
assets/                  third-party art/audio (see "Assets" below)
```

The arena and the HUD are both **built in `_ready()` from code** rather than
hand-authored `.tscn` files. That keeps the scene files tiny and unbreakable, and
means every piece of the layout is a tunable number in one place.

### Enemies

| Enemy | Speed | Health | Melee | Look |
|---|---|---|---|---|
| Lawn Gnome Rusher | 11 | 15 | 5 | 0.6 scale, red body, pointy red hat, white beard |
| Mall Cop Brute | 4 | 120 | 25 | 1.5 scale, navy body, peaked cap and gold badge |

Both come from the same `enemy.gd`; the spawner configures the exports at spawn
time (~70% gnomes, ~30% mall cops).

Enemies sit on **collision layer 2** and mask only layer 1, so they walk through
each other instead of jamming up.

They also have a two-stage anti-jam, because without it they wedge themselves on
fences and parked cars, never die, and the wave gate never opens:

1. A chase counts as *blocked* only when the enemy is touching level geometry
   **and** is no closer to the player than its best-ever approach — so a player
   simply outrunning an enemy never trips it.
2. After `stuck_threshold` seconds blocked, it sidesteps for `avoid_duration`.
   If it is still blocked at `phase_after`, it **phases**: for `phase_duration`
   seconds it walks straight through the obstruction, ignoring physics but
   holding its current height so it can't drop through the ground.

### Waves

`[5, 8, 12]`, 0.6 s between spawns, 2.5 s between waves. The next wave will not
start until every enemy of the current one has been spawned **and** killed.
After wave 3, `arena_cleared` fires and the banner reads `CUL-DE-SAC LIBERATED!`.

---

## Assets

Almost everything visual and audible is third-party, pulled from `~/Games/assets`
and `~/Games/TheDuel`. Licenses are copied into `assets/licenses/`.

| Used for | Source |
|---|---|
| Houses, fences, paths, driveways, trees, planters | Kenney *City Kit (Suburban)* — CC0 |
| Parked cars, police cruisers, garbage truck, cones, crates | Kenney *Car Kit* — CC0 |
| Crosshair | Kenney *Game Icons* (`target.png`) — CC0 |
| HUD panels | Kenney *UI Pack: Adventure* (`panel_brown`) — CC0 |
| HUD font | Kenney *Future* — CC0 |
| Gunshot, pump, ricochet, flesh/dirt impacts, body fall, victory | `~/Games/TheDuel/dualliste/assets/audio` |

Kenney's suburban kit is modelled at roughly 1/8 scale and the car kit at
roughly 1/1.6, so `main.gd` exposes `building_scale`, `fence_scale`,
`prop_scale` and `car_scale` to bring them into a shared metric scale. The GLBs
reference `Textures/colormap.png` as an external file — that folder must stay
next to the models or every model imports untextured.

Models ship without collision, so `main.gd` calls `create_trimesh_collision()`
on each imported `MeshInstance3D`.

### Assets still to buy or commission

These are the pieces nothing in `~/Games` covered, so they're placeholder
geometry or placeholder audio right now:

1. **Enemy characters** — the biggest gap. Both enemies are capsules, cones and
   spheres assembled in `enemy.gd`. Needs two rigged, animated low-poly
   characters (idle / run / melee / death) — a garden gnome and a heavyset
   security guard. The one humanoid pack on disk (*Free Medieval 3D People*) is
   the wrong theme and FBX-only, which Godot can't import without FBX2glTF.
2. **First-person weapon model** — the Liberty Scattergun is boxes and cylinders
   in `player.gd::_build_weapon_model()`. Needs a double-barrel shotgun
   viewmodel with fire, pump and idle-sway animations.
3. **Sound effects** — the `TheDuel` WAVs are reused as placeholders and appear
   to be synthesized rather than recorded. Needs a real set: shotgun fire, shell
   pump, enemy hurt/death vocals, player hurt, footsteps, wave-start sting.
4. **Music / ambience** — none at all. Needs a suburban daytime ambience loop
   plus a combat track and a victory sting.
5. **Ground and road materials** — the grass, asphalt, sidewalk, road stripes and
   boundary walls are flat-coloured CSG. Kenney's path pieces are far too small
   to tile a 60 m arena. Needs a tiling grass/asphalt/concrete material set, or
   modular road and kerb pieces at building scale.
6. **The flag and flagpole** — stacked coloured boxes. Needs a proper flag mesh
   (ideally cloth-simulated or animated) and pole.
7. **VFX** — muzzle flash, pellet impacts and the death confetti are untextured
   particle boxes. Needs flash, spark, smoke and confetti sprite sheets.
8. **Skybox** — currently `ProceduralSkyMaterial`. A painted afternoon-suburbia
   cubemap would lift it a lot.

---

## Values worth tuning first

Everything below is an `@export`, editable in the Inspector without touching code.

**Game feel — `scripts/player.gd`**

| Variable | Default | Effect |
|---|---|---|
| `max_speed` | 14.0 | Top running speed. The single biggest feel knob. |
| `ground_acceleration` | 80.0 | How instantly you reach top speed. |
| `air_acceleration` | 25.0 | Air-strafe authority. Raise for more Quake, lower for more Doom. |
| `jump_velocity` | 9.5 | Paired with gravity 22 in `project.godot`. |
| `fire_cooldown` | 0.75 | Shotgun rhythm. |
| `damage_per_pellet` / `pellet_count` | 12 / 8 | 96 damage on a point-blank full hit. |
| `spread_degrees` | 6.0 | Lower = sniper, higher = must-hug-them. |
| `camera_kick_degrees` | 3.5 | Punch on fire. |
| `mouse_sensitivity` | 0.0022 | |

**Difficulty — `scripts/spawner.gd`**: `wave_sizes`, `spawn_interval`,
`wave_pause`, `gnome_ratio`, and the per-variant speed/health/damage exports.

**Layout — `scripts/main.gd`**: `arena_size`, `culdesac_radius`,
`house_ring_radius`, `spawn_ring_radius`, plus the four asset-scale values.

---

## Next steps

1. **The Telemarketer** — a ranged third enemy that stops at 12 m and lobs slow,
   dodgeable projectiles (rolled-up magazines), forcing you to keep moving
   instead of circle-strafing one target. `enemy.gd` already has the stat-driven
   structure to hang a `ranged_attack` mode off.
2. **Pickups** — health (a casserole dish) and shells dropped by mall cops, on
   `Area3D` triggers around the cul-de-sac. Gives the arena a reason to move you
   through its cover instead of camping the flagpole.
3. **A second weapon** — a rapid-fire "Leaf Blower" with weapon switching on
   `1`/`2` and mouse wheel, to contrast the Scattergun's slow, heavy rhythm.
