# Velocity — Godot 4.6.1 Racing Game

## Project Overview
"Velocity" is a Forza-style 3D racing game built entirely in Godot 4.6.1 with GDScript. All geometry uses CSG primitives and procedural mesh generation (no imported 3D models). The visual design is a dark theme with neon accents (`#0A0E1A` bg, `#FF6B1A` orange, `#00D4FF` cyan). The full design spec is in `plan.md`.

## Engine
- **Godot 4.6.1**
  - macOS: `/opt/homebrew/bin/godot`
  - Windows: `C:/Godot/Godot_v4.6.1-stable_win64_console.exe`
- Run: `godot --path <project-dir>`
- Headless validate: `godot --headless --path . --quit`
- Physics runs at **120Hz** (VehicleBody3D is unstable at 60Hz)

## Project Structure
```
autoloads/
  input_manager.gd     # P1/P2 input registration via InputMap API
  game_manager.gd      # State, car/track registry, season system, scene transitions
  race_manager.gd      # Race state machine, checkpoint/lap/position tracking
  save_manager.gd      # JSON profile + ConfigFile settings persistence
cars/
  car_data.gd          # CarData Resource (physics, visuals, progression)
  car_base.gd/.tscn    # VehicleBody3D controller + scene
  player_car_controller.gd
  ai_car_controller.gd # Path-following AI with rubber-banding
  car_definitions/     # 42 .tres car resources across 4 modes
  car_meshes/          # Procedural mesh generators (sedan, coupe, muscle, f1, stock_car, buggy, trophy_truck)
tracks/
  track_data.gd        # TrackData Resource (metadata, scene_path, point-to-point flag)
  components/          # checkpoint.gd (Area3D gates)
  track_definitions/   # 14 .tres track resources
  track_scenes/        # 14 procedural track generators + scenes
scenes/
  main.tscn            # Entry point
  race/                # race_scene, split_screen_race, race_camera, test_drive
                       # countdown_overlay, results_screen (built in code)
ui/
  main_menu/           # Mode selector with 3D car preview turntable
  garage/              # Car browsing, stats bars, buy/select
  track_select/        # Track cards filtered by mode
  race_setup/          # Laps, AI count, difficulty config
  player_select/       # 1P vs 2P selection
  hud/                 # race_hud (position, lap, speed, minimap, throttle/brake bars)
  pause/               # Pause menu (resume/restart/main menu)
  settings/            # Volume, fullscreen, VSync
  season/              # Season setup (team/car pick) + standings table
data/
  player_profile.gd    # Credits, owned cars, race history
  race_result.gd       # Per-race statistics
```

## Architecture

### Autoloads (load order matters)
1. **InputManager** — registers p1/p2 input actions via InputMap API using `physical_keycode`
2. **SaveManager** — JSON profile persistence (`user://`), ConfigFile settings
3. **GameManager** — game state, car/track registry (42 cars, 14 tracks), season system, scene transitions with fade
4. **RaceManager** — race state machine (IDLE->PRE_RACE->COUNTDOWN->RACING->FINISHED), checkpoint validation, lap counting, position tracking, season result recording

### Car System
- `CarData` Resource defines physics (mass, torque curve, drag, downforce, brake bias, suspension, drift params) and visual properties (colors, dimensions, spoiler flags)
- `car_base.tscn`: VehicleBody3D + 4 VehicleWheel3D + CollisionShape3D + BodyMesh
- `car_base.gd`: torque curve interpolation, aerodynamic drag/downforce, weight transfer, brake bias, 3-stage drift model, slipstream raycast (20m range, 30% drag reduction), anti-flip, stuck detection
- `PlayerCarController`: reads InputManager, calls `car.set_inputs()`
- `AICarController`: path-following with look-ahead, 3 difficulty levels (EASY/MEDIUM/HARD), rubber-banding, stuck detection + reverse, lateral offset spread
- Controllers are added as child Nodes of the car (composition pattern)
- 7 procedural mesh types: sedan, coupe, muscle, f1, stock_car, buggy, trophy_truck

### Track System
- `TrackData` Resource defines track metadata + scene_path + `is_point_to_point` flag
- All tracks procedurally generate geometry in `_ready()`:
  - Road surface: ArrayMesh + SurfaceTool
  - Road collision: ConcavePolygonShape3D from same vertex data
  - Barriers: ArrayMesh walls with backface collision
  - Checkpoints: Area3D gates (layer=0, mask=2) calling RaceManager
  - AI Path: Path3D + Curve3D for AI navigation
  - Spawn transforms for grid positions
  - Environment: DirectionalLight3D, WorldEnvironment with procedural sky

### 14 Tracks
| # | Track | Mode | Type |
|---|-------|------|------|
| 0 | Oval Speedway | STREET | Circuit |
| 1 | Mountain Circuit | STREET | Circuit |
| 2 | City Streets | STREET | Circuit (night) |
| 3 | Monaco | F1 | Street circuit |
| 4 | Monza | F1 | High-speed |
| 5 | Spa | F1 | Classic |
| 6 | Silverstone | F1 | High-speed |
| 7 | Baja Canyon | BAJA | Point-to-point |
| 8 | Baja Desert | BAJA | Point-to-point |
| 9 | Baja Coastal | BAJA | Point-to-point |
| 10 | Airport Circuit | STREET | Short circuit |
| 11 | NASCAR Superspeedway | NASCAR | Oval |
| 12 | NASCAR Short Track | NASCAR | Short oval |
| 13 | NASCAR Intermediate | NASCAR | Oval |

### 42 Cars
- **STREET (0-7):** sedan, coupe, muscle + color variants (8 cars, 8 teams)
- **F1 (8-17):** F1 base + 9 color variants (10 teams x 2 drivers = 20 grid)
- **BAJA (18-25):** buggy, trophy truck, desert runner variants (8 entries)
- **NASCAR (26-41):** stock car base + 15 color variants (16 entries)

### Race Flow
1. `race_scene.gd` loads track, spawns player + AI cars at grid positions, sets up camera
2. RaceManager countdown: 3-2-1-GO (animated overlay)
3. Player drives; checkpoints validate laps (all intermediate CPs must be hit before start/finish counts)
4. Position tracked via progress score (laps x 1000 + checkpoints x 100 + track fraction x 10)
5. After N laps -> FINISHED state; 30s timeout for remaining finishers
6. Results screen: position, time, best lap, credits earned, confetti for 1st
7. If in season: points recorded, advance to next round or show final standings

### Season / Championship System
4 full seasons managed by GameManager:
- **GT Championship** (STREET): 8 rounds, GT points (20/17/15/...)
- **F1 World Championship**: 19 rounds, FIA points (25/18/15/...) + fastest lap bonus, team-based scoring
- **SCORE Desert Series** (BAJA): 5 rounds, high-point scoring (150/120/100/...)
- **NASCAR Cup Series**: 15 rounds, stock points (40/35/34/...) + win bonus

### Split-Screen Multiplayer
- `split_screen_race.gd`: two SubViewports sharing one World3D
- P1: WASD, P2: Arrow keys + Numpad
- Independent cameras and HUDs

### Collision Layers
| Layer | Name | Used by |
|-------|------|---------|
| 1 | Default | Ground, road, barriers |
| 2 | Cars | VehicleBody3D instances |
| 3 | Checkpoints | Checkpoint Area3D (mask=2, detects cars) |

### Point-to-Point Races
Baja tracks use `is_point_to_point = true` in TrackData. Key differences:
- RaceManager uses `finish_checkpoint_index` (last CP) instead of start/finish crossing
- Checkpoints 0..N-2 are intermediate; checkpoint N-1 = finish line
- AI controller uses `open_path = true` (clampf instead of fposmod, brakes near end)
- HUD shows "CP X/Y" instead of "LAP X/Y"; minimap polyline is open (not closed)

### F1-Specific Features
- DRS (Drag Reduction System): 50% drag reduction, available above 80 kph, full throttle activates
- F1-specific AI look-ahead tuning

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
- **ESC** — pause menu

## Key Design Decisions
- **Hardcoded car/track paths** in GameManager (DirAccess doesn't work in exported builds)
- **ArrayMesh for track roads** (not CSGPolygon3D) — avoids collision gaps at path seams
- **ConcavePolygonShape3D** with `backface_collision = true` for barriers
- **Procedural CSG car meshes** — two-tone paint, chrome grille, emissive headlights/taillights
- **Input registered in code** via InputMap API (not project.godot) for complex device ID handling
- **120Hz physics** for VehicleBody3D stability, lowered center_of_mass, anti-flip counter-torque
- **All UI built dynamically in GDScript** (no .tscn scene files for UI) with CanvasLayer overlays
- **Season state in GameManager** rather than a separate autoload — keeps season tightly coupled with race setup
