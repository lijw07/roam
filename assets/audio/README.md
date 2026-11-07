# Roam audio

The first synthesized placeholder cues have been replaced in the main sound paths with recorded effects and orchestral music. See [ATTRIBUTION.md](ATTRIBUTION.md) for sources and licenses.

Use [audio_review.html](audio_review.html) to listen through the updated SFX and music in a browser.

- `sfx/`: combat, footsteps, item handling, UI, and interaction effects. Walk and run steps and landings select randomized stone, wood, leaves, gravel, or mud recordings by reading surface metadata/groups and scene or material names.
- `music/`: orchestral title/menu theme. Active gameplay has no background score; dungeon exploration keeps a quiet wind and water ambience bed.
- `samples/`: source recordings used by the audio manager.

Weapon impacts resolve surfaces from an `audio_surface` metadata value, an `audio_surface_wood` / `_stone` / `_metal` group, scene or node names, and mesh material names. One swing can trigger simultaneous wood, stone, and metal impacts when the weapon overlaps several materials.

Sword swings now vary across recorded blade movements, bow draws and death reactions use recorded performances, and jump/landing cues are quieter/louder variants of the detected ground surface. The review page includes the revised cues for listening and mix feedback.
