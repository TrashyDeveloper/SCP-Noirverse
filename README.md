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

### The map

The site has two underground floors and the Surface.

**Upper floor — Light Containment (LCZ):**

```
   D D D # L # S S      D = Class-D cell block     L = laboratory
   . W O # . # # a      S = Tertiary Server Room   W = restrooms   O = office
   b # # # X # . .      a = CHECKPOINT A (lift)    b = CHECKPOINT B (lift)
   K # Z # . # 7 7      X = lockroom   K = lockers  Z = storage    7 = SCP-173
   A # # 9 9 # T .      A = LCZ armory  9 = SCP-914  T = test chamber
```

**Lower floor (20 m below) — Heavy Containment (HCZ) and Entrance Zone (EZ):**

```
   HEAVY CONTAINMENT              ENTRANCE ZONE
   . 2 . . R . . . .            A # O . B .
   . # # # # # # a .            # # # # # .
   b # . G # . # . .            # S . M # .
   . 3 # # # H # # =  checkpoint # # # # # .
   . . . E # . . . .            C . O F . .
   2/3 = SCP-096 / SCP-049, R = archive, G = generators, H = HCZ armory,
   E = testing room, a/b = the lifts up to Light Containment.
   A/B/C = Gates A, B, C (lifts up to the Surface), S = security office,
   M = facility manager, O = offices, F = cafeteria
```

- **Light → Heavy Containment only by lift:** Checkpoint A (east side) and
  Checkpoint B (west side) each have a lift. The checkpoint doors need
  **Admin 1**. HCZ → EZ is a normal checkpoint door (Admin 1).
- **Lifts:** press **CALL** next to the lift doors to bring the cabin, step
  in and use the panel on the cabin wall to go up or down. The sign above
  the doors shows where the lift is.
- **Class-D cell block:** 16 numbered cells (D-01 … D-16); Class-D start
  locked in and the doors open 6 s into the round.
- **SCP-173:** wide entrance with striped pillars and a "SCP-173 / EUCLID"
  placard, white antechamber with a viewing window, then the containment
  door (Containment 3) into the chamber (high observation window, vent fan).
- **Tertiary Server Room:** lit control room behind a glass wall, dark
  server clusters with frosted glass heat shafts and blue neon floor lights.
- **SCP-914:** intake and output booths on raised platforms with ramps and
  railings, hazard zones, the dial, shelves with supplies.
- Sprinting from a Class-D cell to the Surface exit takes about a minute.

**Surface** (reached by the Gate A/B/C lifts from the Entrance Zone): a night-time yard with
the Gate A/B/C buildings, the **MTF helipad**, the **Chaos Insurgency trucks**,
the **Warhead Control** building and, to the north, the **EXIT road — the
escape zone**.

**Door access** (hold the keycard, Ctrl): Class-D cells open by themselves;
locker room Containment 1; test chamber and SCP-914 Containment 2; SCP
chamber doors Containment 3; LCZ armory Armory 1, HCZ armory Armory 2;
archive and testing room Containment 2; generator room Admin 1; security
office Armory 1; facility manager Admin 2; **Checkpoints A/B and the HCZ→EZ
checkpoint Admin 1**; **Gates A and B Admin 2, Gate C (emergency exit)
Admin 1**.

### How a round works

Every round you spawn as a **random class**; the other characters are bots
(they stand still until Step 4).

| Class | Side | Spawns in | Starts with |
|---|---|---|---|
| Class-D | Class-D & Chaos | LCZ Class-D cells | nothing |
| Scientist | Foundation | LCZ labs & offices | Scientist keycard, First Aid Kit |
| Facility Guard | Foundation | EZ security office & offices | Guard keycard, pistol + 60, First Aid Kit, Flashbang, Light Armor |
| Containment Captain | Foundation | EZ security office | Containment Captain keycard, pistol + 120, First Aid Kit, Adrenaline, Flashbang, Combat Armor |

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

### Teams (for reinforcements in Step 7)

**Mobile Task Force:** MTF Recruit, Cadet, Rifleman, Breacher, Heavy,
Sergeant, Suppressor, Omega Operative, Commander. Units: Epsilon-11
"Nine-Tailed Fox", Nu-7 "Hammer Down", Beta-7 "Maz Hatters", Alpha-1 "Red
Right Hand", Eta-10 "See No Evil", Delta-4 "Minutemen", Zeta-9 "Mole Rats".

**Chaos Insurgency:** Chaos Recruit, Rifleman, Breacher, Heavy, Saboteur,
Infiltrator, Vanguard, Operations Director. Groups: Military Cells, R&D
Cells, Delta Command. Cells: CI-01 Iron Fist … CI-10 Black Crown (see
`scripts/game/factions.gd`).

All of them already exist as classes in `resources/classes/` with their own
health, keycards, armor and grenades. Right now only the Recruits appear (by
escaping); the others will arrive with respawn waves. Their planned weapons
(rifles, shotguns, machine guns) are written in each class's **Notes** — for
now everyone carries the pistol.

### What to try

1. **Class-D:** grab a Janitor or Zone Manager keycard in the LCZ offices /
   locker room, pass the checkpoint (Admin 1), cross HCZ, reach Gate C
   (Admin 1) in the south-west of the Entrance Zone, ride up and run to the
   EXIT road.
2. **Scientist:** same route; look for a Zone Manager card first.
3. **Guard / Containment Captain:** start in the Entrance Zone; head into
   the facility, or up to the Surface to try the Delta Warhead (the Captain's
   card has Admin 2).

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
    C = Containment Captain, e.g. `"DSDGDSCDGDSD"`), `player_count` (you +
    bots, default 10), `round_time_limit_minutes`
    (0 = none), `friendly_fire`, `restart_delay_seconds`.

  See `gameplay_config.example.cfg`. The built-in defaults are in
  `resources/gameplay_config.tres`; the armor carry bonuses are on each
  armor's `.tres` file in `resources/items/`.

## Handy Godot tips for beginners

- **Place an item in a level:** open `scenes/levels/test_facility.tscn`, drag
  `scenes/items/item_pickup.tscn` from the FileSystem dock into the 3D view,
  then drag an item from `resources/items/` onto its **Item Data** field in
  the Inspector. (Its model appears when you run the game.)
- **Change a door's lock:** select a door under `Doors` and set
  **Required Clearance** (0 = no keycard needed).

- **F5** runs the whole game. **F6** runs only the scene you have open —
  great for testing one piece. **F8** (or the ■ button) stops.
- Scenes (`.tscn`) open from the **FileSystem** dock (bottom-left).
  Double-click `scenes/levels/test_facility.tscn` to see the facility in 3D.
  Hold the **right mouse button** + **WASD** to fly around in the editor.
- Click any node in the **Scene** dock (top-left) to edit it in the
  **Inspector** (right). Example: select a lamp's `Light` node and change
  `Light Energy`.
- **Door text:** select a door and change **Zone Code** / **Zone Name**
  (e.g. "HCZ" / "HEAVY CONTAINMENT ZONE").
- **Wall look:** open `resources/materials/concrete_wall.tres` and change the
  shader parameters (panel width, colours, trim height…).
- **The map** is `scenes/levels/facility.tscn`. It was generated from the
  grid above, but it's a normal scene: open it and move, add or delete
  anything. Each zone is a folder under `Zones/`; doors, lights, items,
  signs, elevators, the Surface and spawn points have their own folders.
- The facility is built from `CSGBox3D` blocks — select one and drag the
  orange handles to resize, or **Ctrl+D** to duplicate.
- Errors show in the **Debugger** panel at the bottom while the game runs.

## Project structure

```
project.godot            Project settings (input keys live under Project → Project Settings → Input Map)
scenes/
  ui/                    Main menu, credits, HUD, pause menu
  game/game.tscn         The in-game scene: loads a level, spawns the player
  player/character.tscn  A first-person humanoid
  levels/                Facility maps
  props/                 Doors, training dummy, hazards
  items/item_pickup.tscn An item lying in the world
  effects/               The noir full-screen filter
scripts/                 GDScript code, mirroring the scenes folders
  core/                  Shared building blocks (CharacterInput, InputSource)
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
