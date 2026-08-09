# CYBERPUNK MACBETH: PROJECT CONTEXT & COMPLETE OVERVIEW

## Project Identity

**Title**: Cyberpunk Macbeth  
**Genre**: Synthwave/Cyberpunk 3D Arcade Driving & Tactical Combat  
**Engine**: Godot 4 (GDScript)  
**Theme**: A dark, neon-drenched adaptation of Shakespeare's *Macbeth* set in a corporate dystopia  
**Status**: Active development with multiple verified systems implemented

---

## Executive Summary

Cyberpunk Macbeth is a **procedurally generated 3D driving and combat game** where you play as **Mack (Macbeth)**, an elite corporate enforcer rising through the ranks of **Duncan Dynamics** to seize control of "The Spire Grid" a massive megacity controlled by a single megacorporation.

The game blends **arcade driving physics**, **procedural city generation**, **dynamic weather and lighting**, **turn-based ATB combat** in a cockpit dashboard interface, and a **rich narrative** following the 5-act structure of Macbeth complete with neural glitches, ghost-code hallucinations, and a descent into thermal runaway.

---

## Project Structure Overview

```
CyberpunkCity/
├── *.gd                      # Core GDScript game logic (19 scripts)
├── Main.tscn                 # Root scene - contains entire game world
├── project.godot             # Godot engine configuration
├── *.md                      # Documentation & design specs
├── *.txt                     # Lore, narrative, and system notes
├── addons/
│   └── spatial_audio_3d/     # Custom 3D audio plugin with raycast reverb
├── ambience/                 # Weather audio loops (rain, wind)
├── fonts/                    # UI fonts (Orbitron, Ubuntu)
├── sfx/                      # Sound effects (currently empty)
└── .godot/                   # Godot editor cache & metadata
```

---

## Core Architecture

### Scene Hierarchy (Main.tscn)

The entire game world is contained within **Main.tscn**, with the following node structure:

```
Main (Node3D)
├── WorldEnvironment           # Volumetric fog, glow, neon ambience
├── CityGenerator             # Procedural 600m x 600m city grid
│   ├── Buildings, roads, sidewalks, streetlights
│   └── Special zones (rivers, parks, plazas)
├── PlayerCar (CharacterBody3D)
│   ├── CarBody (MeshInstance3D)
│   ├── TailLight/HeadLightLeft/HeadLightRight
│   ├── CollisionShape3D
│   └── Camera3D
├── BattleTriggerManager       # Detects combat conditions (B key)
├── BattleSystemManager       # Manages ATB combat encounters
├── CockpitDashboardUI (CanvasLayer)   # First-person HUD
├── DialogueSystem (CanvasLayer)       # Visual novel dialogue overlay (F key / API)
├── TacticalOvermapManager    # Satellite map view (M key)
├── CityVisualEffects         # BPM-synced lighting, glitches
├── WeatherSystem              # Neon rain, cyber snow, clear night
├── DustFogSystem              # Volumetric fog & dust particles
├── MusicPlaylistManager       # Context-aware music
├── WeatherAmbienceManager     # Weather-based ambient audio
├── CarEngineAudio             # 3D spatial engine sound
├── AudioSettingsMenu (CanvasLayer)  # ESC menu, volume controls
├── TrafficSystem              # AI traffic with A* pathfinding
└── PedestrianSystem           # Crowd simulation
```

---

## File Index & Responsibilities

### Core Game Systems

| File | Purpose | Key Features |
|------|---------|--------------|
| **Main.tscn** | Root scene | Scene tree with all subsystems, world environment, lighting |
| **project.godot** | Engine config | Window settings, Godot version, render config |

### Player & Vehicle

| File | Purpose | Key Features |
|------|---------|--------------|
| **PlayerCar.gd** | Vehicle controller | Acceleration, steering, friction, visual body dynamics (banking/tilt), multi-tier camera zoom, 3-stage headlights (H key) |

### World Generation

| File | Purpose | Key Features |
|------|---------|--------------|
| **CityGenerator.gd** | Procedural city | 600m x 600m grid, Broadway (30m) & secondary streets (20m), sidewalks (5m), alleyways (10m), seed-based persistence, special zones (rivers, parks, plazas), corner setbacks, L-tower layouts |
| **CitySceneryProps.gd** | Street props | Streetlights, parking lot floodlights, modular prop generation decoupled from city gen |
| **CityVisualEffects.gd** | Visual effects | BPM-synced emission pulses, power-supply glitch flickers, wave ripples, 4-stage ambient lighting (L key) |

### Combat System

| File | Purpose | Key Features |
|------|---------|--------------|
| **BattleTriggerManager.gd** | Combat detection | Listens for B key, detects encounter conditions, transitions to cockpit view |
| **BattleSystemManager.gd** | Combat orchestration | ATB turn-based loop, enemy targeting, hull damage, camera transitions |
| **CockpitDashboardUI.gd** | Combat UI | Windshield viewport, Orbitron synth-deck panel, ATB meters (Ordnance, ICE-Breaker, Nitrous, Overclock), action buttons |
| **Enemies.gd** | Enemy definitions | Profiles: Corporate Enforcers, Heavy War-Rigs, Hunter Drones, stats, weaknesses, 3D mesh generation |
| **NeuralGlitchSystem.gd** | Paranoia system | Mack's glitch gauge, passive decay, Banquo ghost button spawns (B_ANKES_GHOST.EXE) |
| **DialogueSystem.gd** | Visual novel dialogue overlay | CanvasLayer (layer 20), JSON-driven branching dialogue trees, typewriter animation, cubic-eased panel slide, scanline shader, dynamically styled choice buttons, player movement lock during active dialogue |
| **TacticalOvermapManager.gd** | Map system | M key satellite view, top-right PIP feed (220x140px), camera state preservation |

### Weather & Atmosphere

| File | Purpose | Key Features |
|------|---------|--------------|
| **WeatherSystem.gd** | Weather engine | 3 weather states: Neon Rain, Cyber Snow, Clear Night; R key cycling; 2.5s particle crossfading; 3D collision rain streaks with roof splashes |
| **DustFogSystem.gd** | Atmospheric effects | Volumetric cyber fog, 1800 floating dust specks with lit billboard shading, neon light reflection |

### Audio Systems

| File | Purpose | Key Features |
|------|---------|--------------|
| **CarEngineAudio.gd** | Vehicle audio | 3D spatial AudioStreamPlayer3D, speed-driven pitch/volume, 6-ray building distance reverb estimation, camera line-of-sight low-pass occlusion, routes to "Engine" bus |
| **MusicPlaylistManager.gd** | Music system | 3 playlists: DRIVING, BATTLE, STORY; live BPM metadata emission for beat-synced visuals; context-aware switching; routes to "Music" bus |
| **WeatherAmbienceManager.gd** | Ambient audio | Rain downpours, textural wind breezes, seamless 2.5s crossfading, dynamic "CarCabinAmbience" bus with lowpass filtering & room reverb; routes based on WeatherSystem state |
| **AudioSettingsMenu.gd** | Audio UI | ESC pause menu (PROCESS_MODE_ALWAYS), individual volume sliders: MUSIC, AMBIENCE, ENGINE HUM, SFX |
| **addons/spatial_audio_3d/spatial_audio_3d.gd** | 3D audio plugin | Raycast-driven reverb, distance-based delay, dynamic occlusion, physically-informed spatial audio |

### AI & Population

| File | Purpose | Key Features |
|------|---------|--------------|
| **TrafficSystem.gd** | Vehicle traffic | A* pathfinding on city intersection network, max 6 ambient cars, spawn radius 140m, despawn at 270m, Broadway weight preference, obstacle avoidance with 3-ray whisker system |
| **PedestrianSystem.gd** | Crowd simulation | Neon stick/cylinder figurines, vertex shader animation, sidewalk waypoints, crosswalks, cyber parks, parking lots, panic reactions to honking/gunfire |

---

## Narrative & Lore

### The Setting: "The Spire Grid"

A high-density megastructure grid governed by **Duncan Dynamics**, where city streets serve as both physical transit corridors and data channels for the corporate network. The world is bathed in neon, volumetric fog, and the constant hum of data traffic.

### Main Characters

| Character | Role | Description |
|-----------|------|-------------|
| **Mack (Macbeth)** | Protagonist | Elite corporate enforcer for Glamis District, Director of Cawdor Logistics, usurper of CEO Duncan. Upgraded with experimental combat cyberware and high-bandwidth neural stack. |
| **Lady M (Lady Macbeth)** | Partner | Mack's brilliant, ruthless netrunner partner. Orchestrates security bypasses and ICE hacks. Descends into guilt manifesting as hardware memory-wipe loops. |
| **CEO Duncan** | Antagonist | Polished, patriarchal head of Duncan Dynamics. His assassination triggers a grid-wide power vacuum. |
| **The Norns (3 Witches)** | AI Entities | Rogue, glitching AI living in unmapped web frequencies. Transmit prophecy payloads (#03-NORNS) directly into Mack's neural feed. |
| **Bankes (Banquo)** | Former Ally | Mack's former wingman and telemetry scout. Purged by corporate hit-drones. Haunts Mack's HUD as B_ANKES_GHOST.EXE. |
| **Fleance** | Surviving Son | Bankes' netrunner son who escaped the drone ambush into darknet web traffic. |
| **Macduff** | Antagonist | Elite driver of Fife Security Patrol. Operates an un-networked synth-cyborg chassis ("born of a lab-vat, not of woman"). Leads anti-Mack resistance. |
| **Porter** | NPC | Cynical, glitch-modded grease-monkey operating "The Pit" a subterranean garage. Handles vehicle tuning and black-market cyberware. |

### The 5-Act Campaign Structure

Each Act unfolds through **theatrical Scenes** in **12-15 minute playable chunks**:

**PROLOGUE: "The Unseaming of Sweno"**
- Scene I: Glamis Highway Clearance Intercept Sweno's rebel war-rigs, first ATB battle
- Scene II: The Deep-Web Prophecy Receive #03-NORNS prophecy, 3-stage ATB defense battle

**ACT I: "The Red Handshake in the Pit"**
- Scene I: Zero-Day Reconnaissance Track CEO Duncan's convoy
- Scene II: Substation Power Hijack Navigate pitch-black alleys with LONG high beams
- Scene III: Blackout Assassination Intercept Duncan's limo, cockpit ATB boss duel

**ACT II: "Ghost-Code & Thermal Drift"**
- Scene I: The Purge of Bankes Order drone hit on Bankes, Fleance escapes
- Scene II: The Phantom Banquet HUD suffers thermal corruption, B_ANKES_GHOST.EXE appears
- Scene III: Sector Stabilization Secure Cawdor nodes while managing HUD static

**ACT III: "The Descent into Thermal Runaway"**
- "Double, double toil and trouble; fire burn, and cauldron bubble."

**ACTS IV & V**: Continue the downward spiral with more neural degradation and corporate warfare.

### Current Game State

- **Current Status**: Director of Cawdor Logistics
- **Neural Integrity**: 68% (THERMAL WARNING: RUNAWAY IMMINENT)
- **Active Subroutine**: CONSPIRACY_OVERRIDE.EXE [RUNNING]
- **Active Mission**: Prepare vehicle at The Pit for incoming Birnam Purge invasion
- **Objective**: Hardware diagnostic, load Ordnance upgrades, hold central highway

---

## Gameplay Mechanics

### Driving Controls

| Key | Action |
|-----|--------|
| W/S | Accelerate/Reverse |
| A/D | Steer Left/Right |
| Mouse Wheel | FOV Zoom (35 to 150 degrees) |
| H | Cycle headlights: OFF -> NEAR (35m) -> LONG (90m) |
| M | Toggle satellite overhead map view |
| L | Cycle lighting: Normal (100%) -> Low Light (25%) -> Dim (5%) -> Dark Buildings/Lit Grid -> Pitch Black |
| R | Cycle weather: Neon Rain -> Cyber Snow -> Clear Night |
| B | Trigger battle encounter |
| ESC | Audio settings menu |
| 1/2 | Decrease/Increase city seed (regenerate city) |

### Combat System (ATB - Active Time Battle)

Inspired by **Final Fantasy VI** and **Dungeon Master**:

**Dashboard Modules = Party Members:**
- **Driver's Wheel**: Evasion/Positioning
- **Ordnance Array**: Offense/Weapons (fast recharge ATB)
- **Netrunner Deck / Lady M's Uplink**: Tech/Hacks (ICE-Breaker keypad for status effects)
- **Engine/Core**: Buffs/Overclocking/Defense

**Actions:**
- **Gatling/EMP Toggle**: Standard attack, fast ATB recharge
- **ICE-Breaker Keypad**: Black magic/hacks Data Leak, Steering Jam, System Reboot
- **Nitrous Booster**: Defensive stance, dodges heavy attacks, long cooldown
- **Overclock Lever**: Limit break, massive damage, fills Paranoia/Glitch Gauge

**The Paranoia Twist:**
As Mack uses hacks and overclocks (or takes damage), his neural interface degrades:
- Dashboard buttons scramble, labels shift to gibberish
- Ghost buttons (Banquo's ghost) appear as false targets
- Visual distortions: phantom enemies in windshield view

### City Boundaries & Rules

| Zone | Size | Purpose |
|------|------|---------|
| Full Grid | +/-300m (600m x 600m) | Ground wireframe grid |
| Skyscraper Blocks | +/-220m | Building boundaries |
| AI Entity Clamping | +/-250m | Ambient cars and pedestrians turn around/despawn here |
| Player Freedom | Unlimited | PlayerCar can drive beyond city boundaries to highway exit gates |

**Future Feature: Inter-City Exit Gates**
- 4 highway toll gates at North, South, East, West perimeters
- Driving through triggers high-speed highway travel between city seeds/districts:
  - Glamis District
  - Cawdor Logistics
  - Fife Security Zone
  - Dunsinane Spire Core

---

## Audio Architecture & Guidelines

The project uses a structured audio bus routing system:

### 1. 3D Spatial Acoustic System (CarEngineAudio.gd)
* **Vehicle & Player-Emitted Sounds**: All sounds emitted by or attached to the player vehicle (such as engine hum, future car weapon sound effects, car collisions, and localized vehicle SFX) **MUST** utilize our custom 3D acoustic system implemented in **CarEngineAudio.gd**.
* **Key Features**:
  * AudioStreamPlayer3D attached directly to the player vehicle (PlayerCar).
  * Speed-driven pitch shifting and exponential volume interpolation.
  * Real-time acoustic environment raycasting (samples nearby building geometry to adjust AudioEffectReverb wetness and room echo in narrow city streets).
  * Line-of-sight camera occlusion raycasting (dynamically applies AudioEffectLowPassFilter when buildings block line of sight between the camera and vehicle).
* **Audio Bus**: Routes to the custom "Engine" audio bus.

### 2. Standard 2D Ambient & Global Audio Channels
* **Music Playlist Manager (MusicPlaylistManager.gd)**:
  * Context-aware playlist management ("DRIVING", "BATTLE", "STORY").
  * Emits real-time BPM metadata for beat-synced visual glitches.
  * **Audio Bus**: Routes to the "Music" audio bus.
* **Weather Ambiance Manager (WeatherAmbienceManager.gd)**:
  * Controls rain downpours and textural wind breezes with seamless crossfading based on state from WeatherSystem.gd.
  * Dynamically creates the "CarCabinAmbience" audio bus with lowpass filtering and tight interior reverb to simulate listening from inside the car cabin.
  * **Audio Bus**: Routes to the "CarCabinAmbience" bus.

### 3. UI Audio & Settings Menu (AudioSettingsMenu.gd)
* **AudioSettingsMenu.gd**:
  * Toggled via ESC key.
  * Operates with PROCESS_MODE_ALWAYS so sliders and inputs remain interactive while game tree is paused.
  * Features individual volume sliders for **MUSIC**, **AMBIENCE**, **ENGINE HUM**, and **SFX**.

---

## Development Documentation

### Design Documents

| File | Purpose | Contents |
|------|---------|----------|
| **lore and ideas.md** | Master lore document | Complete 5-act campaign, all character profiles, scene descriptions, future plans |
| **the story so far.txt** | Narrative summary | Current story state, recovered logs, active mission |
| **CodingStructureRules.md** | Architecture rules | Modularization principles, naming conventions, coding standards |
| **CityPopulationPlan.md** | AI systems design | Traffic architecture, pedestrian design, boundary rules, exit gates |
| **battle system.txt** | Combat design | ATB mechanics, dashboard interaction, paranoia system |
| **next update update 5** | TODO notes | Traffic de-randomization plans, city filling requirements |

### Key Architecture Principles (from CodingStructureRules.md)

1. **Strict Modularization**
   - Every feature exists in its own dedicated script file
   - Zero "god scripts" or monoliths
   - Core city generator and driving engine remain decoupled from visual effects, weather, or combat

2. **Descriptive Naming**
   - Variables must be highly expressive and domain-specific
   - Avoid generic names: data, temp, manager, obj, quad_mesh, streak_mat
   - Use: cockpit_hud_overlay, cyber_rain_streak_quad_mesh, neural_glitch_potency

3. **Explicit Numbers**
   - Key tweaking numbers exposed via @export variables at script tops
   - Document vectors, RGB colors, array indices with inline comments

4. **Preserve User Settings**
   - Save original camera FOV, offset, pitch when changing views
   - Restore perfectly upon exit

5. **Separate Narrative Files**
   - All story, dialogue, mission briefings in dedicated .txt/.md files
   - Never hardcode narratives in GDScript

---

## Technical Specifications

### City Metrics (CityGenerator.gd)

| Parameter | Value | Description |
|-----------|-------|-------------|
| city_size_x | 600.0m | Total city width (X axis) |
| city_size_z | 600.0m | Total city depth (Z axis) |
| main_broadway_width | 30.0m | Central avenue (3 grid lanes) |
| secondary_street_width | 20.0m | Side streets (2 grid lanes) |
| sidewalk_width | 5.0m | Sidewalk inset (half grid tile) |
| alley_width | 10.0m | Gap between buildings (1 grid lane) |
| city_seed | Configurable | Procedural generation seed (0 = random) |

### Grid System
- **Alignment**: Strict 10m grid alignment
- **Lanes**: 2-lane roads standard
- **Sidewalks**: Discrete grey sidewalk slabs with glowing curbs
- **Blocks**: Monotony broken with corner plazas and L-tower setbacks

### Traffic System (TrafficSystem.gd)

| Parameter | Value | Description |
|-----------|-------|-------------|
| max_ambient_cars | 6 | Maximum simultaneous traffic vehicles |
| spawn_radius_distance | 140m | Distance from player to spawn cars |
| despawn_radius_distance | 270m | Distance from player to despawn cars |
| base_traffic_speed | 12.0 | Base vehicle speed |

**Vehicle Archetypes:**
1. **Commuter Pods**: Compact, dim neon taillights, strictly obey lanes
2. **Corporate Haulers**: Large 6-wheel trucks, glowing side banners, slow-moving
3. **Enforcer Patrols**: High-contrast cyan/magenta, roof sirens, neutral until provoked

### Pedestrian System (PedestrianSystem.gd)

**Mesh Design:**
- Lightweight 3D stick/cylinder figurines
- Glowing neon emission materials (Cyan, Hot Pink, Amber)
- Vertex shader-driven leg swing animation

**AI Behavior:**
- Walks along sidewalks, crosswalks, cyber parks, parking lots
- **Normal**: Casual walking between waypoints
- **Horn Reaction**: Halts or turns when player honks
- **Combat Panic**: Scatters toward building entrances or tree cover on gunfire/high-speed

### Weather States (WeatherSystem.gd)

| State | Description | Visual Effects |
|-------|-------------|----------------|
| NEON_RAIN | Rainy conditions | Chaotic wind angles, roof collision, splash sub-emitters |
| CYBER_SNOW | Snowy conditions | Particle-based snowfall |
| CLEAR_NIGHT | Clear weather | Default city ambience |

**Transition**: R key cycles through states with 2.5s crossfading

### Lighting States (CityVisualEffects.gd)

| State | Key | Ambient Intensity | Description |
|-------|-----|-------------------|-------------|
| Normal | N/A | 100% | Full city illumination |
| Low Light | L | 25% | Reduced visibility |
| Dim | L (x2) | 5% | Very dark |
| Dark Buildings/Lit Grid | L (x3) | 0%/5% | Buildings dark, grid lit |
| Pitch Black | L (x4) | 0% | Total darkness |

---

## Current Development Focus

Based on **next update update 5** and recent commits:

### Immediate Priorities

1. **Traffic System Refinement**
   - De-randomify car spawning
   - Replace ambient spawning with predetermined safe locations
   - Give cars "today's plan" pre-mapped routes
   - Remove random ambient spawning
   - Spawn ~6 cars with established paths within city bounds

2. **City Layout**
   - City now fills the **entire grid bounds** (600m x 600m)
   - Break up block monotony with **corner plazas** and **L-tower setbacks**
   - Strict **10m grid alignment** rules enforced
   - **2-lane roads** standard
   - Discrete **grey sidewalk slabs** with **glowing curbs**

3. **Visual Polish**
   - Volumetric fog density balanced
   - Light energy levels tuned for clear visibility

### Recent Commits

```
5d9bc9c - Expand city layout to full grid bounds and break up block monotony
           with corner plazas and L-tower setbacks

a1c778a - Implement strict 10m grid alignment rules, 2-lane roads, and discrete
           grey sidewalk slabs with glowing curbs

0385b26 - Tune volumetric fog and light energy to a balanced medium state
7ac3608 - Balance volumetric fog density and light energy levels
3c95da4 - Fix Environment volumetric_fog_albedo property name
```

---

## Working with This Project

### For AI Assistants & Contributors

**Quick Start:**
1. Open Main.tscn in Godot 4 to see the complete game world
2. Read CodingStructureRules.md before making any code changes
3. All new features should be **modular** one script per feature
4. Use **descriptive naming** no generic variables
5. Expose tweakable parameters via @export at script tops

**Testing Systems:**
- Press **1/2** keys to cycle through city seeds
- Press **R** to cycle weather states
- Press **L** to cycle lighting levels
- Press **M** to toggle satellite map view
- Press **H** to cycle headlight modes
- Press **B** to trigger battle encounter
- Press **ESC** to open audio settings

**Important Constraints:**
- Do NOT modify CityGenerator.gd core logic without understanding the full system
- Do NOT couple visual effects to driving physics
- DO preserve camera state when switching views
- DO keep narrative content in separate .txt/.md files

### File Modification Priority

| Priority | Files | Reason |
|----------|-------|--------|
| HIGH | TrafficSystem.gd, CityGenerator.gd | Core city population and navigation |
| HIGH | BattleSystemManager.gd, CockpitDashboardUI.gd | Combat is central to gameplay |
| MEDIUM | WeatherSystem.gd, DustFogSystem.gd | Atmosphere and immersion |
| MEDIUM | CarEngineAudio.gd, MusicPlaylistManager.gd | Audio is a key feature |
| LOW | AudioSettingsMenu.gd, TacticalOvermapManager.gd | UI polish |
| LOW | NeuralGlitchSystem.gd, Enemies.gd | Combat depth and story integration |

---

## Asset Inventory

### Audio Files (ambience/)

| File | Size | Format | Purpose |
|------|------|--------|---------|
| QP03 0303 Rain downpour fluctuates | ~17MB | WAV/MP3/OGG | Rain ambience |
| WIND_Winds Textural Breeze Light Debris | ~6MB | WAV/OGG | Wind ambience |

**Note**: Godot import files (.import) are auto-generated do not edit manually

### Fonts (fonts/)

| Directory | Font | Purpose |
|-----------|------|---------|
| Orbitron/ | Orbitron | Dashboard UI, tech displays |
| Ubuntu/ | Ubuntu | General UI text |

### Plugins (addons/)

| Plugin | File | Purpose |
|--------|------|---------|
| Spatial Audio 3D | spatial_audio_3d.gd | Physically-informed 3D audio with raycast reverb and occlusion |

---

## Project Goals & Vision

### Short-Term Goals
1. Verified: Procedural city generation (600m x 600m)
2. Verified: Vehicle physics with visual body dynamics
3. Verified: Dynamic weather system with audio
4. Verified: 3D spatial audio with raycast reverb
5. Verified: Cockpit combat UI foundation
6. In Progress: Traffic system with A* pathfinding
7. In Progress: Pedestrian crowd simulation
8. Next: Complete ATB combat mechanics
9. Next: Narrative scene progression
10. Next: Inter-city travel system

### Long-Term Vision
- Full 5-act campaign following Macbeth's rise and fall
- Multiple city districts with unique seeds and themes
- Deep neural glitch system affecting gameplay
- Multiplayer co-op (Lady M as second player)
- Mod support for custom city seeds and vehicles

---

## Quick Reference for Common Tasks

### Adding a New Feature
1. Create a new .gd script file with descriptive name
2. Add to Main.tscn as a child node if it needs scene access
3. Follow CodingStructureRules.md naming conventions
4. Expose parameters via @export at the top
5. Document the module in this context.md

### Adding New Audio
1. Place files in ambience/ or sfx/
2. Import via Godot (creates .import file automatically)
3. Route to appropriate audio bus
4. Update WeatherAmbienceManager.gd or MusicPlaylistManager.gd as needed

### Modifying City Layout
1. Edit parameters in CityGenerator.gd top section
2. Test with different seeds using **1/2** keys
3. Ensure all systems respect the new boundaries
4. Update TrafficSystem.gd spawn/despawn radii if needed

### Testing Combat
1. Press **B** key to trigger battle encounter
2. Combat transitions to cockpit view
3. ATB gauges fill over time
4. Use dashboard modules to execute actions
5. Press **B** again to exit combat

---

## Index of All Files

### GDScript Files (19 total)
1. AudioSettingsMenu.gd
2. BattleSystemManager.gd
3. BattleTriggerManager.gd
4. CarEngineAudio.gd
5. CityGenerator.gd
6. CitySceneryProps.gd
7. CityVisualEffects.gd
8. CockpitDashboardUI.gd
9. DustFogSystem.gd
10. Enemies.gd
11. Main.tscn
12. MusicPlaylistManager.gd
13. NeuralGlitchSystem.gd
14. PedestrianSystem.gd
15. PlayerCar.gd
16. TacticalOvermapManager.gd
17. TrafficSystem.gd
18. WeatherAmbienceManager.gd
19. WeatherSystem.gd

### Godot Configuration
- project.godot
- .godot/ (editor cache)

### Documentation
- CodingStructureRules.md
- CityPopulationPlan.md
- context.md (this file)
- lore and ideas.md
- the story so far.txt
- battle system.txt
- next update update 5

### Assets
- ambience/ (4 audio files + imports)
- fonts/Orbitron/
- fonts/Ubuntu/
- sfx/ (empty, ready for SFX)
- addons/spatial_audio_3d/ (3 files)

---

## Final Notes

**This is a passion project** blending Shakespearean tragedy with cyberpunk aesthetics and modern game design. The codebase is **well-structured**, **modular**, and **well-documented** making it an excellent foundation for both learning and contribution.

**Key Strengths:**
- Clean architecture with strict separation of concerns
- Comprehensive documentation at every level
- Working prototype with multiple verified systems
- Rich narrative framework ready for implementation
- Unique blend of driving, combat, and story

**Areas for Growth:**
- Combat system completion
- Narrative scene implementation
- Additional audio content (SFX)
- Visual polish and particle effects
- Performance optimization for larger cities

---

**Last Updated**: August 5, 2026  
**Project Status**: Active Development  
**Godot Version**: 4.7 (as per project.godot)  
**Main Scene**: res://Main.tscn

*For the most current information, always check the git commit history and the individual script files.*
