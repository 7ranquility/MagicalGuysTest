# MusicalGuys (playtest build)

A Vampire Survivors style auto-shooter where every weapon is an instrument and the
soundtrack is built live from what you have equipped.

## Run

Open the project in **Godot 4.4** and press F5, or from a terminal:

    godot --path .

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrows | left stick / d-pad |
| Pause | Esc / P | Start |
| Menus | arrows + Enter, or mouse | d-pad + A |

Instruments fire on their own, on the beat. Each one adds its own layer to the music,
playing on exactly the steps it attacks on.

## What is in this build

* One character (Froguitar), one stage (Lo-Fi Grove), 30 minute timer, boss at the end.
* 16 instruments with 8 levels, 16 passives, evolutions and two unions from chests.
  Some start locked and unlock through play.
* Procedural music: drums, bass and keys, plus one layer per equipped instrument that
  grows with its level.
* Settings: volumes, screen shake, damage numbers, key remap, stage length (set it to
  5 or 10 minutes for a quick session).

Not in yet: character and stage select, shop, collection, the other five stages' music
and their menu entry, debug menu. See PLAN.md.

## Dev tools

    godot --headless --path . -- --tool=bot minutes=30     # bot plays a run, prints the result
    godot --headless --path . -- --tool=render_music       # writes user://mix.wav
    python3 tools/gen_content.py                           # regenerates data/enemies.json and data/stages.json

All content lives in `data/*.json`. See DESIGN.md for the architecture.
