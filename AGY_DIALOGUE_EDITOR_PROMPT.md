# 🤖 AGY CLI Prompt: Implement Visual Graph & Dual-Mode Dialogue Editor System in Godot 4

Copy and paste the instructions below directly into your AGY CLI prompt in your other Godot 4 project to replicate the exact Dual-Mode Dialogue Editor system built here:

---

### 📋 COPY-PASTE AGY PROMPT:

```text
Please build a complete, standalone Dual-Mode Dialogue Editor System (F3 Overlay) for this Godot 4 project in GDScript.

The overlay must be an isolated CanvasLayer named `DialogueEditorUI.gd` that pauses the engine when open (process_mode = PROCESS_MODE_ALWAYS, layer = 122). It must load and save dialogue JSON files from `res://scripts/*.json`.

### Core Requirements & Architecture:

1. **Dual-Mode System with Header Toggle**:
   - Header bar button toggles between `EditorViewMode.GRAPH_VIEW` and `EditorViewMode.LIST_VIEW`.
   - Both modes share the exact same underlying `active_dialogue_data` dictionary.

2. **Graph View (`GraphEdit` & `GraphNode`)**:
   - Uses an interactive, zoomable, and pannable `GraphEdit` background with grid snapping.
   - Dynamically constructs `GraphNode` elements for each node in the dialogue file.
   - **Wire Connections**: Listens to `connection_request` and `disconnection_request` signals to visually wire/unwire choice ports to target dialogue nodes.
   - **Color-Coded Output Ports**:
     - 🟡 Gold Port: Standard Dialogue Branch (`NONE`).
     - 🟢 Emerald Port: Street Quest Trigger (`START_STREET_MISSION`).
     - 🔴 Crimson Port: Combat Encounter Trigger (`START_MACK_BATTLE`).

3. **List View (`ItemList` & Form Panel)**:
   - Left side: `ItemList` node directory with `⭐` badges for the `start` node.
   - Right side: Form editor with 11px font size theme and grouped `PanelContainer` boxes:
     - 🔵 `👤 SPEAKER METADATA` (Name, Subtitle, Neural ID).
     - 🟡 `💬 EDITING NODE` (ID, Portrait Emotion dropdown, Dialogue Text).
     - 🟠 `🌿 CHOICE BRANCHES & QUEST TRIGGERS` (Card containers per choice).
   - **Choice Branch Card Details**:
     - Compact `#1:`, `#2:` badges to save horizontal space.
     - **Dynamic Target Dropdown**: `OptionButton` populated dynamically with all valid node IDs (`exit`, `start`, branch IDs) in the active story file.
     - **Choice Action Dropdown**: `💬 STANDARD DIALOGUE BRANCH`, `🚀 TRIGGER F4 STREET QUEST`, `⚔️ TRIGGER F2 MACK BATTLE`.
     - **Quick Navigation**: `🔍 JUMP TO TARGET NODE` button (selects and opens the target node directly in the form view) and `➕ Create & Link Node` button.

4. **File System Scanning**:
   - Automatically scans `res://scripts/*.json` files on opening, provides a file dropdown to select files, a `➕ New Story File` creation handler, and a `💾 Save All` button.

Please generate `DialogueEditorUI.gd` with full GDScript code implementing these exact specifications.
```
