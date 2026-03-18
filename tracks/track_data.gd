class_name TrackData
extends Resource

## Track definition resource with layout and race configuration data.

@export var track_name: String = "Track"
@export_multiline var description: String = ""
@export var length_km: float = 1.0
@export var road_width: float = 12.0
@export var num_checkpoints: int = 4
@export var default_laps: int = 3
@export var difficulty: int = 1
@export var scene_path: String = ""
@export var is_point_to_point: bool = false
