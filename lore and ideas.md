# CYBERPUNK MACBETH: LORE & DEVELOPMENT ROADMAP


todo:
all dialogue things should be in json files simialr to the one that is triggered by the letter "t"

- Dialogs & Dialogue Editor:
  - Add a "Familiarity" threshold for dialogue lines (e.g. initial talk with NPC like Mr. Dodgy has Familiarity = 1; npc won't offer missions until familiarity is higher).
  - Add dialogue "Familiarity Score Modifier" per line (+1, +2, max +5).
- Battle Editor & Loadout Grid System:
  - Add a "Simulate Now" instant test button to jump straight into combat simulations.
  - Visual Grid Slot Equipment UI for both MACK (Cyborg cyberware, primary/secondary weapons, neural augmentations, subdermal armor) and his VEHICLE (turrets, plating, nitro boost modules, ECM countermeasure pods).
  - Clearly shows total available slots, locked/unlocked slots, and currently equipped loadout items with stat bonuses/glitch penalties.
  - Full interactive equipment/tuning available in The Pit (Porter's black-market tuning garage) and directly inside the Battle Editor.
  - Live active loadout slot monitoring reflected on the Cockpit Dashboard / Combat HUD.

- Timed Missions & Penalties:
  - Timed mission pop-ups must include a countdown timer that automatically fails the mission when it reaches 0.
  - Add mission failure penalties options: fee to pay, faction score penalty / lower liking, or mission giver's familiarity score reduction.
- Missions & Familiarity:
  - Missions must have a "Familiarity Needed" threshold (lowest level missions unlocked first, exclusive ones unlocked later).
- Vehicle Controls & Audio:
  - Hold Shift to speed up/boost in the player car.
  - Skidding sound effect for sharp turns at high speeds.
  - Short tire skid audio effect when accelerating from a stop/low speed.
- Dynamic Day-Night Lighting Cycle:
  - Day start at Stage 3 (DIM 5% - early dawn), easing to Stage 2 (LOW_LIGHT 25%) and Stage 1 (NORMAL 100% - peak day).
  - After Mack's daily Grand Battle, drop down to Stage 2 (LOW_LIGHT 25% - dusk).
  - After daily available side missions/quests are exhausted, drop down to Stage 3 (DIM 5% - deep night).
  - Stages 4 (DARK_BUILDINGS) and 5 (PITCH_BLACK) remain dedicated to special narrative/ambush/blackout events.

- 💡 Story & Mission Idea: Banquo Takes the Wheel of the War-Rig:
  - In a pivotal mid-game / emergency mission, Mack is incapacitated, undergoing black-market cyberware surgery, or ambushed off-grid.
  - Banquo must physically take the driver's seat of Mack's heavy dreadnought War-Rig ("WAR-RIG EXECUTOR") to smash through a corporate blockade, extract high-value convoy cargo, or rescue Fleance.
  - Banquo gets to unleash the War-Rig's heavy kinetic cannons, pneumatic ramming overdrive, and dual roof turrets firsthand from the cockpit, giving the player direct control over the monstrous war-machine!

- 🥊 Gameplay Feature: Banquo's On-Foot Man-vs-Man Fighting System:
  - Third-person / close-quarters melee combat system when exploring the city streets, alleys, and indoor interior floors on foot.
  - Features: Punch/kick combos, dodges/rolls, cybernetic sidearm draws, stamina management, impact SFX, and target lock-on against hostile syndicate thugs, assassins, and security guards.




also:
Well, acktually: to make this system far more scalable, readable, and performant, the biggest win lies in moving away from a single monolithic script (PedestrianSystem.gd) that handles generation, state management, movement, geometry checks, array filtering, and UI dialogue for every archetype.  Here are the key structural improvements for refactoring:1. Extract Archetypes into Dedicated State Classes or Sub-NodesRight now, _process and _update_archetype_behaviors iterate through separate tracking arrays (active_pedestrians, active_park_dancers, active_fixers, etc.) and branch using meta-variables.  The Refactor: Create a base PedestrianAgent class (extending CharacterBody3D) with its own internal State Machine (or State pattern sub-nodes).Why: Each agent handles its own physics, timer updates, and state transitions locally (_physics_process). PedestrianSystem transitions into a clean manager/factory responsible solely for spawning, pooling, and spatial distribution.  res://
├── scripts/
│   ├── pedestrian_system.gd       # Manager & Pooling only
│   ├── agents/
│   │   ├── pedestrian_agent.gd    # Base Agent (Movement, Flashlight, Health)
│   │   ├── states/
│   │   │   ├── state_idle.gd
│   │   │   ├── state_walk.gd
│   │   │   ├── state_evade.gd
│   │   │   └── state_queue.gd
2. Replace Direct Meta Checking with Strongly Typed Data & EnumsThe system currently relies heavily on string dictionary keys and untyped metadata via set_meta() and get_meta() (e.g., get_meta("is_tipsy_stumbler"), get_meta("stroll_state")).  The Refactor: Replace metadata dictionaries with strongly typed @export properties or custom Resource definitions (PedestrianArchetypeData).Why: Type safety prevents silent runtime typo bugs, improves autocomplete performance in GDScript, and reduces the memory overhead of GDScript Variant metadata dictionaries.

3. Replace Raycasts in _process with Spatial Collision TriggersDuring rain or shelter-seeking, every pedestrian casts 8 raycasts in 360 degrees every single frame:  GDScript# Current implementation runs 8 raycasts per active pedestrian per frame
for check_angle in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
    var query = PhysicsRayQueryParameters3D.create(...)
    var result = space_state.intersect_ray(query)
The Refactor: Place Area3D nodes ("Shelter Zones") under building overhangs and bus stops.Why: Instead of hundreds of physics raycasts per frame across the crowd, pedestrians simply query the nearest ShelterZone center or respond when entering/exiting an Area3D trigger, eliminating frame drops during weather transitions.

4. Decouple Dialogue Trees into Data Resources (.tres or JSON)Currently, complex dialogue dictionaries like Mr. Dodgy's and the Gang Leader's are built inline as hardcoded dictionaries inside PedestrianSystem.gd.  The Refactor: Extract dialogue into standalone JSON files or custom DialogueResource assets.Why: Keeps code clean and allows you to edit or localize dialogue without modifying NPC logic.

5. Use Multimesh / Server-Driven rendering for distant crowdsIf you plan to scale the crowd size beyond 50+ simultaneous pedestrians, individual Node3D hierarchies (Body + Head + Flashlight + SpotLight) will eventually hit node graph processing limits.  The Refactor: Group low-priority distant pedestrians into a MultiMeshInstance3D or handle movement directly on the RenderingServer and PhysicsServer3D.










A synthwave/cyberpunk 3D arcade driving & tactical combat adaptation of Shakespeare’s *Macbeth*, built in **Godot 4**.

---

## 1. COMPLETED IMPLEMENTATIONS (VERIFIED STATUS)

The following systems are **fully implemented, verified, and operational** in the codebase:

### 🏙️ World & Environment
* **Procedural City Generation (`CityGenerator.gd`)**: 600m × 600m neon skyscraper grid, roads, avenues, streetlights, and building window emission textures.
* **City Lighting & Visual Effects (`CityVisualEffects.gd`)**: BPM-synced emission pulses, power-supply glitch flickers, wave ripples, and multi-stage ambient lighting (`L` key: Normal 100%, Low Light 25%, Dim 5%, Dark Buildings/Lit Grid 0%/5%, Pitch Black 0%).
* **Atmospheric Systems (`WeatherSystem.gd`, `DustFogSystem.gd`)**: Dynamic volumetric neon fog, floating interactive dust specks, and multi-weather state particle engines (Neon Rain, Cyber Snow, Clear Night) with smooth 2.5s visual particle crossfading (`R` key).

### 🚗 Vehicle & Driver Physics (`PlayerCar.gd`)
* **Vehicle Controller**: Forward/reverse acceleration, braking, friction, and responsive steering.
* **Visual Body Dynamics**: Real-time chassis leaning/banking roll (`rotation.z` up to 8.5°) into corners and nose pitch lift/dip (`rotation.x` up to 4.0°) during acceleration/braking.
* **Multi-Stage Headlights**: 3-stage `SpotLight3D` system (`H` key: OFF, NEAR Low Beam at 35m, LONG High Beam at 90m) with high-intensity mesh emission and exported beam length/cone/energy parameters.
* **Multi-Tier Camera System**: Mouse wheel FOV zoom, camera pitch shifts, overhead map mode (`M` key), and Picture-In-Picture (PIP) live feed.

### 🎵 3D Acoustics & Dynamic Audio
* **3D Engine Sound & Spatial Acoustics (`CarEngineAudio.gd`)**: Car-attached `AudioStreamPlayer3D` with speed-driven pitch and volume scaling, real-time 6-ray building distance reverb estimation, and camera line-of-sight low-pass occlusion.
* **Audio Routing & Master Menu (`AudioSettingsMenu.gd`)**: `ESC` pause menu with individual volume sliders for Music, Ambience, Engine Hum, and SFX.
* **Ambiance & Music (`MusicPlaylistManager.gd`, `WeatherAmbienceManager.gd`)**: Context-aware playlist management with BPM metadata emission and interior car cabin acoustics (`CarCabinAmbience` bus with lowpass & room reverb).

### ⚔️ Battle & UI Systems
* **Battle Engine (`BattleSystemManager.gd`, `BattleTriggerManager.gd`)**: Encounter trigger detection and transition pipeline into cockpit combat.
* **Cockpit Dashboard UI (`CockpitDashboardUI.gd`)**: First-person windshield viewport framing, Ordnance, ICE-Breaker, Nitrous, and Overclock ATB meters.

---

## 2. WORLD LORE & NARRATIVE ARCHITECTURE

### The Setting: "The Spire Grid" & Duncan Dynamics
The city is an all-encompassing, high-density megastructure grid governed by **Duncan Dynamics**, the megacorporation controlling all power, infrastructure, and neural bandwidth. The city streets serve as both physical transit corridors and data channels for the corporate network.

### Character Profiles
* **Mack (Macbeth)**: Elite corporate enforcer for Glamis District, promoted to Director of Cawdor Logistics, and ultimately usurper of CEO Duncan. Upgraded with experimental combat cyberware and a high-bandwidth neural stack, Mack's ambition triggers severe thermal runaway and hardware paranoia.
* **Lady M (Lady Macbeth)**: Mack’s brilliant, ruthless netrunner partner. She orchestrates security bypasses and ICE hacks remotely from the vehicle's cockpit deck. Her descent into guilt manifests as a hardware memory-wipe loop ("Out, damn virus!") trying to scrub phantom data-fluid from her implants.
* **CEO Duncan**: The polished, patriarchal head of Duncan Dynamics whose assassination in The Pit triggers a grid-wide signal surge and corporate power vacuum.
* **The Norns (The 3 Witches)**: Anarchistic freelance hackers and netrunners operating from deep darkweb nodes. Unpredictable and unaligned, they play all corporate sides against each other while transmitting cryptic prophecy payloads (`#03-NORNS`) into Mack's neural feed.
* **Bankes (Banquo)**: Mack’s former wingman and telemetry scout. After being purged by corporate hit-drones to protect the conspiracy, Bankes’ corrupted backup haunts Mack's HUD as `B_ANKES_GHOST.EXE`, spawning phantom target markers.
* **Fleance**: Bankes' netrunner son who escaped the drone ambush into darknet web traffic.
* **Macduff**: Elite driver of the Fife Security Patrol. Operating an un-networked synth-cyborg chassis ("born of a lab-vat, not of woman"), Macduff lead the anti-Mack resistance.
* **Porter**: A cynical, glitch-modded grease-monkey operating **"The Pit"**—a subterranean, off-grid garage beneath the central highway. Porter handles vehicle tuning, black-market cyberware, and provides dark, rhythmic street commentary as Mack’s sanity unravels.

### 🦅 Street Gangs & Turf Syndicate Archetypes
* **The Red Crows (Crimson Red)**: The standard baseline street gang controlling central parking lot territories. Balanced in speed and strength, fiercely territorial.
* **The Blue Seagulls (Cobalt Blue)**: Heavyweight armored street syndicate. Slower pacing, high physical resilience, and brutal close-quarters defense.
* **The Yellow Hawks (Amber Gold)**: Lightning-fast, nimble cyber-runners. High speed and agile flank tactics along highway overpasses.
* **The Toxic Vipers (Acid Green)**: Bio-modded street alchemists specializing in neural toxins and illegal cyberware modifications.

### 🚨 Police Cordon & District Blockade System (Crime Scene Quarantine)
* **Dynamic City Blockades**: Certain city blocks or street corridors can be locked down by Fife Security Patrol / Police barricades following high-profile murders, corporate assassinations, or gang turf wars.
* **Access & Bypass Mechanics**:
  1. **Police Faction Standing**: If your reputation with the Police / Fife Security Patrol is high enough (e.g. Faction Standing Level 2+), patrol officers at the checkpoint wave you right through the barrier.
  2. **Bribe & Cyber-Credits**: Pay off the guard officer with cash / cyber-credits via dialogue to temporarily disable security scanners ("Look the other way for 300 Credits").
  3. **Stealth & Vehicle Infiltration**: Slip past patrol scanner cones on foot using shadow alleyways, or hack checkpoint barrier gates remotely using Lady M's ICE-Breaker modules.

### 📐 Indoor Tactical Top-Down View (Cyber Blueprint / Heist Mode)
* **Seamless Transition**: Entering a building interior seamlessly switches the viewport to a stylized, high-contrast **Tactical Blueprint Top-Down View**.
* **Iconographic Symbols**:
  - **Characters / Guard Patrols**: Glowing red/cyan direction cones & movement paths.
  - **Environment Objects**: High-contrast icons for heavy furniture/desks (half-cover), concrete pillars (full-cover), security doors, terminal hacking nodes, and elevator shafts.
* **Tactical & Stealth Gameplay**: Perfect for stealth infiltration, planning heist routes, avoiding guard vision cones, and hacking doors/elevators via Lady M's neural link before bursting into corporate offices.

---

## 3. THE THEATRICAL 5-ACT CAMPAIGN (SCENES & PLAYABLE CHUNKS)

Presented as a 5-Act synth-opera, each Act unfolds through **theatrical Scenes** structured into bite-sized **~12-15 minute playable chunks** (Briefing at The Pit → Grid Pursuit → Cockpit ATB Encounter → Mod-Shop Curtain Call):

---

### PROLOGUE: "THE UNSEAMING OF SWENO"
*"Fair is foul, and foul is fair: hover through the fog and filthy air."*

* **Scene I: Glamis Highway Clearance (~15 min)**
  * *Stage Cue*: Central avenue under heavy `NEON_RAIN`.
  * *Action*: Briefing at The Pit → Intercepting Sweno's rebel war-rigs → Scout drone skirmish → First-person ATB battle executing the rebel commander.
* **Scene II: The Deep-Web Prophecy (~12 min)**
  * *Stage Cue*: Subterranean tunnel network.
  * *Action*: Cooling engines in dark lower tunnels → Receiver intercepts neural packet `#03-NORNS` → 3-stage ATB defense grid battle → The 3 Norns broadcast the prophecy of Cawdor and the CEO seat.

---

### ACT I: "THE RED HANDSHAKE IN THE PIT"
*"Is this a laser-dagger which I see before me, the handle toward my hand?"*

* **Scene I: Zero-Day Reconnaissance (~15 min)**
  * *Stage Cue*: City in `LOW_LIGHT` (25% ambient intensity).
  * *Action*: Tracking CEO Duncan's obsidian convoy route → Testing corporate security feeds → Skirmish with executive outriders.
* **Scene II: Substation Power Hijack (~15 min)**
  * *Stage Cue*: Grid power severed by Lady M; district drops to `PITCH_BLACK` (0% light).
  * *Action*: Navigating pitch-black alleys relying strictly on `LONG` High Beams → Clearing automated perimeter turrets.
* **Scene III: Blackout Assassination (~18 min)**
  * *Stage Cue*: Subterranean garage at The Pit in total darkness.
  * *Action*: Intercepting Duncan's limo → High-stakes Cockpit ATB boss duel executing CEO Duncan as glowing crimson data-fluid spills across the asphalt → Lady M frames Duncan's guards.

---

### ACT II: "GHOST-CODE & THERMAL DRIFT"
*"O, full of scorpions is my mind, dear wife!"*

* **Scene I: The Purge of Bankes (~15 min)**
  * *Stage Cue*: High-speed midnight pursuit.
  * *Action*: Ordering a black-market drone hit on Bankes' patrol to secure Mack's succession → Top-down intercept → Drone squad battle (Fleance escapes into web traffic).
* **Scene II: The Phantom Banquet (~15 min)**
  * *Stage Cue*: High-rise executive sector; HUD experiences severe packet loss.
  * *Action*: Executive banquet celebration → Mack's neural link suffers thermal corruption → `B_ANKES_GHOST.EXE` infects the HUD, overlaying false radar blips and ghost targets during a high-stakes corporate intercept.
* **Scene III: Sector Stabilization (~15 min)**
  * *Stage Cue*: Cawdor Logistics district.
  * *Action*: Securing Cawdor nodes while managing escalating HUD static and phantom target hallucinations.

---

### ACT III: "THE DESCENT INTO THERMAL RUNAWAY"
*"Double, double toil and trouble; fire burn, and cauldron bubble."*

* **Scene I: Darkweb Re-Connect (~15 min)**
  * *Stage Cue*: Deep-web grid sector under heavy `CYBER_SNOW`.
  * *Action*: Forcing a deep-web link with The Norns → ATB battle receiving the 3 warnings (*"Beware Macduff"*, *"None born of organic womb"*, and *"Birnam Malware"*).
* **Scene II: The Fife Node Raid (~15 min)**
  * *Stage Cue*: Fife district under torrential `NEON_RAIN`.
  * *Action*: Scorched-earth strike destroying Macduff's node network and family registry.

---

### ACT IV: "THE MEMORY-WIPE LOOP"
*"Out, damned spot! out, I say! One: two: why, then, 'tis time to do't."*

* **Scene I: Hardware Diagnostic at The Pit (~12 min)**
  * *Stage Cue*: The Pit garage (Current Game Start Location).
  * *Action*: Hardware diagnostic check → Installing heavy Ordnance and heat-sinks while Lady M loops in memory-wipe panic ("Out, damn virus!").
* **Scene II: Perimeter Defense & Trap Deployment (~15 min)**
  * *Stage Cue*: Central highway barricades in `DARK_BUILDINGS` mode (0% buildings, 5% road grid).
  * *Action*: Fortifying central highway nodes against incoming resistance probes.

---

### ACT V: "THE BIRNAM PURGE & SYSTEM MELTDOWN"
*"Lay on, Macduff, and damn'd be him that first cries, 'Hold, enough!'"*

* **Scene I: Birnam Malware Highway Standoff (~15 min)**
  * *Stage Cue*: Central Highway overwhelmed by rogue drone war-rigs.
  * *Action*: Macduff & Malcolm launch **The Birnam Purge**—a massive, self-replicating swarm of drone war-rigs marching down the Central Highway.
* **Scene II: Macduff Final Boss Duel (~20 min)**
  * *Stage Cue*: Spire Grid Summit; Mack's neural stack hits catastrophic hardware meltdown.
  * *Action*: Climax duel against Macduff's un-networked synth-cyborg war-rig (immune to Lady M's ICE hacks), fought in first-person cockpit view as Mack's empire collapses into static.

---

## 4. DYNAMIC MISSION MECHANICS & SCENARIOS

### ⚡ Grid Blackout & Network Hijack Missions
* **The Grid Power Lockdown**: Missions starting in `PITCH_BLACK` mode where players must navigate dark avenues relying strictly on `LONG` High Beams.
* **Grid Hijack Holdout**: Stationary defense while Lady M breaches a mainframe. The city flickers between `PITCH_BLACK`, `DARK_BUILDINGS`, and `DIM` modes during security countermeasures.

### 🌧️ Extreme Weather Operations
* **Blizzard Stealth Infiltration**: Heavy `CYBER_SNOW` with volumetric fog density maxed out. Sound is occluded by snow walls; players use 3D engine acoustics to detect approaching heavy war-rigs.
* **Downpour Hydroplane Pursuit**: High-speed chase under `NEON_RAIN`. Road surfaces gain specular reflection puddles, requiring chassis banking roll (`rotation.z`) control.

### 🕵️ Stealth & Reconnaissance Scenarios
* **Low-Emissions Silent Cruise**: Headlights `OFF` and low engine idling (`-1.0` semitone pitch floor) to slip past automated corporate perimeter turrets.
* **Building Line-of-Sight Evasion**: Breaking camera line-of-sight behind skyscraper corners to trigger low-pass occlusion filter (`1200 Hz`), breaking enemy missile locks before entering cockpit combat.

---

## 5. CAR CUSTOMIZATION & UPGRADE SYSTEM ("THE PIT")

### 🎨 Cosmetic & Aesthetic Customization (Small Upgrades)
* **Custom Body Paint & Holographic Livery**: Base obsidian matte, gloss metallic, and glowing neon accent trim colors (Cyan, Magenta, Gold, Deep Violet).
* **Headlight Color & Beam Customization**:
  * Customizable `SpotLight3D` beam colors (Electric Blue, Laser Crimson, Xenon White, Violet).
  * High-intensity projector lenses boosting `long_beam_length` up to 200+ meters.
  * Wide-spread fog lamp attachments for `near_beam_cone_angle`.
* **Underglow & Exhaust Spark FX**: BPM-synced neon underglow strips and custom exhaust spark particle colors (Gold, Electric Cyan, Hot Pink).

### ⚙️ Performance & Utility Hardware (Medium Upgrades)
* **High-Output Alternator & Battery Banks**: Accelerates `CockpitDashboardUI` ATB meter fill rates for Ordnance and Netrunner modules.
* **Cooling Core & Heat Sinks**: Increases Nitrous boost duration and prevents engine thermal runaway during prolonged overclocks.
* **Traction Control Cyber-Differential**: Reduces chassis drift during high-speed turns under `NEON_RAIN` or `CYBER_SNOW`.

### 💣 Tactical Weapons & Black-Market Cyberware (Big Upgrades)
* **Ordnance Upgrades**: Dual Gatling Cannon Spread, EMP Shockwave Hardpoint, Homing Missile Pods.
* **Netrunner ICE-Breaker Mods**: Steering Jammer, Data Siphon.
* **Neural Sub-Processors & The Glitch Gauge**: High-end illegal chips grant massive combat stat boosts, but increase Mack's **Glitch Gauge**—causing HUD visual noise, ghost target markers (`B_ANKES_GHOST.EXE`), and button label scrambled gibberish during combat.

---

## 6. FUTURE IMPLEMENTATION ROADMAP

### 🎯 PHASE 1: The 15-Minute Micro-Mission Loop
1. **[00:00 - 02:00] Briefing at "The Pit"**: Dashboard dialogue with Lady M and Porter laying out the hit/extraction target.
2. **[02:00 - 05:00] Top-Down Intercept**: Driving through the neon grid to locate and box in the target vehicle.
3. **[05:00 - 08:00] Minor Encounter**: Quick 2-3 turn warm-up battle against escort drones or scout vehicles.
4. **[08:00 - 13:00] First-Person Cockpit ATB Boss Battle**: High-stakes tactical combat against armored executive limos or war-rigs using dashboard modules.
5. **[13:00 - 15:00] Aftermath & Glitch Prophecy**: Target payout, neural prophecy payload transmission from The Norns, and return to Porter's Pit.

### 🚕 PHASE 2: Ambient City Traffic AI
* **Flow Corridors**: Spawn ambient vehicles along fixed street lanes using AABB collision boxes (only converting to rigidbodies when rammed/hit).
* **Traffic Classes**: *Commuter Pods* (mobile cover), *Corporate Haulers* (line-of-sight blockers), and *Enforcer Squads* (neutral/hostile).
* **Acoustics & Horn**: High-frequency acoustic horn that forces civilian traffic to yield and clear lanes.

### 💻 PHASE 3: "The Pit" Interactive Mod-Shop UI
* Build the interactive garage menu for installing the cosmetic paint/headlight mods, performance parts, and Ordnance/ICE upgrades listed in Section 5.

### 🎭 PHASE 4: The 5-Act Narrative Campaign Execution
* Build and hook up the 5-Act story missions outlined in Section 3 from Prologue to the Birnam Malware Standoff and Macduff Boss Duel.




skal legge til:
byen har exit punkter som er connected med neste by
du kan gå ut av bilen, og bli en sånn pinnefigur 😄
fylle hele griddet med by, eller kanskje ha litt høyder og curves langs kantene til griddet?
de andre bilene er altfor dumme nå, har plan for smartere oppførsel der de kjører etter kjøreregler og  har liksom en plan med hvor de skal
legge sidewalks på bakken rundt bygninger
lage klar "mission" bygninger som du kan kjøre inn i og få en "nå er vi inne i huset screen" for eksempel "the garage"
gi bilen stats og våpen som kan oppgraderes i "the garage"
legge til himmel full av stjerner, eller er det mere kult og cyber-ete med starless sky?

og så etterhvert lage det om til et spill med spill-ting. etter bad dogs.
det er også et bpm system på plass så hvis du spiller musikk, så skjer ting i takt med musikken. feks hvis du oppgraderer bilen med neonlys under, så kan de blink i takt
akira style trailing lights?
jornthebjorn — 1:47 AM
Skal også lage et Adaptive music system. Har en plan. (Godot har allerde et veldig bra system som fundament)

vurdere om narrow street skal være off limits for biler, inkludert vår, så der må man bruke nema



[ ] add this haze: could this city be filled with haze so the the lights in the "windows" glow with drama?

Yes, absolutely! Godot’s Volumetric Fog system in Godot 4 works exceptionally well with procedural emissive window textures and OmniLight3D nodes.  
Ukjent

When you turn on atmospheric haze, the procedural windows won't just look like flat lit pixels—their light will scatter into the surrounding air, creating dramatic atmospheric cones, glowing halos, and cinematic street-level light shafts.

Step 1: Add Volumetric Fog via WorldEnvironment
You can attach a WorldEnvironment node to your scene (or configure it via script) to flood the city with thick cyberpunk haze.

GDScript
func _setup_cyberpunk_haze() -> void:
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	
	# Dark background sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.005, 0.02)
	
	# Enable Volumetric Fog
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.035          # Adjust density to taste (0.02 - 0.05 works best for city scales)
	env.volumetric_fog_emission = Color(0.01, 0.02, 0.05) # Deep ambient blue/violet tint in the fog
	env.volumetric_fog_scattering = Color(0.8, 0.85, 1.0)
	env.volumetric_fog_length = 300.0           # Matches half your city size (300m)
	
	# Enable Glow to make window halo blooms pop
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_bloom = 0.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	world_env.environment = env
	add_child(world_env)
Step 2: Enhance Building Lights for Maximum Drama
Your current CityGenerator.gd script already spawns an OmniLight3D inside each skyscraper and creates emissive windows. To make the window glow cut dramatically through the haze:  
Ukjent
+ 1

Enable Volumetric Energy on Building OmniLights:
In _spawn_building(), boost volumetric_fog_energy on building_light:  
Ukjent
+ 2

GDScript
# Inside _spawn_building() in CityGenerator.gd
var building_light: OmniLight3D = OmniLight3D.new()
building_light.light_color = accent_color
building_light.light_energy = 3.5
building_light.volumetric_fog_energy = 2.5 # Makes light scatter heavily into the haze!
building_light.omni_range = max(b_size.x, b_size.z) * 2.0
building_light.omni_attenuation = 0.8
static_body.add_child(building_light)
Give Windows Material Emission Depth:
In _spawn_building(), set b_mat.emission_on_uv2 = false and adjust emission energy multiplier:  
Ukjent
+ 1

GDScript
b_mat.emission_energy_multiplier = 5.0 # Boost brightness so windows cut through dense haze
Step 3: Add Window "Light Beams" (Optional Polish)
Because standard StandardMaterial3D emission textures only glow on the mesh surface itself (they don't cast real-time light beams into fog by default), adding SpotLight3D nodes pointing outward from the skyscraper walls will cast actual light shafts extending out of the windows into the fog:  
Ukjent

GDScript
# Place this inside _spawn_building() to cast volumetric shafts out of building faces
for angle in [0, 90, 180, 270]:
	var window_spot = SpotLight3D.new()
	window_spot.light_color = accent_color
	window_spot.light_energy = 8.0
	window_spot.volumetric_fog_energy = 4.0 # Punchy light shaft
	window_spot.spot_range = 25.0
	window_spot.spot_angle = 45.0
	window_spot.rotation_degrees.y = angle
	static_body.add_child(window_spot)
When combined with your dynamic light stages (L key) and street floodlights (CitySceneryProps.gd), turning the lighting stage down to DIM or DARK_BUILDINGS while keeping volumetric fog enabled will turn the city into a dramatic, atmospheric silhouette shrouded in glowing colored mist!

---

## 🏬 SAFEHOUSE NETWORK & STORY RECOVERY IDEAS

### 1. Banquo's Tactical Loft Apartment
* **Location**: High-rise residential tower in North-West Sector.
* **Features**: Dedicated bed/resting point, high-speed overmap surveillance matrix, decrypted data drive analyzer, private balcony overlooking the city grid.
* **Gameplay**: Can rest here to advance the day, check personal comms, or inspect stored trophies/intel.

### 2. Dual Bunk System at Mack's Hideout
* **Features**: A second designated bed in Mack's central hideout allowing Banquo to crash there after late-night battle prep or when staying close to Mack's thermal monitoring stack.

### 3. The Pit's Secret Panic Room & Safehouse Vault
* **Location**: Concealed heavy steel door along the back wall of "The Pit Garage" (Porter's subterranean hub).
* **Story Arc**:
  * **Lady M's Ambush Recovery**: Later in the campaign, corporate strike forces ambush Lady M's penthouse.
  * **Secret Medical Bay**: Banquo and Mack extract Lady M and smuggle her into The Pit's subterranean panic room.
  * **Interactive Visits**: Player can visit Lady M's recovery pod inside the secret room for off-the-grid mission briefings and covert plot developments!

### 4. Act II Story Mission: "Spectral Disguise & The Fife Infiltration"
* **Story Arc**:
  * **Corporate APB & Cordon Lockout**: Fife Security Patrol places an active high-alert APB on Banquo's standard telemetry signature and head glow color after a high-stakes highway intercept. Central checkpoints are blocked by scanners looking specifically for Banquo's default cyan/electric signature.
  * **The Wardrobe Disguise Objective**: Lady M contacts Banquo: *"Banquo, Fife Security scanner turrets have your neural frequency locked! Return to your Private Loft immediately. Step into your Wardrobe Cupboard and cycle your head glow color outfit disguise to fool their optical scanners!"*
  * **Gameplay Execution**:
    1. Drive to Banquo's Private Loft in the South-East Corner (`250,250`).
    2. Enter the apartment and approach the **Interactive Wardrobe Cupboard**.
    3. Press `E` to cycle head color outfit to a new stealth palette (*e.g., Deep Crimson or Emerald Green*).
    4. The security checkpoint scanner unlocks, allowing Banquo to slip past Fife Security patrols unnoticed to execute the stealth infiltration!

---

## 🍦 SPECIAL MAP LOCATIONS & NARRATIVE TWISTS

### Joe's Ice Cream Store ("The King James" Twist)
* **Location on Map**: A neon-lit street-front parlor called **"Joe's Ice Cream Store"** located within the city grid.
* **Daily Sponsorship Mechanic**:
  * Joe's Ice Cream acts as a regular corporate sponsor, depositing a recurring daily stipend of credits/cash directly to you each in-game day.
  * Provides early-game economic relief, funds for vehicle mods, and a seemingly benign, quirky ally in a cold dystopia.
* **The "King James" Twist**:
  * Later in the campaign, the dark truth is revealed: Joe / the Ice Cream operation is our adaptation's **"King James"** figure (the historical patron/puppeteer in Shakespearean context).
  * The daily support, specific food/neural additives, and financial sponsorship were never genuine charity—it is a sinister, calculated long game designed to subtly manipulate, overheat, and drive Machbeth completely insane into paranoia and thermal breakdown.
* **Dialogue Dynamics & Psychological Goading**:
  * Whenever Banquo/Mack talks with Joe, Joe subtly strokes Mack's ego and pushes him to take on increasingly dangerous, reckless, and high-difficulty contracts ("A legend like Mack shouldn't be doing petty courier work... you belong in the big leagues").
  * Constantly feeds rumors about bleeding-edge, untested experimental combat cyberware, urging Mack to install it to stay ahead of the curve.
* **Special Quest Line: "The Experimental Shipment Intercept"**:
  * **Joe's Intel Tip-off**: Joe provides insider telemetry on a high-security corporate convoy carrying a prototype, unreleased cyberware implant moving through the Spire Grid.
  * **Highway Intercept Mission**: Player must chase down and ambush the heavily armored convoy to hijack the shipment.
  * **The Faustian Trade-off**:
    * **Combat Boon**: The prototype cyberware provides massive, game-changing stat boosts (overclocked ATB speed, devastating ordnance output, extreme damage resistance).
    * **Severe Health/Neural Cost**: The tech is brutally taxing on Mack's bio-chassis—causing permanent baseline max HP reduction, erratic glitch gauge spikes, random combat HUD distortions, and accelerated neural degradation.


