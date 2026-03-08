#!/usr/bin/env lua5.1
--[[
=====================================
CRUSADE TRACKER - RUN ALL TESTS
=====================================

Execute from project root:
    lua5.1 tests/run_all.lua [filter]

Optional filter argument matches suite names.
Exit code 0 = all passed, 1 = some failed.
]]

-- Load all test files (each registers suites with the shared TestRunner)
-- Order matters: tts_mock must be loaded first by each test file

require("tests/test_datamodel")
require("tests/test_utils")
require("tests/test_crusade_points")
require("tests/test_experience")
require("tests/test_out_of_action")
require("tests/test_data_validator")
require("tests/test_tts_integration")
require("tests/test_integration")

-- Run
local T = require("tests/test_runner")
local filter = arg and arg[1] or nil
local allPassed = T.run(filter)

-- Exit with appropriate code
os.exit(allPassed and 0 or 1)
