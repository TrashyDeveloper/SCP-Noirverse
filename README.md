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

### What to try

1. In the Class-D room, a **Janitor Keycard** lies on the middle bunk (and
   Painkillers on the left bunk). A test NPC stands in the room.
2. The east door (to the Research Office) needs **Containment Level 1**.
   Doors only open with a keycard **in your hand**: press **Ctrl** to pull
   out the best card, then **E**. Or throw the card (**T**) at the small
   card reader next to the door!
3. In the Office: Scientist, Guard and Zone Manager keycards (you can only
   carry 3 keycards), a First Aid Kit, Adrenaline and Light Armor.
   Careful with the sparking wiring in the corner.
4. The west door (Storage) needs **Armory Level 1** → the Guard card.
   Inside: pistol, ammo, grenades, Heavy Armor, first aid kits.
5. The north door (Containment Chamber, now a firing range) needs
   **Containment Level 2** → the Scientist card. Near a door, **Ctrl** picks
   the best card that actually opens *that* door.
6. Grab the pistol (**1**), go back to the NPC and **hold E** on it to disarm
   it: it drops everything and can't pick things up or open doors. Hold E
   again to release it (it's also released if you drop all your firearms
   or walk far away). You can't disarm someone holding a non-common item
   (e.g. a gun).
7. Throw a grenade at the dummies (**G**, then left click): High-Explosive
   damages everything in range that isn't behind a wall; a Flashbang blinds
   whoever looks at it. When a grenade goes off nearby, the colours come
   back for a moment.

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
  `%APPDATA%\Godot\app_userdata\SCP Noirverse\`. Open it with Notepad,
  change the numbers and start a new match:
  - item limits: 0–8, **0 = that item type can't be picked up**;
  - ammo limits (one section per armor type): 0–65535, **0 = unlimited**.

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
- There are no global singletons (autoloads) holding game state; the match
  lives inside `game.tscn`, so a server can later run the same logic.
