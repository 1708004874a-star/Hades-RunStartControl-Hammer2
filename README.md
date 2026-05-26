# RunStartControl — 固定第二把狄德勒斯之锤

# RunStartControl — Forced Second Daedalus Hammer

---

## 目录 / Table of Contents

- [中文版](#中文版)
  - [功能概述](#功能概述)
  - [前置条件](#前置条件)
  - [安装](#安装)
  - [核心设计](#核心设计)
  - [冲突处理](#冲突处理)
  - [准备工作](#准备工作)
  - [修改步骤](#修改步骤)
  - [验证测试](#验证测试)
  - [常见问题](#常见问题)
  - [仓库文件](#仓库文件)
  - [进阶说明](#进阶说明)
  - [贡献者](#贡献者)
- [English Version](#english-version)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Core Design](#core-design)
  - [Conflict Handling](#conflict-handling)
  - [Preparation](#preparation)
  - [Step-by-Step Modifications](#step-by-step-modifications)
  - [Verification](#verification)
  - [Troubleshooting](#troubleshooting)
  - [Repository Files](#repository-files)
  - [Advanced Notes](#advanced-notes)
  - [Contributors](#contributors)

---

## 中文版

### 功能概述

RunStartControl 原本支持在赛前面板为每个武器形态固定**第一把**狄德勒斯之锤。本修改新增第二把锤子的固定功能。

- 模组配置面板新增「第二把锤子设置」页面
- 每个武器形态可独立选择，默认「原版随机(不固定)」
- 第二把锤子房间出现**你指定的锤子 + 2 个随机选项**
- 支持 Reroll，固定项保留、另外两项重掷
- 自动处理两把锤子之间的冲突

### 前置条件

| 条件 | 说明 |
|---|---|
| Hades（Steam 版） | 已安装并可正常运行 |
| Hades Speedrunning Modpack v1.3.1 | 本修改基于此版本开发与测试 |
| RunStartControl mod | 随 Speedrunning Modpack 附带，已通过 modimporter 安装 |
| ModConfigMenu | 随 Speedrunning Modpack 附带，`config.Menu` 必须为 `"configmenu"` |
| modimporter | `modimporter.exe` 或 `modimporter.py` 可用 |

Windows 版 Content 目录典型路径：
```
D:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
C:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
```

### 安装

**将 `RunStartControl/` 目录下的所有文件复制到 Hades 的 Mods 目录，覆盖已有文件（建议先备份原文件夹），然后运行 modimporter。**

```
目标路径：
  ...\Hades\Content\Mods\RunStartControl\

运行 modimporter：
  cd "...\Hades\Content"
  modimporter.exe
```

确认输出中出现 `Mods/RunStartControl/Hammer2ConfigMenu.lua` 即表示安装成功。启动游戏，进入模组配置面板即可找到「第二把锤子设置」页面。

### 核心设计

**数据流**

```
赛前面板选锤 → AspectSettings[aspect].Hammer2 存储
       ↓
新跑开始 (EquipWeaponUpgrade) → SetStartingRewards(..., hammer2Reward)
       ↓
StartingData.Hammer2 设为目标 trait
       ↓
游戏内 WeaponUpgrade 房间 → SetTraitsOnLoot 被调用
       ↓
第一把？ → 强制固定第一把（原逻辑）
第二把？ → 先原版三选一，再 InjectForcedHammer 替换首个槽位
       ↓
拿锤 (AddTraitToHero) → 依次清空 Hammer / Hammer2
```

**第一把 vs 第二把的区分**

通过 `RunStartControl.StartingData.Hammer.Trait` 是否为空来判断。第一把房间来时 `Hammer.Trait` 非空 → 强制固定第一把 → 拿后清空 `Hammer`；第二把房间来时 `Hammer.Trait` 已清空、`Hammer2.Trait` 非空 → 走注入逻辑 → 拿后清空 `Hammer2`。

**哨兵值**

`"原版随机(不固定)"` 是不存在于 `TraitData` 中的字符串。选择它时 `TraitData[sentinel]` 返回 `nil`，所有注入逻辑自动跳过，第二把完全按原版随机。如果你想避免中文编码问题，可改为 `"VANILLA (random)"`。

**为什么第二把不设 BlockReroll？**

第一把只有一个选项、reroll 无意义，设 `BlockReroll = true`。第二把保留 3 个选项（1 固定 + 2 随机），不设 BlockReroll，玩家可 reroll 重掷随机部分，固定项始终被 `InjectForcedHammer` 重新注入。

### 冲突处理

游戏中有三种可能的锤子冲突，本修改全部做了处理。

**类型 1：两把选了相同的锤子**

`IsHammerCompatibleWithFirst` 检查 `candidate == firstHammer`，相同返回 `false`。菜单层面该锤子从第二把列表中消失。若先设第二把再改第一把导致冲突，`Hammer2PickerMove` 检测到当前选择不在有效列表中时自动回退到哨兵值。

**类型 2：互斥锤子（RequiredFalseTraits）**

双向检查 `RequiredFalseTraits`，与原版 `IsGameStateEligible` 逻辑一致：

```lua
-- candidate 的排斥列表中是否包含 firstHammer？
Contains(candidateData.RequiredFalseTraits, firstHammer)
-- firstHammer 的排斥列表中是否包含 candidate？
Contains(firstData.RequiredFalseTraits, candidate)
```

**类型 3：运行时意外冲突**

`InjectForcedHammer` 在注入前做三重检查：forcedTrait 是否为有效 trait？英雄是否已拥有？游戏状态是否允许？任何一步失败则静默返回，保留原版随机三选项，不会崩溃。

**冲突总结**

| 场景 | 表现 |
|---|---|
| 两把选了同一锤子 | 第二把菜单中消失，自动回退哨兵值 |
| 互斥锤子 | 同上 |
| 改第一把后第二把变无效 | 自动回退哨兵值 |
| 运行时注入失败 | 静默回退原版三随机 |
| 第二把保持哨兵值 | 完全原版行为 |

### 准备工作

1. **备份**：复制整个 `RunStartControl` 文件夹为 `RunStartControl_backup`。

2. **编码**：用 VS Code 或 Notepad++ 以 **UTF-8（无 BOM）** 保存所有 `.lua` 文件。不要用 Windows 记事本。如果不想处理中文编码，把哨兵值改为 `"VANILLA (random)"`、菜单名改为 `"Second Hammer"` 即可。

### 修改步骤

所有路径相对于 `...\Hades\Content\Mods\RunStartControl\`。修改后的完整文件见本仓库 `RunStartControl/` 目录。

涉及 5 个文件：

| 文件 | 改动 |
|---|---|
| `ReferenceData.lua` | 新增哨兵常量、兼容性判定、候选列表函数 |
| `RunStartControl.lua` | 5处：Hammer2 字段、hammer2Reward 参数、InjectForcedHammer、第二把分支、分别清空 |
| `AspectSettings.lua` | 3处：Hammer2 字段、哨兵默认值、补传 Hammer2 |
| `Hammer2ConfigMenu.lua` | **新建** — 第二把配置菜单 |
| `modfile.txt` | 注册新 Import |

#### 1. ReferenceData.lua

在 `RunStartControl.BoonGods = {` **之前**插入以下新代码。**不要删除**原有的 `RunStartControl.BoonGods = {` 行。

```lua
-- Sentinel value for "don't force the second hammer, keep vanilla". Must not be a real trait name.
RunStartControl.VanillaSentinel = "原版随机(不固定)"

-- Two hammers are incompatible if either lists the other in its RequiredFalseTraits,
-- or if they are the same trait. Mirrors how vanilla IsGameStateEligible filters hammers.
function RunStartControl.IsHammerCompatibleWithFirst( candidate, firstHammer )
    if candidate == nil or firstHammer == nil then
        return true
    end
    if candidate == firstHammer then
        return false
    end
    local candidateData = TraitData[candidate]
    local firstData = TraitData[firstHammer]
    if candidateData and candidateData.RequiredFalseTraits and Contains( candidateData.RequiredFalseTraits, firstHammer ) then
        return false
    end
    if firstData and firstData.RequiredFalseTraits and Contains( firstData.RequiredFalseTraits, candidate ) then
        return false
    end
    return true
end

-- Build the second-hammer option list for an aspect: the sentinel (default = vanilla) followed by
-- every hammer valid for that aspect, minus the pinned first hammer and anything incompatible with it.
function RunStartControl.GetSecondHammerOptions( aspect )
    local options = { RunStartControl.VanillaSentinel }
    local baseHammers = RunStartControl.HammerOptions[aspect] or {}
    local firstHammer = nil
    if GameState.RunStartControl and GameState.RunStartControl.AspectSettings[aspect] then
        firstHammer = GameState.RunStartControl.AspectSettings[aspect].Hammer
    end
    for i, hammer in ipairs( baseHammers ) do
        if RunStartControl.IsHammerCompatibleWithFirst( hammer, firstHammer ) then
            table.insert( options, hammer )
        end
    end
    return options
end
```

#### 2. RunStartControl.lua（5 处改动）

完整代码见仓库 `RunStartControl/RunStartControl.lua`。

**改动 1 — StartingData 新增 Hammer2 字段：**

```lua
RunStartControl.StartingData = {
    StartingReward = nil, -- "Boon" or "WeaponUpgrade"
    Hammer = {
        Aspect = nil, -- actual apsect trait name
        Trait = nil, -- actual trait name
    },
    Hammer2 = {
        Aspect = nil, -- actual aspect trait name
        Trait = nil, -- actual trait name
    },
    Boon = {
        God = nil, -- god name, nothing else
        Rarity = nil,
        Trait = nil, -- actual trait name
    },
}
```

**改动 2 — SetStartingRewards 新增第 8 个参数 `hammer2Reward`：**

```lua
function RunStartControl.SetStartingRewards( weapon, aspectTrait, hammerReward, boonGod, boonTrait, boonRarity, forcedFirstReward, hammer2Reward )
    RunStartControl.StartingData.StartingReward = forcedFirstReward
    local hammerData = TraitData[hammerReward]
    if weapon and aspectTrait and hammerData and IsHammerValid(hammerData, weapon, aspectTrait) then
        RunStartControl.StartingData.Hammer = {
            Aspect = aspectTrait,
            Trait = hammerReward,
        }
    end
    -- second hammer: reset each run start, only set when a real, aspect-valid trait is chosen.
    RunStartControl.StartingData.Hammer2 = { Aspect = nil, Trait = nil }
    local hammer2Data = TraitData[hammer2Reward]
    if weapon and aspectTrait and hammer2Data and IsHammerValid(hammer2Data, weapon, aspectTrait) then
        RunStartControl.StartingData.Hammer2 = {
            Aspect = aspectTrait,
            Trait = hammer2Reward,
        }
    end
    if boonGod and boonTrait then
        RunStartControl.StartingData.Boon = {
            God = boonGod,
            Rarity = boonRarity,
            Trait = boonTrait
        }
    end
end
```

**改动 3 — ResetStartingRewards 加入 Hammer2 并新增 InjectForcedHammer：**

```lua
function RunStartControl.ResetStartingRewards()
    RunStartControl.StartingData = {
        StartingReward = nil,
        Hammer = { Aspect = nil, Trait = nil },
        Hammer2 = { Aspect = nil, Trait = nil },
        Boon = { God = nil, Rarity = nil, Trait = nil },
    }
end

-- Replace one of the rolled hammer options with the forced second-hammer trait.
-- Validates against real hero state so we never inject ineligible content.
function RunStartControl.InjectForcedHammer( lootData, forcedTrait )
    if forcedTrait == nil or TraitData[forcedTrait] == nil then return end
    if HeroHasTrait( forcedTrait ) or not IsGameStateEligible( CurrentRun, TraitData[forcedTrait] ) then return end
    if lootData.UpgradeOptions == nil or IsEmpty( lootData.UpgradeOptions ) then return end
    for i, option in ipairs( lootData.UpgradeOptions ) do
        if option.ItemName == forcedTrait then return end
    end
    lootData.UpgradeOptions[1] = {
        ItemName = forcedTrait,
        Type = "Trait",
        Rarity = "Common",
    }
end
```

**改动 4 — SetTraitsOnLoot 新增第二把分支：**

```lua
ModUtil.WrapBaseFunction("SetTraitsOnLoot", function(baseFunc, lootData, args)
    local isWeaponUpgrade = lootData.Name == "WeaponUpgrade"
    -- First hammer: forced while Hammer.Trait is set; AddTraitToHero clears it on pickup.
    local hammerToForce = isWeaponUpgrade and RunStartControl.StartingData.Hammer.Trait
    local hammer2ToForce = isWeaponUpgrade and not RunStartControl.StartingData.Hammer.Trait and RunStartControl.StartingData.Hammer2.Trait
    local boonToForce = lootData.GodLoot and RunStartControl.StartingData.Boon.Trait

    if RunStartControl.config.Enabled and hammerToForce and HeroHasTrait(RunStartControl.StartingData.Hammer.Aspect) then
        lootData.BlockReroll = true
        lootData.UpgradeOptions = {
            { ItemName = RunStartControl.StartingData.Hammer.Trait, Type = "Trait", Rarity = "Common" }
        }
    elseif RunStartControl.config.Enabled and hammer2ToForce and HeroHasTrait(RunStartControl.StartingData.Hammer2.Aspect) then
        -- Roll vanilla 3 options first, then swap one slot. No BlockReroll so rerolls re-force.
        baseFunc(lootData, args)
        RunStartControl.InjectForcedHammer(lootData, RunStartControl.StartingData.Hammer2.Trait)
    elseif boonToForce and lootData.Name == RunStartControl.StartingData.Boon.God .. "Upgrade" then
        lootData.BlockReroll = true
        lootData.UpgradeOptions = {
            { ItemName = RunStartControl.StartingData.Boon.Trait, Type = 'Trait', Rarity = RunStartControl.StartingData.Boon.Rarity or "Common" }
        }
    else
        baseFunc(lootData, args)
    end
end, RunStartControl)
```

**改动 5 — AddTraitToHero 分别清空第一/第二把：**

```lua
ModUtil.WrapBaseFunction("AddTraitToHero", function(baseFunc, trait)
    if ModUtil.SafeGet(trait, ModUtil.PathToIndexArray("TraitData.Frame")) == "Hammer" then
        -- Clear the first hammer on the first pickup; the second hammer on the next one.
        if RunStartControl.StartingData.Hammer.Trait then
            RunStartControl.StartingData.Hammer = { Aspect = nil, Trait = nil }
        else
            RunStartControl.StartingData.Hammer2 = { Aspect = nil, Trait = nil }
        end
    elseif trait.TraitData and trait.TraitData.God then
        RunStartControl.StartingData.Boon = { God = nil, Trait = nil, Rarity = nil }
    end
    baseFunc(trait)
end, RunStartControl)
```

#### 3. AspectSettings.lua（3 处改动）

完整代码见 `RunStartControl/AspectSettings.lua`。

**改动 1 — SetAspectSettings 新增 hammer2Reward 和 Hammer2 字段：**

```lua
function RunStartControl.SetAspectSettings( weapon, aspectTrait, hammerReward, boonGod, boonSlot, boonRarity, forcedFirstReward, hammer2Reward )
    if not GameState.RunStartControl then
        GameState.RunStartControl = { AspectSettings = {}}
    end
    local existingSettings = GameState.RunStartControl.AspectSettings[aspectTrait] or {}
    local boonTrait = RunStartControl.CoreBoonReference( boonGod, boonSlot, aspectTrait )
    GameState.RunStartControl.AspectSettings[aspectTrait] = {
        Weapon = weapon or existingSettings.Weapon,
        Aspect = aspectTrait or existingSettings.Aspect,
        Hammer = hammerReward or existingSettings.Hammer,
        Hammer2 = hammer2Reward or existingSettings.Hammer2,
        God = boonGod or existingSettings.God,
        Trait = boonTrait or existingSettings.Trait,
        Rarity = boonRarity or existingSettings.Rarity,
        StartingReward = forcedFirstReward or existingSettings.StartingReward
    }
end
```

**改动 2 — ResetAspectSettings 末尾加 VanillaSentinel：**

```lua
    RunStartControl.SetAspectSettings( weaponData.Name, aspectID, RunStartControl.DefaultHammerSettings[aspectID], nil, nil, nil, nil, RunStartControl.VanillaSentinel )
```

**改动 3 — SetStartingRewards 调用末尾补传 Hammer2：**

```lua
    RunStartControl.SetStartingRewards(
        aspectSettings.Weapon,
        aspectSettings.Aspect,
        aspectSettings.Hammer,
        aspectSettings.God,
        aspectSettings.Trait,
        aspectSettings.Rarity,
        aspectSettings.StartingReward,
        aspectSettings.Hammer2
    )
```

#### 4. Hammer2ConfigMenu.lua（新建）

完整代码见 `RunStartControl/Hammer2ConfigMenu.lua`。此文件复刻 `AspectConfigMenu` 的 UI 布局（6×4 网格），区别在于读写 `AspectSettings[aspect].Hammer2`、候选来自 `GetSecondHammerOptions`（已过滤冲突）、菜单注册名为「第二把锤子设置」。

#### 5. modfile.txt

在 `Import "AspectConfigMenu.lua"` 之后加一行：

```
Import "Hammer2ConfigMenu.lua"
```

### 验证测试

1. 冥府之家 → 模组配置面板 → 切到「第二把锤子设置」页，确认默认显示「原版随机(不固定)」
2. 选一把具体第二锤 → 出击
3. 拿第一把锤子（按第一把面板设定固定）
4. 推至深度 ≥ 26 → 第二把锤子房间应出现「1 固定 + 2 随机」
5. Reroll → 固定项保留，另两项重掷
6. 第二把留哨兵值 → 完全原版三随机
7. 测试冲突：设第二把后回第一把选同一锤子 → 第二把自动回退哨兵值

### 常见问题

| 问题 | 解决方案 |
|---|---|
| 新面板页不出现 | 检查 modfile.txt、重跑 modimporter、确认 `config.Menu = "configmenu"` |
| 第二把没被固定 | 确认已先拿第一把；确认两把不冲突 |
| 游戏崩溃 / Lua 错误 | 检查 UTF-8 编码、括号逗号完整性、查看 `modimporter.log.txt` |
| 手柄不能用摇杆 | 重启游戏（ModConfigMenu 已知问题） |

### 仓库文件

```
Hades-RunStartControl-Hammer2/
├── README.md                              # 本指南
└── RunStartControl/                       # 完整 Mod 文件
    ├── RunStartControl.lua                # 核心逻辑
    ├── ReferenceData.lua                  # 数据定义 + 冲突处理
    ├── AspectSettings.lua                 # 形态设置存储
    ├── AspectConfigMenu.lua               # 第一把锤子菜单
    ├── Hammer2ConfigMenu.lua              # 第二把锤子菜单（新增）
    ├── PrePactConfigMenu.lua              # 契约前菜单
    ├── modfile.txt                        # Mod 导入清单
    └── README.md                          # 原作者说明
```

### 进阶说明

- 想给特定形态设默认第二把：在 `ResetAspectSettings` 中对不同 `aspectID` 传不同值
- 改哨兵值文字：改 `ReferenceData.lua` 中的 `VanillaSentinel` 常量即可
- 手动改 `HammerOptions`：`GetSecondHammerOptions` 动态读取，自动反映变化
- 添加新武器形态：在 `ReferenceData.lua` 中更新 `WeaponAspectData` 和 `HammerOptions`，菜单自动适配

### 贡献者

| 贡献者 | 角色 | GitHub |
|---|---|---|
| **1708004874a-star** | 项目发起、测试验证 | [@1708004874a-star](https://github.com/1708004874a-star) |
| **Claude (Anthropic)** | 代码实现、文档编写 | — |

**原始致谢**

- RunStartControl 原作者：**cgull** (cgull#4469), **Museus** (Museus#7777)
- ModConfigMenu 框架：相关作者
- 第二把锤子功能基于 RunStartControl 扩展开发

---

## English Version

### Overview

RunStartControl originally allows fixing the **first** Daedalus Hammer per weapon aspect before a run. This modification adds the ability to also fix the **second** hammer.

- New "Second Hammer" (第二把锤子设置) config page in ModConfigMenu
- Each aspect configurable independently, defaults to "原版随机(不固定)" (vanilla random sentinel)
- Second hammer room offers **your chosen hammer + 2 random options**
- Reroll support: fixed hammer stays, other two re-roll
- Automatic conflict resolution between the two hammers

### Prerequisites

| Requirement | Notes |
|---|---|
| Hades (Steam) | Installed and working |
| Hades Speedrunning Modpack v1.3.1 | This mod is developed and tested on this version |
| RunStartControl mod | Bundled with Speedrunning Modpack, installed via modimporter |
| ModConfigMenu | Bundled with Speedrunning Modpack, `config.Menu` must be `"configmenu"` |
| modimporter | `modimporter.exe` or `modimporter.py` available |

Typical Content path on Windows:
```
D:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
C:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
```

### Installation

**Copy all files from the `RunStartControl/` directory to your Hades Mods directory, overwrite existing files (backup recommended first), then run modimporter.**

```
Target path:
  ...\Hades\Content\Mods\RunStartControl\

Run modimporter:
  cd "...\Hades\Content"
  modimporter.exe
```

Confirm `Mods/RunStartControl/Hammer2ConfigMenu.lua` appears in the modimporter output. Launch the game, open Mod Config panel, and navigate to the "第二把锤子设置" (Second Hammer Settings) page.

### Core Design

**Data Flow**

```
Pre-run panel → AspectSettings[aspect].Hammer2 stored
       ↓
New run starts (EquipWeaponUpgrade) → SetStartingRewards(..., hammer2Reward)
       ↓
StartingData.Hammer2 set to target trait
       ↓
WeaponUpgrade room spawned → SetTraitsOnLoot called
       ↓
First hammer? → Force first hammer (original logic)
Second hammer? → Roll vanilla 3 options first, then InjectForcedHammer swaps one slot
       ↓
Pickup (AddTraitToHero) → Clear Hammer / Hammer2 sequentially
```

**Distinguishing First vs Second Hammer**

The presence of `StartingData.Hammer.Trait` determines which hammer is being forced. When `Hammer.Trait` is set → force first hammer → clear `Hammer` on pickup. When `Hammer.Trait` is already nil but `Hammer2.Trait` is set → injection path → clear `Hammer2` on pickup.

**Sentinel Value**

`"原版随机(不固定)"` is a string that does **not** exist in `TraitData`. When selected, `TraitData[sentinel]` returns `nil`, all injection logic is skipped, and the second hammer behaves completely vanilla. Rename it to `"VANILLA (random)"` if you want to avoid Chinese encoding concerns.

**Why No BlockReroll for Second Hammer?**

First hammer has only one option — `BlockReroll = true` makes sense. Second hammer has 3 options (1 fixed + 2 random) — no BlockReroll, so the player can reroll the random two while `InjectForcedHammer` re-injects the fixed one each time.

### Conflict Handling

Three types of hammer conflicts are all handled.

**Type 1: Same Hammer Selected Twice**

`IsHammerCompatibleWithFirst` returns `false` when `candidate == firstHammer`. The duplicate hammer disappears from the second hammer picker. If the user changes the first hammer afterward, making the second selection invalid, `Hammer2PickerMove` detects the mismatch and resets to the sentinel.

**Type 2: Mutually Exclusive Hammers (RequiredFalseTraits)**

Bidirectional check against `RequiredFalseTraits`, mirroring vanilla `IsGameStateEligible`:

```lua
-- Does candidate forbid firstHammer?
Contains(candidateData.RequiredFalseTraits, firstHammer)
-- Does firstHammer forbid candidate?
Contains(firstData.RequiredFalseTraits, candidate)
```

**Type 3: Runtime Safety Net**

`InjectForcedHammer` performs three checks before injection: Is the trait a valid trait? Does the hero already have it? Does the game state allow it? If any fails, the function silently returns, leaving the vanilla 3-option roll intact — no crashes.

**Conflict Summary**

| Scenario | Behavior |
|---|---|
| Same hammer selected twice | Disappears from picker, resets to sentinel |
| Mutually exclusive hammers | Same as above |
| First hammer change invalidates second | Auto-resets to sentinel |
| Runtime injection failure | Silent fallback to vanilla 3-option roll |
| Sentinel left as-is | Completely vanilla behavior |

### Preparation

1. **Backup**: Copy the entire `RunStartControl` folder as `RunStartControl_backup`.

2. **Encoding**: Save all `.lua` files as **UTF-8 (without BOM)**. Use VS Code or Notepad++. Do NOT use Windows Notepad. To avoid Chinese encoding issues, rename the sentinel to `"VANILLA (random)"` and the menu name to `"Second Hammer"`.

### Step-by-Step Modifications

All paths relative to `...\Hades\Content\Mods\RunStartControl\`. Complete modified files are available in the `RunStartControl/` directory of this repository.

5 files modified:

| File | Changes |
|---|---|
| `ReferenceData.lua` | Add sentinel constant, compatibility check, candidate list builder |
| `RunStartControl.lua` | 5 edits: Hammer2 field, hammer2Reward param, InjectForcedHammer, second hammer branch, dual clear |
| `AspectSettings.lua` | 3 edits: Hammer2 field, sentinel default, pass Hammer2 to SetStartingRewards |
| `Hammer2ConfigMenu.lua` | **NEW** — second hammer config menu page |
| `modfile.txt` | Register new import |

#### 1. ReferenceData.lua

Insert the following code **before** `RunStartControl.BoonGods = {`. Do NOT delete the existing `RunStartControl.BoonGods = {` line.

```lua
-- Sentinel value for "don't force the second hammer, keep vanilla". Must not be a real trait name.
RunStartControl.VanillaSentinel = "原版随机(不固定)"

-- Two hammers are incompatible if either lists the other in its RequiredFalseTraits,
-- or if they are the same trait. Mirrors how vanilla IsGameStateEligible filters hammers.
function RunStartControl.IsHammerCompatibleWithFirst( candidate, firstHammer )
    if candidate == nil or firstHammer == nil then
        return true
    end
    if candidate == firstHammer then
        return false
    end
    local candidateData = TraitData[candidate]
    local firstData = TraitData[firstHammer]
    if candidateData and candidateData.RequiredFalseTraits and Contains( candidateData.RequiredFalseTraits, firstHammer ) then
        return false
    end
    if firstData and firstData.RequiredFalseTraits and Contains( firstData.RequiredFalseTraits, candidate ) then
        return false
    end
    return true
end

-- Build the second-hammer option list for an aspect: the sentinel (default = vanilla) followed by
-- every hammer valid for that aspect, minus the pinned first hammer and anything incompatible with it.
function RunStartControl.GetSecondHammerOptions( aspect )
    local options = { RunStartControl.VanillaSentinel }
    local baseHammers = RunStartControl.HammerOptions[aspect] or {}
    local firstHammer = nil
    if GameState.RunStartControl and GameState.RunStartControl.AspectSettings[aspect] then
        firstHammer = GameState.RunStartControl.AspectSettings[aspect].Hammer
    end
    for i, hammer in ipairs( baseHammers ) do
        if RunStartControl.IsHammerCompatibleWithFirst( hammer, firstHammer ) then
            table.insert( options, hammer )
        end
    end
    return options
end
```

#### 2. RunStartControl.lua (5 edits)

See `RunStartControl/RunStartControl.lua` for the complete file.

**Edit 1 — Add Hammer2 to StartingData:**

```lua
RunStartControl.StartingData = {
    StartingReward = nil, -- "Boon" or "WeaponUpgrade"
    Hammer = {
        Aspect = nil, -- actual apsect trait name
        Trait = nil, -- actual trait name
    },
    Hammer2 = {
        Aspect = nil, -- actual aspect trait name
        Trait = nil, -- actual trait name
    },
    Boon = {
        God = nil, -- god name, nothing else
        Rarity = nil,
        Trait = nil, -- actual trait name
    },
}
```

**Edit 2 — Add 8th parameter `hammer2Reward` to SetStartingRewards:**

```lua
function RunStartControl.SetStartingRewards( weapon, aspectTrait, hammerReward, boonGod, boonTrait, boonRarity, forcedFirstReward, hammer2Reward )
    RunStartControl.StartingData.StartingReward = forcedFirstReward
    local hammerData = TraitData[hammerReward]
    if weapon and aspectTrait and hammerData and IsHammerValid(hammerData, weapon, aspectTrait) then
        RunStartControl.StartingData.Hammer = {
            Aspect = aspectTrait,
            Trait = hammerReward,
        }
    end
    -- second hammer: reset each run start, only set when a real, aspect-valid trait is chosen.
    RunStartControl.StartingData.Hammer2 = { Aspect = nil, Trait = nil }
    local hammer2Data = TraitData[hammer2Reward]
    if weapon and aspectTrait and hammer2Data and IsHammerValid(hammer2Data, weapon, aspectTrait) then
        RunStartControl.StartingData.Hammer2 = {
            Aspect = aspectTrait,
            Trait = hammer2Reward,
        }
    end
    if boonGod and boonTrait then
        RunStartControl.StartingData.Boon = {
            God = boonGod,
            Rarity = boonRarity,
            Trait = boonTrait
        }
    end
end
```

**Edit 3 — Add Hammer2 to ResetStartingRewards and new InjectForcedHammer function:**

```lua
function RunStartControl.ResetStartingRewards()
    RunStartControl.StartingData = {
        StartingReward = nil,
        Hammer = { Aspect = nil, Trait = nil },
        Hammer2 = { Aspect = nil, Trait = nil },
        Boon = { God = nil, Rarity = nil, Trait = nil },
    }
end

-- Replace one of the rolled hammer options with the forced second-hammer trait.
-- Validates against real hero state so we never inject ineligible content.
function RunStartControl.InjectForcedHammer( lootData, forcedTrait )
    if forcedTrait == nil or TraitData[forcedTrait] == nil then return end
    if HeroHasTrait( forcedTrait ) or not IsGameStateEligible( CurrentRun, TraitData[forcedTrait] ) then return end
    if lootData.UpgradeOptions == nil or IsEmpty( lootData.UpgradeOptions ) then return end
    for i, option in ipairs( lootData.UpgradeOptions ) do
        if option.ItemName == forcedTrait then return end
    end
    lootData.UpgradeOptions[1] = {
        ItemName = forcedTrait,
        Type = "Trait",
        Rarity = "Common",
    }
end
```

**Edit 4 — Add second hammer branch in SetTraitsOnLoot:**

```lua
ModUtil.WrapBaseFunction("SetTraitsOnLoot", function(baseFunc, lootData, args)
    local isWeaponUpgrade = lootData.Name == "WeaponUpgrade"
    -- First hammer: forced while Hammer.Trait is set; AddTraitToHero clears it on pickup.
    local hammerToForce = isWeaponUpgrade and RunStartControl.StartingData.Hammer.Trait
    local hammer2ToForce = isWeaponUpgrade and not RunStartControl.StartingData.Hammer.Trait and RunStartControl.StartingData.Hammer2.Trait
    local boonToForce = lootData.GodLoot and RunStartControl.StartingData.Boon.Trait

    if RunStartControl.config.Enabled and hammerToForce and HeroHasTrait(RunStartControl.StartingData.Hammer.Aspect) then
        lootData.BlockReroll = true
        lootData.UpgradeOptions = {
            { ItemName = RunStartControl.StartingData.Hammer.Trait, Type = "Trait", Rarity = "Common" }
        }
    elseif RunStartControl.config.Enabled and hammer2ToForce and HeroHasTrait(RunStartControl.StartingData.Hammer2.Aspect) then
        -- Roll vanilla 3 options first, then swap one slot. No BlockReroll so rerolls re-force.
        baseFunc(lootData, args)
        RunStartControl.InjectForcedHammer(lootData, RunStartControl.StartingData.Hammer2.Trait)
    elseif boonToForce and lootData.Name == RunStartControl.StartingData.Boon.God .. "Upgrade" then
        lootData.BlockReroll = true
        lootData.UpgradeOptions = {
            { ItemName = RunStartControl.StartingData.Boon.Trait, Type = 'Trait', Rarity = RunStartControl.StartingData.Boon.Rarity or "Common" }
        }
    else
        baseFunc(lootData, args)
    end
end, RunStartControl)
```

**Edit 5 — Clear first/second hammer sequentially in AddTraitToHero:**

```lua
ModUtil.WrapBaseFunction("AddTraitToHero", function(baseFunc, trait)
    if ModUtil.SafeGet(trait, ModUtil.PathToIndexArray("TraitData.Frame")) == "Hammer" then
        -- Clear the first hammer on the first pickup; the second hammer on the next one.
        if RunStartControl.StartingData.Hammer.Trait then
            RunStartControl.StartingData.Hammer = { Aspect = nil, Trait = nil }
        else
            RunStartControl.StartingData.Hammer2 = { Aspect = nil, Trait = nil }
        end
    elseif trait.TraitData and trait.TraitData.God then
        RunStartControl.StartingData.Boon = { God = nil, Trait = nil, Rarity = nil }
    end
    baseFunc(trait)
end, RunStartControl)
```

#### 3. AspectSettings.lua (3 edits)

See `RunStartControl/AspectSettings.lua` for the complete file.

**Edit 1 — Add hammer2Reward parameter and Hammer2 field to SetAspectSettings:**

```lua
function RunStartControl.SetAspectSettings( weapon, aspectTrait, hammerReward, boonGod, boonSlot, boonRarity, forcedFirstReward, hammer2Reward )
    if not GameState.RunStartControl then
        GameState.RunStartControl = { AspectSettings = {}}
    end
    local existingSettings = GameState.RunStartControl.AspectSettings[aspectTrait] or {}
    local boonTrait = RunStartControl.CoreBoonReference( boonGod, boonSlot, aspectTrait )
    GameState.RunStartControl.AspectSettings[aspectTrait] = {
        Weapon = weapon or existingSettings.Weapon,
        Aspect = aspectTrait or existingSettings.Aspect,
        Hammer = hammerReward or existingSettings.Hammer,
        Hammer2 = hammer2Reward or existingSettings.Hammer2,
        God = boonGod or existingSettings.God,
        Trait = boonTrait or existingSettings.Trait,
        Rarity = boonRarity or existingSettings.Rarity,
        StartingReward = forcedFirstReward or existingSettings.StartingReward
    }
end
```

**Edit 2 — Pass VanillaSentinel in ResetAspectSettings:**

```lua
    RunStartControl.SetAspectSettings( weaponData.Name, aspectID, RunStartControl.DefaultHammerSettings[aspectID], nil, nil, nil, nil, RunStartControl.VanillaSentinel )
```

**Edit 3 — Append Hammer2 to SetStartingRewards call:**

```lua
    RunStartControl.SetStartingRewards(
        aspectSettings.Weapon,
        aspectSettings.Aspect,
        aspectSettings.Hammer,
        aspectSettings.God,
        aspectSettings.Trait,
        aspectSettings.Rarity,
        aspectSettings.StartingReward,
        aspectSettings.Hammer2
    )
```

#### 4. Hammer2ConfigMenu.lua (NEW)

See `RunStartControl/Hammer2ConfigMenu.lua` for the complete file. It mirrors `AspectConfigMenu`'s 6×4 grid layout, but reads/writes `AspectSettings[aspect].Hammer2`, sources options from `GetSecondHammerOptions` (pre-filtered for conflicts), and registers the menu as "第二把锤子设置".

#### 5. modfile.txt

Add this line after `Import "AspectConfigMenu.lua"`:

```
Import "Hammer2ConfigMenu.lua"
```

### Verification

1. Open Mod Config panel → navigate to "Second Hammer" page → confirm default "原版随机(不固定)"
2. Select a specific second hammer → start run
3. Pick up first hammer (forced per first hammer settings)
4. Reach depth ≥ 26 → second hammer room should show "1 fixed + 2 random"
5. Reroll → fixed stays, other two re-roll
6. Leave sentinel as default → completely vanilla 3-option roll
7. Test conflict: set second hammer, change first to same trait → second auto-resets to sentinel

### Troubleshooting

| Issue | Solution |
|---|---|
| New config page doesn't appear | Check modfile.txt, re-run modimporter, verify `config.Menu = "configmenu"` |
| Second hammer not forced | Confirm first hammer was picked up first; confirm no conflict between hammers |
| Game crash / Lua error | Check UTF-8 encoding, check brackets/commas, inspect `modimporter.log.txt` |
| Controller can't navigate with stick | Restart game (known ModConfigMenu quirk) |

### Repository Files

```
Hades-RunStartControl-Hammer2/
├── README.md                              # This guide
└── RunStartControl/                       # Complete mod files
    ├── RunStartControl.lua                # Core logic
    ├── ReferenceData.lua                  # Data + conflict handling
    ├── AspectSettings.lua                 # Aspect settings storage
    ├── AspectConfigMenu.lua               # First hammer menu
    ├── Hammer2ConfigMenu.lua              # Second hammer menu (NEW)
    ├── PrePactConfigMenu.lua              # Pre-pact menu
    ├── modfile.txt                        # Import manifest
    └── README.md                          # Original author's notes
```

### Advanced Notes

- Set per-aspect default second hammers: pass different `hammer2Reward` values per `aspectID` in `ResetAspectSettings`
- Change sentinel display text: edit the `VanillaSentinel` constant in `ReferenceData.lua`
- Manually edit `HammerOptions`: `GetSecondHammerOptions` reads dynamically — changes are picked up automatically
- Add new weapon aspects: update `WeaponAspectData` and `HammerOptions` in `ReferenceData.lua` — both menus adapt automatically

### Contributors

| Contributor | Role | GitHub |
|---|---|---|
| **1708004874a-star** | Project owner, testing & validation | [@1708004874a-star](https://github.com/1708004874a-star) |
| **Claude (Anthropic)** | Code implementation & documentation | — |

**Original Credits**

- Original RunStartControl authors: **cgull** (cgull#4469), **Museus** (Museus#7777)
- ModConfigMenu framework: respective authors
- Second hammer feature built as an extension of RunStartControl
