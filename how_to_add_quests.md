# How to Add Fetch and Deliver Quests

This guide details how to add, configure, and expand **Fetch and Deliver Quests** in *Cyberpunk Macbeth*.

---

## 1. Overview of Quest Architecture

Quests are completely **decoupled and data-driven**. The quest system connects three core components:

```
┌─────────────────────────┐       ┌────────────────────────┐
│    Dialogue System      │       │     QuestManager       │
│ (res://scripts/*.json)  ├──────►│   (QuestManager.gd)    │
│ Triggers choice targets │       │ Data-driven registry   │
└─────────────────────────┘       └───────────┬────────────┘
                                              │
                                              ▼
                                  ┌────────────────────────┐
                                  │   PedestrianSystem     │
                                  │   & Tactical Overmap   │
                                  │ Dynamic Spawns & Blips │
                                  └────────────────────────┘
```

1. **Dialogue JSON files** (`res://scripts/*.json`): Contain the dialogue text and choice options. Choice target IDs serve as quest start and completion event triggers.
2. **`QuestManager.gd`**: Holds the quest registry, tracks active quest state, manages credit payouts, displays the HUD banner, and triggers Lady M neural text popups.
3. **`PedestrianSystem.gd` & `TacticalOvermapManager.gd`**: Spawn dynamic delivery recipients on sidewalks and mark destination blips.

---

## 2. Step-by-Step: Adding a New Fetch and Deliver Quest

### Step A: Define the Quest in `QuestManager.gd`

Open [`QuestManager.gd`](file:///home/jorn/machbeth/CyberpunkCity/QuestManager.gd) and add a new entry to the `quest_registry` dictionary:

```gdscript
var quest_registry: Dictionary = {
	"dodgy_smuggle_synth": {
		"title": "SYNTH-NIGHT SMUGGLE",
		"description": "Deliver Mr. Dodgy's contraband package to the street busker near the central park.",
		"reward_credits": 750,
		"quest_type": "FETCH_AND_DELIVER",
		"giver_type": "MR_DODGY",            # Character who gives the quest
		"receiver_type": "STREET_BUSKER",     # Character/archetype receiving delivery
		"start_dialogue_target": "dodgy_quest_accept",   # Choice target ID in giver JSON
		"complete_dialogue_target": "busker_deliver_pkg", # Choice target ID in receiver JSON
		"map_blip_color": Color(0.0, 0.85, 1.0, 0.95),    # Cyan map blip
		"completion_lady_m_text": "Good work Banquo. Dodgy's shipment is in the busker's hands."
	}
}
```

---

### Step B: Wire the Quest Giver's Dialogue JSON

To make an NPC give a quest, add a choice in their dialogue file whose `"target"` matches the quest's `"start_dialogue_target"` string.

#### Example Giver Dialogue (`res://scripts/mr_dodgy.json`):
```json
{
	"speaker_display_name": "MR. DODGY",
	"speaker_subtitle": "PARK CONTRABAND DEALER",
	"speaker_color": "#FF8800",
	"nodes": {
		"start": {
			"text": "Need a job, stranger? I got a synth-pack that needs to reach the street musician across the park.",
			"choices": [
				{
					"text": "\"I'll deliver it. Hand over the package.\"",
					"target": "dodgy_quest_accept"
				},
				{
					"text": "\"Not right now, Dodgy.\"",
					"target": "exit"
				}
			]
		},
		"dodgy_quest_accept": {
			"text": "Keep it low key. I've marked the musician's spot on your overmap [M].",
			"choices": [
				{
					"text": "\"[Accept Job]\"",
					"target": "exit"
				}
			]
		}
	}
}
```

---

### Step C: Wire the Quest Receiver's Dialogue JSON

To make an NPC receive a delivery, add a choice in their dialogue file whose `"target"` matches the quest's `"complete_dialogue_target"` string.

#### Example Receiver Dialogue (`res://scripts/street_busker.json`):
```json
{
	"speaker_display_name": "STREET BUSKER",
	"speaker_subtitle": "NEON SYNTH-PLAYER",
	"speaker_color": "#FF0099",
	"nodes": {
		"start": {
			"text": "Hey traveler. Looking to request a tune or just taking in the neon rain?",
			"choices": [
				{
					"text": "\"Dodgy sent me. Here's your synth-pack.\"",
					"target": "busker_deliver_pkg"
				},
				{
					"text": "\"Just passing through.\"",
					"target": "exit"
				}
			]
		},
		"busker_deliver_pkg": {
			"text": "Ah, excellent! Dodgy comes through again. Here's your cut for the trouble.",
			"choices": [
				{
					"text": "\"[Hand Over Package]\"",
					"target": "exit"
				}
			]
		}
	}
}
```

---

## 3. Supported Quest Givers & Receivers

Any character archetype in the city can act as a **Quest Giver**, a **Quest Receiver**, or both!

| Character Archetype | Giver / Receiver Capability | Dialogue JSON Asset | Notes |
| :--- | :--- | :--- | :--- |
| **Gang Leader** | Giver & Receiver | `res://scripts/gang_leader.json` | Syndicate Boss lurking in asphalt parking lots |
| **Mr. Dodgy** | Giver & Receiver | `res://scripts/mr_dodgy.json` | Shady dealer leaning under park streetlamps (smokes neon puffs) |
| **Street Busker** | Giver & Receiver | `res://scripts/street_busker.json` | Musician playing near cyber parks |
| **Street Vendor / Noodle Shop** | Giver & Receiver | `res://scripts/street_vendor.json` | Noodle cart vendor parked on sidewalk edges |
| **Fixer / Informant** | Giver & Receiver | `res://scripts/fixer.json` | Alleyway contacts conducting dark transactions |
| **Dynamic Street Contact** | Receiver (Spawns on demand) | `res://scripts/delivery_contact.json` | Spawns on a random sidewalk with a parked neon motorcycle |

---

## 4. How Character Selection Works for Quests

When the player interacts on foot (pressing `[F]` or `[SPACE]` near an NPC), [`PedestrianSystem.gd`](file:///home/jorn/machbeth/CyberpunkCity/PedestrianSystem.gd) checks which archetype is closest:

1. **Static / World Archetypes** (Mr. Dodgy, Gang Leader, Busker, Noodle Vendor):
   - Already present in the city environment.
   - When interacted with, they open their respective JSON file (`res://scripts/*.json`).
   - If an active quest requires delivering to them, their JSON file presents the delivery choice option (`"complete_dialogue_target"`).

2. **Dynamic Delivery Contacts**:
   - Spawned on a random sidewalk clear of water upon quest start.
   - Marked on the Tactical Overmap (`[M]`) with a radiant square blip.
   - Upon quest completion, they linger for 2.5 seconds and then follow a custom calculated street route out of the city.

---

## 5. Expanding Beyond "Fetch and Deliver" Quests

The system is designed to support future quest types by adding a `"quest_type"` field in `QuestManager.gd`:

- **`FETCH_AND_DELIVER`** (Current): Pick up package from Giver $\rightarrow$ Deliver to Receiver on sidewalk.
- **`ESCORT_VIP`** (Future): Escort an NPC on foot/in car safely to a target district.
- **`ELIMINATE_TARGET`** (Future): Track down a corporate enforcer vehicle and defeat them in dashboard combat.
- **`DATA_HACK`** (Future): Drive to a broadcast tower and complete a neural hacking sequence.

---

## Summary Checklist for Adding a New Quest

- [ ] Add quest definition to `quest_registry` in [`QuestManager.gd`](file:///home/jorn/machbeth/CyberpunkCity/QuestManager.gd)
- [ ] Set `"start_dialogue_target"` in the Giver's dialogue JSON file
- [ ] Set `"complete_dialogue_target"` in the Receiver's dialogue JSON file
- [ ] Run Godot to verify signal wiring and HUD objective updates!
