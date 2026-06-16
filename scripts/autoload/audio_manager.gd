extends Node

# 全局音频管理器单例 - 负责背景音乐播放
# 作为自动加载运行，跨场景切换保持存活

signal music_toggled(is_muted: bool)
signal volume_changed(value_db: float)

const MUSIC_PATH := "res://music/background.mp3"
const DEFAULT_VOLUME_DB := -10.0
const SETTINGS_PATH := "user://audio_settings.cfg"

var _music_player: AudioStreamPlayer
var _muted: bool = false
var _volume_db: float = DEFAULT_VOLUME_DB


func _ready() -> void:
	_setup_music_player()
	_load_setting()
	_apply_mute_state()


func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "BackgroundMusicPlayer"
	_music_player.bus = "Master"
	_music_player.volume_db = _volume_db
	add_child(_music_player)


func _start_background_music() -> void:
	var stream := load(MUSIC_PATH) as AudioStreamMP3
	if stream == null:
		push_error("AudioManager: 无法加载背景音乐文件: ", MUSIC_PATH)
		return

	stream.loop = true
	_music_player.stream = stream
	_music_player.play()


func _apply_mute_state() -> void:
	if _music_player:
		if _muted:
			_music_player.stop()
		else:
			_start_background_music()


# 设置音乐音量（分贝值）
# value_db: -40（静音）到 0（最大）
func set_music_volume(value_db: float) -> void:
	_volume_db = clampf(value_db, -40.0, 0.0)
	if _music_player:
		_music_player.volume_db = _volume_db
	volume_changed.emit(_volume_db)
	_save_setting()


# 获取当前音乐音量
func get_music_volume() -> float:
	return _volume_db


# 切换音乐播放/暂停
func toggle_music() -> void:
	_muted = !_muted
	_apply_mute_state()
	_save_setting()
	music_toggled.emit(_muted)


# 返回当前是否静音
func is_muted() -> bool:
	return _muted


# 持久化音量和静音设置到 user://audio_settings.cfg
func _save_setting() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "muted", _muted)
	config.set_value("audio", "volume", _volume_db)
	config.save(SETTINGS_PATH)


# 从 user://audio_settings.cfg 加载音量和静音设置
func _load_setting() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_muted = config.get_value("audio", "muted", false)
		_volume_db = config.get_value("audio", "volume", DEFAULT_VOLUME_DB)
	else:
		_muted = false
		_volume_db = DEFAULT_VOLUME_DB
	if _music_player:
		_music_player.volume_db = _volume_db
