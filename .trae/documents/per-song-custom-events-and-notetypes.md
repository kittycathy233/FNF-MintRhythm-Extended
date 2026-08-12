# Per-Song Custom Events & Note Types

## Overview

This feature allows per-song customization of **custom events** and **custom note types** by placing files within a song's `data/<song_name>/` folder. Per-song items **take priority over** (override) global definitions and are visually **marked with a light-blue background** in all chart editor versions.

## Directory Structure

```
assets/shared/                         ← Global (lowest priority)
├── custom_events/
│   └── MyEvent.lua / .hx / .txt
├── custom_notetypes/
│   └── MyNoteType.txt
└── data/
    └── <song_name>/                   ← Song folder
        ├── custom_events/              ← Per-song custom events
        │   ├── MyEvent.lua             ← Event script (Lua)
        │   ├── MyEvent.hx              ← Event script (HScript)
        │   └── MyEvent.txt             ← Event description text
        └── custom_notetypes/          ← Per-song custom note types
            ├── MyNoteType.txt          ← Note type config
            ├── MyNoteType.lua          ← Note script (optional)
            └── MyNoteType.hx           ← Note script (optional)

mods/                                   ← Mod folders (same structure)
├── MyMod/
│   └── data/
│       └── <song_name>/
│           ├── custom_events/
│           └── custom_notetypes/
```

## Priority Order

1. **Per-song** (`data/<song_name>/custom_events/` or `custom_notetypes/`) — checked first
2. **Global** (`assets/shared/custom_events/` or `custom_notetypes/`) — fallback if not found per-song

If a file exists in both per-song and global with the **same name**, the **per-song version wins** and the global version is ignored.

## How It Works

### Per-Song Custom Events

**Gameplay (PlayState):**
- Before each song starts, `PlayState.generateSong()` scans all mod folders and shared assets for `data/<song_name>/custom_events/`
- Found `.lua` files are loaded via `FunkinLua`
- Found `.hx` files are loaded via `initHScript`
- Global event scripts with the **same name** are skipped (preventing duplicates)

**Chart Editor:**
- The event dropdown menu scans both per-song and global directories
- Per-song event descriptions (`.txt`) take priority over global ones
- Per-song events are **marked with a light-blue background** in the dropdown

### Per-Song Custom Note Types

**Gameplay (NoteTypesConfig):**
- `loadNoteTypeData(name)` first checks per-song `custom_notetypes/<name>.txt`
- Falls back to global `custom_notetypes/<name>.txt` if not found per-song

**Chart Editor:**
- The note type dropdown scans both directories
- Per-song note types are **marked with a light-blue background** in the dropdown

## Files Modified

### Core Engine
| File | Changes |
|------|---------|
| `source/states/PlayState.hx` | Added per-song `custom_events/` and `custom_notetypes/` scanning in `generateSong()`, loaded before global scripts |
| `source/backend/NoteTypesConfig.hx` | Added `currentSongName` static var; `loadNoteTypeData()` checks per-song path first, falls back to global |
| `source/states/editors/ChartingState.hx` | Updated `reloadNotesDropdowns()` to scan per-song folders; added `_getSongDataFolder()` helper; marked per-song items |

### Chart Editor UI Components
| File | Changes |
|------|---------|
| `source/backend/ui/PsychUIDropDownMenu.hx` | Added `markedIndices`, `markItem()`, `markItems()`; `PsychUIDropDownItem` gained `markedStyle` / `markedHoverStyle` (light-blue themes) |
| `source/states/editors/old/content/FlxUIDropDownMenuCustom.hx` | Added `markedIndices`, `markItem()`, `markItems()`, `clearMarks()`; mark backgrounds rendered as separate `FlxSprite` layer; updated `setData()`, `updateButtonPositions()`, `set_visible()` |
| `source/states/editors/vanilla104/content/ui/VUIDropDownMenu.hx` | Same changes as `PsychUIDropDownMenu.hx` |

### Chart Editor Integration
| File | Version | Changes |
|------|---------|---------|
| `source/states/editors/ChartingState.hx` | 1.0.4-kathy | `reloadNotesDropdowns()` scans per-song folders, marks per-song items |
| `source/states/editors/old/OldChartingState073.hx` | 0.7.3 | `addNoteUI()` and `addEventsUI()` scan per-song folders, mark items |
| `source/states/editors/old/OldChartingState063.hx` | 0.6.3 | Same as 0.7.3 |
| `source/states/editors/vanilla104/ChartingState.hx` | vanilla 1.0.4 | `reloadNotesDropdowns()` + `_getSongDataFolder()` helper, marks per-song items |

## Visual Indicator

Per-song items in dropdown menus are marked with a **light-blue background**:
- **Normal state:** Light blue (`0xFFB3E5FC`) with black text
- **Hover state:** Dark blue (`0xFF0288D1`) with white text

Global items retain their original styling (white background / blue hover).

## Usage Examples

### Example: Add a per-song custom event for "Tutorial"

```
mods/MyFirstMod/
└── data/
    └── Tutorial/
        └── custom_events/
            ├── FlashScreen.lua     ← Lua script that flashes the screen
            └── FlashScreen.txt     ← Description shown in chart editor
```

**`FlashScreen.txt` content:**
```
Flashes the screen white when triggered
```

**`FlashScreen.lua` content:**
```lua
function onCreate()
    -- Register the event handler
    makeLuaSprite('whiteFlash', nil, 0, 0)
    makeGraphic('whiteFlash', 100, 100, 'FFFFFF')
    addLuaSprite('whiteFlash', true)
    setObjectCamera('whiteFlash', 'other')
    setProperty('whiteFlash.alpha', 0)
end

function onEvent(name, value1, value2)
    if name == 'FlashScreen' then
        setProperty('whiteFlash.alpha', 1)
        doTweenAlpha('fadeFlash', 'whiteFlash', 0, 0.3)
    end
end
```

### Example: Add a per-song custom note type

```
mods/MyFirstMod/
└── data/
    └── Tutorial/
        └── custom_notetypes/
            └── Spikes.txt
```

**`Spikes.txt` content:**
```
TWEENS:0
HIT:250
DIFFICULTY:1.0
NOTE_TYPE:Spikes
SPAWN:0
BOP:0
```

## Notes

- The song name is derived from the chart JSON filename (e.g., `Tutorial.json` → `Tutorial`)
- Per-song scripts are loaded with `#if MODS_ALLOWED` conditional compilation
- Both Lua (`.lua`) and HScript (`.hx`) are supported for events and note types
- The `_getSongDataFolder()` helper resolves the song's data folder from `Song.chartPath`
- Marked indices are tracked separately from the list data, so they survive `setData()` calls

## Compatibility

- ✅ KathyEngine 1.0.4 (new chart editor)
- ✅ Old chart editor v0.6.3
- ✅ Old chart editor v0.7.3
- ✅ Vanilla Psych Engine 1.0.4 chart editor
- ✅ Mod system (`mods/<mod>/data/<song>/`)
- ✅ Shared assets (`assets/shared/data/<song>/`)