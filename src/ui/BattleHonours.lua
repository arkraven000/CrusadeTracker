--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Battle Honours UI
=====================================
Version: 1.0.0-alpha

This module provides UI for selecting and managing all three Battle Honour categories:
1. Battle Traits
2. Weapon Modifications
3. Crusade Relics
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local BattleTraits = require("src/honours/BattleTraits")
local WeaponMods = require("src/honours/WeaponMods")
local CrusadeRelics = require("src/honours/CrusadeRelics")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local BattleHonoursUI = {
    initialized = false,
    campaign = nil,
    selectedUnit = nil,
    selectedCategory = "Battle Trait", -- "Battle Trait", "Weapon Modification", "Crusade Relic"
    currentPage = 1,
    itemsPerPage = 8
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize BattleHonours UI module
-- @param campaign table Campaign reference
function BattleHonoursUI.initialize(campaign)
    if BattleHonoursUI.initialized then
        return
    end

    BattleHonoursUI.campaign = campaign
    BattleHonoursUI.initialized = true

    Utils.logInfo("BattleHonours UI module initialized")
end

--- Open Battle Honours panel for a unit
-- @param unitId string Unit ID
function BattleHonoursUI.openForUnit(unitId)
    local unit = BattleHonoursUI.campaign.units[unitId]
    if not unit then
        broadcastToAll("ERROR: Unit not found", {1, 0, 0})
        return
    end

    if not unit.pendingHonourSelection then
        broadcastToAll("Unit does not have pending honour selection", {1, 1, 0})
        return
    end

    BattleHonoursUI.selectedUnit = unit
    BattleHonoursUI.selectedCategory = "Battle Trait"
    BattleHonoursUI.currentPage = 1

    BattleHonoursUI.refreshUI()
end

-- ============================================================================
-- CATEGORY SELECTION
-- ============================================================================

--- Set selected honour category
-- @param category string Category name
function BattleHonoursUI.setCategory(category)
    BattleHonoursUI.selectedCategory = category
    BattleHonoursUI.currentPage = 1
    BattleHonoursUI.refreshUI()
end

--- Get available honours for selected category
-- @return table Array of available honours
function BattleHonoursUI.getAvailableHonours()
    if not BattleHonoursUI.selectedUnit then
        return {}
    end

    local unit = BattleHonoursUI.selectedUnit
    local player = nil

    -- Find player
    for _, p in pairs(BattleHonoursUI.campaign.players) do
        if Utils.tableContains(p.orderOfBattle, unit.id) then
            player = p
            break
        end
    end

    if BattleHonoursUI.selectedCategory == "Battle Trait" then
        return BattleTraits.getAllBattleTraits(player and player.faction or "Generic")

    elseif BattleHonoursUI.selectedCategory == "Weapon Modification" then
        -- For weapon mods, return modification types + available weapons
        return WeaponMods.getWeaponModificationTypes()

    elseif BattleHonoursUI.selectedCategory == "Crusade Relic" then
        if unit.isCharacter then
            return CrusadeRelics.getAvailableRelicsForUnit(unit)
        else
            return {}
        end
    end

    return {}
end

-- ============================================================================
-- HONOUR APPLICATION
-- ============================================================================

--- Apply selected Battle Trait
-- @param traitName string Name of the trait
function BattleHonoursUI.applyBattleTrait(traitName)
    if not BattleHonoursUI.selectedUnit then
        return
    end

    local player = nil
    for _, p in pairs(BattleHonoursUI.campaign.players) do
        if Utils.tableContains(p.orderOfBattle, BattleHonoursUI.selectedUnit.id) then
            player = p
            break
        end
    end

    local success, message = BattleTraits.applyBattleTrait(
        BattleHonoursUI.selectedUnit,
        traitName,
        player and player.faction or "Generic",
        BattleHonoursUI.campaign.log
    )

    if success then
        broadcastToAll(message, {0, 1, 0})
        BattleHonoursUI.selectedUnit = nil
        -- Close panel
    else
        broadcastToAll("ERROR: " .. message, {1, 0, 0})
    end

    BattleHonoursUI.refreshUI()
end

--- Apply Weapon Modifications
-- @param weaponName string Name of the weapon
-- @param modIds table Array of 2 modification IDs
function BattleHonoursUI.applyWeaponModifications(weaponName, modIds)
    if not BattleHonoursUI.selectedUnit then
        return
    end

    local success, message = WeaponMods.applyWeaponModifications(
        BattleHonoursUI.selectedUnit,
        1, -- model index (would be selected in UI)
        weaponName,
        modIds,
        BattleHonoursUI.campaign.log
    )

    if success then
        broadcastToAll(message, {0, 1, 0})
        BattleHonoursUI.selectedUnit = nil
        -- Close panel
    else
        broadcastToAll("ERROR: " .. message, {1, 0, 0})
    end

    BattleHonoursUI.refreshUI()
end

--- Apply Crusade Relic
-- @param relicName string Name of the relic
function BattleHonoursUI.applyCrusadeRelic(relicName)
    if not BattleHonoursUI.selectedUnit then
        return
    end

    local success, message = CrusadeRelics.applyCrusadeRelic(
        BattleHonoursUI.selectedUnit,
        relicName,
        BattleHonoursUI.campaign.log
    )

    if success then
        broadcastToAll(message, {0, 1, 0})
        BattleHonoursUI.selectedUnit = nil
        -- Close panel
    else
        broadcastToAll("ERROR: " .. message, {1, 0, 0})
    end

    BattleHonoursUI.refreshUI()
end

-- ============================================================================
-- PAGINATION
-- ============================================================================

--- Go to next page
function BattleHonoursUI.nextPage()
    local honours = BattleHonoursUI.getAvailableHonours()
    local totalPages = math.ceil(#honours / BattleHonoursUI.itemsPerPage)

    if BattleHonoursUI.currentPage < totalPages then
        BattleHonoursUI.currentPage = BattleHonoursUI.currentPage + 1
        BattleHonoursUI.refreshUI()
    end
end

--- Go to previous page
function BattleHonoursUI.previousPage()
    if BattleHonoursUI.currentPage > 1 then
        BattleHonoursUI.currentPage = BattleHonoursUI.currentPage - 1
        BattleHonoursUI.refreshUI()
    end
end

-- ============================================================================
-- UI REFRESH
-- ============================================================================

--- Refresh UI display
function BattleHonoursUI.refreshUI()
    if not BattleHonoursUI.selectedUnit then
        return
    end

    -- Update category buttons
    local categories = {"Battle Trait", "Weapon Modification", "Crusade Relic"}
    for _, cat in ipairs(categories) do
        local color = (cat == BattleHonoursUI.selectedCategory) and "#FFFF00" or "#CCCCCC"
        -- UI.setAttribute("battleHonours_cat_" .. cat, "color", color)
    end

    -- Update unit info
    local unit = BattleHonoursUI.selectedUnit
    -- UI.setAttribute("battleHonours_unitName", "text", unit.name)
    -- UI.setAttribute("battleHonours_currentHonours", "text",
    --     string.format("Honours: %d / %d", #unit.battleHonours, maxHonours))

    -- Update page indicator
    local honours = BattleHonoursUI.getAvailableHonours()
    local totalPages = math.max(1, math.ceil(#honours / BattleHonoursUI.itemsPerPage))
    -- UI.setAttribute("battleHonours_pageIndicator", "text",
    --     string.format("Page %d of %d", BattleHonoursUI.currentPage, totalPages))

    -- Update pagination buttons
    -- UI.setAttribute("battleHonours_previousPage", "interactable",
    --     tostring(BattleHonoursUI.currentPage > 1))
    -- UI.setAttribute("battleHonours_nextPage", "interactable",
    --     tostring(BattleHonoursUI.currentPage < totalPages))
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle button clicks
-- @param player table Player object
-- @param value string Button value
-- @param id string Element ID
function BattleHonoursUI.onButtonClick(player, value, id)
    if id == "battleHonours_close" then
        BattleHonoursUI.selectedUnit = nil

    elseif id == "battleHonours_previousPage" then
        BattleHonoursUI.previousPage()

    elseif id == "battleHonours_nextPage" then
        BattleHonoursUI.nextPage()

    elseif id:match("^battleHonours_selectTrait_") then
        local traitName = id:gsub("^battleHonours_selectTrait_", "")
        BattleHonoursUI.applyBattleTrait(traitName)

    elseif id:match("^battleHonours_selectRelic_") then
        local relicName = id:gsub("^battleHonours_selectRelic_", "")
        BattleHonoursUI.applyCrusadeRelic(relicName)

    elseif id:match("^battleHonours_category_") then
        local category = id:gsub("^battleHonours_category_", "")
        BattleHonoursUI.setCategory(category)
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return {
    initialize = BattleHonoursUI.initialize,
    openForUnit = BattleHonoursUI.openForUnit,
    refreshUI = BattleHonoursUI.refreshUI,

    -- Category selection
    setCategory = BattleHonoursUI.setCategory,
    getAvailableHonours = BattleHonoursUI.getAvailableHonours,

    -- Callbacks
    onButtonClick = BattleHonoursUI.onButtonClick
}
