extends RefCounted

## Single race result data for persistence.

var track_index: int = 0
var car_index: int = 0
var finish_position: int = 1
var total_cars: int = 1
var total_time: float = 0.0
var best_lap_time: float = 0.0
var credits_earned: int = 0
var laps: int = 0

func to_dict() -> Dictionary:
	return {
		"track_index": track_index,
		"car_index": car_index,
		"finish_position": finish_position,
		"total_cars": total_cars,
		"total_time": total_time,
		"best_lap_time": best_lap_time,
		"credits_earned": credits_earned,
		"laps": laps,
	}

func load_from_dict(d: Dictionary) -> void:
	track_index = d.get("track_index", 0)
	car_index = d.get("car_index", 0)
	finish_position = d.get("finish_position", 1)
	total_cars = d.get("total_cars", 1)
	total_time = d.get("total_time", 0.0)
	best_lap_time = d.get("best_lap_time", 0.0)
	credits_earned = d.get("credits_earned", 0)
	laps = d.get("laps", 0)
