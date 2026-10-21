# SCP: Noirverse

A first-person fan game set in the SCP universe, with a black-and-white film
noir look. Built with **Godot 4** and **GDScript**.

> Unofficial fan project. SCP content is CC BY-SA 3.0 — see [CREDITS.md](CREDITS.md).
> Progress and plans: [ROADMAP.md](ROADMAP.md).

## How to open and play (Windows)

1. **Get Godot.** Download *Godot Engine 4.7* (or newer 4.x) — the
   **standard** version, *not* ".NET" — from <https://godotengine.org/download/windows/>.
   It's a zip: extract it anywhere (e.g. `C:\Godot`). There's no installer;
   just double-click `Godot_v4.7-stable_win64.exe`.
2. **Get this project.** Clone the repository with Git (or GitHub Desktop), or
   on GitHub click **Code → Download ZIP** and extract it.
3. **Import it.** In Godot's Project Manager click **Import**, browse to the
   project folder, pick `project.godot`, then **Import & Edit**. The first
   import takes a little while.
4. **Play.** Press **F5** (or the ▶ "Run Project" button, top right). The main
   menu appears; click **Play**.

### Controls

| Key | Action |
|---|---|
| W A S D | Move |
| Mouse | Look |
| Shift | Sprint |
| Space | Jump |
| E | Interact: doors, card readers, pick up items |
| Hold E | Disarm someone (while holding a firearm) / release them |
| Tab | Inventory wheel (left click = hold item, right click = drop) |
| Left click | Use held item (shoot, heal, throw grenade) |
| R | Reload |
| Q | Drop held item |
| T | Throw held item |
| Left Ctrl | Hotkey: best keycard |
| X | Hotkey: medical item |
| G | Hotkey: grenade |
| 1 / 2 | Hotkey: primary / secondary firearm |
| F | Flashlight |
| Esc | Pause menu (frees the mouse) |

### The map — a new layout every round

The site is **built by code at the start of every round** from a random
seed (`scripts/level/facility_generator.gd`), so you can't rely on muscle
memory: zone shapes, corridors, dead ends, loops and where the rooms are all
change. (Set `map_seed` in the config to replay one layout.) Every map
always has the same *parts* and is always escapable:

- **Upper floor — Light Containment (LCZ, research):** the Class-D cell
  block (16 cells), SCP-914, the SCP-173 chamber, the Tertiary Server Room,
  test chamber, armory, locker room, a lockroom, labs, offices, the
  **SCP-999 pen** (a friendly blob that slowly heals people near it) and the
  **SCP-055 display**, plus living spaces: restrooms, break rooms, meeting
  rooms, a medical bay, storage and janitor's closets.
- **Lower floor (20 m below) — Heavy Containment (HCZ, industrial and
  dangerous):** SCP-096 and SCP-049 chambers, a 2x2 **Containment Pit**
  (walkway around a deep pit, ramp down to the containment unit),
  **pump stations** with steam vents that burst every few seconds (they
  hurt!), generator room (exposed wiring), archive, testing room, armory.
- **Lower floor — Entrance Zone (EZ, offices):** Gates A, B and C (lifts up
  to the Surface), security office, facility manager, the **intercom
  room**, a two-storey **cafeteria** with a balcony, offices, meeting rooms,
  medical bay, break rooms, restrooms.
- **Surface:** a night-time yard with the gate buildings, the MTF helipad,
  Chaos trucks, Warhead Control, **watchtowers** with ramps, sandbag
  **staging areas**, parked **vehicles** (trucks, jeeps, an APC), concrete
  **barriers** for cover and the **EXIT road** (escape zone). Their places
  change every round too.

How the zones connect never changes:

- **Light → Heavy Containment only by lift:** Checkpoint A (east edge) and
  Checkpoint B (west edge). The checkpoint doors need **Admin 1**. HCZ → EZ
  is a checkpoint door (Admin 1) on the boundary between them.
- **Lifts:** press **CALL** next to the doors, step in and use the panel on
  the cabin wall. The sign above the doors shows where the cabin is.
- **Class-D** start locked in their cells; the doors open 6 s into the round.

### Things to use in the facility

| Thing | What it does |
|---|---|
| **Terminals** (blue screens on stands) | Press E: site status (round time, cell doors, warheads). With a Containment 2 / Admin keycard **in hand** (or the *terminal access* perk) you also see how many people of each side are in each zone, both sides' influence and when the next reinforcements arrive. |
| **Intercom** (EZ intercom room) | Press E, type a message, Enter: everyone sees it. 60 s cooldown for everyone; a **Zone Manager** waits only 15 s and can cut in anytime. |
| **Lockers** | Random loot. Some are locked (the tag on the door says e.g. *C1* = Containment 1, *A2* = Armory 2): hold a matching keycard and press E. Lab lockers can hold **experimental items** (Experimental Serum EX-7: strong healing over time; Prototype Flashbang: bigger, longer flash). |
| **Crates** | Shoot them or blow them up; some have something inside. They're also cover. |
| **Barricade Kit** | Hold it, look at a **closed** door and left-click (3 s): planks are nailed across and the door can't be opened. Others tear it down by **holding E** on it (5 s) or destroy it (shooting, grenades). Janitors and Engineers do both twice as fast. |
| **Steam vents** (pump stations) | Burst every few seconds — time your run. |

### How a round works

Every round you spawn as a **random class**; the other characters are bots
(they stand still until Step 4).

| Class | Side | Spawns in | Starts with |
|---|---|---|---|
| Class-D | Class-D & Chaos | LCZ Class-D cells | nothing |
| Scientist | Foundation | LCZ labs & offices | Scientist keycard, First Aid Kit |
| Facility Guard | Foundation | EZ security office & offices | Guard keycard, pistol + 60, First Aid Kit, Flashbang, Light Armor |
| Containment Captain | Foundation | EZ security office | Containment Captain keycard, pistol + 120, First Aid Kit, Adrenaline, Flashbang, Combat Armor |
| Janitor *(minor role)* | Foundation | LCZ janitor's closets | Janitor keycard, Barricade Kit — barricades twice as fast |
| Zone Manager *(minor role)* | Foundation | LCZ offices | Zone Manager keycard, Painkillers — intercom priority, full terminal access |
| Containment Specialist *(minor role)* | Foundation | HCZ (pit, archive, testing) | Research Supervisor keycard, First Aid Kit — full terminal access |

Each Scientist slot has a 35 % chance (`minor_role_chance`) to become one of
the minor roles instead. Minor roles escape like Scientists.

- **Escaping:** reach the Surface and walk into the **EXIT road**. A Class-D
  becomes a **Chaos Insurgency Recruit**, a Scientist an **MTF Recruit**;
  **disarmed** escapees switch sides. You keep your items.
- Each round has one **MTF unit** (e.g. Epsilon-11 "Nine-Tailed Fox") and one
  **Chaos Insurgency cell** (e.g. CI-04 "Rogue Cell"); escapees join them.
- **Friendly fire** is off.
- **The round ends** when only one side is left alive, or when time runs out
  (then the side with more escapes wins). The round-end screen shows the
  winner and stats, then the next round starts.

### Warheads (Surface, Warhead Control building)

| | Delta Warhead | Gamma Warhead |
|---|---|---|
| Needs (held keycard) | Admin level 2 | Admin level 3 |
| Countdown | 90 s, can be cancelled until 10 s are left | 120 s, can't be cancelled |
| Effect | Everyone **underground** dies; the elevators stop working | The **whole site** is destroyed; the round ends (more escapes wins) |

During a countdown the facility lights turn red and a warning shows at the
top of the screen.

### Reinforcements, subclasses and influence

**Respawn waves:** every 3 minutes (`respawn_wave_seconds`) everyone who is
dead comes back on the Surface as an **MTF** squad (at the helipad) or a
**Chaos Insurgency** squad (at the trucks) of this round's unit/cell. While
dead you see the countdown in the top right.

**Influence (soft progression):** good play earns influence for your side
and the same amount of personal **XP**:

| Action | Points |
|---|---|
| Escape | +10 |
| A captive you disarmed escapes (to your side) | +15 |
| Escorting: being within 15 m of an ally who escapes | +5 |
| Disarming an enemy | +3 |
| Killing an enemy | +2 |

Side tiers: **Standard** (0), **Reinforced** (20), **Elite** (50),
**Spearhead** (90), shown as ■□□ in the top right. A higher tier means:

- **Escapees** become a better rank (MTF Recruit → Cadet → Rifleman →
  Sergeant; Chaos Recruit → Rifleman → Vanguard).
- **Waves** go to the side with more influence (ties alternate) and get a
  better leader and troopers, plus one more **specialist** per tier.
- **Personal XP** ranks: *Commended* (10) respawn with a spare First Aid
  Kit; *Decorated* (25) — the most experienced players get the leader and
  specialist slots first; *Veteran* (45) also respawn with a 25-point shield.

**Subclasses** (MTF and Chaos each have all four):

| Subclass | Perk | Gear |
|---|---|---|
| Medic | Medical items twice as fast, +25 % healing | 2 First Aid Kits, Adrenaline, Combat Armor |
| Combat Engineer | Barricades twice as fast, full terminal access | 2 Barricade Kits, Combat Armor |
| Explosives Specialist | Throws grenades 40 % further, carries 2 more | 3 HE grenades, Flashbang, Combat Armor |
| Heavy Gunner | 150 HP, double ammo limits, but 12 % slower | Heavy Armor, 300 rounds |

**Mobile Task Force ranks:** Recruit, Cadet, Rifleman, Breacher, Heavy,
Sergeant, Suppressor, Omega Operative, Commander. Units: Epsilon-11
"Nine-Tailed Fox", Nu-7 "Hammer Down", Beta-7 "Maz Hatters", Alpha-1 "Red
Right Hand", Eta-10 "See No Evil", Delta-4 "Minutemen", Zeta-9 "Mole Rats".
**Chaos Insurgency ranks:** Recruit, Rifleman, Breacher, Heavy, Saboteur,
Infiltrator, Vanguard, Operations Director; cells CI-01 Iron Fist … CI-10
Black Crown (see `scripts/game/factions.gd`). Planned weapons (rifles,
shotguns, machine guns) are in each class's **Notes** — for now everyone
carries the pistol.

### What to try

1. **Class-D:** search offices, the locker room and lockers for a Janitor or
   Zone Manager keycard, find a checkpoint lift (east or west edge of LCZ,
   Admin 1), cross HCZ to the EZ checkpoint, reach a Gate (Gate C needs only
   Admin 1), ride up and run to the EXIT road.
2. **Scientist / minor roles:** same idea; a Zone Manager can read terminals
   to see where the hostiles are and warn everyone over the intercom.
3. **Guard / Containment Captain:** start in the Entrance Zone; barricade
   doors, check terminals, or go up and try the Delta Warhead (the Captain's
   card has Admin 2).
4. **Die** (e.g. in a steam vent) and come back with the next
   reinforcement wave as MTF or Chaos.

## Items

### Keycards and doors

Doors have an access type (**Containment**, **Armory** or **Admin**) and a
level (1–3). A keycard opens the door if its level for that type is high
enough. The small squares on each card show its levels (rows: containment,
armory, admin).

| Keycard (Ctrl priority, best first) | Containment | Armory | Admin |
|---|---|---|---|
| O5 | 3 | 3 | 3 |
| Facility Manager | 3 | 0 | 3 |
| MTF Captain | 2 | 3 | 2 |
| Chaos Insurgency Access Device | 2 | 3 | 2 |
| MTF Sergeant | 2 | 2 | 1 |
| Containment Engineer | 3 | 0 | 2 |
| MTF Private | 1 | 2 | 1 |
| Research Supervisor | 2 | 0 | 1 |
| Guard | 1 | 1 | 1 |
| Zone Manager | 1 | 0 | 1 |
| Scientist | 2 | 0 | 0 |
| Janitor | 1 | 0 | 0 |

### Medical items (hotkey X)

| Item | Effect | Use time |
|---|---|---|
| Adrenaline | +40 temporary shield (fades), 20% faster for 8 s | 0.8 s |
| First Aid Kit | +65 health | 2.5 s |
| Painkillers | +50 health over 15 s | 1 s |

X picks the medical item you used last; otherwise Adrenaline → First Aid Kit
→ Painkillers. Switching items cancels using one.

### Grenades (hotkey G)

High-Explosive (preferred by G) and Flashbang. Left click to throw (armed);
**T** just tosses it unarmed.

### Ammo

Ammo doesn't use slots. Its limit depends on the armor you wear:

| Ammo | No armor | Light | Combat | Heavy |
|---|---|---|---|---|
| 9x19mm | 40 | 70 | 170 | 210 |
| 5.56x45mm | 40 | 40 | 120 | 200 |
| 7.62x39mm | 40 | 40 | 120 | 200 |
| 12/70 Buckshot | 14 | 14 | 54 | 74 |
| .44 Mag | 18 | 18 | 48 | 68 |

If a box has more than you can carry, the rest stays in the box. Dropping
armor drops any ammo (and items) above your new limits. (Only the pistol
exists so far; it uses 9x19mm.)

### Item tiers

Every item has hidden tier flags: **Common**, **Military Grade**, **Rare**,
**Extra Rare** (see each `.tres` in `resources/items/`). Holding anything
that isn't purely Common prevents you from being disarmed. Tiers will also
matter for special places later.

## Classes

Each class is a `.tres` file in `resources/classes/` — double-click one to
change its health, colour, starting items, ammo or what it becomes after
escaping. Spawn rooms are the markers under `SpawnPoints/<group>` in the
level.

## Inventory and carry limits

You have **8 slots**. Each item belongs to a category, and each category has
a carry limit (shown on the Tab screen):

| Category | Default | Light Armor | Combat Armor | Heavy Armor |
|---|---|---|---|---|
| SCP Items | 3 | 3 | 3 | 3 |
| Keycards | 3 | 3 | 3 | 3 |
| Treatment Items | 3 | 3 | 3 | **4** |
| Firearms | 1 | **2** | **2** | **3** |
| Grenades | 2 | 2 | **3** | **4** |
| Radios | 1 | 1 | 1 | 1 |
| Special Weapons | 1 | 1 | 1 | 1 |
| Armor | 1 | 1 | 1 | 1 |

- Other items (e.g. coins, later) have no category limit, only the 8 slots.
- Armor is worn just by carrying it.
- **Changing the limits ("server owners"):** the first time a match starts,
  the game writes `gameplay_config.cfg` to
  `%APPDATA%\SCP-Noirverse\`. Open it with Notepad,
  change the numbers and start a new match:
  - item limits: 0–8, **0 = that item type can't be picked up**;
  - ammo limits (one section per armor type): 0–65535, **0 = unlimited**;
  - `[round]`: `spawn_queue` (D = Class-D, S = Scientist, G = Guard,
    C = Containment Captain, J = Janitor, Z = Zone Manager, X = Containment
    Specialist, e.g. `"DSDGDSCDGDSD"`), `player_count` (you + bots, default
    10), `round_time_limit_minutes` (0 = none), `friendly_fire`,
    `restart_delay_seconds`, `minor_role_chance` (0–1),
    `respawn_wave_seconds` (0 = no respawns), `map_seed` (0 = random map
    every round, any other number = always that map).

  See `gameplay_config.example.cfg`. The built-in defaults are in
  `resources/gameplay_config.tres`; the armor carry bonuses are on each
  armor's `.tres` file in `resources/items/`.

## Handy Godot tips for beginners

- **Add loot to rooms:** the map is made by code, so items are listed in
  `scripts/level/facility_generator.gd`: `ROOM_LOOT` (loose items per room
  type), `LOCKER_LOOT` (locker tables) and `GUARANTEED` (always somewhere in
  a zone). Item ids are the file names in `resources/items/`.

- **F5** runs the whole game. **F6** runs only the scene you have open —
  great for testing one piece. **F8** (or the ■ button) stops.
- Scenes (`.tscn`) open from the **FileSystem** dock (bottom-left).
  Hold the **right mouse button** + **WASD** to fly around in the 3D editor.
- Click any node in the **Scene** dock (top-left) to edit it in the
  **Inspector** (right). Example: select a lamp's `Light` node and change
  `Light Energy`.
- **Door text:** select a door and change **Zone Code** / **Zone Name**
  (e.g. "HCZ" / "HEAVY CONTAINMENT ZONE").
- **Wall look:** open `resources/materials/concrete_wall.tres` and change the
  shader parameters (panel width, colours, trim height…).
- **The map** is generated by `scripts/level/facility_generator.gd` (rooms,
  furniture, surface) using `scripts/level/layout_generator.gd` (zone shapes,
  room placement, corridors). To see a map, press F5 and walk around, or
  change `map_seed` to compare layouts. Room furniture is in the `_furnish`
  functions — each `box(...)` line is one block (centre, size, material).
- Static walls and furniture are merged into a few big meshes per 12 m
  "chunk" (`scripts/level/mesh_batch.gd`), which is why building a map only
  takes a fraction of a second.
- Errors show in the **Debugger** panel at the bottom while the game runs.

## Project structure

```
project.godot            Project settings (input keys live under Project → Project Settings → Input Map)
scenes/
  ui/                    Main menu, credits, HUD, pause menu
  game/game.tscn         The in-game scene: loads a level, spawns the player
  player/character.tscn  A first-person humanoid
  props/                 Doors, training dummy, hazards (terminals, lockers, crates,
                         barricades, the intercom and steam vents are made in code)
  items/item_pickup.tscn An item lying in the world
  effects/               The noir full-screen filter
scripts/                 GDScript code, mirroring the scenes folders
  core/                  Shared building blocks (CharacterInput, InputSource)
  level/                 The procedural map: layout planner, generator, mesh batching
shaders/noir_post.gdshader         Black & white, grain, vignette, scratches
shaders/facility_surface.gdshader  Wall panels, floor and ceiling tiles
assets/textures/         Our own SVG artwork (SCP emblem, hazard stripes)
resources/               Materials, environment (fog, lighting), UI theme
  items/                 Item definitions (.tres) — double-click to edit damage, heal amount...
```

## How the code is organised (ready for bots & multiplayer)

The character never reads the keyboard. Instead:

```
LocalPlayerInput  ──┐
BotInput (later)  ──┼──▶ CharacterInput (move, look, jump, interact…) ──▶ CharacterController
NetworkInput (later)┘
```

- `InputSource` (`scripts/core/input_source.gd`) is "whoever controls a
  character". `LocalPlayerInput` reads your keyboard/mouse.
- Each physics tick the character asks its input source for a
  `CharacterInput` snapshot and acts on it. Bots and online players will just
  be different input sources driving the same character code.
- Items work the same way: the `ItemHandler` uses the held item when the
  `CharacterInput` says `use_item`, so bots will be able to shoot and heal too.
  `Health` and `Inventory` are small reusable nodes you can add to anything.
- `RoundManager` (in `game.tscn`) runs the round: it gets a list of player
  InputSources and fills the remaining slots with bots. For online play the
  server will pass in one input per connected player.
- There are no global singletons (autoloads) holding game state; the match
  lives inside `game.tscn`, so a server can later run the same logic.
