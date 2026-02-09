--[[
=====================================
CRUSADE CAMPAIGN TRACKER
Constants & Configuration
=====================================
Version: 1.0.0-alpha
]]

-- ============================================================================
-- GLOBAL CONSTANTS
-- ============================================================================

CAMPAIGN_VERSION = "1.0.0-alpha"
EDITION = "10th"

-- ============================================================================
-- CAPACITY LIMITS
-- ============================================================================

MAX_PLAYERS = 20
MAX_UNITS_PER_PLAYER = 50
MAX_HEXES = 50
MAX_UNITS_ON_MAP = 20
MAX_RP = 5 -- Per 10th Edition rules, players normally cannot exceed 5 RP
MAX_BATTLE_HONOURS_NON_CHAR = 3
MAX_BATTLE_HONOURS_CHAR = 6
MAX_BATTLE_SCARS = 3
NON_CHAR_XP_CAP = 30

-- ============================================================================
-- TIMING & PERFORMANCE
-- ============================================================================

AUTOSAVE_INTERVAL = 300 -- 5 minutes in seconds
MAX_BACKUP_VERSIONS = 10
UI_UPDATE_THROTTLE = 0.1 -- seconds between UI batch updates
MAX_EVENT_LOG_SIZE = 1000

-- ============================================================================
-- HEX MAP DEFAULTS
-- ============================================================================

HEX_SIZE = 2.0 -- TTS units
DEFAULT_MAP_WIDTH = 7
DEFAULT_MAP_HEIGHT = 7
MAP_CENTER = {x = 0, y = 1, z = 0}

-- Map Skin System (FTC-Inspired Architecture)
HEX_GRID_BASE_HEIGHT = 1.0 -- Y position for functional hex grid zones
MAP_SKIN_HEIGHT = 1.05 -- Y position for visual map skins (above base)
TERRITORY_OVERLAY_HEIGHT = 1.15 -- Y position for territory control overlays (above skin)

-- Map Skin Settings
DEFAULT_MAP_SKIN = "forgeWorld" -- Default preset skin to load
OVERLAY_ALPHA_DEFAULT = 0.4 -- Default transparency for territory overlays

-- ============================================================================
-- CAMPAIGN DEFAULTS
-- ============================================================================

DEFAULT_SUPPLY_LIMIT = 1000
SUPPLY_LIMIT_INCREASE = 200
STARTING_RP = 5

-- ============================================================================
-- TTS PLAYER COLORS (RGB values)
-- ============================================================================

PLAYER_COLORS = {
    White = {1, 1, 1, 1},
    Red = {0.86, 0.1, 0.09, 1},
    Orange = {0.96, 0.44, 0.09, 1},
    Yellow = {0.9, 0.9, 0.17, 1},
    Green = {0.19, 0.7, 0.17, 1},
    Teal = {0.13, 0.69, 0.61, 1},
    Blue = {0.12, 0.53, 1, 1},
    Purple = {0.63, 0.12, 0.94, 1},
    Pink = {0.96, 0.44, 0.81, 1},
    Grey = {0.5, 0.5, 0.5, 1},
    Black = {0.25, 0.25, 0.25, 1},
    Brown = {0.44, 0.23, 0.09, 1}
}

PLAYER_COLOR_NAMES = {
    "White", "Red", "Orange", "Yellow", "Green", "Teal",
    "Blue", "Purple", "Pink", "Grey", "Black", "Brown"
}

-- ============================================================================
-- 10TH EDITION RANK THRESHOLDS
-- ============================================================================

RANK_THRESHOLDS = {
    {rank = 1, name = "Battle-Ready", minXP = 0, characterOnly = false},
    {rank = 2, name = "Blooded", minXP = 6, characterOnly = false},
    {rank = 3, name = "Battle-Hardened", minXP = 16, characterOnly = false},
    {rank = 4, name = "Heroic", minXP = 31, characterOnly = true},
    {rank = 5, name = "Legendary", minXP = 51, characterOnly = true}
}

-- ============================================================================
-- 10TH EDITION REQUISITION COSTS
-- ============================================================================

REQUISITION_COSTS = {
    ["Increase Supply Limit"] = {
        baseCost = 1,
        maxCost = 1,
        timing = "any time"
    },
    ["Renowned Heroes"] = {
        baseCost = 1,
        maxCost = 3,
        timing = "on unit creation OR on rank up",
        characterOnly = true
    },
    ["Legendary Veterans"] = {
        baseCost = 3,
        maxCost = 3,
        timing = "when unit reaches 30 XP",
        nonCharacterOnly = true
    },
    ["Rearm and Resupply"] = {
        baseCost = 1,
        maxCost = 1,
        timing = "before a battle"
    },
    ["Repair and Recuperate"] = {
        baseCost = 1,
        maxCost = 5,
        timing = "after a battle"
    },
    ["Fresh Recruits"] = {
        baseCost = 1,
        maxCost = 4,
        timing = "any time"
    }
}

-- ============================================================================
-- WEAPON MODIFICATION TYPES (10th Edition - 6 types)
-- ============================================================================

WEAPON_MODIFICATIONS = {
    {id = 1, name = "Finely Balanced", effect = "Improve BS or WS by 1"},
    {id = 2, name = "Brutal", effect = "Add 1 to Strength"},
    {id = 3, name = "Armour Piercing", effect = "Improve AP by 1"},
    {id = 4, name = "Master-Worked", effect = "Add 1 to Damage"},
    {id = 5, name = "Heirloom", effect = "Add 1 to Attacks"},
    {id = 6, name = "Precise", effect = "Critical Wounds gain Precision"}
}

-- ============================================================================
-- BATTLE SCAR TYPES (10th Edition - 6 types)
-- ============================================================================

BATTLE_SCARS = {
    {id = 1, name = "Crippling Damage", effect = "Cannot Advance, -1\" Move"},
    {id = 2, name = "Battle-Weary", effect = "-1 to Battle-shock, Leadership, Desperate Escape, Out of Action tests"},
    {id = 3, name = "Fatigued", effect = "-1 OC, no Charge bonus"},
    {id = 4, name = "Disgraced", effect = "Cannot use Stratagems, cannot be Marked for Greatness"},
    {id = 5, name = "Mark of Shame", effect = "Cannot attach, unaffected by Auras, cannot be Marked for Greatness"},
    {id = 6, name = "Deep Scars", effect = "Critical Hits auto-wound"}
}

-- ============================================================================
-- CRUSADE RELIC TIERS
-- ============================================================================

RELIC_TIERS = {
    Artificer = {
        rankRequired = 1,
        crusadePointsCost = 1,
        description = "Any rank"
    },
    Antiquity = {
        rankRequired = 4,
        crusadePointsCost = 2,
        description = "Heroic/Legendary only"
    },
    Legendary = {
        rankRequired = 5,
        crusadePointsCost = 3,
        description = "Legendary only"
    }
}

-- ============================================================================
-- EVENT TYPES (for logging)
-- ============================================================================

EVENT_TYPES = {
    -- Campaign
    "CAMPAIGN_CREATED",
    "CAMPAIGN_LOADED",
    "CAMPAIGN_SAVED",
    "CAMPAIGN_EXPORTED",
    "CAMPAIGN_IMPORTED",

    -- Players
    "PLAYER_ADDED",
    "PLAYER_MODIFIED",
    "PLAYER_REMOVED",

    -- Units
    "UNIT_ADDED",
    "UNIT_MODIFIED",
    "UNIT_DELETED",
    "UNIT_PERMANENTLY_DESTROYED",

    -- XP & Ranks
    "XP_GAINED",
    "XP_CAPPED",
    "RANK_UP",

    -- Battle Honours & Scars
    "BATTLE_HONOUR_GAINED",
    "HONOUR_REPLACED",
    "BATTLE_SCAR_GAINED",
    "DEVASTATING_BLOW",
    "WEAPON_MODIFICATION",
    "CRUSADE_RELIC_GAINED",

    -- Battles
    "BATTLE_RECORDED",
    "OUT_OF_ACTION_PASS",
    "OUT_OF_ACTION_FAIL",
    "AGENDA_COMPLETED",

    -- Requisitions
    "REQUISITION_PURCHASED",
    "ENHANCEMENT_INSTEAD_OF_HONOUR",
    "LEGENDARY_VETERANS",

    -- Territory
    "TERRITORY_CLAIMED",
    "TERRITORY_BONUS_ADDED",
    "TERRITORY_BONUS_REMOVED",
    "TERRITORY_BONUS_CLAIMED",
    "HEX_TOGGLED",

    -- Alliances
    "ALLIANCE_CREATED",
    "ALLIANCE_MODIFIED",

    -- Resources
    "RESOURCE_TYPE_ADDED",
    "RESOURCE_GAINED",
    "RESOURCE_SPENT",
    "SHARED_RESOURCE_GAINED",
    "SHARED_RESOURCE_SPENT",

    -- Attachments
    "UNIT_ATTACHED",
    "UNIT_DETACHED",
    "ATTACHED_UNIT_DESTROYED",

    -- System
    "WARNING",
    "ERROR",
    "MANUAL_NOTE",
    "CP_CHANGE",
    "RP_CAP_REACHED",
    "XP_CAP_REACHED"
}

-- ============================================================================
-- CRUSADE SUPPLEMENTS
-- ============================================================================

CRUSADE_SUPPLEMENTS = {
    { id = "none", name = "Core Rules Only" },
    { id = "tyrannic_war", name = "Tyrannic War" },
    { id = "pariah_nexus", name = "Pariah Nexus" },
    { id = "nachmund", name = "Nachmund Gauntlet" },
    { id = "armageddon", name = "Armageddon" }
}

-- Supplement-specific data: alliance types, campaign phases, features
SUPPLEMENT_DATA = {
    tyrannic_war = {
        campaignPhases = 3,
        allianceTypes = {
            { name = "Defenders", description = "Fight to protect Imperial worlds from the Tyranid menace." },
            { name = "Invaders", description = "Tyranid swarms and Chaos forces exploiting the conflict." },
            { name = "Raiders", description = "Opportunistic xenos and renegades raiding amidst the war." }
        },
        hasStrategicFootings = false,
        hasUpgradeTrees = true
    },
    pariah_nexus = {
        campaignPhases = 3,
        allianceTypes = {
            { name = "Seekers", description = "Harvest blackstone to end the Stilling. Imperial forces best suited." },
            { name = "Protectors", description = "Guard the blackstone from outsiders. Necrons and those with their own noctilith goals." },
            { name = "Interlopers", description = "Chaos raiders, Aeldari, Orks, and others drawn to the Pariah Nexus." }
        },
        hasStrategicFootings = true,
        hasUpgradeTrees = false
    },
    nachmund = {
        campaignPhases = 3,
        allianceTypes = {
            { name = "Guardians", description = "Protect the planet Sangua Terra from the forces of Chaos." },
            { name = "Despoilers", description = "Conquer the Nachmund Gauntlet for Abaddon the Despoiler." },
            { name = "Marauders", description = "Opportunistic raiders and xenos seeking plunder amidst the war." }
        },
        hasStrategicFootings = false,
        hasStrategicSites = true,
        hasTacticalReserves = true
    },
    armageddon = {
        campaignPhases = 0, -- Tree-based campaign, not phased
        allianceTypes = {},
        hasStrategicFootings = false,
        hasTreeCampaign = true,
        hasAnomalies = true
    }
}

-- Strategic Footings (Pariah Nexus)
STRATEGIC_FOOTINGS = {
    "Aggressive",
    "Balanced",
    "Defensive"
}

-- Backward-compat alias
PARIAH_NEXUS_ALLIANCES = { "Seekers", "Protectors", "Interlopers" }

-- ============================================================================
-- BATTLE SIZES
-- ============================================================================

BATTLE_SIZES = {
    "Incursion",
    "Strike Force",
    "Onslaught"
}

-- ============================================================================
-- BATTLEFIELD ROLES
-- ============================================================================

BATTLEFIELD_ROLES = {
    "HQ",
    "Troops",
    "Elites",
    "Fast Attack",
    "Heavy Support",
    "Flyer",
    "Dedicated Transport",
    "Fortification",
    "Lord of War"
}

return {
    -- Export all constants for use in other modules
    CAMPAIGN_VERSION = CAMPAIGN_VERSION,
    EDITION = EDITION,
    MAX_PLAYERS = MAX_PLAYERS,
    MAX_UNITS_PER_PLAYER = MAX_UNITS_PER_PLAYER,
    MAX_HEXES = MAX_HEXES,
    MAX_UNITS_ON_MAP = MAX_UNITS_ON_MAP,
    MAX_RP = MAX_RP,
    MAX_BATTLE_HONOURS_NON_CHAR = MAX_BATTLE_HONOURS_NON_CHAR,
    MAX_BATTLE_HONOURS_CHAR = MAX_BATTLE_HONOURS_CHAR,
    MAX_BATTLE_SCARS = MAX_BATTLE_SCARS,
    NON_CHAR_XP_CAP = NON_CHAR_XP_CAP,
    AUTOSAVE_INTERVAL = AUTOSAVE_INTERVAL,
    MAX_BACKUP_VERSIONS = MAX_BACKUP_VERSIONS,
    UI_UPDATE_THROTTLE = UI_UPDATE_THROTTLE,
    MAX_EVENT_LOG_SIZE = MAX_EVENT_LOG_SIZE,
    HEX_SIZE = HEX_SIZE,
    DEFAULT_MAP_WIDTH = DEFAULT_MAP_WIDTH,
    DEFAULT_MAP_HEIGHT = DEFAULT_MAP_HEIGHT,
    MAP_CENTER = MAP_CENTER,
    HEX_GRID_BASE_HEIGHT = HEX_GRID_BASE_HEIGHT,
    MAP_SKIN_HEIGHT = MAP_SKIN_HEIGHT,
    TERRITORY_OVERLAY_HEIGHT = TERRITORY_OVERLAY_HEIGHT,
    DEFAULT_MAP_SKIN = DEFAULT_MAP_SKIN,
    OVERLAY_ALPHA_DEFAULT = OVERLAY_ALPHA_DEFAULT,
    DEFAULT_SUPPLY_LIMIT = DEFAULT_SUPPLY_LIMIT,
    SUPPLY_LIMIT_INCREASE = SUPPLY_LIMIT_INCREASE,
    STARTING_RP = STARTING_RP,
    PLAYER_COLORS = PLAYER_COLORS,
    PLAYER_COLOR_NAMES = PLAYER_COLOR_NAMES,
    RANK_THRESHOLDS = RANK_THRESHOLDS,
    REQUISITION_COSTS = REQUISITION_COSTS,
    WEAPON_MODIFICATIONS = WEAPON_MODIFICATIONS,
    BATTLE_SCARS = BATTLE_SCARS,
    RELIC_TIERS = RELIC_TIERS,
    EVENT_TYPES = EVENT_TYPES,
    BATTLE_SIZES = BATTLE_SIZES,
    BATTLEFIELD_ROLES = BATTLEFIELD_ROLES,
    CRUSADE_SUPPLEMENTS = CRUSADE_SUPPLEMENTS,
    SUPPLEMENT_DATA = SUPPLEMENT_DATA,
    PARIAH_NEXUS_ALLIANCES = PARIAH_NEXUS_ALLIANCES,
    STRATEGIC_FOOTINGS = STRATEGIC_FOOTINGS
}
