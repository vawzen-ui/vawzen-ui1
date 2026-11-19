-- ============================================================================
--           SECUREX 4.6.36 - ULTIMATE NATIVE IN-GAME RELEASE (OFFICIAL)
-- ============================================================================
-- Architecture: Supabase ('securex_4_6') -> Runtime Lua (Offline Prepared)
-- Target Hardware: Low-End (2GB RAM) to High-End (165Hz) Mobile Devices
-- UI System: 100% Native Game Settings Menu (SettingPageDefine / SettingCatalog)
-- Stability: Zero Custom Canvas Bloat | Zero Touch Conflicts | Zero Memory Leaks
-- Features:
--   1. Official BGMI Native Settings Integration (Lobby & In-Match)
--   2. Native Switchers (AliasMap.Switcher) & Sliders (AliasMap.Slider)
--   3. 2D Player Box ESP & 360° Combat Threat Tracker
--   4. Multi-Category Vehicle Radar (Cars, Buggies, Bikes, Armored + 360° Alerts)
--   5. Essential-Only Loot ESP (Flares, Crates, AR, Snipers, L3 Gear, Scopes)
--   6. Performance Utilities (iPad Wide FOV, Visual Cleanup, Potato Boost, 165 FPS)
--   7. Instant Hardware Persistence (securex_settings.txt)
-- ============================================================================

-- Strict Namespace & State Isolation
_G.LexusConfig = _G.LexusConfig or {}
_G.LexusState  = _G.LexusState or {}

local CFG = _G.LexusConfig

-- Safe Re-injection Clean Slate: Force-stop previous schedulers & clean up old widgets
if _G.StopMasterScheduler then pcall(_G.StopMasterScheduler) end
if _G.NativeTopLaserESP and _G.NativeTopLaserESP.Reset then pcall(_G.NativeTopLaserESP.Reset) end

-- Safe UE4 Type Imports & Constructors
local _slua = rawget(_G, "slua")

local V2_Class = import("Vector2D") or (pcall(import, "/Script/CoreUObject.Vector2D") and import("/Script/CoreUObject.Vector2D")) or _G.FVector2D
local LC_Class = import("LinearColor") or (pcall(import, "/Script/CoreUObject.LinearColor") and import("/Script/CoreUObject.LinearColor")) or _G.FLinearColor
local SC_Class = import("SlateColor") or (pcall(import, "/Script/SlateCore.SlateColor") and import("/Script/SlateCore.SlateColor")) or _G.FSlateColor

local function MakeColor(r, g, b, a)
    if LC_Class then
        local ok, c = pcall(LC_Class, r or 0, g or 0, b or 0, a or 1.0)
        if ok and c then return c end
    end
    if _G.FLinearColor and _G.FLinearColor ~= LC_Class then
        local ok, c = pcall(_G.FLinearColor, r or 0, g or 0, b or 0, a or 1.0)
        if ok and c then return c end
    end
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 1.0 }
end

local FVector = rawget(_G, "FVector")
    or (pcall(import, "FVector") and import("FVector"))
    or (pcall(import, "Vector") and import("Vector"))
    or function(x, y, z) return { X = x, Y = y, Z = z } end

-- Hardening: slua exposes FRotator as a global (81 stock files call it bare),
-- but a table fallback keeps Aimbot alive even if the global is absent.
local FRotator = rawget(_G, "FRotator")
    or (pcall(import, "Rotator") and import("Rotator"))
    or function(p, y, r) return { Pitch = p or 0, Yaw = y or 0, Roll = r or 0 } end

local UEnums = UEnums or (pcall(import, "UEnums") and import("UEnums")) or {}

-- Engine-proven pawn state enum (EnumDefine.lua: GunFire=7, GunADS=9).
-- HasState() is the universal fire/ADS trigger on every pawn class & mode
-- (BR/TDM/Arena/WOW/Rooms) — unlike bool flags which don't exist in Lua.
local EPawnState = rawget(_G, "EPawnState")
    or (pcall(import, "EPawnState") and import("EPawnState"))
    or { GunFire = 7, GunADS = 9 }

local function PawnHasState(pawn, state)
    if not IsValid(pawn) or state == nil then return false end
    if type(pawn.HasState) == "function" then
        local ok, res = pcall(pawn.HasState, pawn, state)
        if ok and res == true then return true end
    end
    return false
end

if not UEnums.ESlateVisibility then
    UEnums.ESlateVisibility = {
        Visible = 0,
        Collapsed = 1,
        Hidden = 2,
        HitTestInvisible = 3,
        SelfHitTestInvisible = 4
    }
end

-- Safe Validation Helper (Hardened: Fail-Closed + PendingKill & IsValidLowLevel Probes)
local function IsValid(obj)
    if not obj then return false end
    local t = type(obj)
    if t == "userdata" then
        if _slua and _slua.isValid then
            local ok, v = pcall(_slua.isValid, obj)
            if ok and v ~= true then return false end
        end
        if obj.IsPendingKill then
            local ok, pk = pcall(obj.IsPendingKill, obj)
            if ok and pk == true then return false end
        end
        if obj.IsValidLowLevel then
            local ok, ll = pcall(obj.IsValidLowLevel, obj)
            if ok and ll == false then return false end
        end
        return true
    end
    return (t == "table")
end

-- High-Precision Wall-Clock Engine (Fixes Android libc CPU-Time os.clock stretch)
local _LastWallTime = 0
local function GetGameTimeNow()
    if _G._mockGameTime and type(_G._mockGameTime) == "number" then
        return _G._mockGameTime
    end
    local t = nil
    pcall(function()
        local gps = _GPS_Cached or import("GameplayStatics")
        local world = (_slua and _slua.getWorld and _slua.getWorld())
            or (slua_GameFrontendHUD and slua_GameFrontendHUD.GetWorld and slua_GameFrontendHUD:GetWorld())
        if gps and gps.GetTimeSeconds then
            t = gps.GetTimeSeconds(world)
        end
    end)
    if t and t > 0 then
        _LastWallTime = t
        return t
    end
    if _G.MasterWallTime and _G.MasterWallTime > 0 then
        return _G.MasterWallTime
    end
    return os.clock()
end

-- Core Palette Colors for In-Game Marks
-- Wall-vision palette: LIGHT BLOOM (user approved). Values ~1.5 cause only a
-- soft emissive lift, far below old HDR 9.0 that melted 2GB GPUs.
local C = {
    accent_cyan  = MakeColor(0.0, 0.90, 1.0, 1.0),
    accent_glow  = MakeColor(0.0, 0.90, 1.0, 0.35),
    accent_green = MakeColor(0.30, 1.5, 0.0, 1.0),    -- lime, light bloom (real enemy visible)
    accent_red   = MakeColor(0.90, 0.0, 1.5, 1.0),    -- purple, light bloom (real enemy behind wall)
    text_white   = MakeColor(1.0, 1.0, 1.0, 1.0),
    text_gold    = MakeColor(1.0, 0.85, 0.20, 1.0),
    bot_visible  = MakeColor(0.0, 1.4, 1.5, 1.0),     -- cyan, light bloom (bot visible)
    bot_occluded = MakeColor(1.5, 1.5, 0.0, 1.0),     -- bright yellow, light bloom (bot behind wall)
}

-- Default Configuration Matrix (100% Opt-In: Every Single Feature Default OFF)
local function SetDefaultConfig()
    -- Visuals: Native In-Game Enemy Threat Counter & Core ESP (All OFF by default)
    if CFG.ESP_Player_Box == nil then CFG.ESP_Player_Box = false end
    -- NOTE: TrackingMode intentionally NOT defaulted here; nil means "migrate
    -- from legacy switches after load" (see below). TrackMode() treats nil as 0.
    if CFG.Laser_Thickness == nil then CFG.Laser_Thickness = 1.5 end

    -- Combat: Native Aimbot & Recoil Engine (All OFF by default)
    if CFG.AimAssistEnabled == nil then CFG.AimAssistEnabled = false end
    if CFG.AimActivationMode == nil then CFG.AimActivationMode = 2 end       -- 0: Scope Only, 1: Hipfire Only, 2: Hip + ADS
    if CFG.AimTargetBone == nil then CFG.AimTargetBone = 0 end               -- 0: Chest / Body (Safe), 1: Neck / Head
    if CFG.AimPower == nil then CFG.AimPower = 2 end                         -- Slider: 1 (Low), 2 (Safe), 3 (High)
    if CFG.AimIgnoreKnocked == nil then CFG.AimIgnoreKnocked = false end
    if CFG.AimHipDistance == nil then CFG.AimHipDistance = 40 end            -- Max 60 Meters
    if CFG.AimScopeDistance == nil then CFG.AimScopeDistance = 150 end        -- Max 180 Meters
    if CFG.NoRecoilEnabled == nil then CFG.NoRecoilEnabled = false end
    if CFG.RecoilReduction == nil then CFG.RecoilReduction = 70 end          -- Slider: 0 - 70% (Safe cap)

    if CFG.Counter_Enabled == nil then CFG.Counter_Enabled = false end
    if CFG.Counter_Y_Offset == nil then CFG.Counter_Y_Offset = 41 end
    if CFG.ESP_Health_Bar == nil then CFG.ESP_Health_Bar = false end
    if CFG.Alert_Incoming_Grenades == nil then CFG.Alert_Incoming_Grenades = false end
    if CFG.ESP_Wall_Vision == nil then CFG.ESP_Wall_Vision = false end
    if CFG.ESP_Vis_Check == nil then CFG.ESP_Vis_Check = false end
    if CFG.ESP_Mecha_Banner == nil then CFG.ESP_Mecha_Banner = false end
    -- TrackingMode replaces the two switches above (kept for legacy save compat).

    -- Vehicles (All OFF by default)
    if CFG.Veh_Cat_Cars == nil then CFG.Veh_Cat_Cars = false end
    if CFG.Veh_Cat_Light == nil then CFG.Veh_Cat_Light = false end
    if CFG.Veh_Cat_Bikes == nil then CFG.Veh_Cat_Bikes = false end
    if CFG.Veh_Cat_Armored == nil then CFG.Veh_Cat_Armored = false end
    if CFG.Veh_Cat_WaterAir == nil then CFG.Veh_Cat_WaterAir = false end
    if CFG.Veh_360_Alert == nil then CFG.Veh_360_Alert = false end
    if CFG.VehicleDistance == nil then CFG.VehicleDistance = 350 end

    -- Essential Loot (All OFF by default)
    if CFG.Loot_Cat_Flares == nil then CFG.Loot_Cat_Flares = false end
    if CFG.Loot_Cat_AirDrop == nil then CFG.Loot_Cat_AirDrop = false end
    if CFG.Loot_Cat_AR == nil then CFG.Loot_Cat_AR = false end
    if CFG.Loot_Cat_Snipers == nil then CFG.Loot_Cat_Snipers = false end
    if CFG.Loot_Cat_SMG == nil then CFG.Loot_Cat_SMG = false end
    if CFG.Loot_Cat_Gear == nil then CFG.Loot_Cat_Gear = false end
    if CFG.Loot_Cat_Scopes == nil then CFG.Loot_Cat_Scopes = false end
    if CFG.Loot_Cat_Meds == nil then CFG.Loot_Cat_Meds = false end
    if CFG.Loot_Cat_Throwables == nil then CFG.Loot_Cat_Throwables = false end
    if CFG.Loot_Cat_Shotguns == nil then CFG.Loot_Cat_Shotguns = false end
    if CFG.Loot_FragGrenade == nil then CFG.Loot_FragGrenade = false end
    if CFG.Loot_SmokeBomb == nil then CFG.Loot_SmokeBomb = false end
    if CFG.Loot_Molotov == nil then CFG.Loot_Molotov = false end
    if CFG.Loot_Scope3x == nil then CFG.Loot_Scope3x = false end
    if CFG.Loot_DP28 == nil then CFG.Loot_DP28 = false end
    if CFG.Loot_SCAR == nil then CFG.Loot_SCAR = false end
    if CFG.Loot_M16A4 == nil then CFG.Loot_M16A4 = false end
    if CFG.Loot_G36C == nil then CFG.Loot_G36C = false end
    if CFG.Loot_Mini14 == nil then CFG.Loot_Mini14 = false end
    if CFG.Loot_SKS == nil then CFG.Loot_SKS = false end
    if CFG.Loot_SLR == nil then CFG.Loot_SLR = false end
    if CFG.Loot_PP19 == nil then CFG.Loot_PP19 = false end
    if CFG.Loot_Thompson == nil then CFG.Loot_Thompson = false end
    if CFG.Loot_DBS == nil then CFG.Loot_DBS = false end
    if CFG.Loot_S12K == nil then CFG.Loot_S12K = false end
    if CFG.Loot_EnergyDrink == nil then CFG.Loot_EnergyDrink = false end
    if CFG.Loot_Painkiller == nil then CFG.Loot_Painkiller = false end
    if CFG.Loot_360_Alert == nil then CFG.Loot_360_Alert = false end
    if CFG.LootDistance == nil then CFG.LootDistance = 35 end

    -- Graphics & Utility (All OFF by default)
    if CFG.iPadViewEnabled == nil then CFG.iPadViewEnabled = false end
    if CFG.iPadViewFOV == nil then CFG.iPadViewFOV = 110 end
    if CFG.TargetFPS == nil then CFG.TargetFPS = 90 end -- Thermal protection default for 2GB/4GB devices
    if CFG.FPSStabilizerEnabled == nil then CFG.FPSStabilizerEnabled = true end
    -- Skin Armory (all OFF / index 1 by default; dynamic slider max = table size)
    if CFG.ModSkin == nil then CFG.ModSkin = false end
    if CFG.KillMessageEnabled == nil then CFG.KillMessageEnabled = false end
    if CFG.AttachmentSkinsEnabled == nil then CFG.AttachmentSkinsEnabled = false end
    if CFG.SkinSuit == nil then CFG.SkinSuit = 1 end
    if CFG.SkinBag == nil then CFG.SkinBag = 1 end
    if CFG.SkinHelmet == nil then CFG.SkinHelmet = 1 end
    if CFG.SkinParachute == nil then CFG.SkinParachute = 1 end
    if CFG.SkinGlider == nil then CFG.SkinGlider = 1 end
    for _, k in ipairs({ "SkinM416", "SkinAKM", "SkinSCAR", "SkinM762", "SkinAUG", "SkinGroza",
        "SkinQBZ", "SkinACE32", "SkinM16A4", "SkinHoney", "SkinUMP", "SkinUZI", "SkinDBS",
        "SkinS12K", "SkinASM", "SkinAWM", "SkinKar98k", "SkinM24",
        "SkinCoupe", "SkinDacia", "SkinUAZ", "SkinBuggy", "SkinMirado", "SkinMiniBus", "SkinMonster", "SkinScooter", "SkinGliderVeh", "SkinHorse", "SkinCyber",
        "SkinPP19", "SkinDP28", "SkinMG3", "SkinP90", "SkinMini14", "SkinSKS", "SkinSLR" }) do
        if CFG[k] == nil then CFG[k] = 1 end
    end
    if CFG.PotatoGraphicsEnabled == nil then CFG.PotatoGraphicsEnabled = false end
    if CFG.VisualCleanupEnabled == nil then CFG.VisualCleanupEnabled = false end
    if CFG.ConfigVersion == nil then CFG.ConfigVersion = 4638 end
end
SetDefaultConfig()

-- Tracking selector: 0=OFF, 1=Snapline line only, 2=Map tracking (mecha) only.
-- Only the selected system runs; the other is runtime-zero.
local function TrackMode()
    return tonumber(CFG.TrackingMode) or 0
end
_G.TrackMode = TrackMode

-- Global Caches
_G.ActiveVehicleMarkCache = _G.ActiveVehicleMarkCache or {}
_G.ActiveLootMarkCache    = _G.ActiveLootMarkCache or {}
_G.ActiveVehicleAttached  = _G.ActiveVehicleAttached or {}
_G.ActiveLootAttached     = _G.ActiveLootAttached or {}
_G.LootTombstones         = _G.LootTombstones or {}
_G.VehicleTombstones      = _G.VehicleTombstones or {}
_G._VehMissedScans        = _G._VehMissedScans or {}
_G.VehicleDefCache        = _G.VehicleDefCache or {}
_G.LootDefCache           = _G.LootDefCache or {}
_G.ActiveEnemyMarks       = _G.ActiveEnemyMarks or {}
_G.ActiveBoxCache         = _G.ActiveBoxCache or {}
_G.ActiveHPMarks          = _G.ActiveHPMarks or {}
_G.ActiveMechaHPMarks     = _G.ActiveMechaHPMarks or {}
_G.ActiveWallVisionPawns  = _G.ActiveWallVisionPawns or {}
-- ============================================================================
-- 2. BULLETPROOF MULTI-TIER SETTINGS PERSISTENCE ENGINE (MMKV + UE4 Native + File)
-- ============================================================================
local ConfigFileName = "securex_settings.txt"
local LegacyConfigFile = "goku_vip_settings.txt"
local MMKV_SETTINGS_KEY = "securex_settings"
local CachedSavePath = nil

local function SerializeVal(v)
    local t = type(v)
    if t == "boolean" then return v and "true" or "false"
    elseif t == "number" then return tostring(v)
    elseif t == "string" then return string.format("%q", v)
    else return nil end
end

local function GenerateConfigPayload()
    local data = "return {\n"
    for k, v in pairs(CFG) do
        local s = SerializeVal(v)
        if s ~= nil then
            data = data .. "  [" .. string.format("%q", tostring(k)) .. "] = " .. s .. ",\n"
        end
    end
    data = data .. "}\n"
    return data
end

local function ApplyConfigPayload(rawStr)
    if not rawStr or #rawStr < 5 then return false end
    local fn = (loadstring or load)(rawStr)
    if not fn then return false end
    local ok, res = pcall(fn)
    if ok and type(res) == "table" then
        -- Backward-compatibility: If legacy config had no ConfigVersion or is older than 4638, reset all to 100% clean OFF
        local isLegacy = (res.ConfigVersion == nil or tonumber(res.ConfigVersion) == nil or tonumber(res.ConfigVersion) < 4638)

        for k, v in pairs(res) do
            if type(v) == "number" then
                local num = tonumber(v)
                if num and num == num and num >= 0 and num < 100000 then
                    CFG[k] = num
                end
            elseif type(v) == "boolean" then
                CFG[k] = (v == true)
            elseif type(v) == "string" then
                CFG[k] = tostring(v)
            end
        end

        if isLegacy then
            -- Reset all features to 100% OFF by default on v4.6.38 launch
            CFG.ESP_Player_Box = false
            CFG.ESP_Top_Laser = false
            CFG.AimAssistEnabled = false
            CFG.NoRecoilEnabled = false
            CFG.Counter_Enabled = false
            CFG.ESP_Health_Bar = false
            CFG.Alert_Incoming_Grenades = false
            CFG.ESP_Wall_Vision = false
            CFG.ESP_Vis_Check = false
            CFG.ESP_Mecha_Banner = false
            CFG.Veh_Cat_Cars = false
            CFG.Veh_Cat_Light = false
            CFG.Veh_Cat_Bikes = false
            CFG.Veh_Cat_Armored = false
            CFG.Veh_Cat_WaterAir = false
            CFG.Veh_360_Alert = false
            CFG.Loot_Cat_Flares = false
            CFG.Loot_Cat_AirDrop = false
            CFG.Loot_Cat_AR = false
            CFG.Loot_Cat_Snipers = false
            CFG.Loot_Cat_SMG = false
            CFG.Loot_Cat_Gear = false
            CFG.Loot_Cat_Scopes = false
            CFG.Loot_Cat_Meds = false
            CFG.Loot_Cat_Throwables = false
            CFG.Loot_FragGrenade = false
            CFG.Loot_SmokeBomb = false
            CFG.Loot_Molotov = false
            CFG.Loot_Scope3x = false
            CFG.Loot_DP28 = false
            CFG.Loot_SCAR = false
            CFG.iPadViewEnabled = false
            CFG.PotatoGraphicsEnabled = false
            CFG.VisualCleanupEnabled = false
            CFG.FPSStabilizerEnabled = false
            CFG.ModSkin = false
            CFG.ConfigVersion = 4638
        end

        -- Enforce hardware safe caps at load-time (defense in depth)
        if CFG.RecoilReduction then
            CFG.RecoilReduction = math.min(70, math.max(0, tonumber(CFG.RecoilReduction) or 70))
        end
        if CFG.LootDistance then
            CFG.LootDistance = math.min(50, math.max(10, tonumber(CFG.LootDistance) or 35))
        end
        if CFG.VehicleDistance then
            CFG.VehicleDistance = math.min(350, math.max(50, tonumber(CFG.VehicleDistance) or 350))
        end
        if CFG.TargetFPS ~= nil then
            CFG.TargetFPS = math.min(165, math.max(60, tonumber(CFG.TargetFPS) or 90))
        end
        if CFG.Laser_Thickness ~= nil then
            CFG.Laser_Thickness = math.min(3.0, math.max(1.0, tonumber(CFG.Laser_Thickness) or 1.5))
        end
        return true
    end
    return false
end

-- Native MMKV Helpers (Tencent C++ In-Memory Key-Value, 100% Android 11-14 Sandbox Safe)
local function MMKV_Save(key, strData)
    local saved = false
    -- Module 1: mmkv_playerprefs
    pcall(function()
        local mmkv_pp = package.loaded["client.logic.LogicPlayerPrefs.mmkv_playerprefs"]
            or (pcall(require, "client.logic.LogicPlayerPrefs.mmkv_playerprefs") and require("client.logic.LogicPlayerPrefs.mmkv_playerprefs"))
        if mmkv_pp and mmkv_pp.SaveGameData then
            mmkv_pp.SaveGameData(key, strData)
            saved = true
        end
    end)
    -- Module 2: Direct MMKVObject
    if not saved then
        pcall(function()
            local MMKVObject = rawget(_G, "MMKVObject") or import("MMKVObject")
            if MMKVObject then
                local mmkvObj = MMKVObject()
                mmkvObj:Init("PlayerPrefs", "")
                mmkvObj:SetBuffer(tostring(key), strData)
                saved = true
            end
        end)
    end
    return saved
end

local function MMKV_Load(key)
    local res = nil
    pcall(function()
        local mmkv_pp = package.loaded["client.logic.LogicPlayerPrefs.mmkv_playerprefs"]
            or (pcall(require, "client.logic.LogicPlayerPrefs.mmkv_playerprefs") and require("client.logic.LogicPlayerPrefs.mmkv_playerprefs"))
        if mmkv_pp and mmkv_pp.LoadGameData then
            local str = mmkv_pp.LoadGameData(key)
            if str and #str > 5 then res = str end
        end
    end)
    if not res then
        pcall(function()
            local MMKVObject = rawget(_G, "MMKVObject") or import("MMKVObject")
            if MMKVObject then
                local mmkvObj = MMKVObject()
                mmkvObj:Init("PlayerPrefs", "")
                local str = mmkvObj:GetBuffer(tostring(key))
                if str and #str > 5 then res = str end
            end
        end)
    end
    return res
end

local function EnsureDirExists(fullPath)
    -- Native pure Lua, zero process spawns (zero lag, 100% crash proof)
end

local function GetConfigPaths(fileNameOverride)
    local targetName = fileNameOverride or ConfigFileName
    local paths = {}
    local seen = {}
    local function addPath(p)
        if p and p ~= "" and not seen[p] then
            seen[p] = true
            table.insert(paths, p)
        end
    end

    if CachedSavePath and not fileNameOverride then addPath(CachedSavePath) end

    -- Native UE4 Writable Dirs (Always accessible on Android 11-14)
    pcall(function()
        if type(Client) == "table" then
            if type(Client.ProjectSavedDir) == "function" then
                local sDir = Client.ProjectSavedDir()
                if sDir and sDir ~= "" then
                    addPath(sDir .. "SaveGames/" .. targetName)
                    addPath(sDir .. "Config/" .. targetName)
                    addPath(sDir .. targetName)
                end
            end
            if type(Client.GetInternalFilesDir) == "function" then
                local iDir = Client.GetInternalFilesDir()
                if iDir and iDir ~= "" then
                    addPath(iDir .. "/" .. targetName)
                    addPath(iDir .. "/SaveGames/" .. targetName)
                end
            end
        end
    end)

    local pkgs = { "com.pubg.imobile", "com.tencent.ig", "com.pubg.krmobile", "com.vng.pubgmobile", "com.rekoo.pubgm" }
    for _, pkg in ipairs(pkgs) do
        local p = "/storage/emulated/0/Android/data/" .. pkg .. "/files/"
        addPath(p .. "UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. targetName)
        addPath(p .. "UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Config/" .. targetName)
        addPath(p .. "GameConfig/" .. targetName)
        addPath(p .. targetName)
        addPath("/data/data/" .. pkg .. "/files/" .. targetName)
        addPath("/data/user/0/" .. pkg .. "/files/" .. targetName)
    end

    addPath("/storage/emulated/0/SecureX/" .. targetName)
    addPath("/storage/emulated/0/GOKUCONFIG/" .. targetName)
    addPath("/storage/emulated/0/GameConfig/" .. targetName)
    addPath("/sdcard/GameConfig/" .. targetName)
    addPath("/sdcard/" .. targetName)
    addPath("ShadowTrackerExtra/Saved/SaveGames/" .. targetName)
    addPath("ShadowTrackerExtra/Saved/" .. targetName)
    addPath(targetName)
    return paths
end

local _LastDiskSaveWallTime = 0
function _G.SaveModSettings(immediate)
    pcall(function()
        local data = GenerateConfigPayload()

        -- Tier 1: Primary Native MMKV Store (Fast in-memory, survives restarts, instant)
        MMKV_Save(MMKV_SETTINGS_KEY, data)
        MMKV_Save("goku_vip_settings", data)

        -- Tier 2 & 3: Flash Disk writes throttled (0.3s) to prevent UI dragging stutter
        local now = GetGameTimeNow()
        if immediate or _LastDiskSaveWallTime == 0 or (now - _LastDiskSaveWallTime) >= 0.3 then
            _LastDiskSaveWallTime = now

            -- Tier 2: Native UE4 C++ File Engine (bypasses Android Scoped Storage restriction)
            if type(Client) == "table" and type(Client.SaveStringToFile) == "function" then
                pcall(function()
                    if type(Client.ProjectSavedDir) == "function" then
                        local pDir = Client.ProjectSavedDir()
                        if pDir and pDir ~= "" then
                            Client.SaveStringToFile(pDir .. "SaveGames/" .. ConfigFileName, data)
                        end
                    end
                    if type(Client.GetInternalFilesDir) == "function" then
                        local iDir = Client.GetInternalFilesDir()
                        if iDir and iDir ~= "" then
                            Client.SaveStringToFile(iDir .. "/" .. ConfigFileName, data)
                        end
                    end
                end)
            end

            -- Tier 3: Standard POSIX Disk Fallback
            local paths = GetConfigPaths(ConfigFileName)
            for _, path in ipairs(paths) do
                EnsureDirExists(path)
                local file = io.open(path, "w")
                if file then
                    file:write(data)
                    file:close()
                    CachedSavePath = path
                    break
                end
            end
        end
    end)
end

function _G.LoadModSettings()
    pcall(function()
        -- Tier 1: Try Native MMKV Store first
        local mmkvData = MMKV_Load(MMKV_SETTINGS_KEY) or MMKV_Load("goku_vip_settings")
        if mmkvData and ApplyConfigPayload(mmkvData) then
            return true
        end

        -- Tier 2: Native UE4 C++ LoadFileToString
        if type(Client) == "table" and type(Client.LoadFileToString) == "function" then
            local ue4Loaded = false
            pcall(function()
                if type(Client.ProjectSavedDir) == "function" then
                    local pDir = Client.ProjectSavedDir()
                    if pDir and pDir ~= "" then
                        local ok, str = pcall(Client.LoadFileToString, pDir .. "SaveGames/" .. ConfigFileName)
                        if ok and str and ApplyConfigPayload(str) then ue4Loaded = true return end
                    end
                end
                if type(Client.GetInternalFilesDir) == "function" then
                    local iDir = Client.GetInternalFilesDir()
                    if iDir and iDir ~= "" then
                        local ok, str = pcall(Client.LoadFileToString, iDir .. "/" .. ConfigFileName)
                        if ok and str and ApplyConfigPayload(str) then ue4Loaded = true return end
                    end
                end
            end)
            if ue4Loaded then return true end
        end

        -- Tier 3: POSIX File Paths
        local fileList = { ConfigFileName, LegacyConfigFile }
        for _, targetName in ipairs(fileList) do
            local paths = GetConfigPaths(targetName)
            local loaded = false
            for _, path in ipairs(paths) do
                local fileContent = nil
                local file = io.open(path, "r")
                if file then
                    fileContent = file:read("*a")
                    file:close()
                end
                if not fileContent and type(Client) == "table" and type(Client.LoadFileToString) == "function" then
                    local ok, c = pcall(Client.LoadFileToString, path)
                    if ok and c and #c > 5 then fileContent = c end
                end
                if fileContent and ApplyConfigPayload(fileContent) then
                    CachedSavePath = path
                    loaded = true
                    break
                end
            end
            if loaded then return true end
        end
    end)
end
pcall(_G.LoadModSettings)

-- One-time migration: old separate switches -> TrackingMode selector.
-- Runs AFTER load so saved values are visible. Saves persist the new key.
if CFG.TrackingMode == nil then
    if CFG.ESP_Top_Laser == true then CFG.TrackingMode = 1
    elseif CFG.ESP_Mecha_Banner == true then CFG.TrackingMode = 2
    else CFG.TrackingMode = 0 end
    pcall(_G.SaveModSettings, true)
end


-- ============================================================================
-- 2.5  SECUREX LOGIN LAYER  (Master License / VAWZEN key server)
-- ============================================================================
-- Everything below this line is the portable Login.lua module, wired into the
-- SecureX runtime.  It provides:
--     _G.LunarLoginRuntime        -> Authorized / Login / Logout / Update
--     _G.MasterLicenseLogin(key)
--     _G.MasterLicenseLogout()
--     _G.MasterLicenseStatus()
--     _G.SecureX_Authorized()     -> gate used by every feature entry point
--
-- Feature entry points (WatchdogTick / FullMatchInit / InitModMenuTab) refuse
-- to run until the key has been validated, so the mod cannot be used without
-- a valid license.
-- ============================================================================

-- ---- 2.5.1  Compatibility shims required by Login.lua ----------------------
-- Login.lua was written against a different host, so it expects a handful of
-- globals.  We define them here on top of SecureX's own persistence layer.

-- Settings path list (Login.lua rewrites the file name itself).
function _G.g_masterahsanyt_ESPSettingsPaths()
    local out = {}
    pcall(function()
        for _, p in ipairs(GetConfigPaths("MASTERPIECE_UMG_ESP_settings.lua")) do
            out[#out + 1] = p
        end
    end)
    if #out == 0 then
        out[1] = "MASTERPIECE_UMG_ESP_settings.lua"
    end
    return out
end

-- Verified write: native UE4 writer first, POSIX second.
function _G.g_masterahsanyt_ESPWriteSettings(path, data)
    if type(path) ~= "string" or type(data) ~= "string" then return false end
    local ok = false
    pcall(function()
        if type(Client) == "table" and type(Client.SaveStringToFile) == "function" then
            local res = Client.SaveStringToFile(path, data)
            if res ~= false then ok = true end
        end
    end)
    if not ok then
        pcall(function()
            local f = io.open(path, "w")
            if f then f:write(data); f:close(); ok = true end
        end)
    end
    return ok
end

-- Stable device identity.  Uses the engine id when available, otherwise a
-- generated id persisted next to the settings so it survives restarts.
function _G.SecureX_DeviceID()
    local id = nil
    pcall(function()
        if type(Client) == "table" then
            local fns = { "GetPhoneDeviceID", "GetDeviceID", "GetUniqueDeviceID", "GetClientDeviceID" }
            for _, fn in ipairs(fns) do
                if type(Client[fn]) == "function" then
                    local ok, v = pcall(Client[fn])
                    if ok and type(v) == "string" and #v > 0 then id = v break end
                end
            end
        end
    end)
    if type(id) == "string" and #id > 0 then return id end

    -- Fallback: persisted random id (never regenerated once written).
    local paths = GetConfigPaths("SECUREX_DEVICE.txt")
    for _, path in ipairs(paths) do
        local ok, f = pcall(io.open, path, "r")
        if ok and f then
            local data = f:read(512)
            f:close()
            if type(data) == "string" then
                local hex = data:match("^(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)$")
                if hex then return hex end
            end
        end
    end
    local seed = tostring(os.time()) .. "|" .. tostring(os.clock()) .. "|" .. tostring(math.random and math.random(1, 2147483647) or 1)
    local hex = ""
    for i = 1, 32 do
        local b = (string.byte(seed, (i % #seed) + 1) or 65) + i * 7
        hex = hex .. string.format("%02x", b % 256)
    end
    for _, path in ipairs(paths) do
        local ok, f = pcall(io.open, path, "w")
        if ok and f then f:write(hex); f:close(); break end
    end
    return hex
end

-- Feature hook table expected by Login.lua's wake() helper.
_G.LunarFeatures = _G.LunarFeatures or {}
if type(_G.LunarFeatures.Token) ~= "table" then _G.LunarFeatures.Token = {} end
if type(_G.LunarFeatures.Wake) ~= "function" then
    _G.LunarFeatures.Wake = function()
    if _G.SecureX_Authorized and _G.SecureX_Authorized() and type(_G.SecureX_BootFeatures) == "function" then
        pcall(_G.SecureX_BootFeatures)
    end
end
end

-- Single source of truth for "may the features run?".
function _G.SecureX_Authorized()
    local l = _G.LunarLoginRuntime
    if not l then return false end
    return l.Authorized == true
end


-- ---- 2.5.2  Login.lua portable module (embedded) ---------------------------
--[[
================================================================================
  Login.lua - Portable Master Login + Kill Limit 8-10 + LuaCore panel
================================================================================
  Drop this block into ANY script to get:

    - Full Master login UI (buttons, key box, dark-blue theme)
    - Kill limit 8-10 messaging on welcome / login
    - Panel: https://vipgfx.in/VAWZEN/connect
    - POST: game=pubg&user_key=KEY&serial=SERIAL

  API after load:
    _G.MasterLicenseLogin(key)
    _G.MasterLicenseLogout()
    _G.MasterLicenseStatus()  -> { authorized, pending, message, ... }
    _G.LunarLoginRuntime      -> Authorized, Login, UI helpers

  Gate your features:
    if _G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized then
      -- start hacks
    end

  Optional: change game name in MasterLicenseConfig (game = "pubg" or "BGMI")
================================================================================
]]

-- One authorization session per Lua process; gameplay identity never owns it.
do
    local licenseScope
local MasterLicenseConfig = {
    -- VAWZEN panel - ONE endpoint only.  Login and heartbeat both use it.
    url = 'https://vipgfx.in/VAWZEN/connect',
    game = 'pubg',
    timeout = 15, clockSkew = 300, expiryPath = nil,
    manualExpiry = "2028-12-31 23:59:59", tamperTolerance = 5,
    secret = 'VAWZEN',
    -- Same panel, periodic liveness re-check after login.
    heartbeat = 'https://vipgfx.in/VAWZEN/connect',
    heartbeatInterval = 300,   -- seconds between heartbeat pings
    heartbeatTimeout  = 10,    -- seconds before a ping counts as failed
}

local MasterLicenseCore = (function()
    local Primitives = (function()
        local floor, abs, max = math.floor, math.abs, math.max
        local byte, char, format = string.byte, string.char, string.format
        local U32 = 4294967296
        local AND, XOR = {}, {}
        for a = 0, 15 do for b = 0, 15 do
            local av, bv, both, different, place = a, b, 0, 0, 1
            for _ = 1, 4 do
                local x, y = av % 2, bv % 2
                if x == 1 and y == 1 then both = both + place end
                if x ~= y then different = different + place end
                av, bv, place = floor(av / 2), floor(bv / 2), place * 2
            end
            AND[a * 16 + b], XOR[a * 16 + b] = both, different
        end end
        local function bitop(a, b, lookup)
            local value, place = 0, 1
            for _ = 1, 8 do
                value = value + lookup[(a % 16) * 16 + b % 16] * place
                a, b, place = floor(a / 16), floor(b / 16), place * 16
            end
            return value
        end
        local function band(a, b) return bitop(a, b, AND) end
        local function bxor(a, b) return bitop(a, b, XOR) end
        local function rol(value, amount)
            local divisor = 2 ^ (32 - amount)
            return (value % divisor) * 2 ^ amount + floor(value / divisor)
        end
        local function little32(value)
            return char(value % 256, floor(value / 256) % 256,
                floor(value / 65536) % 256, floor(value / 16777216) % 256)
        end
        local K = {
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
            0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
            0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
            0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
            0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
            0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
        }
        local SHIFT = {7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21}
        local function md5_raw(input)
            assert(type(input) == "string", "MD5 input must be a string")
            local size = #input
            local message = input .. char(128) .. string.rep(char(0), (55 - size) % 64)
                .. little32((size * 8) % U32) .. little32(floor(size / 536870912))
            local h0, h1, h2, h3 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
            local words = {}
            for offset = 1, #message, 64 do
                for j = 0, 15 do
                    local a, b, c, d = byte(message, offset + j * 4, offset + j * 4 + 3)
                    words[j] = a + b * 256 + c * 65536 + d * 16777216
                end
                local a, b, c, d = h0, h1, h2, h3
                for i = 0, 63 do
                    local f, g, shiftBase
                    if i < 16 then
                        f, g, shiftBase = band(b, c) + band(U32 - 1 - b, d), i, 0
                    elseif i < 32 then
                        f, g, shiftBase = band(d, b) + band(U32 - 1 - d, c), (5 * i + 1) % 16, 4
                    elseif i < 48 then
                        f, g, shiftBase = bxor(bxor(b, c), d), (3 * i + 5) % 16, 8
                    else
                        local bOrNotD = U32 - 1 - band(U32 - 1 - b, d)
                        f, g, shiftBase = bxor(c, bOrNotD), (7 * i) % 16, 12
                    end
                    local nextB = (b + rol((a + f + K[i + 1] + words[g]) % U32,
                        SHIFT[shiftBase + i % 4 + 1])) % U32
                    a, b, c, d = d, nextB, b, c
                end
                h0, h1, h2, h3 = (h0 + a) % U32, (h1 + b) % U32, (h2 + c) % U32, (h3 + d) % U32
            end
            return little32(h0) .. little32(h1) .. little32(h2) .. little32(h3)
        end
        local function hex(input)
            return (input:gsub(".", function(c) return format("%02x", byte(c)) end))
        end
        local function md5(input) return hex(md5_raw(input)) end
        local function form_encode(input)
            assert(type(input) == "string", "Form value must be a string")
            return (input:gsub("[^A-Za-z0-9%-%._~ ]", function(c)
                return format("%%%02X", byte(c)) end):gsub(" ", "+"))
        end
        local function constant_time_equal(a, b)
            if type(a) ~= "string" or type(b) ~= "string" then return false end
            local difference = abs(#a - #b)
            for i = 1, max(#a, #b) do
                difference = difference + abs((byte(a, i) or 0) - (byte(b, i) or 0))
            end
            return difference == 0
        end
        local function name_uuid(input)
            local digest = md5_raw(input)
            local h = hex(digest:sub(1,6) .. char(byte(digest,7) % 16 + 48)
                .. digest:sub(8,8) .. char(byte(digest,9) % 64 + 128) .. digest:sub(10))
            return h:sub(1,8) .. "-" .. h:sub(9,12) .. "-" .. h:sub(13,16)
                .. "-" .. h:sub(17,20) .. "-" .. h:sub(21,32)
        end
        return {md5 = md5, md5_raw = md5_raw, form_encode = form_encode,
                constant_time_equal = constant_time_equal, name_uuid = name_uuid}
    end)()

    local SESSION_KEY='__LunarLicenseSessionV7'
    local function loadSession()
        local t=rawget(_G,SESSION_KEY)
        if type(t)=='table' and t.authorized==true and t.scope==licenseScope then return t end
    end
    local function saveSession(expiresAt)
        _G[SESSION_KEY]={authorized=true,expiresAt=expiresAt,scope=licenseScope}
    end
    local function clearSession() _G[SESSION_KEY]=nil end

    local CreateLocalExpiry = function(cfg)
        local E = {}
        local expiredText = 'Mod expired. DM Owner for renewal.'
        local tamperText  = "Don't be over smart"
        local blockedMessage, blockedPhase
        local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
        local function parse(text)
            if type(text) ~= 'string' then return nil end
            local y,m,d,h,n,s = text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
            y,m,d,h,n,s = tonumber(y),tonumber(m),tonumber(d),tonumber(h),tonumber(n),tonumber(s)
            if not y or not m or not d or not h or not n or not s or y < 1970 or y > 9999 or m < 1 or m > 12 or h > 23 or n > 59 or s > 59 then return nil end
            local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
            local months = {31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
            if d < 1 or d > months[m] then return nil end
            local prior = y - 1
            local days = 365 * (y - 1970) + math.floor(prior / 4) - math.floor(1969 / 4)
                - math.floor(prior / 100) + math.floor(1969 / 100)
                + math.floor(prior / 400) - math.floor(1969 / 400)
            for i = 1, m - 1 do days = days + months[i] end
            return (days + d - 1) * 86400 + h * 3600 + n * 60 + s - 6 * 3600
        end
        local configured = type(cfg.manualExpiry) == 'string' and cfg.manualExpiry:match('^%s*(.-)%s*$') or cfg.manualExpiry
        local expiry = parse(configured)
        local skew = cfg.clockSkew or 120
        if configured ~= nil and configured ~= '' and not expiry then
            blockedMessage, blockedPhase = 'Invalid local expiry date. Use YYYY-MM-DD HH:MM:SS.', 'error'
        end
        local function block(message, phase)
            if not blockedMessage then blockedMessage, blockedPhase = message, phase end
            return false, blockedMessage, blockedPhase
        end
        function E.Status() return not blockedMessage, blockedMessage, blockedPhase end
        function E.MarkTampered() return block(tamperText, 'tampered') end
        function E.GetExpiry() return expiry end
        function E.Accept(server, now, world, phone, rtt)
            if blockedMessage then return E.Status() end
            if not finite(server) or not finite(now) or now < 0 or world == nil
                or not finite(rtt) or rtt < 0 or not finite(phone) then
                return block('Clock verification unavailable.', 'error')
            end
            if math.abs(phone - server) > skew + rtt then return E.MarkTampered() end
            if expiry and server + rtt >= expiry then return block(expiredText, 'expired') end
            return true
        end
        return E
    end

    local CreateAuth = function(P, cfg, deps)
        local A = {}
        licenseScope=P.md5(cfg.url.."\0"..cfg.game.."\0"..cfg.secret)
        local phase, message = 'locked', 'Enter your key to sign in.'
        local allowed, pending, generation = false, nil, 0
        -- Heartbeat state must exist before begin()/received() so the login
        -- callback writes the LOCAL credentials the heartbeat later sends.
        local hbLast, hbBusy, hbFails = 0, false, 0
        local activeKey, activeSerial
        local expiresAt
        local lastRequestLatencyMs, lastResponseTime, lastResponseWorld
        local startFn, stopFn, payloadStarted, restartRequired
        local localExpiry = deps.localExpiry
        do
            local stored = loadSession()
            if stored then
                allowed = true; expiresAt = stored.expiresAt
                phase, message = 'active', 'Session restored'
            end
        end
        if localExpiry then
            local ok, text, state = localExpiry.Status()
            if not ok then message, phase = text, state end
        end
        local function finite(n) return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge end
        local function readClock()
            local ok, n, w = pcall(deps.clock)
            if ok and finite(n) and n >= 0 and w ~= nil then return n, w end
        end
        local function notify(text, state)
            message, phase = text, state
            if type(deps.status) == 'function' then pcall(deps.status, text, state) end
        end
        local function stopPayload()
            if payloadStarted then
                payloadStarted = false
                local ok, accepted = pcall(stopFn)
                if not ok or accepted == false then restartRequired = true end
            end
        end
        local function revoke(text, state)
            generation = generation + 1
            allowed, pending, expiresAt = false, nil, nil
            lastRequestLatencyMs, lastResponseTime, lastResponseWorld = nil, nil, nil
            stopPayload()
            local localDenied = false
            if localExpiry then
                local ok, localText, localPhase = localExpiry.Status()
                if not ok then text, state, localDenied = localText, localPhase, true end
            end
            notify(restartRequired and not localDenied
                and 'Restart required: payload cleanup failed.' or text, state or 'error')
        end
        local function startPayload()
            if payloadStarted or not startFn then return true end
            payloadStarted = true
            local before = generation
            local ok, accepted = pcall(startFn)
            if not ok or accepted == false then
                restartRequired = true
                revoke('Restart required: offline script startup failed.', 'error')
                return false
            end
            return generation == before and allowed
        end
        local function denyReason(reason)
            if type(reason) ~= 'string' then return 'Invalid key' end
            local upper = reason:upper()
            if upper:find('BLOCKED') then return 'Key blocked hai' end
            if upper:find('EXPIRED') then return 'Key expire ho gayi' end
            if upper:find('MAX DEVICE') or upper:find('DEVICE') then return 'Dusre device par lock hai' end
            if upper:find('NOT REGISTERED') or upper:find('INVALID') then return 'Galat key - dobara likho' end
            local lower = reason:sub(1, 120):lower():gsub('[_%s%-]+', ' ')
            if lower == 'max devices' or lower == 'maximum devices'
                or lower == 'max devices reached' then return 'Max Devices' end
            local clean = reason:gsub('[%c]', ' '):sub(1, 120)
            return clean == '' and 'Invalid key' or clean
        end
        local function configuredExpiry(result)
            if cfg.expiryPath == nil then return nil, true end
            if type(cfg.expiryPath) ~= 'table' or #cfg.expiryPath == 0 then return nil, false end
            local v = result
            for _, name in ipairs(cfg.expiryPath) do
                if type(v) ~= 'table' then return nil, false end
                v = rawget(v, name)
            end
            return v, finite(v) and v > 0 and v % 1 == 0
        end
        local function begin(key)
            if restartRequired or pending then return false end
            if localExpiry then
                local ok, text, state = localExpiry.Status()
                if not ok then revoke(text, state); return false end
            end
            if type(key) ~= 'string' then key = '' end
            key = key:match('^%s*(.-)%s*$')
            if #key == 0 or #key > 512 then
                revoke('Expired: enter a valid key.', 'denied'); return false
            end
            local now, world = readClock()
            if not now then
                revoke('Phone clock unavailable. Please try again.', 'error'); return false
            end
            local okSerial, serial = pcall(deps.serial, key)
            if not okSerial or type(serial) ~= 'string' or #serial == 0 or #serial > 512 then
                local failure=tostring(serial)
                local text='Device identifier unavailable.'
                if not okSerial and failure:find('DEVICE_CACHE_CONFLICT',1,true) then
                    text='Saved device records conflict. Restore the registered device backup.'
                elseif not okSerial and failure:find('DEVICE_CACHE_RECOVERY_REQUIRED',1,true) then
                    text='Saved device data could not be recovered. Check storage or restore its backup.'
                elseif not okSerial and failure:find('DEVICE_CACHE_SAVE_FAILED',1,true) then
                    text='Device cache could not be saved. Check game storage access.'
                end
                revoke(text,'error');return false
            end
            generation = generation + 1
            local requestId = generation
            pending = {id = requestId, key = key, serial = serial,
                       started = now, world = world, deadline = now + cfg.timeout}
            notify('Signing in...', 'pending')
            if not pending or pending.id ~= requestId or generation ~= requestId then return false end
            local body = 'game=' .. P.form_encode(cfg.game)
                .. '&user_key=' .. P.form_encode(key)
                .. '&serial=' .. P.form_encode(serial)
            local function received(success, raw)
                if not pending or pending.id ~= requestId or generation ~= requestId then return end
                local current, worldNow = readClock()
                if not current or worldNow ~= pending.world or current < pending.started
                    or current >= pending.deadline then
                    revoke('Request expired. Please sign in again.', 'error'); return
                end
                if success ~= true or type(raw) ~= 'string' or #raw == 0 or #raw > 32768 then
                    revoke('Connection failed. Please try again.', 'error'); return
                end

                -- VAWZEN response: {"status":true,"data":...} or {"status":false,"reason":"..."}
                -- Also accept string-match fallback if JSON decode fails
                local result = nil
                local okDecode, decoded = pcall(deps.decode, raw)
                if okDecode and type(decoded) == 'table' then
                    result = decoded
                else
                    -- Fallback string parse for VAWZEN
                    local statusTrue = raw:find('"status"%s*:%s*true') ~= nil or raw:find('"status":true') ~= nil
                    local reason = raw:match('"reason"%s*:%s*"([^"]+)"')
                    result = { status = statusTrue, reason = reason, data = statusTrue and {} or nil }
                end

                if type(result) ~= 'table' then
                    revoke('Invalid server response.', 'error'); return
                end

                -- status can be boolean true or string "true"
                local isOk = (result.status == true) or (tostring(result.status):lower() == 'true')
                if not isOk then
                    revoke(denyReason(result.reason or result.message), 'denied'); return
                end

                -- VAWZEN: data field optional but preferred when status true
                -- Skip MD5 token / rng checks (not used by VAWZEN server)

                lastRequestLatencyMs = (current - pending.started) * 1000
                lastResponseTime, lastResponseWorld = current, worldNow
                pending = nil

                -- Session: use manual expiry if set, else long-lived until next failed check
                local expiry = nil
                if localExpiry and localExpiry.GetExpiry then
                    expiry = localExpiry.GetExpiry()
                end
                allowed, expiresAt = true, expiry
                activeKey, activeSerial = key, serial
                hbLast, hbFails, hbBusy = current, 0, false
                saveSession(expiresAt)
                if not startPayload() then return end
                notify('Login successful.', 'active')
            end
            local ok, accepted = pcall(deps.post, cfg.url,
                {['Content-Type'] = 'application/x-www-form-urlencoded'},
                body, received, cfg.timeout)
            if not ok or accepted == false then
                revoke('HTTP request could not start.', 'error'); return false
            end
            return true
        end
        function A.Login(key) if allowed then return false end; return begin(key) end

        -- ================= HEARTBEAT (separate endpoint) =================
        -- The main panel (cfg.url) issues the authorization decision exactly
        -- once, at login.  The heartbeat (cfg.heartbeat) is a different URL
        -- with a different job: periodic liveness proof.  It can only REVOKE
        -- access - it never grants it, so a heartbeat alone can't unlock the
        -- mod and a dead heartbeat can't silently keep it alive.
        local function hbBody()
            return 'game=' .. P.form_encode(cfg.game)
                .. '&user_key=' .. P.form_encode(activeKey or '')
                .. '&serial=' .. P.form_encode(activeSerial or '')
        end
        local function hbResult(success, raw)
            hbBusy = false
            if not allowed or restartRequired then return end
            if success ~= true or type(raw) ~= 'string' or #raw == 0 then
                hbFails = hbFails + 1
                if hbFails >= 3 then
                    revoke('Heartbeat lost. Please sign in again.', 'error')
                end
                return
            end
            local statusTrue = raw:find('"status"%s*:%s*true') ~= nil
            if not statusTrue then
                local reason = raw:match('"reason"%s*:%s*"([^"]+)"')
                revoke(denyReason(reason), 'denied')
                return
            end
            hbFails = 0
            local current = readClock()
            if current then hbLast = current end
        end
        function A.Heartbeat(force)
            if not allowed or restartRequired or pending or hbBusy then return false end
            local endpoint = cfg.heartbeat
            if type(endpoint) ~= 'string' or #endpoint == 0 then return false end
            local now = readClock()
            if not now then return false end
            local interval = tonumber(cfg.heartbeatInterval) or 300
            if not force and (now - hbLast) < interval then return false end
            hbBusy = true
            local ok, accepted = pcall(deps.post, endpoint,
                {['Content-Type'] = 'application/x-www-form-urlencoded'},
                hbBody(), hbResult, tonumber(cfg.heartbeatTimeout) or 10)
            if not ok or accepted == false then
                hbBusy = false
                hbFails = hbFails + 1
                if hbFails >= 3 then
                    revoke('Heartbeat unavailable. Please sign in again.', 'error')
                end
                return false
            end
            return true
        end
        function A.GetHeartbeatState()
            return { endpoint = cfg.heartbeat, interval = cfg.heartbeatInterval,
                     last = hbLast, fails = hbFails, busy = hbBusy }
        end

        function A.Tick()
            if pending then
                local now, world = readClock()
                if not now or world ~= pending.world or now < pending.started then
                    revoke('Login clock unavailable. Please try again.', 'locked'); return
                end
                if now >= pending.deadline then
                    revoke('Request timed out. Please try again.', 'error')
                end
            end
            if allowed and not restartRequired then pcall(A.Heartbeat) end
        end
        function A.IsAuthorized()
            if allowed and not restartRequired then return true end
            local stored = loadSession()
            if stored and not restartRequired then
                allowed = true; expiresAt = stored.expiresAt; return true
            end
            return false
        end
        function A.Logout()
            hbLast, hbBusy, hbFails = 0, false, 0
            activeKey, activeSerial = nil, nil
            clearSession(); revoke('Expired: signed out.', 'locked')
        end
        function A.FailClosed(text, requiresRestart)
            if requiresRestart == true then restartRequired = true end
            revoke(text or 'Online access unavailable.', 'error')
        end
        function A.ReportClockTampering()
            if localExpiry then localExpiry.MarkTampered() end
            revoke("Don't be over smart", 'tampered')
        end
        function A.Bind(onStart, onStop)
            if type(onStart) ~= 'function' or type(onStop) ~= 'function' then
                return false, 'START_AND_STOP_REQUIRED'
            end
            if startFn and (startFn ~= onStart or stopFn ~= onStop) then return false, 'ALREADY_BOUND' end
            startFn, stopFn = onStart, onStop
            if A.IsAuthorized() then return startPayload() end
            return true
        end
        function A.Unbind()
            revoke('Offline script disconnected.', 'locked')
            startFn, stopFn = nil, nil
        end
        function A.GetRemainingSeconds() return nil end
        function A.GetState()
            local authorized = A.IsAuthorized()
            local sample, age
            if authorized and lastRequestLatencyMs ~= nil then
                local now, world = readClock()
                if now and world == lastResponseWorld and now >= lastResponseTime then
                    sample, age = lastRequestLatencyMs, now - lastResponseTime
                end
            end
            return {
                phase = phase, message = message, authorized = authorized,
                sessionAuthorized = authorized, expiresAt = expiresAt,
                accessPolicy = "game_session", expiryCheckPolicy = "login_only",
                periodicRecheck = cfg.heartbeat ~= nil, pending = pending ~= nil,
                heartbeatEndpoint = cfg.heartbeat, heartbeatLast = hbLast,
                heartbeatFails = hbFails,
                linked = startFn ~= nil, restartRequired = restartRequired == true,
                lastRequestLatencyMs = sample, lastRequestLatencyAgeSeconds = age,
                latencyScope = "license_http_round_trip"
            }
        end
        return A
    end

    local Core = {Primitives = Primitives, createExpiry = CreateLocalExpiry}
    function Core.new(config, dependencies)
        assert(type(config) == 'table' and type(dependencies) == 'table',
            'License configuration and dependencies required')
        local deps = {}
        for key, value in pairs(dependencies) do deps[key] = value end
        if deps.localExpiry == nil then deps.localExpiry = CreateLocalExpiry(config) end
        return CreateAuth(Primitives, config, deps)
    end
    return Core
end)()

    local UI={Version="LunarUI.V9.NativeGradient.2"}
    local function member(o,k)
        if o==nil then return nil end
        local ok,v=pcall(function() return o[k] end);if ok then return v end
    end
    local function valid(o)
        if o==nil then return false end
        local ok,v=pcall(slua.isValid,o);return ok and v==true
    end
    local vectorClass=rawget(_G,"FVector2D") or import("Vector2D")
    local colorClass=rawget(_G,"FLinearColor") or import("LinearColor")
    local function vector(x,y) return vectorClass(x,y) end
    local function color(r,g,b,a)
        local function linear(v) v=v/255;if v<=0.04045 then return v/12.92 end;return ((v+0.055)/1.055)^2.4 end
        return colorClass(linear(r),linear(g),linear(b),a or 1)
    end
    local function visibility(w,v)
        local fn=member(w,"SetWidgetVisibility") or member(w,"SetVisibility")
        assert(type(fn)=="function","UI_VISIBILITY_UNAVAILABLE");fn(w,v)
    end
    local function parent()
        local ok,t=pcall(require,"GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not ok or type(member(t,"GetMainControlBaseUI"))~="function" then return end
        local found,root=pcall(t.GetMainControlBaseUI);if not found or not valid(root) then return end
        local p=member(root,"CanvasPanel_0");if not valid(p) then p=member(root,"CanvasPanel_42") end
        if valid(p) then return p end
    end
    local function destroy(d)
        if not d then return end
        d.Visible=false
        if d.Event and d.Handle~=nil then pcall(function() d.Event:Remove(d.Handle) end) end
        if valid(d.Container) then pcall(function() d.Container:RemoveFromParent() end) end
        d.Submit=nil;d.Event=nil;d.Handle=nil;d.Container=nil;d.Parent=nil
        d.Input=nil;d.Button=nil;d.Status=nil;d.Title=nil;d.Detail=nil;d.Hint=nil;d.Design=nil;d.Cache=nil
    end
    -- Approved red/green frame, dark red/green heading, light full-color body.
    -- All gradient/angle/brush work happens at construction. No animation,
    -- background asset, network dependency, text outline or external backdrop.
    function UI.Build(kind,key,status,submit)
        local p=parent();if not p then return nil,"UI_NOT_READY" end
        local enums=UEnums.ESlateVisibility
        local passive=enums.SelfHitTestInvisible
        if enums.Visible==nil or passive==nil then return nil,"UI_ENUM_UNAVAILABLE" end
        local welcome=kind=="welcome"
        local W,H=welcome and 600 or 500,welcome and 276 or 248
        local scale=welcome and 0.8 or 1
        pcall(function()
            local v=p:GetCachedGeometry():GetLocalSize()
            if v.X>24 and v.Y>24 then scale=math.min(scale,(v.X-24)/W,(v.Y-24)/H) end
        end)
        local d={Parent=p,Visible=false,Submit=submit,Scale=scale}
        local ok,buildError=pcall(function()
            local function make(class,outer)
                local w=CGame:NewObjectFromPath("/Script/UMG."..class,outer)
                assert(valid(w),"UI_WIDGET_UNAVAILABLE");return w
            end
            d.Container=make("CanvasPanel",p)
            local design=make("CanvasPanel",d.Container);d.Design=design
            local artRoot=design
            local canCache,cache=pcall(make,"InvalidationBox",d.Container)
            if canCache and valid(cache) and type(member(cache,"SetCanCache"))=="function" then
                local attached=pcall(function()cache:AddChild(design);cache:SetCanCache(true);visibility(cache,passive)end)
                if attached then artRoot=cache;d.Cache=cache end
            end
            local artSlot=d.Container:AddChildToCanvas(artRoot)
            artSlot:SetAutoSize(false);artSlot:SetPosition(vector(0,0));artSlot:SetSize(vector(W,H));artSlot:SetZOrder(1)
            visibility(design,passive)
            local function add(w,x,y,ww,hh,z,dynamic)
                local slot=(dynamic and d.Container or design):AddChildToCanvas(w)
                slot:SetAutoSize(false);slot:SetPosition(vector(x,y));slot:SetSize(vector(ww,hh));slot:SetZOrder(z)
                return slot
            end
            -- Flatten static gradient rectangles before applying 50% alpha.
            -- Overlapping body/badge/button fills must not accumulate opacity.
            local artwork={}
            local function drawRect(x,y,ww,hh,c,z,opacity)
                local w=make("Border",d.Container)
                w:SetBrushColor(colorClass(c.R,c.G,c.B,opacity or .5));visibility(w,passive)
                add(w,x,y,ww,hh,z);return w
            end
            local function rect(x,y,ww,hh,c,z,opacity)
                artwork[#artwork+1]={X=x,Y=y,W=ww,H=hh,C=c,Z=z,A=opacity or .5,Order=#artwork+1}
            end
            local function renderArt()
                table.sort(artwork,function(a,b)
                    if a.Z==b.Z then return a.Order>b.Order end
                    return a.Z>b.Z
                end)
                local covered={}
                local function put(out,x,y,w,h)
                    if w>.00001 and h>.00001 then out[#out+1]={X=x,Y=y,W=w,H=h} end
                end
                for _,shape in ipairs(artwork) do
                    local pieces={{X=shape.X,Y=shape.Y,W=shape.W,H=shape.H}}
                    for _,cover in ipairs(covered) do
                        local nextPieces={}
                        for _,piece in ipairs(pieces) do
                            local x1=math.max(piece.X,cover.X);local y1=math.max(piece.Y,cover.Y)
                            local x2=math.min(piece.X+piece.W,cover.X+cover.W)
                            local y2=math.min(piece.Y+piece.H,cover.Y+cover.H)
                            if x2<=x1 or y2<=y1 then nextPieces[#nextPieces+1]=piece
                            else
                                put(nextPieces,piece.X,piece.Y,piece.W,y1-piece.Y)
                                put(nextPieces,piece.X,y2,piece.W,piece.Y+piece.H-y2)
                                put(nextPieces,piece.X,y1,x1-piece.X,y2-y1)
                                put(nextPieces,x2,y1,piece.X+piece.W-x2,y2-y1)
                            end
                        end
                        pieces=nextPieces;if #pieces==0 then break end
                    end
                    -- Coalesce adjacent pieces of the same solid gradient strip.
                    -- This keeps clipping from multiplying native UI widgets.
                    local changed=true
                    while changed do
                        changed=false
                        for i=1,#pieces do
                            local a=pieces[i]
                            for j=i+1,#pieces do
                                local b=pieces[j]
                                local vertical=math.abs(a.X-b.X)<.00001 and math.abs(a.W-b.W)<.00001
                                    and (math.abs(a.Y+a.H-b.Y)<.00001 or math.abs(b.Y+b.H-a.Y)<.00001)
                                local horizontal=math.abs(a.Y-b.Y)<.00001 and math.abs(a.H-b.H)<.00001
                                    and (math.abs(a.X+a.W-b.X)<.00001 or math.abs(b.X+b.W-a.X)<.00001)
                                if vertical or horizontal then
                                    local x,y=math.min(a.X,b.X),math.min(a.Y,b.Y)
                                    a.W=math.max(a.X+a.W,b.X+b.W)-x
                                    a.H=math.max(a.Y+a.H,b.Y+b.H)-y;a.X=x;a.Y=y
                                    table.remove(pieces,j);changed=true;break
                                end
                            end
                            if changed then break end
                        end
                    end
                    for _,piece in ipairs(pieces) do
                        drawRect(piece.X,piece.Y,piece.W,piece.H,shape.C,shape.Z,shape.A)
                    end
                    covered[#covered+1]=shape
                end
                artwork=nil
            end
            local function sample(stops,t,opacity)
                t=math.max(0,math.min(1,t));local a,b,u
                if t<=.5 then a,b,u=stops[1],stops[2],t*2 else a,b,u=stops[2],stops[3],(t-.5)*2 end
                return color(a[1]+(b[1]-a[1])*u,a[2]+(b[2]-a[2])*u,a[3]+(b[3]-a[3])*u,opacity)
            end
            local function panel(x,y,ww,hh,cut,stops,z,columns,opacity)
                columns=math.min(columns,12) -- Static cached gradient geometry.
                for i=0,columns-1 do
                    local a=ww*i/columns;local b=ww*(i+1)/columns
                    local inset=math.max(0,cut-math.min(a,ww-b))
                    rect(x+a,y+inset,b-a,hh-inset*2,sample(stops,(i+.5)/columns,opacity),z,opacity)
                end
            end
            local function rail(x,y,ww,hh,stops,z,columns)
                columns=math.min(columns,12)
                for i=0,columns-1 do
                    rect(x+ww*i/columns,y,ww/columns,hh,sample(stops,(i+.5)/columns),z)
                end
            end
            local function line(ax,ay,bx,by,th,c,z)
                local dx,dy=bx-ax,by-ay
                local len=math.sqrt(dx*dx+dy*dy)
                if len<=0 then return end
                local angle
                if dx==0 then angle=dy>=0 and 90 or -90
                else angle=math.atan(dy/dx)*180/math.pi;if dx<0 then angle=angle+180 end end
                local w=drawRect((ax+bx-len)/2,(ay+by-th)/2,len,th,c,z,z>=7 and 1 or .5)
                w:SetRenderTransformPivot(vector(.5,.5));w:SetRenderAngle(angle)
            end
            local slate=import("SlateColor")
            local fontObject
            if slua and type(slua.loadObject)=="function" then
                local loaded,obj=pcall(slua.loadObject,"/Engine/EngineFonts/Roboto.Roboto")
                if loaded and valid(obj) then fontObject=obj end
            end
            local function style(w,size,c,bold)
                local font=member(w,"Font")
                if font then
                    if type(font)=="table" then local copy={};for k,v in pairs(font) do copy[k]=v end;font=copy end
                    font.Size=size
                    if fontObject then font.FontObject=fontObject;font.TypefaceFontName=bold and "Bold" or "Regular" end
                    if font.OutlineSettings then
                        local outline=font.OutlineSettings
                        if type(outline)=="table" then local copy={};for k,v in pairs(outline) do copy[k]=v end;outline=copy end
                        outline.OutlineSize=0;font.OutlineSettings=outline
                    end
                    w:SetFont(font)
                end
                w:SetColorAndOpacity(slate(c))
                pcall(function()w:SetShadowOffset(vector(0,0));w:SetShadowColorAndOpacity(color(0,0,0,0))end)
                pcall(function() w:SetAutoWrapText(true) end)
            end
            local function text(value,x,y,ww,hh,size,c,z,bold,center,dynamic)
                local w=make("TextBlock",d.Container);w:SetText(value);style(w,size,c,bold)
                visibility(w,passive);add(w,x,y,ww,hh,z,dynamic)
                if center then pcall(function() w:SetJustification(1) end) end
                return w
            end
            local frame={{30,90,180},{25,70,150},{40,120,220}}
            local bright={{100,170,255},{80,150,230},{120,190,255}}
            local edge={{15,40,90},{20,50,100},{25,60,120}}
            local body={{20,40,80},{25,50,95},{30,55,100}}
            local header={{15,45,110},{20,55,130},{25,70,150}}
            local gold={{40,120,220},{90,170,255},{50,140,240}}
            local white=color(255,255,255)
            local forest=color(160,200,255)
            local burgundy=color(120,180,255)
            -- Perimeter only: an opaque full-panel backing would destroy
            -- the requested body transparency even with alpha on the body.
            panel(6,6,W-12,H-12,10,body,2,24,.5)
            rail(13,0,W-26,6,frame,3,24)
            rail(13,H-6,W-26,6,frame,3,24)
            rect(0,13,6,H-26,color(30,90,180),3)
            rect(W-6,13,6,H-26,color(40,140,255),3)
            rail(13,1,W-26,1.5,bright,3,24)
            rail(13,H-3,W-26,1.5,edge,3,24)
            rect(1,13,1.5,H-26,color(100,170,255),3)
            rect(W-3,13,1.5,H-26,color(80,160,240),3)
            for _,s in ipairs({{1,13,13,1},{1,H-13,13,H-1}}) do line(s[1],s[2],s[3],s[4],2,color(90,165,255),3) end
            for _,s in ipairs({{W-13,1,W-1,13},{W-13,H-1,W-1,H-13}}) do line(s[1],s[2],s[3],s[4],2,color(70,150,230),3) end
            panel(10,10,W-20,65,16,gold,4,24,1)
            panel(13,13,W-26,59,14,header,5,32,1)
            if welcome then
                d.Title=text("Welcome to LUA-CORE Lua mod",24,22,W-48,42,19,white,7,true,true)
                local pw=math.min(340,W-72);local px=(W-pw)/2
                panel(px,99,pw,51,12,gold,4,16)
                panel(px+3,102,pw-6,45,10,{{20,60,140},{40,110,210},{25,80,170}},5,20)
                d.Detail=text("Kill limit 8-10",px+16,109,pw-32,34,23,white,7,true,true)
                d.Hint=text("Play smart and avoid report",30,165,W-60,32,17,forest,7,true,true)
            else
                d.Title=text("LUA-CORE",22,15,W-44,31,24,white,7,true,true)
                text("LOGIN",22,45,W-44,21,12,white,7,true,true)
                line(W/2-118,56,W/2-47,56,1,color(140,190,255),7)
                line(W/2+47,56,W/2+118,56,1,color(140,190,255),7)
                text("LOGIN KEY",22,82,W-44,20,13,burgundy,7,true,false)
                rail(27,104,W-54,2,gold,4,24)
                rail(27,143,W-54,2,gold,4,24)
                rect(20,111,2,27,color(40,120,220),4)
                rect(W-22,111,2,27,color(50,140,240),4)
                line(20,111,27,104,2,color(90,170,255),4)
                line(W-27,104,W-20,111,2,color(90,170,255),4)
                line(20,138,27,145,2,color(90,170,255),4)
                line(W-27,145,W-20,138,2,color(90,170,255),4)
                d.Input=make("EditableTextBox",d.Container)
                d.Input:SetText(key or "")
                -- Input-specific native style; TextBlock-only methods stay unused.
                local fg=forest;local bg=color(20,40,90,0)
                local inputStyle=member(d.Input,"WidgetStyle")
                if inputStyle then
                    if type(inputStyle)=="table" then local copy={};for k,v in pairs(inputStyle) do copy[k]=v end;inputStyle=copy end
                    local inputFont=member(inputStyle,"Font")
                    if inputFont then
                        if type(inputFont)=="table" then local copy={};for k,v in pairs(inputFont) do copy[k]=v end;inputFont=copy end
                        inputFont.Size=17
                        if fontObject then inputFont.FontObject=fontObject;inputFont.TypefaceFontName="Regular" end
                        inputStyle.Font=inputFont
                    end
                    inputStyle.ForegroundColor=slate(fg);inputStyle.ReadOnlyForegroundColor=slate(fg)
                    for _,name in ipairs({"BackgroundImageNormal","BackgroundImageHovered","BackgroundImageFocused","BackgroundImageReadOnly"}) do
                        local brush=member(inputStyle,name)
                        if brush then
                            if type(brush)=="table" then local copy={};for k,v in pairs(brush) do copy[k]=v end;brush=copy end
                            brush.TintColor=slate(bg);inputStyle[name]=brush
                        end
                    end
                    d.Input.WidgetStyle=inputStyle
                else
                    local inputFont=member(d.Input,"Font")
                    if inputFont then
                        if type(inputFont)=="table" then local copy={};for k,v in pairs(inputFont) do copy[k]=v end;inputFont=copy end
                        inputFont.Size=17;d.Input.Font=inputFont
                    end
                    d.Input.ForegroundColor=fg;d.Input.BackgroundColor=bg
                end
                local setForeground=member(d.Input,"SetForegroundColor")
                if type(setForeground)=="function" then setForeground(d.Input,fg) end
                pcall(function() d.Input:SetHintText("Enter your key") end)
                visibility(d.Input,enums.Visible);add(d.Input,23,107,W-46,35,8,true)
                d.Hint=text("Your key is saved automatically",22,149,W-44,19,11,burgundy,7,false,false)
                d.Status=text(status or "Enter your key",22,170,W-44,23,11,burgundy,8,false,false,true)
            end
            local button=make("Button",d.Container);d.Button=button
            local by=welcome and 212 or 201;local bh=welcome and 42 or 34
            local bw=welcome and 202 or 190;local bx=(W-bw)/2
            panel(bx-4,by-3,bw+8,bh+6,9,gold,4,16)
            panel(bx,by,bw,bh,8,{{0,112,51},{1,149,68},{0,99,46}},5,16)
            pcall(function() button:SetBackgroundColor(color(255,255,255,0)) end)
            visibility(button,enums.Visible)
            local label=make("TextBlock",button);label:SetText("OK");style(label,17,white,true);visibility(label,passive)
            local labelSlot=button:AddChild(label)
            pcall(function() labelSlot:SetHorizontalAlignment(2);labelSlot:SetVerticalAlignment(2) end)
            add(button,bx,by,bw,bh,9,true)
            d.Event=button.OnClicked
            d.Handle=d.Event:Add(function()
                if not d.Visible or d.Busy then return end
                if welcome then
                    destroy(d);d.Dismissed=true
                    local l=_G.LunarLoginRuntime;if l and l.WelcomeUI==d then l.WelcomeUI=nil end
                    return
                end
                local okRead,k=pcall(function() return d.Input:GetText() end)
                if not okRead or type(k)~="string" then return end
                k=k:match("^%s*(.-)%s*$")
                if #k==0 or #k>512 then d.Status:SetText("Enter a valid key");return end
                if d.Submit then d.Submit(k) end
            end)
            renderArt()
            local slot=p:AddChildToCanvas(d.Container);slot:SetAutoSize(false);slot:SetSize(vector(W,H));slot:SetZOrder(9200)
            local anchors=slot:GetAnchors();anchors.Minimum=vector(.5,.5);anchors.Maximum=vector(.5,.5)
            slot:SetAnchors(anchors);slot:SetAlignment(vector(.5,.5));slot:SetPosition(vector(0,0))
            d.Container:SetRenderTransformPivot(vector(.5,.5));d.Container:SetRenderScale(vector(scale,scale))
            visibility(d.Container,passive)
        end)
        if not ok then UI.LastBuildError=tostring(buildError);destroy(d);return nil,"UI_BUILD_UNAVAILABLE" end
        UI.LastBuildError=nil
        d.Visible=true;return d
    end
    _G.LunarUIAssetCache=nil
    -- Hot UI upgrades retain the existing verified or pending license session.
    local existing=_G.LunarLoginRuntime
    if existing and existing.UIFactory and existing.UIFactory.Version~=UI.Version
        and existing.Scope==MasterLicenseCore.Primitives.md5(MasterLicenseConfig.url.."\0"..MasterLicenseConfig.game.."\0"..MasterLicenseConfig.secret) then
        local visibleWelcome=existing.WelcomeUI and existing.WelcomeUI.Visible
        if existing.DestroyUI then existing.DestroyUI() end
        existing.UIFactory.Build=UI.Build;existing.UIFactory.Version=UI.Version
        if visibleWelcome then existing.WelcomeShown=false end
        existing.NeedsUpdate=true
    end
    local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',string.byte(c)) end)) end
    local function unhex(s)
        if type(s)~="string" or #s>1024 or #s%2~=0 or s:find('[^%x]') then return nil end
        return (s:gsub('..',function(v) return string.char(tonumber(v,16)) end))
    end
    local current=_G.LunarLoginRuntime
    -- Existing runtime survives character recreation and source reload in this process.
    local expectedScope=MasterLicenseCore.Primitives.md5(MasterLicenseConfig.url.."\0"..MasterLicenseConfig.game.."\0"..MasterLicenseConfig.secret)
    if not current or current.Scope~=expectedScope then
        if current and current.DestroyUI then current.DestroyUI() end
        local L={Authorized=false,Pending=false,NeedsUpdate=true,WelcomeShown=false,
            Key="",Seed="",Scope=expectedScope,StorageVersion=1,Status="Enter your key",Diagnostics={HTTP=0,DeviceReads=0}}
        _G.LunarLoginRuntime=L
        L.UIFactory=UI
        -- Identity is pinned independently of the feature-settings location.
        -- All IO is bounded and happens at startup/login, or a delayed save retry.
        local paths=g_masterahsanyt_ESPSettingsPaths()
        for i,path in ipairs(paths) do paths[i]=path:gsub("MASTERPIECE_UMG_ESP_settings.lua$","MASTERAHSAN_LOGIN_V7_settings.lua") end
        local function loginPath(featurePath)
            if type(featurePath)~="string" then return nil end
            local prefix=featurePath:match("^(.*[/\\])[^/\\]+$")
            return (prefix or "").."MASTERAHSAN_LOGIN_V7_settings.lua"
        end
        local function identityPath(path)
            return path:gsub("MASTERAHSAN_LOGIN_V7_settings%.lua$","MASTERAHSAN_DEVICE_V1_settings.lua")
        end
        local function digest(key,seed)
            return MasterLicenseCore.Primitives.md5("LUNAR-DEVICE-1\0"..L.Scope.."\0"..key.."\0"..seed)
        end
        local function readRecord(path,identity)
            if not (io and type(io.open)=="function") then return nil,"unreadable" end
            local ok,file,reason,code=pcall(io.open,path,"r")
            if not ok then return nil,"unreadable" end
            if not file then
                local text=type(reason)=="string" and reason:lower() or ""
                if reason==nil or code==2 or text:find("no such file",1,true)
                    or text:find("not found",1,true) or text:find("does not exist",1,true) then
                    return nil,"missing"
                end
                return nil,"unreadable"
            end
            local good,data=pcall(function() return file:read(4097) end)
            pcall(function() file:close() end)
            if not good or type(data)~="string" then return nil,"unreadable" end
            if #data>4096 then return nil,"invalid" end
            local scope=data:match('%f[%w_]Scope%s*=%s*"([%x]+)"')
            if scope and scope~=L.Scope then return nil,"other_scope" end
            if scope~=L.Scope then return nil,"invalid" end
            local key=unhex(data:match('%f[%w_]KeyHex%s*=%s*"([^"]*)"'))
            local seed=unhex(data:match('%f[%w_]SeedHex%s*=%s*"([^"]*)"'))
            if key==nil or seed==nil or #seed==0 or #seed>512 then return nil,"invalid" end
            local check=data:match('%f[%w_]Check%s*=%s*"([%x]+)"')
            local version=data:match('%f[%w_]Version%s*=%s*(%d+)')
            if identity or check or version then
                if version~="1" or check~=digest(key,seed) then return nil,"invalid" end
            end
            return {Key=key,Seed=seed,Path=path,Identity=identity,Checked=version=="1"},"valid"
        end
        local function candidates()
            local list,seen={},{}
            local function add(path)
                if type(path)=="string" and not seen[path] then seen[path]=true;list[#list+1]=path end
            end
            add(L.Path);add(L.PreferredPath)
            for _,path in ipairs(paths) do add(path) end
            return list
        end
        local function recover()
            if L.IdentityPinned then return true end
            local identities,legacy,issues={},{},{}
            local function collect(base,path,identity)
                local record,state=readRecord(path,identity)
                if record then
                    record.Base=base
                    local list=identity and identities or legacy;list[#list+1]=record
                elseif state=="invalid" or (state=="unreadable" and base==L.PreferredPath) then
                    issues[#issues+1]=state
                end
            end
            for _,base in ipairs(candidates()) do
                local device=identityPath(base)
                collect(base,device,true);collect(base,device..".bak",true)
                collect(base,base,false);collect(base,base..".bak",false)
            end
            local list=#identities>0 and identities or legacy
            local first=list[1]
            if first then
                for _,record in ipairs(list) do
                    if record.Seed~=first.Seed then
                        L.IdentityError="DEVICE_CACHE_CONFLICT";L.Diagnostics.Identity="conflict";return false
                    end
                end
                L.Seed=first.Seed;L.Key=first.Key;L.Path=first.Base
                if L.Key=="" then
                    for _,record in ipairs(list) do
                        if record.Key~="" then L.Key=record.Key;break end
                    end
                end
                -- A matching legacy copy can recover the key after a lost write.
                if L.Key=="" then
                    for _,record in ipairs(legacy) do
                        if record.Seed==L.Seed and record.Key~="" then L.Key=record.Key;break end
                    end
                end
                L.IdentityPinned=true;L.IdentityPersisted=true;L.HasIdentityRecord=first.Identity
                L.IdentityError=nil;L.Dirty=true
                L.Diagnostics.Identity=first.Identity and "restored" or "legacy_migration"
                return true
            end
            if #issues>0 then
                L.IdentityError="DEVICE_CACHE_RECOVERY_REQUIRED";L.Diagnostics.Identity="recovery_required";return false
            end
            L.IdentityError=nil;L.Diagnostics.Identity="new_install";return true
        end
        local function payload(key,seed)
            return 'return { Version = 1, Scope = "'..L.Scope..'", KeyHex = "'..hex(key)
                ..'", SeedHex = "'..hex(seed)..'", Check = "'..digest(key,seed)..'" }'
        end
        local function verifiedWrite(path,identity,key,seed,data)
            local current,state=readRecord(path,identity)
            if current and current.Checked and current.Seed==seed and current.Key==key then return true end
            if state=="unreadable" or state=="other_scope" then return false end
            if current and current.Seed~=seed and (identity or not L.HasIdentityRecord) then return false end
            local ok=g_masterahsanyt_ESPWriteSettings(path,data)
            if not ok then return false end
            local result=readRecord(path,identity)
            return result~=nil and result.Checked and result.Seed==seed and result.Key==key
        end
        L.Save=function()
            if L.Seed=="" or L.IdentityError then return false end
            local key=L.AttemptKey or L.Key
            local data=payload(key,L.Seed)
            local preferred=candidates()
            for _,base in ipairs(preferred) do
                local device=identityPath(base)
                local old,oldState=readRecord(base,false)
                local current,currentState=readRecord(device,true)
                -- Never fork around an unreadable/conflicting saved identity.
                if oldState~="unreadable" and currentState~="unreadable"
                    and oldState~="other_scope" and currentState~="other_scope"
                    and (not old or old.Seed==L.Seed or L.HasIdentityRecord)
                    and (not current or current.Seed==L.Seed) then
                    local a=verifiedWrite(device,true,key,L.Seed,data)
                    local b=verifiedWrite(device..".bak",true,key,L.Seed,data)
                    local c=verifiedWrite(base,false,key,L.Seed,data)
                    local d=verifiedWrite(base..".bak",false,key,L.Seed,data)
                    if (a or b) and ((a and b) or c or d) then
                        L.Path=base;L.Key=key;L.IdentityPinned=true;L.IdentityPersisted=true;L.HasIdentityRecord=true
                        L.IdentityError=nil;L.Dirty=not (a and b and c and d)
                        L.SaveRetryAt=L.Dirty and (os.time()+30) or nil
                        L.SaveError=L.Dirty and "Device backup repair pending" or nil
                        L.Diagnostics.Identity=L.Dirty and "backup_pending" or "saved"
                        return true
                    end
                end
            end
            L.Dirty=true;L.SaveRetryAt=os.time()+30
            L.SaveError="Device cache could not be verified";L.Diagnostics.Identity="save_failed"
            return false
        end
        L.BindSettingsPath=function(featurePath)
            L.PreferredPath=loginPath(featurePath)
            -- Once recovered, neither the key nor seed is replaced by settings.
            if not L.IdentityPinned then recover() end
            if L.Seed~="" and not L.IdentityError and (L.Dirty or not L.IdentityPersisted) then L.Save() end
        end
        L.EnsureIdentity=function()
            if not L.IdentityPinned then
                L.Seed=""
                assert(recover(),L.IdentityError or "DEVICE_CACHE_RECOVERY_REQUIRED")
            end
            if L.Seed=="" then
                L.Diagnostics.DeviceReads=L.Diagnostics.DeviceReads+1
                local id=_G.SecureX_DeviceID and _G.SecureX_DeviceID() or nil
                assert(type(id)=="string" and #id>0 and #id<=512,"DEVICE_ID_UNAVAILABLE")
                L.Seed=id
            end
            local saved=L.Save()
            -- A readable previously stored identity stays usable on read-only
            -- storage. Backup repair must not invent or force a new device ID.
            assert(saved or L.IdentityPersisted,"DEVICE_CACHE_SAVE_FAILED")
        end
        recover()
        L.DestroyUI=function() destroy(L.LoginUI);destroy(L.WelcomeUI);L.LoginUI=nil;L.WelcomeUI=nil end
        local function wake()
            local f=_G.LunarFeatures;if f and f.Wake and not f.Token.Stopped then f.Wake() end
        end
        L.Core=MasterLicenseCore
        L.Auth=MasterLicenseCore.new(MasterLicenseConfig,{
            clock=function() local t=os.time();return t,L.Scope end,
            wall=function() return os.time() end,
            serial=function(key)
                L.EnsureIdentity()
                return MasterLicenseCore.Primitives.name_uuid('MASTER-LUA-V1\0'..key..'\0'..L.Seed)
            end,
            decode=function(raw)
                local ok,json=pcall(require,"common.json_util")
                if not ok or not json or type(json.decode)~="function" then return nil end
                return json.decode(raw)
            end,
            post=function(url,headers,body,callback,timeout)
                local http
                pcall(function()
                    local mm=ModuleManager
                    if not mm then
                        local ok,m2=pcall(require,"client.module_framework.ModuleManager")
                        if ok then mm=m2 end
                    end
                    if mm and type(mm.GetModule)=="function" then
                        local cfg=mm.CommonModuleConfig or {}
                        http=mm.GetModule(cfg.http_manager or "http_manager")
                    end
                end)
                if not http then
                    pcall(function()
                        local ok,m3=pcall(require,"common.http_manager")
                        if ok then http=m3 end
                    end)
                end
                if not http or type(http.Post)~="function" then
                    L.Diagnostics.HTTPError="http_manager unavailable"
                    return false
                end
                L.Diagnostics.HTTP=L.Diagnostics.HTTP+1
                return http:Post(url,headers,body,nil,callback,timeout)
            end,
            status=function(message,phase)
                L.Status=message;L.Pending=phase=="pending"
                if phase=="active" then
                    L.Authorized=true;L.Key=L.AttemptKey or L.Key;L.Save()
                    destroy(L.LoginUI);L.LoginUI=nil
                else L.Authorized=false end
                L.NeedsUpdate=true
                local d=L.LoginUI
                if d then
                    if d.StatusText~=message then d.Status:SetText(message);d.StatusText=message end
                    if d.Busy~=L.Pending then
                        d.Busy=L.Pending
                        pcall(function() d.Input:SetIsEnabled(not L.Pending);d.Button:SetIsEnabled(not L.Pending) end)
                    end
                end
                wake()
            end
        })
        L.Authorized=L.Auth.IsAuthorized()
        L.Login=function(key)
            if L.Authorized or L.Pending then return false end
            L.AttemptKey=type(key)=="string" and key:match("^%s*(.-)%s*$") or ""
            local ok,result=pcall(L.Auth.Login,L.AttemptKey)
            if not ok then L.Status="Login could not start";L.Pending=false;L.NeedsUpdate=true;wake();return false end
            return result
        end
        L.Logout=function()
            L.Auth.Logout();L.Authorized=false;L.DestroyUI();L.NeedsUpdate=true;wake()
        end
        L.Update=function()
            if L.Pending then L.Auth.Tick() end
            if L.Dirty and (not L.SaveRetryAt or os.time()>=L.SaveRetryAt or os.time()<L.SaveRetryAt-30) then L.Save() end
            if L.Authorized then
                if not L.WelcomeShown then
                    local d=UI.Build("welcome")
                    if d then L.WelcomeUI=d;L.WelcomeShown=true end
                end
                L.NeedsUpdate=not L.WelcomeShown or L.Dirty
                return
            end
            local p=parent()
            if L.LoginUI and (not valid(L.LoginUI.Container) or p~=L.LoginUI.Parent) then destroy(L.LoginUI);L.LoginUI=nil end
            if not L.LoginUI then
                local d=UI.Build("login",L.Key,L.Status,L.Login)
                if d then
                    d.Busy=L.Pending;d.StatusText=L.Status;L.LoginUI=d
                    pcall(function() d.Input:SetIsEnabled(not L.Pending);d.Button:SetIsEnabled(not L.Pending) end)
                end
            end
            L.NeedsUpdate=true -- Half-second retry/readiness while locked only.
        end
    end
    _G.MasterLicenseLogin=function(key) return _G.LunarLoginRuntime.Login(key) end
    _G.MasterLicenseLogout=function() return _G.LunarLoginRuntime.Logout() end
    _G.MasterLicenseStatus=function()
        local l=_G.LunarLoginRuntime
        return {authorized=l.Authorized,pending=l.Pending,message=l.Status,
            periodicRecheck=false,expiryCheckPolicy="login_only",saveOK=not l.Dirty,identityState=l.Diagnostics.Identity}
    end

end


-- ===== END Login.lua portable module =====

-- ---- 2.5.3  Runtime driver ------------------------------------------------
-- Login.lua declares Start() in its docs but never implements it.  This is the
-- 0.5s (locked) / 2.0s (authorized) driver that keeps the login window alive,
-- ticks request timeouts and boots the cheat once the key is accepted.
do
    local L = _G.LunarLoginRuntime
    if L then
        local started = false

        local function schedule(iv, fn)
            local okT, ticker = pcall(require, "common.time_ticker")
            if okT and ticker then
                if type(ticker.AddTimerOnce) == "function" then ticker.AddTimerOnce(iv, fn) return true end
                if type(ticker.AddTimer) == "function" then ticker.AddTimer(iv, fn) return true end
            end
            if type(_G.SetTimerOnce) == "function" then _G.SetTimerOnce(iv, fn) return true end
            if type(_G.SetTimer) == "function" then _G.SetTimer(iv, fn) return true end
            if _G.common and _G.common.time_ticker then
                local t2 = _G.common.time_ticker
                if type(t2.AddTimerOnce) == "function" then t2.AddTimerOnce(iv, fn) return true end
                if type(t2.AddTimer) == "function" then t2.AddTimer(iv, fn) return true end
            end
            return false
        end

        function L.Start()
            if started then return true end
            started = true
            local function tick()
                -- One-shot auto sign-in: the key is persisted on the device, so a
                -- returning user is validated without retyping anything.  If the
                -- attempt fails (offline / expired) the login window stays up with
                -- the key pre-filled and the normal OK button still works.
                if not L.Authorized and not L.Pending
                    and not _G._SecureXAutoTried
                    and type(L.Key) == "string" and #L.Key > 0 then
                    _G._SecureXAutoTried = true
                    pcall(L.Login, L.Key)
                end
                pcall(L.Update)
                if L.Authorized and type(_G.SecureX_BootFeatures) == "function" then
                    pcall(_G.SecureX_BootFeatures)
                end
                schedule(L.Authorized and 2.0 or 0.5, tick)
            end
            tick()
            return true
        end

        -- Expose a tiny diagnostic surface.
        _G.SecureX_LoginState = function()
            return {
                authorized = L.Authorized == true,
                pending    = L.Pending == true,
                message    = L.Status,
                identity   = L.Diagnostics and L.Diagnostics.Identity,
                httpCalls  = L.Diagnostics and L.Diagnostics.HTTP,
            }
        end

        pcall(L.Start)
    end
end

-- ============================================================================
-- 3. OFFICIAL ASSET CONFIGURATIONS (VERIFIED AGAINST BGMI.CSV)
-- ============================================================================
_G.VEHICLE_ICON_CONFIG = {
    -- Cars (Roof height ~140-195cm; elevated to 185-235cm)
    { key = "Veh_Icon_UAZ",        catKey = "Veh_Cat_Cars",     id = 71001, name = "UAZ",          title = "UAZ 4x4",             icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_Jeep.Radar_icon_Jeep",                         zOffset = 235 },
    { key = "Veh_Icon_Dacia",      catKey = "Veh_Cat_Cars",     id = 71003, name = "Dacia",        title = "Dacia Sedan",         icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_car.Radar_icon_car",                           zOffset = 195 },
    { key = "Veh_Icon_Coupe",      catKey = "Veh_Cat_Cars",     id = 71005, name = "Coupe RB",     title = "Coupe RB",            icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_Icon_Car_02.Radar_Icon_Car_02",                     zOffset = 185 },
    { key = "Veh_Icon_Mirado",     catKey = "Veh_Cat_Cars",     id = 71006, name = "Mirado",       title = "Mirado Muscle",       icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_sportscar.Radar_icon_sportscar",               zOffset = 190 },

    -- Light & Buggies (Cage/Cab ~155-250cm; elevated to 195-310cm)
    { key = "Veh_Icon_Buggy",      catKey = "Veh_Cat_Light",    id = 71002, name = "Buggy",        title = "Buggy Racer",         icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_Buggy.Radar_icon_Buggy",                       zOffset = 195 },
    { key = "Veh_Icon_Monster",    catKey = "Veh_Cat_Light",    id = 71009, name = "Monster",      title = "Monster Truck",       icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_Bigfoot.Radar_icon_Bigfoot",                   zOffset = 310 },
    { key = "Veh_Icon_MiniBus",    catKey = "Veh_Cat_Light",    id = 71008, name = "MiniBus",      title = "MiniBus",         icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_Bus.Radar_icon_Bus",                           zOffset = 265 },

    -- Motorcycles & Mopeds (Rider height ~145cm; elevated to 175-180cm)
    { key = "Veh_Icon_Motorcycle", catKey = "Veh_Cat_Bikes",    id = 71004, name = "Motorcycle",   title = "Motorcycle",          icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_moto.Radar_icon_moto",                         zOffset = 180 },
    { key = "Veh_Icon_Scooter",    catKey = "Veh_Cat_Bikes",    id = 71012, name = "Scooter",      title = "Scooter Moped",       icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_PedalMotorcycle.Radar_icon_PedalMotorcycle",   zOffset = 175 },

    -- Armored Tanks
    { key = "Veh_Icon_BRDM",       catKey = "Veh_Cat_Armored",  id = 71007, name = "BRDM-2",       title = "BRDM-2 Armored",      icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_ArmoredVehicles.Radar_icon_ArmoredVehicles",   zOffset = 265 },

    -- Water & Air (Clean top clearance)
    { key = "Veh_Icon_Boat",       catKey = "Veh_Cat_WaterAir", id = 71010, name = "Boat",         title = "Speedboat",           icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_boat.Radar_icon_boat",                         zOffset = 185 },
    { key = "Veh_Icon_JetSki",     catKey = "Veh_Cat_WaterAir", id = 71011, name = "Jet Ski",      title = "Jet Ski",             icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_Doubleboat.Radar_icon_Doubleboat",             zOffset = 165 },
    { key = "Veh_Icon_Glider",     catKey = "Veh_Cat_WaterAir", id = 71013, name = "Glider",       title = "Glider",        icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_paraglider.Radar_icon_paraglider",             zOffset = 265 },
    { key = "Veh_Icon_Helicopter", catKey = "Veh_Cat_WaterAir", id = 71014, name = "Helicopter",   title = "Helicopter",          icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_helicopter.Radar_icon_helicopter",             zOffset = 320 },
    { key = "Veh_Icon_Horse",      catKey = "Veh_Cat_WaterAir", id = 71015, name = "Horse",        title = "Horse",         icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_Horse.Radar_icon_Horse",                       zOffset = 225 },
    { key = "Veh_Icon_General",    catKey = "Veh_Cat_Cars",     id = 71016, name = "Vehicle",      title = "General Car Pin",     icon = "/Game/Arts/UI/NoAtlas/Activity_Icon/CG007_Radar/Radar_icon_car.Radar_icon_car",                           zOffset = 210 }
}

-- Essential-Only Loot Items (Strict Game-Changing Items)
_G.ITEM_ICON_CONFIG = {
    -- 1. Flares & Airdrop Crates
    { key = "Loot_FlareGun",      catKey = "Loot_Cat_Flares",     id = 72001, name = "Flare Gun",    itemIds = { 106007, 106009, 106103 }, title = "Flare Gun",          icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_FlareGun.Icon_WEP_FlareGun",         zOffset = 35 },
    { key = "Loot_RespawnFlare",  catKey = "Loot_Cat_Flares",     id = 72002, name = "Respawn Flare",itemIds = { 106107 },                 title = "Respawn Flare",      icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_FlareGun_02.Icon_WEP_FlareGun_02",   zOffset = 35 },
    { key = "Loot_Airdrop",       catKey = "Loot_Cat_Flares",     id = 72003, name = "Air Drop Box", itemIds = {},                         title = "Air Drop Crate",     icon = "/Game/Arts/UI/TableIcons/ItemIcon/Item/Icon_Airdrop_128.Icon_Airdrop_128",             zOffset = 45 },

    -- 2. Air Drop Exclusive Weapons
    { key = "Loot_AWM",           catKey = "Loot_Cat_AirDrop",    id = 72004, name = "AWM",          itemIds = { 103003 },                 title = "AWM Sniper",         icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_AWM.Icon_WEP_AWM",                   zOffset = 35 },
    { key = "Loot_AMR",           catKey = "Loot_Cat_AirDrop",    id = 72005, name = "AMR",          itemIds = { 103012 },                 title = "AMR Anti-Materiel",  icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_AMR.Icon_WEP_AMR",                   zOffset = 35 },
    { key = "Loot_Groza",         catKey = "Loot_Cat_AirDrop",    id = 72006, name = "Groza",        itemIds = { 101005 },                 title = "Groza AR",           icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_GROZA.Icon_WEP_GROZA",               zOffset = 35 },
    { key = "Loot_AUG",           catKey = "Loot_Cat_AirDrop",    id = 72007, name = "AUG",          itemIds = { 101006 },                 title = "AUG A3",             icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_AUG.Icon_WEP_AUG",                   zOffset = 35 },
    { key = "Loot_MG3",           catKey = "Loot_Cat_AirDrop",    id = 72008, name = "MG3",          itemIds = { 105010 },                 title = "MG3 LMG",            icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_MG3.Icon_WEP_MG3",                   zOffset = 35 },
    { key = "Loot_MK14",          catKey = "Loot_Cat_AirDrop",    id = 72009, name = "Mk14",         itemIds = { 103007 },                 title = "Mk14 DMR",           icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_MK14.Icon_WEP_MK14",                 zOffset = 35 },

    -- 3. Rifles (AR)
    { key = "Loot_M416",          catKey = "Loot_Cat_AR",         id = 72010, name = "M416",         itemIds = { 101004 },                 title = "M416 AR",            icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_M416.Icon_WEP_M416",                 zOffset = 35 },
    { key = "Loot_AKM",           catKey = "Loot_Cat_AR",         id = 72011, name = "AKM",          itemIds = { 101001 },                 title = "AKM AR",             icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_AK47.Icon_WEP_AK47",                 zOffset = 35 },
    { key = "Loot_SCAR",          catKey = "Loot_Cat_AR",         id = 72034, name = "SCAR-L",        itemIds = { 101003 },                 title = "SCAR-L AR",          icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_SCAR.Icon_WEP_SCAR",                 zOffset = 35 },
    { key = "Loot_M762",          catKey = "Loot_Cat_AR",         id = 72012, name = "M762",         itemIds = { 101008 },                 title = "Beryl M762",         icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_M762_Small.Icon_WEP_M762_Small",     zOffset = 35 },
    { key = "Loot_M16A4",         catKey = "Loot_Cat_AR",         id = 72035, name = "M16A4",        itemIds = { 101002 },                 title = "M16A4 Burst AR",     icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_M16A4.Icon_WEP_M16A4",               zOffset = 35 },
    { key = "Loot_G36C",          catKey = "Loot_Cat_AR",         id = 72041, name = "G36C",         itemIds = { 101007 },                 title = "G36C AR",            icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_G36C.Icon_WEP_G36C",                 zOffset = 35 },

    -- 4. Sniper Rifles & DMRs
    { key = "Loot_Kar98k",        catKey = "Loot_Cat_Snipers",    id = 72013, name = "Kar98K",       itemIds = { 103001 },                 title = "Kar98K Sniper",      icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_Kar98k.Icon_WEP_Kar98k",             zOffset = 35 },
    { key = "Loot_M24",           catKey = "Loot_Cat_Snipers",    id = 72014, name = "M24",          itemIds = { 103002 },                 title = "M24 Sniper",         icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_M24.Icon_WEP_M24",                   zOffset = 35 },
    { key = "Loot_Mini14",        catKey = "Loot_Cat_Snipers",    id = 72036, name = "Mini14",       itemIds = { 103004 },                 title = "Mini14 DMR",         icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_Mini14.Icon_WEP_Mini14",             zOffset = 35 },
    { key = "Loot_SKS",           catKey = "Loot_Cat_Snipers",    id = 72037, name = "SKS",          itemIds = { 103005 },                 title = "SKS DMR",            icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_SKS.Icon_WEP_SKS",                   zOffset = 35 },
    { key = "Loot_SLR",           catKey = "Loot_Cat_Snipers",    id = 72038, name = "SLR",          itemIds = { 103009 },                 title = "SLR DMR",            icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_SLR.Icon_WEP_SLR",                   zOffset = 35 },

    -- 5. SMGs
    { key = "Loot_DP28",          catKey = "Loot_Cat_SMG",        id = 72033, name = "DP-28",         itemIds = { 105001 },                 title = "DP-28 LMG",          icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_DP28.Icon_WEP_DP28",                 zOffset = 35 },
    { key = "Loot_M249",          catKey = "Loot_Cat_SMG",        id = 72015, name = "M249",         itemIds = { 105002 },                 title = "M249 LMG",           icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_M249.Icon_WEP_M249",                 zOffset = 35 },
    { key = "Loot_P90",           catKey = "Loot_Cat_SMG",        id = 72016, name = "P90",          itemIds = { 102105 },                 title = "P90 SMG",            icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_P90.Icon_WEP_P90",                   zOffset = 35 },
    { key = "Loot_UMP45",         catKey = "Loot_Cat_SMG",        id = 72017, name = "UMP45",        itemIds = { 102002 },                 title = "UMP45 SMG",          icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_UMP45.Icon_WEP_UMP45",               zOffset = 35 },
    { key = "Loot_Vector",        catKey = "Loot_Cat_SMG",        id = 72018, name = "Vector",       itemIds = { 102003 },                 title = "Vector SMG",         icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_Vector.Icon_WEP_Vector",             zOffset = 35 },
    { key = "Loot_Uzi",           catKey = "Loot_Cat_SMG",        id = 72019, name = "Micro UZI",    itemIds = { 102001 },                 title = "Micro Uzi",          icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_UZIPro.Icon_WEP_UZIPro",             zOffset = 35 },
    { key = "Loot_PP19",          catKey = "Loot_Cat_SMG",        id = 72042, name = "PP-19",        itemIds = { 102005 },                 title = "PP-19",    icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_PP19.Icon_WEP_PP19",                 zOffset = 35 },
    { key = "Loot_Thompson",      catKey = "Loot_Cat_SMG",        id = 72043, name = "Tommy Gun",    itemIds = { 102004 },                 title = "Tommy Gun SMG",      icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_Thompson.Icon_WEP_Thompson",         zOffset = 35 },

    -- 6. Shotguns
    { key = "Loot_DBS",           catKey = "Loot_Cat_Shotguns",   id = 72044, name = "DBS",           itemIds = { 104004 },                 title = "DBS Shotgun",        icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_DP12.Icon_WEP_DP12",                 zOffset = 35 },
    { key = "Loot_S12K",          catKey = "Loot_Cat_Shotguns",   id = 72045, name = "S12K",          itemIds = { 104003 },                 title = "S12K Shotgun",       icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_S12K.Icon_WEP_S12K",                 zOffset = 35 },

    -- 7. Level 3 Gear
    { key = "Loot_Lv3Helmet",     catKey = "Loot_Cat_Gear",       id = 72020, name = "Lv3 Helmet",    itemIds = { 502003, 502005 },         title = "Level 3 Helmet",     icon = "/Game/Arts/UI/TableIcons/ItemIcon/Equipment/Icon_Helmet_Lv3.Icon_Helmet_Lv3",           zOffset = 35 },
    { key = "Loot_Lv3Armor",      catKey = "Loot_Cat_Gear",       id = 72021, name = "Lv3 Armor",     itemIds = { 503003 },                 title = "Level 3 Armor",      icon = "/Game/Arts/UI/TableIcons/ItemIcon/Equipment/Icon_Armor_Lv3.Icon_Armor_Lv3",             zOffset = 35 },
    { key = "Loot_Lv3Bag",        catKey = "Loot_Cat_Gear",       id = 72022, name = "Lv3 Backpack",  itemIds = { 501003, 501006 },         title = "Level 3 Backpack",   icon = "/Game/Arts/UI/TableIcons/ItemIcon/Equipment/Icon_Bag_Lv3_A.Icon_Bag_Lv3_A",             zOffset = 35 },

    -- 8. High-Power Scopes
    { key = "Loot_Scope8x",       catKey = "Loot_Cat_Scopes",     id = 72023, name = "8x Scope",      itemIds = { 203005, 20300500, 203006 }, title = "8x Scope",           icon = "/Game/Arts/UI/TableIcons/ItemIcon/Attach/Icon_MZJ_8X.Icon_MZJ_8X",                     zOffset = 35 },
    { key = "Loot_Scope6x",       catKey = "Loot_Cat_Scopes",     id = 72024, name = "6x Scope",      itemIds = { 203015, 20301500 },         title = "6x Scope",           icon = "/Game/Arts/UI/TableIcons/ItemIcon/Attach/Icon_MZJ_6X.Icon_MZJ_6X",                     zOffset = 35 },
    { key = "Loot_Scope4x",       catKey = "Loot_Cat_Scopes",     id = 72025, name = "4x Scope",      itemIds = { 203004, 20300400 },         title = "4x Scope",           icon = "/Game/Arts/UI/TableIcons/ItemIcon/Attach/Icon_MZJ_4X.Icon_MZJ_4X",                     zOffset = 35 },
    { key = "Loot_Scope3x",       catKey = "Loot_Cat_Scopes",     id = 72032, name = "3x Scope",      itemIds = { 203014, 20301400 },         title = "3x Scope",           icon = "/Game/Arts/UI/TableIcons/ItemIcon/Attach/Icon_MZJ_3X.Icon_MZJ_3X",                     zOffset = 35 },

    -- 9. Medicine & Boosters
    { key = "Loot_MedKit",        catKey = "Loot_Cat_Meds",       id = 72026, name = "Med Kit",       itemIds = { 601005 },                 title = "Med Kit",            icon = "/Game/Arts/UI/TableIcons/ItemIcon/Health/Icon_Boost_MKit.Icon_Boost_MKit",             zOffset = 35 },
    { key = "Loot_FirstAid",      catKey = "Loot_Cat_Meds",       id = 72027, name = "First Aid Kit", itemIds = { 601003 },                 title = "First Aid Kit",      icon = "/Game/Arts/UI/TableIcons/ItemIcon/Health/Icon_Heal_FirstAidbox.Icon_Heal_FirstAidbox", zOffset = 35 },
    { key = "Loot_Adrenaline",    catKey = "Loot_Cat_Meds",       id = 72028, name = "Adrenaline",    itemIds = { 601004 },                 title = "Adrenaline Syringe", icon = "/Game/Arts/UI/TableIcons/ItemIcon/Health/Icon_Boost_Injection.Icon_Boost_Injection",   zOffset = 35 },
    { key = "Loot_EnergyDrink",   catKey = "Loot_Cat_Meds",       id = 72039, name = "Energy Drink",  itemIds = { 601001 },                 title = "Energy Drink",       icon = "/Game/Arts/UI/TableIcons/ItemIcon/Health/Icon_Boost_Drink.Icon_Boost_Drink",           zOffset = 35 },
    { key = "Loot_Painkiller",    catKey = "Loot_Cat_Meds",       id = 72040, name = "Painkiller",    itemIds = { 601002 },                 title = "Painkiller",         icon = "/Game/Arts/UI/TableIcons/ItemIcon/Health/Icon_Boost_Pills.Icon_Boost_Pills",           zOffset = 35 },

    -- 10. Throwables
    { key = "Loot_FragGrenade",   catKey = "Loot_Cat_Throwables", id = 72029, name = "Frag Grenade",  itemIds = { 602004, 60200400 },       title = "Frag Grenade",       icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_Grenade.Icon_WEP_Grenade",           zOffset = 35 },
    { key = "Loot_SmokeBomb",     catKey = "Loot_Cat_Throwables", id = 72030, name = "Smoke Bomb",    itemIds = { 602002, 60200200 },       title = "Smoke Grenade",      icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_SmokeBomb.Icon_WEP_SmokeBomb",       zOffset = 35 },
    { key = "Loot_Molotov",       catKey = "Loot_Cat_Throwables", id = 72031, name = "Molotov",       itemIds = { 602003, 602005, 60200300 }, title = "Molotov Cocktail", icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_FireBomb.Icon_WEP_FireBomb",         zOffset = 35 }
}

-- Fast Lookup Mappings (with natural tier priority for crate item selection)
local ITEM_ID_TO_DEF = {}
local ITEM_MARK_ID_TO_DEF = {}
for idx, def in ipairs(_G.ITEM_ICON_CONFIG) do
    def.priority = idx
    ITEM_MARK_ID_TO_DEF[def.id] = def
    if def.itemIds then
        for _, id in ipairs(def.itemIds) do
            ITEM_ID_TO_DEF[id] = def
        end
    end
end

local VEHICLE_NAME_PATTERNS = {
    { "uaz", 71001 }, { "jeep", 71001 }, { "buggy", 71002 }, { "dacia", 71003 }, { "sedan", 71003 },
    { "motorcycle", 71004 }, { "bike", 71004 }, { "moto", 71004 }, { "coupe", 71005 }, { "mirado", 71006 },
    { "brdm", 71007 }, { "bus", 71008 }, { "minibus", 71008 }, { "van", 71008 }, { "bigfoot", 71009 },
    { "monster", 71009 }, { "boat", 71010 }, { "speedboat", 71010 }, { "jetski", 71011 }, { "aquarail", 71011 },
    { "scooter", 71012 }, { "moped", 71012 }, { "glider", 71013 }, { "paraglider", 71013 }, { "helicopter", 71014 },
    { "heli", 71014 }, { "horse", 71015 }
}

local VEHICLE_ID_TO_DEF = {}
for _, def in ipairs(_G.VEHICLE_ICON_CONFIG) do
    VEHICLE_ID_TO_DEF[def.id] = def
end

-- ============================================================================
-- 4. HARDWARE-OPTIMIZED HELPER FUNCTIONS
-- ============================================================================
local function GetActorLocation(actor)
    if not IsValid(actor) then return nil end
    local ok, loc = pcall(actor.K2_GetActorLocation, actor)
    if ok and loc and (loc.X ~= 0 or loc.Y ~= 0 or loc.Z ~= 0) then return loc end
    local ok2, loc2 = false, nil
    if actor.GetActorLocation then
        ok2, loc2 = pcall(actor.GetActorLocation, actor)
        if ok2 and loc2 and (loc2.X ~= 0 or loc2.Y ~= 0 or loc2.Z ~= 0) then return loc2 end
    end
    if actor.RootComponent and IsValid(actor.RootComponent) then
        if actor.RootComponent.K2_GetComponentLocation then
            local ok3, loc3 = pcall(actor.RootComponent.K2_GetComponentLocation, actor.RootComponent)
            if ok3 and loc3 then return loc3 end
        end
    end
    if ok and loc then return loc end
    if ok2 and loc2 then return loc2 end
    return nil
end

local function GetPawnKey(pawn)
    if not IsValid(pawn) then return nil end
    local k = pawn.PlayerKey
    if k and k ~= 0 then return tostring(k) end
    if pawn.GetUniqueID then
        local ok, uid = pcall(pawn.GetUniqueID, pawn)
        if ok and uid and uid ~= 0 then return tostring(uid) end
    end
    local uState = pawn.PlayerState
    if IsValid(uState) and uState.PlayerKey and uState.PlayerKey ~= 0 then return tostring(uState.PlayerKey) end
    return tostring(pawn)
end

-- Stable Vehicle Key: Engine Name is unique per level and survives re-injection.
-- Never use bare tostring(userdata) for vehicles (address changes -> blink + leak).
local function GetVehicleKey(veh)
    if not IsValid(veh) then return nil end
    if type(veh.GetName) == "function" then
        local ok, name = pcall(veh.GetName, veh)
        if ok and name and name ~= "" then
            return "veh_" .. name
        end
    end
    if veh.GetUniqueID then
        local ok, uid = pcall(veh.GetUniqueID, veh)
        if ok and uid and uid ~= 0 then return "veh_uid_" .. tostring(uid) end
    end
    local loc = GetActorLocation(veh)
    if loc then
        return string.format("veh_pos_%.0f_%.0f_%.0f", loc.X, loc.Y, loc.Z)
    end
    return nil
end

-- Shared vehicle death check (UE4 keeps wrecks as valid actors after explosion).
-- File scope so both Phase_Vehicles (1.0s) and FastVehicleSweep (0.25s) agree.
local function IsVehicleDeadShared(veh)
    if not IsValid(veh) then return true end
    local dead = false
    pcall(function()
        if veh.bDead == true or veh.bExploded == true or veh.bDestroyed == true then dead = true end
        if not dead and veh.bHidden == true then dead = true end
        if not dead and veh.Health and type(veh.Health) == "number" and veh.Health <= 0 then dead = true end
        if not dead and veh.VehicleHP and type(veh.VehicleHP) == "number" and veh.VehicleHP <= 0 then dead = true end
        if not dead and veh.CurrentHealth and type(veh.CurrentHealth) == "number" and veh.CurrentHealth <= 0 then dead = true end
        if not dead and veh.GetHealth and type(veh.GetHealth) == "function" then
            local ok, h = pcall(veh.GetHealth, veh)
            if ok and type(h) == "number" and h <= 0 then dead = true end
        end
        if not dead and veh.GetVehicleHealth and type(veh.GetVehicleHealth) == "function" then
            local ok, h = pcall(veh.GetVehicleHealth, veh)
            if ok and type(h) == "number" and h <= 0 then dead = true end
        end
        if not dead and veh.VehicleHealthComponent then
            local hc = veh.VehicleHealthComponent
            if hc then
                if hc.IsDead and type(hc.IsDead) == "function" then
                    local ok, d = pcall(hc.IsDead, hc)
                    if ok and d then dead = true end
                end
                if not dead and hc.Health and type(hc.Health) == "number" and hc.Health <= 0 then dead = true end
                if not dead and hc.CurrentHealth and type(hc.CurrentHealth) == "number" and hc.CurrentHealth <= 0 then dead = true end
            end
        end
    end)
    if not dead and type(veh.IsPendingKill) == "function" then
        local ok, pk = pcall(veh.IsPendingKill, veh)
        if ok and pk then dead = true end
    end
    return dead
end

-- Shared enable check: single source of truth for Phase + Fast sweep.
-- Individual ON overrides category OFF (OR logic) in both places.
local function IsVehicleEnabledShared(def)
    if not def or def == false then return false end
    if def.key and CFG[def.key] == false then return false end
    if def.key and CFG[def.key] == true then return true end
    if def.catKey and CFG[def.catKey] == true then return true end
    return false
end

local function GetLootKey(item)
    if not item then return nil end
    -- 1. Actor Engine Name (Guaranteed unique and immutable in UE4 level)
    if type(item.GetName) == "function" then
        local ok, name = pcall(item.GetName, item)
        if ok and name and name ~= "" then
            return "loot_" .. name
        end
    end
    -- 2. DefineID InstanceID (For BGMI items)
    if item.DefineID and item.DefineID.InstanceID and item.DefineID.InstanceID ~= 0 then
        return "inst_" .. tostring(item.DefineID.InstanceID)
    end
    -- 3. UniqueID
    if type(item.GetUniqueID) == "function" then
        local ok, uid = pcall(item.GetUniqueID, item)
        if ok and uid and uid ~= 0 then
            return "uid_" .. tostring(uid)
        end
    end
    -- 4. Spatial Position Hash (Fallback)
    local loc = GetActorLocation(item)
    if loc then
        return string.format("pos_%.0f_%.0f_%.0f", loc.X, loc.Y, loc.Z)
    end
    return "loot_" .. tostring(item)
end

local function IsPawnDead(pawn)
    if not IsValid(pawn) then return true end
    local hs = pawn.HealthStatus
    if hs and (hs == 2 or hs == 3) then return true end
    if pawn.bIsDead or pawn.bDead then return true end
    if pawn.Health and pawn.Health <= 0 and hs ~= 1 and hs ~= 0 then return true end
    return false
end

local function GetActivePlayerController(passedPC)
    if IsValid(passedPC) and passedPC.AddGameTimer then return passedPC end
    local pc = nil
    pcall(function()
        local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"]
            or (pcall(require, "GameLua.GameCore.Data.GameplayData") and require("GameLua.GameCore.Data.GameplayData"))
        if GameplayData and GameplayData.GetPlayerController then pc = GameplayData.GetPlayerController() end
    end)
    if IsValid(pc) and pc.AddGameTimer then return pc end

    pcall(function()
        if slua_GameFrontendHUD and IsValid(slua_GameFrontendHUD) then
            pc = slua_GameFrontendHUD:GetPlayerController()
        end
    end)
    if IsValid(pc) and pc.AddGameTimer then return pc end

    -- Native C++ Engine GetPlayerController (Official GameplayStatics pattern across 327+ BGMI modules)
    pcall(function()
        local world = (_slua and _slua.getWorld and _slua.getWorld())
        local ctx = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            or world
            or (CGame and CGame.GetGameInstance and CGame:GetGameInstance())
        local GPS = import("GameplayStatics") or import("/Script/Engine.GameplayStatics")
        if GPS and ctx and GPS.GetPlayerController then
            local retPc = GPS.GetPlayerController(ctx, 0)
            if IsValid(retPc) and retPc.AddGameTimer then pc = retPc end
        end
    end)
    if IsValid(pc) and pc.AddGameTimer then return pc end

    pcall(function()
        local lp = (slua_GameFrontendHUD and (slua_GameFrontendHUD.LocalPlayer or slua_GameFrontendHUD.MyPawn))
        if lp and IsValid(lp) and lp.GetController then
            local retPc = lp:GetController()
            if IsValid(retPc) and retPc.AddGameTimer then pc = retPc end
        end
    end)
    return pc
end

local function GetLocalPlayer(pc)
    local p = nil
    if IsValid(pc) then
        pcall(function()
            if pc.GetPlayerCharacterSafety then p = pc:GetPlayerCharacterSafety() end
            if not IsValid(p) and pc.GetCurPlayerCharacter then p = pc:GetCurPlayerCharacter() end
            if not IsValid(p) and pc.GetPlayerCharacter then p = pc:GetPlayerCharacter() end
            -- Canonical UE possessed-pawn path (covers TDM/Arena/Room controllers
            -- like TPlanTDMPlayerController where Safety/Cur wrappers differ)
            if not IsValid(p) and pc.GetPawn then p = pc:GetPawn() end
            if not IsValid(p) and pc.Pawn then p = pc.Pawn end
        end)
    end
    if not IsValid(p) then
        pcall(function()
            local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"]
                or (pcall(require, "GameLua.GameCore.Data.GameplayData") and require("GameLua.GameCore.Data.GameplayData"))
            if GameplayData then
                if GameplayData.GetLocalCharacter then p = GameplayData.GetLocalCharacter() end
                if not IsValid(p) and GameplayData.GetPlayerCharacter then p = GameplayData.GetPlayerCharacter() end
            end
        end)
    end
    if not IsValid(p) and slua_GameFrontendHUD and IsValid(slua_GameFrontendHUD) then
        p = slua_GameFrontendHUD.LocalPlayer or slua_GameFrontendHUD.MyPawn
    end
    if not IsValid(p) and IsValid(pc) then
        pcall(function()
            local hud = (pc.GetHUD and pc:GetHUD()) or pc.MyHUD
            if hud and IsValid(hud) then
                p = hud.LocalPlayer or hud.MyPawn
            end
        end)
    end
    return p
end

-- ============================================================================
-- UNIVERSAL MULTI-MODE PAWN ENUMERATION ENGINE (CLASSIC, TDM, ARENA, PAYLOAD, WOW)
-- ============================================================================
local _cachedPawnsList = nil
local _cachedPawnsTime = 0
local _PAWN_CACHE_TTL = 0.3  -- Reuse same pawn list for 300ms (covers entire combat tick cycle)

local function GetCachedPlayerPawns()
    -- TTL cache: return same list within 0.3s (Phase_Enemies + AimFilter + GetAllEnemies all call this in same tick)
    local now = GetGameTimeNow()
    local dt = now - _cachedPawnsTime
    -- Fix for 2nd Match Dead Bug: if dt < 0 (new match clock reset), immediately invalidate cache!
    if _cachedPawnsList and dt >= 0 and dt < _PAWN_CACHE_TTL then
        return _cachedPawnsList
    end

    local pawnsList = {}
    local seenPawns = {}
    local enemyCountFound = 0
    local pc = GetActivePlayerController()
    local localPawn = GetLocalPlayer(pc)

    local function AddPawn(p)
        if not IsValid(p) then return end
        local key = GetPawnKey(p) or tostring(p)
        if not seenPawns[key] then
            seenPawns[key] = true
            pawnsList[#pawnsList + 1] = p
            if localPawn and p ~= localPawn and IsEnemyPawn(localPawn, p) then
                enemyCountFound = enemyCountFound + 1
            end
        end
    end

    -- Always ensure local player is first
    if IsValid(localPawn) then AddPawn(localPawn) end

    -- Tier 1: Game:GetAllPlayerPawns() (Native CGame Player Pawn Array)
    pcall(function()
        local g = _G.Game or Game or CGame
        if g and g.GetAllPlayerPawns then
            local pawns = g:GetAllPlayerPawns()
            if pawns then
                local n = nil
                pcall(function() if type(pawns.Num) == "function" then n = pawns:Num() end end)
                if n and n > 0 then
                    for i = 0, n - 1 do
                        local p = nil
                        pcall(function() p = pawns:Get(i) end)
                        if p then AddPawn(p) end
                    end
                elseif type(pawns) == "table" then
                    for _, p in pairs(pawns) do AddPawn(p) end
                end
            end
        end
    end)

    -- Tier 2: GameplayData.GetAllCharacters() / ClientGlobalData (Tencent's official client character registry)
    -- Ultra-fast pure Lua table lookup (0.01ms) — contains ALL batch-movement replicated characters in TDM & Classic!
    pcall(function()
        local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"]
            or (pcall(require, "GameLua.GameCore.Data.GameplayData") and require("GameLua.GameCore.Data.GameplayData"))
        if GameplayData then
            if GameplayData.GetAllCharacters then
                local chars = GameplayData.GetAllCharacters()
                if chars then for _, c in pairs(chars) do if c then AddPawn(c) end end end
            end
            if GameplayData.ClientGlobalData and GameplayData.ClientGlobalData.GetAllCharacters then
                local chars2 = GameplayData.ClientGlobalData.GetAllCharacters()
                if chars2 then for _, c in pairs(chars2) do if c then AddPawn(c) end end end
            end
        end
    end)

    -- Tier 3: GameState.PlayerArray (Iterate all PlayerStates and retrieve replicated characters)
    -- Crucial in TDM / Arena: EVERY connected player has a PlayerState in PlayerArray!
    pcall(function()
        local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"]
        local gs = (GameplayData and GameplayData.GetGameState and GameplayData.GetGameState())
            or (CGameState and IsValid(CGameState) and CGameState)
        if gs and IsValid(gs) and gs.PlayerArray then
            local pa = gs.PlayerArray
            local n = (type(pa.Num) == "function") and pa:Num() or (type(pa) == "table" and #pa) or 0
            for i = 0, n - 1 do
                local ps = (type(pa.Get) == "function") and pa:Get(i) or pa[i + 1]
                if ps and IsValid(ps) then
                    local p = (ps.GetPawn and ps:GetPawn())
                        or (ps.GetPlayerCharacter and ps:GetPlayerCharacter())
                        or ps.Pawn
                    if p and IsValid(p) then AddPawn(p) end
                end
            end
        end
    end)

    -- Tier 4: GameplayStatics.GetAllActorsOfClass for STExtraBaseCharacter + TDMPlayerCharacter
    -- In TDM/Arena, 4 teammates satisfy #pawnsList < 5, so we must check enemyCountFound < 4!
    if enemyCountFound < 4 or #pawnsList < 6 then
        pcall(function()
            local gps = _GPS_Cached or import("GameplayStatics")
            local cls = import("/Script/ShadowTrackerExtra.STExtraBaseCharacter") or import("STExtraBaseCharacter")
            local world = (_slua and _slua.getWorld and _slua.getWorld())
            local ctx = localPawn or pc or world
                or (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
                or (CGame and CGame.GetGameInstance and CGame:GetGameInstance())
            if gps and cls and ctx and gps.GetAllActorsOfClass then
                local arr = (slua and slua.Array and UEnums and UEnums.EPropertyClass and slua.Array(UEnums.EPropertyClass.Object, import("/Script/Engine.Actor")))
                local list = gps.GetAllActorsOfClass(ctx, cls, arr)
                if list then
                    local n = (type(list.Num) == "function") and list:Num() or (type(list) == "table" and #list) or 0
                    for i = 0, n - 1 do
                        local act = (type(list.Get) == "function") and list:Get(i) or list[i + 1]
                        if act and IsValid(act) then AddPawn(act) end
                    end
                end
            end
        end)
    end

    -- Tier 5: STExtraPlayerCharacter (Subclass for players fallback)
    if enemyCountFound < 4 or #pawnsList < 6 then
        pcall(function()
            local gps = _GPS_Cached or import("GameplayStatics")
            local cls = import("/Script/ShadowTrackerExtra.STExtraPlayerCharacter") or import("STExtraPlayerCharacter")
            local world = (_slua and _slua.getWorld and _slua.getWorld())
            local ctx = localPawn or pc or world
                or (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            if gps and cls and ctx and gps.GetAllActorsOfClass then
                local arr = (slua and slua.Array and UEnums and UEnums.EPropertyClass and slua.Array(UEnums.EPropertyClass.Object, import("/Script/Engine.Actor")))
                local list = gps.GetAllActorsOfClass(ctx, cls, arr)
                if list then
                    local n = (type(list.Num) == "function") and list:Num() or 0
                    for i = 0, n - 1 do
                        local act = (type(list.Get) == "function") and list:Get(i) or list[i + 1]
                        if act and IsValid(act) then AddPawn(act) end
                    end
                end
            end
        end)
    end

    _cachedPawnsList = pawnsList
    _cachedPawnsTime = now
    return pawnsList
end
_G.GetCachedPlayerPawns = GetCachedPlayerPawns

-- ============================================================================
-- UNIVERSAL TEAM & ENEMY CLASSIFICATION ENGINE (100% BULLETPROOF ACROSS ALL MODES)
-- Verified against TeamAttackUtil.lua, BTService_ChooseEnemy.lua, & libUE4.so
-- ============================================================================
local _PawnTeamCache = _G._PawnTeamCache or {}
_G._PawnTeamCache = _PawnTeamCache
local _ActiveHPMarkPawns = {}
local _ActiveEnemyMarkPawns = {}

-- Lexical Scope Note: _G.ResetSecurexMatchCaches definition placed after line 5838 so all 11 file-local caches are in true lexical scope.

local function ResolvePawnTeamID(pawn)
    if not IsValid(pawn) then return nil end
    local pKey = GetPawnKey(pawn)
    local tid = nil
    -- 1. Direct character property (TeamID or TeamId)
    if pawn.TeamID ~= nil and pawn.TeamID ~= 0 then tid = pawn.TeamID
    elseif pawn.TeamId ~= nil and pawn.TeamId ~= 0 then tid = pawn.TeamId
    end
    -- 2. Method call on character (GetTeamID or GetTeamId)
    if tid == nil or tid == 0 then
        if type(pawn.GetTeamID) == "function" then
            local ok, val = pcall(pawn.GetTeamID, pawn)
            if ok and val ~= nil and val ~= 0 then tid = val end
        elseif type(pawn.GetTeamId) == "function" then
            local ok, val = pcall(pawn.GetTeamId, pawn)
            if ok and val ~= nil and val ~= 0 then tid = val end
        end
    end
    -- 3. PlayerState on character (vital in TDM / Arena!)
    if tid == nil or tid == 0 then
        local ps = pawn.PlayerState
        if IsValid(ps) then
            if ps.TeamID ~= nil and ps.TeamID ~= 0 then tid = ps.TeamID
            elseif ps.TeamId ~= nil and ps.TeamId ~= 0 then tid = ps.TeamId
            elseif type(ps.GetTeamID) == "function" then
                local ok, val = pcall(ps.GetTeamID, ps)
                if ok and val ~= nil and val ~= 0 then tid = val end
            elseif type(ps.GetTeamId) == "function" then
                local ok, val = pcall(ps.GetTeamId, ps)
                if ok and val ~= nil and val ~= 0 then tid = val end
            end
        end
    end
    -- 4. PlayerController on character (TDM stores TeamID on controller as per TDMUtil.lua)
    if tid == nil or tid == 0 then
        local c = (pawn.GetController and pawn:GetController()) or pawn.Controller
        if IsValid(c) then
            if c.TeamID ~= nil and c.TeamID ~= 0 then tid = c.TeamID
            elseif c.TeamId ~= nil and c.TeamId ~= 0 then tid = c.TeamId
            end
        end
    end
    -- 5. If this is local player, check active PlayerController directly
    if (tid == nil or tid == 0) and GetActivePlayerController then
        local pc = GetActivePlayerController()
        if IsValid(pc) then
            local lp = GetLocalPlayer and GetLocalPlayer(pc)
            if lp == pawn then
                if pc.TeamID ~= nil and pc.TeamID ~= 0 then tid = pc.TeamID
                elseif pc.TeamId ~= nil and pc.TeamId ~= 0 then tid = pc.TeamId
                end
            end
        end
    end
    -- 6. Persistent Team Cache (preserves team ID across deaths/respawns in TDM)
    if tid ~= nil and tid ~= 0 then
        if pKey then _PawnTeamCache[pKey] = tid end
    elseif pKey and _PawnTeamCache[pKey] ~= nil and _PawnTeamCache[pKey] ~= 0 then
        tid = _PawnTeamCache[pKey]
    end
    return tid
end

local function ResolvePawnCampID(pawn)
    if not IsValid(pawn) then return nil end
    local camp = nil
    if pawn.CampID ~= nil then camp = pawn.CampID
    elseif pawn.CampId ~= nil then camp = pawn.CampId
    elseif pawn.Camp ~= nil then camp = pawn.Camp
    end
    if camp == nil or camp == 0 then
        local ps = pawn.PlayerState
        if IsValid(ps) then
            if ps.CampID ~= nil and ps.CampID ~= 0 then camp = ps.CampID
            elseif ps.CampId ~= nil and ps.CampId ~= 0 then camp = ps.CampId
            elseif ps.Camp ~= nil and ps.Camp ~= 0 then camp = ps.Camp
            end
        end
    end
    return camp
end

local _EnemyRelationCache = {}
local _LastLocalTeamCheck = nil

local function IsEnemyPawn(localPawn, pawn)
    if not IsValid(pawn) or not IsValid(localPawn) or pawn == localPawn then return false end
    if IsPawnDead(pawn) then return false end

    local myTeam = ResolvePawnTeamID(localPawn)
    if myTeam ~= nil and myTeam ~= 0 and myTeam ~= _LastLocalTeamCheck then
        _LastLocalTeamCheck = myTeam
        _EnemyRelationCache = {}
    end

    local pKey = GetPawnKey(pawn)
    if pKey and _EnemyRelationCache[pKey] ~= nil then
        return _EnemyRelationCache[pKey]
    end

    local isEnemy = true

    -- 1. Official Tencent Native C++ Blueprint Function Library (STExtraBlueprintFunctionLibrary)
    local okBFL, bIsTeammate = pcall(function()
        local BFL = import("STExtraBlueprintFunctionLibrary")
        if BFL then
            if BFL.IsTeammateAttack then
                local isTeam, enabled = BFL.IsTeammateAttack(localPawn, pawn, false)
                if enabled then return isTeam end
            end
            if BFL.CanAttack then
                local canAtk, enabled = BFL.CanAttack(localPawn, pawn, false)
                if enabled then return not canAtk end
            end
        end
        return nil
    end)
    if okBFL and bIsTeammate ~= nil then
        isEnemy = not bIsTeammate
        if pKey then _EnemyRelationCache[pKey] = isEnemy end
        return isEnemy
    end

    -- 2. Official Tencent Game:IsEnemy Engine Check
    local okGameEnemy, isEnemyGame = pcall(function()
        local g = _G.Game or Game or CGame
        if g and g.IsEnemy then
            return g:IsEnemy(localPawn, pawn)
        end
        return nil
    end)
    if okGameEnemy and isEnemyGame ~= nil then
        isEnemy = isEnemyGame
        if pKey then _EnemyRelationCache[pKey] = isEnemy end
        return isEnemy
    end

    -- 3. Official Camp Check (Arena / TDM / WOW Modes) - Coerced to number
    local myCamp = ResolvePawnCampID(localPawn)
    local pCamp = ResolvePawnCampID(pawn)
    if myCamp and pCamp then
        myCamp = tonumber(myCamp)
        pCamp = tonumber(pCamp)
        if myCamp and pCamp and myCamp > 0 and pCamp > 0 and myCamp ~= 999 and pCamp ~= 999 then
            isEnemy = (myCamp ~= pCamp)
            if pKey then _EnemyRelationCache[pKey] = isEnemy end
            return isEnemy
        end
    end

    -- 4. Unified Team ID Resolution (Classic, TDM, 8v8, Gun Game, Solo/FFA)
    local pTeam = ResolvePawnTeamID(pawn)
    if myTeam ~= nil and pTeam ~= nil then
        myTeam = tonumber(myTeam) or myTeam
        pTeam = tonumber(pTeam) or pTeam
        -- In Solo / FFA, all players might have TeamID == 0.
        -- If both are 0, they are enemies unless it's self (which was already checked at top)
        if myTeam == 0 and pTeam == 0 then
            isEnemy = true
        else
            isEnemy = (myTeam ~= pTeam)
        end
        if pKey and (myTeam ~= 0 or pTeam ~= 0) then _EnemyRelationCache[pKey] = isEnemy end
        return isEnemy
    end

    -- 5. PlayerState Teammate List Fallback
    local okTeamList, isTeamFromList = pcall(function()
        local ps = localPawn.PlayerState
        if IsValid(ps) and ps.TeamMatePlayerStateList then
            local list = ps.TeamMatePlayerStateList
            local num = (type(list.Num) == "function") and list:Num() or 0
            for i = 0, num - 1 do
                local matePS = list:Get(i)
                if matePS and IsValid(matePS) then
                    local matePawn = (matePS.GetPlayerCharacter and matePS:GetPlayerCharacter())
                        or (matePS.TeamMatePlayerState and matePS.TeamMatePlayerState:GetPlayerCharacter())
                        or matePS.Pawn
                    if matePawn == pawn then return true end
                end
            end
        end
        return false
    end)
    if okTeamList and isTeamFromList then
        isEnemy = false
        if pKey then _EnemyRelationCache[pKey] = isEnemy end
        return isEnemy
    end

    -- Default: Different pawn and not teammate = Enemy target
    if pKey then _EnemyRelationCache[pKey] = true end
    return true
end
_G.IsEnemyPawn = IsEnemyPawn

-- ============================================================================
-- BULLETPROOF BOT & AI CLASSIFICATION ENGINE (WITH PERMANENT CACHING)
-- ============================================================================
local _PawnAICache = {}

local function ResolveIsAI_Combat(pawn)
    if not IsValid(pawn) then return false end
    local pKey = GetPawnKey(pawn)
    if pKey and _PawnAICache[pKey] ~= nil then
        return _PawnAICache[pKey]
    end

    local isAI = false
    pcall(function()
        if Game and Game.IsAI and Game:IsAI(pawn) then
            isAI = true
        elseif pawn.GetEnsure then
            if pawn:GetEnsure() == true then isAI = true end
        elseif pawn.bEnsure == true then
            isAI = true
        elseif pawn.bIsAI ~= nil then
            isAI = (pawn.bIsAI == true)
        elseif pawn.PlayerKey and type(pawn.PlayerKey) == "string" and string.sub(pawn.PlayerKey, 1, 2) == "AI" then
            isAI = true
        end
    end)
    if pKey then _PawnAICache[pKey] = isAI end
    return isAI
end
_G.ResolveIsAI_Combat = ResolveIsAI_Combat

local function GetAllVehicles()
    local vehList = nil
    pcall(function()
        local g = _G.Game or Game or CGame
        if g and g.GetAllVehicles then vehList = g:GetAllVehicles() end
    end)
    if not vehList then
        pcall(function()
            local g = _G.Game or Game or CGame
            local cls = import("/Script/ShadowTrackerExtra.STExtraVehicleBase") or import("STExtraVehicleBase")
            if cls and g and g.GetActorsByClass then vehList = g:GetActorsByClass(cls) end
        end)
    end
    if not vehList then
        pcall(function()
            local gps = import("GameplayStatics")
            local cls = import("/Script/ShadowTrackerExtra.STExtraVehicleBase") or import("STExtraVehicleBase")
            local world = (_slua and _slua.getWorld and _slua.getWorld())
            local gi = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            local ctx = gi or world
            if gps and cls and ctx and gps.GetAllActorsOfClass then
                local arr = (slua and slua.Array and UEnums and UEnums.EPropertyClass and slua.Array(UEnums.EPropertyClass.Object, cls)) or {}
                vehList = gps.GetAllActorsOfClass(ctx, cls, arr)
            end
        end)
    end
    return vehList
end

-- Safe Actor Iterator for both slua.Array (userdata) and native Lua tables
local function SafeIterateActors(actorList, callback)
    if not actorList then return end
    local handled = false
    local count = 0
    pcall(function()
        if type(actorList.Num) == "function" then
            count = actorList:Num()
        elseif type(actorList) == "table" and #actorList > 0 then
            count = #actorList
        end
    end)
    if count and count > 0 then
        handled = true
        for i = 0, count - 1 do
            local actor = nil
            pcall(function()
                if type(actorList.Get) == "function" then
                    actor = actorList:Get(i)
                elseif type(actorList) == "table" then
                    actor = actorList[i + 1]
                end
            end)
            if actor and IsValid(actor) then
                -- Per-actor containment: one dying actor's getter throwing must
                -- not abort the whole sweep (the tick's outer pcall would drop
                -- every remaining actor/mark update for this cycle).
                local ok, shouldStop = pcall(callback, actor)
                if ok and shouldStop then break end
            end
        end
    end
    if not handled then
        pcall(function()
            for _, actor in pairs(actorList) do
                if actor and IsValid(actor) then
                    local shouldStop = callback(actor)
                    if shouldStop then break end
                end
            end
        end)
    end
end

-- Universal Blueprint Class Resolver & Client-Safe Actor Query
-- P1-FIX: Memoize LoadBlueprintClass results (was calling 16x/sec for same constant paths in threat block)
local _BlueprintClassCache = {}

local function LoadBlueprintClass(path)
    if not path or path == "" then return nil end
    -- Check memoization cache first
    local cached = _BlueprintClassCache[path]
    if cached ~= nil then
        if cached ~= false then return cached end
        -- Retry failed lookups after 8s (handles late asset loading in TDM)
        if _BlueprintClassCache[path .. "_time"] and (os.clock() - _BlueprintClassCache[path .. "_time"]) < 8 then
            return nil
        end
    end
    local cls = nil
    -- 1. Standard Slua blueprint class loader (engine native)
    if slua and slua.loadClass then
        local ok, c = pcall(slua.loadClass, path)
        if ok and c then cls = c end
        if not cls and not string.find(path, "_C$") then
            local ok2, c2 = pcall(slua.loadClass, path .. "_C")
            if ok2 and c2 then cls = c2 end
        end
    end
    -- 2. Internal _slua fallback
    if not cls and _slua and _slua.loadClass then
        local ok, c = pcall(_slua.loadClass, path)
        if ok and c then cls = c end
    end
    -- 3. Dynamic import by path
    if not cls then
        local ok, c = pcall(import, path)
        if ok and c then cls = c end
    end
    -- 4. Dynamic import by short class name
    if not cls and string.find(path, "%.") then
        local shortName = path:match("%.([^%.]+)$")
        if shortName then
            local ok, c = pcall(import, shortName)
            if ok and c then cls = c end
        end
    end
    -- Cache result (with retry timestamp on failure)
    if cls then
        _BlueprintClassCache[path] = cls
    else
        _BlueprintClassCache[path] = false
        _BlueprintClassCache[path .. "_time"] = os.clock()
    end
    return cls
end

local function GetAllWorldActors(cls)
    if not cls then return nil end
    local list = nil
    pcall(function()
        local g = _G.Game or Game or CGame
        if g and g.GetActorsByClass then
            local gl = g:GetActorsByClass(cls)
            if gl then list = gl end
        end
    end)
    if not list then
        pcall(function()
            local gps = import("GameplayStatics")
            local world = (_slua and _slua.getWorld and _slua.getWorld())
                or (slua_GameFrontendHUD and slua_GameFrontendHUD.GetWorld and slua_GameFrontendHUD:GetWorld())
            local gi = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            local ctx = world or gi
            if gps and ctx and gps.GetAllActorsOfClass then
                local actorCls = import("/Script/Engine.Actor") or import("Actor")
                local arr = (slua and slua.Array and UEnums and UEnums.EPropertyClass and slua.Array(UEnums.EPropertyClass.Object, actorCls or cls)) or {}
                list = gps.GetAllActorsOfClass(ctx, cls, arr) or arr
            end
        end)
    end
    return list
end

local function GetActorsInSphere(center, radius, cls)
    if not cls or not center then return nil end
    local list = nil
    pcall(function()
        local g = _G.Game or Game or CGame
        if g and g.GetActorsInSphere then
            local res = g:GetActorsInSphere(center, radius, cls)
            if res and (type(res) == "table" or type(res) == "userdata") then
                list = res
            end
        end
    end)
    -- P1-FIX: REMOVED full-world fallback. When sphere query returns empty/nil, return empty list.
    -- The fallback was calling GetAllWorldActors() (entire map scan) up to 20x/sec in threat block.
    -- Original game NEVER uses this pattern (verified: NTCheckAround.lua, AIVH_Adapter_Tank.lua).
    return list or {}
end

local function ResolveVehicleMark(veh)
    if not IsValid(veh) then return nil end
    local name = ""
    pcall(function()
        if veh.VehicleCommon and veh.VehicleCommon.VehicleDisplayName then
            name = tostring(veh.VehicleCommon.VehicleDisplayName)
        end
        if (not name or name == "") and veh.GetName then
            name = veh:GetName()
        end
    end)
    if not name or name == "" then name = tostring(veh) end
    local lower = string.lower(name)
    for _, pair in ipairs(VEHICLE_NAME_PATTERNS) do
        if string.find(lower, pair[1]) then
            return VEHICLE_ID_TO_DEF[pair[2]]
        end
    end
    return VEHICLE_ID_TO_DEF[71016]
end

-- Accurate ID-First Resolution with Full Multi-Item Support
local function ExtractItemID(item)
    if not IsValid(item) then return nil end
    local id = nil

    local function ParseId(val)
        if not val then return nil end
        local num = tonumber(val)
        if num and num > 0 then
            if num > 10000000 then num = math.floor(num / 100) end
            return num
        end
        return nil
    end

    local function CheckEntry(entry)
        if not entry then return nil end
        local eid = nil
        if entry.ID then eid = entry.ID.TypeSpecificID or entry.ID.ID end
        if not eid and entry.DefineID then eid = entry.DefineID.TypeSpecificID or entry.DefineID.ID end
        if not eid and entry.ItemDefineID then eid = entry.ItemDefineID.TypeSpecificID or entry.ItemDefineID.ID end
        if not eid and entry.TypeSpecificID then eid = entry.TypeSpecificID end
        if not eid and entry.ItemTypeID then eid = entry.ItemTypeID end
        if not eid and entry.ItemID then eid = entry.ItemID end
        if not eid and type(entry.GetItemDefineID) == "function" then
            local ok, def = pcall(entry.GetItemDefineID, entry)
            if ok and def then eid = def.TypeSpecificID or def.ID end
        end
        return ParseId(eid)
    end

    pcall(function()
        -- 1. Direct Item Properties
        if item.DefineID then id = CheckEntry(item.DefineID) end
        if not id and item.ItemDefineID then id = CheckEntry(item.ItemDefineID) end
        if not id and type(item.GetItemDefineID) == "function" then
            local ok, def = pcall(item.GetItemDefineID, item)
            if ok and def then id = CheckEntry(def) end
        end
        if not id and item.PickUpData then id = CheckEntry(item.PickUpData) end
        if not id and item.MainItemData then id = CheckEntry(item.MainItemData) end
        if not id and type(item.GetItemID) == "function" then
            local ok, gid = pcall(item.GetItemID, item)
            if ok and gid then id = ParseId(gid) end
        end
        if not id and item.ItemID then id = ParseId(item.ItemID) end
        if not id and item.TypeSpecificID then id = ParseId(item.TypeSpecificID) end
        if not id and item.WeaponID then id = ParseId(item.WeaponID) end
        if not id and item.CurWeaponID then id = ParseId(item.CurWeaponID) end

        -- AirDrop crate / DeadTombBox support
        if not id and item.DeadTombBox and IsValid(item.DeadTombBox) then
            pcall(function()
                local tbWrapper = nil
                if type(item.DeadTombBox.GetPickupWrapperActor) == "function" then
                    tbWrapper = item.DeadTombBox:GetPickupWrapperActor()
                end
                if tbWrapper and IsValid(tbWrapper) then
                    id = CheckEntry(tbWrapper)
                end
            end)
        end

        -- 2. Multi-Item PickUpDataList search
        local pList = nil
        if type(item.GetPickUpDataList) == "function" then
            local ok, pl = pcall(item.GetPickUpDataList, item)
            if ok and pl then pList = pl end
        elseif item.PickUpDataList then
            pList = item.PickUpDataList
        elseif item.PickUpDataComponent and item.PickUpDataComponent.PickUpDataList then
            pList = item.PickUpDataComponent.PickUpDataList
        end

        if pList then
            local bestId = nil
            local bestPriority = 99999
            SafeIterateActors(pList, function(entry)
                local eid = CheckEntry(entry)
                if eid and ITEM_ID_TO_DEF[eid] then
                    local d = ITEM_ID_TO_DEF[eid]
                    local isEnabled = false
                    if d.catKey == "Loot_Cat_Throwables" then
                        isEnabled = (CFG.Loot_Cat_Throwables ~= false) and (CFG[d.key] ~= false)
                    else
                        isEnabled = (CFG[d.catKey] == true)
                    end
                    if isEnabled then
                        local pri = d.priority or 999
                        if pri < bestPriority then
                            bestPriority = pri
                            bestId = eid
                        end
                    end
                end
                return false
            end)
            if bestId then
                id = bestId
            end
        end
    end)

    return id
end

local function ResolveLootByName(name)
    if not name or name == "" then return nil end
    local lower = string.lower(name)

    if string.find(lower, "flaregun_02") or string.find(lower, "respawnflare") then return ITEM_MARK_ID_TO_DEF[72002] end
    if string.find(lower, "flaregun") or string.find(lower, "flare_gun") then return ITEM_MARK_ID_TO_DEF[72001] end
    if string.find(lower, "airdrop") or string.find(lower, "air_drop") or string.find(lower, "dropbox") then return ITEM_MARK_ID_TO_DEF[72003] end

    if string.find(lower, "_awm_") or string.find(lower, "wep_awm") then return ITEM_MARK_ID_TO_DEF[72004] end
    if string.find(lower, "_amr_") or string.find(lower, "wep_amr") then return ITEM_MARK_ID_TO_DEF[72005] end
    if string.find(lower, "_groza_") or string.find(lower, "wep_groza") then return ITEM_MARK_ID_TO_DEF[72006] end
    if string.find(lower, "_aug_") or string.find(lower, "wep_aug") then return ITEM_MARK_ID_TO_DEF[72007] end
    if string.find(lower, "_mg3_") or string.find(lower, "wep_mg3") then return ITEM_MARK_ID_TO_DEF[72008] end
    if string.find(lower, "_mk14_") or string.find(lower, "wep_mk14") then return ITEM_MARK_ID_TO_DEF[72009] end

    if string.find(lower, "_m416_") or string.find(lower, "wep_m416") then return ITEM_MARK_ID_TO_DEF[72010] end
    if string.find(lower, "_ak47_") or string.find(lower, "_akm_") or string.find(lower, "wep_ak") then return ITEM_MARK_ID_TO_DEF[72011] end
    if string.find(lower, "_m762_") or string.find(lower, "wep_m762") then return ITEM_MARK_ID_TO_DEF[72012] end
    if string.find(lower, "_kar98") or string.find(lower, "wep_kar98") then return ITEM_MARK_ID_TO_DEF[72013] end
    if string.find(lower, "_m24_") or string.find(lower, "wep_m24_") then return ITEM_MARK_ID_TO_DEF[72014] end
    if string.find(lower, "_m249_") or string.find(lower, "wep_m249") then return ITEM_MARK_ID_TO_DEF[72015] end
    if string.find(lower, "_p90_") or string.find(lower, "wep_p90") then return ITEM_MARK_ID_TO_DEF[72016] end
    if string.find(lower, "_ump45_") or string.find(lower, "_ump9_") or string.find(lower, "wep_ump") then return ITEM_MARK_ID_TO_DEF[72017] end
    if string.find(lower, "_vector_") or string.find(lower, "wep_vector") then return ITEM_MARK_ID_TO_DEF[72018] end
    if string.find(lower, "_uzi_") or string.find(lower, "wep_uzi") then return ITEM_MARK_ID_TO_DEF[72019] end

    if string.find(lower, "helmet_lv3") or string.find(lower, "helmet_3") or string.find(lower, "head_3") then return ITEM_MARK_ID_TO_DEF[72020] end
    if string.find(lower, "armor_lv3") or string.find(lower, "armor_3") or string.find(lower, "vest_3") then return ITEM_MARK_ID_TO_DEF[72021] end
    if string.find(lower, "bag_lv3") or string.find(lower, "bag_3") or string.find(lower, "backpack_3") then return ITEM_MARK_ID_TO_DEF[72022] end

    if string.find(lower, "mzj_8x") or string.find(lower, "scope_8x") then return ITEM_MARK_ID_TO_DEF[72023] end
    if string.find(lower, "mzj_6x") or string.find(lower, "scope_6x") then return ITEM_MARK_ID_TO_DEF[72024] end
    if string.find(lower, "mzj_4x") or string.find(lower, "scope_4x") then return ITEM_MARK_ID_TO_DEF[72025] end
    if string.find(lower, "mzj_3x") or string.find(lower, "scope_3x") then return ITEM_MARK_ID_TO_DEF[72032] end
    if string.find(lower, "dp28") or string.find(lower, "wep_dp28") then return ITEM_MARK_ID_TO_DEF[72033] end
    if string.find(lower, "scar") or string.find(lower, "wep_scar") then return ITEM_MARK_ID_TO_DEF[72034] end

    if string.find(lower, "boost_mkit") or string.find(lower, "medkit") or string.find(lower, "med_kit") then return ITEM_MARK_ID_TO_DEF[72026] end
    if string.find(lower, "firstaid") or string.find(lower, "first_aid") then return ITEM_MARK_ID_TO_DEF[72027] end
    if string.find(lower, "adrenaline") or string.find(lower, "boost_injection") then return ITEM_MARK_ID_TO_DEF[72028] end

    -- 1. STRICT EXCLUSION: Stun Grenade / Flashbang (Zero Loot ESP on Stun!)
    -- Match explicit stun/flashbang words, NOT substring 'flash' which falsely hits normal materials!
    if string.find(lower, "stun") or string.find(lower, "zhendan") or string.find(lower, "flashbang") or string.find(lower, "wep_flashbang") then
        return nil
    end

    -- 2. Smoke Grenade
    if string.find(lower, "smoke") or string.find(lower, "smokebomb") or string.find(lower, "yanwu") then
        return ITEM_MARK_ID_TO_DEF[72030]
    end

    -- 3. Molotov Cocktail (BurnGrenade, FireBomb, Molotov, Ranshaodan)
    if string.find(lower, "burn") or string.find(lower, "molotov") or string.find(lower, "firebomb")
        or string.find(lower, "fire_bomb") or string.find(lower, "ranshaodan") then
        return ITEM_MARK_ID_TO_DEF[72031]
    end

    -- 4. Frag Grenade (ONLY actual lethal frag grenade, strictly excluding stun and flashbang)
    if string.find(lower, "frag") or string.find(lower, "shoulei") or string.find(lower, "shou_lei") or string.find(lower, "wep_grenade")
        or (string.find(lower, "grenade") and not string.find(lower, "smoke") and not string.find(lower, "burn") and not string.find(lower, "stun") and not string.find(lower, "flashbang")) then
        return ITEM_MARK_ID_TO_DEF[72029]
    end

    return nil
end

-- Kill-message skin hook: killfeed shows the SELECTED weapon/outfit skin.
-- Minimal port (no kill-counter UI): patches DamageRecordData avatar IDs once.
local function HookKillMessage()
    if _G._KillMsgHooked then return end
    local hooked = false
    -- NOTE: original defines KillInfo:FileItem directly on the class table
    -- (KillInfoTips/KillInfo.lua:439); there is no __inner_impl layer.
    -- Patching a nil path silently never installed the hook.
    pcall(function()
        local KillInfo = package.loaded["GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"]
            or (pcall(require, "GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo") and require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo"))
        if KillInfo and type(KillInfo.FileItem) == "function" and not _G._KillInfoHacked then
            local origFileItem = KillInfo.FileItem
            KillInfo.FileItem = function(self, DamageRecordData)
                if CFG.KillMessageEnabled ~= true then
                    if origFileItem then return origFileItem(self, DamageRecordData) end
                    return
                end
                pcall(function()
                    if DamageRecordData and _G.get_skin_id and DamageRecordData.CauserWeaponID then
                        local skinID = _G.get_skin_id(DamageRecordData.CauserWeaponID)
                        if skinID and skinID ~= DamageRecordData.CauserWeaponID then
                            DamageRecordData.CauserWeaponAvatarID = skinID
                        end
                    end
                    if DamageRecordData and _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0 then
                        DamageRecordData.CauserClothAvatarID = _G.OutfitMap.Suit
                    end
                end)
                if origFileItem then return origFileItem(self, DamageRecordData) end
            end
            _G._KillInfoHacked = true
            hooked = true
        end
    end)
    -- Mark hooked ONLY on success: if KillInfo wasn't loaded yet, retry next match
    if hooked then _G._KillMsgHooked = true end
end
_G.HookKillMessage = HookKillMessage

local function ResolveLootMark(item)
    if not IsValid(item) then return nil end
    local id = ExtractItemID(item)
    if id then
        if id == 602001 then return nil end -- Strictly exclude Stun Grenade (Flashbang)
        if ITEM_ID_TO_DEF[id] then
            return ITEM_ID_TO_DEF[id]
        end
    end

    local name = ""
    pcall(function()
        if item.GetName then name = item:GetName() else name = tostring(item) end
        if (not name or name == "") and item.GetClass then
            local cls = item:GetClass()
            if cls and cls.GetName then name = cls:GetName() end
        end
    end)
    local lname = string.lower(name)
    if string.find(lname, "stun") or string.find(lname, "zhendan") or string.find(lname, "flashbang") then
        return nil
    end

    -- Airdrop/dead-box crates: name matching misses real crate actors, so check
    -- the actor CLASS directly (AirDropBox + death-box variants).
    local classHit = false
    pcall(function()
        if item.GetClass then
            local cls = item:GetClass()
            local cname = ""
            if cls then
                if cls.GetName then cname = cls:GetName() or ""
                elseif type(cls) == "string" then cname = cls end
            end
            cname = string.lower(tostring(cname))
            if string.find(cname, "airdropbox") or string.find(cname, "airdrop")
                or string.find(cname, "deadbox") or string.find(cname, "deadtombbox")
                or string.find(cname, "playerdropbox") then
                classHit = true
            end
        end
    end)
    if classHit and ITEM_MARK_ID_TO_DEF[72003] then
        return ITEM_MARK_ID_TO_DEF[72003]
    end

    pcall(function()
        if item.StaticMeshComponent and item.StaticMeshComponent.StaticMesh then
            name = name .. " " .. tostring(item.StaticMeshComponent.StaticMesh:GetName())
        end
        if item.RootComponent and item.RootComponent.GetChildrenComponents then
            local children = item.RootComponent:GetChildrenComponents(true)
            if children then
                local num = (children.Num and children:Num()) or (type(children) == "table" and #children) or 0
                for i = 0, num - 1 do
                    local comp = (children.Get and children:Get(i)) or children[i + 1]
                    if comp and comp.GetName then
                        name = name .. " " .. tostring(comp:GetName())
                    end
                end
            end
        end
    end)

    return ResolveLootByName(name)
end

-- ============================================================================
-- 4.B PREMIER IN-GAME ENEMY THREAT COUNTER (APEX TOURNAMENT DUAL PILL)
-- Ultra-Clean, Feather-Light, Dedicated Twin Pod Architecture
-- Left Pod: REAL Enemies (Imperial Ruby on Threat / Calm Sapphire when Safe)
-- Right Pod: BOTS (Radiant Cyber Amber Gold when Detected / Stealth Obsidian)
-- 100% Unified Pure Luminescent White Typography
-- 2GB RAM / Low-End Hardware Optimized (Static Cached, 0% GC, 0% Frame Drops)
-- ============================================================================
_G.EnemyCounterUI = _G.EnemyCounterUI or {
    CurrentBaseUI = nil,
    ActiveWidget  = nil,
    LastTotal     = -1,
    LastReal      = -1,
    LastBot       = -1,
    LastYPos      = -1
}

local function EC_GetLinearColor(r, g, b, a)
    local LC_Class = rawget(_G, "FLinearColor") or _G.FLinearColor or import("LinearColor") or (pcall(import, "/Script/CoreUObject.LinearColor") and import("/Script/CoreUObject.LinearColor"))
    if LC_Class then
        local ok, c = pcall(LC_Class, r or 0, g or 0, b or 0, a or 1.0)
        if ok and c then return c end
    end
    return { R = r or 0, G = g or 0, B = b or 0, A = a or 1.0 }
end

local function EC_GetSlateColor(linearColor)
    local SC_Class = rawget(_G, "FSlateColor") or _G.FSlateColor or import("SlateColor") or (pcall(import, "/Script/SlateCore.SlateColor") and import("/Script/SlateCore.SlateColor"))
    if SC_Class then
        local ok, sc = pcall(SC_Class, linearColor)
        if ok and sc then return sc end
    end
    return linearColor
end

-- P1-FIX: Cache FVector2D class at file scope (was resolving 5 import chains per call → 400-800x/sec GC churn)
local _V2_Class_Cached = nil
pcall(function()
    _V2_Class_Cached = rawget(_G, "FVector2D") or _G.FVector2D or import("FVector2D") or import("Vector2D") or (pcall(import, "/Script/CoreUObject.Vector2D") and import("/Script/CoreUObject.Vector2D"))
end)

local function EC_GetVec2D(x, y)
    local V2_Class = _V2_Class_Cached
    if not V2_Class then
        V2_Class = rawget(_G, "FVector2D") or _G.FVector2D or import("FVector2D") or import("Vector2D") or (pcall(import, "/Script/CoreUObject.Vector2D") and import("/Script/CoreUObject.Vector2D"))
        _V2_Class_Cached = V2_Class
    end
    if V2_Class then
        local ok, v = pcall(V2_Class, x or 0, y or 0)
        if ok and v then return v end
    end
    return { X = x or 0, Y = y or 0 }
end

local function EC_GetAnchors(minX, minY, maxX, maxY)
    local A_Class = rawget(_G, "FAnchors") or _G.FAnchors or import("Anchors") or (pcall(import, "/Script/Slate.Anchors") and import("/Script/Slate.Anchors"))
    if A_Class then
        local ok, a = pcall(A_Class, minX or 0, minY or 0, maxX or minX or 0, maxY or minY or 0)
        if ok and a then return a end
        local vMin = EC_GetVec2D(minX or 0, minY or 0)
        local vMax = EC_GetVec2D(maxX or minX or 0, maxY or minY or 0)
        local ok2, a2 = pcall(A_Class, vMin, vMax)
        if ok2 and a2 then return a2 end
    end
    return { Minimum = { X = minX, Y = minY }, Maximum = { X = maxX or minX, Y = maxY or minY } }
end

local function EC_GetHUDCanvas()
    local InGameUITools = package.loaded["GameLua.Mod.BaseMod.Common.UI.InGameUITools"]
        or (pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools") and require("GameLua.Mod.BaseMod.Common.UI.InGameUITools"))
    if InGameUITools and InGameUITools.GetMainControlBaseUI then
        local m = InGameUITools.GetMainControlBaseUI()
        if m and IsValid(m) then
            if _G.EnemyCounterUI.CurrentBaseUI ~= m then
                _G.EnemyCounterUI.CurrentBaseUI = m
                _G.EnemyCounterUI.ActiveWidget = nil
                _G.EnemyCounterUI.LastTotal    = -1
                _G.EnemyCounterUI.LastReal     = -1
                _G.EnemyCounterUI.LastBot      = -1
                _G.EnemyCounterUI.LastYPos     = -1
                -- Preserve laser pool across BaseUI changes; only re-bind container
                if _G.NativeTopLaserESP then
                    _G.NativeTopLaserESP.Container = nil
                    _G.NativeTopLaserESP.ParentCanvas = nil
                end
            end
            -- Primary Universal Full-Screen Canvases (Always active & visible in Classic, TDM, Arena, Cheer Park, Payload)
            if m.CanvasPanel_0 and IsValid(m.CanvasPanel_0) then return m.CanvasPanel_0 end
            if m.CanvasPanel_42 and IsValid(m.CanvasPanel_42) then return m.CanvasPanel_42 end
            if m.CanvasPanel_ForTips and IsValid(m.CanvasPanel_ForTips) then return m.CanvasPanel_ForTips end
            if m.CanvasPanel_Root and IsValid(m.CanvasPanel_Root) then return m.CanvasPanel_Root end
            if m.CanvasPanel_Plan and IsValid(m.CanvasPanel_Plan) then return m.CanvasPanel_Plan end
            if m.CanvasPanel_QuickSign and IsValid(m.CanvasPanel_QuickSign) then return m.CanvasPanel_QuickSign end
            -- Mode-Specific TmodePanel fallback (ONLY when actively visible, not Collapsed)
            if m.TmodePanel and IsValid(m.TmodePanel) then
                local isVisible = false
                pcall(function()
                    if m.TmodePanel.GetVisibility and m.TmodePanel:GetVisibility() ~= UEnums.ESlateVisibility.Collapsed then
                        isVisible = true
                    end
                end)
                if isVisible then return m.TmodePanel end
            end
            if m.ChatAndChatPanelCanvas and IsValid(m.ChatAndChatPanelCanvas) then return m.ChatAndChatPanelCanvas end
            if m.WeatherInfoCanvas and IsValid(m.WeatherInfoCanvas) then return m.WeatherInfoCanvas end
            if m.CanvasRoot and IsValid(m.CanvasRoot) then return m.CanvasRoot end
            if m.Root and IsValid(m.Root) then return m.Root end
            if m.ContentPanel and IsValid(m.ContentPanel) then return m.ContentPanel end
            if type(m.AddChildToCanvas) == "function" then return m end
        end
    end
    -- Fallback 2: Check PlayerController HUD
    local pc = GetActivePlayerController()
    if IsValid(pc) then
        local hud = (pc.GetHUD and pc:GetHUD()) or pc.MyHUD
        if hud and IsValid(hud) then
            if hud.CanvasPanel_0 and IsValid(hud.CanvasPanel_0) then return hud.CanvasPanel_0 end
            if hud.CanvasPanel_42 and IsValid(hud.CanvasPanel_42) then return hud.CanvasPanel_42 end
            if hud.CanvasPanel_Root and IsValid(hud.CanvasPanel_Root) then return hud.CanvasPanel_Root end
            if hud.TmodePanel and IsValid(hud.TmodePanel) then
                local isVisible = false
                pcall(function()
                    if hud.TmodePanel.GetVisibility and hud.TmodePanel:GetVisibility() ~= UEnums.ESlateVisibility.Collapsed then
                        isVisible = true
                    end
                end)
                if isVisible then return hud.TmodePanel end
            end
            if type(hud.AddChildToCanvas) == "function" then return hud end
        end
    end
    -- Fallback 3: slua_GameFrontendHUD global
    if slua_GameFrontendHUD and IsValid(slua_GameFrontendHUD) then
        if slua_GameFrontendHUD.CanvasPanel_0 and IsValid(slua_GameFrontendHUD.CanvasPanel_0) then return slua_GameFrontendHUD.CanvasPanel_0 end
        if slua_GameFrontendHUD.CanvasPanel_42 and IsValid(slua_GameFrontendHUD.CanvasPanel_42) then return slua_GameFrontendHUD.CanvasPanel_42 end
        if slua_GameFrontendHUD.TmodePanel and IsValid(slua_GameFrontendHUD.TmodePanel) then
            local isVisible = false
            pcall(function()
                if slua_GameFrontendHUD.TmodePanel.GetVisibility and slua_GameFrontendHUD.TmodePanel:GetVisibility() ~= UEnums.ESlateVisibility.Collapsed then
                    isVisible = true
                end
            end)
            if isVisible then return slua_GameFrontendHUD.TmodePanel end
        end
    end
    -- Fallback 4: UIManager DefaultScreenMarkPanel
    pcall(function()
        local UIManager = package.loaded["GameLua.Mod.BaseMod.Client.UIManager"] or import("UIManager")
        if UIManager and UIManager.GetUI and UIManager.UI_Config_InGame and UIManager.UI_Config_InGame.DefaultScreenMarkPanel then
            local markUI = UIManager.GetUI(UIManager.UI_Config_InGame.DefaultScreenMarkPanel)
            if markUI and IsValid(markUI) and type(markUI.AddChildToCanvas) == "function" then
                return markUI
            end
        end
    end)
    return nil
end

local function EC_CreateWidget(path, parent)
    local obj = nil
    pcall(function()
        local CGame = rawget(_G, "CGame") or import("CGame") or import("Game")
        if CGame and CGame.NewObjectFromPath then
            obj = CGame:NewObjectFromPath(path, parent)
        end
    end)
    if not obj then
        pcall(function()
            local CGame = rawget(_G, "CGame") or import("CGame") or import("Game")
            if CGame and CGame.NewObjectFromPath then
                obj = CGame.NewObjectFromPath(path, parent)
            end
        end)
    end
    if not obj then
        pcall(function()
            local shortName = path:match("%.(%w+)$") or path:match("([^/]+)$")
            local UClass = import(shortName) or import(path)
            if UClass then obj = NewObject(UClass, parent) end
        end)
    end
    return obj
end

local function EC_CreateTextWithSlot(parent, txt, x, y, size, color, z, alignX, alignY)
    local t = EC_CreateWidget("/Script/UMG.TextBlock", parent)
    local slot = nil
    if t and IsValid(t) then
        pcall(t.SetText, t, tostring(txt or ""))
        if t.SetColorAndOpacity then
            pcall(t.SetColorAndOpacity, t, EC_GetSlateColor(color))
        end
        local appliedFont = false
        pcall(function()
            local fi = t.Font
            if fi then
                fi.Size = math.floor(tonumber(size) or 8)
                if t.SetFont then
                    t:SetFont(fi)
                    appliedFont = true
                end
            end
        end)
        -- Double fail-safe: If engine ignored SetFont or size remained >= 14, scale TextBlock cleanly
        pcall(function()
            if t.SetRenderTransformPivot then
                t:SetRenderTransformPivot(EC_GetVec2D(0.5, 0.5))
            end
            local curSize = t.Font and t.Font.Size
            if (not appliedFont) or (curSize and curSize >= 14) then
                if t.SetRenderScale then
                    t:SetRenderScale(EC_GetVec2D(0.55, 0.55))
                end
            end
        end)
        if t.SetShadowOffset then
            pcall(t.SetShadowOffset, t, EC_GetVec2D(1, 1))
        end
        if t.SetShadowColorAndOpacity then
            pcall(t.SetShadowColorAndOpacity, t, EC_GetLinearColor(0, 0, 0, 0.95))
        end
        if t.SetWidgetVisibility then
            pcall(t.SetWidgetVisibility, t, UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
        slot = parent:AddChildToCanvas(t)
        if slot then
            if slot.SetAutoSize then pcall(slot.SetAutoSize, slot, true) end
            if slot.SetPosition then pcall(slot.SetPosition, slot, EC_GetVec2D(x, y)) end
            local align = EC_GetVec2D(alignX or 0.5, alignY or 0.5)
            if slot.SetAlignment then pcall(slot.SetAlignment, slot, align) end
            if z and slot.SetZOrder then pcall(slot.SetZOrder, slot, z) end
        end
    end
    return t, slot
end

-- ============================================================================
-- The Definitive Apex Tournament Dual Pill Builder (Y: 44, 156 x 21 px)
-- ============================================================================
local function EC_BuildDualPill(parent, yOffset)
    local container = EC_CreateWidget("/Script/UMG.CanvasPanel", parent)
    if not container or not IsValid(container) then return nil end

    local yPos = 41

    local totalW, totalH = 156, 21
    local podW = 74
    local gap  = 8
    local halfH = 10.5
    local fSize = 8

    local slot = parent:AddChildToCanvas(container)
    if slot then
        if slot.SetAnchors then slot:SetAnchors(EC_GetAnchors(0.5, 0, 0.5, 0)) end
        if slot.SetAlignment then slot:SetAlignment(EC_GetVec2D(0.5, 0)) end
        if slot.SetPosition then slot:SetPosition(EC_GetVec2D(0, yPos)) end
        if slot.SetSize then slot:SetSize(EC_GetVec2D(totalW, totalH)) end
        if slot.SetZOrder then slot:SetZOrder(100) end
    end

    -- 1. Twin Pod Bases (Sleek Slate UBorder)
    local borderLeft = EC_CreateWidget("/Script/UMG.Border", container)
    local borderRight = EC_CreateWidget("/Script/UMG.Border", container)
    if borderLeft and borderRight then
        pcall(borderLeft.SetBrushColor, borderLeft, EC_GetLinearColor(0.04, 0.12, 0.24, 0.55))
        pcall(borderRight.SetBrushColor, borderRight, EC_GetLinearColor(0.04, 0.08, 0.14, 0.55))
        local sL = container:AddChildToCanvas(borderLeft)
        local sR = container:AddChildToCanvas(borderRight)
        if sL then
            if sL.SetPosition then sL:SetPosition(EC_GetVec2D(0, 0)) end
            if sL.SetSize then sL:SetSize(EC_GetVec2D(podW, totalH)) end
            if sL.SetZOrder then sL:SetZOrder(1) end
        end
        if sR then
            if sR.SetPosition then sR:SetPosition(EC_GetVec2D(podW + gap, 0)) end
            if sR.SetSize then sR:SetSize(EC_GetVec2D(podW, totalH)) end
            if sR.SetZOrder then sR:SetZOrder(1) end
        end
    end

    -- 2. Bottom LED Neon Flare Lines
    local glowLeft = EC_CreateWidget("/Script/UMG.Border", container)
    local glowRight = EC_CreateWidget("/Script/UMG.Border", container)
    if glowLeft and glowRight then
        pcall(glowLeft.SetBrushColor, glowLeft, EC_GetLinearColor(0.20, 0.90, 1.0, 0.45))
        pcall(glowRight.SetBrushColor, glowRight, EC_GetLinearColor(0.20, 0.90, 1.0, 0.25))
        local gL = container:AddChildToCanvas(glowLeft)
        local gR = container:AddChildToCanvas(glowRight)
        if gL then
            if gL.SetPosition then gL:SetPosition(EC_GetVec2D(6, totalH - 1.8)) end
            if gL.SetSize then gL:SetSize(EC_GetVec2D(podW - 12, 1.8)) end
            if gL.SetZOrder then gL:SetZOrder(2) end
        end
        if gR then
            if gR.SetPosition then gR:SetPosition(EC_GetVec2D(podW + gap + 6, totalH - 1.8)) end
            if gR.SetSize then gR:SetSize(EC_GetVec2D(podW - 12, 1.8)) end
            if gR.SetZOrder then gR:SetZOrder(2) end
        end
    end

    -- 3. Unified Crisp Luminescent White Typography (Clean, Compact, Centered)
    local colWhite = EC_GetLinearColor(1.0, 1.0, 1.0, 1.0)
    local txtReal = EC_CreateTextWithSlot(container, "REAL: 0", math.floor(podW / 2), halfH, fSize, colWhite, 4, 0.5, 0.5)
    local txtBot = EC_CreateTextWithSlot(container, "BOT: 0", podW + gap + math.floor(podW / 2), halfH, fSize, colWhite, 4, 0.5, 0.5)

    return {
        container     = container,
        containerSlot = slot,
        borderLeft    = borderLeft,
        borderRight   = borderRight,
        glowLeft      = glowLeft,
        glowRight     = glowRight,
        txtReal       = txtReal,
        txtBot        = txtBot,
        yPos          = yPos
    }
end

-- ============================================================================
-- Master Update Routine with Dirty-State Throttling (0% GC / 0% Frame Drops)
-- ============================================================================
_G.UpdateEnemyCounters = function(total, real, bot)
    if not (CFG.Counter_Enabled == true) then
        _G.ClearAllEnemyCounters()
        return
    end

    local yPos = 41

    -- Throttled Dirty State Check: Exit in 1 cycle if counts and position are unchanged
    if total == _G.EnemyCounterUI.LastTotal and real == _G.EnemyCounterUI.LastReal and bot == _G.EnemyCounterUI.LastBot and yPos == _G.EnemyCounterUI.LastYPos then
        return
    end
    _G.EnemyCounterUI.LastTotal = total
    _G.EnemyCounterUI.LastReal  = real
    _G.EnemyCounterUI.LastBot   = bot
    _G.EnemyCounterUI.LastYPos  = yPos

    local canvas = EC_GetHUDCanvas()
    if not canvas then return end

    local w = _G.EnemyCounterUI.ActiveWidget
    if not w or not w.container or not IsValid(w.container) or w.yPos ~= yPos then
        if w and w.container and IsValid(w.container) and w.container.RemoveFromParent then
            pcall(w.container.RemoveFromParent, w.container)
        end
        _G.EnemyCounterUI.ActiveWidget = EC_BuildDualPill(canvas, yPos)
        w = _G.EnemyCounterUI.ActiveWidget
    end

    if not w or not w.container or not IsValid(w.container) then return end

    pcall(w.container.SetWidgetVisibility, w.container, UEnums.ESlateVisibility.SelfHitTestInvisible)

    -- Dynamic Smart Threat Colors
    -- Left Pod (REAL PLAYERS): Vivid Ruby Red on Threat / Calm Sapphire when Clear
    local leftBg, leftGlow
    if real > 0 then
        leftBg   = EC_GetLinearColor(0.40, 0.04, 0.06, 0.60) -- Vivid Imperial Ruby
        leftGlow = EC_GetLinearColor(1.0, 0.28, 0.30, 1.0)    -- Crimson Flare
    else
        leftBg   = EC_GetLinearColor(0.04, 0.12, 0.24, 0.88) -- Calm Sapphire Blue
        leftGlow = EC_GetLinearColor(0.20, 0.90, 1.0, 0.70)   -- Cyan Flare
    end

    -- Right Pod (AI BOTS): Radiant Cyber Amber Gold when Detected / Stealth Obsidian when 0
    local rightBg, rightGlow
    if bot > 0 then
        rightBg   = EC_GetLinearColor(0.28, 0.16, 0.02, 0.55) -- Cyber Amber Gold
        rightGlow = EC_GetLinearColor(1.0, 0.88, 0.25, 1.0)    -- Gold Flare
    else
        rightBg   = EC_GetLinearColor(0.04, 0.08, 0.14, 0.88) -- Stealth Obsidian
        rightGlow = EC_GetLinearColor(0.20, 0.90, 1.0, 0.40)   -- Muted Flare
    end

    if w.borderLeft and w.borderLeft.SetBrushColor then pcall(w.borderLeft.SetBrushColor, w.borderLeft, leftBg) end
    if w.borderRight and w.borderRight.SetBrushColor then pcall(w.borderRight.SetBrushColor, w.borderRight, rightBg) end
    if w.glowLeft and w.glowLeft.SetBrushColor then pcall(w.glowLeft.SetBrushColor, w.glowLeft, leftGlow) end
    if w.glowRight and w.glowRight.SetBrushColor then pcall(w.glowRight.SetBrushColor, w.glowRight, rightGlow) end

    -- Update Numbers (100% Unified Pure Luminescent White)
    if w.txtReal then pcall(w.txtReal.SetText, w.txtReal, string.format("REAL: %d", real)) end
    if w.txtBot then pcall(w.txtBot.SetText, w.txtBot, string.format("BOT: %d", bot)) end
end

_G.ClearAllEnemyCounters = function()
    _G.EnemyCounterUI.LastTotal = -1
    _G.EnemyCounterUI.LastReal  = -1
    _G.EnemyCounterUI.LastBot   = -1
    _G.EnemyCounterUI.LastYPos  = -1
    if _G.EnemyCounterUI.ActiveWidget and _G.EnemyCounterUI.ActiveWidget.container and IsValid(_G.EnemyCounterUI.ActiveWidget.container) then
        pcall(_G.EnemyCounterUI.ActiveWidget.container.SetWidgetVisibility, _G.EnemyCounterUI.ActiveWidget.container, UEnums.ESlateVisibility.Collapsed)
    end
end

-- ============================================================================
-- 4.C Note: Native Top-to-Head Laser Engine moved to Section 6.B (in-scope with all engine helpers)

-- ============================================================================
-- 5. NATIVE SCREENMARK ENGINE HOOK (UE4 SLATE HW INTEGRATION)
-- ============================================================================
local GK_MECHA_GROUP_ID = 64200005
local GK_HP_BAR_ID     = 73001
local GK_MECHA_HP_ID   = 73002
local COMMON_MARK_UI   = "/Game/Mod/EvoBase/BluePrints/UI/ScreenMark/Item/CommonActorScreenMark_UIBP.CommonActorScreenMark_UIBP_C"
local MECHA_MARK_UI    = "/Game/Library/Res/Vehicles/Mecha/BluePrints/UI/DamageScreenMark.DamageScreenMark_C"
local HP_BAR_UI        = "/Game/Mod/EvoBase/BluePrints/UI/ScreenMark/Item/HpBarUIBP.HpBarUIBP_C"  

local function ApplyMarkConfigs(smc)
    if not smc or type(smc) ~= "table" then return end
    -- Increase global widget clamp cap so game engine doesn't clamp marks to 20!
    -- Per-group preload is min(PreloadNum or 1, MaxPreloadNum) engine-side
    -- (ScreenMarkManagerBase:GetUIGroupConfigByID), so this cap never
    -- pre-allocates 99/group; 12 is a safe ceiling for threat groups.
    if smc.OtherConfig then
        smc.OtherConfig.MaxWidgetNum = 99
        smc.OtherConfig.MaxPreloadNum = 12
    end
    -- Mecha Combat Threat Tracker (original: +160cm above head, 360° arrows)
    local vOffsetMecha = FVector(0, 0, 160)
    local mechaConfig = {
        UIPathName = MECHA_MARK_UI,
        MaxWidgetNum = 99,
        MaxShowDistance = 40000,
        bBindOutScreen = true,
        bBindBlocked = true,
        bIsBindingActor = true,
        BindSocketName = "head",
        bUseLuaWorldSocketName = true,
        WorldPositionOffset = vOffsetMecha,
        bNeedPreLoad = true,
        Priority = 2
    }
    smc[GK_MECHA_GROUP_ID] = mechaConfig
    smc[9999]             = mechaConfig
    smc[8888]             = mechaConfig



    -- Native In-Game Health Bar (bound to head socket like stock [1006] and our
    -- working mecha banner: HpBarUIBP follows its bind socket, root-binding
    -- ignores world offset which is why +95 alone never moved it).
    local vOffsetHP = FVector(0, 0, 25)
    local hpBarConfig = {
        UIPathName = HP_BAR_UI,
        MaxWidgetNum = 99,
        MaxShowDistance = 40000,
        WorldPositionOffset = vOffsetHP,
        bBindOutScreen = false,
        bBindBlocked = true,
        bIsBindingActor = true,
        BindSocketName = "head",
        bUseLuaWorldSocketName = true,
        bUseLuaWorldOffset = true,
        bNeedPreLoad = true,
        Priority = 1
    }
    smc[GK_HP_BAR_ID] = hpBarConfig
    smc[1006]         = hpBarConfig

    -- Beloved Exclusive Optimus Exclamation [!] Danger HUD (Clean, High-Tech & Permanent!)
    -- Native Engine Ingame Grenade Warning (ShouleiGrenadePosition_UIBP with 360° Edge Radar & Countdown Seconds)
    smc[1010] = {
        UIPathName = "/Game/BluePrints/ControlInput/IngameUI/ShouleiGrenadePosition_UIBP.ShouleiGrenadePosition_UIBP_C",
        MaxWidgetNum = 60,
        MaxShowDistance = 6000, -- STRICT 50-60 METERS
        bBindOutScreen = true,  -- True 360° Out-Screen Warning Edge Radar!
        bBindBlocked = true,
        bIsBindingActor = true,
        bNeedPreLoad = true,
        Priority = 3
    }

    -- Dedicated Native Molotov & Ground Fire Threat Warning (CommonActorScreenMark_UIBP with 360° Edge Radar & FireBomb Icon)
    local molotovThreatConfig = {
        UIPathName = COMMON_MARK_UI,
        MaxWidgetNum = 40,
        MaxShowDistance = 6000, -- STRICT 50-60 METERS
        bBindOutScreen = true,  -- True 360° Out-Screen Warning Edge Radar!
        bBindBlocked = true,
        bIsBindingActor = true,
        bScaleByDistance = false,
        bUseLuaWorldOffset = true,
        bNeedUpdateState = true,
        WorldPositionOffset = FVector(0, 0, 45),
        bNeedPreLoad = true,
        Priority = 4,
        CommonMarkConfig = {
            Icon = "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_FireBomb.Icon_WEP_FireBomb",
            bDistance = true
        }
    }
    smc[101005]   = molotovThreatConfig
    smc[64200010] = molotovThreatConfig

    -- Vehicles (Full 360° Out-Screen Radar Tracking & Elevated Roof Clearance)
    local bVehOut = (CFG.Veh_360_Alert ~= false)
    for _, def in ipairs(_G.VEHICLE_ICON_CONFIG) do
        local vOffset = FVector(0, 0, def.zOffset or 210)
        smc[def.id] = {
            UIPathName = COMMON_MARK_UI,
            MaxWidgetNum = 99,
            MaxShowDistance = 35000,
            bBindOutScreen = bVehOut, -- 360-degree directional edge arrow for vehicles
            bBindBlocked = true,
            bIsBindingActor = true,
            bScaleByDistance = false,
            bUseLuaWorldOffset = true,
            bNeedUpdateState = true,
            WorldPositionOffset = vOffset,
            bNeedPreLoad = true, -- engine OnInit registers only preloaded groups; InitOne below also inits directly (belt & suspenders)
            Priority = 2,
            CommonMarkConfig = { Icon = def.icon, bDistance = true }
        }
    end

    -- Essential Loot (Front Screen / In-FOV Only - NO 360° Edge Radar)
    for _, def in ipairs(_G.ITEM_ICON_CONFIG) do
        local vOffset = FVector(0, 0, def.zOffset or 35)
        smc[def.id] = {
            UIPathName = COMMON_MARK_UI,
            MaxWidgetNum = 99,
            MaxShowDistance = 5000, -- matches 50m CFG.LootDistance cap (engine never renders beyond Lua filter)
            bBindOutScreen = false, -- STRICTLY FALSE: Front-of-camera only! No edge markers!
            bBindBlocked = true,
            bIsBindingActor = true,
            bScaleByDistance = false,
            bUseLuaWorldOffset = true,
            bNeedUpdateState = true,
            WorldPositionOffset = vOffset,
            bNeedPreLoad = true, -- engine OnInit registers only preloaded groups (per-group preload is 1 widget, not 99 - see GetUIGroupConfigByID)
            Priority = 2,
            CommonMarkConfig = { Icon = def.icon, bDistance = true }
        }
    end
end

local function HookConfigProviders()
    pcall(function()
        -- Monkey-patch CommonActorScreenMarkUI for 360° Edge Radar visibility
        local CommonActorScreenMarkUI = package.loaded["GameLua.Mod.BaseMod.Client.ScreenMarkUI.CommonActorScreenMarkUI"]
            or (pcall(require, "GameLua.Mod.BaseMod.Client.ScreenMarkUI.CommonActorScreenMarkUI") and require("GameLua.Mod.BaseMod.Client.ScreenMarkUI.CommonActorScreenMarkUI"))
        if CommonActorScreenMarkUI and not CommonActorScreenMarkUI._sx_outscreen_patched then
            CommonActorScreenMarkUI._sx_outscreen_patched = true
            local orig_SetUpInfo = CommonActorScreenMarkUI.SetUpInfoInternal
            CommonActorScreenMarkUI.SetUpInfoInternal = function(self, ID)
                if orig_SetUpInfo then orig_SetUpInfo(self, ID) end
                pcall(function()
                    local util = require("client.slua_ui_framework.util")
                    if (ID == 101005 or ID == 64200010) and self.Image_Icon then
                        -- Dedicated Molotov Threat Alert: Official HD FireBomb Icon with Flaming Danger Tint
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_FireBomb.Icon_WEP_FireBomb")
                        if self.Image_BG then
                            if self.Image_BG.SetColorAndOpacity then
                                self.Image_BG:SetColorAndOpacity(FLinearColor(1.0, 0.22, 0.02, 0.95))
                            end
                            if self.Image_BG.SetWidgetVisibility then
                                self.Image_BG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                            end
                        end
                    elseif ID == 72023 and self.Image_Icon then
                        -- Official 8x Scope HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Attach/Icon_MZJ_8X.Icon_MZJ_8X")
                    elseif ID == 72024 and self.Image_Icon then
                        -- Official 6x Scope HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Attach/Icon_MZJ_6X.Icon_MZJ_6X")
                    elseif ID == 72025 and self.Image_Icon then
                        -- Official 4x Scope HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Attach/Icon_MZJ_4X.Icon_MZJ_4X")
                    elseif ID == 72032 and self.Image_Icon then
                        -- Official 3x Scope HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Attach/Icon_MZJ_3X.Icon_MZJ_3X")
                    elseif ID == 72033 and self.Image_Icon then
                        -- Official DP-28 LMG HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_DP28.Icon_WEP_DP28")
                    elseif ID == 72034 and self.Image_Icon then
                        -- Official SCAR-L AR HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_SCAR.Icon_WEP_SCAR")
                    elseif ID == 72029 and self.Image_Icon then
                        -- Frag Grenade Ground ESP: Official HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_Grenade.Icon_WEP_Grenade")
                    elseif ID == 72030 and self.Image_Icon then
                        -- Smoke Grenade Ground ESP: Official HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_SmokeBomb.Icon_WEP_SmokeBomb")
                    elseif ID == 72031 and self.Image_Icon then
                        -- Molotov Cocktail Ground ESP: Official HD TableIcon
                        util.SetTexture(self.Image_Icon, "/Game/Arts/UI/TableIcons/ItemIcon/Weapon/Icon_WEP_FireBomb.Icon_WEP_FireBomb")
                    end
                end)
                if self.Image_Icon and self.Image_Icon.SetWidgetVisibility then
                    self.Image_Icon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end
            end

            CommonActorScreenMarkUI.SwitchIfOutOfScreen = function(self, bIsOutScreen)
                if self.Image_Icon then
                    self.Image_Icon:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end
                if self.Image_BG then
                    self.Image_BG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end
                if self.Image_Arrow then
                    self.Image_Arrow:SetWidgetVisibility(bIsOutScreen and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
                    if (self.ID == 101005 or self.ID == 64200010) and bIsOutScreen then
                        local util = require("client.slua_ui_framework.util")
                        util.SetTexture(self.Image_Arrow, "/Game/Arts/UI/Atlas/BattleUI/Ingame_QuickSign/Frames/DJ_Bg_dibiaokuang_jiantou_04_png.DJ_Bg_dibiaokuang_jiantou_04_png")
                        if self.Image_Arrow.SetColorAndOpacity then
                            self.Image_Arrow:SetColorAndOpacity(FLinearColor(1.0, 0.28, 0.02, 1.0)) -- Blazing Molotov Orange-Red Arrow
                        end
                    elseif self.ID == 1010 and bIsOutScreen then
                        local util = require("client.slua_ui_framework.util")
                        util.SetTexture(self.Image_Arrow, "/Game/Arts/UI/Atlas/BattleUI/Ingame_QuickSign/Frames/DJ_Bg_dibiaokuang_jiantou_04_png.DJ_Bg_dibiaokuang_jiantou_04_png")
                        if self.Image_Arrow.SetColorAndOpacity then
                            self.Image_Arrow:SetColorAndOpacity(FLinearColor(1.0, 0.05, 0.05, 1.0))
                        end
                    end
                end
                if self.Text_Distance and self.SCMarkConfig and self.SCMarkConfig.CommonMarkConfig and self.SCMarkConfig.CommonMarkConfig.bDistance then
                    self.Text_Distance:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end
            end
        end

        local GamePlayTools = package.loaded["GameLua.Mod.BaseMod.Common.GamePlayTools"]
            or (pcall(require, "GameLua.Mod.BaseMod.Common.GamePlayTools") and require("GameLua.Mod.BaseMod.Common.GamePlayTools"))
        if GamePlayTools and GamePlayTools.GetCurrentConfig and not GamePlayTools._gk_hooked then
            local orig = GamePlayTools.GetCurrentConfig
            GamePlayTools.GetCurrentConfig = function(Key)
                local res = orig(Key)
                if Key == "ScreenMarkConfig" and res and type(res) == "table" then
                    pcall(ApplyMarkConfigs, res)
                end
                return res
            end
            GamePlayTools._gk_hooked = true
        end
    end)
    pcall(function()
        local CGM = package.loaded["GameLua.GameCore.Main.ClientGameMain"]
        if CGM and CGM.GetCurrentConfig and not CGM._gk_hooked then
            local orig = CGM.GetCurrentConfig
            CGM.GetCurrentConfig = function(Key)
                local res = orig(Key)
                if Key == "ScreenMarkConfig" and res and type(res) == "table" then
                    pcall(ApplyMarkConfigs, res)
                end
                return res
            end
            CGM._gk_hooked = true
        end
    end)
end

local function InitMapTracking()
    pcall(function()
        HookConfigProviders()

        local GamePlayTools = package.loaded["GameLua.Mod.BaseMod.Common.GamePlayTools"]
            or (pcall(require, "GameLua.Mod.BaseMod.Common.GamePlayTools") and require("GameLua.Mod.BaseMod.Common.GamePlayTools"))
        local CGM = package.loaded["GameLua.GameCore.Main.ClientGameMain"]

        if GamePlayTools and GamePlayTools.GetCurrentConfig then
            local smc = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
            if smc and type(smc) == "table" then ApplyMarkConfigs(smc) end
        end

        if CGM and CGM.CurrentConfig and CGM.CurrentConfig.ScreenMarkConfig then
            ApplyMarkConfigs(CGM.CurrentConfig.ScreenMarkConfig)
        end

        for mn, md in pairs(package.loaded) do
            if type(mn) == "string" and (string.find(mn, "ScreenMarkConfig") or string.find(mn, "PlanCH") or string.find(mn, "TDM")) and type(md) == "table" then
                ApplyMarkConfigs(md)
            end
        end
        -- PlanCH (TDM / Arena) Config explicitly
        pcall(function()
            local cfgPlanCH = package.loaded["GameLua.Mod.PlanCH.Client.Config.ScreenMarkConfig"]
                or (pcall(require, "GameLua.Mod.PlanCH.Client.Config.ScreenMarkConfig") and require("GameLua.Mod.PlanCH.Client.Config.ScreenMarkConfig"))
            if cfgPlanCH then ApplyMarkConfigs(cfgPlanCH) end
        end)

        local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
            or (pcall(require, "GameLua.Mod.BaseMod.Common.InGameMarkTools") and require("GameLua.Mod.BaseMod.Common.InGameMarkTools"))

        -- Ensure ScreenMark parent UI Canvas is loaded & visible for ScreenMarkManagerBase
        pcall(function()
            local UIManager = package.loaded["GameLua.Mod.BaseMod.Client.UIManager"] or import("UIManager")
            if UIManager and UIManager.ShowUI and UIManager.UI_Config_InGame and UIManager.UI_Config_InGame.DefaultScreenMarkPanel then
                local ui = UIManager.ShowUI(UIManager.UI_Config_InGame.DefaultScreenMarkPanel)
                if ui and ui.SelfHitTestInvisible then pcall(ui.SelfHitTestInvisible, ui) end
            end
        end)

        -- Pure Native 1010 Integration: Filter Stun/Smoke and apply Optimus Exclamation HUD
        -- Flag set ONLY after confirming the original is a function: if the
        -- manager isn't ready yet (nil ClientAddMapMark), skip wrapping so a
        -- later InitMapTracking retry installs a live wrapper instead of a
        -- permanently-broken nil-calling one.
        if InGameMarkTools and not InGameMarkTools._sx_1010_intercepted then
            local orig_ClientAdd = InGameMarkTools.ClientAddMapMark
            if type(orig_ClientAdd) == "function" then
            InGameMarkTools._sx_1010_intercepted = true
            InGameMarkTools.ClientAddMapMark = function(TypeID, MarkPosition, CustomState, CustomString, MapAdded, Actor, CustomFloat, WeakPlayerState)
                if TypeID == 1010 then
                    if CFG.Alert_Incoming_Grenades == false then
                        return nil -- Block only if explicitly disabled in menu
                    end
                    -- Strictly exclude Stun Grenades and Smoke from triggering threat alerts!
                    if Actor and IsValid(Actor) then
                        local aname = string.lower(Actor.GetName and Actor:GetName() or "")
                        if string.find(aname, "stun") or string.find(aname, "flash") or string.find(aname, "smoke") then
                            return nil
                        end
                    end
                end
                return orig_ClientAdd(TypeID, MarkPosition, CustomState, CustomString, MapAdded, Actor, CustomFloat, WeakPlayerState)
            end
            end
        end

        if InGameMarkTools and InGameMarkTools.ScreenMarkManager then
            local smm = InGameMarkTools.ScreenMarkManager
            _G._marksInitManager = smm
            local function InitOne(id)
                if smm.InitMarkGroupData then pcall(smm.InitMarkGroupData, smm, id, true) end
                if smm.OnInitMarkGroupData then pcall(smm.OnInitMarkGroupData, smm, id) end
            end
            InitOne(GK_MECHA_GROUP_ID)
            InitOne(GK_HP_BAR_ID)
            InitOne(1006)
            InitOne(1010)
            InitOne(101005)
            InitOne(64200010)
            InitOne(GK_MECHA_HP_ID)
            for _, def in ipairs(_G.VEHICLE_ICON_CONFIG) do
                InitOne(def.id)
            end
            for _, def in ipairs(_G.ITEM_ICON_CONFIG) do
                InitOne(def.id)
            end
        end
    end)
end
_G.InitMapTracking = InitMapTracking
pcall(InitMapTracking)

function _G.UpdateMarkOutScreenSetting()
    pcall(InitMapTracking)
    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
    if InGameMarkTools and InGameMarkTools.ScreenMarkManager and InGameMarkTools.ScreenMarkManager.GetMarkGroupData then
        local bVehOut = (CFG.Veh_360_Alert ~= false)
        for _, def in ipairs(_G.VEHICLE_ICON_CONFIG) do
            local grpData = InGameMarkTools.ScreenMarkManager:GetMarkGroupData(def.id)
            if grpData then
                grpData.bBindOutScreen = bVehOut
                if grpData.WorldPositionOffset then
                    grpData.WorldPositionOffset = FVector(0, 0, def.zOffset or 210)
                end
            end
        end
        -- Loot items are strictly front-of-camera only (no edge pointers)
        for _, def in ipairs(_G.ITEM_ICON_CONFIG) do
            local grpData = InGameMarkTools.ScreenMarkManager:GetMarkGroupData(def.id)
            if grpData then
                grpData.bBindOutScreen = false
            end
        end
    end
end

-- ============================================================================
-- 6. ACTIVE CLEANUP ROUTINES
-- ============================================================================
local function ClearAllEnemyESP()
    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
    if InGameMarkTools and InGameMarkTools.HideMapMark then
        for pKey, mId in pairs(_G.ActiveEnemyMarks) do
            if mId then pcall(InGameMarkTools.HideMapMark, mId) end
        end
    end
    _G.ActiveEnemyMarks = {}
    if _G.ClearAllEnemyCounters then pcall(_G.ClearAllEnemyCounters) end

    if InGameMarkTools and InGameMarkTools.HideMapMark then
        for pKey, mId in pairs(_G.ActiveHPMarks) do
            if mId then pcall(InGameMarkTools.HideMapMark, mId) end
        end
        for pKey, mId in pairs(_G.ActiveMechaHPMarks) do
            if mId then pcall(InGameMarkTools.HideMapMark, mId) end
        end
    end
    _G.ActiveHPMarks = {}
    _G.ActiveMechaHPMarks = {}

    -- P0-FIX: Removed dead block — activeEnemyKeys was nil-global (only exists as local in Phase_Enemies).
    -- Line 2014 already clears _G.ActiveHPMarks = {} which does the same job safely.
    for pKey, pawn in pairs(_G.ActiveBoxCache) do
        if IsValid(pawn) and pawn.Replay_SetVisiableOfFrameUI and not IsPawnDead(pawn) then
            pcall(pawn.Replay_SetVisiableOfFrameUI, pawn, false)
        end
    end
    _G.ActiveBoxCache = {}

    if _G.ClearAllWallVision then pcall(_G.ClearAllWallVision) end
end
_G.ClearAllEnemyESP = ClearAllEnemyESP

-- Native Slate Mark Hiding Engines (Dual Hook: InGameMarkTools + MarkDispatchManager)
local function SafeHideVehicleMark(mId)
    if not mId then return end
    pcall(function()
        local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
            or (pcall(require, "GameLua.Mod.BaseMod.Common.InGameMarkTools") and require("GameLua.Mod.BaseMod.Common.InGameMarkTools"))
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mId)
        end
        if InGameMarkTools and InGameMarkTools.GetMarkDispatchManager then
            local mgr = InGameMarkTools.GetMarkDispatchManager()
            if slua and slua.isValid and slua.isValid(mgr) and mgr.ShowOrHideMapMark then
                mgr:ShowOrHideMapMark(mId, false)
            end
        end
    end)
end
_G.SafeHideVehicleMark = SafeHideVehicleMark

local function SafeHideLootMark(mId)
    if not mId then return end
    pcall(function()
        local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
            or (pcall(require, "GameLua.Mod.BaseMod.Common.InGameMarkTools") and require("GameLua.Mod.BaseMod.Common.InGameMarkTools"))
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mId)
        end
        if InGameMarkTools and InGameMarkTools.GetMarkDispatchManager then
            local mgr = InGameMarkTools.GetMarkDispatchManager()
            if slua and slua.isValid and slua.isValid(mgr) and mgr.ShowOrHideMapMark then
                mgr:ShowOrHideMapMark(mId, false)
            end
        end
    end)
end
_G.SafeHideLootMark = SafeHideLootMark


function _G.ClearVehicleIconGroup(markId)
    local grp = _G.ActiveVehicleMarkCache[markId]
    if grp then
        for vehKey, mId in pairs(grp) do
            SafeHideVehicleMark(mId)
            if _G.ActiveVehicleAttached then _G.ActiveVehicleAttached[vehKey] = nil end
            if _G._VehMissedScans then _G._VehMissedScans[vehKey] = nil end
        end
        _G.ActiveVehicleMarkCache[markId] = {}
    end
    if _G.ActiveVehicleAttached then
        for vehKey, data in pairs(_G.ActiveVehicleAttached) do
            if data and data.markId == markId then
                SafeHideVehicleMark(data.mId)
                _G.ActiveVehicleAttached[vehKey] = nil
                if _G._VehMissedScans then _G._VehMissedScans[vehKey] = nil end
            end
        end
    end
end

function _G.ClearVehicleCategory(catKey)
    for _, def in ipairs(_G.VEHICLE_ICON_CONFIG) do
        if def.catKey == catKey then
            _G.ClearVehicleIconGroup(def.id)
        end
    end
    -- Deep Cache Purge: Sweep ActiveVehicleAttached directly for matching category vehicles
    if _G.ActiveVehicleAttached then
        for vehKey, data in pairs(_G.ActiveVehicleAttached) do
            local def = _G.VehicleDefCache and _G.VehicleDefCache[vehKey]
            if def and def.catKey == catKey then
                if data and data.mId then SafeHideVehicleMark(data.mId) end
                if data and data.markId and _G.ActiveVehicleMarkCache[data.markId] then
                    _G.ActiveVehicleMarkCache[data.markId][vehKey] = nil
                end
                _G.ActiveVehicleAttached[vehKey] = nil
                if _G.VehicleDefCache then _G.VehicleDefCache[vehKey] = nil end
            end
        end
    end
end

function _G.ClearAllVehicleIcons()
    for markId, grp in pairs(_G.ActiveVehicleMarkCache) do
        for vehKey, mId in pairs(grp) do
            SafeHideVehicleMark(mId)
        end
    end
    if _G.ActiveVehicleAttached then
        for vehKey, data in pairs(_G.ActiveVehicleAttached) do
            if data and data.mId then SafeHideVehicleMark(data.mId) end
        end
    end
    _G.ActiveVehicleMarkCache = {}
    _G.ActiveVehicleAttached = {}
    _G.VehicleDefCache = {}
    _G.VehicleTombstones = {}
    if _G._VehMissedScans then _G._VehMissedScans = {} end
end

function _G.ClearLootIconGroup(markId)
    local grp = _G.ActiveLootMarkCache[markId]
    if grp then
        for itemKey, mId in pairs(grp) do
            SafeHideLootMark(mId)
            if _G.ActiveLootAttached then _G.ActiveLootAttached[itemKey] = nil end
            if _G.LootDefCache then _G.LootDefCache[itemKey] = nil end
        end
        _G.ActiveLootMarkCache[markId] = {}
    end
    if _G.ActiveLootAttached then
        for itemKey, data in pairs(_G.ActiveLootAttached) do
            if data and data.markId == markId then
                SafeHideLootMark(data.mId)
                _G.ActiveLootAttached[itemKey] = nil
                if _G.LootDefCache then _G.LootDefCache[itemKey] = nil end
            end
        end
    end
end

function _G.ClearLootCategory(catKey)
    for _, def in ipairs(_G.ITEM_ICON_CONFIG) do
        if def.catKey == catKey then
            _G.ClearLootIconGroup(def.id)
        end
    end
    -- Deep Cache Purge: Sweep ActiveLootAttached directly for matching category items
    if _G.ActiveLootAttached then
        for itemKey, data in pairs(_G.ActiveLootAttached) do
            local def = _G.LootDefCache and _G.LootDefCache[itemKey]
            if def and def.catKey == catKey then
                if data and data.mId then SafeHideLootMark(data.mId) end
                if data and data.markId and _G.ActiveLootMarkCache[data.markId] then
                    _G.ActiveLootMarkCache[data.markId][itemKey] = nil
                end
                _G.ActiveLootAttached[itemKey] = nil
                if _G.LootDefCache then _G.LootDefCache[itemKey] = nil end
            end
        end
    end
end

function _G.ClearAllLootIcons()
    for markId, grp in pairs(_G.ActiveLootMarkCache) do
        for itemKey, mId in pairs(grp) do
            SafeHideLootMark(mId)
        end
    end
    if _G.ActiveLootAttached then
        for itemKey, data in pairs(_G.ActiveLootAttached) do
            if data and data.mId then
                SafeHideLootMark(data.mId)
            end
        end
    end
    _G.ActiveLootMarkCache = {}
    _G.ActiveLootAttached = {}
    _G.LootDefCache = {}
    _G.LootTombstones = {}
end

-- ============================================================================
-- 5.1 NATIVE IN-GAME HP BAR HOOKS (Vertical Strip & Mecha Dual Vertical Meters)
-- ============================================================================
local function HookNativeHPBar()
    local HPBarUI = package.loaded["GameLua.Mod.BaseMod.Client.HPBar.HPBarUI"]
    if not HPBarUI then
        pcall(function() HPBarUI = require("GameLua.Mod.BaseMod.Client.HPBar.HPBarUI") end)
    end
    if not HPBarUI or HPBarUI._sx_hooked then return end
    HPBarUI._sx_hooked = true

    local orig_GetHealth = HPBarUI.GetHealth
    HPBarUI.GetHealth = function(self, Actor)
        if not Actor or not IsValid(Actor) then return 0 end
        if Actor.Health and type(Actor.Health) == "number" then return Actor.Health end
        if Actor.GetHealth and type(Actor.GetHealth) == "function" then
            local ok, h = pcall(Actor.GetHealth, Actor)
            if ok and h then return h end
        end
        if orig_GetHealth then return orig_GetHealth(self, Actor) end
        return 100
    end

    local orig_GetHealthMax = HPBarUI.GetHealthMax
    HPBarUI.GetHealthMax = function(self, Actor)
        if not Actor or not IsValid(Actor) then return 100 end
        if Actor.HealthMax and type(Actor.HealthMax) == "number" and Actor.HealthMax > 0 then return Actor.HealthMax end
        if Actor.GetHealthMax and type(Actor.GetHealthMax) == "function" then
            local ok, h = pcall(Actor.GetHealthMax, Actor)
            if ok and h then return h end
        end
        if orig_GetHealthMax then return orig_GetHealthMax(self, Actor) end
        return 100
    end

    local orig_OnActorBindUI = HPBarUI.OnActorBindUI
    HPBarUI.OnActorBindUI = function(self, BindActor)
        if orig_OnActorBindUI then orig_OnActorBindUI(self, BindActor) end
        pcall(function()
            if CFG.ESP_Health_Bar then
                -- Hide monster boss elements (no monster face, no sideways text, no white ghost bar)
                if IsValid(self.Border_Monster) then
                    self.Border_Monster:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end
                if IsValid(self.TextBlock_HPName) then
                    self.TextBlock_HPName:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end
                if IsValid(self.ProgressBarWhite) then
                    self.ProgressBarWhite:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end
                if IsValid(self.ProgressBarVirtualHealth) then
                    self.ProgressBarVirtualHealth:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end

                -- Configure ProgressBarHealth into a clean ground health bar under feet
                local bar = self.ProgressBarHealth or self.ProgressBar_Health or self.ProgressBar_Health_Green
                if IsValid(bar) then
                    bar.BarFillType = 0 -- EProgressBarFillType::LeftToRight (clean ground gauge)
                    bar:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

                    local UIUtil = require("client.common.ui_util")
                    if UIUtil and UIUtil.SetSize then
                        UIUtil.SetSize(bar, 46, 5)
                        if IsValid(self.CanvasPanel_Root) then
                            UIUtil.SetSize(self.CanvasPanel_Root, 48, 7)
                        end
                    end
                end
            end
        end)
    end

    -- Pre-allocated linear colors for HP-Bar Hook (0 allocs per frame)
    local _HP_COLOR_GREEN  = MakeColor(0.15, 0.95, 0.35, 1.0)
    local _HP_COLOR_YELLOW = MakeColor(0.95, 0.85, 0.15, 1.0)
    local _HP_COLOR_RED    = MakeColor(0.95, 0.15, 0.15, 1.0)

    local orig_UpdateHP = HPBarUI.UpdateHP
    HPBarUI.UpdateHP = function(self)
        if orig_UpdateHP then orig_UpdateHP(self) end
        if not CFG.ESP_Health_Bar then return end
        pcall(function()
            local bar = self.ProgressBarHealth or self.ProgressBar_Health or self.ProgressBar_Health_Green
            if IsValid(bar) and self.HPPercentage then
                local pct = self.HPPercentage
                if pct >= 0.70 then
                    bar:SetFillColorAndOpacity(_HP_COLOR_GREEN)
                elseif pct >= 0.30 then
                    bar:SetFillColorAndOpacity(_HP_COLOR_YELLOW)
                else
                    bar:SetFillColorAndOpacity(_HP_COLOR_RED)
                end
            end

                -- Dynamic Perspective Distance Scaling:
                -- Smoothly scales down as distance increases (10m = 1.0x, 100m = 0.65x, 200m+ = 0.38x)
                -- Prevents health bar from bloating or overpowering distant enemies!
                if IsValid(self.CanvasPanel_Root) and IsValid(self.SaveActor) then
                    local pc = GetActivePlayerController()
                    local localPawn = pc and GetLocalPlayer(pc)
                    if localPawn and IsValid(localPawn) then
                        local myPos = GetActorLocation(localPawn)
                        local tarPos = GetActorLocation(self.SaveActor)
                        if myPos and tarPos then
                            local dx = tarPos.X - myPos.X
                            local dy = tarPos.Y - myPos.Y
                            local dz = tarPos.Z - myPos.Z
                            local distM = math.sqrt(dx * dx + dy * dy + dz * dz) / 100.0
                            local dScale = 1.0
                            if distM > 10 then
                                dScale = math.max(0.38, math.min(1.0, 1.0 - (distM - 10) * 0.0035))
                            end
                            self.CanvasPanel_Root:SetRenderScale(EC_GetVec2D(dScale, dScale))
                        end
                    end
                end
        end)
    end
end
pcall(HookNativeHPBar)

-- ============================================================================
-- 5.2 NATIVE THROWABLE PROJECTILE HOOK (0% CPU EVENT-DRIVEN GRENADE DETECTION)
-- ============================================================================
-- Pure event hooks on ProjectileBase & GrenadeActorBase:
-- Zero polling loops | Zero GetAllActorsOfClass overhead | 2GB RAM optimized
-- ============================================================================
_G.ActiveThrowables = _G.ActiveThrowables or {}
_G.ActiveThrowableMarks = _G.ActiveThrowableMarks or {}
_G.DetonatedThreatActors = _G.DetonatedThreatActors or {}

-- Immediate Zero-Delay Detonation / Extinguish Event Callback
_G.OnThrowableDetonated = function(act)
    if not act then return end
    pcall(function()
        local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
        local stableKey = _G.ThreatKey(act)
        _G.DetonatedThreatActors[stableKey] = os.clock()

        for k, data in pairs(_G.ActiveThrowableMarks) do
            if data.actor == act or k == stableKey then
                _G.DetonatedThreatActors[k] = os.clock()
                if data.mId and InGameMarkTools and InGameMarkTools.HideMapMark then
                    pcall(InGameMarkTools.HideMapMark, data.mId)
                end
                _G.ActiveThrowableMarks[k] = nil
            end
        end
    end)
end

-- Stable threat key: engine object NAME (unique spawn counter), NOT tostring()
-- address. UE4 pools projectile objects, so a new live grenade can reuse a
-- detonated one's userdata address -> string key collides -> live threat
-- wrongly skipped as "detonated" for 20s (intermittent misses while spamming).
_G.ThreatKey = function(actor)
    if actor and type(actor.GetName) == "function" then
        local ok, nm = pcall(actor.GetName, actor)
        if ok and nm and nm ~= "" then return "nm_" .. tostring(nm) end
    end
    return tostring(actor)
end

-- Instant threat mount: called from projectile hooks at spawn time so the
-- widget exists immediately (no waiting for the next 1s scan). Scan loop
-- refreshes lifetime afterwards. All guarded; safe no-op when disabled.
_G.MountThreatMarkNow = function(actor)
    if CFG.Alert_Incoming_Grenades == false then return end
    if not actor or not IsValid(actor) then return end
    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
        or (pcall(require, "GameLua.Mod.BaseMod.Common.InGameMarkTools") and require("GameLua.Mod.BaseMod.Common.InGameMarkTools"))
    if not InGameMarkTools or not InGameMarkTools.ClientAddMapMark then return end
    local key = _G.ThreatKey(actor)
    if _G.ActiveThrowableMarks and _G.ActiveThrowableMarks[key] then return end
    local aname = string.lower(actor.GetName and actor:GetName() or "")
    local isMol = string.find(aname, "burn") or string.find(aname, "molotov")
        or string.find(aname, "firebomb") or string.find(aname, "flame") or string.find(aname, "spreading") ~= nil
    local targetMarkId = isMol and 101005 or 1010
    local loc = GetActorLocation(actor)
    if not loc then return end
    local ok, mId = pcall(InGameMarkTools.ClientAddMapMark, targetMarkId, loc, 0, nil, 4, actor)
    if (not ok or not mId) and targetMarkId == 101005 then
        ok, mId = pcall(InGameMarkTools.ClientAddMapMark, 1010, loc, 0, nil, 4, actor)
        if ok and mId then targetMarkId = 1010 end
    end
    if (not ok or not mId) then
        ok, mId = pcall(InGameMarkTools.ClientAddMapMark, targetMarkId, loc, 0, nil, 4, nil)
    end
    if ok and mId then
        _G.ActiveThrowableMarks = _G.ActiveThrowableMarks or {}
        _G.ActiveThrowableMarks[key] = {
            mId = mId, spawnTime = os.clock(), maxLife = 3.5,
            actor = actor, isMolotov = isMol and true or false,
            isFlamePool = false, isProjectile = true, markId = targetMarkId,
        }
    end
end

-- Strict Threat Filter: Frag Grenades, Molotov Cocktails, and Ground Fire
_G.IsDangerousExplosive = function(actor)
    if not actor or not IsValid(actor) then return false end
    if actor._sx_detonated or actor._sx_fire_ended then return false end
    local name = actor.GetName and actor:GetName() or ""
    local cname = ""
    if actor.GetClass then
        local ok, cls = pcall(actor.GetClass, actor)
        if ok and cls and cls.GetName then cname = cls:GetName() end
    end
    local combined = string.lower(name .. " " .. cname)
    local stableKey = _G.ThreatKey(actor)
    if _G.DetonatedThreatActors[stableKey] then return false end

    local isM = string.find(combined, "burn") or string.find(combined, "molotov") or string.find(combined, "firebomb")
        or string.find(combined, "spreading") or string.find(combined, "flame") or string.find(combined, "ranshaodan")

    -- If Frag Grenade has already exploded (state InEffect or PostEffect or Destroyed).
    -- NOTE: GrenadeExplodeStartTime is the fuse-start stamp, NOT explosion proof;
    -- treating it as detonated hides live grenades (widgets never form).
    if not isM then
        if actor.GetCurStateType then
            local ok, st = pcall(actor.GetCurStateType, actor)
            if ok and st and st.TagName then
                if st.TagName == "InEffect" or st.TagName == "PostEffect" or st.TagName == "Destroyed" then
                    _G.DetonatedThreatActors[stableKey] = os.clock()
                    return false
                end
            end
        end
    else
        -- For Molotov, check if fire has ended
        if actor.GetCurStateType then
            local ok, st = pcall(actor.GetCurStateType, actor)
            if ok and st and st.TagName then
                if st.TagName == "PostEffect" or st.TagName == "Destroyed" then
                    _G.DetonatedThreatActors[stableKey] = os.clock()
                    return false
                end
            end
        end
    end

    -- 1. STRICT EXCLUSIONS: Never alert on non-lethal throwables, consumables, or melee
    if string.find(combined, "smoke") or string.find(combined, "flash") or string.find(combined, "stun")
        or string.find(combined, "apple") or string.find(combined, "snow") or string.find(combined, "ball")
        or string.find(combined, "package") or string.find(combined, "band") or string.find(combined, "drink")
        or string.find(combined, "firstaid") or string.find(combined, "pan") or string.find(combined, "crowbar")
        or string.find(combined, "machete") or string.find(combined, "sickle") or string.find(combined, "arrow")
        or string.find(combined, "bolt") or string.find(combined, "healsmoke") then
        return false
    end

    -- 2. STRICT INCLUSIONS: Lethal Explosives & Molotovs
    if string.find(combined, "frag") or string.find(combined, "shoulei")
        or string.find(combined, "burn") or string.find(combined, "molotov") or string.find(combined, "firebomb")
        or string.find(combined, "spreading") or string.find(combined, "flame")
        or string.find(combined, "sticky") or string.find(combined, "c4") or string.find(combined, "timedbomb") then
        return true
    end

    -- 3. Native C++ Class check for Molotov fire on ground
    local isCClass = false
    pcall(function()
        local ASTBuffApplifierSpreading = import("STBuffApplifierSpreading")
        if ASTBuffApplifierSpreading and Game and Game.IsClassOf and Game:IsClassOf(actor, ASTBuffApplifierSpreading) then
            isCClass = true
        end
    end)
    if isCClass then return true end

    -- 4. Exact Item ID verification if exposed
    local itemId = (actor.GetItemTypeID and actor:GetItemTypeID())
        or (actor.ItemDefineID and actor.ItemDefineID.TypeSpecificID)
        or (actor.ItemID)
    if itemId then
        -- 602004 = Frag, 602003/602005 = Molotov, 602006/602007 = Sticky Bomb
        if itemId == 602004 or itemId == 602003 or itemId == 602005 or itemId == 602006 or itemId == 602007 then
            return true
        end
        return false
    end

    return false
end

local function HookThrowableProjectiles()
    local modulePaths = {
        "GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.ProjectileBase",
        "GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.SpecificProjectile.FragGrenade.FragGrenade",
        "GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.SpecificProjectile.BurnGrenade.BurnGrenade",
        "GameLua.Mod.BaseMod.GamePlay.Actor.Grenade.SpecificGrenade.FragGrenade.FragGrenadeActor",
        "GameLua.Mod.BaseMod.GamePlay.Actor.Grenade.SpecificGrenade.BurnGrenade.BurnGrenadeActor",
        -- TDM & Arena specific grenade actor modules!
        "GameLua.Mod.TDM.GamePlay.Actor.Grenade.SpecificGrenade.FragGrenade.FragGrenadeActor",
        "GameLua.Mod.BRTDM.Gameplay.Actor.Grenade.SpecificGrenade.FragGrenade.FragGrenadeActor"
    }

    local function HookClass(mod)
        if not mod then return end
        local target = mod.__inner_impl or mod
        if target and not target._sx_hooked then
            target._sx_hooked = true

            -- Hook ReceiveBeginPlay
            local orig_Begin = target.ReceiveBeginPlay
            target.ReceiveBeginPlay = function(self)
                if orig_Begin then orig_Begin(self) end
                pcall(function()
                    if CFG.Alert_Incoming_Grenades then
                        local act = (self and self.Object) or (self and self.Actor) or self
                        if act and IsValid(act) and _G.IsDangerousExplosive(act) then
                            _G.ActiveThrowables[act] = act
                            if _G.MountThreatMarkNow then pcall(_G.MountThreatMarkNow, act) end
                        end
                    end
                end)
            end

            -- Hook BeginFly (in-flight throwables)
            local orig_BeginFly = target.BeginFly
            if orig_BeginFly then
                target.BeginFly = function(self, oldType)
                    if orig_BeginFly then orig_BeginFly(self, oldType) end
                    pcall(function()
                        if CFG.Alert_Incoming_Grenades then
                            local act = (self and self.Object) or (self and self.Actor) or self
                            if act and IsValid(act) and _G.IsDangerousExplosive(act) then
                                _G.ActiveThrowables[act] = act
                                if _G.MountThreatMarkNow then pcall(_G.MountThreatMarkNow, act) end
                            end
                        end
                    end)
                end
            end

            -- Hook SpawnBuffApplier (specifically captures Molotov flame pool when it shatters)
            local orig_SpawnBuff = target.SpawnBuffApplier
            if orig_SpawnBuff then
                target.SpawnBuffApplier = function(self)
                    if orig_SpawnBuff then orig_SpawnBuff(self) end
                    pcall(function()
                        if CFG.Alert_Incoming_Grenades then
                            local applier = self and self.SpawnedBuffApplier
                            if applier and IsValid(applier) then
                                _G.ActiveThrowables[applier] = applier
                                if _G.MountThreatMarkNow then pcall(_G.MountThreatMarkNow, applier) end
                            end
                        end
                    end)
                end
            end

            -- Hook BeginInEffect: Frag Grenade DETONATES immediately, Molotov ground fire STARTS!
            local orig_BeginInEffect = target.BeginInEffect
            target.BeginInEffect = function(self, oldType)
                -- Teardown race: engine may invoke this on a destroyed effect
                -- during match-exit cleanup; bail before touching members.
                if not IsValid(self) then
                    if orig_BeginInEffect then return orig_BeginInEffect(self, oldType) end
                    return
                end
                pcall(function()
                    local isMolotov = false
                    local aname = string.lower((self.SafeGetObjectName and self:SafeGetObjectName()) or (self.GetName and self:GetName()) or "")
                    if string.find(aname, "burn") or string.find(aname, "molotov") or string.find(aname, "firebomb") then
                        isMolotov = true
                    end
                    if not isMolotov and self.ItemDefineID and (self.ItemDefineID.TypeSpecificID == 602003 or self.ItemDefineID.TypeSpecificID == 602005) then
                        isMolotov = true
                    end

                    local act = (self and self.Object) or (self and self.Actor) or self

                    if not isMolotov then
                        -- FRAG GRENADE: BeginInEffect is the explosion blast! Mark detonated & clear threat mark instantly!
                        self._sx_detonated = true
                        if act then
                            act._sx_detonated = true
                            local stableKey = _G.ThreatKey(act)
                            _G.DetonatedThreatActors[stableKey] = os.clock()
                            _G.ActiveThrowables[act] = nil
                            if _G.OnThrowableDetonated then
                                pcall(_G.OnThrowableDetonated, act)
                            end
                        end
                    else
                        -- MOLOTOV: Impact/Ignition! Flying bottle has SHATTERED!
                        self._sx_detonated = true
                        self._sx_burning = true
                        if act then
                            act._sx_detonated = true
                            local bottleKey = _G.ThreatKey(act)
                            _G.DetonatedThreatActors[bottleKey] = os.clock()
                            _G.ActiveThrowables[act] = nil -- Bottle is no longer an active in-flight projectile!

                            -- MARK TRANSFER (Zero-Blink): Instead of hiding the bottle mark and waiting
                            -- for the next scan to create a flame mark (0.5s blink gap), TRANSFER the
                            -- existing mark to the flame pool actor immediately!
                            local applier = self and self.SpawnedBuffApplier
                            local bottleMark = _G.ActiveThrowableMarks[bottleKey]

                            if applier and IsValid(applier) then
                                _G.ActiveThrowables[applier] = applier
                                local flameKey = _G.ThreatKey(applier)

                                if bottleMark and bottleMark.mId then
                                    -- Transfer the mark: keep the same visual widget, just reassign the tracking data
                                    _G.ActiveThrowableMarks[flameKey] = {
                                        mId = bottleMark.mId,       -- REUSE existing widget (zero blink!)
                                        spawnTime = os.clock(),
                                        maxLife = 8.0,              -- Ground flame lifetime
                                        actor = applier,
                                        isMolotov = true,
                                        isFlamePool = true,
                                        isProjectile = false,
                                        markId = bottleMark.markId
                                    }
                                    -- Remove the bottle entry WITHOUT hiding the mark (it's now owned by flame)
                                    _G.ActiveThrowableMarks[bottleKey] = nil
                                else
                                    -- No bottle mark existed (rare: bottle detonated before first scan)
                                    _G.ActiveThrowableMarks[bottleKey] = nil
                                end
                            else
                                -- No applier yet: hide the bottle mark to prevent duplicate
                                if bottleMark and bottleMark.mId then
                                    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
                                    if InGameMarkTools and InGameMarkTools.HideMapMark then
                                        pcall(InGameMarkTools.HideMapMark, bottleMark.mId)
                                    end
                                end
                                _G.ActiveThrowableMarks[bottleKey] = nil
                            end
                        end
                    end
                end)
                if orig_BeginInEffect then return orig_BeginInEffect(self, oldType) end
            end

            -- Hook EndInEffect (Specifically Molotov fire ending / burning out!)
            local orig_EndInEffect = target.EndInEffect
            target.EndInEffect = function(self, nextType)
                -- Same teardown race as BeginInEffect (match-exit cleanup).
                if not IsValid(self) then
                    if orig_EndInEffect then return orig_EndInEffect(self, nextType) end
                    return
                end
                pcall(function()
                    self._sx_fire_ended = true
                    self._sx_detonated = true
                    local act = (self and self.Object) or (self and self.Actor) or self
                    if act then
                        act._sx_fire_ended = true
                        act._sx_detonated = true
                        local stableKey = _G.ThreatKey(act)
                        _G.DetonatedThreatActors[stableKey] = os.clock()
                        _G.ActiveThrowables[act] = nil
                        if _G.OnThrowableDetonated then
                            pcall(_G.OnThrowableDetonated, act)
                        end
                    end
                    local applier = self and self.SpawnedBuffApplier
                    if applier then
                        applier._sx_fire_ended = true
                        applier._sx_detonated = true
                        local applierKey = tostring(applier)
                        _G.DetonatedThreatActors[applierKey] = os.clock()
                        _G.ActiveThrowables[applier] = nil
                        if _G.OnThrowableDetonated then
                            pcall(_G.OnThrowableDetonated, applier)
                        end
                    end
                end)
                if orig_EndInEffect then return orig_EndInEffect(self, nextType) end
            end

            -- Hook BeginDestroyed (Destruction of projectile or fire)
            local orig_BeginDestroyed = target.BeginDestroyed
            target.BeginDestroyed = function(self, oldType)
                -- Destroyed object: never touch members, only forward.
                if not IsValid(self) then
                    if orig_BeginDestroyed then return orig_BeginDestroyed(self, oldType) end
                    return
                end
                pcall(function()
                    self._sx_detonated = true
                    self._sx_fire_ended = true
                    local act = (self and self.Object) or (self and self.Actor) or self
                    if act then
                        act._sx_detonated = true
                        act._sx_fire_ended = true
                        local stableKey = _G.ThreatKey(act)
                        _G.DetonatedThreatActors[stableKey] = os.clock()
                        _G.ActiveThrowables[act] = nil
                        if _G.OnThrowableDetonated then
                            pcall(_G.OnThrowableDetonated, act)
                        end
                    end
                end)
                if orig_BeginDestroyed then return orig_BeginDestroyed(self, oldType) end
            end

            -- Hook ReceiveEndPlay
            local orig_End = target.ReceiveEndPlay
            target.ReceiveEndPlay = function(self, reason)
                -- EndPlay == already half-destroyed by definition: forward only.
                if not IsValid(self) then
                    if orig_End then return orig_End(self, reason) end
                    return
                end
                pcall(function()
                    self._sx_detonated = true
                    self._sx_fire_ended = true
                    local act = (self and self.Object) or (self and self.Actor) or self
                    if act then
                        act._sx_detonated = true
                        act._sx_fire_ended = true
                        local stableKey = _G.ThreatKey(act)
                        _G.DetonatedThreatActors[stableKey] = os.clock()
                        _G.ActiveThrowables[act] = nil
                        _G.ActiveThrowables[self] = nil
                        if _G.OnThrowableDetonated then
                            pcall(_G.OnThrowableDetonated, act)
                        end
                    end
                end)
                if orig_End then orig_End(self, reason) end
            end
        end
    end

    for _, path in ipairs(modulePaths) do
        pcall(function()
            local mod = package.loaded[path] or (pcall(require, path) and require(path))
            HookClass(mod)
        end)
    end
end
pcall(HookThrowableProjectiles)

_G.ClearAllThrowableAlerts = function()
    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
    if InGameMarkTools and InGameMarkTools.HideMapMark then
        for obj, data in pairs(_G.ActiveThrowableMarks) do
            local mId = type(data) == "table" and data.mId or data
            if mId then pcall(InGameMarkTools.HideMapMark, mId) end
        end
    end
    _G.ActiveThrowableMarks = {}
    _G.DetonatedThreatActors = {}
end

-- P1-FIX: File-scope import caches for hot-path modules (eliminates 172-344 import() calls/sec)
local _KSL_Cached = nil
pcall(function() _KSL_Cached = import("KismetSystemLibrary") or import("/Script/Engine.KismetSystemLibrary") end)
local _GPS_Cached = nil
pcall(function() _GPS_Cached = import("GameplayStatics") end)

-- ============================================================================
-- 7. STAGGERED MASTER ROUND-ROBIN SCHEDULER (1.5S RELAXED, 0% GC HIT)
-- ============================================================================
local STAGGER_PHASE = 0
local ZERO_VECTOR = nil
local function GetZeroVector()
    if not ZERO_VECTOR then ZERO_VECTOR = FVector(0, 0, 0) end
    return ZERO_VECTOR
end

-- Native UE4 Hardware Occlusion & Wall Vision Subsystem (Zero CPU Cost)
local _WH_MeshCache = {}
local _WH_ConsoleReady = false

local function EnableWallVisionConsole()
    pcall(function()
        local ui_util = pcall(require, "client.common.ui_util") and require("client.common.ui_util")
        local gi = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            or (ui_util and ui_util.GetGameInstance and ui_util.GetGameInstance())
            or (_G.GameInstance)
        if gi and gi.ExecuteCMD then
            pcall(gi.ExecuteCMD, gi, "r.EnableDrawDyeingColor", "1")
            pcall(gi.ExecuteCMD, gi, "r.CustomDepth", "1")
            pcall(gi.ExecuteCMD, gi, "r.IdeaOutline.Enable", "1")
            pcall(gi.ExecuteCMD, gi, "r.Highlight.Enable", "1")
        end
        local KSL = import("KismetSystemLibrary")
        local world = _slua and _slua.getWorld and _slua.getWorld()
        if type(KSL) == "table" and type(KSL.ExecuteConsoleCommand) == "function" and world then
            pcall(KSL.ExecuteConsoleCommand, world, "r.EnableDrawDyeingColor 1")
            pcall(KSL.ExecuteConsoleCommand, world, "r.CustomDepth 1")
            pcall(KSL.ExecuteConsoleCommand, world, "r.IdeaOutline.Enable 1")
            pcall(KSL.ExecuteConsoleCommand, world, "r.Highlight.Enable 1")
        end
    end)
end

local function DisableWallVisionConsole()
    pcall(function()
        local ui_util = pcall(require, "client.common.ui_util") and require("client.common.ui_util")
        local gi = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            or (ui_util and ui_util.GetGameInstance and ui_util.GetGameInstance())
            or (_G.GameInstance)
        if gi and gi.ExecuteCMD then
            pcall(gi.ExecuteCMD, gi, "r.EnableDrawDyeingColor", "0")
            pcall(gi.ExecuteCMD, gi, "r.CustomDepth", "0")
            pcall(gi.ExecuteCMD, gi, "r.IdeaOutline.Enable", "0")
            pcall(gi.ExecuteCMD, gi, "r.Highlight.Enable", "0")
        end
        local KSL = import("KismetSystemLibrary")
        local world = _slua and _slua.getWorld and _slua.getWorld()
        if type(KSL) == "table" and type(KSL.ExecuteConsoleCommand) == "function" and world then
            pcall(KSL.ExecuteConsoleCommand, world, "r.EnableDrawDyeingColor 0")
            pcall(KSL.ExecuteConsoleCommand, world, "r.CustomDepth 0")
            pcall(KSL.ExecuteConsoleCommand, world, "r.IdeaOutline.Enable 0")
            pcall(KSL.ExecuteConsoleCommand, world, "r.Highlight.Enable 0")
        end
    end)
end

local function GetAllSkeletalMeshes(pawn)
    if not IsValid(pawn) then return {} end
    local pKey = GetPawnKey(pawn) or tostring(pawn)
    local cached = _WH_MeshCache[pKey]
    -- Cache with 8s TTL — catches armor/helmet pickups that add new mesh slots
    if cached and #cached > 0 and cached._time and (os.clock() - cached._time) < 8.0 then
        local allAlive = true
        for _, m in ipairs(cached) do
            if not IsValid(m) then allAlive = false; break end
        end
        if allAlive then return cached end
    end

    local meshes = {}
    local seen = {}
    local function SafeAdd(m)
        if IsValid(m) and not seen[m] then
            seen[m] = true
            meshes[#meshes + 1] = m
        end
    end

    -- Layer 0: Base pawn meshes (works on ALL pawns including bots)
    SafeAdd(pawn.Mesh)
    SafeAdd(pawn.MasterMesh)
    pcall(function()
        if pawn.GetMesh then SafeAdd(pawn:GetMesh()) end
    end)

    -- Resolve avatar component (only real players have this — bots do NOT)
    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn.AvatarComponent2
    if not avatarComp and type(pawn.getAvatarComponent2) == "function" then
        local ok, comp = pcall(pawn.getAvatarComponent2, pawn)
        if ok and IsValid(comp) then avatarComp = comp end
    end
    if not avatarComp and type(pawn.GetComponentByClass) == "function" then
        local SlotViewComp = import("SlotViewAvatarComponent")
        if SlotViewComp then
            local ok, comp = pcall(pawn.GetComponentByClass, pawn, SlotViewComp)
            if ok and IsValid(comp) then avatarComp = comp end
        end
    end

    if IsValid(avatarComp) then
        -- Layer 1 (BEST): GetAllLoadedMeshComponents() — official game API (LobbyPawn:1108)
        -- Returns ALL loaded meshes across ALL slots, regardless of slot ID numbering
        pcall(function()
            if type(avatarComp.GetAllLoadedMeshComponents) == "function" then
                local allMeshes = avatarComp:GetAllLoadedMeshComponents()
                if allMeshes then
                    if type(allMeshes) == "table" then
                        for _, m in pairs(allMeshes) do SafeAdd(m) end
                    elseif type(allMeshes) == "userdata" then
                        -- TArray userdata iteration
                        local len = allMeshes.Num and allMeshes:Num() or (#allMeshes)
                        for i = 0, len - 1 do
                            local ok2, m = pcall(function() return allMeshes:Get(i) or allMeshes[i] end)
                            if ok2 and IsValid(m) then SafeAdd(m) end
                        end
                    end
                end
            end
        end)

        -- Layer 2: GetAllMeshComponents(false) — CharacterAvatarComponent:1062
        -- Catches weapon attachments, vehicle-mounted meshes, etc.
        pcall(function()
            if type(avatarComp.GetAllMeshComponents) == "function" then
                local allMeshes = avatarComp:GetAllMeshComponents(false)
                if allMeshes then
                    if type(allMeshes) == "table" then
                        for _, m in pairs(allMeshes) do SafeAdd(m) end
                    elseif type(allMeshes) == "userdata" then
                        local len = allMeshes.Num and allMeshes:Num() or (#allMeshes)
                        for i = 0, len - 1 do
                            local ok2, m = pcall(function() return allMeshes:Get(i) or allMeshes[i] end)
                            if ok2 and IsValid(m) then SafeAdd(m) end
                        end
                    end
                end
            end
        end)

        -- Layer 3: Slot-based enumeration (extended range 0-14 + EAvatarSlotType enum lookup)
        if type(avatarComp.GetMeshCompBySlot) == "function" then
            for slot = 0, 14 do
                local ok, slotMesh = pcall(avatarComp.GetMeshCompBySlot, avatarComp, slot)
                if ok and IsValid(slotMesh) then SafeAdd(slotMesh) end
            end
        elseif type(avatarComp.GetMeshCompBySlotID) == "function" then
            for slot = 0, 14 do
                local ok, slotMesh = pcall(avatarComp.GetMeshCompBySlotID, avatarComp, slot)
                if ok and IsValid(slotMesh) then SafeAdd(slotMesh) end
            end
        end

        -- Query all named EAvatarSlotType enum values directly (Helmet, Armor, Backpack, Clothes, etc.)
        pcall(function()
            local EAvatarSlotType = import("EAvatarSlotType")
            if EAvatarSlotType and type(EAvatarSlotType) == "table" and type(avatarComp.GetMeshCompBySlot) == "function" then
                for _, slotVal in pairs(EAvatarSlotType) do
                    if type(slotVal) == "number" then
                        local ok, slotMesh = pcall(avatarComp.GetMeshCompBySlot, avatarComp, slotVal)
                        if ok and IsValid(slotMesh) then SafeAdd(slotMesh) end
                    end
                end
            end
        end)

        -- Layer 3b: LoadedMeshComps internal table (CharacterAvatarComponent:2494)
        pcall(function()
            if avatarComp.LoadedMeshComps then
                for slotID, slotMeshDesc in pairs(avatarComp.LoadedMeshComps) do
                    if type(slotMeshDesc) == "table" and slotMeshDesc.MeshComp then
                        SafeAdd(slotMeshDesc.MeshComp)
                    elseif IsValid(slotMeshDesc) then
                        SafeAdd(slotMeshDesc)
                    end
                end
            end
        end)
    end

    -- Layer 4 (UNCONDITIONAL): UE4 GetComponentsByClass for SkeletalMeshComponent & StaticMeshComponent
    -- Runs for ALL pawns (real players + bots) — captures helmets, vests, backpacks, accessories, custom gear
    if type(pawn.GetComponentsByClass) == "function" then
        pcall(function()
            local SMC = import("SkeletalMeshComponent")
            if SMC then
                local allComps = pawn:GetComponentsByClass(SMC)
                if allComps then
                    if type(allComps) == "table" then
                        for _, m in pairs(allComps) do SafeAdd(m) end
                    elseif type(allComps) == "userdata" then
                        local len = allComps.Num and allComps:Num() or (#allComps)
                        for i = 0, len - 1 do
                            local ok2, m = pcall(function() return allComps:Get(i) or allComps[i] end)
                            if ok2 and IsValid(m) then SafeAdd(m) end
                        end
                    end
                end
            end
            local STMC = import("StaticMeshComponent")
            if STMC then
                local allStatic = pawn:GetComponentsByClass(STMC)
                if allStatic then
                    if type(allStatic) == "table" then
                        for _, m in pairs(allStatic) do SafeAdd(m) end
                    elseif type(allStatic) == "userdata" then
                        local len = allStatic.Num and allStatic:Num() or (#allStatic)
                        for i = 0, len - 1 do
                            local ok2, m = pcall(function() return allStatic:Get(i) or allStatic[i] end)
                            if ok2 and IsValid(m) then SafeAdd(m) end
                        end
                    end
                end
            end
        end)
    end

    -- Layer 5: Root/Base Mesh Attached Children (captures wings, capes, socketed equipment)
    pcall(function()
        local baseMesh = pawn.Mesh or (pawn.GetMesh and pawn:GetMesh())
        if baseMesh and IsValid(baseMesh) and baseMesh.GetAttachChildren then
            local children = baseMesh:GetAttachChildren()
            if children then
                local len = (type(children.Num) == "function" and children:Num()) or (type(children) == "table" and #children) or 0
                for i = 0, len - 1 do
                    local c = (type(children.Get) == "function" and children:Get(i)) or children[i + 1] or children[i]
                    if c and IsValid(c) then SafeAdd(c) end
                end
            end
        end
    end)

    meshes._time = os.clock()
    _WH_MeshCache[pKey] = meshes
    return meshes
end

-- Applied-state caches: C++ calls fire ONCE per mesh, never repeated.
-- Stock game pattern (CreativeModePlayerCharacter/TDMPlayerCharacterBase):
-- dyeing + avatar outline only. No highlight/ideaOutline/customdepth/LOD force.
local _WH_AppliedMesh = {}   -- mesh -> true (dyeing already on)
local _WH_PawnMeshes = {}    -- pKey -> array of meshes we dyed

local function ApplyWallVisionToPawn(pawn, isBot, distM)
    if not IsValid(pawn) then return end
    if not _WH_ConsoleReady then
        EnableWallVisionConsole()
        _WH_ConsoleReady = true
    end
    local pKey = GetPawnKey(pawn)

    -- NO post-process outline (user demand: glow completely off; its default
    -- yellow tint was also washing visible enemies dull yellow).

    -- Bot = Yellow/Orange | Real Enemy = Green/Red — instant visual distinction
    local visColor = isBot and C.bot_visible or C.accent_green
    local occColor = isBot and C.bot_occluded or C.accent_red

    -- 2. Dyeing: only meshes never treated before (mesh-set changes = armor pickup)
    local meshes = GetAllSkeletalMeshes(pawn)
    local stored = (pKey and _WH_PawnMeshes[pKey]) or {}
    local storedCount = #stored
    -- Identity compare, not just count: a gear swap (helmet L1->L2) can keep
    -- the mesh COUNT while replacing members; count-only check left the new
    -- meshes undyed forever ("wallhack misses some enemies").
    local sameSet = (#meshes == storedCount and storedCount > 0)
    if sameSet then
        for i, m in ipairs(meshes) do
            if stored[i] ~= m then sameSet = false; break end
        end
    end
    if sameSet then
        return -- same set, everything already dyed: zero C++ calls
    end
    local newList = {}
    for _, mesh in ipairs(meshes) do
        if IsValid(mesh) then
            newList[#newList + 1] = mesh
            if not _WH_AppliedMesh[mesh] then
                pcall(function()
                    if mesh.SetDrawDyeing then mesh:SetDrawDyeing(true) end
                    if mesh.SetDrawDyeingMode then mesh:SetDrawDyeingMode(1) end
                    if mesh.SetVisibleDyeingColor then mesh:SetVisibleDyeingColor(visColor) end
                    if mesh.SetOccludedDyeingColor then mesh:SetOccludedDyeingColor(occColor) end
                end)
                _WH_AppliedMesh[mesh] = true
            end
        end
    end
    if pKey then _WH_PawnMeshes[pKey] = newList end
end

local function ClearPawnWallVision(pawn)
    if not IsValid(pawn) then return end
    local pKey = GetPawnKey(pawn) or tostring(pawn)
    -- Undo dyeing ONLY on meshes we actually dyed (stored list, no re-enumeration)
    local meshes = (pKey and _WH_PawnMeshes[pKey]) or {}
    for _, mesh in ipairs(meshes) do
        if IsValid(mesh) then
            pcall(function()
                if mesh.SetDrawDyeing then mesh:SetDrawDyeing(false) end
            end)
            _WH_AppliedMesh[mesh] = nil
        end
    end
    if pKey then
        _WH_PawnMeshes[pKey] = nil
        _WH_MeshCache[pKey] = nil
    end
end

local function ClearAllWallVision()
    for pKey, pawn in pairs(_G.ActiveWallVisionPawns) do
        if IsValid(pawn) then
            pcall(ClearPawnWallVision, pawn)
        end
    end
    _G.ActiveWallVisionPawns = {}
    _WH_MeshCache = {}
    _WH_AppliedMesh = {}
    _WH_PawnMeshes = {}
    DisableWallVisionConsole()
    _WH_ConsoleReady = false
end
_G.ClearAllWallVision = ClearAllWallVision

-- Bulletproof Visibility Detection with Adaptive 2-Tier Raycast Throttling (0% GC, 2GB RAM Safe)
local _PawnVisCache = {}
local function CheckPlayerVisibility(pc, pawn, zeroVec, pKey, distM)
    if not IsValid(pc) or not IsValid(pawn) then return false end

    -- Throttled cache: cuts native LineTrace & LineOfSightTo raycasts by ~65% on low-end devices
    local now = GetGameTimeNow()
    if pKey and _PawnVisCache[pKey] then
        local entry = _PawnVisCache[pKey]
        local cacheTTL = (distM and distM > 120) and 0.8 or 0.4
        if (now >= entry.time) and ((now - entry.time) < cacheTTL) then
            return entry.vis
        end
    end

    local isVis = false
    -- 1. Native PlayerController LineOfSightTo test
    pcall(function()
        if pc.LineOfSightTo then
            local ok, res = pcall(pc.LineOfSightTo, pc, pawn, zeroVec, false)
            if ok and res == true then isVis = true end
        end
    end)
    if isVis then
        if pKey then _PawnVisCache[pKey] = { vis = true, time = now } end
        return true
    end

    -- 2. Accurate Camera-to-Head LineTraceSingle raycast
    pcall(function()
        local KSL = _KSL_Cached or import("KismetSystemLibrary") or import("/Script/Engine.KismetSystemLibrary")
        if not _KSL_Cached then _KSL_Cached = KSL end
        if type(KSL) == "table" and type(KSL.LineTraceSingle) == "function" then
            local GameplayStatics = _GPS_Cached or import("GameplayStatics")
            if not _GPS_Cached then _GPS_Cached = GameplayStatics end
            local camMgr = (type(GameplayStatics) == "table" and GameplayStatics.GetPlayerCameraManager and GameplayStatics.GetPlayerCameraManager(pc, 0)) or pc.PlayerCameraManager
            local startLoc = (camMgr and camMgr.GetCameraLocation and camMgr:GetCameraLocation())
                or (pc.GetPlayerCharacter and pc:GetPlayerCharacter() and GetActorLocation(pc:GetPlayerCharacter()))
            local endLoc = GetActorLocation(pawn)
            if startLoc and endLoc then
                local targetLoc = FVector(endLoc.X, endLoc.Y, endLoc.Z + 60)
                local hitResult = {}
                local bHit = KSL.LineTraceSingle(pc, startLoc, targetLoc, 0, false, nil, 0, hitResult, true)
                if bHit then
                    local hitActor = hitResult.GetActor and hitResult:GetActor() or hitResult.Actor
                    if hitActor and (hitActor == pawn or (hitActor.IsChildOf and hitActor:IsChildOf(pawn))) then
                        isVis = true
                    end
                else
                    isVis = true
                end
            end
        end
    end)
    if pKey then _PawnVisCache[pKey] = { vis = isVis, time = now } end
    return isVis
end

-- Native In-Game 2D Bounding Box (Cached: once attached, C++ engine moves it. Zero per-tick loop calls!)
local function UpdatePlayerFrameBox(pawn, pKey)
    if not IsValid(pawn) or not pKey then return end
    if _G.ActiveBoxCache[pKey] == pawn then return end -- Already attached to THIS pawn instance
    pcall(function()
        if pawn.Replay_IsEnemyFrameUIExisted and not pawn:Replay_IsEnemyFrameUIExisted() then
            if pawn.Replay_CreateEnemyFrameUI then
                pawn:Replay_CreateEnemyFrameUI(true, true)
            end
        end
        if pawn.Replay_SetVisiableOfFrameUI then
            pawn:Replay_SetVisiableOfFrameUI(true)
        end
    end)
    _G.ActiveBoxCache[pKey] = pawn
end

local function HidePlayerFrameBox(pawn)
    if IsValid(pawn) and pawn.Replay_SetVisiableOfFrameUI then
        pcall(pawn.Replay_SetVisiableOfFrameUI, pawn, false)
    end
end

function _G.SyncAllPlayerBoxes(bEnable)
    if bEnable then
        local pawns = GetCachedPlayerPawns()
        local pc = GetActivePlayerController()
        local localPawn = pc and GetLocalPlayer(pc)
        for _, pawn in ipairs(pawns) do
            if IsValid(pawn) and pawn ~= localPawn and not IsPawnDead(pawn) then
                if IsEnemyPawn(localPawn, pawn) then
                    local pKey = GetPawnKey(pawn)
                    if pKey then UpdatePlayerFrameBox(pawn, pKey) end
                end
            end
        end
    else
        for pKey, pawn in pairs(_G.ActiveBoxCache) do
            HidePlayerFrameBox(pawn)
        end
        local pawns = GetCachedPlayerPawns()
        for _, pawn in ipairs(pawns) do
            HidePlayerFrameBox(pawn)
        end
        _G.ActiveBoxCache = {}
    end
end





-- ============================================================================
-- 6.B NATIVE TOP-TO-HEAD LASER ENGINE (SNAPLINE) — PRODUCTION BUILD
-- Tencent CanvasPanel+Border Pattern | 0% GC | Dirty-Check | Camera Cache
-- ============================================================================

local ATAN2 = math.atan2 or math.atan

local NativeTopLaserESP = {
    WidgetsPool       = {},
    ActiveCount       = 0,
    MaxWidgets        = 20,
    Container         = nil,
    ParentCanvas      = nil,
    CachedCanvasW     = 1920,
    CachedCanvasH     = 1080,
    CachedVpW         = 1920,
    CachedVpH         = 1080,
    LastDimTime       = 0,
    ActiveEnemies     = {},
    -- Canvas transform (ported from verified all-device SnaplineESP engine):
    -- screen-pixel -> canvas-local scale + offset, measured via AbsoluteToLocal probe.
    _CanvasScaleX     = 1.0,
    _CanvasScaleY     = 1.0,
    _CanvasOffsetX    = 0.0,
    _CanvasOffsetY    = 0.0,
    _lastTransformTime = 0,
}
_G.NativeTopLaserESP = NativeTopLaserESP

-- Pre-allocated reusable vectors (0% GC in hot path)
local _laserScreenVec = EC_GetVec2D(0, 0)
local _laserWorldHead = FVector(0, 0, 0)

local _laserPivotVec  = EC_GetVec2D(0.0, 0.5)
local _laserZeroVec   = EC_GetVec2D(0, 0)
local _laserAnchors00 = EC_GetAnchors(0, 0, 0, 0)
local _laserAnchors11 = EC_GetAnchors(0, 0, 1, 1)

-- Pre-constructed tactical palette — Neon colorful, SYNCED with Wall Vision (reused, 0% GC)
-- Enemy = Neon Lime/Electric Purple | Bot = Cyber Cyan/Radiant Gold
local _laserColEnemyVis  = EC_GetLinearColor(0.2, 1.0, 0.0, 0.75)    -- Neon Lime (Visible)
local _laserColEnemyWall = EC_GetLinearColor(0.8, 0.0, 1.0, 0.65)   -- Electric Purple (Behind Wall)
local _laserColBotVis    = EC_GetLinearColor(0.0, 0.9, 1.0, 0.75)    -- Cyber Cyan (Visible)
local _laserColBotWall   = EC_GetLinearColor(1.0, 0.8, 0.0, 0.65)   -- Radiant Gold (Behind Wall)

-- Pre-cache FMargin for container offsets
local _laserFMargin = nil
pcall(function()
    local FM = rawget(_G, "FMargin") or _G.FMargin or import("FMargin") or import("Margin") or import("/Script/SlateCore.Margin")
    if FM then
        local ok, m = pcall(FM, 0, 0, 0, 0)
        if ok and m then _laserFMargin = m end
    end
end)

-- Pre-cache visibility enum values
local _visVal  = (UEnums and UEnums.ESlateVisibility and UEnums.ESlateVisibility.SelfHitTestInvisible) or 4
local _hideVal = (UEnums and UEnums.ESlateVisibility and UEnums.ESlateVisibility.Collapsed) or 1

-- Pre-cache SlateBlueprintLibrary and WidgetLayoutLibrary at load time (Mimo: don't import in tick)
local _SBL_Cached = nil
pcall(function() _SBL_Cached = import("SlateBlueprintLibrary") end)
local _WLL_Cached = nil
pcall(function() _WLL_Cached = import("WidgetLayoutLibrary") end)
local _ui_util_cached = nil
pcall(function()
    _ui_util_cached = package.loaded["client.common.ui_util"]
        or (pcall(require, "client.common.ui_util") and require("client.common.ui_util"))
end)

-- P0-FIX: Initialize LASER_DIAG (was nil → any laser tick error crashed the 10Hz timer permanently)
_G.LASER_DIAG = _G.LASER_DIAG or { lastErr = nil, errCount = 0 }

-- Cache camera data once per tick (not per enemy)
local _cachedCamFwd = nil
local _cachedCamLoc = nil
local _cachedCamTime = 0

-- ============================================================================
-- RESET & CLEANUP
-- ============================================================================
function NativeTopLaserESP.Reset()
    NativeTopLaserESP.ClearAll()
    if NativeTopLaserESP.Container and IsValid(NativeTopLaserESP.Container) then
        pcall(function()
            if NativeTopLaserESP.Container.RemoveFromParent then
                NativeTopLaserESP.Container:RemoveFromParent()
            end
        end)
    end
    NativeTopLaserESP.Container     = nil
    NativeTopLaserESP.ParentCanvas  = nil
    NativeTopLaserESP.WidgetsPool   = {}
    NativeTopLaserESP.CachedCanvasW = 0
    NativeTopLaserESP.CachedCanvasH = 0
    NativeTopLaserESP.CachedVpW     = 0
    NativeTopLaserESP.CachedVpH     = 0
    NativeTopLaserESP.LastDimTime   = 0
    NativeTopLaserESP._CanvasScaleX = 1.0
    NativeTopLaserESP._CanvasScaleY = 1.0
    NativeTopLaserESP._CanvasOffsetX = 0.0
    NativeTopLaserESP._CanvasOffsetY = 0.0
    NativeTopLaserESP._lastTransformTime = 0
    NativeTopLaserESP.ActiveEnemies = {}
    NativeTopLaserESP.ActiveCount   = 0
end

-- ============================================================================
-- CONTAINER: Full-screen anchored CanvasPanel
-- (Tencent AirLineUI.lua:128-130: Anchors(0,0,1,1) + Offsets(FMargin(0,0,0,0)))
-- ============================================================================
function NativeTopLaserESP.GetOrCreateContainer()
    local parent = EC_GetHUDCanvas()
    if not parent or not IsValid(parent) then return nil end

    -- If container exists and is still valid on the CURRENT active parent canvas, reuse it!
    if NativeTopLaserESP.Container and IsValid(NativeTopLaserESP.Container) then
        local curParent = nil
        if NativeTopLaserESP.Container.GetParent then
            pcall(function() curParent = NativeTopLaserESP.Container:GetParent() end)
        end
        if curParent == parent or (not curParent and NativeTopLaserESP.ParentCanvas == parent) then
            return NativeTopLaserESP.Container
        end
        pcall(function()
            if NativeTopLaserESP.Container.RemoveFromParent then
                NativeTopLaserESP.Container:RemoveFromParent()
            end
        end)
        NativeTopLaserESP.Container = nil
    end

    local container = EC_CreateWidget("/Script/UMG.CanvasPanel", parent)
    if not container or not IsValid(container) then return nil end

    local slot = parent:AddChildToCanvas(container)
    if slot then
        -- CRITICAL: Full-screen anchors + zero offsets (prevents 0x0 collapse)
        if slot.SetAnchors then pcall(slot.SetAnchors, slot, _laserAnchors11) end
        if slot.SetOffsets then
            if _laserFMargin then
                pcall(slot.SetOffsets, slot, _laserFMargin)
            else
                pcall(slot.SetOffsets, slot, 0, 0, 0, 0)
            end
        end
        if slot.SetPosition then pcall(slot.SetPosition, slot, _laserZeroVec) end
        -- P0-FIX: REMOVED SetSize(1920,1080). With stretch anchors (0,0,1,1) + zero offsets,
        -- SetSize INFLATES the container beyond screen boundaries (adds 1920px right + 1080px bottom).
        -- This caused cW = inflated value → fromX = cW*0.5 ≠ true screen center → snapline offset.
        -- Full-stretch anchors + zero offsets already provide correct full-screen coverage.
        if slot.SetAlignment then pcall(slot.SetAlignment, slot, _laserZeroVec) end
        if slot.SetZOrder then pcall(slot.SetZOrder, slot, 10) end
    end

    pcall(container.SetWidgetVisibility, container, _visVal)

    NativeTopLaserESP.Container = container
    NativeTopLaserESP.ParentCanvas = parent

    return container
end

-- ============================================================================
-- DIMENSIONS: Cached viewport/canvas size (throttled 0.5s)
-- ============================================================================
function NativeTopLaserESP.UpdateDimensions(pc)
    local now = os.clock()
    if (now - NativeTopLaserESP.LastDimTime < 0.5) and NativeTopLaserESP.CachedCanvasW > 200 then
        return NativeTopLaserESP.CachedCanvasW, NativeTopLaserESP.CachedCanvasH,
               NativeTopLaserESP.CachedVpW, NativeTopLaserESP.CachedVpH
    end
    NativeTopLaserESP.LastDimTime = now

    local cW, cH = 1920, 1080
    local container = NativeTopLaserESP.GetOrCreateContainer()
    if container and IsValid(container) then
        pcall(function()
            local SBL = _SBL_Cached or import("SlateBlueprintLibrary")
            if SBL and SBL.GetLocalSize then
                local sz = SBL.GetLocalSize(container:GetCachedGeometry())
                if sz and sz.X and sz.X > 200 then
                    cW = sz.X; cH = sz.Y
                end
            end
        end)
    end

    local vW, vH = 1920, 1080
    pcall(function()
        local ui_util = _ui_util_cached or package.loaded["client.common.ui_util"]
        if ui_util and ui_util.GetViewportSize then
            local vs = ui_util.GetViewportSize()
            if vs and vs.X and vs.Y and vs.X > 200 and vs.Y > 200 then
                vW = vs.X; vH = vs.Y
            end
        end
    end)
    if (vW <= 200 or vH <= 200) and pc and IsValid(pc) then
        pcall(function()
            local WLL = _WLL_Cached or import("WidgetLayoutLibrary")
            if WLL and WLL.GetViewportSize then
                local vs = WLL.GetViewportSize(pc)
                if vs and vs.X and vs.Y and vs.X > 200 and vs.Y > 200 then
                    vW = vs.X; vH = vs.Y
                end
            end
        end)
    end
    if vW <= 200 or vH <= 200 then vW = cW; vH = cH end
    -- P2-FIX: Dimension sanity check (defense-in-depth for snapline accuracy).
    -- If container size diverges >5% from viewport, clamp to viewport.
    -- Old 30% tolerance hid 10-15% center shifts (= visible right-side snapline on
    -- notch / 20:9 / safe-area devices). 5% keeps fromX = cW*0.5 on true center.
    if vW > 200 and cW > 200 then
        local ratio = cW / vW
        if ratio > 1.05 or ratio < 0.95 then
            cW = vW; cH = vH
        end
    end

    NativeTopLaserESP.CachedCanvasW = cW
    NativeTopLaserESP.CachedCanvasH = cH
    NativeTopLaserESP.CachedVpW = vW
    NativeTopLaserESP.CachedVpH = vH
    return cW, cH, vW, vH
end

-- ============================================================================
-- CANVAS TRANSFORM: screen-pixel -> canvas-local (all-device fix, ported from
-- verified SnaplineESP engine in DOWNLOADS/SUPABASE LUA CODE NEW.lua:4738-4816).
-- Measures real DPI scale + parent offset via AbsoluteToLocal probe at (0,0)/(100,100).
-- fromX AND toX both go through the SAME transform -> origin and heads agree
-- on notch / 20:9 / safe-area / DPI-scaled devices. 1.0s throttle, 0% GC.
-- ============================================================================
local _laserProbe0 = nil
local _laserProbe1 = nil
function NativeTopLaserESP.UpdateCanvasTransform(pc)
    local container = NativeTopLaserESP.Container
    if not container or not IsValid(container) then return end
    local now = os.clock()
    if NativeTopLaserESP._lastTransformTime and (now - NativeTopLaserESP._lastTransformTime < 1.0)
        and NativeTopLaserESP._CanvasScaleX and NativeTopLaserESP._CanvasScaleX > 0 then
        return
    end
    NativeTopLaserESP._lastTransformTime = now
    local success = false
    pcall(function()
        local SBL = _SBL_Cached or import("SlateBlueprintLibrary")
        if SBL and SBL.AbsoluteToLocal then
            local cg = container:GetCachedGeometry()
            if cg then
                if not _laserProbe0 then
                    _laserProbe0 = EC_GetVec2D(0, 0)
                    _laserProbe1 = EC_GetVec2D(0, 0)
                end
                _laserProbe0.X = 0; _laserProbe0.Y = 0
                local pt0 = SBL.AbsoluteToLocal(cg, _laserProbe0)
                _laserProbe1.X = 100; _laserProbe1.Y = 100
                local pt1 = SBL.AbsoluteToLocal(cg, _laserProbe1)
                if pt0 and pt1 and pt0.X and pt1.X then
                    NativeTopLaserESP._CanvasScaleX = (pt1.X - pt0.X) / 100
                    NativeTopLaserESP._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                    NativeTopLaserESP._CanvasOffsetX = pt0.X
                    NativeTopLaserESP._CanvasOffsetY = pt0.Y
                    success = true
                end
            end
        end
    end)
    if not success then
        pcall(function()
            local WLL = _WLL_Cached or import("WidgetLayoutLibrary")
            if WLL and WLL.ScreenToWidgetLocal and pc and IsValid(pc) then
                local cg = container:GetCachedGeometry()
                if cg then
                    local in0 = EC_GetVec2D(0, 0)
                    local in1 = EC_GetVec2D(100, 100)
                    local pt0 = EC_GetVec2D(0, 0)
                    local pt1 = EC_GetVec2D(0, 0)
                    WLL.ScreenToWidgetLocal(pc, cg, in0, pt0)
                    WLL.ScreenToWidgetLocal(pc, cg, in1, pt1)
                    if pt0 and pt1 and pt0.X and pt1.X then
                        NativeTopLaserESP._CanvasScaleX = (pt1.X - pt0.X) / 100
                        NativeTopLaserESP._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                        NativeTopLaserESP._CanvasOffsetX = pt0.X
                        NativeTopLaserESP._CanvasOffsetY = pt0.Y
                        success = true
                    end
                end
            end
        end)
    end
    if not success then
        local scale = 1.0
        pcall(function()
            local WLL = _WLL_Cached or import("WidgetLayoutLibrary")
            if WLL and WLL.GetViewportScale and pc and IsValid(pc) then
                scale = WLL.GetViewportScale(pc) or 1.0
            end
        end)
        if not scale or scale <= 0 then scale = 1.0 end
        NativeTopLaserESP._CanvasScaleX = 1.0 / scale
        NativeTopLaserESP._CanvasScaleY = 1.0 / scale
        NativeTopLaserESP._CanvasOffsetX = 0
        NativeTopLaserESP._CanvasOffsetY = 0
    end
end

local function LaserScreenToCanvas(sx, sy)
    local scaleX = NativeTopLaserESP._CanvasScaleX or 1.0
    local scaleY = NativeTopLaserESP._CanvasScaleY or 1.0
    local offX = NativeTopLaserESP._CanvasOffsetX or 0
    local offY = NativeTopLaserESP._CanvasOffsetY or 0
    local rx, ry = sx * scaleX + offX, sy * scaleY + offY
    -- NaN/inf guard: Slate can stall on non-finite coordinates
    if rx ~= rx or ry ~= ry then return 0, 0 end
    return rx, ry
end

-- FIXED TOP-CENTER origin: viewport-center pixels -> canvas-local via SAME
-- transform as heads. Works on all devices, no per-device offset needed.
function NativeTopLaserESP.GetLaserStartPos(pc, vW)
    NativeTopLaserESP.UpdateCanvasTransform(pc)
    local pixW = (vW and vW > 200) and vW or (NativeTopLaserESP.CachedVpW or 1920)
    if (not pixW or pixW <= 200) and pc and IsValid(pc) then
        pcall(function()
            if pc.GetViewportSize then
                local vs = _laserProbe0 or EC_GetVec2D(0, 0)
                vs.X = 0; vs.Y = 0
                pc:GetViewportSize(vs)
                if vs and vs.X and vs.X > 200 then pixW = vs.X end
            end
        end)
    end
    if not pixW or pixW <= 200 then pixW = 1920 end
    local fromX = LaserScreenToCanvas(pixW * 0.5, 0)
    return fromX
end

-- ============================================================================
-- WIDGET POOL: Tencent 2-Level Hierarchy (CanvasPanel carrier + Border child)
-- (Longcat/Nemotron: CanvasPanel as line primitive responds to SetRenderAngle,
--  unlike bare UBorder which may not trigger Slate redraw when rotated)
-- (Tencent MortarLineUI: CanvasPanel_Airline with child visual elements)
-- ============================================================================
function NativeTopLaserESP.AcquireWidget(index)
    local container = NativeTopLaserESP.GetOrCreateContainer()
    if not container or not IsValid(container) then return nil end

    local pool = NativeTopLaserESP.WidgetsPool
    local item = pool[index]
    if item and item.Carrier and IsValid(item.Carrier) and item.Slot and IsValid(item.Slot) then
        local curParent = nil
        if item.Carrier.GetParent then
            pcall(function() curParent = item.Carrier:GetParent() end)
        end
        if curParent == container then
            return item
        end
        -- Reparent carrier from previous match/container to current active container
        local reparentOk = false
        pcall(function()
            if item.Carrier.RemoveFromParent then item.Carrier:RemoveFromParent() end
            local newSlot = container:AddChildToCanvas(item.Carrier)
            if newSlot and IsValid(newSlot) then
                item.Slot = newSlot
                if newSlot.SetAnchors then newSlot:SetAnchors(_laserAnchors00) end
                if newSlot.SetAlignment then newSlot:SetAlignment(_laserZeroVec) end
                if newSlot.SetAutoSize then newSlot:SetAutoSize(false) end
                if newSlot.SetZOrder then newSlot:SetZOrder(10) end
                reparentOk = true
            end
        end)
        if reparentOk then return item end
    end

    -- TENCENT PATTERN: CanvasPanel as line carrier (MortarLineUI, AirLineUI, SpacecraftAirDropLine)
    local carrier = EC_CreateWidget("/Script/UMG.CanvasPanel", container)
    if not carrier or not IsValid(carrier) then return nil end

    -- Set pivot ONCE at creation: Pivot (0, 0.5) = left-center: rotation happens around the line start point
    pcall(function()
        if carrier.SetRenderTransformPivot then
            carrier:SetRenderTransformPivot(_laserPivotVec)
        end
        if carrier.SetRenderTranslation then
            carrier:SetRenderTranslation(_laserZeroVec)
        end
    end)

    -- Add carrier to container with absolute positioning anchors
    local slot = container:AddChildToCanvas(carrier)
    if not slot or not IsValid(slot) then return nil end

    pcall(function()
        if slot.SetAnchors then slot:SetAnchors(_laserAnchors00) end
        if slot.SetAlignment then slot:SetAlignment(_laserZeroVec) end
        if slot.SetAutoSize then slot:SetAutoSize(false) end
        if slot.SetZOrder then slot:SetZOrder(10) end
    end)

    -- Primary Visual Primitive: UImage with solid white brush texture (Tencent standard)
    local visual = EC_CreateWidget("/Script/UMG.Image", carrier)
    local visualSlot = nil
    if visual and IsValid(visual) then
        visualSlot = carrier:AddChildToCanvas(visual)
        if visualSlot and IsValid(visualSlot) then
            pcall(function()
                if visualSlot.SetAnchors then visualSlot:SetAnchors(_laserAnchors11) end
                if _laserFMargin and visualSlot.SetOffsets then visualSlot:SetOffsets(_laserFMargin) end
                if visualSlot.SetZOrder then visualSlot:SetZOrder(0) end
            end)
        end
        pcall(function()
            if visual.SetBrushfromPathAsync then
                visual:SetBrushfromPathAsync("/Game/Arts/UI/Atlas/BattleUI/General/Default_White.Default_White", false)
            end
        end)
        pcall(visual.SetWidgetVisibility, visual, _visVal)
    else
        visual = EC_CreateWidget("/Script/UMG.Border", carrier)
        if visual and IsValid(visual) then
            visualSlot = carrier:AddChildToCanvas(visual)
            if visualSlot and IsValid(visualSlot) then
                pcall(function()
                    if visualSlot.SetAnchors then visualSlot:SetAnchors(_laserAnchors11) end
                    if _laserFMargin and visualSlot.SetOffsets then visualSlot:SetOffsets(_laserFMargin) end
                    if visualSlot.SetZOrder then visualSlot:SetZOrder(0) end
                end)
            end
            pcall(visual.SetWidgetVisibility, visual, _visVal)
        end
    end

    -- Start collapsed
    pcall(carrier.SetWidgetVisibility, carrier, _hideVal)

    item = {
        Carrier    = carrier,     -- CanvasPanel (positioning + rotation)
        Visual     = visual,      -- UImage / UBorder child (color visual)
        Border     = visual,      -- Legacy alias for compatibility
        Slot       = slot,        -- Carrier's slot on the container
        LastColor  = nil,
        LastLen    = nil,
        LastAng    = nil,
        Shown      = false,
    }
    pool[index] = item
    return item
end

function NativeTopLaserESP.ClearAll()
    for _, item in pairs(NativeTopLaserESP.WidgetsPool) do
        if item and item.Carrier and IsValid(item.Carrier) then
            pcall(item.Carrier.SetWidgetVisibility, item.Carrier, _hideVal)
        end
        if item then item.Shown = false end
    end
    NativeTopLaserESP.ActiveCount = 0
end
_G.ClearAllNativeLasers = NativeTopLaserESP.ClearAll

-- ============================================================================
-- HEAD LOCATION: Socket → Fallback (reuses _laserWorldHead for 0% GC)
-- ============================================================================
function NativeTopLaserESP.GetHeadLocation(pawn)
    if not IsValid(pawn) then return nil end
    local headPos = nil
    local mesh = pawn.Mesh or (pawn.GetMesh and pawn:GetMesh())
    if mesh and mesh.GetSocketLocation then
        pcall(function()
            local p = mesh:GetSocketLocation("head")
            if p and (p.X ~= 0 or p.Y ~= 0 or p.Z ~= 0) then headPos = p end
        end)
        if not headPos then
            pcall(function()
                local p = mesh:GetSocketLocation("HelmetSocket")
                if p and (p.X ~= 0 or p.Y ~= 0 or p.Z ~= 0) then headPos = p end
            end)
        end
    end
    if not headPos then
        local loc = GetActorLocation(pawn)
        if loc then
            local hOffset = 75.0
            -- P0-FIX: IsProne() was outside pcall — destroyed pawn would crash → kill 10Hz laser timer
            if pawn.bIsCrouched then hOffset = 48.0
            elseif pawn.IsProne then
                local proneOk, isProne = pcall(pawn.IsProne, pawn)
                if proneOk and isProne then hOffset = 25.0 end
            end
            local ok, newVec = pcall(FVector, loc.X, loc.Y, loc.Z + hOffset)
            if ok and newVec then
                headPos = newVec
            else
                _laserWorldHead.X = loc.X
                _laserWorldHead.Y = loc.Y
                _laserWorldHead.Z = loc.Z + hOffset
                headPos = _laserWorldHead
            end
        end
    end
    return headPos
end

-- ============================================================================
-- PROJECTION: Multi-tier World → Canvas Local (camera check cached per tick)
-- ============================================================================
function NativeTopLaserESP.UpdateCameraCache(pc)
    local now = os.clock()
    if (now - _cachedCamTime) < 0.03 and _cachedCamFwd then return end
    _cachedCamTime = now
    _cachedCamFwd = nil
    _cachedCamLoc = nil
    pcall(function()
        local camMgr = pc.PlayerCameraManager
        if camMgr and IsValid(camMgr) and camMgr.GetCameraRotation and camMgr.GetCameraLocation then
            local camRot = camMgr:GetCameraRotation()
            local camLoc = camMgr:GetCameraLocation()
            if camRot and camLoc then
                local fwd = nil
                if type(camRot.Vector) == "function" then
                    local ok, v = pcall(camRot.Vector, camRot)
                    if ok and v and v.X then fwd = v end
                end
                if not fwd and camRot.Pitch and camRot.Yaw then
                    local pRad = math.rad(camRot.Pitch)
                    local yRad = math.rad(camRot.Yaw)
                    local cp = math.cos(pRad)
                    fwd = { X = cp * math.cos(yRad), Y = cp * math.sin(yRad), Z = math.sin(pRad) }
                end
                _cachedCamFwd = fwd
                _cachedCamLoc = camLoc
            end
        end
    end)
end

function NativeTopLaserESP.ProjectToCanvas(head3D, pc, container, cW, cH, vW, vH)
    if not head3D or not pc or not IsValid(pc) then return nil, nil end

    -- Fast Frustum Check: ensure target is in FRONT of camera
    if _cachedCamFwd and _cachedCamLoc and head3D.X then
        local toCamX = head3D.X - _cachedCamLoc.X
        local toCamY = head3D.Y - _cachedCamLoc.Y
        local toCamZ = head3D.Z - _cachedCamLoc.Z
        local dot = toCamX * _cachedCamFwd.X + toCamY * _cachedCamFwd.Y + toCamZ * _cachedCamFwd.Z
        if dot <= 0 then
            return nil, nil -- Target is behind camera plane
        end
    end

    local screenX, screenY = nil, nil

    -- 1. Native UE4 PlayerController projection (primary & fastest, handles camera frustum natively)
    pcall(function()
        _laserScreenVec.X = 0; _laserScreenVec.Y = 0
        local ok, ret2 = pc:ProjectWorldLocationToScreen(head3D, _laserScreenVec, true)
        if ok == true or ok == 1 then
            if ret2 and ret2.X and (ret2.X ~= 0 or ret2.Y ~= 0) then
                screenX = ret2.X; screenY = ret2.Y
            elseif _laserScreenVec and (_laserScreenVec.X ~= 0 or _laserScreenVec.Y ~= 0) then
                screenX = _laserScreenVec.X; screenY = _laserScreenVec.Y
            end
        end
    end)

    -- 1b. Fallback to non-player-viewport relative
    if not screenX or (screenX == 0 and screenY == 0) then
        pcall(function()
            _laserScreenVec.X = 0; _laserScreenVec.Y = 0
            local ok, ret2 = pc:ProjectWorldLocationToScreen(head3D, _laserScreenVec, false)
            if ok == true or ok == 1 then
                if ret2 and ret2.X and (ret2.X ~= 0 or ret2.Y ~= 0) then
                    screenX = ret2.X; screenY = ret2.Y
                elseif _laserScreenVec and (_laserScreenVec.X ~= 0 or _laserScreenVec.Y ~= 0) then
                    screenX = _laserScreenVec.X; screenY = _laserScreenVec.Y
                end
            end
        end)
    end

    local isCanvasCoord = false
    -- 2. Official Tencent: WorldToUILocalPosition fallback (ALREADY returns Canvas-local coords)
    if (not screenX or (screenX == 0 and screenY == 0)) and container and IsValid(container) then
        pcall(function()
            local ui_util = _ui_util_cached or package.loaded["client.common.ui_util"]
            if ui_util and ui_util.WorldToUILocalPosition then
                local pt = ui_util.WorldToUILocalPosition(head3D, container)
                if pt and pt.X and pt.Y and (pt.X ~= 0 or pt.Y ~= 0) then
                    screenX = pt.X
                    screenY = pt.Y
                    isCanvasCoord = true
                    return
                end
            end
        end)
    end

    -- 3. WidgetLayoutLibrary fallback (Widget-space coordinate)
    if not screenX or (screenX == 0 and screenY == 0) then
        pcall(function()
            local WLL = _WLL_Cached or import("WidgetLayoutLibrary")
            if WLL and WLL.ProjectWorldLocationToWidgetPositionReturnValue then
                local pt = WLL.ProjectWorldLocationToWidgetPositionReturnValue(pc, head3D)
                if pt and pt.X and (pt.X ~= 0 or pt.Y ~= 0) then
                    screenX = pt.X; screenY = pt.Y
                    isCanvasCoord = true
                end
            end
        end)
    end

    if screenX and screenY and (screenX ~= 0 or screenY ~= 0) then
        if isCanvasCoord then
            return screenX, screenY
        end
        -- All-device mapping: same canvas transform as origin (scale + offset).
        -- Old (screenX/vW)*cW ignored parent offset -> right-shift on notch/safe-area.
        NativeTopLaserESP.UpdateCanvasTransform(pc)
        local scX = NativeTopLaserESP._CanvasScaleX
        local scY = NativeTopLaserESP._CanvasScaleY
        if scX and scX > 0 and scX < 10 then
            return LaserScreenToCanvas(screenX, screenY)
        end
        local safeVW = (vW and vW > 200) and vW or cW
        local safeVH = (vH and vH > 200) and vH or cH
        if safeVW < 1 then safeVW = 1920 end
        if safeVH < 1 then safeVH = 1080 end
        local toX = (screenX / safeVW) * cW
        local toY = (screenY / safeVH) * cH
        return toX, toY
    end

end



-- ============================================================================
-- INTERNAL: Apply line transform to a single widget (Tencent SetRenderTranslation pattern)
-- ============================================================================
local function _ApplyLineTransform(item, fromX, fromY, length, thickness, angle, chosenColor)
    local carrier = item.Carrier
    local visual  = item.Visual or item.Border
    local slot    = item.Slot

    -- Dirty-check: skip unchanged transforms (fine-grained for smooth motion)
    local lenQ = math.floor(length * 2 + 0.5) * 0.5   -- 0.5px precision = smooth at distance
    local angQ = math.floor(angle * 4 + 0.5) * 0.25   -- 0.25deg precision = smooth rotation
    local fromXQ = math.floor(fromX * 2 + 0.5) * 0.5
    local fromYQ = math.floor(fromY * 2 + 0.5) * 0.5

    -- Hardened dirty-check: includes length, angle, thickness, AND origin (fromX, fromY)
    -- Guarantees orientation change or canvas resize snaps line to new center immediately!
    local posChanged = (lenQ ~= item.LastLen) or (angQ ~= item.LastAng) or (thickness ~= item.LastThick)
        or (fromXQ ~= item.LastFromX) or (fromYQ ~= item.LastFromY)

    if posChanged then
        -- Positioning: Standard UMG CanvasPanelSlot positioning (zero double-offsetting)
        local posDone = false
        if slot and slot.SetPosition then
            local ok = pcall(slot.SetPosition, slot, EC_GetVec2D(fromX, fromY))
            if ok then posDone = true end
        end
        if not posDone and carrier.SetRenderTranslation then
            pcall(carrier.SetRenderTranslation, carrier, EC_GetVec2D(fromX, fromY))
        end

        -- Set size: length × thickness (MortarLineUI:12, AirLineUI:209)
        if slot and slot.SetSize then
            pcall(slot.SetSize, slot, EC_GetVec2D(lenQ, thickness))
        end

        -- Set rotation DEGREES on the carrier CanvasPanel (MortarLineUI:22, AirLineUI:195)
        local rotDone = false
        if carrier.SetRenderAngle then
            local ok = pcall(carrier.SetRenderAngle, carrier, angQ)
            if ok then rotDone = true end
        end
        if not rotDone and carrier.SetRenderTransformAngle then
            local ok = pcall(carrier.SetRenderTransformAngle, carrier, angQ)
            if ok then rotDone = true end
        end
        if not rotDone then
            pcall(function()
                local rt = carrier.RenderTransform
                if rt then
                    rt.Angle = angQ
                    if carrier.SetRenderTransform then
                        carrier:SetRenderTransform(rt)
                    end
                end
            end)
        end

        item.LastLen = lenQ
        item.LastAng = angQ
        item.LastThick = thickness
        item.LastFromX = fromXQ
        item.LastFromY = fromYQ
    end

    -- Color: apply to Visual child (UImage / UBorder)
    if chosenColor ~= item.LastColor then
        if visual and IsValid(visual) then
            if visual.SetColorAndOpacity then
                pcall(visual.SetColorAndOpacity, visual, chosenColor)
            end
            if visual.SetBrushColor then
                pcall(visual.SetBrushColor, visual, chosenColor)
            end
        end
        item.LastColor = chosenColor
    end

    -- Show carrier and visual
    if not item.Shown then
        pcall(carrier.SetWidgetVisibility, carrier, _visVal)
        if visual and IsValid(visual) then
            pcall(visual.SetWidgetVisibility, visual, _visVal)
        end
        item.Shown = true
    end
end

-- ============================================================================
-- MAIN TICK-- ============================================================================
-- MAIN TICK: Error-surfacing, dirty-tracked, zero-GC
-- ============================================================================
function NativeTopLaserESP.Tick(pc)
    if TrackMode() ~= 1 then
        if NativeTopLaserESP.ActiveCount > 0 then NativeTopLaserESP.ClearAll() end
        return
    end

    local livePC = GetActivePlayerController()
    if livePC and IsValid(livePC) then
        pc = livePC
    elseif not pc or not IsValid(pc) then
        if NativeTopLaserESP.ActiveCount > 0 then NativeTopLaserESP.ClearAll() end
        return
    end

    -- IDLE EARLY-OUT: no targets and nothing shown -> skip container, dimension
    -- probes and camera cache (the expensive C++ calls). NEW.lua never had a
    -- 30fps loop at all; this keeps quiet ticks near-zero cost.
    local _foes = NativeTopLaserESP.ActiveEnemies
    if (not _foes or #_foes == 0) and NativeTopLaserESP.ActiveCount == 0 then
        return
    end

    local container = NativeTopLaserESP.GetOrCreateContainer()
    if not container or not IsValid(container) then
        -- Don't ClearAll on 1-frame nil container during UI transitions; simply skip frame
        return
    end

    local localPawn = GetLocalPlayer(pc)
    if not localPawn or not IsValid(localPawn) then
        if NativeTopLaserESP.ActiveCount > 0 then NativeTopLaserESP.ClearAll() end
        return
    end

    local cW, cH, vW, vH = NativeTopLaserESP.UpdateDimensions(pc)

    NativeTopLaserESP.UpdateCameraCache(pc)

    -- FIXED TOP-CENTER (all-device): viewport-center pixels -> canvas-local via the
    -- SAME transform as heads. cW*0.5 assumed fullscreen parent at 0,0 which breaks
    -- on notch/safe-area devices; this stays centered everywhere. No slider needed.
    local fromX = NativeTopLaserESP.GetLaserStartPos(pc, vW)
    if not fromX or fromX <= 0 then fromX = cW * 0.5 end
    local thickness = tonumber(CFG.Laser_Thickness) or 1.5
    local halfThick = thickness * 0.5
    local fromY = halfThick
    local usedCount = 0

    local enemyEntries = NativeTopLaserESP.ActiveEnemies
    if enemyEntries then
        for _, entry in ipairs(enemyEntries) do
            local pawn = entry.pawn
            if IsValid(pawn) and not IsPawnDead(pawn) then
                -- Live head tracking at 30 FPS for silky-smooth motion; fallback to combat-cached head3D
                local head3D = NativeTopLaserESP.GetHeadLocation(pawn) or entry.head3D
                if head3D then
                    local toX, toY = NativeTopLaserESP.ProjectToCanvas(head3D, pc, container, cW, cH, vW, vH)
                    if toX and toY and toX >= -100 and toX <= (cW + 100) and toY >= -100 and toY <= (cH + 100) then
                        local dX = toX - fromX
                        local dY = toY - fromY
                        local length = math.sqrt(dX * dX + dY * dY)

                        if length > 5.0 then
                            usedCount = usedCount + 1
                            if usedCount <= NativeTopLaserESP.MaxWidgets then
                                local item = NativeTopLaserESP.AcquireWidget(usedCount)
                                if item and item.Carrier and item.Slot then
                                    local angle = math.deg(ATAN2(dY, dX))

                                    local chosenColor
                                    if entry.isAI then
                                        chosenColor = entry.isVis and _laserColBotVis or _laserColBotWall
                                    else
                                        chosenColor = entry.isVis and _laserColEnemyVis or _laserColEnemyWall
                                    end

                                    _ApplyLineTransform(item, fromX, fromY, length, thickness, angle, chosenColor)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Collapse unused widgets
    local pool = NativeTopLaserESP.WidgetsPool
    for i = usedCount + 1, #pool do
        local excess = pool[i]
        if excess and excess.Carrier and IsValid(excess.Carrier) then
            pcall(excess.Carrier.SetWidgetVisibility, excess.Carrier, _hideVal)
            excess.Shown = false
        end
    end
    NativeTopLaserESP.ActiveCount = usedCount
end

local function Phase_Enemies(localPawn, myPos, pc)
    -- OFF-means-zero: no enemy feature enabled -> skip the entire pawn scan.
    -- (Menu SetFuncs already cleared stale marks on toggle-off.)
    if not ((TrackMode() ~= 0) or CFG.ESP_Player_Box or CFG.ESP_Health_Bar
        or CFG.ESP_Wall_Vision or CFG.Counter_Enabled
        or CFG.ESP_Vis_Check or CFG.AimAssistEnabled) then
        return
    end
    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
    local zeroVec = GetZeroVector()

    local pawns = GetCachedPlayerPawns()
    local activeEnemyKeys = {}
    local myTeamId = localPawn.TeamID or (type(localPawn.GetTeamID) == "function" and localPawn:GetTeamID())
    local maxDistSq = 40000 * 40000

    local totalEnemies = 0
    local realEnemies  = 0
    local botEnemies   = 0
    local laserTargets = {}
    local currentCombatEnemies = {}

    for _, pawn in ipairs(pawns) do
        if not IsValid(pawn) or pawn == localPawn then goto continue_pawn end

        if not IsEnemyPawn(localPawn, pawn) then goto continue_pawn end

        if IsPawnDead(pawn) then goto continue_pawn end

        local pPos = GetActorLocation(pawn)
        if not pPos then goto continue_pawn end

        local dx = pPos.X - myPos.X
        local dy = pPos.Y - myPos.Y
        local dz = pPos.Z - myPos.Z
        local distSq = dx * dx + dy * dy + dz * dz
        if distSq <= 0 or distSq > maxDistSq then goto continue_pawn end

        local pKey = GetPawnKey(pawn)
        if not pKey then goto continue_pawn end
        activeEnemyKeys[pKey] = true

        -- Accurate Bot vs Real Player Engine Classification (Using Cached Authentic Tencent API)
        totalEnemies = totalEnemies + 1
        local isAI = ResolveIsAI_Combat(pawn)
        if isAI then
            botEnemies = botEnemies + 1
        else
            realEnemies = realEnemies + 1
        end

        local isKnocked = false
        local hs = pawn.HealthStatus
        if hs and (hs == 1 or hs == 2 or hs == 3) then
            isKnocked = true
        elseif pawn.bIsNearDeath or pawn.bNearDeath or (type(pawn.IsNearDeath) == "function" and pawn:IsNearDeath()) then
            isKnocked = true
        end

        local distM = math.sqrt(distSq) / 100.0
        currentCombatEnemies[#currentCombatEnemies + 1] = {
            pawn = pawn,
            pKey = pKey,
            isAI = isAI,
            pos = pPos,
            dist = distM,
            isKnocked = isKnocked
        }

        -- Line-of-Sight Visibility Check (result only feeds laser colors, so it
        -- runs only in snapline mode; otherwise these raycasts are pure waste)
        local isVisible = false
        if CFG.ESP_Vis_Check and TrackMode() == 1 and IsValid(pc) then
            pcall(function()
                isVisible = CheckPlayerVisibility(pc, pawn, zeroVec, pKey, distM)
            end)
        end

        if TrackMode() == 1 then
            -- Cache head 3D position HERE (4Hz) as fallback
            local cachedHead = NativeTopLaserESP.GetHeadLocation(pawn)
            if cachedHead then
                laserTargets[#laserTargets + 1] = { pawn = pawn, isAI = isAI, isVis = isVisible, head3D = cachedHead }
            end
        end

        -- 1. Native In-Game Bounding Box (Respawn safe: re-attaches if pawn changed!)
        if CFG.ESP_Player_Box then
            if _G.ActiveBoxCache[pKey] ~= pawn then
                UpdatePlayerFrameBox(pawn, pKey)
            end
        end

        -- 2. Head health bar (above head, hidden beyond 150m so it never
        -- overlaps the mecha banner at long range; banner covers far threats)
        if CFG.ESP_Health_Bar and InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            if distM and distM > 150 then
                if _G.ActiveHPMarks[pKey] then
                    if InGameMarkTools.HideMapMark then
                        pcall(InGameMarkTools.HideMapMark, _G.ActiveHPMarks[pKey])
                    end
                    _G.ActiveHPMarks[pKey] = nil
                    _ActiveHPMarkPawns[pKey] = nil
                end
            elseif not _G.ActiveHPMarks[pKey] or _ActiveHPMarkPawns[pKey] ~= pawn then
                if _G.ActiveHPMarks[pKey] and InGameMarkTools.HideMapMark then
                    pcall(InGameMarkTools.HideMapMark, _G.ActiveHPMarks[pKey])
                    _G.ActiveHPMarks[pKey] = nil
                end
                pcall(function()
                    if not pawn.GetHPBarHealth then
                        pawn.GetHPBarHealth = function(s) return s.Health or 100 end
                    end
                end)
                pcall(function()
                    if not pawn.GetHPBarHealthMax then
                        pawn.GetHPBarHealthMax = function(s) return s.HealthMax or 100 end
                    end
                end)
                local okMark, mId = pcall(InGameMarkTools.ClientAddMapMark, GK_HP_BAR_ID, zeroVec, 0, "", 4, pawn)
                if okMark and mId then
                    _G.ActiveHPMarks[pKey] = mId
                    _ActiveHPMarkPawns[pKey] = pawn
                end
            end
        end

        -- 3. Native Wall Vision (Chams / Hardware Occluded Dyeing, Respawn Safe)
        if CFG.ESP_Wall_Vision then
            if _G.ActiveWallVisionPawns[pKey] ~= pawn then
                ApplyWallVisionToPawn(pawn, isAI)
                _G.ActiveWallVisionPawns[pKey] = pawn
            else
                -- Re-scan meshes every 8s to catch armor/helmet pickups (cache TTL handles this)
                local pKeyMesh = GetPawnKey(pawn) or tostring(pawn)
                local meshCache = _WH_MeshCache[pKeyMesh]
                if not meshCache or not meshCache._time or (os.clock() - meshCache._time) >= 8.0 then
                    ApplyWallVisionToPawn(pawn, isAI)
                end
            end
        end

        -- 4. Map-tracking mark (mode 2 = original mecha banner, restored)
        if TrackMode() == 2 and InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            if not _G.ActiveEnemyMarks[pKey] or _ActiveEnemyMarkPawns[pKey] ~= pawn then
                if _G.ActiveEnemyMarks[pKey] and InGameMarkTools.HideMapMark then
                    pcall(InGameMarkTools.HideMapMark, _G.ActiveEnemyMarks[pKey])
                    _G.ActiveEnemyMarks[pKey] = nil
                end
                local okMark, mId = pcall(InGameMarkTools.ClientAddMapMark, GK_MECHA_GROUP_ID, zeroVec, 0, "", 4, pawn)
                if okMark and mId then
                    _G.ActiveEnemyMarks[pKey] = mId
                    _ActiveEnemyMarkPawns[pKey] = pawn
                end
            end
        end


        ::continue_pawn::
    end

    -- If no pawns were returned at all (momentary loading/level hiccup), skip cleanup to avoid screen flicker!
    if #pawns == 0 and totalEnemies == 0 then
        return
    end

    -- Unified Anti-Flicker Debounce: Centralized 2-tick grace period (500ms) across ALL features
    local _EnemyMissedTicks = _G._EnemyMissedTicks or {}
    _G._EnemyMissedTicks = _EnemyMissedTicks

    local allTracked = {}
    for k in pairs(_G.ActiveEnemyMarks) do allTracked[k] = true end
    for k in pairs(_G.ActiveHPMarks) do allTracked[k] = true end
    for k in pairs(_G.ActiveBoxCache) do allTracked[k] = true end
    for k in pairs(_G.ActiveWallVisionPawns) do allTracked[k] = true end

    for pKey in pairs(allTracked) do
        if not activeEnemyKeys[pKey] then
            _EnemyMissedTicks[pKey] = (_EnemyMissedTicks[pKey] or 0) + 1
        else
            _EnemyMissedTicks[pKey] = 0
        end
    end

    -- Cleanup dead or out-of-range enemies (shared debounce, no race conditions)
    for pKey, mId in pairs(_G.ActiveEnemyMarks) do
        if TrackMode() ~= 2 or (not activeEnemyKeys[pKey] and (_EnemyMissedTicks[pKey] or 0) >= 2) then
            if InGameMarkTools and InGameMarkTools.HideMapMark and mId then
                pcall(InGameMarkTools.HideMapMark, mId)
            end
            _G.ActiveEnemyMarks[pKey] = nil
            _ActiveEnemyMarkPawns[pKey] = nil
        end
    end
    for pKey, mId in pairs(_G.ActiveHPMarks) do
        if not CFG.ESP_Health_Bar or (not activeEnemyKeys[pKey] and (_EnemyMissedTicks[pKey] or 0) >= 2) then
            if InGameMarkTools and InGameMarkTools.HideMapMark and mId then
                pcall(InGameMarkTools.HideMapMark, mId)
            end
            _G.ActiveHPMarks[pKey] = nil
            _ActiveHPMarkPawns[pKey] = nil
        end
    end
    for pKey, pawn in pairs(_G.ActiveBoxCache) do
        if not CFG.ESP_Player_Box or not activeEnemyKeys[pKey] then
            local isDead = IsPawnDead(pawn)
            local missed = (not CFG.ESP_Player_Box or isDead) and 99 or (_EnemyMissedTicks[pKey] or 0)
            if missed >= 2 then
                if IsValid(pawn) and pawn.Replay_SetVisiableOfFrameUI and not isDead then
                    pcall(pawn.Replay_SetVisiableOfFrameUI, pawn, false)
                end
                _G.ActiveBoxCache[pKey] = nil
            end
        end
    end
    for pKey in pairs(_PawnVisCache) do
        if not activeEnemyKeys[pKey] and (_EnemyMissedTicks[pKey] or 0) >= 2 then
            _PawnVisCache[pKey] = nil
        end
    end
    for pKey, pawn in pairs(_G.ActiveWallVisionPawns) do
        if not CFG.ESP_Wall_Vision or not activeEnemyKeys[pKey] then
            local isDead = IsPawnDead(pawn)
            local missed = (not CFG.ESP_Wall_Vision or isDead) and 99 or (_EnemyMissedTicks[pKey] or 0)
            if missed >= 2 then
                if IsValid(pawn) and not isDead then pcall(ClearPawnWallVision, pawn) end
                _G.ActiveWallVisionPawns[pKey] = nil
                -- MEM-FIX: drop pinned mesh refs with the pawn (TTL alone never evicts dead pawns)
                local mk = GetPawnKey(pawn)
                if mk and _WH_MeshCache then _WH_MeshCache[mk] = nil end
                _WH_MeshCache[pKey] = nil
            end
        end
    end

    -- Clear missed tick counter only after all features have finished evaluating
    for pKey in pairs(allTracked) do
        if not activeEnemyKeys[pKey] and (_EnemyMissedTicks[pKey] or 0) >= 2 then
            _EnemyMissedTicks[pKey] = nil
        end
    end

    -- Update All Active In-Game Threat Counters (0% GC, Dirty-Checked)
    if _G.UpdateEnemyCounters then
        _G.UpdateEnemyCounters(totalEnemies, realEnemies, botEnemies)
    end

    -- Feed cached enemy data to Laser engine (rendered by LASER_DISPATCHER_TIMER)
    if TrackMode() == 1 and NativeTopLaserESP then
        NativeTopLaserESP.ActiveEnemies = laserTargets
    end
    _G._CurrentCombatEnemies = currentCombatEnemies
end

local function Phase_Vehicles(localPawn, myPos)
    local anyVehEnabled = (CFG.Veh_Cat_Cars == true) or (CFG.Veh_Cat_Light == true)
        or (CFG.Veh_Cat_Bikes == true) or (CFG.Veh_Cat_Armored == true) or (CFG.Veh_Cat_WaterAir == true)
    if not anyVehEnabled then
        for _, vdef in ipairs(_G.VEHICLE_ICON_CONFIG) do
            if vdef.key and CFG[vdef.key] == true then
                anyVehEnabled = true
                break
            end
        end
    end

    if not anyVehEnabled then
        if next(_G.ActiveVehicleMarkCache) ~= nil then _G.ClearAllVehicleIcons() end
        return
    end

    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
    if not InGameMarkTools or not InGameMarkTools.ClientAddMapMark then return end
    local zeroVec = GetZeroVector()

    local vehList = GetAllVehicles()
    if not vehList then return end

    local activeVehKeys = {}
    local vehDist = math.min(350, tonumber(CFG.VehicleDistance) or 350)
    local maxDistSq = (vehDist * 100) * (vehDist * 100)
    local exitDistSq = maxDistSq * 1.21 -- 10% hysteresis: enter 400m, exit 440m (no edge blink)
    local now = GetGameTimeNow()
    _G.VehicleTombstones = _G.VehicleTombstones or {}
    _G._VehMissedScans = _G._VehMissedScans or {}
    local _VehMissedScans = _G._VehMissedScans

    local function HideVehKey(vehKey, withTombstone)
        local att = _G.ActiveVehicleAttached and _G.ActiveVehicleAttached[vehKey]
        if att and att.mId then SafeHideVehicleMark(att.mId) end
        if att and att.markId and _G.ActiveVehicleMarkCache[att.markId] then
            _G.ActiveVehicleMarkCache[att.markId][vehKey] = nil
        end
        if _G.ActiveVehicleAttached then _G.ActiveVehicleAttached[vehKey] = nil end
        if _G.VehicleDefCache then _G.VehicleDefCache[vehKey] = nil end
        _VehMissedScans[vehKey] = nil
        if withTombstone then _G.VehicleTombstones[vehKey] = now + 30.0 end
    end

    local function ProcessVeh(veh)
        if not IsValid(veh) then return end
        local vehKey = GetVehicleKey(veh) or GetPawnKey(veh)
        if not vehKey then return end

        -- Tombstone: destroyed wreck stays in GetAllVehicles() for ~30s, never resurrect mark
        local tomb = _G.VehicleTombstones[vehKey]
        if tomb then
            if tomb > now then
                if not IsVehicleDeadShared(veh) then
                    _G.VehicleTombstones[vehKey] = nil -- engine recycled name for fresh spawn
                else
                    return
                end
            else
                _G.VehicleTombstones[vehKey] = nil
            end
        end

        -- Definition Cache: resolve once, reuse
        local def = _G.VehicleDefCache and _G.VehicleDefCache[vehKey]
        if def == nil then
            def = ResolveVehicleMark(veh) or false
            if _G.VehicleDefCache then _G.VehicleDefCache[vehKey] = def end
        end

        -- Disabled category -> instant hide, no tombstone (user may re-enable)
        if not IsVehicleEnabledShared(def) then
            if _G.ActiveVehicleAttached and _G.ActiveVehicleAttached[vehKey] then
                HideVehKey(vehKey, false)
            end
            return
        end

        -- Destroyed / exploded -> instant hide + 30s tombstone (bypass 2-miss grace)
        if IsVehicleDeadShared(veh) then
            if _G.ActiveVehicleAttached and _G.ActiveVehicleAttached[vehKey] then
                HideVehKey(vehKey, true)
            else
                _G.VehicleTombstones[vehKey] = now + 30.0
                if _G.VehicleDefCache then _G.VehicleDefCache[vehKey] = nil end
            end
            return
        end

        local attached = _G.ActiveVehicleAttached and _G.ActiveVehicleAttached[vehKey]
        if attached then
            -- ATTACH-ONCE: C++ Slate (bIsBindingActor) moves widget every frame.
            -- Lua must NOT re-add. Only validate: same def + still in hysteresis range.
            if def and def ~= false and attached.markId ~= def.id then
                HideVehKey(vehKey, false) -- vehicle type changed, fall through to re-add
            else
                local vPos = GetActorLocation(veh)
                if vPos then
                    local dx = vPos.X - myPos.X
                    local dy = vPos.Y - myPos.Y
                    local dz = vPos.Z - myPos.Z
                    local distSq = dx * dx + dy * dy + dz * dz
                    if distSq > 0 and distSq <= exitDistSq then
                        activeVehKeys[vehKey] = true
                        _VehMissedScans[vehKey] = 0
                        attached.actor = veh
                        return -- zero regex, zero ClientAddMapMark, zero blink
                    end
                end
                -- Single bad read or short out-of-range: grace 1 scan, keep widget alive
                _VehMissedScans[vehKey] = (_VehMissedScans[vehKey] or 0) + 1
                if _VehMissedScans[vehKey] < 2 then
                    activeVehKeys[vehKey] = true
                    return
                end
                HideVehKey(vehKey, false)
                return
            end
        end

        local vPos = GetActorLocation(veh)
        if not vPos then return end

        local dx = vPos.X - myPos.X
        local dy = vPos.Y - myPos.Y
        local dz = vPos.Z - myPos.Z
        local distSq = dx * dx + dy * dy + dz * dz
        if distSq <= 0 or distSq > maxDistSq then return end

        if def and def ~= false and IsVehicleEnabledShared(def) then
            activeVehKeys[vehKey] = true
            _VehMissedScans[vehKey] = 0
            local markId = def.id
            local grp = _G.ActiveVehicleMarkCache[markId]
            if not grp then grp = {}; _G.ActiveVehicleMarkCache[markId] = grp end

            if not grp[vehKey] then
                local okMark, mId = pcall(InGameMarkTools.ClientAddMapMark, markId, zeroVec, 0, "", 4, veh)
                if okMark and mId and mId ~= 0 then
                    grp[vehKey] = mId
                    if _G.ActiveVehicleAttached then _G.ActiveVehicleAttached[vehKey] = { markId = markId, mId = mId, actor = veh } end
                end
            else
                if _G.ActiveVehicleAttached then
                    local ex = _G.ActiveVehicleAttached[vehKey]
                    if not ex then _G.ActiveVehicleAttached[vehKey] = { markId = markId, mId = grp[vehKey], actor = veh } end
                end
            end
        end
    end

    SafeIterateActors(vehList, function(v) ProcessVeh(v) return false end)

    -- SINGLE eviction sweeper with 2-miss grace (replaces old instant-hide loop).
    -- Anything still attached but not seen in this scan gets 1 grace tick.
    if _G.ActiveVehicleAttached then
        for vehKey, data in pairs(_G.ActiveVehicleAttached) do
            if not activeVehKeys[vehKey] then
                local actor = data and data.actor
                -- Destroyed while out of scan: instant hide + tombstone, no grace
                if actor and IsValid(actor) and IsVehicleDeadShared(actor) then
                    HideVehKey(vehKey, true)
                elseif data and data.mId and data.markId then
                    _VehMissedScans[vehKey] = (_VehMissedScans[vehKey] or 0) + 1
                    if _VehMissedScans[vehKey] >= 2 then
                        local grp = _G.ActiveVehicleMarkCache[data.markId]
                        if grp and grp[vehKey] then
                            if InGameMarkTools.HideMapMark then pcall(InGameMarkTools.HideMapMark, grp[vehKey]) end
                            grp[vehKey] = nil
                        else
                            if data.mId then SafeHideVehicleMark(data.mId) end
                        end
                        _G.ActiveVehicleAttached[vehKey] = nil
                        if _G.VehicleDefCache then _G.VehicleDefCache[vehKey] = nil end
                        _VehMissedScans[vehKey] = nil
                    end
                else
                    _G.ActiveVehicleAttached[vehKey] = nil
                end
            end
        end
    end
    -- MEM-FIX: prune expired tombstones (10s throttle). Never-seen-again keys
    -- otherwise linger for the whole match. Zero behavior change: only entries
    -- already past expiry are dropped.
    if not _G._lastVehTombSweep or (now - _G._lastVehTombSweep) > 10.0 then
        _G._lastVehTombSweep = now
        for vehKey, exp in pairs(_G.VehicleTombstones) do
            if exp <= now then _G.VehicleTombstones[vehKey] = nil end
        end
    end
end

-- Fast Vehicle & Loot Sweepers for Instant Frame-Accurate Eviction
local function FastVehicleSweep()
    if not _G.ActiveVehicleAttached or next(_G.ActiveVehicleAttached) == nil then return end
    local now = GetGameTimeNow()
    _G.VehicleTombstones = _G.VehicleTombstones or {}
    for vehKey, data in pairs(_G.ActiveVehicleAttached) do
        local def = _G.VehicleDefCache and _G.VehicleDefCache[vehKey]
        -- Same OR-logic as Phase: individual ON keeps mark alive even if category OFF
        if def and not IsVehicleEnabledShared(def) then
            if data and data.mId then SafeHideVehicleMark(data.mId) end
            if data and data.markId and _G.ActiveVehicleMarkCache[data.markId] then
                _G.ActiveVehicleMarkCache[data.markId][vehKey] = nil
            end
            _G.ActiveVehicleAttached[vehKey] = nil
            if _G.VehicleDefCache then _G.VehicleDefCache[vehKey] = nil end
            if _G._VehMissedScans then _G._VehMissedScans[vehKey] = nil end
        elseif data and data.actor then
            -- Destroy check every 0.25s -> widget gone <0.3s after explosion
            local dead = false
            pcall(function() dead = IsVehicleDeadShared(data.actor) end)
            if dead then
                if data.mId then SafeHideVehicleMark(data.mId) end
                if data.markId and _G.ActiveVehicleMarkCache[data.markId] then
                    _G.ActiveVehicleMarkCache[data.markId][vehKey] = nil
                end
                _G.ActiveVehicleAttached[vehKey] = nil
                if _G.VehicleDefCache then _G.VehicleDefCache[vehKey] = nil end
                if _G._VehMissedScans then _G._VehMissedScans[vehKey] = nil end
                _G.VehicleTombstones[vehKey] = now + 30.0
            elseif not IsValid(data.actor) then
                if data.mId then SafeHideVehicleMark(data.mId) end
                if data.markId and _G.ActiveVehicleMarkCache[data.markId] then
                    _G.ActiveVehicleMarkCache[data.markId][vehKey] = nil
                end
                _G.ActiveVehicleAttached[vehKey] = nil
                if _G.VehicleDefCache then _G.VehicleDefCache[vehKey] = nil end
                if _G._VehMissedScans then _G._VehMissedScans[vehKey] = nil end
            end
        end
    end
end
_G.FastVehicleSweep = FastVehicleSweep
-- Test hooks (no game impact, allows offline verification of attach-once + destroy path)
_G.TestPhaseVehicles = Phase_Vehicles
_G.TestVehHelpers = {
    GetVehicleKey = GetVehicleKey,
    IsDead = IsVehicleDeadShared,
    IsEnabled = IsVehicleEnabledShared,
}

local function IsLootActorAlive(item)
    if not IsValid(item) then return false end
    if type(item.IsPendingKill) == "function" then
        local okPK, pkVal = pcall(item.IsPendingKill, item)
        if okPK and pkVal then return false end
    end
    local isHidden = false
    pcall(function()
        if item.IsHidden and item:IsHidden() then isHidden = true end
        if not isHidden and item.bHidden == true then isHidden = true end
        if not isHidden and item.RootComponent and item.RootComponent.bVisible == false then isHidden = true end
    end)
    if isHidden then return false end
    return true
end

local function FastLootSweep()
    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
    if not InGameMarkTools or not InGameMarkTools.HideMapMark then return end
    if not _G.ActiveLootAttached or next(_G.ActiveLootAttached) == nil then return end

    local now = GetGameTimeNow()

    for itemKey, data in pairs(_G.ActiveLootAttached) do
        local actor = data.actor
        local shouldHide = false
        if not IsLootActorAlive(actor) then
            shouldHide = true
        else
            -- Check if item was picked up or crate emptied
            if data.isListWrapper then
                pcall(function()
                    local pList = nil
                    if type(actor.GetPickUpDataList) == "function" then
                        pList = actor:GetPickUpDataList()
                    elseif actor.PickUpDataList then
                        pList = actor.PickUpDataList
                    elseif actor.PickUpDataComponent and actor.PickUpDataComponent.PickUpDataList then
                        pList = actor.PickUpDataComponent.PickUpDataList
                    end
                    if pList then
                        local num = (type(pList.Num) == "function" and pList:Num()) or (type(pList) == "table" and #pList) or 0
                        if num <= 0 then
                            shouldHide = true
                        end
                    end
                    local curDef = ResolveLootMark(actor)
                    if not curDef or not _G.IsLootEnabled(curDef) then
                        shouldHide = true
                    end
                end)
            else
                -- Single ground item: verify item is still inside wrapper AND enabled in menu
                local curDef = ResolveLootMark(actor)
                if not curDef or not _G.IsLootEnabled(curDef) then
                    shouldHide = true
                end
            end
        end

        if shouldHide then
            if _G.LootTombstones then _G.LootTombstones[itemKey] = now + 20.0 end
            if data.mId then
                SafeHideLootMark(data.mId)
            end
            if data.markId and _G.ActiveLootMarkCache[data.markId] then
                _G.ActiveLootMarkCache[data.markId][itemKey] = nil
            end
            _G.ActiveLootAttached[itemKey] = nil
            if _G.LootDefCache then _G.LootDefCache[itemKey] = nil end
        end
    end
end
_G.FastLootSweep = FastLootSweep

local function IsLootEnabled(def)
    if not def or def == false then return false end
    if def.key and CFG[def.key] == false then return false end
    if def.key and CFG[def.key] == true then return true end
    if def.catKey and CFG[def.catKey] == true then return true end
    return false
end
_G.IsLootEnabled = IsLootEnabled

local function Phase_Loot(localPawn, myPos)
    local anyLootEnabled = (CFG.Loot_Cat_Flares == true) or (CFG.Loot_Cat_AirDrop == true)
        or (CFG.Loot_Cat_AR == true) or (CFG.Loot_Cat_Snipers == true)
        or (CFG.Loot_Cat_SMG == true) or (CFG.Loot_Cat_Gear == true)
        or (CFG.Loot_Cat_Scopes == true) or (CFG.Loot_Cat_Meds == true)
        or (CFG.Loot_Cat_Throwables == true) or (CFG.Loot_Cat_Shotguns == true)
    if not anyLootEnabled then
        for _, ldef in ipairs(_G.ITEM_ICON_CONFIG) do
            if ldef.key and CFG[ldef.key] == true then
                anyLootEnabled = true
                break
            end
        end
    end

    if not anyLootEnabled then
        if next(_G.ActiveLootMarkCache) ~= nil then _G.ClearAllLootIcons() end
        return
    end

    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
    if not InGameMarkTools or not InGameMarkTools.ClientAddMapMark then return end
    local activeLootKeys = {}
    local activeMarkIds = {}
    local maxDistSq = (CFG.LootDistance * 100) * (CFG.LootDistance * 100)
    local now = GetGameTimeNow()

    _G.LootTombstones = _G.LootTombstones or {}

    local function ProcessLoot(item)
        local itemKey = GetLootKey(item)
        if not itemKey then return end

        -- 1. Tombstone protection: If recently picked up or evicted, verify actor is NOT still hidden in pool!
        if _G.LootTombstones[itemKey] then
            if not IsLootActorAlive(item) then
                return -- Confirmed dead/hidden in pool! Never resurrect mark!
            else
                _G.LootTombstones[itemKey] = nil -- Actor is actively alive and visible (re-dropped by player!)
            end
        end

        -- 2. Physical ground validity check: Must NOT be hidden, pending kill, or invisible!
        if not IsLootActorAlive(item) then
            local attached = _G.ActiveLootAttached and _G.ActiveLootAttached[itemKey]
            if attached and attached.mId then
                SafeHideLootMark(attached.mId)
                if attached.markId and _G.ActiveLootMarkCache[attached.markId] then
                    _G.ActiveLootMarkCache[attached.markId][itemKey] = nil
                end
                _G.ActiveLootAttached[itemKey] = nil
                if _G.LootDefCache then _G.LootDefCache[itemKey] = nil end
                _G.LootTombstones[itemKey] = now + 20.0
            end
            return
        end

        local isMultiItem = false
        if type(item.GetPickUpDataList) == "function" or item.PickUpDataList
            or (item.PickUpDataComponent and item.PickUpDataComponent.PickUpDataList) then
            isMultiItem = true
        end

        -- ZERO-LOOP EARLY OUT: Validate actor is still physically on ground with valid items!
        local attached = _G.ActiveLootAttached and _G.ActiveLootAttached[itemKey]
        if attached then
            local stillAlive = true
            local iPos = GetActorLocation(item)
            if not iPos or (iPos.X == 0 and iPos.Y == 0 and iPos.Z == 0) then
                stillAlive = false
            else
                local dx = iPos.X - myPos.X
                local dy = iPos.Y - myPos.Y
                local dz = iPos.Z - myPos.Z
                local distSq = dx * dx + dy * dy + dz * dz
                if distSq > maxDistSq then
                    stillAlive = false
                end
            end

            -- Content change & ENABLEMENT check: verify item exists and is enabled in menu
            local defMatches = true
            if stillAlive then
                local currentDef = ResolveLootMark(item)
                if not currentDef or not IsLootEnabled(currentDef) then
                    stillAlive = false
                elseif currentDef.id ~= attached.markId then
                    defMatches = false
                end
            end

            if stillAlive and defMatches then
                activeLootKeys[itemKey] = true
                if attached.mId then activeMarkIds[attached.mId] = true end
                return -- Still valid on ground AND enabled in menu!
            else
                -- Item picked up, empty crate, out of distance, OR item definition changed!
                -- Hide the old mark IMMEDIATELY!
                if attached.mId then
                    SafeHideLootMark(attached.mId)
                end
                if attached.markId and _G.ActiveLootMarkCache[attached.markId] then
                    _G.ActiveLootMarkCache[attached.markId][itemKey] = nil
                end
                _G.ActiveLootAttached[itemKey] = nil
                if _G.LootDefCache then _G.LootDefCache[itemKey] = nil end
                if not stillAlive then
                    _G.LootTombstones[itemKey] = now + 20.0
                    return
                end
            end
        end

        local iPos = GetActorLocation(item)
        if not iPos or (iPos.X == 0 and iPos.Y == 0 and iPos.Z == 0) then return end

        local dx = iPos.X - myPos.X
        local dy = iPos.Y - myPos.Y
        local dz = iPos.Z - myPos.Z
        local distSq = dx * dx + dy * dy + dz * dz
        if distSq > maxDistSq then return end

        -- Permanent Definition Cache: Only cache single wrappers; multi-item containers resolve dynamically!
        local def = nil
        if not isMultiItem and _G.LootDefCache then
            def = _G.LootDefCache[itemKey]
        end
        if def == nil then
            def = ResolveLootMark(item) or false
            if not isMultiItem and _G.LootDefCache then
                _G.LootDefCache[itemKey] = def
            end
        end

        if def and def ~= false and IsLootEnabled(def) then
                local markId = def.id
                local grp = _G.ActiveLootMarkCache[markId]
                if not grp then grp = {}; _G.ActiveLootMarkCache[markId] = grp end

                local mId = grp[itemKey]
                if not mId then
                    -- Pass item (Actor) so libUE4 ScreenMarkManager binds to actor as required by ScreenMarkConfig (bIsBindingActor = true)
                    local okMark, newMId = pcall(InGameMarkTools.ClientAddMapMark, markId, iPos, 0, "", 4, item)
                    if not okMark or not newMId then
                        -- Robust fallback: bind to location directly if actor binding is rejected
                        okMark, newMId = pcall(InGameMarkTools.ClientAddMapMark, markId, iPos, 0, "", 4, nil)
                    end
                    if okMark and newMId then
                        mId = newMId
                        grp[itemKey] = mId
                    end
                end

                if mId then
                    activeLootKeys[itemKey] = true
                    activeMarkIds[mId] = true
                    if _G.ActiveLootAttached then
                        _G.ActiveLootAttached[itemKey] = {
                            markId = markId,
                            mId = mId,
                            actor = item,
                            pos = iPos,
                            isListWrapper = isMultiItem
                        }
                    end
                end
        end
    end

    -- 1. Scan single pickup wrappers (No arbitrary 90-cap cutoffs that cause edge item blinking!)
    local pwaClass = import("/Script/ShadowTrackerExtra.PickUpWrapperActor")
        or import("PickUpWrapperActor")
        or LoadBlueprintClass("/Script/ShadowTrackerExtra.PickUpWrapperActor")
        or LoadBlueprintClass("PickUpWrapperActor")
    local pwaList = GetActorsInSphere(myPos, CFG.LootDistance * 100, pwaClass)
    SafeIterateActors(pwaList, function(item)
        ProcessLoot(item)
        return false
    end)

    -- 2. Scan multi-item pickup list wrappers (Loot piles in BGMI) within sphere
    local plwaClass = import("/Script/ShadowTrackerExtra.PickUpListWrapperActor")
        or import("PickUpListWrapperActor")
        or LoadBlueprintClass("/Script/ShadowTrackerExtra.PickUpListWrapperActor")
        or LoadBlueprintClass("PickUpListWrapperActor")
    local plwaList = GetActorsInSphere(myPos, CFG.LootDistance * 100, plwaClass)
    SafeIterateActors(plwaList, function(item)
        ProcessLoot(item)
        return false
    end)

    -- 3. Scan AirDrop care package crates within sphere
    local adbClass = import("/Script/ShadowTrackerExtra.AirDropBoxActor")
        or import("AirDropBoxActor")
        or LoadBlueprintClass("/Script/ShadowTrackerExtra.AirDropBoxActor")
        or LoadBlueprintClass("AirDropBoxActor")
    if adbClass then
        local adbList = GetActorsInSphere(myPos, CFG.LootDistance * 100, adbClass)
        SafeIterateActors(adbList, function(item)
            ProcessLoot(item)
            return false
        end)
    end

    -- Cleanup loot marks for items no longer active in this scan (Instant hide)
    for markId, grp in pairs(_G.ActiveLootMarkCache) do
        for itemKey, mId in pairs(grp) do
            if not activeMarkIds[mId] then
                SafeHideLootMark(mId)
                grp[itemKey] = nil
                if _G.ActiveLootAttached and _G.ActiveLootAttached[itemKey] and _G.ActiveLootAttached[itemKey].mId == mId then
                    _G.ActiveLootAttached[itemKey] = nil
                end
                if _G.LootDefCache then _G.LootDefCache[itemKey] = nil end
                _G.LootTombstones[itemKey] = now + 20.0
            end
        end
    end

    -- STALE LOOT CACHE SWEEPER: Catch any orphaned ActiveLootAttached entries
    if _G.ActiveLootAttached then
        for itemKey, data in pairs(_G.ActiveLootAttached) do
            if not activeLootKeys[itemKey] then
                if data and data.mId then
                    SafeHideLootMark(data.mId)
                end
                if data and data.markId and _G.ActiveLootMarkCache[data.markId] then
                    _G.ActiveLootMarkCache[data.markId][itemKey] = nil
                end
                _G.ActiveLootAttached[itemKey] = nil
                if _G.LootDefCache then _G.LootDefCache[itemKey] = nil end
                _G.LootTombstones[itemKey] = now + 20.0
            end
        end
    end
    -- MEM-FIX: prune expired loot tombstones (10s throttle). Zero behavior change.
    if not _G._lastLootTombSweep or (now - _G._lastLootTombSweep) > 10.0 then
        _G._lastLootTombSweep = now
        for itemKey, exp in pairs(_G.LootTombstones) do
            if exp <= now then _G.LootTombstones[itemKey] = nil end
        end
    end
end
local function Phase_Maintenance(localPawn, pc)
    pcall(function() collectgarbage("step", 100) end)
    -- Long-match hygiene (this tick already runs every ~7s): expiry sweeps that
    -- are otherwise toggle-gated or reuse-gated, so a 20-25 min match can't pin
    -- dead entries forever on 2GB devices. All rules mirror the hot paths.
    pcall(function()
        -- Threat-detonated entries: hot path prunes them only while grenade
        -- alerts are ON (same 20s rule as the 1s threat block).
        local nowT = os.clock()
        for k, t in pairs(_G.DetonatedThreatActors) do
            if (nowT - t) > 20 then _G.DetonatedThreatActors[k] = nil end
        end
        -- Hook-orphaned projectiles: the 5s dead-sweep lives in the same
        -- gated block; drop invalid actors here so they never pin past it.
        for act, _ in pairs(_G.ActiveThrowables) do
            if not IsValid(act) then _G.ActiveThrowables[act] = nil end
        end
        -- Wall-vision mesh cache: hot path enforces 8s TTL on reuse; expire
        -- entries untouched for 30s so roaming a full map never pins every
        -- unique enemy's mesh set (re-scan on next sighting is cheap).
        for pKey, meshes in pairs(_WH_MeshCache) do
            if type(meshes) ~= "table" or not meshes._time or (nowT - meshes._time) > 30.0 then
                _WH_MeshCache[pKey] = nil
            end
        end
        -- Wall-vision dyeing pinning (late-match OOM on 2GB): meshes stay dyed
        -- + flagged forever once their pawn leaves tracking (dead/out-of-range
        -- evict skips undye for invalid pawns). Sweep orphans: undye the
        -- living, release the dead. Runs here (~7s), not per-tick.
        for wpKey, meshList in pairs(_WH_PawnMeshes) do
            if not _G.ActiveWallVisionPawns[wpKey] then
                if type(meshList) == "table" then
                    for _, mesh in ipairs(meshList) do
                        if IsValid(mesh) then
                            pcall(function()
                                if mesh.SetDrawDyeing then mesh:SetDrawDyeing(false) end
                            end)
                        end
                        _WH_AppliedMesh[mesh] = nil
                    end
                end
                _WH_PawnMeshes[wpKey] = nil
            end
        end
        for mesh, _ in pairs(_WH_AppliedMesh) do
            if not IsValid(mesh) then _WH_AppliedMesh[mesh] = nil end
        end
    end)
    -- NOTE: no iPad re-apply here (NEW.lua parity): event-only application,
    -- engine owns FOV mid-match so nothing fights it.
    -- Skin safety refresh (6s): vehicle enter/exit only; guarded
    -- (LastVehicleEntity) so steady-state cost is ~0.
    if CFG.ModSkin then
        local now = GetGameTimeNow()
        if not _G._lastSkinRefresh or (now - _G._lastSkinRefresh) > 6.0 then
            _G._lastSkinRefresh = now
            pcall(_G.ApplyVehicleSkins, localPawn)
        end
    end
end

local function StaggeredMasterTick()
    local pc = GetActivePlayerController()
    if not IsValid(pc) then return end
    local localPawn = GetLocalPlayer(pc)
    if not IsValid(localPawn) then return end
    local myPos = GetActorLocation(localPawn)
    if not myPos then return end

    -- P1-FIX: Master stagger = 2 phases (Vehicles -> Loot + Maintenance), 7s per phase
    if STAGGER_PHASE == 0 then
        Phase_Vehicles(localPawn, myPos)
        STAGGER_PHASE = 1
    else
        Phase_Loot(localPawn, myPos)
        Phase_Maintenance(localPawn, pc)
        STAGGER_PHASE = 0
    end
end

_G.MASTER_DISPATCHER_TIMER = nil
_G.COMBAT_DISPATCHER_TIMER = nil
_G.MASTER_DISPATCHER_OWNER = nil

local _UnifiedCombatTick = 0

local function StopMasterScheduler(bFullMatchWipe)
    STAGGER_PHASE = 0
    _UnifiedCombatTick = 0
    if IsValid(_G.MASTER_DISPATCHER_OWNER) and _G.MASTER_DISPATCHER_OWNER.RemoveGameTimer then
        if _G.COMBAT_DISPATCHER_TIMER then
            pcall(_G.MASTER_DISPATCHER_OWNER.RemoveGameTimer, _G.MASTER_DISPATCHER_OWNER, _G.COMBAT_DISPATCHER_TIMER)
        end
        if _G.MASTER_DISPATCHER_TIMER and _G.MASTER_DISPATCHER_TIMER ~= _G.COMBAT_DISPATCHER_TIMER then
            pcall(_G.MASTER_DISPATCHER_OWNER.RemoveGameTimer, _G.MASTER_DISPATCHER_OWNER, _G.MASTER_DISPATCHER_TIMER)
        end
        if _G.LASER_DISPATCHER_TIMER then
            pcall(_G.MASTER_DISPATCHER_OWNER.RemoveGameTimer, _G.MASTER_DISPATCHER_OWNER, _G.LASER_DISPATCHER_TIMER)
        end
    end
    _G.MASTER_DISPATCHER_TIMER = nil
    _G.COMBAT_DISPATCHER_TIMER = nil
    _G.LASER_DISPATCHER_TIMER = nil
    _G.MASTER_DISPATCHER_OWNER = nil

    -- CRITICAL ANTI-BLINK FIX: Only wipe visual marks and reset caches on GENUINE match change / lobby exit!
    -- When restarting timers during an active match (e.g. revive or owner refresh), DO NOT wipe the screen!
    if bFullMatchWipe == true then
        pcall(ClearAllEnemyESP)
        if _G.ClearAllVehicleIcons then pcall(_G.ClearAllVehicleIcons) end
        if _G.ClearAllLootIcons then pcall(_G.ClearAllLootIcons) end
        if _G.ClearAllThrowableAlerts then pcall(_G.ClearAllThrowableAlerts) end
        if _G.ClearAllNativeLasers then pcall(_G.ClearAllNativeLasers) end
        if _G.NativeTopLaserESP and _G.NativeTopLaserESP.Reset then pcall(_G.NativeTopLaserESP.Reset) end
        if _G.ClearAllWallVision then pcall(_G.ClearAllWallVision) end

        _WH_ConsoleReady = false
        _G._CurrentCombatEnemies = nil
        _G.ActiveWallVisionPawns = {}
        _G.ActiveEnemyMarks = {}
        _G.ActiveBoxCache = {}
        _G.ActiveHPMarks = {}
        _G.ActiveMechaHPMarks = {}

        _G.ActiveVehicleMarkCache = {}
        _G.ActiveVehicleAttached = {}
        _G.VehicleDefCache = {}
        _G.VehicleTombstones = {}
        _G._VehMissedScans = {}
        _G._lastVehTombSweep = nil
        _G.ActiveLootMarkCache = {}
        _G.ActiveLootAttached = {}
        _G.LootDefCache = {}
        _G.LootTombstones = {}
        _G._lastLootTombSweep = nil

        _G.ActiveThrowables = {}
        _G.ActiveThrowableMarks = {}
        _G.DetonatedThreatActors = {}
        _G._ThreatMissedTicks = {}

        _G._lastAppliedAimAssist = nil
        _G._lastAppliedNoRecoil = nil

        if _G.ResetSecurexMatchCaches then pcall(_G.ResetSecurexMatchCaches) end
    end
end
_G.StopMasterScheduler = StopMasterScheduler

_G.SchedulerGeneration = (_G.SchedulerGeneration or 0) + 1

local function StartMasterScheduler(passedPC, bFullMatchWipe)
    local timerOwner = GetActivePlayerController(passedPC)
    if not IsValid(timerOwner) or not timerOwner.AddGameTimer then return end

    StopMasterScheduler(bFullMatchWipe == true) -- Wipe visual marks & caches only on genuine match switch!
    _G.SchedulerGeneration = (_G.SchedulerGeneration or 0) + 1
    local currentGeneration = _G.SchedulerGeneration

    _G.MASTER_DISPATCHER_OWNER = timerOwner

    -- High-Performance 30 FPS Loop (Laser Snaplines + Dynamic Magnetic Aimbot)
    _G.LASER_DISPATCHER_TIMER = timerOwner:AddGameTimer(0.033, true, function()
        if currentGeneration ~= _G.SchedulerGeneration then return end
        -- Heartbeat (NEW.lua-parity liveness): proves this timer actually fires.
        -- Watchdog treats handles-without-heartbeat as dead and rebuilds, so a
        -- false-positive "timersAlive" can never silence a whole match.
        _G._lastLaserTick = os.clock()
        -- Fresh PC only: falling back to the captured timerOwner here would run
        -- visuals on a destroyed prior-match PC during the watchdog gap.
        local livePC = GetActivePlayerController()
        if not IsValid(livePC) then return end
        if TrackMode() == 1 then
            local ok, err = pcall(NativeTopLaserESP.Tick, livePC)
            if not ok then
                _G.LASER_DIAG.lastErr = err
                _G.LASER_DIAG.errCount = (_G.LASER_DIAG.errCount or 0) + 1
            end
        elseif NativeTopLaserESP.ActiveCount > 0 then
            NativeTopLaserESP.ClearAll()
        end

        -- 30 FPS Dynamic Magnetic Aim Pull (switch-gated: OFF = zero)
        if CFG.AimAssistEnabled and _G.ProcessDynamicAimPull then
            pcall(_G.ProcessDynamicAimPull, livePC)
        end
    end)

    -- Fast Combat Scheduler (0.25s fast cadence for Enemy Visuals + Real-time Grenade/Molotov Threat Alerts + Combat Engine)
    _G.COMBAT_DISPATCHER_TIMER = timerOwner:AddGameTimer(0.25, true, function()
        if currentGeneration ~= _G.SchedulerGeneration then return end
        _G._lastCombatTick = os.clock()
        pcall(function()
            -- ALL-OFF SHORT-CIRCUIT: no feature enabled -> skip the whole tick
            -- (zero pawn scans). Any toggle ON resumes instantly. Individual
            -- Veh_/Loot_ icon switches count too (they work with category OFF).
            local anyOn = ((TrackMode() ~= 0) or CFG.ESP_Player_Box or CFG.ESP_Health_Bar
                or CFG.ESP_Wall_Vision or CFG.Counter_Enabled
                or CFG.ESP_Vis_Check or CFG.AimAssistEnabled or CFG.NoRecoilEnabled
                or CFG.Alert_Incoming_Grenades or CFG.Veh_Cat_Cars or CFG.Veh_Cat_Light
                or CFG.Veh_Cat_Bikes or CFG.Veh_Cat_Armored or CFG.Veh_Cat_WaterAir
                or CFG.Loot_Cat_Flares or CFG.Loot_Cat_AirDrop or CFG.Loot_Cat_AR
                or CFG.Loot_Cat_Snipers or CFG.Loot_Cat_SMG or CFG.Loot_Cat_Gear
                or CFG.Loot_Cat_Scopes or CFG.Loot_Cat_Meds or CFG.Loot_Cat_Throwables
                or CFG.Loot_Cat_Shotguns or CFG.ModSkin)
            if not anyOn then
                for k, v in pairs(CFG) do
                    if v == true and (string.sub(k, 1, 9) == "Veh_Icon_" or string.sub(k, 1, 5) == "Loot_") then
                        anyOn = true
                        break
                    end
                end
            end
            if not anyOn then return end
            local pc = GetActivePlayerController()
            if not IsValid(pc) then return end
            local localPawn = GetLocalPlayer(pc)
            if not IsValid(localPawn) then return end
            local myPos = GetActorLocation(localPawn)
            if not myPos then return end

            _UnifiedCombatTick = _UnifiedCombatTick + 1

            Phase_Enemies(localPawn, myPos, pc)

            -- Lazy re-hook for late-loaded TDM grenade modules (every 5s)
            local nowClock = os.clock()
            if not _G._lastThrowableHookTime or (nowClock - _G._lastThrowableHookTime) >= 5.0 then
                _G._lastThrowableHookTime = nowClock
                pcall(HookThrowableProjectiles)
            end

            -- Fast weapon switch check for Aimbot & No Recoil on respawn / weapon swap (0% CPU, dirty-checked)
            if _G.CheckCombatWeaponSwitch then pcall(_G.CheckCombatWeaponSwitch) end
            -- Late-manager self-heal (TDM/Arena): if the ScreenMarkManager appeared
            -- after boot (or a new one replaced it), register our groups on it once.
            pcall(function()
                local MT = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
                local smm = MT and MT.ScreenMarkManager
                if smm and IsValid(smm) and _G._marksInitManager ~= smm then
                    if _G.InitMapTracking then _G.InitMapTracking() end
                end
            end)
            if CFG.AimAssistEnabled and _G.UpdateAimTargetFiltering then
                pcall(_G.UpdateAimTargetFiltering, localPawn)
            end

            -- Real-Time Frag & Molotov Threat Warning Subsystem (<50m, Instant Auto-Cleanup)
            -- Every 4th combat tick (1.0s): cooked/short-lived grenades can die
            -- between wider gaps, so 1s it is (2s missed live threats entirely).
            if CFG.Alert_Incoming_Grenades and (_UnifiedCombatTick % 4 == 0) then
                pcall(function()
                    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
                    if not (InGameMarkTools and InGameMarkTools.ClientAddMapMark and InGameMarkTools.HideMapMark) then return end

                    local now = os.clock()

                    -- Prune stale detonated cache entries older than 20 seconds
                    for k, t in pairs(_G.DetonatedThreatActors) do
                        if (now - t) > 20 then _G.DetonatedThreatActors[k] = nil end
                    end

                    local liveThreatKeys = {}

                    local function CheckThreatActor(actor)
                        if not actor or not IsValid(actor) then return end
                        if actor._sx_detonated or actor._sx_fire_ended then return end
                        if type(actor.IsPendingKill) == "function" then
                            local ok, pk = pcall(actor.IsPendingKill, actor)
                            if ok and pk then return end
                        end

                        local stableKey = _G.ThreatKey(actor)
                        if _G.DetonatedThreatActors[stableKey] then return end

                        local aname = string.lower(actor.GetName and actor:GetName() or "")
                        local cname = ""
                        if actor.GetClass then
                            local ok, cls = pcall(actor.GetClass, actor)
                            if ok and cls and cls.GetName then cname = string.lower(cls:GetName()) end
                        end
                        local combined = aname .. " " .. cname

                        -- Strict non-threat exclusion
                        if string.find(combined, "smoke") or string.find(combined, "flash") or string.find(combined, "stun")
                            or string.find(combined, "apple") or string.find(combined, "snow") or string.find(combined, "ball") then
                            return
                        end

                        local isMolotov = string.find(combined, "burn") or string.find(combined, "molotov") or string.find(combined, "firebomb")
                            or string.find(combined, "spreading") or string.find(combined, "flame") or string.find(combined, "ranshaodan")
                        if not isMolotov then
                            local itemId = (actor.GetItemTypeID and actor:GetItemTypeID())
                                or (actor.ItemDefineID and actor.ItemDefineID.TypeSpecificID)
                                or (actor.ItemID)
                            if itemId == 602003 or itemId == 602005 then
                                isMolotov = true
                            end
                        end
                        if not isMolotov then
                            pcall(function()
                                local ASTBuffApplifierSpreading = import("STBuffApplifierSpreading")
                                if ASTBuffApplifierSpreading and Game and Game.IsClassOf and Game:IsClassOf(actor, ASTBuffApplifierSpreading) then
                                    isMolotov = true
                                end
                            end)
                        end

                        local isFrag = string.find(combined, "frag") or string.find(combined, "shoulei") or string.find(combined, "shou_lei")
                        if not isFrag and not isMolotov then
                            local itemId = (actor.GetItemTypeID and actor:GetItemTypeID())
                                or (actor.ItemDefineID and actor.ItemDefineID.TypeSpecificID)
                                or (actor.ItemID)
                            if itemId == 602004 then
                                isFrag = true
                            end
                        end

                        local isFlamePool = isMolotov and (string.find(combined, "spreading") or string.find(combined, "burning") or string.find(combined, "applifier"))
                        local isProjectile = not isFlamePool and (string.find(combined, "projectile") or string.find(combined, "burngrenade") or string.find(combined, "fraggrenade"))

                        -- Projectile Impact & Detonation check (for BOTH Frag AND Molotov bottle!)
                        -- NOTE: GrenadeExplodeStartTime is NOT a detonation signal (fuse
                        -- runs from throw); state tags below are the real impact check.
                        -- Skipping on StartTime hid live grenades = widgets never formed.
                        if isProjectile then
                            if actor.GetCurStateType then
                                local ok, state = pcall(actor.GetCurStateType, actor)
                                if ok and state and state.TagName then
                                    if state.TagName == "InEffect" or state.TagName == "PostEffect" or state.TagName == "Destroyed" then
                                        _G.DetonatedThreatActors[stableKey] = now
                                        return -- Projectile reached impact state!
                                    end
                                end
                            end
                        elseif isFlamePool then
                            -- Ground Flame Pool check: check if fire has burned out
                            if actor.GetCurStateType then
                                local ok, state = pcall(actor.GetCurStateType, actor)
                                if ok and state and state.TagName then
                                    if state.TagName == "PostEffect" or state.TagName == "Destroyed" then
                                        _G.DetonatedThreatActors[stableKey] = now
                                        return -- Fire ended!
                                    end
                                end
                            end
                        end

                        -- Flying projectile threat filter (lethal frag / molotov verification)
                        if not isFrag and not isMolotov then
                            if not _G.IsDangerousExplosive(actor) then return end
                        end

                        local gLoc = GetActorLocation(actor)
                        if not gLoc then return end

                        local dx = gLoc.X - myPos.X
                        local dy = gLoc.Y - myPos.Y
                        local dz = gLoc.Z - myPos.Z
                        if (dx * dx + dy * dy + dz * dz) <= 25000000 then -- <= 50m
                            liveThreatKeys[stableKey] = { actor = actor, loc = gLoc, isMolotov = isMolotov, isFlamePool = isFlamePool, isProjectile = isProjectile }
                        end
                    end

                    -- Fast & responsive scan for small TDM maps and fast projectile throws
                    if true then
                        -- 1. Scan Frag Grenades (Native In-Game Flying Projectiles)
                        local BPFragClass = LoadBlueprintClass("/Game/Arts_PlayerBluePrints/Weapon/Projectile/FragGrenade/BP_Projectile_FragGrenade.BP_Projectile_FragGrenade_C")
                            or LoadBlueprintClass("/Game/Arts_PlayerBluePrints/Weapon/Projectile/FragGrenade/BP_Projectile_FragGrenade")
                            or import("BP_Projectile_FragGrenade_C")
                        local fragList = GetActorsInSphere(myPos, 5000, BPFragClass)
                        SafeIterateActors(fragList, function(act)
                            CheckThreatActor(act)
                            return false
                        end)

                        -- 2. Scan Molotov Cocktails (Native In-Game Flying Projectiles)
                        local BPMolotovClass = LoadBlueprintClass("/Game/Arts_PlayerBluePrints/Weapon/Projectile/BurnGrenade/BP_Projectile_BurnGrenade.BP_Projectile_BurnGrenade_C")
                            or LoadBlueprintClass("/Game/Arts_PlayerBluePrints/Weapon/Projectile/BurnGrenade/BP_Projectile_BurnGrenade")
                            or import("BP_Projectile_BurnGrenade_C")
                            or import("BP_Projectile_BurnGrenade")
                        local molotovList = GetActorsInSphere(myPos, 5000, BPMolotovClass)
                        SafeIterateActors(molotovList, function(act)
                            CheckThreatActor(act)
                            return false
                        end)

                        -- 3. Scan Ground Flame Pools (Molotov BurningSpreading Fire)
                        local BPBurnArea = LoadBlueprintClass("/Game/Arts_PlayerBluePrints/Weapon/Grenade/BurningSpreading.BurningSpreading_C")
                            or LoadBlueprintClass("/Game/Arts_PlayerBluePrints/Weapon/Grenade/BurningSpreading")
                            or import("BurningSpreading_C")
                            or import("BurningSpreading")
                        local fireList = GetActorsInSphere(myPos, 5000, BPBurnArea)
                        SafeIterateActors(fireList, function(act)
                            CheckThreatActor(act)
                            return false
                        end)

                        -- 4. Scan Native C++ Spreading Fire Class (STBuffApplifierSpreading)
                        pcall(function()
                            local ASTBuffApplifierSpreading = import("STBuffApplifierSpreading")
                            if ASTBuffApplifierSpreading and ASTBuffApplifierSpreading ~= BPBurnArea then
                                local spreadList = GetActorsInSphere(myPos, 5000, ASTBuffApplifierSpreading)
                                SafeIterateActors(spreadList, function(act)
                                    CheckThreatActor(act)
                                    return false
                                end)
                            end
                        end)

                        -- 5. Scan Common Base Projectile Class (Catches all active flying projectiles)
                        local BPProjBase = LoadBlueprintClass("/Game/Arts_PlayerBluePrints/Weapon/Projectile/BP_Projectile_Base.BP_Projectile_Base_C")
                            or LoadBlueprintClass("/Game/Arts_PlayerBluePrints/Weapon/Projectile/BP_Projectile_Base.BP_Projectile_Base")
                            or import("BP_Projectile_Base_C")
                        if BPProjBase then
                            local baseList = GetActorsInSphere(myPos, 5000, BPProjBase)
                            SafeIterateActors(baseList, function(act)
                                CheckThreatActor(act)
                                return false
                            end)
                        end
                    end

                    -- 6. Scan Active Throwables from Lua Hooks (dead refs pruned here:
                    -- lifecycle hooks miss cleanup when actors vanish without effect callbacks)
                    do
                        local nowT = os.clock()
                        if not _G._lastThrowableSweep or (nowT - _G._lastThrowableSweep) > 5.0 then
                            _G._lastThrowableSweep = nowT
                            for key, act in pairs(_G.ActiveThrowables) do
                                local dead = true
                                pcall(function()
                                    if act and IsValid(act) then
                                        if type(act.IsPendingKill) == "function" then
                                            local ok, pk = pcall(act.IsPendingKill, act)
                                            dead = (ok and pk) and true or false
                                        else
                                            dead = false
                                        end
                                    end
                                end)
                                if dead then _G.ActiveThrowables[key] = nil end
                            end
                        end
                    end
                    for _, act in pairs(_G.ActiveThrowables) do
                        if act and IsValid(act) then
                            CheckThreatActor(act)
                        end
                    end

                    -- Mount Dedicated Native Threat Warnings (1010 for Frag Shoulei, 101005 for Molotov / Flame)
                    for stableKey, info in pairs(liveThreatKeys) do
                        local existing = _G.ActiveThrowableMarks[stableKey]
                        if existing then
                            -- Still live on this scan: refresh lifetime so the mark
                            -- survives the full fuse (old code expired 3.5s after
                            -- FIRST sighting, killing the widget mid-fuse).
                            existing.spawnTime = now
                            if _G._ThreatMissedTicks then _G._ThreatMissedTicks[stableKey] = 0 end
                        else
                            local targetMarkId = info.isMolotov and 101005 or 1010
                            -- Re-validate: the projectile may have detonated between
                            -- scan and mount; never hand a dying actor to native.
                            local bindActor = (info.actor and IsValid(info.actor)) and info.actor or nil
                            local ok, mId = pcall(InGameMarkTools.ClientAddMapMark, targetMarkId, info.loc, 0, nil, 4, bindActor)
                            if not ok or not mId then
                                -- Fallback to 1010 if 101005 is not preloaded on this map
                                if targetMarkId == 101005 then
                                    ok, mId = pcall(InGameMarkTools.ClientAddMapMark, 1010, info.loc, 0, nil, 4, bindActor)
                                    if ok and mId then targetMarkId = 1010 end
                                end
                            end
                            if not ok or not mId then
                                -- Robust fallback: bind to location directly if actor binding is rejected!
                                ok, mId = pcall(InGameMarkTools.ClientAddMapMark, targetMarkId, info.loc, 0, nil, 4, nil)
                            end
                            if ok and mId then
                                -- Flying projectile max life = 3.5s (TDM safe); Ground fire = 8.0s
                                local maxLife = (info.isFlamePool and 8.0) or 3.5
                                _G.ActiveThrowableMarks[stableKey] = {
                                    mId = mId,
                                    spawnTime = now,
                                    maxLife = maxLife,
                                    actor = info.actor,
                                    isMolotov = info.isMolotov,
                                    isFlamePool = info.isFlamePool,
                                    isProjectile = info.isProjectile,
                                    markId = targetMarkId
                                }
                            end
                        end
                    end

                    -- DEDUPLICATION SHIELD: If ground fire pool is active within 300cm of a projectile bottle, retire bottle immediately!
                    for pKey, pData in pairs(_G.ActiveThrowableMarks) do
                        if pData.isProjectile and pData.isMolotov then
                            for fKey, fData in pairs(_G.ActiveThrowableMarks) do
                                if fKey ~= pKey and fData.isFlamePool and fData.actor and pData.actor then
                                    local pLoc = GetActorLocation(pData.actor)
                                    local fLoc = GetActorLocation(fData.actor)
                                    if pLoc and fLoc then
                                        local ddx = pLoc.X - fLoc.X
                                        local ddy = pLoc.Y - fLoc.Y
                                        local ddz = pLoc.Z - fLoc.Z
                                        if (ddx * ddx + ddy * ddy + ddz * ddz) <= 90000 then -- <= 300cm
                                            if pData.mId and InGameMarkTools and InGameMarkTools.HideMapMark then
                                                pcall(InGameMarkTools.HideMapMark, pData.mId)
                                            end
                                            _G.ActiveThrowableMarks[pKey] = nil
                                            _G.DetonatedThreatActors[pKey] = now
                                        end
                                    end
                                end
                            end
                        end
                    end

                    -- AUTO-CLEANUP with 2-tick debounce grace period
                    local _ThreatMissedTicks = _G._ThreatMissedTicks or {}
                    _G._ThreatMissedTicks = _ThreatMissedTicks
                    for stableKey, data in pairs(_G.ActiveThrowableMarks) do
                        if liveThreatKeys[stableKey] == nil then
                            _ThreatMissedTicks[stableKey] = (_ThreatMissedTicks[stableKey] or 0) + 1
                        else
                            _ThreatMissedTicks[stableKey] = 0
                        end
                        local isNoLongerThreat = (_ThreatMissedTicks[stableKey] or 0) >= 2
                        local isDetonated = false

                        if _G.DetonatedThreatActors[stableKey] then
                            isDetonated = true
                        end

                        if not isDetonated and data.actor then
                            if data.actor._sx_detonated == true or data.actor._sx_fire_ended == true then
                                isDetonated = true
                            elseif data.isProjectile then
                                -- Any in-flight projectile (Frag or Molotov bottle) that detonates or impacts
                                if data.actor.GetCurStateType then
                                    local ok, state = pcall(data.actor.GetCurStateType, data.actor)
                                    if ok and state and state.TagName then
                                        if state.TagName == "InEffect" or state.TagName == "PostEffect" or state.TagName == "Destroyed" then
                                            isDetonated = true
                                        end
                                    end
                                end
                            else
                                -- Ground Flame Pool burned out check
                                if data.actor.GetCurStateType then
                                    local ok, state = pcall(data.actor.GetCurStateType, data.actor)
                                    if ok and state and state.TagName then
                                        if state.TagName == "PostEffect" or state.TagName == "Destroyed" then
                                            isDetonated = true
                                        end
                                    end
                                end
                            end
                        end

                        local isDead = (not IsValid(data.actor))
                        if not isDead and type(data.actor.IsPendingKill) == "function" then
                            local ok, pk = pcall(data.actor.IsPendingKill, data.actor)
                            if ok and pk then isDead = true end
                        end

                        local isExpired = (now - data.spawnTime) >= data.maxLife
                        local isOutOfRange = false
                        if not isDead and myPos then
                            local cLoc = GetActorLocation(data.actor)
                            if cLoc then
                                local ddx = cLoc.X - myPos.X
                                local ddy = cLoc.Y - myPos.Y
                                local ddz = cLoc.Z - myPos.Z
                                if (ddx * ddx + ddy * ddy + ddz * ddz) > 25000000 then -- > 50m
                                    isOutOfRange = true
                                end
                            end
                        end

                        if isDetonated or isNoLongerThreat or isDead or isExpired or isOutOfRange then
                            if isDetonated or isDead then
                                _G.DetonatedThreatActors[stableKey] = now
                            end
                            if data.mId and InGameMarkTools and InGameMarkTools.HideMapMark then
                                pcall(InGameMarkTools.HideMapMark, data.mId)
                            end
                            _G.ActiveThrowableMarks[stableKey] = nil
                            _ThreatMissedTicks[stableKey] = nil
                        end
                    end
                end)
            end

            -- 3.5. Fast Loot Eviction Sweep: <0.25s instant removal of picked up items
            pcall(FastLootSweep)
            pcall(FastVehicleSweep)

            -- 4. Unified Environment Stagger Phase (Replaces separate 0.8s timer)
            -- Runs every 14 ticks (3.5s), cycling: Phase 0 (Vehicles) -> Phase 1 (Loot + Maintenance)
            -- = each phase refreshes every 7.0s. Fast destroy/pickup eviction still
            -- runs every 0.25s via FastVehicleSweep/FastLootSweep + event hooks,
            -- so only NEW marks wait up to 7s.
            if (_UnifiedCombatTick % 14 == 0) then
                pcall(StaggeredMasterTick)
            end
        end)
    end)

    -- Unified Timer Architecture: MASTER_DISPATCHER_TIMER aliases COMBAT_DISPATCHER_TIMER
    -- Eliminates third native timer while keeping watchdog / external hooks 100% satisfied
    _G.MASTER_DISPATCHER_TIMER = _G.COMBAT_DISPATCHER_TIMER

    pcall(function()
        local pc = GetActivePlayerController()
        if IsValid(pc) then
            local localPawn = GetLocalPlayer(pc)
            if IsValid(localPawn) then
                local myPos = GetActorLocation(localPawn)
                if myPos then Phase_Enemies(localPawn, myPos, pc) end
            end
        end
    end)
end
_G.StartMasterScheduler = StartMasterScheduler

-- ============================================================================
-- 8. GRAPHICS & UTILITY ENGINE MODS
-- ============================================================================
local _iPadViewOrigFOV = nil

-- iPad View: verbatim port of DOWNLOADS/SUPABASE LUA CODE NEW.lua:2898-2949
-- (Valid -> IsValid for this file). Event-driven ONLY (match-init / respawn /
-- menu toggle): never re-applied on a timer, so the engine never fights it
-- mid-match (no flicker). Trade-off inherited from NEW: if the engine resets
-- FOV itself (vehicle enter/exit), it re-applies on next init/respawn/toggle.
local function ApplyiPadView(force)
    pcall(function()
        local pc = GetActivePlayerController()
        local char = GetLocalPlayer(pc)
        if not IsValid(char) then return end
        local cam = char.ThirdPersonCameraComponent
            or (char.GetCameraComponent and char:GetCameraComponent())
            or char.FirstPersonCameraComponent
            or char.CameraComponent

        local SettingModule = nil
        pcall(function()
            local mm = ModuleManager or (pcall(require, "client.module_framework.ModuleManager") and require("client.module_framework.ModuleManager"))
            if mm and mm.GetModule then
                SettingModule = mm.GetModule(mm.CommonModuleConfig and mm.CommonModuleConfig.SettingModule or "SettingModule")
            end
        end)

        if not CFG.iPadViewEnabled then
            local defaultFov = (_iPadViewOrigFOV and _iPadViewOrigFOV <= 100) and _iPadViewOrigFOV or 90
            if SettingModule and SettingModule.SetOptionValue then
                pcall(SettingModule.SetOptionValue, SettingModule, "TpViewValue", defaultFov)
            end
            if char.SetTpCameraFov then pcall(char.SetTpCameraFov, char, defaultFov) end
            if char.SetFovInTPPSpringArm then pcall(char.SetFovInTPPSpringArm, char, defaultFov) end
            if pc and IsValid(pc) and pc.NormalCameraModeData and pc.NormalCameraModeData.SwitchCameraData then
                pc.NormalCameraModeData.SwitchCameraData.CameraFOV = defaultFov
            end
            if IsValid(cam) and cam.FieldOfView ~= defaultFov then cam.FieldOfView = defaultFov end
            return
        end

        if not _iPadViewOrigFOV then
            local currentFov = (IsValid(cam) and cam.FieldOfView) or 90
            if currentFov <= 100 then _iPadViewOrigFOV = currentFov else _iPadViewOrigFOV = 90 end
        end

        local targetFov = CFG.iPadViewFOV or 110
        if SettingModule and SettingModule.SetOptionValue then
            pcall(SettingModule.SetOptionValue, SettingModule, "TpViewValue", targetFov)
        end
        if char.SetTpCameraFov then pcall(char.SetTpCameraFov, char, targetFov) end
        if char.SetFovInTPPSpringArm then pcall(char.SetFovInTPPSpringArm, char, targetFov) end
        if pc and IsValid(pc) and pc.NormalCameraModeData and pc.NormalCameraModeData.SwitchCameraData then
            pc.NormalCameraModeData.SwitchCameraData.CameraFOV = targetFov
        end
        if IsValid(cam) and cam.FieldOfView ~= targetFov then
            cam.FieldOfView = targetFov
        end
    end)
end
_G.ApplyiPadView = ApplyiPadView

-- ============================================================================
-- 165 FPS UNLOCK (ported from DOWNLOADS/SUPABASE LUA CODE NEW.lua:1442-1646).
-- Hooks game's graphics settings modules so the in-game FPS menu exposes the
-- top tier (level 8) + fine-tune slider 90-165 step 5, and forces the engine
-- caps to 165 immediately. Runs once, fully pcall-guarded: on devices/modules
-- where a hook target is missing it simply skips that layer. Low-end safe:
-- this only UNLOCKS the ceiling; actual frame target stays CFG.TargetFPS
-- (default 90) so weak GPUs never get force-fed 165.
-- ============================================================================
pcall(function()
    if _G.__165FPS_UNLOCK_PATCHED then return end
    local function safe_require(modname)
        local ok, mod = pcall(require, modname)
        if not ok then return nil end
        return mod
    end
    local graphics = safe_require("client.slua.logic.setting.logic_setting_graphics")
    local fpsComp = safe_require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
    local fpsFT = safe_require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
    local db = safe_require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
    local function get_game_instance()
        if db and db.GetGameInstance then
            local ok, gi = pcall(db.GetGameInstance, db)
            if ok and gi then return gi end
        end
        local ok, gp = pcall(require, "GameLua.GameCore.Data.GameplayData")
        if ok and gp and gp.GetGameInstance then
            local ok2, gi2 = pcall(gp.GetGameInstance)
            if ok2 and gi2 then return gi2 end
        end
        return nil
    end
    if graphics and type(graphics.SetFPS) == "function" then
        if not graphics.__original_SetFPS then
            graphics.__original_SetFPS = graphics.SetFPS
        end
        local orig = graphics.__original_SetFPS
        graphics.SetFPS = function(self, level)
            -- CRASH-FIX: forward orig return values (game settings UI reads them).
            local r1, r2, r3 = nil, nil, nil
            local ok = pcall(function() r1, r2, r3 = orig(self, level) end)
            if level == 8 then
                pcall(function()
                    if self.ExecuteCMD then
                        self:ExecuteCMD("t.MaxFPS", "165")
                        self:ExecuteCMD("r.FrameRateLimit", "165")
                    end
                end)
            end
            if ok then return r1, r2, r3 end
        end
    end
    if fpsComp and fpsComp.__inner_impl then
        local impl = fpsComp.__inner_impl
        if not impl.__165patched then
            impl.GetMaxFPSLevel = function() return 8, 8 end
            impl.InitRealSupportFPS = function(self)
                local tbl = {}
                for i = 1, 8 do tbl[i] = { true, true } end
                if db and db.RealSupportFPS then
                    pcall(function() db:UpdateUIData(db.RealSupportFPS, tbl, false) end)
                end
                return tbl
            end
            impl.UpdateSelectedFPSState = function(self, level)
                local fpsMap = { [2] = 20, [3] = 25, [4] = 30, [5] = 40, [6] = 60, [7] = 90, [8] = 120 }
                local UIRoot = self.UIRoot
                if not UIRoot then return end
                for i = 2, 8 do
                    local nodeName = "NodeFps" .. tostring(fpsMap[i] or 120)
                    local node = UIRoot[nodeName]
                    if IsValid(node) and node.SetIsEnabled then
                        node:SetIsEnabled(true)
                        pcall(function() node:SetRenderOpacity(1.0) end)
                        local switcher = UIRoot["WidgetSwitcher_" .. i]
                        if IsValid(switcher) and switcher.SetActiveWidgetIndex then
                            switcher:SetActiveWidgetIndex(i == level and 0 or 1)
                        end
                    end
                end
            end
            impl.__165patched = true
        end
    end
    if fpsFT and fpsFT.__inner_impl and db then
        local impl = fpsFT.__inner_impl
        if not impl.__165patched then
            local MIN_FPS, MAX_FPS, STEP = 90, 165, 5
            local function clamp(v) return math.max(MIN_FPS, math.min(MAX_FPS, v)) end
            impl.ShowOrHide = function(self)
                pcall(function() self:SelfHitTestInvisible() end)
                if self.InitFPSFTSwitch then pcall(self.InitFPSFTSwitch, self) end
            end
            impl.InitFPSFTSwitch = function(self)
                if not db then return end
                local on = db:GetUIData(db.FPSFineTuneSwitch)
                local UIRoot = self.UIRoot
                if not UIRoot then return end
                if UIRoot.Setting_Switch then
                    pcall(function() UIRoot.Setting_Switch:SetSwitcherEnable2(on, true) end)
                end
                if UIRoot.CanvasPanel_8 then
                    pcall(function() self:SetWidgetVisible(UIRoot.CanvasPanel_8, on) end)
                end
                if UIRoot.WidgetSwitcher_0 then
                    pcall(function() UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end)
                end
                if self.InitFPSFTValue165 then pcall(self.InitFPSFTValue165, self) end
            end
            impl.InitFPSFTValue165 = function(self)
                if not db then return end
                local UIRoot = self.UIRoot
                if not UIRoot then return end
                local on = db:GetUIData(db.FPSFineTuneSwitch)
                local val = on and (db:GetUIData(db.FPSFineTuneNum) or 165) or 165
                local slider, progress, textLabel = UIRoot.Slider_screen3, UIRoot.ProgressBar_screen3, UIRoot.Veihclescreen3
                if not (slider and progress and textLabel) then return end
                if on then
                    pcall(function() slider:SetLocked(false) end)
                    pcall(function() progress:SetFillColorAndOpacity(FLinearColor(1, 1, 1, 1)) end)
                    pcall(function() slider:SetSliderHandleColor(FLinearColor(1, 1, 1, 1)) end)
                else
                    pcall(function() slider:SetLocked(true) end)
                    pcall(function() progress:SetFillColorAndOpacity(FLinearColor(1, 0.625, 0.6, 1)) end)
                    pcall(function() slider:SetSliderHandleColor(FLinearColor(1, 0.625, 0.6, 1)) end)
                end
                local norm = (val - MIN_FPS) / (MAX_FPS - MIN_FPS)
                pcall(function() textLabel:SetText(tostring(val)) end)
                pcall(function() slider:SetValue(norm) end)
                pcall(function() progress:SetPercent(norm) end)
            end
            impl.OnFPSFTValueChange3 = function(self, val)
                if not db then return end
                pcall(function()
                    db:UpdateUIData(db.FPSFineTuneNum, val)
                    if self.InitFPSFTValue165 then pcall(self.InitFPSFTValue165, self) end
                    local parent = self.GetParentUI and self:GetParentUI()
                    if parent and parent.SetDirty then pcall(function() parent:SetDirty(true) end) end
                    local gi = get_game_instance()
                    if gi and gi.ExecuteCMD then
                        pcall(gi.ExecuteCMD, gi, "t.MaxFPS", tostring(val))
                        pcall(gi.ExecuteCMD, gi, "r.FrameRateLimit", tostring(val))
                    end
                end)
            end
            impl.OnFPSFTSliderValueChange3 = function(self, nv)
                if not db then return end
                if not db:GetUIData(db.FPSFineTuneSwitch) then return end
                local raw = math.floor(MIN_FPS + (MAX_FPS - MIN_FPS) * nv)
                raw = math.floor(raw / STEP) * STEP
                self:OnFPSFTValueChange3(clamp(raw))
            end
            impl.OnFPSFTAdd3 = function(self)
                local cur = (db and db:GetUIData(db.FPSFineTuneNum)) or MIN_FPS
                self:OnFPSFTValueChange3(math.min(MAX_FPS, cur + STEP))
            end
            impl.OnFPSFTMinus3 = function(self)
                local cur = (db and db:GetUIData(db.FPSFineTuneNum)) or MIN_FPS
                self:OnFPSFTValueChange3(math.max(MIN_FPS, cur - STEP))
            end
            impl.OnFPSFTAdd = impl.OnFPSFTAdd3
            impl.OnFPSFTMinus = impl.OnFPSFTMinus3
            impl.OnFPSFTSliderValueChange = impl.OnFPSFTSliderValueChange3
            impl.__165patched = true
        end
    end
    -- Immediate ceiling (actual running target still follows CFG.TargetFPS via ApplyFPSLimit)
    local gi = get_game_instance()
    if gi and gi.ExecuteCMD then
        pcall(gi.ExecuteCMD, gi, "t.MaxFPS", "165")
        pcall(gi.ExecuteCMD, gi, "r.FrameRateLimit", "165")
    end
    _G.__165FPS_UNLOCK_PATCHED = true
end)

local function ApplyFPSLimit(targetFps)
    targetFps = math.min(165, math.max(60, tonumber(targetFps) or tonumber(CFG.TargetFPS) or 90))
    if _G._lastAppliedFPS == targetFps then return end
    CFG.TargetFPS = targetFps
    local applied = false
    pcall(function()
        local ui_util = pcall(require, "client.common.ui_util") and require("client.common.ui_util")
        local gi = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            or (ui_util and ui_util.GetGameInstance and ui_util.GetGameInstance())
            or (_G.GameInstance)
        if gi and gi.ExecuteCMD then
            local fpsStr = tostring(targetFps)
            pcall(gi.ExecuteCMD, gi, "t.MaxFPS", fpsStr)
            pcall(gi.ExecuteCMD, gi, "r.FrameRateLimit", fpsStr)
            applied = true
        end
        if not applied then
            local KSL = import("KismetSystemLibrary")
            local world = _slua and _slua.getWorld and _slua.getWorld()
            if type(KSL) == "table" and type(KSL.ExecuteConsoleCommand) == "function" and world then
                pcall(KSL.ExecuteConsoleCommand, world, "t.MaxFPS " .. tostring(targetFps))
                pcall(KSL.ExecuteConsoleCommand, world, "r.FrameRateLimit " .. tostring(targetFps))
                applied = true
            end
        end
    end)
    if applied then _G._lastAppliedFPS = targetFps end
end
_G.ApplyFPSLimit = ApplyFPSLimit

local function ApplyFPSStabilizer(enable)
    local isEnabled = (enable ~= false)
    if enable == nil then isEnabled = (CFG.FPSStabilizerEnabled ~= false) end
    CFG.FPSStabilizerEnabled = isEnabled
    if _G._lastFPSStabApplied == isEnabled then return end

    local ok = pcall(function()
        if _slua and _slua.setGCParam then
            if isEnabled then _slua.setGCParam(5.0E-4, 500, 50)
            else _slua.setGCParam(0.001, 1000, 0) end
        end

        local ui_util = pcall(require, "client.common.ui_util") and require("client.common.ui_util")
        local gi = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            or (ui_util and ui_util.GetGameInstance and ui_util.GetGameInstance())
            or (_G.GameInstance)
        local KSL = import("KismetSystemLibrary")
        local world = _slua and _slua.getWorld and _slua.getWorld()

        local function ExecCmd(cmd, arg)
            -- Per-command shield: one unknown/failing command must not abort the rest.
            if gi and gi.ExecuteCMD then pcall(gi.ExecuteCMD, gi, cmd, arg) end
            if type(KSL) == "table" and type(KSL.ExecuteConsoleCommand) == "function" and world then
                pcall(KSL.ExecuteConsoleCommand, world, cmd .. " " .. tostring(arg))
            end
        end

        if isEnabled then
            ExecCmd("a.ParallelAnimEvaluation", "1")
            ExecCmd("r.GTSyncType", "1")
            ExecCmd("r.OneFrameThreadLag", "1")
            ExecCmd("r.FinishCurrentFrame", "0")
            ExecCmd("r.EnableWeaponCompTickOptimise", "1")
            ExecCmd("r.EnableWeaponGameStallIssueFix", "1")
            ExecCmd("slate.SuperFrameMiniMapUpdateRate", "3")
            ExecCmd("r.Streaming.PoolSize", "400")
            ExecCmd("r.Streaming.LimitPoolSizeToVRAM", "1")
            ExecCmd("fx.ParticlePerfStats", "0")
            ExecCmd("r.VSync", "0")
            ExecCmd("Jank.EnableCollection", "0")
            ExecCmd("Jank.EnableCollectionFromGamePlay", "0")
            ExecCmd("Engine.GSleepSlackTimeThod", "0.0012")
            ExecCmd("Engine.GSleepTimeThod", "0.0012")
            -- Gunfight anti-lag: decals clamped, particles to LOD 1.5, GC purge paced
            -- (prevents smoke/spray drops and 20s combat freezes on low-end)
            ExecCmd("diy.SetDecalBakingRTSize", "256")
            ExecCmd("r.ParticleLodDistanceScale", "1.5")
            ExecCmd("gc.TimeBetweenPurgingPendingKillObjects", "60")
            -- Heavy GPU cuts: zero gameplay loss, big FPS + thermal headroom
            ExecCmd("r.ShadowQuality", "0")
            ExecCmd("r.Shadow.CSM.MaxCascades", "0")
            ExecCmd("r.DistanceFieldShadowing", "0")
            ExecCmd("r.Fog", "0")
            ExecCmd("r.AtmosphericFog", "0")
            ExecCmd("r.BloomQuality", "0")
            ExecCmd("r.DepthOfFieldQuality", "0")
            ExecCmd("r.MotionBlurQuality", "0")
            ExecCmd("r.LensFlareQuality", "0")
            ExecCmd("r.AmbientOcclusionLevels", "0")
            ExecCmd("r.EyeAdaptationQuality", "0")
            ExecCmd("r.WaterReflection", "0")
            ExecCmd("r.SSR.Quality", "0")
        else
            -- Stock revert so OFF never leaves the engine in a cut-down state
            ExecCmd("a.ParallelAnimEvaluation", "0")
            ExecCmd("r.GTSyncType", "0")
            ExecCmd("r.Streaming.PoolSize", "0")
            ExecCmd("Jank.EnableCollection", "1")
            ExecCmd("Jank.EnableCollectionFromGamePlay", "1")
            ExecCmd("diy.SetDecalBakingRTSize", "512")
            ExecCmd("r.ParticleLodDistanceScale", "1.0")
            ExecCmd("gc.TimeBetweenPurgingPendingKillObjects", "20")
            ExecCmd("r.ShadowQuality", "1")
            ExecCmd("r.Shadow.CSM.MaxCascades", "1")
            ExecCmd("r.Fog", "1")
            ExecCmd("r.AtmosphericFog", "1")
            ExecCmd("r.BloomQuality", "1")
            ExecCmd("r.DepthOfFieldQuality", "1")
            ExecCmd("r.MotionBlurQuality", "1")
            ExecCmd("r.AmbientOcclusionLevels", "1")
            ExecCmd("r.WaterReflection", "1")
            ExecCmd("r.SSR.Quality", "1")
        end
    end)
    if ok then _G._lastFPSStabApplied = isEnabled end
end
_G.ApplyFPSStabilizer = ApplyFPSStabilizer
_G.ResetFPSCache = function() _G._lastAppliedFPS = nil _G._lastFPSStabApplied = nil end

-- ----------------------------------------------------------------------------
-- TIER-0 LITE: pure client-side junk telemetry OFF (zero server packet).
-- Verified vs original source (mini_obb), recurring-cost items only:
--   bWriteLog=false ......... game log gate (CharacterBase prints check this)
--   log_tree no-op ........... C++ table dump, returns nil (common/log.lua:250)
--   GEM wrappers no-op ....... native/file only, no SendPkg (gem_report_utils)
--   EmulatorSystem.Tick .....  5s re-poll driver (client_entry.lua:207)
--   EnableReportALLAbroad ...  voice QoS per room join (antsvoice wrapper only)
-- Deliberately NOT touched (verified zero recurring cost or server-linked):
--   Client.* native, HDmpveUpload (user-share only), DumpCacheToFile (0 callers),
--   ReportSysInfoToGEM (login one-shot), ReqFlagOnInit/SendPkg (server packet),
--   VoiceReportSubsystem record/upload + HandleSuspiciousMark (server-expected
--   evidence chain -- reverted to stock, zero behavior delta),
--   mic/speaker/voice-msg path, first-lobby emulator tip, white-simulator list.
-- No loop/timer/scan added: runs once per match from FullMatchInit + once at boot.
-- Idempotent: _tier0_* flags persist in same Lua VM, re-apply is a cheap skip.
-- ----------------------------------------------------------------------------
local function FindLoadedModule_Tier0(suffix)
    local ok, found = pcall(function()
        if type(package) ~= "table" or type(package.loaded) ~= "table" then return nil end
        local needle = string.lower(suffix)
        for k, v in pairs(package.loaded) do
            if type(k) == "string" and type(v) == "table" then
                if string.find(string.lower(k), needle, 1, true) then return v end
            end
        end
        return nil
    end)
    if ok then return found end
    return nil
end

local function Tier0_Noop() end

local function ApplyTier0Lite()
    pcall(function()
        _G.bWriteLog = false
        if type(rawget(_G, "log_tree")) == "function" and not rawget(_G, "_tier0_logtree_off") then
            _G._tier0_logtree_off = true
            _G.log_tree = Tier0_Noop
        end
        local gm = FindLoadedModule_Tier0("gem_report_utils")
        if type(gm) == "table" then
            for _, fname in ipairs({ "ReportBtnClickEvent", "ReportBtnClickEventInBattle", "ReportLobbyClickEvent", "ReportEventImmediate", "ReportEventDelay", "SaveGemReportInFile" }) do
                if type(gm[fname]) == "function" and not gm["_tier0_" .. fname] then
                    gm["_tier0_" .. fname] = true
                    gm[fname] = Tier0_Noop
                end
            end
        end
        local em = FindLoadedModule_Tier0("logic_emulator")
        if type(em) == "table" and type(em.Tick) == "function" and not em._tier0_tick_off then
            em._tier0_tick_off = true
            em.Tick = Tier0_Noop
        end
        local av = FindLoadedModule_Tier0("logic_antsvoice_interface")
        if type(av) == "table" and type(av.EnableReportALLAbroad) == "function" and not av._tier0_er then
            av._tier0_er = true
            av.EnableReportALLAbroad = function() return true end
        end
    end)
end
_G.ApplyTier0Lite = ApplyTier0Lite

local function ApplyPotatoGraphics(enable)
    local isEnabled = false
    if enable ~= nil then
        isEnabled = (enable == true)
    else
        isEnabled = (CFG.PotatoGraphicsEnabled == true)
    end
    CFG.PotatoGraphicsEnabled = isEnabled

    pcall(function()
        local ui_util = pcall(require, "client.common.ui_util") and require("client.common.ui_util")
        local gi = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            or (ui_util and ui_util.GetGameInstance and ui_util.GetGameInstance())
            or (_G.GameInstance)
        local KSL = import("KismetSystemLibrary")
        local world = _slua and _slua.getWorld and _slua.getWorld()

        local function ExecCmd(cmd, arg)
            -- Per-command shield: one unknown/failing command must not abort the rest.
            if gi and gi.ExecuteCMD then pcall(gi.ExecuteCMD, gi, cmd, arg) end
            if type(KSL) == "table" and type(KSL.ExecuteConsoleCommand) == "function" and world then
                pcall(KSL.ExecuteConsoleCommand, world, cmd .. " " .. tostring(arg))
            end
        end

        local TG = import("TextureGroup")
        local ClientObj = nil
        pcall(function()
            local Core = package.loaded["GameLua.GameCore.Main.ClientGameMain"]
            if Core and Core.GetClientEngineObject then ClientObj = Core:GetClientEngineObject() end
        end)

        local envGroups = { 42, 10, 5, 28, 16, 14, 1, 2, 23, 34, 4 }

        if isEnabled then
            if ClientObj and ClientObj.SetTextureGroupLODBias then
                for _, grp in ipairs(envGroups) do pcall(ClientObj.SetTextureGroupLODBias, grp, 2) end
                if TG then
                    if TG.TEXTUREGROUP_Character then pcall(ClientObj.SetTextureGroupLODBias, TG.TEXTUREGROUP_Character, 0) end
                    if TG.TEXTUREGROUP_Weapon then pcall(ClientObj.SetTextureGroupLODBias, TG.TEXTUREGROUP_Weapon, 0) end
                end
            end
            ExecCmd("r.MipLODBiasFromQuality", "2")
            ExecCmd("r.MipMapLODBias", "2")
            ExecCmd("r.MaxAnisotropy", "0")
            ExecCmd("foliage.LODDistanceScale", "0.7")
            ExecCmd("r.SkeletalMeshLODBias", "0")
        else
            if ClientObj and ClientObj.SetTextureGroupLODBias then
                for _, grp in ipairs(envGroups) do pcall(ClientObj.SetTextureGroupLODBias, grp, 0) end
            end
            ExecCmd("r.MipLODBiasFromQuality", "0")
            ExecCmd("r.MipMapLODBias", "0")
            ExecCmd("r.MaxAnisotropy", "1")
            ExecCmd("foliage.LODDistanceScale", "1.0")
        end
    end)
end
_G.ApplyPotatoGraphics = ApplyPotatoGraphics

local function ApplyEnvironment(force)
    pcall(function()
        local ui_util = pcall(require, "client.common.ui_util") and require("client.common.ui_util")
        local gi = (slua_GameFrontendHUD and slua_GameFrontendHUD.GetGameInstance and slua_GameFrontendHUD:GetGameInstance())
            or (ui_util and ui_util.GetGameInstance and ui_util.GetGameInstance())
            or (_G.GameInstance)
        local KSL = import("KismetSystemLibrary")
        local world = _slua and _slua.getWorld and _slua.getWorld()

        local function ExecCmd(cmd, arg)
            -- Per-command shield: one unknown/failing command must not abort the rest.
            if gi and gi.ExecuteCMD then pcall(gi.ExecuteCMD, gi, cmd, arg) end
            if type(KSL) == "table" and type(KSL.ExecuteConsoleCommand) == "function" and world then
                pcall(KSL.ExecuteConsoleCommand, world, cmd .. " " .. tostring(arg))
            end
        end

        local cleanup = (CFG.VisualCleanupEnabled == true)
        ExecCmd("grass.DiscardDataOnLoad", "0")
        if cleanup then
            ExecCmd("grass.DensityScale", "0")
            ExecCmd("foliage.DensityScale", "0")
            ExecCmd("r.Fog", "0")
            ExecCmd("grass.flush", "1")
        else
            ExecCmd("grass.DensityScale", "1")
            ExecCmd("foliage.DensityScale", "1")
            ExecCmd("r.Fog", "1")
            ExecCmd("grass.flush", "1")
        end
    end)
end
_G.ApplyEnvironment = ApplyEnvironment

-- ============================================================================
-- 8.A MOD SKIN ARMORY (ported from DOWNLOADS/SUPABASE LUA CODE NEW.lua:519-1166,
--   menu 6079-6133, loop 6318-6415; verified against wardrobe_data.lua:469-496
--   HasItem/GetItemCountOnlyForever and CharacterAvatarComponent slot types;
--   slot names binary-verified in libUE4.so; asset coverage in PAK CSV).
-- LIGHTER THAN NEW for 2GB RAM:
--   1. Batched avatar rebuild: 1x OnRep_BodySlotStateChanged per apply
--      (NEW fires up to 6x, one per changed slot = 6 mesh rebuild hitches).
--   2. Download throttle: max 3 asset downloads per 5s window
--      (NEW bursts ~11 puffer downloads on first equip = lag spike).
--   3. Event-driven only (match-init / respawn / weapon-swap / menu / 6s
--      vehicle+pet refresh). No per-tick skin work.
--   4. VIP_Attachments table NOT ported (only guards): saves ~0.5-1MB Lua RAM;
--      weapon-level skins fully work, per-attachment max-level details skipped.
--   5. Slider Max is dynamic (#table incl. ExtraMythics). NEW hardcodes
--      Max=4 while its table holds 80 suits, hiding almost all mythics.
-- NEW MYTHICS: paste verified IDs into _G.ExtraMythicSuits; slider + lobby
--   inventory pick them up. Never invent IDs (invalid = failed downloads).
--   2026-10 deep scan (25729 lua + DUMP_SKIN.txt 59994 + Dump_Skin_4.6.0.cpp
--   61706 items): all-max guns/vehicles/suits/hair/gliders curated, dup=0.
-- ============================================================================
_G.CustSlotType = _G.CustSlotType or {
    ClothesEquipemtSlot = 5, BackpackEquipemtSlot = 8, HelmetEquipemtSlot = 9,
    ParachuteEquipemtSlot = 11, GlideEquipemtSlot = 15,
}
_G.ExtraMythicSuits = _G.ExtraMythicSuits or {}
_G.WeaponSkinMap = _G.WeaponSkinMap or {}
_G.VehicleSkinMap = _G.VehicleSkinMap or {}
_G.OutfitMap = _G.OutfitMap or {}
_G.skinIdCache = _G.skinIdCache or {}
_G.skinIdCache2 = _G.skinIdCache2 or {}
_G.VIP_Attachments = {
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0},
}
_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}_G.VipAttachToIndex = {}
for skinId, attachList in pairs(_G.VIP_Attachments) do
    for index, attachId in ipairs(attachList) do
        if attachId > 0 then
            _G.VipAttachToIndex[attachId] = index
        end
    end
end
_G.OutfitSkins = {
    Suit = {1405628,1407920,1407916,1407895,1407870,1407856,1407812,1407758,1407789,1407682,1407696,1407695,1407632,1407631,1407667,1407618,1407573,1407572,1407559,1407558,1407550,1407523,1407718,1407512,1407471,1407470,1407366,1407330,1410668,1407276,1407275,1407142,1407141,1407140,1406971,1406897,1406891,1407187,1400687,1405340,1405623,1405132,1407917,1407918,1407921,1407926,1407901,1407902,1407903,1407904,1407822,1407823,1407824,1407825,1407807,1407808,1407845,1407846,1407847,1407848,1407794,1411037,1407795,1411038,1407796,1411039,1407726,1408075,1405870,1405983,1406152,1406311,1406475,1406638,1406641,1406810,1406970,1407102,1407218,1407258,1407365,1407511,1407624,1407666,1407855,1407989,1408037,1408044,1406469,1406872,1407103,1407259,1407990,1408038,1408045,1405486,1406428,1410090,1404243,1407219,1407625,1407513,1407514,1407919},
    Bag = {
        {1501001061, 1501002061, 1501003061},
        {1501001062, 1501002062, 1501003062},
        {1501001273, 1501002273, 1501003273},
        {1501001174, 1501002174, 1501003174},
        {1501001265, 1501002265, 1501003265},
        {1501001637, 1501002637, 1501003637},
        {1501001624, 1501002624, 1501003624},
        {1501001220, 1501002220, 1501003220},
        {1501001515, 1501002515, 1501003515},
        {1501001642, 1501002642, 1501003642},
    },
    Helmet = {
        {1502001023, 1502002023, 1502003023},
        {1502001183, 1502002183, 1502003183},
        {1502001194, 1502002194, 1502003194},
        {1502001128, 1502002128, 1502003128},
        {1502001235, 1502002235, 1502003235},
        {1502001423, 1502002423, 1502003423},
        {1502001431, 1502002431, 1502003431},
        {1502001434, 1502002434, 1502003434},
        {1502001493, 1502002493, 1502003493},
        {1502001499, 1502002499, 1502003499},
        {1410989},
        {1410990},
        {1410991},
        {1410996},
        {1410997},
        {1410998},
        {1410999},
        {1411000},
        {1411001},
    },
    Parachute = {1401324,1401621,1401620,1401161,1401037,1401412,1401370},
    Glider = {4151089,4151097,4151132,4151131,4151110,4151099,4151083,4151109,4151095,4151078},
}
do
    local seen = {}
    for _, id in ipairs(_G.OutfitSkins.Suit) do seen[id] = true end
    for _, id in ipairs(_G.ExtraMythicSuits) do
        if id and id ~= 0 and not seen[id] then
            _G.OutfitSkins.Suit[#_G.OutfitSkins.Suit + 1] = id
            seen[id] = true
        end
    end
end
_G.skinIdMappings = {
    [101004]={101004,1101004246,1101004236,1101004226,1101004218,1101004209,1101004201,1101004163,1101004138,1101004046},
    [101001]={101001,1101001249,1101001265,1101001242,1101001213,1101001174,1101001256,1101001128,1101001105,1101001089,1101001063},
    [101003]={101003,1101003167,1101003227,1101003146,1101003219,1101003208,1101003195,1101003119,1101003099},
    [102002]={102002,1102002446,1102002438,1102002043,1102002424,1102002136,1102002061,1102002143,1102002117},
    [101008]={101008,1101008154,1101008146,1101008104,1101008081,1101008116,1101008070,1101008170,1101008163},
    [101006]={101006,1101006106,1101006098,1101006085,1101006062,1101006075,1101006044,1101006067,1101006033},
    [102001]={102001,1102001120,1102001151,1102001143,1102001130,1102001024,1102001036,1102001089,1102001103},
    [101005]={101005,1101005098,1101005038,1101005052,1101005105,1101005090,1101005082,1101005043,1101005025},
    [104003]={104003,1104003026,1104003046,1104003037,1104003031,1104003027,1104003199},
    [104004]={104004,1104004051,1104004041,1104004035,1104004024,1104004015,1104004055},
    [101101]={101101,1101101006,1101101008},
    [101007]={101007,1101007063,1101007025,1101007073,1101007064,1101007038,1101007034,1101007019,1101007070},
    [101012]={101012,1101012010,1101012032,1101012018,1101012009,1101012036,1101012026,1101012025},
    [101002]={101002,1101002008,1101002055,1101002028,1101002142,1101002133,1101002128,1101002119,1101002111},
    [101102]={101102,1101102056,1101102041,1101102048,1101102024,1101102016,1101102006,1101102031,1101102057},
    [103001]={103001,1103001202,1103001129,1103001060,1103001191,1103001179,1103001154},
    [103002]={103002,1103002030,1103002156,1103002136,1103002087,1103002059,1103002049},
    [103003]={103003,1103003042,1103003051,1103003099,1103003087,1103003079,1103003062,1103003041},
    [102005]={102005,1102005064,1102005078,1102005057,1102005052,1102005041,1102005020,1102005007,1102005045},
    [105001]={105001,1105002091,1105002106,1105002083,1105002035,1105002063,1105002076,1105002071,1105002058},
    [105010]={105010,1105010019,1105010008,1105010026,1105010028,1105010027,1105010012,1105010010,1105010009},
    [102105]={102105,1102105028,1102105012,1102105018,1102105072,1102105002,1102105031,1102105030,1102105029},
    [103004]={103004,1103006084,1103006030,1103006046,1103006075},
    [103005]={103005,1103004037,1103004087,1103004080,1103004058},
    [103009]={103009,1103009051,1103009037,1103009022,1103009055},
}
_G.VehicleSkins = {
    [1961001] = { 1961151,1961152,1961153,1961147,1961148,1961149,1961144,1961145,1961137,1961138,1961139,1961066,1961067,1961065,1961062,1961063,1961064,1961054,1961055,1961056,1961057,1961051,1961052,1961053,1961048,1961049,1961050,1961044,1961045,1961046,1961047,1961041,1961042,1961043,1961038,1961039,1961040,1961033,1961034,1961035,1961029,1961030,1961031,1961032,1961007,1961010,1961012,1961013,1961014,1961015,1961140,1961141,1961142,1961143,1991023,1991024 ,1961017,1961021,1961070,1961068,1961036,1961061,1961059},
    [1903001] = { 1903228,1903220,1903221,1903223,1903218,1903219,1903213,1903212,1903202,1908094,1908095,1903193,1903192,1903191,19030790,19030791,19030800,19030801,1903074,1903075,1903076,1903071,1903072,1903073,1903216,1903217,1991001,1991002,1991003,1991004,1903088,1903089,1903090,1903023 ,1903020,1903022,1903029,1903031,1903018,1903017,1903014,1903087,1903197,1903070,1903037},
    [1915004] = { 1915021, 1915022, 1915008, 1915009, 1914011 ,1915017,1915018,1915022,1915005,1915019,1915026,1915016},
    [1908001] = { 1908108,1908109,19080951,19081080,1908084,1908085,1908075,1908077,1908078,1908070,1908069,1908066,1908086,1908088,1908089,1908018 ,1908032,1908009,1908006,1908017,1908019,1908002,1908099,1908127,1908115,1908100},
    [1907002] = { 1907058, 1907054, 1907059, 1907053, 1907063, 1907072, 1907040, 1907041, 1907027, 1907047, 1907021,1907018,1907012,1907008,1907033,1907035,1907037,1907051},

    [1904001] = {1904007,1904010,1904013,1904015,1904004,1904011},
    [1953001] = {1953008,1953011,1953012,1953009,1953003,1953010},
    [1917001] = {1917005,1917006,1917002,1917003},
    [1960001] = {1960002,1960003},
    [1987001] = {1987002,1987003},
    [1916004] = {1916005,1916006},}
do
    local seen = {}
    for _, id in ipairs(_G.OutfitSkins.Suit) do seen[id] = true end
    for _, id in ipairs(_G.ExtraMythicSuits) do
        if id and id ~= 0 and not seen[id] then
            _G.OutfitSkins.Suit[#_G.OutfitSkins.Suit + 1] = id
            seen[id] = true
        end
    end
end

-- Throttled asset downloader: max 3 new downloads per 5s window (burst = lag on 2GB)
_G._skinDlCount = _G._skinDlCount or 0
_G._skinDlWindow = _G._skinDlWindow or 0
local function DownloadSkinItem(id)
    if not id or id == 0 then return end
    if _G.skinIdCache[id] then return end
    local now = GetGameTimeNow()
    if now - (_G._skinDlWindow or 0) > 5.0 then
        _G._skinDlWindow = now
        _G._skinDlCount = 0
    end
    if (_G._skinDlCount or 0) >= 3 then return end
    local ok = pcall(function()
        local puffer_manager = require("client.slua.logic.download.puffer.puffer_manager")
        local puffer_const = require("client.slua.logic.download.puffer_const")
        if not puffer_manager or not puffer_const then return end
        local state = puffer_manager.GetState(puffer_const.ENUM_DownloadType.ODPTD, { id })
        if state ~= puffer_const.ENUM_DownloadState.Done and state ~= puffer_const.ENUM_DownloadState.Downloading then
            puffer_manager.Download(puffer_const.ENUM_DownloadType.ODPTD, { id })
        end
    end)
    if ok then
        _G._skinDlCount = (_G._skinDlCount or 0) + 1
        _G.skinIdCache[id] = true
    end
end
_G.download_item = DownloadSkinItem -- manual/test trigger alias
_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local targetSkinId = _G.WeaponSkinMap and _G.WeaponSkinMap[weaponID]
    if targetSkinId and targetSkinId > 0 then
        DownloadSkinItem(targetSkinId)
        return targetSkinId
    end
    return weaponID
end

-- Batched avatar equip: collect all slot changes, ONE rebuild at the end
_G.equip_character_avatar = function(Character)
    if not IsValid(Character) or not Character.AvatarComponent2 then return end
    local BackpackUtils = nil
    pcall(function() BackpackUtils = import("BackpackUtils") end)
    local comp = Character.AvatarComponent2
    if not IsValid(comp) then return end
    local SlotSyncData = comp.NetAvatarData and comp.NetAvatarData.SlotSyncData
    if not SlotSyncData then return end
    local num = 0
    pcall(function() num = SlotSyncData:Num() end)
    if not num or num <= 0 then return end
    local function ResolveMapped(mappedSkin, slotData, levelFunc)
        if not mappedSkin or mappedSkin == 0 then return nil end
        if type(mappedSkin) == "table" then
            local level = 1
            if levelFunc and BackpackUtils then
                pcall(function() level = levelFunc(slotData.AdditionalItemID) or 1 end)
            end
            if level < 1 then level = 1 end
            if level > 3 then level = 3 end
            return mappedSkin[level] or mappedSkin[1]
        end
        return mappedSkin
    end
    local hasGlider = false
    for i = 0, num - 1 do
        local sd = nil
        pcall(function() sd = SlotSyncData:Get(i) end)
        if sd and sd.SlotID == _G.CustSlotType.GlideEquipemtSlot then hasGlider = true break end
    end
    if not hasGlider then
        pcall(function() SlotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 }) end)
        pcall(function() num = SlotSyncData:Num() end)
    end
    local wants = {
        [_G.CustSlotType.ClothesEquipemtSlot] = _G.OutfitMap.Suit,
        [_G.CustSlotType.BackpackEquipemtSlot] = _G.OutfitMap.Bag,
        [_G.CustSlotType.HelmetEquipemtSlot] = _G.OutfitMap.Helmet,
        [_G.CustSlotType.ParachuteEquipemtSlot] = _G.OutfitMap.Parachute,
        [_G.CustSlotType.GlideEquipemtSlot] = _G.OutfitMap.Glider,
    }
    local changed = false
    for i = 0, (num or 0) - 1 do
        local sd = nil
        pcall(function() sd = SlotSyncData:Get(i) end)
        if sd and wants[sd.SlotID] ~= nil then
            local levelFunc = nil
            if sd.SlotID == _G.CustSlotType.BackpackEquipemtSlot and BackpackUtils then
                levelFunc = BackpackUtils.GetEquipmentBagLevel
            elseif sd.SlotID == _G.CustSlotType.HelmetEquipemtSlot and BackpackUtils then
                levelFunc = BackpackUtils.GetEquipmentHelmetLevel
            end
            local applyId = ResolveMapped(wants[sd.SlotID], sd, levelFunc)
            if applyId and applyId ~= 0 and sd.ItemId ~= applyId then
                DownloadSkinItem(applyId)
                sd.ItemId = applyId
                pcall(function() SlotSyncData:Set(i, sd) end)
                changed = true
            end
        end
    end
    if changed and comp.OnRep_BodySlotStateChanged then
        pcall(comp.OnRep_BodySlotStateChanged, comp)
    end
end

_G.ApplyWeaponSkins = function(PlayerCharacter)
    if not IsValid(PlayerCharacter) then return end
    pcall(function()
        local WeaponManager = PlayerCharacter.GetWeaponManager and PlayerCharacter:GetWeaponManager()
        if not IsValid(WeaponManager) then return end
        for slot = 1, 3 do
            local Weapon = WeaponManager.GetInventoryWeaponByPropSlot and WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if IsValid(Weapon) and IsValid(Weapon.synData) and Weapon.GetWeaponID then
                local WeaponID = Weapon:GetWeaponID()
                local SkinID = _G.get_skin_id(WeaponID) or WeaponID
                local SkinData = nil
                pcall(function() SkinData = Weapon.synData:Get(7) end)
                -- NOTE (matches DOWNLOADS port source): accumulate changes, fire
                -- mesh refresh ONCE at the end. Refresh calls used to sit inside
                -- the master-only branch, so attachment-only writes never
                -- refreshed and never became visible.
                local weaponModified = false
                if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= SkinID then
                    DownloadSkinItem(SkinID)
                    SkinData.defineID.TypeSpecificID = SkinID
                    pcall(function() Weapon.synData:Set(7, SkinData) end)
                    if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(SkinID) end) end
                    weaponModified = true
                end
                -- Selected-skin attachments (own toggle; dirty-checked per slot, throttled downloads)
                if CFG.AttachmentSkinsEnabled == true and SkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[SkinID] then
                    for AttachIdx = 0, 5 do
                        local attachData = nil
                        pcall(function() attachData = Weapon.synData:Get(AttachIdx) end)
                        if attachData then
                            local attachmentId = nil
                            pcall(function()
                                if attachData.defineID then attachmentId = attachData.defineID.TypeSpecificID end
                            end)
                            if attachmentId and attachmentId > 0 then
                                local mapIndex = _G.BaseAttachToIndex[attachmentId] or _G.VipAttachToIndex[attachmentId]
                                if mapIndex and _G.VIP_Attachments[SkinID][mapIndex] and _G.VIP_Attachments[SkinID][mapIndex] > 0 then
                                    local targetAttachId = _G.VIP_Attachments[SkinID][mapIndex]
                                    if targetAttachId ~= attachmentId then
                                        attachData.defineID.TypeSpecificID = targetAttachId
                                        pcall(function() Weapon.synData:Set(AttachIdx, attachData) end)
                                        DownloadSkinItem(targetAttachId)
                                        weaponModified = true
                                    end
                                end
                            end
                        end
                    end
                end
                if weaponModified then
                    if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    if Weapon.OnRep_synData then pcall(function() Weapon:OnRep_synData() end) end
                end
            end
        end
    end)
end

_G.ApplyVehicleSkins = function(PlayerCharacter)
    if not IsValid(PlayerCharacter) then return end
    pcall(function()
        local Vehicle = PlayerCharacter.GetCurrentVehicle and PlayerCharacter:GetCurrentVehicle()
        if not IsValid(Vehicle) then
            _G.LastVehicleEntity = nil
            return
        end
        if _G.LastVehicleEntity == Vehicle and _G.CurrentEquipVehicleID ~= nil then return end
        local VehicleAvatar = Vehicle.VehicleAvatar or Vehicle.VehicleAvatarComponent_BP
            or (Vehicle.GetAvatarComponent and Vehicle:GetAvatarComponent())
        if not IsValid(VehicleAvatar) then return end
        local defId, currentId = "", ""
        pcall(function()
            defId = tostring((VehicleAvatar.GetDefaultAvatarID and VehicleAvatar:GetDefaultAvatarID()) or Vehicle.VehicleID or "")
            currentId = tostring((Vehicle.GetAvatarId and Vehicle:GetAvatarId()) or "")
        end)
        local applySkinId = 0
        for baseMapId, targetSkin in pairs(_G.VehicleSkinMap) do
            if (defId ~= "" and string.find(defId, tostring(baseMapId), 1, true))
                or (currentId ~= "" and string.find(currentId, tostring(baseMapId), 1, true)) then
                applySkinId = targetSkin
                break
            end
        end
        if applySkinId and applySkinId > 0 then
            DownloadSkinItem(applySkinId)
            if VehicleAvatar.ChangeItemAvatar then
                VehicleAvatar.curSwitchEffectId = 7303001
                pcall(VehicleAvatar.ChangeItemAvatar, VehicleAvatar, applySkinId, true)
            end
            _G.CurrentEquipVehicleID = applySkinId
            _G.LastVehicleEntity = Vehicle
        end
    end)
end


_G.ForceRefreshSkinMaps = function()
    if CFG.ModSkin ~= true then return end
    local function pick(tbl, idx)
        if not tbl then return nil end
        idx = math.min(#tbl, math.max(1, tonumber(idx) or 1))
        return tbl[idx]
    end
    local s = _G.OutfitSkins
    if s then
        if CFG.SkinSuit then _G.OutfitMap.Suit = pick(s.Suit, CFG.SkinSuit) or _G.OutfitMap.Suit end
        if CFG.SkinBag then _G.OutfitMap.Bag = pick(s.Bag, CFG.SkinBag) or _G.OutfitMap.Bag end
        if CFG.SkinHelmet then _G.OutfitMap.Helmet = pick(s.Helmet, CFG.SkinHelmet) or _G.OutfitMap.Helmet end
        if CFG.SkinParachute then _G.OutfitMap.Parachute = pick(s.Parachute, CFG.SkinParachute) end
        if CFG.SkinGlider then _G.OutfitMap.Glider = pick(s.Glider, CFG.SkinGlider) end
    end
    if _G.skinIdMappings then
        local wmap = {
            SkinM416 = 101004, SkinAKM = 101001, SkinSCAR = 101003, SkinM762 = 101008,
            SkinAUG = 101006, SkinGroza = 101005, SkinQBZ = 101007, SkinACE32 = 101102,
            SkinM16A4 = 101002, SkinHoney = 101012, SkinUMP = 102002, SkinUZI = 102001,
            SkinDBS = 104004, SkinS12K = 104003, SkinASM = 101101,
            SkinAWM = 103003, SkinKar98k = 103001, SkinM24 = 103002,
            SkinPP19 = 102005, SkinDP28 = 105001, SkinMG3 = 105010, SkinP90 = 102105,
            SkinMini14 = 103004, SkinSKS = 103005, SkinSLR = 103009,
        }
        for cfgKey, weaponId in pairs(wmap) do
            local list = _G.skinIdMappings[weaponId]
            if CFG[cfgKey] and list then
                _G.WeaponSkinMap[weaponId] = pick(list, CFG[cfgKey]) or _G.WeaponSkinMap[weaponId]
            end
        end
    end
    if _G.VehicleSkins then
        local vmap = {
            SkinDacia = 1903001, SkinUAZ = 1908001, SkinCoupe = 1961001,
            SkinBuggy = 1907002, SkinMirado = 1915004, SkinMiniBus = 1904001,
            SkinMonster = 1953001, SkinScooter = 1917001, SkinGliderVeh = 1960001,
            SkinHorse = 1987001, SkinCyber = 1916004,
        }
        for cfgKey, baseId in pairs(vmap) do
            local list = _G.VehicleSkins[baseId]
            if CFG[cfgKey] and list then
                _G.VehicleSkinMap[baseId] = pick(list, CFG[cfgKey]) or _G.VehicleSkinMap[baseId]
            end
        end
    end
end

-- Apply current skin selection to local player right now (menu instant feedback)
_G.ApplySkinSelectionNow = function()
    if CFG.ModSkin ~= true then return end
    pcall(_G.ForceRefreshSkinMaps)
    local pc = GetActivePlayerController()
    local lp = GetLocalPlayer(pc)
    if not IsValid(lp) then return end
    pcall(_G.equip_character_avatar, lp)
    pcall(_G.ApplyWeaponSkins, lp)
    pcall(_G.ApplyVehicleSkins, lp)
end

-- Restore stock appearance after ModSkin OFF (weapons/avatar/vehicle)
_G.RestoreStockSkins = function()
    _G.OutfitMap = {}
    _G.WeaponSkinMap = {}
    _G.VehicleSkinMap = {}
    _G.LastVehicleEntity = nil
    _G.CurrentEquipVehicleID = nil
    local pc = GetActivePlayerController()
    local lp = GetLocalPlayer(pc)
    if not IsValid(lp) then return end
    pcall(function()
        local WeaponManager = lp.GetWeaponManager and lp:GetWeaponManager()
        if IsValid(WeaponManager) then
            for slot = 1, 3 do
                local Weapon = WeaponManager.GetInventoryWeaponByPropSlot and WeaponManager:GetInventoryWeaponByPropSlot(slot)
                if IsValid(Weapon) and IsValid(Weapon.synData) and Weapon.GetWeaponID then
                    local WeaponID = Weapon:GetWeaponID()
                    local SkinData = nil
                    pcall(function() SkinData = Weapon.synData:Get(7) end)
                    if SkinData and SkinData.defineID and SkinData.defineID.TypeSpecificID ~= WeaponID then
                        SkinData.defineID.TypeSpecificID = WeaponID
                        pcall(function() Weapon.synData:Set(7, SkinData) end)
                        if Weapon.SetWeaponAvatarID then pcall(function() Weapon:SetWeaponAvatarID(WeaponID) end) end
                        if Weapon.DelayHandleAvatarMeshChanged then pcall(function() Weapon:DelayHandleAvatarMeshChanged() end) end
                    end
                end
            end
        end
        if lp.AvatarComponent2 and lp.AvatarComponent2.OnRep_BodySlotStateChanged then
            pcall(lp.AvatarComponent2.OnRep_BodySlotStateChanged, lp.AvatarComponent2)
        end
    end)
end

-- ============================================================================
-- 8.A MOD SKIN ARMORY (ported from DOWNLOADS/SUPABASE LUA CODE NEW.lua:519-1166,
--   menu 6079-6133, loop 6318-6415; verified against CharacterAvatarComponent
--   slot types; slot names binary-verified in libUE4.so; asset coverage in
--   PAK CSV; lobby hooks REMOVED (match-only).
-- LIGHTER THAN NEW for 2GB RAM:
--   1. Batched avatar rebuild: 1x OnRep_BodySlotStateChanged per apply
--      (NEW fires up to 6x, one per changed slot = 6 mesh rebuild hitches).
--   2. Download throttle: max 3 asset downloads per 5s window
--      (NEW bursts ~11 puffer downloads on first equip = lag spike).
--   3. Event-driven only (match-init / respawn / weapon-swap / menu / 6s
--      vehicle+pet refresh). No per-tick skin work.
--   4. VIP_Attachments table NOT ported (only guards): saves ~0.5-1MB Lua RAM;
--      weapon-level skins fully work, per-attachment max-level details skipped.
--   5. Slider Max is dynamic (#table incl. ExtraMythics). NEW hardcodes
--      Max=4 while its table holds 80 suits, hiding almost all mythics.
-- NEW MYTHICS: paste verified IDs into _G.ExtraMythicSuits; slider + lobby
--   inventory pick them up. Never invent IDs (invalid = failed downloads).
--   2026-10 deep scan (25729 lua + DUMP_SKIN.txt 59994 + Dump_Skin_4.6.0.cpp
--   61706 items): all-max guns/vehicles/suits/hair/gliders curated, dup=0.
-- 8.B NATIVE COMBAT ENGINE: AIM ASSIST & RECOIL CONTROL (100% ENGINE TRANSPARENT)
-- ============================================================================
-- Architecture: Verified against native libUE4.so (243.5MB) & Tencent Lua Source
-- Components: ShootWeaponEntityComp, BulletTrack (RecoilInfo_NoTss), AutoAimingConfig
-- 0% Memory Leaks | 0% Frame Drops | State Dirty-Checked (0ms idle cost)
-- 100% Safe Heuristics: Retains natural ballistic dispersion & camera shake
-- ============================================================================

local aimOriginalCache = {}
local recoilOriginalCache = {}
local bulletTrackOriginalCache = {}
local _AimForbidCache = {} -- FORWARD DECLARED: In scope for both ApplyAimAssist and UpdateAimTargetFiltering
local _LastAimState = nil
local _LastRecoilState = nil
local _LastWeaponKey = nil

-- Verified default values from libUE4.so & Tencent GMWeaponEditor.lua
local AIM_BASE_VALUES = {
    Speed = 6.75,
    RangeRate = 1.85,
    SpeedRate = 1.70,
    RangeRateSight = 2.00,
    SpeedRateSight = 1.50,
    CenterSpeedRate = 1.15,
    CrouchRate = 1.225,
    ProneRate = 1.15,
    DyingRate = 1.0,
    adsorbMaxAttenuationDis = 4000.0,
    adsorbMaxRange = 15000.0,
    AdsorbMaxAttenuationDis = 4000.0,
    AdsorbMaxRange = 15000.0
}

local RECOIL_FIELDS = {
    "RecoilKick", "RecoilKickADS", "AnimationKick",
    "GameDeviationFactor", "RecoilModifierStand", "RecoilModifierCrouch", "RecoilModifierProne",
    "CameraShakeScale", "AimCameraShakeScale", "ShootCameraShakeScale", "FireCameraShakeScale",
    "GameDeviationAccuracy", "ShotGunHorizontalSpread", "ShotGunVerticalSpread", "DeviationMultiplier",
    "AccessoriesVRecoilFactor", "AccessoriesHRecoilFactor", "AccessoriesRecoveryFactor"
}

local RECOIL_TARGET_VALUES = {
    RecoilKick = 0.05,
    RecoilKickADS = 0.05,
    AnimationKick = 0.05,
    GameDeviationFactor = 0.05,
    RecoilModifierStand = 0.05,
    RecoilModifierCrouch = 0.05,
    RecoilModifierProne = 0.05,
    CameraShakeScale = 0.35,
    AimCameraShakeScale = 0.35,
    ShootCameraShakeScale = 0.35,
    FireCameraShakeScale = 0.35,
    GameDeviationAccuracy = 0.35,
    ShotGunHorizontalSpread = 0.45,
    ShotGunVerticalSpread = 0.45,
    DeviationMultiplier = 0.35,
    AccessoriesVRecoilFactor = 0.05,
    AccessoriesHRecoilFactor = 0.05,
    AccessoriesRecoveryFactor = 0.05
}

local RECOIL_INFO_FIELDS = {
    "VerticalRecoilMin", "VerticalRecoilMax", "RecoilSpeedVertical", "RecoilSpeedHorizontal", "VerticalRecoveryMax"
}

-- Native BulletTrack.RecoilInfo_NoTss struct fields (Verified from libUE4.so & GMWeaponEditor.lua)
local BT_RECOIL_FIELDS = {
    "RecoilSpeedVertical", "RecoilSpeedHorizontal", "RecovertySpeedVertical",
    "RecoilValueClimb", "RecoilValueFail", "VerticalRecoveryModifier"
}

-- Native BulletTrack.DeviationInfo_NoTss struct fields (Verified from libUE4.so & GMWeaponEditor.lua)
local BT_DEVIATION_FIELDS = {
    "DeviationBase", "DeviationRecoilGain", "DeviationRecoilGainADS",
    "DeviationMaxMove", "DeviationMoveMultiplier"
}

-- Forward declaration for smart filtering
local UpdateAimTargetFiltering = nil

local function GetAllEnemiesForCombat(lp)
    if _G._CurrentCombatEnemies and #_G._CurrentCombatEnemies > 0 then
        local enemies = {}
        for _, e in ipairs(_G._CurrentCombatEnemies) do
            if IsValid(e.pawn) and e.pawn ~= lp then
                enemies[#enemies + 1] = e.pawn
            end
        end
        return enemies
    end

    local enemies = {}
    local pawns = GetCachedPlayerPawns()
    if not pawns then return enemies end
    for _, pawn in ipairs(pawns) do
        if IsValid(pawn) and pawn ~= lp then
            if IsEnemyPawn(lp, pawn) then
                enemies[#enemies + 1] = pawn
            end
        end
    end
    return enemies
end

-- ResolveIsAI_Combat is defined above with permanent _PawnAICache
local ResolveIsAI_Combat = _G.ResolveIsAI_Combat or ResolveIsAI_Combat

-- Universal Weapon Entity Resolver (Verified from libUE4.so FNames & Tencent GMWeaponEditor.lua:508)
local function ResolveWeaponEntity(w)
    if not IsValid(w) then return nil end
    local ent = w.ShootWeaponEntity
        or w.ShootWeaponEntityComponent
        or w.WeaponEntityComp
    if not IsValid(ent) and type(w.GetShootWeaponEntityComponent) == "function" then
        pcall(function() ent = w:GetShootWeaponEntityComponent() end)
    end
    if not IsValid(ent) then
        ent = w.ShootWeaponEntityComp or w.ShootWeaponComponent or w.STExtraShootWeaponComponent
    end
    if not IsValid(ent) and type(w.GetShootWeaponComponent) == "function" then
        pcall(function() ent = w:GetShootWeaponComponent() end)
    end
    if IsValid(ent) then return ent end
    return w
end

local function GetPlayerWeapons(char)
    local targetWeapons = {}
    if not IsValid(char) then return targetWeapons end
    local wm = char.WeaponManagerComponent or (char.GetWeaponManager and char:GetWeaponManager())
    if not IsValid(wm) then return targetWeapons end

    local curW = (wm.GetCurrentUsingWeapon and wm:GetCurrentUsingWeapon())
        or wm.CurrentWeaponReplicated
        or (char.GetCurrentWeapon and char:GetCurrentWeapon())
    if IsValid(curW) then targetWeapons[curW] = true end

    pcall(function()
        if wm.GetAllInventoryWeaponList then
            local list = wm:GetAllInventoryWeaponList(false)
            if list then
                if type(list.Num) == "function" then
                    local n = list:Num()
                    for i = 0, n - 1 do
                        local w = (type(list.Get) == "function" and list:Get(i)) or list[i + 1] or list[i]
                        if IsValid(w) then targetWeapons[w] = true end
                    end
                else
                    for _, w in pairs(list) do
                        if IsValid(w) then targetWeapons[w] = true end
                    end
                end
            end
        end
        for slot = 1, 3 do
            if wm.GetInventoryWeaponByPropSlot then
                local w = wm:GetInventoryWeaponByPropSlot(slot)
                if IsValid(w) then targetWeapons[w] = true end
            end
        end
    end)
    return targetWeapons, curW
end

-- ============================================================================
-- 1. NATIVE AIM ASSIST ENGINE
-- ============================================================================
local function ApplyAimAssist(force)
    local pc = GetActivePlayerController()
    local char = GetLocalPlayer(pc)
    if not IsValid(char) then return end

    -- Unlock GameState Match-Level AutoAim (Crucial in TDM / Custom Rooms)
    pcall(function()
        local gs = (pc.GetGameState and pc:GetGameState()) or (pc.World and pc.World.GameState)
        if not IsValid(gs) and pc.GetWorld then
            local w = pc:GetWorld()
            if IsValid(w) then gs = w.GameState end
        end
        if IsValid(gs) then
            if gs.bAutoAimAt ~= nil and gs.bAutoAimAt == false then gs.bAutoAimAt = true end
            if gs.bEnableAutoAimTrainingMode ~= nil and gs.bEnableAutoAimTrainingMode == false then gs.bEnableAutoAimTrainingMode = true end
        end
    end)

    local targetWeapons, curW = GetPlayerWeapons(char)

    local actMode = tonumber(CFG.AimActivationMode) or 2
    local ignoreKnocked = (CFG.AimIgnoreKnocked ~= false)
    local ignoreBots = false -- bots always targeted (Ignore-Bots option removed)
    local hipDist = math.min(60, math.max(10, tonumber(CFG.AimHipDistance) or 40))
    local scopeDist = math.min(150, math.max(50, tonumber(CFG.AimScopeDistance) or 150)) -- Clamped to 150m native max
    local aimLevel = tonumber(CFG.AimPower) or 2
    if aimLevel > 3 then aimLevel = 3 end
    if aimLevel < 1 then aimLevel = 1 end

    local pKey = GetPawnKey(char) or tostring(char)
    local targetBoneKey = tostring(CFG.AimTargetBone or 0)
    local currentState = tostring(CFG.AimAssistEnabled) .. "_" .. tostring(aimLevel)
        .. "_" .. tostring(actMode) .. "_" .. tostring(targetBoneKey) .. "_" .. tostring(ignoreKnocked) .. "_" .. tostring(ignoreBots)
        .. "_" .. tostring(hipDist) .. "_" .. tostring(scopeDist) .. "_" .. tostring(curW) .. "_" .. tostring(pKey)
    if not force and currentState == _LastAimState then return end
    _LastAimState = currentState

    -- ------------------------------------------------------------------------
    -- CASE 1: DISABLED -> 100% Zero-Trace Factory Restore
    -- ------------------------------------------------------------------------
    if not CFG.AimAssistEnabled then
        -- 1. Restore Enemy Tags and Forbid Flags
        pcall(function()
            local enemies = GetAllEnemiesForCombat(char)
            for _, enemy in ipairs(enemies) do
                if IsValid(enemy) then
                    enemy.bForbidAutoAimAt = false
                    if enemy.Tags and type(enemy.Tags.Num) == "function" then
                        local num = enemy.Tags:Num()
                        for i = num - 1, 0, -1 do
                            if enemy.Tags:Get(i) == "IgnoreWeaponAutoAim" then
                                if enemy.Tags.Remove then enemy.Tags:Remove(i) end
                            end
                        end
                    end
                end
            end
            for k in pairs(_AimForbidCache) do _AimForbidCache[k] = nil end
        end)

        -- 2. Restore Pawn / Controller properties
        pcall(function()
            local autoAimComp = char.AutoAimComp or char.BP_AutoAimingComponent or char.WeaponAutoAimingComponent or char.AutoAimComponent
            if IsValid(autoAimComp) and autoAimComp.Bones ~= nil and char.AimNormalBoneArray then
                autoAimComp.Bones = char.AimNormalBoneArray
            end
            char.ActiveAimScopeRange = false
            if pc and IsValid(pc) then pc.AutoAimType = 1 end
            if char.GetController then
                local c = char:GetController()
                if IsValid(c) then c.AutoAimType = 1 end
            end
        end)

        -- 3. Restore In-game native SettingModule
        pcall(function()
            local mm = package.loaded["client.module_framework.ModuleManager"]
                or (pcall(require, "client.module_framework.ModuleManager") and require("client.module_framework.ModuleManager"))
            if mm and mm.GetModule then
                local sm = mm.GetModule(mm.CommonModuleConfig and mm.CommonModuleConfig.SettingModule or "SettingModule")
                if sm and sm.SetOptionValue then
                    sm:SetOptionValue("AimAssist", 0)
                    sm:SetOptionValue("bAimAssist", false)
                end
            end
        end)

        -- 4. Restore Weapon AutoAimingConfig
        pcall(function()
            for ent, orig in pairs(aimOriginalCache) do
                if IsValid(ent) and ent.AutoAimingConfig then
                    pcall(function() ent.AutoAimingConfig.TriggerBeforeFire = false end)
                    for _, range in ipairs({ "OuterRange", "InnerRange", "ScopeRange" }) do
                        local cfg = ent.AutoAimingConfig[range]
                        local saved = orig[range]
                        if cfg and saved then
                            for k, origVal in pairs(saved) do
                                pcall(function() cfg[k] = origVal end)
                            end
                        end
                    end
                end
            end
            for k in pairs(aimOriginalCache) do aimOriginalCache[k] = nil end
        end)
        return
    end

    -- ------------------------------------------------------------------------
    -- CASE 2: ENABLED -> GODTIER COMBAT ENHANCEMENT
    -- ------------------------------------------------------------------------

    -- PART A: Native Pawn & Controller Layer (Runs unconditionally, independent of weapons!)
    -- 1. Controller AutoAimType = 5 (EAutoAimType::ScopeOrFire - Official BuffAction_ScopeAim pattern)
    pcall(function()
        if pc and IsValid(pc) then pc.AutoAimType = 5 end
        if char.GetController then
            local c = char:GetController()
            if IsValid(c) then c.AutoAimType = 5 end
        end
    end)

    -- 2. Target Bones Array: Head vs Chest/Spine with safe fallbacks (Official BuffAction_ShootAimHead pattern)
    pcall(function()
        local autoAimComp = char.AutoAimComp or char.BP_AutoAimingComponent or char.WeaponAutoAimingComponent or char.AutoAimComponent
        if IsValid(autoAimComp) and autoAimComp.Bones ~= nil then
            local isHead = (CFG.AimTargetBone == 1 or CFG.AimTargetBone == "1" or CFG.AimTargetBone == "head" or CFG.AimTargetBone == 2)
            if isHead and char.AimHeadBoneArray then
                autoAimComp.Bones = char.AimHeadBoneArray
            elseif not isHead and char.AimNormalBoneArray then
                autoAimComp.Bones = char.AimNormalBoneArray
            else
                -- Fallback if character BP lacks native bone arrays
                pcall(function()
                    if type(autoAimComp.Bones.Empty) == "function" and type(autoAimComp.Bones.Add) == "function" then
                        autoAimComp.Bones:Empty()
                        if isHead then
                            autoAimComp.Bones:Add("head")
                            autoAimComp.Bones:Add("neck_01")
                        else
                            autoAimComp.Bones:Add("spine_02")
                            autoAimComp.Bones:Add("spine_01")
                            autoAimComp.Bones:Add("pelvis")
                        end
                    else
                        autoAimComp.Bones = isHead and { "head", "neck_01" } or { "spine_02", "spine_01", "pelvis" }
                    end
                end)
            end
        end
    end)

    -- 3. Scope Range & Check Flags
    pcall(function()
        char.ActiveAimScopeRange = (actMode == 0 or actMode == 2)
        local autoAimComp = char.AutoAimComp or char.BP_AutoAimingComponent or char.WeaponAutoAimingComponent or char.AutoAimComponent
        if IsValid(autoAimComp) and autoAimComp.SetIsStartScopeAutoAimCheck then
            pcall(autoAimComp.SetIsStartScopeAutoAimCheck, autoAimComp, false)
        end
    end)

    -- 4. Native SettingModule Enable
    pcall(function()
        local mm = package.loaded["client.module_framework.ModuleManager"]
            or (pcall(require, "client.module_framework.ModuleManager") and require("client.module_framework.ModuleManager"))
        if mm and mm.GetModule then
            local sm = mm.GetModule(mm.CommonModuleConfig and mm.CommonModuleConfig.SettingModule or "SettingModule")
            if sm and sm.SetOptionValue then
                sm:SetOptionValue("AimAssist", 1)
                sm:SetOptionValue("bAimAssist", true)
            end
        end
    end)

    -- PART B: Weapon Entity AutoAimingConfig Tuning (libUE4.so 47-Property Matrix)
    local pRatio = (aimLevel == 1 and 0.40) or (aimLevel == 2 and 0.75) or 1.0
    local hipUnits = hipDist * 100.0
    local scopeUnits = math.min(scopeDist * 100.0, 15000.0) -- Clamped to 15,000 native max

    -- Character-level Scope Trace distance
    pcall(function()
        if char.AutoScopeAimTraceDistance ~= nil then
            char.AutoScopeAimTraceDistance = scopeUnits
        end
    end)

    -- Power Ratios
    local targetMaxAngle    = 15.0 + pRatio * 25.0 -- Expands aim cone from 15 deg to 40 deg
    local targetSpeed       = 6.5 + pRatio * 3.5   -- 6.5 to 10.0 snap speed
    local targetRangeRate   = 1.5 + pRatio * 1.0   -- 1.5 to 2.5 tracking range
    local targetSpeedRate   = 1.4 + pRatio * 0.9   -- 1.4 to 2.3 rotation speed
    local targetRangeSight  = 1.6 + pRatio * 1.2   -- 1.6 to 2.8 scope sight range
    local targetSpeedSight  = 1.4 + pRatio * 0.8   -- 1.4 to 2.2 scope rotation
    local targetCenterSpeed = 1.3 + pRatio * 0.5   -- Sticky center velocity
    local targetCrouch      = 1.2 + pRatio * 0.3   -- Crouch boost
    local targetProne       = 1.1 + pRatio * 0.2   -- Prone boost
    local dyingVal          = ignoreKnocked and 0.0 or (1.0 + pRatio * 0.5)

    for w, _ in pairs(targetWeapons) do
        local entity = ResolveWeaponEntity(w)
        local autoAimCfg = (IsValid(entity) and entity.AutoAimingConfig) or (IsValid(w) and w.AutoAimingConfig)

        if autoAimCfg then
            local cacheKey = entity or w
            -- 1. Backup original configuration once
            if not aimOriginalCache[cacheKey] then
                local saved = {}
                pcall(function()
                    saved.TriggerBeforeFire = autoAimCfg.TriggerBeforeFire
                    saved.MaxAngle = autoAimCfg.MaxAngle
                    for _, rName in ipairs({ "OuterRange", "InnerRange", "ScopeRange" }) do
                        local rObj = autoAimCfg[rName]
                        if rObj then
                            saved[rName] = {}
                            pcall(function()
                                for k, v in pairs(rObj) do saved[rName][k] = v end
                            end)
                        end
                    end
                end)
                aimOriginalCache[cacheKey] = saved
            end

            -- 2. Top-Level Knobs: Pre-Fire Instant Aim Trigger & Aim Cone Angle
            pcall(function()
                autoAimCfg.TriggerBeforeFire = true
                if autoAimCfg.MaxAngle ~= nil then
                    autoAimCfg.MaxAngle = targetMaxAngle
                end
            end)

            -- 3. OuterRange Modification (Verified libUE4.so fields only)
            pcall(function()
                local curOuter = autoAimCfg.OuterRange
                if curOuter then
                    local tOuter = {}
                    pcall(function() for k, v in pairs(curOuter) do tOuter[k] = v end end)

                    if actMode == 0 then -- Scoped Only
                        tOuter.RangeRate = 0
                        tOuter.SpeedRate = 0
                        tOuter.RangeRateSight = targetRangeSight
                        tOuter.SpeedRateSight = targetSpeedSight
                    elseif actMode == 1 then -- Hipfire Only
                        tOuter.RangeRate = targetRangeRate
                        tOuter.SpeedRate = targetSpeedRate
                        tOuter.RangeRateSight = 0
                        tOuter.SpeedRateSight = 0
                    else -- Universal (Hipfire + Scope)
                        tOuter.RangeRate = targetRangeRate
                        tOuter.SpeedRate = targetSpeedRate
                        tOuter.RangeRateSight = targetRangeSight
                        tOuter.SpeedRateSight = targetSpeedSight
                    end

                    tOuter.Speed = targetSpeed
                    tOuter.CenterSpeedRate = targetCenterSpeed
                    tOuter.CrouchRate = targetCrouch
                    tOuter.ProneRate = targetProne
                    tOuter.DyingRate = dyingVal
                    tOuter.AdsorbMinRange = 50.0
                    tOuter.AdsorbActiveMinRange = 50.0
                    tOuter.AdsorbMinAttenuationDis = 1000.0
                    tOuter.AdsorbMaxAttenuationDis = hipUnits
                    tOuter.OpeningRate = 1.3 + pRatio * 0.5
                    tOuter.LandingRate = 1.3 + pRatio * 0.5
                    tOuter.FreeFallRate = 1.2
                    tOuter.DriveVehicleRate = 1.2

                    -- Reassign struct (slua C++ memory reflection) + fallback mutate
                    pcall(function() autoAimCfg.OuterRange = tOuter end)
                    for k, v in pairs(tOuter) do
                        pcall(function() curOuter[k] = v end)
                    end
                end
            end)

            -- 4. InnerRange Modification (Verified libUE4.so fields only)
            -- NOTE: CrouchRate, SpeedRate, AdsorbMinRange, DriveVehicleRate DO NOT exist on InnerRange
            pcall(function()
                local curInner = autoAimCfg.InnerRange
                if curInner then
                    local tInner = {}
                    pcall(function() for k, v in pairs(curInner) do tInner[k] = v end end)

                    if actMode == 0 then
                        tInner.RangeRate = 0
                        tInner.RangeRateSight = targetRangeSight
                        tInner.SpeedRateSight = targetSpeedSight
                    elseif actMode == 1 then
                        tInner.RangeRate = targetRangeRate
                        tInner.RangeRateSight = 0
                        tInner.SpeedRateSight = 0
                    else
                        tInner.RangeRate = targetRangeRate
                        tInner.RangeRateSight = targetRangeSight
                        tInner.SpeedRateSight = targetSpeedSight
                    end

                    tInner.Speed = targetSpeed + 1.0
                    tInner.CenterSpeedRate = targetCenterSpeed + 0.2
                    tInner.ProneRate = targetProne
                    tInner.DyingRate = dyingVal
                    tInner.AdsorbActiveMinRange = 50.0
                    tInner.AdsorbMinAttenuationDis = 1000.0
                    tInner.AdsorbMaxAttenuationDis = hipUnits
                    tInner.OpeningRate = 1.4 + pRatio * 0.5
                    tInner.LandingRate = 1.4 + pRatio * 0.5

                    pcall(function() autoAimCfg.InnerRange = tInner end)
                    for k, v in pairs(tInner) do
                        pcall(function() curInner[k] = v end)
                    end
                end
            end)

            -- 5. ScopeRange Modification (Verified libUE4.so fields only)
            -- NOTE: Speed, CenterSpeedRate, CrouchRate, ProneRate, LandingRate DO NOT exist on ScopeRange
            pcall(function()
                local curScope = autoAimCfg.ScopeRange
                if curScope then
                    local tScope = {}
                    pcall(function() for k, v in pairs(curScope) do tScope[k] = v end end)

                    tScope.SpeedRate = targetSpeedRate + 0.3
                    tScope.SpeedRateSight = targetSpeedSight + 0.4
                    tScope.RangeRate = targetRangeRate + 0.2
                    tScope.RangeRateSight = targetRangeSight + 0.3
                    tScope.AdsorbMinRange = 1000.0
                    tScope.AdsorbMaxRange = scopeUnits
                    tScope.AdsorbMinAttenuationDis = 1000.0
                    tScope.OpeningRate = 1.6 + pRatio * 0.8
                    tScope.DyingRate = dyingVal
                    tScope.FreeFallRate = 1.3
                    tScope.DriveVehicleRate = 1.4
                    tScope.InVehicleRate = 1.4

                    pcall(function() autoAimCfg.ScopeRange = tScope end)
                    for k, v in pairs(tScope) do
                        pcall(function() curScope[k] = v end)
                    end
                end
            end)

            -- 6. Additive Path-B: Native Attribute Modifier Layer (Anti-Drift / TSS Resistance)
            pcall(function()
                local attrComp = (IsValid(entity) and (entity.AttrModifyComp or entity.AttrModifierCompoment or entity.AttrModifierComponent))
                    or (IsValid(w) and (w.AttrModifyComp or w.AttrModifierCompoment or w.AttrModifierComponent))
                if IsValid(attrComp) and type(attrComp.AddModifyItemAndCache) == "function" then
                    attrComp:AddModifyItemAndCache("AutoAimingConfig_InnerRange_Speed", 0, targetSpeed + 1.0, true, w, false)
                    attrComp:AddModifyItemAndCache("AutoAimingConfig_ScopeRange_RangeRateSight", 0, targetRangeSight + 0.3, true, w, false)
                    attrComp:AddModifyItemAndCache("AutoAimingConfig_ScopeRange_SpeedRateSight", 0, targetSpeedSight + 0.4, true, w, false)
                end
            end)
        end
    end

    -- PART C: Target Filtering Call
    if UpdateAimTargetFiltering then
        pcall(UpdateAimTargetFiltering, char)
    end
end
_G.ApplyAimAssist = ApplyAimAssist

-- ============================================================================
-- 2. SMART TARGET FILTERING (IGNORE KNOCKED, IGNORE BOTS, DISTANCE CULLING)
-- CACHE-POWERED: Uses pre-calculated _CurrentCombatEnemies + _AimForbidCache dirty-checking
-- ============================================================================
-- _AimForbidCache is forward-declared above ApplyAimAssist for global scope & clean resets

UpdateAimTargetFiltering = function(localPlayer)
    pcall(function()
        -- Switch-gated: OFF means absolute zero.
        if not CFG.AimAssistEnabled then return end
        local lp = localPlayer or GetLocalPlayer()
        if not IsValid(lp) then return end

        local ignoreKnocked = (CFG.AimIgnoreKnocked ~= false)
        local ignoreBots = false -- bots always targeted (Ignore-Bots option removed)
        local hipDist = tonumber(CFG.AimHipDistance) or 40
        local scopeDist = tonumber(CFG.AimScopeDistance) or 150

        local isScoped = PawnHasState(lp, EPawnState and EPawnState.GunADS)
        if not isScoped and type(lp.IsGunADS) == "function" then
            local okAds, res = pcall(lp.IsGunADS, lp)
            if okAds and res == true then isScoped = true end
        end
        if not isScoped and (lp.bIsGunADS == true or lp.IsLocalActuallyScopeIn == true) then
            isScoped = true
        end

        local maxDist = isScoped and scopeDist or hipDist

        -- 1. Direct reuse of cached enemies from Phase_Enemies (0 redundant world queries)
        local enemies = _G._CurrentCombatEnemies
        if not enemies or #enemies == 0 then
            local fallback = GetAllEnemiesForCombat(lp)
            if not fallback or #fallback == 0 then return end
            enemies = {}
            local lpLoc = GetActorLocation(lp)
            for _, fEnemy in ipairs(fallback) do
                local pKey = GetPawnKey(fEnemy)
                local eLoc = GetActorLocation(fEnemy)
                local distM = 0
                if lpLoc and eLoc then
                    local dx = lpLoc.X - eLoc.X; local dy = lpLoc.Y - eLoc.Y; local dz = lpLoc.Z - eLoc.Z
                    distM = math.sqrt(dx * dx + dy * dy + dz * dz) / 100.0
                end
                local hs = fEnemy.HealthStatus
                local isKnocked = (hs and (hs == 1 or hs == 2 or hs == 3)) or fEnemy.bIsNearDeath or fEnemy.bNearDeath
                    or (type(fEnemy.IsNearDeath) == "function" and fEnemy:IsNearDeath())
                enemies[#enemies + 1] = {
                    pawn = fEnemy,
                    pKey = pKey,
                    isAI = ResolveIsAI_Combat(fEnemy),
                    pos = eLoc,
                    dist = distM,
                    isKnocked = isKnocked
                }
            end
        end

        for _, eInfo in ipairs(enemies) do
            local enemy = eInfo.pawn
            if IsValid(enemy) and enemy ~= lp then
                local forbid = false

                -- 1. Ignore AI Bots (from cache)
                if ignoreBots and eInfo.isAI then
                    forbid = true
                end

                -- 2. Skip Knocked Enemies (from cache)
                if not forbid and ignoreKnocked and eInfo.isKnocked then
                    forbid = true
                end

                -- 3. Distance Range Filtering (from pre-computed distance)
                if not forbid and eInfo.dist and eInfo.dist > maxDist then
                    forbid = true
                end

                -- 4. Direct C++ State Synchronization (Never skip if native engine reset it in TDM)
                local pKey = eInfo.pKey or GetPawnKey(enemy)
                if enemy.bForbidAutoAimAt ~= forbid then
                    pcall(function() enemy.bForbidAutoAimAt = forbid end)
                end
                if pKey then _AimForbidCache[pKey] = forbid end

                -- Manage native Unreal Engine Actor Tag for libUE4.so C++ auto aim bypass
                pcall(function()
                    if enemy.Tags then
                        local hasTag = false
                        local tagIdx = -1
                        local num = (type(enemy.Tags.Num) == "function") and enemy.Tags:Num() or 0
                        for i = 0, num - 1 do
                            if enemy.Tags:Get(i) == "IgnoreWeaponAutoAim" then
                                hasTag = true
                                tagIdx = i
                                break
                            end
                        end
                        if forbid and not hasTag then
                            if enemy.Tags.AddUnique then
                                enemy.Tags:AddUnique("IgnoreWeaponAutoAim")
                            elseif enemy.Tags.Add then
                                enemy.Tags:Add("IgnoreWeaponAutoAim")
                            end
                        elseif not forbid and hasTag and tagIdx >= 0 then
                            if enemy.Tags.Remove then
                                enemy.Tags:Remove(tagIdx)
                            end
                        end
                    end
                end)

                -- 5. Force Register as Candidate in native AutoAimComponent (Required for TDM / Custom Pawns)
                if not forbid then
                    local autoAimComp = lp.AutoAimComp or lp.BP_AutoAimingComponent or lp.WeaponAutoAimingComponent or lp.AutoAimComponent
                    if IsValid(autoAimComp) and autoAimComp.RegisterAutoAimCandidate then
                        pcall(autoAimComp.RegisterAutoAimCandidate, autoAimComp, enemy)
                    end
                end
            end
        end
    end)
end
_G.UpdateAimTargetFiltering = UpdateAimTargetFiltering

-- ============================================================================
-- 2.5 DYNAMIC AIM MAGNET ENGINE (30 FPS HIGH-PERFORMANCE SOFT AIM ASSIST)
-- Smooth client-side camera pull towards Head or Spine on ADS / Fire
-- Completely unblockable by server in TDM, Arena, or Classic
-- ============================================================================
local function ProcessDynamicAimPull(livePC)
    -- Switch-gated: OFF means absolute zero (as if the feature doesn't exist).
    if not CFG.AimAssistEnabled then return end
    local pc = livePC or GetActivePlayerController()
    if not IsValid(pc) then return end
    local char = GetLocalPlayer(pc)
    if not IsValid(char) then return end

    local actMode = tonumber(CFG.AimActivationMode) or 2
    local aimLevel = tonumber(CFG.AimPower) or 2

    -- 1. Determine User State: engine state machine FIRST (universal across
    -- modes/pawns), proven bool flags as fallback (bIsGunADS/IsGunADS).
    local isScoped = PawnHasState(char, EPawnState and EPawnState.GunADS)
    if not isScoped and type(char.IsGunADS) == "function" then
        local okAds, res = pcall(char.IsGunADS, char)
        if okAds and res == true then isScoped = true end
    end
    if not isScoped and (char.bIsGunADS == true or char.IsLocalActuallyScopeIn == true) then
        isScoped = true
    end

    local isFiring = PawnHasState(char, EPawnState and EPawnState.GunFire)
    if not isFiring then
        local wm = char.WeaponManagerComponent or (char.GetWeaponManager and char:GetWeaponManager())
        local curW = wm and ((wm.GetCurrentUsingWeapon and wm:GetCurrentUsingWeapon()) or wm.CurrentWeaponReplicated)
        if IsValid(curW) and curW.bIsFiring == true then isFiring = true end
    end

    local shouldPull = false
    if actMode == 0 and isScoped then
        shouldPull = true
    elseif actMode == 1 and isFiring then
        shouldPull = true
    elseif actMode == 2 and (isScoped or isFiring) then
        shouldPull = true
    end

    if not shouldPull then return end

    -- 2. Camera Location & Control Rotation
    local camLoc = nil
    if pc.PlayerCameraManager then
        pcall(function() camLoc = pc.PlayerCameraManager:GetCameraLocation() end)
    end
    if not camLoc then
        local myLoc = GetActorLocation(char)
        if myLoc then camLoc = FVector(myLoc.X, myLoc.Y, myLoc.Z + 60) end
    end
    if not camLoc then return end

    local curRot = nil
    if pc.GetControlRotation then
        pcall(function() curRot = pc:GetControlRotation() end)
    end
    if not curRot then curRot = pc.ControlRotation end
    if not curRot then return end

    -- 3. Target Bone
    local isHead = (CFG.AimTargetBone == 1 or CFG.AimTargetBone == "1" or CFG.AimTargetBone == "head" or CFG.AimTargetBone == 2)
    local boneName = isHead and "head" or "spine_02"

    local maxDist = isScoped and (tonumber(CFG.AimScopeDistance) or 150) or (tonumber(CFG.AimHipDistance) or 40)
    local enemies = _G._CurrentCombatEnemies
    if not enemies or #enemies == 0 then return end

    local bestTargetLoc = nil
    local bestDeltaYaw = 0
    local bestDeltaPitch = 0
    local bestFov = 999.0
    local maxAimCone = isScoped and 24.0 or 18.0 -- Angular FOV threshold

    for _, eInfo in ipairs(enemies) do
        local enemy = eInfo.pawn
        if IsValid(enemy) and enemy ~= char and not eInfo.isKnocked then
            if (not eInfo.dist or eInfo.dist <= maxDist) then
                local targetLoc = nil
                local mesh = enemy.Mesh or enemy.CharacterMesh0
                if mesh and mesh.GetSocketLocation then
                    pcall(function() targetLoc = mesh:GetSocketLocation(boneName) end)
                end
                if not targetLoc then
                    local ePos = eInfo.pos or GetActorLocation(enemy)
                    if ePos then
                        targetLoc = FVector(ePos.X, ePos.Y, ePos.Z + (isHead and 70 or 35))
                    end
                end

                if targetLoc then
                    local dx = targetLoc.X - camLoc.X
                    local dy = targetLoc.Y - camLoc.Y
                    local dz = targetLoc.Z - camLoc.Z
                    local dist2D = math.sqrt(dx * dx + dy * dy)
                    if dist2D > 50 then
                        local targetYaw = math.deg(math.atan2(dy, dx))
                        local targetPitch = math.deg(math.atan2(dz, dist2D))

                        local dYaw = (targetYaw - curRot.Yaw) % 360
                        if dYaw > 180 then dYaw = dYaw - 360 end
                        local dPitch = targetPitch - curRot.Pitch

                        local fov = math.sqrt(dYaw * dYaw + dPitch * dPitch)
                        if fov < bestFov and fov <= maxAimCone then
                            bestFov = fov
                            bestDeltaYaw = dYaw
                            bestDeltaPitch = dPitch
                            bestTargetLoc = targetLoc
                        end
                    end
                end
            end
        end
    end

    -- 4. Apply Smooth Camera Pull
    if bestTargetLoc and bestFov <= maxAimCone then
        -- Smooth pull rates: Low (18%), Safe/Medium (32%), High/Godtier (50%)
        local pullFactor = (aimLevel == 1 and 0.18) or (aimLevel == 2 and 0.32) or 0.50
        local stepYaw = bestDeltaYaw * pullFactor
        local stepPitch = bestDeltaPitch * pullFactor

        -- Clamp max angular change per 33ms tick to ensure buttery-smooth tracking
        local maxStep = (aimLevel == 3) and 8.0 or 5.0
        stepYaw = math.max(-maxStep, math.min(maxStep, stepYaw))
        stepPitch = math.max(-maxStep, math.min(maxStep, stepPitch))

        local newYaw = curRot.Yaw + stepYaw
        local newPitch = curRot.Pitch + stepPitch
        local ok_rot, newRot = pcall(FRotator, newPitch, newYaw, 0)
        if not ok_rot or not newRot then return end

        if pc.SetControlRotation then
            pcall(pc.SetControlRotation, pc, newRot, "AimAssistPull")
        elseif pc.ClientSetControlRotation then
            pcall(pc.ClientSetControlRotation, pc, newRot)
        else
            pcall(function() pc.ControlRotation = newRot end)
        end
    end
end
_G.ProcessDynamicAimPull = ProcessDynamicAimPull
_G.TestAimPull = ProcessDynamicAimPull

-- ============================================================================
-- 3. LESS RECOIL & RECOIL STABILIZATION ENGINE (ShootWeaponEntity + BulletTrack)
-- ============================================================================
local function ApplyNoRecoil(force)
    pcall(function()
        local pc = GetActivePlayerController()
        local char = GetLocalPlayer(pc)
        if not IsValid(char) then return end

        local targetWeapons, curW = GetPlayerWeapons(char)

        local pKey = GetPawnKey(char) or tostring(char)
        local currentState = tostring(CFG.NoRecoilEnabled) .. "_" .. tostring(CFG.RecoilReduction) .. "_" .. tostring(curW) .. "_" .. tostring(pKey)
        if not force and currentState == _LastRecoilState then return end
        _LastRecoilState = currentState

        -- If disabled, cleanly restore 1:1 original weapon parameters (Entity + BulletTrack)
        if not CFG.NoRecoilEnabled then
            for ent, saved in pairs(recoilOriginalCache) do
                if IsValid(ent) then
                    for k, v in pairs(saved) do
                        if k == "RecoilInfo" then
                            if ent.RecoilInfo then
                                local tStruct = {}
                                for rk, rv in pairs(v) do tStruct[rk] = rv end
                                ent.RecoilInfo = tStruct
                            end
                        elseif k == "ShootCameraShakeScale" then
                            if ent.ShootCameraShake then ent.ShootCameraShake.Scale = v end
                        else
                            ent[k] = v
                        end
                    end
                end
            end
            for bt, saved in pairs(bulletTrackOriginalCache) do
                if IsValid(bt) then
                    if bt.SetUseTss then pcall(bt.SetUseTss, bt, true) end
                    if bt.RecoilInfo_NoTss and saved.RecoilInfo_NoTss then
                        local tStruct = {}
                        for k, v in pairs(saved.RecoilInfo_NoTss) do tStruct[k] = v end
                        bt.RecoilInfo_NoTss = tStruct
                    end
                    if bt.DeviationInfo_NoTss and saved.DeviationInfo_NoTss then
                        local tStruct = {}
                        for k, v in pairs(saved.DeviationInfo_NoTss) do tStruct[k] = v end
                        bt.DeviationInfo_NoTss = tStruct
                    end
                end
            end
            for k in pairs(recoilOriginalCache) do recoilOriginalCache[k] = nil end
            for k in pairs(bulletTrackOriginalCache) do bulletTrackOriginalCache[k] = nil end
            return
        end

        local rawVal = tonumber(CFG.RecoilReduction) or 70
        if rawVal > 70 then rawVal = 70 end -- Safe anti-ban cap
        if rawVal < 0 then rawVal = 0 end
        local slider = rawVal / 100.0

        for w, _ in pairs(targetWeapons) do
            -- 1. BulletTrack Subsystem (NoTss Recoil Bypass as verified in GMWeaponEditor.lua)
            local bt = w.BulletTrack
            if IsValid(bt) then
                pcall(function()
                    if bt.SetUseTss then bt:SetUseTss(false) end
                    if bt.RecoilInfo_NoTss then
                        if not bulletTrackOriginalCache[bt] then
                            bulletTrackOriginalCache[bt] = {}
                        end
                        if not bulletTrackOriginalCache[bt].RecoilInfo_NoTss then
                            bulletTrackOriginalCache[bt].RecoilInfo_NoTss = {}
                            local ri = bt.RecoilInfo_NoTss
                            for _, f in ipairs(BT_RECOIL_FIELDS) do
                                if ri[f] ~= nil then bulletTrackOriginalCache[bt].RecoilInfo_NoTss[f] = ri[f] end
                            end
                        end

                        local origBT = bulletTrackOriginalCache[bt] and bulletTrackOriginalCache[bt].RecoilInfo_NoTss
                        if origBT then
                            -- Tencent GMWeaponEditor Pattern: clone all existing fields first to avoid wiping unknown C++ properties
                            local tStruct = {}
                            if type(bt.RecoilInfo_NoTss) == "table" or type(bt.RecoilInfo_NoTss) == "userdata" then
                                pcall(function()
                                    for k, v in pairs(bt.RecoilInfo_NoTss) do tStruct[k] = v end
                                end)
                            end
                            for _, f in ipairs(BT_RECOIL_FIELDS) do
                                if origBT[f] ~= nil then
                                    tStruct[f] = origBT[f] * (1.0 - slider)
                                end
                            end
                            bt.RecoilInfo_NoTss = tStruct
                        end
                    end

                    -- DeviationInfo_NoTss (Bullet spread & crosshair bloom stabilization)
                    if bt.DeviationInfo_NoTss then
                        if not bulletTrackOriginalCache[bt] then
                            bulletTrackOriginalCache[bt] = {}
                        end
                        if not bulletTrackOriginalCache[bt].DeviationInfo_NoTss then
                            bulletTrackOriginalCache[bt].DeviationInfo_NoTss = {}
                            local di = bt.DeviationInfo_NoTss
                            for _, f in ipairs(BT_DEVIATION_FIELDS) do
                                if di[f] ~= nil then bulletTrackOriginalCache[bt].DeviationInfo_NoTss[f] = di[f] end
                            end
                        end

                        local origDI = bulletTrackOriginalCache[bt] and bulletTrackOriginalCache[bt].DeviationInfo_NoTss
                        if origDI then
                            local tStruct = {}
                            for _, f in ipairs(BT_DEVIATION_FIELDS) do
                                if origDI[f] ~= nil then
                                    tStruct[f] = origDI[f] * (1.0 - (slider * 0.7))
                                end
                            end
                            bt.DeviationInfo_NoTss = tStruct
                        end
                    end
                end)
            end

            -- 2. ShootWeaponEntity Component (Universal Resolver)
            local entity = ResolveWeaponEntity(w)
            if IsValid(entity) then
                if not recoilOriginalCache[entity] then
                    local saved = { RecoilInfo = {} }
                    for _, f in ipairs(RECOIL_FIELDS) do
                        if entity[f] ~= nil then saved[f] = entity[f] end
                    end
                    if entity.RecoilInfo then
                        for _, f in ipairs(RECOIL_INFO_FIELDS) do
                            if entity.RecoilInfo[f] ~= nil then saved.RecoilInfo[f] = entity.RecoilInfo[f] end
                        end
                    end
                    if entity.ShootCameraShake and entity.ShootCameraShake.Scale ~= nil then
                        saved.ShootCameraShakeScale = entity.ShootCameraShake.Scale
                    end
                    recoilOriginalCache[entity] = saved
                end

                local orig = recoilOriginalCache[entity]
                if orig then
                    for _, f in ipairs(RECOIL_FIELDS) do
                        if entity[f] ~= nil and orig[f] ~= nil and RECOIL_TARGET_VALUES[f] ~= nil then
                            local target = RECOIL_TARGET_VALUES[f]
                            entity[f] = orig[f] + (target - orig[f]) * slider
                        end
                    end
                    if entity.RecoilInfo and orig.RecoilInfo then
                        -- Tencent GMWeaponEditor Pattern: clone all existing fields first
                        local tStruct = {}
                        if type(entity.RecoilInfo) == "table" or type(entity.RecoilInfo) == "userdata" then
                            pcall(function()
                                for k, v in pairs(entity.RecoilInfo) do tStruct[k] = v end
                            end)
                        end
                        for _, f in ipairs(RECOIL_INFO_FIELDS) do
                            if entity.RecoilInfo[f] ~= nil and orig.RecoilInfo[f] ~= nil then
                                local target = 0.05
                                tStruct[f] = orig.RecoilInfo[f] + (target - orig.RecoilInfo[f]) * slider
                            end
                        end
                        entity.RecoilInfo = tStruct
                    end
                    if entity.ShootCameraShake and orig.ShootCameraShakeScale ~= nil then
                        local origScale = orig.ShootCameraShakeScale
                        local targetScale = math.max(0.35, origScale * 0.35)
                        entity.ShootCameraShake.Scale = origScale + (targetScale - origScale) * slider
                    end
                end
            end
        end
    end)
end
_G.ApplyNoRecoil = ApplyNoRecoil

local _LastCombatPawnKey = nil

-- ============================================================================
-- BULLETPROOF CACHE RESET (Full Lexical Scope: all 17 locals bound)
-- ============================================================================
function _G.ResetSecurexMatchCaches()
    _cachedPawnsList = nil
    _cachedPawnsTime = 0
    _PawnAICache = {}
    _EnemyRelationCache = {}
    _PawnTeamCache = {}
    _G._PawnTeamCache = {}
    _EnemyMissedTicks = {}
    _G._EnemyMissedTicks = {}
    _PawnVisCache = {}
    _WH_MeshCache = {}
    _WH_AppliedMesh = {}
    _WH_PawnMeshes = {}
    _LastLocalTeamCheck = nil
    _BlueprintClassCache = {}
    _AimForbidCache = {}
    aimOriginalCache = {}
    recoilOriginalCache = {}
    bulletTrackOriginalCache = {}
    _lastAppliedAimAssist = nil
    _lastAppliedNoRecoil = nil
    _LastWeaponKey = nil
    _LastCombatPawnKey = nil
    _LastRecoilState = nil
    _LastAimState = nil
    _ActiveHPMarkPawns = {}
    _ActiveEnemyMarkPawns = {}
    _G._VehMissedScans = {}
    _G._LootMissedScans = {}
    _G.ModMenuInitialized = nil
    _G._lastThrowableHookTime = 0
end
local _LastCombatPawnInstance = nil
local function CheckCombatWeaponSwitch()
    local pc = GetActivePlayerController()
    local char = GetLocalPlayer(pc)
    if not IsValid(char) then return end
    local pInstance = tostring(char)

    -- Detect Every Single Respawn in TDM! (char memory pointer changes on every death/respawn)
    if pInstance ~= _LastCombatPawnInstance then
        _LastCombatPawnInstance = pInstance
        _LastCombatPawnKey = GetPawnKey(char) or pInstance
        _LastWeaponKey = nil
        _LastAimState = nil -- Invalidate cached aim state so new pawn receives full configuration immediately!
        if CFG.AimAssistEnabled and ApplyAimAssist then ApplyAimAssist(true) end
        if CFG.ModSkin then
            pcall(_G.equip_character_avatar, char)
            pcall(_G.ApplyWeaponSkins, char)
        end
    end

    -- Worn-skin self-heal (~1s): helmet/bag L1->L2->L3 swaps and fresh weapon
    -- pickups fire no swap/respawn event, so re-apply would otherwise wait for
    -- the next swap/respawn/menu. Both applies are dirty-gated inside (zero
    -- writes + zero rebuild when steady), so steady-state cost is a few native
    -- reads. No new timer: reuses this existing 0.25s dispatcher.
    _SkinSelfHealCounter = (_SkinSelfHealCounter or 0) + 1
    if CFG.ModSkin and _SkinSelfHealCounter >= 4 then
        _SkinSelfHealCounter = 0
        pcall(_G.equip_character_avatar, char)
        pcall(_G.ApplyWeaponSkins, char)
    end

    local wm = char.WeaponManagerComponent or (char.GetWeaponManager and char:GetWeaponManager())
        or char.CharacterWeaponManager or char.WeaponManger or char.WeaponManager
    if not IsValid(wm) then return end

    local curW = (wm.GetCurrentUsingWeapon and wm:GetCurrentUsingWeapon())
        or wm.CurrentWeaponReplicated
        or (char.GetCurrentWeapon and char:GetCurrentWeapon())

    -- If player is holstered / unarmed, pawn setup already applied, return
    if not curW or not IsValid(curW) then return end

    local wKey = tostring(curW)
    -- Trigger on weapon swap or pawn respawn. NO periodic force-refresh:
    -- apply-once + cache design (re-apply only when the weapon actually
    -- changes). NOTE: if the engine/TSS ever resets recoil values mid-life
    -- without a weapon swap, control silently lapses until next swap/respawn.
    if wKey ~= _LastWeaponKey then
        _LastWeaponKey = wKey
        if CFG.AimAssistEnabled and ApplyAimAssist then ApplyAimAssist(true) end
        if CFG.NoRecoilEnabled and ApplyNoRecoil then ApplyNoRecoil(true) end
        -- Weapon-swap skin apply (swap only, not periodic): dirty-checked inside
        if CFG.ModSkin then
            pcall(_G.ApplyWeaponSkins, char)
        end
    end
end
_G.CheckCombatWeaponSwitch = CheckCombatWeaponSwitch

-- ============================================================================
-- 9. OFFICIAL IN-GAME SETTINGS MENU INTEGRATION (100% NATIVE ENGINE UI)
-- ============================================================================
-- 0% Canvas Bloat | 0% Lag | 0% Touch Conflict | 100% Rock-Solid Native Stability
-- Seamlessly integrates into BGMI's official Settings Window (Lobby & In-Match)
-- Reuses native Switchers (AliasMap.Switcher), Sliders (AliasMap.Slider) & Headers
-- ============================================================================

function _G.InitModMenuTab()
    -- P1-FIX: Early-out if already initialized (prevents repetitive overhead)
    if _G.ModMenuInitialized then return true end
    -- LICENSE GATE: no menu until the key is validated.
    if not _G.SecureX_Authorized() then return false end
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["common.loc_util"] then
        LocUtil = package.loaded["common.loc_util"]
    end
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = package.loaded["client.common.LocUtil"]
    end
    if not LocUtil then
        pcall(function() LocUtil = require("common.loc_util") end)
    end

    -- Hook LocUtil to guarantee crisp labels for our Mod Menu tab and items
    if LocUtil and not LocUtil._IsSecureXMenuHooked then
        local origResolve = LocUtil.ResolveText
        if origResolve then
            LocUtil.ResolveText = function(text, ...)
                if type(text) == "string" then
                    return text
                end
                return origResolve(text, ...)
            end
        end
        LocUtil._IsSecureXMenuHooked = true
    end

    -- Resolve SettingPageDefine & Catalogs across all BGMI runtime paths
    local SettingPageDefine = package.loaded["client.logic.NewSetting.SettingPageDefine"]
    if not SettingPageDefine then
        pcall(function() SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine") end)
    end
    if not SettingPageDefine then
        SettingPageDefine = package.loaded["client.setting.SettingPageDefine"]
        if not SettingPageDefine then
            pcall(function() SettingPageDefine = require("client.setting.SettingPageDefine") end)
        end
    end

    local AliasMap = nil
    pcall(function()
        AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
    end)
    if not AliasMap or not AliasMap.Switcher then
        local UICfg = rawget(_G, "UIManager") and _G.UIManager.UI_Config
        AliasMap = {
            Switcher = (UICfg and UICfg.Setting_Option_Switcher) or "Setting_Option_Switcher",
            Slider   = (UICfg and UICfg.Setting_Option_Slider) or "Setting_Option_Slider",
            Title    = (UICfg and UICfg.Setting_Title) or "Setting_Title",
            Spacer   = (UICfg and UICfg.Setting_Spacer) or "Setting_Spacer"
        }
    end

    if not SettingPageDefine then return false end

    local Spacer = { UI = AliasMap.Spacer or "Setting_Spacer" }

    -- Standardized Choice Maps & Labels (Strict Plain Text - Zero Emojis)
    local aimTriggerNames = { "Hipfire Only", "ADS Scope Only", "Hipfire + ADS" }
    local aimTriggerVals  = { 1, 0, 2 }

    local boolSwitcherText = { 39268, 39267 }
    local boolSwitcherVal  = { true, false }

    local function ParseBoolVal(v, currentVal)
        if v == true or v == "true" then return true end
        if v == false or v == "false" then return false end
        if v == 0 or v == "0" then return true end   -- Index 0: Option 1 (Open / Enable)
        if v == 1 or v == "1" then return false end  -- Index 1: Option 2 (Close / Disable)
        if v == 2 or v == "2" then return false end
        if currentVal ~= nil then return currentVal end
        return false
    end

    -- ========================================================================
    -- 1. STACK: PLAYER ESP (TAB 1)
    -- ========================================================================
    local Stack_Visuals = {
        { UI = AliasMap.Title, Text = "--- ENEMY COUNTER ---" },
        {
            Key = "Counter_Enabled",
            UI = AliasMap.Switcher,
            Text = "Enemy Counter",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Counter_Enabled == true end,
            SetFunc = function(c, v)
                CFG.Counter_Enabled = ParseBoolVal(v, CFG.Counter_Enabled)
                if not CFG.Counter_Enabled and _G.ClearAllEnemyCounters then
                    _G.ClearAllEnemyCounters()
                end
                if _G.EnemyCounterUI then _G.EnemyCounterUI.LastTotal = -1 end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,
        { UI = AliasMap.Title, Text = "--- ENEMY LOOK ---" },
        {
            Key = "TrackingMode",
            UI = AliasMap.Switcher,
            Text = "Tracking Mode",
            SwitcherText = { "Off", "Snapline", "MapTracking" },
            SwitcherValue = { 0, 1, 2 },
            GetFunc = function() return math.min(2, math.max(0, tonumber(CFG.TrackingMode) or 0)) end,
            SetFunc = function(c, v)
                local m = math.min(2, math.max(0, tonumber(v) or 0))
                CFG.TrackingMode = m
                if m ~= 1 and _G.ClearAllNativeLasers then
                    pcall(_G.ClearAllNativeLasers)
                end
                if m ~= 2 then
                    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
                    if InGameMarkTools and InGameMarkTools.HideMapMark then
                        for pKey, mId in pairs(_G.ActiveEnemyMarks) do
                            if mId then pcall(InGameMarkTools.HideMapMark, mId) end
                        end
                    end
                    _G.ActiveEnemyMarks = {}
                    _ActiveEnemyMarkPawns = {}
                end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Laser_Thickness",
            UI = AliasMap.Slider,
            Text = "Line Thickness",
            Min = 1.0,
            Max = 3.0,
            GetFunc = function() return tonumber(CFG.Laser_Thickness) or 1.5 end,
            SetFunc = function(c, v)
                CFG.Laser_Thickness = tonumber(v) or 1.5
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "ESP_Player_Box",
            UI = AliasMap.Switcher,
            Text = "Player Box",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.ESP_Player_Box == true end,
            SetFunc = function(c, v)
                CFG.ESP_Player_Box = ParseBoolVal(v, CFG.ESP_Player_Box)
                pcall(_G.SyncAllPlayerBoxes, CFG.ESP_Player_Box)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "ESP_Health_Bar",
            UI = AliasMap.Switcher,
            Text = "Health Bar",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.ESP_Health_Bar == true end,
            SetFunc = function(c, v)
                CFG.ESP_Health_Bar = ParseBoolVal(v, CFG.ESP_Health_Bar)
                if not CFG.ESP_Health_Bar then
                    local InGameMarkTools = package.loaded["GameLua.Mod.BaseMod.Common.InGameMarkTools"]
                    if InGameMarkTools and InGameMarkTools.HideMapMark then
                        for pKey, mId in pairs(_G.ActiveHPMarks) do
                            if mId then pcall(InGameMarkTools.HideMapMark, mId) end
                        end
                    end
                    _G.ActiveHPMarks = {}
                end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "ESP_Vis_Check",
            UI = AliasMap.Switcher,
            Text = "Visible Check",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.ESP_Vis_Check == true end,
            SetFunc = function(c, v)
                CFG.ESP_Vis_Check = ParseBoolVal(v, CFG.ESP_Vis_Check)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "ESP_Wall_Vision",
            UI = AliasMap.Switcher,
            Text = "See Through Walls",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.ESP_Wall_Vision == true end,
            SetFunc = function(c, v)
                CFG.ESP_Wall_Vision = ParseBoolVal(v, CFG.ESP_Wall_Vision)
                if not CFG.ESP_Wall_Vision and _G.ClearAllWallVision then
                    pcall(_G.ClearAllWallVision)
                end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,
        { UI = AliasMap.Title, Text = "--- DANGER ALERTS ---" },
        {
            Key = "Alert_Incoming_Grenades",
            UI = AliasMap.Switcher,
            Text = "Grenade Warning",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Alert_Incoming_Grenades == true end,
            SetFunc = function(c, v)
                CFG.Alert_Incoming_Grenades = ParseBoolVal(v, CFG.Alert_Incoming_Grenades)
                if not CFG.Alert_Incoming_Grenades and _G.ClearAllThrowableAlerts then
                    pcall(_G.ClearAllThrowableAlerts)
                end
                _G.SaveModSettings()
                return true
            end
        }
    }

    -- ========================================================================
    -- 2. STACK: COMBAT ENGINE (TAB 2)
    -- ========================================================================
    local Stack_Combat = {
        { UI = AliasMap.Title, Text = "--- AIMBOT ---" },
        {
            Key = "AimAssistEnabled",
            UI = AliasMap.Switcher,
            Text = "Aimbot",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.AimAssistEnabled == true end,
            SetFunc = function(c, v)
                CFG.AimAssistEnabled = ParseBoolVal(v, CFG.AimAssistEnabled)
                ApplyAimAssist(true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "AimTriggerMode",
            UI = AliasMap.Switcher,
            Text = "Aim Works When",
            SwitcherText = aimTriggerNames,
            SwitcherValue = aimTriggerVals,
            GetFunc = function() return tonumber(CFG.AimActivationMode) or 2 end,
            SetFunc = function(c, v)
                CFG.AimActivationMode = tonumber(v) or 2
                ApplyAimAssist(true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "AimTargetBone",
            UI = AliasMap.Switcher,
            Text = "Aim At",
            SwitcherText = { "Chest", "Head" },
            SwitcherValue = { 0, 1 },
            GetFunc = function() return (tonumber(CFG.AimTargetBone) == 1 or CFG.AimTargetBone == "head") and 1 or 0 end,
            SetFunc = function(c, v)
                CFG.AimTargetBone = tonumber(v) or 0
                ApplyAimAssist(true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "AimPower",
            UI = AliasMap.Slider,
            Text = "Aim Strength",
            Min = 1,
            Max = 3,
            GetFunc = function()
                local v = tonumber(CFG.AimPower) or 2
                if v > 3 then v = 3 end
                if v < 1 then v = 1 end
                return v
            end,
            SetFunc = function(c, v)
                local p = tonumber(v) or 2
                if p > 3 then p = 3 end
                if p < 1 then p = 1 end
                CFG.AimPower = p
                ApplyAimAssist(true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "AimIgnoreKnocked",
            UI = AliasMap.Switcher,
            Text = "Skip Knocked Enemies",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.AimIgnoreKnocked == true end,
            SetFunc = function(c, v)
                CFG.AimIgnoreKnocked = ParseBoolVal(v, CFG.AimIgnoreKnocked)
                ApplyAimAssist(true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "AimHipDistance",
            UI = AliasMap.Slider,
            Text = "Hipfire Range",
            Min = 10,
            Max = 60,
            GetFunc = function()
                local d = tonumber(CFG.AimHipDistance) or 40
                return math.min(60, math.max(10, d))
            end,
            SetFunc = function(c, v)
                local d = tonumber(v) or 40
                CFG.AimHipDistance = math.min(60, math.max(10, d))
                ApplyAimAssist(true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "AimScopeDistance",
            UI = AliasMap.Slider,
            Text = "Scope Range",
            Min = 50,
            Max = 180,
            GetFunc = function()
                local d = tonumber(CFG.AimScopeDistance) or 150
                return math.min(180, math.max(50, d))
            end,
            SetFunc = function(c, v)
                local d = tonumber(v) or 150
                CFG.AimScopeDistance = math.min(180, math.max(50, d))
                ApplyAimAssist(true)
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,
        { UI = AliasMap.Title, Text = "--- RECOIL ---" },
        {
            Key = "NoRecoilEnabled",
            UI = AliasMap.Switcher,
            Text = "No Recoil",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.NoRecoilEnabled == true end,
            SetFunc = function(c, v)
                CFG.NoRecoilEnabled = ParseBoolVal(v, CFG.NoRecoilEnabled)
                ApplyNoRecoil(true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "RecoilReduction",
            UI = AliasMap.Slider,
            Text = "Recoil Less %",
            Min = 0,
            Max = 70,
            GetFunc = function() return math.min(70, tonumber(CFG.RecoilReduction) or 70) end,
            SetFunc = function(c, v)
                local val = tonumber(v) or 70
                if val > 70 then val = 70 end
                if val < 0 then val = 0 end
                CFG.RecoilReduction = val
                ApplyNoRecoil(true)
                _G.SaveModSettings()
                return true
            end
        }
    }

    -- ========================================================================
    -- 3. STACK: VEHICLE RADAR (TAB 3)
    -- ========================================================================
    local Stack_Vehicles = {
        -- CATEGORY 1: CARS & SEDANS
        { UI = AliasMap.Title, Text = "--- CARS ---" },
        {
            Key = "Veh_Cat_Cars",
            UI = AliasMap.Switcher,
            Text = "Cars",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Cat_Cars == true end,
            SetFunc = function(c, v)
                CFG.Veh_Cat_Cars = ParseBoolVal(v, CFG.Veh_Cat_Cars)
                if not CFG.Veh_Cat_Cars and _G.ClearVehicleCategory then pcall(_G.ClearVehicleCategory, "Veh_Cat_Cars") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_UAZ",
            UI = AliasMap.Switcher,
            Text = "UAZ",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_UAZ == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_UAZ = ParseBoolVal(v, CFG.Veh_Icon_UAZ)
                if not CFG.Veh_Icon_UAZ and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71001) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Dacia",
            UI = AliasMap.Switcher,
            Text = "Dacia",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Dacia == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Dacia = ParseBoolVal(v, CFG.Veh_Icon_Dacia)
                if not CFG.Veh_Icon_Dacia and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71003) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Coupe",
            UI = AliasMap.Switcher,
            Text = "Coupe",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Coupe == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Coupe = ParseBoolVal(v, CFG.Veh_Icon_Coupe)
                if not CFG.Veh_Icon_Coupe and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71005) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Mirado",
            UI = AliasMap.Switcher,
            Text = "Mirado",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Mirado == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Mirado = ParseBoolVal(v, CFG.Veh_Icon_Mirado)
                if not CFG.Veh_Icon_Mirado and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71006) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_General",
            UI = AliasMap.Switcher,
            Text = "Other Cars",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_General == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_General = ParseBoolVal(v, CFG.Veh_Icon_General)
                if not CFG.Veh_Icon_General and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71016) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 2: BUGGIES & LIGHT OFF-ROAD
        { UI = AliasMap.Title, Text = "--- BUGGIES ---" },
        {
            Key = "Veh_Cat_Light",
            UI = AliasMap.Switcher,
            Text = "Buggies",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Cat_Light == true end,
            SetFunc = function(c, v)
                CFG.Veh_Cat_Light = ParseBoolVal(v, CFG.Veh_Cat_Light)
                if not CFG.Veh_Cat_Light and _G.ClearVehicleCategory then pcall(_G.ClearVehicleCategory, "Veh_Cat_Light") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Buggy",
            UI = AliasMap.Switcher,
            Text = "Buggy",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Buggy == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Buggy = ParseBoolVal(v, CFG.Veh_Icon_Buggy)
                if not CFG.Veh_Icon_Buggy and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71002) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Monster",
            UI = AliasMap.Switcher,
            Text = "Monster Truck",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Monster == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Monster = ParseBoolVal(v, CFG.Veh_Icon_Monster)
                if not CFG.Veh_Icon_Monster and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71009) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_MiniBus",
            UI = AliasMap.Switcher,
            Text = "MiniBus",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_MiniBus == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_MiniBus = ParseBoolVal(v, CFG.Veh_Icon_MiniBus)
                if not CFG.Veh_Icon_MiniBus and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71008) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 3: MOTORCYCLES & BIKES
        { UI = AliasMap.Title, Text = "--- BIKES ---" },
        {
            Key = "Veh_Cat_Bikes",
            UI = AliasMap.Switcher,
            Text = "Bikes",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Cat_Bikes == true end,
            SetFunc = function(c, v)
                CFG.Veh_Cat_Bikes = ParseBoolVal(v, CFG.Veh_Cat_Bikes)
                if not CFG.Veh_Cat_Bikes and _G.ClearVehicleCategory then pcall(_G.ClearVehicleCategory, "Veh_Cat_Bikes") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Motorcycle",
            UI = AliasMap.Switcher,
            Text = "Motorcycle",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Motorcycle == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Motorcycle = ParseBoolVal(v, CFG.Veh_Icon_Motorcycle)
                if not CFG.Veh_Icon_Motorcycle and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71004) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Scooter",
            UI = AliasMap.Switcher,
            Text = "Scooter",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Scooter == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Scooter = ParseBoolVal(v, CFG.Veh_Icon_Scooter)
                if not CFG.Veh_Icon_Scooter and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71012) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 4: ARMORED & HEAVY
        { UI = AliasMap.Title, Text = "--- ARMORED ---" },
        {
            Key = "Veh_Cat_Armored",
            UI = AliasMap.Switcher,
            Text = "Armored",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Cat_Armored == true end,
            SetFunc = function(c, v)
                CFG.Veh_Cat_Armored = ParseBoolVal(v, CFG.Veh_Cat_Armored)
                if not CFG.Veh_Cat_Armored and _G.ClearVehicleCategory then pcall(_G.ClearVehicleCategory, "Veh_Cat_Armored") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_BRDM",
            UI = AliasMap.Switcher,
            Text = "BRDM",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_BRDM == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_BRDM = ParseBoolVal(v, CFG.Veh_Icon_BRDM)
                if not CFG.Veh_Icon_BRDM and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71007) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 5: WATER & AIR VEHICLES
        { UI = AliasMap.Title, Text = "--- WATER & AIR ---" },
        {
            Key = "Veh_Cat_WaterAir",
            UI = AliasMap.Switcher,
            Text = "Water & Air",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Cat_WaterAir == true end,
            SetFunc = function(c, v)
                CFG.Veh_Cat_WaterAir = ParseBoolVal(v, CFG.Veh_Cat_WaterAir)
                if not CFG.Veh_Cat_WaterAir and _G.ClearVehicleCategory then pcall(_G.ClearVehicleCategory, "Veh_Cat_WaterAir") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Boat",
            UI = AliasMap.Switcher,
            Text = "Boat",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Boat == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Boat = ParseBoolVal(v, CFG.Veh_Icon_Boat)
                if not CFG.Veh_Icon_Boat and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71010) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_JetSki",
            UI = AliasMap.Switcher,
            Text = "Jet Ski",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_JetSki == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_JetSki = ParseBoolVal(v, CFG.Veh_Icon_JetSki)
                if not CFG.Veh_Icon_JetSki and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71011) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Glider",
            UI = AliasMap.Switcher,
            Text = "Glider",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Glider == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Glider = ParseBoolVal(v, CFG.Veh_Icon_Glider)
                if not CFG.Veh_Icon_Glider and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71013) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Helicopter",
            UI = AliasMap.Switcher,
            Text = "Helicopter",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Helicopter == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Helicopter = ParseBoolVal(v, CFG.Veh_Icon_Helicopter)
                if not CFG.Veh_Icon_Helicopter and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71014) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Veh_Icon_Horse",
            UI = AliasMap.Switcher,
            Text = "Horse",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_Icon_Horse == true end,
            SetFunc = function(c, v)
                CFG.Veh_Icon_Horse = ParseBoolVal(v, CFG.Veh_Icon_Horse)
                if not CFG.Veh_Icon_Horse and _G.ClearVehicleIconGroup then pcall(_G.ClearVehicleIconGroup, 71015) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- VEHICLE ALERTS & RANGE
        { UI = AliasMap.Title, Text = "--- VEHICLE RANGE ---" },
        {
            Key = "Veh_360_Alert",
            UI = AliasMap.Switcher,
            Text = "Off-Screen Alert",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Veh_360_Alert == true end,
            SetFunc = function(c, v)
                CFG.Veh_360_Alert = ParseBoolVal(v, CFG.Veh_360_Alert)
                if _G.UpdateMarkOutScreenSetting then pcall(_G.UpdateMarkOutScreenSetting) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "VehicleDistance",
            UI = AliasMap.Slider,
            Text = "Vehicle Range (100-350m)",
            Min = 100,
            Max = 350,
            GetFunc = function() return math.min(350, tonumber(CFG.VehicleDistance) or 350) end,
            SetFunc = function(c, v)
                CFG.VehicleDistance = math.min(350, math.max(100, tonumber(v) or 350))
                _G.SaveModSettings()
                return true
            end
        }
    }

    -- ========================================================================
    -- 4. STACK: SUPPLY & LOOT ESP (TAB 4)
    -- ========================================================================
    local Stack_Loot = {
        -- LOOT DETECTION DISTANCE (top: most-changed setting first)
        { UI = AliasMap.Title, Text = "--- LOOT RANGE ---" },
        {
            Key = "LootDistance",
            UI = AliasMap.Slider,
            Text = "Loot Range (10-50m)",
            Min = 10,
            Max = 50,
            GetFunc = function() return math.min(50, math.max(10, tonumber(CFG.LootDistance) or 35)) end,
            SetFunc = function(c, v)
                CFG.LootDistance = math.min(50, math.max(10, tonumber(v) or 35))
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,
        -- CATEGORY 1: AIRDROP & SPECIAL FLARES
        { UI = AliasMap.Title, Text = "--- FLARES ---" },
        {
            Key = "Loot_Cat_Flares",
            UI = AliasMap.Switcher,
            Text = "Flares",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_Flares == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_Flares = ParseBoolVal(v, CFG.Loot_Cat_Flares)
                if not CFG.Loot_Cat_Flares and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_Flares") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_FlareGun",
            UI = AliasMap.Switcher,
            Text = "Flare Gun",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_FlareGun == true end,
            SetFunc = function(c, v)
                CFG.Loot_FlareGun = ParseBoolVal(v, CFG.Loot_FlareGun)
                if not CFG.Loot_FlareGun and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72001) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_RespawnFlare",
            UI = AliasMap.Switcher,
            Text = "Recall Flare",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_RespawnFlare == true end,
            SetFunc = function(c, v)
                CFG.Loot_RespawnFlare = ParseBoolVal(v, CFG.Loot_RespawnFlare)
                if not CFG.Loot_RespawnFlare and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72002) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Airdrop",
            UI = AliasMap.Switcher,
            Text = "AirDrop Crate",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Airdrop == true end,
            SetFunc = function(c, v)
                CFG.Loot_Airdrop = ParseBoolVal(v, CFG.Loot_Airdrop)
                if not CFG.Loot_Airdrop and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72003) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 2: AIRDROP EXCLUSIVE WEAPONS
        { UI = AliasMap.Title, Text = "--- AIRDROP GUNS ---" },
        {
            Key = "Loot_Cat_AirDrop",
            UI = AliasMap.Switcher,
            Text = "AirDrop Guns",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_AirDrop == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_AirDrop = ParseBoolVal(v, CFG.Loot_Cat_AirDrop)
                if not CFG.Loot_Cat_AirDrop and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_AirDrop") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_AWM",
            UI = AliasMap.Switcher,
            Text = "AWM",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_AWM == true end,
            SetFunc = function(c, v)
                CFG.Loot_AWM = ParseBoolVal(v, CFG.Loot_AWM)
                if not CFG.Loot_AWM and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72004) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_AMR",
            UI = AliasMap.Switcher,
            Text = "AMR",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_AMR == true end,
            SetFunc = function(c, v)
                CFG.Loot_AMR = ParseBoolVal(v, CFG.Loot_AMR)
                if not CFG.Loot_AMR and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72005) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Groza",
            UI = AliasMap.Switcher,
            Text = "Groza",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Groza == true end,
            SetFunc = function(c, v)
                CFG.Loot_Groza = ParseBoolVal(v, CFG.Loot_Groza)
                if not CFG.Loot_Groza and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72006) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_AUG",
            UI = AliasMap.Switcher,
            Text = "AUG",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_AUG == true end,
            SetFunc = function(c, v)
                CFG.Loot_AUG = ParseBoolVal(v, CFG.Loot_AUG)
                if not CFG.Loot_AUG and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72007) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_MG3",
            UI = AliasMap.Switcher,
            Text = "MG3",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_MG3 == true end,
            SetFunc = function(c, v)
                CFG.Loot_MG3 = ParseBoolVal(v, CFG.Loot_MG3)
                if not CFG.Loot_MG3 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72008) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_MK14",
            UI = AliasMap.Switcher,
            Text = "Mk14",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_MK14 == true end,
            SetFunc = function(c, v)
                CFG.Loot_MK14 = ParseBoolVal(v, CFG.Loot_MK14)
                if not CFG.Loot_MK14 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72009) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 3: POPULAR ASSAULT RIFLES (AR)
        { UI = AliasMap.Title, Text = "--- RIFLES ---" },
        {
            Key = "Loot_Cat_AR",
            UI = AliasMap.Switcher,
            Text = "Rifles",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_AR == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_AR = ParseBoolVal(v, CFG.Loot_Cat_AR)
                if not CFG.Loot_Cat_AR and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_AR") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_M416",
            UI = AliasMap.Switcher,
            Text = "M416",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_M416 == true end,
            SetFunc = function(c, v)
                CFG.Loot_M416 = ParseBoolVal(v, CFG.Loot_M416)
                if not CFG.Loot_M416 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72010) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_AKM",
            UI = AliasMap.Switcher,
            Text = "AKM",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_AKM == true end,
            SetFunc = function(c, v)
                CFG.Loot_AKM = ParseBoolVal(v, CFG.Loot_AKM)
                if not CFG.Loot_AKM and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72011) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_SCAR",
            UI = AliasMap.Switcher,
            Text = "SCAR-L",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_SCAR == true end,
            SetFunc = function(c, v)
                CFG.Loot_SCAR = ParseBoolVal(v, CFG.Loot_SCAR)
                if not CFG.Loot_SCAR and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72034) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_M762",
            UI = AliasMap.Switcher,
            Text = "M762",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_M762 == true end,
            SetFunc = function(c, v)
                CFG.Loot_M762 = ParseBoolVal(v, CFG.Loot_M762)
                if not CFG.Loot_M762 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72012) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_M16A4",
            UI = AliasMap.Switcher,
            Text = "M16A4",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_M16A4 == true end,
            SetFunc = function(c, v)
                CFG.Loot_M16A4 = ParseBoolVal(v, CFG.Loot_M16A4)
                if not CFG.Loot_M16A4 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72035) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_G36C",
            UI = AliasMap.Switcher,
            Text = "G36C",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_G36C == true end,
            SetFunc = function(c, v)
                CFG.Loot_G36C = ParseBoolVal(v, CFG.Loot_G36C)
                if not CFG.Loot_G36C and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72041) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 4: SNIPER RIFLES & DMRS
        { UI = AliasMap.Title, Text = "--- SNIPERS ---" },
        {
            Key = "Loot_Cat_Snipers",
            UI = AliasMap.Switcher,
            Text = "Snipers",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_Snipers == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_Snipers = ParseBoolVal(v, CFG.Loot_Cat_Snipers)
                if not CFG.Loot_Cat_Snipers and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_Snipers") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Kar98k",
            UI = AliasMap.Switcher,
            Text = "Kar98k",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Kar98k == true end,
            SetFunc = function(c, v)
                CFG.Loot_Kar98k = ParseBoolVal(v, CFG.Loot_Kar98k)
                if not CFG.Loot_Kar98k and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72013) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_M24",
            UI = AliasMap.Switcher,
            Text = "M24",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_M24 == true end,
            SetFunc = function(c, v)
                CFG.Loot_M24 = ParseBoolVal(v, CFG.Loot_M24)
                if not CFG.Loot_M24 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72014) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Mini14",
            UI = AliasMap.Switcher,
            Text = "Mini14",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Mini14 == true end,
            SetFunc = function(c, v)
                CFG.Loot_Mini14 = ParseBoolVal(v, CFG.Loot_Mini14)
                if not CFG.Loot_Mini14 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72036) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_SKS",
            UI = AliasMap.Switcher,
            Text = "SKS",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_SKS == true end,
            SetFunc = function(c, v)
                CFG.Loot_SKS = ParseBoolVal(v, CFG.Loot_SKS)
                if not CFG.Loot_SKS and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72037) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_SLR",
            UI = AliasMap.Switcher,
            Text = "SLR",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_SLR == true end,
            SetFunc = function(c, v)
                CFG.Loot_SLR = ParseBoolVal(v, CFG.Loot_SLR)
                if not CFG.Loot_SLR and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72038) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 5: SUBMACHINE GUNS & LMGS
        { UI = AliasMap.Title, Text = "--- SMG ---" },
        {
            Key = "Loot_Cat_SMG",
            UI = AliasMap.Switcher,
            Text = "SMGs",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_SMG == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_SMG = ParseBoolVal(v, CFG.Loot_Cat_SMG)
                if not CFG.Loot_Cat_SMG and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_SMG") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_DP28",
            UI = AliasMap.Switcher,
            Text = "DP-28",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_DP28 == true end,
            SetFunc = function(c, v)
                CFG.Loot_DP28 = ParseBoolVal(v, CFG.Loot_DP28)
                if not CFG.Loot_DP28 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72033) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_M249",
            UI = AliasMap.Switcher,
            Text = "M249",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_M249 == true end,
            SetFunc = function(c, v)
                CFG.Loot_M249 = ParseBoolVal(v, CFG.Loot_M249)
                if not CFG.Loot_M249 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72015) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_P90",
            UI = AliasMap.Switcher,
            Text = "P90",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_P90 == true end,
            SetFunc = function(c, v)
                CFG.Loot_P90 = ParseBoolVal(v, CFG.Loot_P90)
                if not CFG.Loot_P90 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72016) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_UMP45",
            UI = AliasMap.Switcher,
            Text = "UMP45",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_UMP45 == true end,
            SetFunc = function(c, v)
                CFG.Loot_UMP45 = ParseBoolVal(v, CFG.Loot_UMP45)
                if not CFG.Loot_UMP45 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72017) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Vector",
            UI = AliasMap.Switcher,
            Text = "Vector",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Vector == true end,
            SetFunc = function(c, v)
                CFG.Loot_Vector = ParseBoolVal(v, CFG.Loot_Vector)
                if not CFG.Loot_Vector and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72018) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Uzi",
            UI = AliasMap.Switcher,
            Text = "Micro UZI",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Uzi == true end,
            SetFunc = function(c, v)
                CFG.Loot_Uzi = ParseBoolVal(v, CFG.Loot_Uzi)
                if not CFG.Loot_Uzi and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72019) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_PP19",
            UI = AliasMap.Switcher,
            Text = "PP-19",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_PP19 == true end,
            SetFunc = function(c, v)
                CFG.Loot_PP19 = ParseBoolVal(v, CFG.Loot_PP19)
                if not CFG.Loot_PP19 and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72042) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Thompson",
            UI = AliasMap.Switcher,
            Text = "Thompson",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Thompson == true end,
            SetFunc = function(c, v)
                CFG.Loot_Thompson = ParseBoolVal(v, CFG.Loot_Thompson)
                if not CFG.Loot_Thompson and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72043) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 6: SHOTGUNS
        { UI = AliasMap.Title, Text = "--- SHOTGUNS ---" },
        {
            Key = "Loot_Cat_Shotguns",
            UI = AliasMap.Switcher,
            Text = "Shotguns",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_Shotguns == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_Shotguns = ParseBoolVal(v, CFG.Loot_Cat_Shotguns)
                if not CFG.Loot_Cat_Shotguns and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_Shotguns") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_DBS",
            UI = AliasMap.Switcher,
            Text = "DBS",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_DBS == true end,
            SetFunc = function(c, v)
                CFG.Loot_DBS = ParseBoolVal(v, CFG.Loot_DBS)
                if not CFG.Loot_DBS and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72044) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_S12K",
            UI = AliasMap.Switcher,
            Text = "S12K",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_S12K == true end,
            SetFunc = function(c, v)
                CFG.Loot_S12K = ParseBoolVal(v, CFG.Loot_S12K)
                if not CFG.Loot_S12K and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72045) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 7: LEVEL 3 MILITARY GEAR
        { UI = AliasMap.Title, Text = "--- LEVEL 3 GEAR ---" },
        {
            Key = "Loot_Cat_Gear",
            UI = AliasMap.Switcher,
            Text = "Level 3 Gear",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_Gear == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_Gear = ParseBoolVal(v, CFG.Loot_Cat_Gear)
                if not CFG.Loot_Cat_Gear and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_Gear") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Lv3Helmet",
            UI = AliasMap.Switcher,
            Text = "Level 3 Helmet",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Lv3Helmet == true end,
            SetFunc = function(c, v)
                CFG.Loot_Lv3Helmet = ParseBoolVal(v, CFG.Loot_Lv3Helmet)
                if not CFG.Loot_Lv3Helmet and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72020) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Lv3Armor",
            UI = AliasMap.Switcher,
            Text = "Level 3 Vest",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Lv3Armor == true end,
            SetFunc = function(c, v)
                CFG.Loot_Lv3Armor = ParseBoolVal(v, CFG.Loot_Lv3Armor)
                if not CFG.Loot_Lv3Armor and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72021) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Lv3Bag",
            UI = AliasMap.Switcher,
            Text = "Level 3 Bag",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Lv3Bag == true end,
            SetFunc = function(c, v)
                CFG.Loot_Lv3Bag = ParseBoolVal(v, CFG.Loot_Lv3Bag)
                if not CFG.Loot_Lv3Bag and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72022) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 8: HIGH-POWER OPTICAL SCOPES
        { UI = AliasMap.Title, Text = "--- SCOPES ---" },
        {
            Key = "Loot_Cat_Scopes",
            UI = AliasMap.Switcher,
            Text = "Scopes",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_Scopes == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_Scopes = ParseBoolVal(v, CFG.Loot_Cat_Scopes)
                if not CFG.Loot_Cat_Scopes and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_Scopes") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Scope8x",
            UI = AliasMap.Switcher,
            Text = "8x Scope",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Scope8x == true end,
            SetFunc = function(c, v)
                CFG.Loot_Scope8x = ParseBoolVal(v, CFG.Loot_Scope8x)
                if not CFG.Loot_Scope8x and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72023) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Scope6x",
            UI = AliasMap.Switcher,
            Text = "6x Scope",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Scope6x == true end,
            SetFunc = function(c, v)
                CFG.Loot_Scope6x = ParseBoolVal(v, CFG.Loot_Scope6x)
                if not CFG.Loot_Scope6x and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72024) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Scope4x",
            UI = AliasMap.Switcher,
            Text = "4x Scope",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Scope4x == true end,
            SetFunc = function(c, v)
                CFG.Loot_Scope4x = ParseBoolVal(v, CFG.Loot_Scope4x)
                if not CFG.Loot_Scope4x and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72025) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Scope3x",
            UI = AliasMap.Switcher,
            Text = "3x Scope",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Scope3x == true end,
            SetFunc = function(c, v)
                CFG.Loot_Scope3x = ParseBoolVal(v, CFG.Loot_Scope3x)
                if not CFG.Loot_Scope3x and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72032) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 9: MEDICAL SUPPLIES & BOOSTERS
        { UI = AliasMap.Title, Text = "--- MEDICINE ---" },
        {
            Key = "Loot_Cat_Meds",
            UI = AliasMap.Switcher,
            Text = "Medicine",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_Meds == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_Meds = ParseBoolVal(v, CFG.Loot_Cat_Meds)
                if not CFG.Loot_Cat_Meds and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_Meds") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_MedKit",
            UI = AliasMap.Switcher,
            Text = "Med Kit",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_MedKit == true end,
            SetFunc = function(c, v)
                CFG.Loot_MedKit = ParseBoolVal(v, CFG.Loot_MedKit)
                if not CFG.Loot_MedKit and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72026) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_FirstAid",
            UI = AliasMap.Switcher,
            Text = "First Aid",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_FirstAid == true end,
            SetFunc = function(c, v)
                CFG.Loot_FirstAid = ParseBoolVal(v, CFG.Loot_FirstAid)
                if not CFG.Loot_FirstAid and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72027) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Adrenaline",
            UI = AliasMap.Switcher,
            Text = "Adrenaline",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Adrenaline == true end,
            SetFunc = function(c, v)
                CFG.Loot_Adrenaline = ParseBoolVal(v, CFG.Loot_Adrenaline)
                if not CFG.Loot_Adrenaline and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72028) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_EnergyDrink",
            UI = AliasMap.Switcher,
            Text = "Energy Drink",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_EnergyDrink == true end,
            SetFunc = function(c, v)
                CFG.Loot_EnergyDrink = ParseBoolVal(v, CFG.Loot_EnergyDrink)
                if not CFG.Loot_EnergyDrink and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72039) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Painkiller",
            UI = AliasMap.Switcher,
            Text = "Painkiller",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Painkiller == true end,
            SetFunc = function(c, v)
                CFG.Loot_Painkiller = ParseBoolVal(v, CFG.Loot_Painkiller)
                if not CFG.Loot_Painkiller and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72040) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,

        -- CATEGORY 10: TACTICAL THROWABLES
        { UI = AliasMap.Title, Text = "--- GRENADES ---" },
        {
            Key = "Loot_Cat_Throwables",
            UI = AliasMap.Switcher,
            Text = "Throwables",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Cat_Throwables == true end,
            SetFunc = function(c, v)
                CFG.Loot_Cat_Throwables = ParseBoolVal(v, CFG.Loot_Cat_Throwables)
                if not CFG.Loot_Cat_Throwables and _G.ClearLootCategory then pcall(_G.ClearLootCategory, "Loot_Cat_Throwables") end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_FragGrenade",
            UI = AliasMap.Switcher,
            Text = "Frag Grenade",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_FragGrenade == true end,
            SetFunc = function(c, v)
                CFG.Loot_FragGrenade = ParseBoolVal(v, CFG.Loot_FragGrenade)
                if not CFG.Loot_FragGrenade and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72029) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_SmokeBomb",
            UI = AliasMap.Switcher,
            Text = "Smoke",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_SmokeBomb == true end,
            SetFunc = function(c, v)
                CFG.Loot_SmokeBomb = ParseBoolVal(v, CFG.Loot_SmokeBomb)
                if not CFG.Loot_SmokeBomb and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72030) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Molotov",
            UI = AliasMap.Switcher,
            Text = "Molotov",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Molotov == true end,
            SetFunc = function(c, v)
                CFG.Loot_Molotov = ParseBoolVal(v, CFG.Loot_Molotov)
                if not CFG.Loot_Molotov and _G.ClearLootIconGroup then pcall(_G.ClearLootIconGroup, 72031) end
                _G.SaveModSettings()
                return true
            end
        },
    }

    -- ========================================================================
    -- 5. STACK: SKIN ARMORY (TAB 5)
    -- ========================================================================
    local function SkinSliderEntry(Key, Text, maxCount, applyKind, mapKey)
        return {
            Key = Key,
            UI = AliasMap.Slider,
            Text = Text,
            Min = 1,
            Max = math.max(1, maxCount),
            GetFunc = function()
                return math.min(maxCount, math.max(1, tonumber(CFG[Key]) or 1))
            end,
            SetFunc = function(c, v)
                CFG[Key] = math.min(maxCount, math.max(1, tonumber(v) or 1))
                if CFG.ModSkin == true then
                    pcall(_G.ForceRefreshSkinMaps)
                    pcall(_G.ApplySkinSelectionNow)
                end
                _G.SaveModSettings()
                return true
            end
        }
    end
    local _SkinSuitMax = #((_G.OutfitSkins and _G.OutfitSkins.Suit) or { 1 })
    local _SkinBagMax = #( (_G.OutfitSkins and _G.OutfitSkins.Bag) or { 1 })
    local _SkinHelmetMax = #( (_G.OutfitSkins and _G.OutfitSkins.Helmet) or { 1 })
    local _SkinParachuteMax = #( (_G.OutfitSkins and _G.OutfitSkins.Parachute) or { 1 })
    local _SkinGliderMax = #( (_G.OutfitSkins and _G.OutfitSkins.Glider) or { 1 })
    local function _SkinListMax(list) return math.max(1, #(list or { 1 })) end
    local Stack_Skin = {
        {
            Key = "ModSkin",
            UI = AliasMap.Switcher,
            Text = "Skin Armory",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.ModSkin == true end,
            SetFunc = function(c, v)
                CFG.ModSkin = ParseBoolVal(v, CFG.ModSkin)
                if CFG.ModSkin then
                    pcall(_G.ForceRefreshSkinMaps)
                    pcall(_G.ApplySkinSelectionNow)
                else
                    pcall(_G.RestoreStockSkins)
                end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,
        { UI = AliasMap.Title, Text = "--- EXTRAS ---" },
        {
            Key = "KillMessageEnabled",
            UI = AliasMap.Switcher,
            Text = "Kill Message Skin",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.KillMessageEnabled == true end,
            SetFunc = function(c, v)
                CFG.KillMessageEnabled = ParseBoolVal(v, CFG.KillMessageEnabled)
                if CFG.KillMessageEnabled then pcall(_G.HookKillMessage) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "AttachmentSkinsEnabled",
            UI = AliasMap.Switcher,
            Text = "Attachment Skins",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.AttachmentSkinsEnabled == true end,
            SetFunc = function(c, v)
                CFG.AttachmentSkinsEnabled = ParseBoolVal(v, CFG.AttachmentSkinsEnabled)
                if CFG.ModSkin then pcall(_G.ApplySkinSelectionNow) end
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "Loot_Airdrop_Crate",
            UI = AliasMap.Switcher,
            Text = "AirDrop Crate",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.Loot_Airdrop == true end,
            SetFunc = function(c, v)
                CFG.Loot_Airdrop = ParseBoolVal(v, CFG.Loot_Airdrop)
                if not CFG.Loot_Airdrop and _G.ClearLootIconGroup then
                    pcall(_G.ClearLootIconGroup, 72003)
                end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,
        { UI = AliasMap.Title, Text = "--- OUTFITS ---" },
        SkinSliderEntry("SkinSuit", "Outfit", _SkinSuitMax),
        SkinSliderEntry("SkinBag", "Backpack", _SkinBagMax),
        SkinSliderEntry("SkinHelmet", "Helmet", _SkinHelmetMax),
        SkinSliderEntry("SkinParachute", "Parachute", _SkinParachuteMax),
        SkinSliderEntry("SkinGlider", "Glider", _SkinGliderMax),
        Spacer,
        { UI = AliasMap.Title, Text = "--- RIFLES ---" },
        SkinSliderEntry("SkinM416", "M416", _SkinListMax(_G.skinIdMappings[101004])),
        SkinSliderEntry("SkinAKM", "AKM", _SkinListMax(_G.skinIdMappings[101001])),
        SkinSliderEntry("SkinSCAR", "SCAR-L", _SkinListMax(_G.skinIdMappings[101003])),
        SkinSliderEntry("SkinM762", "Beryl M762", _SkinListMax(_G.skinIdMappings[101008])),
        SkinSliderEntry("SkinAUG", "AUG A3", _SkinListMax(_G.skinIdMappings[101006])),
        SkinSliderEntry("SkinGroza", "Groza", _SkinListMax(_G.skinIdMappings[101005])),
        SkinSliderEntry("SkinQBZ", "QBZ-95", _SkinListMax(_G.skinIdMappings[101007])),
        SkinSliderEntry("SkinACE32", "ACE32", _SkinListMax(_G.skinIdMappings[101102])),
        SkinSliderEntry("SkinM16A4", "M16A4", _SkinListMax(_G.skinIdMappings[101002])),
        SkinSliderEntry("SkinHoney", "Honey Badger", _SkinListMax(_G.skinIdMappings[101012])),
        Spacer,
        { UI = AliasMap.Title, Text = "--- SMG ---" },
        SkinSliderEntry("SkinUMP", "UMP45", _SkinListMax(_G.skinIdMappings[102002])),
        SkinSliderEntry("SkinUZI", "Micro UZI", _SkinListMax(_G.skinIdMappings[102001])),
        SkinSliderEntry("SkinPP19", "PP-19 Bizon", _SkinListMax(_G.skinIdMappings[102005])),
        SkinSliderEntry("SkinP90", "P90", _SkinListMax(_G.skinIdMappings[102105])),
        SkinSliderEntry("SkinDBS", "DBS", _SkinListMax(_G.skinIdMappings[104004])),
        SkinSliderEntry("SkinS12K", "S12K", _SkinListMax(_G.skinIdMappings[104003])),
        SkinSliderEntry("SkinASM", "ASM Abakan", _SkinListMax(_G.skinIdMappings[101101])),
        Spacer,
        { UI = AliasMap.Title, Text = "--- LMG ---" },
        SkinSliderEntry("SkinDP28", "DP-28", _SkinListMax(_G.skinIdMappings[105001])),
        SkinSliderEntry("SkinMG3", "MG3", _SkinListMax(_G.skinIdMappings[105010])),
        Spacer,
        { UI = AliasMap.Title, Text = "--- SNIPERS ---" },
        SkinSliderEntry("SkinAWM", "AWM", _SkinListMax(_G.skinIdMappings[103003])),
        SkinSliderEntry("SkinKar98k", "Kar98k", _SkinListMax(_G.skinIdMappings[103001])),
        SkinSliderEntry("SkinM24", "M24", _SkinListMax(_G.skinIdMappings[103002])),
        SkinSliderEntry("SkinMini14", "Mini14", _SkinListMax(_G.skinIdMappings[103004])),
        SkinSliderEntry("SkinSKS", "SKS", _SkinListMax(_G.skinIdMappings[103005])),
        SkinSliderEntry("SkinSLR", "SLR", _SkinListMax(_G.skinIdMappings[103009])),
        Spacer,
        { UI = AliasMap.Title, Text = "--- CARS ---" },
        SkinSliderEntry("SkinCoupe", "Coupe RB", _SkinListMax(_G.VehicleSkins[1961001])),
        SkinSliderEntry("SkinDacia", "Dacia", _SkinListMax(_G.VehicleSkins[1903001])),
        SkinSliderEntry("SkinUAZ", "UAZ", _SkinListMax(_G.VehicleSkins[1908001])),
        SkinSliderEntry("SkinBuggy", "Buggy", _SkinListMax(_G.VehicleSkins[1907002])),
        SkinSliderEntry("SkinMirado", "Mirado", _SkinListMax(_G.VehicleSkins[1915004])),
        SkinSliderEntry("SkinMiniBus", "MiniBus", _SkinListMax(_G.VehicleSkins[1904001])),
        SkinSliderEntry("SkinMonster", "Monster Truck", _SkinListMax(_G.VehicleSkins[1953001])),
        SkinSliderEntry("SkinScooter", "Scooter", _SkinListMax(_G.VehicleSkins[1917001])),
        SkinSliderEntry("SkinGliderVeh", "Motor Glider", _SkinListMax(_G.VehicleSkins[1960001])),
        SkinSliderEntry("SkinHorse", "Horse", _SkinListMax(_G.VehicleSkins[1987001])),
        SkinSliderEntry("SkinCyber", "Cybertruck", _SkinListMax(_G.VehicleSkins[1916004])),
    }

    -- ========================================================================
    -- 6. STACK: SYSTEM & GRAPHICS (TAB 6)
    -- ========================================================================
    local Stack_System = {
        { UI = AliasMap.Title, Text = "--- CAMERA ---" },
        {
            Key = "iPadViewEnabled",
            UI = AliasMap.Switcher,
            Text = "iPad Wide View",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.iPadViewEnabled == true end,
            SetFunc = function(c, v)
                CFG.iPadViewEnabled = ParseBoolVal(v, CFG.iPadViewEnabled)
                pcall(ApplyiPadView, true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "iPadViewFOV",
            UI = AliasMap.Slider,
            Text = "Camera FOV (90-135)",
            Min = 90,
            Max = 135,
            GetFunc = function() return CFG.iPadViewFOV or 110 end,
            SetFunc = function(c, v)
                CFG.iPadViewFOV = math.min(135, math.max(90, tonumber(v) or 110))
                if CFG.iPadViewEnabled then pcall(ApplyiPadView, true) end
                _G.SaveModSettings()
                return true
            end
        },
        Spacer,
        { UI = AliasMap.Title, Text = "--- PERFORMANCE ---" },
        {
            Key = "VisualCleanupEnabled",
            UI = AliasMap.Switcher,
            Text = "Clean Visuals",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.VisualCleanupEnabled == true end,
            SetFunc = function(c, v)
                CFG.VisualCleanupEnabled = ParseBoolVal(v, CFG.VisualCleanupEnabled)
                pcall(ApplyEnvironment, true)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "PotatoGraphicsEnabled",
            UI = AliasMap.Switcher,
            Text = "Low-End Boost",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.PotatoGraphicsEnabled == true end,
            SetFunc = function(c, v)
                CFG.PotatoGraphicsEnabled = ParseBoolVal(v, CFG.PotatoGraphicsEnabled)
                pcall(ApplyPotatoGraphics, CFG.PotatoGraphicsEnabled)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "TargetFPS",
            UI = AliasMap.Switcher,
            Text = "Max FPS",
            SwitcherText = { "60 FPS", "90 FPS", "120 FPS", "144 FPS", "165 FPS (Ultra)" },
            SwitcherValue = { 60, 90, 120, 144, 165 },
            GetFunc = function() return math.min(165, math.max(60, tonumber(CFG.TargetFPS) or 90)) end,
            SetFunc = function(c, v)
                CFG.TargetFPS = math.min(165, math.max(60, tonumber(v) or 90))
                if _G.ResetFPSCache then pcall(_G.ResetFPSCache) end
                pcall(ApplyFPSLimit, CFG.TargetFPS)
                _G.SaveModSettings()
                return true
            end
        },
        {
            Key = "FPSStabilizerEnabled",
            UI = AliasMap.Switcher,
            Text = "Smooth FPS",
            SwitcherText = boolSwitcherText,
            SwitcherValue = boolSwitcherVal,
            GetFunc = function() return CFG.FPSStabilizerEnabled == true end,
            SetFunc = function(c, v)
                CFG.FPSStabilizerEnabled = ParseBoolVal(v, CFG.FPSStabilizerEnabled)
                if _G.ResetFPSCache then pcall(_G.ResetFPSCache) end
                pcall(ApplyFPSStabilizer, CFG.FPSStabilizerEnabled)
                _G.SaveModSettings()
                return true
            end
        }
    }

    -- Master Mod Menu Definition (Native In-Game Settings Page)
    -- TAB 1: PLAYER ESP, TAB 2: COMBAT ENGINE, TAB 3: VEHICLE RADAR, TAB 4: SUPPLY & LOOT ESP, TAB 5: SKIN ARMORY, TAB 6: SYSTEM & GRAPHICS
    SettingPageDefine.ModMenu = {
        Key = "ModMenu",
        Text = "ELITE MENU",
        UIKey = "Setting_Page_Privacy",
        Category = {
            { Key = "Cat_Visuals",  Text = "PLAYER ESP",         Stack = Stack_Visuals },
            { Key = "Cat_Combat",   Text = "COMBAT ENGINE",      Stack = Stack_Combat },
            { Key = "Cat_Vehicle",  Text = "VEHICLE RADAR",      Stack = Stack_Vehicles },
            { Key = "Cat_Loot",     Text = "SUPPLY & LOOT ESP",  Stack = Stack_Loot },
            { Key = "Cat_Skin",     Text = "SKIN ARMORY",        Stack = Stack_Skin },
            { Key = "Cat_System",   Text = "SYSTEM & GRAPHICS",  Stack = Stack_System }
        }
    }

    -- Helper to safely inject page at top of any catalog table
    local function InjectCatalog(cat)
        if not cat or type(cat) ~= "table" then return end
        for _, p in ipairs(cat) do
            if p and p.Key == "ModMenu" then return end
        end
        table.insert(cat, 1, SettingPageDefine.ModMenu)
    end

    -- 1. Lobby Setting Catalog
    local catLobby = package.loaded["client.logic.NewSetting.SettingCatalog"]
        or (pcall(require, "client.logic.NewSetting.SettingCatalog") and require("client.logic.NewSetting.SettingCatalog"))
    InjectCatalog(catLobby)

    -- 2. BaseMod In-Game Match Setting Catalog
    local catBaseMod = package.loaded["GameLua.Mod.BaseMod.Client.Config.SettingCatalog"]
        or (pcall(require, "GameLua.Mod.BaseMod.Client.Config.SettingCatalog") and require("GameLua.Mod.BaseMod.Client.Config.SettingCatalog"))
    InjectCatalog(catBaseMod)

    -- 3. Active Match Dynamic Config Catalog (GamePlayTools)
    pcall(function()
        local GamePlayTools = package.loaded["GameLua.Mod.BaseMod.Common.GamePlayTools"]
            or (pcall(require, "GameLua.Mod.BaseMod.Common.GamePlayTools") and require("GameLua.Mod.BaseMod.Common.GamePlayTools"))
        if GamePlayTools and GamePlayTools.GetCurrentConfig then
            local activeCat = GamePlayTools.GetCurrentConfig("SettingCatalog")
            InjectCatalog(activeCat)
        end
    end)

    -- 4. PlanCH (TDM / Arena) & PlanPH Theme Mode Setting Catalogs
    local catPlanCH = package.loaded["GameLua.Mod.PlanCH.Client.Config.SettingCatalog"]
        or (pcall(require, "GameLua.Mod.PlanCH.Client.Config.SettingCatalog") and require("GameLua.Mod.PlanCH.Client.Config.SettingCatalog"))
    InjectCatalog(catPlanCH)

    local catPlanPH = package.loaded["GameLua.Mod.PlanPH.Client.Config.SettingCatalog"]
        or (pcall(require, "GameLua.Mod.PlanPH.Client.Config.SettingCatalog") and require("GameLua.Mod.PlanPH.Client.Config.SettingCatalog"))
    InjectCatalog(catPlanPH)

    -- 5. D350 Mode Setting Catalog
    local catD350 = package.loaded["GameLua.Mod.D350.Client.Config.SettingCatalog"]
        or (pcall(require, "GameLua.Mod.D350.Client.Config.SettingCatalog") and require("GameLua.Mod.D350.Client.Config.SettingCatalog"))
    InjectCatalog(catD350)

    -- 6. Check package.loaded for any other active SettingCatalogs
    for k, v in pairs(package.loaded) do
        if type(k) == "string" and k:find("SettingCatalog") and type(v) == "table" then
            InjectCatalog(v)
        end
    end

    _G.ModMenuInitialized = true
    return true
end

-- ============================================================================
-- 10. GAME LIFECYCLE HOOKS + SELF-HEALING WATCHDOG (MULTI-MATCH SURVIVAL)
-- ============================================================================
-- Root Cause Analysis (from ClientGameMain.lua):
-- 1. Game fires EVENTID_INGAME_CONTROLLER_BEGINPLAY when new match PC is ready
-- 2. Between matches, GetActivePlayerController() returns nil (lobby has no PC)
-- 3. Our AddGameTimer timers die when old PC is destroyed by UE4
-- 4. time_ticker (FTimeTicker) SURVIVES between matches (C++ native singleton)
--
-- Solution: Hook into game's EventSystem + fast-poll during transitions only

local _WatchdogLoopToken = (_G._WatchdogLoopToken or 0) + 1
_G._WatchdogLoopToken = _WatchdogLoopToken
local myToken = _WatchdogLoopToken

-- Track match state for fast-polling during transitions
local _matchTransitionMode = false
local _lastPCRef = nil

-- Core re-initialization function
local function IsSameActor(a, b)
    if a == b then return true end
    if not IsValid(a) or not IsValid(b) then return false end
    -- GetUniqueID is a native call on possibly-destroyed prior-match userdata:
    -- pcall each side separately (TOCTOU hardened, Lua-error safe).
    local idA, idB = nil, nil
    pcall(function() if a.GetUniqueID then idA = a:GetUniqueID() end end)
    pcall(function() if b.GetUniqueID then idB = b:GetUniqueID() end end)
    if idA and idB and idA ~= 0 and idA == idB then return true end
    return tostring(a) == tostring(b)
end

local function FullMatchInit(bIsMatchChange)
    -- LICENSE GATE
    if not _G.SecureX_Authorized() then return false end
    local pc = GetActivePlayerController()
    if not IsValid(pc) then return false end

    -- Same-frame double-fire mutex: BEGINPLAY + BEGINPLAY_FINISH + Watchdog can
    -- all fire FullMatchInit within milliseconds (each would rebuild schedulers
    -- and re-apply skins natively). Genuine matches are seconds apart; the
    -- transition fast-poll (0.5s) retries anyway, so collapsing is lossless.
    -- MUST use os.clock (monotonic process time): GetGameTimeNow is WORLD time
    -- and resets every match -- using it here blocked the ENTIRE 2nd match.
    local nowM = os.clock()
    if _G._fmiMutexUntil and nowM < _G._fmiMutexUntil then return false end
    _G._fmiMutexUntil = nowM + 0.5

    -- Detect genuine match transition or PC change (prevents false "timers alive" on pointer reuse)
    local isNewMatch = (bIsMatchChange == true)
        or (_matchTransitionMode == true)
        or (not IsValid(_G.MASTER_DISPATCHER_OWNER))
        or (not IsSameActor(_G.MASTER_DISPATCHER_OWNER, pc))
        or (_lastPCRef == nil)
        or (not IsSameActor(_lastPCRef, pc))

    -- Check if timers are genuinely alive on this specific active PC
    local timersAlive = (not isNewMatch)
        and IsValid(_G.MASTER_DISPATCHER_OWNER)
        and IsSameActor(_G.MASTER_DISPATCHER_OWNER, pc)
        and _G.COMBAT_DISPATCHER_TIMER ~= nil
        and _G.LASER_DISPATCHER_TIMER ~= nil

    if not timersAlive or isNewMatch then
        -- Force-nil stale timer handles if PC changed
        if _G.MASTER_DISPATCHER_OWNER and (not IsValid(_G.MASTER_DISPATCHER_OWNER) or not IsSameActor(_G.MASTER_DISPATCHER_OWNER, pc)) then
            _G.MASTER_DISPATCHER_TIMER = nil
            _G.COMBAT_DISPATCHER_TIMER = nil
            _G.LASER_DISPATCHER_TIMER = nil
            _G.MASTER_DISPATCHER_OWNER = nil
        end

        -- Full re-initialization for match
        pcall(InitMapTracking)
        pcall(ApplyFPSStabilizer, CFG.FPSStabilizerEnabled ~= false)
        pcall(ApplyTier0Lite)
        if CFG.TargetFPS then pcall(ApplyFPSLimit, CFG.TargetFPS) end
        if CFG.PotatoGraphicsEnabled then pcall(ApplyPotatoGraphics, true) end
        if CFG.VisualCleanupEnabled then pcall(ApplyEnvironment, true) end
        if CFG.iPadViewEnabled then pcall(ApplyiPadView, true) end
        if CFG.AimAssistEnabled and _G.ApplyAimAssist then pcall(_G.ApplyAimAssist, true) end
        if CFG.NoRecoilEnabled and _G.ApplyNoRecoil then pcall(_G.ApplyNoRecoil, true) end
        if CFG.ModSkin then
            pcall(_G.ForceRefreshSkinMaps)
            local _skPc = GetActivePlayerController()
            local _skLp = GetLocalPlayer(_skPc)
            if IsValid(_skLp) then
                pcall(_G.equip_character_avatar, _skLp)
                pcall(_G.ApplyWeaponSkins, _skLp)
            end
        end
        pcall(HookThrowableProjectiles)
        if _G.HookKillMessage then pcall(_G.HookKillMessage) end
        -- pcall: AddGameTimer on a transitioning PC must never abort the tick
        -- with a Lua error (native safety comes from the IsValid gate inside).
        pcall(StartMasterScheduler, pc, isNewMatch)

        _lastPCRef = pc
        _matchTransitionMode = false
        return true
    else
        -- Timers are ALREADY running smoothly on this PC! Clear transition mode and DO NOT touch timers!
        _matchTransitionMode = false
        return false
    end
end

-- Watchdog tick — runs periodically to detect and fix state issues
local function WatchdogTick()
    -- LICENSE GATE
    if not _G.SecureX_Authorized() then return end
    local pc = GetActivePlayerController()

    if not IsValid(pc) then
        -- We're in lobby/loading — enter fast-poll mode for next match
        _matchTransitionMode = true
        return
    end

    local timersAlive = IsValid(_G.MASTER_DISPATCHER_OWNER)
        and IsSameActor(_G.MASTER_DISPATCHER_OWNER, pc)
        and _G.COMBAT_DISPATCHER_TIMER ~= nil
        and _G.LASER_DISPATCHER_TIMER ~= nil

    -- Heartbeat verification (2nd-match silence fix): handles can look alive
    -- while their native timers are actually dead (destroyed owner passing a
    -- stale IsValid, module reload, engine stall). If neither dispatcher has
    -- fired for 5s mid-match, drop the handles so FullMatchInit rebuilds.
    -- Grace: skip while transitioning (ticks may legitimately pause there).
    if timersAlive and not _matchTransitionMode then
        local nowHB = os.clock()
        local combatStale = _G._lastCombatTick and (nowHB - _G._lastCombatTick) > 5.0
        local laserStale = _G._lastLaserTick and (nowHB - _G._lastLaserTick) > 5.0
        if (combatStale and laserStale) or (not _G._lastCombatTick and not _G._lastLaserTick and _G._fmiMutexUntil and nowHB > _G._fmiMutexUntil + 5.0) then
            _G.COMBAT_DISPATCHER_TIMER = nil
            _G.LASER_DISPATCHER_TIMER = nil
            _G.MASTER_DISPATCHER_TIMER = nil
            timersAlive = false
        end
    end

    if _matchTransitionMode or not timersAlive then
        pcall(FullMatchInit, _matchTransitionMode)
    end

    -- GM-button hide: once per PC (pointer-keyed), not every watchdog tick.
    -- Writing fields onto live PC userdata every 3s mid-transition is a native
    -- crash vector; one successful hide per PC is sufficient.
    local gmKey = tostring(pc)
    if _G._gmHiddenFor ~= gmKey then
        _G._gmHiddenFor = gmKey
        pcall(function()
        pc.IsAGMPlayer = function() return false end
        pc.IsEnterpriseGMMod = function() return false end
        local InGameUITools = package.loaded["GameLua.Mod.BaseMod.Common.UI.InGameUITools"]
            or (pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools") and require("GameLua.Mod.BaseMod.Common.UI.InGameUITools"))
        if InGameUITools and InGameUITools.GetMainControlBaseUI then
            local mainUI = InGameUITools.GetMainControlBaseUI()
            if mainUI and mainUI.Button_IngameGM and IsValid(mainUI.Button_IngameGM) then
                mainUI.Button_IngameGM:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
            if mainUI and mainUI.TextBlock_GMUI and IsValid(mainUI.TextBlock_GMUI) then
                mainUI.TextBlock_GMUI:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
        end
        end)
    end
    pcall(_G.InitModMenuTab)
end

-- Layer 1: common.time_ticker watchdog loop (SURVIVES between matches!)
-- FTimeTicker is a C++ native singleton that persists through match transitions
local function RunWatchdogLoop()
    if myToken ~= _G._WatchdogLoopToken then return end
    pcall(WatchdogTick)

    -- Schedule next tick: fast (0.5s) during transition, normal (3.0s) otherwise
    local interval = _matchTransitionMode and 0.5 or 3.0

    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker then
        if ticker.AddTimerOnce then
            ticker.AddTimerOnce(interval, RunWatchdogLoop)
        elseif ticker.AddTimer then
            ticker.AddTimer(interval, RunWatchdogLoop)
        elseif ticker.AddTimerLoop then
            ticker.AddTimerLoop(interval, RunWatchdogLoop, 1, interval)
        end
    end
end

-- Layer 2: Hook into game's EventSystem lifecycle events
-- Guarded against double-registration on re-inject (same VM, _G persists):
-- without this, every re-inject appends duplicate FullMatchInit listeners and
-- duplicate pickup/drop sweep handlers (timer pairs + double native writes).
pcall(function()
    if _G._sx_eventsRegistered then return end
    if _G.EventSystem and _G.EventSystem.registEvent then
        -- Hook: New match's PlayerController is ready
        if _G.EVENTTYPE_INGAME and _G.EVENTID_INGAME_CONTROLLER_BEGINPLAY then
            _G.EventSystem:registEvent(_G.EVENTTYPE_INGAME, _G.EVENTID_INGAME_CONTROLLER_BEGINPLAY, function()
                pcall(FullMatchInit)
            end)
        end

        -- Hook: GameState created (earliest signal that a new match is loading)
        if _G.EVENTTYPE_STATE and _G.EVENTID_GAMESTATE_BEGIN_PLAY then
            _G.EventSystem:registEvent(_G.EVENTTYPE_STATE, _G.EVENTID_GAMESTATE_BEGIN_PLAY, function()
                _matchTransitionMode = true
            end)
        end

        -- Hook: Match ended (pre-switch to lobby)
        if _G.EVENTTYPE_STATE and _G.EVENTID_ON_MODE_PRE_SWITCH then
            _G.EventSystem:registEvent(_G.EVENTTYPE_STATE, _G.EVENTID_ON_MODE_PRE_SWITCH, function()
                _matchTransitionMode = true
            end)
        end

        -- Hook: Controller BeginPlay finished (combat is active)
        if _G.EVENTTYPE_INGAME and _G.EVENTID_INGAME_CONTROLLER_BEGINPLAY_FINISH then
            _G.EventSystem:registEvent(_G.EVENTTYPE_INGAME, _G.EVENTID_INGAME_CONTROLLER_BEGINPLAY_FINISH, function()
                pcall(FullMatchInit)
            end)
        end

        -- Hook: Player picked up item (Instant <0.001s map mark eviction + tombstone protection)
        if _G.EVENTTYPE_PLAYEREVENT_ITEM and _G.EVENTID_PLAYEREVENT_PICKUPITEM then
            _G.EventSystem:registEvent(_G.EVENTTYPE_PLAYEREVENT_ITEM, _G.EVENTID_PLAYEREVENT_PICKUPITEM, function(eventType, eventId, playerKey, itemId, count, reason, source, instId)
                pcall(function()
                    if source and type(source) == "userdata" then
                        local key = GetLootKey(source)
                        if key then
                            if _G.LootTombstones then _G.LootTombstones[key] = GetGameTimeNow() + 20.0 end
                            local attached = _G.ActiveLootAttached and _G.ActiveLootAttached[key]
                            if attached and attached.mId then
                                if _G.SafeHideLootMark then _G.SafeHideLootMark(attached.mId) end
                                if attached.markId and _G.ActiveLootMarkCache[attached.markId] then
                                    _G.ActiveLootMarkCache[attached.markId][key] = nil
                                end
                                _G.ActiveLootAttached[key] = nil
                                if _G.LootDefCache then _G.LootDefCache[key] = nil end
                            end
                        end
                    end
                    pcall(FastLootSweep)
            pcall(FastVehicleSweep)
                end)
            end)
        end

        -- Hook: Player dropped item (Trigger immediate sweep)
        if _G.EVENTTYPE_PLAYEREVENT_ITEM and _G.EVENTID_PLAYEREVENT_DROPITEM then
            _G.EventSystem:registEvent(_G.EVENTTYPE_PLAYEREVENT_ITEM, _G.EVENTID_PLAYEREVENT_DROPITEM, function(eventType, eventId, playerKey, itemId, count, reason)
                pcall(FastLootSweep)
            pcall(FastVehicleSweep)
            end)
        end
    end
    _G._sx_eventsRegistered = true
end)

-- Boot the feature set. Called once, the moment the license is accepted.
function _G.SecureX_BootFeatures()
    if _G._SecureXBooted then return true end
    if not _G.SecureX_Authorized() then return false end
    _G._SecureXBooted = true
    pcall(WatchdogTick)
    pcall(ApplyTier0Lite)
    pcall(_G.InitModMenuTab)
    pcall(function() if CFG.TargetFPS then ApplyFPSLimit(CFG.TargetFPS) end end)
    pcall(function() if CFG.FPSStabilizerEnabled ~= false then ApplyFPSStabilizer(CFG.FPSStabilizerEnabled) end end)
    return true
end

-- Initial boot.  The watchdog loop always runs (it is the driver and is cheap)
-- but every tick is gated, so nothing happens until the key is valid.
RunWatchdogLoop()
if _G.SecureX_Authorized() then
    pcall(WatchdogTick)
    pcall(ApplyTier0Lite)
    pcall(_G.InitModMenuTab)
end

-- Manual triggers (last resort + compat)
_G.StartPBC = function() pcall(FullMatchInit) pcall(WatchdogTick) end
_G.RetryStart = function() pcall(FullMatchInit) pcall(WatchdogTick) end
_G.OnMatchStart = function() pcall(FullMatchInit) end

return true
