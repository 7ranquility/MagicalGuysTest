#!/usr/bin/env python3
"""Authoring helper for the two largest config files: data/enemies.json and data/stages.json.

The JSON files are what the game loads. This script only exists so the wave timelines of
all stages can be tuned together (density curve, event rhythm). Run it from the project
root after changing the tables below:  python3 tools/gen_content.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")


def E(name, sprite, ai, hp, speed, damage, xp, radius=8, desc="", **extra):
    d = {"name": name, "sprite": sprite, "ai": ai, "hp": hp, "speed": speed, "damage": damage,
         "radius": radius, "xp": xp, "desc": desc}
    d.update(extra)
    return d


ENEMIES = {
    # --- Lo-Fi Grove
    "sour_note": E("Sour Note", "en_noteguy", "chase", 8, 36, 5, 1, desc="A note that never found its chord. Wanders in packs."),
    "flat_bat": E("Flat Bat", "en_bat", "flyer", 5, 62, 4, 1, 7, "Always a semitone under. Flies over everything."),
    "hum_slime": E("Hum Slime", "en_slime", "chase", 20, 30, 7, 2, 9, "Sixty cycles of mains hum, given a body."),
    "tape_tick": E("Tape Tick", "en_tick", "chase", 4, 72, 3, 0.5, 5, "Tiny, fast, and lives inside old cassettes.", scale=0.8),
    "hiss_wisp": E("Hiss Wisp", "en_wisp", "sine", 12, 55, 6, 2, 7, "Tape hiss drifting in lazy curves.", flyer=True, pa=0.9, pb=3.0),
    "ear_worm": E("Ear Worm", "en_grub", "zigzag", 16, 50, 6, 2, 8, "You will not get it out of your head.", pa=0.8, pb=0.9),
    "shroom_shaker": E("Shroom Shaker", "en_shroom", "chase", 45, 26, 9, 4, 10, "A maraca that grew roots. Slow but sturdy.", kb_resist=0.4),
    "chewed_cassette": E("Chewed Cassette", "en_cassette", "chase", 30, 34, 8, 3, 9, "Splits into Tape Ticks when it breaks.", split_into="tape_tick", split_count=3),
    "garden_gnome": E("Garden Gnome-ad", "en_gnome", "ranged", 22, 40, 7, 3, 8, "Keeps its distance and throws wrong notes.", pa=150, pb=2.6, pc=95),
    "moss_mumbler": E("Moss Mumbler", "en_moss", "chase", 90, 28, 12, 6, 11, "Mumbles the lyrics. Thick skinned.", armor=2, kb_resist=0.6),
    "off_key_troll": E("Off-Key Troll", "en_troll", "chase", 160, 34, 15, 10, 13, "Sings loudest, sings worst.", scale=1.3, kb_resist=0.7,
                       phases=[{"hp": 1.0, "attacks": [{"kind": "slam", "every_beats": 8, "count": 2, "radius": 46, "damage": 12, "warn_beats": 3}]}]),
    # --- Cathedral of Dissonance
    "off_key_ghoul": E("Off-Key Ghoul", "en_ghoul", "chase", 26, 40, 9, 2, 9, "The congregation's worst singer, risen again."),
    "choir_shade": E("Choir Shade", "en_shade", "chase", 18, 66, 8, 2, 8, "A fast shadow that lost its choir."),
    "feedback_wraith": E("Feedback Wraith", "en_wraith", "teleport", 40, 38, 11, 4, 9, "Howls, vanishes, and reappears right next to you.", pa=4.0, pb=120),
    "silence_specter": E("Silence Specter", "en_specter", "phase", 34, 44, 10, 4, 9, "Fades out on the off-bars. Its touch muffles the music.", flyer=True, muffles=True),
    "dissonant_cultist": E("Dissonant Cultist", "en_cultist", "ranged", 36, 38, 10, 4, 9, "Chants tritones from a safe distance.", pa=170, pb=2.4, pc=110),
    "gargoyle": E("Gargoyle", "en_gargoyle", "charger", 70, 46, 14, 6, 10, "Winds up, then dives.", flyer=True, pa=330, pb=150, pc=0.7,
                  phases=[{"hp": 1.0, "attacks": [{"kind": "aimed", "every_beats": 8, "count": 5, "spread": 60, "speed": 120, "damage": 12}]}]),
    "requiem_ghost": E("Requiem Ghost", "en_rghost", "sine", 30, 58, 9, 3, 8, "Sways to a funeral march.", flyer=True, pa=1.1, pb=2.4),
    "mute_knight": E("Mute Knight", "en_knight", "chase", 180, 30, 16, 9, 11, "Armored in silence. Barely flinches.", armor=4, kb_resist=0.8,
                     phases=[{"hp": 1.0, "attacks": [{"kind": "cross", "every_beats": 8, "count": 2, "width": 20, "damage": 14, "warn_beats": 4}]}]),
    # --- Neon Overdrive
    "broken_record": E("Broken Record", "en_record", "zigzag", 40, 60, 10, 3, 9, "Skips left, skips right, skips left, skips right.", pa=0.6, pb=1.2),
    "blown_speaker": E("Blown Speaker", "en_speaker", "exploder", 45, 52, 12, 4, 9, "Gets close, then pops. Stand clear of the circle.", pa=60, pb=70, pc=0.9),
    "glitch": E("Glitch", "en_glitch", "teleport", 36, 50, 11, 4, 8, "A dropped frame with teeth.", pa=3.0, pb=100),
    "static_cloud": E("Static Cloud", "en_static", "buffer", 80, 42, 8, 6, 10, "Hangs back and speeds up everything around it.", flyer=True, pa=180, pb=130),
    "boombox_brute": E("Boombox Brute", "en_boombox", "ranged", 220, 30, 14, 10, 12, "Heavy, loud, and it shoots.", armor=2, kb_resist=0.7, pa=200, pb=3.0, pc=120,
                       phases=[{"hp": 1.0, "attacks": [{"kind": "radial", "every_beats": 8, "count": 10, "speed": 95, "damage": 12}]}]),
    "clip_shard": E("Clip Shard", "en_shard", "chase", 22, 82, 9, 2, 7, "What is left when the signal goes over 0 dB."),
    "buzz_wasp": E("Buzz Wasp", "en_wasp", "sine", 26, 76, 9, 3, 7, "A ground loop with wings.", flyer=True, pa=0.6, pb=5.0),
    # --- The Blue Note
    "heckler": E("Heckler", "en_bully", "charger", 85, 48, 15, 6, 10, "Storms the stage when you least need it.", pa=300, pb=130, pc=0.6,
                 phases=[{"hp": 1.0, "attacks": [{"kind": "charge", "every_beats": 8, "speed": 380, "damage": 16, "warn_beats": 3}]}]),
    "shrieking_diva": E("Shrieking Diva", "en_diva", "ranged", 60, 40, 13, 5, 9, "Holds the high note until something breaks.", pa=190, pb=2.2, pc=135),
    "crab_canon": E("Crab Canon", "en_crab", "zigzag", 70, 56, 12, 5, 9, "The same melody, sideways and backwards.", armor=2, pa=1.0, pb=1.4),
    "spotlight_moth": E("Spotlight Moth", "en_moth", "sine", 34, 70, 10, 3, 8, "Drawn to whoever is in the light. That is you.", flyer=True, pa=1.2, pb=3.5),
    "tempo_imp": E("Tempo Imp", "en_imp", "chase", 30, 88, 10, 3, 7, "Rushes every bar."),
    "scale_snake": E("Scale Snake", "en_snake", "sine", 55, 52, 12, 4, 8, "Runs up and down, never resolves.", pa=0.8, pb=2.0),
    "web_spinner": E("Web Spinner", "en_spider", "chase", 110, 44, 13, 6, 10, "Bursts into a brood of Tape Ticks.", split_into="tape_tick", split_count=4),
    # --- Mount Shredmore
    "ember": E("Ember", "en_ember", "exploder", 50, 64, 16, 4, 8, "A stray spark from the pyro rig. Explodes.", pa=55, pb=80, pc=0.8),
    "headbanger": E("Headbanger", "en_headbanger", "charger", 130, 50, 18, 7, 10, "Hair first, questions never.", pa=360, pb=160, pc=0.55,
                    phases=[{"hp": 1.0, "attacks": [{"kind": "charge", "every_beats": 8, "speed": 420, "damage": 20, "warn_beats": 3},
                                                     {"kind": "slam", "every_beats": 8, "offset_beats": 4, "count": 3, "radius": 50, "damage": 16, "warn_beats": 3}]}]),
    "riff_beetle": E("Riff Beetle", "en_beetle", "chase", 260, 32, 18, 11, 12, "A wall of chitin. Bring something that hits hard.", armor=5, kb_resist=0.85),
    # --- tools
    "practice_dummy": E("Practice Dummy", "en_dummy", "chase", 1000000000, 0, 0, 0, 10, "Stands there and takes it.", kb_resist=1.0, hidden=True),
}

for stage_, name_ in [("forest", "Paper Lantern"), ("cathedral", "Candelabra"), ("neon", "Street Lamp"),
                      ("jazz", "Table Lamp"), ("volcano", "Brazier"), ("castle", "Torch Stand")]:
    ENEMIES["prop_" + stage_] = {"name": name_, "sprite": "prop_" + stage_, "ai": "prop", "hp": 6, "speed": 0, "damage": 0,
                                 "radius": 9, "xp": 0, "desc": "Break it for a pickup.", "hidden": True}


def boss(name, sprite, hp, speed, damage, desc, phases):
    return {"name": name, "sprite": sprite, "ai": "boss", "boss": True, "hp": hp, "speed": speed, "damage": damage,
            "radius": 24, "xp": 300, "desc": desc, "phases": phases}


ENEMIES["tape_worm"] = boss("The Tape Worm", "boss_tapeworm", 14000, 34, 18, "It ate every mixtape in the grove.", [
    {"hp": 1.0, "attacks": [
        {"kind": "radial", "every_beats": 8, "count": 10, "speed": 80, "damage": 10},
        {"kind": "summon", "every_beats": 16, "offset_beats": 4, "enemy": "tape_tick", "count": 6}]},
    {"hp": 0.6, "speed": 1.2, "attacks": [
        {"kind": "aimed", "every_beats": 4, "count": 5, "spread": 50, "speed": 120, "damage": 10},
        {"kind": "slam", "every_beats": 8, "offset_beats": 2, "count": 3, "radius": 55, "damage": 14, "warn_beats": 4},
        {"kind": "summon", "every_beats": 16, "offset_beats": 8, "enemy": "tape_tick", "count": 8}]},
    {"hp": 0.3, "speed": 1.4, "attacks": [
        {"kind": "spiral", "every_beats": 8, "beats": 4, "arms": 3, "speed": 90, "damage": 10},
        {"kind": "charge", "every_beats": 8, "offset_beats": 5, "speed": 420, "damage": 18, "warn_beats": 3},
        {"kind": "radial", "every_beats": 16, "offset_beats": 12, "count": 16, "speed": 100, "damage": 10}]},
])
ENEMIES["organist"] = boss("The Dissonant Organist", "boss_organist", 26000, 30, 22, "Plays every stop at once.", [
    {"hp": 1.0, "attacks": [
        {"kind": "cross", "every_beats": 8, "count": 2, "width": 26, "damage": 16, "warn_beats": 4},
        {"kind": "summon", "every_beats": 16, "offset_beats": 6, "enemy": "off_key_ghoul", "count": 6}]},
    {"hp": 0.66, "speed": 1.15, "attacks": [
        {"kind": "slam", "every_beats": 4, "count": 3, "radius": 50, "spread": 180, "damage": 16, "warn_beats": 3},
        {"kind": "cross", "every_beats": 8, "offset_beats": 4, "count": 3, "width": 24, "damage": 16, "warn_beats": 4},
        {"kind": "radial", "every_beats": 8, "offset_beats": 2, "count": 12, "speed": 90, "damage": 12}]},
    {"hp": 0.33, "speed": 1.3, "attacks": [
        {"kind": "spiral", "every_beats": 8, "beats": 6, "arms": 4, "speed": 95, "damage": 12},
        {"kind": "lines", "every_beats": 4, "offset_beats": 2, "count": 3, "width": 22, "damage": 16, "warn_beats": 3},
        {"kind": "summon", "every_beats": 16, "offset_beats": 8, "enemy": "silence_specter", "count": 5}]},
])
ENEMIES["dj_overdrive"] = boss("DJ Overdrive", "boss_dj", 40000, 36, 24, "Drops the bass, then drops the ceiling.", [
    {"hp": 1.0, "attacks": [
        {"kind": "lines", "every_beats": 4, "count": 2, "width": 20, "damage": 16, "warn_beats": 3},
        {"kind": "aimed", "every_beats": 8, "offset_beats": 2, "count": 7, "spread": 70, "speed": 135, "damage": 12}]},
    {"hp": 0.66, "speed": 1.2, "attacks": [
        {"kind": "field", "every_beats": 16, "count": 3, "radius": 60, "duration": 8, "damage": 6, "slow": 0.7, "style": "fog"},
        {"kind": "charge", "every_beats": 8, "offset_beats": 4, "speed": 460, "damage": 20, "warn_beats": 3},
        {"kind": "radial", "every_beats": 4, "offset_beats": 1, "count": 12, "speed": 105, "damage": 12},
        {"kind": "summon", "every_beats": 16, "offset_beats": 10, "enemy": "blown_speaker", "count": 5}]},
    {"hp": 0.33, "speed": 1.35, "attacks": [
        {"kind": "spiral", "every_beats": 8, "beats": 6, "arms": 5, "speed": 105, "damage": 12, "turn": 0.28},
        {"kind": "lines", "every_beats": 4, "offset_beats": 2, "count": 4, "width": 20, "damage": 16, "warn_beats": 3},
        {"kind": "charge", "every_beats": 8, "offset_beats": 6, "speed": 500, "damage": 22, "warn_beats": 2}]},
])
ENEMIES["maestro_scat"] = boss("Maestro Scat", "boss_scat", 56000, 40, 26, "Never plays the same solo twice. Sadly.", [
    {"hp": 1.0, "attacks": [
        {"kind": "aimed", "every_beats": 2, "count": 3, "spread": 30, "speed": 150, "damage": 12},
        {"kind": "summon", "every_beats": 16, "offset_beats": 4, "enemy": "tempo_imp", "count": 6}]},
    {"hp": 0.7, "speed": 1.15, "attacks": [
        {"kind": "aimed", "every_beats": 2, "count": 5, "spread": 60, "speed": 155, "damage": 12},
        {"kind": "slam", "every_beats": 8, "offset_beats": 3, "count": 4, "radius": 55, "damage": 18, "warn_beats": 3},
        {"kind": "field", "every_beats": 16, "offset_beats": 8, "count": 3, "radius": 70, "duration": 9, "damage": 0, "slow": 0.6, "style": "smoke"}]},
    {"hp": 0.35, "speed": 1.3, "attacks": [
        {"kind": "spiral", "every_beats": 8, "beats": 8, "arms": 4, "speed": 110, "damage": 12, "turn": 0.5},
        {"kind": "charge", "every_beats": 8, "offset_beats": 4, "speed": 480, "damage": 22, "warn_beats": 3},
        {"kind": "cross", "every_beats": 8, "offset_beats": 6, "count": 3, "width": 24, "damage": 18, "warn_beats": 3},
        {"kind": "summon", "every_beats": 16, "offset_beats": 12, "enemy": "heckler", "count": 3}]},
])
ENEMIES["pyro_shredder"] = boss("Pyro Shredder", "boss_shredder", 78000, 42, 30, "Eleven is where the dial starts.", [
    {"hp": 1.0, "attacks": [
        {"kind": "field", "every_beats": 8, "count": 3, "radius": 55, "duration": 8, "damage": 8, "style": "lava"},
        {"kind": "radial", "every_beats": 4, "offset_beats": 2, "count": 14, "speed": 110, "damage": 14}]},
    {"hp": 0.7, "speed": 1.2, "attacks": [
        {"kind": "charge", "every_beats": 4, "speed": 480, "damage": 24, "warn_beats": 2},
        {"kind": "cross", "every_beats": 8, "offset_beats": 2, "count": 4, "width": 26, "damage": 20, "warn_beats": 3},
        {"kind": "field", "every_beats": 8, "offset_beats": 4, "count": 4, "radius": 55, "duration": 8, "damage": 8, "style": "lava"},
        {"kind": "summon", "every_beats": 16, "offset_beats": 6, "enemy": "ember", "count": 8}]},
    {"hp": 0.35, "speed": 1.4, "attacks": [
        {"kind": "spiral", "every_beats": 8, "beats": 8, "arms": 6, "speed": 115, "damage": 14, "turn": 0.22},
        {"kind": "slam", "every_beats": 4, "offset_beats": 1, "count": 5, "radius": 55, "spread": 220, "damage": 22, "warn_beats": 3},
        {"kind": "charge", "every_beats": 8, "offset_beats": 6, "speed": 520, "damage": 26, "warn_beats": 2}]},
])
ENEMIES["grand_conductor"] = boss("The Grand Conductor", "boss_conductor", 130000, 44, 34, "Every monster you met was reading his score.", [
    {"hp": 1.0, "attacks": [
        {"kind": "lines", "every_beats": 4, "count": 3, "width": 22, "damage": 20, "warn_beats": 3},
        {"kind": "radial", "every_beats": 8, "offset_beats": 2, "count": 16, "speed": 105, "damage": 14},
        {"kind": "summon", "every_beats": 16, "offset_beats": 6, "enemy": "mute_knight", "count": 3}]},
    {"hp": 0.75, "speed": 1.15, "attacks": [
        {"kind": "cross", "every_beats": 4, "count": 4, "width": 24, "damage": 20, "warn_beats": 3},
        {"kind": "aimed", "every_beats": 2, "count": 5, "spread": 55, "speed": 160, "damage": 14},
        {"kind": "slam", "every_beats": 8, "offset_beats": 5, "count": 5, "radius": 55, "spread": 220, "damage": 22, "warn_beats": 3}]},
    {"hp": 0.5, "speed": 1.3, "attacks": [
        {"kind": "spiral", "every_beats": 8, "beats": 8, "arms": 5, "speed": 110, "damage": 14, "turn": 0.3},
        {"kind": "charge", "every_beats": 8, "offset_beats": 4, "speed": 500, "damage": 26, "warn_beats": 2},
        {"kind": "field", "every_beats": 16, "offset_beats": 8, "count": 4, "radius": 60, "duration": 9, "damage": 8, "style": "lava"},
        {"kind": "summon", "every_beats": 16, "offset_beats": 12, "enemy": "gargoyle", "count": 4}]},
    {"hp": 0.25, "speed": 1.45, "attacks": [
        {"kind": "spiral", "every_beats": 4, "beats": 4, "arms": 6, "speed": 120, "damage": 14, "turn": 0.4},
        {"kind": "lines", "every_beats": 4, "offset_beats": 2, "count": 5, "width": 22, "damage": 22, "warn_beats": 2},
        {"kind": "slam", "every_beats": 4, "offset_beats": 1, "count": 4, "radius": 55, "spread": 200, "damage": 24, "warn_beats": 3},
        {"kind": "charge", "every_beats": 8, "offset_beats": 6, "speed": 540, "damage": 28, "warn_beats": 2}]},
])


# --------------------------------------------------------------------------- stages

def lerp(a, b, u):
    return a + (b - a) * u


def waves(roster, density=1.0):
    """roster: 15 enemy lists, one per two reference minutes."""
    out = []
    for k, enemies in enumerate(roster):
        m = k * 2
        u = m / 28.0
        out.append({
            "t": m, "enemies": enemies,
            "interval": round(lerp(1.0, 0.3, u), 2),
            "batch": int(round(lerp(2, 7, u) * density)),
            "min": int(round(lerp(8, 170, u ** 0.9) * density)),
            "max": int(round(lerp(45, 430, u ** 0.9) * density)),
        })
    return out


def events(swarm, ring, wall, elites, minis, boss_id, boss_hp=1.0):
    ev = []
    for k, t in enumerate([3, 9, 15, 21, 27]):
        ev.append({"t": t, "kind": "swarm", "enemy": swarm[k % len(swarm)], "count": 26 + 10 * k})
    for k, t in enumerate([6, 18, 25]):
        ev.append({"t": t, "kind": "ring", "enemy": ring[k % len(ring)], "count": 22 + 10 * k, "radius": 430})
    for k, t in enumerate([12, 23]):
        ev.append({"t": t, "kind": "wall", "enemy": wall[k % len(wall)], "count": 26 + 12 * k})
    for k, t in enumerate([2, 5, 8, 11, 14, 17, 19, 22, 24, 26, 28, 29]):
        ev.append({"t": t, "kind": "elite", "enemy": elites[k % len(elites)], "count": 1 if k < 6 else 2, "hp_mult": 1.0,
                   "text": "An elite takes the stage"})
    for k, t in enumerate([10, 20]):
        ev.append({"t": t, "kind": "miniboss", "enemy": minis[k % len(minis)], "hp_mult": 2.5 + 1.5 * k})
    ev.append({"t": 30, "kind": "boss", "enemy": boss_id, "hp_mult": boss_hp})
    ev.sort(key=lambda e: e["t"])
    return ev


STAGES = {}
STAGES["forest"] = {
    "name": "Lo-Fi Grove", "genre": "Lo-fi hip hop", "track": "lofi_grove",
    "desc": "A sleepy clearing with tape hiss in the air. A gentle place to start, at first.",
    "floor": "res://assets/world/BG.png", "floor_scale": 1.0, "floor_tint": "#ffffff", "icon": "obs_forest",
    "obstacles": {"density": 0.3, "radius": 14, "sprite": "obs_forest"},
    "hp_mult": 1.0, "damage_mult": 1.0, "hp_growth": 0.07,
    "prop": "prop_forest", "prop_interval": 11,
    "hazards": [
        {"kind": "field", "every_beats": 32, "from_minute": 2.0, "count": 1, "grow_minutes": 8, "radius": 70, "duration": 12,
         "slow": 0.6, "style": "fog", "drift": 8}],
    "relics": [],
    "waves": waves([
        ["sour_note"], ["sour_note", "flat_bat"], ["sour_note", "hum_slime"], ["hum_slime", "flat_bat", "tape_tick"],
        ["sour_note", "hiss_wisp", "ear_worm"], ["hum_slime", "ear_worm", "chewed_cassette"],
        ["shroom_shaker", "sour_note", "flat_bat"], ["garden_gnome", "hum_slime", "ear_worm"],
        ["chewed_cassette", "hiss_wisp", "shroom_shaker"], ["moss_mumbler", "tape_tick", "sour_note"],
        ["garden_gnome", "shroom_shaker", "ear_worm"], ["moss_mumbler", "chewed_cassette", "hiss_wisp"],
        ["off_key_troll", "hum_slime", "tape_tick"], ["moss_mumbler", "garden_gnome", "shroom_shaker", "flat_bat"],
        ["off_key_troll", "moss_mumbler", "chewed_cassette", "ear_worm"]]),
    "events": events(["flat_bat", "tape_tick"], ["hum_slime", "shroom_shaker", "moss_mumbler"], ["sour_note", "ear_worm"],
                     ["shroom_shaker", "moss_mumbler", "off_key_troll"], ["off_key_troll"], "tape_worm"),
}
STAGES["cathedral"] = {
    "name": "Cathedral of Dissonance", "genre": "Gothic organ", "track": "lofi_grove",
    "desc": "Cold stone, colder harmony. Bells fall from the vault on the downbeat.",
    "floor": "res://assets/generated/floor_cathedral.png", "floor_scale": 1.0, "floor_tint": "#ffffff", "icon": "obs_cathedral",
    "obstacles": {"density": 0.34, "radius": 14, "sprite": "obs_cathedral"},
    "hp_mult": 1.35, "damage_mult": 1.15, "hp_growth": 0.075,
    "prop": "prop_cathedral", "prop_interval": 11,
    "hazards": [
        {"kind": "falling", "every_beats": 16, "from_minute": 1.0, "count": 2, "grow_minutes": 6, "radius": 38, "spread": 240,
         "warn_beats": 4, "damage": 14}],
    "relics": [{"id": "mask", "achievement": "secret_mime", "pos": [0, -1400], "text": "A white mask. It says nothing."}],
    "waves": waves([
        ["off_key_ghoul"], ["off_key_ghoul", "flat_bat"], ["choir_shade", "off_key_ghoul"], ["requiem_ghost", "flat_bat"],
        ["off_key_ghoul", "dissonant_cultist"], ["choir_shade", "feedback_wraith"], ["silence_specter", "off_key_ghoul"],
        ["gargoyle", "requiem_ghost", "choir_shade"], ["dissonant_cultist", "feedback_wraith", "off_key_ghoul"],
        ["mute_knight", "choir_shade"], ["silence_specter", "gargoyle", "requiem_ghost"],
        ["mute_knight", "dissonant_cultist", "off_key_ghoul"], ["feedback_wraith", "gargoyle", "choir_shade"],
        ["mute_knight", "silence_specter", "requiem_ghost"], ["mute_knight", "gargoyle", "feedback_wraith", "dissonant_cultist"]]),
    "events": events(["flat_bat", "choir_shade"], ["off_key_ghoul", "requiem_ghost", "mute_knight"], ["choir_shade", "off_key_ghoul"],
                     ["feedback_wraith", "gargoyle", "mute_knight"], ["gargoyle", "mute_knight"], "organist"),
}
STAGES["neon"] = {
    "name": "Neon Overdrive", "genre": "Synthwave", "track": "lofi_grove",
    "desc": "A city that never turns the volume down. Watch for the laser grid.",
    "floor": "res://assets/generated/floor_neon.png", "floor_scale": 1.0, "floor_tint": "#ffffff", "icon": "obs_neon",
    "obstacles": {"density": 0.26, "radius": 13, "sprite": "obs_neon"},
    "hp_mult": 1.8, "damage_mult": 1.3, "hp_growth": 0.08,
    "prop": "prop_neon", "prop_interval": 11,
    "hazards": [
        {"kind": "sweep", "every_beats": 16, "from_minute": 1.0, "count": 1, "grow_minutes": 7, "width": 20, "warn_beats": 4, "damage": 16},
        {"kind": "sweep", "every_beats": 32, "offset_beats": 8, "from_minute": 10.0, "count": 2, "grow_minutes": 10, "axis": "h",
         "width": 20, "warn_beats": 4, "damage": 16}],
    "relics": [{"id": "antenna", "achievement": "secret_theremin", "pos": [1500, 0], "text": "An antenna hums when you come close."}],
    "waves": waves([
        ["clip_shard"], ["broken_record", "clip_shard"], ["buzz_wasp", "broken_record"], ["glitch", "clip_shard"],
        ["blown_speaker", "broken_record"], ["chewed_cassette", "buzz_wasp", "glitch"], ["static_cloud", "clip_shard", "broken_record"],
        ["blown_speaker", "glitch", "buzz_wasp"], ["boombox_brute", "clip_shard"], ["static_cloud", "broken_record", "blown_speaker"],
        ["boombox_brute", "glitch", "buzz_wasp"], ["blown_speaker", "chewed_cassette", "clip_shard"],
        ["static_cloud", "boombox_brute", "broken_record"], ["glitch", "blown_speaker", "buzz_wasp", "clip_shard"],
        ["boombox_brute", "static_cloud", "blown_speaker", "glitch"]]),
    "events": events(["clip_shard", "buzz_wasp"], ["broken_record", "blown_speaker", "boombox_brute"], ["clip_shard", "glitch"],
                     ["glitch", "static_cloud", "boombox_brute"], ["boombox_brute"], "dj_overdrive"),
}
STAGES["jazz"] = {
    "name": "The Blue Note", "genre": "Swing jazz", "track": "lofi_grove",
    "desc": "A long, narrow club. There is nowhere to go but left or right.",
    "floor": "res://assets/generated/floor_jazz.png", "floor_scale": 1.0, "floor_tint": "#ffffff", "icon": "obs_jazz",
    "bounds_y": 150, "wall_color": "#241a2e",
    "obstacles": {"density": 0.22, "radius": 13, "sprite": "obs_jazz"},
    "hp_mult": 2.3, "damage_mult": 1.45, "hp_growth": 0.085,
    "prop": "prop_jazz", "prop_interval": 10,
    "hazards": [
        {"kind": "field", "every_beats": 32, "from_minute": 1.0, "count": 1, "grow_minutes": 8, "radius": 75, "duration": 12,
         "slow": 0.65, "style": "smoke", "drift": 12},
        {"kind": "falling", "every_beats": 16, "offset_beats": 8, "from_minute": 6.0, "count": 2, "grow_minutes": 8, "radius": 36,
         "spread": 220, "warn_beats": 4, "damage": 18}],
    "relics": [],
    "waves": waves([
        ["tempo_imp"], ["tempo_imp", "spotlight_moth"], ["scale_snake", "tempo_imp"], ["crab_canon", "spotlight_moth"],
        ["shrieking_diva", "tempo_imp"], ["heckler", "scale_snake"], ["crab_canon", "shrieking_diva", "spotlight_moth"],
        ["web_spinner", "tempo_imp"], ["heckler", "crab_canon", "scale_snake"], ["shrieking_diva", "web_spinner", "spotlight_moth"],
        ["heckler", "tempo_imp", "crab_canon"], ["web_spinner", "scale_snake", "shrieking_diva"],
        ["heckler", "crab_canon", "spotlight_moth"], ["web_spinner", "shrieking_diva", "tempo_imp", "scale_snake"],
        ["heckler", "web_spinner", "crab_canon", "shrieking_diva"]], 0.85),
    "events": events(["tempo_imp", "spotlight_moth"], ["scale_snake", "crab_canon", "heckler"], ["tempo_imp", "scale_snake"],
                     ["crab_canon", "heckler", "web_spinner"], ["heckler", "web_spinner"], "maestro_scat"),
}
STAGES["volcano"] = {
    "name": "Mount Shredmore", "genre": "Metal", "track": "lofi_grove",
    "desc": "Double kick, molten rock. The ground itself solos here.",
    "floor": "res://assets/generated/floor_volcano.png", "floor_scale": 1.0, "floor_tint": "#ffffff", "icon": "obs_volcano",
    "obstacles": {"density": 0.3, "radius": 15, "sprite": "obs_volcano"},
    "hp_mult": 2.9, "damage_mult": 1.6, "hp_growth": 0.09,
    "prop": "prop_volcano", "prop_interval": 10,
    "hazards": [
        {"kind": "falling", "every_beats": 8, "from_minute": 0.5, "count": 2, "grow_minutes": 5, "radius": 36, "spread": 260,
         "warn_beats": 4, "damage": 20, "leave": {"radius": 34, "duration": 7, "damage": 6, "tick": 0.5, "style": "lava"}}],
    "relics": [],
    "waves": waves([
        ["tempo_imp", "clip_shard"], ["ember", "tempo_imp"], ["headbanger", "clip_shard"], ["buzz_wasp", "ember"],
        ["off_key_troll", "tempo_imp"], ["riff_beetle", "clip_shard"], ["headbanger", "ember", "buzz_wasp"],
        ["blown_speaker", "off_key_troll"], ["riff_beetle", "tempo_imp", "ember"], ["headbanger", "blown_speaker", "clip_shard"],
        ["off_key_troll", "riff_beetle", "buzz_wasp"], ["ember", "headbanger", "tempo_imp"],
        ["riff_beetle", "blown_speaker", "off_key_troll"], ["headbanger", "ember", "buzz_wasp", "clip_shard"],
        ["riff_beetle", "headbanger", "off_key_troll", "ember"]]),
    "events": events(["clip_shard", "buzz_wasp", "tempo_imp"], ["ember", "off_key_troll", "riff_beetle"], ["tempo_imp", "clip_shard"],
                     ["headbanger", "riff_beetle", "off_key_troll"], ["headbanger", "riff_beetle"], "pyro_shredder"),
}
STAGES["castle"] = {
    "name": "Castle Crescendo", "genre": "Orchestral", "track": "lofi_grove",
    "desc": "The hidden hall where the score was written. Everything you have met, at full volume.",
    "floor": "res://assets/generated/floor_castle.png", "floor_scale": 1.0, "floor_tint": "#ffffff", "icon": "obs_castle",
    "obstacles": {"density": 0.32, "radius": 15, "sprite": "obs_castle"},
    "hp_mult": 3.8, "damage_mult": 1.9, "hp_growth": 0.1,
    "prop": "prop_castle", "prop_interval": 10,
    "hazards": [
        {"kind": "falling", "every_beats": 8, "from_minute": 0.5, "count": 3, "grow_minutes": 5, "radius": 38, "spread": 280,
         "warn_beats": 4, "damage": 22},
        {"kind": "sweep", "every_beats": 16, "offset_beats": 4, "from_minute": 5.0, "count": 1, "grow_minutes": 8, "width": 22,
         "warn_beats": 4, "damage": 22}],
    "relics": [],
    "waves": waves([
        ["choir_shade", "tempo_imp"], ["mute_knight", "clip_shard"], ["gargoyle", "requiem_ghost"], ["dissonant_cultist", "heckler"],
        ["silence_specter", "feedback_wraith", "choir_shade"], ["riff_beetle", "tempo_imp"], ["shrieking_diva", "gargoyle", "glitch"],
        ["headbanger", "mute_knight"], ["static_cloud", "boombox_brute", "choir_shade"], ["ember", "blown_speaker", "silence_specter"],
        ["riff_beetle", "gargoyle", "dissonant_cultist"], ["heckler", "headbanger", "feedback_wraith"],
        ["mute_knight", "boombox_brute", "shrieking_diva"], ["riff_beetle", "static_cloud", "gargoyle", "tempo_imp"],
        ["mute_knight", "riff_beetle", "headbanger", "silence_specter"]], 1.1),
    "events": events(["choir_shade", "tempo_imp", "clip_shard"], ["mute_knight", "riff_beetle", "gargoyle"], ["choir_shade", "tempo_imp"],
                     ["mute_knight", "headbanger", "boombox_brute", "riff_beetle"], ["mute_knight", "headbanger"], "grand_conductor"),
}


def dump_flat(path, table):
    """One entry per line; nested 'phases' and lists stay on the entry's line."""
    lines = []
    for key, val in table.items():
        lines.append("  %s: %s" % (json.dumps(key), json.dumps(val, ensure_ascii=False)))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("{\n" + ",\n".join(lines) + "\n}\n")


def dump_stages(path, table):
    chunks = []
    for key, st in table.items():
        rows = []
        for k, v in st.items():
            if k in ("waves", "events", "hazards", "relics") and v:
                inner = ",\n".join("      " + json.dumps(x, ensure_ascii=False) for x in v)
                rows.append("    %s: [\n%s\n    ]" % (json.dumps(k), inner))
            else:
                rows.append("    %s: %s" % (json.dumps(k), json.dumps(v, ensure_ascii=False)))
        chunks.append("  %s: {\n%s\n  }" % (json.dumps(key), ",\n".join(rows)))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("{\n" + ",\n".join(chunks) + "\n}\n")


if __name__ == "__main__":
    dump_flat(os.path.join(DATA, "enemies.json"), ENEMIES)
    dump_stages(os.path.join(DATA, "stages.json"), STAGES)
    print("%d enemies, %d stages" % (len(ENEMIES), len(STAGES)))
