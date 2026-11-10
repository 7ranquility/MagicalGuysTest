# Plan

The game builds and runs after every phase. Each phase ends with a headless check
(`scripts/tools/`) and a screenshot pass.

| Phase | Scope | Exit check |
|---|---|---|
| 0 | Repo inspection, tooling (headless Godot, screenshots, audio capture), DESIGN.md, PLAN.md | Docs written, tech risks tested |
| 1 | Autoloads, content loader, generated art, run scene: player, pooled enemies, spatial grid, XP, level-up, HUD, death and results | Bot survives and levels up in a headless run |
| 2 | 16 instruments x 8 levels, 16 passives, evolutions, unions, pickups, chests, props, reroll/skip/banish | Every instrument deals damage at every level |
| 3 | Synth, stems, master clock, beat-synced attacks, layer tiers, intensity, boss key change, mixer, SFX | Captured audio is on tempo and in key |
| 4 | 6 stages, 30+ enemies, wave timelines, hazards, bosses with phases, win condition | Every stage timeline runs start to boss |
| 5 | Save, shop, characters, achievements, secrets, arcana, collection, jukebox, modes | Save round trip, migration, unlock flow |
| 6 | All menus, gamepad, remap, touch stick, game feel, accessibility, debug menu | Screenshot of every screen |
| 7 | Bot balance runs, DPS table, 500+ enemy benchmark, README | Definition of done checklist |

## Change log

Changes to this plan are recorded here as phases complete.

* **Scope cut to a playtest build (on request).** Done: core loop, all instruments and
  passives, evolutions, pickups, chests, props, stage 1 with boss, HUD, pause, settings,
  results, procedural music for Lo-Fi Grove with per-instrument layers, SFX.
  Enemy, stage, character, shop, achievement and arcana data for the full game is written
  but only stage 1 and Froguitar are reachable. Open: stage and character select, shop,
  collection, jukebox, music for stages 2 to 6, boss key change, debug menu, balance pass.
* **Music design change.** An instrument's layer is generated from its attack rhythm, so
  the layer's notes and the attacks land on the same steps. Layers switch in on bar lines.
  All stages point at the Lo-Fi Grove track until their own tracks exist.
