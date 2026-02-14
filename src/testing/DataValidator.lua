--[[
=====================================
DATA VALIDATOR
Phase 9: Testing & Quality Assurance
=====================================

Comprehensive data integrity validation for campaign data:
- Campaign structure validation
- Player data validation
- Unit data validation
- Battle record validation
- Map configuration validation
]]

local DataValidator = {}

-- Dependencies
local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")

-- Validation results
DataValidator.lastValidation = nil

-- ============================================================================
-- MAIN VALIDATION
-- ============================================================================

--- Validate entire campaign
-- @param campaign table Campaign data
-- @return boolean Is valid
-- @return table Validation report
function DataValidator.validateCampaign(campaign)
    local report = {
        isValid = true,
        errors = {},
        warnings = {},
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }

    if not campaign then
        table.insert(report.errors, "Campaign is nil")
        report.isValid = false
        return false, report
    end

    -- Validate campaign structure
    DataValidator.validateCampaignStructure(campaign, report)

    -- Validate players
    DataValidator.validatePlayers(campaign, report)

    -- Validate units
    DataValidator.validateUnits(campaign, report)

    -- Validate battles
    DataValidator.validateBattles(campaign, report)

    -- Validate map configuration
    if campaign.mapConfig then
        DataValidator.validateMapConfig(campaign, report)
    end

    -- Validate alliances
    if campaign.alliances then
        DataValidator.validateAlliances(campaign, report)
    end

    -- Set overall validity
    report.isValid = #report.errors == 0

    DataValidator.lastValidation = report
    return report.isValid, report
end

-- ============================================================================
-- CAMPAIGN STRUCTURE VALIDATION
-- ============================================================================

--- Validate campaign structure
-- @param campaign table Campaign data
-- @param report table Validation report
function DataValidator.validateCampaignStructure(campaign, report)
    -- Check required fields
    local requiredFields = {"id", "name", "createdDate", "players", "units", "battles", "log"}

    for _, field in ipairs(requiredFields) do
        if campaign[field] == nil then
            table.insert(report.errors, "Missing required field: " .. field)
        end
    end

    -- Validate field types
    if campaign.players and type(campaign.players) ~= "table" then
        table.insert(report.errors, "Campaign.players must be a table")
    end

    if campaign.units and type(campaign.units) ~= "table" then
        table.insert(report.errors, "Campaign.units must be a table")
    end

    if campaign.battles and type(campaign.battles) ~= "table" then
        table.insert(report.errors, "Campaign.battles must be a table")
    end

    -- Check campaign ID format (GUIDs are timestamp_counter_random_random)
    if campaign.id and not string.match(campaign.id, "^[%d_]+$") then
        table.insert(report.warnings, "Campaign ID has unexpected format: " .. campaign.id)
    end
end

-- ============================================================================
-- PLAYER VALIDATION
-- ============================================================================

--- Validate all players
-- @param campaign table Campaign data
-- @param report table Validation report
function DataValidator.validatePlayers(campaign, report)
    if not campaign.players then
        return
    end

    local playerCount = 0

    for playerId, player in pairs(campaign.players) do
        playerCount = playerCount + 1

        -- Validate player structure
        if not player.id then
            table.insert(report.errors, "Player missing ID")
        elseif player.id ~= playerId then
            table.insert(report.errors, string.format("Player ID mismatch: key=%s, id=%s", playerId, player.id))
        end

        -- Required player fields
        local requiredPlayerFields = {"name", "color", "faction", "requisitionPoints", "supplyLimit", "supplyUsed", "orderOfBattle"}

        for _, field in ipairs(requiredPlayerFields) do
            if player[field] == nil then
                table.insert(report.errors, string.format("Player %s missing field: %s", player.name or playerId, field))
            end
        end

        -- Validate RP
        if player.requisitionPoints and type(player.requisitionPoints) ~= "number" then
            table.insert(report.errors, string.format("Player %s RP must be a number", player.name))
        end

        if player.requisitionPoints and player.requisitionPoints < 0 then
            table.insert(report.warnings, string.format("Player %s has negative RP: %d", player.name, player.requisitionPoints))
        end

        -- Validate supply
        if player.supplyUsed and player.supplyLimit then
            if player.supplyUsed > player.supplyLimit then
                table.insert(report.warnings, string.format("Player %s over supply limit: %d/%d", player.name, player.supplyUsed, player.supplyLimit))
            end
        end

        -- Validate order of battle
        if player.orderOfBattle and type(player.orderOfBattle) ~= "table" then
            table.insert(report.errors, string.format("Player %s orderOfBattle must be a table", player.name))
        end
    end

    if playerCount == 0 then
        table.insert(report.warnings, "Campaign has no players")
    end
end

-- ============================================================================
-- UNIT VALIDATION
-- ============================================================================

--- Validate all units
-- @param campaign table Campaign data
-- @param report table Validation report
function DataValidator.validateUnits(campaign, report)
    if not campaign.units then
        return
    end

    local unitCount = 0
    local orphanedUnits = {}

    for unitId, unit in pairs(campaign.units) do
        unitCount = unitCount + 1

        -- Validate unit structure
        if not unit.id then
            table.insert(report.errors, "Unit missing ID")
        elseif unit.id ~= unitId then
            table.insert(report.errors, string.format("Unit ID mismatch: key=%s, id=%s", unitId, unit.id))
        end

        -- Required unit fields
        local requiredUnitFields = {"name", "unitType", "ownerId", "pointsCost", "experiencePoints", "rank", "crusadePoints"}

        for _, field in ipairs(requiredUnitFields) do
            if unit[field] == nil then
                table.insert(report.errors, string.format("Unit %s missing field: %s", unit.name or unitId, field))
            end
        end

        -- Validate owner exists
        if unit.ownerId then
            local owner = campaign.players[unit.ownerId]
            if not owner then
                table.insert(report.errors, string.format("Unit %s has invalid owner ID: %s", unit.name, unit.ownerId))
                table.insert(orphanedUnits, unitId)
            else
                -- Check if unit is in owner's order of battle
                local inOOB = false
                for _, oobUnitId in ipairs(owner.orderOfBattle) do
                    if oobUnitId == unitId then
                        inOOB = true
                        break
                    end
                end

                if not inOOB then
                    table.insert(report.warnings, string.format("Unit %s not in owner's order of battle", unit.name))
                end
            end
        end

        -- Validate XP and Rank
        if unit.experiencePoints and type(unit.experiencePoints) ~= "number" then
            table.insert(report.errors, string.format("Unit %s XP must be a number", unit.name))
        end

        if unit.experiencePoints and unit.experiencePoints < 0 then
            table.insert(report.warnings, string.format("Unit %s has negative XP: %d", unit.name, unit.experiencePoints))
        end

        if unit.rank and (unit.rank < 1 or unit.rank > 5) then
            table.insert(report.errors, string.format("Unit %s has invalid rank: %d (must be 1-5)", unit.name, unit.rank))
        end

        -- Validate points cost
        if unit.pointsCost and unit.pointsCost < 0 then
            table.insert(report.warnings, string.format("Unit %s has negative points cost: %d", unit.name, unit.pointsCost))
        end

        -- Validate battle honours and scars
        if unit.battleHonours and type(unit.battleHonours) ~= "table" then
            table.insert(report.errors, string.format("Unit %s battleHonours must be a table", unit.name))
        end

        if unit.battleScars and type(unit.battleScars) ~= "table" then
            table.insert(report.errors, string.format("Unit %s battleScars must be a table", unit.name))
        end

        -- Check battle scars limit
        if unit.battleScars and #unit.battleScars > 3 then
            table.insert(report.errors, string.format("Unit %s has more than 3 battle scars: %d", unit.name, #unit.battleScars))
        end
    end

    if #orphanedUnits > 0 then
        table.insert(report.warnings, string.format("Found %d orphaned units", #orphanedUnits))
    end
end

-- ============================================================================
-- BATTLE VALIDATION
-- ============================================================================

--- Validate all battles
-- @param campaign table Campaign data
-- @param report table Validation report
function DataValidator.validateBattles(campaign, report)
    if not campaign.battles then
        return
    end

    for i, battle in ipairs(campaign.battles) do
        -- Required battle fields (DataModel uses 'timestamp' not 'date')
        local requiredBattleFields = {"id", "timestamp", "participants", "missionType"}

        for _, field in ipairs(requiredBattleFields) do
            if battle[field] == nil then
                table.insert(report.errors, string.format("Battle #%d missing field: %s", i, field))
            end
        end

        -- Validate participants (participant objects have .playerId, not bare IDs)
        if battle.participants and type(battle.participants) ~= "table" then
            table.insert(report.errors, string.format("Battle #%d participants must be a table", i))
        elseif battle.participants then
            for _, participant in ipairs(battle.participants) do
                local pid = type(participant) == "table" and participant.playerId or participant
                if pid and not campaign.players[pid] then
                    table.insert(report.warnings, string.format("Battle #%d has invalid participant: %s", i, tostring(pid)))
                end
            end
        end

        -- Validate winner (DataModel uses 'winner' not 'winnerId')
        if battle.winner and not campaign.players[battle.winner] then
            table.insert(report.warnings, string.format("Battle #%d has invalid winner: %s", i, battle.winner))
        end
    end
end

-- ============================================================================
-- MAP VALIDATION
-- ============================================================================

--- Validate map configuration
-- @param campaign table Campaign data
-- @param report table Validation report
function DataValidator.validateMapConfig(campaign, report)
    local mapConfig = campaign.mapConfig

    if not mapConfig then
        return
    end

    -- Check required map fields (DataModel stores dimensions in mapConfig.dimensions)
    local dims = mapConfig.dimensions
    if not dims or not dims.width or not dims.height then
        table.insert(report.errors, "Map config missing dimensions.width or dimensions.height")
    end

    if dims and dims.width and (dims.width < 1 or dims.width > 50) then
        table.insert(report.warnings, string.format("Map width unusual: %d", dims.width))
    end

    if dims and dims.height and (dims.height < 1 or dims.height > 50) then
        table.insert(report.warnings, string.format("Map height unusual: %d", dims.height))
    end

    -- Validate hexes
    if mapConfig.hexes and type(mapConfig.hexes) ~= "table" then
        table.insert(report.errors, "Map hexes must be a table")
    end
end

-- ============================================================================
-- ALLIANCE VALIDATION
-- ============================================================================

--- Validate alliances
-- @param campaign table Campaign data
-- @param report table Validation report
function DataValidator.validateAlliances(campaign, report)
    if not campaign.alliances then
        return
    end

    for allianceId, alliance in pairs(campaign.alliances) do
        -- Check required fields
        if not alliance.id or not alliance.name or not alliance.members then
            table.insert(report.errors, string.format("Alliance '%s' missing required fields", tostring(allianceId)))
        end

        -- Validate members
        if alliance.members and type(alliance.members) ~= "table" then
            table.insert(report.errors, string.format("Alliance '%s' members must be a table", tostring(allianceId)))
        elseif alliance.members then
            for _, memberId in ipairs(alliance.members) do
                if not campaign.players[memberId] then
                    table.insert(report.warnings, string.format("Alliance %s has invalid member: %s", alliance.name or allianceId, memberId))
                end
            end
        end
    end
end

-- ============================================================================
-- REPORT GENERATION
-- ============================================================================

--- Generate a human-readable validation report
-- @param report table Validation report
-- @return string Formatted report
function DataValidator.generateReportText(report)
    if not report then
        return "No validation report available"
    end

    local text = string.format("=== VALIDATION REPORT ===\nTimestamp: %s\nStatus: %s\n\n",
        report.timestamp,
        report.isValid and "VALID" or "INVALID"
    )

    if #report.errors > 0 then
        text = text .. string.format("ERRORS (%d):\n", #report.errors)
        for i, error in ipairs(report.errors) do
            text = text .. string.format("  %d. %s\n", i, error)
        end
        text = text .. "\n"
    end

    if #report.warnings > 0 then
        text = text .. string.format("WARNINGS (%d):\n", #report.warnings)
        for i, warning in ipairs(report.warnings) do
            text = text .. string.format("  %d. %s\n", i, warning)
        end
        text = text .. "\n"
    end

    if #report.errors == 0 and #report.warnings == 0 then
        text = text .. "No issues found. Campaign data is valid.\n"
    end

    return text
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return DataValidator
