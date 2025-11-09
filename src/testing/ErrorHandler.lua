--[[
=====================================
ERROR HANDLER
Phase 9: Testing & Quality Assurance
=====================================

Centralized error handling and reporting:
- Error capture and logging
- Error recovery strategies
- User-friendly error messages
- Error statistics
]]

local ErrorHandler = {}

-- Dependencies
local Utils = require("src/core/Utils")

-- Error storage
ErrorHandler.errors = {}
ErrorHandler.errorCounts = {}
ErrorHandler.maxErrors = 100 -- Maximum errors to store

-- Error severity levels
ErrorHandler.SEVERITY = {
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    CRITICAL = "CRITICAL"
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize error handler
function ErrorHandler.initialize()
    ErrorHandler.errors = {}
    ErrorHandler.errorCounts = {}

    Utils.logInfo("ErrorHandler initialized")
end

-- ============================================================================
-- ERROR CAPTURING
-- ============================================================================

--- Capture an error
-- @param errorType string Type/category of error
-- @param message string Error message
-- @param severity string Error severity (use ErrorHandler.SEVERITY)
-- @param context table Additional context data
function ErrorHandler.captureError(errorType, message, severity, context)
    severity = severity or ErrorHandler.SEVERITY.MEDIUM

    local error = {
        type = errorType,
        message = message,
        severity = severity,
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        context = context or {}
    }

    -- Add to error log
    table.insert(ErrorHandler.errors, 1, error)

    -- Trim if too many errors
    if #ErrorHandler.errors > ErrorHandler.maxErrors then
        table.remove(ErrorHandler.errors)
    end

    -- Update error counts
    if not ErrorHandler.errorCounts[errorType] then
        ErrorHandler.errorCounts[errorType] = 0
    end
    ErrorHandler.errorCounts[errorType] = ErrorHandler.errorCounts[errorType] + 1

    -- Log based on severity
    if severity == ErrorHandler.SEVERITY.CRITICAL or severity == ErrorHandler.SEVERITY.HIGH then
        Utils.logError(string.format("[%s] %s: %s", severity, errorType, message))
    else
        Utils.logWarning(string.format("[%s] %s: %s", severity, errorType, message))
    end

    -- Broadcast critical errors to players
    if severity == ErrorHandler.SEVERITY.CRITICAL then
        broadcastToAll("CRITICAL ERROR: " .. message, {1, 0, 0})
    end

    return error
end

-- ============================================================================
-- SAFE EXECUTION
-- ============================================================================

--- Execute a function safely with error handling
-- @param func function Function to execute
-- @param errorType string Error type for logging
-- @param ... any Function arguments
-- @return boolean Success
-- @return any Result or error message
function ErrorHandler.safeExecute(func, errorType, ...)
    local success, result = pcall(func, ...)

    if not success then
        ErrorHandler.captureError(
            errorType or "UNKNOWN_ERROR",
            tostring(result),
            ErrorHandler.SEVERITY.HIGH,
            {stackTrace = debug.traceback()}
        )
        return false, result
    end

    return true, result
end

--- Execute with retry logic
-- @param func function Function to execute
-- @param maxRetries number Maximum retry attempts
-- @param errorType string Error type for logging
-- @param ... any Function arguments
-- @return boolean Success
-- @return any Result or error message
function ErrorHandler.executeWithRetry(func, maxRetries, errorType, ...)
    maxRetries = maxRetries or 3
    local args = {...}

    for attempt = 1, maxRetries do
        local success, result = pcall(func, table.unpack(args))

        if success then
            return true, result
        end

        if attempt < maxRetries then
            Utils.logWarning(string.format("Retry %d/%d for %s: %s", attempt, maxRetries, errorType, tostring(result)))
            Wait.time(function() end, 0.5 * attempt) -- Exponential backoff
        else
            ErrorHandler.captureError(
                errorType or "RETRY_FAILED",
                tostring(result),
                ErrorHandler.SEVERITY.HIGH,
                {attempts = maxRetries}
            )
            return false, result
        end
    end

    return false, "Max retries exceeded"
end

-- ============================================================================
-- ERROR RECOVERY
-- ============================================================================

--- Attempt to recover from an error
-- @param errorType string Type of error
-- @param recoveryFunc function Recovery function
-- @return boolean Recovery successful
function ErrorHandler.attemptRecovery(errorType, recoveryFunc)
    Utils.logInfo("Attempting recovery for: " .. errorType)

    local success, result = pcall(recoveryFunc)

    if success then
        Utils.logInfo("Recovery successful for: " .. errorType)
        return true
    else
        ErrorHandler.captureError(
            "RECOVERY_FAILED",
            string.format("Failed to recover from %s: %s", errorType, tostring(result)),
            ErrorHandler.SEVERITY.HIGH
        )
        return false
    end
end

-- ============================================================================
-- ERROR REPORTING
-- ============================================================================

--- Get error statistics
-- @return table Error statistics
function ErrorHandler.getStatistics()
    local stats = {
        totalErrors = #ErrorHandler.errors,
        errorsByType = {},
        errorsBySeverity = {
            [ErrorHandler.SEVERITY.LOW] = 0,
            [ErrorHandler.SEVERITY.MEDIUM] = 0,
            [ErrorHandler.SEVERITY.HIGH] = 0,
            [ErrorHandler.SEVERITY.CRITICAL] = 0
        },
        recentErrors = {}
    }

    -- Count by type
    for errorType, count in pairs(ErrorHandler.errorCounts) do
        stats.errorsByType[errorType] = count
    end

    -- Count by severity and get recent errors
    local recentCount = math.min(10, #ErrorHandler.errors)
    for i = 1, recentCount do
        local error = ErrorHandler.errors[i]
        stats.errorsBySeverity[error.severity] = stats.errorsBySeverity[error.severity] + 1
        table.insert(stats.recentErrors, {
            type = error.type,
            message = error.message,
            severity = error.severity,
            timestamp = error.timestamp
        })
    end

    return stats
end

--- Generate error report text
-- @return string Formatted error report
function ErrorHandler.generateReportText()
    local stats = ErrorHandler.getStatistics()

    local text = string.format([[
=== ERROR REPORT ===
Total Errors: %d

ERRORS BY SEVERITY:
  CRITICAL: %d
  HIGH: %d
  MEDIUM: %d
  LOW: %d

]],
        stats.totalErrors,
        stats.errorsBySeverity[ErrorHandler.SEVERITY.CRITICAL],
        stats.errorsBySeverity[ErrorHandler.SEVERITY.HIGH],
        stats.errorsBySeverity[ErrorHandler.SEVERITY.MEDIUM],
        stats.errorsBySeverity[ErrorHandler.SEVERITY.LOW]
    )

    text = text .. "ERRORS BY TYPE:\n"
    for errorType, count in pairs(stats.errorsByType) do
        text = text .. string.format("  %s: %d\n", errorType, count)
    end

    text = text .. "\nRECENT ERRORS:\n"
    for i, error in ipairs(stats.recentErrors) do
        text = text .. string.format("  %d. [%s] %s: %s (%s)\n",
            i,
            error.severity,
            error.type,
            error.message,
            error.timestamp
        )
    end

    return text
end

--- Get user-friendly error message
-- @param error table Error object
-- @return string User-friendly message
function ErrorHandler.getUserMessage(error)
    local userMessages = {
        DATA_VALIDATION_FAILED = "There was a problem with the campaign data. Please check your recent changes.",
        UNIT_NOT_FOUND = "The selected unit could not be found.",
        PLAYER_NOT_FOUND = "The selected player could not be found.",
        SAVE_FAILED = "Failed to save campaign. Please try again.",
        LOAD_FAILED = "Failed to load campaign. The save data may be corrupted.",
        NETWORK_ERROR = "A network error occurred. Please check your connection.",
        PERMISSION_DENIED = "You don't have permission to perform this action."
    }

    return userMessages[error.type] or "An error occurred: " .. error.message
end

-- ============================================================================
-- UTILITIES
-- ============================================================================

--- Clear error log
function ErrorHandler.clearErrors()
    ErrorHandler.errors = {}
    ErrorHandler.errorCounts = {}
    Utils.logInfo("Error log cleared")
end

--- Export errors to JSON
-- @return string JSON string
function ErrorHandler.exportErrors()
    return Utils.safeJSONEncode({
        errors = ErrorHandler.errors,
        statistics = ErrorHandler.getStatistics()
    })
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return ErrorHandler
