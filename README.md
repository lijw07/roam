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
scripts/
  player.gd               Player movement and animation: locomotion, stances, dodge and actions
  animation_test.gd       Animation test scene: camera, HUD, action keys and animation browser
  projectile.gd           Moves an effect forward and frees it after its lifetime
```

## Player controls
`player.gd` drives the player in the playground, the animation test scene and the dungeon
preview's walk mode.

| Key | Action | Animations |
| --- | --- | --- |
| W A S D | Walk | `Walking_A`, idle `Idle_A` (`Idle_B` after standing still for a while) |
| Shift | Run | `Running_A` |
| Space | Jump | `Jump_Start`, `Jump_Idle`, `Jump_Land` |
| Right mouse (hold) | Strafe: keep facing one way | `Walking_Backwards`, `Running_Strafe_Left`, `Running_Strafe_Right` |
| Alt | Dodge toward the move direction, or back when standing still | `Dodge_Forward`, `Dodge_Backward`, `Dodge_Left`, `Dodge_Right` |
| C | Crouch (Shift for a crouch run) | `Sneaking`, `Crouching` |
| Z | Crawl | `Crawling` |
| Left mouse / J | Attack with the held weapon | the weapon's `attack_animations`, or its `running_attack_animation` while sprinting |

Crouching and crawling shrink the collision capsule (to 94% and 68% of standing height, measured
from the posed meshes), and you only stand back up when there is room overhead. The packs have no
crouch or crawl idle, so standing still holds the cycle on its feet-together frame.

The general animations are methods for gameplay code to call: `interact()`, `pick_up(item)`,
`throw()`, `use_item()`, `take_hit()` (`Hit_A` or `Hit_B`), `die()` (`Death_A` or `Death_B`,
ending on the matching `_Pose`) and `spawn(from_air)` (`Spawn_Ground` or `Spawn_Air`). Each one
holds the player in place until it finishes. Given an item, `pick_up` first steps and turns the
player so the right hand lands on the item's origin (its grip), takes it at the bottom of the reach,
and moves it to the weapon's `hand` once the player is back up. The dungeon preview plays `Spawn_Ground` when you
spawn and `Interact` when you open a door.

## Weapons
A weapon scene's root runs `weapon.gd`, which says how it is held and swung: `hand` (`handslot.r`
or `handslot.l`), `grip_rotation_degrees`, `attack_animations` and `running_attack_animation`.

Its **Stance** group changes how the player moves while holding it: `idle_animation` and
`run_animation` replace the player's own, and `upper_body_animation` keeps the arms, chest and head
in that pose on top of every other movement clip (walk, strafe, sneak, jump, dodge). The player
builds those combined clips on first use. The bow uses `Ranged_Bow_Idle` and `Running_HoldingBow`,
so it stays upright in front of the body instead of swinging out like a rifle.

The one-handed sword combos through `Melee_1H_Attack_Slice_Diagonal`, `Slice_Horizontal`, `Stab` and
`Chop`. Pressing attack in the last 60% of a swing queues the next one, earlier presses are ignored,
and the combo starts over half a second after the last swing ends. Attacking while sprinting plays
`Melee_1H_Attack_Jump_Chop` and lunges about 2.8 m forward. The bow (left hand, turned 180°, bow
stance), the one-handed axe (turned 180° so the blade leads), the dagger (turned 180° so the curved
edge faces up) and both crossbows (turned 90° so they point along the forearm) only set their grip
and stance so far; the other weapons hold correctly as modeled and have no
attacks yet.

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
| Q / E | Orbit the camera |
| Mouse wheel | Zoom |

Browsed animations play on the spot, one-shots repeat, and moving cancels them.

A row of the ten weapons the player has animations for lies in front of the spawn, grips toward
you: one- and two-handed sword and axe, dagger, wand, staff, both crossbows and the bow. Walk up to
one and press 2 to pick it up; picking up another puts the held one back where it was.

## Characters
Every character scene loads the same eight rig_medium libraries, so any animation works on any
character: `combat_melee`, `combat_ranged`, `general`, `movement_advanced`, `movement_basic`,
`simulation`, `special` and `tools`. All ten share one rig.

## Credits
3D models and animations by Kay Lousberg ([KayKit](https://www.kaylousberg.com)), CC0:
Adventurers 2.0, Skeletons 1.1, Dungeon Pack 1.1 and Character Animations 1.1.
