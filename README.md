# Velocity

A Forza-style 3D racing game built in Godot 4.6.1 with GDScript. All geometry is procedurally generated — no imported 3D models.

## Features

- **4 Racing Modes:** Street (GT), Formula 1, Baja Desert Rally, NASCAR
- **42 Cars** across 7 vehicle types (sedan, coupe, muscle, F1, stock car, buggy, trophy truck) — all procedurally generated meshes
- **14 Tracks** — ovals, street circuits, mountain roads, point-to-point desert stages, and superspeedways
- **Full Season Championships** for each mode with authentic points systems
- **AI Opponents** with 3 difficulty levels and rubber-banding
- **Split-Screen Multiplayer** (2 players)
- **Garage & Progression** — earn credits, unlock cars
- **HUD** with position, lap counter, speed, minimap, throttle/brake indicators
- **DRS System** for F1 mode, slipstream drafting

## Requirements

- [Godot 4.6.1](https://godotengine.org/download)

## Running

Open the project in Godot or run from the command line:

```bash
godot --path /path/to/racing-game
```

## Controls

| Key | Action |
|-----|--------|
| W / S | Accelerate / Brake |
| A / D | Steer |
| Space | Handbrake |
| Q | Look back |
| R | Reset car |
| ESC | Pause |

Split-screen Player 2 uses Arrow Keys + Numpad.

## Architecture

The game uses Godot's VehicleBody3D physics at 120Hz with four singleton autoloads (InputManager, SaveManager, GameManager, RaceManager). Cars use a composition pattern — controllers (player or AI) are added as child nodes. All track geometry is generated procedurally in `_ready()` using ArrayMesh and CSG primitives.

See [CLAUDE.md](CLAUDE.md) for detailed technical documentation.
