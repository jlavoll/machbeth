extends Node

# ==============================================================================
# MUSIC PLAYER & PLAYLIST MANAGER (musicplayer.gd)
# ==============================================================================
# Central manager for all music-related functionality in CyberpunkCity.
# - Scans/registers tracks in res://music/
# - Categorizes tracks into context-aware playlists ("DRIVING", "BATTLE", "STORY")
# - Handles audio playback, track switching, looping, and smooth crossfading
# - Emits BPM metadata to synchronize city visual effects and shaders

signal track_changed(track_title: String, bpm: float, playlist_category: String)

enum PlaylistCategory {
	DRIVING,
	BATTLE,
	STORY
}

# ------------------------------------------------------------------------------
# TRACK PROFILE DATA STRUCTURE
# ------------------------------------------------------------------------------
class MusicTrackProfile:
	var track_title: String
	var audio_filepath: String
	var bpm_tempo: float
	var genre_tag: String
	var category: PlaylistCategory

# ------------------------------------------------------------------------------
# PLAYLIST CATALOGS & STATE
# ------------------------------------------------------------------------------
var driving_playlist: Array[MusicTrackProfile] = []
var battle_playlist: Array[MusicTrackProfile] = []
var story_playlist: Array[MusicTrackProfile] = []

var active_category: PlaylistCategory = PlaylistCategory.DRIVING
var current_track_index: int = 0
var active_track_profile: MusicTrackProfile = null

var audio_player: AudioStreamPlayer
var crossfade_player: AudioStreamPlayer
var is_crossfading: bool = false

@onready var trigger_manager = $"../BattleTriggerManager"

# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _ready() -> void:
	_create_audio_players()
	_initialize_playlist_catalogs()
	
	# Connect to BattleTriggerManager signals for automatic combat music switching
	if is_instance_valid(trigger_manager):
		trigger_manager.combat_encounter_requested.connect(func():
			switch_playlist_category(PlaylistCategory.BATTLE)
		)
		trigger_manager.combat_encounter_concluded.connect(func():
			switch_playlist_category(PlaylistCategory.DRIVING)
		)

	# Start playing default Driving playlist
	switch_playlist_category(PlaylistCategory.DRIVING)

func _create_audio_players() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "CyberpunkAudioPlayer"
	audio_player.bus = "Music"
	add_child(audio_player)
	audio_player.finished.connect(_on_track_finished)

	crossfade_player = AudioStreamPlayer.new()
	crossfade_player.name = "CyberpunkAudioPlayerCrossfade"
	crossfade_player.bus = "Music"
	add_child(crossfade_player)

func _initialize_playlist_catalogs() -> void:
	driving_playlist.clear()
	battle_playlist.clear()
	story_playlist.clear()

	# Track 1: Rørgryten (Driving / Ambient Electronic)
	var track1 = MusicTrackProfile.new()
	track1.track_title = "Rørgryten v2_3"
	track1.audio_filepath = "res://music/LANDR-rørgryten v2_3-Open-Medium.mp3"
	track1.bpm_tempo = 128.0
	track1.genre_tag = "Cyberpunk Electronic"
	track1.category = PlaylistCategory.DRIVING
	driving_playlist.append(track1)

	# Track 2: Sakral Sang (Story / Cyber Choral)
	var track2 = MusicTrackProfile.new()
	track2.track_title = "Sakral Sang"
	track2.audio_filepath = "res://music/LANDR-sakral sang-Open-Medium.wav"
	track2.bpm_tempo = 110.0
	track2.genre_tag = "Sacral Ambient Synth"
	track2.category = PlaylistCategory.STORY
	story_playlist.append(track2)

	# Fallback/Existing Track: Thunder and Lightning if present
	if ResourceLoader.exists("res://music/thunder and lightning kladd 3 145BPM.ogg"):
		var track3 = MusicTrackProfile.new()
		track3.track_title = "Thunder and Lightning"
		track3.audio_filepath = "res://music/thunder and lightning kladd 3 145BPM.ogg"
		track3.bpm_tempo = 145.0
		track3.genre_tag = "Darksynth / Cyber Metal"
		track3.category = PlaylistCategory.BATTLE
		battle_playlist.append(track3)
	else:
		# Copy driving track to battle playlist as battle fallback
		battle_playlist.append(track1)

# ==============================================================================
# PLAYLIST SWITCHING & PLAYBACK CONTROLS
# ==============================================================================

func switch_playlist_category(new_category: PlaylistCategory) -> void:
	active_category = new_category
	current_track_index = 0
	
	var active_list: Array[MusicTrackProfile] = _get_active_playlist_array()
	if active_list.size() > 0:
		play_track_from_active_category(0)

func play_track_from_active_category(index: int, crossfade_duration: float = 1.0) -> void:
	var active_list: Array[MusicTrackProfile] = _get_active_playlist_array()
	if index >= 0 and index < active_list.size():
		current_track_index = index
		var new_profile = active_list[current_track_index]
		
		if ResourceLoader.exists(new_profile.audio_filepath):
			var stream = load(new_profile.audio_filepath)
			active_track_profile = new_profile
			
			if audio_player.playing and crossfade_duration > 0.0:
				_crossfade_to_stream(stream, crossfade_duration)
			else:
				audio_player.stream = stream
				audio_player.volume_db = 0.0
				audio_player.play()
			
			var cat_name: String = PlaylistCategory.keys()[active_category]
			print("[MUSIC] [Category: ", cat_name, "] Playing: ", active_track_profile.track_title, " (", active_track_profile.bpm_tempo, " BPM)")
			track_changed.emit(active_track_profile.track_title, active_track_profile.bpm_tempo, cat_name)

func _crossfade_to_stream(new_stream: AudioStream, duration: float) -> void:
	if is_crossfading:
		return
	is_crossfading = true
	
	crossfade_player.stream = new_stream
	crossfade_player.volume_db = -80.0
	crossfade_player.play()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(audio_player, "volume_db", -80.0, duration)
	tween.tween_property(crossfade_player, "volume_db", 0.0, duration)
	
	tween.chain().tween_callback(func():
		audio_player.stop()
		audio_player.stream = new_stream
		audio_player.volume_db = 0.0
		audio_player.play(crossfade_player.get_playback_position())
		crossfade_player.stop()
		is_crossfading = false
	)

func next_track() -> void:
	var active_list: Array[MusicTrackProfile] = _get_active_playlist_array()
	if active_list.size() > 0:
		var next_idx = (current_track_index + 1) % active_list.size()
		play_track_from_active_category(next_idx)

func previous_track() -> void:
	var active_list: Array[MusicTrackProfile] = _get_active_playlist_array()
	if active_list.size() > 0:
		var prev_idx = (current_track_index - 1 + active_list.size()) % active_list.size()
		play_track_from_active_category(prev_idx)

func pause_music() -> void:
	if audio_player and audio_player.playing:
		audio_player.stream_paused = true

func resume_music() -> void:
	if audio_player and audio_player.stream_paused:
		audio_player.stream_paused = false

func set_volume(volume_linear: float) -> void:
	var db = linear_to_db(clamp(volume_linear, 0.0001, 1.0))
	if audio_player:
		audio_player.volume_db = db

func _get_active_playlist_array() -> Array[MusicTrackProfile]:
	match active_category:
		PlaylistCategory.DRIVING: return driving_playlist
		PlaylistCategory.BATTLE: return battle_playlist
		PlaylistCategory.STORY: return story_playlist
		_: return driving_playlist

func get_current_bpm() -> float:
	if active_track_profile != null:
		return active_track_profile.bpm_tempo
	return 120.0

func get_current_track_title() -> String:
	if active_track_profile != null:
		return active_track_profile.track_title
	return "No Track Playing"

func get_audio_player() -> AudioStreamPlayer:
	return audio_player

func _on_track_finished() -> void:
	next_track()
