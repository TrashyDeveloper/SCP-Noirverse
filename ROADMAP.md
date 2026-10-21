# SCP: Noirverse — Roadmap

Small, playable steps. Each step ends with something you can run in Godot,
and is committed + pushed once it works. `[x]` = done.

## Step 1 — Foundations ✅
- [x] Godot 4 project (GDScript, Forward+ renderer)
- [x] First-person controller: walk, sprint, jump, mouse look, head bob
- [x] Input separated from logic (`InputSource` → `CharacterInput` → `CharacterController`), ready for bots and networking
- [x] Interaction system (look at something + press **E**)
- [x] Sliding doors with a "clearance level" (locked doors show a red light)
- [x] Small noir test facility: 4 rooms, 3 corridors, 4 doors, props, signs
- [x] Noir look: black & white post-process, film grain, scratches, vignette, flickering lights, volumetric fog, flashlight (**F**)
- [x] Main menu (Play / Credits / Quit) with an animated 3D backdrop
- [x] Credits screen with CC BY-SA 3.0 attribution
- [x] Pause menu (**Esc**)

## Step 2 — Items & inventory
- [ ] Item pickups lying in the world (keycards, medkit, pistol)
- [ ] Inventory (small slot bar) and item use
- [ ] Keycard levels open matching doors
- [ ] Health, damage and death; medkit heals

## Step 3 — Classes & rounds
- [ ] Class definitions (Class-D, Scientist, Facility Guard) with spawn points, starting items and colours
- [ ] Round manager: assign random classes, start/end a round, round-end screen
- [ ] Escape exit: Class-D / Scientists who reach it "escape"
- [ ] Win conditions per team

## Step 4 — AI bots
- [ ] `BotInput` (an `InputSource` driven by AI) using navigation meshes
- [ ] Simple behaviours: wander, flee, follow, open doors
- [ ] Guards shoot hostiles with the pistol

## Step 5 — The SCPs
- [ ] SCP-173: moves only when no one is looking; blinking meter for humans
- [ ] SCP-096: enrages when its face is seen, then hunts that target
- [ ] SCP-049: slow, deadly touch
- [ ] Containment chambers; playing as an SCP (and SCP bots)

## Step 6 — The full facility
- [ ] Zones: Light Containment, Heavy Containment, Entrance, Surface
- [ ] Checkpoints between zones, elevators/gates
- [ ] Modular room pieces so the layout can vary each round
- [ ] Surface escape area

## Step 7 — Reinforcements
- [ ] Respawn waves: Nine-Tailed Fox (MTF Epsilon-11) and Chaos Insurgency
- [ ] Their goals: MTF contain SCPs and escort scientists, Chaos help Class-D

## Step 8 — Sound & polish
- [ ] Original sound effects and ambience (footsteps, doors, alarms, SCP sounds)
- [ ] Settings menu (mouse sensitivity, volume, graphics)
- [ ] Better low-poly models (still original)

## Step 9 — Online multiplayer
- [ ] Host/join (Godot high-level multiplayer, ENet)
- [ ] `NetworkInput`: server-authoritative movement from client commands
- [ ] Sync items, doors, rounds; bots fill empty slots
