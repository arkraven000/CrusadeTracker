--[[
=====================================
CRUSADE POINTS TESTS
=====================================
Tests for the 10th Edition Crusade Points formula.

CRITICAL: CP = Battle Honours CP - Battle Scars count
- Battle Traits / Weapon Mods: +1 each (+2 if TITANIC)
- Crusade Relics: +1 (Artificer), +2 (Antiquity), +3 (Legendary)
- Battle Scars: -1 each
- CAN BE NEGATIVE
- XP does NOT contribute to CP in 10th Edition
]]

require("tests/tts_mock")
local T = require("tests/test_runner")
local Assert = T.Assert

local CrusadePoints = require("src/crusade/CrusadePoints")
local DataModel = require("src/core/DataModel")
local Constants = require("src/core/Constants")

-- Helper: create a basic unit for testing
local function makeUnit(overrides)
    overrides = overrides or {}
    local u = DataModel.createUnit("testOwner", {
        name = overrides.name or "Test Unit",
        pointsCost = overrides.pointsCost or 100,
        isCharacter = overrides.isCharacter or false,
        isTitanic = overrides.isTitanic or false
    })
    -- Apply overrides
    if overrides.battleHonours then u.battleHonours = overrides.battleHonours end
    if overrides.battleScars then u.battleScars = overrides.battleScars end
    if overrides.experiencePoints then u.experiencePoints = overrides.experiencePoints end
    return u
end

-- Helper: create a simple Battle Trait honour (+1 CP)
local function makeTrait(name)
    return DataModel.createBattleHonour("Battle Trait", {
        name = name or "Test Trait",
        crusadePointsCost = 1
    })
end

-- Helper: create a Crusade Relic honour
local function makeRelic(tier, cp)
    return DataModel.createBattleHonour("Crusade Relic", {
        name = tier .. " Relic",
        tier = tier,
        crusadePointsCost = cp
    })
end

-- Helper: create a Battle Scar
local function makeScar(name)
    return DataModel.createBattleScar({
        name = name or "Test Scar"
    })
end

-- ============================================================================
-- BASIC CP CALCULATION
-- ============================================================================

T.suite("CrusadePoints - Basic Calculation")

T.test("fresh unit has 0 CP", function()
    local u = makeUnit()
    Assert.equals(0, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("one Battle Trait gives +1 CP", function()
    local u = makeUnit({
        battleHonours = {makeTrait("Inspiring Leader")}
    })
    Assert.equals(1, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("multiple Battle Traits stack", function()
    local u = makeUnit({
        battleHonours = {makeTrait("Trait 1"), makeTrait("Trait 2"), makeTrait("Trait 3")}
    })
    Assert.equals(3, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("one Battle Scar gives -1 CP", function()
    local u = makeUnit({
        battleScars = {makeScar("Crippling Damage")}
    })
    Assert.equals(-1, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("honours and scars combine correctly", function()
    local u = makeUnit({
        battleHonours = {makeTrait("Trait 1"), makeTrait("Trait 2")},
        battleScars = {makeScar("Scar 1")}
    })
    -- CP = 2 honours - 1 scar = 1
    Assert.equals(1, CrusadePoints.calculateCrusadePoints(u))
end)

-- ============================================================================
-- NEGATIVE CP (CRITICAL RULE)
-- ============================================================================

T.suite("CrusadePoints - Negative CP")

T.test("CP can be negative (more scars than honours)", function()
    local u = makeUnit({
        battleScars = {makeScar("Scar 1"), makeScar("Scar 2"), makeScar("Scar 3")}
    })
    -- CP = 0 honours - 3 scars = -3
    Assert.equals(-3, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("CP can be negative with some honours", function()
    local u = makeUnit({
        battleHonours = {makeTrait("Trait 1")},
        battleScars = {makeScar("Scar 1"), makeScar("Scar 2"), makeScar("Scar 3")}
    })
    -- CP = 1 honour - 3 scars = -2
    Assert.equals(-2, CrusadePoints.calculateCrusadePoints(u))
end)

-- ============================================================================
-- TITANIC UNITS
-- ============================================================================

T.suite("CrusadePoints - TITANIC Units")

T.test("TITANIC Battle Trait gives +2 CP instead of +1", function()
    local u = makeUnit({
        isTitanic = true,
        battleHonours = {makeTrait("Trait 1")}
    })
    Assert.equals(2, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("TITANIC with multiple traits", function()
    local u = makeUnit({
        isTitanic = true,
        battleHonours = {makeTrait("Trait 1"), makeTrait("Trait 2")}
    })
    -- TITANIC: 2 traits * 2 CP each = 4 CP
    Assert.equals(4, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("TITANIC bonus only applies to traits/mods, not relics", function()
    local u = makeUnit({
        isTitanic = true,
        battleHonours = {
            makeTrait("Trait 1"),           -- +2 (TITANIC)
            makeRelic("Artificer", 1)       -- +1 (relic CP is fixed)
        }
    })
    -- CP = 2 (TITANIC trait) + 1 (Artificer relic) = 3
    Assert.equals(3, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("TITANIC scars still -1 each", function()
    local u = makeUnit({
        isTitanic = true,
        battleHonours = {makeTrait("Trait 1")},
        battleScars = {makeScar("Scar 1")}
    })
    -- CP = 2 (TITANIC trait) - 1 (scar) = 1
    Assert.equals(1, CrusadePoints.calculateCrusadePoints(u))
end)

-- ============================================================================
-- CRUSADE RELICS
-- ============================================================================

T.suite("CrusadePoints - Crusade Relics")

T.test("Artificer relic = +1 CP", function()
    local u = makeUnit({
        battleHonours = {makeRelic("Artificer", 1)}
    })
    Assert.equals(1, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("Antiquity relic = +2 CP", function()
    local u = makeUnit({
        battleHonours = {makeRelic("Antiquity", 2)}
    })
    Assert.equals(2, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("Legendary relic = +3 CP", function()
    local u = makeUnit({
        battleHonours = {makeRelic("Legendary", 3)}
    })
    Assert.equals(3, CrusadePoints.calculateCrusadePoints(u))
end)

T.test("mixed honours and relics calculate correctly", function()
    local u = makeUnit({
        isCharacter = true,
        battleHonours = {
            makeTrait("Trait 1"),           -- +1
            makeTrait("Trait 2"),           -- +1
            makeRelic("Artificer", 1),     -- +1
            makeRelic("Antiquity", 2)      -- +2
        },
        battleScars = {makeScar("Scar 1")} -- -1
    })
    -- CP = 1 + 1 + 1 + 2 - 1 = 4
    Assert.equals(4, CrusadePoints.calculateCrusadePoints(u))
end)

-- ============================================================================
-- XP DOES NOT AFFECT CP (10TH EDITION)
-- ============================================================================

T.suite("CrusadePoints - XP Independence")

T.test("XP has no effect on CP", function()
    local u1 = makeUnit({experiencePoints = 0})
    local u2 = makeUnit({experiencePoints = 50})
    Assert.equals(
        CrusadePoints.calculateCrusadePoints(u1),
        CrusadePoints.calculateCrusadePoints(u2),
        "XP should not affect CP in 10th Edition"
    )
end)

-- ============================================================================
-- UPDATE AND BREAKDOWN
-- ============================================================================

T.suite("CrusadePoints - Update and Breakdown")

T.test("updateUnitCrusadePoints updates cached value", function()
    local u = makeUnit({
        battleHonours = {makeTrait("Trait 1"), makeTrait("Trait 2")}
    })
    Assert.equals(0, u.crusadePoints) -- initial cached value
    local newCP = CrusadePoints.updateUnitCrusadePoints(u)
    Assert.equals(2, newCP)
    Assert.equals(2, u.crusadePoints)
end)

T.test("getCrusadePointsBreakdown returns detailed info", function()
    local u = makeUnit({
        battleHonours = {makeTrait("Trait 1"), makeRelic("Antiquity", 2)},
        battleScars = {makeScar("Scar 1")}
    })
    local bd = CrusadePoints.getCrusadePointsBreakdown(u)
    Assert.equals(2, bd.total) -- 1 + 2 - 1
    Assert.equals(3, bd.fromHonours) -- 1 + 2
    Assert.equals(1, bd.fromScars)
    Assert.equals(2, bd.honourCount)
    Assert.equals(1, bd.scarCount)
    Assert.isType(bd.formula, "string")
end)

T.test("validateCrusadePointsCalculation detects mismatch", function()
    local u = makeUnit({
        battleHonours = {makeTrait("Trait 1")}
    })
    u.crusadePoints = 99 -- wrong cached value
    Assert.isFalse(CrusadePoints.validateCrusadePointsCalculation(u))
end)

T.test("validateCrusadePointsCalculation confirms correct value", function()
    local u = makeUnit({
        battleHonours = {makeTrait("Trait 1")}
    })
    CrusadePoints.updateUnitCrusadePoints(u)
    Assert.isTrue(CrusadePoints.validateCrusadePointsCalculation(u))
end)

-- ============================================================================
-- SORTING
-- ============================================================================

T.suite("CrusadePoints - Sorting")

T.test("sortUnitsByCrusadePoints sorts ascending", function()
    local u1 = makeUnit({name = "Low", battleHonours = {makeTrait("T1")}})
    local u2 = makeUnit({name = "High", battleHonours = {makeTrait("T1"), makeTrait("T2"), makeTrait("T3")}})
    local u3 = makeUnit({name = "Mid", battleHonours = {makeTrait("T1"), makeTrait("T2")}})
    CrusadePoints.updateUnitCrusadePoints(u1)
    CrusadePoints.updateUnitCrusadePoints(u2)
    CrusadePoints.updateUnitCrusadePoints(u3)

    local sorted = CrusadePoints.sortUnitsByCrusadePoints({u1, u2, u3}, false)
    Assert.equals("Low", sorted[1].name)
    Assert.equals("Mid", sorted[2].name)
    Assert.equals("High", sorted[3].name)
end)

T.test("sortUnitsByCrusadePoints sorts descending", function()
    local u1 = makeUnit({name = "Low"})
    local u2 = makeUnit({name = "High", battleHonours = {makeTrait("T1"), makeTrait("T2")}})
    CrusadePoints.updateUnitCrusadePoints(u1)
    CrusadePoints.updateUnitCrusadePoints(u2)

    local sorted = CrusadePoints.sortUnitsByCrusadePoints({u1, u2}, true)
    Assert.equals("High", sorted[1].name)
    Assert.equals("Low", sorted[2].name)
end)

-- ============================================================================
-- SUPPLY CALCULATION
-- ============================================================================

T.suite("CrusadePoints - Supply Calculation")

T.test("calculateSupplyUsed sums points costs", function()
    local u1 = DataModel.createUnit("p1", {name = "Unit A", pointsCost = 100})
    local u2 = DataModel.createUnit("p1", {name = "Unit B", pointsCost = 200})
    local player = DataModel.createPlayer("Test", "Blue", "Marines")
    table.insert(player.orderOfBattle, u1.id)
    table.insert(player.orderOfBattle, u2.id)

    local units = {[u1.id] = u1, [u2.id] = u2}
    local supply = CrusadePoints.calculateSupplyUsed(player, units)
    Assert.equals(300, supply)
end)

T.test("calculateSupplyUsed includes enhancement cost", function()
    local u = DataModel.createUnit("p1", {name = "Captain", pointsCost = 100})
    u.enhancement = DataModel.createEnhancement({name = "Test Enhancement", pointsCost = 25})

    local player = DataModel.createPlayer("Test", "Blue", "Marines")
    table.insert(player.orderOfBattle, u.id)

    local supply = CrusadePoints.calculateSupplyUsed(player, {[u.id] = u})
    Assert.equals(125, supply)
end)

T.test("checkSupplyLimit detects over limit", function()
    local u = DataModel.createUnit("p1", {name = "Expensive", pointsCost = 1500})
    local player = DataModel.createPlayer("Test", "Blue", "Marines")
    player.supplyLimit = 1000
    table.insert(player.orderOfBattle, u.id)

    local isOver, used, limit = CrusadePoints.checkSupplyLimit(player, {[u.id] = u})
    Assert.isTrue(isOver)
    Assert.equals(1500, used)
    Assert.equals(1000, limit)
end)

T.test("checkSupplyLimit confirms under limit", function()
    local u = DataModel.createUnit("p1", {name = "Cheap", pointsCost = 100})
    local player = DataModel.createPlayer("Test", "Blue", "Marines")
    table.insert(player.orderOfBattle, u.id)

    local isOver = CrusadePoints.checkSupplyLimit(player, {[u.id] = u})
    Assert.isFalse(isOver)
end)

-- ============================================================================
-- NIL SAFETY
-- ============================================================================

T.suite("CrusadePoints - Nil Safety")

T.test("calculateCrusadePoints handles nil unit", function()
    Assert.equals(0, CrusadePoints.calculateCrusadePoints(nil))
end)

T.test("updateUnitCrusadePoints handles nil unit", function()
    Assert.equals(0, CrusadePoints.updateUnitCrusadePoints(nil))
end)

T.test("getCrusadePointsBreakdown handles nil unit", function()
    local bd = CrusadePoints.getCrusadePointsBreakdown(nil)
    Assert.equals(0, bd.total)
end)

T.test("calculateSupplyUsed handles nil player", function()
    local supply, err = CrusadePoints.calculateSupplyUsed(nil, {})
    Assert.equals(0, supply)
    Assert.isNotNil(err)
end)

T.test("calculateSupplyUsed handles nil units collection", function()
    local player = DataModel.createPlayer("Test", "Blue", "Marines")
    local supply, err = CrusadePoints.calculateSupplyUsed(player, nil)
    Assert.equals(0, supply)
    Assert.isNotNil(err)
end)

return T
