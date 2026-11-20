class_name GameAudio
extends RefCounted
## Единая точка звука игры: SFX и музыка идут через Core.sound_manager (шины SFX/Music,
## настройки mute игрока уже учтены). Потоки грузятся лениво и кэшируются.
## Звуки генерирует tools/make_audio.py (оригинальные ассеты, без лицензий).

const DIR := "res://game/audio/"

static var _current_music: String = ""


static func stream(sound_name: String) -> AudioStream:
	var path := DIR + sound_name + ".wav"  # ResourceLoader сам кэширует; свой static-кэш давал «resources still in use» при выходе
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


static func sfx(sound_name: String, volume: float = 1.0, pitch_var: float = 0.05) -> void:
	var s := stream(sound_name)
	var core := _core()
	if s == null or core == null or core.get("sound_manager") == null:
		return
	core.sound_manager.play_sfx(s, volume, pitch_var)


## Музыка с петлёй; повторный вызов с тем же треком не перезапускает его.
static func music(track: String, volume: float = 0.5) -> void:
	if track == _current_music:
		return
	var s := stream(track)
	var core := _core()
	if s == null or core == null or core.get("sound_manager") == null:
		return
	_current_music = track
	core.sound_manager.play_music(s, volume)


static func _core() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Core") if tree else null
