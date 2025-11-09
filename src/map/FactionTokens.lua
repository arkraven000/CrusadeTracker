--[[
=====================================
FACTION TOKENS
Phase 8: Advanced UI Integration
=====================================

Manages faction-specific tokens on the hex map:
- Strategic objectives
- Fortifications
- Resource nodes
- Custom markers
]]

local FactionTokens = {}

-- Dependencies
local Utils = require("src/core/Utils")
local DataModel = require("src/core/DataModel")

-- Module state
FactionTokens.campaign = nil

-- Token types
FactionTokens.TOKEN_TYPES = {
    OBJECTIVE = "Strategic Objective",
    FORTIFICATION = "Fortification",
    RESOURCE = "Resource Node",
    RELIC = "Ancient Relic",
    SHRINE = "Sacred Shrine",
    OUTPOST = "Forward Outpost",
    CUSTOM = "Custom Marker"
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize the Faction Tokens module
-- @param campaign table Campaign data
function FactionTokens.initialize(campaign)
    FactionTokens.campaign = campaign

    Utils.logInfo("FactionTokens module initialized")
end

-- ============================================================================
-- TOKEN MANAGEMENT
-- ============================================================================

--- Place a token on a hex
-- @param hexKey string Hex identifier (q,r)
-- @param playerId string Player ID
-- @param tokenType string Type of token
-- @param data table Optional token data
-- @param campaignLog table Campaign log reference
-- @return table Token object
function FactionTokens.placeToken(hexKey, playerId, tokenType, data, campaignLog)
    if not FactionTokens.campaign or not FactionTokens.campaign.mapConfig then
        Utils.logError("Cannot place token: No map configured")
        return nil
    end

    local hex = FactionTokens.campaign.mapConfig.hexes[hexKey]
    if not hex then
        Utils.logError("Cannot place token: Hex not found - " .. hexKey)
        return nil
    end

    -- Initialize tokens array if needed
    if not hex.tokens then
        hex.tokens = {}
    end

    -- Create token
    local token = {
        id = Utils.generateGUID(),
        playerId = playerId,
        type = tokenType,
        placedDate = os.date("%Y-%m-%d %H:%M:%S"),
        data = data or {}
    }

    -- Add token to hex
    table.insert(hex.tokens, token)

    -- Log event
    local player = FactionTokens.campaign.players[playerId]
    if campaignLog then
        table.insert(campaignLog, DataModel.createEventLogEntry("TOKEN_PLACED", {
            player = player and player.name or "Unknown",
            tokenType = tokenType,
            hex = hexKey
        }))
    end

    Utils.logInfo(string.format("Token placed: %s by %s at %s", tokenType, player and player.name or playerId, hexKey))

    return token
end

--- Remove a token from a hex
-- @param hexKey string Hex identifier
-- @param tokenId string Token ID
-- @param campaignLog table Campaign log reference
-- @return boolean Success
function FactionTokens.removeToken(hexKey, tokenId, campaignLog)
    if not FactionTokens.campaign or not FactionTokens.campaign.mapConfig then
        return false
    end

    local hex = FactionTokens.campaign.mapConfig.hexes[hexKey]
    if not hex or not hex.tokens then
        return false
    end

    -- Find and remove token
    for i, token in ipairs(hex.tokens) do
        if token.id == tokenId then
            table.remove(hex.tokens, i)

            -- Log event
            if campaignLog then
                table.insert(campaignLog, DataModel.createEventLogEntry("TOKEN_REMOVED", {
                    tokenType = token.type,
                    hex = hexKey
                }))
            end

            Utils.logInfo(string.format("Token removed: %s from %s", token.type, hexKey))
            return true
        end
    end

    return false
end

--- Get all tokens for a player
-- @param playerId string Player ID
-- @return table Array of tokens with hex locations
function FactionTokens.getPlayerTokens(playerId)
    local tokens = {}

    if not FactionTokens.campaign or not FactionTokens.campaign.mapConfig then
        return tokens
    end

    for hexKey, hex in pairs(FactionTokens.campaign.mapConfig.hexes) do
        if hex.tokens then
            for _, token in ipairs(hex.tokens) do
                if token.playerId == playerId then
                    table.insert(tokens, {
                        token = token,
                        hexKey = hexKey,
                        hex = hex
                    })
                end
            end
        end
    end

    return tokens
end

--- Get all tokens on a hex
-- @param hexKey string Hex identifier
-- @return table Array of tokens
function FactionTokens.getHexTokens(hexKey)
    if not FactionTokens.campaign or not FactionTokens.campaign.mapConfig then
        return {}
    end

    local hex = FactionTokens.campaign.mapConfig.hexes[hexKey]
    if not hex or not hex.tokens then
        return {}
    end

    return hex.tokens
end

--- Get token count by type for a player
-- @param playerId string Player ID
-- @param tokenType string Token type (optional, counts all if nil)
-- @return number Token count
function FactionTokens.getTokenCount(playerId, tokenType)
    local count = 0
    local playerTokens = FactionTokens.getPlayerTokens(playerId)

    for _, entry in ipairs(playerTokens) do
        if not tokenType or entry.token.type == tokenType then
            count = count + 1
        end
    end

    return count
end

-- ============================================================================
-- TOKEN EFFECTS
-- ============================================================================

--- Apply token effects for a player (e.g., resource generation)
-- @param playerId string Player ID
-- @param campaignLog table Campaign log reference
-- @return table Summary of effects applied
function FactionTokens.applyTokenEffects(playerId, campaignLog)
    local effects = {
        rpGained = 0,
        resourcesGained = {},
        bonuses = {}
    }

    local playerTokens = FactionTokens.getPlayerTokens(playerId)

    for _, entry in ipairs(playerTokens) do
        local token = entry.token

        -- Apply effects based on token type
        if token.type == FactionTokens.TOKEN_TYPES.RESOURCE then
            -- Resource nodes generate RP
            effects.rpGained = effects.rpGained + (token.data.rpPerTurn or 1)

        elseif token.type == FactionTokens.TOKEN_TYPES.FORTIFICATION then
            -- Fortifications provide defensive bonuses
            table.insert(effects.bonuses, {
                type = "Defensive",
                description = "Fortification at " .. entry.hexKey
            })

        elseif token.type == FactionTokens.TOKEN_TYPES.SHRINE then
            -- Shrines provide morale bonuses
            table.insert(effects.bonuses, {
                type = "Morale",
                description = "Sacred Shrine at " .. entry.hexKey
            })
        end
    end

    -- Apply RP if any gained
    if effects.rpGained > 0 then
        local player = FactionTokens.campaign.players[playerId]
        if player then
            player.requisitionPoints = (player.requisitionPoints or 0) + effects.rpGained

            if campaignLog then
                table.insert(campaignLog, DataModel.createEventLogEntry("RP_GAINED", {
                    player = player.name,
                    amount = effects.rpGained,
                    source = "Faction Tokens"
                }))
            end
        end
    end

    return effects
end

-- ============================================================================
-- VALIDATION
-- ============================================================================

--- Check if a player can place a token at a hex
-- @param hexKey string Hex identifier
-- @param playerId string Player ID
-- @param tokenType string Token type
-- @return boolean Can place
-- @return string Reason if cannot place
function FactionTokens.canPlaceToken(hexKey, playerId, tokenType)
    if not FactionTokens.campaign or not FactionTokens.campaign.mapConfig then
        return false, "No map configured"
    end

    local hex = FactionTokens.campaign.mapConfig.hexes[hexKey]
    if not hex then
        return false, "Hex not claimed"
    end

    -- Check if player controls the hex (optional rule)
    if hex.controllerId and hex.controllerId ~= playerId then
        return false, "Hex controlled by another player"
    end

    -- Check token limits (if configured)
    local maxTokensPerHex = FactionTokens.campaign.rules.maxTokensPerHex or 3
    local currentTokens = hex.tokens and #hex.tokens or 0

    if currentTokens >= maxTokensPerHex then
        return false, "Maximum tokens on hex reached"
    end

    return true, "OK"
end

-- ============================================================================
-- STATISTICS
-- ============================================================================

--- Get token statistics for all players
-- @return table Token statistics by player
function FactionTokens.getTokenStatistics()
    local stats = {}

    if not FactionTokens.campaign then
        return stats
    end

    for playerId, player in pairs(FactionTokens.campaign.players) do
        stats[playerId] = {
            playerName = player.name,
            totalTokens = 0,
            byType = {}
        }

        -- Count tokens by type
        for tokenType, typeName in pairs(FactionTokens.TOKEN_TYPES) do
            local count = FactionTokens.getTokenCount(playerId, typeName)
            stats[playerId].byType[typeName] = count
            stats[playerId].totalTokens = stats[playerId].totalTokens + count
        end
    end

    return stats
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

return FactionTokens
