# CYBERPUNK MACBETH: LORE & DEVELOPMENT ROADMAP

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
* **The Norns (The 3 Witches)**: Three rogue, glitching AI entities living deep within unmapped web frequencies. They transmit cryptic prophecy payloads (`#03-NORNS`) directly into Mack’s neural feed, predicting his rise to CEO.
* **Bankes (Banquo)**: Mack’s former wingman and telemetry scout. After being purged by corporate hit-drones to protect the conspiracy, Bankes’ corrupted backup haunts Mack's HUD as `B_ANKES_GHOST.EXE`, spawning phantom target markers.
* **Fleance**: Bankes' netrunner son who escaped the drone ambush into darknet web traffic.
* **Macduff**: Elite driver of the Fife Security Patrol. Operating an un-networked synth-cyborg chassis ("born of a lab-vat, not of woman"), Macduff lead the anti-Mack resistance.
* **Porter**: A cynical, glitch-modded grease-monkey operating **"The Pit"**—a subterranean, off-grid garage beneath the central highway. Porter handles vehicle tuning, black-market cyberware, and provides dark, rhythmic street commentary as Mack’s sanity unravels.

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
