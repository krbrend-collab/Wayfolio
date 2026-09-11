# Wayfolio Audio — Private Asset Ingestion Handoff

The app's semantic audio runtime lives in source control, but third-party source audio bytes do **not**.

The public repository intentionally ignores everything in this directory except this README. Keep the approved source/master audio in the private Wayfolio Google Drive audio library and copy/build it locally into the Xcode target according to source licenses.

## Required local folder structure

```text
Audio/
  01 Music Loops/
  02 Ambience Beds/
  03 Wayfolio System Cues/
  04 Gameplay & Encounter SFX/
  05 Character, Creature & Reveal Stingers/
  06 Story, Location & Transition Stingers/
```

The runtime already searches these bundle subdirectories as well as the top-level bundle.

## Private Drive destinations

- 01 Music Loops — Drive folder ID `13jXQrUH_s7yjy-zK_eQmkwNZUqMoV4Ba`
- 02 Ambience Beds — `1xgSBGX5-JJauTGdHWOrd0D9PhtZPTZgR`
- 03 Wayfolio System Cues — `13Xnh1bBWKk2mZbrpnfLMI3_S5s-aN3Tv`
- 04 Gameplay & Encounter SFX — `1aSGN0duhaBG15_zS6Im8KBq2ZM_3t47W`
- 05 Character, Creature & Reveal Stingers — `1Pgzxj2xj37B00scYxcPnJjeilrPQScq6`
- 06 Story, Location & Transition Stingers — `1O_cUVuByWM-SQmi7ZR0rs4uZDqGeMDf6`

## Approved source set

### Music

1. foggysunrise — Dark Whimsy / `Glass Gardens looped version.wav`
   - Source: https://foggysunrise.itch.io/dark-whimsy-music-pack
   - Target: `wayfolio_music_login_wayfolio_v01.wav`
   - Creator states the music is free to use with credit.

2. Francesco Pirrone — Free Epic Fantasy Music Pack
   - Source: https://francesco-pirrone.itch.io/free-epic-fantasy-music-pack-for-action-platformers-and-rpgs
   - Select loop versions when available:
     - Village Square → `wayfolio_music_safe_village_v01.m4a`
     - Village Market → `wayfolio_music_market_shop_v01.m4a`
     - Village Tavern → `wayfolio_music_tavern_inn_v01.m4a`
     - Woods → `wayfolio_music_wilderness_calm_v01.m4a`
     - Underwater → `wayfolio_music_water_v01.m4a`
     - Castle Dungeon → `wayfolio_music_ruins_dungeon_v01.m4a`
     - Intro Ominous → `wayfolio_music_hostile_v01.m4a`
     - Home → `wayfolio_music_safe_haven_v01.m4a`
     - Friends Reunited → `wayfolio_music_story_reflection_v01.m4a`
     - Fight → `wayfolio_music_combat_standard_v01.m4a`
     - Boss → `wayfolio_music_combat_boss_v01.m4a`

3. kmontesdev — Fantasy Game Music Tracks (CC0)
   - Source: https://kmontesdev.itch.io/7-fantasy-music-tracks
   - `Faerie Shrine.mp3` → `wayfolio_music_sacred_v01.m4a`
   - Source page explicitly marks the seven tracks CC0/public-domain usable/remixable.

### Ambience

4. Nox Sound Design — Essentials Series
   - Source: https://nox-sound-design.itch.io/essentials-series-sfx-nox-sound
   - Approved ingredients: Forest Birds, Night Ambience, Rain Calm, Stream, Cave Dark, Cave Drips, Campfire, Wind Forest/Calm.
   - Used for village morning/evening layers, forest day/night, rain, stream, cave, shrine/garden, and campfire/night.

5. TheAmbientFort — RPG Makers Kit 1
   - Source: https://theambientfort.itch.io/rpgmakerskit1
   - `Ambience Day (Gj).wav` contributes to `wayfolio_ambience_village_morning_v01.m4a`.
   - Also supplies UI Open/Close below.

6. Gregor Quendel — Free City & Nature Sounds
   - Source: https://gregor-quendel.itch.io/free-general-ambience-sounds
   - Nonverbal crowd ambience → `wayfolio_ambience_market_crowd_v01.m4a` and low village-evening crowd layer.

7. Andorios — RPG Medieval Lively Music
   - Source: https://andorios.itch.io/rpg-medieval-animated-music
   - `Crowded_Tavern_Looped` → `wayfolio_ambience_tavern_room_v01.m4a`.

### UI / gameplay / stingers

8. TheAmbientFort — RPG Makers Kit 1
   - `UI Open.wav` → `wayfolio_ui_open_v01.wav`
   - `UI Close.wav` → `wayfolio_ui_close_v01.wav`

9. Leohpaz — RPG Essentials SFX Free
   - Source: https://leohpaz.itch.io/rpg-essentials-sfx-free
   - Hover → `wayfolio_ui_select_v01.wav`
   - Confirm → `wayfolio_ui_confirm_v01.wav`
   - Decline → `wayfolio_gameplay_check_failure_v01.wav`
   - Encounter → `wayfolio_gameplay_initiative_start_v01.wav`
   - Impact → `wayfolio_gameplay_damage_v01.wav`
   - Attack Buff → `wayfolio_gameplay_status_positive_v01.wav`
   - Debuff → `wayfolio_gameplay_status_negative_v01.wav`
   - Water + Confirm layered → `wayfolio_gameplay_crafting_complete_v01.wav`
   - **License handling:** creator explicitly allows use in projects but says not to sell or redistribute the asset pack. Do not commit the raw pack/files to this public repository.

10. Mixkit — Crystal Chime
    - Source: https://mixkit.co/free-sound-effects/chimes/
    - Crystal chime → `wayfolio_ui_login_crystal_chime_v01.wav`
    - Retain a copy/link of the applicable Mixkit license with the source record.

11. DHSFX — Fantasy Stinger Sound Effects
    - Source: https://dhsfx.itch.io/fantasy-stinger-sound-effects
    - Creator requests credit and a reference to the creator's SoundCloud profile.
    - Exact selected WAVs:
      - Bright swell → projection appear / map reveal / majestic reveal
      - Descending Breeze 1 → projection dismiss
      - Bright Arpeggio 3 → new record
      - Bright Arpeggio 1 → record updated / check success
      - Bright Arpeggio 6 → quest update
      - Bright Arpeggio 4 → item received
      - Bright pulsing 1 → connection established
      - Dissonant low arpeggio → warning
      - Reversed tone 1 → visual generation start
      - Bright pulsing 2 → visual generation loop
      - Gentle harmony 2 → visual generation complete
      - Low strings pluck 1 → turn change
      - Bright Arpeggio 7 → discovery / landmark discovery
      - Gentle harmony 7 → objective complete / revelation
      - Gentle harmony 1 → shared choice appears
      - High strings pluck arpeggio → story discovery
      - Gentle harmony 3 → friendly NPC reveal
      - Reverb tone → mysterious NPC reveal
      - Kalimba tune → cute creature reveal
      - Santur Arpeggio 1 → curious/whimsical reveal
      - High reverb drone → uncanny reveal
      - Dissonant mid arpeggio → standard threat reveal
      - Hammering tone → boss reveal
      - Bright arpeggio 2 → location arrival
      - Descending Breeze 2 → location departure
      - Reversed tone 2 → scene transition
      - Unsettling drone 1 → suspense rise
      - Unsettling drone 3 → danger escalation
      - Gentle harmony 5 → resolution
      - Gentle harmony 4 → rest/camp
      - Bright Arpeggio 5 → quest phase change

12. ThousandthPrime — Dice SFX Assets (CC0)
    - Source: https://jamiec7919.itch.io/dice-sfx-assets
    - Audition pack and choose the best compact die roll → `wayfolio_gameplay_dice_roll_v01.wav`.
    - This selection remains intentionally unresolved until listening/QA.

13. lentikula — Healing Spell Impacts (CC0)
    - Source: https://lentikula.itch.io/healing-spell-impacts
    - Audition 15 impacts and choose the warmest suitable option → `wayfolio_gameplay_healing_v01.wav`.
    - This selection remains intentionally unresolved until listening/QA.

## Required composite ambience masters

The following targets are not simple renames and must be rendered as approved masters:

- `wayfolio_ambience_village_morning_v01.m4a` = TheAmbientFort `Ambience Day (Gj).wav` + restrained Nox Forest Birds layer.
- `wayfolio_ambience_village_evening_v01.m4a` = Nox Night Ambience + low Gregor Quendel nonverbal crowd bed.
- Other Nox ambience targets may use selected source bed(s) as appropriate but must be loop-checked and normalized consistently.
- `wayfolio_gameplay_crafting_complete_v01.wav` = Leohpaz Water + Confirm layered as the approved crafting/alchemy completion cue.

## Processing / QA gate

For every canonical target:

1. Acquire source bytes from the approved source page.
2. Preserve source title, creator, source URL, license/credit requirement, and original filename in the private source/license record.
3. Do not overwrite source originals; create canonical Wayfolio masters separately.
4. Render/transcode to the manifest target filename and format.
5. Remove accidental leading/trailing dead air only when it improves trigger timing without changing the intended sound.
6. Verify loops are click-free and do not contain unintended gaps.
7. Check peak/loudness consistency by category; do not normalize all categories to identical perceived loudness.
8. Verify transient duration and trigger timing.
9. Store the canonical master in its correct private Drive destination.
10. Add the local canonical master to the corresponding Xcode Audio subdirectory/resource target without committing the raw audio bytes to public GitHub.
11. Test semantic trigger → correct file → correct device → correct ducking/replacement behavior.
12. Promote the manifest entry to IMPLEMENTATION READY only after audible QA passes.

## Current hard boundary from ChatGPT mobile

The source pages are confirmed and the acquisition/processing rules above are ready, but many itch.io downloads require the interactive `No thanks, just take me to the downloads` flow. This chat does not have a safe file-byte path from those third-party download flows into the private Drive/Xcode project. Source-byte acquisition, DAW/ffmpeg rendering where needed, Xcode resource inclusion, simulator/device playback, and host-runtime wiring therefore remain Codex/Mac tasks.
