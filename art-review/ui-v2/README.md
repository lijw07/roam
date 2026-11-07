# Roam UI review 02

Status: pending visual approval. Replaces the rejected generated-image direction in ui-v1.

This preview is rendered by Godot using the project's original assets. No generated painting, redrawn character, or generated texture is used. The live menu scenes and gameplay scripts have not been changed by this art pass. The parent art-review/.gdignore prevents review assets being imported into the game.

## Review images

- main-menu.png: centered title and menu over original dungeon meshes.
- character-select.png: original Knight model, original character portrait renders, original starting equipment.
- character-select-mage.png: original Mage model and staff, validating a second selection.
- hub.png: matching loadout, 3 × 3 backpack, 8 × 6 stash, and three class-compatible crafting examples sourced from the project recipes.

## Source and reproduction

From the Roam project directory:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --rendering-method gl_compatibility --resolution 1440x900 --script "$PWD/art-review/ui-v2/preview.gd"
```

Append `-- --interactive` to navigate the visual prototype. Character choices, Back, Play, Continue, and Main Menu navigate the review. Settings is a placeholder, crafting/materials/dungeon actions are nonfunctional review controls. It does not choose a saved class, alter inventory, or start a run. This preview is a separate SceneTree script; it is not a replacement for the real UI logic.

Character geometry/materials/animation: scenes/characters/adventurers/*.tscn, their original KayKit models, and general/Idle_A. Portraits are rendered from the same models. Equipment uses the project's ItemIconRenderer. Dungeon meshes come from assets/dungeon: floors, walls, pillars, banners and containers, with their existing materials. Original asset provenance/licenses remain in assets/licenses.

UI surfaces: original Godot StyleBoxFlat controls with restrained depth, graphite backgrounds, ivory labels and muted brass selection/primary states. Text remains native and editable. The preview uses the locally available Avenir Next system font with Arial fallback; no font binaries are copied or distributed. A final cross-platform font choice is still needed before integration.

Verified: four 1440 × 900 captures completed on Godot 4.7.2 Compatibility renderer with no reported script/render errors in the final run. Inspected portrait and equipment sizing, long class description, slot geometry, and footer placement. This is a desktop art/layout review; responsive layouts, full gameplay flows, and other platforms are not validated.
