RunStartControl.WeaponAspectData = {
    [1] = {
        Name = "SwordWeapon",
        Aspects = {
           [1] = "SwordBaseUpgradeTrait",
           [2] = "SwordCriticalParryTrait",
           [3] = "DislodgeAmmoTrait",
           [4] = "SwordConsecrationTrait",
        }
    },
    [2] = {
        Name = "SpearWeapon",
        Aspects = {
            [1] = "SpearBaseUpgradeTrait",
            [2] = "SpearTeleportTrait",
            [3] = "SpearWeaveTrait",
            [4] = "SpearSpinTravel",            
        }
    },
    [3] = {
        Name = "ShieldWeapon",
        Aspects = {
            [1] = "ShieldBaseUpgradeTrait",
            [2] = "ShieldRushBonusProjectileTrait",
            [3] = "ShieldTwoShieldTrait",
            [4] = "ShieldLoadAmmoTrait",
        }
    },
    [4] = {
        Name = "BowWeapon",
        Aspects = {
            [1] = "BowBaseUpgradeTrait",
            [2] = "BowMarkHomingTrait",
            [3] = "BowLoadAmmoTrait",
            [4] = "BowBondTrait",
        }
    },
    [5] = {
        Name = "FistWeapon",
        Aspects = {
            [1] = "FistBaseUpgradeTrait",
            [2] = "FistVacuumTrait",
            [3] = "FistWeaveTrait",
            [4] = "FistDetonateTrait",
        }
    },
    [6] = {
        Name = "GunWeapon",
        Aspects = {
            [1] = "GunBaseUpgradeTrait",
            [2] = "GunGrenadeSelfEmpowerTrait",
            [3] = "GunManualReloadTrait",
            [4] = "GunLoadedGrenadeTrait",
        }
    },
}

RunStartControl.HammerOptions = {
    SwordBaseUpgradeTrait = {"SwordTwoComboTrait","SwordSecondaryAreaDamageTrait","SwordGoldDamageTrait","SwordBlinkTrait","SwordThrustWaveTrait","SwordHealthBufferDamageTrait","SwordSecondaryDoubleAttackTrait","SwordCriticalTrait","SwordBackstabTrait","SwordDoubleDashAttackTrait","SwordHeavySecondStrikeTrait","SwordCursedLifeStealTrait"},
    SwordCriticalParryTrait = {"SwordTwoComboTrait","SwordSecondaryAreaDamageTrait","SwordGoldDamageTrait","SwordBlinkTrait","SwordThrustWaveTrait","SwordHealthBufferDamageTrait","SwordSecondaryDoubleAttackTrait","SwordCriticalTrait","SwordBackstabTrait","SwordDoubleDashAttackTrait","SwordHeavySecondStrikeTrait","SwordCursedLifeStealTrait"},
    DislodgeAmmoTrait = {"SwordTwoComboTrait","SwordSecondaryAreaDamageTrait","SwordGoldDamageTrait","SwordBlinkTrait","SwordThrustWaveTrait","SwordHealthBufferDamageTrait","SwordSecondaryDoubleAttackTrait","SwordCriticalTrait","SwordBackstabTrait","SwordDoubleDashAttackTrait","SwordHeavySecondStrikeTrait","SwordCursedLifeStealTrait"},
    SwordConsecrationTrait = {"SwordConsecrationBoostTrait","SwordSecondaryAreaDamageTrait","SwordGoldDamageTrait","SwordBlinkTrait","SwordThrustWaveTrait","SwordHealthBufferDamageTrait","SwordSecondaryDoubleAttackTrait","SwordBackstabTrait","SwordDoubleDashAttackTrait","SwordCursedLifeStealTrait"},
    SpearBaseUpgradeTrait = {"SpearReachAttack", "SpearAutoAttack", "SpearThrowExplode", "SpearThrowBounce", "SpearThrowPenetrate", "SpearThrowCritical", "SpearSpinDamageRadius", "SpearSpinChargeLevelTime", "SpearDashMultiStrike", "SpearThrowElectiveCharge", "SpearSpinChargeAreaDamageTrait", "SpearAttackPhalanxTrait"},
    SpearTeleportTrait = {"SpearReachAttack", "SpearAutoAttack", "SpearThrowPenetrate", "SpearThrowCritical", "SpearSpinDamageRadius", "SpearSpinChargeLevelTime", "SpearDashMultiStrike", "SpearSpinChargeAreaDamageTrait", "SpearAttackPhalanxTrait"},
    SpearWeaveTrait = {"SpearReachAttack", "SpearThrowExplode", "SpearThrowBounce", "SpearThrowPenetrate", "SpearThrowCritical", "SpearSpinDamageRadius", "SpearSpinChargeLevelTime", "SpearDashMultiStrike", "SpearThrowElectiveCharge", "SpearSpinChargeAreaDamageTrait", "SpearAttackPhalanxTrait"},
    SpearSpinTravel = {"SpearSpinTravelDurationTrait","SpearReachAttack", "SpearThrowPenetrate", "SpearSpinDamageRadius", "SpearSpinChargeLevelTime", "SpearDashMultiStrike", "SpearThrowElectiveCharge", "SpearSpinChargeAreaDamageTrait", "SpearAttackPhalanxTrait"},
    ShieldBaseUpgradeTrait = {"ShieldDashAOETrait", "ShieldRushProjectileTrait", "ShieldThrowFastTrait", "ShieldThrowCatchExplode", "ShieldChargeHealthBufferTrait", "ShieldChargeSpeedTrait", "ShieldBashDamageTrait", "ShieldPerfectRushTrait", "ShieldThrowElectiveCharge", "ShieldThrowEmpowerTrait", "ShieldBlockEmpowerTrait", "ShieldThrowRushTrait"},
    ShieldRushBonusProjectileTrait = {"ShieldDashAOETrait", "ShieldRushProjectileTrait", "ShieldThrowFastTrait", "ShieldThrowCatchExplode", "ShieldChargeHealthBufferTrait", "ShieldChargeSpeedTrait", "ShieldBashDamageTrait", "ShieldPerfectRushTrait", "ShieldThrowEmpowerTrait", "ShieldBlockEmpowerTrait", "ShieldThrowRushTrait"},
    ShieldTwoShieldTrait = {"ShieldDashAOETrait", "ShieldRushProjectileTrait", "ShieldThrowCatchExplode", "ShieldChargeHealthBufferTrait", "ShieldChargeSpeedTrait", "ShieldBashDamageTrait", "ShieldPerfectRushTrait", "ShieldThrowEmpowerTrait", "ShieldBlockEmpowerTrait"},
    ShieldLoadAmmoTrait = {"ShieldLoadAmmoBoostTrait", "ShieldDashAOETrait", "ShieldRushProjectileTrait", "ShieldThrowFastTrait", "ShieldThrowCatchExplode", "ShieldChargeHealthBufferTrait", "ShieldChargeSpeedTrait", "ShieldBashDamageTrait", "ShieldPerfectRushTrait", "ShieldThrowElectiveCharge", "ShieldThrowEmpowerTrait", "ShieldBlockEmpowerTrait", "ShieldThrowRushTrait"},
    BowBaseUpgradeTrait = {"BowDoubleShotTrait", "BowLongRangeDamageTrait", "BowSlowChargeDamageTrait", "BowTapFireTrait", "BowPenetrationTrait", "BowPowerShotTrait", "BowSecondaryBarrageTrait", "BowTripleShotTrait", "BowSecondaryFocusedFireTrait", "BowChainShotTrait", "BowCloseAttackTrait", "BowConsecutiveBarrageTrait"},
    BowMarkHomingTrait = {"BowDoubleShotTrait", "BowLongRangeDamageTrait", "BowSlowChargeDamageTrait", "BowTapFireTrait", "BowPenetrationTrait", "BowPowerShotTrait", "BowSecondaryBarrageTrait", "BowTripleShotTrait", "BowChainShotTrait", "BowCloseAttackTrait", "BowConsecutiveBarrageTrait"},
    BowLoadAmmoTrait = {"BowDoubleShotTrait", "BowLongRangeDamageTrait", "BowSlowChargeDamageTrait", "BowTapFireTrait", "BowPenetrationTrait", "BowPowerShotTrait", "BowSecondaryBarrageTrait", "BowTripleShotTrait", "BowSecondaryFocusedFireTrait", "BowChainShotTrait", "BowCloseAttackTrait", "BowConsecutiveBarrageTrait"},
    BowBondTrait = {"BowBondBoostTrait", "BowDoubleShotTrait", "BowLongRangeDamageTrait", "BowSlowChargeDamageTrait", "BowPowerShotTrait", "BowSecondaryBarrageTrait", "BowTripleShotTrait", "BowChainShotTrait", "BowCloseAttackTrait"},
    FistBaseUpgradeTrait = {"FistReachAttackTrait", "FistDashAttackHealthBufferTrait", "FistTeleportSpecialTrait", "FistDoubleDashSpecialTrait", "FistChargeSpecialTrait", "FistKillTrait", "FistSpecialLandTrait", "FistAttackFinisherTrait", "FistConsecutiveAttackTrait", "FistSpecialFireballTrait", "FistAttackDefenseTrait", "FistHeavyAttackTrait"},
    FistVacuumTrait = {"FistReachAttackTrait", "FistDashAttackHealthBufferTrait", "FistKillTrait", "FistSpecialLandTrait", "FistAttackFinisherTrait", "FistConsecutiveAttackTrait", "FistAttackDefenseTrait", "FistHeavyAttackTrait", "FistDoubleDashSpecialTrait"},
    FistWeaveTrait = {"FistReachAttackTrait", "FistDashAttackHealthBufferTrait", "FistTeleportSpecialTrait", "FistDoubleDashSpecialTrait", "FistChargeSpecialTrait", "FistKillTrait", "FistAttackFinisherTrait", "FistConsecutiveAttackTrait", "FistSpecialFireballTrait", "FistAttackDefenseTrait", "FistHeavyAttackTrait"},
    FistDetonateTrait = {"FistDetonateBoostTrait", "FistSpecialLandTrait", "FistChargeSpecialTrait", "FistConsecutiveAttackTrait", "FistDashAttackHealthBufferTrait", "FistAttackDefenseTrait", "FistTeleportSpecialTrait", "FistDoubleDashSpecialTrait", "FistKillTrait"},
    GunBaseUpgradeTrait = {"GunSlowGrenade", "GunMinigunTrait", "GunShotgunTrait", "GunExplodingSecondaryTrait", "GunGrenadeFastTrait", "GunArmorPenerationTrait", "GunInfiniteAmmoTrait", "GunGrenadeClusterTrait", "GunGrenadeDropTrait", "GunHeavyBulletTrait", "GunChainShotTrait", "GunHomingBulletTrait"},
    GunGrenadeSelfEmpowerTrait = {"GunSlowGrenade", "GunMinigunTrait", "GunShotgunTrait", "GunExplodingSecondaryTrait", "GunGrenadeFastTrait", "GunArmorPenerationTrait", "GunInfiniteAmmoTrait", "GunGrenadeClusterTrait", "GunGrenadeDropTrait", "GunHeavyBulletTrait", "GunChainShotTrait", "GunHomingBulletTrait"},
    GunManualReloadTrait = {"GunSlowGrenade", "GunMinigunTrait", "GunShotgunTrait", "GunExplodingSecondaryTrait", "GunGrenadeFastTrait", "GunArmorPenerationTrait", "GunInfiniteAmmoTrait", "GunGrenadeClusterTrait", "GunGrenadeDropTrait", "GunHeavyBulletTrait", "GunChainShotTrait", "GunHomingBulletTrait"},
    GunLoadedGrenadeTrait = {"GunLoadedGrenadeBoostTrait", "GunLoadedGrenadeLaserTrait", "GunLoadedGrenadeSpeedTrait", "GunLoadedGrenadeWideTrait", "GunLoadedGrenadeInfiniteAmmoTrait", "GunSlowGrenade", "GunGrenadeFastTrait", "GunArmorPenerationTrait"},
  }

RunStartControl.DefaultHammerSettings = {
    SwordBaseUpgradeTrait = "SwordDoubleDashAttackTrait",
    SwordCriticalParryTrait = "SwordDoubleDashAttackTrait",
    DislodgeAmmoTrait = "SwordDoubleDashAttackTrait",
    SwordConsecrationTrait = "SwordBackstabTrait",
    SpearBaseUpgradeTrait = "SpearAutoAttack",
    SpearTeleportTrait = "SpearAutoAttack",
    SpearWeaveTrait = "SpearThrowExplode",
    SpearSpinTravel = "SpearThrowElectiveCharge",
    ShieldBaseUpgradeTrait = "ShieldRushProjectileTrait",
    ShieldRushBonusProjectileTrait = "ShieldRushProjectileTrait",
    ShieldTwoShieldTrait = "ShieldRushProjectileTrait",
    ShieldLoadAmmoTrait = "ShieldRushProjectileTrait",
    BowBaseUpgradeTrait = "BowTripleShotTrait",
    BowMarkHomingTrait = "BowConsecutiveBarrageTrait",
    BowLoadAmmoTrait = "BowTapFireTrait",
    BowBondTrait = "BowDoubleShotTrait",
    FistBaseUpgradeTrait = "FistDashAttackHealthBufferTrait",
    FistVacuumTrait = "FistDashAttackHealthBufferTrait",
    FistWeaveTrait = "FistDashAttackHealthBufferTrait",
    FistDetonateTrait = "FistDashAttackHealthBufferTrait",
    GunBaseUpgradeTrait = "GunShotgunTrait",
    GunGrenadeSelfEmpowerTrait = "GunExplodingSecondaryTrait",
    GunManualReloadTrait = "GunExplodingSecondaryTrait",
    GunLoadedGrenadeTrait = "GunGrenadeFastTrait",
}

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

RunStartControl.BoonGods = {
    "Aphrodite",
    "Ares",
    "Artemis",
    "Athena",
    "Demeter",
    "Dionysus",
    "Poseidon",
    "Zeus",
}

-- God is capitalized god name, coreSlot is Attack/Special/Cast/Dash, aspect is "ShieldLoadAmmoTrait" or nothing,
-- just checking for beowulf
function RunStartControl.CoreBoonReference( god, coreSlot, aspect )
    if coreSlot == "Attack" then
        return god .. "WeaponTrait"
    elseif coreSlot == "Special" then
        return god .. "SecondaryTrait"
    elseif coreSlot == "Cast" then
        if aspect == "ShieldLoadAmmoTrait" and god ~= "Dionysus" and god ~= "Poseidon" then
            return "ShieldLoadAmmo_" .. god .. "RangedTrait"
        else
            return god .. "RangedTrait"
        end
    elseif coreSlot == "Dash" then
        return god .."RushTrait"
    end
end

function RunStartControl.GetEquippedWeaponAspect()
    for i, weaponData in ipairs(RunStartControl.WeaponAspectData) do
        for i, aspectTrait in ipairs(weaponData.Aspects) do
            if HeroHasTrait(aspectTrait) then
                return {
                    Weapon = weaponData.Name,
                    Aspect = aspectTrait,
                }
            end
        end
    end 
end

function RunStartControl.HeroForcingGod()
    for k, trait in pairs( CurrentRun.Hero.Traits ) do
        if trait ~= nil and trait.ForceBoonName ~= nil and trait.Uses > 0 then
            return trait.ForceBoonName:sub(1, -8)
        end
    end
    return false
end