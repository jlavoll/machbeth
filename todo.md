- [x] when we end a day, all the pedestrians should despawn and respawn, shifting out entertainment in the park properly
- [x] shift to drive faster (boost max speed 38m/s), also add skid mark sounds (res://sfx/outrun_skid.wav)
- [x] Day lighting cycle progression (with F6 debug stepper):
  - Day starts at Stage 3 (DIM 5% - early morning dawn)
  - Transitions to Stage 2 (LOW_LIGHT 25% - morning) and then Stage 1 (NORMAL 100% - peak daytime)
  - After completing Mack's daily Grand Battle, lights step down to Stage 2 (LOW_LIGHT 25% - evening dusk)
  - When that day's available side missions/quests are exhausted, lights step down to Stage 3 (DIM 5% - deep night)
  - Stages 4 (DARK_BUILDINGS) and 5 (PITCH_BLACK) are reserved for special story events (blackouts, ambushes, infiltration)


- [ ] Instant simulations of battles from The Pit & Loadout Grid System / Battle Editor (NEEDS INVESTIGATION: Simulations are not activating/starting when triggered in The Pit; need to return to this to trace the exact activation pipeline and execution lifecycle).
  - Visual Equipment Grid for both MACK (Cyborg implants, weapons, neural mods, armor plates) and his VEHICLE (weapon turrets, armor chassis, nitro boosters, ECM scramblers).
  - Shows all available inventory slots and what is currently equipped.
  - Interactive tuning/equipping accessible in The Pit (Porter's subterranean black-market hub) and in the Battle Editor.
  - Live equipment status & active slot monitoring on the Cockpit Dashboard / Combat HUD.




- [x] can duncan have a big tv screen in his private room that has a live feed of the streets outside (768x432 SubViewport camera with slow surveillance pan overlooking Broadway intersection)

- [ ] Banquo's On-Foot Man-vs-Man Fighting System:
  - Melee combat mechanics (combos, punches, dodges, blocks, and cybernetic sidearm draws).
  - Combat targeting lock-on reticle against hostile syndicate enforcers, corporate assassins, and muggers in alleys/indoor rooms.
  - Health/stamina meters, impact sound effects, hit reactions/flinches, and takedowns.


- [x] fix fonts in shop screen (Crisp typography hierarchy with Orbitron titles and legible ShareTech font sizing)

- [x] we are getting "assist MACK" random requests when we do our own solo mission: Gated modal decision events in CampaignManager when inside buildings or during active quests (buffered to subtle comms).
- [x] in the mission editor then, we should specify is it a mission for banquo or for mack: Added Operative selector (MACK War-Rig vs BANQUO On-Foot Infiltration) and list item tags.
- [x] equipped upgrades, equipped weapons etc on enemy design editor, needs to be a pull-down list: Dynamically populated OptionButtons reading live from weapons.json and upgrades.json catalogs.

- [ ] when we are in a mission fighting as banquo and we lose, does mack tow us back to the pit? is that what happens? (Ensure proper Mack emergency evac & clean summary teardown)

maybe we can order some "airstrikes" frm lady m. costs momeny, so we should have a money
readout at the HUD, and then she can say "ok i fixed this thing, but i need 20 seconds to execute it"

- [x] we need a visualization of available equipment slots in the car, for Mack and even for Banquo, with a live stats readout as we change equipment:
  - Separated Banquo into his own dedicated Operative Armory Terminal (`BanquoOperativeUI.gd`) accessed in his high-rise loft wardrobe/gear rack.
  - Upgraded The Pit Loadout Grid (`LoadoutGridUI.gd`) to a spacious 2-column tactical blueprint display focusing exclusively on Mack Cyborg and the War-Rig Chassis.
  - Increased typography size ($10\text{px} - 13\text{px}$) and expanded high-resolution vector schematics ($140\text{px}$ canvases) with spatial hardpoint callout vectors.
  - Added live capacity badges (`[X/N SLOTS | Y FREE]`), `[UNEQUIP]` slot clearing, and real-time calculation of Mack's Power Threat rating & combat rank card.

- [x] Enrich city personality with multi-branching pedestrian dialogue & situational reactivity:
  - Upgraded 5 core citizen archetypes from 1-line quips to deep branching conversation trees:
    - **Street Food Hawker (Kai)**: Sells hot Neon Noodles and Stim-Cola, provides corporate convoy movement rumors and district vendor lore.
    - **Narrow Alley Resident (Vance)**: Street surveillance paranoia, stealth bypass routes around police cameras, and paid informant tips.
    - **Cyber Park Rave Dancer (Nova)**: Outrun pirate radio frequencies (108.4 FM), rave resistance culture, and Three Witches fog prophecies.
    - **Perimeter Cyber-Jogger (Torx)**: Titanium knee cyberware, particulate scrubber lungs, and speed-trap radar advice.
	- **Cyber-Bard (Orpheus)**: Sings custom Shakespearean cyberpunk ballads (*Ballad of Mack's War-Rig*, *Lament of Duncan*, *Three Phantoms in the Mist*, and *Canto of Victory*).
  - Integrated **situational & time-of-day reactivity** (`start_night` when dusk/night falls, and `start_post_battle` when Mack shatters a corporate convoy on the highway).


- [x] doppler effect on concert as we drive by
- [x] unique indoor footsteps & room-size tailored acoustic reverb: Created `IndoorRoomReverb` DSP audio bus, dynamically adjusting room size and damping based on room floor area (Banquo's tight 15x15m loft vs. cavernous 40x30m HQ Lobby/Pit Garage), while keeping balconies/rooftops dry/open-air.

- [x] discrete horizontal tactical compass ribbon at top of HUD (`TacticalCompassHUD.gd`):
  - Compact, semi-transparent cyberpunk ribbon ($380\text{px} \times 24\text{px}$) with GeistPixel typography.
  - Smooth real-time heading tracking for both vehicle driving and on-foot exploration.
  - Features cardinal (N, E, S, W in gold) and ordinal (NE, SE, SW, NW in cyan) ticks with exact numeric degree readout (e.g. `045° // NE`).
  - Active quest waypoint tracking: renders dynamic gold diamond beacon indicators pegged to directional target positions.
  - Automatically hides cleanly during full-screen overmap, loadout, armory, and telemetry consoles.

- [x] Northern Barren Metropolis ("Sector 00") & Connecting Cyber-Highway Corridor (`CityGenerator.gd`):
  - Built physical $2200\text{m} \times 36\text{m}$ multilane asphalt cyber-highway extending from North Exit Gate ($Z = -300\text{m}$) down to $Z = -2500\text{m}$ with glowing cyan/amber guardrails and overhead holographic speed limit / distance checkpoint gantries every $250\text{m}$.
  - Built the $600\text{m} \times 600\text{m}$ Northern Barren Metropolis centered at $Z = -2800\text{m}$ featuring cold blackened asphalt, dim ember crimson wireframe grid, brutalist monolithic towers, and zero civilian crowds for an eerie abandoned industrial wasteland atmosphere.
  - Removed boundary wrap-around at North edge in `PlayerCar.gd`, enabling seamless continuous driving between both cities ($\sim 1.0\text{ to }1.5\text{ minutes}$ at top speed).
  - Connected dynamic satellite camera tracking in `TacticalOvermapManager.gd` across the full corridor.
