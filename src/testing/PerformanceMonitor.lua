--[[
=====================================
PERFORMANCE MONITOR
Phase 9: Testing & Quality Assurance
=====================================

Performance tracking and optimization:
- Function execution timing
- Memory usage tracking
- Performance bottleneck identification
- Operation profiling
]]

local PerformanceMonitor = {}

-- Dependencies
local Utils = require("src/core/Utils")

-- Performance data
PerformanceMonitor.metrics = {
    functionCalls = {},
    timings = {},
    memorySnapshots = {},
    operationCounts = {}
}

PerformanceMonitor.enabled = false
PerformanceMonitor.startTime = nil

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize performance monitor
function PerformanceMonitor.initialize()
    PerformanceMonitor.enabled = true
    PerformanceMonitor.startTime = os.time()
    PerformanceMonitor.metrics = {
        functionCalls = {},
        timings = {},
        memorySnapshots = {},
        operationCounts = {}
    }

    Utils.logInfo("PerformanceMonitor initialized")
end

--- Stop performance monitoring
function PerformanceMonitor.stop()
    PerformanceMonitor.enabled = false
    Utils.logInfo("PerformanceMonitor stopped")
end

-- ============================================================================
-- TIMING FUNCTIONS
-- ============================================================================

--- Start timing an operation
-- @param operationName string Name of the operation
-- @return number Start time
function PerformanceMonitor.startTiming(operationName)
    if not PerformanceMonitor.enabled then
        return os.clock()
    end

    local startTime = os.clock()

    if not PerformanceMonitor.metrics.timings[operationName] then
        PerformanceMonitor.metrics.timings[operationName] = {
            calls = 0,
            totalTime = 0,
            minTime = nil,
            maxTime = nil,
            avgTime = 0
        }
    end

    return startTime
end

--- End timing an operation
-- @param operationName string Name of the operation
-- @param startTime number Start time from startTiming
function PerformanceMonitor.endTiming(operationName, startTime)
    if not PerformanceMonitor.enabled then
        return
    end

    local endTime = os.clock()
    local elapsed = endTime - startTime

    local timing = PerformanceMonitor.metrics.timings[operationName]
    if not timing then
        return
    end

    timing.calls = timing.calls + 1
    timing.totalTime = timing.totalTime + elapsed

    if not timing.minTime or elapsed < timing.minTime then
        timing.minTime = elapsed
    end

    if not timing.maxTime or elapsed > timing.maxTime then
        timing.maxTime = elapsed
    end

    timing.avgTime = timing.totalTime / timing.calls
end

--- Measure a function execution
-- @param functionName string Name of function
-- @param func function Function to measure
-- @param ... any Function arguments
-- @return any Function results
function PerformanceMonitor.measureFunction(functionName, func, ...)
    local startTime = PerformanceMonitor.startTiming(functionName)
    local results = {func(...)}
    PerformanceMonitor.endTiming(functionName, startTime)
    return table.unpack(results)
end

-- ============================================================================
-- FUNCTION CALL TRACKING
-- ============================================================================

--- Record a function call
-- @param functionName string Name of function
function PerformanceMonitor.recordFunctionCall(functionName)
    if not PerformanceMonitor.enabled then
        return
    end

    if not PerformanceMonitor.metrics.functionCalls[functionName] then
        PerformanceMonitor.metrics.functionCalls[functionName] = 0
    end

    PerformanceMonitor.metrics.functionCalls[functionName] =
        PerformanceMonitor.metrics.functionCalls[functionName] + 1
end

-- ============================================================================
-- MEMORY TRACKING
-- ============================================================================

--- Take a memory snapshot
-- @param label string Snapshot label
function PerformanceMonitor.takeMemorySnapshot(label)
    if not PerformanceMonitor.enabled then
        return
    end

    -- Note: TTS Lua doesn't have collectgarbage("count")
    -- This is a placeholder for memory tracking
    local snapshot = {
        label = label,
        timestamp = os.time(),
        -- Memory metrics would go here if available
    }

    table.insert(PerformanceMonitor.metrics.memorySnapshots, snapshot)
end

-- ============================================================================
-- OPERATION COUNTING
-- ============================================================================

--- Increment an operation counter
-- @param operationName string Operation name
-- @param amount number Amount to increment (default 1)
function PerformanceMonitor.incrementOperation(operationName, amount)
    if not PerformanceMonitor.enabled then
        return
    end

    amount = amount or 1

    if not PerformanceMonitor.metrics.operationCounts[operationName] then
        PerformanceMonitor.metrics.operationCounts[operationName] = 0
    end

    PerformanceMonitor.metrics.operationCounts[operationName] =
        PerformanceMonitor.metrics.operationCounts[operationName] + amount
end

-- ============================================================================
-- REPORTING
-- ============================================================================

--- Get performance report
-- @return table Performance metrics
function PerformanceMonitor.getReport()
    local report = {
        enabled = PerformanceMonitor.enabled,
        uptime = os.time() - (PerformanceMonitor.startTime or os.time()),
        timings = {},
        functionCalls = {},
        operationCounts = {},
        topSlowOperations = {},
        topFrequentCalls = {}
    }

    -- Copy timings
    for name, timing in pairs(PerformanceMonitor.metrics.timings) do
        report.timings[name] = {
            calls = timing.calls,
            totalTime = timing.totalTime,
            avgTime = timing.avgTime,
            minTime = timing.minTime,
            maxTime = timing.maxTime
        }
    end

    -- Copy function calls
    for name, count in pairs(PerformanceMonitor.metrics.functionCalls) do
        report.functionCalls[name] = count
    end

    -- Copy operation counts
    for name, count in pairs(PerformanceMonitor.metrics.operationCounts) do
        report.operationCounts[name] = count
    end

    -- Find top slow operations
    local timingsList = {}
    for name, timing in pairs(PerformanceMonitor.metrics.timings) do
        table.insert(timingsList, {name = name, avgTime = timing.avgTime, totalTime = timing.totalTime})
    end

    table.sort(timingsList, function(a, b)
        return a.totalTime > b.totalTime
    end)

    for i = 1, math.min(10, #timingsList) do
        table.insert(report.topSlowOperations, timingsList[i])
    end

    -- Find top frequent calls
    local callsList = {}
    for name, count in pairs(PerformanceMonitor.metrics.functionCalls) do
        table.insert(callsList, {name = name, count = count})
    end

    table.sort(callsList, function(a, b)
        return a.count > b.count
    end)

    for i = 1, math.min(10, #callsList) do
        table.insert(report.topFrequentCalls, callsList[i])
    end

    return report
end

--- Generate performance report text
-- @return string Formatted report
function PerformanceMonitor.generateReportText()
    local report = PerformanceMonitor.getReport()

    local text = string.format([[
=== PERFORMANCE REPORT ===
Status: %s
Uptime: %d seconds

TOP 10 SLOWEST OPERATIONS:
]],
        report.enabled and "ENABLED" or "DISABLED",
        report.uptime
    )

    for i, op in ipairs(report.topSlowOperations) do
        text = text .. string.format("  %d. %s: %.3fms total (%.3fms avg, %d calls)\n",
            i,
            op.name,
            op.totalTime * 1000,
            op.avgTime * 1000,
            report.timings[op.name].calls
        )
    end

    text = text .. "\nTOP 10 MOST FREQUENT CALLS:\n"

    for i, call in ipairs(report.topFrequentCalls) do
        text = text .. string.format("  %d. %s: %d calls\n",
            i,
            call.name,
            call.count
        )
    end

    text = text .. "\nOPERATION COUNTS:\n"
    for name, count in pairs(report.operationCounts) do
        text = text .. string.format("  %s: %d\n", name, count)
    end

    return text
end

-- ============================================================================
-- ANALYSIS
-- ============================================================================

--- Identify performance bottlenecks
-- @param threshold number Time threshold in seconds (default 0.1)
-- @return table List of bottlenecks
function PerformanceMonitor.identifyBottlenecks(threshold)
    threshold = threshold or 0.1

    local bottlenecks = {}

    for name, timing in pairs(PerformanceMonitor.metrics.timings) do
        if timing.avgTime > threshold then
            table.insert(bottlenecks, {
                operation = name,
                avgTime = timing.avgTime,
                calls = timing.calls,
                totalTime = timing.totalTime,
                severity = timing.avgTime > (threshold * 5) and "HIGH" or "MEDIUM"
            })
        end
    end

    table.sort(bottlenecks, function(a, b)
        return a.totalTime > b.totalTime
    end)

    return bottlenecks
end

-- ============================================================================
-- UTILITIES
-- ============================================================================

--- Reset all metrics
function PerformanceMonitor.reset()
    PerformanceMonitor.metrics = {
        functionCalls = {},
        timings = {},
        memorySnapshots = {},
        operationCounts = {}
    }
    PerformanceMonitor.startTime = os.time()

    Utils.logInfo("PerformanceMonitor metrics reset")
end

--- Export metrics to JSON
-- @return string JSON string
function PerformanceMonitor.exportMetrics()
    local report = PerformanceMonitor.getReport()
    return Utils.safeJSONEncode(report)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return PerformanceMonitor
