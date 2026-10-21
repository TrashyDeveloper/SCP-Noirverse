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

## Step 2 — Items & inventory ✅
- [x] Item pickups lying in the world (keycards L1–L3, medkit, pistol, ammo)
- [x] Inventory (6 slots + spare ammo), select with 1–6 / mouse wheel, drop with Q
- [x] Keycard levels open matching doors (carried cards count)
- [x] Health, damage and death screen; medkit heals
- [x] Pistol: hitscan shots, magazine + reload, muzzle flash, recoil, bullet holes, hit marker
- [x] Training dummies (firing range) and an electrical hazard for testing

## Step 2.5 — Inventory rework ✅
- [x] No hotbar: 8-slot inventory screen on **Tab** (left click hold, right click drop)
- [x] Item categories with carry limits (SCP items, keycards, treatment, firearms, grenades, radios, special weapons, armor; others only limited by slots)
- [x] Armor (Light / Combat / Heavy) raises some limits; dropping armor drops the extras
- [x] Per-ammo-type limits
- [x] Gameplay config: defaults in `resources/gameplay_config.tres`, overridable in `user://gameplay_config.cfg` (limits 0–8, 0 = can't pick up)
- [ ] Later: flashlight and coin as inventory items, armor damage reduction, more item types per category

## Step 2.6 — Item basics ✅
- [x] 12 keycards with Containment / Armory / Admin access levels; doors need the keycard **in hand**
- [x] Card readers on both sides of every door; thrown keycards that hit a reader operate the door
- [x] Hotkeys: Ctrl keycard (best card for the nearby door), X medical (last used first), G grenade, 1/2 primary/secondary firearm
- [x] Throwing any held item (T)
- [x] Medical items with use times: First Aid Kit, Painkillers (heal over time), Adrenaline (shield + speed)
- [x] Grenades: High-Explosive (damage with falloff, blocked by walls) and Flashbang (blinds if looking)
- [x] 5 ammo types with armor-dependent limits, configurable (0–65535, 0 = unlimited); partial ammo pickup; excess dropped
- [x] Item tier flags (Common / Military Grade / Rare / Extra Rare)
- [x] Disarming (hold E with a firearm): target drops everything, can't open inventory/doors or pick up; release by holding E, or automatically when the captor dies, has no firearm or is too far
- [x] Test NPC (idle) to practise disarming
- [ ] Later: custom hotkeys in a settings menu, glass that breaks from thrown items, disarm effects on escape (Step 3), third-person held items

## Step 3 — Classes & rounds
- [ ] Class definitions (Class-D, Scientist, Facility Guard) with spawn points, starting items and colours
- [ ] Round manager: assign random classes, start/end a round, round-end screen
- [ ] Escape exit: Class-D / Scientists who reach it "escape" (disarmed escapees switch sides)
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
