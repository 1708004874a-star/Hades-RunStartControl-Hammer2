# RunStartControl — 固定第二把狄德勒斯之锤 完整指南

# RunStartControl — Forced Second Daedalus Hammer Complete Guide

---

> **中文** | [English](#english-version) — 本文档为中英双语对照。Each section is presented in Chinese followed by English.

---

## 中文版

### 目录

1. [功能概述](#1-功能概述)
2. [前置条件](#2-前置条件)
3. [核心设计思路](#3-核心设计思路)
4. [冲突处理机制](#4-冲突处理机制)
5. [准备工作](#5-准备工作)
6. [逐文件修改步骤](#6-逐文件修改步骤)
7. [运行 modimporter](#7-运行-modimporter)
8. [验证测试](#8-验证测试)
9. [常见问题](#9-常见问题)
10. [进阶说明](#10-进阶说明)

---

### 1. 功能概述

RunStartControl 原本支持在赛前面板为每个武器形态固定**第一把**狄德勒斯之锤。本修改在其基础上新增第二把锤子的固定功能：

- 在模组配置面板增加新页面「第二把锤子设置」
- 每个武器形态可独立选择第二把锤子，默认「原版随机(不固定)」
- 拿到第一把锤子后，第二把锤子房间出现**你指定的锤子 + 2 个随机选项**
- 支持 Reroll（重掷保留固定项，另外两项重新随机）
- 自动处理两把锤子之间的冲突

### 2. 前置条件

| 条件 | 说明 |
|---|---|
| Hades（Steam 版） | 已安装、可正常运行 |
| RunStartControl mod | 已通过 modimporter 安装并能正常工作 |
| ModConfigMenu | 必须使用 `configmenu` 模式 |
| modimporter | `modimporter.exe` 或 `modimporter.py` |

Windows 版 Hades 的 `Content` 目录典型路径：
```
D:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
C:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
```

### 3. 核心设计思路

#### 3.1 数据流

```
赛前面板选锤 → AspectSettings[aspect].Hammer2 存储
       ↓
新跑开始 (EquipWeaponUpgrade) → SetStartingRewards(..., hammer2Reward)
       ↓
StartingData.Hammer2 设置为目标 trait
       ↓
游戏内刷出 WeaponUpgrade 房间 → SetTraitsOnLoot 被调用
       ↓
第一把？ → 强制固定第一把（原逻辑）
第二把？ → 先原版三选一，再 InjectForcedHammer 替换第一个槽位
       ↓
拿锤子 (AddTraitToHero) → 清空 Hammer（第一把）/ Hammer2（第二把）
```

#### 3.2 第一把 vs 第二把的区分

通过 `RunStartControl.StartingData.Hammer.Trait` 是否为空来判断：

- 第一把锤子房间：`Hammer.Trait` 非空 → 强制固定 → 拿后清空 `Hammer`
- 第二把锤子房间：`Hammer.Trait` 已空，`Hammer2.Trait` 非空 → 走注入逻辑 → 拿后清空 `Hammer2`

#### 3.3 哨兵值

哨兵值 `"原版随机(不固定)"` 是不存在于 `TraitData` 中的字符串。选择它时 `TraitData["原版随机(不固定)"]` 返回 `nil`，所有注入逻辑自动跳过，第二把完全按原版随机。

#### 3.4 为什么第二把不设 BlockReroll？

第一把只有一个选项、reroll 无意义。第二把保留 3 个选项（1 固定 + 2 随机），不设 `BlockReroll`，玩家可 reroll 重掷随机部分，固定项始终保留。

### 4. 冲突处理机制

#### 冲突类型 1：两把选了相同的锤子

`IsHammerCompatibleWithFirst` 检查 `candidate == firstHammer`，相同返回 `false`。菜单层面该锤子从第二把列表中消失。若先设第二把再改第一把导致冲突，自动回退哨兵值。

#### 冲突类型 2：互斥锤子（RequiredFalseTraits）

双向检查 `RequiredFalseTraits`：
```lua
-- candidate 排斥 firstHammer？
Contains(candidateData.RequiredFalseTraits, firstHammer)
-- firstHammer 排斥 candidate？
Contains(firstData.RequiredFalseTraits, candidate)
```
任一方向成立即判定不兼容，与原版 `IsGameStateEligible` 逻辑一致。

#### 冲突类型 3：运行时意外冲突

`InjectForcedHammer` 注入前做三重检查：
1. `forcedTrait` 是否为有效 trait？
2. 英雄是否已拥有此 trait？
3. 游戏当前状态是否允许此 trait？

任何一步失败则静默返回，保留原版随机三选项。

#### 冲突处理总结

| 场景 | 表现 |
|---|---|
| 两把选了同一锤子 | 第二把菜单中该锤消失，自动回退哨兵值 |
| 两把存在互斥关系 | 同上 |
| 改第一把后第二把变无效 | 自动回退哨兵值 |
| 运行时注入失败 | 静默回退原版三随机 |
| 第二把保持「原版随机」 | 完全走原版逻辑 |

### 5. 准备工作

1. **备份**：复制整个 `RunStartControl` 文件夹为 `RunStartControl_backup`
2. **编码**：用 VS Code / Notepad++ 以 UTF-8（无 BOM）编码保存文件。不要用 Windows 记事本。如果不想处理中文编码，可把哨兵值和菜单名改成英文

### 6. 逐文件修改步骤

所有文件路径相对于 `...\Hades\Content\Mods\RunStartControl\`。修改后的完整文件见本仓库的 `RunStartControl/` 目录。

修改涉及 5 个文件：

| 文件 | 改动 |
|---|---|
| `ReferenceData.lua` | 新增哨兵常量、兼容性判定、候选列表函数 |
| `RunStartControl.lua` | 5处：StartingData 加 Hammer2、SetStartingRewards 加参数、ResetStartingRewards 加 InjectForcedHammer、SetTraitsOnLoot 加第二把分支、AddTraitToHero 分别清空 |
| `AspectSettings.lua` | 3处：SetAspectSettings 加 Hammer2、重置默认值加哨兵、调用补传 Hammer2 |
| `Hammer2ConfigMenu.lua` | 新建 — 第二把锤子配置菜单 |
| `modfile.txt` | 注册新 Import |

#### 6.1 ReferenceData.lua

在 `RunStartControl.BoonGods = {` 之前插入哨兵常量和两个新函数。完整代码见 `RunStartControl/ReferenceData.lua`。

**新增内容：**
- `RunStartControl.VanillaSentinel` — 哨兵常量，值为 `"原版随机(不固定)"`
- `RunStartControl.IsHammerCompatibleWithFirst(candidate, firstHammer)` — 判断两个锤子是否兼容
- `RunStartControl.GetSecondHammerOptions(aspect)` — 构建第二把候选列表（过滤冲突项）

#### 6.2 RunStartControl.lua（5 处改动）

完整代码见 `RunStartControl/RunStartControl.lua`。

**改动列表：**
1. `StartingData` 加入 `Hammer2` 字段
2. `SetStartingRewards` 新增第 8 个参数 `hammer2Reward` 与第二把写入逻辑
3. `ResetStartingRewards` 加入 `Hammer2` 并新增 `InjectForcedHammer` 函数
4. `SetTraitsOnLoot` 包裹新增第二把分支（先调 `baseFunc` 再注入）
5. `AddTraitToHero` 包裹改为先清第一把、再清第二把

#### 6.3 AspectSettings.lua（3 处改动）

完整代码见 `RunStartControl/AspectSettings.lua`。

**改动列表：**
1. `SetAspectSettings` 新增 `hammer2Reward` 参数和 `Hammer2` 存储字段
2. `ResetAspectSettings` 默认传 `VanillaSentinel` 作为第 8 个参数
3. `SetStartingRewards` 调用末尾补传 `aspectSettings.Hammer2`

#### 6.4 Hammer2ConfigMenu.lua（新建）

完整代码见 `RunStartControl/Hammer2ConfigMenu.lua`。

此文件复刻 `AspectConfigMenu` 的 UI 布局（6×4 网格），区别在于：
- 读写 `AspectSettings[aspect].Hammer2`
- 候选来自 `GetSecondHammerOptions`（已过滤冲突）
- 左右切换传第 8 个参数
- 菜单注册名为「第二把锤子设置」

#### 6.5 modfile.txt

在 `Import "AspectConfigMenu.lua"` 后加一行 `Import "Hammer2ConfigMenu.lua"`。

### 7. 运行 modimporter

```cmd
cd "D:\Program Files (x86)\Steam\steamapps\common\Hades\Content"
modimporter.exe
```

确认输出中出现 `Mods/RunStartControl/Hammer2ConfigMenu.lua`。

### 8. 验证测试

1. 进入冥府之家 → 模组配置面板 → 切到「第二把锤子设置」页
2. 确认默认值显示「原版随机(不固定)」
3. 选一把具体的第二锤 → 出击
4. 拿第一把锤子（按第一把面板设定固定）
5. 推进到深度 ≥ 26 的第二把锤子房间 → 确认「1 固定 + 2 随机」
6. 测试 Reroll → 固定项保留，另两项重掷
7. 第二把留「原版随机」→ 完全原版三随机
8. 测试冲突：设第二把后改第一把为同一锤子 → 第二把自动回退哨兵值

### 9. 常见问题

| 问题 | 解决方案 |
|---|---|
| 新面板页不出现 | 检查 modfile.txt、重跑 modimporter、确认 `config.Menu = "configmenu"` |
| 第二把没被固定 | 确认已先拿第一把；确认两把不冲突 |
| 游戏崩溃/Lua 错误 | 检查编码 UTF-8、检查括号逗号、查看 modimporter.log.txt |
| 手柄不能用摇杆选 | 重启游戏（ModConfigMenu 已知问题） |

### 10. 进阶说明

- 想给特定形态设默认第二把：在 `ResetAspectSettings` 中对不同 `aspectID` 传不同值
- 改哨兵值显示文字：改 `ReferenceData.lua` 中的 `VanillaSentinel` 常量即可
- 手动改 `HammerOptions`：`GetSecondHammerOptions` 动态读取，自动反映变化

---

## English Version

### Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Core Design](#3-core-design)
4. [Conflict Handling](#4-conflict-handling)
5. [Preparation](#5-preparation)
6. [Step-by-Step Modifications](#6-step-by-step-modifications)
7. [Run modimporter](#7-run-modimporter)
8. [Verification](#8-verification)
9. [Troubleshooting](#9-troubleshooting)
10. [Advanced Notes](#10-advanced-notes)

---

### 1. Overview

RunStartControl originally allows fixing the **first** Daedalus Hammer per weapon aspect from the pre-run panel. This modification adds the ability to also fix the **second** Daedalus Hammer:

- New config page "Second Hammer" (第二把锤子设置) in ModConfigMenu
- Each aspect independently configurable, defaulting to "VANILLA (random)"
- After picking up the first hammer, the second hammer room offers **your chosen hammer + 2 random options**
- Reroll support (fixed hammer stays, other two re-roll)
- Automatic conflict resolution between the two hammers

### 2. Prerequisites

| Requirement | Notes |
|---|---|
| Hades (Steam) | Installed and working |
| RunStartControl mod | Installed via modimporter, confirmed working |
| ModConfigMenu | `config.Menu` must be `"configmenu"` (not `"prerun"`) |
| modimporter | `modimporter.exe` or `modimporter.py` available |

Typical Content path on Windows:
```
D:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
```

### 3. Core Design

#### 3.1 Data Flow

```
Pre-run panel → AspectSettings[aspect].Hammer2 stored
       ↓
New run starts (EquipWeaponUpgrade) → SetStartingRewards(..., hammer2Reward)
       ↓
StartingData.Hammer2 set to target trait
       ↓
WeaponUpgrade room spawns → SetTraitsOnLoot called
       ↓
First hammer? → Force first hammer (original logic)
Second hammer? → Vanilla roll first, then InjectForcedHammer swaps one slot
       ↓
Pickup (AddTraitToHero) → Clear Hammer (first) / Hammer2 (second)
```

#### 3.2 Distinguishing First vs Second Hammer

The presence of `StartingData.Hammer.Trait` determines which hammer is being forced:

- **First hammer room**: `Hammer.Trait` is set → force the first hammer → `AddTraitToHero` clears `Hammer`
- **Second hammer room**: `Hammer.Trait` is already nil, `Hammer2.Trait` is set → injection path → `AddTraitToHero` clears `Hammer2`

#### 3.3 Sentinel Value

The sentinel `"原版随机(不固定)"` is a string that does **not** exist in `TraitData`. When selected:
- `TraitData[sentinel]` returns `nil`
- `SetStartingRewards` does not set `Hammer2`
- `InjectForcedHammer` exits early on nil check
- Result: second hammer behaves completely vanilla

#### 3.4 Why No BlockReroll for Second Hammer?

First hammer has only one option — reroll makes no sense, so `BlockReroll = true`. Second hammer retains 3 options (1 fixed + 2 random), so BlockReroll is NOT set, allowing the player to reroll the random options while the fixed one stays.

### 4. Conflict Handling

#### Conflict Type 1: Same Hammer Selected Twice

`IsHammerCompatibleWithFirst` checks `candidate == firstHammer` and returns `false` if equal. In the menu, the already-selected first hammer disappears from the second hammer picker. If the user changes the first hammer after setting the second, making the second selection invalid, it auto-resets to the sentinel.

#### Conflict Type 2: Mutually Exclusive Hammers (RequiredFalseTraits)

Bidirectional check against `RequiredFalseTraits`:
```lua
-- Does candidate forbid firstHammer?
Contains(candidateData.RequiredFalseTraits, firstHammer)
-- Does firstHammer forbid candidate?
Contains(firstData.RequiredFalseTraits, candidate)
```
Either direction returns incompatible, mirroring vanilla `IsGameStateEligible` behavior.

#### Conflict Type 3: Runtime Unexpected Conflicts

`InjectForcedHammer` performs three safety checks before injection:
1. Is `forcedTrait` a valid trait in `TraitData`?
2. Does the hero already have this trait?
3. Does the current game state allow this trait?

If any check fails, the function silently returns, leaving the vanilla 3-option roll intact.

#### Conflict Summary

| Scenario | Behavior |
|---|---|
| Both hammers set to the same trait | Trait disappears from second hammer picker, auto-resets to sentinel |
| Hammers are mutually exclusive | Same as above |
| Changing first hammer invalidates second | Auto-resets to sentinel |
| Runtime injection failure | Silent fallback to vanilla 3-option roll |
| Second hammer left at "VANILLA (random)" | Completely vanilla behavior |

### 5. Preparation

1. **Backup**: Copy entire `RunStartControl` folder as `RunStartControl_backup`
2. **Encoding**: Save all `.lua` files as **UTF-8 (without BOM)**. Use VS Code or Notepad++. Do NOT use Windows Notepad. If you want to avoid Chinese encoding issues, rename the sentinel to `"VANILLA (random)"` and the menu name to `"Second Hammer"`

### 6. Step-by-Step Modifications

All paths relative to `...\Hades\Content\Mods\RunStartControl\`. The complete modified files are available in the `RunStartControl/` directory of this repository.

**Files modified (5 total):**

| File | Changes |
|---|---|
| `ReferenceData.lua` | Add sentinel constant, compatibility check, candidate list builder |
| `RunStartControl.lua` | 5 edits: Hammer2 in StartingData, hammer2Reward param, InjectForcedHammer, second hammer branch in SetTraitsOnLoot, dual clear in AddTraitToHero |
| `AspectSettings.lua` | 3 edits: Hammer2 field, sentinel default, pass Hammer2 to SetStartingRewards |
| `Hammer2ConfigMenu.lua` | NEW — second hammer config menu page |
| `modfile.txt` | Register new import |

#### 6.1 ReferenceData.lua

Insert before `RunStartControl.BoonGods = {`:

- `RunStartControl.VanillaSentinel` — sentinel constant
- `RunStartControl.IsHammerCompatibleWithFirst(candidate, firstHammer)` — compatibility predicate
- `RunStartControl.GetSecondHammerOptions(aspect)` — builds filtered second-hammer option list

See `RunStartControl/ReferenceData.lua` for the complete file.

#### 6.2 RunStartControl.lua (5 edits)

See `RunStartControl/RunStartControl.lua` for the complete file.

1. `StartingData` — add `Hammer2` block
2. `SetStartingRewards` — add 8th param `hammer2Reward` and Hammer2 initialization logic
3. `ResetStartingRewards` — add `Hammer2` block + new `InjectForcedHammer` function
4. `SetTraitsOnLoot` wrapper — add second hammer branch (call `baseFunc` then inject)
5. `AddTraitToHero` wrapper — clear first hammer, then second hammer sequentially

#### 6.3 AspectSettings.lua (3 edits)

See `RunStartControl/AspectSettings.lua` for the complete file.

1. `SetAspectSettings` — add `hammer2Reward` param and `Hammer2` storage field
2. `ResetAspectSettings` — pass `VanillaSentinel` as 8th argument
3. `SetStartingRewards` call — append `aspectSettings.Hammer2`

#### 6.4 Hammer2ConfigMenu.lua (NEW)

See `RunStartControl/Hammer2ConfigMenu.lua` for the complete file.

This file mirrors `AspectConfigMenu`'s 6×4 grid layout, with the following differences:
- Reads/writes `AspectSettings[aspect].Hammer2`
- Options sourced from `GetSecondHammerOptions` (pre-filtered for conflicts)
- Left/right navigation passes the 8th parameter to `SetAspectSettings`
- Menu registered as "第二把锤子设置" (Second Hammer Settings)

#### 6.5 modfile.txt

Add `Import "Hammer2ConfigMenu.lua"` after the `AspectConfigMenu.lua` import line.

### 7. Run modimporter

```cmd
cd "D:\Program Files (x86)\Steam\steamapps\common\Hades\Content"
modimporter.exe
```

Confirm `Mods/RunStartControl/Hammer2ConfigMenu.lua` appears in the output.

### 8. Verification

1. Enter House of Hades → Mod Config panel → navigate to "Second Hammer" page
2. Confirm default value "VANILLA (random)" for all aspects
3. Select a specific second hammer for your aspect → start run
4. Pick up first hammer (forced per first hammer settings)
5. Progress to depth ≥ 26 for second hammer room → confirm "1 fixed + 2 random"
6. Test reroll → fixed stays, other two re-roll
7. Leave second hammer as "VANILLA (random)" → completely vanilla 3-option roll
8. Test conflict: set second hammer, then change first hammer to same trait → second auto-resets to sentinel

### 9. Troubleshooting

| Issue | Solution |
|---|---|
| New config page doesn't appear | Check modfile.txt, re-run modimporter, confirm `config.Menu = "configmenu"` |
| Second hammer not forced | Confirm first hammer was picked up first; confirm no conflict between hammers |
| Game crash / Lua error | Check UTF-8 encoding, check brackets/commas, inspect modimporter.log.txt |
| Controller can't navigate with stick | Restart game (known ModConfigMenu quirk) |

### 10. Advanced Notes

- To set per-aspect default second hammers: modify `ResetAspectSettings` to pass different values per `aspectID`
- To change sentinel display text: edit `VanillaSentinel` constant in `ReferenceData.lua`
- If you manually edit `HammerOptions`: `GetSecondHammerOptions` reads dynamically and reflects changes automatically
- Adding new weapon aspects: update `WeaponAspectData` and `HammerOptions` in `ReferenceData.lua`, both menus will pick up new entries automatically

---

## 仓库文件说明 / Repository Files

```
Hades-RunStartControl-Hammer2/
├── README.md                              # 本指南 / This guide
└── RunStartControl/                       # 完整 Mod 文件（可直接放入 Mods 目录）
    ├── RunStartControl.lua                # 核心逻辑 / Core logic
    ├── ReferenceData.lua                  # 数据定义 / Data definitions
    ├── AspectSettings.lua                 # 形态设置存储 / Aspect settings storage
    ├── AspectConfigMenu.lua               # 第一把锤子菜单 / First hammer menu
    ├── Hammer2ConfigMenu.lua              # 第二把锤子菜单（新增）/ Second hammer menu (NEW)
    ├── PrePactConfigMenu.lua              # 契约前菜单 / Pre-pact menu
    ├── modfile.txt                        # Mod 导入清单 / Import manifest
    └── README.md                          # 原作者说明 / Original author's notes
```

---

## 安装方法 / Installation

### 中文

1. 将本仓库 `RunStartControl/` 目录下的所有文件复制到：
   ```
   Hades\Content\Mods\RunStartControl\
   ```
   覆盖已有文件（建议先备份原文件夹）。

2. 运行 modimporter：
   ```cmd
   cd "D:\Program Files (x86)\Steam\steamapps\common\Hades\Content"
   modimporter.exe
   ```

3. 启动游戏，进入模组配置面板，找到「第二把锤子设置」页面。

### English

1. Copy all files from this repo's `RunStartControl/` directory to:
   ```
   Hades\Content\Mods\RunStartControl\
   ```
   Overwriting existing files (backup recommended first).

2. Run modimporter:
   ```cmd
   cd "D:\Program Files (x86)\Steam\steamapps\common\Hades\Content"
   modimporter.exe
   ```

3. Launch the game, open Mod Config panel, navigate to "Second Hammer" page.

---

## 致谢 / Credits

- 原始 RunStartControl mod 作者 / Original RunStartControl authors: **cgull** (cgull#4469), **Museus** (Museus#7777)
- 第二把锤子功能 / Second hammer feature: 基于 RunStartControl 扩展 / Extension based on RunStartControl
