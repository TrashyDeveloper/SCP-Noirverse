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
| E | Interact (open/close doors) |
| F | Flashlight |
| Esc | Pause menu (frees the mouse) |

### What to try (Step 1)

- Walk to a door, look at it: you'll see **[E] Open door**. Press E.
- The door to *Storage* (west corridor) has a **red** light: it needs a
  level-1 keycard, which arrives in Step 2.
- Turn on the flashlight (**F**) in a dark corner.
- Watch the lights flicker.

## Handy Godot tips for beginners

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
  props/                 Doors and other reusable objects
  effects/               The noir full-screen filter
scripts/                 GDScript code, mirroring the scenes folders
  core/                  Shared building blocks (CharacterInput, InputSource)
shaders/noir_post.gdshader   Black & white, grain, vignette, scratches
resources/               Materials, environment (fog, lighting), UI theme
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
- There are no global singletons (autoloads) holding game state; the match
  lives inside `game.tscn`, so a server can later run the same logic.
