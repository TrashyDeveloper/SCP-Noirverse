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
| E | Interact: open/close doors, pick up items |
| 1–6 / mouse wheel | Choose which item to hold |
| Left click | Use held item (shoot pistol, use medkit) |
| R | Reload |
| Q | Drop held item |
| F | Flashlight |
| Esc | Pause menu (frees the mouse) |

### What to try

1. In the Class-D room, a **Level 1 Keycard** lies on the middle bunk. Look at
   it and press **E**.
2. Go through the west corridor. The *Storage* door has a **red** light (it
   needs Level 1); with the card you can now open it.
3. In Storage, grab the **pistol**, the **Level 2 Keycard**, ammo and a
   medkit.
4. Open the north *Containment Chamber* (Level 2): it's a temporary firing
   range. Press the pistol's number key, **left click** to shoot the dummies,
   **R** to reload.
5. In the *Research Office* (east), careful with the sparking **exposed
   wiring** in the corner: it hurts! Hold a medkit and left click to heal.
   Stay in the sparks too long and you'll see the death screen.

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
shaders/noir_post.gdshader   Black & white, grain, vignette, scratches
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
