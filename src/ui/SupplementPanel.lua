--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Supplement Panel UI
=====================================
Version: 1.0.0-alpha

Dedicated panel for viewing and managing Crusade supplement data:
- Campaign phase tracking
- Alliance standings and player assignments
- Per-player resource management (Blackstone Fragments, Battle Points, etc.)
- Strategic Footing selection (Pariah Nexus)
- Crusade Blessings purchasing
]]

local Utils = require("src/core/Utils")
local Constants = require("src/core/Constants")
local MissionPackResources = require("src/campaign/MissionPackResources")

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local SupplementPanel = {
    campaign = nil,
    currentTab = "overview", -- "overview", "alliances", "blessings"
    selectedPlayerId = nil
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize supplement panel
-- @param campaign table Active campaign object
function SupplementPanel.initialize(campaign)
    SupplementPanel.campaign = campaign
    log("Supplement Panel initialized")
end

--- Check if the active campaign uses a supplement
-- @return boolean True if supplement is active
function SupplementPanel.hasActiveSupplement()
    if not SupplementPanel.campaign then
        return false
    end
    local supp = SupplementPanel.campaign.crusadeSupplement
    return supp and supp ~= "none"
end

--- Get the active supplement display name
-- @return string Supplement name or nil
function SupplementPanel.getSupplementName()
    if not SupplementPanel.campaign then
        return nil
    end
    local suppId = SupplementPanel.campaign.crusadeSupplement
    for _, supp in ipairs(Constants.CRUSADE_SUPPLEMENTS) do
        if supp.id == suppId then
            return supp.name
        end
    end
    return nil
end

-- ============================================================================
-- CONTENT BUILDING
-- ============================================================================

--- Build the full supplement panel content
-- @return table Array of XML table elements
function SupplementPanel.buildContent()
    local campaign = SupplementPanel.campaign
    if not campaign or not SupplementPanel.hasActiveSupplement() then
        return { { tag = "Text", attributes = {
            text = "No Crusade supplement is active for this campaign.",
            fontSize = "12", color = "#888888", alignment = "MiddleCenter"
        } } }
    end

    local suppId = campaign.crusadeSupplement
    local suppData = Constants.SUPPLEMENT_DATA[suppId]
    local supplementName = SupplementPanel.getSupplementName() or suppId

    local children = {}

    -- Header
    table.insert(children, { tag = "Text", attributes = {
        text = supplementName,
        fontSize = "18", color = "#D4A843", alignment = "MiddleCenter", fontStyle = "Bold"
    } })

    -- Campaign Phase indicator (for phased campaigns)
    if suppData and suppData.campaignPhases and suppData.campaignPhases > 0 then
        local currentPhase = campaign.currentCampaignPhase or 1
        local totalPhases = campaign.campaignPhaseCount or suppData.campaignPhases

        table.insert(children, { tag = "Panel", attributes = {
            height = "36", color = "rgba(30,30,40,0.9)", padding = "5"
        }, children = {
            { tag = "HorizontalLayout", attributes = { spacing = "8" }, children = {
                { tag = "Text", attributes = {
                    text = "Campaign Phase",
                    fontSize = "13", color = "#BBBBBB", width = "55%"
                } },
                { tag = "Text", attributes = {
                    text = currentPhase .. " of " .. totalPhases,
                    fontSize = "16", color = "#D4A843", fontStyle = "Bold", width = "25%",
                    alignment = "MiddleCenter"
                } },
                { tag = "Button", attributes = {
                    id = "supplement_advancePhase",
                    onClick = "onUIButtonClick",
                    width = "20%", fontSize = "10",
                    colors = "#8B6914|#D4A843|#6B5010|#44340A",
                    textColor = "#FFFFFF",
                    interactable = currentPhase < totalPhases and "true" or "false"
                }, value = "Advance" }
            } }
        } })
    end

    -- Tab buttons
    table.insert(children, { tag = "Panel", attributes = { height = "4" } })

    local tabs = { { id = "overview", label = "Overview" } }
    if suppData and suppData.allianceTypes and #suppData.allianceTypes > 0 then
        table.insert(tabs, { id = "alliances", label = "Alliances" })
    end
    if suppId == "pariah_nexus" then
        table.insert(tabs, { id = "blessings", label = "Blessings" })
    end

    if #tabs > 1 then
        local tabChildren = {}
        for _, tab in ipairs(tabs) do
            local isActive = (SupplementPanel.currentTab == tab.id)
            table.insert(tabChildren, { tag = "Button", attributes = {
                id = "supplement_tab_" .. tab.id,
                onClick = "onUIButtonClick",
                fontSize = "11",
                colors = isActive and "#8B6914|#D4A843|#6B5010|#44340A" or "#333333|#555555|#222222|#111111",
                textColor = isActive and "#FFFFFF" or "#999999",
                fontStyle = isActive and "Bold" or "Normal"
            }, value = tab.label })
        end
        table.insert(children, { tag = "HorizontalLayout", attributes = {
            spacing = "4", height = "30"
        }, children = tabChildren })
    end

    table.insert(children, { tag = "Panel", attributes = { height = "1", color = "#333333" } })
    table.insert(children, { tag = "Panel", attributes = { height = "4" } })

    -- Tab content
    if SupplementPanel.currentTab == "overview" then
        SupplementPanel._buildOverviewTab(children, suppId, suppData)
    elseif SupplementPanel.currentTab == "alliances" then
        SupplementPanel._buildAlliancesTab(children, suppId, suppData)
    elseif SupplementPanel.currentTab == "blessings" then
        SupplementPanel._buildBlessingsTab(children, suppId)
    end

    return children
end

--- Build the Overview tab content
-- @param children table Children array to append to
-- @param suppId string Supplement ID
-- @param suppData table Supplement data from Constants
function SupplementPanel._buildOverviewTab(children, suppId, suppData)
    local campaign = SupplementPanel.campaign

    -- Section: Player Resources
    table.insert(children, { tag = "Text", attributes = {
        text = "PLAYER RESOURCES",
        fontSize = "13", color = "#D4A843", fontStyle = "Bold"
    } })

    local resourceTypes = MissionPackResources.getSupplementResourceTypes(suppId)

    if #resourceTypes == 0 then
        table.insert(children, { tag = "Text", attributes = {
            text = "No tracked resources for this supplement.",
            fontSize = "11", color = "#666666"
        } })
    else
        -- Header row
        local headerChildren = {
            { tag = "Text", attributes = {
                text = "Player", fontSize = "10", color = "#888888", width = "35%"
            } }
        }
        for _, rt in ipairs(resourceTypes) do
            table.insert(headerChildren, { tag = "Text", attributes = {
                text = rt.name, fontSize = "9", color = "#888888",
                width = tostring(math.floor(55 / #resourceTypes)) .. "%",
                alignment = "MiddleCenter"
            } })
        end
        table.insert(headerChildren, { tag = "Text", attributes = {
            text = "", width = "10%"
        } })
        table.insert(children, { tag = "HorizontalLayout", attributes = {
            spacing = "3", height = "18"
        }, children = headerChildren })

        -- Player rows
        for playerId, player in pairs(campaign.players) do
            local rowChildren = {
                { tag = "Text", attributes = {
                    text = player.name,
                    fontSize = "11", color = "#CCCCCC", width = "35%"
                } }
            }

            for _, rt in ipairs(resourceTypes) do
                local amount = MissionPackResources.getPlayerResource(player, rt.name)
                table.insert(rowChildren, { tag = "Text", attributes = {
                    text = tostring(amount),
                    fontSize = "13", color = "#EEEEEE", fontStyle = "Bold",
                    width = tostring(math.floor(55 / #resourceTypes)) .. "%",
                    alignment = "MiddleCenter"
                } })
            end

            -- Edit button
            table.insert(rowChildren, { tag = "Button", attributes = {
                id = "supplement_editPlayer_" .. playerId,
                onClick = "onUIButtonClick",
                width = "10%", fontSize = "9",
                colors = "#444444|#666666|#333333|#222222",
                textColor = "#AAAAAA"
            }, value = "Edit" })

            table.insert(children, { tag = "HorizontalLayout", attributes = {
                spacing = "3", height = "28", color = "rgba(30,30,40,0.6)"
            }, children = rowChildren })
        end
    end

    -- Section: Strategic Footings (Pariah Nexus only)
    if suppData and suppData.hasStrategicFootings then
        table.insert(children, { tag = "Panel", attributes = { height = "6" } })
        table.insert(children, { tag = "Text", attributes = {
            text = "STRATEGIC FOOTINGS",
            fontSize = "13", color = "#D4A843", fontStyle = "Bold"
        } })
        table.insert(children, { tag = "Text", attributes = {
            text = "Each player selects a footing before battle. Selection is revealed simultaneously.",
            fontSize = "10", color = "#666666"
        } })

        for _, footing in ipairs(Constants.STRATEGIC_FOOTINGS) do
            table.insert(children, { tag = "Panel", attributes = {
                height = "24", color = "rgba(30,30,40,0.6)", padding = "3"
            }, children = {
                { tag = "HorizontalLayout", attributes = { spacing = "5" }, children = {
                    { tag = "Panel", attributes = { width = "4", height = "100%", color = "#8B6914" } },
                    { tag = "Text", attributes = {
                        text = footing,
                        fontSize = "12", color = "#CCCCCC"
                    } }
                } }
            } })
        end
    end

    -- Section: Supplement Features summary
    if suppData then
        table.insert(children, { tag = "Panel", attributes = { height = "6" } })
        table.insert(children, { tag = "Text", attributes = {
            text = "SUPPLEMENT FEATURES",
            fontSize = "13", color = "#D4A843", fontStyle = "Bold"
        } })

        local features = {}
        if suppData.hasStrategicFootings then
            table.insert(features, "Strategic Footings")
        end
        if suppData.hasUpgradeTrees then
            table.insert(features, "Upgrade Trees (Monster Hunters / Striding Behemoths)")
        end
        if suppData.hasStrategicSites then
            table.insert(features, "Strategic Sites")
        end
        if suppData.hasTacticalReserves then
            table.insert(features, "Tactical Reserves & Surgical Deep Strike")
        end
        if suppData.hasTreeCampaign then
            table.insert(features, "Tree-based Campaign Progression")
        end
        if suppData.hasAnomalies then
            table.insert(features, "Warp Anomalies")
        end
        if #features == 0 then
            table.insert(features, "Core supplement rules active")
        end

        for _, feat in ipairs(features) do
            table.insert(children, { tag = "Text", attributes = {
                text = "  - " .. feat,
                fontSize = "10", color = "#BBBBBB"
            } })
        end
    end
end

--- Build the Alliances tab content
-- @param children table Children array to append to
-- @param suppId string Supplement ID
-- @param suppData table Supplement data from Constants
function SupplementPanel._buildAlliancesTab(children, suppId, suppData)
    local campaign = SupplementPanel.campaign
    if not suppData or not suppData.allianceTypes then
        return
    end

    table.insert(children, { tag = "Text", attributes = {
        text = "ALLIANCE ASSIGNMENTS",
        fontSize = "13", color = "#D4A843", fontStyle = "Bold"
    } })
    table.insert(children, { tag = "Text", attributes = {
        text = "Assign players to alliances. Click a player under an alliance to reassign them.",
        fontSize = "10", color = "#666666"
    } })

    table.insert(children, { tag = "Panel", attributes = { height = "4" } })

    -- Build alliance-to-members lookup from campaign.alliances
    local allianceByName = {}
    for allianceId, alliance in pairs(campaign.alliances or {}) do
        allianceByName[alliance.name] = {
            id = allianceId,
            alliance = alliance
        }
    end

    -- Display each alliance type
    for _, allianceInfo in ipairs(suppData.allianceTypes) do
        local allianceEntry = allianceByName[allianceInfo.name]
        local memberCount = 0
        if allianceEntry and allianceEntry.alliance.members then
            memberCount = #allianceEntry.alliance.members
        end

        -- Alliance header
        table.insert(children, { tag = "Panel", attributes = {
            height = "30", color = "rgba(40,35,20,0.8)", padding = "4"
        }, children = {
            { tag = "HorizontalLayout", attributes = { spacing = "5" }, children = {
                { tag = "Panel", attributes = { width = "4", height = "100%", color = "#D4A843" } },
                { tag = "Text", attributes = {
                    text = allianceInfo.name .. " (" .. memberCount .. " players)",
                    fontSize = "13", color = "#D4A843", fontStyle = "Bold"
                } }
            } }
        } })

        -- Alliance description
        table.insert(children, { tag = "Text", attributes = {
            text = "  " .. allianceInfo.description,
            fontSize = "9", color = "#888888"
        } })

        -- Member list
        if allianceEntry and allianceEntry.alliance.members then
            for _, memberId in ipairs(allianceEntry.alliance.members) do
                local player = campaign.players[memberId]
                if player then
                    table.insert(children, { tag = "HorizontalLayout", attributes = {
                        spacing = "5", height = "24", color = "rgba(30,30,40,0.6)"
                    }, children = {
                        { tag = "Panel", attributes = { width = "20" } },
                        { tag = "Text", attributes = {
                            text = player.name .. " (" .. player.faction .. ")",
                            fontSize = "11", color = "#CCCCCC", width = "70%"
                        } },
                        { tag = "Button", attributes = {
                            id = "supplement_removeFromAlliance_" .. allianceEntry.id .. "_" .. memberId,
                            onClick = "onUIButtonClick",
                            width = "20%", fontSize = "9",
                            colors = "#553333|#774444|#442222|#331111",
                            textColor = "#CC8888"
                        }, value = "Remove" }
                    } })
                end
            end
        end

        table.insert(children, { tag = "Panel", attributes = { height = "2" } })
    end

    -- Unassigned players section
    table.insert(children, { tag = "Panel", attributes = { height = "6" } })
    table.insert(children, { tag = "Panel", attributes = { height = "1", color = "#333333" } })
    table.insert(children, { tag = "Panel", attributes = { height = "4" } })
    table.insert(children, { tag = "Text", attributes = {
        text = "UNASSIGNED PLAYERS",
        fontSize = "12", color = "#999999"
    } })

    local hasUnassigned = false
    for playerId, player in pairs(campaign.players) do
        local isAssigned = false
        for _, alliance in pairs(campaign.alliances or {}) do
            if Utils.tableContains(alliance.members, playerId) then
                isAssigned = true
                break
            end
        end

        if not isAssigned then
            hasUnassigned = true
            -- Show player with assignment buttons
            local assignButtons = {}
            for _, allianceInfo in ipairs(suppData.allianceTypes) do
                local allianceEntry = allianceByName[allianceInfo.name]
                if allianceEntry then
                    table.insert(assignButtons, { tag = "Button", attributes = {
                        id = "supplement_assignToAlliance_" .. allianceEntry.id .. "_" .. playerId,
                        onClick = "onUIButtonClick",
                        fontSize = "9",
                        colors = "#333355|#444477|#222244|#111133",
                        textColor = "#AAAAAA"
                    }, value = allianceInfo.name })
                end
            end

            table.insert(children, { tag = "Panel", attributes = {
                height = "46", color = "rgba(30,30,40,0.6)", padding = "3"
            }, children = {
                { tag = "Text", attributes = {
                    text = player.name .. " (" .. player.faction .. ")",
                    fontSize = "11", color = "#EEEEEE"
                } },
                { tag = "HorizontalLayout", attributes = {
                    spacing = "4", height = "22"
                }, children = assignButtons }
            } })
        end
    end

    if not hasUnassigned then
        table.insert(children, { tag = "Text", attributes = {
            text = "All players are assigned to alliances.",
            fontSize = "10", color = "#4CAF50"
        } })
    end
end

--- Build the Blessings tab content (Pariah Nexus)
-- @param children table Children array to append to
-- @param suppId string Supplement ID
function SupplementPanel._buildBlessingsTab(children, suppId)
    local campaign = SupplementPanel.campaign

    table.insert(children, { tag = "Text", attributes = {
        text = "CRUSADE BLESSINGS",
        fontSize = "13", color = "#D4A843", fontStyle = "Bold"
    } })
    table.insert(children, { tag = "Text", attributes = {
        text = "Spend Blackstone Fragments to purchase permanent upgrades.",
        fontSize = "10", color = "#666666"
    } })

    table.insert(children, { tag = "Panel", attributes = { height = "4" } })

    -- Player selector for blessing purchases
    table.insert(children, { tag = "Text", attributes = {
        text = "Select Player", fontSize = "11", color = "#BBBBBB"
    } })

    for playerId, player in pairs(campaign.players) do
        local isSelected = (SupplementPanel.selectedPlayerId == playerId)
        local bsf = MissionPackResources.getPlayerResource(player, "Blackstone Fragments")
        local btnColor = isSelected and "#2E6B3A|#3D8B4D|#1E4B2A|#152E1A" or "#333333|#555555|#222222|#111111"

        table.insert(children, { tag = "Button", attributes = {
            id = "supplement_selectPlayer_" .. playerId,
            onClick = "onUIButtonClick",
            height = "28", fontSize = "11",
            colors = btnColor,
            textColor = isSelected and "#FFFFFF" or "#AAAAAA"
        }, value = player.name .. " - BSF: " .. bsf })
    end

    -- Show blessings list for selected player
    if SupplementPanel.selectedPlayerId then
        local player = campaign.players[SupplementPanel.selectedPlayerId]
        if player then
            local bsf = MissionPackResources.getPlayerResource(player, "Blackstone Fragments")

            table.insert(children, { tag = "Panel", attributes = { height = "6" } })
            table.insert(children, { tag = "Panel", attributes = { height = "1", color = "#333333" } })
            table.insert(children, { tag = "Panel", attributes = { height = "4" } })

            table.insert(children, { tag = "Text", attributes = {
                text = player.name .. " - Available BSF: " .. bsf,
                fontSize = "12", color = "#D4A843"
            } })

            -- List purchased blessings
            if player.crusadeBlessings and #player.crusadeBlessings > 0 then
                table.insert(children, { tag = "Text", attributes = {
                    text = "Purchased:", fontSize = "10", color = "#4CAF50"
                } })
                for _, blessingName in ipairs(player.crusadeBlessings) do
                    table.insert(children, { tag = "Text", attributes = {
                        text = "  [X] " .. blessingName,
                        fontSize = "10", color = "#88CC88"
                    } })
                end
                table.insert(children, { tag = "Panel", attributes = { height = "4" } })
            end

            -- Available blessings (from config)
            table.insert(children, { tag = "Text", attributes = {
                text = "Available Blessings:",
                fontSize = "11", color = "#BBBBBB"
            } })

            -- Load blessings from supplement config
            local blessings = SupplementPanel._getAvailableBlessings(suppId)
            for _, blessing in ipairs(blessings) do
                local owned = false
                if player.crusadeBlessings then
                    for _, name in ipairs(player.crusadeBlessings) do
                        if name == blessing.name then
                            owned = true
                            break
                        end
                    end
                end

                local canAfford = bsf >= blessing.cost
                local statusColor = owned and "#555555" or (canAfford and "#CCCCCC" or "#664444")

                table.insert(children, { tag = "Panel", attributes = {
                    height = "50", color = "rgba(30,30,40,0.6)", padding = "4"
                }, children = {
                    { tag = "HorizontalLayout", attributes = { spacing = "5" }, children = {
                        { tag = "VerticalLayout", attributes = { width = "75%" }, children = {
                            { tag = "Text", attributes = {
                                text = blessing.name .. " (" .. blessing.cost .. " BSF)",
                                fontSize = "11", color = statusColor, fontStyle = "Bold"
                            } },
                            { tag = "Text", attributes = {
                                text = blessing.description,
                                fontSize = "9", color = "#888888"
                            } }
                        } },
                        { tag = "Button", attributes = {
                            id = "supplement_buyBlessing_" .. SupplementPanel.selectedPlayerId .. "_" .. blessing.name,
                            onClick = "onUIButtonClick",
                            width = "25%", fontSize = "10",
                            colors = owned and "#333333|#333333|#333333|#333333" or (canAfford and "#2E6B3A|#3D8B4D|#1E4B2A|#152E1A" or "#442222|#442222|#442222|#442222"),
                            textColor = owned and "#666666" or (canAfford and "#FFFFFF" or "#664444"),
                            interactable = (not owned and canAfford) and "true" or "false"
                        }, value = owned and "Owned" or "Buy" }
                    } }
                } })
            end
        end
    end
end

--- Get available blessings for a supplement
-- @param suppId string Supplement ID
-- @return table Array of blessing definitions
function SupplementPanel._getAvailableBlessings(suppId)
    if suppId == "pariah_nexus" then
        return {
            { name = "Single-Minded Seeker", cost = 10, description = "Warlord: D6+2 on win, 6+ = 3 BSF after each game." },
            { name = "Neuro-Emitter", cost = 15, description = "Once/battle: 3 friendly units get FNP 5+ vs Psychic." },
            { name = "Acquisitive Opportunist", cost = 15, description = "Warlord gains footing ability (Scouts/Lone Op/Stealth)." },
            { name = "Empathic Disinclinator", cost = 20, description = "One objective marker grants 5+ invuln to friendlies." },
            { name = "Empyrically Polarised Blackstone", cost = 20, description = "Change Strategic Footing after reveal (1/phase)." }
        }
    end
    return {}
end

-- ============================================================================
-- RESOURCE EDITING
-- ============================================================================

--- Add resource to a player
-- @param playerId string Player ID
-- @param resourceName string Resource name
-- @param amount number Amount to add
function SupplementPanel.addResource(playerId, resourceName, amount)
    local campaign = SupplementPanel.campaign
    if not campaign then return end

    local player = campaign.players[playerId]
    if not player then return end

    MissionPackResources.addPlayerResource(player, resourceName, amount, nil, campaign.log)
    Utils.logInfo(player.name .. " gained " .. amount .. " " .. resourceName)
end

--- Spend resource from a player
-- @param playerId string Player ID
-- @param resourceName string Resource name
-- @param amount number Amount to spend
-- @return boolean Success
function SupplementPanel.spendResource(playerId, resourceName, amount)
    local campaign = SupplementPanel.campaign
    if not campaign then return false end

    local player = campaign.players[playerId]
    if not player then return false end

    local success = MissionPackResources.spendPlayerResource(player, resourceName, amount, campaign.log)
    if success then
        Utils.logInfo(player.name .. " spent " .. amount .. " " .. resourceName)
    end
    return success
end

--- Purchase a Crusade Blessing for a player
-- @param playerId string Player ID
-- @param blessingName string Blessing name
-- @param cost number BSF cost
-- @return boolean Success
function SupplementPanel.purchaseBlessing(playerId, blessingName, cost)
    local campaign = SupplementPanel.campaign
    if not campaign then return false end

    local player = campaign.players[playerId]
    if not player then return false end

    -- Check if already owned
    if player.crusadeBlessings then
        for _, name in ipairs(player.crusadeBlessings) do
            if name == blessingName then
                return false
            end
        end
    end

    -- Spend BSF
    local success = MissionPackResources.spendPlayerResource(
        player, "Blackstone Fragments", cost, campaign.log
    )
    if not success then
        return false
    end

    -- Add blessing
    if not player.crusadeBlessings then
        player.crusadeBlessings = {}
    end
    table.insert(player.crusadeBlessings, blessingName)

    -- Log
    table.insert(campaign.log, {
        type = "RESOURCE_SPENT",
        timestamp = Utils.getUnixTimestamp(),
        details = {
            player = player.name,
            resource = "Crusade Blessing: " .. blessingName,
            amount = cost
        }
    })

    Utils.logInfo(player.name .. " purchased blessing: " .. blessingName)
    broadcastToAll(player.name .. " purchased: " .. blessingName, {0.83, 0.66, 0.26})
    return true
end

-- ============================================================================
-- ALLIANCE MANAGEMENT
-- ============================================================================

--- Assign a player to an alliance
-- @param allianceId string Alliance ID
-- @param playerId string Player ID
function SupplementPanel.assignToAlliance(allianceId, playerId)
    local campaign = SupplementPanel.campaign
    if not campaign then return end

    local alliance = campaign.alliances[allianceId]
    local player = campaign.players[playerId]
    if not alliance or not player then return end

    -- Remove from any existing alliance first
    for _, a in pairs(campaign.alliances) do
        Utils.removeByValue(a.members, playerId)
    end

    -- Add to new alliance
    table.insert(alliance.members, playerId)

    Utils.logInfo(player.name .. " assigned to alliance: " .. alliance.name)
    broadcastToAll(player.name .. " joined " .. alliance.name, {0.83, 0.66, 0.26})
end

--- Remove a player from an alliance
-- @param allianceId string Alliance ID
-- @param playerId string Player ID
function SupplementPanel.removeFromAlliance(allianceId, playerId)
    local campaign = SupplementPanel.campaign
    if not campaign then return end

    local alliance = campaign.alliances[allianceId]
    local player = campaign.players[playerId]
    if not alliance or not player then return end

    Utils.removeByValue(alliance.members, playerId)
    Utils.logInfo(player.name .. " removed from alliance: " .. alliance.name)
end

-- ============================================================================
-- CAMPAIGN PHASE MANAGEMENT
-- ============================================================================

--- Advance to the next campaign phase
function SupplementPanel.advancePhase()
    local campaign = SupplementPanel.campaign
    if not campaign then return end

    local maxPhase = campaign.campaignPhaseCount or 0
    local current = campaign.currentCampaignPhase or 1

    if current >= maxPhase then
        broadcastToAll("Campaign is already at the final phase!", {1, 0.5, 0})
        return
    end

    campaign.currentCampaignPhase = current + 1

    table.insert(campaign.log, {
        type = "MANUAL_NOTE",
        timestamp = Utils.getUnixTimestamp(),
        details = {
            message = "Campaign advanced to Phase " .. campaign.currentCampaignPhase .. " of " .. maxPhase
        }
    })

    broadcastToAll("Campaign Phase " .. campaign.currentCampaignPhase .. " of " .. maxPhase .. " has begun!", {0.83, 0.66, 0.26})
    Utils.logInfo("Campaign advanced to phase " .. campaign.currentCampaignPhase)
end

-- ============================================================================
-- UI CALLBACKS
-- ============================================================================

--- Handle supplement panel button clicks
-- @param player object Player who clicked
-- @param value string Button value
-- @param id string Button ID
function SupplementPanel.handleClick(player, value, id)
    -- Tab switching
    if string.match(id, "^supplement_tab_(.+)") then
        SupplementPanel.currentTab = string.match(id, "^supplement_tab_(.+)")
        SupplementPanel.refresh()

    -- Advance campaign phase
    elseif id == "supplement_advancePhase" then
        SupplementPanel.advancePhase()
        SupplementPanel.refresh()

    -- Player selection (blessings tab)
    elseif string.match(id, "^supplement_selectPlayer_(.+)") then
        SupplementPanel.selectedPlayerId = string.match(id, "^supplement_selectPlayer_(.+)")
        SupplementPanel.refresh()

    -- Resource edit
    elseif string.match(id, "^supplement_editPlayer_(.+)") then
        local playerId = string.match(id, "^supplement_editPlayer_(.+)")
        SupplementPanel._showResourceEditor(playerId)

    -- Assign to alliance
    elseif string.match(id, "^supplement_assignToAlliance_(.+)_(.+)") then
        local allianceId, playerId = string.match(id, "^supplement_assignToAlliance_(.+)_(.+)")
        SupplementPanel.assignToAlliance(allianceId, playerId)
        SupplementPanel.refresh()

    -- Remove from alliance
    elseif string.match(id, "^supplement_removeFromAlliance_(.+)_(.+)") then
        local allianceId, playerId = string.match(id, "^supplement_removeFromAlliance_(.+)_(.+)")
        SupplementPanel.removeFromAlliance(allianceId, playerId)
        SupplementPanel.refresh()

    -- Buy blessing
    elseif string.match(id, "^supplement_buyBlessing_") then
        local rest = string.gsub(id, "^supplement_buyBlessing_", "")
        -- Extract playerId (first segment before _) and blessingName (rest)
        local playerId = string.match(rest, "^([^_]+)_")
        local blessingName = string.gsub(rest, "^[^_]+_", "")
        if playerId and blessingName then
            local blessings = SupplementPanel._getAvailableBlessings(
                SupplementPanel.campaign.crusadeSupplement
            )
            for _, b in ipairs(blessings) do
                if b.name == blessingName then
                    SupplementPanel.purchaseBlessing(playerId, blessingName, b.cost)
                    break
                end
            end
            SupplementPanel.refresh()
        end

    -- Resource increment/decrement
    elseif string.match(id, "^supplement_addResource_") then
        local rest = string.gsub(id, "^supplement_addResource_", "")
        local playerId, resourceName = string.match(rest, "^([^_]+)_(.+)")
        if playerId and resourceName then
            SupplementPanel.addResource(playerId, resourceName, 1)
            SupplementPanel.refresh()
        end

    elseif string.match(id, "^supplement_subResource_") then
        local rest = string.gsub(id, "^supplement_subResource_", "")
        local playerId, resourceName = string.match(rest, "^([^_]+)_(.+)")
        if playerId and resourceName then
            SupplementPanel.spendResource(playerId, resourceName, 1)
            SupplementPanel.refresh()
        end

    -- Close and back
    elseif id == "supplement_close" then
        -- Will be handled by UICore
    end
end

--- Show resource editor inline for a player (rebuilds overview with +/- buttons)
-- @param playerId string Player ID
function SupplementPanel._showResourceEditor(playerId)
    SupplementPanel.selectedPlayerId = playerId
    -- Refresh to show edit mode in overview
    SupplementPanel.refresh()
end

--- Refresh the supplement panel display
function SupplementPanel.refresh()
    local content = SupplementPanel.buildContent()

    -- Wrap in scrollable container
    local scrollContent = {
        tag = "VerticalLayout",
        attributes = {
            spacing = "4",
            padding = "4"
        },
        children = content
    }

    local fullXml = UI.getXmlTable()
    if fullXml then
        -- Find supplementContentArea and replace its children
        local found = false
        local function findAndReplace(elements)
            for _, element in ipairs(elements) do
                if element.attributes and element.attributes.id == "supplementContentArea" then
                    element.children = { scrollContent }
                    return true
                end
                if element.children then
                    if findAndReplace(element.children) then
                        return true
                    end
                end
            end
            return false
        end

        if findAndReplace(fullXml) then
            UI.setXmlTable(fullXml)
        else
            log("ERROR: Could not find supplementContentArea in UI XML tree")
        end
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return SupplementPanel
