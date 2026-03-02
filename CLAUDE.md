# Velocity — Godot 4.6.1 Racing Game

## Project Overview
"Velocity" is a Forza-style 3D racing game built entirely in Godot 4.6.1 with GDScript. All geometry uses CSG primitives and procedural mesh generation (no imported 3D models). The full roadmap is in `plan.md`.

## Engine
- **Godot 4.6.1** installed at `/opt/homebrew/bin/godot`
- Run: `godot --path /Users/aidan/Code/racing-game`
- Headless validate: `godot --headless --path . --quit`
- Physics runs at **120Hz** (VehicleBody3D is unstable at 60Hz)

## Project Structure
```
autoloads/           # Singleton autoloads (InputManager, GameManager, RaceManager)
cars/
  car_data.gd        # CarData Resource class (physics, visuals, progression)
  car_base.gd/.tscn  # VehicleBody3D controller + scene
  player_car_controller.gd
  car_definitions/   # .tres car resources (starter_sedan.tres)
  car_meshes/        # Per-car procedural mesh generators (future)
tracks/
  track_data.gd      # TrackData Resource class
  components/        # checkpoint.gd (Area3D checkpoint gates)
  track_definitions/ # .tres track resources (oval_speedway.tres)
  track_scenes/      # Track scenes + scripts (oval_speedway.gd/.tscn)
scenes/race/         # race_scene (main), test_drive (Phase 1 test), race_camera
ui/                  # UI scenes (future: hud, menus, garage, etc.)
data/                # Data classes (future: PlayerProfile, RaceResult)
```

## Implementation Status
- **Phase 0:** Complete — project structure, project.godot, git
- **Phase 1:** Complete — car drives on flat plane (test_drive.tscn)
- **Phase 2:** Complete — oval speedway track with lap counting (race_scene.tscn)
- **Phases 3-8:** Not started (HUD, AI, menus, more tracks, split-screen, polish)

## Architecture

### Autoloads (load order matters)
1. **InputManager** — registers p1/p2 input actions via InputMap API using `physical_keycode`
2. **GameManager** — game state, selected car/track index, car/track path registry
3. **RaceManager** — race state machine (IDLE→PRE_RACE→COUNTDOWN→RACING→FINISHED), checkpoint validation, lap counting, timing

### Car System
- `CarData` Resource defines all physics/visual properties
- `car_base.tscn`: VehicleBody3D + 4 VehicleWheel3D + CollisionShape3D + BodyMesh
- `car_base.gd`: torque curve interpolation, aerodynamic drag/downforce, weight transfer, brake bias, 3-stage drift model, slipstream raycast, anti-flip, stuck detection
- `PlayerCarController`: reads InputManager, calls `car.set_inputs()`
- Controllers are added as child Nodes of the car (composition pattern)

### Track System
- `TrackData` Resource defines track metadata + scene_path
- `oval_speedway.gd`: procedurally generates all geometry in `_ready()`:
  - Road surface: ArrayMesh + SurfaceTool (128 segments around oval)
  - Road collision: ConcavePolygonShape3D from same vertex data
  - Barriers: ArrayMesh walls with backface collision
  - Checkpoints: Area3D gates (layer=0, mask=2) calling RaceManager
  - Environment: DirectionalLight3D, WorldEnvironment with procedural sky
- Track dimensions: R=80m turns, 350m straights, 16m road, 15° banking

### Race Flow
1. `race_scene.gd` loads track, spawns car at spawn point, sets up camera
2. RaceManager countdown: 3-2-1-GO (3 seconds)
3. Player drives; checkpoints validate laps (all intermediate CPs must be hit before start/finish counts)
4. After N laps → FINISHED state
5. Debug HUD shows: lap count, race time, best lap, speed, countdown overlay

### Collision Layers
| Layer | Name | Used by |
|-------|------|---------|
| 1 | Default | Ground, road, barriers |
| 2 | Cars | VehicleBody3D instances |
| 3 | Checkpoints | Checkpoint Area3D (mask=2, detects cars) |

## Godot 4.6.1 Gotchas
- `VehicleWheel3D.suspension_rest_length` renamed to `wheel_rest_length`
- `class_name` types can't be used as type annotations without editor cache — use `Resource` base type
- `:=` type inference fails on `Resource`-typed property access — use explicit `var x: float = ...`
- `Environment.TONE_MAP_ACES` doesn't exist — use integer values (0=Linear, 1=Reinhardt, 2=Filmic)
- `Node3D.look_at()` fails if node not in scene tree — compute Basis manually instead
- Sub-resources must appear before nodes in .tscn files
- `config/features=PackedStringArray("4.4")` is correct for 4.6.1 projects
- Use `physical_keycode` (not `keycode`) for InputEventKey to ensure reliable key matching
- VehicleBody3D `engine_force`: positive drives in **+Z** (not -Z), so negate for forward motion
- VehicleBody3D `steering`: also inverted relative to expectation, negate for correct left/right
- Set VehicleBody3D transform **before** `add_child()` — physics engine may ignore post-add transform changes

## Controls
- **WASD** — accelerate/brake/steer
- **Space** — handbrake
- **Q** — look back
- **R** — reset car position
- **ESC** — pause (future)

## Key Design Decisions
- **Hardcoded car/track paths** in GameManager (DirAccess doesn't work in exported builds)
- **ArrayMesh for track road** (not CSGPolygon3D) — avoids collision gaps at path seams
- **ConcavePolygonShape3D** with `backface_collision = true` for barriers
- **Procedural CSG car meshes** — two-tone paint, chrome grille, emissive headlights/taillights
- **Input registered in code** via InputMap API (not project.godot) for complex device ID handling
- **120Hz physics** for VehicleBody3D stability, lowered center_of_mass, anti-flip counter-torque
