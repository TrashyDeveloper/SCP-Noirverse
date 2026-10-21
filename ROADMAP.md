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

## Step 2.7 — Look & feel ✅
- [x] Round inventory wheel (8 segments, metal rims, item info in the centre)
- [x] Grenade explosions bring the colours back for a moment (stronger when closer)
- [x] Light Containment Zone style: dark metal wall panels with seams, trim and kick plates; tiled floors; LCZ doors with frames, vents, hazard stripe and SCP emblem
- [ ] Later: per-zone door/wall styles for Heavy Containment, Entrance and Surface

## Step 3 — Classes & rounds ✅
- [x] Class definitions (Class-D, Scientist, Facility Guard, plus MTF Private and Chaos Conscript for escapees) with spawn points, starting items, ammo and colours
- [x] Sides (Foundation vs Class-D & Chaos; SCPs later), friendly fire off by default
- [x] Round manager: spawn queue, random class for the player, bots fill the other slots, round timer
- [x] Gate A exit wing with escape zone; escapees change class and keep their items; disarmed escapees switch sides
- [x] Win conditions: last side alive, or most escapes when time runs out; round-end screen with stats and auto restart
- [x] Round settings in the gameplay config (spawn queue, player count, time limit, friendly fire, restart delay)
- [ ] Later: spectating after death, respawn waves (Step 7), per-class models

## Step 3.5 — The site map & teams ✅
- [x] Four zones: Light Containment, Heavy Containment, Entrance Zone, Surface (grid-built, ~216 × 60 m underground + a ~84 × 100 m surface yard)
- [x] Zone looks (wall/floor styles, LCZ/HCZ/EZ door stencils), checkpoints between zones
- [x] Rooms: Class-D cells, labs, offices, lockers, test chamber, armories, SCP-173/096/049 chambers (empty), generator & server rooms, security office, manager office, cafeteria
- [x] Gates A, B and C with elevators to the Surface; Surface yard with helipad, Chaos trucks, Warhead Control and the EXIT road (escape zone)
- [x] Spawns: Class-D & Scientists in LCZ, Guards & Containment Captain in EZ, MTF & Chaos on the Surface, SCP points in HCZ
- [x] Containment Captain class and keycard; escapes turn into MTF Recruit / Chaos Insurgency Recruit
- [x] All MTF ranks and Chaos ranks as classes; MTF units and CI cells (one of each per round)
- [x] Delta Warhead (underground) and Gamma Warhead (whole site) with countdowns, alarm lights and detonation
- [ ] Later: more weapons for the MTF/CI ranks, per-zone room variety, zone lockdowns/decontamination

## Step 3.6 — Classic Light Containment ✅
- [x] Rooms spanning several grid cells
- [x] Class-D cell block: 16 numbered cells with bunks, toilets and sinks; Class-D start locked in, cells open 6 s into the round with an announcement
- [x] SCP-914 room (machine, intake/output booths, dial; refining comes later)
- [x] Lockroom (double doors), computer room, restrooms, storage
- [ ] Later: SCP-914 refining items, LCZ decontamination timer

## Step 3.7 — Two floors, lifts and signature rooms ✅
- [x] Light Containment on the upper floor; Heavy Containment + Entrance Zone 20 m below
- [x] Checkpoint A and Checkpoint B with lifts — the only way between Light and Heavy Containment
- [x] Lift redesign: enclosed cabin (walls, handrails, light, control panel with display), two-piece sliding doors, frames, CALL buttons, "lift at ..." indicators
- [x] SCP-173 chamber moved to Light Containment (striped entrance, placard, white antechamber, viewing window, containment door)
- [x] Tertiary Server Room replaces the computer room (glass-walled control room, server clusters, heat shafts, blue neon)
- [x] SCP-914 room redesign (raised booths with ramps and railings, hazard zones, shelves)
- [x] Blue-lit screens on card readers; HCZ archive and testing room

## Step 3.8 — A living, changing facility ✅
- [x] Procedural map every round (seeded; `map_seed` in the config to repeat one): irregular zone shapes, winding corridors, dead ends, loops, key rooms in new places each round
- [x] Fast building: static geometry merged into chunked meshes + one collision shape per floor
- [x] Living spaces: offices, meeting rooms, restrooms, break rooms, cafeteria (two storeys), janitor's closets, medical bays, storage
- [x] Zone flavour: LCZ research (labs, experimental items, SCP-999 pen, SCP-055 display); HCZ industrial (containment pit with ramp, pump stations with steam vents); Surface watchtowers, staging areas, vehicles, barriers
- [x] Terminals with limited info (more with the right keycard or perk), the intercom (Zone Manager priority), locked lockers with random loot, breakable crates, barricade kits
- [x] Minor roles: Janitor, Zone Manager, Containment Specialist
- [x] MTF & Chaos subclasses: Medic, Combat Engineer, Explosives Specialist, Heavy Gunner (with perks)
- [x] Respawn waves (dead players return as MTF or Chaos) and influence/XP: tiers improve escapee ranks and waves, personal XP gives small bonuses
- [x] Tests: 200 seeds plan correctly; flood-fill check that every door, lift and the exit can be reached on foot
- [ ] Later: SCP-914 refining, SCPs that move (Step 5), more vehicle use, decontamination timer

## Step 3.9 — Guns, machines, warheads, bodies and sound ✅
- [x] New guns: SMG, Vector, M4, AK-47, Light Machine Gun, MG-60, Sniper Rifle; detailed models (pistol remodelled); automatic fire, spread, recoil, aiming/zoom
- [x] SCP-914 works: dial with five settings, key, intake/output booths, item recipes and effects on people; new clockwork model with spinning gears
- [x] Alpha Warhead silo in Heavy Containment (rising missile, gantry arms, beacons, steam, countdown screen)
- [x] Gamma Warhead is a spinning fusion reactor; spinning up brings the colours back around it
- [x] Jointed, animated player bodies dressed for every role; others' held items visible
- [x] Sound effects (generated, original) and menu music (placeholder or your own track)
- [ ] Later: settings menu with volume sliders, per-weapon reload animations, more SCP-914 recipes

## Step 3.10 — Menus and admin tools ✅
- [x] Settings menu (mouse, invert, FOV, volumes, fullscreen, V-Sync, shadows, film grain, brightness), saved per player
- [x] Main menu redesign (emblem, gradient panel, tips, drifting camera); key list and influence removed from the in-game screen
- [x] Admin menu (N): players list with go to / bring / kill / select, teleport to rooms and zones, item giver, role switch, god mode, noclip (Alt), forced warheads
- [ ] Later: key rebinding, admin permissions for online servers

## Step 4 — AI bots
- [ ] `BotInput` (an `InputSource` driven by AI) using navigation meshes
- [ ] Simple behaviours: wander, flee, follow, open doors
- [ ] Guards shoot hostiles with the pistol

## Step 5 — The SCPs
- [ ] SCP-173: moves only when no one is looking; blinking meter for humans
- [ ] SCP-096: enrages when its face is seen, then hunts that target
- [ ] SCP-049: slow, deadly touch
- [ ] Containment chambers; playing as an SCP (and SCP bots)

## Step 6 — Facility variety
- [x] Zones, checkpoints, gate elevators, surface escape (done early in Step 3.5)
- [x] Modular room pieces so the layout can vary each round (done in Step 3.8)

## Step 7 — Reinforcements
- [x] Respawn waves on the Surface using the MTF / Chaos ranks and the round's unit/cell (Step 3.8)
- [ ] Their goals: MTF contain SCPs and escort scientists, Chaos help Class-D
- [x] New weapons for the ranks (SMG, rifles, machine guns — Step 3.9); shotgun later

## Step 8 — Sound & polish
- [ ] Original sound effects and ambience (footsteps, doors, alarms, SCP sounds)
- [ ] Settings menu (mouse sensitivity, volume, graphics)
- [ ] Better low-poly models (still original)

## Step 9 — Online multiplayer
- [ ] Host/join (Godot high-level multiplayer, ENet)
- [ ] `NetworkInput`: server-authoritative movement from client commands
- [ ] Sync items, doors, rounds; bots fill empty slots
