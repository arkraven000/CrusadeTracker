--[[
=====================================
INTEGRATION TESTS
=====================================
End-to-end tests that exercise multiple modules together:
- Full campaign lifecycle
- Battle recording workflow
- Post-battle XP + Out of Action flow
- Character vs non-Character progression
- Supply limit management
]]

local TTSMock = require("tests/tts_mock")
local T = require("tests/test_runner")
local Assert = T.Assert

local DataModel = require("src/core/DataModel")
local Constants = require("src/core/Constants")
local Utils = require("src/core/Utils")
local CrusadePoints = require("src/crusade/CrusadePoints")
local Experience = require("src/crusade/Experience")
local OutOfAction = require("src/crusade/OutOfAction")
local DataValidator = require("src/testing/DataValidator")
local SaveLoad = require("src/persistence/SaveLoad")

-- ============================================================================
-- CAMPAIGN LIFECYCLE
-- ============================================================================

T.suite("Integration - Campaign Lifecycle")

T.setup(function()
    TTSMock.resetAll()
end)

T.test("create campaign, add players, add units, validate", function()
    -- Create campaign
    local campaign = DataModel.createCampaign("Galactic War", {
        description = "A battle for the galaxy"
    })

    -- Add two players
    local p1 = DataModel.createPlayer("Alice", "Blue", "Space Marines", {
        forceName = "Ultramarines 3rd Company"
    })
    local p2 = DataModel.createPlayer("Bob", "Red", "Necrons", {
        forceName = "Szarekhan Dynasty"
    })
    campaign.players[p1.id] = p1
    campaign.players[p2.id] = p2

    -- Add units to Alice
    local u1 = DataModel.createUnit(p1.id, {
        name = "Intercessors",
        unitType = "Infantry",
        pointsCost = 100,
        battlefieldRole = "Troops",
        isBattleline = true
    })
    local u2 = DataModel.createUnit(p1.id, {
        name = "Captain Titus",
        unitType = "Infantry",
        pointsCost = 100,
        battlefieldRole = "HQ",
        isCharacter = true
    })
    campaign.units[u1.id] = u1
    campaign.units[u2.id] = u2
    table.insert(p1.orderOfBattle, u1.id)
    table.insert(p1.orderOfBattle, u2.id)

    -- Add units to Bob
    local u3 = DataModel.createUnit(p2.id, {
        name = "Warriors",
        unitType = "Infantry",
        pointsCost = 130,
        battlefieldRole = "Troops"
    })
    campaign.units[u3.id] = u3
    table.insert(p2.orderOfBattle, u3.id)

    -- Validate
    local isValid, report = DataValidator.validateCampaign(campaign)
    Assert.isTrue(isValid, "Campaign should be valid: " ..
        DataValidator.generateReportText(report))

    -- Check supply
    local supply1 = CrusadePoints.calculateSupplyUsed(p1, campaign.units)
    Assert.equals(200, supply1) -- 100 + 100

    local supply2 = CrusadePoints.calculateSupplyUsed(p2, campaign.units)
    Assert.equals(130, supply2)
end)

-- ============================================================================
-- BATTLE WORKFLOW
-- ============================================================================

T.suite("Integration - Battle Workflow")

T.setup(function()
    TTSMock.resetAll()
end)

T.test("record battle with XP awards and validate results", function()
    -- Setup campaign
    local campaign = DataModel.createCampaign("Battle Test")
    local p1 = DataModel.createPlayer("Alice", "Blue", "Marines")
    local p2 = DataModel.createPlayer("Bob", "Red", "Necrons")
    campaign.players[p1.id] = p1
    campaign.players[p2.id] = p2

    -- Create units
    local u1 = DataModel.createUnit(p1.id, {name = "Squad Alpha", pointsCost = 100})
    local u2 = DataModel.createUnit(p1.id, {name = "Captain", pointsCost = 100, isCharacter = true})
    local u3 = DataModel.createUnit(p2.id, {name = "Warriors", pointsCost = 130})
    campaign.units[u1.id] = u1
    campaign.units[u2.id] = u2
    campaign.units[u3.id] = u3
    table.insert(p1.orderOfBattle, u1.id)
    table.insert(p1.orderOfBattle, u2.id)
    table.insert(p2.orderOfBattle, u3.id)

    -- Record battle
    local battle = DataModel.createBattleRecord({
        battleSize = "Strike Force",
        missionType = "Search and Destroy",
        participants = {
            DataModel.createBattleParticipant(p1.id, {u1.id, u2.id}),
            DataModel.createBattleParticipant(p2.id, {u3.id})
        },
        winner = p1.id,
        markedForGreatness = {[p1.id] = u2.id}, -- Captain is marked
        combatTallies = {
            [u1.id] = {killsThisBattle = 3} -- Squad Alpha destroyed 3 units
        },
        destroyedUnits = {
            [p2.id] = {} -- No Bob units destroyed (simplified)
        }
    })
    table.insert(campaign.battles, battle)

    -- Process post-battle XP
    local summary = Experience.processPostBattleXP(battle, campaign.units, campaign.log)

    -- Verify Battle Experience (+1 to all)
    Assert.equals(1, u3.experiencePoints, "Warriors should have +1 battle XP")

    -- Verify Dealers of Death (u1 had 3 kills from 0, crosses 3rd threshold = +1 XP)
    -- u1 should have: 1 (battle) + 1 (dealers of death) = 2 XP
    Assert.equals(2, u1.experiencePoints, "Squad Alpha should have 2 XP (1 battle + 1 dealers)")

    -- Verify Marked for Greatness (u2 = Captain, +3 XP)
    -- u2 should have: 1 (battle) + 3 (marked) = 4 XP
    Assert.equals(4, u2.experiencePoints, "Captain should have 4 XP (1 battle + 3 marked)")

    -- Campaign should still be valid
    local isValid = DataValidator.validateCampaign(campaign)
    Assert.isTrue(isValid)
end)

-- ============================================================================
-- CHARACTER PROGRESSION
-- ============================================================================

T.suite("Integration - Character Progression Path")

T.test("CHARACTER unit progresses through all 5 ranks", function()
    local u = DataModel.createUnit("owner", {
        name = "Chapter Master",
        pointsCost = 200,
        isCharacter = true
    })

    local log = {}

    -- Rank 1: Battle-Ready (0 XP)
    Assert.equals(1, u.rank)

    -- Add XP to reach Rank 2: Blooded (6 XP)
    Experience.addXP(u, 6, "test", log)
    Assert.equals(2, u.rank)
    Assert.equals(6, u.experiencePoints)

    -- Add XP to reach Rank 3: Battle-Hardened (16 XP)
    Experience.addXP(u, 10, "test", log)
    Assert.equals(3, u.rank)
    Assert.equals(16, u.experiencePoints)

    -- Add XP to reach Rank 4: Heroic (31 XP)
    Experience.addXP(u, 15, "test", log)
    Assert.equals(4, u.rank)
    Assert.equals(31, u.experiencePoints)

    -- Add XP to reach Rank 5: Legendary (51 XP)
    Experience.addXP(u, 20, "test", log)
    Assert.equals(5, u.rank)
    Assert.equals(51, u.experiencePoints)

    -- Can still gain more XP past Legendary
    Experience.addXP(u, 10, "test", log)
    Assert.equals(61, u.experiencePoints)
    Assert.equals(5, u.rank) -- still Legendary
end)

-- ============================================================================
-- NON-CHARACTER PROGRESSION
-- ============================================================================

T.suite("Integration - Non-Character Progression Path")

T.test("non-CHARACTER caps at rank 3 and 30 XP", function()
    local u = DataModel.createUnit("owner", {
        name = "Intercessors",
        pointsCost = 100,
        isCharacter = false
    })

    local log = {}

    -- Progress to rank 3
    Experience.addXP(u, 16, "test", log)
    Assert.equals(3, u.rank) -- Battle-Hardened

    -- Try to exceed cap
    Experience.addXP(u, 20, "test", log) -- Would be 36, but capped at 30
    Assert.equals(30, u.experiencePoints)
    Assert.equals(3, u.rank) -- Still Battle-Hardened

    -- Can't gain more
    local success = Experience.addXP(u, 1, "test", log)
    Assert.isFalse(success)
    Assert.equals(30, u.experiencePoints)
end)

T.test("non-CHARACTER with Legendary Veterans breaks the cap", function()
    local u = DataModel.createUnit("owner", {
        name = "Veteran Squad",
        pointsCost = 100,
        isCharacter = false
    })

    local log = {}

    -- Get to 30 XP
    Experience.addXP(u, 30, "test", log)
    Assert.equals(30, u.experiencePoints)
    Assert.equals(3, u.rank)

    -- Apply Legendary Veterans
    local success = Experience.applyLegendaryVeterans(u, log)
    Assert.isTrue(success)

    -- Now can gain more XP
    Experience.addXP(u, 5, "test", log)
    Assert.equals(35, u.experiencePoints)
    Assert.equals(4, u.rank) -- Heroic (31+ XP with LV)
end)

-- ============================================================================
-- OUT OF ACTION INTEGRATION
-- ============================================================================

T.suite("Integration - Out of Action Flow")

T.test("unit survives out of action with devastating blow", function()
    local trait = DataModel.createBattleHonour("Battle Trait", {name = "Lethal Sharpshooter"})
    local u = DataModel.createUnit("owner", {
        name = "Survivors",
        pointsCost = 100
    })
    table.insert(u.battleHonours, trait)
    CrusadePoints.updateUnitCrusadePoints(u)
    Assert.equals(1, u.crusadePoints)

    -- Apply Devastating Blow
    local success = OutOfAction.applyOutOfActionConsequence(
        u, "Devastating Blow", {honourIndex = 1}, {}
    )
    Assert.isTrue(success)
    Assert.arrayLength(u.battleHonours, 0)
    Assert.equals(0, u.crusadePoints)
    Assert.isNil(u._markedForDeletion) -- unit survives
end)

T.test("unit destroyed when no honours remain", function()
    local u = DataModel.createUnit("owner", {name = "Doomed"})

    local success = OutOfAction.applyOutOfActionConsequence(
        u, "Devastating Blow", {honourIndex = nil}, {}
    )
    Assert.isTrue(success)
    Assert.isTrue(u._markedForDeletion)
end)

T.test("unit accumulates scars across battles", function()
    local u = DataModel.createUnit("owner", {name = "Scarred"})

    -- Battle 1: gain scar
    OutOfAction.applyBattleScar(u, 1, {})
    Assert.arrayLength(u.battleScars, 1)

    -- Battle 2: gain different scar
    OutOfAction.applyBattleScar(u, 2, {})
    Assert.arrayLength(u.battleScars, 2)

    -- Battle 3: gain third scar
    OutOfAction.applyBattleScar(u, 3, {})
    Assert.arrayLength(u.battleScars, 3)

    -- Battle 4: can't gain more scars
    local success = OutOfAction.applyBattleScar(u, 4, {})
    Assert.isFalse(success)
    Assert.arrayLength(u.battleScars, 3)

    -- CP should reflect 3 scars
    CrusadePoints.updateUnitCrusadePoints(u)
    Assert.equals(-3, u.crusadePoints)
end)

-- ============================================================================
-- FULL BATTLE + OOA FLOW
-- ============================================================================

T.suite("Integration - Complete Battle Flow")

T.test("full battle with XP, kills, and OOA consequences", function()
    -- Setup
    local campaign = DataModel.createCampaign("Full Battle Test")
    local p1 = DataModel.createPlayer("Alice", "Blue", "Marines")
    campaign.players[p1.id] = p1

    local hero = DataModel.createUnit(p1.id, {
        name = "Hero Captain",
        pointsCost = 100,
        isCharacter = true
    })
    local troops = DataModel.createUnit(p1.id, {
        name = "Tactical Squad",
        pointsCost = 100
    })
    -- Give troops a Battle Trait
    table.insert(troops.battleHonours, DataModel.createBattleHonour("Battle Trait", {
        name = "Melee Expert"
    }))
    CrusadePoints.updateUnitCrusadePoints(troops)

    campaign.units[hero.id] = hero
    campaign.units[troops.id] = troops
    table.insert(p1.orderOfBattle, hero.id)
    table.insert(p1.orderOfBattle, troops.id)

    -- Battle
    local battle = DataModel.createBattleRecord({
        battleSize = "Strike Force",
        missionType = "Annihilation",
        participants = {
            DataModel.createBattleParticipant(p1.id, {hero.id, troops.id})
        },
        winner = p1.id,
        markedForGreatness = {[p1.id] = hero.id},
        combatTallies = {
            [hero.id] = {killsThisBattle = 6}, -- 6 kills!
            [troops.id] = {killsThisBattle = 2}
        }
    })

    -- Process XP
    Experience.processPostBattleXP(battle, campaign.units, campaign.log)

    -- Hero: +1 (battle) + 2 (dealers: 6 kills crosses 3rd and 6th) + 3 (marked) = 6 XP
    Assert.equals(6, hero.experiencePoints, "Hero should have 6 XP")
    Assert.equals(2, hero.rank, "Hero should be Blooded (rank 2) at 6 XP")

    -- Troops: +1 (battle) + 0 (dealers: 2 kills, no threshold) = 1 XP
    Assert.equals(1, troops.experiencePoints, "Troops should have 1 XP")

    -- Troops took damage, apply OOA consequence: Battle Scar
    OutOfAction.applyBattleScar(troops, 1, campaign.log)
    Assert.arrayLength(troops.battleScars, 1)

    -- CP check: troops had 1 honour (+1) and now 1 scar (-1) = 0 CP
    CrusadePoints.updateUnitCrusadePoints(troops)
    Assert.equals(0, troops.crusadePoints)

    -- Campaign should still be valid
    local isValid = DataValidator.validateCampaign(campaign)
    Assert.isTrue(isValid)
end)

-- ============================================================================
-- EXPORT/IMPORT ROUND-TRIP WITH FULL DATA
-- ============================================================================

T.suite("Integration - Export/Import Round-Trip")

T.test("full campaign export and re-import preserves integrity", function()
    -- Build a campaign with rich data
    local campaign = DataModel.createCampaign("Export Test")

    local p = DataModel.createPlayer("Alice", "Blue", "Marines")
    campaign.players[p.id] = p

    local u = DataModel.createUnit(p.id, {
        name = "Veterans",
        pointsCost = 150,
        isCharacter = false
    })
    u.experiencePoints = 20
    u.rank = 3
    table.insert(u.battleHonours, DataModel.createBattleHonour("Battle Trait", {
        name = "Inspiring Leader"
    }))
    table.insert(u.battleScars, DataModel.createBattleScar({name = "Crippling Damage"}))
    CrusadePoints.updateUnitCrusadePoints(u)

    campaign.units[u.id] = u
    table.insert(p.orderOfBattle, u.id)

    -- Add battle record
    local battle = DataModel.createBattleRecord({
        battleSize = "Strike Force",
        missionType = "Take and Hold",
        participants = {DataModel.createBattleParticipant(p.id, {u.id})}
    })
    table.insert(campaign.battles, battle)

    -- Export
    local json = SaveLoad.exportCampaignJSON(campaign)
    Assert.isNotNil(json)

    -- Import
    local imported = SaveLoad.importCampaignJSON(json)
    Assert.isNotNil(imported)

    -- Validate imported campaign
    local isValid, report = DataValidator.validateCampaign(imported)
    Assert.isTrue(isValid, "Imported campaign should be valid: " ..
        DataValidator.generateReportText(report))

    -- Verify data preservation
    Assert.equals("Export Test", imported.name)
    local importedUnit = imported.units[u.id]
    Assert.isNotNil(importedUnit)
    Assert.equals("Veterans", importedUnit.name)
    Assert.equals(20, importedUnit.experiencePoints)
    Assert.equals(3, importedUnit.rank)
    Assert.equals(1, #importedUnit.battleHonours)
    Assert.equals(1, #importedUnit.battleScars)
end)

-- ============================================================================
-- SUPPLY LIMIT MANAGEMENT
-- ============================================================================

T.suite("Integration - Supply Limit Management")

T.test("supply tracking across unit changes", function()
    local campaign = DataModel.createCampaign("Supply Test")
    local p = DataModel.createPlayer("Alice", "Blue", "Marines")
    p.supplyLimit = 500
    campaign.players[p.id] = p

    -- Add units
    local u1 = DataModel.createUnit(p.id, {name = "Unit A", pointsCost = 200})
    local u2 = DataModel.createUnit(p.id, {name = "Unit B", pointsCost = 150})
    campaign.units[u1.id] = u1
    campaign.units[u2.id] = u2
    table.insert(p.orderOfBattle, u1.id)
    table.insert(p.orderOfBattle, u2.id)

    -- Check supply: 200 + 150 = 350 / 500
    local isOver, used, limit = CrusadePoints.checkSupplyLimit(p, campaign.units)
    Assert.isFalse(isOver)
    Assert.equals(350, used)
    Assert.equals(500, limit)

    -- Add expensive unit that puts us over
    local u3 = DataModel.createUnit(p.id, {name = "Unit C", pointsCost = 200})
    campaign.units[u3.id] = u3
    table.insert(p.orderOfBattle, u3.id)

    -- Now 200 + 150 + 200 = 550 > 500
    isOver = CrusadePoints.checkSupplyLimit(p, campaign.units)
    Assert.isTrue(isOver)
end)

-- ============================================================================
-- CONSTANTS INTEGRITY
-- ============================================================================

T.suite("Integration - Constants Integrity")

T.test("rank thresholds are ordered correctly", function()
    local thresholds = Constants.RANK_THRESHOLDS
    for i = 2, #thresholds do
        Assert.isTrue(
            thresholds[i].minXP > thresholds[i-1].minXP,
            "Rank thresholds must be in ascending XP order"
        )
        Assert.equals(i, thresholds[i].rank, "Rank numbers must be sequential")
    end
end)

T.test("battle scars are numbered 1-6", function()
    Assert.arrayLength(Constants.BATTLE_SCARS, 6)
    for i = 1, 6 do
        Assert.equals(i, Constants.BATTLE_SCARS[i].id)
        Assert.isNotNil(Constants.BATTLE_SCARS[i].name)
    end
end)

T.test("weapon modifications are numbered 1-6", function()
    Assert.arrayLength(Constants.WEAPON_MODIFICATIONS, 6)
    for i = 1, 6 do
        Assert.equals(i, Constants.WEAPON_MODIFICATIONS[i].id)
    end
end)

T.test("relic tiers have correct CP costs", function()
    Assert.equals(1, Constants.RELIC_TIERS.Artificer.crusadePointsCost)
    Assert.equals(2, Constants.RELIC_TIERS.Antiquity.crusadePointsCost)
    Assert.equals(3, Constants.RELIC_TIERS.Legendary.crusadePointsCost)
end)

T.test("relic tiers have correct rank requirements", function()
    Assert.equals(1, Constants.RELIC_TIERS.Artificer.rankRequired)
    Assert.equals(4, Constants.RELIC_TIERS.Antiquity.rankRequired)
    Assert.equals(5, Constants.RELIC_TIERS.Legendary.rankRequired)
end)

T.test("player colors has 12 entries", function()
    local count = 0
    for _ in pairs(Constants.PLAYER_COLORS) do count = count + 1 end
    Assert.equals(12, count)
    Assert.arrayLength(Constants.PLAYER_COLOR_NAMES, 12)
end)

return T
