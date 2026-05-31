# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Hades game mod (Lua) that extends the existing **RunStartControl** mod to add the ability to pin a **second** Daedalus Hammer per weapon aspect. The mod integrates with ModConfigMenu and uses ModUtil to hook into game functions.

There is no build system, no linter, and no automated test suite. Everything is Lua files deployed directly into the Hades game's mod directory.

## Installation / Deployment

```bash
# Copy all files from RunStartControl/ into the game's mod directory, overwriting existing files:
#   ...\Hades\Content\Mods\RunStartControl\

# Then run modimporter from the Content directory:
cd "...\Hades\Content"
modimporter.exe
```

Confirm `Mods/RunStartControl/Hammer2ConfigMenu.lua` appears in modimporter output. Testing is done in-game by launching Hades and navigating to the Mod Config panel.

## Architecture

### Module Load Order (modfile.txt)

Load Priority 55: `RunStartControl.lua` (core hooks, `StartingData` struct)  
Load Priority 56: `ReferenceData.lua` (static data tables + helper functions), `AspectSettings.lua` (persistent settings + run-start hook)  
Load Priority 100: `AspectConfigMenu.lua`, `Hammer2ConfigMenu.lua`, `PrePactConfigMenu.lua` (UI menus)

### Runtime Data Flow

```
ModConfigMenu (pre-run) → AspectSettings[aspect].Hammer2 (written via SetAspectSettings)
       ↓
EquipWeaponUpgrade hook (run start) → SetStartingRewards → StartingData.Hammer2 set
       ↓
SetTraitsOnLoot hook (WeaponUpgrade room spawns):
  - Hammer.Trait set?   → force first hammer (1-option, BlockReroll=true)
  - Hammer.Trait nil, Hammer2.Trait set? → run baseFunc (3 vanilla opts), then InjectForcedHammer
  - Otherwise          → vanilla behavior
       ↓
AddTraitToHero hook (player picks up hammer):
  - Clears Hammer.Trait on first pickup, Hammer2.Trait on next
```

### Key Data Structures

**`RunStartControl.StartingData`** (in-memory, per-run):
```lua
{ StartingReward, Hammer = {Aspect, Trait}, Hammer2 = {Aspect, Trait}, Boon = {God, Rarity, Trait} }
```

**`GameState.RunStartControl.AspectSettings[aspectTrait]`** (persisted to save file):
```lua
{ Weapon, Aspect, Hammer, Hammer2, God, Trait, Rarity, StartingReward }
```

### File Responsibilities

| File | Role |
|---|---|
| `RunStartControl.lua` | Registers mod, defines `StartingData`, wraps `ChooseRoomReward`, `ChooseLoot`, `SetTraitsOnLoot`, `AddTraitToHero` |
| `ReferenceData.lua` | Static lookup tables (`WeaponAspectData`, `HammerOptions`, `DefaultHammerSettings`, `BoonGods`), `VanillaSentinel` constant, `IsHammerCompatibleWithFirst`, `GetSecondHammerOptions`, `CoreBoonReference`, `GetEquippedWeaponAspect` |
| `AspectSettings.lua` | `SetAspectSettings` / `ResetAspectSettings` (writes to `GameState`), wraps `EquipWeaponUpgrade` to call `SetStartingRewards` at run start |
| `AspectConfigMenu.lua` | First-hammer ModConfigMenu page ("Aspect Hammer Settings"), `HammerPickerLeft/Right`, defines `MenuXPositions`/`MenuYPositions` shared by both menus |
| `Hammer2ConfigMenu.lua` | Second-hammer ModConfigMenu page ("第二把锤子设置"), `Hammer2PickerLeft/Right`, reads options from `GetSecondHammerOptions` |
| `PrePactConfigMenu.lua` | Alternative menu when `config.Menu = "prerun"` |

### Sentinel Value

`RunStartControl.VanillaSentinel = "原版随机(不固定)"` is a deliberately non-existent trait name. When `GameState.RunStartControl.AspectSettings[aspect].Hammer2` equals the sentinel (or is nil), `TraitData[sentinel]` returns `nil`, all injection logic is skipped, and the second hammer behaves as vanilla. To avoid UTF-8 issues, rename it to `"VANILLA (random)"` in `ReferenceData.lua`.

### Conflict Handling Pattern

`IsHammerCompatibleWithFirst` checks bidirectional `RequiredFalseTraits` + identity. `GetSecondHammerOptions` pre-filters the picker list using it. `Hammer2PickerMove` detects if the stored selection was filtered out and resets to the sentinel. `InjectForcedHammer` has a final runtime guard (checks `HeroHasTrait` and `IsGameStateEligible`) and silently no-ops rather than crashing.

## Key Conventions

- All `.lua` files must be saved as **UTF-8 without BOM**. Do not use Windows Notepad.
- `ModUtil.WrapBaseFunction(name, func, RunStartControl)` is the pattern for all game-function hooks.
- `ModUtil.LoadOnce(fn, RunStartControl)` runs once on mod load (used for one-time initialization like `ResetAspectSettings` and menu registration).
- `ModUtil.Path.Context.Env("StartNewRun", fn, RunStartControl)` scopes a wrap to only apply during a new run start.
- The UI grid layout (6 columns × 4 rows) uses `MenuXPositions`/`MenuYPositions` defined in `AspectConfigMenu.lua` and reused by `Hammer2ConfigMenu.lua`. Each picker is a left-arrow component + text label + right-arrow component.
- When adding a new weapon aspect: update `WeaponAspectData` and `HammerOptions` in `ReferenceData.lua`. Both menus iterate `WeaponAspectData` dynamically and adapt automatically.
- After any file edit, re-run `modimporter.exe` before testing in game.
