# CITY POPULATION ARCHITECTURE: AMBIENT VEHICLES & PEDESTRIANS

A technical design specification and implementation plan for populating the city grid with reactive AI traffic and civilian/corporate pedestrians.

---

## 1. AMBIENT VEHICLE TRAFFIC SYSTEM (`TrafficSystem.gd`)

### Spawning & Pooling Architecture
* **Distance-Based Pulse Spawner**: Vehicles spawn in street corridors slightly beyond camera FOV boundaries and despawn when exiting the view threshold, maintaining zero performance impact.
* **Simple Collision Proxy**: Ambient traffic uses lightweight AABB bounding boxes while driving in lanes, instantly converting to 3D `RigidBody3D` physics objects if struck by `PlayerCar` or ordnance.
* **Seed Integration**: Traffic density, vehicle color palettes, and speed corridors scale dynamically based on `CityGenerator.city_seed`.

### Vehicle Archetypes
1. **Commuter Pods (Civilian)**:
   * *Visuals*: Compact, low-profile dark matte pods with dim neon taillights.
   * *Behavior*: Strictly obey street lanes at steady speeds.
   * *Tactical Use*: Mobile cover for `PlayerCar` to break enemy target locks.
2. **Corporate Haulers (Heavy Transport)**:
   * *Visuals*: Large, blocky 6-wheel trucks with glowing neon side-banners.
   * *Behavior*: Slow-moving, occupying wide lanes.
   * *Tactical Use*: Line-of-sight blockers that muffle 3D acoustics (`CarEngineAudio.gd`).
3. **Enforcer Patrols (Glamis/Cawdor Security)**:
   * *Visuals*: High-contrast cyan/magenta patrol cars with roof sirens.
   * *Behavior*: Neutral until `PlayerCar` draws weapons or impacts civilian traffic.

---

## 2. PEDESTRIAN CROWD SYSTEM (`PedestrianSystem.gd`)

### Mesh & Shader Design
* **Stylized Neon Stick/Cylinder Figurines**: Lightweight 3D figures built using slim cylinders/capsules with glowing neon emission materials (Cyan, Hot Pink, Amber).
* **Low-Cost Animation**: Vertex shader-driven leg swing / walking bobbing motion to avoid heavy skeletal animation overhead.

### Walking AI & Sidewalk Corridors
* **Sidewalk & Park Waypoints**: Pedestrians walk along building sidewalk borders, crosswalks, Cyber Parks (grass paths), and Parking Lots.
* **Scattering & Panic Reactions**:
  * *Normal State*: Casual walking between waypoints.
  * *Horn Reaction*: Honking `PlayerCar` acoustic horn causes pedestrians to halt or turn.
  * *Combat Panic*: Gunfire or high-speed driving triggers a panic state—pedestrians scatter toward building entrances or park tree cover.

---

## 4. CITY BOUNDARIES & INTER-CITY EXIT GATES PLAN

### Boundary Rules & City Limits
* **City Grid Metric**: Ground wireframe grid extends to $\pm 300\text{m}$ ($600\text{m} \times 600\text{m}$ total size), with skyscraper city blocks bounded between $\pm 220\text{m}$.
* **AI Entity Boundary Clamping**: Ambient cars (`TrafficSystem.gd`) and pedestrians (`PedestrianSystem.gd`) are clamped to $\pm 250\text{m}$. Crossing $\pm 250\text{m}$ forces pedestrians to turn around and despawns/recycles traffic back into city blocks.
* **Player Freedom**: `PlayerCar` is free to drive beyond the city grid boundaries to reach highway exit gates.

### Future Inter-City Exit Gates Feature
* **Highway Exit Toll Gates**: 4 highway exit toll gates positioned at the North, South, East, and West perimeter ends of the main avenues.
* **Inter-City Highway Travel**: Driving `PlayerCar` through an exit gate triggers a high-speed highway travel phase, allowing seamless travel between different city seeds / districts (Glamis District, Cawdor Logistics, Fife Security Zone, and Dunsinane Spire Core).
