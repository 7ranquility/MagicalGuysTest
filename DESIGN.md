# MusicalGuys: Design

A Vampire Survivors style bullet heaven where every weapon is a musical instrument
and the soundtrack is assembled live from what the player has equipped.

## 1. What was in the repo

| Area | Found | Decision |
|---|---|---|
| Engine | Godot 4.4, GDScript, Forward+ renderer, 1920x1080 | Kept. Nothing in the goal needs a different stack. |
| Game code | Prototype: one `CharacterBody2D` player, one enemy scene, aura and projectile weapon, level-up popup, `UpgradeRegistry` autoload with upgrades as lambdas | Replaced. Node-per-enemy with group scans is O(n^2) and tops out near 100 enemies. The ideas (auto-aim projectile, aura, XP gems, level-up choice) carry over into the new systems. |
| Art | `Froguitar` frog (7 frames), `Noteguy` enemy (4 frames), lemon-note attack (4 frames), `GRASS+` tileset, `BG.png`, coin, two UI nine-patch sheets | All reused. The frog is the starter character, Noteguy is the first enemy, the UI sheet drives the theme, the grass field is the first stage floor. |
| Audio | None | Music and SFX are synthesized procedurally at runtime. |
| Addons | Dialogic, Gaea, Phantom Camera, Todo Manager, GDScript formatter | Left installed and untouched. The game does not depend on them. |
| Conventions | `.cursorrules`: typed GDScript, snake_case files, PascalCase classes, signals in past tense, pooling, packed arrays | Followed. One deviation, see 9. |
| Input map | `ui_*` extended with WASD and gamepad | Kept, plus dedicated `move_*` and `pause` actions that can be remapped. |

## 2. Core decisions

**Final encounter.** Each stage ends with a boss at the end of the timer. Killing it is the
win. (The alternative, an unbeatable Reaper, makes "cleared" ambiguous.) In Endless mode the
run continues after the boss with rising curse.

**Data-oriented simulation.** Enemies, shots, enemy bullets, pickups, particles and damage
numbers live in pooled struct-of-arrays managers (packed arrays, swap-remove, no nodes per
entity). A uniform spatial grid is rebuilt once per frame with a counting sort and serves every
collision query. Each manager draws all of its entities in a single `_draw()` from one atlas.

**Everything on the beat.** There is one master clock, derived from the audio playback
position. Weapons do not have free-running timers. A cooldown in seconds is converted into
"hits per 4 bars" for the stage tempo and laid out as a Euclidean rhythm on the 16th-note
grid. Cooldown upgrades raise the hit count, so balance stays tempo independent while every
attack still lands on a grid step.

**Config over code.** `data/*.json` defines instruments, passives, enemies, stages, waves,
characters, shop, achievements, arcana and all music. Code implements a fixed set of
primitives (attack patterns, enemy AI kinds, boss attacks, hazard kinds, synth timbres) that
config entries parameterize.

## 3. Module map

```
scripts/autoload/   content.gd   JSON database + validation
                    save.gd      versioned save, migration, export/import, settings
                    audio.gd     buses, SFX pool, voice limiting, ducking
                    music.gd     music director: clock, stems, layers, intensity
                    game.gd      screen flow, run setup, unlock checks
scripts/audio/      synth.gd, stem_renderer.gd, rhythm.gd
scripts/core/       run.gd (loop), player.gd, stats.gd, spatial_grid.gd,
                    enemy_manager.gd, boss_controller.gd, wave_director.gd,
                    weapon_system.gd, shot_manager.gd, enemy_bullets.gd,
                    pickup_manager.gd, prop_manager.gd, hazard_manager.gd,
                    fx_manager.gd, level_up.gd, atlas.gd
scripts/ui/         ui_kit.gd + one script per screen, hud.gd, debug_menu.gd
scripts/tools/      headless tools: validate, bot playtest, balance table, benchmark
data/               all content
tools/gen_art.py    generates the sprite atlas and stage floors
```

Frame order in `run.gd`: input and player, music steps to weapons, wave director, enemies
(AI, grid, separation, contact), shots, enemy bullets, hazards, boss, pickups, deaths, FX, HUD.

## 4. Instruments

Sixteen instruments (14 regular, 2 secret), eight levels each, each built on a different
attack primitive:

| Instrument | Pattern | Evolves with | Evolution |
|---|---|---|---|
| Drums | shockwave rings around the player | Metronome | Thunder Kit |
| Electric Guitar | instant piercing beam in facing direction | Volume Knob | Feedback Axe |
| Bass | slow wide wave, heavy knockback | Amplifier | Subwoofer of Doom |
| Violin | homing bow slashes | Tuning Fork | Stradivarius Storm |
| Trumpet | forward cone blast | Stage Presence | Fanfare of Kings |
| Piano | notes rain on random enemies | Sustain Pedal | Grand Finale |
| Harp | orbiting strings | Capo | Celestial Lyre |
| Synthesizer | bouncing waveform shots | Encore | Modular Monster |
| Cello | alternating melee arcs | Earplugs | Requiem Bow |
| Flute | rapid needle notes | Lucky Pick | Pied Piper |
| Choir | damaging, slowing aura | Backstage Pass | Hallelujah |
| Turntable | boomerang records | Royalties | Platinum Record |
| Triangle | chain lightning | Groupie Magnet | Golden Triangle |
| Organ | erupting pipes leave damage pools | Setlist | Phantom's Organ |
| Theremin (secret) | lock-on arc to the nearest enemies | Spotlight | Aether Wave |
| Cowbell (secret) | lobbed exploding bells | Roadie | More Cowbell |

Unions: Drums + Bass become **Rhythm Section**, Violin + Cello become **String Quartet**.
Both need the two instruments at max level and a chest.

## 5. Adaptive soundtrack

No audio assets exist, so everything is synthesized.

* **Synth.** Band-limited wavetable voices (organ, saw, pulse, pluck, strings, brass, flute,
  voice, bell, FM, ...) plus synthesized drum kits, all in GDScript.
* **Stems.** A stage track is a set of loops of identical length (the chord progression,
  4 or 8 bars). Each layer (base parts, intensity parts, one per equipped instrument) is
  rendered to PCM on a worker thread from pattern data: scale degrees relative to the
  current chord, so every layer is in the stage's key by construction. Stage style adds
  swing, octave, articulation and post-processing.
* **Sample-locked playback.** All layers play through one `AudioStreamSynchronized`. A new
  layer is written into a silent slot of the already running stream, then faded in at the
  next bar line. Layers therefore can not drift or enter off-beat.
* **Tiers.** Instrument levels 1-2, 3-5, 6-8 and the evolved form each have their own
  pattern (more notes, harmony, echo, different timbre).
* **Intensity.** Enemy density, boss presence and low HP drive extra percussion layers, a
  filter sweep and a danger layer. When a boss appears all stems are re-rendered a whole
  step up and swapped in at a bar line.
* **Mixer.** Master, Music, SFX buses with sliders. SFX are voice limited, rate limited per
  sound and compressed, and the SFX bus is ducked as voices pile up. Attack sounds are
  pitched to tones of the current chord.

## 6. Stages

| # | Stage | Genre | Hazard | Boss |
|---|---|---|---|---|
| 1 | Lo-Fi Grove | lo-fi hip hop | sleepy fog (slow zones) | The Tape Worm |
| 2 | Cathedral of Dissonance | gothic organ | falling bells | The Dissonant Organist |
| 3 | Neon Overdrive | synthwave | laser sweeps | DJ Overdrive |
| 4 | The Blue Note | swing jazz (corridor map) | smoke clouds, tumbling spotlights | Maestro Scat |
| 5 | Mount Shredmore | metal | lava eruptions and pools | Pyro Shredder |
| H | Castle Crescendo (hidden) | orchestral | cannon volleys | The Grand Conductor |

## 7. Meta progression

Gold persists. Power-up shop with 19 stats, rising costs and full refund. Achievements
unlock characters, instruments, passives, stages, modes and Sheet Music cards (arcana).
Collection screen with recipes, bestiary and a jukebox with per-layer toggles. Hyper, Hurry
and Endless modes per stage. Save file is versioned JSON with migrations, export/import and
reset.

## 8. Performance budget

Target: 60 FPS with 500+ enemies. Script budget per frame is about 8 ms: enemy update and
grid under 3 ms, shots under 2 ms, drawing under 2 ms. No allocations in the per-frame paths
(preallocated packed arrays, reusable query buffers). `scripts/tools/benchmark.gd` measures it.

## 9. Deviations and calls made

* **Scenes are built in code.** `.cursorrules` asks for editor steps instead of scene source.
  This work was done without the editor, so there is one tiny scene (`main_scene.tscn`,
  same UID as before) and every node tree is constructed in typed GDScript. Layout lives in
  `scripts/ui/`.
* **Old prototype files removed.** The former player, enemy, weapon and menu scenes and
  scripts are superseded and were deleted, along with stray `*.tmp` editor files. They
  remain in git history.
* **Placeholder art is generated.** `tools/gen_art.py` draws the extra sprites in the style
  and size (32 px, dark outline) of the existing frog and Noteguy.
* **Fonts.** Pixelify Sans and Silkscreen (SIL OFL) were added for readable pixel text.
