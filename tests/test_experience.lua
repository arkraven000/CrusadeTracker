--[[
=====================================
EXPERIENCE & RANK TESTS
=====================================
Tests for XP awards, rank progression, and XP caps (10th Edition).

Three XP Award Types:
1. Battle Experience: +1 XP to ALL participating units
2. Dealers of Death: +1 XP per third enemy unit destroyed (lifetime tally)
3. Marked for Greatness: +3 XP to ONE selected unit per player per battle
]]

require("tests/tts_mock")
local T = require("tests/test_runner")
local Assert = T.Assert

local Experience = require("src/crusade/Experience")
local DataModel = require("src/core/DataModel")
local Constants = require("src/core/Constants")

-- Helper: create a test unit
local function makeUnit(opts)
    opts = opts or {}
    local u = DataModel.createUnit("testOwner", {
        name = opts.name or "Test Unit",
        pointsCost = opts.pointsCost or 100,
        isCharacter = opts.isCharacter or false
    })
    if opts.xp then u.experiencePoints = opts.xp end
    if opts.rank then u.rank = opts.rank end
    if opts.hasLegendaryVeterans then u.hasLegendaryVeterans = true end
    if opts.canGainXP == false then u.canGainXP = false end
    if opts.battleScars then u.battleScars = opts.battleScars end
    return u
end

-- ============================================================================
-- RANK CALCULATION
-- ============================================================================

T.suite("Experience - Rank Calculation")

T.test("0 XP = Rank 1 (Battle-Ready)", function()
    local rank, name = Experience.calculateRank(0, false, false)
    Assert.equals(1, rank)
    Assert.equals("Battle-Ready", name)
end)

T.test("6 XP = Rank 2 (Blooded)", function()
    local rank, name = Experience.calculateRank(6, false, false)
    Assert.equals(2, rank)
    Assert.equals("Blooded", name)
end)

T.test("16 XP = Rank 3 (Battle-Hardened)", function()
    local rank, name = Experience.calculateRank(16, false, false)
    Assert.equals(3, rank)
    Assert.equals("Battle-Hardened", name)
end)

T.test("non-CHARACTER caps at rank 3 (Battle-Hardened)", function()
    local rank, name = Experience.calculateRank(50, false, false)
    Assert.equals(3, rank)
    Assert.equals("Battle-Hardened", name)
end)

T.test("CHARACTER at 31 XP = Rank 4 (Heroic)", function()
    local rank, name = Experience.calculateRank(31, true, false)
    Assert.equals(4, rank)
    Assert.equals("Heroic", name)
end)

T.test("CHARACTER at 51 XP = Rank 5 (Legendary)", function()
    local rank, name = Experience.calculateRank(51, true, false)
    Assert.equals(5, rank)
    Assert.equals("Legendary", name)
end)

T.test("Legendary Veterans non-CHARACTER can reach Heroic", function()
    local rank, name = Experience.calculateRank(31, false, true)
    Assert.equals(4, rank)
    Assert.equals("Heroic", name)
end)

T.test("Legendary Veterans non-CHARACTER can reach Legendary", function()
    local rank, name = Experience.calculateRank(51, false, true)
    Assert.equals(5, rank)
    Assert.equals("Legendary", name)
end)

T.test("5 XP = still Rank 1 (below Blooded threshold)", function()
    local rank = Experience.calculateRank(5, false, false)
    Assert.equals(1, rank)
end)

T.test("15 XP = Rank 2 (below Battle-Hardened threshold)", function()
    local rank = Experience.calculateRank(15, false, false)
    Assert.equals(2, rank)
end)

-- ============================================================================
-- RANK DETAILS AND REQUIREMENTS
-- ============================================================================

T.suite("Experience - Rank Details")

T.test("getRankDetails returns correct info", function()
    local details = Experience.getRankDetails(1)
    Assert.isNotNil(details)
    Assert.equals("Battle-Ready", details.name)
    Assert.equals(0, details.minXP)
end)

T.test("getNextRankRequirements for rank 1", function()
    local next = Experience.getNextRankRequirements(1, false, false)
    Assert.isNotNil(next)
    Assert.equals(2, next.rank)
    Assert.equals(6, next.minXP)
end)

T.test("getNextRankRequirements returns nil for max rank CHARACTER", function()
    local next = Experience.getNextRankRequirements(5, true, false)
    Assert.isNil(next, "Rank 5 CHARACTER should have no next rank")
end)

T.test("getNextRankRequirements returns nil for non-CHARACTER at rank 3", function()
    local next = Experience.getNextRankRequirements(3, false, false)
    Assert.isNil(next, "Non-CHARACTER without LV cannot go past rank 3")
end)

T.test("getNextRankRequirements allows rank 4 for non-CHARACTER with LV", function()
    local next = Experience.getNextRankRequirements(3, false, true)
    Assert.isNotNil(next)
    Assert.equals(4, next.rank)
end)

T.test("getXPForNextRank calculates correctly", function()
    local u = makeUnit({xp = 3, rank = 1})
    local needed = Experience.getXPForNextRank(u)
    Assert.equals(3, needed) -- Need 6 XP for rank 2, have 3
end)

T.test("getXPForNextRank returns nil at max rank", function()
    local u = makeUnit({xp = 60, rank = 5, isCharacter = true})
    local needed = Experience.getXPForNextRank(u)
    Assert.isNil(needed)
end)

-- ============================================================================
-- XP AWARDS
-- ============================================================================

T.suite("Experience - addXP")

T.test("addXP increases experience points", function()
    local u = makeUnit()
    local log = {}
    local success, amount = Experience.addXP(u, 5, "test", log)
    Assert.isTrue(success)
    Assert.equals(5, amount)
    Assert.equals(5, u.experiencePoints)
end)

T.test("addXP triggers rank up", function()
    local u = makeUnit({xp = 5, rank = 1})
    local log = {}
    Experience.addXP(u, 1, "test", log)
    Assert.equals(6, u.experiencePoints)
    Assert.equals(2, u.rank) -- Rank 2 at 6 XP
end)

T.test("addXP sets pendingHonourSelection on rank up", function()
    local u = makeUnit({xp = 5, rank = 1})
    Experience.addXP(u, 1, "test", {})
    Assert.isTrue(u.pendingHonourSelection)
end)

T.test("addXP respects XP cap for non-CHARACTER", function()
    local u = makeUnit({xp = 28})
    local log = {}
    local success, amount = Experience.addXP(u, 5, "test", log)
    Assert.isTrue(success)
    Assert.equals(2, amount) -- Capped at 30
    Assert.equals(30, u.experiencePoints)
end)

T.test("addXP refuses when at XP cap", function()
    local u = makeUnit({xp = 30})
    local success, amount, msg = Experience.addXP(u, 5, "test", {})
    Assert.isFalse(success)
    Assert.equals(0, amount)
    Assert.contains(msg, "max XP")
end)

T.test("CHARACTER has no XP cap", function()
    local u = makeUnit({isCharacter = true, xp = 50})
    local success, amount = Experience.addXP(u, 10, "test", {})
    Assert.isTrue(success)
    Assert.equals(10, amount)
    Assert.equals(60, u.experiencePoints)
end)

T.test("Legendary Veterans removes XP cap", function()
    local u = makeUnit({xp = 30, hasLegendaryVeterans = true})
    local success, amount = Experience.addXP(u, 5, "test", {})
    Assert.isTrue(success)
    Assert.equals(5, amount)
    Assert.equals(35, u.experiencePoints)
end)

T.test("unit with canGainXP=false cannot gain XP", function()
    local u = makeUnit({canGainXP = false})
    local success, _, msg = Experience.addXP(u, 5, "test", {})
    Assert.isFalse(success)
    Assert.contains(msg, "cannot gain XP")
end)

-- ============================================================================
-- BATTLE EXPERIENCE (+1 to all)
-- ============================================================================

T.suite("Experience - Battle Experience")

T.test("awards +1 XP to all participating units", function()
    local u1 = makeUnit({name = "Unit 1"})
    local u2 = makeUnit({name = "Unit 2"})
    local units = {[u1.id] = u1, [u2.id] = u2}

    local battle = DataModel.createBattleRecord({battleSize = "Strike Force"})
    battle.participants = {
        DataModel.createBattleParticipant("p1", {u1.id, u2.id})
    }

    local results = Experience.awardBattleExperienceXP(battle, units, {})
    Assert.equals(1, u1.experiencePoints)
    Assert.equals(1, u2.experiencePoints)
end)

-- ============================================================================
-- DEALERS OF DEATH (+1 per 3rd kill)
-- ============================================================================

T.suite("Experience - Dealers of Death")

T.test("no XP for first 2 kills", function()
    local u = makeUnit()
    local xp = Experience.calculateDealersOfDeathXP(u, 2, {})
    Assert.equals(0, xp)
    Assert.equals(2, u.combatTallies.unitsDestroyed)
end)

T.test("+1 XP on 3rd kill", function()
    local u = makeUnit()
    local xp = Experience.calculateDealersOfDeathXP(u, 3, {})
    Assert.equals(1, xp)
end)

T.test("+2 XP for 6 kills from 0", function()
    local u = makeUnit()
    local xp = Experience.calculateDealersOfDeathXP(u, 6, {})
    Assert.equals(2, xp) -- crosses 3rd and 6th thresholds
end)

T.test("tally tracks lifetime kills across battles", function()
    local u = makeUnit()
    -- Battle 1: 2 kills (no XP)
    Experience.calculateDealersOfDeathXP(u, 2, {})
    Assert.equals(2, u.combatTallies.unitsDestroyed)

    -- Battle 2: 1 kill (crosses 3rd threshold)
    local xp = Experience.calculateDealersOfDeathXP(u, 1, {})
    Assert.equals(1, xp)
    Assert.equals(3, u.combatTallies.unitsDestroyed)
end)

T.test("getNextDealersOfDeathThreshold calculates correctly", function()
    Assert.equals(3, Experience.getNextDealersOfDeathThreshold(0))
    Assert.equals(3, Experience.getNextDealersOfDeathThreshold(1))
    Assert.equals(3, Experience.getNextDealersOfDeathThreshold(2))
    Assert.equals(6, Experience.getNextDealersOfDeathThreshold(3))
    Assert.equals(6, Experience.getNextDealersOfDeathThreshold(4))
    Assert.equals(6, Experience.getNextDealersOfDeathThreshold(5))
    Assert.equals(9, Experience.getNextDealersOfDeathThreshold(6))
end)

-- ============================================================================
-- MARKED FOR GREATNESS (+3 XP)
-- ============================================================================

T.suite("Experience - Marked for Greatness")

T.test("awards +3 XP to marked unit", function()
    local u = makeUnit({name = "Hero"})
    local units = {[u.id] = u}

    local battle = DataModel.createBattleRecord({battleSize = "Strike Force"})
    battle.markedForGreatness = {["p1"] = u.id}

    local results = Experience.awardMarkedForGreatnessXP(battle, units, {})
    Assert.equals(3, u.experiencePoints)
    Assert.isNotNil(results[u.id])
    Assert.isTrue(results[u.id].success)
end)

T.test("Disgraced scar prevents Marked for Greatness", function()
    local scar = DataModel.createBattleScar({name = "Disgraced"})
    local u = makeUnit({name = "Disgraced Unit", battleScars = {scar}})
    local units = {[u.id] = u}

    local battle = DataModel.createBattleRecord({battleSize = "Strike Force"})
    battle.markedForGreatness = {["p1"] = u.id}

    local results = Experience.awardMarkedForGreatnessXP(battle, units, {})
    Assert.equals(0, u.experiencePoints)
    Assert.isFalse(results[u.id].success)
end)

T.test("Mark of Shame scar prevents Marked for Greatness", function()
    local scar = DataModel.createBattleScar({name = "Mark of Shame"})
    local u = makeUnit({name = "Shamed Unit", battleScars = {scar}})
    local units = {[u.id] = u}

    local battle = DataModel.createBattleRecord({battleSize = "Strike Force"})
    battle.markedForGreatness = {["p1"] = u.id}

    local results = Experience.awardMarkedForGreatnessXP(battle, units, {})
    Assert.equals(0, u.experiencePoints)
    Assert.isFalse(results[u.id].success)
end)

-- ============================================================================
-- LEGENDARY VETERANS REQUISITION
-- ============================================================================

T.suite("Experience - Legendary Veterans")

T.test("applies to non-CHARACTER at 30 XP", function()
    local u = makeUnit({xp = 30})
    u.rank = 3 -- Battle-Hardened
    local success = Experience.applyLegendaryVeterans(u, {})
    Assert.isTrue(success)
    Assert.isTrue(u.hasLegendaryVeterans)
end)

T.test("refuses CHARACTER units", function()
    local u = makeUnit({isCharacter = true, xp = 30})
    local success = Experience.applyLegendaryVeterans(u, {})
    Assert.isFalse(success)
end)

T.test("refuses unit below 30 XP", function()
    local u = makeUnit({xp = 20})
    local success = Experience.applyLegendaryVeterans(u, {})
    Assert.isFalse(success)
end)

T.test("refuses already-applied", function()
    local u = makeUnit({xp = 30, hasLegendaryVeterans = true})
    local success = Experience.applyLegendaryVeterans(u, {})
    Assert.isFalse(success)
end)

T.test("Legendary Veterans recalculates rank", function()
    local u = makeUnit({xp = 35})
    u.rank = 3
    Experience.applyLegendaryVeterans(u, {})
    -- 35 XP with LV should be Heroic (rank 4, requires 31 XP)
    Assert.equals(4, u.rank)
end)

-- ============================================================================
-- POST-BATTLE XP PROCESSING
-- ============================================================================

T.suite("Experience - Post-Battle Processing")

T.test("processPostBattleXP awards all XP types", function()
    local u1 = makeUnit({name = "Fighter"})
    local u2 = makeUnit({name = "Support"})
    local units = {[u1.id] = u1, [u2.id] = u2}

    local battle = DataModel.createBattleRecord({battleSize = "Strike Force"})
    battle.participants = {
        DataModel.createBattleParticipant("p1", {u1.id, u2.id})
    }
    battle.markedForGreatness = {["p1"] = u1.id}
    battle.combatTallies = {
        [u1.id] = {killsThisBattle = 3}
    }

    local summary = Experience.processPostBattleXP(battle, units, {})

    -- u1: +1 (battle) + 1 (dealers of death, 3 kills) + 3 (marked) = 5
    Assert.equals(5, u1.experiencePoints)
    -- u2: +1 (battle)
    Assert.equals(1, u2.experiencePoints)
end)

T.test("incrementBattlesParticipated tracks tally", function()
    local u = makeUnit()
    Assert.equals(0, u.combatTallies.battlesParticipated)
    Experience.incrementBattlesParticipated(u)
    Assert.equals(1, u.combatTallies.battlesParticipated)
    Experience.incrementBattlesParticipated(u)
    Assert.equals(2, u.combatTallies.battlesParticipated)
end)

return T
