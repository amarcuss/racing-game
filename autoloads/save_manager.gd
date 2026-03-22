extends Node

## Persistence singleton: player profile (JSON) and settings (ConfigFile).

const PROFILE_PATH := "user://profile.json"
const SETTINGS_PATH := "user://settings.cfg"

var _profile_script: GDScript = preload("res://data/player_profile.gd")
var profile: RefCounted  # PlayerProfile

# Settings
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = true
var vsync: bool = true

func _ready() -> void:
	_load_profile()
	_load_settings()
	_apply_settings()

# --- Profile ---

func _load_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if not file:
			profile = _profile_script.new()
			return
		var text: String = file.get_as_text()
		file.close()
		var json := JSON.new()
		var err: int = json.parse(text)
		if err == OK and json.data is Dictionary:
			profile = _profile_script.new()
			profile.load_from_dict(json.data)
			return
	profile = _profile_script.new()

func _save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		var text: String = JSON.stringify(profile.to_dict(), "\t")
		file.store_string(text)
		file.close()

func add_credits(amount: int) -> void:
	profile.credits += amount
	_save_profile()

func spend_credits(amount: int) -> bool:
	if profile.credits < amount:
		return false
	profile.credits -= amount
	_save_profile()
	return true

func own_car(index: int) -> void:
	if index not in profile.owned_car_indices:
		profile.owned_car_indices.append(index)
		_save_profile()

func is_car_owned(index: int) -> bool:
	return index in profile.owned_car_indices

func select_car(index: int) -> void:
	profile.selected_car_index = index
	GameManager.selected_car_index = index
	_save_profile()

func record_race_result(result_dict: Dictionary) -> void:
	profile.race_results.append(result_dict)
	profile.total_races += 1
	if result_dict.get("finish_position", 0) == 1:
		profile.total_wins += 1
	_save_profile()

# --- Settings ---

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master_volume = cfg.get_value("audio", "master_volume", 1.0)
		sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
		music_volume = cfg.get_value("audio", "music_volume", 1.0)
		fullscreen = cfg.get_value("display", "fullscreen", true)
		vsync = cfg.get_value("display", "vsync", true)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.save(SETTINGS_PATH)
	_apply_settings()

func _apply_settings() -> void:
	# Volume — set linear gain on bus 0 (Master)
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))

	# Fullscreen
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# VSync
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
