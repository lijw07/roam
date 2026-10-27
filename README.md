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

Crouching and crawling shrink the collision capsule (to 94% and 68% of standing height, measured
from the posed meshes), and you only stand back up when there is room overhead. The packs have no
crouch or crawl idle, so standing still holds the cycle on its feet-together frame.

The general animations are methods for gameplay code to call: `interact()`, `pick_up()`,
`throw()`, `use_item()`, `take_hit()` (`Hit_A` or `Hit_B`), `die()` (`Death_A` or `Death_B`,
ending on the matching `_Pose`) and `spawn(from_air)` (`Spawn_Ground` or `Spawn_Air`). Each one
holds the player in place until it finishes. The dungeon preview plays `Spawn_Ground` when you
spawn and `Interact` when you open a door.

The idle, fidget, walk and run animations are exports under **Animations**, so a character can
use a variant such as `Walking_B` or `Running_B`.

## Playground
Open `scenes/playground/playground.tscn` and press F6 to walk the knight around a flat floor.

## Animation test
Open `scenes/playground/animation_test.tscn` and press F6. The HUD shows the playing animation and
the current stance.

| Key | Action |
| --- | --- |
| 1 – 8 | Interact, pick up, throw, use item, hit, die, spawn, spawn from the air |
| Left / Right | Previous / next animation in the current library |
| Up / Down | Previous / next library (`movement_basic`, `movement_advanced`, `general`) |
| Q / E | Orbit the camera |
| Mouse wheel | Zoom |

Browsed animations play on the spot, one-shots repeat, and moving cancels them.

## Characters
Every character scene loads the same eight rig_medium libraries, so any animation works on any
character: `combat_melee`, `combat_ranged`, `general`, `movement_advanced`, `movement_basic`,
`simulation`, `special` and `tools`. All ten share one rig.

## Credits
3D models and animations by Kay Lousberg ([KayKit](https://www.kaylousberg.com)), CC0:
Adventurers 2.0, Skeletons 1.1, Dungeon Pack 1.1 and Character Animations 1.1.
