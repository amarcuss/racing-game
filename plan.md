# Forza-Style 3D Racing Game — Godot 4.6.1

## Context
Building a full-featured 3D racing game from scratch in an empty directory. Godot 4.6.1 is installed at `/opt/homebrew/bin/godot`. Since we can't import commercial 3D models, all geometry uses CSG primitives and procedural mesh generation. The game needs multiple tracks, car garage, AI opponents, split-screen multiplayer, and a progression system.

## Visual Design System

### Color Palette
Primary dark theme inspired by Forza Horizon's UI — high contrast with neon accents on dark backgrounds.

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| Background Dark | Near-black blue | `#0A0E1A` | Menu backgrounds, panels |
| Background Mid | Dark slate | `#141B2D` | Cards, secondary panels |
| Surface | Charcoal blue | `#1E2740` | Buttons, input fields |
| Primary Accent | Electric orange | `#FF6B1A` | Selected items, speed, highlights |
| Secondary Accent | Cyan blue | `#00D4FF` | Position indicator, lap info, links |
| Success | Lime green | `#7FFF00` | "GO!", unlocked items, checkmarks |
| Warning/Credits | Gold | `#FFD700` | Credits display, star ratings |
| Danger/Brake | Hot red | `#FF2244` | Brake indicator, locked items |
| Text Primary | White | `#F0F0F0` | Headers, speed numbers |
| Text Secondary | Silver gray | `#8899AA` | Descriptions, labels |

### Typography (using Godot built-in fonts, sized for impact)
- **Title/Logo:** 72px bold, letter-spacing 8px, uppercase — `"VELOCITY"` (game title)
- **HUD Speed:** 96px bold monospace — massive, bottom-right, with km/h in 24px below
- **HUD Labels:** 28px bold uppercase — "LAP 2/3", "1ST", "01:23.456"
- **Menu Headers:** 48px bold — "GARAGE", "SELECT TRACK"
- **Button Text:** 22px bold uppercase with 4px letter-spacing
- **Body/Descriptions:** 18px regular — car descriptions, settings labels

### UI Component Styles
- **Buttons:** Rounded corners (8px), `Surface` bg, `Primary Accent` left border (4px) on hover, subtle scale animation (1.0 → 1.02) on hover, `Primary Accent` bg when selected
- **Cards (car/track):** `Background Mid` bg, 1px `Surface` border, left accent stripe on selection, hover glow (outer shadow in accent color), 12px padding
- **Panels:** `Background Dark` with subtle radial gradient from center (slightly lighter), 0.85 opacity for overlay panels
- **Progress Bars (car stats):** Rounded, `Surface` track bg, gradient fill from `Secondary Accent` to `Primary Accent` based on value
- **Sliders (settings):** Custom handle (circle, `Primary Accent`), track in `Surface`

### HUD Design
```
┌─────────────────────────────────────────────────────┐
│  [1ST]  ·  LAP 2/3  ·  01:23.456                   │  ← top bar, semi-transparent dark strip
│                                                     │
│                                                     │
│                                            ┌──────┐ │
│                                 [MINIMAP]  │      │ │  ← top-right corner
│                                            └──────┘ │
│                                                     │
│                                                     │
│                                                     │
│                                           ┌───────┐ │
│                                           │  187  │ │  ← large speed number
│                                           │ km/h  │ │
│                                           │ ───── │ │  ← thin orange bar = throttle
│                                           │ ───── │ │  ← thin red bar = brake
│                                           └───────┘ │
└─────────────────────────────────────────────────────┘
```
- **Speed display:** Large 96px number in white, "km/h" in small text below, thin horizontal bars showing throttle (orange) and brake (red) input levels — gives visual feedback like a telemetry display
- **Position:** "1ST" in massive bold text with `Secondary Accent` color, pulsing glow animation when position changes
- **Lap counter:** "LAP 2/3" in `Text Primary`, current lap highlighted in `Primary Accent`
- **Timer:** Monospace digits, milliseconds visible, current lap time + best lap time below in smaller text
- **Top bar:** Semi-transparent `#0A0E1A` at 70% opacity, horizontal strip across top

### Countdown Design
- Numbers "3", "2", "1" appear center-screen at 200px, zoom-in + fade-out animation (scale 0.5→1.5, alpha 1.0→0.0 over 0.8s)
- Each number in `Text Primary` with thick outline
- "GO!" appears in `Success` green at 250px, with screen flash effect (full white overlay at 30% alpha fading to 0 over 0.3s)

### Results Screen Design
- Dark overlay slides up from bottom (0.5s ease-out)
- Position shown huge center-top: "1ST" / "2ND" etc in gradient text (gold for 1st, silver for 2nd, bronze for 3rd)
- 1st place gets particle confetti effect (GPUParticles2D emitting from top)
- Stats listed below: total time, best lap, credits earned
- Credits earned animates counting up from 0 with coin sound
- Scrollable leaderboard below showing all finisher positions
- Two buttons at bottom: "NEXT RACE" (accent) and "MAIN MENU" (surface)

### Main Menu Design
```
┌─────────────────────────────────────────────────────┐
│                                                     │
│               V E L O C I T Y                       │  ← title with letter-spacing, subtle glow
│           ─────────────────────                     │  ← thin orange accent line under title
│                                                     │
│              [ QUICK RACE ]                         │  ← buttons centered, stacked
│              [   GARAGE   ]                         │
│              [  SETTINGS  ]                         │
│              [    QUIT    ]                         │
│                                                     │
│                                 Credits: 1,500 ★    │  ← bottom-right, gold
│  v0.1                                               │  ← bottom-left, muted
└─────────────────────────────────────────────────────┘
```
- Background: 3D SubViewport showing a car slowly rotating on a turntable with dramatic lighting (spotlight from above, rim light from behind) — reuses the car mesh system
- Subtle animated gradient overlay on the background (dark vignette edges)

### Garage Design
```
┌──────────────────────┬──────────────────────────────┐
│  GARAGE              │                              │
│  Credits: 1,500 ★    │     [3D Car Preview]         │
│  ─────────────       │     (rotating on turntable)  │
│                      │                              │
│  ┌── Sedan S ──────┐ │  ┌─ SPEED    ████████░░ ──┐ │
│  │ T1  FREE  ✓     │ │  │ HANDLING  ██████░░░░   │ │
│  └─────────────────┘ │  │ BRAKING   ███████░░░   │ │
│  ┌── Sport Coupe ──┐ │  │ DRIFT     █████░░░░░   │ │
│  │ T2  $1,500  🔒  │ │  └───────────────────────┘ │
│  └─────────────────┘ │                              │
│  ┌── Muscle Car ───┐ │  A reliable starter car.     │
│  │ T3  $4,000  🔒  │ │  Balanced handling with      │
│  └─────────────────┘ │  moderate speed.              │
│         ...          │                              │
│                      │  [ SELECT ] or [ BUY $1500 ] │
│  [← BACK]            │                              │
└──────────────────────┴──────────────────────────────┘
```
- Left panel scrolls through car cards
- Right panel: 3D car preview in SubViewport with turntable rotation + 3-point lighting
- Stats bars use gradient fills (cyan→orange) proportional to value
- Locked cars show price in `Warning/Credits` gold, lock icon, slightly dimmed card
- Selected car card gets `Primary Accent` left border and subtle glow

### Car Visual Improvements
Each car tier should be visually distinct beyond just color:
- **Tier 1 (Sedan):** Tall cabin, boxy proportions, small headlights
- **Tier 2 (Coupe):** Lower cabin, slightly wider stance, angled rear
- **Tier 3 (Muscle):** Wide body, pronounced hood scoop (extra CSGBox3D), low cabin
- **Tier 4 (Super):** Very low profile, wide rear with spoiler (thin CSGBox3D), angular shapes
- **Tier 5 (Hyper):** Widest body, lowest cabin, large rear wing, aggressive wedge shape, more CSG pieces for detail

All cars get:
- **Metallic paint material:** `metallic = 0.6`, `roughness = 0.25`, `clearcoat = 0.8` for that glossy car-paint look
- **Two-tone color:** Body color + darker secondary color on lower body panels (darkened 40%)
- **Chrome trim:** `metallic = 1.0`, `roughness = 0.05`, silver color — used on grille, door handles (small CSGBox3D accents)
- **Emissive headlights/taillights:** `emission_enabled = true`, headlights warm white, taillights red, brake lights brighter red when braking

### Track Visual Design
Each track has a distinct color temperature and atmosphere:

**Oval Speedway** — Bright daylight, warm
- Sky: Clear blue with white sun, `energy = 1.2`
- Road: Dark asphalt (`#333333`) with white dashed center line (CSGBox3D strips) and orange rumble strips on edges
- Barriers: Concrete gray with alternating red/white stripes at corners
- Infield: Green grass with checker flag pattern near start/finish
- Grandstands: Stacked gray boxes with colorful "crowd" strips (randomized colored small boxes)

**Mountain Circuit** — Overcast, cool tones
- Sky: Overcast gray-blue, `ambient_light` slightly blue tinted, volumetric fog enabled
- Road: Darker asphalt, yellow center line, metal guardrails (silver CSGBox3D with posts)
- Scenery: Pine trees (CSGCylinder3D brown trunk + CSGSphere3D dark green canopy), rocky outcrops (gray CSGBox3D clusters at angles)
- Elevation: Road rises and falls, hairpin switchbacks with visible drop-offs

**City Streets** — Night, neon-lit
- Sky: Dark night sky, no sun, ambient light low
- Road: Wet-look asphalt (higher `roughness`, slightly blue-tinted), white lane markings
- Buildings: Tall CSGBox3D walls with emissive window grids (small emissive rectangles in warm yellow/white patterns)
- Street lights: CSGCylinder3D posts with OmniLight3D at top (warm white pools of light)
- Accent: Neon-colored barriers at corners (emissive cyan/pink), gives that nighttime racing feel

### Scene Transitions
- Fade-to-black between menus (0.3s fade out, 0.3s fade in) via a CanvasLayer with ColorRect animated with a Tween
- Race start: camera sweeps along the grid showing cars, then snaps to player chase cam at "GO!"
- Race end: slow-motion effect (Engine.time_scale = 0.3) for 2 seconds as winner crosses line, then results slide in

### Particle Effects
- **Tire smoke during drift:** GPUParticles3D attached to rear wheels, white/gray smoke, emits when `is_drifting == true`
- **Exhaust:** Subtle dark particles from rear of car at all times, intensity tied to throttle
- **Sparks on wall scrape:** Brief orange spark particles on collision with barriers
- **Dust on grass:** Brown/tan particles when driving off-track on grass surfaces
- **Confetti on results:** GPUParticles2D, multicolored small rectangles falling from top of screen for 1st place finish

---

## Architecture Overview

### Core Tech
- **Engine:** Godot 4.6.1 with GDScript
- **Car physics:** `VehicleBody3D` with 4 `VehicleWheel3D` nodes — gives us suspension, traction, and per-wheel friction control for drift
- **Track roads:** `Path3D` for the racing line + `StaticBody3D`/`ConcavePolygonShape3D` for drivable collision (CSGPolygon3D for visuals only — its auto-generated collision has gap issues at path seams)
- **Car visuals:** Procedural CSG meshes (CSGBox3D body + cabin + headlights/taillights), `use_collision = false` on all CSG (collision handled by the VehicleBody3D's own CollisionShape3D)
- **Split-screen:** Two `SubViewport`s sharing one `World3D`
- **Save system:** `ConfigFile` for settings, JSON dictionary serialization for player profile (avoids Godot Resource nested-custom-resource bugs with `Array[CustomResource]`)
- **Input:** `p1_`/`p2_` prefix pattern — registered programmatically via `InputMap` in code (not project.godot, since complex events with device IDs can't be reliably defined in .ini format)
- **Physics tick rate:** 120Hz (`physics/common/physics_ticks_per_second = 120`) — VehicleBody3D is unstable at 60Hz, especially at high speeds

### Project Structure
```
racing-game/
├── project.godot
├── autoloads/          # GameManager, SaveManager, AudioManager, InputManager, RaceManager
├── cars/
│   ├── car_data.gd              # CarData Resource class
│   ├── car_base.tscn + .gd     # VehicleBody3D base scene + controller
│   ├── player_car_controller.gd # Reads input, drives car
│   ├── ai_car_controller.gd    # Path-following AI
│   ├── car_definitions/*.tres   # 5 cars: sedan, coupe, muscle, super, hyper
│   └── car_meshes/*.gd         # Procedural mesh generators per car type
├── tracks/
│   ├── track_data.gd            # TrackData Resource class
│   ├── track_base.tscn + .gd   # Base track with checkpoints, spawns, AI path
│   ├── components/              # Checkpoint, StartFinishLine scenes
│   └── track_scenes/            # 3 tracks: oval, mountain, city
├── scenes/
│   ├── main.tscn                # Entry point
│   └── race/                    # race_scene, split_screen_race, camera, countdown, results
├── ui/
│   ├── main_menu/               # Main menu
│   ├── garage/                  # Car browsing/buying/selecting
│   ├── track_select/            # Track picking
│   ├── race_setup/              # Laps, AI count, split-screen toggle
│   ├── hud/                     # Speedometer, lap counter, position, timer, minimap
│   ├── settings/                # Audio/video settings
│   └── pause/                   # Pause menu overlay
└── data/                        # PlayerProfile, RaceResult Resource classes
```

### 5 Autoload Singletons
1. **GameManager** — game state, selected car/track, scene transitions, car/track registry
2. **SaveManager** — save/load profiles and settings to `user://`
3. **AudioManager** — music player + SFX pool (scene-based autoload)
4. **InputManager** — per-player input abstraction (`get_acceleration(player_index)`)
5. **RaceManager** — race state machine (countdown → racing → finished), lap/checkpoint tracking, position sorting

### 5 Cars (progression tiers)
| Car | Tier | Price | Top Speed | Power (HP) | Weight (kg) | Drive | Character |
|-----|------|-------|-----------|------------|-------------|-------|-----------|
| Starter Sedan | 1 | Free | 180 kph | 150 | 1200 | FWD | Understeer, forgiving |
| Sport Coupe | 2 | 1,500 | 220 kph | 280 | 1100 | RWD | Balanced, tail-happy |
| Muscle Car | 3 | 4,000 | 250 kph | 450 | 1400 | RWD | Powerful, heavy oversteer |
| Super Car | 4 | 10,000 | 300 kph | 600 | 1150 | RWD | Precise, high downforce |
| Hyper Car | 5 | 25,000 | 350 kph | 900 | 1050 | AWD | Planted, extreme speed |

### 3 Tracks
1. **Oval Speedway** (1.2 km, 4 checkpoints) — high-speed sweeping oval with 15° banked corners, wide 16m road, long straights for slipstream battles, rumble strips on the apexes, grandstands lining the straight. Tests top speed and drafting. Suits powerful cars.
2. **Mountain Circuit** (2.5 km, 8 checkpoints) — technical winding road with 40m elevation change, hairpin switchbacks, esses through a forest section, one fast sweeper on a ridgeline. 10m road width. Guardrails at drop-offs, grass runoff on inside of corners. Tests handling, braking, and weight transfer. Favors balanced cars.
3. **City Streets** (1.8 km, 6 checkpoints) — night circuit through a city grid with tight 90° corners, a chicane through a plaza, one short straight, narrow 8m road with concrete walls (no runoff — hit the wall and lose time). Tests precision and brake points. Punishes oversteer-heavy cars.

### Racing Physics Model

**Drive types implemented via VehicleWheel3D configuration:**
- **FWD:** Front wheels have `use_as_traction = true`. Naturally understeers — safe, predictable. Lifting throttle mid-corner tucks the nose in (lift-off oversteer), which is the main technique to rotate the car.
- **RWD:** Rear wheels have `use_as_traction = true`. Can oversteer on throttle (power oversteer) — the basis for drifting. Too much throttle mid-corner breaks rear traction.
- **AWD:** All four wheels `use_as_traction = true`, but rear gets 60% torque split (`engine_force * 0.6`) and front gets 40%. Planted and fast, but less dramatic.

**Torque curve simulation (not just flat force):**
`CarData` stores a simplified 3-point torque curve:
- `torque_low_rpm: float` — force at low speed (launch)
- `torque_peak_rpm: float` — peak force (mid-range, where the car pulls hardest)
- `torque_high_rpm: float` — force near top speed (falls off due to air resistance)
- `car_base.gd` interpolates between these based on `current_speed_kph / max_speed_kph` ratio, giving each car a distinct acceleration feel — muscle cars punch hard at low speed and fall off, hyper cars build progressively

**Aerodynamic drag and downforce:**
- `drag_coefficient: float` — air resistance force = `drag * speed²`, applied as opposing force along velocity. This naturally limits top speed without a hard cap, and makes slipstreaming meaningful.
- `downforce_coefficient: float` — extra grip at speed = `downforce * speed²`, added as downward force. Super/hyper cars have high downforce (corner faster at speed), muscle car has very low (raw power, less grip).

**Weight transfer:**
On braking, weight shifts to front wheels — front grip increases, rear grip decreases:
- Front `wheel_friction_slip` += `weight_transfer_factor * brake_amount`
- Rear `wheel_friction_slip` -= `weight_transfer_factor * brake_amount`
On acceleration, weight shifts to rear — rear grip increases:
- Works naturally with VehicleBody3D's suspension compression

**Drift model (proper 3-stage):**
1. **Initiation:** Player applies handbrake OR snaps throttle with rear weight unloaded (trail-braking into corner + throttle). Rear wheel slip angle exceeds threshold → enter drift state. For FWD cars, lift-off oversteer + handbrake is the entry method.
2. **Sustain:** During drift, rear `wheel_friction_slip` is reduced (less grip), but steering range increases (`max_steering_angle * 1.5`). Counter-steering (steering into the drift) is needed to maintain angle. Throttle modulates drift angle — more throttle = wider angle.
3. **Recovery:** Release handbrake + reduce throttle + straighten steering → rear grip gradually restores over 0.5s (not instant, feels organic).
- Drift is scored: angle × speed × duration = drift points (visual only, shown in HUD during drift, potential future use for bonus credits).

**Brake bias:**
`brake_bias: float` (0.0 = all rear, 1.0 = all front, default 0.65 = 65% front)
- Front brake force = `total_brake * brake_bias`
- Rear brake force = `total_brake * (1.0 - brake_bias)`
- Higher front bias = stable braking (understeer under braking)
- Lower front bias = more rotation under braking (trail-brake oversteer) — faster but riskier

**Slipstream/drafting:**
`car_base.gd` raycasts forward (50m range). If another car is directly ahead within 20m and speed > 100kph:
- Reduce drag by 30% → speed increases ~5-10 kph over normal top speed
- HUD shows "SLIPSTREAM" indicator
- This creates natural overtaking opportunities on straights

### Track Design Principles

**Corner types used across the 3 tracks:**
- **Hairpin:** 180° turn, requires heavy braking → 2nd gear corner. Oval has banked variants, City has flat hairpins.
- **Sweeper:** High-speed gradual curve, tests downforce. Oval track's entire shape is sweeping.
- **Chicane:** Quick left-right (or right-left), tests weight transfer. Mountain circuit and city streets have these.
- **Esses:** Series of alternating medium curves. Mountain circuit specialty.

**Banking:**
Oval speedway corners are banked at ~15° — modeled by tilting the road surface via Path3D curve tilt. Banking adds a centripetal force component that increases effective grip, allowing higher cornering speed. Flat corners (mountain, city) require pure tire grip.

**Track surface:**
- Racing line (center of track) has base friction
- Off-racing-line (edges) has same friction but accumulates dust/dirt → no mechanical difference but could be visual in future
- Grass/runoff: significantly lower friction (`wheel_friction_slip * 0.3`), detected by checking if any wheel's collision contact is with the grass StaticBody3D

**Rumble strips (kerbs):**
Raised colored strips at corner entries/exits — modeled as slightly raised CSGBox3D strips with bumpy collision. Driving over them causes suspension oscillation (visual/audio feedback) but allows corner-cutting for faster lines. Too much kerb = destabilize the car.

### AI Racing Intelligence

**Path following (base):** Same as before — follow AIPath curve with look-ahead steering and curvature-based braking.

**Spatial awareness:**
AI cars raycast sideways (left and right, 3m range) and forward (15m range):
- If another car is alongside, AI won't steer into them (collision avoidance)
- If a slower car is ahead, AI picks an inside or outside line to overtake (offset from the AIPath curve by ±3m)
- If being overtaken, AI doesn't swerve to block (that would be unfair on easy/medium)
- On hard difficulty, AI defends the inside line when a car is close behind (detected via rear raycast)

**Braking points:**
Instead of braking proportional to curvature (which is smooth and unrealistic), AI has pre-defined braking zones for each corner:
- At setup, `ai_car_controller.gd` pre-scans the AIPath curve to identify corners (curvature > threshold) and calculates a braking point based on entry speed and corner radius
- This gives distinct hard-braking-then-accelerate behavior rather than smooth speed modulation

**Mistakes:**
On easy/medium, AI occasionally:
- Brakes slightly too late (overshoots corner by 2-5m, loses 0.5s)
- Gets slightly wide on exit
- This is done by adding small random noise to braking distances and steering, making AI feel human rather than robotic

### Key Game Systems
- **Checkpoints:** `Area3D` gates that must be hit in order to validate laps (prevents shortcutting)
- **Credits:** 500/300/200/150/100/75/50/25 for positions 1st-8th
- **Sector timing:** Each track divided into 3 sectors (using checkpoint positions). HUD shows sector delta vs personal best (green = faster, red = slower) like real motorsport timing
- **Starting grid:** Shuffled randomly for now; later phases could add qualifying laps

### Engineering Decisions (avoiding known pitfalls)

**Car/track registry — hardcoded, not directory scans:**
`DirAccess.list_dir_begin()` doesn't work in exported Godot builds (res:// is packed). Instead, `GameManager` holds a hardcoded array of resource paths:
```gdscript
const CAR_PATHS := [
    "res://cars/car_definitions/starter_sedan.tres",
    "res://cars/car_definitions/sport_coupe.tres",
    # ...
]
```

**Track road collision — separate StaticBody3D, not CSG collision:**
`CSGPolygon3D` with `use_collision = true` and `mode = MODE_PATH` generates collision per-segment, causing gaps at seam joints where cars can clip through. Instead:
- CSGPolygon3D has `use_collision = false` (visual only)
- A separate `StaticBody3D` child uses a `ConcavePolygonShape3D` generated from the road mesh at `_ready()` using `CSGPolygon3D.get_meshes()` → `ConcavePolygonShape3D.set_faces()`
- This gives one continuous collision surface

**VehicleBody3D stability:**
- Lower center of mass: `center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM`, `center_of_mass = Vector3(0, -0.3, 0)` (below geometric center)
- Physics at 120Hz: `physics/common/physics_ticks_per_second = 120`
- Apply counter-torque when airborne to prevent endless spinning
- Speed limiter in `apply_throttle()` to prevent physics explosions

**AI path tracking — local search, not full scan:**
Each AI caches its `last_known_offset` on the curve. Each frame, it only searches ±30m around that offset (not the entire curve). Falls back to full scan only if the car gets teleported (e.g., after a reset).

**Car reset/respawn:**
`CarBase` includes a `reset_to_track()` method: if car speed < 2 kph for > 3 seconds, or car Y position < -10 (fell off world), snap car to the nearest point on the track's AI path with correct facing direction. A "RESET" prompt appears when the car is detected as stuck, and player can trigger with a button.

**Save system — JSON, not Resource serialization:**
Godot's `ResourceSaver.save()` with nested custom Resources (`Array[RaceResult]` inside `PlayerProfile`) silently drops data or fails to deserialize in some Godot 4.x versions. Instead:
- `PlayerProfile` and `RaceResult` have `to_dict() -> Dictionary` and `static from_dict(d: Dictionary)` methods
- `SaveManager` writes JSON via `FileAccess.store_string(JSON.stringify(profile.to_dict()))` to `user://profile.json`

**Scene loading — loading screen:**
`GameManager.transition_to_scene()` uses `ResourceLoader.load_threaded_request()` + a loading screen scene that polls `ResourceLoader.load_threaded_get_status()` and shows a progress bar. Prevents freeze frames when loading large track scenes.

**Input registration in code:**
`InputManager._ready()` calls `InputMap.add_action()` and `InputMap.action_add_event()` for all p1/p2 actions with correct device IDs. This avoids project.godot syntax issues with complex InputEvent serialization.

**Collision layers:**
| Layer | Name | Used by |
|-------|------|---------|
| 1 | Default | Ground, barriers, scenery |
| 2 | Cars | VehicleBody3D instances |
| 3 | Checkpoints | Checkpoint Area3D (mask=2, detects cars) |
Cars: layer=2, mask=1,2 (collide with ground and other cars)
Checkpoints: layer=0, mask=2 (detect cars only, no physical collision)

### Godot 4.6.1 Specific Notes
- `VehicleWheel3D.suspension_rest_length` was renamed to `wheel_rest_length`
- Available wheel properties: `wheel_roll_influence`, `wheel_radius`, `wheel_rest_length`, `wheel_friction_slip`, `suspension_travel`, `suspension_stiffness`, `suspension_max_force`, `damping_compression`, `damping_relaxation`
- `class_name` types can't be used as type annotations (e.g. `@export var x: CarData`) without the `.godot/` cache — use `Resource` base type instead
- `:=` type inference fails when RHS accesses properties on `Resource`-typed vars — use explicit `var x: float = ...`
- Sub_resources must appear before nodes in .tscn files
- `config/features=PackedStringArray("4.4")` for Godot 4.6.1 projects

---

## Implementation Phases

### Phase 0: Project Setup ✅
- `git init`, create `.gitignore` (Godot standard: `.godot/`, `*.import`, `export_presets.cfg`)
- Create directory structure: `autoloads/`, `cars/`, `cars/car_definitions/`, `cars/car_meshes/`, `tracks/`, `tracks/components/`, `tracks/track_scenes/`, `tracks/track_definitions/`, `tracks/environments/`, `scenes/`, `scenes/race/`, `ui/`, `ui/theme/`, `ui/main_menu/`, `ui/garage/`, `ui/track_select/`, `ui/race_setup/`, `ui/hud/`, `ui/settings/`, `ui/pause/`, `data/`, `assets/`
- Create `project.godot` with window settings (1920x1080, stretch mode canvas_items), physics at 120Hz, rendering settings (MSAA 2x)

### Phase 1: Foundation — "A Car That Drives" ✅
Create input system, VehicleBody3D car on a flat plane with chase camera.
- `autoloads/game_manager.gd` (minimal — just state holder + hardcoded car paths)
- `autoloads/input_manager.gd` (registers p1 actions via `InputMap` API in `_ready()`)
- `cars/car_data.gd` (CarData Resource class — includes: drive_type enum (FWD/RWD/AWD), torque_low/peak/high_rpm, drag_coefficient, downforce_coefficient, brake_bias, weight_transfer_factor, drift_friction_slip, drift_steer_multiplier, plus all existing suspension/wheel/visual exports)
- `cars/car_definitions/starter_sedan.tres`
- `cars/car_base.gd` (VehicleBody3D controller — applies CarData to wheels/suspension, configures drive type FWD/RWD/AWD, torque curve interpolation for engine force, aerodynamic drag + downforce applied in `_physics_process`, weight transfer on braking, `center_of_mass` lowered, 3-stage drift model, brake bias distribution, slipstream raycast, `reset_to_track()` stub)
- `cars/car_base.tscn` (VehicleBody3D + 4 VehicleWheel3D + CollisionShape3D + BodyMesh Node3D)
- `cars/player_car_controller.gd` (reads InputManager, calls car methods)
- `scenes/race/race_camera.gd` (smooth chase camera with look-back support)
- `scenes/race/test_drive.tscn` — flat `StaticBody3D` ground plane + `DirectionalLight3D` + `WorldEnvironment` + car instance + camera
- **Verify:** Run `godot --path . scenes/race/test_drive.tscn`. WASD drives, camera follows, suspension bounces, car doesn't flip on turns (center of mass works), speed caps at max_speed_kph

### Phase 2: First Track — "Drive Around a Loop"
Oval speedway with road surface, proper collision, barriers, checkpoints, lap counting.
- `tracks/track_data.gd` (TrackData Resource class)
- `tracks/track_base.gd` (base track script: collects checkpoints/spawns, connects Area3D signals to RaceManager, generates road collision from CSG mesh at `_ready()` using `get_meshes()` → `ConcavePolygonShape3D`)
- `tracks/track_base.tscn` (scene with node structure: TrackGeometry, Checkpoints, SpawnPoints, AIPath, StartFinishLine, WorldEnvironment, DirectionalLight3D)
- `tracks/components/checkpoint.tscn` + `.gd` (Area3D with collision on layer 3 mask 2)
- `tracks/track_scenes/oval_speedway.tscn` + `.gd` (Path3D oval curve + CSGPolygon3D road visual + `_build_road_collision()` at ready + CSGBox3D barriers + ground plane)
- `autoloads/race_manager.gd` (race state machine: PRE_RACE→COUNTDOWN→RACING→FINISHED, checkpoint validation, lap counting, position sorting)
- `scenes/race/race_scene.gd` (single-player orchestrator: loads track scene, spawns car at spawn point, sets up camera, registers with RaceManager)
- **Verify:** Drive laps on the oval. Car doesn't clip through road at any point. Crossing start/finish increments lap after hitting all checkpoints. Barriers prevent falling off. Timer tracks race time.

### Phase 3: HUD and Race Flow — "A Real Race"
Countdown, speedometer, lap display, position, timer, results screen, pause — all styled per the Visual Design System.
- `ui/theme/racing_theme.tres` — dark theme with accent colors, custom button/panel/label styles
- `ui/hud/race_hud.tscn` + `.gd` — semi-transparent top bar (position, lap, timer), large speed display bottom-right with throttle/brake bars
- `ui/hud/speedometer.tscn` — 96px speed number + km/h label + throttle/brake input bars
- `scenes/race/countdown_overlay.tscn` — animated zoom-in numbers, "GO!" flash effect
- `scenes/race/results_screen.tscn` — slide-up overlay, position in gradient color, credit count-up animation
- `ui/pause/pause_menu.tscn` + `.gd` — dark overlay panel, styled buttons
- **Verify:** 3-2-1-GO with animations, HUD updates live with styled components, results show with credit awards, ESC pauses with overlay

### Phase 4: AI Opponents — "Race Against Others"
AI cars following racing line with difficulty levels and efficient path tracking.
- `cars/ai_car_controller.gd` — path-following with cached `last_offset` (local ±30m search each frame, not full curve scan), curvature look-ahead for braking, 3 difficulty presets, rubber-banding multiplier, stuck detection (speed < 2kph for 3s → reset to path)
- `cars/car_definitions/sport_coupe.tres`, `muscle_car.tres`
- `cars/car_meshes/sedan_mesh.gd`, `coupe_mesh.gd`, `muscle_mesh.gd` (distinct silhouettes per tier)
- Add `AIPath` (Path3D with Curve3D racing line) to oval speedway
- Update `race_scene.gd` to spawn N AI cars at grid positions with random car data
- Update `race_manager.gd` position calculation for multi-car sorting
- **Verify:** 5+ AI cars race without getting stuck or falling off. Position display updates correctly. Easy AI is noticeably slower than hard. AI brakes for corners and doesn't just slam into walls.

### Phase 5: Menus and Progression — "A Game Loop"
Full menu flow with dark theme UI, 3D car previews, garage, save/load, credits, unlocks.
- `autoloads/save_manager.gd`, `autoloads/audio_manager.tscn` + `.gd`
- `data/player_profile.gd`, `data/race_result.gd`
- `ui/main_menu/main_menu.tscn` — dark bg with 3D rotating car SubViewport, centered title "VELOCITY" with glow, accent-striped buttons, credits display in gold
- `ui/garage/garage.tscn` — split layout: scrollable car cards (left) + 3D turntable preview with 3-point lighting (right) + gradient stat bars + buy/select button
- `ui/track_select/track_select.tscn` — track cards with preview colors and difficulty stars
- `ui/race_setup/race_setup.tscn` — laps slider, AI count, difficulty, split-screen toggle
- `ui/settings/settings_menu.tscn` — styled sliders and checkboxes
- `scenes/main.tscn` as entry point, fade transitions between all scenes
- **Verify:** Full loop: menu → garage → select track → race → earn credits → buy car → save. All screens follow dark theme with accent colors.

### Phase 6: More Tracks — "Variety"
Mountain circuit and city streets with unique geometry and AI paths.
- `tracks/track_scenes/mountain_circuit.tscn` + `.gd`
- `tracks/track_scenes/city_streets.tscn` + `.gd`
- **Verify:** All 3 tracks playable with AI, each feels distinct

### Phase 7: Split-Screen — "Play With a Friend"
Two-player local multiplayer with dual viewports.
- `scenes/race/split_screen_race.tscn` + `.gd`
- P2 input actions, race_setup split-screen toggle
- **Verify:** Screen splits, each player controls independently with own HUD

### Phase 8: Polish — "Look and Feel"
Visual and audio polish pass applying the full design system:
- Metallic car paint materials (clearcoat, two-tone lower body, chrome trim accents)
- Emissive headlights/taillights (brake lights brighten on brake input)
- Tire smoke particles (GPUParticles3D on rear wheels during drift)
- Exhaust particles, sparks on wall scrape, dust on grass
- Engine sound (AudioStreamPlayer3D, pitch mapped to RPM/speed)
- Tire screech audio during drift, collision crash sounds
- Scene transition fades (CanvasLayer + ColorRect tween)
- Countdown zoom-in animations, "GO!" screen flash
- Results screen with position-based colors (gold/silver/bronze), credit count-up animation, 1st-place confetti
- Minimap (SubViewport with top-down orthographic Camera3D)
- Screen shake on collision (camera offset tween)
- City track: night lighting with OmniLight3D street lamps, emissive building windows, neon barriers
- Slow-motion effect when winner crosses finish line

---

## Verification
After each phase, run: `godot --path /Users/aidan/Code/racing-game` to launch and test interactively. Each phase produces something playable.

For headless validation (no GPU), run: `godot --headless --path /Users/aidan/Code/racing-game --quit` to verify scripts parse without errors.

Key things to test at each phase:
- Phase 1: Car doesn't flip on sharp turns (center of mass), speed caps work, no physics jitter
- Phase 2: Drive the full track loop 3 times — no collision gaps, checkpoints all trigger, lap count is correct
- Phase 4: Watch AI for 3 full laps — no stuck cars, no AI driving off-track, positions update
- Phase 5: Quit game mid-race, relaunch — profile loads, credits persist, unlocked cars remembered
