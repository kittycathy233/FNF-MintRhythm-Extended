# Port Legacy Psych Engine v0.6.3 HSV Arrow Color Rendering

## Context

The current KathyEngine renders arrow/note colors with the **RGBPalette** shader system (newer Psych): it REPLACES each note's R/G/B channels with explicit `FlxColor` values stored in `ClientPrefs.data.arrowRGB` (4 directions × \[r,g,b]), edited via a mouse/controller color-wheel UI in `NotesColorSubState`.

The old **Psych Engine v0.6.3** used a different **ColorSwap HSV shader**: it SHIFTS the hue/saturation/brightness of the note's *original texture* colors, stored as `ClientPrefs.arrowHSV` (4 directions × \[hue, sat, brt] integers, all default 0 = no shift), edited via a simple H/S/B number UI in `NotesSubState`.

The user wants the old HSV rendering ported as an opt-in mode, with the color-editing sub-state also switching to the old style when legacy is selected. **Default stays RGB** (preserves current behavior + existing `arrowRGB` customizations). Splashes are included in legacy mode. Toggle lives in Visuals Settings.

## Approach

Add a parallel `ColorSwap` (HSV) shader path that activates when `ClientPrefs.data.arrowColorMode == 'HSV'`. Both shader systems coexist; the active one is chosen by the setting. The HSV path mirrors the RGB system's **global-shared-shader** pattern so the legacy sub-state edits reflect live in gameplay (one `ColorSwap` per direction, shared by all notes/strums of that direction; per-sprite `shader` null/non-null toggles the "static = no shift" behavior, exactly like `RGBShaderReference.enabled`).

## Files to Create

### 1. `source/shaders/ColorSwap.hx` (new)

Port of old PE `ColorSwap.hx` + `ColorSwapShader`, adapted to `package shaders;`. Contains:

* `ColorSwap` class: `shader`, `hue`/`saturation`/`brightness` setters that write to `shader.uTime.value[0/1/2]`.

* `ColorSwapShader` class: the GLSL HSV-shift fragment shader (rgb2hsv → add hue/sat, multiply brightness → hsv2rgb), verbatim from old PE `e:\EXTRA\FNF\ENGINE\PE\FNF-PsychEngine-0.6.3\source\ColorSwap.hx`.

### 2. `source/options/NotesColorSubStateLegacy.hx` (new)

Port of old PE `NotesSubState.hx`, adapted to KathyEngine conventions:

* `package options;` extends `MusicBeatSubstate`.

* Reads/writes `ClientPrefs.data.arrowHSV` (4×3 Int array).

* Uses `Note.globalColorSwapShaders[i]` directly as each preview note's shader (so edits reflect live in gameplay too — mirrors how `NotesColorSubState` uses `Note.globalRgbShaders`).

* UI: 4 notes vertically, each with 3 Alphabet number columns (Hue / Saturation / Brightness). Up/Down selects note, Left/Right selects H/S/B, ACCEPT enters edit mode, Left/Right changes value, RESET resets. Range Hue −180..180, Sat/Brt −100..100.

* Mobile/KathyEngine conventions per project memory: `CoolUtil.getCachedGrid()` backdrop (persist+destroyOnNoUse=false), `addTouchPad('NONE','B_C')`, `controls.mobileC` for tip text, `LanguageBasic.getPhrase` for the reset tip.

* `destroy()` resets `Note.globalColorSwapShaders = []`.

## Files to Modify

### 3. `source/backend/ClientPrefs.hx`

Add two fields to `SaveVariables` (near `arrowRGB` \~line 47):

```hx
public var arrowColorMode:String = 'RGB'; // 'RGB' (new) or 'HSV' (legacy Psych v0.6.3)
public var arrowHSV:Array<Array<Int>> = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];
```

No special load logic needed — `Reflect.fields` loop in `loadPrefs` handles them; old saves without the field keep the defaults.

### 4. `source/objects/Note.hx`

* Import `shaders.ColorSwap`.

* Add fields: `public var colorSwap:ColorSwap;` and `public static var globalColorSwapShaders:Array<ColorSwap> = [];` (mirror `rgbShader`/`globalRgbShaders`).

* Add splash HSV fields (mirror old PE): `public var noteSplashHue:Float = 0; public var noteSplashSat:Float = 0; public var noteSplashBrt:Float = 0;`

* Add `public static function initializeGlobalColorSwapShader(noteData:Int):ColorSwap` — creates a shared `ColorSwap` per direction seeded from `ClientPrefs.data.arrowHSV[noteData]` (mirror `initializeGlobalRGBShader` at [Note.hx:354](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/objects/Note.hx#L354)).

* Add `public function defaultHSV()` — sets `colorSwap.hue/sat/brightness` from `ClientPrefs.data.arrowHSV[noteData]`, and copies into `noteSplashHue/Sat/Brt` (mirror `defaultRGB` at [Note.hx:199](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/objects/Note.hx#L199)).

* In constructor (\~[Note.hx:286-298](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/objects/Note.hx#L286)): branch on mode.

  * HSV: `colorSwap = Note.initializeGlobalColorSwapShader(noteData); shader = colorSwap.shader;` then `defaultHSV()`.

  * RGB: existing `rgbShader = new RGBShaderReference(...)` path (unchanged).

* In `set_noteType` ([Note.hx:218](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/objects/Note.hx#L218)): branch.

  * HSV: call `defaultHSV()`; for `'Hurt Note'` create a LOCAL `new ColorSwap()` (so it doesn't pollute the global), set hue/sat/brt = 0, `shader = localColorSwap.shader`, set `noteSplashHue/Sat/Brt = 0` (mirrors old PE).

  * RGB: existing logic.

* Keep `rgbShader`/`globalRgbShaders` creation in HSV mode too (cheap; NoteSplash/VisualsSettings previews may still reference `globalRgbShaders`) — only the sprite's `shader` differs.

### 5. `source/objects/StrumNote.hx`

* Import `shaders.ColorSwap`.

* Add `public var colorSwap:ColorSwap;`.

* In constructor ([StrumNote.hx:30-48](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/objects/StrumNote.hx#L30)): branch.

  * HSV: `colorSwap = Note.initializeGlobalColorSwapShader(leData); shader = colorSwap.shader;`

  * RGB: existing `rgbShader` path.

* In `playAnim` ([StrumNote.hx:186-194](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/objects/StrumNote.hx#L186)): branch the enable toggle.

  * HSV: `shader = (anim != 'static') ? colorSwap.shader : null;` (null = no shift = original texture, equivalent to old PE's hue=0/sat=0/brt=0 on static).

  * RGB: existing `if(useRGBShader) rgbShader.enabled = ...`.

### 6. `source/objects/NoteSplash.hx`

* Import `shaders.ColorSwap`.

* Add `public var colorSwap:ColorSwap;` field; init in constructor (`colorSwap = new ColorSwap();` — local per-splash, like old PE).

* In `spawnSplashNote` ([NoteSplash.hx:216, \~246-301](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/objects/NoteSplash.hx#L246)): branch early (after `noteData` is finalized, before the RGB `tempShader` block).

  * HSV: compute `nd = noteData % Note.colArray.length`; base HSV from `ClientPrefs.data.arrowHSV[nd]`; if `note != null` override with `note.noteSplashHue/Sat/Brt`; set `colorSwap.hue/sat/brightness`; `this.shader = colorSwap.shader;` then SKIP the RGB tempShader block (guard the RGB block with `else`).

  * RGB: existing logic unchanged.

* `PixelSplashShaderRef`/`rgbShader` stays as-is (used in RGB mode).

### 7. `source/options/OptionsState.hx`

Branch the `note_colors` entry (\~[OptionsState.hx:91](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/options/OptionsState.hx#L91)):

```hx
Language.get("note_colors") => () -> openSubState(
    ClientPrefs.data.arrowColorMode == 'HSV'
        ? new options.NotesColorSubStateLegacy()
        : new options.NotesColorSubState()),
```

### 8. `source/options/VisualsSettingsSubState.hx`

Add the toggle near the Note Skins block (\~line 52), before `noteSkin`:

```hx
var option:Option = new Option("Arrow Color Mode:",
    "RGB = new palette colors; HSV = legacy Psych v0.6.3 hue/sat/brightness shift",
    'arrowColorMode', STRING, ['RGB', 'HSV']);
addOption(option);
option.onChange = onChangeArrowColorMode;
```

`onChangeArrowColorMode` rebuilds the 4 preview strums (destroy + recreate `StrumNote`s with new mode) so the preview reflects the toggle; also clears+rebuilds `Note.globalRgbShaders`/`globalColorSwapShaders`. In `destroy()` (\~[line 396](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/options/VisualsSettingsSubState.hx#L396)) also reset `Note.globalColorSwapShaders = []` alongside the existing `globalRgbShaders = []`.

## Key Reuse / Patterns

* Global-shared-shader + per-sprite `shader` toggle pattern: mirrors `RGBShaderReference.enabled` ([RGBPalette.hx:108-112](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/shaders/RGBPalette.hx#L108)) and `StrumNote.playAnim` ([StrumNote.hx:193](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/objects/StrumNote.hx#L193)).

* Sub-state mobile conventions (grid cache, touchpad, language) from project memory + existing `NotesColorSubState.hx`.

* Old PE source of truth: `e:\EXTRA\FNF\ENGINE\PE\FNF-PsychEngine-0.6.3\source\{Note,StrumNote,ColorSwap,ClientPrefs}.hx` and `source\options\NotesSubState.hx`.

## Verification

1. Build: `lime build windows -D officialBuild` (must compile clean).
2. RGB mode (default): open Options → Note Colors → confirm existing color-wheel UI & behavior unchanged; play a song → notes/strums/splashes render with RGB colors as before.
3. Visuals Settings → set "Arrow Color Mode" = HSV.
4. Options → Note Colors → confirm the legacy H/S/B number UI appears; change Hue/Sat/Brt for a direction → confirm the preview note updates live; close and play a song → notes/strums/splashes of that direction reflect the HSV shift (e.g. Hue 180 on purple flips hue).
5. In gameplay, confirm strum `static` shows the unshifted texture (no tint) and `pressed`/`confirm` applies the HSV shift.
6. Hurt Note in HSV mode renders grayscale-ish (hue/sat/brt = 0) with the electric splash.
7. Toggle back to RGB → Note Colors sub-state reverts to color-wheel UI; gameplay reverts to RGB.
8. Mobile: open Note Colors (legacy) on a touch device → grid bg, TouchPad B/C buttons, RESET via button C work; no texture-dump issues.

