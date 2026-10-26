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
  player.gd               Playground character movement
  lab_character.gd        Animation lab character: swaps model, holds equipment
  interaction_station.gd  Animation lab prop: grants a loadout or plays an animation
  animation_lab.gd        Animation lab HUD, camera and animation browser
  projectile.gd           Moves an effect forward and frees it after its lifetime
```

## Playground
Open `scenes/playground/playground.tscn` and press F6.

| Key | Action |
| --- | --- |
| W A S D | Move |
| Shift | Run |
| Space | Jump |

## Animation lab
Open `scenes/playground/animation_lab.tscn` and press F6. One drivable character stands in a ring
of stations; walk up to a station and press F to use it. The character wears any of the ten
character scenes as its model, so every animation can be checked on every character.

| Key | Action |
| --- | --- |
| W A S D | Move (relative to the camera) |
| Shift / Space | Run / jump |
| F | Use the nearest station (equip, sit, lockpick, ...), or stop using it |
| Left mouse / J | Attack — cycles through the loadout's attacks, and cannot be interrupted or spammed |
| Right mouse (hold) | Block or aim, depending on the loadout |
| `[` `]` | Previous / next character |
| Left / Right | Previous / next animation in the current library |
| Up / Down | Previous / next animation library |
| Q / E | Orbit the camera |
| Mouse wheel | Zoom |
| X | Drop the loadout and reset |

Browsing with the arrow keys plays any of the 139 animations on the spot; moving cancels it.

Blocking, aiming and channelling are planted stances — holding right mouse stops the character
rather than sliding it along in a stationary pose, because the packs contain no block-walk or
aim-walk cycle. There is no two-handed walk cycle either, so the axe and the staff borrow the
two-handed carry cycles (`Walking_C` and `Running_HoldingRifle`) that keep both hands on the
weapon.

### Stations
| Station | Press F to |
| --- | --- |
| Sword & Shield | Equip sword and shield: 1H attacks, right mouse blocks |
| Two-Handed Axe | Equip the axe: 2H attacks, carried in both hands while moving |
| Dual Daggers | Equip two daggers: dual-wield attacks |
| Bow | Equip the bow: draw and release, right mouse aims, bow run cycle |
| Staff | Equip the staff: magic attacks, right mouse channels a spell |
| Locked Chest | Lockpick (loops until you press F again) |
| Chair | Sit down, idle, stand up |
| Bed | Lie down, idle, stand up |
| Barrel | Pick up (one shot) |

The packs ship no shovel, pickaxe, hammer, saw or fishing rod, so the digging, mining and
hammering interactions were removed rather than mimed with empty hands. The axe is the only tool
model in the packs. Adding a tool asset is enough to bring one back: give an action station a
`main_hand` scene alongside its animations.

Only the chair and the bed move you: they have an `Anchor` child marking where the body has to be
for the animation to line up, plus an `Exit` child marking where you are put back down afterwards.
Every other station plays its animation where you stand, turning you to face the prop.

### Attack effects
| Loadout | Effect |
| --- | --- |
| Bow | Fires an `arrow_bow` model that flies forward and despawns |
| Staff | Casts a glowing bolt with a particle trail and a light |
| Melee (sword, axe, daggers) | Sparks at the point of contact — **only when the swing hits something** |

Melee swings raycast forward at three heights when the swing connects; nothing in reach means no
effect, so swinging at thin air stays clean. The ring holds a **Training Dummy** (a skeleton that
idles in place) to swing at, and props and pedestals work as targets too.

The asset packs contain no VFX art, so the arrow is the real `arrow_bow` model while the bolt and
the sparks are built from `CPUParticles3D`, an emissive mesh and a light in `scenes/effects/`.
Timing, reach and the spawn bone are per-station exports in the **Attack effect** group.

### Checking it still works
```
godot --headless --path . --script res://tests/animation_lab_check.gd
```
Covers every character wearing a loadout, each stance's idle/walk/run, planted blocking, the full
attack cycle and spam resistance, every station's detect/play/release, the seated and lying poses
against the measured chair and bed geometry, hit-only melee sparks, both projectiles, and the
animation browser. Exits non-zero on failure.

A station is an `Area3D` running `interaction_station.gd`. Its exports define what F does: the
**Action** group holds `enter`/`idle`/`exit` animations, the **Loadout** group holds the scenes to
put in each hand plus the stance's idle, walk, run, attack and secondary animations. Duplicate a
station, point it at another prop and fill in the animations to add a new test.

## Character lineup
Open `scenes/playground/character_lineup.tscn` and press F6 to see every character side by side,
each looping one animation assigned through its `AnimationPlayer`'s **Autoplay on Load**.

| Character | Animation | | Character | Animation |
| --- | --- | --- | --- | --- |
| Barbarian | `combat_melee/Melee_2H_Attack_Spinning` | | Skeleton Warrior | `combat_melee/Melee_2H_Idle` |
| Knight | `combat_melee/Melee_Blocking` | | Skeleton Rogue | `special/Skeletons_Walking` |
| Mage | `combat_ranged/Ranged_Magic_Spellcasting` | | Skeleton Minion | `combat_melee/Melee_Unarmed_Idle` |
| Ranger | `combat_ranged/Ranged_Bow_Aiming_Idle` | | Skeleton Mage | `special/Skeletons_Idle` |
| Rogue | `movement_advanced/Sneaking` | | | |
| Rogue (Hooded) | `tools/Lockpicking` | | | |

Every character scene loads the same eight rig_medium libraries, so any animation works on any
character: `combat_melee`, `combat_ranged`, `general`, `movement_advanced`, `movement_basic`,
`simulation`, `special` and `tools`. All ten share one rig, including the `handslot.l` and
`handslot.r` bones the animation lab attaches equipment to.

## Credits
3D models and animations by Kay Lousberg ([KayKit](https://www.kaylousberg.com)), CC0:
Adventurers 2.0, Skeletons 1.1, Dungeon Pack 1.1 and Character Animations 1.1.
