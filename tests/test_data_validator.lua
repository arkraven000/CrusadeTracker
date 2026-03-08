--[[
=====================================
DATA VALIDATOR TESTS
=====================================
Tests for campaign data integrity validation.
]]

require("tests/tts_mock")
local T = require("tests/test_runner")
local Assert = T.Assert

local DataValidator = require("src/testing/DataValidator")
local DataModel = require("src/core/DataModel")
local Constants = require("src/core/Constants")

-- Helper: create a valid campaign with players and units
local function makeValidCampaign()
    local campaign = DataModel.createCampaign("Test Campaign")
    local player = DataModel.createPlayer("Alice", "Blue", "Space Marines")
    campaign.players[player.id] = player

    local unit = DataModel.createUnit(player.id, {
        name = "Intercessors",
        unitType = "Infantry",
        pointsCost = 100
    })
    campaign.units[unit.id] = unit
    table.insert(player.orderOfBattle, unit.id)

    return campaign, player, unit
end

-- ============================================================================
-- CAMPAIGN VALIDATION
-- ============================================================================

T.suite("DataValidator - Campaign Validation")

T.test("valid campaign passes validation", function()
    local campaign = makeValidCampaign()
    local isValid, report = DataValidator.validateCampaign(campaign)
    Assert.isTrue(isValid)
    Assert.arrayLength(report.errors, 0)
end)

T.test("nil campaign fails validation", function()
    local isValid, report = DataValidator.validateCampaign(nil)
    Assert.isFalse(isValid)
    Assert.isTrue(#report.errors > 0)
end)

T.test("missing required fields detected", function()
    local campaign = {name = "Incomplete"}
    local isValid, report = DataValidator.validateCampaign(campaign)
    Assert.isFalse(isValid)
    -- Should detect missing id, createdDate, players, units, battles, log
    Assert.isTrue(#report.errors > 0)
end)

-- ============================================================================
-- CAMPAIGN STRUCTURE VALIDATION
-- ============================================================================

T.suite("DataValidator - Campaign Structure")

T.test("validates required campaign fields", function()
    local report = {errors = {}, warnings = {}}
    local campaign = {id = "123", name = "Test"}
    -- Missing createdDate, players, units, battles, log
    DataValidator.validateCampaignStructure(campaign, report)
    Assert.isTrue(#report.errors >= 4)
end)

T.test("validates field types", function()
    local report = {errors = {}, warnings = {}}
    local campaign = {
        id = "123", name = "Test", createdDate = 123,
        players = "not a table",
        units = {},
        battles = {},
        log = {}
    }
    DataValidator.validateCampaignStructure(campaign, report)
    -- Should detect players is not a table
    local foundError = false
    for _, err in ipairs(report.errors) do
        if err:find("players must be a table") then foundError = true end
    end
    Assert.isTrue(foundError)
end)

-- ============================================================================
-- PLAYER VALIDATION
-- ============================================================================

T.suite("DataValidator - Player Validation")

T.test("valid player passes", function()
    local campaign = makeValidCampaign()
    local report = {errors = {}, warnings = {}}
    DataValidator.validatePlayers(campaign, report)
    Assert.arrayLength(report.errors, 0)
end)

T.test("player ID mismatch detected", function()
    local campaign = DataModel.createCampaign("Test")
    local player = DataModel.createPlayer("Alice", "Blue", "Marines")
    campaign.players["wrong_key"] = player
    local report = {errors = {}, warnings = {}}
    DataValidator.validatePlayers(campaign, report)
    -- Should detect player.id != key
    Assert.isTrue(#report.errors > 0)
end)

T.test("missing player fields detected", function()
    local campaign = DataModel.createCampaign("Test")
    campaign.players["p1"] = {id = "p1", name = "Alice"}
    -- Missing color, faction, requisitionPoints, etc.
    local report = {errors = {}, warnings = {}}
    DataValidator.validatePlayers(campaign, report)
    Assert.isTrue(#report.errors > 0)
end)

T.test("negative RP generates warning", function()
    local campaign = makeValidCampaign()
    local playerId = next(campaign.players)
    campaign.players[playerId].requisitionPoints = -1
    local report = {errors = {}, warnings = {}}
    DataValidator.validatePlayers(campaign, report)
    local found = false
    for _, w in ipairs(report.warnings) do
        if w:find("negative RP") then found = true end
    end
    Assert.isTrue(found)
end)

T.test("empty campaign warns no players", function()
    local campaign = DataModel.createCampaign("Empty")
    local report = {errors = {}, warnings = {}}
    DataValidator.validatePlayers(campaign, report)
    local found = false
    for _, w in ipairs(report.warnings) do
        if w:find("no players") then found = true end
    end
    Assert.isTrue(found)
end)

-- ============================================================================
-- UNIT VALIDATION
-- ============================================================================

T.suite("DataValidator - Unit Validation")

T.test("valid unit passes", function()
    local campaign = makeValidCampaign()
    local report = {errors = {}, warnings = {}}
    DataValidator.validateUnits(campaign, report)
    Assert.arrayLength(report.errors, 0)
end)

T.test("unit ID mismatch detected", function()
    local campaign, player = makeValidCampaign()
    local unit = DataModel.createUnit(player.id, {name = "Bad Unit", unitType = "Infantry", pointsCost = 100})
    campaign.units["wrong_key"] = unit
    local report = {errors = {}, warnings = {}}
    DataValidator.validateUnits(campaign, report)
    Assert.isTrue(#report.errors > 0)
end)

T.test("orphaned unit detected (owner doesn't exist)", function()
    local campaign = makeValidCampaign()
    local orphan = DataModel.createUnit("nonexistent_owner", {
        name = "Orphan",
        unitType = "Infantry",
        pointsCost = 100
    })
    campaign.units[orphan.id] = orphan
    local report = {errors = {}, warnings = {}}
    DataValidator.validateUnits(campaign, report)
    Assert.isTrue(#report.errors > 0)
end)

T.test("invalid rank detected", function()
    local campaign, _, unit = makeValidCampaign()
    unit.rank = 10 -- invalid
    local report = {errors = {}, warnings = {}}
    DataValidator.validateUnits(campaign, report)
    local found = false
    for _, err in ipairs(report.errors) do
        if err:find("invalid rank") then found = true end
    end
    Assert.isTrue(found)
end)

T.test("too many battle scars detected", function()
    local campaign, _, unit = makeValidCampaign()
    unit.battleScars = {
        DataModel.createBattleScar({name = "S1"}),
        DataModel.createBattleScar({name = "S2"}),
        DataModel.createBattleScar({name = "S3"}),
        DataModel.createBattleScar({name = "S4"}) -- more than 3!
    }
    local report = {errors = {}, warnings = {}}
    DataValidator.validateUnits(campaign, report)
    local found = false
    for _, err in ipairs(report.errors) do
        if err:find("more than 3 battle scars") then found = true end
    end
    Assert.isTrue(found)
end)

-- ============================================================================
-- BATTLE VALIDATION
-- ============================================================================

T.suite("DataValidator - Battle Validation")

T.test("valid battle passes", function()
    local campaign, player = makeValidCampaign()
    local battle = DataModel.createBattleRecord({
        battleSize = "Strike Force",
        missionType = "Search and Destroy",
        participants = {DataModel.createBattleParticipant(player.id, {})}
    })
    table.insert(campaign.battles, battle)
    local report = {errors = {}, warnings = {}}
    DataValidator.validateBattles(campaign, report)
    Assert.arrayLength(report.errors, 0)
end)

T.test("battle with invalid participant warns", function()
    local campaign = makeValidCampaign()
    local battle = DataModel.createBattleRecord({
        battleSize = "Strike Force",
        missionType = "Test",
        participants = {DataModel.createBattleParticipant("nonexistent_player", {})}
    })
    table.insert(campaign.battles, battle)
    local report = {errors = {}, warnings = {}}
    DataValidator.validateBattles(campaign, report)
    Assert.isTrue(#report.warnings > 0)
end)

-- ============================================================================
-- MAP VALIDATION
-- ============================================================================

T.suite("DataValidator - Map Validation")

T.test("valid map config passes", function()
    local campaign = makeValidCampaign()
    campaign.mapConfig = DataModel.createHexMapConfig(7, 7)
    local report = {errors = {}, warnings = {}}
    DataValidator.validateMapConfig(campaign, report)
    Assert.arrayLength(report.errors, 0)
end)

T.test("missing map dimensions detected", function()
    local campaign = makeValidCampaign()
    campaign.mapConfig = {hexes = {}}
    local report = {errors = {}, warnings = {}}
    DataValidator.validateMapConfig(campaign, report)
    Assert.isTrue(#report.errors > 0)
end)

-- ============================================================================
-- ALLIANCE VALIDATION
-- ============================================================================

T.suite("DataValidator - Alliance Validation")

T.test("valid alliance passes", function()
    local campaign, player = makeValidCampaign()
    local alliance = DataModel.createAlliance("Seekers", {player.id})
    campaign.alliances[alliance.id] = alliance
    local report = {errors = {}, warnings = {}}
    DataValidator.validateAlliances(campaign, report)
    Assert.arrayLength(report.errors, 0)
end)

T.test("alliance with invalid member warns", function()
    local campaign = makeValidCampaign()
    local alliance = DataModel.createAlliance("Bad Alliance", {"nonexistent"})
    campaign.alliances[alliance.id] = alliance
    local report = {errors = {}, warnings = {}}
    DataValidator.validateAlliances(campaign, report)
    Assert.isTrue(#report.warnings > 0)
end)

-- ============================================================================
-- REPORT GENERATION
-- ============================================================================

T.suite("DataValidator - Report Generation")

T.test("generateReportText produces readable output", function()
    local campaign = makeValidCampaign()
    local _, report = DataValidator.validateCampaign(campaign)
    local text = DataValidator.generateReportText(report)
    Assert.isType(text, "string")
    Assert.contains(text, "VALIDATION REPORT")
    Assert.contains(text, "VALID")
end)

T.test("generateReportText handles nil report", function()
    local text = DataValidator.generateReportText(nil)
    Assert.contains(text, "No validation report")
end)

T.test("generateReportText shows errors", function()
    local _, report = DataValidator.validateCampaign(nil)
    local text = DataValidator.generateReportText(report)
    Assert.contains(text, "INVALID")
    Assert.contains(text, "ERRORS")
end)

return T
