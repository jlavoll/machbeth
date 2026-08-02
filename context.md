# CYBERPUNK CITY PROJECT CONTEXT & ARCHITECTURE

## Project Overview
A 3D Cyberpunk arcade driving and combat prototype built in **Godot 4**. The game features procedural/grid-based city generation, weather ambiance systems, first-person cockpit tactical HUD, combat triggers, turn-based/ATB synth-deck combat systems, and a dynamic audio engine.

---

## Codebase Architecture & File Structure

### Core Game World & Entities
* **[Main.tscn](file:///home/jorn/machbeth/CyberpunkCity/Main.tscn)**: Primary scene tree containing all subsystem nodes, world environment, lighting, and the player vehicle.
* **[PlayerCar.gd](file:///home/jorn/machbeth/CyberpunkCity/PlayerCar.gd)**: Player vehicle controller (`CharacterBody3D`). Handles forward/reverse acceleration, friction, steering, visual body banking/pitch dynamics, and multi-tier camera zooming.
* **[CityGenerator.gd](file:///home/jorn/machbeth/CyberpunkCity/CityGenerator.gd)**: Procedurally generates procedural city blocks, roads, neon skyscrapers, and street lights.
* **[CityVisualEffects.gd](file:///home/jorn/machbeth/CyberpunkCity/CityVisualEffects.gd)**: Manages world-space visual effects, neon glitches, beat-synced lighting pulses, and shader uniforms.

### Systems & Managers
* **[BattleTriggerManager.gd](file:///home/jorn/machbeth/CyberpunkCity/BattleTriggerManager.gd)**: Detects combat conditions while driving and requests encounter transitions.
* **[BattleSystemManager.gd](file:///home/jorn/machbeth/CyberpunkCity/BattleSystemManager.gd)**: Manages active turn-based combat encounters, enemy target tracking, and hull damage resolution.
* **[CockpitDashboardUI.gd](file:///home/jorn/machbeth/CyberpunkCity/CockpitDashboardUI.gd)**: First-person windshield overlay and synth-deck UI (`CanvasLayer`), housing Ordnance, ICE-Breaker, Nitrous, and Overclock ATB meters.
* **[NeuralGlitchSystem.gd](file:///home/jorn/machbeth/CyberpunkCity/NeuralGlitchSystem.gd)** & **[DustFogSystem.gd](file:///home/jorn/machbeth/CyberpunkCity/DustFogSystem.gd)**: Atmospheric visual systems for fog, dust particles, and digital corruption effects.
* **[TacticalOvermapManager.gd](file:///home/jorn/machbeth/CyberpunkCity/TacticalOvermapManager.gd)**: Controls minimap and tactical urban overlay displays.

---

## Audio Architecture & Guidelines

The project uses a structured audio bus routing system:

### 1. 3D Spatial Acoustic System (`CarEngineAudio.gd`)
* **Vehicle & Player-Emitted Sounds**: All sounds emitted by or attached to the player vehicle (such as engine hum, future car weapon sound effects, car collisions, and localized vehicle SFX) **MUST** utilize our custom 3D acoustic system implemented in **[CarEngineAudio.gd](file:///home/jorn/machbeth/CyberpunkCity/CarEngineAudio.gd)**.
* **Key Features**:
  * `AudioStreamPlayer3D` attached directly to the player vehicle (`PlayerCar`).
  * Speed-driven pitch shifting and exponential volume interpolation.
  * Real-time acoustic environment raycasting (samples nearby building geometry to adjust `AudioEffectReverb` wetness and room echo in narrow city streets).
  * Line-of-sight camera occlusion raycasting (dynamically applies `AudioEffectLowPassFilter` when buildings block line of sight between the camera and vehicle).
* **Audio Bus**: Routes to the custom `"Engine"` audio bus.

### 2. Standard 2D Ambient & Global Audio Channels
* **Music Playlist Manager ([MusicPlaylistManager.gd](file:///home/jorn/machbeth/CyberpunkCity/MusicPlaylistManager.gd))**:
  * Context-aware playlist management ("DRIVING", "BATTLE", "STORY").
  * Emits real-time BPM metadata for beat-synced visual glitches.
  * **Audio Bus**: Routes to the `"Music"` audio bus.
* **Weather Ambiance Manager ([WeatherAmbienceManager.gd](file:///home/jorn/machbeth/CyberpunkCity/WeatherAmbienceManager.gd))**:
  * Controls rain downpours and textural wind breezes with seamless crossfading based on state from **[WeatherSystem.gd](file:///home/jorn/machbeth/CyberpunkCity/WeatherSystem.gd)**.
  * Dynamically creates the `"CarCabinAmbience"` audio bus with lowpass filtering and tight interior reverb to simulate listening from inside the car cabin.
  * **Audio Bus**: Routes to the `"CarCabinAmbience"` bus.

### 3. UI Audio & Settings Menu (`AudioSettingsMenu.gd`)
* **[AudioSettingsMenu.gd](file:///home/jorn/machbeth/CyberpunkCity/AudioSettingsMenu.gd)**:
  * Toggled via `ESC` key.
  * Operates with `PROCESS_MODE_ALWAYS` so sliders and inputs remain interactive while game tree is paused.
  * Features individual volume sliders for **MUSIC**, **AMBIENCE**, **ENGINE HUM**, and **SFX**.
