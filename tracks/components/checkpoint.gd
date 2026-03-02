class_name Checkpoint
extends Area3D

## Checkpoint gate that detects when cars pass through it.
## Reports to RaceManager for lap validation.

@export var checkpoint_index: int = 0
@export var is_start_finish: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is VehicleBody3D:
		RaceManager.checkpoint_hit(checkpoint_index, body)
