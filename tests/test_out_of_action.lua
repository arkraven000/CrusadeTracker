--[[
=====================================
OUT OF ACTION TESTS
=====================================
Tests for Out of Action test mechanics.

Process:
1. Destroyed units roll D6
2. On 2-6: Pass, no effect
3. On 1: Fail, choose consequence:
   - Devastating Blow: Remove one Battle Honour (unit destroyed if none)
   - Battle Scar: Gain scar (MUST choose Devastating Blow if at 3 scars)
]]

require("tests/tts_mock")
local T = require("tests/test_runner")
local Assert = T.Assert

local OutOfAction = require("src/crusade/OutOfAction")
local DataModel = require("src/core/DataModel")
local CrusadePoints = require("src/crusade/CrusadePoints")
local Constants = require("src/core/Constants")

-- Helpers
local function makeUnit(opts)
    opts = opts or {}
    local u = DataModel.createUnit("testOwner", {
        name = opts.name or "Test Unit",
        pointsCost = 100,
        isCharacter = opts.isCharacter or false
    })
    if opts.battleHonours then u.battleHonours = opts.battleHonours end
    if opts.battleScars then u.battleScars = opts.battleScars end
    return u
end

local function makeTrait(name)
    return DataModel.createBattleHonour("Battle Trait", {name = name or "Test Trait"})
end

local function makeScar(name)
    return DataModel.createBattleScar({name = name or "Test Scar"})
end

-- ============================================================================
-- OUT OF ACTION TEST MECHANICS
-- ============================================================================

T.suite("OutOfAction - Test Mechanics")

T.test("conductOutOfActionTest returns boolean and roll", function()
    local u = makeUnit()
    local passed, roll = OutOfAction.conductOutOfActionTest(u, {})
    Assert.isType(passed, "boolean")
    Assert.isType(roll, "number")
    Assert.isTrue(roll >= 1 and roll <= 6)
end)

T.test("roll >= 2 passes test", function()
    -- Run many times to verify pass/fail logic
    local u = makeUnit()
    local passCount = 0
    local failCount = 0
    for i = 1, 100 do
        local passed, roll = OutOfAction.conductOutOfActionTest(u, {})
        if passed then
            passCount = passCount + 1
            Assert.isTrue(roll >= 2, "Passed test should have roll >= 2")
        else
            failCount = failCount + 1
            Assert.equals(1, roll, "Failed test should have roll = 1")
        end
    end
    -- Statistically, should have some passes and maybe some fails
    Assert.isTrue(passCount > 0, "Should have at least one pass in 100 rolls")
end)

-- ============================================================================
-- CONSEQUENCE AVAILABILITY
-- ============================================================================

T.suite("OutOfAction - Consequence Availability")

T.test("canChooseBattleScar with no scars", function()
    local u = makeUnit()
    local can = OutOfAction.canChooseBattleScar(u)
    Assert.isTrue(can)
end)

T.test("canChooseBattleScar denied at 3 scars", function()
    local u = makeUnit({
        battleScars = {makeScar("S1"), makeScar("S2"), makeScar("S3")}
    })
    local can, reason = OutOfAction.canChooseBattleScar(u)
    Assert.isFalse(can)
    Assert.isNotNil(reason)
end)

T.test("canChooseDevastatingBlow always allowed", function()
    local u = makeUnit()
    local can = OutOfAction.canChooseDevastatingBlow(u)
    Assert.isTrue(can)
end)

T.test("canChooseDevastatingBlow warns when no honours", function()
    local u = makeUnit()
    local can, warning = OutOfAction.canChooseDevastatingBlow(u)
    Assert.isTrue(can)
    Assert.isNotNil(warning)
    Assert.contains(warning, "permanently destroy")
end)

T.test("getAvailableConsequences returns both options", function()
    local u = makeUnit({battleHonours = {makeTrait("T1")}})
    local consequences = OutOfAction.getAvailableConsequences(u)
    Assert.arrayLength(consequences, 2)
end)

T.test("at 3 scars, Devastating Blow is mandatory", function()
    local u = makeUnit({
        battleHonours = {makeTrait("T1")},
        battleScars = {makeScar("S1"), makeScar("S2"), makeScar("S3")}
    })
    local consequences = OutOfAction.getAvailableConsequences(u)
    -- Find Battle Scar option
    local scarOption
    local devastatingOption
    for _, c in ipairs(consequences) do
        if c.type == "Battle Scar" then scarOption = c end
        if c.type == "Devastating Blow" then devastatingOption = c end
    end
    Assert.isFalse(scarOption.allowed)
    Assert.isTrue(devastatingOption.mandatory)
end)

-- ============================================================================
-- DEVASTATING BLOW
-- ============================================================================

T.suite("OutOfAction - Devastating Blow")

T.test("removes Battle Honour by index", function()
    local trait = makeTrait("My Trait")
    local u = makeUnit({battleHonours = {trait}})
    CrusadePoints.updateUnitCrusadePoints(u)
    Assert.equals(1, u.crusadePoints)

    local success, msg = OutOfAction.applyDevastatingBlow(u, 1, {})
    Assert.isTrue(success)
    Assert.arrayLength(u.battleHonours, 0)
    Assert.equals(0, u.crusadePoints) -- CP recalculated
end)

T.test("removes specific honour at index", function()
    local t1 = makeTrait("Trait A")
    local t2 = makeTrait("Trait B")
    local u = makeUnit({battleHonours = {t1, t2}})

    OutOfAction.applyDevastatingBlow(u, 1, {})
    Assert.arrayLength(u.battleHonours, 1)
    Assert.equals("Trait B", u.battleHonours[1].name)
end)

T.test("permanently destroys unit with no honours", function()
    local u = makeUnit({name = "Doomed Unit"})
    local success, msg = OutOfAction.applyDevastatingBlow(u, nil, {})
    Assert.isTrue(success)
    Assert.isTrue(u._markedForDeletion)
    Assert.contains(msg, "PERMANENTLY DESTROYED")
end)

T.test("invalid honour index is rejected", function()
    local u = makeUnit({battleHonours = {makeTrait("T1")}})
    local success = OutOfAction.applyDevastatingBlow(u, 5, {})
    Assert.isFalse(success)
end)

-- ============================================================================
-- BATTLE SCARS
-- ============================================================================

T.suite("OutOfAction - Battle Scars")

T.test("applies battle scar to unit", function()
    local u = makeUnit()
    local success, msg = OutOfAction.applyBattleScar(u, 1, {})
    Assert.isTrue(success)
    Assert.arrayLength(u.battleScars, 1)
    Assert.equals("Crippling Damage", u.battleScars[1].name)
end)

T.test("scar reduces CP by 1", function()
    local u = makeUnit({battleHonours = {makeTrait("T1")}})
    CrusadePoints.updateUnitCrusadePoints(u)
    Assert.equals(1, u.crusadePoints)

    OutOfAction.applyBattleScar(u, 1, {})
    Assert.equals(0, u.crusadePoints) -- 1 honour - 1 scar = 0
end)

T.test("refuses scar when at 3 scars", function()
    local u = makeUnit({
        battleScars = {makeScar("S1"), makeScar("S2"), makeScar("S3")}
    })
    local success = OutOfAction.applyBattleScar(u, 1, {})
    Assert.isFalse(success)
end)

T.test("all 6 battle scar types are valid", function()
    for i = 1, 6 do
        local scar = OutOfAction.getBattleScar(i)
        Assert.isNotNil(scar, "Battle scar ID " .. i .. " should exist")
        Assert.isNotNil(scar.name)
    end
end)

T.test("getAllBattleScars returns 6 scars", function()
    local scars = OutOfAction.getAllBattleScars()
    Assert.arrayLength(scars, 6)
end)

-- ============================================================================
-- SCAR REMOVAL
-- ============================================================================

T.suite("OutOfAction - Scar Removal")

T.test("removeBattleScar removes scar at index", function()
    local u = makeUnit({
        battleScars = {makeScar("S1"), makeScar("S2")}
    })
    local success = OutOfAction.removeBattleScar(u, 1, {})
    Assert.isTrue(success)
    Assert.arrayLength(u.battleScars, 1)
end)

T.test("removeBattleScar increases CP", function()
    local u = makeUnit({
        battleHonours = {makeTrait("T1")},
        battleScars = {makeScar("S1")}
    })
    CrusadePoints.updateUnitCrusadePoints(u)
    Assert.equals(0, u.crusadePoints) -- 1 - 1 = 0

    OutOfAction.removeBattleScar(u, 1, {})
    Assert.equals(1, u.crusadePoints) -- 1 - 0 = 1
end)

T.test("removeBattleScar rejects invalid index", function()
    local u = makeUnit({battleScars = {makeScar("S1")}})
    Assert.isFalse(OutOfAction.removeBattleScar(u, 5, {}))
    Assert.isFalse(OutOfAction.removeBattleScar(u, 0, {}))
    Assert.isFalse(OutOfAction.removeBattleScar(u, nil, {}))
end)

-- ============================================================================
-- APPLY CONSEQUENCE
-- ============================================================================

T.suite("OutOfAction - applyOutOfActionConsequence")

T.test("applies Devastating Blow consequence", function()
    local u = makeUnit({battleHonours = {makeTrait("T1")}})
    u._pendingOutOfActionChoice = true

    local success = OutOfAction.applyOutOfActionConsequence(
        u, "Devastating Blow", {honourIndex = 1}, {}
    )
    Assert.isTrue(success)
    Assert.isNil(u._pendingOutOfActionChoice)
    Assert.arrayLength(u.battleHonours, 0)
end)

T.test("applies Battle Scar consequence", function()
    local u = makeUnit()
    u._pendingOutOfActionChoice = true

    local success = OutOfAction.applyOutOfActionConsequence(
        u, "Battle Scar", {scarId = 2}, {}
    )
    Assert.isTrue(success)
    Assert.isNil(u._pendingOutOfActionChoice)
    Assert.arrayLength(u.battleScars, 1)
    Assert.equals("Battle-Weary", u.battleScars[1].name)
end)

T.test("rejects invalid consequence type", function()
    local u = makeUnit()
    local success = OutOfAction.applyOutOfActionConsequence(u, "InvalidType", {}, {})
    Assert.isFalse(success)
end)

-- ============================================================================
-- STATUS QUERIES
-- ============================================================================

T.suite("OutOfAction - Status Queries")

T.test("hasPendingOutOfActionChoice detects pending", function()
    local u = makeUnit()
    Assert.isFalse(OutOfAction.hasPendingOutOfActionChoice(u))
    u._pendingOutOfActionChoice = true
    Assert.isTrue(OutOfAction.hasPendingOutOfActionChoice(u))
end)

T.test("getOutOfActionStatus returns complete info", function()
    local u = makeUnit({
        battleHonours = {makeTrait("T1"), makeTrait("T2")},
        battleScars = {makeScar("S1")}
    })
    local status = OutOfAction.getOutOfActionStatus(u)
    Assert.isFalse(status.hasPendingChoice)
    Assert.equals(1, status.currentScars)
    Assert.equals(3, status.maxScars)
    Assert.equals(2, status.currentHonours)
    Assert.isFalse(status.willBeDestroyed)
end)

T.test("getOutOfActionStatus detects will-be-destroyed", function()
    local u = makeUnit()
    local status = OutOfAction.getOutOfActionStatus(u)
    Assert.isTrue(status.willBeDestroyed) -- no honours = destroyed on devastating blow
end)

return T
