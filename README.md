# roam
A game made with Godot where players traverse through a series of procedurally generated dungeons to gather loot and face more difficult bosses.

## Requirements
- Godot 4.7 (GL Compatibility renderer)

## Project structure
```
assets/
  animations/   Character animations (rig_medium, rig_large)
  BinbunVFX_Vol2/  Binbun's Stylized Hit FX and Elemental Magic FX (free versions, CC0): the hit
                flashes and the cast circle
  characters/   Adventurer and skeleton models
  dungeon/      Dungeon pieces by type (floors, walls, stairs, ...)
  equipment/    Weapons, shields and items
  licenses/     Asset pack licenses
scenes/
  characters/   One scene per character, each with its own collision
  dungeon/      One scene per dungeon piece, each with its own collision
  equipment/    One scene per item, each with its own collision
  effects/      Arrow, magic bolt and melee impact effects
  playground/   Movement, animation, inventory and combat test scenes
  ui/           The health, mana and stamina bars, and the bar over each enemy
shaders/        The enemy health bar's billboard fill and the hit outline
resources/
  attacks/      AttackStep resources: one per attack clip, shared by every weapon that uses it
  potions/      Potion resources: what each potion restores and over how long
scripts/
  player.gd               Player movement and animation: locomotion, stances, dodge and actions
  animation_test.gd       Animation test scene: camera, HUD, action keys and animation browser
  weapon.gd               How a weapon is held, its combo and the stance it gives the player
  shield.gd               An off-hand shield and its block animations
  upper_body_twist.gd     Twists the spine, chest and head toward the camera while the legs walk another way
  attack_step.gd          One step of a combo: its animation and when it can chain
  projectile.gd           Moves an effect forward, damages the first hurtbox it reaches and stops at walls
  stat_pool.gd            A refilling pool (mana, stamina): spend, drain, restore, restore over time, passive regen
  health.gd               A StatPool that can take damage, heal, die and be revived
  hurtbox.gd              The area that receives hits and passes them to a Health
  hit.gd                  One hit: its damage, who dealt it and where it came from
  potion.gd               A potion's restores, poured into the drinker's Health, Mana and Stamina
  breakable.gd            Frees an object when its Health runs out
  vitals_hud.gd           Health, mana and stamina bars bound to three pools
  damage_numbers.gd       Pops a floating number over every hurtbox that takes a hit
  floating_number.gd      One floating number that rises, fades and frees itself
  enemy_health_bar.gd     The health bar that floats over an enemy's head
  hurtbox_watcher.gd      Base for scene-wide hit listeners: watches every hurtbox, present and future
  hit_outlines.gd         Flashes an outline on whatever the player's hits land on
  hit_effects.gd          Plays a hit flash where the player's hits land on an enemy
  cast_effects.gd         Opens a glowing circle under the player while a wand or staff casts
  projectile_warm_up.gd   Draws every projectile and an arena-wide light once at load, so the first shot doesn't compile shaders
  warm_up_spot.gd         The point under the floor where warm-ups draw: on screen to the renderer, hidden by the floor
  loading_cover.gd        Black cover that hides the arena while the warm-ups compile, then fades out
  combat_test.gd          Combat test scene: camera, weapon pickups and stat test keys
```

## Player controls
`player.gd` drives the player in the playground, the animation test scene and the dungeon
preview's walk mode.

| Key | Action | Animations |
| --- | --- | --- |
| W | Walk forward (Shift: run) | `Walking_A` / `Running_A`, idle `Idle_A` (`Idle_B` after standing still for a while) |
| A / D, diagonals | Walk or run sideways | `Walking_A` / `Running_A` with the legs turned toward the direction of travel |
| S (and back diagonals) | Walk backwards (2.5 m/s) | `Walking_Backwards` |
| Space | Jump | `Jump_Start`, `Jump_Idle`, `Jump_Land` |
| Right mouse | Hold with a shield to block in place, or with a crossbow or bow to aim in place; press with a wand for a long cast, or with a staff to raise it overhead | see Shields, Ranged weapons and Magic |
| Alt | Dodge toward the move direction, or back when standing still | `Dodge_Forward`, `Dodge_Backward`, `Dodge_Left`, `Dodge_Right` |
| Left mouse / J | Attack with the held weapon, or punch and kick with an empty main hand | the weapon's combo, or its `running_attack_animation` while sprinting |

The camera, not WASD, decides which way the character faces. While moving, the legs turn toward the
direction of travel and play the normal walk or run (or the backwards walk when moving more than
100° away from the view), and `upper_body_twist.gd`, a `SkeletonModifier3D`, twists the spine, chest
and head back toward the camera (up to 90°, split 35/35/30). Attacking or blocking turns the whole
character to the camera. When it stops, it settles facing where it was looking, and the camera then
orbits freely without turning it. The camera's yaw comes from `_camera_yaw()`, which
`dungeon_explorer.gd` overrides with the camera rig's rotation.

The general animations are methods for gameplay code to call: `interact()`, `pick_up(item)`,
`throw()`, `use_item()`, `take_hit()` (`Hit_A` or `Hit_B`), `die()` (`Death_A` or `Death_B`,
ending on the matching `_Pose`) and `spawn(from_air)` (`Spawn_Ground` or `Spawn_Air`). Each one
holds the player in place until it finishes. Given an item, `pick_up` reaches with the hand the item
will be held in: the right hand normally, the left for a left-handed weapon such as the bow or a
dual-wield off-hand weapon (playing `PickUp` mirrored, see Dual wielding). It first steps and turns
the player so that hand lands on the item's origin (its grip), then takes it straight into that hand
at the bottom of the reach. The dungeon preview plays `Spawn_Ground` when you
spawn and `Interact` when you open a door.

## Weapons
A weapon scene's root runs `weapon.gd`, which says how it is held and swung: `hand` (`handslot.r`
or `handslot.l`), `grip_rotation_degrees`, `combo` (a list of `AttackStep` resources), `secondary_combo` (right mouse),
`running_attack_animation`, `allows_shield`, `dual_wieldable` and `worn_on_both_hands`, plus a **Ranged** group for
crossbows and bows.

Its **Stance** group changes how the player moves while holding it: `idle_animation` and
`run_animation` replace the player's own, and `upper_body_animation` keeps the arms, chest and head
in that pose on top of every other movement clip (walk, strafe, jump, dodge). The player
builds those combined clips on first use, counter-rotating the spine so the upper body keeps facing
forward even when the legs' clip turns the body (the strafes turn the root bone 60° toward the
direction of travel).

The player plays every clip as authored, root bone included, so the strafes, aiming poses and spins
keep their body turns and `Spawn_Air` shows its drop. Dodges play from in-place copies with the root
bone's slide removed, since the controller moves the body itself. The bow uses `Ranged_Bow_Idle` and `Running_HoldingBow`,
so it stays upright in front of the body instead of swinging out like a rifle.

### Fantasy Weapons pack
The weapons in `scenes/equipment/weapons/` reuse the adventurer setups. They share the adventurer
models' conventions (blade along +Y from the grip, axe heads toward -X, shield faces toward +Z), so
most need no grip rotation:

| Type | Weapons | Setup |
| --- | --- | --- |
| One-handed sword | `sword_a`, `sword_b`, `sword_c` (curved), `sword_d` (rapier) | the one-handed sword's combo, `allows_shield`, `dual_wieldable` |
| Two-handed sword | `sword_e` | two-handed stance and the two-handed sword's combo |
| Dagger | `dagger_a`, `dagger_b` | the dagger's combo, `dual_wieldable` (straight blades, so no flip) |
| One-handed axe | `axe_a`, `axe_c` (cleaver, turned 180° so the blade leads) | the one-handed axe's combo, `allows_shield`, `dual_wieldable` |
| Hammer and mace | `hammer_a`, `hammer_b`, `hammer_c` | the one-handed axe's combo (there are no hammer clips), `allows_shield`, `dual_wieldable` |
| Two-handed axe | `axe_b` | two-handed stance and the two-handed axe's combo |
| Polearm | `halberd` (turned 180° so the blade leads), `spear_a` | two-handed stance; the halberd uses the two-handed axe's combo, the spear Stab → Slice → Stab |
| Fist weapon | `fistweapon_a`, `fistweapon_b` | a two-handed pair: `worn_on_both_hands` puts a mirrored copy of the model on the left hand (with `off_hand_grip()`), so no shield or off-hand weapon; turned (-90, 180, 0) so the knuckles and claws face the punch; left mouse punches left then right (`fists/left_punch.tres`, `Punch_A` mirrored, then the unarmed punch), right mouse kicks |
| Staff | `staff_a`, `staff_b` | the staff's casts |
| Wand | `wand_a` | the wand's casts |
| Bow | `bow_a_withString`, `bow_b_withString` | the bow's setup, turned (0, -90, 180) because these bows are modelled lying along X |
| Shield | `shield_a`, `shield_b`, `shield_c` | `shield.gd` with `grip_offset` set to each back's depth (0.16, 0.16, 0.17) |

`fistweapon_b_stacked` is the drop display for the claws, so it isn't in the test scene;
`fistweapon_a_stacked`, the unstrung `bow_a` and `bow_b` and the arrows are props with no setup.

### Attacking on the move
Attacks, casts, shots, aiming and blocking don't stop the player. While one plays and a move key is
held, the controller keeps moving at the walk or run speed and plays the action on the upper body over
the gait's legs (`moving_action/<clip>_on_<gait>`, built on first use by `_with_legs_of`: the action's
chest, head and arms, the gait's hips and legs looped under it, and the spine counter-rotated so the
upper body faces the camera). Held poses (`Melee_Blocking`, the aim holds) are layered over the walk
the same way (`moving_hold/`). Starting or stopping mid-action swaps between the standing and moving
copy at the same playback time, so the swing carries on. A step with `uses_legs` on (the kick) still
plants the player, and sprinting into an attack still plays the weapon's lunge.

### Combos
Every KayKit attack is a standalone move: it winds up from a neutral stance, swings for about a tenth
of a second, then spends 0.5–1.2 s returning to neutral. Played back to back that reads as separate
attacks, so each `AttackStep` (in `resources/attacks/`) marks where in its clip the combo can move on:

| Field | Meaning |
| --- | --- |
| `combo_time` | After the swing's follow-through: a buffered press cuts the recovery here and blends (0.2 s) into the next step |
| `window_end` | Last moment a press continues the string; after it the player can move or dodge out of the recovery |
| `chain_start` | How far into the wind-up the step starts when it follows another, skipping the slow neutral part |
| `projectile_time` | When to launch the held weapon's `projectile` during this step (-1 for none) |
| `uses_legs` | Plants the player for this step instead of letting the action play over the walk or run |
| `mirrored` | Plays the clip mirrored left to right (built on first use, see Dual wielding), so a right-handed clip strikes with the left hand |
| `continues_automatically` | Moves on to the next step at `combo_time` without waiting for a press (the wand and staff's build-up into the shot) |

A press any time during a swing is remembered. A press after `window_end`, during the rest of the
recovery or up to 0.4 s after the swing ends, still continues the string from the next step; only a
longer pause starts it over. After the last step the string starts again at its `window_end`, which gives
the finisher a beat. Dodging or moving can't cut a swing short until its `window_end`.

| Clip | Swing | `combo_time` | `window_end` | `chain_start` |
| --- | --- | --- | --- | --- |
| `Melee_1H_Attack_Slice_Diagonal` | 0.37–0.47 | 0.75 | 1.00 | 0.05 |
| `Melee_1H_Attack_Slice_Horizontal` | 0.23–0.33 | 0.70 | 1.00 | 0.00 |
| `Melee_1H_Attack_Stab` | 0.37–0.43 | 0.80 | 1.40 | 0.05 |
| `Melee_1H_Attack_Chop` | 0.57–0.60 | 0.88 | 1.05 | 0.15 |

The orders follow each swing's follow-through into the closest wind-up: the sword goes Diagonal →
Stab → Chop → Horizontal, the axe Diagonal → Chop → Horizontal, and the dagger Diagonal → Stab →
Horizontal. Chained, hits land about 0.6–0.85 s apart instead of about 1.3 s, and the player stays in
place. Attacking while
sprinting plays `Melee_1H_Attack_Jump_Chop` and lunges about 2.8 m forward.

### Two-handed weapons
The packs have no two-handed walk or run, so the two-handed sword and axe use `Melee_2H_Idle` as
the idle and keep its arms over the player's normal `Walking_A` and `Running_A` (and every other
movement clip), so both hands stay on the weapon. They don't allow a shield.

Both combo through `resources/attacks/two_handed/`, the sword Slice → Stab → Chop → Spin and the axe
Slice → Chop → Spin:

| Clip | Swing | `combo_time` | `window_end` | `chain_start` |
| --- | --- | --- | --- | --- |
| `Melee_2H_Attack_Slice` | 0.37–0.43 | 0.72 | 1.05 | 0.05 |
| `Melee_2H_Attack_Stab` | about 0.40 | 0.78 | 1.35 | 0.05 |
| `Melee_2H_Attack_Chop` | 0.70–0.87 | 1.12 | 1.50 | 0.25 |
| `Melee_2H_Attack_Spin` (finisher, turns the body a full circle) | 0.63–1.33 | 1.60 | 2.20 | 0.15 |

There is no two-handed sprint attack, so sprinting into an attack starts the combo.
`Melee_2H_Attack_Spinning` (a looping whirlwind) is unused.

### Dual wielding
The one-handed sword, axe and dagger are `dual_wieldable`. Picking one up while holding another and
no shield puts it in the left hand, picked up with the left hand directly; picking up a third swaps
the left-hand weapon. The left-handed pickup is `PickUp` mirrored on first use (`_mirrored()` reflects
every bone's pose across the body's centre line, swaps each `.l` bone with its `.r` twin and corrects
for the rest pose, so the left hand lands where the right hand would on the other side), and the
player lines its left hand up with the weapon the same way. A shield replaces the left-hand weapon, and
any other weapon replaces both. The left hand uses `Weapon.off_hand_grip()`, the right-hand grip
mirrored: the hand slots mirror each other with the forearm axis flipped, so the grip is flipped
back along that axis and through the blade's thickness, which keeps the axe's blade and the dagger's
curved edge leading in either hand.

Dual wielding attacks with the player's `dual_wield_combo`, `resources/attacks/dual_wield/`, in the
order Chop → Stab → Slice (each follow-through flows closest into the next wind-up, and the two-part
slice finishes). Each step chains only once its follow-through has settled and starts the next from
the top of its wind-up, so even mashing plays every attack whole, about 0.8–1.1 s per step:

| Clip | Swing | `combo_time` | `window_end` | `chain_start` |
| --- | --- | --- | --- | --- |
| `Melee_Dualwield_Attack_Chop` | right 0.45–0.60, left 0.85–0.90 | 1.10 | 1.22 | 0.05 |
| `Melee_Dualwield_Attack_Stab` | both 0.38–0.45 | 0.85 | 1.40 | 0.05 |
| `Melee_Dualwield_Attack_Slice` | both 0.55–0.68 and 0.75–0.83 | 1.10 | 1.12 | 0.05 |

The packs have no dual-wield idle, walk, run or sprint attack, so the player moves as with one
weapon and sprinting into an attack still plays the main-hand weapon's `Melee_1H_Attack_Jump_Chop`.

### Unarmed
With nothing in the main hand (including holding only a shield) left mouse runs the `unarmed_combo`
export: a left punch (`fists/left_punch.tres`, `Melee_Unarmed_Attack_Punch_A` mirrored) then a right
punch (`unarmed/punch.tres`), alternating while mashed. With both hands empty, right mouse runs
`unarmed_secondary_combo`, a kick (`unarmed/kick.tres`); with a shield, right mouse blocks instead.
The fist weapons use the same moves.

| Step | Swing | `combo_time` | `window_end` | `chain_start` |
| --- | --- | --- | --- | --- |
| Left punch (`Punch_A` mirrored) | 0.38–0.47 | 0.62 | 1.00 | 0.05 |
| Right punch (`Punch_A`) | 0.38–0.47 | 0.62 | 1.00 | 0.05 |
| Kick (`Melee_Unarmed_Attack_Kick`) | 0.25–0.40 | 0.60 | 0.85 | 0.05 |

There is no unarmed sprint attack.

### Ranged weapons
The crossbows and the bow aim and shoot instead of swinging. Holding right mouse aims: the player
can walk (not sprint or jump) like a shield block, turns with the camera, plays `aim_animation` from `aim_start` until
`aim_ready_time`, then holds `aim_hold_animation` (or, when that is empty, the rest of the aim clip
from `aim_ready_time`, looped, since the crossbow aim clips raise and then hold in one clip).
Letting go before the aim is ready lowers it.

Left mouse while aiming fires: the `shot_animations` play back to back, the first from
`aimed_shot_start`, and can't be cancelled. Left mouse without aiming raises the weapon and fires
the moment the aim is ready, unless the weapon also has a `combo`, which then plays instead (the wand
and staff's quick cast). If right mouse is still held, the last shot clip hands straight back to the
aim hold at `aim_return_time` (when set); otherwise the player raises again once the shots finish.

| Weapon | Aim (`aim_start` → `aim_ready_time`) | Hold | Shot | `aim_return_time` |
| --- | --- | --- | --- | --- |
| One-handed crossbow | `Ranged_1H_Aiming` 0 → 0.4 | rest of the aim clip | `Ranged_1H_Shoot` from 0.3, `Ranged_1H_Reload` | none (lowers to reload, raises again) |
| Two-handed crossbow | `Ranged_2H_Aiming` 0 → 0.4 | rest of the aim clip | `Ranged_2H_Shoot` from 0.3, `Ranged_2H_Reload` | 1.5 (the reload ends aimed) |
| Bow | `Ranged_Bow_Draw` 0.3 → 1.0 | `Ranged_Bow_Aiming_Idle` | `Ranged_Bow_Release` | none (lowers, redraws) |

Each shot launches the weapon's `projectile` once, `shot_release_time` into the first shot clip, at
`projectile_origin` in the weapon's space and facing the camera's direction (the same launch as the
wands). The arrow and bolt models point along +Z, the way `projectile.gd` flies them:

| Weapon | Projectile (`scenes/effects/`) | Release | Origin |
| --- | --- | --- | --- |
| One-handed crossbow | `crossbow_bolt` (`arrow_crossbow`, 32 m/s) | 0.34 s, at the trigger recoil | (0, 0.12, 0.4), on the rail |
| Two-handed crossbow | `crossbow_bolt` | 0.34 s, at the trigger recoil | (0, 0.15, 0.75), on the rail |
| Bow | `arrow` (`arrow_bow`, 26 m/s) | 0.02 s, as the string hand opens | the grip |
| Bow A, bow B | `arrow_a`, `arrow_b` (the Fantasy pack's arrows, 26 m/s) | 0.02 s | the grip |

The projectiles fly straight for 3 s, damage the first hurtbox they reach and stop at walls (see
Damage); no arrow is shown nocked while aiming.

The bow's draw starts at 0.3 s because its first 0.3 s rises from the plain idle, not the bow's.
`Ranged_1H_Shooting` / `Ranged_2H_Shooting` (rapid-fire loops) and
the bow's `_Up` variants (aiming upward) are unused, since the player doesn't know the camera's pitch.

### Magic
The wand and staff build up before they shoot: those buttons run a two-step combo
(`resources/attacks/magic/`) whose first step has `continues_automatically` on, so it hands to the
second at its `combo_time` without another press. The staff's right mouse is a single step:

| Weapon | Button | Steps | Spammed |
| --- | --- | --- | --- |
| Wand | Left mouse (`combo`) | `Ranged_Magic_Spellcasting` for 0.6 s, then `Ranged_Magic_Shoot` from 0.15 | about one cast every 1.4 s |
| Wand | Right mouse (`secondary_combo`) | `Ranged_Magic_Spellcasting_Long` up to its channel's end (1.4 s), then `Ranged_Magic_Shoot` from 0.15 | about one cast every 2.2 s |
| Staff | Left mouse (`combo`) | `Ranged_Magic_Spellcasting_Long` (1.4 s), then `Ranged_Magic_Shoot` from 0.15 | about one cast every 2.2 s |
| Staff | Right mouse (`secondary_combo`) | `Ranged_Magic_Raise` on its own: the staff lifted overhead, held, lowered | about once every 2.0 s |

The wands and staffs fire projectiles. A step with `projectile_time` set spawns one projectile at that
point in its clip: the Shoot step at 0.3 s, when the thrust has finished and the weapon points level,
and the staff's Raise at 0.7 s, with the staff held overhead. The weapon's `projectile` is used for
left mouse and `secondary_projectile` for right mouse; it spawns at `projectile_origin` in the weapon's
space (the tip or head), facing the camera's direction, parented to the player's parent so it flies on
its own. All are in `scenes/effects/` and use `projectile.gd` (they fly straight up to their
`max_range`, damage the first hurtbox they reach and stop at walls; see Damage):

| Weapon | Left mouse | Right mouse |
| --- | --- | --- |
| Wand | `magic_bolt` (blue, small, 15 m/s) | `magic_bolt_charged` (blue, large, 10 m/s) |
| Wand A | `arcane_bolt` (violet, small, 18 m/s) | `arcane_bolt_charged` (violet, large, 11 m/s) |
| Staff | `nature_bolt` (green, 14 m/s) | `nature_burst` (green, very large, 9 m/s, from the raised staff) |
| Staff A | `ember_bolt` (amber, 14 m/s) | `ember_burst` (amber, very large, 9 m/s, from the raised staff) |
| Staff B | `frost_bolt` (white-cyan, 14 m/s) | `frost_burst` (white-cyan, very large, 9 m/s, from the raised staff) |

The variants are copies of `magic_bolt` with a different core size and colour, light and trail.

Presses only queue the combo that the same button started, so clicking one button during the
other's cast doesn't cut it short. `Ranged_Magic_Summon` is unused.

While the player casts, `cast_effects.gd` opens a glowing circle with rising sparks under their feet:
the free area effect from Binbun's Elemental Magic FX (`vfx_fire_area_01`). It follows the player
and opens when a `Ranged_Magic_` clip starts. It closes the moment the bolt or burst leaves (the
player's `projectile_launched` signal), partway through the Shoot or Raise clip, or earlier if another
clip cuts the cast short, such as a dodge or a hit. The next spellcast opens it again. Its colour is the held
weapon's `cast_color`, the colour of its bolts. `radius` is 0.8 m and `emission` is 1.2; the pack's
3.0 washed out to white on GL Compatibility, which has no HDR glow to carry it:

| Weapon | `cast_color` |
| --- | --- |
| Wand | blue `(0.35, 0.8, 1)` |
| Wand A | violet `(0.62, 0.35, 1)` |
| Staff | green `(0.35, 0.95, 0.3)` |
| Staff A | amber `(1, 0.5, 0.15)` |
| Staff B | frost `(0.6, 0.9, 1)` |

There is a single circle, kept for the whole scene, and a cast only changes its shader parameters, so
casting never creates a material. When the scene starts the circle opens once under the floor (see
"Warm-ups") and stays up for at least 0.2 s and 16 frames before it hides. Its sparks only start
emitting 0.1 s into `open`, and a shorter warm-up left their shaders to compile on the first cast (about
0.28 s with the driver's shader cache off). The 16 frames overlap the projectile warm-up's light, which
compiles the lit version the circle needs when a bolt launches beside it.

### Shields
A shield's root runs `shield.gd` and is held in the left hand alongside a main-hand weapon whose
`allows_shield` is on (the one-handed sword and axe); picking up a weapon that doesn't allow one, or
a shield while holding such a weapon, puts the other item back. Holding right mouse with a shield
blocks:

| Situation | Animation |
| --- | --- |
| Start blocking while standing still | `Melee_Block` raises the shield, then `Melee_Blocking` holds it |
| Move while blocking | walks (no sprint or jump) with `Melee_Blocking` on the upper body over the walk, the legs turned toward travel and the upper body twisted back to the camera; raising, bashing and block hits work on the move too (dodging still works) |
| Right mouse in the air | nothing: the shield only comes up on the ground, so a jump keeps its arc, and holding it through the landing raises the shield once the landing finishes |
| Hit while blocking (`take_hit()`) | `Melee_Block_Hit` instead of `Hit_A` / `Hit_B` |
| Attack while blocking | `Melee_Block_Attack`, a shield bash |
| Release | blends back to the normal idle or movement (the packs have no lower-shield clip) |

Not blocking, the sword or axe combos as usual with the shield on the forearm. `grip_offset` (default 0.145 along the hand
slot's Z) moves the shield out so its back face sits on the hand instead of the forearm passing
through it; all nine adventurer shields share that back depth.

Grips: the bow is held in the left hand turned 180° with the bow stance, the crossbows are turned
90° so they point along the forearm, the one-handed axe is turned 180° so the blade leads, and the
dagger is turned 180° so its curved edge faces up. Every adventurer weapon now attacks.

The idle, fidget, walk and run animations are exports under **Animations**, so a character can
use a variant such as `Walking_B` or `Running_B`.

## Health, mana and stamina
Every character scene (the six adventurers and four skeletons) has three stat nodes and a hurtbox:

| Node | Script | Max | Passive regen |
| --- | --- | --- | --- |
| `Health` | `health.gd` | 100 | adventurers 1.5/s after 5 s without damage; skeletons none |
| `Mana` | `stat_pool.gd` | 100 | 5/s after 1.5 s without spending |
| `Stamina` | `stat_pool.gd` | 100 | 35/s after 0.5 s without spending |
| `Hurtbox` | `hurtbox.gd` | | |

`StatPool` is the shared base: `spend(amount)` (false, and nothing taken, if there isn't enough),
`can_spend`, `drain`, `restore`, `restore_over_time(amount, duration)`, `fill`, `ratio`, `is_empty`
and `is_full`, with a `changed(value, max_value)` and a `depleted` signal. Draining restarts the
`regen_delay` countdown, and passive regen (`regen_rate` per second) only runs once it has passed.
`Health` adds `take_damage(amount, source)`, `heal`, `heal_over_time`, `kill`, `revive(fraction)`,
`is_dead` and an `invulnerable` switch, with `damaged`, `healed`, `died` and `revived` signals. A dead
Health ignores damage, healing and regen, and drops any heal still running over time.

The enemies override `Health`'s max: minion 100, mage 120, rogue 140, warrior 200, champion 800. Any
other object gets health the same way: add a `Health` node and a `Hurtbox` pointing at it. The
breakable containers (barrels, boxes, crates and kegs in `scenes/dungeon/containers/`) do, with 20–45
health, and run `breakable.gd`, which frees them when their health runs out. Chests and trunks don't.

### Potions
A potion is a `Potion` resource with `health`, `mana`, `stamina` and `duration`. `apply_to(drinker)`
restores each amount into the drinker's `Health`, `Mana` and `Stamina` nodes, all at once when
`duration` is 0, or spread evenly over `duration` seconds. The player's `drink(potion)` plays
`Use_Item` and applies it (returning false while dead or busy). There are no potion models yet, so
they exist only as data:

| Potion | Restores |
| --- | --- |
| `health_potion` | 40 health |
| `mana_potion` | 50 mana |
| `stamina_potion` | 60 stamina |
| `regeneration_potion` | 60 health over 5 s |

## Damage
Hurtboxes sit on the `hurtboxes` physics layer (layer 2), named in `project.godot`; everything else
stays on `world` (layer 1). A hurtbox copies the collision shapes of the body it belongs to (the
character's capsule, or the generated collision of an imported model), so it always matches the body.
`receive(hit)` ignores hits from its own owner and hits while dead, asks `block_check` whether the hit
is blocked, otherwise damages its Health, and emits `hit_taken(hit, damage)` or `blocked(hit)`.

Each melee `AttackStep` has a hit window, `hit_start` to `hit_end`, measured from the speed of the hand
bones in each clip; during it every hurtbox the striking weapon's area overlaps takes one hit for that
step. Dual wielding strikes with both weapons; empty hands and the fist weapons strike with sphere
queries at both hands and feet (as does a kick); a shield bash strikes with the shield. The sprint
lunge uses the weapon's `running_attack_hit_start` / `_end` (0.66–0.80 s of `Melee_1H_Attack_Jump_Chop`).

| Clip | Hit window |
| --- | --- |
| 1H Slice Diagonal / Slice Horizontal / Stab / Chop | 0.35–0.48 / 0.22–0.35 / 0.34–0.45 / 0.54–0.64 |
| 2H Slice / Stab / Chop / Spin | 0.34–0.46 / 0.34–0.46 / 0.64–0.89 / 0.62–1.33 |
| Dual-wield Chop / Stab / Slice | 0.50–0.92 / 0.34–0.46 / 0.52–0.86 |
| Punch (either hand) / Kick | 0.37–0.49 / 0.22–0.42 |
| Shield bash (`Melee_Block_Attack`) | 0.32–0.45 |

Damage lives on the weapon (`Weapon.damage`), shield (`Shield.bash_damage`, 8), projectile
(`damage` on its scene) and player (`unarmed_damage`, 6):

| Weapons | Damage |
| --- | --- |
| Daggers | 12 |
| Fist weapons | 14 |
| Rapier (`sword_d`) / other 1H swords | 16 / 18 |
| 1H axes / hammers and maces | 20 / 22 |
| Spear / halberd | 30 / 38 |
| 2H swords / 2H axes | 40 / 45 |
| Arrows / crossbow bolts | 22 / 30 |
| Wand bolts (`magic_bolt`, `arcane_bolt`) / charged | 12, 14 / 28, 30 |
| Staff bolts / bursts | 16 / 35 |

Projectiles ray-cast each physics step from where they were to where they move, against hurtboxes and
`world` bodies, skipping the shooter, so fast arrows can't pass through a target between frames.

Every projectile has a `max_range` in metres, set on its scene next to its `damage`. It counts the
distance it has flown, and its last step is clipped to what's left of the range, so it can still hit
something right at the limit. It vanishes there. Heavier shots carry less far:

| Projectiles | `max_range` | Speed |
| --- | --- | --- |
| Wand bolts (`magic_bolt`, `arcane_bolt`) / charged | 20 m / 18 m | 15, 18 / 10, 11 m/s |
| Staff bolts / bursts | 22 m / 16 m | 14 / 9 m/s |
| Arrows (`arrow`, `arrow_a`, `arrow_b`) | 30 m | 26 m/s |
| Crossbow bolts | 35 m | 32 m/s |

`lifetime` still frees a projectile that has stopped moving (the unused `melee_sparks` relies on it);
for every shot above the range runs out first.

Wand and staff projectiles fade out instead of popping. Past `shrink_from` (0.5, half their range) they
shrink in step with the distance left, reaching nothing at `max_range`. That covers their core, the
energy of their light, and the size of their trail sparks: the sparks live in world space, so the
node's scale doesn't reach them. Arrows and crossbow bolts keep the default `shrink_from` of 1 and fly
at full size to the end. Size changes nothing else: a shrinking bolt still flies at full speed and hits
for full damage.

Blocking with a shield stops any hit that comes from within `block_arc_degrees` (120°) of where the
player faces and plays `Melee_Block_Hit`; hits from behind still land. An unblocked hit plays `Hit_A`
or `Hit_B` on the player and the enemies, and reaching zero health plays `Death_A` or `Death_B`
(through `die()`, which now kills the Health). `spawn()` revives the player at full health. Enemies
stand still while they react, and stay down once dead. `Hit_A` and `Hit_B` were authored from the plain
`Idle_A` stance, so crossfading them on an enemy with another idle (the minion's raised fists, the mage's
staff, the champion's two-handed stance) dragged the whole body out of its stance and back. Instead each
enemy builds an additive copy on first use (`flinch_in_stance/Hit_A`, `Hit_B`): every bone keeps the
pose of the enemy's own idle and only adds how far the hit clip moves it from the clip's first frame.
The flinch starts from the stance, so it blends in over just 0.06 s, and it blends back into the idle over
the last 0.25 s of the clip. Deaths still play the plain clips, blending in over 0.2 s. Once dead, their body leaves the `world` layer at once, and
as soon as it rests on the floor every collision shape under it (body capsule, hurtbox, held weapons)
is disabled and its physics stops, so the player walks through the corpse and arrows fly past it.

### Stamina costs
The player's `Stamina` pays for sprinting, attacking and blocking:

| Action | Cost |
| --- | --- |
| Sprinting | `sprint_stamina_per_second` (15/s) while running on the ground |
| A jump | `jump_stamina_cost` (10) |
| A combo step, sprint lunge or shot | the weapon's `stamina_cost` (both weapons' when dual wielding; `unarmed_stamina_cost`, 6, with empty hands) |
| A shield bash | the shield's `bash_stamina_cost` (10) |
| A blocked hit | its damage × the shield's `block_stamina_per_damage` (1) |

One-handed weapons are cheap to swing; two-handed weapons hit about twice as hard but cost three to
four times the stamina, so a full bar is about twelve sword swings but only three two-handed axe swings:

| Weapons | `stamina_cost` | Damage |
| --- | --- | --- |
| Daggers, fist weapons | 6 | 12, 14 |
| Rapier (`sword_d`) | 7 | 16 |
| Other 1H swords | 8 | 18 |
| 1H axes / hammers and maces | 10 / 11 | 20 / 22 |
| Spear / halberd | 22 / 26 | 30 / 38 |
| 2H swords / 2H axes | 28 / 32 | 40 / 45 |
| Crossbows / bows | 8 / 12 | 30 / 22 per bolt or arrow |
| Wands and staffs | 0 (left for mana) | per bolt |

An attack or jump only needs some stamina left to start and can take the bar to zero; with an empty
bar the player can't swing, bash, shoot or jump, and a combo stops at the next step. Running the bar dry leaves the
player winded: Shift walks instead of running until stamina is back to `sprint_recovery_ratio` (30%).
Stamina doesn't regenerate while the shield is up. A blocked hit that costs more stamina than is left
breaks the guard: the bar empties and the full hit lands. Dodging is free.

### UI
`scenes/ui/vitals_hud.tscn` is three plain bars (health, mana, stamina) with their values, bound to
the pools set on its `health`, `mana` and `stamina` exports. `damage_numbers.gd` watches every hurtbox
in the scene and pops a number over the top of whatever was hit: yellow for damage dealt, red for
damage the player takes, and "Blocked" in grey.

Every enemy scene has a `HealthBar` (`scenes/ui/enemy_health_bar.tscn`): a red bar that always faces the
camera, placed just above the top of the enemy's hurtbox, that follows its health and hides on death.

`hit_outlines.gd` flashes an outline on whatever takes damage from a hit, red on enemies and white on
items (the breakable containers), never on the player. Every mesh of the target gets the same shared
`ShaderMaterial` (`shaders/hit_outline.gdshader`, an unshaded, front-culled inverted hull) as its
`material_overlay`, and the colour and thickness are per-mesh instance uniforms
(`set_instance_shader_parameter`). The outline holds for 0.08 s, shrinks away over 0.3 s, then the
overlay is removed. The enemy health bar is left out.

Hits must never create materials. The GL Compatibility renderer compiles shaders again for every new
material instance, even one identical to a material already in use, and a compile in the middle of a fight
is a visible hitch (measured at 175–450 ms per hit with the driver's shader cache off). Creating a fresh
outline material per hit caused a microstutter on every hit. With one shared material, a hit costs no compile. The first compile is moved to
loading: `hit_outlines.gd` puts the outline on every target at zero thickness for two frames when the scene
starts, and `damage_numbers.gd` pops one invisible number containing every digit and "Blocked" so the
label shader and its glyphs are ready before the first hit. Enemies also build their in-stance flinch clips
when they load instead of on their first hit.

`hit_effects.gd` plays one of the pack's two hit flashes (`vfx_hit_01`, `vfx_hit_02`, picked at random)
whenever an enemy takes damage, on the side of its hurtbox facing the blow at the height of the strike.
Hits of `heavy_damage` (30) or more, such as spear, halberd and two-handed swings, flash `heavy_scale`
(1.4) times bigger. Items and the player get no flash. Each flash frees itself when its animation ends.
The pack's impact and big impact effects are left unused: on GL Compatibility their core sphere renders as
a solid white ball. Two changes keep the pack working on this renderer:
- `impact_sphere.gdshader` no longer writes `PREMUL_ALPHA_FACTOR`, which only Forward+ and Mobile
  support, so on Compatibility the shader failed to compile and printed errors. Only the unused impact
  effects draw with it.
- Each flash's `VFXOmniLightBB` is hidden. On Compatibility the first time a light touches a material
  compiles a new variant of that material's shader, so the flash light stalled the first hit on each kind
  of enemy (about 0.5 s with the driver's shader cache off), and a warm-up can't reach every material.
Both flashes are warmed up when the scene starts, played under the floor.

`damage_numbers.gd`, `hit_outlines.gd` and `hit_effects.gd` all extend `hurtbox_watcher.gd`.

### Warm-ups
GL Compatibility compiles a shader the first time something is drawn with it, on the frame it appears,
and it has no background compiling. So every effect that would first appear mid-fight is drawn once
while the arena loads, and the cost lands there.

`projectile_warm_up.gd` covers ranged weapons. The first wand or staff use used to freeze the game: the
first bolt compiled its own core and trail materials, and its `OmniLight3D` (the only lights in the
arena) compiled a lit version of every material it reached: the floor, the player, the cast circle. That
was 19 shader programs, and the worst frame took 2.3 s with the driver's shader cache off. On GL
Compatibility even unshaded materials get a separate version when a light touches them. So the warm-up
first waits four unlit frames, which let the other warm-ups compile their unlit versions. Then it shows
every `projectile` and `secondary_projectile` of the weapons in the scene, standing still, dealing no
damage, with their lights at 0.001 energy. Alongside them goes one faint light with a 60 m range that
reaches everything in view. After ten frames all of it is freed.

Warm-ups have to be on screen to compile, but nobody should see them. Shrinking them didn't work:
particles live in world space and ignore the node's scale, so the sparks played on the player. Two layers
hide them:
- `WarmUpSpot.under_floor()` puts the hit flashes, the cast circle and the projectiles 3 m under the
  floor, on the line from the camera through the player's feet. The renderer still draws them, but the
  floor covers every pixel.
- `LoadingCover` (`loading_cover.gd`), a black `ColorRect` on canvas layer 100, holds for at least 20
  frames and 0.5 s, then fades out over 0.3 s and frees itself. Every warm-up finishes behind it (the
  projectiles by frame 15, the cast circle by frame 17), and so does the slow first frame that compiles
  the rest of the arena. It ignores the mouse, so the first click still reaches the game.

The outline and damage-number warm-ups draw in place: a zero-width outline on every target, and one
fully transparent number. Both happen behind the cover. Once the cover is gone, the first swing, hit,
cast, bolt, arrow and crossbow bolt compile nothing, whether or not they hit.

## Combat test
Open `scenes/playground/combat_test.tscn` and press F6. Every usable weapon and shield lies on the
floor in four labelled rows (one-handed at z = -5, two-handed and fist weapons at -10, all twelve
shields at -15, ranged and magic at -20), with the five enemies at z = -28 and the eleven breakable
containers at -33. The health, mana and stamina bars are bottom left.

| Key | Action |
| --- | --- |
| F | Pick up the nearest weapon (the held one goes back to its spot) |
| 1 / 2 / 3 / 4 | Drink a health / mana / stamina / regeneration potion |
| 5 | Take 15 damage from behind |
| 6 / 7 | Spend 20 mana / 25 stamina |
| R | Reset the arena |
| Click / Esc | Capture / free the mouse |

The movement and combat controls are the player's own (see Player controls).

## Playground
Open `scenes/playground/playground.tscn` and press F6 to walk the knight around a flat floor.

## Animation test
Open `scenes/playground/animation_test.tscn` and press F6. The HUD shows the playing animation and
the current stance.

| Key | Action |
| --- | --- |
| 1 – 8 | Interact, pick up the weapon in front of you, throw, use item, hit, die, spawn, spawn from the air |
| Left / Right | Previous / next animation in the current library |
| Up / Down | Previous / next library (`movement_basic`, `movement_advanced`, `general`) |
| Mouse | Look: turns the character while it moves, attacks or blocks; orbits around it while it stands still |
| Click / Esc | Capture / free the mouse |
| Mouse wheel | Zoom |
| C | Freeze / release the character's facing: it locks the direction the character is facing, so the camera orbits and zooms freely without turning it, and attacks, aiming and WASD all use that locked direction. Use it to watch an animation from the front or side |

Browsed animations play on the spot, one-shots repeat, and moving cancels them.

Every weapon from both packs lies on the floor in front of the spawn, grips toward you, grouped by type
with a label on the floor in front of each group (the `WeaponLabels` node): one-handed melee (1H swords,
daggers, 1H axes, hammers and maces) at z = -5, two-handed and special (2H swords, 2H axes, polearms,
fist weapons, shields) at z = -11, and ranged and magic (wands, staffs, crossbows, bows) at z = -17.
Walk up to one and press 2 to pick it up; picking up another puts the held one back where it was.

## Characters
Every character scene loads the same eight rig_medium libraries, so any animation works on any
character: `combat_melee`, `combat_ranged`, `general`, `movement_advanced`, `movement_basic`,
`simulation`, `special` and `tools`. All ten share one rig.

## Credits
3D models and animations by Kay Lousberg ([KayKit](https://www.kaylousberg.com)), CC0:
Adventurers 2.0, Skeletons 1.1, Dungeon Pack 1.1 and Character Animations 1.1.
