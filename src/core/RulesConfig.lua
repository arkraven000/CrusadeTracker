--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Rules Configuration Loader
=====================================
Version: 1.0.0-alpha

Loads and manages edition-specific rules configuration.
In TTS, config data is embedded in Lua (JSON files are for reference/documentation).

This allows the campaign to be edition-agnostic - changing editions
only requires loading different configuration data.
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- ============================================================================
-- 10TH EDITION RULES CONFIGURATION (Embedded Data)
-- ============================================================================

--- 10th Edition Crusade Rules Configuration
-- Source: config/rules_10th.json
local RULES_10TH = {
    edition = "10th",
    version = "1.0.0",
    description = "Warhammer 40,000 10th Edition Crusade Rules Configuration",

    rankThresholds = Constants.RANK_THRESHOLDS,

    nonCharacterMaxXP = Constants.NON_CHAR_XP_CAP,

    requisitions = Constants.REQUISITION_COSTS,

    crusadePointsFormula = "floor(XP / 5) + Battle Honours - Battle Scars",

    crusadePointsNotes = {
        "Battle Honours: +1 each (or +2 if TITANIC)",
        "Crusade Relics: +1 (Artificer), +2 (Antiquity), +3 (Legendary)",
        "Battle Scars: -1 each",
        "Can result in negative Crusade Points"
    },

    xpAwardTypes = {
        ["Battle Experience"] = {
            amount = 1,
            recipients = "all participating units",
            automatic = true
        },
        ["Every Third Kill"] = {
            amount = 1,
            calculation = "Per third enemy unit destroyed (3rd, 6th, 9th, etc.)",
            automatic = false
        },
        ["Marked for Greatness"] = {
            amount = 3,
            recipients = "ONE unit per player per battle",
            restrictions = {"Cannot have Disgraced or Mark of Shame Battle Scars"},
            automatic = false
        }
    },

    maxValues = {
        requisitionPoints = Constants.MAX_RP,
        battleHonoursNonCharacter = Constants.MAX_BATTLE_HONOURS_NON_CHAR,
        battleHonoursCharacter = Constants.MAX_BATTLE_HONOURS_CHAR,
        battleScars = Constants.MAX_BATTLE_SCARS,
        supplyLimitDefault = Constants.DEFAULT_SUPPLY_LIMIT,
        supplyLimitIncrease = Constants.SUPPLY_LIMIT_INCREASE
    }
}

--- 10th Edition Battle Scars Configuration
-- Source: config/battle_scars.json
local BATTLE_SCARS_10TH = {
    edition = "10th",
    version = "1.0.0",
    description = "10th Edition Battle Scars (6 types)",
    battleScars = Constants.BATTLE_SCARS,
    maxBattleScarsPerUnit = Constants.MAX_BATTLE_SCARS,
    notes = {
        "When a unit fails an Out of Action test, it must gain a Battle Scar OR lose a Battle Honour",
        "If a unit has 3 Battle Scars, it MUST choose Devastating Blow (lose honour) on next Out of Action failure",
        "If a unit has no Battle Honours remaining and chooses Devastating Blow, it is permanently destroyed",
        "Battle Scars reduce Crusade Points by 1 each"
    }
}

--- 10th Edition Weapon Modifications Configuration
-- Source: config/weapon_mods.json
local WEAPON_MODS_10TH = {
    edition = "10th",
    version = "1.0.0",
    description = "10th Edition Weapon Modifications (6 types, roll TWO different)",
    weaponModifications = Constants.WEAPON_MODIFICATIONS,
    rules = {
        "When a unit gains a Weapon Enhancement Battle Honour, select ONE weapon",
        "Roll 2D6 for TWO different weapon modifications",
        "If you roll the same result twice, re-roll until you get two different results",
        "Apply BOTH modifications to the selected weapon",
        "Must select CHARACTER model's weapon if unit is CHARACTER",
        "Must select Unit Champion's weapon if unit has one and is not CHARACTER",
        "Cannot modify weapons that are Enhancements or Crusade Relics",
        "Cannot modify a weapon that already has weapon modifications",
        "Weapon modifications are lost if the weapon is replaced via Enhancements or Rearm and Resupply"
    },
    notes = {
        "Weapon Modifications count as ONE Battle Honour",
        "Contributes +1 CP (or +2 if TITANIC) like any other honour",
        "Two modifications per weapon is mandatory, not optional"
    }
}

-- ============================================================================
-- RULES CONFIGURATION MANAGER
-- ============================================================================

--- Active rules configuration
local activeRulesConfig = nil
local activeEdition = nil

--- Load rules configuration for an edition
-- @param edition string Edition identifier ("10th", etc.)
-- @return boolean Success
function loadRulesConfig(edition)
    edition = edition or "10th"

    Utils.logInfo("Loading rules configuration for edition: " .. edition)

    if edition == "10th" then
        activeRulesConfig = {
            rules = RULES_10TH,
            battleScars = BATTLE_SCARS_10TH,
            weaponMods = WEAPON_MODS_10TH
        }
        activeEdition = edition
        Utils.logInfo("Loaded 10th Edition rules configuration")
        return true
    else
        Utils.logError("Unknown edition: " .. edition)
        return false
    end
end

--- Get active rules configuration
-- @return table Rules configuration or nil
function getRulesConfig()
    if not activeRulesConfig then
        -- Auto-load default edition
        loadRulesConfig("10th")
    end
    return activeRulesConfig
end

--- Get active edition
-- @return string Edition identifier or nil
function getActiveEdition()
    return activeEdition or "10th"
end

-- ============================================================================
-- RULES QUERIES
-- ============================================================================

--- Get rank threshold by rank number
-- @param rank number Rank number (1-5)
-- @return table Rank threshold data or nil
function getRankThreshold(rank)
    local config = getRulesConfig()
    for _, threshold in ipairs(config.rules.rankThresholds) do
        if threshold.rank == rank then
            return threshold
        end
    end
    return nil
end

--- Get requisition configuration by name
-- @param requisitionName string Requisition name
-- @return table Requisition config or nil
function getRequisitionConfig(requisitionName)
    local config = getRulesConfig()
    return config.rules.requisitions[requisitionName]
end

--- Get XP award type configuration
-- @param awardType string "Battle Experience", "Every Third Kill", or "Marked for Greatness"
-- @return table XP award config or nil
function getXPAwardConfig(awardType)
    local config = getRulesConfig()
    return config.rules.xpAwardTypes[awardType]
end

--- Get battle scar by ID
-- @param scarId number Scar ID (1-6)
-- @return table Battle Scar definition or nil
function getBattleScarConfig(scarId)
    local config = getRulesConfig()
    return config.battleScars.battleScars[scarId]
end

--- Get all battle scars
-- @return table Array of battle scar definitions
function getAllBattleScars()
    local config = getRulesConfig()
    return config.battleScars.battleScars
end

--- Get weapon modification by ID
-- @param modId number Mod ID (1-6)
-- @return table Weapon modification definition or nil
function getWeaponModConfig(modId)
    local config = getRulesConfig()
    for _, mod in ipairs(config.weaponMods.weaponModifications) do
        if mod.id == modId then
            return mod
        end
    end
    return nil
end

--- Get all weapon modifications
-- @return table Array of weapon modification definitions
function getAllWeaponMods()
    local config = getRulesConfig()
    return config.weaponMods.weaponModifications
end

--- Get max value for a game constant
-- @param constantName string Constant name
-- @return number Max value or nil
function getMaxValue(constantName)
    local config = getRulesConfig()
    return config.rules.maxValues[constantName]
end

-- ============================================================================
-- CUSTOM RULES SUPPORT (Future)
-- ============================================================================

--- Add custom battle scar
-- @param scarDef table Battle Scar definition
-- @return boolean Success
function addCustomBattleScar(scarDef)
    if not scarDef or not scarDef.name then
        return false
    end

    local config = getRulesConfig()

    -- Assign ID if not provided
    if not scarDef.id then
        scarDef.id = #config.battleScars.battleScars + 1
    end

    table.insert(config.battleScars.battleScars, scarDef)
    Utils.logInfo("Added custom Battle Scar: " .. scarDef.name)

    return true
end

--- Add custom requisition
-- @param requisitionName string Requisition name
-- @param requisitionConfig table Requisition configuration
-- @return boolean Success
function addCustomRequisition(requisitionName, requisitionConfig)
    if not requisitionName or not requisitionConfig then
        return false
    end

    local config = getRulesConfig()
    config.rules.requisitions[requisitionName] = requisitionConfig

    Utils.logInfo("Added custom Requisition: " .. requisitionName)
    return true
end

-- ============================================================================
-- RULES VALIDATION
-- ============================================================================

--- Validate rules configuration structure
-- @param rulesConfig table Rules configuration to validate
-- @return boolean Valid
-- @return string Error message if invalid
function validateRulesConfig(rulesConfig)
    if not rulesConfig then
        return false, "No rules configuration provided"
    end

    -- Check required top-level keys
    if not rulesConfig.rules then
        return false, "Missing 'rules' section"
    end

    if not rulesConfig.battleScars then
        return false, "Missing 'battleScars' section"
    end

    if not rulesConfig.weaponMods then
        return false, "Missing 'weaponMods' section"
    end

    -- Validate rules section
    if not rulesConfig.rules.rankThresholds then
        return false, "Missing 'rankThresholds' in rules"
    end

    if not rulesConfig.rules.requisitions then
        return false, "Missing 'requisitions' in rules"
    end

    if not rulesConfig.rules.maxValues then
        return false, "Missing 'maxValues' in rules"
    end

    -- Validate rank thresholds count (should be 5 for 10th edition)
    if #rulesConfig.rules.rankThresholds ~= 5 then
        return false, "Expected 5 rank thresholds, got " .. #rulesConfig.rules.rankThresholds
    end

    -- Validate battle scars count (should be 6 for 10th edition)
    if #rulesConfig.battleScars.battleScars ~= 6 then
        return false, "Expected 6 battle scars, got " .. #rulesConfig.battleScars.battleScars
    end

    -- Validate weapon mods count (should be 6 for 10th edition)
    if #rulesConfig.weaponMods.weaponModifications ~= 6 then
        return false, "Expected 6 weapon modifications, got " .. #rulesConfig.weaponMods.weaponModifications
    end

    return true, nil
end

--- Get rules configuration summary
-- @return table Summary of active rules config
function getRulesConfigSummary()
    local config = getRulesConfig()

    return {
        edition = getActiveEdition(),
        version = config.rules.version,
        rankCount = #config.rules.rankThresholds,
        requisitionCount = Utils.tableSize(config.rules.requisitions),
        battleScarCount = #config.battleScars.battleScars,
        weaponModCount = #config.weaponMods.weaponModifications,
        crusadePointsFormula = config.rules.crusadePointsFormula,
        maxValues = config.rules.maxValues
    }
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Auto-load 10th Edition on module load
loadRulesConfig("10th")

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    -- Loading
    loadRulesConfig = loadRulesConfig,
    getRulesConfig = getRulesConfig,
    getActiveEdition = getActiveEdition,

    -- Queries
    getRankThreshold = getRankThreshold,
    getRequisitionConfig = getRequisitionConfig,
    getXPAwardConfig = getXPAwardConfig,
    getBattleScarConfig = getBattleScarConfig,
    getAllBattleScars = getAllBattleScars,
    getWeaponModConfig = getWeaponModConfig,
    getAllWeaponMods = getAllWeaponMods,
    getMaxValue = getMaxValue,

    -- Custom Rules
    addCustomBattleScar = addCustomBattleScar,
    addCustomRequisition = addCustomRequisition,

    -- Validation
    validateRulesConfig = validateRulesConfig,
    getRulesConfigSummary = getRulesConfigSummary,

    -- Direct access to config data (for advanced use)
    RULES_10TH = RULES_10TH,
    BATTLE_SCARS_10TH = BATTLE_SCARS_10TH,
    WEAPON_MODS_10TH = WEAPON_MODS_10TH
}
