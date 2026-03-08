--[[
=====================================
DATA MODEL TESTS
=====================================
Tests for all factory functions in DataModel.lua
]]

require("tests/tts_mock")
local T = require("tests/test_runner")
local Assert = T.Assert

local DataModel = require("src/core/DataModel")
local Constants = require("src/core/Constants")

-- ============================================================================
-- CAMPAIGN CREATION
-- ============================================================================

T.suite("DataModel.createCampaign")

T.test("creates campaign with required fields", function()
    local c = DataModel.createCampaign("Test Campaign")
    Assert.isNotNil(c)
    Assert.equals("Test Campaign", c.name)
    Assert.isNotNil(c.id)
    Assert.isNotNil(c.createdDate)
    Assert.equals(Constants.CAMPAIGN_VERSION, c.version)
    Assert.equals(Constants.EDITION, c.edition)
end)

T.test("campaign has correct default values", function()
    local c = DataModel.createCampaign("Test")
    Assert.equals("", c.description)
    Assert.equals(Constants.DEFAULT_SUPPLY_LIMIT, c.supplyLimitDefault)
    Assert.isType(c.players, "table")
    Assert.isType(c.units, "table")
    Assert.isType(c.battles, "table")
    Assert.isType(c.log, "table")
    Assert.isNil(c.mapConfig)
    Assert.equals("none", c.crusadeSupplement)
    Assert.equals(0, c.currentBackupIndex)
end)

T.test("campaign accepts config overrides", function()
    local c = DataModel.createCampaign("Custom", {
        description = "A test campaign",
        supplyLimit = 2000,
        missionPack = "Leviathan",
        crusadeSupplement = "pariah_nexus"
    })
    Assert.equals("A test campaign", c.description)
    Assert.equals(2000, c.supplyLimitDefault)
    Assert.equals("Leviathan", c.missionPack)
    Assert.equals("pariah_nexus", c.crusadeSupplement)
end)

T.test("each campaign gets unique ID", function()
    local c1 = DataModel.createCampaign("One")
    local c2 = DataModel.createCampaign("Two")
    Assert.notEquals(c1.id, c2.id)
end)

-- ============================================================================
-- PLAYER CREATION
-- ============================================================================

T.suite("DataModel.createPlayer")

T.test("creates player with required fields", function()
    local p = DataModel.createPlayer("Alice", "Blue", "Space Marines")
    Assert.isNotNil(p)
    Assert.equals("Alice", p.name)
    Assert.equals("Blue", p.color)
    Assert.equals("Space Marines", p.faction)
    Assert.isNotNil(p.id)
end)

T.test("player has correct defaults", function()
    local p = DataModel.createPlayer("Bob", "Red", "Necrons")
    Assert.equals("", p.forceName)
    Assert.equals("", p.subfaction)
    Assert.equals("", p.detachment)
    Assert.equals(Constants.DEFAULT_SUPPLY_LIMIT, p.supplyLimit)
    Assert.equals(0, p.supplyUsed)
    Assert.equals(Constants.STARTING_RP, p.requisitionPoints)
    Assert.equals(0, p.battleTally)
    Assert.equals(0, p.victories)
    Assert.isType(p.orderOfBattle, "table")
    Assert.arrayLength(p.orderOfBattle, 0)
end)

T.test("player accepts config overrides", function()
    local p = DataModel.createPlayer("Carol", "Green", "Orks", {
        forceName = "Da Boyz",
        subfaction = "Goffs",
        detachment = "Waaagh!",
        supplyLimit = 1500
    })
    Assert.equals("Da Boyz", p.forceName)
    Assert.equals("Goffs", p.subfaction)
    Assert.equals("Waaagh!", p.detachment)
    Assert.equals(1500, p.supplyLimit)
end)

T.test("starting RP matches 10th Edition rules (5 RP)", function()
    local p = DataModel.createPlayer("Test", "White", "Test Faction")
    Assert.equals(5, p.requisitionPoints)
end)

-- ============================================================================
-- UNIT CREATION
-- ============================================================================

T.suite("DataModel.createUnit")

T.test("creates unit with required fields", function()
    local u = DataModel.createUnit("owner123", {name = "Intercessors", pointsCost = 100})
    Assert.isNotNil(u)
    Assert.equals("Intercessors", u.name)
    Assert.equals(100, u.pointsCost)
    Assert.equals("owner123", u.ownerId)
    Assert.isNotNil(u.id)
end)

T.test("unit has correct progression defaults", function()
    local u = DataModel.createUnit("owner", {name = "Test"})
    Assert.equals(0, u.experiencePoints)
    Assert.equals(1, u.rank)
    Assert.equals(0, u.crusadePoints)
    Assert.isFalse(u.hasLegendaryVeterans)
end)

T.test("unit has correct type flag defaults", function()
    local u = DataModel.createUnit("owner", {name = "Test"})
    Assert.isFalse(u.isCharacter)
    Assert.isFalse(u.isTitanic)
    Assert.isFalse(u.isEpicHero)
    Assert.isFalse(u.isBattleline)
    Assert.isFalse(u.isDedicatedTransport)
    Assert.isTrue(u.canGainXP) -- default true
end)

T.test("unit type flags can be set", function()
    local u = DataModel.createUnit("owner", {
        name = "Captain",
        isCharacter = true,
        isTitanic = false
    })
    Assert.isTrue(u.isCharacter)
    Assert.isFalse(u.isTitanic)
end)

T.test("TITANIC unit flag works", function()
    local u = DataModel.createUnit("owner", {
        name = "Knight",
        isTitanic = true
    })
    Assert.isTrue(u.isTitanic)
end)

T.test("unit has empty collections", function()
    local u = DataModel.createUnit("owner", {name = "Test"})
    Assert.arrayLength(u.battleHonours, 0)
    Assert.arrayLength(u.battleScars, 0)
    Assert.isNil(u.enhancement)
    Assert.arrayLength(u.weaponModifications, 0)
    Assert.arrayLength(u.crusadeRelics, 0)
end)

T.test("unit combat tallies initialized correctly", function()
    local u = DataModel.createUnit("owner", {name = "Test"})
    Assert.equals(0, u.combatTallies.battlesParticipated)
    Assert.equals(0, u.combatTallies.unitsDestroyed)
end)

T.test("enhancement is singular (not array)", function()
    local u = DataModel.createUnit("owner", {name = "Test"})
    Assert.isNil(u.enhancement, "enhancement should be nil by default, not an empty table")
end)

-- ============================================================================
-- BATTLE HONOUR CREATION
-- ============================================================================

T.suite("DataModel.createBattleHonour")

T.test("creates Battle Trait honour", function()
    local h = DataModel.createBattleHonour("Battle Trait", {
        name = "Inspiring Leader",
        description = "Units within 6\" can use this unit's Leadership"
    })
    Assert.equals("Battle Trait", h.category)
    Assert.equals("Inspiring Leader", h.name)
    Assert.equals(1, h.crusadePointsCost)
    Assert.isNotNil(h.acquiredDate)
end)

T.test("creates Weapon Modification honour", function()
    local h = DataModel.createBattleHonour("Weapon Modification", {
        name = "Modified Bolt Rifle",
        weaponName = "Bolt Rifle",
        modelIndex = 1,
        modifications = {"Brutal", "Armour Piercing"}
    })
    Assert.equals("Weapon Modification", h.category)
    Assert.equals("Bolt Rifle", h.weaponName)
    Assert.equals(1, h.modelIndex)
    Assert.arrayLength(h.modifications, 2)
end)

T.test("creates Crusade Relic honour", function()
    local h = DataModel.createBattleHonour("Crusade Relic", {
        name = "Blade of Valor",
        tier = "Artificer",
        crusadePointsCost = 1,
        rankRequired = 1
    })
    Assert.equals("Crusade Relic", h.category)
    Assert.equals("Artificer", h.tier)
    Assert.equals(1, h.crusadePointsCost)
    Assert.equals(1, h.rankRequired)
end)

T.test("Legendary relic has CP cost 3", function()
    local h = DataModel.createBattleHonour("Crusade Relic", {
        name = "Sword of the Imperium",
        tier = "Legendary",
        crusadePointsCost = 3,
        rankRequired = 5
    })
    Assert.equals(3, h.crusadePointsCost)
    Assert.equals(5, h.rankRequired)
end)

-- ============================================================================
-- BATTLE SCAR CREATION
-- ============================================================================

T.suite("DataModel.createBattleScar")

T.test("creates battle scar with defaults", function()
    local s = DataModel.createBattleScar({name = "Crippling Damage"})
    Assert.equals("Crippling Damage", s.name)
    Assert.equals("out_of_action", s.acquiredBy)
    Assert.isNotNil(s.acquiredDate)
end)

-- ============================================================================
-- BATTLE RECORD CREATION
-- ============================================================================

T.suite("DataModel.createBattleRecord")

T.test("creates battle record with required fields", function()
    local b = DataModel.createBattleRecord({
        battleSize = "Strike Force",
        missionType = "Search and Destroy"
    })
    Assert.isNotNil(b.id)
    Assert.isNotNil(b.timestamp)
    Assert.equals("Strike Force", b.battleSize)
    Assert.equals("Search and Destroy", b.missionType)
end)

T.test("battle record has empty collections by default", function()
    local b = DataModel.createBattleRecord({battleSize = "Incursion"})
    Assert.isType(b.participants, "table")
    Assert.isType(b.destroyedUnits, "table")
    Assert.isType(b.markedForGreatness, "table")
    Assert.isType(b.combatTallies, "table")
    Assert.isFalse(b.isDraw)
    Assert.isNil(b.winner)
end)

-- ============================================================================
-- HEX MAP CREATION
-- ============================================================================

T.suite("DataModel.createHexMapConfig")

T.test("creates hex map config", function()
    local m = DataModel.createHexMapConfig(7, 7)
    Assert.equals(7, m.dimensions.width)
    Assert.equals(7, m.dimensions.height)
    Assert.isType(m.hexes, "table")
end)

T.test("creates hex with coordinates", function()
    local h = DataModel.createHex(3, 4)
    Assert.equals(3, h.coordinate.q)
    Assert.equals(4, h.coordinate.r)
    Assert.isNil(h.controlledBy, "hex should start uncontrolled")
    Assert.isFalse(h.active)
end)

-- ============================================================================
-- ALLIANCE CREATION
-- ============================================================================

T.suite("DataModel.createAlliance")

T.test("creates alliance", function()
    local a = DataModel.createAlliance("Seekers", {"p1", "p2"})
    Assert.equals("Seekers", a.name)
    Assert.arrayLength(a.members, 2)
    Assert.isFalse(a.shareTerritory)
    Assert.isFalse(a.shareResources)
end)

T.test("alliances are keyed by ID (not indexed)", function()
    local a = DataModel.createAlliance("Test", {})
    Assert.isNotNil(a.id, "alliance must have an id for keyed storage")
end)

-- ============================================================================
-- EVENT LOG ENTRY
-- ============================================================================

T.suite("DataModel.createEventLogEntry")

T.test("creates event log entry", function()
    local e = DataModel.createEventLogEntry("CAMPAIGN_CREATED", {name = "My Campaign"})
    Assert.equals("CAMPAIGN_CREATED", e.type)
    Assert.equals("My Campaign", e.details.name)
    Assert.isNotNil(e.timestamp)
    Assert.isNotNil(e.timestampFormatted)
    Assert.isTrue(e.visibleToAll)
end)

return T
