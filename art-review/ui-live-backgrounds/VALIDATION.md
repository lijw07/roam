# Live UI background and inventory validation

The main menu, character selection, and hub now instance the live dungeon background. These are integrated game scenes, not the earlier review prototypes.

- Original KayKit meshes/materials, existing torch effects, no generated imagery.
- Actual selected character stands inside the background room with class-compatible weapon meshes and original attack, block, aim/cast and swap animations. No combat logic runs in the showcase.
- Main menu, character selection and hub rendered at 1280 × 720; controls inspected for readability and clipping.
- Camera movement confirmed across a 12-second phase change in its 48-second loop.
- Dungeon inventory captured in the actual gameplay test scene, with temporary sample potion/resource stacks, then closed to verify the overlay disappears.
- Inventory UI checks: 17 passed, 0 failed. Includes accepted/rejected potion use, moving, shift-splitting, pending-action cancellation, drop signal and close methods.
- Full dungeon capture reports a model-owner warning from gameplay_test.gd's existing character swap and two particle-shader allocations at engine shutdown. No new UI script errors were reported. Headless checks also report the host certificate-store warning. These messages have not been addressed as part of this UI work.
- Desktop Compatibility renderer checked on Godot 4.7.2. Other renderer/export targets are not validated.

The previous ui-v1, ui-v2 and ui-v3 directories are historical art reviews; they are not runtime dependencies.

Character showcase checks pass for all five classes and both demo weapons per class. Rotation checks: 13 passed, 0 failed, covering yaw-only drag, animation/timer/camera pause, release outside the control, focus loss, class changes, Escape and cursor cleanup. Screenshots include the rotated actor, shield block and alternate weapon. Floating tooltips removed by the overlapping upstream changes remain removed. All six conflict entries have been resolved.

The dungeon backpack has been further simplified to a compact 64-pixel item grid, stack counts, title and close button. The details sidebar, capacity counter, use button and help footer were removed. The updated inventory checks pass: 17 checks, 0 failures. `dungeon-inventory-minimal.png` and `dungeon-inventory.png` show the revised panel at 1280 × 720 in the actual dungeon scene, with no clipping.

The shared health, mana and stamina HUD now uses 220 × 4 pixel bars with muted colors, small labels and separate current/maximum values. `capture_vitals.gd` captures full and partially depleted states in the actual dungeon and checks full, drained, empty, restored and missing-pool behavior. All checks passed; both `dungeon-vitals-full.png` and `dungeon-vitals-minimal.png` were visually inspected at 1280 × 720. The existing model-owner and particle-shader shutdown warnings remain.

The dungeon's top control text is replaced by bottom-right keycap and mouse-button glyphs. The row wraps without overlapping vitals at 1280 × 720 and 960 × 540; inventory and death states show their relevant actions. Interaction prompts sit above the row and hide while the inventory is open. Character selection now centers the actor between the class list and a short description/backstory for each of the five classes. The duplicate class name, equipment list and rotation instruction beneath the actor are removed. The turntable checks still pass (13/13). `capture_controls_lore.gd` verifies all five story bindings, inventory/death hint switching and viewport bounds, and captures the updated screens. The existing dungeon warnings above remain unchanged.

Shared menu buttons now have a thin gray border and translucent charcoal fill in their normal state, with a dimmer bordered disabled state. The existing white hover/focus treatment remains. Main menu, settings binding slots (including empty slots), and hub footer were rendered and visually checked at 1280 × 720 using `capture_button_borders.gd`; the run exited without errors. Captures: `main-menu-bordered-buttons.png`, `settings-bordered-buttons.png`, `settings-bordered-focus.png`, and `hub-bordered-buttons.png`.

Crafting and Shop tabs also have outlines in selected and unselected states. Crafting item buttons inherit the shared border. Shop offers use a matching bordered panel, with item/price above the quantity and Buy controls so names remain readable in the narrow column. Both tabs were rendered and inspected at 1280 × 720; `shop-bordered-offers.png` captures the shop layout. No purchases or saved settings were changed during capture.

Expanded crafting details now use equal 16-pixel left/right padding (replacing the 56-pixel left-only indent), with 8-pixel ingredient spacing. Crafting and shop lists have a 10-pixel gap before the scrollbar. Shared vertical scrollbars use a subdued 6-pixel track/thumb with brighter hover/drag states. `capture_crafting_spacing.gd` verifies recipe expansion, the scrollbar gap and scrolling; expanded crafting and shop captures were visually checked at 1280 × 720. The run exited without errors.

Stash item cards now use an opaque charcoal panel, thin border, original item icon, compact name/type heading, divider and aligned stack count. Equipment warnings and potion/damage details remain. `capture_stash_tooltip.gd` checks material/potion/equipment contents, icon loading, edge placement and dismissal; rendered cards were inspected after content-driven sizing settled.

The pause menu and leave-run confirmation now share a bordered dark panel. Confirmation replaces the pause options, defaults focus to Cancel, and uses equal-width Cancel/Leave run buttons. Escape cancels confirmation or closes settings while keeping the game paused; Resume restores play. `capture_pause_confirmation.gd` checked these states and reopening without ending a run or changing saved inventory. The existing dungeon model-owner and particle-shader shutdown warnings remain.
