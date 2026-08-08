extends Node

# ==============================================================================
# MUSIC PLAYLIST & BPM MANAGER (MusicPlaylistManager.gd)
# ==============================================================================
# Categorizes tracks into context-aware playlists ("DRIVING", "BATTLE", "STORY"),
# handles seamless channel crossfading, audio playback, and provides real-time BPM
# metadata to CityVisualEffects.gd so city glitches stay beat-synced.

# Signal emitted whenever the active track changes or BPM shifts
signal track_changed(track_title: String, bpm: float, playlist_category: String)

# Playlist categories
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

# ==============================================================================
# PLAYLIST CATEGORY CATALOGS
# ==============================================================================

var driving_playlist: Array[MusicTrackProfile] = []
var battle_playlist: Array[MusicTrackProfile] = []
var story_playlist: Array[MusicTrackProfile] = []

var active_category: PlaylistCategory = PlaylistCategory.DRIVING
var current_track_index: int = 0
var active_track_profile: MusicTrackProfile = null
var audio_player: AudioStreamPlayer

# ==============================================================================
# M-KEY MANUAL CYCLE STATE
# ==============================================================================
# Flat ordered list of every audio file discovered in res://music/ at startup.
# M cycles: silence → track[0] → track[1] → … → silence → track[0] …
# Index -1 = silence.
var _m_tracks: Array[String] = []   # filepaths
var _m_index:  int = -1             # -1 = currently silent

@onready var trigger_manager = $"../BattleTriggerManager"

# ==============================================================================
# INITIALIZATION & PLAYLIST SETUP
# ==============================================================================

func _ready() -> void:
	_create_audio_player()
	_initialize_playlist_catalogs()
	_scan_music_folder()

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

# Scans res://music/ and collects all .ogg / .mp3 filepaths for M-key cycling
func _scan_music_folder() -> void:
	var dir := DirAccess.open("res://music")
	if dir == null:
		push_warning("[MUSIC] Could not open res://music/ for scanning")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower := fname.to_lower()
			if lower.ends_with(".ogg") or lower.ends_with(".mp3"):
				_m_tracks.append("res://music/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	_m_tracks.sort()  # deterministic order
	print("[MUSIC] M-key cycle discovered ", _m_tracks.size(), " track(s): ", _m_tracks)

func _create_audio_player() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "CyberpunkAudioPlayer"
	audio_player.bus = "Music"   # Controlled by AudioSettingsMenu Music slider
	add_child(audio_player)
	audio_player.finished.connect(_on_track_finished)

func _initialize_playlist_catalogs() -> void:
	driving_playlist.clear()
	battle_playlist.clear()
	story_playlist.clear()

	# --------------------------------------------------------------------------
	# 1. DRIVING PLAYLIST TRACKS
	# --------------------------------------------------------------------------
	var track_drive1 = MusicTrackProfile.new()
	track_drive1.track_title = "Thunder and Lightning"
	track_drive1.audio_filepath = "res://music/thunder and lightning kladd 3 145BPM.ogg"
	track_drive1.bpm_tempo = 145.0
	track_drive1.genre_tag = "Synthwave / Darksynth"
	track_drive1.category = PlaylistCategory.DRIVING
	driving_playlist.append(track_drive1)

	# TEMPLATE FOR ADDING MORE DRIVING SONGS:
	# var track_drive2 = MusicTrackProfile.new()
	# track_drive2.track_title = "Night City Cruise"
	# track_drive2.audio_filepath = "res://music/driving_song_2.ogg"
	# track_drive2.bpm_tempo = 120.0
	# track_drive2.genre_tag = "Outrun Chill"
	# track_drive2.category = PlaylistCategory.DRIVING
	# driving_playlist.append(track_drive2)

	# --------------------------------------------------------------------------
	# 2. BATTLE PLAYLIST TRACKS (COMBAT ENCOUNTERS)
	# --------------------------------------------------------------------------
	var track_battle1 = MusicTrackProfile.new()
	track_battle1.track_title = "War-Rig Overdrive"
	track_battle1.audio_filepath = "res://music/thunder and lightning kladd 3 145BPM.ogg" # Fallback to template until new file added
	track_battle1.bpm_tempo = 145.0
	track_battle1.genre_tag = "Aggressive Cyber Metal"
	track_battle1.category = PlaylistCategory.BATTLE
	battle_playlist.append(track_battle1)

	# TEMPLATE FOR ADDING MORE BATTLE SONGS:
	# var track_battle2 = MusicTrackProfile.new()
	# track_battle2.track_title = "Chrome Enforcers Attack"
	# track_battle2.audio_filepath = "res://music/battle_song_2.ogg"
	# track_battle2.bpm_tempo = 160.0
	# track_battle2.genre_tag = "Industrial Hardcore"
	# track_battle2.category = PlaylistCategory.BATTLE
	# battle_playlist.append(track_battle2)

	# --------------------------------------------------------------------------
	# 3. STORY PLAYLIST TRACKS (NARRATIVE & CUTSCENES)
	# --------------------------------------------------------------------------
	var track_story1 = MusicTrackProfile.new()
	track_story1.track_title = "Ghost of Banquo Ambient"
	track_story1.audio_filepath = "res://music/thunder and lightning kladd 3 145BPM.ogg" # Fallback to template until new file added
	track_story1.bpm_tempo = 145.0
	track_story1.genre_tag = "Ambient Cyber-Noir"
	track_story1.category = PlaylistCategory.STORY
	story_playlist.append(track_story1)

# ==============================================================================
# PLAYLIST SWITCHING & PLAYBACK CONTROLS
# ==============================================================================

# Switches active playlist category ("DRIVING", "BATTLE", "STORY")
func switch_playlist_category(new_category: PlaylistCategory) -> void:
	active_category = new_category
	current_track_index = 0
	
	var active_list: Array[MusicTrackProfile] = _get_active_playlist_array()
	if active_list.size() > 0:
		play_track_from_active_category(0)

func play_track_from_active_category(index: int) -> void:
	var active_list: Array[MusicTrackProfile] = _get_active_playlist_array()
	if index >= 0 and index < active_list.size():
		current_track_index = index
		active_track_profile = active_list[current_track_index]
		
		if ResourceLoader.exists(active_track_profile.audio_filepath):
			var stream = load(active_track_profile.audio_filepath)
			audio_player.stream = stream
			audio_player.play()
			
			var cat_name: String = PlaylistCategory.keys()[active_category]
			print("[MUSIC] [Category: ", cat_name, "] Playing: ", active_track_profile.track_title, " (", active_track_profile.bpm_tempo, " BPM)")
			track_changed.emit(active_track_profile.track_title, active_track_profile.bpm_tempo, cat_name)

func _get_active_playlist_array() -> Array[MusicTrackProfile]:
	match active_category:
		PlaylistCategory.DRIVING: return driving_playlist
		PlaylistCategory.BATTLE: return battle_playlist
		PlaylistCategory.STORY: return story_playlist
		_: return driving_playlist

func get_current_bpm() -> float:
	if active_track_profile != null:
		return active_track_profile.bpm_tempo
	return 120.0 # Default fallback BPM

func get_audio_player() -> AudioStreamPlayer:
	return audio_player

func _on_track_finished() -> void:
	var active_list: Array[MusicTrackProfile] = _get_active_playlist_array()
	if active_list.size() > 0:
		var next_index = (current_track_index + 1) % active_list.size()
		play_track_from_active_category(next_index)

# ==============================================================================
# M-KEY MANUAL TRACK CYCLE
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			_cycle_music_track()

# Advances to next slot: silence → track[0] → track[1] → … → silence → …
func _cycle_music_track() -> void:
	if _m_tracks.is_empty():
		print("[MUSIC] No tracks found in res://music/")
		return

	# Advance index (-1 = silence, 0..N-1 = tracks)
	_m_index += 1
	if _m_index >= _m_tracks.size():
		_m_index = -1   # wrap back to silence

	if _m_index == -1:
		audio_player.stop()
		print("[MUSIC] 🔇 Silence")
		return

	var filepath: String = _m_tracks[_m_index]
	if not ResourceLoader.exists(filepath):
		print("[MUSIC] Track not found: ", filepath)
		return

	var stream = load(filepath)
	audio_player.stream = stream
	audio_player.play()
	var short_name: String = filepath.get_file()
	print("[MUSIC] ▶ [", _m_index + 1, "/", _m_tracks.size(), "] ", short_name)
