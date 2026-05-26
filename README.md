# RunStartControl — 固定第二把狄德勒斯之锤 / Forced Second Daedalus Hammer

---

## 安装 / Installation

**将 `RunStartControl/` 目录下的所有文件复制到 Hades 的 Mods 目录，覆盖已有文件（建议先备份原文件夹），然后运行 modimporter。**

Copy all files from `RunStartControl/` to your Hades Mods directory, overwrite existing files (backup recommended first), then run modimporter.

```
目标路径 / Target path:
  ...\Hades\Content\Mods\RunStartControl\

导入 / Import:
  cd "...\Hades\Content"
  modimporter.exe
```

确认输出中出现 `Mods/RunStartControl/Hammer2ConfigMenu.lua` 即表示安装成功。启动游戏，进入模组配置面板即可找到「第二把锤子设置」页面。

Confirm `Mods/RunStartControl/Hammer2ConfigMenu.lua` appears in the modimporter output. Launch the game, open Mod Config panel, navigate to the "第二把锤子设置" (Second Hammer Settings) page.

---

## 功能概述 / Overview

RunStartControl 原本支持在赛前面板为每个武器形态固定**第一把**狄德勒斯之锤。本修改新增第二把锤子的固定功能。

Originally, RunStartControl allows fixing the **first** Daedalus Hammer per weapon aspect before a run. This modification adds the ability to also fix the **second** hammer.

- 模组配置面板新增「第二把锤子设置」页面 / New "Second Hammer" config page in ModConfigMenu
- 每个武器形态可独立选择，默认「原版随机(不固定)」/ Each aspect configurable independently, defaults to "原版随机(不固定)" (vanilla random sentinel)
- 第二把锤子房间出现 **你指定的锤子 + 2 个随机选项** / Second hammer room offers **your chosen hammer + 2 random options**
- 支持 Reroll，固定项保留、另外两项重掷 / Reroll keeps the fixed hammer, re-rolls the other two
- 自动处理两把锤子之间的冲突 / Automatic conflict resolution between hammers

---

## 前置条件 / Prerequisites

| 条件 | 说明 |
|---|---|
| Hades（Steam 版） | 已安装并可正常运行 / Installed and working |
| RunStartControl mod | 已通过 modimporter 安装并能正常工作 / Installed via modimporter, confirmed working |
| ModConfigMenu | `config.Menu` 必须为 `"configmenu"`（非 `"prerun"`）/ Must use `"configmenu"` mode |
| modimporter | `modimporter.exe` 或 `modimporter.py` 可用 |

Windows 版 Content 目录典型路径 / Typical Content path:
```
D:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
C:\Program Files (x86)\Steam\steamapps\common\Hades\Content\
```

---

## 核心设计 / Core Design

### 数据流 / Data Flow

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

### 第一把 vs 第二把的区分 / First vs Second Hammer

通过 `RunStartControl.StartingData.Hammer.Trait` 是否为空来判断。第一把房间来时 `Hammer.Trait` 非空 → 强制固定第一把 → 拿后清空 `Hammer`；第二把房间来时 `Hammer.Trait` 已清空、`Hammer2.Trait` 非空 → 走注入逻辑 → 拿后清空 `Hammer2`。

The presence of `StartingData.Hammer.Trait` determines which hammer is being forced. When `Hammer.Trait` is set → force first hammer → clear `Hammer` on pickup. When `Hammer.Trait` is already nil but `Hammer2.Trait` is set → injection path → clear `Hammer2` on pickup.

### 哨兵值 / Sentinel Value

`"原版随机(不固定)"` 是不存在于 `TraitData` 中的字符串。选择它时 `TraitData[sentinel]` 返回 `nil`，所有注入逻辑自动跳过，第二把完全按原版随机。如果你想避免中文编码问题，可改为 `"VANILLA (random)"`。

`"原版随机(不固定)"` is a string that does not exist in `TraitData`. When selected, `TraitData[sentinel]` returns `nil`, all injection logic is skipped, and the second hammer behaves completely vanilla. Rename it to `"VANILLA (random)"` if you want to avoid Chinese encoding concerns.

### 为什么第二把不设 BlockReroll？ / Why No BlockReroll?

第一把只有一个选项、reroll 无意义，设 `BlockReroll = true`。第二把保留 3 个选项（1 固定 + 2 随机），不设 BlockReroll，玩家可 reroll 重掷随机部分，固定项始终被 `InjectForcedHammer` 重新注入。

First hammer has only one option — `BlockReroll = true` makes sense. Second hammer has 3 options (1 fixed + 2 random) — no BlockReroll, so the player can reroll the random two while `InjectForcedHammer` re-injects the fixed one each time.

---

## 冲突处理 / Conflict Handling

游戏中有三种可能的锤子冲突，本修改全部做了处理。There are three types of hammer conflicts, all handled.

### 类型 1：两把选了相同的锤子 / Same Hammer Twice

`IsHammerCompatibleWithFirst` 检查 `candidate == firstHammer`，相同返回 `false`。菜单层面该锤子从第二把列表中消失。若先设第二把再改第一把导致冲突，`Hammer2PickerMove` 检测到当前选择不在有效列表中时自动回退到哨兵值。

`IsHammerCompatibleWithFirst` returns `false` when `candidate == firstHammer`. The duplicate hammer disappears from the second hammer picker. If the user changes the first hammer afterward, making the second selection invalid, `Hammer2PickerMove` detects the mismatch and resets to the sentinel.

### 类型 2：互斥锤子 / RequiredFalseTraits

双向检查 `RequiredFalseTraits`，与原版 `IsGameStateEligible` 逻辑一致：

Bidirectional check against `RequiredFalseTraits`, mirroring vanilla `IsGameStateEligible`:

```lua
-- candidate 的排斥列表中是否包含 firstHammer？
Contains(candidateData.RequiredFalseTraits, firstHammer)
-- firstHammer 的排斥列表中是否包含 candidate？
Contains(firstData.RequiredFalseTraits, candidate)
```

### 类型 3：运行时意外 / Runtime Safety Net

`InjectForcedHammer` 在注入前做三重检查：forcedTrait 是否为有效 trait？英雄是否已拥有？游戏状态是否允许？任何一步失败则静默返回，保留原版随机三选项，不会崩溃。

`InjectForcedHammer` performs three checks before injection: Is the trait valid? Does the hero already have it? Does the game state allow it? If any fails, the function silently returns, leaving the vanilla 3-option roll intact.

### 冲突总结 / Summary

| 场景 / Scenario | 表现 / Behavior |
|---|---|
| 两把选了同一锤子 / Same hammer twice | 第二把菜单中消失，自动回退哨兵值 / Disappears from picker, resets to sentinel |
| 互斥锤子 / Mutually exclusive | 同上 / Same as above |
| 改第一把后第二把变无效 / First hammer change invalidates second | 自动回退哨兵值 / Auto-resets to sentinel |
| 运行时注入失败 / Runtime injection failure | 静默回退原版三随机 / Silent fallback to vanilla |
| 第二把保持哨兵值 / Sentinel left as-is | 完全原版行为 / Completely vanilla |

---

## 准备工作 / Preparation

1. **备份 / Backup**：复制整个 `RunStartControl` 文件夹为 `RunStartControl_backup`。Copy the entire `RunStartControl` folder as `RunStartControl_backup`.

2. **编码 / Encoding**：用 VS Code 或 Notepad++ 以 **UTF-8（无 BOM）** 保存所有 `.lua` 文件。不要用 Windows 记事本。如果不想处理中文编码，把哨兵值改为 `"VANILLA (random)"`、菜单名改为 `"Second Hammer"` 即可。

   Save all `.lua` files as **UTF-8 (without BOM)**. Use VS Code or Notepad++. Do NOT use Windows Notepad. To avoid Chinese encoding issues, rename the sentinel to `"VANILLA (random)"` and the menu name to `"Second Hammer"`.

---

## 修改步骤 / Step-by-Step Modifications

所有路径相对于 `...\Hades\Content\Mods\RunStartControl\`。修改后的完整文件见本仓库 `RunStartControl/` 目录。All paths relative to `...\Hades\Content\Mods\RunStartControl\`. Complete modified files are in the `RunStartControl/` directory of this repo.

涉及 5 个文件 / 5 files modified:

| 文件 / File | 改动 / Changes |
|---|---|
| `ReferenceData.lua` | 新增哨兵常量、兼容性判定、候选列表函数 / Add sentinel, compatibility check, candidate list |
| `RunStartControl.lua` | 5处：Hammer2 字段、hammer2Reward 参数、InjectForcedHammer、第二把分支、分别清空 / 5 edits covering Hammer2 data, injection, and dual clear |
| `AspectSettings.lua` | 3处：Hammer2 字段、哨兵默认值、补传 Hammer2 / 3 edits: Hammer2 field, sentinel default, pass Hammer2 |
| `Hammer2ConfigMenu.lua` | **新建 / NEW** — 第二把配置菜单 / Second hammer config menu |
| `modfile.txt` | 注册新 Import / Register new import |

### 6.1 ReferenceData.lua

在 `RunStartControl.BoonGods = {` **之前**插入以下新代码。Insert the following **before** `RunStartControl.BoonGods = {`:

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

**不要删除**原有的 `RunStartControl.BoonGods = {`，新代码插在它前面即可。Do NOT delete the existing `RunStartControl.BoonGods = {` line — new code goes above it.

### 6.2 RunStartControl.lua（5 处改动 / 5 edits）

完整代码见仓库 `RunStartControl/RunStartControl.lua`。See `RunStartControl/RunStartControl.lua` for the complete file.

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

### 6.3 AspectSettings.lua（3 处改动 / 3 edits）

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

### 6.4 Hammer2ConfigMenu.lua（新建 / NEW）

完整代码见 `RunStartControl/Hammer2ConfigMenu.lua`。此文件复刻 `AspectConfigMenu` 的 UI 布局（6×4 网格），区别在于读写 `AspectSettings[aspect].Hammer2`、候选来自 `GetSecondHammerOptions`（已过滤冲突）、菜单注册名为「第二把锤子设置」。

See `RunStartControl/Hammer2ConfigMenu.lua` for the complete file. It mirrors `AspectConfigMenu`'s 6×4 grid layout, but reads/writes `AspectSettings[aspect].Hammer2`, sources options from `GetSecondHammerOptions` (pre-filtered), and registers the menu as "第二把锤子设置".

### 6.5 modfile.txt

在 `Import "AspectConfigMenu.lua"` 之后加一行 / Add this line after `Import "AspectConfigMenu.lua"`:

```
Import "Hammer2ConfigMenu.lua"
```

---

## 验证测试 / Verification

1. 冥府之家 → 模组配置面板 → 切到「第二把锤子设置」页，确认默认显示「原版随机(不固定)」/ Open Mod Config panel, navigate to "Second Hammer" page, confirm "原版随机(不固定)" default
2. 选一把具体第二锤 → 出击 / Select a specific second hammer → start run
3. 拿第一把锤子（按第一把面板设定固定）/ Pick up first hammer (forced per first hammer settings)
4. 推至深度 ≥ 26 → 第二把锤子房间应出现「1 固定 + 2 随机」/ Reach depth ≥ 26 → second hammer room should show "1 fixed + 2 random"
5. Reroll → 固定项保留，另两项重掷 / Reroll → fixed stays, other two re-roll
6. 第二把留哨兵值 → 完全原版三随机 / Leave sentinel → completely vanilla 3-option roll
7. 测试冲突：设第二把后回第一把选同一锤子 → 第二把自动回退哨兵值 / Test conflict: set second hammer, change first to same trait → second auto-resets to sentinel

---

## 常见问题 / Troubleshooting

| 问题 / Issue | 解决方案 / Solution |
|---|---|
| 新面板页不出现 / New page absent | 检查 modfile.txt、重跑 modimporter、确认 `config.Menu = "configmenu"` / Check modfile.txt, re-run modimporter, verify `config.Menu = "configmenu"` |
| 第二把没被固定 / Second not forced | 确认已先拿第一把；确认两把不冲突 / Confirm first hammer was picked up first; confirm no conflict |
| 游戏崩溃 / Crash or Lua error | 检查 UTF-8 编码、括号逗号完整性、查看 `modimporter.log.txt` / Check UTF-8 encoding, bracket/ comma integrity, inspect modimporter.log.txt |
| 手柄不能用摇杆 / Controller nav broken | 重启游戏（ModConfigMenu 已知问题）/ Restart game (known ModConfigMenu quirk) |

---

## 仓库文件 / Repository Files

```
Hades-RunStartControl-Hammer2/
├── README.md                              # 本指南 / This guide
└── RunStartControl/                       # 完整 Mod 文件 / Complete mod files
    ├── RunStartControl.lua                # 核心逻辑 / Core logic
    ├── ReferenceData.lua                  # 数据定义 + 冲突处理 / Data + conflict handling
    ├── AspectSettings.lua                 # 形态设置存储 / Aspect settings storage
    ├── AspectConfigMenu.lua               # 第一把锤子菜单 / First hammer menu
    ├── Hammer2ConfigMenu.lua              # 第二把锤子菜单（新增）/ Second hammer menu (NEW)
    ├── PrePactConfigMenu.lua              # 契约前菜单 / Pre-pact menu
    ├── modfile.txt                        # Mod 导入清单 / Import manifest
    └── README.md                          # 原作者说明 / Original author's notes
```

---

## 进阶说明 / Advanced Notes

- 想给特定形态设默认第二把：在 `ResetAspectSettings` 中对不同 `aspectID` 传不同值 / Set per-aspect defaults by passing different `hammer2Reward` values per `aspectID` in `ResetAspectSettings`
- 改哨兵值文字：改 `ReferenceData.lua` 中的 `VanillaSentinel` 常量即可 / Change sentinel display text by editing the `VanillaSentinel` constant in `ReferenceData.lua`
- 手动改 `HammerOptions`：`GetSecondHammerOptions` 动态读取，自动反映变化 / `GetSecondHammerOptions` reads `HammerOptions` dynamically — manual edits are picked up automatically
- 添加新武器形态：在 `ReferenceData.lua` 中更新 `WeaponAspectData` 和 `HammerOptions`，菜单自动适配 / Adding new aspects: update `WeaponAspectData` and `HammerOptions` in `ReferenceData.lua` — both menus adapt automatically

---

## 贡献者 / Contributors

| 贡献者 / Contributor | 角色 / Role | GitHub |
|---|---|---|
| **1708004874a-star** | 项目发起、测试验证 / Project owner, testing & validation | [@1708004874a-star](https://github.com/1708004874a-star) |
| **Claude (Anthropic)** | 代码实现、文档编写 / Code implementation & documentation | — |

### 原始致谢 / Original Credits

- RunStartControl 原作者 / Original authors: **cgull** (cgull#4469), **Museus** (Museus#7777)
- ModConfigMenu 框架 / framework: 相关作者 / respective authors
- 第二把锤子功能基于 RunStartControl 扩展开发 / Second hammer feature built as an extension of RunStartControl
