extends RefCounted

## Player progression data: credits, owned cars, race history.

var credits: int = 0
var owned_car_indices: Array[int] = [0]
var selected_car_index: int = 0
var race_results: Array = []  # Array of Dicts
var total_races: int = 0
var total_wins: int = 0

func to_dict() -> Dictionary:
	return {
		"credits": credits,
		"owned_car_indices": owned_car_indices,
		"selected_car_index": selected_car_index,
		"race_results": race_results,
		"total_races": total_races,
		"total_wins": total_wins,
	}

func load_from_dict(d: Dictionary) -> void:
	credits = d.get("credits", 0)
	var raw_owned: Array = d.get("owned_car_indices", [0])
	owned_car_indices = []
	for idx in raw_owned:
		owned_car_indices.append(int(idx))
	selected_car_index = d.get("selected_car_index", 0)
	race_results = d.get("race_results", [])
	total_races = d.get("total_races", 0)
	total_wins = d.get("total_wins", 0)
