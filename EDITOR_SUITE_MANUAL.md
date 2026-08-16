# 🖥️ Cyberpunk Macbeth Editor Suite Manual (F1 – F4)

This manual explains how to use the built-in in-game editor suite in **Cyberpunk Macbeth**. Pressing **F1, F2, F3, or F4** during gameplay opens an isolated, paused overlay for editing game data, quests, dialogue trees, and combat encounters.


  ### 🔗 How All 4 Editors Connect Seamlessly:                                            
                                                                                          
                      ┌─────────────────────────────────────────┐                         
                      │          F3: DIALOGUE EDITOR            │                         
                      │  (Create NPC conversation branch nodes) │                         
                      └───────────────────┬─────────────────────┘                         
                                          │                                               
                   ⚡ Choice Action Trigger Dropdown (New!)                               
              ┌───────────────────────────┴───────────────────────────┐                   
              │                                                       │                   
    ┌─────────▼──────────────────────────┐         ┌──────────────────▼─────────────────┐ 
    │     F4: BANQUO STREET EDITOR       │         │      F2: MACK BATTLES EDITOR       │ 
    │  (Tail Target, Courier, Recon...)  │         │ (Multi-round War-Rig encounters)  │  
    └─────────────────┬──────────────────┘         └──────────────────┬─────────────────┘ 
                      │                                               │                   
                      └───────────────────────┬───────────────────────┘                   
                                              │                                           
                            ┌─────────────────▼─────────────────┐                         
                            │        F1: DATABASE EDITOR        │                         
                            │ (Weapons, Upgrades & Enemy Stats) │                         
                            └───────────────────────────────────┘                         
  ──────                                                          
---

## 🎹 Quick Function Key Overview

| Key | Editor Name | Purpose & Function | Saved JSON File |
| :--- | :--- | :--- | :--- |
| **F1** | **DATABASE EDITOR** | View, edit, and balance global stats for Weapons, Cyberware Upgrades, and Enemy Archetypes. | `data/weapons.json`<br>`data/upgrades.json`<br>`data/enemies.json` |
| **F2** | **MACK BATTLES EDITOR** | Create and balance Mack's heavy War-Rig combat encounters across Campaign Acts & multi-round enemy waves. | `data/missions.json` |
| **F3** | **DIALOGUE EDITOR** | Build visual-novel style dialogue trees, branching choices, speaker portraits, and quest action triggers. | `scripts/*.json`<br>(e.g., `scripts/mr_dodgy.json`) |
| **F4** | **BANQUO STREET MISSIONS EDITOR** | Design Banquo's street quests (Tail Target, Courier Runs, Wiretaps, Alley Pursuits, Pit Brawls). | `data/street_missions.json` |

---

## 🛠️ Detailed Editor Guides & Workflow

### 1. ⚙️ F1: Database Editor (`F1`)
The **Database Editor** lets you tweak item stats, pricing, damage, and enemy behavior parameters in real time.

- **Tabs**: Switch between `WEAPONS CATALOG`, `UPGRADES CATALOG`, and `ENEMIES CATALOG`.
- **Editing**: Select an item from the left panel to modify attributes (e.g., weapon DPS, fire rate, enemy HP, scrap drops).
- **Saving**: Click `💾 SAVE ALL` to write updates directly to the respective `res://data/*.json` files.

---

### 2. ⚔️ F2: Mack Battles Editor (`F2`)
The **Mack Battles Editor** designs multi-wave combat missions where Mack deploys the War-Rig into corporate battlegrounds.

- **Act Filtering**: Organize battles by Campaign Act (Act I through Act IV).
- **Wave / Round Setup**: Add multiple rounds per battle and assign enemy units from the F1 enemy catalog.
- **Rewards**: Configure credit payouts, scrap salvage drops, and completion messages from Lady M.

---

### 3. 📜 F3: Visual Dialogue Node Graphing Editor (`F3`)
The **Dialogue Editor** crafts interactive conversations using Godot's visual `GraphEdit` & `GraphNode` canvas interface.

- **Visual Canvas Nodes**: Drag and position dialogue nodes across an infinite grid canvas (`start`, `who_are_you`, `accept_quest`).
- **Interactive Wire Dragging**: Drag wires directly between Choice Output ports and target Input ports to visually map branching conversation paths.
- **⚡ Color-Coded Quest Triggers**:
  Choice ports change color based on action triggers:
  1. 🟡 **Gold Port (`NONE`)** — Standard dialogue conversation branch.
  2. 🟢 **Emerald Port (`START_STREET_MISSION`)** — Launches an F4 Banquo Street Quest (e.g., `street_01_pink_cadillac`).
  3. 🔴 **Crimson Port (`START_MACK_BATTLE`)** — Triggers an F2 Mack War-Rig Combat encounter.

---

### 4. 🕵️‍♂️ F4: Banquo Street Missions Editor (`F4`)
The **Banquo Street Missions Editor** designs Banquo's street operations across 5 distinct quest archetypes:

- **Quest Archetypes**:
  1. 🕵️‍♂️ **TAIL_TARGET**: Follow a target vehicle (like the *Pink Cadillac*) at a safe distance (15m–40m) without triggering suspicion.
  2. 📦 **COURIER_RUN**: Deliver sensitive data drives or contraband across city districts under a time limit.
  3. 📡 **EAVESDROP_RECON**: Infiltrate crowd spaces (like park concerts/rallies) to intercept encrypted audio transmissions.
  4. 🏃 **ALLEY_PURSUIT**: Sprint through narrow alleys to tackle or corner fleeing corporate informants.
  5. 🥊 **PIT_BRAWL**: 1-on-1 melee fights in street arenas or garage pits.
- **Dynamic Parameters**: Selecting a quest type automatically displays type-specific input fields (e.g., safe tailing distance, destination, time limit).

---

## 🔗 Step-by-Step Workflow Example: Creating a Street Quest

Here is how to create a complete quest from scratch:

1. **Step 1 (F4)**: Open **F4**, click `➕ NEW STREET QUEST`, set Quest Name to `"The Mysterious Pink Cadillac"`, Type to `TAIL_TARGET`, and set Target Vehicle to `Pink Cadillac`. Click `💾 SAVE ALL`.
2. **Step 2 (F3)**: Open **F3**, load `scripts/mr_dodgy.json`. Add a choice option: `"Tell me about the Pink Cadillac"`.
3. **Step 3 (F3 Integration)**: On the acceptance choice, set **Quest Trigger Action** to `START_STREET_MISSION` and set **Target Quest ID** to `street_01_pink_cadillac`. Click `💾 SAVE ALL`.
4. **Play!**: Approach Mr. Dodgy in the park, talk to him, accept the quest, and watch the Pink Cadillac spawn at West Park Plaza with its persistent street tailing mechanics!
