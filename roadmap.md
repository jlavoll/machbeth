# 🗺️ CYBERPUNK MACBETH: STEP-BY-STEP DEVELOPMENT ROADMAP

This document outlines the small, incremental steps forward to build out the dual-agent campaign flow (Banquo gathering/stealth & Mack grand autobattles), vehicle garage, cyborg modding, and city traffic polish.

---

## 📌 STEP 1: Traffic System Stability & Deterministic Spawning
**Focus**: Replace ambient random traffic pop-in with a fixed set of citywide vehicles following predetermined daily routes.

* **Key Actions**:
  - Disable distance-based ambient car despawning in `TrafficSystem.gd`.
  - Spawn 6–8 specific cars at safe initial street coordinates upon city generation.
  - Assign each car a deterministic route (daily schedule plan) generated via the existing A* grid pathfinder.
  - Scale city building grid bounds to cleanly fit the full 600m x 600m map.
* **Achieved Summary**: The city feels alive with persistent, predictable traffic patterns instead of random popping, making Limo Intercept and Pursuit mechanics reliable and tactical.

---

## 📌 STEP 2: Banquo's Inter-Battle Tactical Intercept Mission
**Focus**: Build the core loop for Banquo's small-scale street missions (intercepting corporate limos and drone couriers).

* **Key Actions**:
  - Add a target vehicle (e.g. "Duncan Logistics Limo") spawned into traffic with a mini-map objective icon.
  - Trigger a tactical 1-on-1 intercept phase when Banquo sideswipes or traps the target vehicle.
  - Reward salvage materials, cyber-credits, and encrypted data-cores upon mission completion.
* **Achieved Summary**: Players have a functional, repeatable street mission loop as Banquo to earn money and scrap before sending Mack into grand battles.

---

## 📌 STEP 3: The Pit Garage & Vehicle Fleet Manager
**Focus**: Create an interactive Garage Hub UI at "The Pit" to store, view, and upgrade vehicles.

* **Key Actions**:
  - Create a dedicated Garage state/UI accessible at The Pit subterranean location.
  - Support two distinct vehicles in the fleet: **Banquo's Intercept Car** (Agility/Speed) and **Mack's War-Rig** (Armor/Heavy Ordnance).
  - Add upgrade slots: Engine Tuning (ATB fill speed), Armor Plating (Hull HP), and Ordnance Mounts (Gatling / EMP).
* **Achieved Summary**: A working base hub where resource spoils from Banquo's missions can be spent to upgrade both vehicles.

---

## 📌 STEP 4: Mack's Cyborg Parts & Glitch Integration
**Focus**: Implement the cyborg customization screen for Mack and link upgrades to the Glitch Gauge system.

* **Key Actions**:
  - Build a Cyborg Modding interface in The Pit for Mack (Neural Cores, Ocular Scopes, Sub-Dermal Plating).
  - Connect cyberware quality to Mack's **Glitch Gauge** in `NeuralGlitchSystem.gd`.
  - Ensure higher-tier parts increase passive HUD static and `B_ANKES_GHOST.EXE` phantom button spawns during combat.
* **Achieved Summary**: Cyberware upgrades directly power up Mack's stats while visually driving his narrative downfall through HUD paranoia.

---

## 📌 STEP 5: Grand Autobattle / Campaign Deployment Pipeline
**Focus**: Connect Banquo's preparation phase to Mack's Grand Battles.

* **Key Actions**:
  - Add a "Deploy Mack" war-table terminal in The Pit.
  - When deployed, Mack's War-Rig launches into an automated/tactical Grand Battle encounter (Act progression).
  - Render the outcome in the Cockpit ATB view, unlock the next chapter of story dialogue via `DialogueSystem.gd`, and update sector control.
* **Achieved Summary**: The complete high-level campaign loop is functional — prep as Banquo $\to$ deploy Mack on grand hits $\to$ advance Shakespearean cyber-tragedy.
