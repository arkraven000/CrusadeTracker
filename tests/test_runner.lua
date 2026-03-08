--[[
=====================================
TEST RUNNER
=====================================

Lightweight test framework for Lua 5.1 (no external dependencies).
Provides test grouping, assertions, setup/teardown, and summary reporting.
]]

local TestRunner = {}
TestRunner._suites = {}
TestRunner._currentSuite = nil
TestRunner._results = {
    total = 0,
    passed = 0,
    failed = 0,
    errors = 0,
    skipped = 0,
    failures = {}
}

-- ============================================================================
-- SUITE MANAGEMENT
-- ============================================================================

function TestRunner.suite(name)
    local suite = {
        name = name,
        tests = {},
        setup = nil,
        teardown = nil
    }
    table.insert(TestRunner._suites, suite)
    TestRunner._currentSuite = suite
    return suite
end

function TestRunner.setup(func)
    if TestRunner._currentSuite then
        TestRunner._currentSuite.setup = func
    end
end

function TestRunner.teardown(func)
    if TestRunner._currentSuite then
        TestRunner._currentSuite.teardown = func
    end
end

function TestRunner.test(name, func)
    if TestRunner._currentSuite then
        table.insert(TestRunner._currentSuite.tests, {name = name, func = func})
    end
end

function TestRunner.skip(name, func)
    if TestRunner._currentSuite then
        table.insert(TestRunner._currentSuite.tests, {name = name, func = func, skip = true})
    end
end

-- ============================================================================
-- ASSERTIONS
-- ============================================================================

local Assert = {}

function Assert.isTrue(value, message)
    if not value then
        error("Expected true, got " .. tostring(value) .. (message and (": " .. message) or ""), 2)
    end
end

function Assert.isFalse(value, message)
    if value then
        error("Expected false, got " .. tostring(value) .. (message and (": " .. message) or ""), 2)
    end
end

function Assert.equals(expected, actual, message)
    if expected ~= actual then
        error(string.format("Expected %s, got %s%s",
            tostring(expected), tostring(actual),
            message and (": " .. message) or ""), 2)
    end
end

function Assert.notEquals(expected, actual, message)
    if expected == actual then
        error(string.format("Expected value to differ from %s%s",
            tostring(expected),
            message and (": " .. message) or ""), 2)
    end
end

function Assert.isNil(value, message)
    if value ~= nil then
        error("Expected nil, got " .. tostring(value) .. (message and (": " .. message) or ""), 2)
    end
end

function Assert.isNotNil(value, message)
    if value == nil then
        error("Expected non-nil value" .. (message and (": " .. message) or ""), 2)
    end
end

function Assert.isType(value, expectedType, message)
    if type(value) ~= expectedType then
        error(string.format("Expected type %s, got %s%s",
            expectedType, type(value),
            message and (": " .. message) or ""), 2)
    end
end

function Assert.greaterThan(expected, actual, message)
    if actual <= expected then
        error(string.format("Expected %s > %s%s",
            tostring(actual), tostring(expected),
            message and (": " .. message) or ""), 2)
    end
end

function Assert.greaterOrEqual(expected, actual, message)
    if actual < expected then
        error(string.format("Expected %s >= %s%s",
            tostring(actual), tostring(expected),
            message and (": " .. message) or ""), 2)
    end
end

function Assert.lessThan(expected, actual, message)
    if actual >= expected then
        error(string.format("Expected %s < %s%s",
            tostring(actual), tostring(expected),
            message and (": " .. message) or ""), 2)
    end
end

function Assert.lessOrEqual(expected, actual, message)
    if actual > expected then
        error(string.format("Expected %s <= %s%s",
            tostring(actual), tostring(expected),
            message and (": " .. message) or ""), 2)
    end
end

function Assert.contains(haystack, needle, message)
    if type(haystack) == "string" then
        if not haystack:find(needle, 1, true) then
            error(string.format("String does not contain '%s'%s",
                needle, message and (": " .. message) or ""), 2)
        end
    elseif type(haystack) == "table" then
        for _, v in pairs(haystack) do
            if v == needle then return end
        end
        error(string.format("Table does not contain '%s'%s",
            tostring(needle), message and (": " .. message) or ""), 2)
    else
        error("Assert.contains requires string or table", 2)
    end
end

function Assert.tableSize(tbl, expectedSize, message)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    if count ~= expectedSize then
        error(string.format("Expected table size %d, got %d%s",
            expectedSize, count,
            message and (": " .. message) or ""), 2)
    end
end

function Assert.arrayLength(arr, expectedLen, message)
    if #arr ~= expectedLen then
        error(string.format("Expected array length %d, got %d%s",
            expectedLen, #arr,
            message and (": " .. message) or ""), 2)
    end
end

function Assert.throws(func, message)
    local ok, err = pcall(func)
    if ok then
        error("Expected function to throw an error" .. (message and (": " .. message) or ""), 2)
    end
    return err
end

function Assert.doesNotThrow(func, message)
    local ok, err = pcall(func)
    if not ok then
        error("Expected no error, got: " .. tostring(err) .. (message and (": " .. message) or ""), 2)
    end
end

-- ============================================================================
-- RUNNER
-- ============================================================================

function TestRunner.run(filter)
    local startTime = os.clock()

    -- Reset results
    TestRunner._results = {
        total = 0, passed = 0, failed = 0, errors = 0, skipped = 0,
        failures = {}
    }

    print("\n" .. string.rep("=", 70))
    print("  CRUSADE TRACKER TEST SUITE")
    print(string.rep("=", 70))

    for _, suite in ipairs(TestRunner._suites) do
        -- Filter suites if specified
        if not filter or suite.name:find(filter, 1, true) then
            print("\n  [SUITE] " .. suite.name)
            print("  " .. string.rep("-", 60))

            for _, test in ipairs(suite.tests) do
                TestRunner._results.total = TestRunner._results.total + 1

                if test.skip then
                    TestRunner._results.skipped = TestRunner._results.skipped + 1
                    print(string.format("    [SKIP] %s", test.name))
                else
                    local setupFailed = false

                    -- Run setup
                    if suite.setup then
                        local setupOk, setupErr = pcall(suite.setup)
                        if not setupOk then
                            TestRunner._results.errors = TestRunner._results.errors + 1
                            print(string.format("    [ERR]  %s (setup failed: %s)", test.name, setupErr))
                            table.insert(TestRunner._results.failures, {
                                suite = suite.name,
                                test = test.name,
                                error = "Setup failed: " .. tostring(setupErr)
                            })
                            setupFailed = true
                        end
                    end

                    if not setupFailed then
                        -- Run test
                        local ok, err = pcall(test.func)

                        if ok then
                            TestRunner._results.passed = TestRunner._results.passed + 1
                            print(string.format("    [PASS] %s", test.name))
                        else
                            TestRunner._results.failed = TestRunner._results.failed + 1
                            print(string.format("    [FAIL] %s", test.name))
                            print(string.format("           %s", tostring(err)))
                            table.insert(TestRunner._results.failures, {
                                suite = suite.name,
                                test = test.name,
                                error = tostring(err)
                            })
                        end

                        -- Run teardown
                        if suite.teardown then
                            pcall(suite.teardown)
                        end
                    end
                end
            end
        end
    end

    local elapsed = os.clock() - startTime

    -- Summary
    print("\n" .. string.rep("=", 70))
    print("  RESULTS")
    print(string.rep("=", 70))
    print(string.format("  Total:   %d", TestRunner._results.total))
    print(string.format("  Passed:  %d", TestRunner._results.passed))
    print(string.format("  Failed:  %d", TestRunner._results.failed))
    print(string.format("  Errors:  %d", TestRunner._results.errors))
    print(string.format("  Skipped: %d", TestRunner._results.skipped))
    print(string.format("  Time:    %.3fs", elapsed))

    if #TestRunner._results.failures > 0 then
        print("\n  FAILURE DETAILS:")
        print("  " .. string.rep("-", 60))
        for i, f in ipairs(TestRunner._results.failures) do
            print(string.format("  %d) %s > %s", i, f.suite, f.test))
            print(string.format("     %s", f.error))
        end
    end

    local allPassed = TestRunner._results.failed == 0 and TestRunner._results.errors == 0
    print("\n  " .. (allPassed and "ALL TESTS PASSED" or "SOME TESTS FAILED"))
    print(string.rep("=", 70) .. "\n")

    return allPassed
end

-- Make Assert available
TestRunner.Assert = Assert

return TestRunner
