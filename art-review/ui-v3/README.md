# Minimal UI review 03

Pending visual approval. This revision follows the request to make the UI really minimal.

- Solid charcoal background, plain white/gray text, flat controls.
- White primary action, subtle gray selected row, thin inventory-slot outlines.
- Original character and equipment models rendered in Godot.
- Godot's built-in font; no generated imagery, custom font dependency, decorative scenery, or panel ornament.

Screenshots: main-menu.png, character-select.png, character-select-mage.png, hub.png.

The preview remains isolated under art-review/.gdignore. No live gameplay or UI files were modified by this revision. The stash is empty sample data; the crafting list uses three real recipes. Shop, Settings and dungeon actions are visual placeholders. Character selection and menu navigation work within the review without saving profile changes.

Render from the project root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path "$PWD" --rendering-method gl_compatibility --resolution 1440x900 --script "$PWD/art-review/ui-v3/preview.gd"
```

Append `-- --interactive` to navigate the review. Four captures completed without reported script or rendering errors on Godot 4.7.2. The main menu, Knight selection and hub screenshots were visually checked at 1440 × 900. Live-game integration and responsive layout testing await approval of the direction.
