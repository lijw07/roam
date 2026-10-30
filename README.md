# roam
A game made with Godot where players traverse through a series of procedurally generated dungeons to gather loot and face more difficult bosses.

## Requirements
- Godot 4.7 (GL Compatibility renderer)

## Project structure
```
assets/
  animations/   Character animations (rig_medium, rig_large)
  characters/   Adventurer and skeleton models
  dungeon/      Dungeon pieces by type (floors, walls, stairs, ...)
  equipment/    Weapons, shields and items
  licenses/     Asset pack licenses
scenes/
  characters/   One scene per character, each with its own collision
  dungeon/      One scene per dungeon piece, each with its own collision
  equipment/    One scene per item, each with its own collision
  effects/      Arrow, magic bolt and melee impact effects
  playground/   Movement and animation test scenes
resources/
  attacks/      AttackStep resources: one per attack clip, shared by every weapon that uses it
scripts/
  player.gd               Player movement and animation: locomotion, stances, dodge and actions
  animation_test.gd       Animation test scene: camera, HUD, action keys and animation browser
  weapon.gd               How a weapon is held, its combo and the stance it gives the player
  shield.gd               An off-hand shield and its block animations
  upper_body_twist.gd     Twists the spine, chest and head toward the camera while the legs walk another way
  attack_step.gd          One step of a combo: its animation and when it can chain
  projectile.gd           Moves an effect forward and frees it after its lifetime
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
| Right mouse (hold) | With a shield, block in place; with a crossbow or bow, aim in place | see Shields and Ranged weapons |
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
or `handslot.l`), `grip_rotation_degrees`, `combo` (a list of `AttackStep` resources),
`running_attack_animation`, `allows_shield` and `dual_wieldable`, plus a **Ranged** group for
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

### Combos
Every KayKit attack is a standalone move: it winds up from a neutral stance, swings for about a tenth
of a second, then spends 0.5–1.2 s returning to neutral. Played back to back that reads as separate
attacks, so each `AttackStep` (in `resources/attacks/`) marks where in its clip the combo can move on:

| Field | Meaning |
| --- | --- |
| `combo_time` | After the swing's follow-through: a buffered press cuts the recovery here and blends (0.2 s) into the next step |
| `window_end` | Last moment a press continues the string; after it the player can move or dodge out of the recovery |
| `chain_start` | How far into the wind-up the step starts when it follows another, skipping the slow neutral part |

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
With nothing in the main hand (including holding only a shield) the player fights with the
`unarmed_combo` export, `resources/attacks/unarmed/`:

| Clip | Swing | `combo_time` | `window_end` | `chain_start` |
| --- | --- | --- | --- | --- |
| `Melee_Unarmed_Attack_Punch_A` | 0.38–0.47 | 0.62 | 1.00 | 0.05 |
| `Melee_Unarmed_Attack_Kick` | 0.25–0.40 | 0.60 | 0.85 | 0.05 |

There is no unarmed sprint attack. Holding a weapon without a combo (the bow, crossbows, wand, staff)
doesn't attack.

### Ranged weapons
The crossbows and the bow aim and shoot instead of swinging. Holding right mouse aims: the player
plants like a shield block, turns with the camera, plays `aim_animation` from `aim_start` until
`aim_ready_time`, then holds `aim_hold_animation` (or, when that is empty, the rest of the aim clip
from `aim_ready_time`, looped, since the crossbow aim clips raise and then hold in one clip).
Letting go before the aim is ready lowers it.

Left mouse while aiming fires: the `shot_animations` play back to back, the first from
`aimed_shot_start`, and can't be cancelled. Left mouse without aiming raises the weapon and fires
the moment the aim is ready. After the last shot clip, if right mouse is still held, the player
holds the aim when `shot_ends_aimed` is on and raises again when it isn't.

| Weapon | Aim (`aim_start` → `aim_ready_time`) | Hold | Shot | Ends aimed |
| --- | --- | --- | --- | --- |
| One-handed crossbow | `Ranged_1H_Aiming` 0 → 0.4 | rest of the aim clip | `Ranged_1H_Shoot` from 0.3, `Ranged_1H_Reload` | no (lowers to reload) |
| Two-handed crossbow | `Ranged_2H_Aiming` 0 → 0.4 | rest of the aim clip | `Ranged_2H_Shoot` from 0.3, `Ranged_2H_Reload` | yes |
| Bow | `Ranged_Bow_Draw` 0.3 → 1.0 | `Ranged_Bow_Aiming_Idle` | `Ranged_Bow_Release` | no (redraws) |

The bow's draw starts at 0.3 s because its first 0.3 s rises from the plain idle, not the bow's.
There are no projectiles yet. `Ranged_1H_Shooting` / `Ranged_2H_Shooting` (rapid-fire loops) and
the bow's `_Up` variants (aiming upward) are unused, since the player doesn't know the camera's pitch.

### Shields
A shield's root runs `shield.gd` and is held in the left hand alongside a main-hand weapon whose
`allows_shield` is on (the one-handed sword and axe); picking up a weapon that doesn't allow one, or
a shield while holding such a weapon, puts the other item back. Holding right mouse with a shield
blocks:

| Situation | Animation |
| --- | --- |
| Start blocking while standing still | `Melee_Block` raises the shield, then `Melee_Blocking` holds it |
| Move or jump while blocking | nothing: blocking is a planted stance, so movement input waits until you let go (dodging still works) |
| Right mouse in the air | nothing: the shield only comes up on the ground, so a jump keeps its arc, and holding it through the landing raises the shield once the landing finishes |
| Hit while blocking (`take_hit()`) | `Melee_Block_Hit` instead of `Hit_A` / `Hit_B` |
| Attack while blocking | `Melee_Block_Attack`, a shield bash |
| Release | blends back to the normal idle or movement (the packs have no lower-shield clip) |

Not blocking, the sword or axe combos as usual with the shield on the forearm. `grip_offset` (default 0.145 along the hand
slot's Z) moves the shield out so its back face sits on the hand instead of the forearm passing
through it; all nine adventurer shields share that back depth.

Grips: the bow is held in the left hand turned 180° with the bow stance, the crossbows are turned
90° so they point along the forearm, the one-handed axe is turned 180° so the blade leads, and the
dagger is turned 180° so its curved edge faces up. The swords, axes, dagger, crossbows and bow
attack; the wand and staff hold correctly but have no attacks yet.

The idle, fidget, walk and run animations are exports under **Animations**, so a character can
use a variant such as `Walking_B` or `Running_B`.

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

A row of the ten weapons the player has animations for, plus a round shield, lies in front of the spawn, grips toward
you: one- and two-handed sword and axe, dagger, wand, staff, both crossbows and the bow. Walk up to
one and press 2 to pick it up; picking up another puts the held one back where it was.

## Characters
Every character scene loads the same eight rig_medium libraries, so any animation works on any
character: `combat_melee`, `combat_ranged`, `general`, `movement_advanced`, `movement_basic`,
`simulation`, `special` and `tools`. All ten share one rig.

## Credits
3D models and animations by Kay Lousberg ([KayKit](https://www.kaylousberg.com)), CC0:
Adventurers 2.0, Skeletons 1.1, Dungeon Pack 1.1 and Character Animations 1.1.
