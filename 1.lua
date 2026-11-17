-- Supplied hack feature implementation follows in its own scope.
-- ============================================================================
-- SKINS VISUAL ENGINE  (extracted from Skin.lua - skin codes/logic only)
-- ============================================================================
local function __SkinsVisualEngine()
    if type(_G.SKIN_TOGGLES) ~= "table" then _G.SKIN_TOGGLES = { ALL_SKIN = false } end
    _G.ALL_SKINS_ENABLED = (_G.SKIN_TOGGLES.ALL_SKIN == true)
    local function _skOn(id) local t=_G.SKIN_TOGGLES; if type(t)~="table" then return false end; if t.ALL_SKIN~=true then return false end; return t[id]~=false end
    local _outfitSavePathCache = nil
    local function _getOutfitSavePath()
        if _outfitSavePathCache then return _outfitSavePathCache end
        local pid = "default"
        pcall(function()
            local Subsystem = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
            local AccountSubsystem = Subsystem:Get("AccountSubsystem")
            if AccountSubsystem and AccountSubsystem.GetAccountUID then
                local uid = AccountSubsystem:GetAccountUID()
                if uid and uid ~= 0 then pid = tostring(uid) end
            end
        end)
        local fileName = "SERIOTON_AddOutfit_Save_" .. pid .. ".txt"
        local possibleDirs = {
            '/storage/emulated/0/Android/data/com.pubg.imobile/files/',
            '/storage/emulated/0/Android/data/com.pubg.krmobile/files/',
            '/storage/emulated/0/Android/data/com.vng.pubgmobile/files/',
            '/storage/emulated/0/Android/data/com.rekoo.pubgm/files/'
        }
        for _, dir in ipairs(possibleDirs) do
            local f = io.open(dir .. fileName, 'r')
            if f then f:close(); _outfitSavePathCache = dir .. fileName; return _outfitSavePathCache end
        end
        for _, dir in ipairs(possibleDirs) do
            local f = io.open(dir .. "config.ini", 'r')
            if f then f:close(); _outfitSavePathCache = dir .. fileName; return _outfitSavePathCache end
        end
        _outfitSavePathCache = possibleDirs[1] .. fileName
        return _outfitSavePathCache
    end

    local function _saveEquippedCache()
        pcall(function()
            local cch = _G.AddOutfitEquippedCache
            if not cch then return end
            local path = _getOutfitSavePath()
            local lines = {}
            if cch.outfitRes then lines[#lines + 1] = "outfitRes=" .. tostring(cch.outfitRes) end
            if cch.outfitIns then lines[#lines + 1] = "outfitIns=" .. tostring(cch.outfitIns) end
            local clothIds = {}
            for resID in pairs(cch.clothes or {}) do
                clothIds[#clothIds + 1] = tostring(resID)
            end
            if #clothIds > 0 then
                lines[#lines + 1] = "clothes=" .. table.concat(clothIds, ",")
            end
            local eq = cch.equip or {}
            if eq.bag then lines[#lines + 1] = "equip_bag=" .. tostring(eq.bag) end
            if eq.helmet then lines[#lines + 1] = "equip_helmet=" .. tostring(eq.helmet) end
            if eq.armor then lines[#lines + 1] = "equip_armor=" .. tostring(eq.armor) end
            if eq.parachute then lines[#lines + 1] = "equip_parachute=" .. tostring(eq.parachute) end
            if eq.glider then lines[#lines + 1] = "equip_glider=" .. tostring(eq.glider) end
            if eq.bagIns then lines[#lines + 1] = "equip_bagIns=" .. tostring(eq.bagIns) end
            if eq.helmetIns then lines[#lines + 1] = "equip_helmetIns=" .. tostring(eq.helmetIns) end
            if eq.armorIns then lines[#lines + 1] = "equip_armorIns=" .. tostring(eq.armorIns) end
            if eq.parachuteIns then lines[#lines + 1] = "equip_parachuteIns=" .. tostring(eq.parachuteIns) end
            if eq.gliderIns then lines[#lines + 1] = "equip_gliderIns=" .. tostring(eq.gliderIns) end
            for wid, w in pairs(cch.weapons or {}) do
                lines[#lines + 1] = "weapon_" .. tostring(wid) .. "=" .. tostring(w.resID) .. ":" .. tostring(w.insID or 0)
            end
            pcall(function()
                if DataMgr and DataMgr.MotionSlotList then
                    local parts = {}
                    for _, ins in ipairs(DataMgr.MotionSlotList) do
                        ins = tonumber(ins)
                        if ins and ins > 0 then parts[#parts + 1] = tostring(ins) end
                    end
                    if #parts > 0 then lines[#lines + 1] = "motion=" .. table.concat(parts, ",") end
                end
            end)
            pcall(function()
                local AvatarData = require("client.logic.data.AvatarData")
                local parts = {}
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 then parts[#parts + 1] = tostring(ins) end
                end
                if #parts > 0 then lines[#lines + 1] = "rolewear=" .. table.concat(parts, ",") end
            end)
            pcall(function()
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    for subType, ins in pairs(DataMgr.equipmentSkinInsIDTable) do
                        ins = tonumber(ins)
                        if ins and ins > 0 then
                            lines[#lines + 1] = "equipins_" .. tostring(subType) .. "=" .. tostring(ins)
                        end
                    end
                end
            end)
            pcall(function()
                if DataMgr and DataMgr.vst_skin then
                    local ins = tonumber(DataMgr.vst_skin)
                    if ins and ins > 0 then lines[#lines + 1] = "vst_skin=" .. tostring(ins) end
                end
            end)
            pcall(function()
                local HT = require("client.logic.lobby.hall_theme_utils")
                local ins = tonumber(HT.GetThemeInstId and HT.GetThemeInstId()) or 0
                if ins > 0 then
                    lines[#lines + 1] = "hall_theme_ins=" .. tostring(ins)
                    local res = tonumber(HT.homeThemeItemId) or 0
                    if res <= 0 and _G.AddOutfit_R and _G.AddOutfit_R.insToRes then
                        res = tonumber(_G.AddOutfit_R.insToRes[ins]) or 0
                    end
                    if res > 0 then lines[#lines + 1] = "hall_theme_res=" .. tostring(res) end
                end
            end)
            pcall(function()
                if DataMgr and DataMgr.VehicleSlotList then
                    for subType, insList in pairs(DataMgr.VehicleSlotList) do
                        if insList and type(insList) == "table" then
                            local parts = {}
                            for _, ins in ipairs(insList) do
                                ins = tonumber(ins)
                                if ins and ins > 0 then parts[#parts + 1] = tostring(ins) end
                            end
                            if #parts > 0 then
                                lines[#lines + 1] = "vehicle_" .. tostring(subType) .. "=" .. table.concat(parts, ",")
                            end
                        end
                    end
                end
            end)
            pcall(function()
                local GTS = ModuleManager and ModuleManager.GetModule
                    and ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if GTS and GTS.GarageVehicleInfo then
                    for slot, info in pairs(GTS.GarageVehicleInfo) do
                        if info and info.inst_id then
                            lines[#lines + 1] = "garage_" .. tostring(slot) .. "="
                                .. tostring(info.inst_id) .. ":" .. tostring(info.res_id or 0)
                        end
                    end
                end
            end)
            pcall(function()
                local cch2 = _G.AddOutfitEquippedCache
                if cch2 and cch2.throwObjects then
                    for st, info in pairs(cch2.throwObjects) do
                        if info.resID and info.resID > 0 then
                            lines[#lines + 1] = "throw_" .. tostring(st) .. "=" .. tostring(info.resID) .. ":" .. tostring(info.insID or 0)
                        end
                    end
                end
            end)
            local file = io.open(path, 'w+')
            if not file then return end
            file:write(table.concat(lines, "\n"))
            file:close()
        end)
    end

    local function _loadEquippedCache()
        pcall(function()
            local path = _getOutfitSavePath()
            local file = io.open(path, 'r')
            if not file then return end
            local content = file:read('*a')
            file:close()
            if not content or content == "" then return end

            _G._savedOutfitClothes = {}
            _G._savedOutfitRes = nil
            _G._savedOutfitIns = nil
            _G._savedOutfitEquip = {}
            _G._savedVehicleSlotList = {}
            _G._savedGarageVehicles = {}
            _G._savedMotionList = {}
            _G._savedRoleWearList = {}
            _G._savedEquipIns = {}
            _G._savedVstSkin = nil
            _G._savedHallThemeIns = nil
            _G._savedHallThemeRes = nil
            _G._savedThrowObjects = {}

            for line in content:gmatch("[^\n]+") do
                local key, val = line:match("^(.-)=(.+)$")
                if key and val then
                    if key == "outfitRes" then _G._savedOutfitRes = tonumber(val)
                    elseif key == "outfitIns" then _G._savedOutfitIns = tonumber(val)
                    elseif key == "clothes" then
                        for id in val:gmatch("([^,]+)") do
                            _G._savedOutfitClothes[tonumber(id)] = true
                        end
                    elseif key == "equip_bag" then _G._savedOutfitEquip.bag = tonumber(val)
                    elseif key == "equip_helmet" then _G._savedOutfitEquip.helmet = tonumber(val)
                    elseif key == "equip_armor" then _G._savedOutfitEquip.armor = tonumber(val)
                    elseif key == "equip_parachute" then _G._savedOutfitEquip.parachute = tonumber(val)
                    elseif key == "equip_glider" then _G._savedOutfitEquip.glider = tonumber(val)
                    elseif key == "equip_bagIns" then _G._savedOutfitEquip.bagIns = tonumber(val)
                    elseif key == "equip_helmetIns" then _G._savedOutfitEquip.helmetIns = tonumber(val)
                    elseif key == "equip_armorIns" then _G._savedOutfitEquip.armorIns = tonumber(val)
                    elseif key == "equip_parachuteIns" then _G._savedOutfitEquip.parachuteIns = tonumber(val)
                    elseif key == "equip_gliderIns" then _G._savedOutfitEquip.gliderIns = tonumber(val)
                    elseif key == "motion" then
                        for ins in val:gmatch("([^,]+)") do
                            ins = tonumber(ins)
                            if ins and ins > 0 then _G._savedMotionList[#_G._savedMotionList + 1] = ins end
                        end
                    elseif key == "rolewear" then
                        for ins in val:gmatch("([^,]+)") do
                            ins = tonumber(ins)
                            if ins and ins > 0 then _G._savedRoleWearList[#_G._savedRoleWearList + 1] = ins end
                        end
                    elseif key:match("^equipins_(%d+)$") then
                        local subType = tonumber(key:match("^equipins_(%d+)$"))
                        if subType then _G._savedEquipIns[subType] = tonumber(val) end
                    elseif key == "vst_skin" then _G._savedVstSkin = tonumber(val)
                    elseif key == "hall_theme_ins" then _G._savedHallThemeIns = tonumber(val)
                    elseif key == "hall_theme_res" then _G._savedHallThemeRes = tonumber(val)
                    elseif key:match("^weapon_(.+)$") then
                        local wid = tonumber(key:match("^weapon_(.+)$"))
                        local resID, insID = val:match("^(.-):(.+)$")
                        if wid and resID then
                            _G._savedOutfitEquip["weapon_" .. wid] = { resID = tonumber(resID), insID = tonumber(insID) or 0 }
                        end
                    elseif key:match("^vehicle_(%d+)$") then
                        local subType = tonumber(key:match("^vehicle_(%d+)$"))
                        if subType then
                            local list = {}
                            for ins in val:gmatch("([^,]+)") do
                                ins = tonumber(ins)
                                if ins and ins > 0 then list[#list + 1] = ins end
                            end
                            if #list > 0 then _G._savedVehicleSlotList[subType] = list end
                        end
                    elseif key:match("^garage_(%d+)$") then
                        local slot = tonumber(key:match("^garage_(%d+)$"))
                        local insID, resID = val:match("^(.-):(.+)$")
                        if slot and insID then
                            _G._savedGarageVehicles[slot] = {
                                inst_id = tonumber(insID),
                                res_id = tonumber(resID) or 0,
                            }
                        end
                    elseif key:match("^throw_(%d+)$") then
                        local st = tonumber(key:match("^throw_(%d+)$"))
                        if st then
                            local resID, insID = val:match("^(.-):(.+)$")
                            _G._savedThrowObjects[st] = { resID = tonumber(resID), insID = tonumber(insID) or 0 }
                        end
                    end
                end
            end

            if not _G.AddOutfitEquippedCache then
                _G.AddOutfitEquippedCache = {
                    outfitRes = nil, outfitIns = nil,
                    clothes = {}, equip = {}, weapons = {},
                }
            end
            local cch = _G.AddOutfitEquippedCache
            cch.clothes = cch.clothes or {}
            cch.equip = cch.equip or {}
            cch.weapons = cch.weapons or {}

            if _G._savedOutfitRes then
                cch.outfitRes = _G._savedOutfitRes
                cch.outfitIns = _G._savedOutfitIns
            end
            if not _G._addOutfitPersistLoaded and _G._savedOutfitClothes then
                for resID in pairs(_G._savedOutfitClothes) do
                    cch.clothes[resID] = true
                end
            end

            if _G._savedOutfitEquip then
                for k, v in pairs(_G._savedOutfitEquip) do
                    if k == "bag" then cch.equip.bag = v
                    elseif k == "helmet" then cch.equip.helmet = v
                    elseif k == "armor" then cch.equip.armor = v
                    elseif k == "parachute" then cch.equip.parachute = v
                    elseif k == "glider" then cch.equip.glider = v
                    elseif k == "bagIns" then cch.equip.bagIns = v
                    elseif k == "helmetIns" then cch.equip.helmetIns = v
                    elseif k == "armorIns" then cch.equip.armorIns = v
                    elseif k == "parachuteIns" then cch.equip.parachuteIns = v
                    elseif k == "gliderIns" then cch.equip.gliderIns = v
                    elseif type(k) == "string" and k:match("^weapon_(.+)$") then
                        local wid = tonumber(k:match("^weapon_(.+)$"))
                        if wid then cch.weapons[wid] = v end
                    end
                end
            end
-- by @IG_Serioton
            if _G._savedThrowObjects then
                cch.throwObjects = cch.throwObjects or {}
                for st, info in pairs(_G._savedThrowObjects) do
                    if info.resID and info.resID > 0 then
                        cch.throwObjects[st] = info
                    end
                end
            end

            _G._addOutfitPersistLoaded = true
            _lastSnapshot = _snapshotCache()
            print("[AddOutfit] Loaded saved IDs from file:", path)
        end)
    end

    local function _snapshotCache()
        local cch = _G.AddOutfitEquippedCache
        if not cch then return "" end
        local parts = {}
        parts[#parts + 1] = tostring(cch.outfitRes or 0)
        local clothIds = {}
        for resID in pairs(cch.clothes or {}) do
            clothIds[#clothIds + 1] = resID
        end
        table.sort(clothIds)
        parts[#parts + 1] = table.concat(clothIds, ",")
        local eq = cch.equip or {}
        parts[#parts + 1] = tostring(eq.bag or 0)
        parts[#parts + 1] = tostring(eq.helmet or 0)
        parts[#parts + 1] = tostring(eq.armor or 0)
        parts[#parts + 1] = tostring(eq.parachute or 0)
        parts[#parts + 1] = tostring(eq.glider or 0)
        local wIds = {}
        for wid in pairs(cch.weapons or {}) do wIds[#wIds + 1] = wid end
        table.sort(wIds)
        for _, wid in ipairs(wIds) do
            local w = cch.weapons[wid]
            parts[#parts + 1] = tostring(wid) .. ":" .. tostring(w.resID or 0)
        end
        if cch.throwObjects then
            local tIds = {}
            for st in pairs(cch.throwObjects) do tIds[#tIds + 1] = st end
            table.sort(tIds)
            for _, st in ipairs(tIds) do
                local info = cch.throwObjects[st]
                parts[#parts + 1] = "throw_" .. tostring(st) .. ":" .. tostring(info.resID or 0)
            end
        end
        return table.concat(parts, "|")
    end

    local _lastSnapshot = ""
    local _saveDirty = false
    local _saveInProgress = false
    local _lastSaveClock = 0
    local SAVE_MIN_INTERVAL = 2.5

    local function _flushSave(force)
        if _saveInProgress then
            _saveDirty = true
            return
        end
        local now = 0
        pcall(function() now = os.clock() end)
        if not force and _lastSaveClock > 0 and (now - _lastSaveClock) < SAVE_MIN_INTERVAL then
            _saveDirty = true
            return
        end
        _saveInProgress = true
        _saveDirty = false
        pcall(function()
            if _G.AddOutfitSyncCacheBeforeSave then _G.AddOutfitSyncCacheBeforeSave() end
            _lastSnapshot = _snapshotCache()
            pcall(_saveEquippedCache)
            local cch2 = _G.AddOutfitEquippedCache
            if cch2 then
                _G._savedOutfitRes = tonumber(cch2.outfitRes) and cch2.outfitRes > 0 and cch2.outfitRes or nil
                _G._savedOutfitIns = tonumber(cch2.outfitIns) and cch2.outfitIns > 0 and cch2.outfitIns or nil
                _G._savedOutfitClothes = {}
                for resID in pairs(cch2.clothes or {}) do
                    _G._savedOutfitClothes[resID] = true
                end
            end
        end)
        pcall(function() _lastSaveClock = os.clock() end)
        _saveInProgress = false
    end

    local _saveDeferred = false
    local function _AutoSaveOutfit(force)
        if force then
            _flushSave(true)
            return
        end
        _saveDirty = true
        if _saveDeferred then return end
        _saveDeferred = true
        local function _doDeferredFlush()
            _saveDeferred = false
            if _saveDirty then _flushSave(false) end
        end
        local ok = pcall(_G.SetTimer, 0.5, _doDeferredFlush)
        if not ok then _doDeferredFlush() end
    end

    _G.AddOutfitTryFlushSave = function()
        if _saveDirty then _flushSave(false) end
    end

    -- ========== حقن WardrobeNewHandler (لإصلاح حفظ السيارات في اللوبي) ==========
    pcall(function()
        local WardrobeNewHandler = {}

        local _bShowNotice = false

        local _ao_R = nil
        local function getR()
            if _ao_R then return _ao_R end
            _ao_R = _G.AddOutfit_R
            return _ao_R
        end
        local function aoIsInjectedIns(ins)
            ins = tonumber(ins)
            if not ins then return false end
            local R = getR()
            return R and R.insToRes[ins] ~= nil
        end

        function WardrobeNewHandler.send_depot_modify_combat_vehicle_req(insID, slotIndex, bShowNotice)
            insID = tonumber(insID)
            slotIndex = tonumber(slotIndex) or 1
            _bShowNotice = bShowNotice
            if aoIsInjectedIns(insID) then
                local R = getR()
                local resID = R and R.insToRes[insID]
                local itemSubType = 0
                if resID and CDataTable and CDataTable.GetTableData then
                    local c = CDataTable.GetTableData("Item", resID)
                    itemSubType = c and tonumber(c.ItemSubType or c.itemSubType) or 0
                end
                if itemSubType and itemSubType > 0 and DataMgr then
                    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                    local slotList = DataMgr.VehicleSlotList[itemSubType] or {}
                    if bShowNotice then
                        for i = #slotList, 1, -1 do
                            if slotList[i] == insID then
                                table.remove(slotList, i)
                            end
                        end
                        slotList[slotIndex] = insID
                    else
                        for i, sid in ipairs(slotList) do
                            if sid == insID then
                                table.remove(slotList, i)
                                break
                            end
                        end
                    end
                    DataMgr.VehicleSlotList[itemSubType] = slotList
                end
                pcall(function()
                    local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                    if tabSurveillance and tabSurveillance.VehicleChange then
                        tabSurveillance.VehicleChange()
                    end
                end)
                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
                end
                pcall(_AutoSaveOutfit)
                return
            end
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(1012780591, insID, slotIndex, bShowNotice)
        end

        function WardrobeNewHandler.on_depot_modify_combat_vehicle_rsp(ret_code, vehicle_info)
            if ret_code ~= 0 and ret_code ~= NetErrorCode_NONE then
                if _bShowNotice and ShowNotice then ShowNotice(ret_code) end
                return
            end
            if vehicle_info and DataMgr then
                DataMgr.VehicleSlotList = vehicle_info
            end
            pcall(function()
                local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                if tabSurveillance and tabSurveillance.VehicleChange then
                    tabSurveillance.VehicleChange()
                end
            end)
            if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
            end
        end

        function WardrobeNewHandler.send_select_item(insID)
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(595484784, insID)
        end

        function WardrobeNewHandler.send_equip_motion_list_req(motion_list)
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(1124239581, motion_list)
        end

        package.loaded["client.network.Protocol.WardrobeNewHandler"] = WardrobeNewHandler
        print("[AddOutfit] WardrobeNewHandler injected into package.loaded")
    end)

    local _ao_ok, _ao_err = pcall(function()
        -- Per-match guard using match counter (handles controller reuse across matches)
        do
            local curMatchID = ""
            pcall(function()
                local GD = require("GameLua.GameCore.Data.GameplayData")
                if GD and GD.GetPlayerController then
                    local pc = GD.GetPlayerController()
                    if pc and slua.isValid(pc) then
                        -- Use the player key + timestamp as unique match ID
                        curMatchID = tostring(pc.PlayerKey or "") .. "_" .. tostring(pc)
                    end
                end
            end)
            if curMatchID == "" then
                _G._AO_MATCH_ID = nil
            elseif _G._AO_MATCH_ID == curMatchID then
                return  -- Already loaded for this match
            else
                _G._AO_MATCH_ID = curMatchID
            end
        end
        local game_frontend_hud = require("game_frontend_hud")

        local DEBUG = true
        local function isInMatchOrGame()
            local ok, r = pcall(function()
                if GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus() then
                    return true
                end
                if GameStatus and GameStatus.IsInLobbyOrMainCity and not GameStatus.IsInLobbyOrMainCity() then
                    return true
                end
            end)
            return ok and r == true
        end
        local function log(...)
            print("[AddOutfit]", ...)
        end

        local MATCH_CONFIG = {
            outfitRes = 0,
            weaponSkins = {},
            equip = { bag = 0, helmet = 0, armor = 0 },
        }

        local ITEMS = {}
        local _itemsLoaded = false  -- -- by @IG_Serioton
        local function buildNonMaxLevelSet()
            local nonMax = {}
            if not (CDataTable and CDataTable.GetTable) then return nonMax end
-- by @IG_Serioton
            pcall(function()
                local upTbl = CDataTable.GetTable("ItemUpgradeConfig")
                if not upTbl then return end
-- by @IG_Serioton
                local maxLvl, maxItem = {}, {}
                local groupMembers = {}
                for _, cfg in pairs(upTbl) do
                    local gid   = tonumber(cfg.GroupID)
                    local lvl   = tonumber(cfg.Level)
                    local itm   = tonumber(cfg.ItemID)
                    if gid and lvl and itm then
                        if not groupMembers[gid] then groupMembers[gid] = {} end
                        groupMembers[gid][#groupMembers[gid] + 1] = itm
                        if not maxLvl[gid] or lvl > maxLvl[gid] then
                            maxLvl[gid] = lvl
                            maxItem[gid] = itm
                        end
                    end
                end
                for gid, members in pairs(groupMembers) do
                    local topItem = maxItem[gid]
                    for _, itm in ipairs(members) do
                        if itm ~= topItem then nonMax[itm] = true end
                    end
                end
            end)

-- by @IG_Serioton
            local function processXSuitTable(tableName)
                pcall(function()
                    local tbl = CDataTable.GetTable(tableName)
                    if not tbl then return end
                    local maxStar, maxItem = {}, {}
                    local periodMembers = {}
                    for _, data in pairs(tbl) do
                        local period = tonumber(data.Period or data.period)
                        local star   = tonumber(data.Star or data.star or data.Level or data.level)
                        local itm    = tonumber(data.ItemID or data.itemID or data.ItemId)
                        if period and star and itm then
                            if not periodMembers[period] then periodMembers[period] = {} end
                            periodMembers[period][#periodMembers[period] + 1] = itm
                            if not maxStar[period] or star > maxStar[period] then
                                maxStar[period] = star
                                maxItem[period] = itm
                            end
                        end
                    end
                    for period, members in pairs(periodMembers) do
                        local topItem = maxItem[period]
                        for _, itm in ipairs(members) do
                            if itm ~= topItem then nonMax[itm] = true end
                        end
                    end
                end)
            end
            processXSuitTable("GoldenSuitUpgradeCfg")
            processXSuitTable("GoldenSuitUpgradeCfgKJ")
            processXSuitTable("GoldenSuitUpgradeCfgIN")

-- by @IG_Serioton
            pcall(function()
                local bpMap = CDataTable.GetTable("BackpackMapping")
                if not bpMap then return end
                for _, m in pairs(bpMap) do
                    local lv3 = tonumber(m.SkinItemIDLv3 or 0) or 0
                    local lv1 = tonumber(m.SkinItemIDLv1 or 0) or 0
                    local lv2 = tonumber(m.SkinItemIDLv2 or 0) or 0
                    if lv1 > 0 and lv1 ~= lv3 then nonMax[lv1] = true end
                    if lv2 > 0 and lv2 ~= lv3 then nonMax[lv2] = true end
                end
            end)

            return nonMax
        end

        local function refreshItems()
            if _itemsLoaded then return #ITEMS end
            if #ITEMS > 0 then return #ITEMS end
            local ItemTable = CDataTable and CDataTable.GetTable and CDataTable.GetTable("Item")
            if not ItemTable then return 0 end
            local nonMax = buildNonMaxLevelSet()
            local seen, count, skipped = {}, 0, 0
            for id, v in pairs(ItemTable) do
                local rid = tonumber(v.ID or v.Id or id)
                if rid and rid > 0 and not seen[rid] then
                    local bpId = tonumber(v.BPID or v.bpID or v.BpId or 0) or 0
                    local mainTab = tonumber(v.WardrobeMainTab or v.wardrobeMainTab or 0) or 0
                    if bpId ~= 0 or mainTab ~= 0 then
                        seen[rid] = true
                        if nonMax[rid] then
                            skipped = skipped + 1
                        else
                            ITEMS[#ITEMS + 1] = rid
                            count = count + 1
                        end
                    end
                end
            end
            table.sort(ITEMS)
            if count > 0 then
                _itemsLoaded = true
                log("@IG_Serioton", count, "-- by @IG_Serioton", "(-- by @IG_Serioton", skipped, "-- by @IG_Serioton)")
            end
            return count
        end
--https://t.me/IG_Serioton
        local _K = {
            INS_BASE = 2000000000, PKG_SLOT = 3, MELEE_ID = 108,
            GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true },
            NET_OK = NetErrorCode_NONE or "ok",
            GUN_MASTER_SYN_SLOT = 7,
            THROW_SUB = { [612] = "shoulei", [613] = "smoke", [614] = "stun", [615] = "burn" },
            THROW_AVATAR_KEY = { shoulei = "GrenadeAvatarShoulei", smoke = "GrenadeAvatarSmoke", stun = "GrenadeAvatarStun", burn = "GrenadeAvatarBurn" },
        }

        local R = { insToRes = {}, resToIns = {} }
        local _injectedResSet = {}
        for _, rid in ipairs(ITEMS) do _injectedResSet[rid] = true end

        local _C = { cfg = {}, fullSuit = {}, equipSlot = {}, weaponId = {}, itemTab = {}, vehicleItems = {}, pageMatch = {} }

        local _S = {
            matchApplied = false, matchTimer = nil, matchOutfitDone = false,
            avatarItemsRegistered = false, weaponApplied = false, weaponDiagDone = false,
            lastWeaponResID = 0, weaponSpawnHooked = false, bootstrapNotified = false,
            globalFrame = 0, weaponHookGuardUntil = 0, equipSkinApplying = false,
            injectedDone = false, lastAppliedWeaponID = 0, lastAppliedSkinID = 0,
            bootstrapped = false, lobbyApplied = false,
        }

        _G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
        _G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}
        _G.AddOutfitLastLobbyOutfitRes = _G.AddOutfitLastLobbyOutfitRes or nil

        _K.ST_TOP     = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Package_Slot) or 403
        _K.ST_PANTS   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Pants_Slot) or 404
        _K.ST_SHOES   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Shoes_Slot) or 405
        _K.ST_UNDER_T = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderCloth) or 450
        _K.ST_UNDER_P = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderPants) or 451
        _K.WARDROBE_TAB_SUIT, _K.WARDROBE_TAB_CLOTHES = 10, 3
        _K.WARDROBE_TAB_TROUSERS, _K.WARDROBE_TAB_SHOES = 4, 5
        _K.WARDROBE_TAB_BAG, _K.WARDROBE_TAB_HELMET, _K.WARDROBE_TAB_ARMOR = 15, 16, 17
        _K.WARDROBE_TAB_GUN, _K.WARDROBE_TAB_PARACHUTE = 9, 7
        _K.WARDROBE_TAB_GLIDER = 20
        _K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_PAGE_VEHICLE = 1, 4, 5, 6
        pcall(function()
            local wm = require("client.slua.umg.Wardrobe.wardrobe_macro")
            local t = wm.ENUM_WardrobeSubTabString
            _K.WARDROBE_TAB_SUIT = t.ENUM_WardrobeSubTabString_suit
            _K.WARDROBE_TAB_CLOTHES = t.ENUM_WardrobeSubTabString_clothes
            _K.WARDROBE_TAB_TROUSERS = t.ENUM_WardrobeSubTabString_trousers
            _K.WARDROBE_TAB_SHOES = t.ENUM_WardrobeSubTabString_shoes
            _K.WARDROBE_TAB_BAG = t.ENUM_WardrobeSubTabString_bag
            _K.WARDROBE_TAB_HELMET = t.ENUM_WardrobeSubTabString_helmet
            _K.WARDROBE_TAB_ARMOR = t.ENUM_WardrobeSubTabString_armor
            _K.WARDROBE_TAB_GUN = t.ENUM_WardrobeSubTabString_gun
            _K.WARDROBE_TAB_PARACHUTE = t.ENUM_WardrobeSubTabString_parachute
            _K.WARDROBE_TAB_GLIDER = t.ENUM_WardrobeSubTabString_effect
            _K.WARDROBE_PAGE_AVATAR = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Avatar
            _K.WARDROBE_PAGE_WEAPON = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Weapon
            _K.WARDROBE_PAGE_PARACHUTE = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Parachute
            _K.WARDROBE_PAGE_VEHICLE = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Vehicle
        end)

        local FULL_SUIT_CLEAR_ST = {
            [_K.ST_TOP] = true, [_K.ST_PANTS] = true, [_K.ST_SHOES] = true,
            [_K.ST_UNDER_T] = true, [_K.ST_UNDER_P] = true,
        }

        local function cache()
            _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
                outfitRes = nil, outfitIns = nil,
                clothes = {},
                equip = {},
                weapons = {},
            }
            return _G.AddOutfitEquippedCache
        end

        local function cfg(resID)
            if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.cfg[resID] ~= nil then return _C.cfg[resID] end
            local c = CDataTable.GetTableData("Item", resID)
            _C.cfg[resID] = c
            return c
        end

        local function subType(c)
            return c and (c.ItemSubType or c.itemSubType) or nil
        end

        local function isThrowObjectRes(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local c = cfg(resID)
            if not c then return nil end
            local st = tonumber(c.ItemSubType or c.itemSubType or 0)
            if _K.THROW_SUB[st] then return st end
            return nil
        end

        local function saveThrowObject(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID then return end
            local st = isThrowObjectRes(resID)
            if not st then return end
            local cch = cache()
            cch.throwObjects = cch.throwObjects or {}
            cch.throwObjects[st] = { resID = resID, insID = insID or R.resToIns[resID] or 0 }
        end

        local function isInjectedIns(ins)
            return ins and R.insToRes[tonumber(ins)] ~= nil
        end

        local function isInjectedRes(res)
            return res and (R.resToIns[tonumber(res)] ~= nil or _injectedResSet[tonumber(res)])
        end

        local function weaponIdFromSkin(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.weaponId[resID] ~= nil then return _C.weaponId[resID] end
            local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
            local wid = m and (m.WeaponID or m.WeaponId) or nil
            _C.weaponId[resID] = wid
            return wid
        end

        local function isHallThemeRes(resID)
            resID = tonumber(resID)
            if not resID then return false end
            local c = cfg(resID)
            if not c then return false end
            local it = tonumber(c.ItemType or c.itemType or 0)
            if ENUM_ITEM_TYPE and ENUM_ITEM_TYPE.Hall_Theme then
                return it == ENUM_ITEM_TYPE.Hall_Theme
            end
            return it == 202
        end

        local function getEquipSkinSlot(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.equipSlot[resID] ~= nil then return _C.equipSlot[resID] end
            local slot = nil
            local itemCfg = cfg(resID)
            if itemCfg then
                local st = tonumber(itemCfg.ItemSubType or itemCfg.itemSubType or 0)
                local it = tonumber(itemCfg.ItemType or itemCfg.itemType or 0)
                if st == 501 or st == 504 then slot = "bag"
                elseif st == 502 or st == 505 then slot = "helmet"
                elseif st == 503 or st == 506 then slot = "armor"
                elseif it == 4 and st == 701 then slot = "parachute"
                elseif it == 4 and (st == 413 or st == 414 or st == 415) then slot = "glider" end
            end
            if not slot then
                if resID >= 1502000000 and resID < 1503000000 then slot = "helmet"
                elseif resID >= 1505000000 and resID < 1506000000 then slot = "helmet"
                elseif resID >= 1501000000 and resID < 1502000000 then slot = "bag"
                elseif resID >= 1504000000 and resID < 1505000000 then slot = "bag" end
            end
            _C.equipSlot[resID] = slot
            return slot
        end

        local function wardrobeTab(resID, depotData)
            if depotData and depotData.subTabType then return tonumber(depotData.subTabType) end
            local c = cfg(resID)
            return c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
        end

        local function wardrobeMainTab(resID, depotData)
            if depotData and depotData.mainTabType then return tonumber(depotData.mainTabType) end
            local c = cfg(resID)
            return c and tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or _K.WARDROBE_PAGE_AVATAR
        end

        local function getInjectedItemTab(resID, depotData)
            resID = tonumber(resID)
            if not resID then return nil, nil end
            if _C.itemTab[resID] then
                return _C.itemTab[resID][1], _C.itemTab[resID][2]
            end
            local c = cfg(resID)
            local st = c and tonumber(c.ItemSubType or c.itemSubType) or 0

            local equipSlot = getEquipSkinSlot(resID)
            local result
            if equipSlot == "bag" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_BAG}
            elseif equipSlot == "helmet" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_HELMET}
            elseif equipSlot == "armor" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_ARMOR}
            elseif equipSlot == "parachute" then result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE}
            elseif equipSlot == "glider" then result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_GLIDER}
            elseif weaponIdFromSkin(resID) then result = {_K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_TAB_GUN}
            else
                local mainTab = wardrobeMainTab(resID, depotData)
                local subTab = wardrobeTab(resID, depotData)
                if subTab and subTab > 0 then result = {mainTab, subTab}
                elseif st == _K.ST_PANTS then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_TROUSERS}
                elseif st == _K.ST_SHOES then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SHOES}
                elseif st == _K.ST_TOP then
                    if isFullSuitRes(resID, depotData) then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SUIT}
                    else result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_CLOTHES} end
                elseif st == 400 or st == 408 or st == 409 or st == 410 then
                    result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE}
                else
                    result = {mainTab, subTab or 0}
                end
            end
            _C.itemTab[resID] = result
            return result[1], result[2]
        end

        local function injectedMatchesPage(resID, depotData, mainTab, subTab)
            local itemMain, itemSub = getInjectedItemTab(resID, depotData)
            if itemMain ~= mainTab or itemSub ~= subTab then return false end
            if subTab == _K.WARDROBE_TAB_SUIT or subTab == _K.WARDROBE_TAB_CLOTHES then
                local st = depotData and depotData.itemSubType or subType(cfg(resID))
                if st == _K.ST_TOP then
                    local full = isFullSuitRes(resID, depotData)
                    if subTab == _K.WARDROBE_TAB_SUIT then return full end
                    if subTab == _K.WARDROBE_TAB_CLOTHES then return not full end
                end
            end
            return true
        end

        local function isFullSuitRes(resID, depotData)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return false end
            if _C.fullSuit[resID] ~= nil then return _C.fullSuit[resID] end
            local result = false
            pcall(function()
                local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                if LogicXSuit.IsXSuit(resID) then result = true end
            end)
            if not result then
                local tab = wardrobeTab(resID, depotData)
                if tab == _K.WARDROBE_TAB_SUIT then result = true end
            end
            _C.fullSuit[resID] = result
            return result
        end

        local function getClothKind(resID, depotData)
            resID = tonumber(resID)
            if not resID then return nil end
            local st = subType(cfg(resID))
            if st == _K.ST_TOP then
                return isFullSuitRes(resID, depotData) and "full_suit" or "top"
            end
            if st == _K.ST_PANTS then return "pants" end
            if st == _K.ST_SHOES then return "shoes" end
            if st == _K.ST_UNDER_T then return "under_top" end
            if st == _K.ST_UNDER_P then return "under_pants" end
            return nil
        end

        local function subTypesToClearForKind(kind)
            if kind == "full_suit" then return FULL_SUIT_CLEAR_ST end
            if kind == "top" then return { [_K.ST_TOP] = true } end
            if kind == "pants" then return { [_K.ST_PANTS] = true } end
            if kind == "shoes" then return { [_K.ST_SHOES] = true } end
            if kind == "under_top" then return { [_K.ST_UNDER_T] = true } end
            if kind == "under_pants" then return { [_K.ST_UNDER_P] = true } end
            return nil
        end

        local function isBodyClothSubType(st)
            st = tonumber(st)
            return st == _K.ST_TOP or st == _K.ST_PANTS or st == _K.ST_SHOES or st == _K.ST_UNDER_T or st == _K.ST_UNDER_P
        end

        local _outfitMergeCache = { key = nil, items = nil }
        local _weaponSkinResMergeCache = { key = nil, res = nil }
        local _convertCache = {}

        local function getConvertedAvatarCustom(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _convertCache[resID] ~= nil then return _convertCache[resID] end
            local AvatarData = require("client.logic.data.AvatarData")
            local converted = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
            _convertCache[resID] = converted
            return converted
        end

        local function invalidateSocialWearCache()
            local s = _G.AddOutfitSocialState
            if s then
                s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
            end
            _outfitMergeCache.key = nil
            _outfitMergeCache.items = nil
            _weaponSkinResMergeCache.key = nil
            _weaponSkinResMergeCache.res = nil
        end

-- by @IG_Serioton
        local EQUIP_LEVEL_SETS = {
            [1502000382] = { lv1 = 1502001382, lv2 = 1502002382, lv3 = 1502003382, slot = "helmet" },
        }
        local _equipLevelByRes = {}
        local function registerEquipLevelSet(catalog, lv1, lv2, lv3, slot)
            catalog = tonumber(catalog)
            if not catalog then return end
            local set = {
                catalog = catalog,
                lv1 = tonumber(lv1) or 0,
                lv2 = tonumber(lv2) or 0,
                lv3 = tonumber(lv3) or 0,
                slot = slot or "helmet",
            }
            EQUIP_LEVEL_SETS[catalog] = set
            for _, rid in ipairs({ catalog, set.lv1, set.lv2, set.lv3 }) do
                if rid and rid > 0 then _equipLevelByRes[rid] = set end
            end
        end
        for catalog, set in pairs(EQUIP_LEVEL_SETS) do
            registerEquipLevelSet(catalog, set.lv1, set.lv2, set.lv3, set.slot)
        end
        _G.AddOutfitRegisterEquipLevelSet = registerEquipLevelSet

-- by @IG_Serioton
        local EQUIP_LEVEL_RANGES = {
            { base = 1502000000, slot = "helmet" }, ---- by @IG_Serioton
            { base = 1501000000, slot = "bag"    }, --  @IG_Serioton
        }

        local function findEquipLevelRange(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            for _, r in ipairs(EQUIP_LEVEL_RANGES) do
                if resID >= r.base and resID < r.base + 1000000 then return r end
            end
            return nil
        end

        local function detectLevelFromPattern(resID)
            resID = tonumber(resID)
            if not resID then return nil, nil end
            local r = findEquipLevelRange(resID)
            if not r then return nil, nil end
            if resID < r.base + 1000 or resID >= r.base + 4000 then return nil, nil end
            local tail = resID - r.base
            local levelDigit = math.floor(tail / 1000)
            if levelDigit >= 1 and levelDigit <= 3 then
                return levelDigit, r.base + (tail - levelDigit * 1000)
            end
            return nil, nil
        end

        local function buildPatternLevelSet(catalog)
            catalog = tonumber(catalog)
            if not catalog then return nil end
            local r = findEquipLevelRange(catalog)
            if not r then return nil end
            local tail = catalog - r.base
            if tail < 0 or tail >= 1000 then return nil end
            return {
                catalog = catalog,
                lv1 = catalog + 1000,
                lv2 = catalog + 2000,
                lv3 = catalog + 3000,
                slot = r.slot,
            }
        end

        local function getEquipLevelSet(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local set = _equipLevelByRes[resID]
            if set then return set end
            local level, catalog = detectLevelFromPattern(resID)
            if catalog then
                if EQUIP_LEVEL_SETS[catalog] then return EQUIP_LEVEL_SETS[catalog] end
                if level then return buildPatternLevelSet(catalog) end
            end
            -- @IG_Serioton
            local direct = buildPatternLevelSet(resID)
            if direct then
                _equipLevelByRes[resID] = direct
                if direct.lv1 > 0 then _equipLevelByRes[direct.lv1] = direct end
                if direct.lv2 > 0 then _equipLevelByRes[direct.lv2] = direct end
                if direct.lv3 > 0 then _equipLevelByRes[direct.lv3] = direct end
            end
            return direct
        end

        local function normalizeEquipCatalogRes(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return 0 end
            local set = getEquipLevelSet(resID)
            if set then return set.catalog end
            return resID
        end

        local function detectLevelFromEquipRes(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local set = getEquipLevelSet(resID)
            if set then
                if resID == set.lv1 then return 1
                elseif resID == set.lv2 then return 2
                elseif resID == set.lv3 then return 3 end
            end
            local level = detectLevelFromPattern(resID)
            return level
        end

        local function mapEquipLevelSet(set, level)
            if not set then return 0 end
            level = tonumber(level) or 3
            if level == 1 then return set.lv1 or 0
            elseif level == 2 then return set.lv2 or 0 end
            return set.lv3 or 0
        end

        local function mapEquipSkinRes(resID, level)
            resID, level = tonumber(resID), tonumber(level) or 3
            if not resID or resID <= 0 then return 0 end
            local catalogRes = normalizeEquipCatalogRes(resID)
            local set = getEquipLevelSet(catalogRes)
            if set then
                local mapped = mapEquipLevelSet(set, level)
                if mapped > 0 then return mapped end
            end
            local mapped = 0
            pcall(function()
                local itemMappingCfg = CDataTable.GetTableData("BackpackMapping", catalogRes)
                if itemMappingCfg then
                    if level == 1 then mapped = tonumber(itemMappingCfg.SkinItemIDLv1) or 0
                    elseif level == 2 then mapped = tonumber(itemMappingCfg.SkinItemIDLv2) or 0
                    else mapped = tonumber(itemMappingCfg.SkinItemIDLv3) or 0 end
                end
                if mapped <= 0 and DataMgr and DataMgr.GetEquipmentItemIDByResID then
                    mapped = tonumber(DataMgr.GetEquipmentItemIDByResID(level, catalogRes)) or 0
                end
            end)
            if mapped > 0 then return mapped end
            if isInjectedRes(catalogRes) then return catalogRes end
            return 0
        end

        local function buildEquipSkinLists(resID)
            resID = normalizeEquipCatalogRes(resID)
            return {
                mapEquipSkinRes(resID, 1),
                mapEquipSkinRes(resID, 2),
                mapEquipSkinRes(resID, 3),
            }
        end

        local function ensureMatchEquipCache()
            local cch = cache()
            local eq = MATCH_CONFIG.equip or {}
            if (not cch.equip.bag or cch.equip.bag <= 0) and eq.bag and eq.bag > 0 then
                cch.equip.bag = eq.bag
            end
            if (not cch.equip.helmet or cch.equip.helmet <= 0) and eq.helmet and eq.helmet > 0 then
                cch.equip.helmet = eq.helmet
            end
            if (not cch.equip.armor or cch.equip.armor <= 0) and eq.armor and eq.armor > 0 then
                cch.equip.armor = eq.armor
            end
            if (not cch.equip.parachute or cch.equip.parachute <= 0) and eq.parachute and eq.parachute > 0 then
                cch.equip.parachute = eq.parachute
            end
            if (not cch.equip.glider or cch.equip.glider <= 0) and eq.glider and eq.glider > 0 then
                cch.equip.glider = eq.glider
            end
        end

        local function syncMatchConfigFromCache()
            local cch = cache()
            if cch.outfitRes and cch.outfitRes > 0 then
                MATCH_CONFIG.outfitRes = cch.outfitRes
            else
                MATCH_CONFIG.outfitRes = 0
            end
            MATCH_CONFIG.weaponSkins = MATCH_CONFIG.weaponSkins or {}
            for wid, w in pairs(cch.weapons or {}) do
                if w.resID and w.resID > 0 then
                    MATCH_CONFIG.weaponSkins[wid] = w.resID
                end
            end
            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
            for _, slot in ipairs({ "bag", "helmet", "armor", "parachute", "glider" }) do
                if cch.equip[slot] and cch.equip[slot] > 0 then
                    MATCH_CONFIG.equip[slot] = cch.equip[slot]
                end
            end
        end

        local function restorePersistedVehicles()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if _G._savedVehicleSlotList and DataMgr then
                    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                    for subType, insList in pairs(_G._savedVehicleSlotList) do
                        if insList and #insList > 0 then
                            DataMgr.VehicleSlotList[subType] = insList
                        end
                    end
                end
            end)
            pcall(function()
                if _G._savedGarageVehicles then
                    local GTS = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                    if GTS then
                        GTS.GarageVehicleInfo = GTS.GarageVehicleInfo or {}
                        for slot, info in pairs(_G._savedGarageVehicles) do
                            if info and info.inst_id then
                                GTS.GarageVehicleInfo[slot] = info
                            end
                        end
                    end
                end
            end)
        end

        local function restorePersistedMotions()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not _G._savedMotionList or #_G._savedMotionList == 0 then return end
                if not DataMgr then return end
                DataMgr.MotionSlotList = {}
                for i, ins in ipairs(_G._savedMotionList) do
                    DataMgr.MotionSlotList[i] = ins
                end
                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                end
            end)
        end

        local function restorePersistedEquipIns()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not DataMgr then return end
                if _G._savedEquipIns then
                    DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
                    for subType, ins in pairs(_G._savedEquipIns) do
                        if ins and ins > 0 then
                            DataMgr.equipmentSkinInsIDTable[subType] = ins
                        end
                    end
                end
                if _G._savedVstSkin and _G._savedVstSkin > 0 then
                    DataMgr.vst_skin = _G._savedVstSkin
                end
            end)
        end

        local function restorePersistedThrowObjects()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not _G._savedThrowObjects then return end
                local cch = cache()
                cch.throwObjects = cch.throwObjects or {}
                for st, info in pairs(_G._savedThrowObjects) do
                    if info.resID and info.resID > 0 then
                        cch.throwObjects[st] = info
                    end
                end
            end)
        end

        local GAME_HELMET_LEVEL = {
            [502001] = 1, [502004] = 1,
            [502002] = 2, [502005] = 2,
            [502003] = 3,
        }
        local GAME_BAG_LEVEL = {
            [501001] = 1, [501004] = 1,
            [501002] = 2, [501005] = 2,
            [501003] = 3,
        }

        local function detectEquipLevelFromBaseId(baseId, catalogResID)
            baseId, catalogResID = tonumber(baseId), tonumber(catalogResID)
            if not baseId or baseId <= 0 then return nil end
            local level
            pcall(function()
                catalogResID = catalogResID and normalizeEquipCatalogRes(catalogResID) or catalogResID
                if catalogResID then
                    local set = getEquipLevelSet(catalogResID)
                    if set then
                        if baseId == set.lv1 then level = 1
                        elseif baseId == set.lv2 then level = 2
                        elseif baseId == set.lv3 then level = 3 end
                    end
                    if not level then
                        local m = CDataTable.GetTableData("BackpackMapping", catalogResID)
                        if m then
                            if tonumber(m.SkinItemIDLv1) == baseId then level = 1
                            elseif tonumber(m.SkinItemIDLv2) == baseId then level = 2
                            elseif tonumber(m.SkinItemIDLv3) == baseId then level = 3 end
                        end
                    end
                end
                if not level then
                    local patLevel, patCatalog = detectLevelFromPattern(baseId)
                    if patLevel and (not catalogResID or patCatalog == catalogResID) then
                        level = patLevel
                    end
                end
                if not level then level = GAME_HELMET_LEVEL[baseId] or GAME_BAG_LEVEL[baseId] end
                if not level and baseId >= 1505000001 and baseId <= 1505000003 then
                    level = baseId - 1505000000
                end
                if not level then
                    pcall(function()
                        local BU = require("GameLua.Mod.BaseMod.GamePlay.Backpack.BackpackUtils")
                        if BU.GetEquipmentHelmetLevel then
                            local hl = BU.GetEquipmentHelmetLevel(baseId)
                            if hl and hl >= 1 and hl <= 3 then level = hl end
                        end
                        if not level and BU.GetEquipmentBagLevel then
                            local bl = BU.GetEquipmentBagLevel(baseId)
                            if bl and bl >= 1 and bl <= 3 then level = bl end
                        end
                    end)
                end
            end)
            return level
        end

        local function isBaseEquipItemId(itemId)
            itemId = tonumber(itemId)
            if not itemId or itemId <= 0 then return false end
            if GAME_HELMET_LEVEL[itemId] or GAME_BAG_LEVEL[itemId] then return true end
            if itemId >= 1505000001 and itemId <= 1505000100 then return true end
            if itemId >= 1501000000 and itemId < 1502000000 then return true end
            if itemId >= 502001 and itemId <= 502999 then return true end
            if itemId >= 501001 and itemId <= 501999 then return true end
            return false
        end

        local function resolveMatchEquipSkin(catalogResID, baseItemID)
            catalogResID = normalizeEquipCatalogRes(catalogResID)
            if not catalogResID or catalogResID <= 0 then return 0 end
            local level = detectEquipLevelFromBaseId(baseItemID, catalogResID) or 3
            return mapEquipSkinRes(catalogResID, level)
        end

        local function getEquipDisplayLevel(resID, slot)
            local wornLevel = detectLevelFromEquipRes(resID)
            if wornLevel then return wornLevel end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if slot == "bag" then wornLevel = fbd:GetBagLevel() or 3
                elseif slot == "helmet" then wornLevel = fbd:GetHelmetLevel() or 3 end
            end)
            return wornLevel or 3
        end

        local function syncEquipLevelFromRes(resID, slot)
            local level = detectLevelFromEquipRes(resID)
            if not level then return end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if slot == "helmet" then
                    fbd:SetHelmetLevel(level)
                elseif slot == "bag" then
                    fbd:SetBagLevel(level)
                end
            end)
        end

        local function saveEquipSkin(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID then return end
            local slot = getEquipSkinSlot(resID)
            if not slot then return end
            local cch = cache()
            cch.equip[slot] = resID
            if insID then cch.equip[slot .. "Ins"] = insID end
            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
            MATCH_CONFIG.equip[slot] = resID
            _S.matchApplied = false
            invalidateSocialWearCache()
            log("ذاكرة معدات", slot, resID)
            pcall(_AutoSaveOutfit)
        end

        local function saveClothPiece(resID)
            resID = tonumber(resID)
            if not resID then return end
            local cch = cache()
            cch.clothes[resID] = true
            _S.matchApplied = false
            invalidateSocialWearCache()
            pcall(_AutoSaveOutfit)
        end

        local function clearClothesForKind(kind)
            local clearMap = subTypesToClearForKind(kind)
            if not clearMap then return end
            local cch = cache()
            for resID in pairs(cch.clothes) do
                local st = subType(cfg(resID))
                if st and clearMap[st] then cch.clothes[resID] = nil end
            end
            if kind == "full_suit" then
                cch.outfitRes, cch.outfitIns = nil, nil
            end
        end

        local function saveWeaponToCache(weaponID, resID, insID)
            weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
            if not weaponID or not resID or resID <= 0 then return end
            local cch = cache()
            cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
            _G.AddOutfitLastAppliedSkin = {}
            _S.matchApplied = false
            invalidateSocialWearCache()
            log("ذاكرة سكن", weaponID, "→", resID)
            pcall(_AutoSaveOutfit)
        end

        local function cacheWeaponSkinFromIns(weaponID, insID)
            weaponID, insID = tonumber(weaponID), tonumber(insID)
            if not weaponID or not insID or insID <= 0 then return end
            if isInjectedIns(insID) then
                saveWeaponToCache(weaponID, R.insToRes[insID], insID)
                return
            end
            pcall(function()
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID and tonumber(d.resID) > 0 then
                    saveWeaponToCache(weaponID, tonumber(d.resID), insID)
                end
            end)
        end

        local function saveEquip(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID or not insID then return end
            local c = cfg(resID)
            local st = subType(c)
            local kind = getClothKind(resID)
            local cch = cache()
            if kind == "full_suit" then
                clearClothesForKind("full_suit")
                cch.outfitRes, cch.outfitIns = resID, insID
                _G.AddOutfitLastLobbyOutfitRes = resID
                invalidateSocialWearCache()
            elseif kind then
                if cch.outfitRes and isFullSuitRes(cch.outfitRes) then
                    cch.outfitRes, cch.outfitIns = nil, nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                end
                clearClothesForKind(kind)
                saveClothPiece(resID)
            elseif getEquipSkinSlot(resID) then
                saveEquipSkin(resID, insID)
            elseif _K.GUN_SUB[st] then
                local wid = weaponIdFromSkin(resID)
                if not wid then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        wid = wgl.GetCurGunID and wgl:GetCurGunID() or nil
                        if not wid and wgl.GetCurrentGunID then
                            wid = wgl:GetCurrentGunID()
                        end
                    end)
                end
                if wid then saveWeaponToCache(wid, resID, insID) end
            elseif st == _K.MELEE_ID then
                saveWeaponToCache(_K.MELEE_ID, resID, insID)
            elseif isThrowObjectRes(resID) then
                saveThrowObject(resID, insID)
            elseif isInjectedRes(resID) then
                local mt = wardrobeMainTab(resID)
                if mt ~= _K.WARDROBE_PAGE_VEHICLE then
                    saveClothPiece(resID)
                end
            end
            _S.matchApplied = false
            pcall(_AutoSaveOutfit)
        end

        local _lastSyncWeaponCache = 0
        local function syncWeaponCacheFromLobby()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastSyncWeaponCache) < 0.3 then return end  -- throttle: max ~3x per second
            _lastSyncWeaponCache = now
            local cch = cache()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if bag then
                    if bag.bag_skin and tonumber(bag.bag_skin) > 0 then
                        local rid = isInjectedIns(bag.bag_skin) and R.insToRes[bag.bag_skin]
                            or (function()
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(bag.bag_skin)
                                return d and tonumber(d.resID)
                            end)()
                        if rid and isInjectedRes(rid) then cch.equip.bag = rid end
                    end
                    if bag.helmet_skin and tonumber(bag.helmet_skin) > 0 then
                        local rid = isInjectedIns(bag.helmet_skin) and R.insToRes[bag.helmet_skin]
                            or (function()
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(bag.helmet_skin)
                                return d and tonumber(d.resID)
                            end)()
                        if rid and isInjectedRes(rid) then cch.equip.helmet = rid end
                    end
                    if bag.weapon_skin_list then
                        for weaponID, entry in pairs(bag.weapon_skin_list) do
                            cacheWeaponSkinFromIns(weaponID, entry and (entry.skin_id or entry.skinId))
                        end
                    end
                end
            end)
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                if Arm.rsp_list and Arm.rsp_list.install_list then
                    for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                        cacheWeaponSkinFromIns(weaponID, entry and entry.skin_id)
                    end
                end
            end)
            pcall(function()
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    local function ridFromIns(ins)
                        ins = tonumber(ins)
                        if not ins or ins <= 0 then return nil end
                        if isInjectedIns(ins) then return R.insToRes[ins] end
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetHallDepotItemDataByInsID(ins)
                        return d and tonumber(d.resID)
                    end
                    local bagRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[504])
                    if bagRid and isInjectedRes(bagRid) then cch.equip.bag = bagRid end
                    local helmRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[505])
                    if helmRid and isInjectedRes(helmRid) then cch.equip.helmet = helmRid end
                    local armorRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[506])
                    if armorRid and isInjectedRes(armorRid) then cch.equip.armor = armorRid end
                end
            end)
        end

        local _lastSyncClothesCache = 0
        local function syncClothesCacheFromLobby()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastSyncClothesCache) < 0.3 then return end  -- throttle: max ~3x per second
            _lastSyncClothesCache = now
            local cch = cache()
            pcall(function()
                local inLobby = false
                if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
                    inLobby = true
                end
                
                if inLobby and not _G._addOutfitPersistLoaded then
                    cch.outfitRes = nil
                    cch.outfitIns = nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                    cch.clothes = {}
                end

                local AvatarData = require("client.logic.data.AvatarData")
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 then
                        local resID = isInjectedIns(ins) and R.insToRes[ins]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(ins)
                                return d and tonumber(d.resID)
                            end)()
                        if resID and isInjectedRes(resID) then
                            if isFullSuitRes(resID) then
                                cch.outfitRes, cch.outfitIns = resID, ins
                                _G.AddOutfitLastLobbyOutfitRes = resID
                            elseif not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
-- @IG_Serioton
                                cch.clothes[resID] = true
                            elseif getEquipSkinSlot(resID) then
                                local slot = getEquipSkinSlot(resID)
                                cch.equip[slot] = resID
                                cch.equip[slot .. "Ins"] = ins
                            end
                        end
                    end
                end

-- @IG_Serioton
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local paraInsID = tonumber(fashionbag_data:GetParachute())
                    if paraInsID and paraInsID > 0 then
                        local paraResID
                        if isInjectedIns(paraInsID) then
                            paraResID = R.insToRes[paraInsID]
                        else
                            local d = wd:GetHallDepotItemDataByInsID(paraInsID)
                            paraResID = d and tonumber(d.resID)
                        end
                        if paraResID and paraResID > 0 then
                            cch.equip.parachute = paraResID
                            cch.equip.parachuteIns = paraInsID
                            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
                            MATCH_CONFIG.equip.parachute = paraResID
                        end
                    end
                end)

-- @IG_Serioton
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local gliderInsID = tonumber(fashionbag_data:GetAircraftOrGliding())
                    if gliderInsID and gliderInsID > 0 then
                        local gliderResID
                        if isInjectedIns(gliderInsID) then
                            gliderResID = R.insToRes[gliderInsID]
                        else
                            local d = wd:GetHallDepotItemDataByInsID(gliderInsID)
                            gliderResID = d and tonumber(d.resID)
                        end
                        if gliderResID and gliderResID > 0 then
                            cch.equip.glider = gliderResID
                            cch.equip.gliderIns = gliderInsID
                            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
                            MATCH_CONFIG.equip.glider = gliderResID
                        end
                    end
                end)
            end)
        end

        local function syncClothesCacheFromLive()
            local cch = cache()
            pcall(function()
                local AvatarData = require("client.logic.data.AvatarData")
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 then
                        local resID = isInjectedIns(ins) and R.insToRes[ins]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(ins)
                                return d and tonumber(d.resID)
                            end)()
                        if resID and isInjectedRes(resID) then
                            if isFullSuitRes(resID) then
                                cch.outfitRes, cch.outfitIns = resID, ins
                                _G.AddOutfitLastLobbyOutfitRes = resID
                            elseif not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
                                cch.clothes[resID] = true
                            else
                                local slot = getEquipSkinSlot(resID)
                                if slot then
                                    cch.equip[slot] = resID
                                    cch.equip[slot .. "Ins"] = ins
                                end
                            end
                        end
                    end
                end
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local paraInsID = tonumber(fashionbag_data:GetParachute())
                    if paraInsID and paraInsID > 0 then
                        local paraResID = isInjectedIns(paraInsID) and R.insToRes[paraInsID]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(paraInsID)
                                return d and tonumber(d.resID)
                            end)()
                        if paraResID and paraResID > 0 then
                            cch.equip.parachute = paraResID
                            cch.equip.parachuteIns = paraInsID
                        end
                    end
                    local gliderInsID = tonumber(fashionbag_data:GetAircraftOrGliding())
                    if gliderInsID and gliderInsID > 0 then
                        local gliderResID = isInjectedIns(gliderInsID) and R.insToRes[gliderInsID]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(gliderInsID)
                                return d and tonumber(d.resID)
                            end)()
                        if gliderResID and gliderResID > 0 then
                            cch.equip.glider = gliderResID
                            cch.equip.gliderIns = gliderInsID
                        end
                    end
                end)
            end)
        end

        local function syncThrowObjectCacheFromLobby()
            local cch = cache()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if not bag or not bag.throw_object_list then return end
                cch.throwObjects = cch.throwObjects or {}
                for subType, insID in pairs(bag.throw_object_list) do
                    insID = tonumber(insID)
                    subType = tonumber(subType)
                    if insID and insID > 0 and subType and _K.THROW_SUB[subType] then
                        local resID
                        if isInjectedIns(insID) then
                            resID = R.insToRes[insID]
                        else
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            resID = d and tonumber(d.resID)
                        end
                        if resID and isInjectedRes(resID) then
                            cch.throwObjects[subType] = { resID = resID, insID = insID }
                        end
                    end
                end
            end)
        end

        local function syncAllCacheFromLive()
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLive()
            syncThrowObjectCacheFromLobby()
            ensureMatchEquipCache()
            syncMatchConfigFromCache()
        end
        _G.AddOutfitSyncCacheBeforeSave = syncAllCacheFromLive

        local function snapshotLobbyWear()
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLobby()
            syncThrowObjectCacheFromLobby()
            ensureMatchEquipCache()
        end

        local function getCachedWeaponSkin(weaponID)
            weaponID = tonumber(weaponID) or 0
            if weaponID <= 0 then return nil end
            syncWeaponCacheFromLobby()
            local w = cache().weapons[weaponID]
            if w and w.resID and w.resID > 0 then return w.resID end
            return nil
        end

        local function getMatchWeaponSkin(weaponID)
            weaponID = tonumber(weaponID) or 0
            local fromCache = getCachedWeaponSkin(weaponID)
            if fromCache then return fromCache end
            if MATCH_CONFIG.weaponSkins then
                local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
                if fixed and fixed > 0 then return fixed end
            end
            return nil
        end

        local _ticker
        pcall(function() _ticker = require("common.time_ticker") end)
        local function later(sec, fn)
            if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
            if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
        end

        local function getEntity()
            local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
            if not ok or not dc then return nil end
            local ok2, e = pcall(dc.GetWardrobeData, EWardrobeDataSource and EWardrobeDataSource.Wardrobe or nil)
            if ok2 and e then return e end
            ok2, e = pcall(dc.GetWardrobeData)
            return ok2 and e or nil
        end

        local function alreadyHave(entity, resID)
            local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
            if not arr then return false end
            for _, idx in pairs(arr) do
                local d = entity._data[idx]
                if d and d.count and d.count > 0 then return true end
            end
            return false
        end

        local function ensureDepotTabFields(entity, data, resID)
            if not data then return end
            pcall(function()
                if entity and entity.LoadConfigForData and CDataTable.GetTableData then
                    entity:LoadConfigForData(data, CDataTable.GetTableData)
                end
            end)
            local equipSlot = getEquipSkinSlot(resID)
            if equipSlot == "bag" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_BAG
            elseif equipSlot == "helmet" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_HELMET
            elseif equipSlot == "armor" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_ARMOR
            end
            local c = cfg(resID)
            if c then data.itemSubType = tonumber(c.ItemSubType or c.itemSubType) or data.itemSubType end
            if c then
                local wmTab = tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                if wmTab == _K.WARDROBE_PAGE_VEHICLE then
                    data.mainTabType = _K.WARDROBE_PAGE_VEHICLE
                    data.subTabType = tonumber(c.WardrobeTab or c.wardrobeTab) or data.subTabType
                end
            end
        end

        local function depotResID(v)
            return v and tonumber(v.resID or v.res_id) or nil
        end

        local function injectedEquipAllowed(resID, mainTab, subTab)
            local slot = getEquipSkinSlot(resID)
            if slot == "bag" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_BAG
            end
            if slot == "helmet" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_HELMET
            end
            if slot == "armor" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_ARMOR
            end
            if slot == "parachute" then
                return mainTab == _K.WARDROBE_PAGE_PARACHUTE and subTab == _K.WARDROBE_TAB_PARACHUTE
            end
            if slot == "glider" then
                return mainTab == _K.WARDROBE_PAGE_PARACHUTE and subTab == _K.WARDROBE_TAB_GLIDER
            end
            return nil
        end

        local function injectOne(entity, resID, insID)
            if alreadyHave(entity, resID) then
                R.resToIns[resID] = R.resToIns[resID] or insID
                R.insToRes[insID] = resID
                pcall(function()
                    local data = entity.GetDataByInsID and entity:GetDataByInsID(R.resToIns[resID])
                    if data then ensureDepotTabFields(entity, data, resID) end
                end)
                return true
            end
            entity:AddData({
                instid = insID, res_id = resID, count = 1,
                lock_cnt = 0, isnew = 0, valid_hours = 0, expire_ts = 0,
            })
            pcall(function()
                local data = entity.GetDataByInsID and entity:GetDataByInsID(insID)
                if data then
                    ensureDepotTabFields(entity, data, resID)
                end
            end)
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
-- @IG_Serioton
            return true
        end

        local function injectArmory(resID, insID)
            local wid = weaponIdFromSkin(resID)
            if not wid then return end
            local Arm = require("client.logic.armory.logic_armory")
            Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
            Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
            if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
            Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
            Arm.WardrobeInsList = Arm.WardrobeInsList or {}
            Arm.WardrobeInsList[resID] = insID
        end

-- @IG_Serioton
        local function injectAll(entity)
            if _S.injectedDone then return true end
            refreshItems()
            entity = entity or getEntity()
            if not entity or not entity.bInit then return false end

            if next(_C.fullSuit) == nil then
                pcall(function()
                    for _, rid in ipairs(ITEMS) do
                        local c = cfg(rid)
                        if c then
                            local st = tonumber(c.ItemSubType or c.itemSubType) or 0
                            if st == _K.ST_TOP then
                                local tab = tonumber(c.WardrobeTab or c.wardrobeTab) or 0
                                if tab == _K.WARDROBE_TAB_SUIT then
                                    _C.fullSuit[rid] = true
                                else
                                    pcall(function()
                                        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                                        if LogicXSuit.IsXSuit(rid) then _C.fullSuit[rid] = true end
                                    end)
                                end
                            end
                            local wmTab = tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                            if wmTab == _K.WARDROBE_PAGE_VEHICLE then
                                _C.vehicleItems[#_C.vehicleItems + 1] = rid
                            end
                        end
                        getEquipSkinSlot(rid)
                        weaponIdFromSkin(rid)
                    end
                    for _, rid in ipairs(ITEMS) do
                        getInjectedItemTab(rid)
                    end
                    local allTabs = {
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SUIT},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_CLOTHES},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_TROUSERS},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SHOES},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_BAG},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_HELMET},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_ARMOR},
                        {_K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_TAB_GUN},
                        {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE},
                        {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_GLIDER},
                        {_K.WARDROBE_PAGE_VEHICLE, 0},
                    }
                    -- pageMatch is now computed lazily in IsValidCurrentPageItem
                    for k in pairs(_C.pageMatch) do _C.pageMatch[k] = nil end
                end)
            end

            local n = 0
            for i, resID in ipairs(ITEMS) do
                local insID = _K.INS_BASE + i
                if injectOne(entity, resID, insID) then
                    n = n + 1
                    local c = cfg(resID)
                    if _K.GUN_SUB[subType(c)] or subType(c) == _K.MELEE_ID then
                        injectArmory(resID, insID)
                    end
                end
            end
            if n > 0 then
                _S.injectedDone = true
                _G.AddOutfit_R = R
                log("حقن", n, "items")
            end
            return n > 0
        end

        local function injectAllSources()
            return injectAll(getEntity())
        end

        local function refreshWardrobe()
            pcall(function()
                if EventSystem and EVENTTYPE_WARDROBE then
                    if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
                    end
                    if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
                    end
                    if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
                    end
                end
            end)
        end

        local function findWornInsBySubType(st)
            st = tonumber(st)
            if not st then return nil end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local AvatarData = require("client.logic.data.AvatarData")
            for _, ins in pairs(AvatarData.GetRoleWear()) do
                ins = tonumber(ins)
                if ins and ins > 0 then
                    local d = wd:GetHallDepotItemDataByInsID(ins)
                    if d and tonumber(d.itemSubType) == st then
                        return ins, d.resID
                    end
                end
            end
            return nil
        end

        local function removeRoleWearBySubTypes(stMap)
            if not stMap then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local AvatarData = require("client.logic.data.AvatarData")
            for _, ins in pairs(AvatarData.GetRoleWear()) do
                ins = tonumber(ins)
                if ins and ins > 0 then
                    local d = wd:GetHallDepotItemDataByInsID(ins)
                    if d and stMap[tonumber(d.itemSubType)] then
                        AvatarData.RemoveRoleWearDataByValue(ins)
                    end
                end
            end
        end

        local function clearFashionBagSlots(stMap)
            if not stMap then return end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if not bag or not bag.rolewear_list then return end
                for st, _ in pairs(stMap) do
                    local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
                    if idx then bag.rolewear_list[idx] = 0 end
                end
            end)
        end

        local function syncFashionBagRolewear()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
            end)
        end

        local function ensureKnapsackExtInfo()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local idx = fbd:GetFashionBagUseIndex()
                if not fbd:GetKnapsackExtInfoByIndex(idx) then
                    fbd:SetKnapsackExtInfoByIndex(idx, {})
                end
            end)
        end

        local function getEquipSubType(resID, slot)
            local c = cfg(resID)
            if c then
                local st = tonumber(c.ItemSubType or c.itemSubType)
                if st then return st end
            end
            if slot == "bag" then return ENUM_ITEM_SUBTYPE.Backpack end
            if slot == "helmet" then return ENUM_ITEM_SUBTYPE.Helmet_NoLevel end
            return nil
        end

        local function softRemoveEquipVisual(oldResID, slot)
            oldResID = normalizeEquipCatalogRes(oldResID)
            if not oldResID or oldResID <= 0 or not slot then return end
            pcall(function()
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                for lvl = 1, 3 do
                    local displayRes = mapEquipSkinRes(oldResID, lvl)
                    if displayRes > 0 then
                        TAM.ChangeAvatarEquipment(tostring(DataMgr.roleData.uid),
                            AvatarData.CreateAvatarCustom(displayRes), false)
                    end
                end
            end)
        end

        local function applyEquipVisual(resID, insID, slot)
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                local lds = require("client.slua.logic.wardrobe.logic_display_setting")
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                syncEquipLevelFromRes(resID, slot)
                local level = getEquipDisplayLevel(resID, slot)
                local catalogRes = normalizeEquipCatalogRes(resID)
                local itemSt = getEquipSubType(catalogRes, slot)
                if itemSt then lav:AddToWearInfo(itemSt, insID, catalogRes, 0, 0) end
                lav:AvatarChange(catalogRes, true)
                local displayRes = mapEquipSkinRes(catalogRes, level)
                if displayRes > 0 then
                    TAM.ChangeAvatarEquipment(tostring(DataMgr.roleData.uid),
                        AvatarData.CreateAvatarCustom(displayRes), true)
                end
                if lds.data then
                    if slot == "bag" then lds.data.OpenBag = true end
                    if slot == "helmet" then lds.data.OpenHelmet = true end
                end
                if slot == "helmet" then
                    fbd:SetHeadShow(insID)
                    local WRH = require("client.network.Protocol.WardRobeHandler")
                    WRH.send_depot_set_head_show_req(insID)
                end
                if slot == "bag" then HT.PutOnBag(fbd:GetFashionBagUseIndex()) end
            end)
        end

        -- ========== دوال الخلع المُحسَّنة ==========
        local takeOffEquipSkinVisual, takeOffClothVisual, takeOffWeaponSkinVisual

        local function takeOffItem(insID)
            insID = tonumber(insID)
            if not insID or insID <= 0 then return false end
            local resID = R.insToRes[insID]
            if not resID then return false end

            local cch = cache()
            local kind = getClothKind(resID)
            local slot = getEquipSkinSlot(resID)
            local wid  = weaponIdFromSkin(resID)
            local handled = false

            if slot then
                local oldRes = cch.equip[slot] or resID
                takeOffEquipSkinVisual(slot, oldRes, insID)
                cch.equip[slot]          = nil
                cch.equip[slot .. "Ins"] = nil
                if MATCH_CONFIG.equip then MATCH_CONFIG.equip[slot] = 0 end
                handled = true
            elseif kind then
                takeOffClothVisual(resID, insID, kind)
                if kind == "full_suit" then
                    cch.outfitRes, cch.outfitIns = nil, nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                else
                    cch.clothes[resID] = nil
                end
                handled = true
            elseif wid then
                takeOffWeaponSkinVisual(wid, resID, insID)
                cch.weapons[wid] = nil
                _G.AddOutfitLastAppliedSkin = {}
                _S.weaponApplied = false
                _S.weaponDiagDone = false
                _S.lastAppliedWeaponID = 0
                _S.lastAppliedSkinID = 0
                buildSkinMappings()
                handled = true
            elseif isHallThemeRes(resID) then
                pcall(function()
                    local HT = require("client.logic.lobby.hall_theme_utils")
                    HT.homeThemeItemId = 0
                    HT.SetThemeInstId(0)
                    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local idx = fbd:GetFashionBagUseIndex()
                    local bag = fbd:GetCurrentFashionBag()
                    if bag and bag.avatar_show then
                        bag.avatar_show[HT.knapsack_ext_background] = nil
                    end
                end)
                handled = true
            end

            if not handled then return false end

            _S.matchApplied = false
            _S.matchOutfitDone = false
            invalidateSocialWearCache()
            pcall(_AutoSaveOutfit)
            return true
        end

        takeOffEquipSkinVisual = function(slot, resID, insID)
            if not slot then return end
            resID, insID = tonumber(resID), tonumber(insID)
            if _S.equipSkinApplying then return end
            _S.equipSkinApplying = true
            pcall(function()
                if resID and resID > 0 then softRemoveEquipVisual(resID, slot) end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local lds = require("client.slua.logic.wardrobe.logic_display_setting")
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local itemSt = resID and getEquipSubType(resID, slot)
                if itemSt and insID and insID > 0 then
                    pcall(function() lav:SetCurrentWearPreview(itemSt, nil) end)
                end
                if slot == "bag" then
                    fbd:SetBagSkin(0)
                    if lds.data then lds.data.OpenBag = false end
                    HT.PutOnBag(fbd:GetFashionBagUseIndex())
                elseif slot == "helmet" then
                    fbd:SetHelmetSkin(0)
                    if lds.data then lds.data.OpenHelmet = false end
                    fbd:SetHeadShow(0)
                elseif slot == "armor" then
                    pcall(function()
                        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                        wl:on_putdown_rsp(_K.NET_OK, { res_id = resID or 0, instid = insID or 0, count = 1 }, nil)
                    end)
                end
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    local subKey = (slot == "bag") and 504 or (slot == "helmet") and 505 or (slot == "armor") and 506
                    if subKey then DataMgr.equipmentSkinInsIDTable[subKey] = 0 end
                end
                syncFashionBagRolewear()
            end)
            _S.equipSkinApplying = false
        end

        takeOffClothVisual = function(resID, insID, kind)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID or not insID then return end
            kind = kind or getClothKind(resID)
            local clearMap = subTypesToClearForKind(kind)
            if not clearMap then return end
            pcall(function()
                removeRoleWearBySubTypes(clearMap)
                clearFashionBagSlots(clearMap)
                local WRH = require("client.network.Protocol.WardRobeHandler")
                WRH.on_depot_put_down_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, nil)
                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                local uid = tostring(DataMgr.roleData.uid)
                local itemSt = subType(cfg(resID)) or _K.ST_TOP
                if kind == "full_suit" then
                    itemSt = _K.ST_TOP
                    for st in pairs(clearMap) do
                        local oIns, oRes = findWornInsBySubType(st)
                        if oIns and oRes and oRes > 0 then
                            TAM.ChangeAvatarEquipment(uid, AvatarData.CreateAvatarCustom(oRes), false)
                        end
                    end
                end
                TAM.ChangeAvatarEquipment(uid, AvatarData.CreateAvatarCustom(resID), false)
                pcall(function() AvatarData.RemoveRoleWearDataByValue(insID) end)
                pcall(function() av:SetCurrentWearPreview(itemSt, nil) end)
                later(0.05, function()
                    pcall(function() av:ProcessTakeOff() end)
                    syncFashionBagRolewear()
                    pcall(function()
                        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                        wl:on_putdown_rsp(_K.NET_OK, { res_id = resID, instid = insID, count = 1 }, nil)
                    end)
                    if av.InitCurrentWearPreviewMap then av:InitCurrentWearPreviewMap(true) end
                end)
            end)
        end

        takeOffWeaponSkinVisual = function(weaponID, resID, insID)
            weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
            if not weaponID then return end
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                -- مسح من install_list
                if Arm.rsp_list and Arm.rsp_list.install_list then
                    Arm.rsp_list.install_list[weaponID] = nil
                end
                -- مسح من FashionBag
                if fbd.UpdateCurrentFashionBagWeaponSkin then
                    fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, 0)
                end
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if bag and bag.weapon_skin_list then
                    bag.weapon_skin_list[weaponID] = nil
                end
                -- تحديث واجهة السلاح
                local bagIdx = fbd:GetFashionBagUseIndex()
                HT.proc_skin_list_chg("weapon_skin", weaponID, 0, bagIdx, {})
                wgl:SetGunID(weaponID)
                if wgl.UpdateCurrentGunAvatar then
                    wgl:UpdateCurrentGunAvatar(weaponID, 0)
                end
                -- أحداث التحديث
                if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, 0)
                end
                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, 0)
                end
                if EventSystem and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, weaponID)
                end
                log("خلع سكن سلاح", weaponID)
            end)
        end
-- @IG_Serioton

        local function putOnThrowObject(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID then return end
            local st = isThrowObjectRes(resID)
            if not st then return end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:PutOnThrowObjectSkin(insID)
            end)
            saveThrowObject(resID, insID)
            pcall(_AutoSaveOutfit)
            log("لبس قنبلة", st, resID)
        end

        local function putOnEquipSkin(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local slot = getEquipSkinSlot(resID)
            if not slot then return end
            if _S.equipSkinApplying then return end
            _S.equipSkinApplying = true
            pcall(function()
                local cch = cache()
                local oldResID = cch.equip[slot]
                local oldInsID = cch.equip[slot .. "Ins"]
                ensureKnapsackExtInfo()
                local item = { res_id = resID, instid = insID, count = 1, color = 0, pattern = 0 }
                local oldItem = nil
                if oldInsID and oldInsID > 0 and oldResID and oldResID > 0 then
                    oldItem = { res_id = oldResID, instid = oldInsID, count = 1, color = 0, pattern = 0 }
                end
                local HT = require("client.logic.lobby.hall_theme_utils")
                if slot == "helmet" then
                    HT.ProcPutOnHelmet(item, oldItem)
                elseif slot == "bag" then
                    HT.ProcPutOnBagSkin(item, oldItem)
                elseif slot == "parachute" then
            -- @IG_Serioton
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    local origAddToWearInfo = lav.AddToWearInfo
                    lav.AddToWearInfo = function(self2, subType, ...)
                        if tonumber(subType) == 701 then return end
                        return origAddToWearInfo(self2, subType, ...)
                    end
                    pcall(function()
                        wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                    end)
                    lav.AddToWearInfo = origAddToWearInfo
                elseif slot == "glider" then
-- @IG_Serioton
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    local origAddToWearInfo = lav.AddToWearInfo
                    lav.AddToWearInfo = function(self2, subType, ...)
                        local st = tonumber(subType)
                        if st == 413 or st == 414 or st == 415 then return end
                        return origAddToWearInfo(self2, subType, ...)
                    end
                    pcall(function()
                        wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                    end)
                    lav.AddToWearInfo = origAddToWearInfo
                else
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                end
                saveEquipSkin(resID, insID)
                if oldResID and oldResID > 0 and oldResID ~= resID then
                    softRemoveEquipVisual(oldResID, slot)
                end
-- @IG_Serioton
                if slot ~= "parachute" and slot ~= "glider" then
                    applyEquipVisual(resID, insID, slot)
                end
                invalidateSocialWearCache()
                log("لبس معدات", slot, resID)
            end)
            _S.equipSkinApplying = false
        end

        local function putOnCloth(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if not d then return end

            local kind = getClothKind(resID, d)
            if not kind then return end

            local cch = cache()
            local switchingFromSuit = (kind ~= "full_suit") and cch.outfitRes and isFullSuitRes(cch.outfitRes)
            local switchingToSuit = (kind == "full_suit") and not cch.outfitRes and next(cch.clothes) ~= nil

            local clearMap
            if switchingFromSuit then
                clearMap = FULL_SUIT_CLEAR_ST
            else
                clearMap = subTypesToClearForKind(kind)
            end
            if not clearMap then return end

            local itemSt = subType(cfg(resID)) or _K.ST_TOP

            local function doPutOn()
                local oldIns, oldRes = findWornInsBySubType(itemSt)
                removeRoleWearBySubTypes(clearMap)
                clearFashionBagSlots(clearMap)
                saveEquip(resID, insID)

                local slot = _K.PKG_SLOT
                pcall(function()
                    local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
                    local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(itemSt)
                    if idx then slot = idx end
                end)

                local olditem
                if oldIns and oldIns ~= insID then
                    olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
                end

                local WRH = require("client.network.Protocol.WardRobeHandler")
                local item = { res_id = resID, count = 1, instid = insID }
                WRH.on_depot_put_on_rsp(_K.NET_OK, item, olditem, slot, insID, oldIns or 0)

                pcall(function()
                    local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    av:AddToWearInfo(itemSt, insID, resID, 0, 0)
                    local displayResID = resID
                    local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                    if LogicXSuit.IsXSuit(displayResID) then
                        displayResID = LogicXSuit.GetItemShowID(insID) or displayResID
                    end
                    av:AvatarChange(displayResID, true, 0, 0)
                    later(0.05, function()
                        pcall(function() av:ProcessTakeOff() end)
                        syncFashionBagRolewear()
                    end)
                end)
                log("لبس", kind, resID)
            end

            if switchingFromSuit then
                local suitRes = cch.outfitRes
                local suitIns = cch.outfitIns
                cch.outfitRes, cch.outfitIns = nil, nil
                _G.AddOutfitLastLobbyOutfitRes = nil
                if suitRes and suitIns then
                    pcall(function() takeOffClothVisual(suitRes, suitIns, "full_suit") end)
                    later(0.15, doPutOn)
                else
                    doPutOn()
                end
            elseif switchingToSuit then
                local toTakeOff = {}
                for clothRes in pairs(cch.clothes) do
                    local clothIns = R.resToIns[clothRes]
                    local clothKind = getClothKind(clothRes)
                    if clothIns and clothKind then
                        toTakeOff[#toTakeOff + 1] = { resID = clothRes, insID = clothIns, kind = clothKind }
                    end
                end
                for _, c in ipairs(toTakeOff) do
                    cch.clothes[c.resID] = nil
                    pcall(function() takeOffClothVisual(c.resID, c.insID, c.kind) end)
                end
                later(0.15, doPutOn)
            else
                doPutOn()
            end
        end

        local function equipWeaponSkin(weaponID, insID)
            weaponID, insID = tonumber(weaponID), tonumber(insID)
            if not weaponID or not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            saveEquip(resID, insID)

            local Arm = require("client.logic.armory.logic_armory")
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local HT = require("client.logic.lobby.hall_theme_utils")
            local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

            injectArmory(resID, insID)
            Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
            Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
            if fbd.UpdateCurrentFashionBagWeaponSkin then
                fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
            end

            local bagIdx = fbd:GetFashionBagUseIndex()
            HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

            wgl:SetGunID(weaponID)
            wgl:UpdateCurrentGunAvatar(weaponID, insID)

            if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
            end
            if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
            end
            log("weapon skin", weaponID, resID, insID)
        end

        local function putOnHallTheme(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID or not isHallThemeRes(resID) then return end
            local item = { res_id = resID, count = 1, instid = insID }
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                wl:on_puton_rsp(_K.NET_OK, item, nil, 1, insID, 0)
            end)
            pcall(_AutoSaveOutfit)
            log("ثيم لوبي", resID, insID)
        end

        local function restorePersistedHallTheme()
            if not _G._addOutfitPersistLoaded then return end
            local ins = tonumber(_G._savedHallThemeIns)
            if not ins or ins <= 0 then return end
            later(2.5, function()
                if isInjectedIns(ins) then putOnHallTheme(ins) end
            end)
        end

-- @IG_Serioton
        local SOCIAL = _G.AddOutfitSocialState or {}
        _G.AddOutfitSocialState = SOCIAL
        SOCIAL.debGen = SOCIAL.debGen or 0

        local function socialDebounce(sec, fn)
            SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
            local gen = SOCIAL.debGen
            later(sec, function()
                if gen ~= SOCIAL.debGen then return end
                pcall(fn)
            end)
        end

        local function getLobbyCurPage()
            local p = nil
            pcall(function()
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC.GetCurPage then p = LMC.GetCurPage() end
            end)
            return p
        end

        local function getWeaponSkinResFast()
            local cch = cache()
            local wid = tonumber(DataMgr.Weapon_ID) or 0
            local w = wid > 0 and cch.weapons[wid] or nil
            if w and w.resID and w.resID > 0 then return w.resID end
            for _, ww in pairs(cch.weapons) do
                if ww.resID and ww.resID > 0 then return ww.resID end
            end
            return nil
        end

        local function resolveLobbyWeaponSkinRes()
            local wid = tonumber(DataMgr.Weapon_ID) or 0
            local skin = getWeaponSkinResFast()
            if skin and skin > 0 then return skin end
            if wid > 0 then
                local fromMatch = getMatchWeaponSkin(wid)
                if fromMatch and fromMatch > 0 then return fromMatch end
            end
            return nil
        end

        local function rememberLobbyOutfitRes(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 or not isFullSuitRes(resID) then return end
            _G.AddOutfitLastLobbyOutfitRes = resID
            local cch = cache()
            if not cch.outfitRes or cch.outfitRes <= 0 then
                cch.outfitRes = resID
                if isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
            end
        end

        local function resolveLobbyOutfitRes()
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then return cch.outfitRes end
            if tonumber(_G.AddOutfitLastLobbyOutfitRes) and _G.AddOutfitLastLobbyOutfitRes > 0 then
                return tonumber(_G.AddOutfitLastLobbyOutfitRes)
            end
            if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
                return tonumber(MATCH_CONFIG.outfitRes)
            end
            for resID in pairs(cch.clothes) do
                if isFullSuitRes(resID) then return resID end
            end
            return nil
        end

        local function collectAllClothResIDs()
            local ids = {}
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then
                ids[cch.outfitRes] = true
            end
            for resID in pairs(cch.clothes) do
                if not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
                    ids[resID] = true
                end
            end
            return ids
        end

        local function wearPatchKey()
            local outfit = resolveLobbyOutfitRes() or 0
            local skin = resolveLobbyWeaponSkinRes() or 0
            local cch = cache()
            local eq = (cch.equip.bag or 0) .. "_" .. (cch.equip.helmet or 0)
            return outfit .. "_" .. skin .. "_" .. eq
        end

        local function applyInjectedPspace(roleData)
            if not roleData then return end
            roleData.bshow = true
            roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
            local outfitRes = resolveLobbyOutfitRes()
            if outfitRes and outfitRes > 0 then
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
            end
            local skinRes = resolveLobbyWeaponSkinRes()
            if skinRes and skinRes > 0 then
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
                roleData.depot_show_info = roleData.depot_show_info or {}
                if roleData.depot_show_info.weapon == nil then roleData.depot_show_info.weapon = true end
            end
        end

        local function patchSelfWearCache(force)
            local key = wearPatchKey()
            if not force and SOCIAL.wearPatchKey == key then return false end
            SOCIAL.wearPatchKey = key
            local myUid = tonumber(DataMgr.roleData.uid)
            if not myUid then return false end
            pcall(function()
                local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                local d = BD:GetCacheData(myUid)
                if d then applyInjectedPspace(d) end
            end)
            return true
        end

        local function requestSocialAvatarRefresh()
            pcall(function()
                if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
                    EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
                end
            end)
        end

        local function onSocialWearDirty(forceRefresh)
            SOCIAL.lastHandSkin = nil
            if patchSelfWearCache(forceRefresh) then requestSocialAvatarRefresh() end
        end

        local _myUidCached
        local function isMyWearData(wearData)
            if not wearData then return false end
            if not _myUidCached then
                pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
            end
            return _myUidCached and tonumber(wearData.uid) == _myUidCached
        end

        local function mergeInjectedWeaponIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local cch = cache()
            local wKey = ""
            for wid, w in pairs(cch.weapons) do wKey = wKey .. wid .. ":" .. (w.resID or 0) .. "," end
            wKey = wKey .. "|" .. tostring(DataMgr.Weapon_ID or 0)
            local skinRes
            if _weaponSkinResMergeCache.key == wKey then
                skinRes = _weaponSkinResMergeCache.res
            else
                skinRes = resolveLobbyWeaponSkinRes()
                _weaponSkinResMergeCache.key = wKey
                _weaponSkinResMergeCache.res = skinRes
            end
            if not skinRes or skinRes <= 0 then return end
            wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
                weaponResId = 0, weaponSkinId = 0,
                diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
            }
            wearData.mainWeaponInfo.weaponSkinId = skinRes
            wearData.mainWeaponInfo.weaponResId = 0
        end

        local function getOutfitMergeItems()
            local cch = cache()
            local clothKey = ""
            for resID in pairs(cch.clothes) do clothKey = clothKey .. resID .. "," end
            local key = (cch.outfitRes or 0) .. "_" .. clothKey .. "_" .. (cch.equip.bag or 0) .. "_" .. (cch.equip.helmet or 0)
            if _outfitMergeCache.key == key and _outfitMergeCache.items then
                return _outfitMergeCache.items
            end
            local outfitRes = resolveLobbyOutfitRes()
            local AvatarData = require("client.logic.data.AvatarData")
            local items = {}
            if outfitRes and outfitRes > 0 and isFullSuitRes(outfitRes) then
                rememberLobbyOutfitRes(outfitRes)
                local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
                if converted then items[#items + 1] = converted end
                for resID in pairs(collectAllClothResIDs()) do
                    if resID ~= outfitRes and not isFullSuitRes(resID)
                        and not isBodyClothSubType(subType(cfg(resID))) then
                        local cv = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
                        if cv then items[#items + 1] = cv end
                    end
                end
            else
                for resID in pairs(collectAllClothResIDs()) do
                    if not isFullSuitRes(resID) then
                        local converted = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
                        if converted then items[#items + 1] = converted end
                    end
                end
            end
            _outfitMergeCache.key = key
            _outfitMergeCache.items = items
            return items
        end

        local function mergeInjectedOutfitIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local outfitRes = resolveLobbyOutfitRes()
            local items = getOutfitMergeItems()
            if #items == 0 then return end
            if outfitRes and outfitRes > 0 and isFullSuitRes(outfitRes) then
                local newList = {}
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if not (e and e.ItemID and isBodyClothSubType(subType(cfg(e.ItemID)))) then
                        newList[#newList + 1] = e
                    end
                end
                for _, item in ipairs(items) do
                    newList[#newList + 1] = item
                end
                wearData.WearInfoList = newList
            else
                wearData.WearInfoList = wearData.WearInfoList or {}
                for _, item in ipairs(items) do
                    wearData.WearInfoList[#wearData.WearInfoList + 1] = item
                end
            end
        end

        local function mergeInjectedEquipIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local cch = cache()
            wearData.depot_show_info = wearData.depot_show_info or {}
            if cch.equip.bag and cch.equip.bag > 0 then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLevel = getEquipDisplayLevel(cch.equip.bag, "bag")
                wearData.depot_show_info.bag = true
                wearData.bagSkinInsId = mapEquipSkinRes(catalogBag, bagLevel)
                wearData.skin_info = wearData.skin_info or {}
                wearData.skin_info.bag_skin = cch.equip.bagIns or R.resToIns[cch.equip.bag] or cch.equip.bag
                wearData.skin_info.bag_level = bagLevel
            end
            if cch.equip.helmet and cch.equip.helmet > 0 then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLevel = getEquipDisplayLevel(cch.equip.helmet, "helmet")
                local helmDisplay = mapEquipSkinRes(catalogHelm, helmLevel)
                wearData.depot_show_info.helmet = true
                wearData.helmet_skin = helmDisplay
                wearData.headShow = helmDisplay
                wearData.skin_info = wearData.skin_info or {}
                wearData.skin_info.helmet_skin = cch.equip.helmetIns or R.resToIns[cch.equip.helmet] or cch.equip.helmet
                wearData.skin_info.head_show = wearData.skin_info.helmet_skin
                wearData.skin_info.helmet_level = helmLevel
            end
        end

        local function mergeInjectedIntoWearData(wearData)
            if not wearData then return end
            mergeInjectedWeaponIntoWearData(wearData)
            mergeInjectedOutfitIntoWearData(wearData)
            mergeInjectedEquipIntoWearData(wearData)
        end

-- @IG_Serioton
        local function reapplyAccessoryIns(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local c = cfg(resID)
            local st = subType(c)
            saveClothPiece(resID)
            local itemSt = st
            local oldIns, oldRes
            if itemSt then
                oldIns, oldRes = findWornInsBySubType(itemSt)
                if oldIns == insID then oldIns, oldRes = nil, nil end
                removeRoleWearBySubTypes({ [itemSt] = true })
            end
            local WRH = require("client.network.Protocol.WardRobeHandler")
            local olditem
            if oldIns then
                olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
            end
            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, 1, insID, oldIns or 0)
            pcall(function()
                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                if oldIns and itemSt then av:SetCurrentWearPreview(itemSt, nil) end
                if itemSt then av:AddToWearInfo(itemSt, insID, resID, 0, 0) end
                av:AvatarChange(resID, true, 0, 0)
                av:ProcessTakeOff()
                syncFashionBagRolewear()
            end)
        end

        local function reapplyInjectedIns(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID then return end
            if isHallThemeRes(resID) then
                putOnHallTheme(insID)
            elseif getEquipSkinSlot(resID) then
                putOnEquipSkin(insID)
            elseif getClothKind(resID) then
                putOnCloth(insID)
            elseif weaponIdFromSkin(resID) then
                equipWeaponSkin(weaponIdFromSkin(resID), insID)
            elseif _K.GUN_SUB[subType(cfg(resID))] then
                local cch = cache()
                local foundWid = nil
                for wid, w in pairs(cch.weapons or {}) do
                    if w.resID == resID then foundWid = wid; break end
                end
                if foundWid then equipWeaponSkin(foundWid, insID) end
            elseif subType(cfg(resID)) == _K.MELEE_ID then
                equipWeaponSkin(_K.MELEE_ID, insID)
            elseif isThrowObjectRes(resID) then
                putOnThrowObject(insID)
            else
                reapplyAccessoryIns(insID)
            end
        end

        local function reapplyLobbyEquipped()
            if not _skOn("ALL_SKIN") then return end
            if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
                return
            end
            if _S.lobbyApplied then return end
            _S.lobbyApplied = true
            later(2.0, function() _S.lobbyApplied = false end)

            restorePersistedVehicles()
            restorePersistedMotions()
            restorePersistedEquipIns()
            restorePersistedThrowObjects()
            restorePersistedHallTheme()
            syncMatchConfigFromCache()

            if not _G._addOutfitPersistLoaded then
                snapshotLobbyWear()
            end
            local cch = cache()
            if not _G._addOutfitPersistLoaded and _G._savedOutfitClothes then
                for resID in pairs(_G._savedOutfitClothes) do
                    cch.clothes[resID] = true
                end
            end
            if not _G._addOutfitPersistLoaded and _G._savedOutfitRes and (not cch.outfitRes or cch.outfitRes <= 0) then
                cch.outfitRes = _G._savedOutfitRes
                cch.outfitIns = _G._savedOutfitIns or R.resToIns[_G._savedOutfitRes]
            end
            syncMatchConfigFromCache()

            local applyStep = 0
            local function scheduleApply(fn)
                applyStep = applyStep + 1
                later(applyStep * 0.12, fn)
            end

            if not _G._addOutfitPersistLoaded and _G._savedRoleWearList and #_G._savedRoleWearList > 0 then
                for _, insID in ipairs(_G._savedRoleWearList) do
                    local id = insID
                    scheduleApply(function() reapplyInjectedIns(id) end)
                end
            elseif cch.outfitIns and isInjectedIns(cch.outfitIns) then
                scheduleApply(function() putOnCloth(cch.outfitIns) end)
            else
                for resID in pairs(cch.clothes) do
                    local ins = R.resToIns[resID]
                    local rid = resID
                    if ins and isInjectedIns(ins) then
                        scheduleApply(function()
                            if getClothKind(rid) then
                                putOnCloth(ins)
                            else
                                reapplyAccessoryIns(ins)
                            end
                        end)
                    end
                end
            end
            for wid, w in pairs(cch.weapons) do
                local weaponID, entry = wid, w
                scheduleApply(function()
                    if entry.insID and isInjectedIns(entry.insID) then
                        equipWeaponSkin(weaponID, entry.insID)
                    elseif entry.resID and R.resToIns[entry.resID] and isInjectedIns(R.resToIns[entry.resID]) then
                        equipWeaponSkin(weaponID, R.resToIns[entry.resID])
                    end
                end)
            end
            for _, slot in ipairs({ "bag", "helmet", "armor", "parachute", "glider" }) do
                local resID = cch.equip[slot]
                local insID = cch.equip[slot .. "Ins"]
                scheduleApply(function()
                    if insID and isInjectedIns(insID) then
                        putOnEquipSkin(insID)
                    elseif resID and R.resToIns[resID] then
                        putOnEquipSkin(R.resToIns[resID])
                    end
                end)
            end
            if cch.throwObjects then
                for st, info in pairs(cch.throwObjects) do
                    local tInfo = info
                    scheduleApply(function()
                        if tInfo.insID and isInjectedIns(tInfo.insID) then
                            putOnThrowObject(tInfo.insID)
                        elseif tInfo.resID and R.resToIns[tInfo.resID] and isInjectedIns(R.resToIns[tInfo.resID]) then
                            putOnThrowObject(R.resToIns[tInfo.resID])
                        end
                    end)
                end
            end
            later(math.max(applyStep * 0.12 + 0.3, 0.5), function()
                syncMatchConfigFromCache()
                pcall(_AutoSaveOutfit, true)
                log("-- @IG_Serioton (-- @IG_Serioton)")
            end)

            pcall(function()
                if _G._addOutfitPersistLoaded then return end
                local GTS = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GTS then return end
                local maxSlots = GTS:GetMaxPositionNum()
                GTS.GarageVehicleInfo = GTS.GarageVehicleInfo or {}
                local usedIns = {}
                for slot, info in pairs(GTS.GarageVehicleInfo) do
                    if info and info.inst_id then
                        usedIns[tonumber(info.inst_id)] = true
                    end
                end
                local changed = false
                for slot = 1, maxSlots do
                    if not GTS.GarageVehicleInfo[slot] then
                        for _, resID in ipairs(_C.vehicleItems) do
                            if isInjectedRes(resID) then
                                local insID = R.resToIns[resID]
                                if insID and not usedIns[insID] then
                                    GTS.GarageVehicleInfo[slot] = { inst_id = insID, res_id = resID }
                                    usedIns[insID] = true
                                    changed = true
                                    break
                                end
                            end
                        end
                    end
                end
                if changed then
                    if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                        EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                    end
                end
            end)
        end

        local function initHooks()
        local function hookLobbySwipePersistence()
            pcall(function()
                local AC = require("client.slua.logic.avatar.avatar_common")
                local oGetWear = AC.GetWearDataFromRoleData
                AC.GetWearDataFromRoleData = function(roleData)
                    local wearData = oGetWear(roleData)
                    if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid) then
                        mergeInjectedIntoWearData(wearData)
                    end
                    return wearData
                end
                local oUp = AC.UpdateAvatar
                AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
                    if isMyWearData(wearData) then mergeInjectedIntoWearData(wearData) end
                    return oUp(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
                end
            end)
            pcall(function()
                if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
                    EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                        if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                            socialDebounce(0.5, reapplyLobbyEquipped) ---- @IG_Serioton
                        end
                    end)
                end
            end)
        end

        -- ========== -- @IG_Serioton==========
        local function hookCDataTableCache()
            pcall(function()
                if not CDataTable or CDataTable._lava_cached then return end
                CDataTable._lava_cached = true
                local origGetTableData = CDataTable.GetTableData
                CDataTable.GetTableData = function(tableName, resID, ...)
                    if tableName == "Item" then
                        resID = tonumber(resID)
                        if resID and _C.cfg[resID] ~= nil then
                            return _C.cfg[resID]
                        end
                        local result = origGetTableData(tableName, resID, ...)
                        if resID then
                            _C.cfg[resID] = result
                        end
                        return result
                    end
                    return origGetTableData(tableName, resID, ...)
                end
            end)
        end

        local function hookDepotInit()
            pcall(function()
                local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
                local orig = WDE.InitData
                WDE.InitData = function(self, pkg)
                    orig(self, pkg)
                    injectAll(self)
                    refreshWardrobe()
                end
            end)
        end

        local function hookWardrobeData()
            pcall(function()
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local function wrapGet(name)
                    local o = wd[name]
                    if not o then return end
                    wd[name] = function(self, insID, ...)
                        insID = tonumber(insID)
                        if isInjectedIns(insID) then
                            local e = getEntity()
                            if e then return e:GetDataByInsID(insID) end
                        end
                        return o(self, insID, ...)
                    end
                end
                wrapGet("GetHallDepotItemDataByInsID")
                wrapGet("GetValidHallDepotItemDataByInsID")
                local function wrapBool(name)
                    local o = wd[name]
                    if not o then return end
                    wd[name] = function(self, id, ...)
                        if isInjectedRes(tonumber(id)) or isInjectedIns(tonumber(id)) then return true end
                        return o(self, id, ...)
                    end
                end
                wrapBool("HasItem")
                wrapBool("HasValidItem")
                wrapBool("CheckHasPermanentItem")
                if not wd._lava_global_equip then
                    wd._lava_global_equip = true
                    local origGetEquipped = wd.GetEquippedSkinIDByWeaponID
                    wd.GetEquippedSkinIDByWeaponID = function(self, weaponID)
                        local w = cache().weapons[tonumber(weaponID)]
                        if w and w.resID and w.resID > 0 then return w.resID end
                        return origGetEquipped(self, weaponID)
                    end
                end
                if not wd._lava_global_equip_ins then
                    wd._lava_global_equip_ins = true
                    if wd.GetEquippedSkinInsIDByWeaponID then
                        local origGetEquippedIns = wd.GetEquippedSkinInsIDByWeaponID
                        wd.GetEquippedSkinInsIDByWeaponID = function(self, weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then return w.insID end
                            return origGetEquippedIns(self, weaponID)
                        end
                    end
                    if wd.GetWeaponSkinInsID then
                        local origGetWSI = wd.GetWeaponSkinInsID
                        wd.GetWeaponSkinInsID = function(self, weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then return w.insID end
                            return origGetWSI(self, weaponID)
                        end
                    end
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oPutDownReq = wl.wardrobe_put_down_req
                if oPutDownReq then
                    wl.wardrobe_put_down_req = function(self, ins_id, unequip_by_server)
                        ins_id = tonumber(ins_id)
                        if isInjectedIns(ins_id) then
                            local resID = R.insToRes[ins_id]
                            takeOffItem(ins_id)
                            pcall(function()
                                self:on_putdown_rsp(_K.NET_OK, {
                                    instid = ins_id,
                                    res_id = resID or 0,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = ins_id,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                        return oPutDownReq(self, ins_id, unequip_by_server)
                    end
                end
            end)
        end

        local function hookPageFilter()
            pcall(function()
                local SubTab = require("client.slua.umg.Wardrobe.subtab_item_list_base")
                if SubTab._lava_prefilter then return end
                SubTab._lava_prefilter = true
                local origGet = SubTab.GetArrayHallDepotItemInfo
                SubTab.GetArrayHallDepotItemInfo = function(self)
                    local allData = origGet(self)
                    if not allData or not next(allData) then return allData end
                    local pageId = self.subTabConfig and self.subTabConfig.pageId
                    local subTabId = self.subTabConfig and self.subTabConfig.subTabId
                    if not pageId or not subTabId then return allData end
                    local result = {}
                    for _, data in pairs(allData) do
                        local resID = depotResID(data)
                        if resID and isInjectedRes(resID) then
                            local itemMain, itemSub = getInjectedItemTab(resID, data)
                            if itemMain == pageId then
                                if pageId == _K.WARDROBE_PAGE_AVATAR then
                                    if subTabId == _K.WARDROBE_TAB_SUIT or subTabId == _K.WARDROBE_TAB_CLOTHES then
                                        local st = data.itemSubType or subType(cfg(resID))
                                        if st == _K.ST_TOP then
                                            local full = isFullSuitRes(resID, data)
                                            if (subTabId == _K.WARDROBE_TAB_SUIT and full) or
                                            (subTabId == _K.WARDROBE_TAB_CLOTHES and not full) then
                                                result[#result + 1] = data
                                            end
                                        end
                                    elseif itemSub == subTabId then
                                        result[#result + 1] = data
                                    end
                                elseif itemSub == subTabId then
                                    result[#result + 1] = data
                                end
                            end
                        else
                            result[#result + 1] = data
                        end
                    end
                    return result
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local o1 = wl.IsValidCurrentPageItem
                wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
                    local resID = depotResID(v)
                    if resID and isInjectedRes(resID) then
                        local cacheKey = resID .. "_" .. mainTab .. "_" .. subTab
                        if _C.pageMatch[cacheKey] ~= nil then
                            return _C.pageMatch[cacheKey]
                        end
                        local result
                        if not (v.expireTS == 0 or not t or t < v.expireTS) then
                            result = false
                        else
                            local equipOk = injectedEquipAllowed(resID, mainTab, subTab)
                            if equipOk ~= nil then
                                result = equipOk
                            elseif weaponIdFromSkin(resID) then
                                result = mainTab == _K.WARDROBE_PAGE_WEAPON and subTab == _K.WARDROBE_TAB_GUN
                            elseif mainTab == _K.WARDROBE_PAGE_VEHICLE then
                                local c = cfg(resID)
                                local wmTab = c and tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                                if wmTab ~= mainTab and v.mainTabType ~= mainTab then
                                    result = false
                                else
                                    local wTab = c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
                                    local vTab = v.subTabType and tonumber(v.subTabType) or nil
                                    if wTab and wTab == subTab then result = true
                                    elseif vTab and vTab == subTab then result = true
                                    else result = o1(self, mainTab, subTab, v, t) end
                                end
                            elseif mainTab == _K.WARDROBE_PAGE_AVATAR then
                                local st = v.itemSubType or subType(cfg(resID))
                                if st == _K.ST_TOP then
                                    local full = isFullSuitRes(resID, v)
                                    if subTab == _K.WARDROBE_TAB_SUIT and full then result = true
                                    elseif subTab == _K.WARDROBE_TAB_CLOTHES and not full then result = true
                                    else result = false end
                                elseif st == _K.ST_PANTS and subTab == _K.WARDROBE_TAB_TROUSERS then
                                    result = true
                                elseif st == _K.ST_SHOES and subTab == _K.WARDROBE_TAB_SHOES then
                                    result = true
                                elseif v.subTabType == subTab then
                                    result = true
                                else
                                    result = false
                                end
                            else
                                result = o1(self, mainTab, subTab, v, t)
                            end
                        end
                        _C.pageMatch[cacheKey] = result
                        return result
                    end
                    return o1(self, mainTab, subTab, v, t)
                end
                local o2 = wl.IsCanUse
                wl.IsCanUse = function(self, resId)
                    if isInjectedRes(resId) then return true end
                    return o2(self, resId)
                end
                local o4 = wl.GetWardrobeInsIdByResId
                wl.GetWardrobeInsIdByResId = function(self, resid)
                    resid = tonumber(resid)
                    if isInjectedRes(resid) then return R.resToIns[resid] end
                    return o4(self, resid)
                end
            end)
        end

        local function hookArmory()
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                if not Arm._lava_global_own then
                    Arm._lava_global_own = true
                    local origIsOwn = Arm.IsSkinOwn
                    Arm.IsSkinOwn = function(weaponID, skinID)
                        if isInjectedRes(skinID) then return 1 end
                        return origIsOwn(weaponID, skinID)
                    end
                end
                if not Arm._lava_global_get_install then
                    Arm._lava_global_get_install = true
                    if Arm.get_install_skin then
                        local origGetInstall = Arm.get_install_skin
                        Arm.get_install_skin = function(weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return { skin_id = w.insID }
                            end
                            return origGetInstall(weaponID)
                        end
                    end
                    if Arm.GetInstallSkinInsID then
                        local origGetInstall2 = Arm.GetInstallSkinInsID
                        Arm.GetInstallSkinInsID = function(weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                            return origGetInstall2(weaponID)
                        end
                    end
                end
                local oi = Arm.install_weapon_skin
                Arm.install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if isInjectedIns(ins) then
                        wid = tonumber(weaponIdFromSkin(R.insToRes[ins]) or wid)
                        equipWeaponSkin(wid, ins)
                        return
                    end
                    return oi(cd, wid, ins)
                end
                local function hookArmoryUninstall(fnName)
                    local orig = Arm[fnName]
                    if not orig then return end
                    Arm[fnName] = function(cd, wid, ins, ...)
                        ins = tonumber(ins)
                        wid = tonumber(wid)
                        if ins and isInjectedIns(ins) then
                            local resID = R.insToRes[ins]
                            wid = weaponIdFromSkin(resID) or wid
                            if takeOffItem(ins) then
                                refreshWardrobe()
                                return
                            end
                        elseif wid and wid > 0 then
                            local cch = cache()
                            local w = cch.weapons[wid]
                            if w and w.insID and isInjectedIns(w.insID) then
                                if takeOffItem(w.insID) then
                                    refreshWardrobe()
                                    return
                                end
                            end
                        end
                        return orig(cd, wid, ins, ...)
                    end
                end
                hookArmoryUninstall("uninstall_weapon_skin")
                hookArmoryUninstall("remove_weapon_skin")
            end)
        end

        local function hookLobbyTheme()
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if wl._lava_hooked_hall_theme then return end
                wl._lava_hooked_hall_theme = true
                local origPutOn = wl.wardrobe_puton_req
                wl.wardrobe_puton_req = function(self, insID, extra)
                    insID = tonumber(insID)
                    if insID and isInjectedIns(insID) and isHallThemeRes(R.insToRes[insID]) then
                        putOnHallTheme(insID)
                        return
                    end
                    return origPutOn(self, insID, extra)
                end
            end)
        end

        local function hookPutOn()
            pcall(function()
                local WRH = require("client.network.Protocol.WardRobeHandler")
                local o = WRH.send_depot_put_on_req
                WRH.send_depot_put_on_req = function(insID, extra)
                    insID = tonumber(insID)
                    if isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        local c = cfg(resID)
                        local st = subType(c)
                        if getEquipSkinSlot(resID) then
                            putOnEquipSkin(insID)
                            return
                        end
                        if getClothKind(resID) then
                            putOnCloth(insID)
                            return
                        end
                        if _K.GUN_SUB[st] then
                            local wid = weaponIdFromSkin(resID)
                            if not wid then
                                pcall(function()
                                    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                    wid = wgl.GetCurGunID and wgl:GetCurGunID() or nil
                                    if not wid and wgl.GetCurrentGunID then
                                        wid = wgl:GetCurrentGunID()
                                    end
                                end)
                            end
                            if wid then equipWeaponSkin(wid, insID) end
                            return
                        end
                        if st == _K.MELEE_ID then
                            equipWeaponSkin(_K.MELEE_ID, insID)
                            return
                        end
                        if isHallThemeRes(resID) then
                            putOnHallTheme(insID)
                            return
                        end
                        if isThrowObjectRes(resID) then
                            local st = isThrowObjectRes(resID)
                            local cch = cache()
                            local oldThrow = cch.throwObjects and cch.throwObjects[st]
                            local oldInsID = oldThrow and oldThrow.insID or 0
                            local oldResID = oldThrow and oldThrow.resID or 0
                            putOnThrowObject(insID)
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            local bagIndex = fbd:GetFashionBagUseIndex()
                            local olditem
                            if oldInsID and oldInsID ~= insID and oldInsID ~= 0 then
                                olditem = { res_id = oldResID, count = 1, instid = oldInsID }
                            end
                            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, bagIndex, insID, oldInsID, extra)
                            return
                        end
                        local mainTab = wardrobeMainTab(resID)
                        if mainTab == _K.WARDROBE_PAGE_VEHICLE then
                            local item = { res_id = resID, count = 1, instid = insID }
                            WRH.on_depot_put_on_rsp(_K.NET_OK, item, nil, 1, insID, 0, extra)
                            return
                        end
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        if wd:GetHallDepotItemDataByInsID(insID) then
-- @IG_Serioton
                            local itemSt = st or subType(cfg(resID))
                            local oldIns, oldRes
                            if itemSt then
                                oldIns, oldRes = findWornInsBySubType(itemSt)
                                if oldIns == insID then oldIns, oldRes = nil, nil end
                                removeRoleWearBySubTypes({ [itemSt] = true })
                            end
                            saveClothPiece(resID)
                            local olditem
                            if oldIns then
                                olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
                            end
                            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, 1, insID, oldIns or 0, extra)
                            pcall(function()
                                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                                if oldIns and itemSt then av:SetCurrentWearPreview(itemSt, nil) end
                                if itemSt then av:AddToWearInfo(itemSt, insID, resID, 0, 0) end
                                av:AvatarChange(resID, true, 0, 0)
                                av:ProcessTakeOff()
                                syncFashionBagRolewear()
                            end)
                            pcall(_AutoSaveOutfit)
                        end
                        return
                    end
                    return o(insID, extra)
                end
            end)

            pcall(function()
                local WRH = require("client.network.Protocol.WardRobeHandler")
                local oPutDown = WRH.send_depot_put_down_req
                WRH.send_depot_put_down_req = function(insID, extra)
                    insID = tonumber(insID)
                    if isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        local removed = takeOffItem(insID)
                        if removed then
                            local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                            pcall(function()
                                wl:on_putdown_rsp(_K.NET_OK, {
                                    res_id = resID or 0,
                                    instid = insID,
                                    count  = 1,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = insID,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                    end
                    return oPutDown(insID, extra)
                end
            end)

            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oPutDownReq = wl.wardrobe_put_down_req
                if oPutDownReq then
                    wl.wardrobe_put_down_req = function(self, ins_id, unequip_by_server)
                        ins_id = tonumber(ins_id)
                        if isInjectedIns(ins_id) then
                            local resID = R.insToRes[ins_id]
                            takeOffItem(ins_id)
                            pcall(function()
                                self:on_putdown_rsp(_K.NET_OK, {
                                    instid = ins_id,
                                    res_id = resID or 0,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = ins_id,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                        return oPutDownReq(self, ins_id, unequip_by_server)
                    end
                end
            end)

            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oEquipSlot = wl.EquipSlotVehicle
                if oEquipSlot and not wl._lava_hooked_equip_slot_vehicle then
                    wl._lava_hooked_equip_slot_vehicle = true
                    wl.EquipSlotVehicle = function(self, resid, dragVehicleInsID, Index)
                        dragVehicleInsID = tonumber(dragVehicleInsID)
                        if dragVehicleInsID and isInjectedIns(dragVehicleInsID) then
                            local resID = R.insToRes[dragVehicleInsID]
                            local c = cfg(resID)
                            local itemSubType = c and tonumber(c.ItemSubType or c.itemSubType) or 0
                            if itemSubType and itemSubType > 0 then
                                DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                                local slotList = DataMgr.VehicleSlotList[itemSubType] or {}
                                local idx = Index or 1
                                for i = #slotList, 1, -1 do
                                    if slotList[i] == dragVehicleInsID then
                                        table.remove(slotList, i)
                                    end
                                end
                                slotList[idx] = dragVehicleInsID
                                DataMgr.VehicleSlotList[itemSubType] = slotList
                                if DataMgr.vehicleSkinInsIDTable then
                                    DataMgr.vehicleSkinInsIDTable[resID] = DataMgr.vehicleSkinInsIDTable[resID] or dragVehicleInsID
                                end
                            end
                            DataMgr.UpdateVehicleSkin(itemSubType, dragVehicleInsID)
                            pcall(function()
                                local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                                if tabSurveillance and tabSurveillance.VehicleChange then
                                    tabSurveillance.VehicleChange()
                                end
                            end)
                            if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
                            end
                            return
                        end
                        return oEquipSlot(self, resid, dragVehicleInsID, Index)
                    end
                end
            end)

            pcall(function()
                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if GarageThemeSystem and not GarageThemeSystem._lava_hooked_equip_vehicle then
                    GarageThemeSystem._lava_hooked_equip_vehicle = true
                    local oEquip = GarageThemeSystem.EquipVehicle
                    GarageThemeSystem.EquipVehicle = function(self, Position, InsID)
                        InsID = tonumber(InsID)
                        if InsID and isInjectedIns(InsID) then
                            self:OnEquipVehicle(Position, InsID)
                            return
                        end
                        return oEquip(self, Position, InsID)
                    end
                    local oBatch = GarageThemeSystem.BatchEquipVehicle
                    GarageThemeSystem.BatchEquipVehicle = function(self, InsIDList)
                        if InsIDList and type(InsIDList) == "table" then
                            local hasInjected = false
                            local filtered = {}
                            for slot, ins in pairs(InsIDList) do
                                if isInjectedIns(tonumber(ins)) then
                                    hasInjected = true
                                    self:OnEquipVehicle(slot, tonumber(ins))
                                else
                                    filtered[slot] = ins
                                end
                            end
                            if hasInjected and not next(filtered) then
                                return
                            end
                            InsIDList = filtered
                        end
                        return oBatch(self, InsIDList)
                    end

                    local oReceive = GarageThemeSystem.OnReceiveGarageData
                    GarageThemeSystem.OnReceiveGarageData = function(self, VehicleInfo)
                        local injectedSlots = {}
                        if self.GarageVehicleInfo then
                            for slot, info in pairs(self.GarageVehicleInfo) do
                                if info and info.inst_id and isInjectedIns(tonumber(info.inst_id)) then
                                    injectedSlots[slot] = info
                                end
                            end
                        end
                        oReceive(self, VehicleInfo)
                        for slot, info in pairs(injectedSlots) do
                            if not self.GarageVehicleInfo[slot] then
                                self.GarageVehicleInfo[slot] = info
                            end
                        end
                    end

                    local oGetInfo = GarageThemeSystem.GetGarageVehicleInfo
                    GarageThemeSystem.GetGarageVehicleInfo = function(self)
                        if not self.bDataReceived and self.GarageVehicleInfo and next(self.GarageVehicleInfo) then
                            return self.GarageVehicleInfo
                        end
                        return oGetInfo(self)
                    end

                    local oGetShowList = GarageThemeSystem.GetGarageShowCarInsIDList
                    if oGetShowList then
                        GarageThemeSystem.GetGarageShowCarInsIDList = function(self, VehicleType)
                            local List = oGetShowList(self, VehicleType) or {}
                            for _, resID in ipairs(_C.vehicleItems) do
                                if isInjectedRes(resID) and #List < self:GetMaxPositionNum() then
                                    local c = cfg(resID)
                                    if c then
                                        local itemSubType = tonumber(c.ItemSubType or c.itemSubType) or 0
                                        local taxonomy = CDataTable.GetTableDataByFilter("WardrobeVehiclesTaxonomy", "ItemSubType", itemSubType)
                                        if taxonomy and taxonomy.UseInGarage == 1 and taxonomy.CategoryID == VehicleType then
                                            local insID = R.resToIns[resID]
                                            if insID then
                                                local alreadyIn = false
                                                for _, existingIns in ipairs(List) do
                                                    if tonumber(existingIns) == tonumber(insID) then
                                                        alreadyIn = true
                                                        break
                                                    end
                                                end
                                                if not alreadyIn then
                                                    table.insert(List, insID)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            return List
                        end
                    end
                end
            end)
        end

        local function hookMotionEquip()
            if not _skOn("ALL_SKIN") then return end
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if wl._lava_hooked_motion then return end
                wl._lava_hooked_motion = true

                local origEquip = wl.EquipMotion
                wl.EquipMotion = function(self, instid, dst_slot)
                    instid = tonumber(instid)
                    if instid and isInjectedIns(instid) then
                        local insSlot = 0
                        for i, v in ipairs(DataMgr.MotionSlotList) do
                            if v == instid then insSlot = i; break end
                        end
                        if insSlot > 0 then
                            local curIns = DataMgr.MotionSlotList[dst_slot]
                            if curIns == instid then return end
                            DataMgr.MotionSlotList[insSlot] = curIns or 0
                            DataMgr.MotionSlotList[dst_slot] = instid
                        else
                            while #DataMgr.MotionSlotList < dst_slot do
                                table.insert(DataMgr.MotionSlotList, 0)
                            end
                            DataMgr.MotionSlotList[dst_slot] = instid
                        end
                        if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                            EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                        end
                        pcall(_AutoSaveOutfit)
                        return
                    end
                    return origEquip(self, instid, dst_slot)
                end

                local origUnequip = wl.unequip_motion_req
                wl.unequip_motion_req = function(self, instid, slot)
                    instid = tonumber(instid)
                    if instid and isInjectedIns(instid) then
                        for i, v in ipairs(DataMgr.MotionSlotList) do
                            if v == instid then
                                table.remove(DataMgr.MotionSlotList, i)
                                break
                            end
                        end
                        if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                            EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                        end
                        pcall(_AutoSaveOutfit)
                        return
                    end
                    return origUnequip(self, instid, slot)
                end
            end)
        end

        local _emoteSlotKey = nil
        local _emoteSlotCache = {}
        local function getInjectedEmotes()
            local slotList = DataMgr and DataMgr.MotionSlotList or {}
            local key = table.concat(slotList, ",")
            if key == _emoteSlotKey then return _emoteSlotCache end
            _emoteSlotKey = key
            _emoteSlotCache = {}
            for _, insID in ipairs(slotList) do
                insID = tonumber(insID)
                if insID and insID > 0 and isInjectedIns(insID) then
                    local resID = R.insToRes[insID]
                    if resID then
                        local c = cfg(resID)
                        if c and tonumber(c.ItemType) == 22 then
                            _emoteSlotCache[#_emoteSlotCache + 1] = {
                                resID = resID,
                                name = c.ItemName or "",
                                icon = c.ItemSmallIcon or c.ItemIcon or ""
                            }
                        end
                    end
                end
            end
            return _emoteSlotCache
        end

        local function hookIngameEmote()
            if not _skOn("ALL_SKIN") then return end
            pcall(function()
                local QEU = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")
                if QEU._lava_hooked then return end
                QEU._lava_hooked = true

                local origGetList = QEU.GetShowExpressionList
                QEU.GetShowExpressionList = function()
                    local tShowEmoteList, nWeaponEmoteId = origGetList()
                    tShowEmoteList = tShowEmoteList or {}
                    local emotes = getInjectedEmotes()
                    if #emotes > 0 then
                        local existingIDs = {}
                        for _, existing in pairs(tShowEmoteList) do
                            if existing.DefineID then
                                existingIDs[tonumber(existing.DefineID.TypeSpecificID) or 0] = true
                            end
                        end
                        for _, em in ipairs(emotes) do
                            if not existingIDs[em.resID] then
                                tShowEmoteList[#tShowEmoteList + 1] = {
                                    DefineID = {TypeSpecificID = em.resID},
                                    Name = em.name
                                }
                            end
                        end
                    end
                    return tShowEmoteList, nWeaponEmoteId
                end
            end)

            pcall(function()
                local QE = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpression")
                if QE._lava_hooked_img then return end
                QE._lava_hooked_img = true

                local origGetImg = QE.GetEmoteImagePalthMap
                QE.GetEmoteImagePalthMap = function(self, ...)
                    origGetImg(self, ...)
                    local emotes = getInjectedEmotes()
                    for _, em in ipairs(emotes) do
                        if em.icon ~= "" then
                            self.ItemIDToImagePathMap[em.resID] = em.icon
                        end
                    end
                end
            end)

            pcall(function()
                local le = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
                if le._lava_hooked_exist then return end
                le._lava_hooked_exist = true

                local origExist = le.IsEmoteExist
                le.IsEmoteExist = function(EmoteID)
                    if isInjectedRes(tonumber(EmoteID)) then return true end
                    return origExist(EmoteID)
                end

                local origDownloaded = le.CheckEmoteDownloaded
                if origDownloaded then
                    le.CheckEmoteDownloaded = function(EmoteID, bUseCache, bLobby, bForeceLobby)
                        if isInjectedRes(tonumber(EmoteID)) then return true end
                        return origDownloaded(EmoteID, bUseCache, bLobby, bForeceLobby)
                    end
                end
            end)
        end

        local function hookFashionBag()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if fbd._lava_hooked_bag then return end
                fbd._lava_hooked_bag = true
                local function onFashionBagSkinChanged(skin, slot)
                    skin = tonumber(skin)
                    if _S.equipSkinApplying or not skin or skin <= 0 or not isInjectedIns(skin) then return end
                    local rid = R.insToRes[skin]
                    if not rid or not isInjectedRes(rid) then return end
                    local cch = cache()
                    local oldRes = cch.equip[slot]
                    if oldRes and oldRes > 0 and oldRes ~= rid then
                        softRemoveEquipVisual(oldRes, slot)
                    end
                    saveEquipSkin(rid, skin)
                    if slot ~= "parachute" and slot ~= "glider" then
                        applyEquipVisual(rid, skin, slot)
                    end
                end
                local origBag = fbd.SetBagSkin
                fbd.SetBagSkin = function(self, skin)
                    local r = origBag(self, skin)
                    onFashionBagSkinChanged(skin, "bag")
                    return r
                end
                local origHelm = fbd.SetHelmetSkin
                fbd.SetHelmetSkin = function(self, skin)
                    local r = origHelm(self, skin)
                    onFashionBagSkinChanged(skin, "helmet")
                    return r
                end
                local function reInjectThrowObjects(bagIndex)
                    pcall(function()
                        local cch = cache()
                        if not cch.throwObjects then return end
                        local bags = fbd.GetFashionBags and fbd:GetFashionBags()
                        if not bags or not bags.bags then return end
                        local bag = bags.bags[bagIndex]
                        if not bag then return end
                        bag.throw_object_list = bag.throw_object_list or {}
                        for st, info in pairs(cch.throwObjects) do
                            if info.insID and info.insID > 0 and _K.THROW_SUB[st] then
                                bag.throw_object_list[st] = info.insID
                            end
                        end
                    end)
                end
                local origUpdateAll = fbd.UpdateAllFashionBagExtraInfos
                if origUpdateAll then
                    fbd.UpdateAllFashionBagExtraInfos = function(self, all_knapsack_ext_info)
                        origUpdateAll(self, all_knapsack_ext_info)
                        if all_knapsack_ext_info then
                            for i, _ in pairs(all_knapsack_ext_info) do
                                reInjectThrowObjects(i)
                            end
                        end
                    end
                end
                local origUpdateOne = fbd.UpdateFashionBagExtraInfoByIndex
                if origUpdateOne then
                    fbd.UpdateFashionBagExtraInfoByIndex = function(self, index, knapsack_ext_info)
                        origUpdateOne(self, index, knapsack_ext_info)
                        if index then reInjectThrowObjects(index) end
                    end
                end
            end)
            pcall(function()
                if not DataMgr or DataMgr._lava_hooked_equip_skin then return end
                DataMgr._lava_hooked_equip_skin = true
                local orig = DataMgr.UpdateEquipmentSkin
                DataMgr.UpdateEquipmentSkin = function(itemSubType, putOnId)
                    putOnId = tonumber(putOnId)
                    if putOnId and putOnId > 0 and isInjectedIns(putOnId) and not _S.equipSkinApplying then
                        putOnEquipSkin(putOnId)
                    elseif putOnId == 0 then
                        local slot = (itemSubType == ENUM_ITEM_SUBTYPE.Backpack) and "bag"
                            or (itemSubType == ENUM_ITEM_SUBTYPE.Helmet_NoLevel) and "helmet" or nil
                        if slot then
                            local cch = cache()
                            takeOffEquipSkinVisual(slot, cch.equip[slot], cch.equip[slot .. "Ins"])
                            cch.equip[slot]          = nil
                            cch.equip[slot .. "Ins"] = nil
                            if MATCH_CONFIG.equip then MATCH_CONFIG.equip[slot] = 0 end
                            _S.matchApplied = false
                            invalidateSocialWearCache()
                            pcall(_AutoSaveOutfit)
                        end
                    end
                    return orig(itemSubType, putOnId)
                end
            end)
        end

        local function hookBackpackValid()
            if _G.DEV_WARDROBE_BP_HOOKED then return end
            _G.DEV_WARDROBE_BP_HOOKED = true
            pcall(function()
                local BU = import("BackpackUtils")
                if BU and BU.GetBPIDByResID then
                    local orig = BU.GetBPIDByResID
                    BU.GetBPIDByResID = function(resID)
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local bp = orig(resID)
                            if bp and bp > 0 then return bp end
                            return resID
                        end
                        return orig(resID)
                    end
                end
            end)
            pcall(function()
                local AU = import("AvatarUtils")
                if AU and AU.GetBPIDByResID then
                    local orig = AU.GetBPIDByResID
                    AU.GetBPIDByResID = function(resID, ...)
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local bp = orig(resID, ...)
                            if bp and bp > 0 then return bp end
                            return resID
                        end
                        return orig(resID, ...)
                    end
                end
            end)
        end

        local function hookAvatarValid()
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if not CAC._lava_hooked_check_valid then
                    CAC._lava_hooked_check_valid = true
                    local orig = CAC.CheckItemValid
                    CAC.CheckItemValid = function(self, resID)
                        if isInjectedRes(resID) then return true end
                        return orig(self, resID)
                    end
                end
                if not CAC._lava_hooked_puton then
                    CAC._lava_hooked_puton = true
                    local origPutOn = CAC.PutOnCustomEquipmentByID
                    CAC.PutOnCustomEquipmentByID = function(self, resID, CustomData)
                        -- Skip non-local player to avoid lag
                        if self.IsSelf and not self:IsSelf() then
                            return origPutOn(self, resID, CustomData)
                        end
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local ok, result = pcall(function()
                                local ItemDefineID = FItemDefineID(4, resID)
                                local EAvatarCustomType = import("EAvatarCustomType")
                                local AvatarCustom = FAvatarCustomDefault()
                                if CustomData then AvatarCustom = CustomData end
                                AvatarCustom.CustomType = EAvatarCustomType.AvatarCustomCharacter
                                return self:HandleEquipItem(ItemDefineID, AvatarCustom)
                            end)
                            if ok and result == true then return true end
                            if ok and result ~= false and result ~= nil then return result end
                        end
                        return origPutOn(self, resID, CustomData)
                    end
                end
            end)
        end

        -- ========== ماتش ==========
        local function isInLobby()
            local ok, r = pcall(function()
                return GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() == true
            end)
            return ok and r == true
        end

        local function isInRealMatch()
            local ok, r = pcall(function()
                return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus() == true
            end)
            return ok and r == true
        end

        local function isInGamePlay()
            if isInLobby() then return false end
            if isInRealMatch() then return true end
            local ok, r = pcall(function()
                local SingleTrainTool = require("GameLua.Mod.SingleTraining.GamePlay.Data.SingleTrainTool")
                return SingleTrainTool.IsSelfInTraining and SingleTrainTool.IsSelfInTraining()
            end)
            if ok and r then return true end
            local char = getLocalChar()
            return char and slua.isValid(char) and slua.isValid(char.CharacterAvatarComp2_BP)
        end

        local function getPlayerController()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerController then
                local pc = GD.GetPlayerController()
                if pc and slua.isValid(pc) then return pc end
            end
            local pc = nil
            pcall(function()
                if slua_GameFrontendHUD and slua_GameFrontendHUD.GetPlayerController then
                    pc = slua_GameFrontendHUD:GetPlayerController()
                end
            end)
            return pc and slua.isValid(pc) and pc or nil
        end

        function getLocalChar()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerCharacter then
                local char = GD.GetPlayerCharacter()
                if char and slua.isValid(char) then return char end
            end
            local pc = getPlayerController()
            if pc then
                local char = nil
                pcall(function()
                    if pc.GetPlayerCharacterSafety then char = pc:GetPlayerCharacterSafety() end
                    if (not char or not slua.isValid(char)) and pc.GetPawn then char = pc:GetPawn() end
                    if (not char or not slua.isValid(char)) and pc.K2_GetPawn then char = pc:K2_GetPawn() end
                end)
                if char and slua.isValid(char) then return char end
            end
            return nil
        end

        local function notify(msg)
            if not DEBUG or isInMatchOrGame() then return end
            msg = "[AddOutfit] " .. tostring(msg)
            log(msg:gsub("^%[AddOutfit%] ", ""))
            pcall(function()
                if ShowNotice then ShowNotice(msg, false, 10) end
            end)
        end

        local function getDesiredOutfit()
            if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
                return tonumber(MATCH_CONFIG.outfitRes)
            end
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then return cch.outfitRes end
            if tonumber(_G.AddOutfitLastLobbyOutfitRes) and _G.AddOutfitLastLobbyOutfitRes > 0 then
                return tonumber(_G.AddOutfitLastLobbyOutfitRes)
            end
            return nil
        end

        local function getWearSlotForResID(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local itemCfg = cfg(resID)
            if not itemCfg then return 3 end
            local st = tonumber(itemCfg.ItemSubType or itemCfg.itemSubType or 0)
            if st == 401 then return 1 end
            if st == 402 then return 2 end
            if st == 403 then return 3 end
            if st == 404 then return 4 end
            if st == 405 then return 5 end
            if st == 407 then return 6 end
            if st == 400 or st == 408 then return 9 end
            if st == 409 or st == 410 then return 10 end
            if getEquipSkinSlot(resID) then return nil end
            if weaponIdFromSkin(resID) then return nil end
            return 3
        end

        local function makeWearEntry(resID)
            local ENUM = ENUM_AVATAR_DATA_TYPE or { ItemID = 1, ColorID = 2, PatternID = 3 }
            return { [ENUM.ItemID] = resID, [ENUM.ColorID] = 0, [ENUM.PatternID] = 0 }
        end

        local function isApplySuccess(r) return r ~= false end

        local function refreshMatchAvatar(comp)
            if not slua.isValid(comp) then return end
            pcall(function() if comp.ProcessAvatarRectify then comp:ProcessAvatarRectify() end end)
            pcall(function() if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end end)
            pcall(function() if comp.RefreshAvatarReAttach then comp:RefreshAvatarReAttach() end end)
        end

        local function applyItemToMatchAvatar(comp, resID)
            if not slua.isValid(comp) or not resID or not isInjectedRes(resID) then return false end
            resID = tonumber(resID)
            local applied = false
            pcall(function()
                comp.bSyncAvatar = false
                comp.forceLodMode = true
                comp.bIsLobbyAvatar = false
            end)
            local AvatarData = require("client.logic.data.AvatarData")
            local wearEntry = makeWearEntry(resID)
            local AData = AvatarData.ConvertToAvatarCustom and AvatarData.ConvertToAvatarCustom(wearEntry)
                or AvatarData.CreateAvatarCustom(resID, 0, 0)
            pcall(function()
                if comp.PutOnEquipmentByResID then
                    local r = comp:PutOnEquipmentByResID(AData.ItemID or resID, AData)
                    if isApplySuccess(r) then applied = true end
                end
            end)
            if not applied then
                pcall(function()
                    if comp.PutOnCustomEquipmentByID then
                        local r = comp:PutOnCustomEquipmentByID(resID, AData)
                        if isApplySuccess(r) then applied = true end
                    end
                end)
            end
            if not applied then
                pcall(function()
                    local ItemDefineID = FItemDefineID(4, resID)
                    local EAvatarCustomType = import("EAvatarCustomType")
                    local AvatarCustom = FAvatarCustomDefault()
                    AvatarCustom.CustomType = EAvatarCustomType.AvatarCustomCharacter
                    local r = comp:HandleEquipItem(ItemDefineID, AvatarCustom)
                    if isApplySuccess(r) then applied = true end
                end)
            end
            if applied then refreshMatchAvatar(comp) end
            return applied
        end

        local function applyClothToComp(comp, resID)
            if not slua.isValid(comp) then return false end
            local ok = false
            pcall(function()
                if comp.PutOnCustomEquipmentByID then
                    local r = comp:PutOnCustomEquipmentByID(resID)
                    if isApplySuccess(r) then ok = true end
                end
            end)
            if ok then return true end
            return applyItemToMatchAvatar(comp, resID)
        end

        local function matchApplyOutfit(char)
            if not _skOn("ALL_SKIN") then return false end
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLobby()
            local comp = char.CharacterAvatarComp2_BP
            if not slua.isValid(comp) then return false end

            local outfitRes = getDesiredOutfit()
            local applied = false

            if outfitRes and isFullSuitRes(outfitRes) then
                pcall(function()
                    local r = comp:PutOnCustomEquipmentByID(outfitRes)
                    if isApplySuccess(r) then applied = true end
                end)
                if not applied then
                    pcall(function()
                        local r = comp:HandleEquipItem(FItemDefineID(4, outfitRes), FAvatarCustomDefault())
                        if isApplySuccess(r) then applied = true end
                    end)
                end
                if applied then notify("بدلة OK " .. outfitRes) end
                -- تطبيق الإكسسوارات (ماسك/نظارة/طاقية) فوق البدلة الكاملة
                for resID in pairs(collectAllClothResIDs()) do
                    if resID ~= outfitRes and not isFullSuitRes(resID)
                        and not isBodyClothSubType(subType(cfg(resID)))
                        and applyClothToComp(comp, resID) then
                        applied = true
                        notify("إكسسوار OK " .. resID)
                    end
                end
            else
                for resID in pairs(collectAllClothResIDs()) do
                    if not isFullSuitRes(resID) and applyClothToComp(comp, resID) then
                        applied = true
                        notify("ملابس OK " .. resID)
                    end
                end
            end
            return applied
        end

        local _lastPatchTime = 0
        local function patchPlayerInfoForMatch(PlayerInfo)
            if not PlayerInfo then return end
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastPatchTime) < 1.0 then return end  -- throttle: max once per second
            _lastPatchTime = now
            snapshotLobbyWear()
            local cch = cache()
            if cch.equip.bag then PlayerInfo.bag_skin = cch.equip.bag end
            if cch.equip.helmet then PlayerInfo.helmet_skin = cch.equip.helmet end
            if cch.equip.armor then PlayerInfo.armor_skin = cch.equip.armor end
-- @IG_Serioton
            local idx = tonumber(PlayerInfo.use_rolewear) or 1
            PlayerInfo.use_rolewear = idx
            PlayerInfo.all_knapsack_ext_info = PlayerInfo.all_knapsack_ext_info or {}
            PlayerInfo.all_knapsack_ext_info[idx] = PlayerInfo.all_knapsack_ext_info[idx] or {}
            local ext = PlayerInfo.all_knapsack_ext_info[idx]
            if cch.equip.bag then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLists = buildEquipSkinLists(catalogBag)
                ext.bag_skin = catalogBag
                ext.bag_skin_list = bagLists
                PlayerInfo.bag_skin = catalogBag
            end
            if cch.equip.helmet then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLists = buildEquipSkinLists(catalogHelm)
                ext.helmet_skin = catalogHelm
                ext.helmet_skin_list = helmLists
                PlayerInfo.helmet_skin = catalogHelm
            end
            if cch.equip.armor then ext.armor_skin = cch.equip.armor end
            if cch.equip.parachute and cch.equip.parachute > 0 then
                ext.parachute = cch.equip.parachuteIns or cch.equip.parachute
            end
            if cch.equip.glider and cch.equip.glider > 0 then
                ext.gliding = cch.equip.glider
            end

            pcall(function()
                if cch.throwObjects then
                    local throwList = {}
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            throwList[st] = info.resID
                        end
                    end
                    if next(throwList) then
                        local function applyThrowList(kext)
                            if not kext then return end
                            kext.throw_object_list = kext.throw_object_list or {}
                            for st, resID in pairs(throwList) do
                                kext.throw_object_list[st] = resID
                            end
                        end
                        applyThrowList(ext)
                        applyThrowList(PlayerInfo.knapsack_ext_info)
                        PlayerInfo.all_knapsack_ext_info = PlayerInfo.all_knapsack_ext_info or {}
                        for i = 1, 6 do
                            PlayerInfo.all_knapsack_ext_info[i] = PlayerInfo.all_knapsack_ext_info[i] or {}
                            applyThrowList(PlayerInfo.all_knapsack_ext_info[i])
                        end
                        for i, kext in pairs(PlayerInfo.all_knapsack_ext_info) do
                            applyThrowList(kext)
                        end
                        log("patchPlayerInfoForMatch: throw_object_list injected into all knapsack entries")
                    end
                end
            end)

            pcall(function()
                if DataMgr and DataMgr.VehicleSlotList then
                    PlayerInfo.vst_in_battle = PlayerInfo.vst_in_battle or {}
                    for subType, insList in pairs(DataMgr.VehicleSlotList) do
                        if insList and type(insList) == "table" then
                            local resList = {}
                            for i, insID in ipairs(insList) do
                                insID = tonumber(insID)
                                if insID and insID > 0 then
                                    local resID
                                    if isInjectedIns(insID) then
                                        resID = R.insToRes[insID]
                                    else
                                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                        local d = wd:GetHallDepotItemDataByInsID(insID)
                                        resID = d and tonumber(d.resID)
                                    end
                                    if resID and resID > 0 then
                                        resList[#resList + 1] = resID
                                    end
                                end
                            end
                            if #resList > 0 then
                                PlayerInfo.vst_in_battle[subType] = resList
                            end
                        end
                    end
                    if DataMgr.vst_skin then
                        local skinIns = tonumber(DataMgr.vst_skin)
                        if skinIns and skinIns > 0 then
                            local skinRes
                            if isInjectedIns(skinIns) then
                                skinRes = R.insToRes[skinIns]
                            else
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(skinIns)
                                skinRes = d and tonumber(d.resID)
                            end
                            if skinRes and skinRes > 0 then
                                PlayerInfo.vst_skin = skinRes
                            end
                        end
                    end
                end
            end)
        end

        local _lastApplyEquipToController = 0
        local function applyMatchEquipAvatarToController()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastApplyEquipToController) < 0.3 then return false end  -- throttle: max 3x/sec
            _lastApplyEquipToController = now
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.equip.bag and not cch.equip.helmet and not cch.equip.armor and not cch.equip.parachute and not cch.equip.glider then return false end

            local char = getLocalChar()
            local eq = pc.InitialEquipmentAvatar or {}

            -- طبّق سكن الشنطة فقط لو اللاعب لابس شنطة فعلاً
            if cch.equip.bag and cch.equip.bag > 0 and isWearingEquip(char, "bag") then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLists = buildEquipSkinLists(catalogBag)
                eq.BagAvatar = catalogBag
                eq.BagAvatarList = bagLists
                local realBagId = getCharEquipLevel(char, 8) or 0
                local bagLevel
                if realBagId > 0 and isBaseEquipItemId(realBagId) then
                    bagLevel = detectEquipLevelFromBaseId(realBagId, catalogBag)
                elseif realBagId > 0 then
                    bagLevel = detectLevelFromEquipRes(realBagId)
                end
                bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                local bagDisplay = mapEquipSkinRes(catalogBag, bagLevel)
                if bagDisplay > 0 then eq.BagAvatar = bagDisplay end
            else
                eq.BagAvatar = 0
                eq.BagAvatarList = nil
            end
            -- طبّق سكن الخوذة فقط لو اللاعب لابس خوذة فعلاً
            if cch.equip.helmet and cch.equip.helmet > 0 and isWearingEquip(char, "helmet") then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLists = buildEquipSkinLists(catalogHelm)
                eq.HelmetAvatar = catalogHelm
                eq.HelmetAvatarList = helmLists
                local realHelmId = getCharEquipLevel(char, 9) or 0
                local helmLevel
                if realHelmId > 0 and isBaseEquipItemId(realHelmId) then
                    helmLevel = detectEquipLevelFromBaseId(realHelmId, catalogHelm)
                elseif realHelmId > 0 then
                    helmLevel = detectLevelFromEquipRes(realHelmId)
                end
                helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                local helmDisplay = mapEquipSkinRes(catalogHelm, helmLevel)
                if helmDisplay > 0 then eq.HelmetAvatar = helmDisplay end
            else
                eq.HelmetAvatar = 0
                eq.HelmetAvatarList = nil
            end
            if cch.equip.armor then eq.ArmorAvatar = cch.equip.armor end
            if cch.equip.parachute and cch.equip.parachute > 0 then
                eq.ParachuteAvatar = cch.equip.parachute
            end
            if cch.equip.glider and cch.equip.glider > 0 then
                eq.GliderAvatar = cch.equip.glider
            end

            pc.InitialEquipmentAvatar = eq
            pcall(function()
                if slua.isValid(pc.PlayerState) and pc.PlayerState.MetroPlayerStateAvatarFeature then
                    pc.PlayerState.MetroPlayerStateAvatarFeature.InitialEquipmentAvatar = eq
                end
            end)
            pcall(function()
                local comp = char and char.CharacterAvatarComp2_BP
                if slua.isValid(comp) and comp.GetEquipmentSkinItemID then
                    if cch.equip.helmet and isWearingEquip(char, "helmet") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.helmet) end)
                    end
                    if cch.equip.bag and isWearingEquip(char, "bag") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.bag) end)
                    end
                    if cch.equip.parachute and isWearingEquip(char, "parachute") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.parachute) end)
                    end
                    if cch.equip.glider and cch.equip.glider > 0 then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.glider) end)
                    end
                end
            end)
            pcall(function()
                if pc.OnEquipmentAvatarChange and pc.OnEquipmentAvatarChange.Broadcast then
                    pc.OnEquipmentAvatarChange:Broadcast()
                end
            end)
            notify("معدات: خوذة=" .. tostring(eq.HelmetAvatar) .. " شنطة=" .. tostring(eq.BagAvatar))
            return true
        end

        local function hookEquipMapping()
            pcall(function()
                if DataMgr and not DataMgr._lava_equip_map_hooked then
                    DataMgr._lava_equip_map_hooked = true
                    local orig = DataMgr.GetEquipmentItemIDByResID
                    DataMgr.GetEquipmentItemIDByResID = function(level, itemResID)
                        level, itemResID = tonumber(level) or 3, tonumber(itemResID)
                        local catalogRes = normalizeEquipCatalogRes(itemResID)
                        local r = orig(level, catalogRes)
                        if r and r > 0 then return r end
                        if isInjectedIns(itemResID) then
                            return mapEquipSkinRes(normalizeEquipCatalogRes(R.insToRes[itemResID]), level)
                        end
                        if isInjectedRes(itemResID) then
                            return mapEquipSkinRes(catalogRes, level)
                        end
                        return r or 0
                    end
                end
            end)
            pcall(function()
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                if lav._lava_skinins_hooked then return end
                lav._lava_skinins_hooked = true
                local orig2 = lav.GetEquipmentItemIDBySkinInsID
                lav.GetEquipmentItemIDBySkinInsID = function(self, itemSubType, itemInsID)
                    local level = lav.GetEquipmentItemShowLevel(lav, itemSubType)
                    local r = orig2(self, itemSubType, itemInsID)
                    if r and r > 0 then return r end
                    itemInsID = tonumber(itemInsID)
                    if isInjectedIns(itemInsID) then
                        return mapEquipSkinRes(normalizeEquipCatalogRes(R.insToRes[itemInsID]), level)
                    end
                    pcall(function()
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetHallDepotItemDataByInsID(itemInsID)
                        if d and isInjectedRes(d.resID) then
                            return mapEquipSkinRes(normalizeEquipCatalogRes(d.resID), level)
                        end
                    end)
                    return r
                end
            end)
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if CAC._lava_equip_skin_hooked then return end
                CAC._lava_equip_skin_hooked = true
                local orig3 = CAC.GetEquipmentSkinItemID
                CAC.GetEquipmentSkinItemID = function(self, InItemID)
                    -- Skip non-local player equipment to avoid lag
                    if self.IsSelf and not self:IsSelf() then
                        return orig3(self, InItemID)
                    end
                    local cch = cache()
                    InItemID = tonumber(InItemID) or 0

                    local function tryGetSkin(catalogRes)
                        if not catalogRes or catalogRes <= 0 then return 0 end
                        catalogRes = normalizeEquipCatalogRes(catalogRes)
                        local skin = resolveMatchEquipSkin(catalogRes, InItemID)
                        if skin > 0 then return skin end
                        for lvl = 1, 3 do
                            local s = mapEquipSkinRes(catalogRes, lvl)
                            if s > 0 then return s end
                        end
                        return 0
                    end

                    if InItemID > 0 and isBaseEquipItemId(InItemID) then
                        local isHelmetBase = GAME_HELMET_LEVEL[InItemID] ~= nil
                            or (InItemID >= 1505000001 and InItemID <= 1505000100)
                            or (InItemID >= 502001 and InItemID <= 502999)
                        local isBagBase = GAME_BAG_LEVEL[InItemID] ~= nil
                            or (InItemID >= 501001 and InItemID <= 501999)
                            or (InItemID >= 1501000000 and InItemID < 1502000000)

                        local char = getLocalChar()
                        if isHelmetBase and cch.equip.helmet and cch.equip.helmet > 0 then
                            if char and isWearingEquip(char, "helmet") then
                                local skin = tryGetSkin(cch.equip.helmet)
                                if skin > 0 then return skin end
                            end
                        end
                        if isBagBase and cch.equip.bag and cch.equip.bag > 0 then
                            if char and isWearingEquip(char, "bag") then
                                local skin = tryGetSkin(cch.equip.bag)
                                if skin > 0 then return skin end
                            end
                        end
                    end

                    local origResult = orig3(self, InItemID)
                    if origResult and origResult > 0 and origResult ~= InItemID then
                        return origResult
                    end

                    -- fallback مع تحقق isWearingEquip
                    local isHelmetQuery = GAME_HELMET_LEVEL[InItemID] ~= nil or (InItemID >= 502001 and InItemID <= 502999)
                    local isBagQuery = GAME_BAG_LEVEL[InItemID] ~= nil or (InItemID >= 501001 and InItemID <= 501999)
                    local char = getLocalChar()

                    if isHelmetQuery and cch.equip.helmet and cch.equip.helmet > 0 then
                        if char and isWearingEquip(char, "helmet") then
                            local skin = tryGetSkin(cch.equip.helmet)
                            if skin > 0 then return skin end
                        end
                    end
                    if isBagQuery and cch.equip.bag and cch.equip.bag > 0 then
                        if char and isWearingEquip(char, "bag") then
                            local skin = tryGetSkin(cch.equip.bag)
                            if skin > 0 then return skin end
                        end
                    end
                    return origResult
                end
                local origEquipFinish = CAC.OnAvatarEquipFinish
                CAC.OnAvatarEquipFinish = function(self, slotType, isEquipped, itemID)
                    if origEquipFinish then origEquipFinish(self, slotType, isEquipped, itemID) end
                    if not isEquipped then return end
                    -- Only process local player equipment to avoid lag
                    if not self.IsSelf or not self:IsSelf() then return end
                    pcall(function()
                        if self.IsLobbyActor and self:IsLobbyActor() then return end
                        local EAvatarSlotType = import("EAvatarSlotType")
                        local cch = cache()
                        local isHelmet = slotType == EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot
                        local isBag = slotType == EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot
                        if (isHelmet and cch.equip.helmet and cch.equip.helmet > 0)
                            or (isBag and cch.equip.bag and cch.equip.bag > 0) then
                            local owner = self.GetOwner and self:GetOwner()
                            if owner and slua.isValid(owner) and owner.AddGameTimer then
                                owner:AddGameTimer(0.25, false, function()
                                    if slua.isValid(owner) then matchApplyEquipSkins(owner) end
                                end)
                            end
                        end
                        applyMatchEquipAvatarToController()
                    end)
                end
            end)
        end

        local function applyMatchEquipSkinAtLevel(comp, catalogResID, level)
            if not slua.isValid(comp) or not catalogResID or catalogResID <= 0 then return false end
            catalogResID = normalizeEquipCatalogRes(catalogResID)
            level = tonumber(level) or 3
            local skinId = mapEquipSkinRes(catalogResID, level)
            if not skinId or skinId <= 0 then skinId = catalogResID end
            local ok = false
            pcall(function()
                if comp.PutOnCustomEquipmentByID then
                    local r = comp:PutOnCustomEquipmentByID(skinId)
                    if isApplySuccess(r) then ok = true end
                end
            end)
            if not ok then
                pcall(function()
                    local r = comp:HandleEquipItem(FItemDefineID(4, skinId), FAvatarCustomDefault())
                    if isApplySuccess(r) then ok = true end
                end)
            end
            if ok then refreshMatchAvatar(comp) end
            return ok
        end

            -- أضف الدالة دي قبل matchApplyEquipSkins
        local function getCharEquipLevel(char, slotID)
            local found = nil
            pcall(function()
                local comp = char and char.CharacterAvatarComp2_BP
                if not slua.isValid(comp) then return end
                local NetAvatarData = slua.IndexReference(comp, "NetAvatarData")
                if not NetAvatarData then return end
                local TempSlotSyncData = slua.IndexReference(NetAvatarData, "SlotSyncData")
                if not TempSlotSyncData then return end
                for Index, AvatarSynData in pairs(TempSlotSyncData) do
                    if AvatarSynData.SlotID == slotID and AvatarSynData.ItemID and AvatarSynData.ItemID > 0 then
                        found = AvatarSynData.ItemID
                        return
                    end
                end
            end)
            return found
        end

        local function isWearingEquip(char, slot)
            local slotID = (slot == "helmet") and 9 or (slot == "bag") and 8 or (slot == "parachute") and 11 or (slot == "glider") and 15 or nil
            if not slotID then return false end

-- @IG_Serioton
            local itemID = getCharEquipLevel(char, slotID)
            if itemID and itemID > 0 then return true end

-- @IG_Serioton
            local wearing = false
            pcall(function()
                local pc = getPlayerController()
                if not pc or not slua.isValid(pc) then return end
                if pc.PlayerState and pc.PlayerState.MetroPlayerStateAvatarFeature then
                    local psEquip = pc.PlayerState.MetroPlayerStateAvatarFeature.EquipmentAvatarData
                    if psEquip then
                        if slot == "helmet" and psEquip.HelmetAvatar and psEquip.HelmetAvatar > 0 then
                            wearing = true
                        elseif slot == "bag" and psEquip.BagAvatar and psEquip.BagAvatar > 0 then
                            wearing = true
                        end
                    end
                end
            end)
            return wearing
        end

        local _lastMatchApplyEquip = 0
        local function matchApplyEquipSkins(char)
            if not _skOn("ALL_SKIN") then return false end
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastMatchApplyEquip) < 0.5 then return false end  -- -- @IG_Serioton
            _lastMatchApplyEquip = now
            local cch = cache()
            if not cch.equip.bag and not cch.equip.helmet and not cch.equip.parachute and not cch.equip.glider then return false end
            local comp = char and char.CharacterAvatarComp2_BP
            if not slua.isValid(comp) then return false end
            local ok = false

            if cch.equip.helmet and cch.equip.helmet > 0 then
                if isWearingEquip(char, "helmet") then
                    local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                    local realHelmId = getCharEquipLevel(char, 9) or 0
                    local helmLevel
                    if realHelmId > 0 and isBaseEquipItemId(realHelmId) then
                        helmLevel = detectEquipLevelFromBaseId(realHelmId, catalogHelm)
                    elseif realHelmId > 0 then
                        helmLevel = detectLevelFromEquipRes(realHelmId)
                    end
                    helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                    if applyMatchEquipSkinAtLevel(comp, catalogHelm, helmLevel) then
                        ok = true
                        notify("خوذة ماتش OK " .. mapEquipSkinRes(catalogHelm, helmLevel))
                    end
                end
            end

            if cch.equip.bag and cch.equip.bag > 0 then
                if isWearingEquip(char, "bag") then
                    local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                    local realBagId = getCharEquipLevel(char, 8) or 0
                    local bagLevel
                    if realBagId > 0 and isBaseEquipItemId(realBagId) then
                        bagLevel = detectEquipLevelFromBaseId(realBagId, catalogBag)
                    elseif realBagId > 0 then
                        bagLevel = detectLevelFromEquipRes(realBagId)
                    end
                    bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                    if applyMatchEquipSkinAtLevel(comp, catalogBag, bagLevel) then
                        ok = true
                        notify("شنطة ماتش OK " .. mapEquipSkinRes(catalogBag, bagLevel))
                    end
                end
            end

            if cch.equip.parachute and cch.equip.parachute > 0 then
                if isWearingEquip(char, "parachute") then
                    local paraResID = cch.equip.parachute
                    pcall(function()
                        if comp.PutOnCustomEquipmentByID then
                            local r = comp:PutOnCustomEquipmentByID(paraResID)
                            if isApplySuccess(r) then
                                ok = true
                                notify("براشوت ماتش OK " .. tostring(paraResID))
                            end
                        end
                    end)
                    if not ok then
                        pcall(function()
                            local r = comp:HandleEquipItem(FItemDefineID(4, paraResID), FAvatarCustomDefault())
                            if isApplySuccess(r) then
                                ok = true
                                notify("براشوت ماتش OK " .. tostring(paraResID))
                            end
                        end)
                    end
                end
            end

            if cch.equip.glider and cch.equip.glider > 0 then
                local gliderResID = cch.equip.glider
                pcall(function()
                    if comp.PutOnCustomEquipmentByID then
                        local r = comp:PutOnCustomEquipmentByID(gliderResID)
                        if isApplySuccess(r) then
                            ok = true
                            notify("جلايدر ماتش OK " .. tostring(gliderResID))
                        end
                    end
                end)
                if not ok then
                    pcall(function()
                        local r = comp:HandleEquipItem(FItemDefineID(4, gliderResID), FAvatarCustomDefault())
                        if isApplySuccess(r) then
                            ok = true
                            notify("جلايدر ماتش OK " .. tostring(gliderResID))
                        end
                    end)
                end
            end

-- @IG_Serioton
            applyMatchEquipAvatarToController()

-- @IG_Serioton
            pcall(function()
                local NetAvatarData = slua.IndexReference(comp, "NetAvatarData")
                if not NetAvatarData then return end
                local TempSlotSyncData = slua.IndexReference(NetAvatarData, "SlotSyncData")
                if not TempSlotSyncData then return end

                for Index, AvatarSynData in pairs(TempSlotSyncData) do
                    local slotID = AvatarSynData.SlotID
                    local NDRid = AvatarSynData.ItemID

                    if slotID == 8 and NDRid ~= 0 and cch.equip.bag and cch.equip.bag > 0 then
                        local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                        local bagLevel
                        if isBaseEquipItemId(NDRid) then
                            bagLevel = detectEquipLevelFromBaseId(NDRid, catalogBag)
                        else
                            bagLevel = detectLevelFromEquipRes(NDRid)
                        end
                        bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                        local skinId = mapEquipSkinRes(catalogBag, bagLevel)
                        if skinId <= 0 then skinId = mapEquipSkinRes(catalogBag, 3) end
                        if skinId > 0 and NDRid ~= skinId then
                            AvatarSynData.ItemID = skinId
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

                    if slotID == 9 and NDRid ~= 0 and cch.equip.helmet and cch.equip.helmet > 0 then
                        local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                        local helmLevel
                        if isBaseEquipItemId(NDRid) then
                            helmLevel = detectEquipLevelFromBaseId(NDRid, catalogHelm)
                        else
                            helmLevel = detectLevelFromEquipRes(NDRid)
                        end
                        helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                        local skinId = mapEquipSkinRes(catalogHelm, helmLevel)
                        if skinId <= 0 then skinId = mapEquipSkinRes(catalogHelm, 3) end
                        if skinId > 0 and NDRid ~= skinId then
                            AvatarSynData.ItemID = skinId
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

-- @IG_Serioton
                    if slotID == 11 and NDRid ~= 0 and cch.equip.parachute and cch.equip.parachute > 0 then
                        local paraResID = cch.equip.parachute
                        if NDRid ~= paraResID then
                            AvatarSynData.ItemID = paraResID
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

                    -- جلايدر - SlotID 15 (GlideEquipmtSlot)
                    if slotID == 15 and NDRid ~= 0 and cch.equip.glider and cch.equip.glider > 0 then
                        local gliderResID = cch.equip.glider
                        if NDRid ~= gliderResID then
                            AvatarSynData.ItemID = gliderResID
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end
                end

                if ok and comp.OnRep_BodySlotStateChanged then
                    comp:OnRep_BodySlotStateChanged()
                end
            end)
            return ok
        end

        local function hookPlayerWearingDone()
            pcall(function()
                local pc = getPlayerController()
                if not pc or not slua.isValid(pc) or pc._lava_wear_done_hooked then return end
                pc._lava_wear_done_hooked = true
                if pc.OnPlayerChangeWearingDone and pc.OnPlayerChangeWearingDone.Add then
                    pc.OnPlayerChangeWearingDone:Add(function()
                        applyMatchEquipAvatarToController()
                        local char = getLocalChar()
                        if char then
                            char:AddGameTimer(0.2, false, function()
                                if slua.isValid(char) then matchApplyEquipSkins(char) end
                            end)
                        end
                    end)
                end
            end)
        end

        local function hookCommerAvatarData()
            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                if CommerAvatarDataUtil._lava_hooked_equip then return end
                CommerAvatarDataUtil._lava_hooked_equip = true
                local orig = CommerAvatarDataUtil.GeneratePlayerAvatarData
                CommerAvatarDataUtil.GeneratePlayerAvatarData = function(self, PlayerInfo, uPlayerController, ...)
                    -- Skip expensive operations for non-local players
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function() patchPlayerInfoForMatch(PlayerInfo) end)
                    end
                    orig(self, PlayerInfo, uPlayerController, ...)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        applyMatchEquipAvatarToController()
                    end
                end
            end)
        end

        local function hookMatchAvatarData()
            hookCommerAvatarData()
            pcall(function()
                local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
                if AvatarDataUtil._lava_hooked_gen then return end
                AvatarDataUtil._lava_hooked_gen = true
                local origGet = AvatarDataUtil.GetPlayerInfo
                AvatarDataUtil.GetPlayerInfo = function(uPlayerController)
                    local pi = origGet(uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if pi and uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        patchPlayerInfoForMatch(pi)
                    end
                    return pi
                end
                local origGen = AvatarDataUtil.GeneratePlayerAvatarData
                AvatarDataUtil.GeneratePlayerAvatarData = function(uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function()
                            local PlayerInfo = AvatarDataUtil.GetPlayerInfo(uPlayerController)
                            if PlayerInfo then patchPlayerInfoForMatch(PlayerInfo) end
                        end)
                    end
                    origGen(uPlayerController)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        applyMatchEquipAvatarToController()
                    end
                    return
                end
                local origInit = AvatarDataUtil.InitialEquipmentAvatar
                AvatarDataUtil.InitialEquipmentAvatar = function(PlayerInfo, uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function() patchPlayerInfoForMatch(PlayerInfo) end)
                    end
                    origInit(PlayerInfo, uPlayerController)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        applyMatchEquipAvatarToController()
                    end
                end
            end)
        end

        local function hookClassMethod(classModule, methodName, hookTag, newFunc)
            if not classModule then log("hookClassMethod: nil classModule for", methodName) return false end
            local impl = classModule.__inner_impl
            if not impl then log("hookClassMethod: no __inner_impl for", methodName) return false end
            if impl[hookTag] then log("hookClassMethod: already hooked", methodName) return false end
            local orig = impl[methodName]
            if not orig then log("hookClassMethod: no orig method", methodName) return false end
            impl[hookTag] = true
            impl[methodName] = function(...)
                return newFunc(orig, ...)
            end
            pcall(function() rawset(classModule, methodName, nil) end)
            -- log("hookClassMethod: hooked", methodName)
            return true
        end

        local function hookGrenadeAvatarInit()
            pcall(function()
                local PCB = require("GameLua.GameCore.Framework.PlayerControllerBase")
                -- log suppressed
                hookClassMethod(PCB, "InitGrenadeAvatarList", "_lava_hooked_grenade_init", function(orig, self, ReInitial)
                    orig(self, ReInitial)
                    -- Only inject for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if not localPC or self ~= localPC then return end
                    if ReInitial then
                        pcall(function()
                            local cch = cache()
                            if cch.throwObjects and self.AddToGrenadeAvatarItemList then
                                for st, info in pairs(cch.throwObjects) do
                                    if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                                        self:AddToGrenadeAvatarItemList(info.resID)
                                    end
                                end
                            end
                        end)
                    end
                end)
            end)
        end

        local function applyGrenadeSkinsToController()
            if not _skOn("ALL_SKIN") then return false end
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.throwObjects then return false end
            local hasThrow = false
            for _, info in pairs(cch.throwObjects) do
                if info.resID and info.resID > 0 then hasThrow = true break end
            end
            if not hasThrow then return false end
            pcall(function()
                if pc.AddToGrenadeAvatarItemList then
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            pc:AddToGrenadeAvatarItemList(info.resID)
                        end
                    end
                end
                if pc.OnWeaponAvatarUpdate then
                    pc:OnWeaponAvatarUpdate()
                end
                local char = getLocalChar()
                if char and slua.isValid(char) then
                    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
                    if slua.isValid(curWeapon) then
                        local wid = 0
                        pcall(function() wid = curWeapon:GetWeaponID() end)
                        if wid >= 602001 and wid <= 602004 then
                            log("applyGrenadeSkinsToController: held grenade wid=", wid)
                            if curWeapon.DelayHandleAvatarMeshChanged then
                                curWeapon:DelayHandleAvatarMeshChanged()
                            end
                            if curWeapon.HandleAvatarMeshChanged then
                                curWeapon:HandleAvatarMeshChanged()
                            end
                            local GRENADE_WID_TO_SUB = {
                                [602001] = 614, [602002] = 613,
                                [602003] = 615, [602004] = 612,
                            }
                            local sub = GRENADE_WID_TO_SUB[wid]
                            local info = sub and cch.throwObjects[sub]
                            if info and info.resID and info.resID > 0 then
                                if slua.isValid(curWeapon.GrenadeAvatarComponent_BP) then
                                    curWeapon.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                    log("applyGrenadeSkinsToController: ChangeItemAvatar on held weapon", info.resID)
                                end
                                if curWeapon.AddGameTimer then
                                    curWeapon:AddGameTimer(0.1, false, function()
                                        pcall(function()
                                            if slua.isValid(curWeapon) and slua.isValid(curWeapon.GrenadeAvatarComponent_BP) then
                                                curWeapon.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                            end
                                        end)
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
            return true
        end

        -- Simplified: only hook TryGetGrenadeAvatarID (lightweight), 
        -- skip per-grenade-class GetAvatarID hooks (heavy, fire for all players)
        local function hookGrenadeAvatarLookup()
            pcall(function()
                local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
                if AvatarDataUtil and not AvatarDataUtil._lava_hooked_try_get then
                    AvatarDataUtil._lava_hooked_try_get = true
                    local origTry = AvatarDataUtil.TryGetGrenadeAvatarID
                    if origTry then
                        AvatarDataUtil.TryGetGrenadeAvatarID = function(uPlayerController, ItemID)
                            local cch = cache()
                            if cch.throwObjects then
                                if ItemID == 602001 and cch.throwObjects[614] and cch.throwObjects[614].resID and cch.throwObjects[614].resID > 0 then
                                    return cch.throwObjects[614].resID
                                elseif ItemID == 602002 and cch.throwObjects[613] and cch.throwObjects[613].resID and cch.throwObjects[613].resID > 0 then
                                    return cch.throwObjects[613].resID
                                elseif ItemID == 602003 and cch.throwObjects[615] and cch.throwObjects[615].resID and cch.throwObjects[615].resID > 0 then
                                    return cch.throwObjects[615].resID
                                elseif ItemID == 602004 and cch.throwObjects[612] and cch.throwObjects[612].resID and cch.throwObjects[612].resID > 0 then
                                    return cch.throwObjects[612].resID
                                end
                            end
                            return origTry(uPlayerController, ItemID)
                        end
                    end
                end
            end)
            -- Per-class GetAvatarID hooks removed (heavy, fire for all player grenades)
            -- Timer-based applyGrenadeSkinsToController handles periodic application
        end

        local GRENADE_ITEMID_TO_SUB = {
            [602001] = 614,
            [602002] = 613,
            [602003] = 615,
            [602004] = 612,
        }

        -- Lightweight version: only hooks UpdateGrenadeAvatar for local grenades
        -- Timer-based applyGrenadeSkinsToController handles periodic application
        local function hookProjectileGrenadeAvatar()
            pcall(function()
                local ProjectileBase = require("GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.ProjectileBase")
                local impl = ProjectileBase and ProjectileBase.__inner_impl
                if not impl or impl._lava_hooked_proj then return end
                impl._lava_hooked_proj = true
                local origUpdate = impl.UpdateGrenadeAvatar
                if origUpdate then
                    impl.UpdateGrenadeAvatar = function(self)
                        -- Only process local player grenades
                        if self.bAuthority then return origUpdate(self) end
                        local cch = cache()
                        if cch.throwObjects and slua.isValid(self.GrenadeAvatarComponent_BP) then
                            local itemID
                            if self.GetItemTypeID then
                                itemID = tonumber(self:GetItemTypeID())
                            elseif self.ItemDefineID then
                                itemID = tonumber(self.ItemDefineID.TypeSpecificID)
                            end
                            local sub = itemID and GRENADE_ITEMID_TO_SUB[itemID]
                            local info = sub and cch.throwObjects[sub]
                            if info and info.resID and info.resID > 0 then
                                pcall(function()
                                    self.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                end)
                                return
                            end
                        end
                        return origUpdate(self)
                    end
                end
                -- Skip BeginInitialize and ResetGrenadeAvatar hooks (they fire for every player's grenades)
                -- Timer-based applyGrenadeSkinsToController will re-apply periodically
            end)
        end

        local function applyMatchWeaponSkinsToController()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local skinList = {}
            for _, w in pairs(cache().weapons) do
                if w.resID and w.resID > 0 then skinList[#skinList + 1] = w.resID end
            end
            if #skinList == 0 then return false end
            local ok = false
            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                CommerAvatarDataUtil:InitWeaponSkinList(pc, skinList, nil, nil)
                if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end
                if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end
                ok = true
            end)
            if ok then notify("سلاح PC: " .. table.concat(skinList, ",")) end
            return ok
        end

        local _weaponTypeIDCache = {}
        local function resolveWeaponTypeID(weaponResID)
            weaponResID = tonumber(weaponResID) or 0
            if weaponResID <= 0 then return 0 end
            if _weaponTypeIDCache[weaponResID] ~= nil then return _weaponTypeIDCache[weaponResID] end
            local found = 0
            pcall(function()
                local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
                if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
            end)
            if found > 0 then _weaponTypeIDCache[weaponResID] = found; return found end
            pcall(function()
                local ic = CDataTable.GetTableData("Item", weaponResID)
                if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
            end)
            local result = found > 0 and found or weaponResID
            _weaponTypeIDCache[weaponResID] = result
            return result
        end

        local _lastBuildSkinMappings = 0
        local function buildSkinMappings()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastBuildSkinMappings) < 0.5 then return end  -- throttle: max twice per second
            _lastBuildSkinMappings = now
            syncWeaponCacheFromLobby()
            local m = _G.AddOutfitSkinIdMappings
            for k in pairs(m) do m[k] = nil end
            for wid, w in pairs(cache().weapons) do
                wid = tonumber(wid)
                if wid and w.resID and w.resID > 0 then m[wid] = { tonumber(w.resID) } end
            end
            if MATCH_CONFIG.weaponSkins then
                for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
                    weaponKey, skinRes = tonumber(weaponKey), tonumber(skinRes)
                    if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                        m[weaponKey] = { skinRes }
                    end
                end
            end
        end

        local _skinIdCache = {}
        local _skinIdCacheTick = 0
        local function get_skin_id(currentGunId, maxIt)
            currentGunId, maxIt = tonumber(currentGunId) or 0, tonumber(maxIt) or 0
            if currentGunId <= 0 and maxIt <= 0 then return 0 end
            -- Fast path: prefer using weapon cache directly
            local cch = cache()
            local wid = maxIt > 0 and maxIt or currentGunId
            local w = cch.weapons[wid]
            if w and w.resID and w.resID > 0 then return w.resID end
            -- Try type ID lookup
            local typeId = resolveWeaponTypeID(wid)
            if typeId ~= wid then
                local w2 = cch.weapons[typeId]
                if w2 and w2.resID and w2.resID > 0 then return w2.resID end
            end
            -- Cache with short TTL
            local nowTick = _S.globalFrame or 0
            if (nowTick - _skinIdCacheTick) < 60 then
                local cached = _skinIdCache[wid]
                if cached then return cached end
            end
            buildSkinMappings()
            local m = _G.AddOutfitSkinIdMappings
            local result = nil
            if m[wid] and m[wid][1] then result = tonumber(m[wid][1])
            elseif typeId ~= wid and m[typeId] and m[typeId][1] then result = tonumber(m[typeId][1])
            end
            if result then
                _skinIdCache[wid] = result
                _skinIdCacheTick = nowTick
                return result
            end
            return wid
        end
        _G.get_skin_id = get_skin_id
        _G.skinIdMappings = _G.AddOutfitSkinIdMappings

        -- ========== Attachment Skin System (ported from C++ DumpSkin) ==========
        -- Builds weapon-skin -> attachment-skin maps from ItemUpgradeConfig and
        -- ItemUpgradeUnLockConfig, then applies the correct attachment skins
        -- (scopes, compensators, magazines, grips, stocks) when a weapon skin
        -- is active, so each skin carries its own dedicated attachments.

        local _attachMaps = nil

        local function _nameToString(name)
            if name == nil then return "" end
            if type(name) == "string" then return name end
            if type(name) == "userdata" then
                local s = nil
                pcall(function() if name.ToString then s = name:ToString() end end)
                if s and type(s) == "string" then return s end
                pcall(function() if name.ToWString then s = name:ToWString() end end)
                if s and type(s) == "string" then return s end
            end
            if type(name) == "table" and name.SourceString then
                return name.SourceString
            end
            return tostring(name)
        end

        local _WEAPON_CLASS_SUFFIXES = {
            { keywords = { "kar98", "awm", "m24", "amr", "mosin", "win94", "mk14" },
            suffixes = { "(Snipers)", "(Sniper Rifles)" } },
            { keywords = { "m249", "mg3", "dp-28", "dp28" },
            suffixes = { "(Machine Guns)" } },
            { keywords = { "ump", "p90", "vector", "bizon", "uzi", "thompson",
                        "mp5", "mp5k", "tommy" },
            suffixes = { "(SMG)", "(SMG, Pistols)", "(Rifles, SMG)" } },
            { keywords = { "p1911", "p92", "p18c", "deagle", "r1895", "r45",
                        "skorpion", "g18" },
            suffixes = { "(Pistols)", "(SMG, Pistols)" } },
            { keywords = { "akm", "m762", "scar", "famas", "m16a4", "aug",
                        "groza", "qbz", "m416", "mk47", "g36c", "ace32",
                        "k2", "m4" },
            suffixes = { "(AR)", "(Rifles, SMG)" } },
        }

        local function _classSuffixesFromSkinName(skinName)
            if type(skinName) ~= "string" or skinName == "" then return {} end
            local low = string.lower(skinName)
            for _, entry in ipairs(_WEAPON_CLASS_SUFFIXES) do
                for _, kw in ipairs(entry.keywords) do
                    if string.find(low, kw, 1, true) then return entry.suffixes end
                end
            end
            return {}
        end

        local function buildAttachmentMaps()
            if _attachMaps then return _attachMaps end
            _attachMaps = {
                skinAttachments  = {},  -- weaponSkinId -> { partSkinId1, partSkinId2, ... }
                skinBases        = {},  -- weaponSkinId -> { baseId1, baseId2, ... }
                attachToSkin     = {},  -- partSkinId   -> { weaponSkinId, baseId }
                skinToBaseWeapon = {},  -- weaponSkinId -> baseWeaponID
            }
            if not CDataTable or not CDataTable.GetTable then return _attachMaps end

            -- 1) GroupID -> [PartIds] from ItemUpgradeUnLockConfig
            local groupToParts = {}
            pcall(function()
                local unlockTbl = CDataTable.GetTable("ItemUpgradeUnLockConfig")
                if not unlockTbl then return end
                for _, row in pairs(unlockTbl) do
                    local gid  = tonumber(row.GroupID)
                    local part = tonumber(row.PartId or row.PartID)
                    if gid and part then
                        if not groupToParts[gid] then groupToParts[gid] = {} end
                        groupToParts[gid][#groupToParts[gid] + 1] = part
                    end
                end
            end)

            -- 2) weaponSkinId -> GroupID + skinToBaseWeapon from ItemUpgradeConfig
            local skinToGroup = {}
            pcall(function()
                local upTbl = CDataTable.GetTable("ItemUpgradeConfig")
                if not upTbl then return end
                for _, row in pairs(upTbl) do
                    local gid = tonumber(row.GroupID)
                    local itm = tonumber(row.ItemID)
                    if gid and itm and itm >= 1000000000 then
                        skinToGroup[itm] = gid
                        local baseWeaponID = math.floor(itm / 1000) % 1000000
                        if baseWeaponID >= 100000 and baseWeaponID <= 999999 then
                            _attachMaps.skinToBaseWeapon[itm] = baseWeaponID
                        end
                    end
                end
            end)

            -- 3) Base name -> [ids] index from Item table (vanilla attachments only)
            local baseNameToIds = {}
            local itemTbl = CDataTable.GetTable("Item")
            if itemTbl then
                for k, row in pairs(itemTbl) do
                    local id = tonumber(k) or tonumber(row and row.ItemID)
                    if id and id >= 1000 and id < 10000000 then
                        local nm = row and row.ItemName
                        if type(nm) ~= "string" then nm = _nameToString(nm) end
                        if type(nm) == "string" and nm ~= "" then
                            if not baseNameToIds[nm] then baseNameToIds[nm] = {} end
                            baseNameToIds[nm][#baseNameToIds[nm] + 1] = id
                        end
                    end
                end
            end

            -- 4) For each weapon skin, resolve its attachments' base IDs
            for weaponSkinId, gid in pairs(skinToGroup) do
                local parts = groupToParts[gid]
                if parts and #parts > 0 then
                    local bases = {}
                    local wc = cfg(weaponSkinId)
                    local weaponSkinName = ""
                    if wc then
                        local nm = wc.ItemName
                        if type(nm) ~= "string" then nm = _nameToString(nm) end
                        weaponSkinName = nm or ""
                    end
                    local suffixes = _classSuffixesFromSkinName(weaponSkinName)

                    for _, partId in ipairs(parts) do
                        local baseId = 0
                        local partRow = nil
                        if itemTbl then
                            partRow = itemTbl[partId] or itemTbl[tostring(partId)]
                        end
                        if not partRow and CDataTable.GetTableData then
                            partRow = CDataTable.GetTableData("Item", partId)
                        end
                        if partRow then
                            local nm = partRow.ItemName
                            if type(nm) ~= "string" then nm = _nameToString(nm) end
                            if type(nm) == "string" and nm ~= "" then
                                local list = baseNameToIds[nm]
                                if type(list) == "table" and #list >= 1 then
                                    baseId = list[1]
                                    for _, v in ipairs(list) do
                                        if v < baseId then baseId = v end
                                    end
                                end
                                if baseId == 0 then
                                    for _, suf in ipairs(suffixes) do
                                        local trial = nm .. " " .. suf
                                        local lst = baseNameToIds[trial]
                                        if type(lst) == "table" and #lst >= 1 then
                                            baseId = lst[1]
                                            for _, v in ipairs(lst) do
                                                if v < baseId then baseId = v end
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        bases[#bases + 1] = baseId
                        _attachMaps.attachToSkin[partId] = { weaponSkinId, baseId }
                    end
                    _attachMaps.skinAttachments[weaponSkinId] = parts
                    _attachMaps.skinBases[weaponSkinId] = bases
                end
            end

            local nSkins, nAttach = 0, 0
            for _ in pairs(_attachMaps.skinAttachments) do nSkins = nSkins + 1 end
            for _ in pairs(_attachMaps.attachToSkin) do nAttach = nAttach + 1 end
            log("Attachment maps: " .. nSkins .. " skins, " .. nAttach .. " attachments")

            return _attachMaps
        end

        local function applyAttachmentSkins(AttachmentArray, selectedSkinID)
            if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end
            selectedSkinID = tonumber(selectedSkinID) or 0
            if selectedSkinID == 0 then return false end

            local maps = buildAttachmentMaps()
            local attachments = maps.skinAttachments[selectedSkinID]
            local bases = maps.skinBases[selectedSkinID]

            local numSlots = 0
            pcall(function() numSlots = AttachmentArray:Num() end)
            if numSlots <= 0 then return false end

            local changed = false

            -- If selected skin has no attachments in the map, revert any
            -- part-skins found on attachment slots back to their base IDs.
            if not attachments or #attachments == 0 then
                for slotIdx = 0, numSlots - 1 do
                    if slotIdx ~= _K.GUN_MASTER_SYN_SLOT then
                        local slotData = AttachmentArray:Get(slotIdx)
                        if slotData then
                            local curID = 0
                            pcall(function()
                                curID = slua.IndexReference(slotData, "defineID").TypeSpecificID or 0
                            end)
                            curID = tonumber(curID) or 0
                            if curID > 0 then
                                local rIt = maps.attachToSkin[curID]
                                if rIt then
                                    local baseId = rIt[2]
                                    if baseId ~= 0 and baseId ~= curID then
                                        pcall(function()
                                            local defRef = slua.IndexReference(slotData, "defineID")
                                            defRef.TypeSpecificID = baseId
                                            slotData.operationType = 0
                                            AttachmentArray:Set(slotIdx, slotData)
                                        end)
                                        changed = true
                                    end
                                end
                            end
                        end
                    end
                end
                return changed
            end

            -- Build a set of valid attachment skin IDs for this weapon skin
            local validSkinIds = {}
            for _, id in ipairs(attachments) do
                validSkinIds[tonumber(id) or 0] = true
            end

            -- Normal case: for each attachment slot, find the matching
            -- attachment skin by baseId and swap to the selected skin's version.
            for slotIdx = 0, numSlots - 1 do
                if slotIdx ~= _K.GUN_MASTER_SYN_SLOT then
                    local slotData = AttachmentArray:Get(slotIdx)
                    if slotData then
                        local curID = 0
                        pcall(function()
                            curID = slua.IndexReference(slotData, "defineID").TypeSpecificID or 0
                        end)
                        curID = tonumber(curID) or 0
                        if curID > 0 then
                            -- Protection: if current attachment is already the correct skin, skip
                            if validSkinIds[curID] then
                                -- Already the correct skinned attachment, don't change
                            else
                                local baseId = 0
                                local rIt = maps.attachToSkin[curID]
                                if rIt then
                                    baseId = rIt[2]
                                elseif curID < 10000000 then
                                    baseId = curID
                                else
                                    -- Unknown skinned attachment from different skin, skip
                                    baseId = 0
                                end
                                if baseId ~= 0 then
                                    local srcIdx = 0
                                    for k, b in ipairs(bases) do
                                        if b ~= 0 and b == baseId then
                                            local candidate = tonumber(attachments[k]) or 0
                                            if candidate ~= 0 and candidate ~= curID then
                                                srcIdx = k
                                                break
                                            end
                                        end
                                    end
                                    if srcIdx > 0 and srcIdx <= #attachments then
                                        local newID = tonumber(attachments[srcIdx]) or 0
                                        if newID ~= 0 and newID ~= curID then
                                            pcall(function()
                                                local defRef = slua.IndexReference(slotData, "defineID")
                                                defRef.TypeSpecificID = newID
                                                slotData.operationType = 0
                                                AttachmentArray:Set(slotIdx, slotData)
                                            end)
                                            changed = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return changed
        end

        local function applySkinToWeaponRef(CurWeapon)
            if not slua.isValid(CurWeapon) then return false end
            local AttachmentArray = CurWeapon.synData
            if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

-- @IG_Serioton
            local AttachmentData = AttachmentArray:Get(_K.GUN_MASTER_SYN_SLOT)
            if not AttachmentData then return false end

            local current_gunid = 0
            pcall(function()
                current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0
            end)
            current_gunid = tonumber(current_gunid) or 0
            if current_gunid <= 0 then return false end

            local MaxIt = 0
            pcall(function()
                if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
                if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
            end)
            MaxIt = tonumber(MaxIt) or 0
            if MaxIt <= 0 then return false end

            local tmp_id = get_skin_id(current_gunid, MaxIt)
            tmp_id = tonumber(tmp_id) or 0
            if tmp_id <= 0 then return false end

-- @IG_Serioton
            if tmp_id == current_gunid and not isInjectedRes(tmp_id) then
                local ok, attChanged = pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
                if ok and attChanged then
                    pcall(function()
                        local char = getLocalChar()
                        if char and char.AddGameTimer then
                            for _, delay in ipairs({0.3, 0.6, 1.0}) do
                                char:AddGameTimer(delay, false, function()
                                    if slua.isValid(CurWeapon) then
                                        local aa = CurWeapon.synData
                                        if aa and slua.isValid(aa) then
                                            pcall(applyAttachmentSkins, aa, tmp_id)
                                        end
                                    end
                                end)
                            end
                        end
                    end)
                end
                return false
            end
            if tmp_id == _S.lastAppliedSkinID and MaxIt == _S.lastAppliedWeaponID then
                local ok, attChanged = pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
                if ok and attChanged then
                    pcall(function()
                        local char = getLocalChar()
                        if char and char.AddGameTimer then
                            for _, delay in ipairs({0.3, 0.6, 1.0}) do
                                char:AddGameTimer(delay, false, function()
                                    if slua.isValid(CurWeapon) then
                                        local aa = CurWeapon.synData
                                        if aa and slua.isValid(aa) then
                                            pcall(applyAttachmentSkins, aa, tmp_id)
                                        end
                                    end
                                end)
                            end
                        end
                    end)
                end
                return true
            end

            _G.AddOutfitLastAppliedSkin[current_gunid] = tmp_id
            pcall(function()
                local defRef = slua.IndexReference(AttachmentData, "defineID")
                defRef.TypeSpecificID = tmp_id
                local c0 = cfg(tmp_id)
                if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
                AttachmentData.operationType = 0
                AttachmentArray:Set(_K.GUN_MASTER_SYN_SLOT, AttachmentData)
            end)
            pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
            if CurWeapon.DelayHandleAvatarMeshChanged then CurWeapon:DelayHandleAvatarMeshChanged() end
            -- Delayed re-application of attachment skins to ensure attachments
            -- are updated after the weapon finishes loading its default attachments.
            -- This fixes the issue where attachments don't update until you swap them.
            pcall(function()
                local char = getLocalChar()
                if char and char.AddGameTimer then
                    for _, delay in ipairs({0.3, 0.6, 1.0}) do
                        char:AddGameTimer(delay, false, function()
                            if slua.isValid(CurWeapon) then
                                local aa = CurWeapon.synData
                                if aa and slua.isValid(aa) then
                                    pcall(applyAttachmentSkins, aa, tmp_id)
                                end
                            end
                        end)
                    end
                end
            end)
            _S.weaponHookGuardUntil = _S.globalFrame + 45
            _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
            _S.lastAppliedWeaponID = MaxIt
            _S.lastAppliedSkinID = tmp_id
            return true
        end

        function _G.equip_weapon_avatar(uCharacter)
            if not uCharacter or not slua.isValid(uCharacter) then return false end
            buildSkinMappings()
            local WeaponManager = uCharacter:GetWeaponManager()
            if not WeaponManager or not slua.isValid(WeaponManager) then return false end
            local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
            if not uWeaponList or not slua.isValid(uWeaponList) then return false end
            local appliedAny = false
            for i = 0, uWeaponList:Num() - 1 do
                local CurWeapon = uWeaponList:Get(i)
                if slua.isValid(CurWeapon) and applySkinToWeaponRef(CurWeapon) then
                    appliedAny = true
                end
            end
            return appliedAny
        end

        local function getDesiredWeaponSkins()
            syncWeaponCacheFromLobby()
            local out, seen = {}, {}
            local function add(res)
                res = tonumber(res)
                if res and res > 0 and not seen[res] then seen[res] = true; out[#out + 1] = res end
            end
            for _, w in pairs(cache().weapons) do add(w.resID) end
            if MATCH_CONFIG.weaponSkins then
                for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
            end
            return out
        end

        local function registerWeaponAvatarItems(char)
            local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
            if not slua.isValid(pc) then return false end
            local BU = import("BackpackUtils")
            local AU = import("AvatarUtils")
            local addedCount = 0
            for _, resID in ipairs(getDesiredWeaponSkins()) do
                local doneDirect = false
                pcall(function()
                    if pc.AddWeaponAvatarItem then
                        pc:AddWeaponAvatarItem(tonumber(resID))
                        doneDirect = true
                        addedCount = addedCount + 1
                    end
                end)
                if not doneDirect then
                    pcall(function()
                        local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                        local arr = slua.Array(UEnums.EPropertyClass.Int)
                        local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                        if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                            for _, parentID in pairs(parents) do
                                pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                            end
                            addedCount = addedCount + 1
                        end
                    end)
                end
            end
            if addedCount == 0 then return false end
            pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
            pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
            notify("سجّلت " .. addedCount .. " سكن سلاح")
            return true
        end

        local _lastMatchApplyWeapon = 0
        local function matchApplyWeaponSkin(char)
            if not _skOn("ALL_SKIN") then return false end
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastMatchApplyWeapon) < 0.4 then return false end  -- throttle: max 2.5x/sec
            _lastMatchApplyWeapon = now
            buildSkinMappings()
            applyMatchWeaponSkinsToController()
            if not _S.avatarItemsRegistered then
                _S.avatarItemsRegistered = registerWeaponAvatarItems(char)
            end
            local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
            if not slua.isValid(curWeapon) then
                return _G.equip_weapon_avatar(char)
            end

            local curWeaponResID = 0
            pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
            local desiredSkin = get_skin_id(curWeaponResID, curWeaponResID)
            if curWeaponResID == _S.lastAppliedWeaponID and desiredSkin == _S.lastAppliedSkinID then
                pcall(_G.equip_weapon_avatar, char)
                return true
            end

            local ok = applySkinToWeaponRef(curWeapon)
            ok = _G.equip_weapon_avatar(char) or ok
            if ok then
                _S.lastAppliedWeaponID = curWeaponResID
                _S.lastAppliedSkinID = desiredSkin
                _S.weaponApplied = true
                _S.weaponDiagDone = true
                notify("سكن سلاح مطبق: " .. tostring(desiredSkin))
            end
            return ok
        end

        local function applyMatchThrowObjects()
            if not _skOn("ALL_SKIN") then return false end
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.throwObjects then
                log("applyMatchThrowObjects: no throwObjects in cache")
                return false
            end
            local hasThrow = false
            for st, info in pairs(cch.throwObjects) do
                if info.resID and info.resID > 0 then hasThrow = true end
            end
            if not hasThrow then
                log("applyMatchThrowObjects: throwObjects cache empty")
                return false
            end
            local applied = false
            pcall(function()
                -- Try setting InitialConsumableAvatar fields (works if Lua table reference)
                if pc.InitialConsumableAvatar then
                    for st, info in pairs(cch.throwObjects) do
                        local key = _K.THROW_AVATAR_KEY[_K.THROW_SUB[st]]
                        if key and info.resID and info.resID > 0 then
                            pc.InitialConsumableAvatar[key] = info.resID
                            -- log suppressed
                        end
                    end
                end
                -- Rebuild grenade avatar list from InitialConsumableAvatar
                if pc.InitGrenadeAvatarList then
                    pc:InitGrenadeAvatarList(false)
                end
                -- Fallback: directly add to GrenadeAvatarItemList (overwrites server entries)
                if pc.AddToGrenadeAvatarItemList then
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            pc:AddToGrenadeAvatarItemList(info.resID)
                            applied = true
                        end
                    end
                end
            end)
            return applied
        end

        local function matchApplyAll(char)
            if not _skOn("ALL_SKIN") then return false end
            local ok = false
            if not _S.matchOutfitDone then
                _S.matchOutfitDone = matchApplyOutfit(char)
                ok = _S.matchOutfitDone or ok
            end
            if applyMatchEquipAvatarToController() then ok = true end
            if matchApplyEquipSkins(char) then ok = true; _S.matchApplied = true end
            if matchApplyWeaponSkin(char) then ok = true end
            if applyMatchThrowObjects() then ok = true end
            return ok
        end

-- @IG_Serioton
        local function startMatchWatcher(char)
            if _S.matchTimer then return end
            _S.matchOutfitDone = false
            _S.avatarItemsRegistered = false
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.lastAppliedWeaponID = 0
            _S.lastAppliedSkinID = 0

            local attempts = 0
            notify("-- @IG_Serioton")

            _S.matchTimer = char:AddGameTimer(1.0, true, function()
                attempts = attempts + 1
                local cur = getLocalChar()
                if not cur or not slua.isValid(cur) then return end
                pcall(matchApplyAll, cur)
                if attempts >= 30 then
                    pcall(function() if cur.RemoveGameTimer then cur:RemoveGameTimer(_S.matchTimer) end end)
                    _S.matchTimer = nil
                    log("-- @IG_Serioton")
                end
            end)
        end

-- @IG_Serioton
        local _hookedGetWeaponAvatarRes = false

        local function hookBackpackWeaponAvatarRes()
            if _hookedGetWeaponAvatarRes then return end
            _hookedGetWeaponAvatarRes = true
            pcall(function()
                local BPL = require("GameLua.Mod.BaseMod.Client.Backpack.BackPackFunctionLibrary")
                if BPL and BPL.GetWeaponAvatarRes and not BPL._lava_hooked_avatar_res then
                    BPL._lava_hooked_avatar_res = true
                    local _bpAvatarResCache = {}
                    local _bpAvatarResTicks = {}
                    local _bpResCacheAge = 0
                    local origGetRes = BPL.GetWeaponAvatarRes
                    BPL.GetWeaponAvatarRes = function(WeaponID, AdditionalDataArray)
                        WeaponID = tonumber(WeaponID) or 0
                        if WeaponID <= 0 then return origGetRes(WeaponID, AdditionalDataArray) end
                        -- Cache with invalidation every ~5 seconds via frame count
                        local cached = _bpAvatarResCache[WeaponID]
                        local age = _bpResCacheAge
                        local nowTick = _S.globalFrame or 0
                        if cached and (nowTick - (_bpAvatarResTicks[WeaponID] or 0)) < 150 then
                            return cached, ""
                        end
                        local targetSkinID = 0
                        -- 1) map directly from cache weapons
                        local cch = cache()
                        local typeId = resolveWeaponTypeID(WeaponID)
                        local w = cch.weapons[typeId] or cch.weapons[WeaponID]
                        if w and w.resID and w.resID > 0 then
                            targetSkinID = w.resID
                        end
                        -- 2) fallback to get_skin_id
                        if targetSkinID <= 0 or targetSkinID == WeaponID then
                            local sid = get_skin_id(WeaponID, WeaponID)
                            targetSkinID = tonumber(sid) or 0
                        end
                        -- Cache result
                        if targetSkinID > 0 and targetSkinID ~= WeaponID then
                            _bpAvatarResCache[WeaponID] = targetSkinID
                            _bpAvatarResTicks[WeaponID] = nowTick
                            local skinCfg = cfg(targetSkinID)
                            if skinCfg then
                                return targetSkinID, ""
                            end
                        end
                        _bpAvatarResCache[WeaponID] = WeaponID
                        _bpAvatarResTicks[WeaponID] = nowTick
                        return origGetRes(WeaponID, AdditionalDataArray)
                    end
                    log("[AddOutfit] hookBackpackWeaponAvatarRes: تم")
                end
            end)
        end

-- @IG_Serioton
        local _lastVehicleSkinKey = ""

        local function applyVehicleSkinInGame()
            if not _skOn("ALL_SKIN") then return end
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return end

            local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
            if not vehicle or not slua.isValid(vehicle) then
                _lastVehicleSkinKey = ""
                return
            end
            pcall(syncVehicleAvatarSkinList)

            local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
            if not avatarComp or not slua.isValid(avatarComp) then return end

            local defaultAvatarID = avatarComp.GetDefaultAvatarID and avatarComp:GetDefaultAvatarID()
            if not defaultAvatarID or defaultAvatarID == 0 then return end

            local currentAvatarID = avatarComp.GetCurrentAvatarID and avatarComp:GetCurrentAvatarID()

-- @IG_Serioton
            local cacheKey = tostring(vehicle) .. "_" .. tostring(defaultAvatarID) .. "_" .. tostring(currentAvatarID)
            if cacheKey == _lastVehicleSkinKey then return end

-- @IG_Serioton
            local vehicleSubType = 0
            local defaultItemCfg = cfg(defaultAvatarID)
            if defaultItemCfg then
                vehicleSubType = tonumber(defaultItemCfg.ItemSubType or defaultItemCfg.itemSubType) or 0
            end

-- @IG_Serioton
            local desiredSkins = {}
            local firstSkinResID = 0
            if vehicleSubType > 0 and DataMgr and DataMgr.VehicleSlotList then
                local slotList = DataMgr.VehicleSlotList[vehicleSubType]
                if slotList then
                    for i = 1, #slotList do
                        local skinInsID = tonumber(slotList[i])
                        if skinInsID and skinInsID > 0 then
                            local skinResID = 0
                            if isInjectedIns(skinInsID) then
                                skinResID = R.insToRes[skinInsID] or 0
                            else
                                pcall(function()
                                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                    local d = wd:GetHallDepotItemDataByInsID(skinInsID)
                                    skinResID = d and tonumber(d.resID) or 0
                                end)
                            end
                            if skinResID > 0 then
                                desiredSkins[skinResID] = true
                                if firstSkinResID == 0 then
                                    firstSkinResID = skinResID
                                end
                            end
                        end
                    end
                end
            end

-- @IG_Serioton
            if vehicleSubType > 0 then
                pcall(function()
                    local pc = getPlayerController()
                    if pc and pc.PlayerState then
                        local vst = pc.PlayerState.vst_in_battle
                        if vst and vst[vehicleSubType] then
                            local resList = vst[vehicleSubType]
                            if resList and type(resList) == "table" then
                                for _, resID in ipairs(resList) do
                                    resID = tonumber(resID)
                                    if resID and resID > 0 then
                                        if not desiredSkins[resID] then
                                            desiredSkins[resID] = true
                                            if firstSkinResID == 0 then
                                                firstSkinResID = resID
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end

-- @IG_Serioton
            if firstSkinResID == 0 and DataMgr and DataMgr.VehicleSlotList then
                local defStr = tostring(defaultAvatarID)
                for subType, insList in pairs(DataMgr.VehicleSlotList) do
                    if insList and type(insList) == "table" then
                        for i = 1, #insList do
                            local skinInsID = tonumber(insList[i])
                            if skinInsID and skinInsID > 0 then
                                local rid = 0
                                if isInjectedIns(skinInsID) then
                                    rid = R.insToRes[skinInsID] or 0
                                else
                                    pcall(function()
                                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                        local d = wd:GetHallDepotItemDataByInsID(skinInsID)
                                        rid = d and tonumber(d.resID) or 0
                                    end)
                                end
                                if rid > 0 then
                                    local skinCfg = cfg(rid)
                                    if skinCfg then
                                        local skinDefault = skinCfg.DefaultAvatarID or skinCfg.defaultAvatarID
                                        if skinDefault and tostring(skinDefault):find(defStr, 1, true) then
                                            if not desiredSkins[rid] then
                                                desiredSkins[rid] = true
                                                firstSkinResID = rid
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        if firstSkinResID > 0 then break end
                    end
                end
            end

-- @IG_Serioton
            if currentAvatarID and desiredSkins[currentAvatarID] then
                _lastVehicleSkinKey = cacheKey
                return
            end

            local skinResID = firstSkinResID

            if skinResID == 0 then
                _lastVehicleSkinKey = cacheKey
                return
            end


-- @IG_Serioton
            pcall(function()
                local pc = getPlayerController()
                if pc and avatarComp.SetVehicleNetAvatarData then
                    avatarComp:SetVehicleNetAvatarData(pc)
                end
-- @IG_Serioton
                if avatarComp.VehicleNetAvatarData then
                    avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                    avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                end
                avatarComp:ChangeItemAvatar(skinResID, true)
                avatarComp.CanChangeAvatar = true
            end)

-- @IG_Serioton
            pcall(applyVehicleChassisLight)

            _lastVehicleSkinKey = cacheKey
        end

-- @IG_Serioton
        local _LAVA_CHASSIS_LIGHT_ID = 7302002

        local function isLocalPlayerVehicle(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return false end
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return false end
            local currentVehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
            if currentVehicle and currentVehicle == vehicle then return true end
            local driver = nil
            pcall(function() driver = vehicle.GetDriver and vehicle:GetDriver() end)
            if driver and driver == char then return true end
            return false
        end

        local function getVehicleSkinID(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return 0 end
            local skinID = 0
            pcall(function()
                if vehicle.GetVehicleSkinItemID then
                    skinID = vehicle:GetVehicleSkinItemID() or 0
                end
            end)
            if skinID and skinID > 0 then return skinID end
            pcall(function()
                if vehicle.ClientUsedAvatarID then
                    skinID = vehicle.ClientUsedAvatarID
                end
            end)
            if skinID and skinID > 0 then return skinID end
            pcall(function()
                local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                if avatarComp and slua.isValid(avatarComp) and avatarComp.GetCurrentAvatarID then
                    skinID = avatarComp:GetCurrentAvatarID() or 0
                end
            end)
            return skinID or 0
        end

        local function vehicleHasSkinApplied(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return false end
            local skinID = getVehicleSkinID(vehicle)
            if skinID <= 0 then return false end
            local defaultID = 0
            pcall(function()
                local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                if avatarComp and slua.isValid(avatarComp) and avatarComp.GetDefaultAvatarID then
                    defaultID = avatarComp:GetDefaultAvatarID() or 0
                end
            end)
            return skinID ~= defaultID
        end

        local function forceVehicleChassisLight(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return end
            local licenseComp = vehicle.GetLicenseComponent and vehicle:GetLicenseComponent()
            if not licenseComp or not slua.isValid(licenseComp) then
                print("[AddOutfit] forceVehicleChassisLight: no licenseComp")
                return
            end
            if not licenseComp.LicensePlate then
                print("[AddOutfit] forceVehicleChassisLight: no LicensePlate")
                return
            end
            if licenseComp.LicensePlate.ChassisLightId == _LAVA_CHASSIS_LIGHT_ID and slua.isValid(licenseComp.ChassisLightMesh) then
                return
            end
            local skinID = getVehicleSkinID(vehicle)
            if skinID > 0 then
                licenseComp.LicensePlate.ItemID = skinID
            end
            licenseComp.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
            if licenseComp.curVehicleAvatarId == nil or licenseComp.curVehicleAvatarId == 0 then
                licenseComp.curVehicleAvatarId = skinID
            end
            print("[AddOutfit] forceVehicleChassisLight: skinID=" .. tostring(skinID) .. " ChassisLightId=" .. tostring(_LAVA_CHASSIS_LIGHT_ID) .. " ItemID=" .. tostring(licenseComp.LicensePlate.ItemID))
            if licenseComp.PreChangeChassisLight then
                pcall(function() licenseComp:PreChangeChassisLight() end)
            end
        end

        local function applyVehicleChassisLight()
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return end
            local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
            if not vehicle or not slua.isValid(vehicle) then return end
            if not isLocalPlayerVehicle(vehicle) then return end
            if not vehicleHasSkinApplied(vehicle) then return end
            forceVehicleChassisLight(vehicle)
        end

        local function hookVehicleLicenseComponentBase()
            local ok, VLB = pcall(require, "GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
            if not ok or not VLB then return end
            local impl = VLB.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_chassis then return end
            impl._lava_hooked_chassis = true

            local origCheckDownloaded = impl.CheckHasVehicleDownloaded
            impl.CheckHasVehicleDownloaded = function(self, ItemID)
                local vehicle = self:GetOwner()
                if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                    return true
                end
                return origCheckDownloaded(self, ItemID)
            end

            local origPreChange = impl.PreChangeChassisLight
            impl.PreChangeChassisLight = function(self)
                pcall(function()
                    local vehicle = self:GetOwner()
                    if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                        if self.LicensePlate then
                            local skinID = getVehicleSkinID(vehicle)
                            if skinID > 0 then
                                self.LicensePlate.ItemID = skinID
                            end
                            self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                        end
                    end
                end)
                return origPreChange(self)
            end

            local origAsyncLoad = impl.AsyncLoadAccessoryItemHandle
            if origAsyncLoad then
                impl.AsyncLoadAccessoryItemHandle = function(self, itemId, bCheckDownload)
                    if itemId == _LAVA_CHASSIS_LIGHT_ID then
                        bCheckDownload = false
                    end
                    return origAsyncLoad(self, itemId, bCheckDownload)
                end
            end

            local origAsyncLoadHandle = impl._AsyncLoadHandle
            if origAsyncLoadHandle then
                impl._AsyncLoadHandle = function(self, ItemID)
                    if ItemID == _LAVA_CHASSIS_LIGHT_ID then
                        pcall(function()
                            local UBackpackUtils = import("BackpackUtils")
                            local handlePath = self:GetAccessoryAvatarHandlePath(ItemID)
                            local itemCfg = CDataTable.GetTableData("Item", ItemID)
                            if handlePath and itemCfg and itemCfg.BPID then
                                local bpCfg = CDataTable.GetTableData("AvatarBPTable", itemCfg.BPID)
                                if bpCfg and bpCfg.AvatarBPPath and bpCfg.AvatarBPPath ~= "" then
                                    self:AsyncLoadAsset(handlePath, self.OnAccHandleLoaded, self, ItemID, itemCfg.BPID)
                                    return
                                end
                            end
                            print("[AddOutfit] _AsyncLoadHandle bypass failed for chassis light, trying direct load")
                        end)
                    end
                    return origAsyncLoadHandle(self, ItemID)
                end
            end

            local origOnRep = impl.OnRep_LicensePlate
            if origOnRep then
                impl.OnRep_LicensePlate = function(self)
                    local bReapply = false
                    pcall(function()
                        local vehicle = self:GetOwner()
                        if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                            bReapply = true
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(vehicle)
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                        end
                    end)
                    local result = origOnRep(self)
                    if bReapply then
                        pcall(function()
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(self:GetOwner())
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                            if self.PreChangeChassisLight then
                                self:PreChangeChassisLight()
                            end
                        end)
                    end
                    return result
                end
            end

            local origOnVehicleMesh = impl.OnVehicleMeshAvatarEquiped
            if origOnVehicleMesh then
                impl.OnVehicleMeshAvatarEquiped = function(self, expectItemId)
                    local result = origOnVehicleMesh(self, expectItemId)
                    pcall(function()
                        local vehicle = self:GetOwner()
                        if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(vehicle)
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                            if self.PreChangeChassisLight then
                                self:PreChangeChassisLight()
                            end
                        end
                    end)
                    return result
                end
            end

            print("[AddOutfit] VehicleLicenseComponentBase chassis hook installed")
        end

        local function hookVehiclePlateLicenseUtil()
            local ok, VPLU = pcall(require, "GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            if not ok or not VPLU then return end
            if VPLU._lava_hooked_chassis then return end
            VPLU._lava_hooked_chassis = true
            local origGetLoc = VPLU.GetChassisLightLocAndScale
            VPLU.GetChassisLightLocAndScale = function(vehicleId, bIsLobbyVehicle)
                local loc, scale = origGetLoc(vehicleId, bIsLobbyVehicle)
                if loc and scale then
                    return loc, scale
                end
                local defaultLoc = FVector(0, -20, 10)
                local defaultScale = FVector(6.5, 7, 1)
                print("[AddOutfit] GetChassisLightLocAndScale fallback defaults for vehicleId:" .. tostring(vehicleId))
                return defaultLoc, defaultScale
            end
            print("[AddOutfit] VehiclePlateLicenseUtil chassis hook installed")
        end

        local function hookServerChangeVehicleAvatar(pc)
            if not pc or not slua.isValid(pc) then return end
            if pc._lava_hooked_server_vehicle_skin then return end
            if not pc.ServerChangeVehicleAvatar then return end
            pc._lava_hooked_server_vehicle_skin = true
            local orig = pc.ServerChangeVehicleAvatar
            local hooked = function(self, resID)
                pcall(function()
                    local char = self:GetPlayerCharacterSafety()
                    if char and slua.isValid(char) then
                        local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
                        if vehicle and slua.isValid(vehicle) then
                            local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                            if avatarComp and slua.isValid(avatarComp) then
                                if avatarComp.SetVehicleNetAvatarData then
                                    avatarComp:SetVehicleNetAvatarData(self)
                                end
                                if avatarComp.VehicleNetAvatarData then
                                    avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                                    avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                                end
                                avatarComp:ChangeItemAvatar(resID, true)
                                avatarComp.CanChangeAvatar = true
                                _lastVehicleSkinKey = ""
                                print("[AddOutfit] Vehicle skin changed locally to " .. tostring(resID))
                                pcall(applyVehicleChassisLight)
                            end
                        end
                    end
                end)
            end
            pcall(function() rawset(pc, "ServerChangeVehicleAvatar", hooked) end)
        end

        local _lava_skin_click_handler
        local function getSkinClickHandler()
            if _lava_skin_click_handler then return _lava_skin_click_handler end
            _lava_skin_click_handler = function(self)
                if self.resID > 0 then
                    local UsingID = self:GetLoopScrollBoxParentUI():GetCurUsingSkinID()
                    if self.resID ~= UsingID then
                        pcall(function()
                            local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                            local PlayerController = GameplayData.GetPlayerController()
                            if not slua.isValid(PlayerController) then return end
                            local char = PlayerController:GetPlayerCharacterSafety()
                            if not char or not slua.isValid(char) then return end
                            local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
                            if not vehicle or not slua.isValid(vehicle) then return end
                            local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                            if not avatarComp or not slua.isValid(avatarComp) then return end
                            if avatarComp.SetVehicleNetAvatarData then
                                avatarComp:SetVehicleNetAvatarData(PlayerController)
                            end
                            if avatarComp.VehicleNetAvatarData then
                                avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                                avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                            end
                            avatarComp:ChangeItemAvatar(self.resID, true)
                            avatarComp.CanChangeAvatar = true
                            _lastVehicleSkinKey = ""
                            print("[AddOutfit] VehicleSkinItem applied skin locally " .. tostring(self.resID))
                            pcall(applyVehicleChassisLight)
                        end)
                    end
                end
                if EventSystem and EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                    EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                end
            end
            return _lava_skin_click_handler
        end

        local function hookVehicleSkinItem()
            local ok, VSI = pcall(require, "GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
            if not ok or not VSI then return end
            -- VSI هو class table اللي ليه __newindex = error، لازم نعدل على __inner_impl
            local impl = VSI.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_skin_item then return end
            impl._lava_hooked_skin_item = true
            local handler = getSkinClickHandler()
            local origRegist = impl.RegistEvents
            impl.RegistEvents = function(self)
                rawset(self, "OnClickSkinButton", handler)
                return origRegist(self)
            end
            local origOnRefresh = impl.OnRefresh
            impl.OnRefresh = function(self, resID, selectIndex)
                local cur = rawget(self, "OnClickSkinButton")
                if cur ~= handler then
                    rawset(self, "OnClickSkinButton", handler)
                    pcall(function()
                        if self.UnRegistEvents and self.RegistEvents then
                            self:UnRegistEvents()
                            self:RegistEvents()
                        end
                    end)
                end
                return origOnRefresh(self, resID, selectIndex)
            end
            impl.OnClickSkinButton = handler
        end

        local function hookVehicleSkinAndMusicPanel()
            local ok, VSP = pcall(require, "GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
            if not ok or not VSP then return end
            local impl = VSP.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_panel then return end
            impl._lava_hooked_panel = true
            local orig = impl.InitSkinList
            impl.InitSkinList = function(self)
                hookVehicleSkinItem()
                return orig(self)
            end
        end

        local function syncVehicleAvatarSkinList()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return end
            hookServerChangeVehicleAvatar(pc)
            hookVehicleSkinItem()
            hookVehicleSkinAndMusicPanel()
            hookVehicleLicenseComponentBase()
            hookVehiclePlateLicenseUtil()
            if pc.bEnableFuzzyAvatarOnClient then
                pc.bEnableFuzzyAvatarOnClient = false
            end
            if not DataMgr or not DataMgr.VehicleSlotList then return end
            if not pc.InitVehicleAvatarSkinList then return end
            local vehicleSkinData = {}
            for subType, insList in pairs(DataMgr.VehicleSlotList) do
                if insList and type(insList) == "table" then
                    local itemArray = {}
                    for _, insID in ipairs(insList) do
                        insID = tonumber(insID)
                        if insID and insID > 0 then
                            local skinResID = 0
                            if isInjectedIns(insID) then
                                skinResID = R.insToRes[insID] or 0
                            else
                                pcall(function()
                                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                    local d = wd:GetHallDepotItemDataByInsID(insID)
                                    skinResID = d and tonumber(d.resID) or 0
                                end)
                            end
                            if skinResID and skinResID > 0 then
                                table.insert(itemArray, {ItemTableID = skinResID, Count = 1})
                            end
                        end
                    end
                    if #itemArray > 0 then
                        table.insert(vehicleSkinData, {Items = itemArray})
                    end
                end
            end
            if #vehicleSkinData > 0 then
                pc.InitialVehicleAvatarSkinList = vehicleSkinData
                pc:InitVehicleAvatarSkinList()
            end
        end

        local function stopMatchWatcher()
            if _S.matchTimer then
                pcall(function()
                    local char = getLocalChar()
                    if char and char.RemoveGameTimer then char:RemoveGameTimer(_S.matchTimer) end
                end)
                _S.matchTimer = nil
            end
            _S.matchOutfitDone = false
            _S.avatarItemsRegistered = false
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.lastAppliedWeaponID = 0
            _S.lastAppliedSkinID = 0
            _S.matchApplied = false
            _S.bootstrapped = false   -- إعادة ضبط bootstrap
        end

        local function bootstrapMatch(char)
            if _S.bootstrapped then return true end
            char = char or getLocalChar()
            if not char or not slua.isValid(char) then return false end
            snapshotLobbyWear()
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.matchOutfitDone = false
            if not _S.bootstrapNotified then
                _S.bootstrapNotified = true
                notify("اكتشفت شخصيتك في الماتش")
            end
            startMatchWatcher(char)
            hookPlayerWearingDone()
            matchApplyAll(char)
            _S.bootstrapped = true
            return true
        end

        local function isSelfAvatarComp(self)
            if not self or not self.IsSelf then return true end
            local ok, r = pcall(function() return self:IsSelf() end)
            return ok and r == true
        end

        local function hookMatchAvatar()
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_PLAYEREVENT_AVATAR and EVENTID_LOCAL_PLAYEREVENT_AVATAR_ALL_MESH_LOADED then
                    EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_AVATAR, EVENTID_LOCAL_PLAYEREVENT_AVATAR_ALL_MESH_LOADED, function()
                        if isInLobby() then return end
                        local char = getLocalChar()
                        if char then
                            hookPlayerWearingDone()
                            applyMatchEquipAvatarToController()
                            matchApplyEquipSkins(char)
                        end
                    end)
                end
            end)
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if not CAC._lava_hooked_mesh then
                    CAC._lava_hooked_mesh = true
                    local o = CAC.OnAvatarAllMeshLoadedLua
                    CAC.OnAvatarAllMeshLoadedLua = function(self)
                        o(self)
                        pcall(function()
                            if self.IsLobbyActor and self:IsLobbyActor() then return end
                            if not (self.IsSelf and self:IsSelf()) then return end
                            local char = getLocalChar()
                            if char and char.AddGameTimer then
                                char:AddGameTimer(0.5, false, function() bootstrapMatch(char) end)
                            end
                        end)
                    end
                end
            end)
            pcall(function()
                local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
                local oLoad = WAC.OnWeaponAvatarLoadedLua
                WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
                    oLoad(self, slotID, definedID)
                    pcall(function()
                        if self.IsLobbyActor and self:IsLobbyActor() then return end
                        if not isSelfAvatarComp(self) then return end
                        if _S.globalFrame < _S.weaponHookGuardUntil then return end
                        local char = getLocalChar()
                        if not char then return end
                        bootstrapMatch(char)
                        _S.weaponApplied = false
                        if char.AddGameTimer then
                            char:AddGameTimer(0.2, false, function()
                                local c = getLocalChar()
                                if c then matchApplyWeaponSkin(c) end
                            end)
                            -- Extra delayed pass for attachment skins
                            char:AddGameTimer(0.5, false, function()
                                local c = getLocalChar()
                                if c then matchApplyWeaponSkin(c) end
                            end)
                        end
                    end)
                end
            end)
        end

        local function onWeaponLuaInit(_, _, weapon)
            if not weapon or not slua.isValid(weapon) then return end
            local char = getLocalChar()
            if not char then return end
            local owner = nil
            pcall(function() if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end end)
            if not slua.isValid(owner) or owner ~= char then return end
            if _S.globalFrame < _S.weaponHookGuardUntil then return end
            pcall(function()
                char:AddGameTimer(0.15, false, function()
                    if slua.isValid(weapon) then
                        applySkinToWeaponRef(weapon)
                        _S.weaponApplied = false
                    end
                end)
                -- Extra delayed pass for attachment skins
                char:AddGameTimer(0.5, false, function()
                    if slua.isValid(weapon) then
                        applySkinToWeaponRef(weapon)
                    end
                end)
            end)
        end

        local function hookWeaponSpawn()
            if _S.weaponSpawnHooked then return end
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
                    EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
                    _S.weaponSpawnHooked = true
                end
            end)
        end

        local function hookLobbyWeaponCache()
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                local oRsp = Arm.install_weapon_skin_rsp
                Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
                    oRsp(client_data, errorCode, weapon_id, instanceID)
                    if errorCode == 0 or errorCode == _K.NET_OK then
                        cacheWeaponSkinFromIns(weapon_id, instanceID)
                    end
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local o = wl.on_puton_rsp
                wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
                    o(self, res, item, olditem, index, extra)
                    if item and item.instid and (res == 0 or res == _K.NET_OK) then
                        local resID, insID = tonumber(item.res_id), tonumber(item.instid)
                        local slot = getEquipSkinSlot(resID)
                        if isInjectedIns(insID) and slot and not _S.equipSkinApplying then
                            saveEquipSkin(resID, insID)
                            if slot ~= "parachute" and slot ~= "glider" then
                                applyEquipVisual(resID, insID, slot)
                            end
                        elseif isInjectedIns(insID) then
                            local mt = wardrobeMainTab(resID)
                            if mt ~= _K.WARDROBE_PAGE_VEHICLE then
                                if isThrowObjectRes(resID) then
                                    saveThrowObject(resID, insID)
                                else
                                    saveEquip(resID, insID)
                                end
                            end
                        end
                    end
                end
            end)
        end

-- @IG_Serioton
        local function hookGunWardrobe()
            pcall(function()
                local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                if wgl._lava_gun_hooked then return end
                wgl._lava_gun_hooked = true

                local origSetGunID = wgl.SetGunID
                wgl.SetGunID = function(self, weaponID, ...)
                    weaponID = tonumber(weaponID)
                    if not weaponID then return origSetGunID(self, weaponID, ...) end

                    local w = cache().weapons[weaponID]
                    local injected = w and w.insID and w.insID > 0 and isInjectedIns(w.insID)
-- @IG_Serioton
                    local currentSkin = wgl.GetCurrentEquippedSkinInsID and wgl:GetCurrentEquippedSkinInsID(weaponID) or 0
                    if injected and currentSkin == w.insID then
-- @IG_Serioton
                        return origSetGunID(self, weaponID, ...)
                    end

                    if injected then
                        pcall(function()
                            local Arm = require("client.logic.armory.logic_armory")
                            Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
                            Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
                            Arm.rsp_list.install_list[weaponID] = { skin_id = w.insID }
                            
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            if fbd.UpdateCurrentFashionBagWeaponSkin then
                                fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, w.insID)
                            end
                            if fbd.SetFashionBagWeaponSkin then
                                fbd:SetFashionBagWeaponSkin(weaponID, w.insID)
                            end
                        end)
                    else
-- @IG_Serioton
                        pcall(function()
                            local Arm = require("client.logic.armory.logic_armory")
                            if Arm.rsp_list and Arm.rsp_list.install_list then
                                Arm.rsp_list.install_list[weaponID] = nil
                            end
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            if fbd.UpdateCurrentFashionBagWeaponSkin then
                                fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, 0)
                            end
                            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                            if bag and bag.weapon_skin_list then
                                bag.weapon_skin_list[weaponID] = nil
                            end
                        end)
                    end

                    local result = origSetGunID(self, weaponID, ...)

                    if injected then
                        later(0.05, function()
                            pcall(function()
                                local wgl2 = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                wgl2:UpdateCurrentGunAvatar(weaponID, w.insID)
                                
                                if EventSystem then
                                    if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, w.resID)
                                    end
                                    if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
                                    end
                                    if EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                                        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, w.resID)
                                    end
                                end
                            end)
                        end)
-- @IG_Serioton
                    else
-- @IG_Serioton
                        later(0.05, function()
                            pcall(function()
                                local wgl2 = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                wgl2:UpdateCurrentGunAvatar(weaponID, 0)
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, 0)
                                end
                                if EventSystem and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, weaponID)
                                end
                            end)
                        end)
                        log("إزالة سكن السلاح", weaponID)
                    end
                    
                    return result
                end

                local origUpdateGunAvatar = wgl.UpdateCurrentGunAvatar
                wgl.UpdateCurrentGunAvatar = function(self, weaponID, insID, ...)
                    weaponID = tonumber(weaponID)
                    insID = tonumber(insID)
                    if weaponID and (not insID or insID <= 0) then
                        local w = cache().weapons[weaponID]
                        if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                            insID = w.insID
                            log("UpdateCurrentGunAvatar: استخدام سكن محفوظ", weaponID, insID)
                        else
                            insID = 0
                        end
                    end
                    return origUpdateGunAvatar(self, weaponID, insID, ...)
                end

                if wgl.GetCurrentEquippedSkinInsID then
                    local origGetCurSkin = wgl.GetCurrentEquippedSkinInsID
                    wgl.GetCurrentEquippedSkinInsID = function(self, weaponID, ...)
                        weaponID = tonumber(weaponID)
                        if weaponID then
                            local w = cache().weapons[weaponID]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                        end
                        return origGetCurSkin(self, weaponID, ...)
                    end
                end

                if wgl.GetGunSkinInsID then
                    local origGetGunSkin = wgl.GetGunSkinInsID
                    wgl.GetGunSkinInsID = function(self, weaponID, ...)
                        weaponID = tonumber(weaponID)
                        if weaponID then
                            local w = cache().weapons[weaponID]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                        end
                        return origGetGunSkin(self, weaponID, ...)
                    end
                end

                log("hookGunWardrobe: تم")
            end)
        end

        -- ========== Collection Ace Eliminator Broadcast (619150001) ==========
        local ELIMINATION_KING_EFFECT_ID = 619150001

        -- ========== Last Strike Champion Final Kill Effect (61950002) ==========
        local FINAL_KILL_EFFECT_ID = 61950002

        local function getLocalPlayerKey()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerState then
                local ps = GD.GetPlayerState()
                if ps and slua.isValid(ps) and ps.PlayerKey then
                    return tonumber(ps.PlayerKey)
                end
            end
            return nil
        end

        local function getLocalUID()
            local uid
            pcall(function()
                local Subsystem = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
                local AccountSubsystem = Subsystem:Get("AccountSubsystem")
                if AccountSubsystem and AccountSubsystem.GetAccountUID then
                    uid = AccountSubsystem:GetAccountUID()
                end
            end)
            if not uid then
                pcall(function()
                    local GD = require("GameLua.GameCore.Data.GameplayData")
                    local ps = GD.GetPlayerState()
                    if ps and slua.isValid(ps) and ps.UID then
                        uid = tonumber(ps.UID)
                    end
                end)
            end
            return uid
        end

        local function hookEliminationKingEffect()
            if not _skOn("ALL_SKIN") then return end
            if _G._lava_hooked_elim_king then return end
            _G._lava_hooked_elim_king = true

            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                if CommerAvatarDataUtil._lava_hooked_ext_attr then return end
                CommerAvatarDataUtil._lava_hooked_ext_attr = true

                local ExtendAttribute = require("Server.config.ExtendAttribute")
                local origGetAttr = CommerAvatarDataUtil.GetPlayerExtendAttributeAndTest
                CommerAvatarDataUtil.GetPlayerExtendAttributeAndTest = function(self, UID, attr)
                    if attr == ExtendAttribute.EliminationKingEffect then
                        local localUID = getLocalUID()
                        if localUID and tonumber(UID) == tonumber(localUID) then
                            return ELIMINATION_KING_EFFECT_ID
                        end
                    end
                    return origGetAttr(self, UID, attr)
                end
                log("hookEliminationKingEffect: CommerAvatarDataUtil hooked")
            end)

            pcall(function()
                local KillInfoClass = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
                local impl = KillInfoClass.__inner_impl
                if not impl or impl._lava_hooked_show_king then return end
                impl._lava_hooked_show_king = true

                local origShow = impl.ShowKingEliminationInfo
                impl.ShowKingEliminationInfo = function(self, DamageRecordData)
                    local localKey = getLocalPlayerKey()
                    if localKey and DamageRecordData and DamageRecordData.ExpandDataContent then
                        pcall(function()
                            local FatalDamageInfo = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent)
                            if FatalDamageInfo and FatalDamageInfo.KingEliminationInfo then
                                local KingEliminationInfo = FatalDamageInfo.KingEliminationInfo
                                if KingEliminationInfo.NewKingEliminationInfo then
                                    local info = KingEliminationInfo.NewKingEliminationInfo
                                    if tonumber(info.PlayerKey) == localKey then
                                        info.EffectID = ELIMINATION_KING_EFFECT_ID
                                        log("hookEliminationKingEffect: injected EffectID into NewKingEliminationInfo")
                                    end
                                end
                                if KingEliminationInfo.DeadKingEliminationInfo then
                                    local info = KingEliminationInfo.DeadKingEliminationInfo
                                    if tonumber(info.KillerPlayerKey) == localKey then
                                        info.EffectID = ELIMINATION_KING_EFFECT_ID
                                        log("hookEliminationKingEffect: injected EffectID into DeadKingEliminationInfo")
                                    end
                                end
                            end
                        end)
                    end
                    return origShow(self, DamageRecordData)
                end
                log("hookEliminationKingEffect: KillInfo.ShowKingEliminationInfo hooked")
            end)

            pcall(function()
                local KingEliminationInfoItemClass = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KingEliminationInfoItem")
                local impl = KingEliminationInfoItemClass.__inner_impl
                if not impl or impl._lava_hooked_update then return end
                impl._lava_hooked_update = true

                local origUpdate = impl.UpdateKingEliminationInfo
                impl.UpdateKingEliminationInfo = function(self, DamageRecordData, KingEliminationInfo)
                    local localKey = getLocalPlayerKey()
                    if localKey and KingEliminationInfo then
                        if KingEliminationInfo.NewKingEliminationInfo then
                            local info = KingEliminationInfo.NewKingEliminationInfo
                            if tonumber(info.PlayerKey) == localKey then
                                info.EffectID = ELIMINATION_KING_EFFECT_ID
                            end
                        end
                        if KingEliminationInfo.DeadKingEliminationInfo then
                            local info = KingEliminationInfo.DeadKingEliminationInfo
                            if tonumber(info.KillerPlayerKey) == localKey then
                                info.EffectID = ELIMINATION_KING_EFFECT_ID
                            end
                        end
                    end
                    return origUpdate(self, DamageRecordData, KingEliminationInfo)
                end
                log("hookEliminationKingEffect: KingEliminationInfoItem hooked")
            end)

            pcall(function()
                local PlayerStateBaseClass = require("GameLua.GameCore.Framework.PlayerStateBase")
                local impl = PlayerStateBaseClass.__inner_impl
                if not impl or impl._lava_hooked_init_team then return end
                impl._lava_hooked_init_team = true

                local origInit = impl.InitTeamShowData
                impl.InitTeamShowData = function(self, ...)
                    origInit(self, ...)
                    pcall(function()
                        local localUID = getLocalUID()
                        if localUID and self.UID and tonumber(self.UID) == tonumber(localUID) then
                            self.EliminationKingEffectID = ELIMINATION_KING_EFFECT_ID
                        end
                    end)
                end
                log("hookEliminationKingEffect: PlayerStateBase hooked")
            end)
        end

        local function tickEliminationKingEffect()
            pcall(function()
                local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
                if ok and GD and GD.GetPlayerState then
                    local ps = GD.GetPlayerState()
                    if ps and slua.isValid(ps) then
                        if not ps.EliminationKingEffectID or ps.EliminationKingEffectID == 0 then
                            ps.EliminationKingEffectID = ELIMINATION_KING_EFFECT_ID
                        end
                    end
                end
            end)
        end

        -- ========== Last Strike Champion Final Kill Effect (61950002) ==========
        local function hookFinalKillEffect()
            if not _skOn("ALL_SKIN") then return end
            if _G._lava_hooked_final_kill then return end
            _G._lava_hooked_final_kill = true

            -- 1. Hook FinalKillEffectLevelSequenceActor to handle missing config for 61950002
            -- If config doesn't exist or Sequence is empty, directly call OnPlay callback
            pcall(function()
                local LSActor = require("GameLua.Mod.Library.GamePlay.Actor.FinalKillEffectLevelSequenceActor")
                if LSActor._lava_hooked then return end
                LSActor._lava_hooked = true

                local origBeginPlay = LSActor.ReceiveBeginPlay
                if origBeginPlay then
                    LSActor.ReceiveBeginPlay = function(self)
                        if self.ItemId == FINAL_KILL_EFFECT_ID then
                            local Config = CDataTable.GetTableData("FinalKillEffectCfg", self.ItemId)
                            if not Config or not Config.Sequence or Config.Sequence == "" then
                                log("hookFinalKillEffect: no sequence for 61950002, calling OnPlay directly")
                                if self.Callback and self.Callback.OnPlay then
                                    self.Callback.OnPlay()
                                end
                                return
                            end
                        end
                        return origBeginPlay(self)
                    end
                    log("hookFinalKillEffect: FinalKillEffectLevelSequenceActor hooked")
                end
            end)

            -- 2. Hook TriggerParticleEffect to force ItemId = 61950002
            pcall(function()
                local Feature = require("GameLua.Mod.BaseMod.GamePlay.Feature.Player.PlayerCharacterFinalKillEffectFeature")
                if Feature._lava_hooked_fke then return end
                Feature._lava_hooked_fke = true

                local origTriggerParticle = Feature.TriggerParticleEffect
                if origTriggerParticle then
                    Feature.TriggerParticleEffect = function(self, ItemId, Location, Rotator, TeamMemberNames)
                        log("hookFinalKillEffect: TriggerParticleEffect called, ItemId=" .. tostring(ItemId) .. " forcing to " .. tostring(FINAL_KILL_EFFECT_ID))
                        return origTriggerParticle(self, FINAL_KILL_EFFECT_ID, Location, Rotator, TeamMemberNames)
                    end
                end

                local origPrepareItem = Feature.PrepareItem
                if origPrepareItem then
                    Feature.PrepareItem = function(self, ItemId)
                        log("hookFinalKillEffect: PrepareItem called, ItemId=" .. tostring(ItemId) .. " forcing to " .. tostring(FINAL_KILL_EFFECT_ID))
                        return origPrepareItem(self, FINAL_KILL_EFFECT_ID)
                    end
                end
                log("hookFinalKillEffect: PlayerCharacterFinalKillEffectFeature hooked")
            end)

            -- 3. Direct client-side trigger when game ends
            local function triggerFinalKillEffect()
                pcall(function()
                    local char = getLocalChar()
                    if not char or not slua.isValid(char) then
                        log("hookFinalKillEffect: char not valid")
                        return
                    end

                    if _G._lava_fke_triggered then return end
                    _G._lava_fke_triggered = true

                    char:EnsureDynamicFeature("FinalKillEffect")
                    if not char.FinalKillEffect then
                        log("hookFinalKillEffect: FinalKillEffect feature not available")
                        return
                    end

                    local Location = char:K2_GetActorLocation()
                    local Rotator = FRotator(0, 0, 0)
                    local Names = char.PlayerName or ""

                    log("hookFinalKillEffect: triggering effect 61950002")
                    char.FinalKillEffect:TriggerParticleEffect(FINAL_KILL_EFFECT_ID, Location, Rotator, Names)
                end)
            end

            -- 3a. Hook BattleResult.on_game_result (global function, client-side)
            pcall(function()
                if BattleResult and BattleResult.on_game_result and not BattleResult._lava_hooked_fke then
                    BattleResult._lava_hooked_fke = true
                    local origOnGameResult = BattleResult.on_game_result
                    BattleResult.on_game_result = function(battle_result, result)
                        log("hookFinalKillEffect: BattleResult.on_game_result triggered")
                        triggerFinalKillEffect()
                        return origOnGameResult(battle_result, result)
                    end
                    log("hookFinalKillEffect: BattleResult.on_game_result hooked")
                end
            end)

            -- 3b. Hook BattleResult.on_game_over (global function, client-side)
            pcall(function()
                if BattleResult and BattleResult.on_game_over and not BattleResult._lava_hooked_fke_over then
                    BattleResult._lava_hooked_fke_over = true
                    local origOnGameOver = BattleResult.on_game_over
                    BattleResult.on_game_over = function(game_id)
                        log("hookFinalKillEffect: BattleResult.on_game_over triggered")
                        triggerFinalKillEffect()
                        return origOnGameOver(game_id)
                    end
                    log("hookFinalKillEffect: BattleResult.on_game_over hooked")
                end
            end)

            -- 3c. Also register for the event as backup (with nil checks)
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_STATE and EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT
                    and not _G._lava_fke_event_registered then
                    _G._lava_fke_event_registered = true
                    EventSystem:registEvent(EVENTTYPE_STATE, EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT, triggerFinalKillEffect)
                    log("hookFinalKillEffect: registered for EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT")
                end
            end)

            log("hookFinalKillEffect: done")
        end

-- @IG_Serioton
        -- ===================================================================
        -- SECURITY: ANTI-CHEAT BYPASS (from 2.lua Section 19)
        -- ===================================================================
        local function hookSecurityBypass()
            -- 1. Disable puffer download reporting
            pcall(function()
                local pufferTlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
                if pufferTlog then
                    pufferTlog.ReportEvent = function() end
                    pufferTlog.ReportDownloadResult = function() end
                    pufferTlog.ReportODPAKError = function() end
                end
            end)

            -- 2. Bypass AvatarUtils weapon blacklist
            pcall(function()
                local AvatarUtils = package.loaded["AvatarUtils"]
                if AvatarUtils then
                    AvatarUtils.CheckIsWeaponInBlackList = function() return false end
                    AvatarUtils.IsValidAvatar = function() return true end
                end
            end)

            -- 3. Disable file integrity checking
            pcall(function()
                local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
                if SubsystemMgr then
                    local FileCheckSubsystem = SubsystemMgr:Get("FileCheckSubsystem")
                    if FileCheckSubsystem then
                        FileCheckSubsystem.StartCheck = function() end
                        FileCheckSubsystem.ReportAbnormalFile = function() end
                    end
                end
            end)

            -- 4. Disable equipment exception reporting
            pcall(function()
                local equipReport = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
                if equipReport then
                    equipReport.Report = function() end
                end
            end)

            -- 5. Disable puffer download validation
            pcall(function()
                local pufferManager = require("client.slua.logic.download.puffer.puffer_manager")
                local pufferConst = require("client.slua.logic.download.puffer_const")
                if pufferManager and pufferConst then
                    local origCheck = pufferManager.CheckResourceValid
                    if origCheck then
                        pufferManager.CheckResourceValid = function(...) return true end
                    end
                end
            end)

            -- 6. Bypass avatar hash verification
            pcall(function()
                local AvatarUtils = package.loaded["AvatarUtils"]
                if AvatarUtils then
                    local origVerify = AvatarUtils.VerifyAvatarData
                    if origVerify then
                        AvatarUtils.VerifyAvatarData = function(...) return true end
                    end
                end
            end)

            print("[AddOutfit] Security bypass installed")
        end

        -- ===================================================================
        -- KILL MESSAGE SYSTEM (from 2.lua Section 17)
        -- Injects weapon skin + outfit skin + golden color into kill feed
        -- ===================================================================
        local _killCounterHooked = false
        local _safeRequireCache = {}
        local function safeRequire(name)
            if _safeRequireCache[name] then return _safeRequireCache[name] end
            local loaded = package.loaded[name]
            if loaded then _safeRequireCache[name] = loaded; return loaded end
            local ok, mod = pcall(require, name)
            if ok and mod then _safeRequireCache[name] = mod; return mod end
            return nil
        end

        _G.AKFakeKillCounts = _G.AKFakeKillCounts or setmetatable({}, { __index = function() return 0 end })

        local function pushKillCounterUpdate(weaponID, skinID, killCount)
            pcall(function()
                local UIManager = safeRequire("client.slua_ui_framework.manager")
                if not UIManager then return end
                local killCounterUI = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if not killCounterUI or not killCounterUI.UpdateWeaponID then return end
                local avatarSkinID = skinID or weaponID
                killCounterUI:UpdateWeaponID(weaponID, avatarSkinID)
                local ModuleManager = safeRequire("client.module_framework.ModuleManager")
                if ModuleManager then
                    local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                    if kcLogic and kcLogic.GetEquipedKillCounterId then
                        local equippedKCId = kcLogic:GetEquipedKillCounterId(0, avatarSkinID)
                        if killCounterUI.SetKillCounterItemShowWithNum then
                            killCounterUI:SetKillCounterItemShowWithNum(equippedKCId, killCount, avatarSkinID)
                        end
                    end
                end
            end)
        end

        local function hookKillMessages()
            if _killCounterHooked then return end
            local anyHooked = false

            -- 1. Kill Counter UI hooks
            pcall(function()
                local KillCounterUI = safeRequire("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
                if KillCounterUI and KillCounterUI.__inner_impl then
                    local impl = KillCounterUI.__inner_impl
                    impl.CheckSupportKCUI = function() return true end
                    impl.CheckNeedMainKillCounterUI = function(self, weapon, PlayerID)
                        if slua.isValid(weapon) then
                            local weaponID = weapon:GetWeaponID()
                            local skinID = _G.get_skin_id and _G.get_skin_id(weaponID) or weaponID
                            self:UpdateMainKillCounterUI(true, weaponID, skinID)
                            pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID] or 0)
                        else
                            self:UpdateMainKillCounterUI(false)
                        end
                    end
                    local origUpdate = impl.UpdateMainKillCounterUI
                    impl.UpdateMainKillCounterUI = function(self, bShow, weaponID, AvatarID)
                        if bShow then
                            AvatarID = _G.get_skin_id and _G.get_skin_id(weaponID) or AvatarID
                        end
                        if origUpdate then origUpdate(self, bShow, weaponID, AvatarID) end
                        if bShow then
                            pushKillCounterUpdate(weaponID, AvatarID, _G.AKFakeKillCounts[weaponID] or 0)
                        end
                    end
                    anyHooked = true
                end
            end)

            -- 2. Kill Counter Logic hooks
            pcall(function()
                local ModuleManager = safeRequire("client.module_framework.ModuleManager")
                if ModuleManager then
                    local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                    if kcLogic then
                        kcLogic.CheckSupportKC = function() return true end
                        kcLogic.CheckSupportKillCounterAvatar = function() return true end
                        kcLogic.CheckHasWeaponKillCounter = function() return true end
                        kcLogic.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                        kcLogic.GetEquipedKillCounterId = function() return 2100004 end
                        kcLogic.GetMyEquipedKillCounterId = function() return 2100004 end
                        kcLogic.GetOneWeaponKillCountInBattle = function(self, uid, weaponId)
                            return _G.AKFakeKillCounts[weaponId] or 0
                        end
                        kcLogic.GetWeaponKillCountByUid = function(self, uid, weaponId)
                            return _G.AKFakeKillCounts[weaponId] or 0
                        end
                        anyHooked = true
                    end
                end
            end)

            -- 3. Kill Info Message hook (inject skin + color into kill feed)
            pcall(function()
                local KillInfo = safeRequire("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
                if KillInfo and KillInfo.__inner_impl then
                    local origFileItem = KillInfo.__inner_impl.FileItem
                    KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                        pcall(function()
                            local GD = safeRequire("GameLua.GameCore.Data.GameplayData")
                            if not GD then return end
                            local playerChar = GD.GetPlayerCharacter()
                            if not playerChar or not slua.isValid(playerChar) then return end
                            -- Only modify YOUR kill messages
                            if DamageRecordData.Causer ~= playerChar:GetPlayerNameSafety() then return end
                            local currentWeapon = playerChar:GetCurrentWeapon()
                            if not slua.isValid(currentWeapon) then return end
                            local weaponID = currentWeapon:GetWeaponID()
                            local skinID = _G.get_skin_id and _G.get_skin_id(weaponID) or weaponID
                            -- Inject weapon skin into kill message
                            if skinID then
                                DamageRecordData.CauserWeaponAvatarID = skinID
                            end
                            -- Inject outfit skin into kill message
                            if _G.SuitSkin and _G.SuitSkin ~= 0 then
                                DamageRecordData.CauserClothAvatarID = _G.SuitSkin
                            end
                            -- Golden name color
                            DamageRecordData.IsUseColor = true
                            DamageRecordData.UseColor = import("LinearColor")(1.0, 0.8, 0.0, 1.0)
                            -- Track kill count
                            if DamageRecordData.ResultHealthStatus == 2 then
                                _G.AKFakeKillCounts[weaponID] = (_G.AKFakeKillCounts[weaponID] or 0) + 1
                                pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID])
                            end
                        end)
                        if origFileItem then return origFileItem(self, DamageRecordData) end
                    end
                    anyHooked = true
                end
            end)

            -- 4. Weapon Slot Mode 2 - Kill Counter Icon
            pcall(function()
                local SlotMode2 = safeRequire("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
                if SlotMode2 and SlotMode2.__inner_impl then
                    local origCheck = SlotMode2.__inner_impl.CheckShowKCIcon
                    SlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                        if self.KillCounterImg and slua.isValid(self.KillCounterImg) then
                            self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible)
                        end
                        if origCheck then return origCheck(self) end
                    end
                    local origShow = SlotMode2.__inner_impl.ShowKCIcon
                    if origShow then
                        SlotMode2.__inner_impl.ShowKCIcon = function(self, weaponID, skinID)
                            local cnt = _G.AKFakeKillCounts[weaponID] or 0
                            if origShow then origShow(self, weaponID, skinID) end
                            if cnt > 0 then
                                pcall(function()
                                    if self.KillCounterImg and self.KillCounterImg.SetKillCount then
                                        self.KillCounterImg:SetKillCount(cnt)
                                    end
                                end)
                            end
                        end
                    end
                    anyHooked = true
                end
            end)

            if anyHooked then _killCounterHooked = true end
        end

        -- 5. Refresh kill counter for current weapon
        _G.RefreshKillCounterUI = function()
            pcall(function()
                local GD = safeRequire("GameLua.GameCore.Data.GameplayData")
                if not GD then return end
                local pc = GD.GetPlayerController()
                if not pc or not slua.isValid(pc) then return end
                local lp = pc:GetPlayerCharacterSafety()
                if not lp or not slua.isValid(lp) then return end
                local cw = lp:GetCurrentWeapon()
                if not slua.isValid(cw) then return end
                local wID = cw:GetWeaponID()
                if not wID or wID == 0 then return end
                local sid = _G.get_skin_id and _G.get_skin_id(wID)
                if not sid then
                    local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
                    if KCUI and KCUI.__inner_impl then
                        KCUI.__inner_impl:UpdateMainKillCounterUI(false)
                    end
                    return
                end
                local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
                if KCUI and KCUI.__inner_impl then
                    KCUI.__inner_impl:UpdateMainKillCounterUI(true, wID, sid)
                end
                pushKillCounterUpdate(wID, sid, _G.AKFakeKillCounts[wID] or 0)
            end)
        end

        _G.ForceEnableKillCounterUI = function()
            hookKillMessages()
            _G.RefreshKillCounterUI()
        end

        -- ===================================================================
        -- TEAM BROADCAST KILL MESSAGES (v1.1)
        -- Shows weapon skin / vehicle skin in team kill notifications
        -- ===================================================================
        local _teamBroadcastHooked = false
        local function hookTeamBroadcast()
            if _teamBroadcastHooked then return end
            pcall(function()
                local BattleKillBroadcastSubSystem = require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem")
                if not BattleKillBroadcastSubSystem then return end
                local O_CopyKillOrPutDownMessageDataUserDataToLuaTable = BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable
                if not O_CopyKillOrPutDownMessageDataUserDataToLuaTable then return end
                BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
                    local msgData = O_CopyKillOrPutDownMessageDataUserDataToLuaTable(self, messageData)
                    if not msgData or not msgData.bIamCauser then return msgData end
                    pcall(function()
                        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                        if not pc then return end
                        local uCharacter = pc:GetPlayerCharacterSafety()
                        if not uCharacter or not slua.isValid(uCharacter) then return end
                        if msgData.DamageType == UEnums.DamageType.VehicleDamage then
                            -- Vehicle kill: inject vehicle skin
                            local carSkinID = _G.CurrentEquipVehicleID
                            if carSkinID and carSkinID ~= 0 then
                                local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                ExpandData.CauserVehicleSkinID = carSkinID
                                ExpandData.CauserWeaponAvatarID = carSkinID
                                msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        else
                            -- Weapon kill: inject weapon skin
                            local currWeapon = uCharacter:GetCurrentWeapon()
                            if currWeapon and slua.isValid(currWeapon) then
                                local synData = currWeapon.synData
                                if synData and slua.isValid(synData) then
                                    local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                    if weaponDefineID and slua.isValid(weaponDefineID) then
                                        local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                        ExpandData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                                    end
                                end
                            end
                        end
                    end)
                    return msgData
                end
                _teamBroadcastHooked = true
                print("[AddOutfit] Team broadcast kill messages hooked")
            end)
        end

        

                local function start()
            log("AddOutfit Merged start")
            -- Security bypass first
            pcall(hookSecurityBypass)
            -- Kill message system
            pcall(hookKillMessages)
            -- Team broadcast kill messages (v1.1)
            pcall(hookTeamBroadcast)
            buildSkinMappings()
            pcall(restorePersistedVehicles)
            pcall(restorePersistedMotions)
            pcall(restorePersistedEquipIns)
            pcall(restorePersistedThrowObjects)
            pcall(restorePersistedHallTheme)
            pcall(syncMatchConfigFromCache)
            hookCDataTableCache()
            hookDepotInit()
            hookWardrobeData()
            hookPageFilter()
            hookArmory()
            hookPutOn()
            hookLobbyTheme()
            hookMotionEquip()
            hookIngameEmote()
            hookFashionBag()
            hookBackpackValid()
            hookAvatarValid()
            hookEquipMapping()
            hookLobbyWeaponCache()
            hookGunWardrobe()
            hookLobbySwipePersistence()
            hookMatchAvatar()
            hookMatchAvatarData()
            hookGrenadeAvatarInit()
            hookGrenadeAvatarLookup()
            hookProjectileGrenadeAvatar()
            hookWeaponSpawn()
            hookVehicleLicenseComponentBase()
            hookVehiclePlateLicenseUtil()
            hookBackpackWeaponAvatarRes()
            hookEliminationKingEffect()
            hookFinalKillEffect()

            if injectAllSources() then
                refreshWardrobe()
                later(1.0, reapplyLobbyEquipped)
            else
                local tries = 0
                local function retry()
                    tries = tries + 1
                    if injectAllSources() then
                        refreshWardrobe()
                        later(1.0, reapplyLobbyEquipped)
                        return
                    end
                    if tries < 40 then later(1.5, retry) end
                end
                later(1.5, retry)
            end

            pcall(function()
                if isInGamePlay() then
                    local char = getLocalChar()
                    if char then bootstrapMatch(char) end
                elseif isInLobby() then
                    snapshotLobbyWear()
                end
            end)
        end

        hookBackpackValid()
        hookEquipMapping()
        hookMatchAvatar()
        hookMatchAvatarData()
        hookGrenadeAvatarInit()
        hookGrenadeAvatarLookup()
        hookProjectileGrenadeAvatar()
        hookWeaponSpawn()
        hookBackpackWeaponAvatarRes()
        hookEliminationKingEffect()
        hookFinalKillEffect()
        pcall(_loadEquippedCache)
        start()
        pcall(hookVehicleSkinAndMusicPanel)

        -- Time-based application loop (replaces frame-based tick listener)
        -- Uses os.clock() for time tracking instead of frame counting
        local _lastTickTime = os.clock()
        local _timeCount = 0
        
        -- Periodic application functions with different rates
        local function fastApplyLoop()
            if not _skOn("ALL_SKIN") then return end
            pcall(function()
                _timeCount = _timeCount + 1
                _S.globalFrame = _timeCount
                -- Refresh kill counter UI periodically
                if _timeCount % 3 == 0 and _killCounterHooked then
                    pcall(function()
                        if _G.RefreshKillCounterUI then _G.RefreshKillCounterUI() end
                    end)
                end
                if isInLobby() then
                    if _timeCount % 10 == 0 then
                        pcall(snapshotLobbyWear)
                    end
                    if _timeCount % 5 == 0 then
                        pcall(_G.AddOutfitTryFlushSave)
                    end
                end
                if isInGamePlay() then
                    local char = getLocalChar()
                    local charValid = char and slua.isValid(char)
                    if not _S.matchTimer and charValid then
                        bootstrapMatch(char)
                    end
                    if _timeCount % 5 == 0 and charValid then
                        pcall(function()
                            local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
                            if slua.isValid(curWeapon) then
                                applySkinToWeaponRef(curWeapon)
                            end
                            equip_weapon_avatar(char)
                            if not _S.matchOutfitDone then
                                _S.matchOutfitDone = matchApplyOutfit(char)
                            end
                            matchApplyEquipSkins(char)
                            applyGrenadeSkinsToController()
                        end)
                    end
                    if _timeCount % 5 == 0 then
                        pcall(applyVehicleSkinInGame)
                    end
                end
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(1.0, fastApplyLoop)
            end
        end
        
        -- Toggle ON karte hi turant apply (relog ki zarurat nahi)
        _G.SKIN_ApplyNow = function()
            if not _skOn("ALL_SKIN") then return end
            pcall(function()
                if isInLobby() then pcall(reapplyLobbyEquipped) end
                if isInGamePlay() then
                    local ch = getLocalChar()
                    if ch and slua.isValid(ch) then
                        pcall(matchApplyAll, ch)
                    end
                end
            end)
        end

        local function mediumLoop()
            pcall(function()
                -- Character boot check at medium rate
                if isInGamePlay() then
                    local char = getLocalChar()
                    if char and not _S.matchTimer then
                        bootstrapMatch(char)
                    end
                    pcall(tickEliminationKingEffect)
                    pcall(applyVehicleChassisLight)
                end
                if isInLobby() then
                    pcall(snapshotLobbyWear)
                end
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(2.5, mediumLoop)
            end
        end
        
        local function slowLoop()
            pcall(function()
                if isInGamePlay() then
                    pcall(syncVehicleAvatarSkinList)
                end
                pcall(_G.AddOutfitTryFlushSave)
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(5.0, slowLoop)
            end
        end
        
        -- Start all loops
        if _ticker and _ticker.AddTimerOnce then
            _ticker.AddTimerOnce(0.5, fastApplyLoop)
            _ticker.AddTimerOnce(1.0, mediumLoop)
            _ticker.AddTimerOnce(2.0, slowLoop)
        end

        -- Game status change detection via polling (cheaper than hooking events)
        local _lastGameStatus = ""
        local function statusPollLoop()
            local currentStatus = ""
            if isInLobby() then currentStatus = "lobby"
            elseif isInGamePlay() then currentStatus = "gameplay"
            else currentStatus = "other" end
            
            if currentStatus ~= _lastGameStatus then
                _lastGameStatus = currentStatus
                -- Status changed, run post-switch logic
                stopMatchWatcher()
                _S.bootstrapNotified = false
                _S.matchOutfitDone = false
                _S.lobbyApplied = false
                _G._lava_fke_triggered = nil
                pcall(function()
                    if isInLobby() then 
                        snapshotLobbyWear()
                        later(2.0, reapplyLobbyEquipped)
                    end
                end)
                pcall(function()
                    if isInGamePlay() then
                        local char = getLocalChar()
                        if char then bootstrapMatch(char) end
                    end
                end)
                pcall(_AutoSaveOutfit, true)
            end
            
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(3.0, statusPollLoop)
            end
        end
        
        if _ticker and _ticker.AddTimerOnce then
            _ticker.AddTimerOnce(1.0, statusPollLoop)
        end


        end -- initHooks

        local function prewarmModules()
            local mods = {
                "client.logic.armory.logic_armory",
                "client.slua.logic.wardrobe.fashionbag.fashionbag_data",
                "client.logic.lobby.hall_theme_utils",
                "client.slua.logic.wardrobe.logic_wardrobe_gun",
                "client.slua.logic.wardrobe.wardrobe_data",
                "client.network.Protocol.WardRobeHandler",
                "client.slua.logic.wardrobe.logic_wardrobe_avatar",
                "client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils",
                "client.logic.data.AvatarData",
                "client.slua.logic.XSuit.logic_xsuit",
                "client.slua.logic.wardrobe.logic_wardrobe_new",
                "client.slua.logic.wardrobe.logic_display_setting",
                "client.logic.avatar.logic_team_avatar_manager",
                "client.slua.logic.wardrobe.logic_wardrobe_data_center",
                "client.slua.logic.wardrobe.WardrobeDataEntity",
                "client.slua.umg.Wardrobe.subtab_item_list_base",
                "client.slua.logic.wardrobe.tab_surveillance",
                "client.network.comm.NetManager",
                "client.slua.umg.Wardrobe.wardrobe_macro",
                "client.slua.logic.avatar.avatar_common",
                "client.slua.logic.lobby.Main.Lobby_Main_Control",
                "common.time_ticker",
                "GameLua.GameCore.Module.Subsystem.SubsystemMgr",
                "GameLua.Mod.BaseMod.GamePlay.Backpack.BackpackUtils",
                "GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil",
                "GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil",
            }
            for _, m in ipairs(mods) do
                pcall(require, m)
            end
        end

        prewarmModules()
        initHooks()

        log("AddOutfit Merged loaded")
        notify("-- @IG_Serioton")
    end)
    if not _ao_ok then
        print("[AddOutfit] LOAD ERROR:", tostring(_ao_err))
    end
end
pcall(__SkinsVisualEngine)

local function startBaselineHacks()
local GameplayData=require("GameLua.GameCore.Data.GameplayData")
local EPawnState=import("EPawnState")
local UKismetSystemLibrary=import("KismetSystemLibrary")
_G.g_masterahsanyt=_G.g_masterahsanyt or "@MasterAhsanYT"
local g_masterahsanyt_credit=_G.g_masterahsanyt
local g_masterahsanyt_StartSettingsMaintenance
-- BYPASS START
-- ============================================================================
-- ============================================================================
-- Ultimate Wallhack + ESP Detection Bypass
-- Source: BRPlayerCharacterBase.lua (118 KB script) — Bypass.lua integrated
-- Auto-runs on pawn spawn, independent of login / license / expiry.
-- Wrapped with BYPASS START / BYPASS END markers for later separation.
-- ============================================================================

do -- V9.5 integration: scope helper locals below the Lua chunk limit.
local function _BYPASS_InstallUltimateWallhackBypass()
    if _G.__ULTIMATE_WH_BYPASS_LOADED then return end

    local nop = function() end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE == true
    end

    ---------- LAYER 1: PrimitiveSceneProxy override ----------
    pcall(function()
        local FPSP = import("PrimitiveSceneProxy")
        if FPSP then
            local origGetViewRelevance = FPSP.GetViewRelevance
            FPSP.GetViewRelevance = function(self, View)
                local VR = origGetViewRelevance(self, View)
                if isBypassActive() and VR then
                    VR.bRenderCustomDepth = false
                    VR.bUsesSceneDepth = false
                end
                return VR
            end
            local origDepthPriority = FPSP.GetDepthPriorityGroup
            FPSP.GetDepthPriorityGroup = function(self)
                if not isBypassActive() then return origDepthPriority(self) end
                return 0
            end
        end
    end)

    ---------- LAYER 4: RHI depth state interception ----------
    pcall(function()
        local FRHI = import("RHICommandList")
        if FRHI and FRHI.SetDepthState then
            local origSetDepth = FRHI.SetDepthState
            FRHI.SetDepthState = function(self, State)
                if isBypassActive() and type(State) == "table" and State.DepthEnable ~= nil then
                    State.DepthEnable = true
                end
                return origSetDepth(self, State)
            end
        end
    end)

    ---------- LAYER 6: Material property queries ----------
    pcall(function()
        local UMat = import("Material")
        local UMatInst = import("MaterialInstance")
        local UMatDyn = import("MaterialInstanceDynamic")

        if UMat then
            UMat.__origDDT = UMat.GetDisableDepthTest
            UMat.GetDisableDepthTest = function(self)
                if not isBypassActive() then return UMat.__origDDT(self) end
                return false
            end
            UMat.__origBM = UMat.GetBlendMode
            UMat.GetBlendMode = function(self)
                if not isBypassActive() then return UMat.__origBM(self) end
                return 0
            end
            UMat.__origHash = UMat.GetMaterialHash
            UMat.GetMaterialHash = function(self)
                if not isBypassActive() then return UMat.__origHash(self) end
                return "FAKE_HASH"
            end
            UMat.__origVM = UMat.VerifyMaterial
            UMat.VerifyMaterial = function(self)
                if not isBypassActive() then return UMat.__origVM(self) end
                return true
            end
        end
        if UMatInst then
            UMatInst.__origDDT = UMatInst.GetDisableDepthTest
            UMatInst.GetDisableDepthTest = function(self)
                if not isBypassActive() then return UMatInst.__origDDT(self) end
                return false
            end
            UMatInst.__origBM = UMatInst.GetBlendMode
            UMatInst.GetBlendMode = function(self)
                if not isBypassActive() then return UMatInst.__origBM(self) end
                return 0
            end
            UMatInst.__origBM2 = UMatInst.GetBaseMaterial
            UMatInst.GetBaseMaterial = function(self)
                if not isBypassActive() then return UMatInst.__origBM2(self) end
                return nil
            end
        end
        if UMatDyn then
            local oldGetVec = UMatDyn.K2_GetVectorParameterValue
            UMatDyn.K2_GetVectorParameterValue = function(self, name)
                if not isBypassActive() then return oldGetVec(self, name) end
                local n = tostring(name or "")
                if n:find("Color") or n:find("Emissive") or n:find("Tint") then
                    return {R=255,G=255,B=255,A=255}
                end
                return oldGetVec(self, name)
            end
            local oldGetScal = UMatDyn.K2_GetScalarParameterValue
            UMatDyn.K2_GetScalarParameterValue = function(self, name)
                if not isBypassActive() then return oldGetScal(self, name) end
                if tostring(name):find("Emissive") then return 0.0 end
                return oldGetScal(self, name)
            end
        end
    end)

    ---------- LAYER 8: Kernel & memory spoof ----------
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local kc = SubMgr:Get("ClientKernelCheckSubsystem")
            if kc and not kc.__akhooked then
                local origIKC = kc.IsKernelClean
                kc.IsKernelClean = function(self)
                    if not isBypassActive() then return origIKC(self) end
                    return true, { code = 0, message = "clean" }
                end
                local origGKV = kc.GetKernelVersion
                kc.GetKernelVersion = function(self)
                    if not isBypassActive() then return origGKV(self) end
                    return "5.4.0-generic"
                end
                kc.__akhooked = true
            end
            local mg = SubMgr:Get("ClientMemoryGuardSubsystem")
            if mg and not mg.__akhooked then
                local origIMC = mg.IsMemoryClean
                mg.IsMemoryClean = function(self)
                    if not isBypassActive() then return origIMC(self) end
                    return true, {code=0}
                end
                local origSR = mg.ScanResult
                mg.ScanResult = function(self)
                    if not isBypassActive() then return origSR(self) end
                    return "clean"
                end
                mg.__akhooked = true
            end
        end
    end)

    ---------- LAYER 9: MARK SYSTEM SPOOF ----------
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        local MarkMgr = InGameMarkTools and InGameMarkTools.ScreenMarkManager
        if MarkMgr then
            local ourMarkGroups = {1006, 9999}
            if MarkMgr.GetAllActiveMarks then
                local orig = MarkMgr.GetAllActiveMarks
                MarkMgr.GetAllActiveMarks = function(self, ...)
                    local marks = orig(self, ...)
                    if not isBypassActive() or not marks or type(marks) ~= "table" then return marks end
                    local filtered = {}
                    for _, m in ipairs(marks) do
                        if m.MarkGroupID and not table.contains(ourMarkGroups, m.MarkGroupID) then
                            table.insert(filtered, m)
                        end
                    end
                    return filtered
                end
            end
            if MarkMgr.GetMarkCount then
                local orig = MarkMgr.GetMarkCount
                MarkMgr.GetMarkCount = function(self, ...)
                    local count = orig(self, ...)
                    if isBypassActive() then count = math.max(0, count - 2) end
                    return count
                end
            end
            if MarkMgr.GetMarksByGroup then
                local orig = MarkMgr.GetMarksByGroup
                MarkMgr.GetMarksByGroup = function(self, groupId)
                    if isBypassActive() and (groupId == 1006 or groupId == 9999) then return {} end
                    return orig(self, groupId)
                end
            end
            if MarkMgr.OnAddMark then MarkMgr.OnAddMark = nop end
            if MarkMgr.OnRemoveMark then MarkMgr.OnRemoveMark = nop end
        end
    end)

    ---------- LAYER 10: REPLAY UI DETECTION KILL ----------
    pcall(function()
        if _G.Replay_IsEnemyFrameUIExisted then
            local orig = _G.Replay_IsEnemyFrameUIExisted
            _G.Replay_IsEnemyFrameUIExisted = function(...)
                if isBypassActive() then return false end
                return orig(...)
            end
        end
        if _G.Replay_CreateEnemyFrameUI then
            local orig = _G.Replay_CreateEnemyFrameUI
            _G.Replay_CreateEnemyFrameUI = function(...)
                if isBypassActive() then
                    local backup = _G.ReportEnemyFrameUI or nop
                    _G.ReportEnemyFrameUI = nop
                    local res = orig(...)
                    _G.ReportEnemyFrameUI = backup
                    return res
                end
                return orig(...)
            end
        end
    end)

    ---------- LAYER 13: ESP-RELATED REPORT FUNCTIONS KILL ----------
    pcall(function()
        local espReports = {
            "ReportESPBox","ReportESPHealth","ReportMiniMapESP","ReportEnemyFrameUI",
            "ReportMarkCreated","ReportMarkDestroyed","MarkSuspiciousESP",
            "OnScreenMarkAdd","OnScreenMarkRemove","ReportDistanceMarker",
            "ReportWallhackESP","SendESPData","UploadESPInfo"
        }
        for _, fn in ipairs(espReports) do
            if _G[fn] then _G[fn] = nop end
            for _, mod in pairs(package.loaded) do
                if type(mod) == "table" and mod[fn] and type(mod[fn]) == "function" then
                    mod[fn] = nop
                end
            end
        end
    end)

    -- Gameplay RPC and packet dispatch are left untouched.

    _G.__ULTIMATE_WH_BYPASS_LOADED = true
    print("[ok] Ultimate Wallhack + ESP Detection Bypass Installed")
end

-- ========================================================================
-- WHABypass TABLE + DETECTION SUBSYSTEM SPOOF
-- ========================================================================
local function _BYPASS_SetupWHABypassTable()
    local bypass = {}
    local function nop() end
    local function returnTrue() return true end
    local function returnFalse() return false end
    local function safe_require(mod)
        local ok, res = pcall(require, mod)
        return ok and res or nil
    end
    local function tryImport(name)
        local ok, lib = pcall(import, name)
        return ok and lib or nil
    end

    local function blockScreenshots()
        pcall(function()
            local SS = tryImport("ScreenshotMaker") or tryImport("ScreenshotMTDer")
            if SS then
                SS.MakePicture = function() return "" end
                SS.ReMakePicture = function() return "" end
                SS.HasCaptured = returnTrue
            end
        end)
    end

    local function blockGameplayCallbacks()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        if GC._WHABlocked then return end

        local reportFuncs = {
            "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms",
            "ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt",
            "ReportPlayerMoveRoute","ReportPlayerPosition","ReportAimFlow","ReportHitFlow",
            "ReportWallHack","ReportAimbot","ReportSpeedHack","ReportMagicBullet",
            "ReportAbnormalMaterial","ReportDepthTestChange","ReportMemoryException",
            "ReportMaterialScan","ReportShaderOverride","ReportCircleFlow",
            "OnPlayerRPCValidateFailed","OnPlayerActorChannelError",
            "OnPlayerSpectateException","OnShutdownAfterError"
        }
        for _, fn in ipairs(reportFuncs) do GC[fn] = nop end

        local oldStateChanged = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, state, ...)
            if state and type(state) == "string" then
                local s = state:lower()
                if s:find("cheat") or s:find("ban") or s:find("integrity") then return end
            end
            if oldStateChanged then return oldStateChanged(UID, state, ...) end
        end

        GC._WHABlocked = true
    end

    local function spoofTssSdk()
        pcall(function()
            local t = _G.TssSdk
            if t then
                t.GetFileMD5 = function() return "" end
                t.VerifyFileSignature = returnTrue
                t.CheckIntegrity = returnTrue
                t.ScanMemory = function() return true, {} end
                t.IsEmulator = returnFalse
                t.OnRecvData = nop
            end
        end)
    end

    local function disableDetectionSubsystems()
        local sm = safe_require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not sm then return end

        local targetSubs = {
            "ClientWallhackDetectionSubsystem", "ClientESPDetectionSubsystem",
            "ClientAimTrackingSubsystem", "ShootVerifySubSystemClient",
            "ClientRenderCheckSubsystem", "ClientMemoryGuardSubsystem",
            "ClientKernelCheckSubsystem", "ClientHawkEyePatrolSubsystem",
            "ClientAntiCheatSubsystem", "IntegrityCheckSubsystem",
            "FileCheckSubsystem", "AvatarExceptionSubsystem"
        }
        for _, sn in ipairs(targetSubs) do
            local sub = sm:Get(sn)
            if sub and type(sub) == "table" then
                for k, v in pairs(sub) do
                    if type(v) == "function" then
                        if k:find("Report") or k:find("Send") or k:find("Verify") or
                           k:find("Check") or k:find("Detect") or k:find("Scan") then
                            sub[k] = nop
                        end
                    end
                end

                if sn == "ClientWallhackDetectionSubsystem" then
                    sub.IsVisionNormal = returnTrue
                    sub.GetVisibilityRate = function() return math.random(60, 85) end
                elseif sn == "ClientESPDetectionSubsystem" then
                    sub.HasESP = returnFalse
                    sub.CheckOverlay = function() return "clean" end
                elseif sn == "ClientAimTrackingSubsystem" then
                    sub.GetAimData = function()
                        return { accuracy = math.random(45,65), headshotRate = math.random(15,35) }
                    end
                    sub.IsAimNormal = returnTrue
                elseif sn == "ClientMemoryGuardSubsystem" then
                    sub.IsMemoryClean = function() return true, {code=0} end
                    sub.ScanResult = function() return "clean" end
                elseif sn == "ShootVerifySubSystemClient" then
                    sub.OnShootVerifyFailed = nop
                    sub.VerifyShot = returnTrue
                end
            end
        end
    end

    local function disableHiggsBoson()
        pcall(function()
            local hbc = safe_require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
            if hbc then
                hbc.bMHActive = false
                hbc.bCallPreReplication = false
                if hbc.ControlMHActive then hbc.ControlMHActive = nop end
                if hbc.StartAvatarCheck then hbc.StartAvatarCheck = nop end
                if hbc.BlackList then
                    for k in pairs(hbc.BlackList) do hbc.BlackList[k] = nil end
                end
            end
            if _G.AvatarCheckCallback then
                _G.AvatarCheckCallback.StartAvatarCheck = nop
                _G.AvatarCheckCallback.OnReportItemID = nop
            end
            _G.BlackList = {}
        end)
    end

    function bypass.Init()
        blockScreenshots()
        blockGameplayCallbacks()
        spoofTssSdk()
        disableDetectionSubsystems()
        disableHiggsBoson()
    end

    _G.WHABypass = bypass
end

-- ========================================================================
-- BYPASS EXECUTION
-- ========================================================================
local function _BYPASS_Execute()
    if _G._BYPASS_DONE then return end
    local ok, err = pcall(function()
        _G._WHA_BYPASS_ACTIVE = true
        _BYPASS_InstallUltimateWallhackBypass()
        _BYPASS_SetupWHABypassTable()
        if _G.WHABypass and _G.WHABypass.Init then
            _G.WHABypass.Init()
        end
        _G._BYPASS_DONE = true
        print("[ORDER] All bypasses executed")
    end)
    if not ok then
        print("[ORDER] Bypass failed, will retry:", tostring(err))
        _G._BYPASS_DONE = false
    end
end

-- Expose globally so callback bridge / any other scope can trigger it.
_G._BYPASS_Execute = _BYPASS_Execute
end -- V9.5 integration: exported callback retains the scoped helpers.

-- ============================================================================
-- ============================================================================
-- BYPASS END
-- ============================================================================
-- ============================================================================

-- ============================================================================
-- MAIN SCRIPT CALLBACK BRIDGE | tracking and settings maintenance
-- Each adapter runs the original game callback once, then its existing addition.
-- ============================================================================
-- MAIN SCRIPT CALLBACK BRIDGE END

-- Immediate bypass attempt on script load (in case a pawn is already present).
if Client and _G._BYPASS_Execute then pcall(_G._BYPASS_Execute) end

_G.LexusConfig = _G.LexusConfig or {}
_G.LexusConfig.IpadView = _G.LexusConfig.IpadView or false
_G.LexusState = _G.LexusState or {}
_G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
_G.LexusState.CustomTextData.IpadViewFOV = _G.LexusState.CustomTextData.IpadViewFOV or 120

-- g_masterahsanyt_GetLocalPlayer made by @Masterpiece2025
local function g_masterahsanyt_GetLocalPlayer()
    local ok, GDP = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GDP then return nil end
    local player = GDP.GetPlayerCharacter()
    if player and slua.isValid(player) then return player end
    return nil
end

-- g_masterahsanyt_ApplyiPadView made by @Masterpiece2025
local function g_masterahsanyt_ApplyiPadView()
    local player = g_masterahsanyt_GetLocalPlayer()
    if not player then return end
    local cam = player.ThirdPersonCameraComponent
    if not cam or not slua.isValid(cam) then return end
    if player.bIsWeaponAiming then return end

    if _G.LexusConfig.IpadView and _G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized then
        local targetFOV = _G.LexusState.CustomTextData.IpadViewFOV or 120
        if cam.FieldOfView ~= targetFOV then
            cam.FieldOfView = targetFOV
        end
    else
        if cam.FieldOfView ~= 90 then
            cam.FieldOfView = 90
        end
    end
end

-- Persistent ESP feature settings.
local g_masterahsanyt_ESPOptionDefaults = {
    Name=false, Line=false, Box=false, Health=false, Distance=false, Skeleton=false, Counter=false
}
_G.g_masterahsanyt_ESPOptions = _G.g_masterahsanyt_ESPOptions or {}
for k,v in pairs(g_masterahsanyt_ESPOptionDefaults) do
    if _G.g_masterahsanyt_ESPOptions[k] == nil then _G.g_masterahsanyt_ESPOptions[k] = v end
end
local g_masterahsanyt_ESPSettingsFile = "MASTERPIECE_UMG_ESP_settings.lua"
local function g_masterahsanyt_ESPSettingsPaths()
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_masterahsanyt_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_masterahsanyt_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_masterahsanyt_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_masterahsanyt_ESPSettingsFile,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/"..g_masterahsanyt_ESPSettingsFile,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/"..g_masterahsanyt_ESPSettingsFile,
        "ShadowTrackerExtra/Saved/SaveGames/"..g_masterahsanyt_ESPSettingsFile,
        g_masterahsanyt_ESPSettingsFile
    }
    local home=nil
    pcall(function() if os and os.getenv then home=os.getenv("HOME") end end)
    if type(home)=="string" and home~="" then
        table.insert(paths,1,home.."/Documents/ShadowTrackerExtra/Saved/SaveGames/"..g_masterahsanyt_ESPSettingsFile)
    end
    return paths
end
-- Replace the SaveGames file only after write/flush/close succeed where Lua
-- exposes rename. A failed temporary write keeps the last saved file intact.
local function g_masterahsanyt_ESPWriteSettings(path,payload)
    local atomic=os and type(os.rename)=="function"
    local target=atomic and path..".tmp" or path
    local opened,file=pcall(io.open,target,"w")
    if not opened or not file then return false,"Open failed: "..target end
    local closed=false
    local ok,err=pcall(function()
        local result,reason=file:write(payload)
        assert(result,reason or "Settings write failed")
        if file.flush then local flushed,why=file:flush();assert(flushed,why or "Settings flush failed") end
        local result,reason=file:close();closed=true
        assert(result,reason or "Settings close failed")
    end)
    if not closed then pcall(function() file:close() end) end
    if ok and atomic then
        local called,result,reason=pcall(os.rename,target,path)
        ok=called and result~=nil and result~=false
        err=ok and nil or (reason or result or "Settings rename failed")
    end
    if not ok and atomic and os.remove then pcall(os.remove,target) end
    return ok,err,atomic
end

local g_masterahsanyt_ESPLoadedSettingsPath=nil

local function g_masterahsanyt_ESPLoadSettings()
    if not io or type(io.open) ~= "function" then return false end
    local paths = g_masterahsanyt_ESPSettingsPaths()
    local content=nil
    for _,path in ipairs(paths) do
        local ok,f=pcall(io.open,path,"r")
        if ok and f then
            local rok,text=pcall(function() return f:read("*a") end)
            pcall(function() f:close() end)
            if rok and type(text)=="string" and text~="" then content=text;g_masterahsanyt_ESPLoadedSettingsPath=path;break end
        end
    end
    if not content then return false end
    for k in pairs(g_masterahsanyt_ESPOptionDefaults) do
        local v=content:match(k.."%s*=%s*(true)") or content:match(k.."%s*=%s*(false)")
        if v then _G.g_masterahsanyt_ESPOptions[k]=(v=="true") end
    end
    return true
end
g_masterahsanyt_ESPLoadSettings()

-- One authorization session per Lua process; gameplay identity never owns it.
do
    local licenseScope
local MasterLicenseConfig = {
    -- VIPGFX login panel (replaces the old key.authapi.xyz server).
    url = 'https://vipgfx.in/VAWZEN/connect', game = 'BGMI',
    timeout = 10, clockSkew = 120, expiryPath = nil,
    manualExpiry = "2026-12-31 23:59:59", tamperTolerance = 5,
    -- License token advertised by the VIPGFX panel.
    secret = 'Qp5KSGTquetnUkjX6UVBAURH8hTkZuLM',
    -- Panel answers with {status, reason}; legacy token/rng is still
    -- verified automatically whenever that pair is present.
    verifyToken = false,
    -- Panel ka game name key ke saath register hota hai. Ek naam par
    -- "NOT REGISTERED" aaye to baaki naam automatically try hote hain.
    games = { 'BGMI', 'PUBG', 'PUBGM', 'PUBGMOBILE', 'pubg_mobile',
              'BGMI_MOBILE', 'PUBG_MOBILE', 'bgmi', 'pubgmobile' },
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
        local expiredText = 'Mod expired. DM @Masterpiece2025 for renewal.'
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
            if type(reason) ~= 'string' then return 'Expired' end
            local lower = reason:sub(1, 120):lower():gsub('[_%s%-]+', ' ')
            if lower == 'max devices' or lower == 'maximum devices'
                or lower == 'max devices reached' then return 'Max Devices' end
            local clean = reason
            for _, field in ipairs({'key', 'serial'}) do
                if pending and type(pending[field]) == 'string' and #pending[field] > 0 then
                    local needle = pending[field]:gsub('([^%w])', '%%%1')
                    clean = clean:gsub(needle, '[' .. field .. ']')
                end
            end
            if type(cfg.secret) == 'string' and #cfg.secret > 0 then
                clean = clean:gsub(cfg.secret:gsub('([^%w])', '%%%1'), '[credential]')
            end
            clean = clean:gsub('[%c]', ' '):sub(1, 120)
            return clean == '' and 'Expired' or ('Expired: ' .. clean)
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
            local gameList = (type(cfg.games) == 'table' and #cfg.games > 0)
                and cfg.games or { cfg.game }
            local gameIdx = 1
            local function buildBody(g)
                return 'game=' .. P.form_encode(g)
                    .. '&user_key=' .. P.form_encode(key)
                    .. '&serial=' .. P.form_encode(serial)
            end
            local received
            local function sendNext()
                if gameIdx > #gameList then
                    revoke('Key not registered on panel (tried: '
                        .. table.concat(gameList, ', ') .. ').', 'denied')
                    return
                end
                local okPost, started = pcall(deps.post, cfg.url,
                    {['Content-Type'] = 'application/x-www-form-urlencoded'},
                    buildBody(gameList[gameIdx]), received, cfg.timeout)
                if not okPost or started == false then
                    revoke('HTTP request could not start.', 'error')
                end
            end
            received = function(success, raw)
                if not pending or pending.id ~= requestId or generation ~= requestId then return end
                local current, worldNow = readClock()
                if not current or worldNow ~= pending.world or current < pending.started
                    or current >= pending.deadline then
                    revoke('Request expired. Please sign in again.', 'error'); return
                end
                if success ~= true or type(raw) ~= 'string' or #raw == 0 or #raw > 32768 then
                    revoke('Connection failed. Please try again.', 'error'); return
                end
                local ok, result = pcall(deps.decode, raw)
                if not ok or type(result) ~= 'table' then
                    revoke('Invalid server response.', 'error'); return
                end
                if result.status ~= true then
                    local rs = type(result.reason) == 'string' and result.reason:lower() or ''
                    if (rs:find('not registered', 1, true) or rs:find('not register', 1, true))
                        and gameIdx < #gameList then
                        gameIdx = gameIdx + 1
                        if pending then pending.deadline = current + cfg.timeout end
                        notify('Trying game: ' .. tostring(gameList[gameIdx]), 'pending')
                        sendNext(); return
                    end
                    revoke(denyReason(result.reason), 'denied'); return
                end
                local data = type(result.data) == 'table' and result.data or result
                local okWall, wall = pcall(deps.wall)
                if not okWall or not finite(wall) then
                    revoke('Phone clock unavailable.', 'error'); return
                end
                -- VIPGFX panel: accept the panel verdict. Legacy token/rng is
                -- still verified exactly as before when it is present.
                local serverTime = data.rng
                if not (finite(serverTime) and serverTime % 1 == 0) then
                    serverTime = data.server_time or data.serverTime or data.time
                        or data.expiry_time or data.expiry or wall
                end
                if cfg.verifyToken ~= false and type(data.token) == 'string'
                    and #data.token == 32 and data.token:match('^[%x]+$') then
                    local expected = P.md5(cfg.game .. '-' .. key .. '-' .. serial .. '-' .. cfg.secret)
                    if not P.constant_time_equal(data.token:lower(), expected) then
                        revoke('Server token verification failed.', 'denied'); return
                    end
                end
                if localExpiry then
                    local accepted, text, state = localExpiry.Accept(
                        serverTime, current, worldNow, wall, current - pending.started)
                    if not accepted then revoke(text, state); return end
                elseif math.abs(wall - serverTime) > cfg.clockSkew then
                    revoke('Phone/server clock mismatch. Check automatic time.', 'error'); return
                end
                local expiry, validExpiry = configuredExpiry(result)
                if not validExpiry then
                    revoke('Configured server expiry field is missing or invalid.', 'error'); return
                end
                if expiry and expiry - serverTime - (current - pending.started) <= 0 then
                    revoke('Expired', 'denied'); return
                end
                local fixedExpiry = localExpiry and localExpiry.GetExpiry()
                if fixedExpiry then expiry = math.min(expiry or fixedExpiry, fixedExpiry) end
                lastRequestLatencyMs = (current - pending.started) * 1000
                lastResponseTime, lastResponseWorld = current, worldNow
                pending = nil
                allowed, expiresAt = true, expiry
                saveSession(expiresAt)
                if not startPayload() then return end
                notify('Login successful.', 'active')
            end
            sendNext()
            return true
        end
        function A.Login(key) if allowed then return false end; return begin(key) end
        function A.Tick()
            if not pending then return end
            local now, world = readClock()
            if not now or world ~= pending.world or now < pending.started then
                revoke('Login clock unavailable. Please try again.', 'locked'); return
            end
            if now >= pending.deadline then
                revoke('Request timed out. Please try again.', 'error')
            end
        end
        function A.IsAuthorized()
            if allowed and not restartRequired then return true end
            local stored = loadSession()
            if stored and not restartRequired then
                allowed = true; expiresAt = stored.expiresAt; return true
            end
            return false
        end
        function A.Logout() clearSession(); revoke('Expired: signed out.', 'locked') end
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
                periodicRecheck = false, pending = pending ~= nil,
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
            local frame={{235,43,67},{132,80,46},{21,212,120}}
            local bright={{255,150,159},{241,212,180},{149,255,197}}
            local edge={{124,15,35},{65,51,28},{6,91,48}}
            local body={{255,162,154},{255,239,197},{139,239,176}}
            local header={{141,20,43},{76,48,38},{7,95,53}}
            local gold={{188,108,59},{242,219,164},{114,179,105}}
            local white=color(255,255,255)
            local forest=color(10,48,26)
            local burgundy=color(86,20,35)
            -- Perimeter only: an opaque full-panel backing would destroy
            -- the requested body transparency even with alpha on the body.
            panel(6,6,W-12,H-12,10,body,2,24,.5)
            rail(13,0,W-26,6,frame,3,24)
            rail(13,H-6,W-26,6,frame,3,24)
            rect(0,13,6,H-26,color(235,43,67),3)
            rect(W-6,13,6,H-26,color(21,212,120),3)
            rail(13,1,W-26,1.5,bright,3,24)
            rail(13,H-3,W-26,1.5,edge,3,24)
            rect(1,13,1.5,H-26,color(255,141,154),3)
            rect(W-3,13,1.5,H-26,color(142,255,193),3)
            for _,s in ipairs({{1,13,13,1},{1,H-13,13,H-1}}) do line(s[1],s[2],s[3],s[4],2,color(255,159,166),3) end
            for _,s in ipairs({{W-13,1,W-1,13},{W-13,H-1,W-1,H-13}}) do line(s[1],s[2],s[3],s[4],2,color(155,255,200),3) end
            panel(10,10,W-20,65,16,gold,4,24,1)
            panel(13,13,W-26,59,14,header,5,32,1)
            if welcome then
                d.Title=text("Welcome to @Masterpiece2025 Lua mod",24,22,W-48,42,19,white,7,true,true)
                local pw=math.min(340,W-72);local px=(W-pw)/2
                panel(px,99,pw,51,12,gold,4,16)
                panel(px+3,102,pw-6,45,10,{{179,29,52},{231,73,87},{178,26,47}},5,20)
                d.Detail=text("Kill limit 8-10",px+16,109,pw-32,34,23,white,7,true,true)
                d.Hint=text("Play smart and avoid report",30,165,W-60,32,17,forest,7,true,true)
            else
                d.Title=text("VIPGFX PANEL",22,15,W-44,31,24,white,7,true,true)
                text("LOGIN",22,45,W-44,21,12,white,7,true,true)
                line(W/2-118,56,W/2-47,56,1,color(251,244,228),7)
                line(W/2+47,56,W/2+118,56,1,color(251,244,228),7)
                text("LOGIN KEY",22,82,W-44,20,13,burgundy,7,true,false)
                rail(27,104,W-54,2,gold,4,24)
                rail(27,143,W-54,2,gold,4,24)
                rect(20,111,2,27,color(188,108,59),4)
                rect(W-22,111,2,27,color(114,179,105),4)
                line(20,111,27,104,2,color(242,219,164),4)
                line(W-27,104,W-20,111,2,color(242,219,164),4)
                line(20,138,27,145,2,color(242,219,164),4)
                line(W-27,145,W-20,138,2,color(242,219,164),4)
                d.Input=make("EditableTextBox",d.Container)
                d.Input:SetText(key or "")
                -- Input-specific native style; TextBlock-only methods stay unused.
                local fg=forest;local bg=color(255,244,216,0)
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
                local id=Client.GetPhoneDeviceID()
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
            decode=function(raw) local json=require("common.json_util");return json.decode(raw) end,
            post=function(url,headers,body,callback,timeout)
                local http=ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
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

-- Settings registration follows the supplied working native-page reference.
-- Feature rows, option values and authentication stay owned by this script.
local g_masterahsanyt_EnsureHackMenu
do
    local VERSION = "LunarSettings.V9.2.MenuFix"
    local function runtime()
        local state = _G.LunarNativeSettingsRuntime
        if type(state) ~= "table" then state = {}; _G.LunarNativeSettingsRuntime = state end
        return state
    end
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function loadTable(name)
        local ok, value = pcall(require, name)
        if not ok then
            if package and package.loaded and type(package.loaded[name]) ~= "table" then
                package.loaded[name] = nil
            end
            error(name .. ": " .. tostring(value), 0)
        end
        assert(type(value) == "table", name .. ": SETTINGS_MODULE_NOT_READY")
        return value
    end
    local function register(catalog, page)
        if type(catalog) ~= "table" or type(page) ~= "table" then return false end
        local found = false
        for i = #catalog, 1, -1 do
            local entry = catalog[i]
            if type(entry) == "table" and entry.Key == "HackMenu" then
                if found then table.remove(catalog, i) else catalog[i] = page; found = true end
            end
        end
        if not found then table.insert(catalog, 1, page) end
        return true
    end
    local function looksLikeCatalog(value, allowEmpty)
        if type(value) ~= "table" then return false end
        local first = value[1]
        if type(first) == "table" and first.Key ~= nil then return true end
        return allowEmpty and next(value) == nil
    end
    local function isMainSettings(config)
        local key
        if type(config) == "string" then key = config
        else
            key = member(config, "keyName") or member(config, "KeyName")
                or member(config, "key") or member(config, "Key")
        end
        if key == nil then return false end
        local lower = string.lower(tostring(key))
        return lower:find("setting_main", 1, true) ~= nil
            and lower:find("custom", 1, true) == nil
    end
    local function injectShowCatalog(manager, config, args, count)
        local actual, first = config, 1
        if config == manager then actual, first = args[1], 2 end
        if not isMainSettings(actual) then return end
        local state = runtime()
        if not state.Page then return end
        state.LastShowUIInjected = false
        for i = first, count do
            if looksLikeCatalog(args[i], false) then
                state.LastShowUIInjected = register(args[i], state.Page)
                state.LastShowUICatalogIndex = i
                break
            end
        end
        if not state.LastShowUIInjected and looksLikeCatalog(args[first], true) then
            state.LastShowUIInjected = register(args[first], state.Page)
            state.LastShowUICatalogIndex = first
        end
    end
    local function installManagers(state)
        local managers = {}
        local function add(manager)
            if manager == nil then return end
            for _, current in ipairs(managers) do if current == manager then return end end
            managers[#managers + 1] = manager
        end
        add(_G.UIManager)
        local ok, loaded = pcall(loadTable, "client.slua_ui_framework.manager")
        if ok then add(loaded); state.ManagerModuleError = nil
        else state.ManagerModuleError = tostring(loaded) end
        local count = 0
        for _, manager in ipairs(managers) do
            local show = member(manager, "ShowUI")
            if type(show) == "function" then
                local record = member(manager, "__LunarSettingsUIHook")
                if type(record) ~= "table" or record.Version ~= VERSION or record.Wrapper ~= show then
                    record = {Version = VERSION, Original = show}
                    record.Wrapper = function(config, ...)
                        local current = runtime()
                        -- Register again before opening, including rebuilt mode catalogs.
                        if not current.Initializing and type(current.Ensure) == "function" then
                            pcall(current.Ensure)
                        end
                        local args, n = {...}, select('#', ...)
                        injectShowCatalog(manager, config, args, n)
                        return record.Original(config, (table.unpack or unpack)(args, 1, n))
                    end
                    manager.ShowUI = record.Wrapper
                    manager.__LunarSettingsUIHook = record
                end
                count = count + 1
            end
        end
        state.Managers = managers
        state.HookCount = count
        state.HookInstalled = count > 0
        return state.HookInstalled
    end
    local function restoreAliases(state, aliases)
        for _, manager in ipairs(state.Managers or {}) do
            local config = member(manager, "UI_Config")
            if config then
                for _, key in ipairs({"Switcher", "Slider"}) do
                    if type(aliases[key]) ~= "table" then
                        local value = member(config, "Setting_Option_" .. key)
                        if type(value) == "table" then aliases[key] = value end
                    end
                end
            end
        end
    end
    local function syncModeCatalogs(state)
        local names = {"GameLua.Mod.BaseMod.Client.Config.SettingCatalog",
            "GameLua.Mod.D350.Client.Config.SettingCatalog",
            "GameLua.Mod.PlanPH.Client.Config.SettingCatalog"}
        for i, name in ipairs(names) do
            local catalog = package and package.loaded and package.loaded[name]
            if type(catalog) ~= "table" and i == 1 then
                local ok, value = pcall(loadTable, name)
                if ok then catalog = value; state.ModeCatalogError = nil
                else state.ModeCatalogError = tostring(value) end
            end
            if type(catalog) == "table" then register(catalog, state.Page) end
        end
    end
    local function buildPage(F, AliasMap, sliderReady)
    local function featureState() return _G.LunarFeatures end
    local function value(c,v) if v==nil then return c end return v end
    local function espAll(version)
        return {Key="LunarV"..version.."_All",UI=AliasMap.Switcher,Text="All ESP",
            LunarBulk=true,
            SwitcherText={"All On","All Off"},
            EventType=F.ESPSettingsEventType,EventID=F.ESPSettingsEventID,
            GetFunc=function() return featureState().GetESPAll(version) end,
            SetFunc=function(c,v) return featureState().SetESPAll(version,value(c,v)) end}
    end
    local function espSwitch(version,key,label)
        return {Key=version==1 and ("LunarV1_"..key) or ("MasterpieceESP_"..key),
            UI=AliasMap.Switcher,Text=label,
            EventType=F.ESPSettingsEventType,EventID=F.ESPSettingsEventID,
            GetFunc=function()
                local options=version==1 and _G.g_Botmater_ESPOptions or _G.g_masterahsanyt_ESPOptions
                return options[key]==true
            end,
            SetFunc=function(c,v) return featureState().SetESP(version,key,value(c,v)) end}
    end
    local V1={espAll(1)}
    for _,entry in ipairs({{"Name","ESP NAME"},{"Line","ESP LINE"},{"Health","ESP HEALTH"},{"Distance","ESP DISTANCE"},{"EnemyCounter","ESP COUNTER"}}) do
        V1[#V1+1]=espSwitch(1,entry[1],entry[2])
    end
    local V2={espAll(2),
        espSwitch(2,"Name","ESP NAME"),espSwitch(2,"Line","ESP LINE"),espSwitch(2,"Box","ESP BOX"),
        espSwitch(2,"Health","ESP HEALTH"),espSwitch(2,"Distance","ESP DISTANCE"),espSwitch(2,"Skeleton","ESP SKELETON"),espSwitch(2,"Counter","ESP COUNTER")}
    local Other={
        {Key="LunarWall",UI=AliasMap.Switcher,Text="Wall Hack",ExpandIndex=0,EventType=F.ESPSettingsEventType,EventID=3,GetFunc=function() return featureState().Settings.WallEnabled end,
            SetFunc=function(c,v) featureState().SetWall(value(c,v));return true end},
        {Key="LunarIpad",UI=AliasMap.Switcher,Text="iPad View",ExpandIndex=0,GetFunc=function() return _G.LexusConfig.IpadView end,
            SetFunc=function(c,v) featureState().SetIpad(value(c,v));return true end},
        {Key="LunarAim",UI=AliasMap.Switcher,Text="Aimbot V1",ExpandIndex=0,
            EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
            GetFunc=function() return featureState().Settings.AimEnabled end,
            SetFunc=function(c,v) featureState().SetAim(value(c,v));return true end}
    }
    -- Verified native settings item contract: absolute Min/Max values, native
    -- key/value callbacks, and expansion events owned by the game's page.
    local function rangeItem(key,label,lo,hi,parent,get,set)
        return {Key=key,UI=AliasMap.Slider,Text=label,Min=lo,Max=hi,ExpandHandle=parent,
            GetFunc=function() return get() end,
            SetFunc=function(c,v)
                featureState()[set](value(c,v))
                featureState().Save(true)
                return true
            end}
    end
    if sliderReady then
        table.insert(Other,3,rangeItem("LunarIpadFOV","iPad FOV",90,120,"LunarIpad",
            function() return featureState().Settings.IpadFOV end,"SetIpadFOV"))
    end
    if sliderReady then
        Other[#Other+1]=rangeItem("LunarAimSpeed","Aim speed",100,120,"LunarAim",
            function() return featureState().Settings.AimSpeed end,"SetAimSpeed")
    end
    Other[#Other+1]={Key="LunarAimTarget",UI=AliasMap.Switcher,Text="Aim target",ExpandHandle="LunarAim",
        SwitcherText={"Head","Body","Leg"},SwitcherValue={1,2,3},
        GetFunc=function() return featureState().Settings.AimTarget end,
        SetFunc=function(c,v) featureState().SetAimTarget(value(c,v));return true end}
    Other[#Other+1]={Key="LunarAim2",UI=AliasMap.Switcher,Text="Aimbot V2",
        EventType=F.AimSettingsEventType,EventID=F.AimSettingsEventID,
        GetFunc=function() return featureState().Settings.Aim2Enabled end,
        SetFunc=function(c,v) featureState().SetAim2(value(c,v));return true end}
    Other[#Other+1]={Key="LunarMortarAim",UI=AliasMap.Switcher,Text="Mortar aim",
        GetFunc=function() return featureState().Settings.MortarEnabled end,
        SetFunc=function(c,v) featureState().SetMortar(value(c,v));return true end}
    local names={"Pink","White","Cyan","Green","Yellow","Saffron","Red"}
    for i,entry in ipairs({{"WallVisible","Visible color"},{"WallOccluded","Behind-wall color"}}) do
        local key,label=entry[1],entry[2]
        table.insert(Other,1+i,{Key="Lunar"..key,UI=AliasMap.CompactSwitcher or AliasMap.Switcher,Text=label,
            EventType=F.ESPSettingsEventType,EventID=3,
            ExpandHandle="LunarWall",SwitcherText=names,SwitcherValue={1,2,3,4,5,6,7},
            GetFunc=function() return featureState().Settings[key] end,
            SetFunc=function(c,v) return featureState().SetWallColor(key,value(c,v)) end})
    end
    -- ===== Skins Visual: All Skin Hacks ON/OFF =====
    if type(_G.SKIN_TOGGLES) ~= "table" then
        _G.SKIN_TOGGLES = { ALL_SKIN = false }
    end
    _G.ALL_SKINS_ENABLED = (_G.SKIN_TOGGLES.ALL_SKIN == true)
    local function skinSyncFlags()
        local on = _G.SKIN_TOGGLES.ALL_SKIN == true
        _G.ALL_SKINS_ENABLED = on
    end
    skinSyncFlags()
    if type(_G.SKIN_ToggleOn) ~= "function" then
        _G.SKIN_ToggleOn = function(id)
            local t = _G.SKIN_TOGGLES
            if type(t) ~= "table" then return true end
            if t.ALL_SKIN == false then return false end
            return t[id] ~= false
        end
    end
    local SkinsVisualStack={
        {Key="LunarAllSkinHacks",UI=AliasMap.Switcher,Text="All Skin Hacks",ExpandIndex=0,
            GetFunc=function() return _G.SKIN_TOGGLES.ALL_SKIN == true end,
            SetFunc=function(c,v)
                local on = value(c,v) == true
                _G.SKIN_TOGGLES.ALL_SKIN = on
                skinSyncFlags()
                if on and type(_G.SKIN_ApplyNow) == "function" then
                    pcall(_G.SKIN_ApplyNow)
                end
                return true
            end}
    }
    local page={Key="HackMenu",Text="Hack menu",UIKey="Setting_Page_Privacy",Category={
        {Key="Lunar_SKINS_VISUAL",Text="Skins Visual",Stack=SkinsVisualStack},
        {Key="Lunar_ESP_V1",Text="ESP V1",Stack=V1},
        {Key="Lunar_ESP_V2",Text="ESP V2",Stack=V2},
        {Key="Lunar_Other",Text="Other Features",Stack=Other}
    }}

        return page
    end
    local function initialize(state)
        local F = _G.LunarFeatures
        assert(type(F) == "table", "FEATURE_RUNTIME_NOT_READY")
        local pages = loadTable("client.logic.NewSetting.SettingPageDefine")
        local catalog = loadTable("client.logic.NewSetting.SettingCatalog")
        local aliases = loadTable("client.slua.umg.NewSetting.Item.AliasMap")
        restoreAliases(state, aliases)
        assert(type(aliases.Switcher) == "table", "AliasMap.Switcher_not_ready")

        -- Missing optional sliders must not hide the entire settings tab.
        -- Rebuild with both original slider rows as soon as their UI is available.
        local sliderReady = type(aliases.Slider) == "table"
        local compact = aliases.CompactSwitcher or aliases.Switcher
        local rebuild = state.Version ~= VERSION or not state.Page
            or state.Features ~= F or state.Alias ~= aliases
            or state.Switcher ~= aliases.Switcher or state.Slider ~= aliases.Slider
            or state.CompactSwitcher ~= compact
        if rebuild then
            state.Page = buildPage(F, aliases, sliderReady)
            state.PageBuilds = (state.PageBuilds or 0) + 1
        end
        state.Version, state.Features, state.PageDefine, state.Catalog = VERSION, F, pages, catalog
        state.Alias, state.Switcher, state.Slider = aliases, aliases.Switcher, aliases.Slider
        state.CompactSwitcher = compact
        state.SliderReady = sliderReady
        state.DeferredSliderRows = sliderReady and 0 or 2
        pages.HackMenu = state.Page
        state.Registered = register(catalog, state.Page)
        syncModeCatalogs(state)

        -- Bulk selector enhancement is optional; its failure cannot block the page.
        local okClass, switchClass = pcall(loadTable, "client.slua.umg.NewSetting.Item.Setting_Option_Switcher")
        if okClass and type(F.InstallNativeBulkSwitch) == "function" then
            local okBulk, result = pcall(F.InstallNativeBulkSwitch, switchClass)
            state.BulkSwitchReady = okBulk and result == true
            state.BulkSwitchError = not okBulk and tostring(result) or nil
        else
            state.BulkSwitchReady = false
            state.BulkSwitchError = not okClass and tostring(switchClass) or "BULK_SWITCH_HELPER_UNAVAILABLE"
        end
        state.Ready = state.Registered and state.HookInstalled == true
        if state.Ready then
            state.LastError = nil
            _G.HackMenuInitialized = "MASTERAHSAN_NATIVE_SETTINGS_V9_2"
        else state.LastError = "SETTINGS_UI_MANAGER_NOT_READY" end
        return state.Ready
    end
    g_masterahsanyt_EnsureHackMenu = function()
        local state = runtime()
        state.Ensure = g_masterahsanyt_EnsureHackMenu
        if state.Initializing then return false end
        state.Initializing = true
        state.Attempts = (state.Attempts or 0) + 1
        -- Install early even when page/alias modules are still loading.
        local okHook, hookError = pcall(installManagers, state)
        if not okHook then state.HookInstalled = false; state.HookError = tostring(hookError)
        else state.HookError = nil end
        local ok, result = pcall(initialize, state)
        state.Initializing = false
        if not ok then state.Ready = false; state.LastError = tostring(result) end
        return ok and result == true
    end
    _G.LunarSettingsDiagnostics = function()
        local state = runtime()
        local timer = _G.__MasterShotFastRunner
        return {version = state.Version, ready = state.Ready == true,
            registered = state.Registered == true, attempts = state.Attempts or 0,
            lastError = state.LastError, hookInstalled = state.HookInstalled == true,
            hookCount = state.HookCount or 0, hookError = state.HookError,
            managerModuleError = state.ManagerModuleError,
            pageBuilt = state.Page ~= nil, pageBuilds = state.PageBuilds or 0,
            pageUIKey = state.Page and state.Page.UIKey or nil,
            sliderReady = state.SliderReady == true, deferredSliderRows = state.DeferredSliderRows,
            lastShowUIInjected = state.LastShowUIInjected,
            lastShowUICatalogIndex = state.LastShowUICatalogIndex,
            maintenanceProvider = type(timer) == "table" and timer.Provider or nil,
            maintenanceError = type(timer) == "table" and timer.LastError or nil}
    end
end

-- ESP configuration made by @Masterpiece2025
_G.g_masterahsanyt_MasterShotESP = _G.g_masterahsanyt_MasterShotESP or {

    Enabled = true,
    MaxRangeMeters = 450.0,

    -- Target 60 updates/sec when the engine timer permits. No skeleton decimation.
    -- Discovery is separate from rendering; every rendered pose uses fresh projections.
    ScanInterval = 0.35,
    UpdateInterval = 1.0 / 60.0,
    WidgetBuildBudget = 96, -- New line widgets per update; existing widgets stay live.
    Profile = false,       -- Optional CPU timing in _G.g_masterahsanyt_ESPDiagnostics.
    TransformInterval = 0.60,
    MaxRendered = 8,

    CounterY = 36.0,
    CounterWidth = 218.4,
    CounterHeight = 33.6,
    CounterDiamondSize = 0.0,

    TracerThickness = 1.80,
    NameGap = 2.0,
    NameFontSize = 14,
    DistanceFontSize = 20,
    DistanceBelowFeet = 8.0,
}
if (tonumber(_G.g_masterahsanyt_MasterShotESP.MaxRendered) or 0) < 1 then
    _G.g_masterahsanyt_MasterShotESP.MaxRendered = 8
end
if (tonumber(_G.g_masterahsanyt_MasterShotESP.MaxRangeMeters) or 0) < 400.0 then
    _G.g_masterahsanyt_MasterShotESP.MaxRangeMeters = 450.0
end
-- Upgrade a table retained by an earlier hot-reload to the new readable marker size.
if (tonumber(_G.g_masterahsanyt_MasterShotESP.DistanceFontSize) or 0) < 20 then
    _G.g_masterahsanyt_MasterShotESP.DistanceFontSize = 20
end
-- Counters are 20% larger than the previous 182x28 revision.
_G.g_masterahsanyt_MasterShotESP.CounterWidth=218.4
_G.g_masterahsanyt_MasterShotESP.CounterHeight=33.6
_G.g_masterahsanyt_MasterShotESP.CounterDiamondSize=0.0

-- Upgrade only the shipped 30 Hz default on the first performance revision.
if not _G.g_masterahsanyt_MasterShotESP.PerformanceRevision then
    if _G.g_masterahsanyt_MasterShotESP.UpdateInterval == 0.033 then
        _G.g_masterahsanyt_MasterShotESP.UpdateInterval = 1.0 / 60.0
    end
    _G.g_masterahsanyt_MasterShotESP.PerformanceRevision = 1
end
_G.MasterShotESP = _G.g_masterahsanyt_MasterShotESP

-- ESP runtime state made by @Masterpiece2025
local g_masterahsanyt_ShotESP = {
    Canvas = nil,
    RootUI = nil,
    Counter = nil,
    Enemies = {},
    Lines = {},
    Names = {},
    Boxes = {},
    HealthBars = {},
    Skeletons = {},
    Headers = {},
    Footers = {},
    BuildStage = {},
    BoneNameCache = {},
    Decorations = {},
    TemplateFont = nil,
    TemplateFontObject = nil,
    TemplateTypeface = nil,
    TemplateColorAndOpacity = nil,
    LastScanClock = -999.0,
    LastTransformClock = -999.0,
    LastWorld = nil,
    TracerOrigin = nil,

    CanvasScaleX = 1.0,
    CanvasScaleY = 1.0,
    CanvasOffsetX = 0.0,
    CanvasOffsetY = 0.0,
    ViewportW = nil,
    ViewportH = nil,
    RawViewportW = nil,
    RawViewportH = nil,
    HeaderRoots = {},
    Active = {},
    Alive = {},
    BoneMeshes = {},
    BonePoints = {},
    TimerClock = 0.0,
    Now = 0.0,
    Disabled = false,
    -- Bot detection result cache (avoids repeated IsAI calls every frame)
    _BotCache = {},
    RealCount = 0,
    BotCount = 0,
}

local V2 = _G.FVector2D
if not V2 then pcall(function() V2 = import("Vector2D") end) end
local V3 = _G.FVector
if not V3 then pcall(function() V3 = import("Vector") end) end
local LinearColor = _G.FLinearColor
if not LinearColor then pcall(function() LinearColor = import("LinearColor") end) end
local Anchors = _G.FAnchors
if not Anchors then pcall(function() Anchors = import("Anchors") or import("/Script/Slate.Anchors") end) end
local SlateBlueprintLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
local WidgetLayoutLibrary = nil
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
local SlateColor = nil
pcall(function() SlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
local KismetTextLibrary = nil
pcall(function() KismetTextLibrary = import("KismetTextLibrary") or import("/Script/Engine.KismetTextLibrary") end)
local GameplayStaticsESP = nil
pcall(function() GameplayStaticsESP = import("GameplayStatics") end)
local ESPGameplayData=nil
pcall(function() ESPGameplayData=require("GameLua.GameCore.Data.GameplayData") end)

-- g_masterahsanyt_ESPV2 made by @Masterpiece2025
local function g_masterahsanyt_ESPV2(x, y)
    if V2 then return V2(x, y) end
    return {X = x, Y = y}
end

local function g_masterahsanyt_ESPV3(x, y, z)
    if V3 then
        local ok, v = pcall(V3, x, y, z)
        if ok and v then return v end
    end
    return {X = x, Y = y, Z = z}
end

-- ESP color made by @Masterpiece2025
local function g_masterahsanyt_ESPColor(r, g, b, a)
    if LinearColor then return LinearColor(r, g, b, a or 1.0) end
    return {R=r, G=g, B=b, A=a or 1.0}
end

-- ESP color theme made by @Masterpiece2025
local ESP_REAL = g_masterahsanyt_ESPColor(0.90, 0.14, 0.14, 0.98)
local ESP_BOT  = g_masterahsanyt_ESPColor(0.18, 0.86, 0.36, 0.98)
local ESP_WHITE = g_masterahsanyt_ESPColor(1.0, 1.0, 1.0, 1.0)
local ESP_BLACK = g_masterahsanyt_ESPColor(0.0, 0.0, 0.0, 1.0)
local ESP_TEXT_CLEAR = g_masterahsanyt_ESPColor(0.0,0.0,0.0,0.0)
local ESP_HEADER_BG = g_masterahsanyt_ESPColor(0.0, 0.0, 0.0, 0.78)
local ESP_COUNTER_RED = g_masterahsanyt_ESPColor(1.0, 0.055, 0.105, 1.0)
local ESP_COUNTER_RED_DARK = g_masterahsanyt_ESPColor(0.12, 0.008, 0.012, 1.0)
local ESP_COUNTER_BLUE = g_masterahsanyt_ESPColor(0.18, 0.86, 0.36, 1.0)
local ESP_COUNTER_BLUE_DARK = g_masterahsanyt_ESPColor(0.012, 0.06, 0.025, 1.0)
local ESP_COUNTER_CENTER = g_masterahsanyt_ESPColor(0.075, 0.080, 0.095, 1.0)

-- ESP gradient color made by @Masterpiece2025
local function g_masterahsanyt_ESPScaleColor(color, factor, alphaMul)
    if not color then return g_masterahsanyt_ESPColor(1, 1, 1, 1) end
    local r = math.max(0.0, math.min(1.0, (tonumber(color.R) or 1.0) * (factor or 1.0)))
    local g = math.max(0.0, math.min(1.0, (tonumber(color.G) or 1.0) * (factor or 1.0)))
    local b = math.max(0.0, math.min(1.0, (tonumber(color.B) or 1.0) * (factor or 1.0)))
    local a = math.max(0.0, math.min(1.0, (tonumber(color.A) or 1.0) * (alphaMul or 1.0)))
    return g_masterahsanyt_ESPColor(r, g, b, a)
end

local ESP_REAL_DARK  = g_masterahsanyt_ESPScaleColor(ESP_REAL, 0.68, 1.0)
local ESP_REAL_LIGHT = g_masterahsanyt_ESPScaleColor(ESP_REAL, 1.12, 0.82)
local ESP_BOT_DARK   = g_masterahsanyt_ESPScaleColor(ESP_BOT, 0.68, 1.0)
local ESP_BOT_LIGHT  = g_masterahsanyt_ESPScaleColor(ESP_BOT, 1.10, 0.82)
local ESP_WHITE_SOFT = g_masterahsanyt_ESPColor(0.94, 0.94, 0.94, 0.98)
local ESP_WHITE_GLOSS = g_masterahsanyt_ESPColor(1.0, 1.0, 1.0, 0.34)

local g_masterahsanyt_ESPTheme
do
local ESP_REAL_THEME = {Key="REAL",Main=ESP_REAL,Light=ESP_REAL_LIGHT,
    Text=g_masterahsanyt_ESPColor(1.0,0.86,0.84,1.0),
    Background=g_masterahsanyt_ESPColor(0.05,0.005,0.005,0.97),
    Empty=g_masterahsanyt_ESPColor(0.055,0.008,0.008,1.0)}
local ESP_BOT_THEME = {Key="BOT",Main=ESP_BOT,Light=ESP_BOT_LIGHT,
    Text=g_masterahsanyt_ESPColor(0.82,1.0,0.87,1.0),
    Background=g_masterahsanyt_ESPColor(0.005,0.05,0.015,0.97),
    Empty=g_masterahsanyt_ESPColor(0.008,0.055,0.018,1.0)}
g_masterahsanyt_ESPTheme=function(isBot)
    return isBot and ESP_BOT_THEME or ESP_REAL_THEME
end
end
-- ESP object validation made by @Masterpiece2025
local function g_masterahsanyt_ESPValid(obj)
    if not obj then return false end
    if not slua or not slua.isValid then return false end
    local ok, valid = pcall(slua.isValid, obj)
    return ok and valid == true
end

local ESPShared={}
function ESPShared.Finite(n)
    return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
function ESPShared.SafeNumber(value,fallback,lo,hi)
    local n=tonumber(value)
    if not ESPShared.Finite(n) then n=fallback end
    return math.max(lo,math.min(hi,n))
end
function ESPShared.VectorComponents(v) return tonumber(v.X),tonumber(v.Y),tonumber(v.Z) end
function ESPShared.VectorValues(v)
    if v==nil then return nil end
    local ok,x,y,z=pcall(ESPShared.VectorComponents,v)
    if ok and ESPShared.Finite(x) and ESPShared.Finite(y) and ESPShared.Finite(z)
        and math.abs(x)<1e12 and math.abs(y)<1e12 and math.abs(z)<1e12 then return x,y,z end
end

-- ESP timing made by @Masterpiece2025
local function g_masterahsanyt_ESPNow()
    local t = nil
    pcall(function()
        local w = (slua and slua.getWorld and slua.getWorld()) or nil
        if GameplayStaticsESP and w and GameplayStaticsESP.GetRealTimeSeconds then
            t = GameplayStaticsESP.GetRealTimeSeconds(w)
        end
    end)
    t=tonumber(t)
    if ESPShared.Finite(t) and t>=0 then return t end
    -- os.clock measures CPU time on some platforms, not elapsed frame time.
    -- If the engine clock is unavailable, advance by executed timer delays.
    return ESPShared.SafeNumber(g_masterahsanyt_ShotESP.TimerClock,0.0,0.0,1e12)
end

-- ESP world access made by @Masterpiece2025
local function g_masterahsanyt_ESPWorld()
    local w = nil
    pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
    return w
end

-- ESP player controller made by @Masterpiece2025
local function g_masterahsanyt_ESPGetController()
    local pc = nil
    pcall(function()
        local GDP = ESPGameplayData
        if GDP and GDP.GetPlayerController then pc = GDP.GetPlayerController() end
    end)
    if not g_masterahsanyt_ESPValid(pc) then
        pcall(function()
            if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
        end)
    end
    return g_masterahsanyt_ESPValid(pc) and pc or nil
end

-- ESP local player made by @Masterpiece2025
local function g_masterahsanyt_ESPGetLocalCharacter()
    local c = nil
    pcall(function()
        local GDP = ESPGameplayData
        if GDP then
            if GDP.GetPlayerCharacter then c = GDP.GetPlayerCharacter() end
            if not g_masterahsanyt_ESPValid(c) and GDP.GetLocalCharacter then c = GDP.GetLocalCharacter() end
        end
    end)
    if not g_masterahsanyt_ESPValid(c) then
        local pc = g_masterahsanyt_ESPGetController()
        pcall(function() if pc and pc.GetPawn then c = pc:GetPawn() end end)
    end
    return g_masterahsanyt_ESPValid(c) and c or nil
end

-- g_masterahsanyt_ESPGetPlayerState made by @Masterpiece2025
local function g_masterahsanyt_ESPGetPlayerState(character)
    if not g_masterahsanyt_ESPValid(character) then return nil end
    local ps = nil
    pcall(function()
        if character.GetPlayerStateSafety then ps = character:GetPlayerStateSafety() end
    end)
    if not g_masterahsanyt_ESPValid(ps) then
        pcall(function() if character.GetPlayerState then ps = character:GetPlayerState() end end)
    end
    if not g_masterahsanyt_ESPValid(ps) then
        pcall(function() ps = character.PlayerState end)
    end
    return g_masterahsanyt_ESPValid(ps) and ps or nil
end

-- g_masterahsanyt_ESPNormalizeName made by @Masterpiece2025
local function g_masterahsanyt_ESPNormalizeName(value)
    if value == nil or value == false then return nil end
    local ok, text = pcall(tostring, value)
    if not ok or not text then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == "nil" or text == "None" or text == "NULL" or text == "UNKNOWN" then return nil end
    if text:find("^userdata:") or text:find("^table:") then return nil end
    return text
end

-- ESP player name made by @Masterpiece2025
local function g_masterahsanyt_ESPResolvePlayerName(character)
    if not g_masterahsanyt_ESPValid(character) then return nil end
    local name = nil

-- take made by @Masterpiece2025
    local function take(value)
        if not name then name = g_masterahsanyt_ESPNormalizeName(value) end
    end

    pcall(function() if character.GetPlayerNameSafety then take(character:GetPlayerNameSafety()) end end)
    pcall(function() if not name and character.GetPlayerName then take(character:GetPlayerName()) end end)
    pcall(function() if not name then take(character.PlayerName) end end)
    pcall(function() if not name then take(character.NickName) end end)
    pcall(function() if not name then take(character.AIPlayerName) end end)
    pcall(function() if not name then take(character.BotName) end end)

    if not name then
        local ps = g_masterahsanyt_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
            pcall(function() if not name then take(ps.PlayerName) end end)
            pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
            pcall(function() if not name then take(ps.NickName) end end)
            pcall(function() if not name then take(ps.AccountName) end end)
            pcall(function() if not name then take(ps.AIPlayerName) end end)
        end
    end
    return name
end

-- g_masterahsanyt_ESPGetPlayerKey made by @Masterpiece2025
local function g_masterahsanyt_ESPGetPlayerKey(character)
    local key = nil
    pcall(function() if character.GetPlayerKey then key = character:GetPlayerKey() end end)
    if key == nil then pcall(function() key = character.PlayerKey end) end
    if key == nil then
        local ps = g_masterahsanyt_ESPGetPlayerState(character)
        if ps then pcall(function() key = ps.PlayerKey end) end
    end
    if key == nil or tostring(key) == "" or tostring(key) == "0" or tostring(key) == "-1" then
        return tostring(character)
    end
    return tostring(key) .. "_" .. tostring(character)
end

-- ESP team detection made by @Masterpiece2025
local function g_masterahsanyt_ESPGetTeamID(character)
    if not g_masterahsanyt_ESPValid(character) then return nil end
    local id = nil
    pcall(function() if character.GetTeamID then id = character:GetTeamID() end end)
    if id == nil then pcall(function() id = character.TeamID end) end
    if id == nil then
        local ps = g_masterahsanyt_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
            if id == nil then pcall(function() id = ps.TeamID end) end
        end
    end
    return id
end

-- ESP alive detection made by @Masterpiece2025
local ESPFinishedLastBreath,ESPDeadPawnState
pcall(function() ESPFinishedLastBreath=import("ECharacterHealthStatus").FinishedLastBreath end)
pcall(function() ESPDeadPawnState=EPawnState and EPawnState.Dead end)
local function ESPActorField(actor,key) return actor[key] end
local function ESPReadActorField(actor,key)
    local ok,value=pcall(ESPActorField,actor,key)
    if ok then return value end
end
local function ESPReadActorMethod(actor,key,...)
    local method=ESPReadActorField(actor,key)
    if type(method)=="function" then
        local ok,value=pcall(method,actor,...)
        if ok then return value end
    end
end
local function ESPActorDeadFlag(actor,key)
    local value=ESPReadActorField(actor,key)
    return value==true or value==1
end
local function g_masterahsanyt_ESPIsAlive(character)
    if not g_masterahsanyt_ESPValid(character) then return false,"invalid" end
    if ESPActorDeadFlag(character,"bDead") or ESPActorDeadFlag(character,"bIsDead")
        or ESPActorDeadFlag(character,"bIsDeadFlag") then return false,"dead" end
    if ESPFinishedLastBreath~=nil
        and ESPReadActorField(character,"HealthStatus")==ESPFinishedLastBreath then return false,"dead" end
    if ESPDeadPawnState~=nil then
        local state=ESPReadActorMethod(character,"HasPawnState",ESPDeadPawnState)
        if state==true or state==1 then return false,"dead" end
        state=ESPReadActorMethod(character,"HasState",ESPDeadPawnState)
        if state==true or state==1 then return false,"dead" end
    end
    local dead=ESPReadActorMethod(character,"IsDead")
    if dead==true or dead==1 then return false,"dead" end
    -- Knocked characters remain eligible even when their normal HP is zero.
    -- Terminal flags above always take precedence over the rescue state.
    local alive=ESPReadActorMethod(character,"IsAlive")
    if alive==true or alive==1 then return true,"alive" end
    local knocked=ESPReadActorMethod(character,"IsNearDeath")
    if knocked==true or knocked==1 then return true,"knocked" end
    if alive==false or alive==0 then return false,"dead" end
    local hp=ESPReadActorField(character,"Health")
    if not ESPShared.Finite(hp) then hp=ESPReadActorField(character,"HP") end
    if not ESPShared.Finite(hp) then hp=ESPReadActorMethod(character,"GetHealth") end
    if ESPShared.Finite(hp) then return hp>0,hp>0 and "alive" or "unknown" end
    -- Missing/failed replication is not positive evidence of life.
    return false,"unknown"
end

-- Event-driven V1/V2 visibility. The original shared life evaluator and Wall
-- renderer are deliberately untouched. 1=knocked, 2=confirmed dead, 3=exit pending.
ESPShared.Events={Records=setmetatable({}, {__mode="k"}),Clearers={}}
_G.LunarESPEvents=ESPShared.Events
do
    local E=ESPShared.Events
    function E.WorldChanged(world)
        if world==nil then return end
        if E.World~=nil and E.World~=world then
            if E.UnbindAll then E.UnbindAll() end
            E.Records=setmetatable({}, {__mode="k"})
        end
        E.World=world
    end

    local function eventActor(self)
        if not Client then return nil end
        -- Only queried on a native event, never by a new poll or timer. This
        -- prevents a first HUD update from discarding a new-world death event.
        E.WorldChanged(g_masterahsanyt_ESPWorld())
        return self and self.Object
    end

    function E.Clear(actor)
        for _,clear in ipairs(E.Clearers) do pcall(clear,actor) end
    end

    function E.Spawn(self)
        local actor=eventActor(self)
        if actor~=nil then E.Records[actor]=nil end
    end

    function E.Death(self)
        local actor=eventActor(self)
        if actor==nil then return end
        if E.Records[actor]~=2 then
            E.Records[actor]=2
            E.Clear(actor)
        end
    end

    function E.NearDeath(self,isNearDeath)
        local actor=eventActor(self)
        if actor==nil or E.Records[actor]==2 then return end
        local status=ESPReadActorField(actor,"HealthStatus")
        if ESPFinishedLastBreath~=nil and status==ESPFinishedLastBreath then
            E.Records[actor]=2
            E.Clear(actor)
        elseif isNearDeath==true or isNearDeath==1 then
            if E.Records[actor]~=1 then
                E.Records[actor]=1
                E.Clear(actor)
            end
        elseif isNearDeath==false or isNearDeath==0 then
            -- False can also accompany death. Do not equate it with rescue;
            -- require the original life result in the existing ESP pass too.
            if E.Records[actor]==1 then
                E.Records[actor]=3
                E.Clear(actor)
            end
        end
    end

    function E.Counted(actor)
        -- Keep the original counter's knocked-player behavior; only confirmed
        -- death adds an exclusion. Never change Frame.Entries[actor].Alive.
        return E.Records[actor]~=2
    end

    function E.Visible(actor,snapshot)
        local state=E.Records[actor]
        if state==2 or state==1 then return false end
        if state==3 then
            if not snapshot or not snapshot.Alive or snapshot.LifeState=="knocked" then return false end
            -- Preserve the original map-specific IsAlive/GetHealth priority.
            -- A stale zero HP field must not permanently hide a rescued pawn.
            -- Only a confirmed death event/status can set state 2.
            E.Records[actor]=nil
        end
        return snapshot and snapshot.Alive and snapshot.LifeState~="knocked"
    end

    function E.Project(pc,actor,state)
        local snapshot=ESPShared.GetFrameRecord(actor)
        if not E.Visible(actor,snapshot) then return nil,nil,false,"life" end
        local head,feet,onScreen,reason=ESPShared.ProjectActor(pc,actor,state)
        -- A native call can dispatch a lifecycle event during projection.
        if not E.Visible(actor,snapshot) then return nil,nil,false,"life" end
        return head,feet,onScreen,reason
    end

    function E.ClearIn(state,prune,actor)
        -- Reuse the existing pooled-widget cleanup. All keys except this
        -- actor's are kept, including actors beyond the display budget.
        for _,item in ipairs(state.Enemies) do
            if item.Character==actor then
                local key=item.Key
                local keep=setmetatable({[key]=false},{__index=function() return true end})
                state.Active[key]=nil
                state.Alive[key]=nil
                if state.LastProjected then state.LastProjected[key]=nil end
                prune(keep,keep)
            end
        end
    end

    -- Independent SLua multicast listeners. No CharacterBase method is changed.
    -- Add(function) returns an integer handle; Remove(handle) removes that
    -- listener only. See Tencent/sluaunreal LuaDelegate.cpp, LuaMultiDelegate.
    -- Insert this chunk inside the existing ESPShared.Events do/end block,
    -- replacing only the three BRPlayerCharacterBase handler overrides.
    local oldObserver=_G.__LunarESPEventObserver
    if oldObserver and oldObserver~=E and type(oldObserver.UnbindAll)=="function" then
        pcall(oldObserver.UnbindAll)
    end
    _G.__LunarESPEventObserver=E
    E.Bindings={}
    E.BindingCount=0
    E.BindingLimit=512
    E.ObserverDiagnostics={Bound=0,Unsupported=0,AddErrors=0,RemoveErrors=0}
    local observerGeneration=1
    local dispatchDepth=0
    local pendingAll=false
    local pendingActors={}

    local function observerMember(object,key)
        if object==nil then return nil end
        local ok,value=pcall(function() return object[key] end)
        if ok then return value end
    end
    local function observerValid(actor)
        if actor==nil then return false end
        if not slua or type(slua.isValid)~="function" then return false end
        local ok,yes=pcall(slua.isValid,actor)
        return ok and yes==true
    end
    local function removeBinding(actor,row)
        if E.Bindings[actor]~=row then return end
        E.Bindings[actor]=nil
        E.BindingCount=math.max(0,E.BindingCount-1)
        row.Active=false
        local tracked=_G.g_masterahsanyt_TrackedCharacters
        local key=tostring(actor)
        if tracked and tracked[key]==actor then tracked[key]=nil end
        row.Actor[1]=nil
        for _,owned in ipairs(row.Handles) do
            local remove=observerMember(owned.Delegate,"Remove")
            if type(remove)=="function" then
                local ok=pcall(remove,owned.Delegate,owned.Handle)
                if not ok then E.ObserverDiagnostics.RemoveErrors=E.ObserverDiagnostics.RemoveErrors+1 end
            end
        end
        row.Handles={}
    end
    local function flushObserverCleanup()
        if dispatchDepth~=0 then return end
        if pendingAll then
            pendingAll=false
            for actor,row in pairs(E.Bindings) do removeBinding(actor,row) end
            pendingActors={}
        else
            for actor in pairs(pendingActors) do
                pendingActors[actor]=nil
                local row=E.Bindings[actor]
                if row then removeBinding(actor,row) end
            end
        end
    end
    function E.UnbindAll()
        -- Removing a Lua delegate during its native multicast dispatch is
        -- unsafe in SLua. Invalidate now; flush on the next existing ESP pass.
        observerGeneration=observerGeneration+1
        pendingAll=true
        for _,row in pairs(E.Bindings) do row.Active=false end
        flushObserverCleanup()
    end
    function E.Unobserve(actor)
        local row=E.Bindings[actor]
        if not row then return end
        row.Active=false
        if dispatchDepth~=0 then pendingActors[actor]=true
        else removeBinding(actor,row) end
    end
    local eventSpecs={
        {Name="IsEnterNearDeathDelegate",Handler="NearDeath"},
        {Name="OnDeathDelegate",Handler="Death"},
        {Name="OnPawnRespawnDelegate",Handler="Spawn"}
    }
    function E.Observe(actor)
        if not Client or actor==nil then return false end
        if pendingAll or next(pendingActors)~=nil then flushObserverCleanup() end
        local row=E.Bindings[actor]
        if row then return row.Bound end
        if not observerValid(actor) then return false end
        -- A hard bound limits listener retention even if enumeration fails.
        -- Unsupported actors still use the original live-state fallback.
        if E.BindingCount>=E.BindingLimit then return false end
        row={Active=true,Generation=observerGeneration,
            Actor=setmetatable({actor},{__mode="v"}),Handles={},Bound=false}
        E.Bindings[actor]=row
        E.BindingCount=E.BindingCount+1
        -- Native class lifecycle stays untouched. Existing pawn discovery
        -- supplies tracking/maintenance, and native respawn delegates clear ESP.
        _G.g_masterahsanyt_TrackedCharacters=_G.g_masterahsanyt_TrackedCharacters or {}
        _G.g_masterahsanyt_TrackedCharacters[tostring(actor)]=actor
        if g_masterahsanyt_StartSettingsMaintenance then
            pcall(g_masterahsanyt_StartSettingsMaintenance,actor)
        end
        if not _G._BYPASS_DONE and type(_G._BYPASS_Execute)=="function" then
            pcall(_G._BYPASS_Execute)
        end
        for _,spec in ipairs(eventSpecs) do
            local delegate=observerMember(actor,spec.Name)
            local add=observerMember(delegate,"Add")
            local remove=observerMember(delegate,"Remove")
            if type(add)=="function" and type(remove)=="function" then
                local handler=spec.Handler
                local function observed(...)
                    local current=row.Actor[1]
                    if not row.Active or row.Generation~=observerGeneration
                        or _G.LunarESPEvents~=E or not observerValid(current) then return end
                    dispatchDepth=dispatchDepth+1
                    -- The existing state machine accepts self.Object. This
                    -- transient wrapper is never installed on a native class.
                    pcall(E[handler],{Object=current},...)
                    dispatchDepth=dispatchDepth-1
                    -- Cleanup is intentionally deferred until Observe/Sync.
                end
                local ok,handle=pcall(add,delegate,observed)
                if ok and type(handle)=="number" and handle>0 then
                    row.Handles[#row.Handles+1]={Delegate=delegate,Handle=handle}
                    row.Bound=true
                    E.ObserverDiagnostics.Bound=E.ObserverDiagnostics.Bound+1
                else
                    E.ObserverDiagnostics.AddErrors=E.ObserverDiagnostics.AddErrors+1
                end
            else
                E.ObserverDiagnostics.Unsupported=E.ObserverDiagnostics.Unsupported+1
            end
        end
        return row.Bound
    end
    function E.SyncObservedPawns(pawns)
        -- Called with the already-enumerated GetAllPlayerPawns result, never
        -- obtains a second actor list and never schedules another timer.
        flushObserverCleanup()
        for actor,row in pairs(E.Bindings) do
            -- Enumeration can temporarily omit a still-valid pawn. Keep its
            -- existing lifecycle listeners and death record so stale HP on
            -- return cannot resurrect ESP, and a real respawn while omitted
            -- can still release the record. Native invalidation/world reset
            -- removes these bounded listeners; no new poll or timer is added.
            if not observerValid(actor) then
                E.Unobserve(actor)
                E.Records[actor]=nil
            end
        end
        -- Native arrays are also observed by the existing GetFrameRecord
        -- pass. Even an unavailable/non-table list must release invalid rows.
        if type(pawns)~="table" then return end
        for _,actor in pairs(pawns) do
            if actor~=nil then E.Observe(actor) end
        end
    end

end

-- Bot cache uses the same actor/player key as pruning, with replication retries.
local function g_masterahsanyt_ESPIsBot(character, key, providedCache, providedNow)
    if not g_masterahsanyt_ESPValid(character) then return false end
    key = key or g_masterahsanyt_ESPGetPlayerKey(character)
    local cache = providedCache or g_masterahsanyt_ShotESP._BotCache
    local now = providedNow or g_masterahsanyt_ShotESP.Now
    local entry = cache[key]
    if entry and now >= entry.Clock and now - entry.Clock < 2.0 then return entry.Value end
    local result = nil
    local function take(v)
        if result == nil and (v == true or v == false or v == 1 or v == 0) then
            result = (v == true or v == 1)
        end
    end
    pcall(function() if Game and Game.IsAI then take(Game:IsAI(character)) end end)
    if result == nil then pcall(function() take(character.bIsAI) end) end
    if result == nil then pcall(function() if character.IsBot then take(character:IsBot()) end end) end
    if result == nil then
        local ps = g_masterahsanyt_ESPGetPlayerState(character)
        if ps then
            pcall(function() take(ps.bIsABot) end)
            pcall(function() take(ps.bIsBot) end)
            pcall(function() take(ps.bIsAI) end)
            if result == nil then pcall(function() if ps.IsBot then take(ps:IsBot()) end end) end
        end
    end
    -- Unresolved replication data is never cached as a permanent false.
    cache[key] = result ~= nil and {Value=result, Clock=now} or nil
    return result == true
end

-- ESP actor position made by @Masterpiece2025
local function g_masterahsanyt_ESPActorLocation(character)
    local loc = nil
    if not g_masterahsanyt_ESPValid(character) then return nil end
    pcall(function()
        if character.K2_GetActorLocation then loc = character:K2_GetActorLocation()
        elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(character) end
    end)
    return loc
end

-- ESP distance calculation made by @Masterpiece2025
local function g_masterahsanyt_ESPDistanceMeters(a,b)
    local ax,ay,az=ESPShared.VectorValues(a)
    local bx,by,bz=ESPShared.VectorValues(b)
    if not ax or not bx then return math.huge end
    local dx,dy,dz=ax-bx,ay-by,az-bz
    return math.sqrt(dx*dx+dy*dy+dz*dz)/100.0
end


-- A memo lives for one scheduler callback only.
-- Callback-local values never retain actors, controllers or native locations
-- after Finish. The bounded pool keeps only reusable vector buffers.
ESPShared.Frame={Active=false,Entries={},Pool={},PoolLimit=256,Now=0,ViewAt=-999,Controllers={},Transforms={},TransformPool={}}
function ESPShared.Frame.Finish()
    local frame=ESPShared.Frame
    for actor,entry in pairs(frame.Entries) do
        frame.Entries[actor]=nil
        entry.Location=nil;entry.LocationX=nil;entry.LocationY=nil;entry.LocationZ=nil
        entry.DistanceOrigin=nil;entry.DistanceSquared=nil;entry.DistanceMeters=nil
        entry.Alive=false;entry.Projected=false;entry.OnScreen=false
        entry.HasHead=false;entry.HasFeet=false;entry.PC=nil
        if #frame.Pool<frame.PoolLimit then frame.Pool[#frame.Pool+1]=entry end
    end
    for pc in pairs(frame.Controllers) do frame.Controllers[pc]=nil end
    for state,value in pairs(frame.Transforms) do
        frame.Transforms[state]=nil
        if #frame.TransformPool<4 then frame.TransformPool[#frame.TransformPool+1]=value end
    end
    frame.DistanceOrigin=nil;frame.OriginX=nil;frame.OriginY=nil;frame.OriginZ=nil
    frame.Pawns=nil;frame.Active=false;frame.V1CanvasChecked=false
end
function ESPShared.Frame.Begin(now)
    ESPShared.Frame.Finish()
    ESPShared.Frame.Now=now;ESPShared.Frame.Active=true
end
function ESPShared.GetFrameRecord(actor)
    local frame=ESPShared.Frame
    local entry=frame.Active and frame.Entries[actor]
    if entry then return entry end
    if ESPShared.Events.Observe then ESPShared.Events.Observe(actor) end
    entry=frame.Active and table.remove(frame.Pool) or nil
    if not entry then entry={} end
    entry.Alive,entry.LifeState=g_masterahsanyt_ESPIsAlive(actor)
    entry.Projected=false;entry.OnScreen=false;entry.HasHead=false;entry.HasFeet=false
    entry.Location=entry.Alive and g_masterahsanyt_ESPActorLocation(actor) or nil
    entry.LocationX,entry.LocationY,entry.LocationZ=ESPShared.VectorValues(entry.Location)
    if not entry.LocationX then entry.Location=nil end
    if frame.Active and actor~=nil then frame.Entries[actor]=entry end
    return entry
end
function ESPShared.GetFramePawns()
    if ESPShared.Frame.Active and ESPShared.Frame.Pawns then return ESPShared.Frame.Pawns end
    local pawns
    pcall(function() if Game and Game.GetAllPlayerPawns then pawns=Game:GetAllPlayerPawns() end end)
    -- The native CharacterBase already maintains this public registry.
    -- Read it only when the engine pawn getter is unavailable; no native
    -- AddCharacter/RemoveCharacter or lifecycle method is replaced.
    if not pawns and GameplayData then
        if type(GameplayData.GetAllPlayerCharacters)=="function" then
            pcall(function()pawns=GameplayData.GetAllPlayerCharacters()end)
        end
        if not pawns and type(GameplayData.GetAllCharacters)=="function" then
            pcall(function()pawns=GameplayData.GetAllCharacters()end)
        end
    end
    if ESPShared.Frame.Active then ESPShared.Frame.Pawns=pawns end
    local E=ESPShared.Events
    local now=ESPShared.Frame.Active and ESPShared.Frame.Now or g_masterahsanyt_ESPNow()
    if E.SyncObservedPawns and (not E.SyncDue or now>=E.SyncDue or now<(E.SyncClock or now)) then
        E.SyncObservedPawns(pawns);E.SyncDue=now+1;E.SyncClock=now
    end
    return pawns
end
function ESPShared.DistanceSquaredFrom(entry,origin)
    if not entry or not entry.LocationX then return math.huge end
    local frame=ESPShared.Frame
    if frame.Active and entry.DistanceOrigin==origin and entry.DistanceSquared~=nil then return entry.DistanceSquared end
    local x,y,z
    if frame.Active and frame.DistanceOrigin==origin then
        x,y,z=frame.OriginX,frame.OriginY,frame.OriginZ
    else
        x,y,z=ESPShared.VectorValues(origin)
        if frame.Active then frame.DistanceOrigin=origin;frame.OriginX=x;frame.OriginY=y;frame.OriginZ=z end
    end
    if not x then
        if frame.Active then entry.DistanceOrigin=origin;entry.DistanceSquared=math.huge;entry.DistanceMeters=nil end
        return math.huge
    end
    local dx,dy,dz=x-entry.LocationX,y-entry.LocationY,z-entry.LocationZ
    local squared=dx*dx+dy*dy+dz*dz
    if frame.Active then entry.DistanceOrigin=origin;entry.DistanceSquared=squared;entry.DistanceMeters=nil end
    return squared
end
function ESPShared.DistanceMetersFrom(entry,origin)
    local squared=ESPShared.DistanceSquaredFrom(entry,origin)
    if ESPShared.Frame.Active and entry.DistanceMeters~=nil then return entry.DistanceMeters end
    local distance=math.sqrt(squared)/100.0
    if ESPShared.Frame.Active then entry.DistanceMeters=distance end
    return distance
end
function ESPShared.InRange(entry,origin,maxRange)
    if not ESPShared.Finite(maxRange) or maxRange<=0 then return ESPShared.DistanceMetersFrom(entry,origin)<=maxRange end
    local squared=ESPShared.DistanceSquaredFrom(entry,origin)
    if squared==math.huge then return false end
    local limit=maxRange*100.0;limit=limit*limit
    -- Preserve the original sqrt/division decision at floating-point boundaries.
    if math.abs(squared-limit)<=math.max(1,limit)*1e-12 then
        return ESPShared.DistanceMetersFrom(entry,origin)<=maxRange
    end
    return squared<limit
end
function ESPShared.ProjectionControllerValid(pc)
    if pc==nil then return false end
    local frame=ESPShared.Frame
    if frame.Active then
        local cached=frame.Controllers[pc]
        if cached~=nil then return cached end
        local valid=g_masterahsanyt_ESPValid(pc);frame.Controllers[pc]=valid;return valid
    end
    return g_masterahsanyt_ESPValid(pc)
end
function ESPShared.CanvasTransform(state)
    local frame=ESPShared.Frame
    local value=frame.Active and frame.Transforms[state]
    local rx,ry,rox,roy=state.CanvasScaleX,state.CanvasScaleY,state.CanvasOffsetX,state.CanvasOffsetY
    if not value or value.RX~=rx or value.RY~=ry or value.ROX~=rox or value.ROY~=roy then
        value=value or (frame.Active and table.remove(frame.TransformPool)) or {}
        value.RX=rx;value.RY=ry;value.ROX=rox;value.ROY=roy
        value.SX=ESPShared.SafeNumber(rx,1,0.00001,100)
        value.SY=ESPShared.SafeNumber(ry,1,0.00001,100)
        value.OX=ESPShared.SafeNumber(rox,0,-1e7,1e7)
        value.OY=ESPShared.SafeNumber(roy,0,-1e7,1e7)
        if frame.Active then frame.Transforms[state]=value end
    end
    return value.SX,value.SY,value.OX,value.OY
end
function ESPShared.AssignProbeVector(vector,x,y,z)
    vector.X=x;vector.Y=y;vector.Z=z
end
function ESPShared.UpdateProbeVector(vector,x,y,z)
    if vector and pcall(ESPShared.AssignProbeVector,vector,x,y,z) then return vector end
    return g_masterahsanyt_ESPV3(x,y,z)
end

-- Validate all cached candidates before display caps. Reuse the list and alive
-- map, so dead/out-of-range actors are pruned on the next scheduled HUD update.
local function g_masterahsanyt_ESPFilterEnemies(list, myLocation, maxRange, alive)
    for key in pairs(alive) do alive[key]=nil end
    local count,kept,realCount,botCount=#list,0,0,0
    maxRange=tonumber(maxRange) or 450.0
    if maxRange~=maxRange or maxRange<=0 or maxRange==math.huge then maxRange=450.0 end
    for i=1,count do
        local item=list[i]
        local character=item and item.Character
        local snapshot=item and item.Key and ESPShared.GetFrameRecord(character)
        if snapshot and snapshot.Alive and ESPShared.Events.Counted(character) then
            local location=snapshot.Location
            local distance=ESPShared.DistanceMetersFrom(snapshot,myLocation)
            if distance<=maxRange then
                item.Distance=distance
                kept=kept+1;list[kept]=item;alive[item.Key]=true
                if item.IsBot then botCount=botCount+1 else realCount=realCount+1 end
            end
        end
    end
    for i=kept+1,count do list[i]=nil end
    return realCount,botCount
end

-- ESP character vertical bounds made by @Masterpiece2025
local function g_masterahsanyt_ESPGetCharacterVerticalBounds(character,cachedLocation)
    if not g_masterahsanyt_ESPValid(character) then return nil, nil end

    local center, halfHeight = nil, nil
    local capsule = nil

    pcall(function()
        if character.GetCapsuleComponent then
            capsule = character:GetCapsuleComponent()
        elseif character.CapsuleComponent then
            capsule = character.CapsuleComponent
        end
    end)

    if capsule and g_masterahsanyt_ESPValid(capsule) then
        pcall(function()
            if capsule.K2_GetComponentLocation then
                center = capsule:K2_GetComponentLocation()
            elseif capsule.GetComponentLocation then
                center = capsule:GetComponentLocation()
            end

            if capsule.GetScaledCapsuleHalfHeight then
                halfHeight = capsule:GetScaledCapsuleHalfHeight()
            elseif capsule.GetUnscaledCapsuleHalfHeight then
                halfHeight = capsule:GetUnscaledCapsuleHalfHeight()
            elseif capsule.CapsuleHalfHeight then
                halfHeight = capsule.CapsuleHalfHeight
            end
        end)
    end

    local cx,cy,cz=ESPShared.VectorValues(center)
    if center and not cx then center=nil end
    if not center then center=cachedLocation end
    if not center then
        pcall(function()
            if character.K2_GetActorLocation then
                center = character:K2_GetActorLocation()
            end
        end)
    end

    if not center then
        pcall(function()
            if Game and Game.GetActorLocation then
                center = Game:GetActorLocation(character)
            end
        end)
    end

    if not cx then cx,cy,cz=ESPShared.VectorValues(center) end
    if not cx then return nil,nil end

    halfHeight=tonumber(halfHeight)
    if not ESPShared.Finite(halfHeight) or halfHeight<10 or halfHeight>200 then
        halfHeight = 85
        pcall(function()
            if character.bIsCrouched then halfHeight = 60 end
            if character.IsProne and character:IsProne() then halfHeight = 25 end
        end)
    end

    return center, halfHeight, cx, cy, cz
end

-- ESP head and feet position made by @Masterpiece2025
local function g_masterahsanyt_ESPGetCharacterBoxLocs(character,cachedLocation)
    local center, halfHeight, x, y, z = g_masterahsanyt_ESPGetCharacterVerticalBounds(character,cachedLocation)
    if not x or not halfHeight then return nil,nil end

    local headLoc = g_masterahsanyt_ESPV3(
        x,
        y,
        z + halfHeight
    )

    local feetLoc = g_masterahsanyt_ESPV3(
        x,
        y,
        z - halfHeight
    )

    return headLoc, feetLoc, center
end

-- ESP head position made by @Masterpiece2025

-- ESP feet position made by @Masterpiece2025

-- Bounded inactive HUD widgets. Records retain native widget/slot structure,
-- never an enemy key, actor, name, delegate, bone mesh or controller. Collapsed
-- widgets stay under the same canvas so reuse does not allocate CanvasSlots.
local ESPWidgetPool={}
do
local shapes={
    Line={Fields={"Widget","Slot","PosVec","SizeVec","VectorReuseDisabled"},Check={"Widget","Slot"},Limit=256},
    NameV2={Fields={"Widget","Text","DistanceText","TextSlot","DistanceSlot","Slot"},
        Check={"Widget","Text","DistanceText","TextSlot","DistanceSlot","Slot"},Limit=16},
    NameV1={Fields={"Widget","BottomLine","HealthBg","HealthFill","Text","DistanceText",
        "LineSlot","HealthBgSlot","HealthFillSlot","TextSlot","DistanceSlot","Slot"},
        Check={"Widget","BottomLine","HealthBg","HealthFill","Text","DistanceText",
        "LineSlot","HealthBgSlot","HealthFillSlot","TextSlot","DistanceSlot","Slot"},Limit=16},
    Decor={Fields={"Widget","Slot","Groups"},Check={"Widget","Slot"},Limit=8},
    Header={Fields={"Widget","Slot","Groups"},Check={"Widget","Slot"},Limit=8},
}
local function remove(widget,pool)
    if pool and pool.Remove then pool.Remove(widget)
    elseif widget then pcall(function() widget:RemoveFromParent() end) end
end
local function weight(data)
    local count=1
    if data.Groups then
        for _,group in pairs(data.Groups) do count=count+#group end
    elseif data.Text then count=data.BottomLine and 6 or 3 end
    return count
end
local function resetGroups(groups)
    if not groups then return end
    for _,group in pairs(groups) do
        for field in pairs(group) do if type(field)~="number" then group[field]=nil end end
        for _,piece in ipairs(group) do
            local w,s,pv,sv,disabled=piece.Widget,piece.Slot,piece.PosVec,piece.SizeVec,piece.VectorReuseDisabled
            for field in pairs(piece) do piece[field]=nil end
            piece.Widget,piece.Slot,piece.PosVec,piece.SizeVec,piece.VectorReuseDisabled=w,s,pv,sv,disabled
            piece.Visible=false
        end
    end
end
function ESPWidgetPool.New(capacity)
    return {Bins={},Canvas=nil,Enabled=true,Weight=0,Capacity=capacity,
        Reused=0,Released=0,Created=0,Discarded=0}
end
ESPWidgetPool.V2=ESPWidgetPool.New(1024)
ESPWidgetPool.V1=ESPWidgetPool.New(128)
function ESPWidgetPool.Flush(pool)
    for kind,bin in pairs(pool.Bins) do
        for i=#bin,1,-1 do
            local item=bin[i];bin[i]=nil;remove(item.Widget,pool)
            for key in pairs(item) do item[key]=nil end
        end
        pool.Bins[kind]=nil
    end
    pool.Canvas=nil;pool.Weight=0
end
function ESPWidgetPool.Tag(pool,kind,canvas,data)
    if pool.Canvas~=canvas then ESPWidgetPool.Flush(pool);pool.Canvas=canvas end
    data.PoolOwner=pool;data.PoolKind=kind;data.PoolCanvas=canvas
    pool.Created=pool.Created+1
    return data
end
function ESPWidgetPool.Release(data)
    if data.PoolReleased then return true end
    local pool,kind,canvas=data.PoolOwner,data.PoolKind,data.PoolCanvas
    if not pool or not pool.Enabled or pool.Canvas~=canvas or data.Broken
        or not g_masterahsanyt_ESPValid(data.Widget) then return false end
    local shape=shapes[kind]
    if not shape then return false end
    local bin=pool.Bins[kind]
    if not bin then bin={};pool.Bins[kind]=bin end
    local cost=weight(data)
    if #bin>=shape.Limit or pool.Weight+cost>pool.Capacity then return false end
    local ok=pcall(function()
        data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        if data.Text then data.Text:SetText("") end
        if data.DistanceText then data.DistanceText:SetText("") end
        if data.Groups then
            for _,group in pairs(data.Groups) do
                for _,piece in ipairs(group) do
                    if piece.Broken then error("POOL_BROKEN_PIECE") end
                    if piece.Visible~=false then
                        piece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end
        end
    end)
    if not ok then return false end
    resetGroups(data.Groups)
    local item={Weight=cost}
    for _,field in ipairs(shape.Fields) do item[field]=data[field] end
    -- Clear even caller-added fields so a reference never follows another enemy.
    for field in pairs(data) do data[field]=nil end
    data.PoolReleased=true
    bin[#bin+1]=item;pool.Weight=pool.Weight+cost;pool.Released=pool.Released+1
    return true
end
function ESPWidgetPool.Take(pool,kind,canvas)
    if pool.Canvas~=canvas then ESPWidgetPool.Flush(pool);pool.Canvas=canvas end
    if not pool.Enabled then return nil end
    local shape,bin=shapes[kind],pool.Bins[kind]
    if not shape or not bin then return nil end
    while #bin>0 do
        local item=bin[#bin];bin[#bin]=nil;pool.Weight=pool.Weight-item.Weight
        local valid=true
        for _,field in ipairs(shape.Check) do
            if not g_masterahsanyt_ESPValid(item[field]) then valid=false;break end
        end
        if valid and item.Groups then
            for _,group in pairs(item.Groups) do
                for _,piece in ipairs(group) do
                    if not g_masterahsanyt_ESPValid(piece.Widget) or not g_masterahsanyt_ESPValid(piece.Slot) then
                        valid=false;break
                    end
                end
                if not valid then break end
            end
        end
        -- Missing bindings or externally detached/reparented widgets fall back
        -- to normal construction, rather than assuming their CanvasSlot works.
        if valid then
            local ok,parent=pcall(function() return item.Widget:GetParent() end)
            valid=ok and parent==canvas
        end
        if valid then
            local data={PoolOwner=pool,PoolKind=kind,PoolCanvas=canvas}
            for _,field in ipairs(shape.Fields) do data[field]=item[field] end
            resetGroups(data.Groups)
            pool.Reused=pool.Reused+1
            return data
        end
        remove(item.Widget,pool);pool.Discarded=pool.Discarded+1
        for key in pairs(item) do item[key]=nil end
    end
    return nil
end
end

-- ESP widget destroy made by @Masterpiece2025
local function g_masterahsanyt_ESPDestroyWidgetData(data)
    if not data then return end
    if ESPWidgetPool.Release(data) then return end
    for _, field in ipairs({"Widget", "Container", "Text", "DistanceText"}) do
        local widget=data[field]
        if g_masterahsanyt_ESPValid(widget) then
            pcall(function() widget:RemoveFromParent() end)
        end
    end
end

-- ESP widget cleanup made by @Masterpiece2025
local function g_masterahsanyt_ESPResetWidgets()
    ESPWidgetPool.V2.Enabled=false
    for _, data in pairs(g_masterahsanyt_ShotESP.Lines) do g_masterahsanyt_ESPDestroyWidgetData(data) end
    for _, data in pairs(g_masterahsanyt_ShotESP.Names) do g_masterahsanyt_ESPDestroyWidgetData(data) end
    for _, group in pairs(g_masterahsanyt_ShotESP.Boxes) do for _,data in ipairs(group) do g_masterahsanyt_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_masterahsanyt_ShotESP.HealthBars) do for _,data in ipairs(group) do g_masterahsanyt_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_masterahsanyt_ShotESP.Skeletons) do for _,data in ipairs(group) do g_masterahsanyt_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_masterahsanyt_ShotESP.Headers) do for _,data in ipairs(group) do g_masterahsanyt_ESPDestroyWidgetData(data) end end
    for _, group in pairs(g_masterahsanyt_ShotESP.Footers) do for _,data in ipairs(group) do g_masterahsanyt_ESPDestroyWidgetData(data) end end
    g_masterahsanyt_ShotESP.Lines = {}
    g_masterahsanyt_ShotESP.Names = {}
    g_masterahsanyt_ShotESP.Boxes = {}
    g_masterahsanyt_ShotESP.HealthBars = {}
    g_masterahsanyt_ShotESP.Skeletons = {}
    for _, data in pairs(g_masterahsanyt_ShotESP.HeaderRoots) do g_masterahsanyt_ESPDestroyWidgetData(data) end
    g_masterahsanyt_ShotESP.HeaderRoots = {}
    g_masterahsanyt_ShotESP.Headers = {}
    g_masterahsanyt_ShotESP.Footers = {}
    g_masterahsanyt_ShotESP.BuildStage = {}
    g_masterahsanyt_ShotESP.BoneNameCache = {}
    for _,data in pairs(g_masterahsanyt_ShotESP.Decorations) do g_masterahsanyt_ESPDestroyWidgetData(data) end
    g_masterahsanyt_ShotESP.Decorations = {}
    if g_masterahsanyt_ShotESP.Counter then g_masterahsanyt_ESPDestroyWidgetData(g_masterahsanyt_ShotESP.Counter) end
    g_masterahsanyt_ShotESP.Counter = nil
    g_masterahsanyt_ShotESP.Canvas = nil
    g_masterahsanyt_ShotESP.RootUI = nil
    g_masterahsanyt_ShotESP.Enemies = {}
    g_masterahsanyt_ShotESP.Active = {}
    g_masterahsanyt_ShotESP.Alive = {}
    g_masterahsanyt_ShotESP.BoneMeshes = {}
    g_masterahsanyt_ShotESP.BonePoints = {}
    g_masterahsanyt_ShotESP.TemplateFont = nil
    g_masterahsanyt_ShotESP.TemplateFontObject = nil
    g_masterahsanyt_ShotESP.TemplateTypeface = nil
    g_masterahsanyt_ShotESP.TemplateColorAndOpacity = nil
    g_masterahsanyt_ShotESP.ViewportW, g_masterahsanyt_ShotESP.ViewportH = nil, nil
    g_masterahsanyt_ShotESP.RawViewportW, g_masterahsanyt_ShotESP.RawViewportH = nil, nil
    g_masterahsanyt_ShotESP.TracerOrigin = nil
    g_masterahsanyt_ShotESP.LastScanClock = -999.0
    g_masterahsanyt_ShotESP.LastTransformClock = -999.0
    g_masterahsanyt_ShotESP.LastController = nil
    g_masterahsanyt_ShotESP.LastPawn = nil
    g_masterahsanyt_ShotESP._BotCache = {}
    g_masterahsanyt_ShotESP.RealCount = 0
    g_masterahsanyt_ShotESP.BotCount = 0
    ESPWidgetPool.Flush(ESPWidgetPool.V2)
    ESPWidgetPool.V2.Enabled=true
end

-- ESP HUD canvas made by @Masterpiece2025
local function g_masterahsanyt_ESPGetCanvas()
    if g_masterahsanyt_ESPValid(g_masterahsanyt_ShotESP.Canvas) then return g_masterahsanyt_ShotESP.Canvas end
    local root = nil
    pcall(function()
        local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if InGameUITools and InGameUITools.GetMainControlBaseUI then root = InGameUITools.GetMainControlBaseUI() end
    end)
    if not g_masterahsanyt_ESPValid(root) then return nil end
    g_masterahsanyt_ShotESP.RootUI = root
    local canvas = nil
    pcall(function()
        if g_masterahsanyt_ESPValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
        elseif g_masterahsanyt_ESPValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
    end)
    if g_masterahsanyt_ESPValid(canvas) then g_masterahsanyt_ShotESP.Canvas = canvas return canvas end
    return nil
end

-- Discover a valid FontObject from existing HUD TextBlocks so dynamic TextBlocks always render glyphs
local function g_masterahsanyt_ESPGetTemplateTextStyle()
    if g_masterahsanyt_ESPValid(g_masterahsanyt_ShotESP.TemplateFontObject) then
        return g_masterahsanyt_ShotESP.TemplateFont
    end

    local visited = 0
    local function scanWidget(w, depth)
        if not w or depth > 6 or visited > 250 then return false end
        if not g_masterahsanyt_ESPValid(w) then return false end
        visited = visited + 1

        local found = false
        pcall(function()
            if w.SetText and w.SetFont and w.Font then
                local f = w.Font
                if f and g_masterahsanyt_ESPValid(f.FontObject) then
                    g_masterahsanyt_ShotESP.TemplateFont = f
                    g_masterahsanyt_ShotESP.TemplateFontObject = f.FontObject
                    pcall(function() g_masterahsanyt_ShotESP.TemplateTypeface = f.TypefaceFontName end)
                    pcall(function() g_masterahsanyt_ShotESP.TemplateColorAndOpacity = w.ColorAndOpacity end)
                    found = true
                end
            end
        end)
        if found then return true end

        local childCount = 0
        pcall(function() if w.GetChildrenCount then childCount = tonumber(w:GetChildrenCount()) or 0 end end)
        for i = 0, childCount - 1 do
            local child = nil
            pcall(function() child = w:GetChildAt(i) end)
            if child and scanWidget(child, depth + 1) then return true end
        end

        local treeRoot = nil
        pcall(function() if w.WidgetTree and w.WidgetTree.RootWidget then treeRoot = w.WidgetTree.RootWidget end end)
        if treeRoot and treeRoot ~= w and scanWidget(treeRoot, depth + 1) then return true end

        return false
    end

    local canvas = g_masterahsanyt_ESPGetCanvas()
    if canvas then scanWidget(canvas, 0) end
    if not g_masterahsanyt_ESPValid(g_masterahsanyt_ShotESP.TemplateFontObject) and g_masterahsanyt_ESPValid(g_masterahsanyt_ShotESP.RootUI) then
        scanWidget(g_masterahsanyt_ShotESP.RootUI, 0)
    end

    if not g_masterahsanyt_ESPValid(g_masterahsanyt_ShotESP.TemplateFontObject) and slua and slua.loadObject then
        for _, path in ipairs({
            "/Engine/EngineFonts/Roboto.Roboto",
            "/Engine/EngineFonts/Roboto",
            "/Engine/EngineFonts/DroidSansFallback.DroidSansFallback"
        }) do
            local ok, obj = pcall(slua.loadObject, path)
            if ok and g_masterahsanyt_ESPValid(obj) then
                g_masterahsanyt_ShotESP.TemplateFontObject = obj
                break
            end
        end
    end

    return g_masterahsanyt_ShotESP.TemplateFont
end

-- ESP viewport size made by @Masterpiece2025
local function g_masterahsanyt_ESPViewport(pc)
    local w,h
    local function take(x,y)
        x,y=tonumber(x),tonumber(y)
        if ESPShared.Finite(x) and ESPShared.Finite(y) and x>200 and y>200 and x<1e6 and y<1e6 then w,h=x,y;return true end
    end
    pcall(function()
        if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
            local v=WidgetLayoutLibrary.GetViewportSize(pc);if v then take(v.X,v.Y) end
        end
    end)
    if not w then pcall(function() local x,y=pc:GetViewportSize();take(x,y) end) end
    if not w then pcall(function() local v=g_masterahsanyt_ESPV2(0,0);pc:GetViewportSize(v);take(v.X,v.Y) end) end
    if not w then pcall(function() local x,y=pc:GetViewportSize(0,0);take(x,y) end) end
    return w or 2400.0,h or 1080.0
end

-- ESP HUD canvas made by @Masterpiece2025
local function g_masterahsanyt_ESPGetCanvasLocalSize()
    local canvas = g_masterahsanyt_ESPGetCanvas()
    if not g_masterahsanyt_ESPValid(canvas) then return nil, nil end

    local cw, ch = nil, nil
    pcall(function()
        local geo = canvas:GetCachedGeometry()
        if not geo then return end

        local size = nil
        if geo.GetLocalSize then
            size = geo:GetLocalSize()
        elseif SlateBlueprintLibrary and SlateBlueprintLibrary.GetLocalSize then
            size = SlateBlueprintLibrary.GetLocalSize(geo)
        end

        if size and ESPShared.Finite(size.X) and ESPShared.Finite(size.Y) and size.X > 100 and size.Y > 100 then
            cw, ch = tonumber(size.X), tonumber(size.Y)
        end
    end)

    return cw, ch
end

-- ESP canvas transform made by @Masterpiece2025
local function g_masterahsanyt_ESPUpdateCanvasTransform(pc)
    local canvas = g_masterahsanyt_ESPGetCanvas()
    if not g_masterahsanyt_ESPValid(canvas) then return false end

    local calibrated = false

    pcall(function()
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
            local geo = canvas:GetCachedGeometry()
            if geo then
                local p0 = SlateBlueprintLibrary.AbsoluteToLocal(
                    geo,
                    g_masterahsanyt_ESPV2(0, 0)
                )
                local p1 = SlateBlueprintLibrary.AbsoluteToLocal(
                    geo,
                    g_masterahsanyt_ESPV2(100, 100)
                )

                if p0 and p1
                    and ESPShared.Finite(p0.X) and ESPShared.Finite(p0.Y)
                    and ESPShared.Finite(p1.X) and ESPShared.Finite(p1.Y)
                    and math.abs(p0.X)<1e7 and math.abs(p0.Y)<1e7
                    and p1.X>p0.X and p1.Y>p0.Y
                    and p1.X-p0.X<10000 and p1.Y-p0.Y<10000 then

                    g_masterahsanyt_ShotESP.CanvasScaleX = (p1.X - p0.X) / 100.0
                    g_masterahsanyt_ShotESP.CanvasScaleY = (p1.Y - p0.Y) / 100.0
                    g_masterahsanyt_ShotESP.CanvasOffsetX = p0.X
                    g_masterahsanyt_ShotESP.CanvasOffsetY = p0.Y
                    calibrated = true
                end
            end
        end
    end)

    if not calibrated then
        local scale = 1.0
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                local s = WidgetLayoutLibrary.GetViewportScale(pc)
                if ESPShared.Finite(s) and s>=0.01 and s<=100 then
                    scale = s
                end
            end
        end)

        g_masterahsanyt_ShotESP.CanvasScaleX = 1.0 / scale
        g_masterahsanyt_ShotESP.CanvasScaleY = 1.0 / scale
        g_masterahsanyt_ShotESP.CanvasOffsetX = 0.0
        g_masterahsanyt_ShotESP.CanvasOffsetY = 0.0
    end

    return true
end

-- ESP world to HUD projection made by @Masterpiece2025
local function g_masterahsanyt_ESPProject(pc,worldLoc)
    local frame=ESPShared.Frame
    -- Skeleton results own their output; only the immediate raw scratch is shared.
    if not frame.RawPixel then frame.RawPixel=g_masterahsanyt_ESPV2(0,0) end
    local pix=ESPShared.ProjectRaw(pc,worldLoc,frame.Active and frame.RawPixel or nil)
    if not pix then return nil end
    local sx,sy,ox,oy=ESPShared.CanvasTransform(g_masterahsanyt_ShotESP)
    return g_masterahsanyt_ESPV2(pix.X*sx+ox,pix.Y*sy+oy)
end

-- Fresh projections deliberately avoid screen-space lerp: it adds camera lag
-- and desynchronizes the capsule outline from the independently projected bones.

local function g_masterahsanyt_ESPActorOnScreen(head,feet,minX,minY,maxX,maxY)
    local function usable(p)
        return p and ESPShared.Finite(p.X) and ESPShared.Finite(p.Y)
    end
    head=usable(head) and head or nil;feet=usable(feet) and feet or nil
    if not head and not feet then return false end
    head=head or feet;feet=feet or head
    return math.max(head.X,feet.X)>=minX and math.min(head.X,feet.X)<=maxX
        and math.max(head.Y,feet.Y)>=minY and math.min(head.Y,feet.Y)<=maxY
end

function ESPShared.ViewSize(pc)
    local now=ESPShared.Frame.Active and ESPShared.Frame.Now or g_masterahsanyt_ESPNow()
    if not ESPShared.Frame.Active or ESPShared.Frame.ViewPC~=pc or now<ESPShared.Frame.ViewAt or now-ESPShared.Frame.ViewAt>=0.25 then
        ESPShared.Frame.ViewW,ESPShared.Frame.ViewH=g_masterahsanyt_ESPViewport(pc)
        ESPShared.Frame.ViewPC=pc;ESPShared.Frame.ViewAt=now
    end
    return ESPShared.Frame.ViewW,ESPShared.Frame.ViewH
end
function ESPShared.NativeProject(pc,location,pix)
    return pc:ProjectWorldLocationToScreen(location,pix,true)
end
function ESPShared.ActorProbeLocations(actor,entry)
    local center,height,x,y,z=g_masterahsanyt_ESPGetCharacterVerticalBounds(actor,entry.Location)
    if not x or not height then return nil,nil end
    entry.WorldHead=ESPShared.UpdateProbeVector(entry.WorldHead,x,y,z+height)
    entry.WorldFeet=ESPShared.UpdateProbeVector(entry.WorldFeet,x,y,z-height)
    return entry.WorldHead,entry.WorldFeet
end
function ESPShared.ProjectRaw(pc,location,pix)
    if not ESPShared.VectorValues(location) or not ESPShared.ProjectionControllerValid(pc) then return nil end
    pix=pix or g_masterahsanyt_ESPV2(0,0);pix.X=0;pix.Y=0
    local ok,result,out=pcall(ESPShared.NativeProject,pc,location,pix)
    if out then pix=out end
    local good,x,y=pcall(function() return tonumber(pix.X),tonumber(pix.Y) end)
    if not ok or not good or not ESPShared.Finite(x) or not ESPShared.Finite(y) or math.abs(x)>=1e7 or math.abs(y)>=1e7 then return nil,"unavailable" end
    if result==false or result==0 then return nil,"offscreen" end
    if result~=true and result~=1 and not (result==nil and (x~=0 or y~=0)) then return nil,"unavailable" end
    return pix,"visible"
end
function ESPShared.ProbeActor(pc,actor)
    local entry=ESPShared.GetFrameRecord(actor)
    if entry.Projected and entry.PC==pc then return entry end
    entry.Projected=true;entry.PC=pc;entry.OnScreen=false;entry.ProjectionReason="unavailable"
    if not entry.Alive or not entry.Location then return entry end
    local ok,head,feet=pcall(ESPShared.ActorProbeLocations,actor,entry)
    if not ok then return entry end
    entry.RawHead=entry.RawHead or g_masterahsanyt_ESPV2(0,0)
    entry.RawFeet=entry.RawFeet or g_masterahsanyt_ESPV2(0,0)
    local hp,hr=ESPShared.ProjectRaw(pc,head,entry.RawHead)
    local fp,fr=ESPShared.ProjectRaw(pc,feet,entry.RawFeet)
    if hp then entry.RawHead=hp end;if fp then entry.RawFeet=fp end
    entry.HasHead=hp~=nil;entry.HasFeet=fp~=nil
    local width,height=ESPShared.ViewSize(pc)
    entry.OnScreen=g_masterahsanyt_ESPActorOnScreen(hp,fp,0,0,width,height)
    if entry.OnScreen then entry.ProjectionReason="visible"
    elseif hp or fp or hr=="offscreen" or fr=="offscreen" then entry.ProjectionReason="offscreen" end
    return entry
end
function ESPShared.CanvasBounds(pc,state)
    local width,height=ESPShared.ViewSize(pc)
    local sx,sy,ox,oy=ESPShared.CanvasTransform(state)
    local maxX,maxY=ox+width*sx,oy+height*sy
    if ESPShared.Finite(state.ViewportW) and state.ViewportW>1 then maxX=math.min(maxX,ox+state.ViewportW) end
    if ESPShared.Finite(state.ViewportH) and state.ViewportH>1 then maxY=math.min(maxY,oy+state.ViewportH) end
    return ox,oy,maxX,maxY
end
function ESPShared.ProjectActor(pc,actor,state)
    local entry=ESPShared.ProbeActor(pc,actor)
    if not entry.OnScreen then return nil,nil,false,entry.ProjectionReason end
    local sx,sy,ox,oy=ESPShared.CanvasTransform(state)
    local prefix=state==g_masterahsanyt_ShotESP and "V2" or "V1"
    local function convert(raw,field)
        local p=entry[field] or g_masterahsanyt_ESPV2(0,0);entry[field]=p
        p.X=raw.X*sx+ox;p.Y=raw.Y*sy+oy;return p
    end
    local head=entry.HasHead and convert(entry.RawHead,prefix.."Head") or nil
    local feet=entry.HasFeet and convert(entry.RawFeet,prefix.."Feet") or nil
    local minX,minY,maxX,maxY=ESPShared.CanvasBounds(pc,state)
    local visible=g_masterahsanyt_ESPActorOnScreen(head,feet,minX,minY,maxX,maxY)
    return head,feet,visible,visible and "visible" or "offscreen"
end


-- ESP text setter with FText conversion fallback

-- ESP font style made by @Masterpiece2025
local function g_masterahsanyt_ESPSetFont(textWidget, size)
    if not g_masterahsanyt_ESPValid(textWidget) then return end
    g_masterahsanyt_ESPGetTemplateTextStyle()
    pcall(function()
        local f = textWidget.Font or g_masterahsanyt_ShotESP.TemplateFont
        if f then
            if g_masterahsanyt_ESPValid(g_masterahsanyt_ShotESP.TemplateFontObject) then
                pcall(function() f.FontObject = g_masterahsanyt_ShotESP.TemplateFontObject end)
            end
            if g_masterahsanyt_ShotESP.TemplateTypeface then
                pcall(function() f.TypefaceFontName = g_masterahsanyt_ShotESP.TemplateTypeface end)
            end
            pcall(function() f.Size = size end)
            if f.OutlineSettings then
                pcall(function()
                    local os = f.OutlineSettings
                    os.OutlineSize = 0
                    os.OutlineColor = ESP_TEXT_CLEAR
                    f.OutlineSettings = os
                end)
            end
            pcall(function() textWidget:SetFont(f) end)
            pcall(function() textWidget.Font = f end)
        end
        if textWidget.SetShadowOffset then
            pcall(function() textWidget:SetShadowOffset(g_masterahsanyt_ESPV2(0.0,0.0)) end)
        end
        if textWidget.SetShadowColorAndOpacity then
            pcall(function() textWidget:SetShadowColorAndOpacity(ESP_TEXT_CLEAR) end)
        end
    end)
end

-- ESP text color made by @Masterpiece2025
local function g_masterahsanyt_ESPSetTextColor(textWidget, color)
    if not g_masterahsanyt_ESPValid(textWidget) or not color then return end
    local applied = false
    pcall(function()
        local sc = textWidget.ColorAndOpacity or g_masterahsanyt_ShotESP.TemplateColorAndOpacity or (SlateColor and SlateColor())
        if sc then
            sc.SpecifiedColor = color
            pcall(function() sc.ColorUseRule = 0 end)
            local check = sc.SpecifiedColor
            if check and tonumber(check.A) and tonumber(check.A) > 0 then
                textWidget:SetColorAndOpacity(sc)
                pcall(function() textWidget.ColorAndOpacity = sc end)
                applied = true
            end
        end
    end)
    if not applied then
        pcall(function() textWidget:SetColorAndOpacity(color) end)
    end
    pcall(function() if textWidget.SetOpacity then textWidget:SetOpacity(1.0) end end)
    pcall(function() if textWidget.SetRenderOpacity then textWidget:SetRenderOpacity(1.0) end end)
end

-- ESP line widget made by @Masterpiece2025
local function g_masterahsanyt_ESPCreateLine(color,parent)
    local canvas = parent or g_masterahsanyt_ESPGetCanvas()
    if not g_masterahsanyt_ESPValid(canvas) then return nil end
    local budget = g_masterahsanyt_ShotESP.BuildRemaining
    if budget ~= nil then
        if budget <= 0 then return nil end
        g_masterahsanyt_ShotESP.BuildRemaining = budget - 1
    end
    local pooled=canvas==g_masterahsanyt_ShotESP.Canvas and ESPWidgetPool.Take(ESPWidgetPool.V2,"Line",canvas)
    if pooled then
        local ok=pcall(function() pooled.Widget:SetBrushColor(color) end)
        if ok then pooled.Visible=false;return pooled end
        pcall(function() pooled.Widget:RemoveFromParent() end)
    end
    local border = nil
    pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
    if not g_masterahsanyt_ESPValid(border) then return nil end
    pcall(function()
        border:SetBrushColor(color)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        border:SetRenderTransformPivot(g_masterahsanyt_ESPV2(0.0, 0.5))
    end)
    local slot = nil
    pcall(function() slot = canvas:AddChildToCanvas(border) end)
    if not slot then g_masterahsanyt_ESPDestroyWidgetData({Widget=border}) return nil end
    pcall(function() slot:SetAutoSize(false) slot:SetZOrder(30) end)
    local data={Widget=border, Slot=slot}
    if canvas==g_masterahsanyt_ShotESP.Canvas then ESPWidgetPool.Tag(ESPWidgetPool.V2,"Line",canvas,data) end
    return data
end

-- ESP line made by @Masterpiece2025
local function g_masterahsanyt_ESPDrawLine(data, x1, y1, x2, y2, thickness)
    if not data or not data.Widget or not data.Slot then return false end
    local dx, dy = x2-x1, y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 1 then
        if data.Visible ~= false then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.Visible = false
        end
        return false
    end
    local angle = ((math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)) * 180.0 / math.pi
    local unchanged=data.Visible==true and data.X1 and
        math.abs(data.X1-x1)<0.25 and math.abs(data.Y1-y1)<0.25 and
        math.abs(data.X2-x2)<0.25 and math.abs(data.Y2-y2)<0.25 and
        math.abs((data.Thickness or 0)-thickness)<0.05
    if unchanged then return true end
    -- Reuse native transform values after the first draw. Older bindings
    -- that reject mutable structs fall back once to the original setter path.
    local setterOK=pcall(function()
        if data.VectorReuseDisabled then
            data.Slot:SetPosition(g_masterahsanyt_ESPV2(x1, y1 - thickness*0.5))
            data.Slot:SetSize(g_masterahsanyt_ESPV2(len, thickness))
        else
            data.PosVec=data.PosVec or g_masterahsanyt_ESPV2(x1, y1 - thickness*0.5)
            data.SizeVec=data.SizeVec or g_masterahsanyt_ESPV2(len, thickness)
            data.PosVec.X=x1;data.PosVec.Y=y1-thickness*0.5
            data.SizeVec.X=len;data.SizeVec.Y=thickness
            data.Slot:SetPosition(data.PosVec)
            data.Slot:SetSize(data.SizeVec)
        end
        data.Widget:SetRenderAngle(angle)
        if not data.Visible then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
    end)
    if not setterOK and not data.VectorReuseDisabled then
        data.VectorReuseDisabled=true;data.PosVec=nil;data.SizeVec=nil
        setterOK=pcall(function()
            data.Slot:SetPosition(g_masterahsanyt_ESPV2(x1, y1 - thickness*0.5))
            data.Slot:SetSize(g_masterahsanyt_ESPV2(len, thickness))
            data.Widget:SetRenderAngle(angle)
            if not data.Visible then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
        end)
    end
    if not setterOK then data.Broken=true return false end
    data.Broken=false
    data.X1,data.Y1,data.X2,data.Y2,data.Thickness=x1,y1,x2,y2,thickness
    data.Visible=true
    return true
end

-- ESP widget hide made by @Masterpiece2025
local function g_masterahsanyt_ESPHide(data)
    if data and data.Visible~=false and data.Widget then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        if not ok then data.Broken=true end
        data.Visible=false
    end
end

local function g_masterahsanyt_ESPDestroyGroup(group)
    if not group then return end
    for _, data in ipairs(group) do g_masterahsanyt_ESPDestroyWidgetData(data) end
end

-- Check native widget validity at discovery cadence; failed setters mark a
-- piece broken immediately. This avoids an IsValid bridge call per piece/frame.
local function g_masterahsanyt_ESPGroupHealthy(group)
    if not group then return false end
    local now = g_masterahsanyt_ShotESP.Now
    local validate = not group.ValidatedAt or now < group.ValidatedAt or now-group.ValidatedAt >= 0.35
    for _, data in ipairs(group) do
        if data.Broken or (validate and not g_masterahsanyt_ESPValid(data.Widget)) then return false end
    end
    if validate then group.ValidatedAt = now end
    return true
end

-- Keep partial groups across ticks; budgeted creation prevents first-visibility spikes.
local function g_masterahsanyt_ESPLineGroup(registry, key, count, color, parent)
    local group = registry[key]
    if group and not g_masterahsanyt_ESPGroupHealthy(group) then
        g_masterahsanyt_ESPDestroyGroup(group)
        group = nil
    end
    if not group or #group > count then
        g_masterahsanyt_ESPDestroyGroup(group)
        group = {}
        registry[key] = group
    end
    while #group < count do
        local data = g_masterahsanyt_ESPCreateLine(color, parent)
        if not data then return nil end
        group[#group + 1] = data
        g_masterahsanyt_ESPHide(data)
    end
    return group
end

-- Existing geometry and widgets are reused. Stable identity performs no native
-- color setters; failed brush assignments remain eligible for retry.
local function g_masterahsanyt_ESPApplyGroupTheme(group,theme,kind)
    if not group or group.ThemeKey==theme.Key then return end
    local ok=pcall(function()
        for i,piece in ipairs(group) do
            local color=theme.Main
            if kind=="Header" then
                if i>=23 then color=theme.Background
                elseif i>=9 and i<=12 then color=theme.Light end
            elseif kind=="Arcs" then
                if i>=11 and i<=20 then color=theme.Light end
            elseif kind=="Footer" then
                if i<=4 then color=theme.Light end
            elseif kind=="Health" then
                if i==1 then color=theme.Background
                elseif i>=10 then color=theme.Light
                else color=theme.Empty end
            end
            piece.Widget:SetBrushColor(color)
        end
    end)
    if ok then group.ThemeKey=theme.Key end
end

local function g_masterahsanyt_ESPHideGroup(group)
    if not group then return end
    for _, data in ipairs(group) do g_masterahsanyt_ESPHide(data) end
end

local function g_masterahsanyt_ESPHideDetailedEnemy(key)
    g_masterahsanyt_ESPHide(g_masterahsanyt_ShotESP.Lines[key])
    g_masterahsanyt_ESPHideGroup(g_masterahsanyt_ShotESP.Boxes[key])
    g_masterahsanyt_ESPHideGroup(g_masterahsanyt_ShotESP.HealthBars[key])
    g_masterahsanyt_ESPHideGroup(g_masterahsanyt_ShotESP.Skeletons[key])
    g_masterahsanyt_ESPHideGroup(g_masterahsanyt_ShotESP.Headers[key])
    local decor=g_masterahsanyt_ShotESP.Decorations[key]
    if decor and decor.Visible~=false then pcall(function() decor.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) decor.Visible=false end
end

local g_masterahsanyt_ESPHealthRatio

local function g_masterahsanyt_ESPSetGroupVisible(group,visible)
    if not group or group.GroupVisible==visible then return end
    for _,data in ipairs(group) do
        if visible then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            data.Visible=true
        else g_masterahsanyt_ESPHide(data) end
    end
    group.GroupVisible=visible
end

local function g_masterahsanyt_ESPCreateDecorationRoot(poolKind)
    local canvas=g_masterahsanyt_ESPGetCanvas()
    if not g_masterahsanyt_ESPValid(canvas) then return nil end
    poolKind=poolKind or "Decor"
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V2,poolKind,canvas)
    if pooled then
        local ok=pcall(function()
            pooled.Slot:SetZOrder(poolKind=="Header" and 30 or 29)
            pooled.Widget:SetRenderScale(g_masterahsanyt_ESPV2(1.0,1.0))
            pooled.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        if ok then pooled.Visible=true;return pooled end
        pcall(function() pooled.Widget:RemoveFromParent() end)
    end
    local root=nil
    pcall(function() root=CGame:NewObjectFromPath("/Script/UMG.CanvasPanel",canvas) end)
    if not g_masterahsanyt_ESPValid(root) then return nil end
    local slot=nil
    pcall(function() slot=canvas:AddChildToCanvas(root) end)
    if not slot then g_masterahsanyt_ESPDestroyWidgetData({Widget=root}) return nil end
    pcall(function()
        slot:SetAutoSize(false)
        slot:SetSize(g_masterahsanyt_ESPV2(1000.0,1400.0))
        slot:SetZOrder(29)
        root:SetRenderTransformPivot(g_masterahsanyt_ESPV2(0.0,0.0))
        root:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    return ESPWidgetPool.Tag(ESPWidgetPool.V2,poolKind,canvas,{Widget=root,Slot=slot,Groups={},Visible=true})
end

local function g_masterahsanyt_ESPDecorGroup(data,name,count,color)
    return g_masterahsanyt_ESPLineGroup(data.Groups,name,count,color,data.Widget)
end


local function g_masterahsanyt_ESPBuildArcs(data)
    local group=g_masterahsanyt_ESPDecorGroup(data,"Arcs",26,ESP_REAL)
    if not group then return nil end
    if group.Built then return group end
    local cx,cy,half,ry=500.0,385.0,268.0,180.0
    -- Progressive stroke curve: 2x at both corners, 5x at the center.
    -- Red base thickness is 3.0; white base thickness is 1.5.
    local redThickness={6.0,10.5,15.0,10.5,6.0}
    local whiteThickness={3.0,5.25,7.5,5.25,3.0}
    local index=1
    for _,side in ipairs({-1,1}) do
        local previous=nil
        for step=0,5 do
            local angle=(-70+step*28)*math.pi/180
            local p={X=cx+side*half*math.cos(angle),Y=cy+ry*math.sin(angle)}
            if previous then
                g_masterahsanyt_ESPDrawLine(group[index],previous.X,previous.Y,p.X,p.Y,redThickness[step])
                index=index+1
            end
            previous=p
        end
    end
    local tickIndex=21
    for _,side in ipairs({-1,1}) do
        local x=cx+side*half*1.02
        for _,oy in ipairs({-24.0,0.0,24.0}) do
            g_masterahsanyt_ESPDrawLine(group[tickIndex],x-side*5.0,cy+oy,x+side*2.0,cy+oy,2.2)
            tickIndex=tickIndex+1
        end
    end
    local ih,ir=half*.82,ry*.76
    for _,side in ipairs({-1,1}) do
        local previous=nil
        for step=0,5 do
            local angle=(-54+step*(108/5))*math.pi/180
            local p={X=cx+side*ih*math.cos(angle),Y=cy+ir*math.sin(angle)}
            if previous then
                pcall(function() group[index].Widget:SetBrushColor(ESP_WHITE) end)
                g_masterahsanyt_ESPDrawLine(group[index],previous.X,previous.Y,p.X,p.Y,whiteThickness[step])
                index=index+1
            end
            previous=p
        end
    end
    group.Built=true group.GroupVisible=true
    return group
end

local function g_masterahsanyt_ESPBuildHealth(data)
    local group=g_masterahsanyt_ESPDecorGroup(data,"Health",11,ESP_REAL)
    if not group then return nil end
    if group.Built then return group end
    -- Twice the original footprint so distant health remains readable.
    local x,barBottom,barTop,barW=700.0,1120.0,564.0,60.0
    pcall(function()
        for i=1,11 do group[i].Widget:SetBrushColor(ESP_REAL) end
    end)
    g_masterahsanyt_ESPDrawLine(group[1],x,barTop,x,barBottom,barW)
    local sh=(barBottom-barTop)/8
    for i=1,8 do
        local y1=barBottom-(i-1)*sh-2
        local y2=barBottom-i*sh+2
        g_masterahsanyt_ESPDrawLine(group[i+1],x,y1,x,y2,barW*.64)
    end
    g_masterahsanyt_ESPDrawLine(group[10],x-barW*.5,barTop,x+barW*.5,barTop,2.0)
    g_masterahsanyt_ESPDrawLine(group[11],x-barW*.5,barBottom,x+barW*.5,barBottom,2.0)
    group.Built=true group.GroupVisible=true group.Filled=-1
    return group
end

local function g_masterahsanyt_ESPBuildFooter(data)
    local group=g_masterahsanyt_ESPDecorGroup(data,"Footer",6,ESP_WHITE)
    if not group then return nil end
    if group.Built then return group end
    local cx,y,w=500.0,1243.0,394.0
    local s={{cx-w*.5,y,cx-w*.29,y},{cx-w*.5,y,cx-w*.58,y-7},{cx+w*.29,y,cx+w*.5,y},{cx+w*.5,y,cx+w*.58,y-7},{cx-w*.23,y,cx-w*.19,y},{cx+w*.19,y,cx+w*.23,y}}
    for i,v in ipairs(s) do pcall(function() group[i].Widget:SetBrushColor(i>=5 and ESP_REAL or ESP_WHITE) end) g_masterahsanyt_ESPDrawLine(group[i],v[1],v[2],v[3],v[4],i>=5 and 2.2 or 1.6) end
    group.Built=true group.GroupVisible=true
    return group
end

local function g_masterahsanyt_ESPUpdateDecoration(key,character,head,feet,opt,stage,isBot)
    local enabled=opt.Name or opt.Box or opt.Health or opt.Distance
    local data=g_masterahsanyt_ShotESP.Decorations[key]
    if not enabled or not head or not feet then
        if data and data.Visible~=false then pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) data.Visible=false end
        return
    end
    if not data or not g_masterahsanyt_ESPValid(data.Widget) then
        g_masterahsanyt_ESPDestroyWidgetData(data)
        data=g_masterahsanyt_ESPCreateDecorationRoot()
        g_masterahsanyt_ShotESP.Decorations[key]=data
    end
    if not data then return end
    local h=math.abs(feet.Y-head.Y)
    if h<8 then return end
    local scale=h/1000.0
    local x,y=head.X-500.0*scale,head.Y-200.0*scale
    local moved=not data.X or math.abs(data.X-x)>=.25 or math.abs(data.Y-y)>=.25
    local scaled=not data.Scale or math.abs(data.Scale-scale)>=.001
    if moved then
        local ok=pcall(function() data.Slot:SetPosition(g_masterahsanyt_ESPV2(x,y)) end)
        if ok then data.X,data.Y=x,y end
    end
    if scaled then
        local ok=pcall(function() data.Widget:SetRenderScale(g_masterahsanyt_ESPV2(scale,scale)) end)
        if ok then data.Scale=scale else data.Scale=nil end
    end
    if data.Visible~=true then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        if ok then data.Visible=true end
    end
    -- Header: handled by ESPUpdateHeaderFrame (screen-space, dynamic width) — hide DecorationRoot version
    if data.Groups.Header then g_masterahsanyt_ESPSetGroupVisible(data.Groups.Header, false) end
    local theme=g_masterahsanyt_ESPTheme(isBot)
    local arcs=data.Groups.Arcs
    if opt.Box then arcs=g_masterahsanyt_ESPBuildArcs(data) end
    if arcs then g_masterahsanyt_ESPApplyGroupTheme(arcs,theme,"Arcs") end
    g_masterahsanyt_ESPSetGroupVisible(arcs,opt.Box==true)
    local health=data.Groups.Health
    if opt.Health then health=g_masterahsanyt_ESPBuildHealth(data) end
    local healthTypeChanged=health and health.ThemeKey~=theme.Key
    if health then g_masterahsanyt_ESPApplyGroupTheme(health,theme,"Health") end
    g_masterahsanyt_ESPSetGroupVisible(health,opt.Health==true)
    if health and opt.Health then
        local filled=math.ceil(g_masterahsanyt_ESPHealthRatio(character)*8-.001)
        if health.Filled~=filled or healthTypeChanged then
            local ok=pcall(function() for i=1,8 do health[i+1].Widget:SetBrushColor(i<=filled and theme.Main or theme.Empty) end end)
            if ok then health.Filled=filled end
        end
    end
    local footer=data.Groups.Footer
    if opt.Distance then footer=g_masterahsanyt_ESPBuildFooter(data) end
    if footer then g_masterahsanyt_ESPApplyGroupTheme(footer,theme,"Footer") end
    g_masterahsanyt_ESPSetGroupVisible(footer,opt.Distance==true)
end

local function g_masterahsanyt_ESPUpdateHeaderFrame(key,head,feet,enabled,isBot)
    local group=g_masterahsanyt_ShotESP.Headers[key]
    if not enabled or not head or not feet then g_masterahsanyt_ESPHideGroup(group) return end
    local h=math.abs(feet.Y-head.Y)
    -- Compact distance scaling.  The bottom edge stays above the head and all
    -- height growth happens upward, so zooming never pushes the plate onto the body.
    local w=math.max(68.0,math.min(232.0,h*0.315))
    local cached=g_masterahsanyt_ShotESP.Names[key] and g_masterahsanyt_ShotESP.Names[key].CachedName or ""
    w=math.max(w,math.min(232.0,28.0+#tostring(cached)*6.0))
    local hh=math.max(18.0,math.min(48.0,h*0.070))
    local headGap=math.max(4.0,math.min(10.0,h*0.025))
    local cx=head.X
    local b=head.Y-headGap
    local t=b-hh
    local cy=(t+b)*0.5
    local l,r=cx-w*0.5,cx+w*0.5
    local cut=hh*0.28
    -- 25 frame/background widgets + 8 horizontal fill bands per corner.
    -- The bands approximate true triangles without using rotated rectangles,
    -- which were the source of the original black corner leakage.
    local root = g_masterahsanyt_ShotESP.HeaderRoots[key]
    if not root or not g_masterahsanyt_ESPValid(root.Widget) then
        g_masterahsanyt_ESPDestroyGroup(group)
        g_masterahsanyt_ShotESP.Headers[key] = nil
        group = nil
        g_masterahsanyt_ESPDestroyWidgetData(root)
        root = g_masterahsanyt_ESPCreateDecorationRoot("Header")
        g_masterahsanyt_ShotESP.HeaderRoots[key] = root
        if not root then return end
        group=root.Groups.__Header
        root.Groups.__Header=nil
        g_masterahsanyt_ShotESP.Headers[key]=group
        pcall(function() root.Slot:SetZOrder(30) end)
    end
    -- Move 57 header pieces with one parent slot. Width/height changes still
    -- rebuild the exact original geometry with constant stroke thickness.
    local rootY = b
    local moved = not root.X or math.abs(root.X-cx) >= 0.25 or math.abs(root.Y-rootY) >= 0.25
    if moved then
        local ok = pcall(function() root.Slot:SetPosition(g_masterahsanyt_ESPV2(cx,rootY)) end)
        if ok then root.X,root.Y = cx,rootY end
    end
    local theme=g_masterahsanyt_ESPTheme(isBot)
    local ready = group and #group == 57
    if ready then g_masterahsanyt_ESPApplyGroupTheme(group,theme,"Header") end
    if ready and group.Width and math.abs(group.Width-w) < 0.25 and math.abs(group.Height-hh) < 0.25 then
        local healthy = g_masterahsanyt_ESPGroupHealthy(group)
        if healthy then
            for _, piece in ipairs(group) do
                if piece.Drawn then
                    if piece.Visible ~= true then
                        local ok = pcall(function() piece.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                        if ok then piece.Visible = true end
                    end
                else g_masterahsanyt_ESPHide(piece) end
            end
            return
        end
    end
    group=g_masterahsanyt_ESPLineGroup(g_masterahsanyt_ShotESP.Headers,key,57,ESP_REAL,root.Widget)
    if not group then return end
    cx, b, t, cy = 0.0, 0.0, -hh, -hh*0.5
    l, r = -w*0.5, w*0.5
    local seg={{l+cut,t,r-cut,t},{r-cut,t,r,t+cut},{r,t+cut,r,b-cut},{r,b-cut,r-cut,b},{r-cut,b,l+cut,b},{l+cut,b,l,b-cut},{l,b-cut,l,t+cut},{l,t+cut,l+cut,t}}
    if not group.HeaderStyled then
        local ok=pcall(function() for i=23,57 do group[i].Slot:SetZOrder(0) end end)
        if ok then group.HeaderStyled=true end
    end
    g_masterahsanyt_ESPApplyGroupTheme(group,theme,"Header")
    -- octagon border
    for i,s in ipairs(seg) do g_masterahsanyt_ESPDrawLine(group[i],s[1],s[2],s[3],s[4],2.0) end
    -- white inner accent lines on top/bottom edges
    g_masterahsanyt_ESPDrawLine(group[9],l+cut*1.05,t,l+w*0.16,t,1.25)
    g_masterahsanyt_ESPDrawLine(group[10],r-w*0.16,t,r-cut*1.05,t,1.25)
    g_masterahsanyt_ESPDrawLine(group[11],l+cut*1.05,b,l+w*0.16,b,1.25)
    g_masterahsanyt_ESPDrawLine(group[12],r-w*0.16,b,r-cut*1.05,b,1.25)
    -- bottom spike
    g_masterahsanyt_ESPDrawLine(group[13],cx-cut*0.7,b,cx,b+cut,2.0)
    g_masterahsanyt_ESPDrawLine(group[14],cx,b+cut,cx+cut*0.7,b,2.0)
    -- chevrons (side arrows)
    local co=cut*0.70
    g_masterahsanyt_ESPDrawLine(group[15],l-co*1.9,cy,l-co*1.25,cy-co,2.2)
    g_masterahsanyt_ESPDrawLine(group[16],l-co*1.9,cy,l-co*1.25,cy+co,2.2)
    g_masterahsanyt_ESPDrawLine(group[17],r+co*1.9,cy,r+co*1.25,cy-co,2.2)
    g_masterahsanyt_ESPDrawLine(group[18],r+co*1.9,cy,r+co*1.25,cy+co,2.2)
    g_masterahsanyt_ESPDrawLine(group[19],l-co*2.8,cy,l-co*2.15,cy-co,2.2)
    g_masterahsanyt_ESPDrawLine(group[20],l-co*2.8,cy,l-co*2.15,cy+co,2.2)
    g_masterahsanyt_ESPDrawLine(group[21],r+co*2.8,cy,r+co*2.15,cy-co,2.2)
    g_masterahsanyt_ESPDrawLine(group[22],r+co*2.8,cy,r+co*2.15,cy+co,2.2)
    -- background: center + left strip + right strip (3-part fill of octagon interior)
    g_masterahsanyt_ESPDrawLine(group[23],l+cut,cy,r-cut,cy,hh)
    g_masterahsanyt_ESPDrawLine(group[24],l,cy,l+cut,cy,hh-2*cut)
    g_masterahsanyt_ESPDrawLine(group[25],r-cut,cy,r,cy,hh-2*cut)
    -- Fill each missing corner triangle with horizontal stepped bands.  Every
    -- band starts inside the diagonal, so black cannot cross the red border.
    local cornerSteps=8
    local bandH=cut/cornerSteps
    for i=1,cornerSteps do
        local inset=(i-1)*bandH
        local topY=t+(i-0.5)*bandH
        local bottomY=b-(i-0.5)*bandH
        local leftStart=l+cut-inset
        local rightEnd=r-cut+inset

        if inset>0.5 then
            g_masterahsanyt_ESPDrawLine(group[25+i],leftStart,topY,l+cut+0.5,topY,bandH)
            g_masterahsanyt_ESPDrawLine(group[33+i],r-cut-0.5,topY,rightEnd,topY,bandH)
            g_masterahsanyt_ESPDrawLine(group[41+i],leftStart,bottomY,l+cut+0.5,bottomY,bandH)
            g_masterahsanyt_ESPDrawLine(group[49+i],r-cut-0.5,bottomY,rightEnd,bottomY,bandH)
        else
            g_masterahsanyt_ESPHide(group[25+i])
            g_masterahsanyt_ESPHide(group[33+i])
            g_masterahsanyt_ESPHide(group[41+i])
            g_masterahsanyt_ESPHide(group[49+i])
        end
    end
    group.Width, group.Height = w, hh
    for _, piece in ipairs(group) do piece.Drawn = piece.Visible == true end
end



g_masterahsanyt_ESPHealthRatio = function(character)
    local hp, maxHp = nil, nil
    pcall(function()
        hp = character.Health or character.HP or character.CurrentHealth
        maxHp = character.HealthMax or character.MaxHealth or character.MaxHP
        if not tonumber(hp) and character.GetHealth then hp=character:GetHealth() end
        if not tonumber(maxHp) and character.GetMaxHealth then maxHp=character:GetMaxHealth() end
    end)
    hp, maxHp = tonumber(hp), tonumber(maxHp)
    if not hp or not maxHp or maxHp <= 0 then return 1.0 end
    return math.max(0.0,math.min(1.0,hp/maxHp))
end




local g_masterahsanyt_ESPBones = {
    head={"Head","head","head_01"}, neck={"neck_01","Neck","neck"}, pelvis={"pelvis","Pelvis"},
    ls={"upperarm_l","UpperArm_L","clavicle_l"}, le={"lowerarm_l","LowerArm_L"}, lw={"hand_l","Hand_L"},
    rs={"upperarm_r","UpperArm_R","clavicle_r"}, re={"lowerarm_r","LowerArm_R"}, rw={"hand_r","Hand_R"},
    lh={"thigh_l","Thigh_L","hip_l"}, lk={"calf_l","Calf_L","knee_l"}, la={"foot_l","Foot_L"},
    rh={"thigh_r","Thigh_R","hip_r"}, rk={"calf_r","Calf_R","knee_r"}, ra={"foot_r","Foot_R"}
}
local g_masterahsanyt_ESPBoneLinks={{"head","neck"},{"neck","ls"},{"ls","le"},{"le","lw"},{"neck","rs"},{"rs","re"},{"re","rw"},{"neck","pelvis"},{"pelvis","lh"},{"lh","lk"},{"lk","la"},{"pelvis","rh"},{"rh","rk"},{"rk","ra"}}

-- Cache only the bone-name lookup; world positions and camera projections remain fresh.
local function g_masterahsanyt_ESPBoneScreen(pc, mesh, id, names, cache)
    local cached = cache[id]
    if cached then
        local ok, loc = pcall(function()
            if mesh.GetSocketLocation then return mesh:GetSocketLocation(cached)
            elseif mesh.GetBoneLocation then return mesh:GetBoneLocation(cached) end
        end)
        if ok and loc and tonumber(loc.X) then return g_masterahsanyt_ESPProject(pc,loc) end
        cache[id] = nil
    end
    for _, name in ipairs(names) do
        local ok, loc = pcall(function()
            local exists = nil
            if mesh.DoesSocketExist then exists = mesh:DoesSocketExist(name)
            elseif mesh.GetBoneIndex then exists = (tonumber(mesh:GetBoneIndex(name)) or -1) >= 0 end
            if exists ~= false then
                if mesh.GetSocketLocation then return mesh:GetSocketLocation(name)
                elseif mesh.GetBoneLocation then return mesh:GetBoneLocation(name) end
            end
        end)
        if ok and loc and tonumber(loc.X) then
            cache[id] = name
            return g_masterahsanyt_ESPProject(pc,loc)
        end
    end
    return nil
end

local function g_masterahsanyt_ESPUpdateSkeleton(key, character, pc, enabled, isBot)
    local group = g_masterahsanyt_ShotESP.Skeletons[key]
    if not enabled then g_masterahsanyt_ESPHideGroup(group) return end
    local mesh = nil
    pcall(function() mesh=character.Mesh or (character.GetMesh and character:GetMesh()) end)
    if not g_masterahsanyt_ESPValid(mesh) then g_masterahsanyt_ESPHideGroup(group) return end
    if g_masterahsanyt_ShotESP.BoneMeshes[key] ~= mesh then
        g_masterahsanyt_ShotESP.BoneMeshes[key] = mesh
        g_masterahsanyt_ShotESP.BoneNameCache[key] = {}
        g_masterahsanyt_ShotESP.BonePoints[key] = {}
    end
    local points = g_masterahsanyt_ShotESP.BonePoints[key]
    local cache = g_masterahsanyt_ShotESP.BoneNameCache[key]
    local theme=g_masterahsanyt_ESPTheme(isBot)
    group = g_masterahsanyt_ESPLineGroup(g_masterahsanyt_ShotESP.Skeletons,key,#g_masterahsanyt_ESPBoneLinks,theme.Main)
    if not group then return end
    g_masterahsanyt_ESPApplyGroupTheme(group,theme,"Skeleton")
    for id, names in pairs(g_masterahsanyt_ESPBones) do
        points[id] = g_masterahsanyt_ESPBoneScreen(pc,mesh,id,names,cache)
    end
    local ankle = points.la or points.ra
    local skeletonH = (points.head and ankle) and math.abs(ankle.Y-points.head.Y) or 360.0
    local thickness = math.max(1.0,math.min(2.8,skeletonH*0.0028))
    for i, link in ipairs(g_masterahsanyt_ESPBoneLinks) do
        local a, b = points[link[1]], points[link[2]]
        if a and b then g_masterahsanyt_ESPDrawLine(group[i],a.X,a.Y,b.X,b.Y,thickness)
        else g_masterahsanyt_ESPHide(group[i]) end
    end
end

-- ESP enemy name widget made by @Masterpiece2025
local function g_masterahsanyt_ESPCreateNameTag(isBot)
    local canvas = g_masterahsanyt_ESPGetCanvas()
    if not g_masterahsanyt_ESPValid(canvas) then return nil end
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V2,"NameV2",canvas)
    if pooled then
        local theme=g_masterahsanyt_ESPTheme(isBot)
        g_masterahsanyt_ESPSetTextColor(pooled.Text,theme.Text)
        g_masterahsanyt_ESPSetTextColor(pooled.DistanceText,theme.Text)
        g_masterahsanyt_ESPSetFont(pooled.Text,tonumber(_G.g_masterahsanyt_MasterShotESP.NameFontSize) or 16,0)
        g_masterahsanyt_ESPSetFont(pooled.DistanceText,tonumber(_G.g_masterahsanyt_MasterShotESP.DistanceFontSize) or 20,0)
        pooled.IsBot=isBot;pooled.ContainerVisible=false
        if pooled then return pooled end
    end

    local container, nameText, distanceText = nil, nil, nil
    pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not g_masterahsanyt_ESPValid(container) then return nil end
    pcall(function() nameText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    pcall(function() distanceText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    if not g_masterahsanyt_ESPValid(nameText) or not g_masterahsanyt_ESPValid(distanceText) then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end

    pcall(function()
        nameText:SetText("")
        distanceText:SetText("")
        nameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        distanceText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        if nameText.SetJustification then nameText:SetJustification(1) end
        if nameText.SetRenderTransformPivot then nameText:SetRenderTransformPivot(g_masterahsanyt_ESPV2(.5,.5)) end
        if distanceText.SetJustification then distanceText:SetJustification(1) end
        if distanceText.SetRenderTransformPivot then distanceText:SetRenderTransformPivot(g_masterahsanyt_ESPV2(.5,.5)) end
    end)

    local theme=g_masterahsanyt_ESPTheme(isBot)
    g_masterahsanyt_ESPSetTextColor(nameText, theme.Text)
    g_masterahsanyt_ESPSetTextColor(distanceText, theme.Text)
    g_masterahsanyt_ESPSetFont(nameText, tonumber(_G.g_masterahsanyt_MasterShotESP.NameFontSize) or 16, 0)
    -- Distance labels are intentionally borderless; the larger glyphs provide clarity.
    g_masterahsanyt_ESPSetFont(distanceText, tonumber(_G.g_masterahsanyt_MasterShotESP.DistanceFontSize) or 20, 0)
    local nameSlot, distanceSlot, mainSlot = nil, nil, nil
    pcall(function() nameSlot = container:AddChildToCanvas(nameText) end)
    pcall(function() distanceSlot = container:AddChildToCanvas(distanceText) end)
    if not nameSlot or not distanceSlot then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end
    pcall(function() mainSlot = canvas:AddChildToCanvas(container) end)
    if not mainSlot then
        pcall(function() container:RemoveFromParent() end)
        return nil
    end

    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetAlignment(g_masterahsanyt_ESPV2(0.0, 0.0))
        mainSlot:SetZOrder(65)
        nameSlot:SetAutoSize(true)
        nameSlot:SetAlignment(g_masterahsanyt_ESPV2(0.5, 0.5))
        nameSlot:SetZOrder(1)
        distanceSlot:SetAutoSize(true)
        distanceSlot:SetAlignment(g_masterahsanyt_ESPV2(0.5, 0.5))
        distanceSlot:SetZOrder(1)
    end)

    local data={
        Widget = container,
        Text = nameText,
        DistanceText = distanceText,
        TextSlot = nameSlot,
        DistanceSlot = distanceSlot,
        Slot = mainSlot,
        IsBot = isBot
    }
    return ESPWidgetPool.Tag(ESPWidgetPool.V2,"NameV2",canvas,data)
end

-- ESP enemy name and distance made by @Masterpiece2025
local function g_masterahsanyt_ESPUpdateNameTag(key, character, headScreen, footScreen, isBot, distance, forceName, forceDistance)
    local showName = _G.g_masterahsanyt_ESPOptions.Name == true
    local showDistance = _G.g_masterahsanyt_ESPOptions.Distance == true
    if forceName~=nil then showName=forceName==true end
    if forceDistance~=nil then showDistance=forceDistance==true end
    local data = g_masterahsanyt_ShotESP.Names[key]
    if not showName and not showDistance then
        if data and data.ContainerVisible~=false and g_masterahsanyt_ESPValid(data.Widget) then pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) data.ContainerVisible=false end
        return
    end
    -- Fix: only cache non-empty resolved names; "" is truthy in Lua so never cache it
    local name = nil
    if showName then
        local cached = data and data.CachedName
        if type(cached) == "string" and #cached > 0 then
            name = cached
        else
            name = g_masterahsanyt_ESPResolvePlayerName(character)
            if data and type(name) == "string" and #name > 0 then
                data.CachedName = name
            end
        end
        -- Fallback label for display only (not cached, so future frames retry)
        if not (type(name) == "string" and #name > 0) then
            name = isBot and "BOT" or "PLAYER"
        end
    else
        name = ""
    end
    if not headScreen then
        if data and g_masterahsanyt_ESPValid(data.Widget) then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.ContainerVisible=false
        end
        return
    end

    if not data or not g_masterahsanyt_ESPValid(data.Widget) then
        g_masterahsanyt_ESPDestroyWidgetData(data)
        data = g_masterahsanyt_ESPCreateNameTag(isBot)
        g_masterahsanyt_ShotESP.Names[key] = data
        -- Only cache real resolved names on creation, not fallback labels
        if data and type(name)=="string" and #name>0 and name~="BOT" and name~="PLAYER" then
            data.CachedName = name
        end
    end
    if not data then return end
    if data.IsBot~=isBot then
        local theme=g_masterahsanyt_ESPTheme(isBot)
        g_masterahsanyt_ESPSetTextColor(data.Text,theme.Text)
        g_masterahsanyt_ESPSetTextColor(data.DistanceText,theme.Text)
        data.IsBot=isBot
    end

    local dist = math.max(0, math.floor((tonumber(distance) or 0) + 0.5))
    local distanceLabel = string.format("%dm", dist)

    local bodyH=(footScreen and math.abs(footScreen.Y-headScreen.Y)) or 120.0
    local charCount=#name
    pcall(function() if utf8 and utf8.len then charCount=utf8.len(name) or charCount end end)
    -- Same compact, bottom-anchored geometry as ESPUpdateHeaderFrame.
    local w=math.max(68.0,math.min(232.0,bodyH*0.315))
    w=math.max(w,math.min(232.0,28.0+charCount*6.0))
    local hh=math.max(18.0,math.min(48.0,bodyH*0.070))
    local nameScale=math.max(0.80,math.min(1.18,math.min(bodyH/330.0,(w*0.80)/math.max(1.0,charCount*8.4))))
    local distanceScale=math.max(0.60,math.min(1.30,bodyH/200.0))
    local offscreenDistance = forceDistance==true and forceName==false
    if offscreenDistance then distanceScale=math.max(distanceScale,1.10) end

    -- Anchor the lower edge above the head; only the upper edge expands with scale.
    local cx = headScreen.X
    local headGap=math.max(4.0,math.min(10.0,bodyH*0.025))
    local bottomY=headScreen.Y-headGap
    local x = cx - w*0.5
    local y = bottomY-hh

    -- Distance text: at FEET position (CanvasPanel doesn't clip children outside bounds)
    local footY = footScreen and footScreen.Y or (headScreen.Y + bodyH)
    local distY = (footY - y) + bodyH*0.020   -- relative to container top-left, at feet level
    local distX = footScreen and (footScreen.X - x) or (w*0.5)

    local nameVisibilityChanged=data.ShowName~=showName
    local distanceVisibilityChanged=data.ShowDistance~=showDistance
    local layoutChanged=not data.LayoutX or math.abs(data.LayoutX-x)>=0.25 or math.abs(data.LayoutY-y)>=0.25 or
        math.abs((data.LayoutW or 0)-w)>=0.25 or math.abs((data.LayoutH or 0)-hh)>=0.25

    local applied = pcall(function()
        local shownName = showName and name or ""
        local shownDistance = showDistance and distanceLabel or ""
        if data.LastName ~= shownName then
            data.Text:SetText(shownName)
            data.LastName = shownName
        end
        if data.NameScale~=nameScale then data.Text:SetRenderScale(g_masterahsanyt_ESPV2(nameScale,nameScale)) end
        if data.DistanceScale~=distanceScale then data.DistanceText:SetRenderScale(g_masterahsanyt_ESPV2(distanceScale,distanceScale)) end
        if data.LastDistance ~= shownDistance then
            data.DistanceText:SetText(shownDistance)
            data.LastDistance = shownDistance
        end
        if nameVisibilityChanged then
            data.Text:SetWidgetVisibility(showName and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end
        if distanceVisibilityChanged then
            data.DistanceText:SetWidgetVisibility(showDistance and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed)
        end

        -- Move the container to match the header octagon exactly
        if layoutChanged then
            data.Slot:SetPosition(g_masterahsanyt_ESPV2(x, y))
            data.Slot:SetSize(g_masterahsanyt_ESPV2(w, hh))
        end

        -- Name text centered inside container (matches header box center)
        if data.LayoutW~=w or data.LayoutH~=hh then
            data.TextSlot:SetPosition(g_masterahsanyt_ESPV2(w*0.5, hh*0.5))
        end

        -- Distance text below the header box
        local distChanged = not data.DistX or math.abs(data.DistX-distX)>=0.25 or math.abs((data.DistY or 0)-distY)>=0.25
        if distChanged then
            data.DistanceSlot:SetPosition(g_masterahsanyt_ESPV2(distX, distY))
        end

        if data.ContainerVisible~=true then
            data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
    end)
    if not applied then return end
    data.ShowName,data.ShowDistance=showName,showDistance
    data.NameScale=nameScale
    data.DistanceScale=distanceScale
    data.LayoutX,data.LayoutY,data.LayoutW,data.LayoutH=x,y,w,hh
    data.DistX,data.DistY=distX,distY
    data.ContainerVisible=true
end

-- ESP enemy and bot counter HUD made by @Masterpiece2025
local function g_masterahsanyt_ESPCreateCounter()
    local canvas = g_masterahsanyt_ESPGetCanvas()
    if not g_masterahsanyt_ESPValid(canvas) then return nil end
    local container=nil
    pcall(function() container=CGame:NewObjectFromPath("/Script/UMG.CanvasPanel",canvas) end)
    if not g_masterahsanyt_ESPValid(container) then return nil end
    local currentV1=_G.LunarFeatures and _G.LunarFeatures.V1 and _G.LunarFeatures.V1.Counter
    local displayW=currentV1 and tonumber(currentV1.Width) or 218.4
    local displayH=currentV1 and tonumber(currentV1.Height) or 33.6
    local fontSize=currentV1 and tonumber(currentV1.FontSize) or 13
    local fontScale=currentV1 and tonumber(currentV1.FontScale) or 1.2
    local width,height,shieldH=294.0,44.0,52.0
    local sx,sy=displayW/width,displayH/shieldH
    local strokeScale=math.min(sx,sy)
    local half=width*0.5
    local pieces={}

    local function addRect(x,y,w,h,color,z)
        local widget=nil
        pcall(function() widget=CGame:NewObjectFromPath("/Script/UMG.Border",container) end)
        if not g_masterahsanyt_ESPValid(widget) then return nil end
        local slot=nil
        pcall(function()
            widget:SetBrushColor(color)
            widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            slot=container:AddChildToCanvas(widget)
            slot:SetAutoSize(false)
            slot:SetPosition(g_masterahsanyt_ESPV2(x*sx,y*sy))
            slot:SetSize(g_masterahsanyt_ESPV2(math.max(1.0,w*sx),math.max(1.0,h*sy)))
            slot:SetZOrder(z or 1)
        end)
        if not slot then return nil end
        pieces[#pieces+1]={Widget=widget,Slot=slot}
        return pieces[#pieces]
    end

    local function addLine(x1,y1,x2,y2,thickness,color,z)
        local line=g_masterahsanyt_ESPCreateLine(color,container)
        if not line then return nil end
        pcall(function() line.Slot:SetZOrder(z or 8) end)
        g_masterahsanyt_ESPDrawLine(line,x1*sx,y1*sy,x2*sx,y2*sy,thickness*strokeScale)
        pieces[#pieces+1]=line
        return line
    end

    -- True trapezoid panels: horizontal scanlines keep every sloped edge clean.
    local panelSteps=16
    local bandH=height/panelSteps
    for i=1,panelSteps do
        local y=(i-1)*bandH
        local t=(i-0.5)/panelSteps
        local outerInset=2.0+t*18.0
        local innerInset=34.0-t*24.0
        local leftRight=half-innerInset
        local rightLeft=half+innerInset
        local red=g_masterahsanyt_ESPScaleColor(ESP_COUNTER_RED_DARK,0.82+t*0.28,1.0)
        local blue=g_masterahsanyt_ESPScaleColor(ESP_COUNTER_BLUE_DARK,0.92+t*0.42,1.0)
        addRect(outerInset,y,leftRight-outerInset,bandH+0.15,red,1)
        addRect(rightLeft,y,width-outerInset-rightLeft,bandH+0.15,blue,1)
    end

    -- Bright polygon outlines matching the reference silhouette.
    local lp={{2,1},{half-34,1},{half-20,height*0.66},{half-10,height},{20,height},{2,1}}
    local rp={{width-2,1},{half+34,1},{half+20,height*0.66},{half+10,height},{width-20,height},{width-2,1}}
    for i=1,#lp-1 do addLine(lp[i][1],lp[i][2],lp[i+1][1],lp[i+1][2],2.1,ESP_COUNTER_RED,7) end
    for i=1,#rp-1 do addLine(rp[i][1],rp[i][2],rp[i+1][1],rp[i+1][2],2.1,ESP_COUNTER_BLUE,7) end

    -- Independent downward center shield (not the legacy rotated diamond).
    local shieldSteps=18
    local shieldBand=shieldH/shieldSteps
    for i=1,shieldSteps do
        local y=(i-1)*shieldBand
        local t=(i-0.5)/shieldSteps
        local hw
        if t<0.68 then hw=34.0-t*17.0 else hw=22.5-(t-0.68)*39.0 end
        hw=math.max(9.0,hw)
        addRect(half-hw,y,hw*2.0,shieldBand+0.15,ESP_COUNTER_CENTER,5)
    end

    -- End chevrons and the white center accents/V.
    addLine(5,5,12,height-5,4.0,ESP_COUNTER_CENTER,9)
    addLine(12,5,19,height-5,4.0,ESP_COUNTER_RED,9)
    addLine(width-5,5,width-12,height-5,4.0,ESP_COUNTER_CENTER,9)
    addLine(width-12,5,width-19,height-5,4.0,ESP_COUNTER_BLUE,9)
    addLine(half-12,5,half-7,height*0.58,4.5,ESP_REAL_LIGHT,10)
    addLine(half+12,5,half+7,height*0.58,4.5,ESP_BOT_LIGHT,10)
    addLine(half-11,14,half,35,6.0,ESP_WHITE,11)
    addLine(half+11,14,half,35,6.0,ESP_WHITE,11)

    local function addText(initial,x,color)
        local text=nil
        pcall(function() text=CGame:NewObjectFromPath("/Script/UMG.TextBlock",container) end)
        if not g_masterahsanyt_ESPValid(text) then return nil,nil end
        local slot=nil
        pcall(function()
            text:SetText(initial)
            text:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            if text.SetJustification then text:SetJustification(1) end
            slot=container:AddChildToCanvas(text)
            slot:SetAutoSize(true)
            slot:SetAlignment(g_masterahsanyt_ESPV2(0.5,0.5))
            slot:SetPosition(g_masterahsanyt_ESPV2(x*sx,displayH*0.5))
            slot:SetZOrder(12)
        end)
        g_masterahsanyt_ESPSetTextColor(text,color)
        g_masterahsanyt_ESPSetFont(text,fontSize,0)
        pcall(function()
            text:SetRenderTransformPivot(g_masterahsanyt_ESPV2(0.5,0.5))
            text:SetRenderScale(g_masterahsanyt_ESPV2(fontScale,fontScale))
        end)
        return text,slot
    end

    local realText=addText("REAL: 0",half*0.5,g_masterahsanyt_ESPTheme(false).Text)
    local botText=addText("BOT: 0",half+half*0.5,g_masterahsanyt_ESPTheme(true).Text)
    if not realText or not botText then
        g_masterahsanyt_ESPDestroyWidgetData({Widget=container})
        return nil
    end

    local mainSlot=nil
    pcall(function() mainSlot=canvas:AddChildToCanvas(container) end)
    if not mainSlot then g_masterahsanyt_ESPDestroyWidgetData({Widget=container}) return nil end

    local anchored=false
    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetSize(g_masterahsanyt_ESPV2(displayW,displayH))
        mainSlot:SetZOrder(60)
        -- Viewport-independent top-center anchor: survives aspect ratio, DPI,
        -- notch and safe-zone variations without drifting toward a corner.
        if mainSlot.SetAnchors and Anchors then
            local anchors=nil
            pcall(function()
                anchors=Anchors(
                    g_masterahsanyt_ESPV2(0.5,0.0),
                    g_masterahsanyt_ESPV2(0.5,0.0)
                )
            end)
            if not anchors then pcall(function() anchors=Anchors() end) end
            if anchors then
                pcall(function() anchors.Minimum=g_masterahsanyt_ESPV2(0.5,0.0) end)
                pcall(function() anchors.Maximum=g_masterahsanyt_ESPV2(0.5,0.0) end)
                mainSlot:SetAnchors(anchors)
                mainSlot:SetAlignment(g_masterahsanyt_ESPV2(0.5,0.0))
                anchored=true
            end
        end
    end)

    return {Widget=container,Slot=mainSlot,RealText=realText,BotText=botText,
        Width=displayW,Height=displayH,FontSize=fontSize,FontScale=fontScale,DiamondSize=0,Pieces=pieces,ViewportAnchored=anchored}
end

-- ESP counter position and tracer origin made by @Masterpiece2025
local function g_masterahsanyt_ESPUpdateCounter(realCount, botCount, pc)

    local data = g_masterahsanyt_ShotESP.Counter
    if not data or not g_masterahsanyt_ESPValid(data.Widget) then
        -- The static counter is built atomically; the budget applies to enemy
        -- line groups that would otherwise all spawn together.
        local budget = g_masterahsanyt_ShotESP.BuildRemaining
        g_masterahsanyt_ShotESP.BuildRemaining = nil
        data = g_masterahsanyt_ESPCreateCounter()
        g_masterahsanyt_ShotESP.BuildRemaining = budget
        g_masterahsanyt_ShotESP.Counter = data
    end
    if not data then return nil end

    local cw = g_masterahsanyt_ShotESP.ViewportW
    local centerX = nil

    if tonumber(cw) and cw > 1 then
        centerX = cw * 0.5
    else

        local vw = g_masterahsanyt_ESPViewport(pc)
        centerX =
            (vw * 0.5) * (g_masterahsanyt_ShotESP.CanvasScaleX or 1.0)
            + (g_masterahsanyt_ShotESP.CanvasOffsetX or 0.0)
    end

    if not centerX then return nil end

    local counterY = tonumber(_G.g_masterahsanyt_MasterShotESP.CounterY) or 36.0

    if data.LastReal ~= realCount then
        local ok=pcall(function() data.RealText:SetText(string.format("REAL: %d", realCount or 0)) end)
        if ok then data.LastReal = realCount end
    end
    if data.LastBot ~= botCount then
        local ok=pcall(function() data.BotText:SetText(string.format("BOT: %d", botCount or 0)) end)
        if ok then data.LastBot = botCount end
    end

    local positionChanged = data.CenterX ~= centerX or data.CounterY ~= counterY
    local visibleChanged = data.Visible ~= true
    local applied = pcall(function()
        if positionChanged and data.ViewportAnchored then
            data.Slot:SetPosition(g_masterahsanyt_ESPV2(0.0,counterY))
        elseif positionChanged then
            data.Slot:SetAlignment(g_masterahsanyt_ESPV2(0.0,0.0))
            data.Slot:SetPosition(g_masterahsanyt_ESPV2(centerX-data.Width*0.5,counterY))
        end
        if visibleChanged then data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end
    end)
    if applied then data.CenterX,data.CounterY,data.Visible = centerX,counterY,true end

    local diamondSize = tonumber(data.DiamondSize) or 20.0
    local anchorX = centerX
    local anchorY = counterY + (data.Height * 0.5) + (diamondSize / math.sqrt(2.0))

    data.AnchorX = anchorX
    data.AnchorY = anchorY

    g_masterahsanyt_ShotESP.TracerOrigin = g_masterahsanyt_ESPV2(anchorX, anchorY)
    return g_masterahsanyt_ShotESP.TracerOrigin
end

-- ESP enemy scan made by @Masterpiece2025
local function g_masterahsanyt_ESPScanEnemies()
    local pc = g_masterahsanyt_ESPGetController()
    local me = g_masterahsanyt_ESPGetLocalCharacter()
    if not pc or not me then g_masterahsanyt_ShotESP.Enemies = {} return nil, 0, 0 end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    if not myLoc then g_masterahsanyt_ShotESP.Enemies = {} return pc, 0, 0 end
    local myTeam = g_masterahsanyt_ESPGetTeamID(me)

    local list = {}
    local realCount, botCount = 0, 0
    local pawns=ESPShared.GetFramePawns()
    pawns = pawns or _G.g_masterahsanyt_TrackedCharacters
    if pawns then
        for _, character in pairs(pawns) do
            if character~=me and ESPShared.GetFrameRecord(character).Alive and ESPShared.Events.Counted(character) then
                local team = g_masterahsanyt_ESPGetTeamID(character)
                -- Fix: only skip as same-team when both IDs are non-zero and equal
                local sameTeam = false
                if myTeam ~= nil and team ~= nil then
                    local tNum, mNum = tonumber(team), tonumber(myTeam)
                    sameTeam = tNum and mNum and tNum > 0 and mNum > 0 and tNum == mNum
                end
                if not sameTeam then
                    local loc = ESPShared.GetFrameRecord(character).Location
                    local dist = ESPShared.DistanceMetersFrom(ESPShared.GetFrameRecord(character),myLoc)
                    if dist <= (tonumber(_G.g_masterahsanyt_MasterShotESP.MaxRangeMeters) or 400.0) then
                        local key = g_masterahsanyt_ESPGetPlayerKey(character)
                        local isBot = g_masterahsanyt_ESPIsBot(character,key)
                        if isBot then botCount = botCount + 1 else realCount = realCount + 1 end
                        list[#list+1] = {Character=character, Key=key, IsBot=isBot, Distance=dist}
                    end
                end
            end
        end
    end
    table.sort(list, function(a,b)
        if a.Distance == b.Distance then return a.Key < b.Key end
        return (a.Distance or 99999) < (b.Distance or 99999)
    end)
    g_masterahsanyt_ShotESP.Enemies = list
    return pc, realCount, botCount
end

-- ESP stale widget cleanup made by @Masterpiece2025
local function g_masterahsanyt_ESPPrune(active,alive)
    -- Visual caches follow the displayed set. Counting metadata follows alive.
    -- Move header children into their actor-free parent bundle before pruning
    -- either registry; no detached child can follow a different enemy.
    for key,root in pairs(g_masterahsanyt_ShotESP.HeaderRoots) do
        if not active[key] and root.PoolOwner and root.Groups then
            root.Groups.__Header=g_masterahsanyt_ShotESP.Headers[key]
            g_masterahsanyt_ShotESP.Headers[key]=nil
        end
    end
    for _,registry in ipairs({g_masterahsanyt_ShotESP.Lines,g_masterahsanyt_ShotESP.Names,
        g_masterahsanyt_ShotESP.Decorations,g_masterahsanyt_ShotESP.HeaderRoots}) do
        for key,data in pairs(registry) do
            if not active[key] then g_masterahsanyt_ESPDestroyWidgetData(data);registry[key]=nil end
        end
    end
    for _,registry in ipairs({g_masterahsanyt_ShotESP.Boxes,g_masterahsanyt_ShotESP.HealthBars,
        g_masterahsanyt_ShotESP.Skeletons,g_masterahsanyt_ShotESP.Headers,g_masterahsanyt_ShotESP.Footers}) do
        for key,group in pairs(registry) do
            if not active[key] then g_masterahsanyt_ESPDestroyGroup(group);registry[key]=nil end
        end
    end
    for _,registry in ipairs({g_masterahsanyt_ShotESP.BuildStage,g_masterahsanyt_ShotESP.BoneNameCache,
        g_masterahsanyt_ShotESP.BoneMeshes,g_masterahsanyt_ShotESP.BonePoints}) do
        for key in pairs(registry) do if not active[key] then registry[key]=nil end end
    end
    for key in pairs(g_masterahsanyt_ShotESP._BotCache) do if not alive[key] then g_masterahsanyt_ShotESP._BotCache[key]=nil end end
end

ESPShared.Events.Clearers[#ESPShared.Events.Clearers+1]=function(actor)
    ESPShared.Events.ClearIn(g_masterahsanyt_ShotESP,g_masterahsanyt_ESPPrune,actor)
end

-- ESP main HUD update made by @Masterpiece2025
local function g_masterahsanyt_ESPUpdate()
    local opt = _G.g_masterahsanyt_ESPOptions
    local anyEnabled = opt and (opt.Name or opt.Line or opt.Box or opt.Health or opt.Distance or opt.Skeleton or opt.Counter)
    if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) or not _G.g_masterahsanyt_MasterShotESP.Enabled or not anyEnabled then
        if not g_masterahsanyt_ShotESP.Disabled then g_masterahsanyt_ESPResetWidgets() end
        g_masterahsanyt_ShotESP.Disabled = true
        return
    end
    g_masterahsanyt_ShotESP.Disabled = false
    local buildBudget = tonumber(_G.g_masterahsanyt_MasterShotESP.WidgetBuildBudget) or 96
    if buildBudget ~= buildBudget or buildBudget == math.huge then buildBudget = 96 end
    g_masterahsanyt_ShotESP.BuildRemaining = math.max(1, math.floor(buildBudget))

    local world = g_masterahsanyt_ESPWorld()
    ESPShared.Events.WorldChanged(world)
    if world ~= g_masterahsanyt_ShotESP.LastWorld then
        g_masterahsanyt_ESPResetWidgets()
        g_masterahsanyt_ShotESP.LastWorld = world
        g_masterahsanyt_ShotESP.LastScanClock = -999.0
        g_masterahsanyt_ShotESP.LastTransformClock = -999.0
        g_masterahsanyt_ShotESP.TracerOrigin = nil
    end

    if g_masterahsanyt_ShotESP.Canvas and not g_masterahsanyt_ESPValid(g_masterahsanyt_ShotESP.Canvas) then
        g_masterahsanyt_ESPResetWidgets()
    end
    local canvas = g_masterahsanyt_ESPGetCanvas()
    if not canvas then return end
    local now = g_masterahsanyt_ESPNow()
    g_masterahsanyt_ShotESP.Now = now
    if now < g_masterahsanyt_ShotESP.LastScanClock then
        g_masterahsanyt_ShotESP.LastScanClock = -999.0
        g_masterahsanyt_ShotESP.LastTransformClock = -999.0
    end
    local pc = g_masterahsanyt_ESPGetController()
    local me = g_masterahsanyt_ESPGetLocalCharacter()
    if pc ~= g_masterahsanyt_ShotESP.LastController or me ~= g_masterahsanyt_ShotESP.LastPawn then
        g_masterahsanyt_ESPResetWidgets()
        g_masterahsanyt_ShotESP.LastController, g_masterahsanyt_ShotESP.LastPawn = pc,me
        canvas = g_masterahsanyt_ESPGetCanvas()
        if not canvas then return end
    end
    if not pc or not me then return end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    local realCount, botCount = nil, nil
    if (now - g_masterahsanyt_ShotESP.LastScanClock) >= (tonumber(_G.g_masterahsanyt_MasterShotESP.ScanInterval) or 0.30) then
        pc, realCount, botCount = g_masterahsanyt_ESPScanEnemies()
        g_masterahsanyt_ShotESP.LastScanClock = now
        g_masterahsanyt_ShotESP.RealCount, g_masterahsanyt_ShotESP.BotCount = realCount, botCount
    end
    pc = pc or g_masterahsanyt_ESPGetController()
    if not pc then return end

    if (now - (g_masterahsanyt_ShotESP.LastTransformClock or -999.0))
        >= (tonumber(_G.g_masterahsanyt_MasterShotESP.TransformInterval) or 0.50) then
        g_masterahsanyt_ESPUpdateCanvasTransform(pc)
        local cw,ch=g_masterahsanyt_ESPGetCanvasLocalSize()
        if cw and ch then g_masterahsanyt_ShotESP.ViewportW,g_masterahsanyt_ShotESP.ViewportH=cw,ch end
        local rw,rh=g_masterahsanyt_ESPViewport(pc)
        g_masterahsanyt_ShotESP.RawViewportW,g_masterahsanyt_ShotESP.RawViewportH=rw,rh
        g_masterahsanyt_ShotESP.LastTransformClock = now
    end

    local rawW,rawH=ESPShared.ViewSize(pc)
    -- The tracer uses the physical viewport midpoint in canvas coordinates.
    local canvasScaleX=ESPShared.SafeNumber(g_masterahsanyt_ShotESP.CanvasScaleX,1.0,0.00001,100)
    local canvasScaleY=ESPShared.SafeNumber(g_masterahsanyt_ShotESP.CanvasScaleY,1.0,0.00001,100)
    local canvasOffsetX=ESPShared.SafeNumber(g_masterahsanyt_ShotESP.CanvasOffsetX,0.0,-1e7,1e7)
    local canvasOffsetY=ESPShared.SafeNumber(g_masterahsanyt_ShotESP.CanvasOffsetY,0.0,-1e7,1e7)
    local originCenter = g_masterahsanyt_ESPV2(
        (rawW*0.5)*canvasScaleX+canvasOffsetX,
        4.0*canvasScaleY+canvasOffsetY
    )
    local active,alive=g_masterahsanyt_ShotESP.Active,g_masterahsanyt_ShotESP.Alive
    g_masterahsanyt_ShotESP.RealCount,g_masterahsanyt_ShotESP.BotCount=g_masterahsanyt_ESPFilterEnemies(
        g_masterahsanyt_ShotESP.Enemies,myLoc,_G.g_masterahsanyt_MasterShotESP.MaxRangeMeters,alive)
    if opt.Counter then
        g_masterahsanyt_ESPUpdateCounter(
            g_masterahsanyt_ShotESP.RealCount or 0,
            g_masterahsanyt_ShotESP.BotCount or 0,
            pc
        )
    elseif g_masterahsanyt_ShotESP.Counter then
        g_masterahsanyt_ESPHide(g_masterahsanyt_ShotESP.Counter)
    end

    -- Counter-only mode stops here after validating cached scan candidates, avoiding
    -- projection, skeleton, box and per-enemy widget work entirely.
    local detailedEnabled=opt.Name or opt.Line or opt.Box or opt.Health or opt.Distance or opt.Skeleton
    if not detailedEnabled then
        for key in pairs(active) do active[key]=nil end
        g_masterahsanyt_ESPPrune(active,alive)
        return
    end

    for key in pairs(active) do active[key]=nil end
    local configuredMax=math.floor(ESPShared.SafeNumber(_G.g_masterahsanyt_MasterShotESP.MaxRendered,8,1,64))
    local maxRendered = configuredMax
    local renderedCount=0
    -- Keep the nearest-candidate budget; counting still validates every actor.
    for index,item in ipairs(g_masterahsanyt_ShotESP.Enemies) do
        if index>maxRendered then break end
        local c,key=item.Character,item.Key
        local headScreen,footScreen,onScreen=ESPShared.Events.Project(pc,c,g_masterahsanyt_ShotESP)
        if onScreen then
            if renderedCount<maxRendered then
                renderedCount=renderedCount+1
                active[key] = true
                local buildStage=g_masterahsanyt_ShotESP.BuildStage[key] or 1
                local color = item.IsBot and ESP_BOT or ESP_REAL
                local line = g_masterahsanyt_ShotESP.Lines[key]

                local colorKey = item.IsBot and "BOT" or "REAL"
                if opt.Line and (not line or not g_masterahsanyt_ESPValid(line.Widget)) then
                    g_masterahsanyt_ESPDestroyWidgetData(line)
                    line = g_masterahsanyt_ESPCreateLine(color)
                    if line then line.ColorKey = colorKey end
                    g_masterahsanyt_ShotESP.Lines[key] = line
                elseif opt.Line and line and line.ColorKey ~= colorKey then
                    pcall(function() line.Widget:SetBrushColor(color) end)
                    line.ColorKey = colorKey
                end

                if opt.Line and line then
                    local tracerTarget = headScreen or footScreen
                    if tracerTarget then
                        g_masterahsanyt_ESPDrawLine(
                            line,
                            originCenter.X, originCenter.Y,
                            tracerTarget.X, tracerTarget.Y,
                            tonumber(_G.g_masterahsanyt_MasterShotESP.TracerThickness) or 1.80
                        )
                    end
                elseif line then g_masterahsanyt_ESPHide(line) end

                g_masterahsanyt_ESPUpdateDecoration(key,c,headScreen,footScreen,opt,buildStage,item.IsBot)
                g_masterahsanyt_ESPUpdateNameTag(key,c,headScreen,footScreen,item.IsBot,item.Distance)
                -- Header frame: dynamic per-frame update (fills, corner fills, scale with name)
                g_masterahsanyt_ESPUpdateHeaderFrame(key,headScreen,footScreen,opt.Name==true,item.IsBot)

                -- All visible skeletons refresh with the current camera; no round-robin delay.
                g_masterahsanyt_ESPUpdateSkeleton(key, c, pc, opt.Skeleton == true, item.IsBot)
                g_masterahsanyt_ShotESP.BuildStage[key]=math.min(5,buildStage+1)

            end
        end
    end
    g_masterahsanyt_ESPPrune(active,alive)
end

-- One pending render chain. Menu refreshes invalidate/wake it rather than
-- drawing synchronously multiple times in the same frame.
local g_masterahsanyt_ESPRunnerToken={}
if type(_G.__MasterShotESPCleanup) == "function" then pcall(_G.__MasterShotESPCleanup) end
_G.__MasterShotESPRunner=g_masterahsanyt_ESPRunnerToken
_G.__MasterShotESPCleanup=g_masterahsanyt_ESPResetWidgets
local g_masterahsanyt_ESPDiagnostics={Updates=0,Errors=0,LastError=nil}
_G.g_masterahsanyt_ESPDiagnostics=g_masterahsanyt_ESPDiagnostics
local g_masterahsanyt_ESPTicker=nil
pcall(function() g_masterahsanyt_ESPTicker=require("common.time_ticker") end)
local g_masterahsanyt_ESPTick
local function g_masterahsanyt_ESPSchedule(delay)
    delay=ESPShared.SafeNumber(delay,0.50,0.001,0.50)
    if _G.__MasterShotESPRunner~=g_masterahsanyt_ESPRunnerToken then return end
    if not g_masterahsanyt_ESPTicker or not g_masterahsanyt_ESPTicker.AddTimerOnce then
        g_masterahsanyt_ESPDiagnostics.LastError="common.time_ticker.AddTimerOnce unavailable"
        return
    end
    local serial=(g_masterahsanyt_ESPRunnerToken.Serial or 0)+1
    g_masterahsanyt_ESPRunnerToken.Serial=serial
    g_masterahsanyt_ESPRunnerToken.Due=g_masterahsanyt_ESPNow()+delay
    local ok, err=pcall(g_masterahsanyt_ESPTicker.AddTimerOnce,delay,function()
        if _G.__MasterShotESPRunner~=g_masterahsanyt_ESPRunnerToken
            or g_masterahsanyt_ESPRunnerToken.Serial~=serial then return end
        g_masterahsanyt_ESPRunnerToken.Due=nil
        g_masterahsanyt_ShotESP.TimerClock=g_masterahsanyt_ShotESP.TimerClock+delay
        g_masterahsanyt_ESPTick()
    end)
    if not ok or err==false then
        g_masterahsanyt_ESPRunnerToken.Due=nil
        g_masterahsanyt_ESPDiagnostics.Errors=g_masterahsanyt_ESPDiagnostics.Errors+1
        g_masterahsanyt_ESPDiagnostics.LastError=tostring(err)
    end
end
g_masterahsanyt_ESPTick=function()
    local token=g_masterahsanyt_ESPRunnerToken
    if _G.__MasterShotESPRunner~=token then return end
    local now=g_masterahsanyt_ESPNow()
    local profiling=_G.g_masterahsanyt_MasterShotESP.Profile and os and type(os.clock)=="function"
    local callbackStarted=profiling and os.clock() or nil
    ESPShared.Frame.Begin(now)
    local F=_G.LunarFeatures
    if F then F.TimerClock=g_masterahsanyt_ShotESP.TimerClock end
    if not token.RenderDue or now>=token.RenderDue-0.000001 or (token.LastRenderClock and now<token.LastRenderClock) then
        local previous=g_masterahsanyt_ESPDiagnostics.LastTickSeconds
        if previous and now>previous then g_masterahsanyt_ESPDiagnostics.UpdateHz=1/(now-previous) end
        g_masterahsanyt_ESPDiagnostics.LastTickSeconds=now
        local started=profiling and os.clock() or nil
        local ok,err=pcall(g_masterahsanyt_ESPUpdate)
        g_masterahsanyt_ESPDiagnostics.LastUpdateOK=ok
        g_masterahsanyt_ESPDiagnostics.Updates=g_masterahsanyt_ESPDiagnostics.Updates+1
        if not ok then
            g_masterahsanyt_ESPDiagnostics.Errors=g_masterahsanyt_ESPDiagnostics.Errors+1
            g_masterahsanyt_ESPDiagnostics.LastError=tostring(err)
        end
        if started then
            local elapsed=os.clock()-started
            g_masterahsanyt_ESPDiagnostics.LastUpdateCPUSeconds=elapsed
            g_masterahsanyt_ESPDiagnostics.MaxUpdateCPUSeconds=math.max(elapsed,g_masterahsanyt_ESPDiagnostics.MaxUpdateCPUSeconds or 0)
        end
        local o=_G.g_masterahsanyt_ESPOptions or {}
        local enabled=_G.g_masterahsanyt_MasterShotESP.Enabled and _G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized
        local detailed=enabled and (o.Name or o.Line or o.Box or o.Health or o.Distance or o.Skeleton)
        local interval=tonumber(_G.g_masterahsanyt_MasterShotESP.UpdateInterval) or 1/60
        if not detailed then interval=enabled and o.Counter and math.max(0.05,tonumber(_G.g_masterahsanyt_MasterShotESP.ScanInterval) or 0.35) or 0.50 end
        if interval~=interval or math.abs(interval)==math.huge or interval<=0 then interval=1/60 end
        token.LastRenderClock=now
        token.RenderDue=now+math.max(0.001,interval)
    end
    if profiling then g_masterahsanyt_ESPDiagnostics.LastPumpCPUSeconds=0 end
    if F and F.Pump and not F.Token.Stopped then
        local pumpStarted=profiling and os.clock() or nil
        local ok,err=pcall(F.Pump,now)
        if not ok then F.Error("Scheduler",err) end
        if pumpStarted then
            local elapsed=os.clock()-pumpStarted
            g_masterahsanyt_ESPDiagnostics.LastPumpCPUSeconds=elapsed
            g_masterahsanyt_ESPDiagnostics.MaxPumpCPUSeconds=math.max(elapsed,g_masterahsanyt_ESPDiagnostics.MaxPumpCPUSeconds or 0)
        end
    end
    ESPShared.Frame.Finish()
    local after=g_masterahsanyt_ESPNow()
    local interval=math.max(0.001,token.RenderDue-after)
    if F and F.NextInterval and not F.Token.Stopped then interval=math.min(interval,F.NextInterval(after)) end
    g_masterahsanyt_ESPSchedule(interval)
    if callbackStarted then
        local elapsed=os.clock()-callbackStarted
        g_masterahsanyt_ESPDiagnostics.LastCallbackCPUSeconds=elapsed
        g_masterahsanyt_ESPDiagnostics.MaxCallbackCPUSeconds=math.max(elapsed,g_masterahsanyt_ESPDiagnostics.MaxCallbackCPUSeconds or 0)
        g_masterahsanyt_ESPDiagnostics.TotalCallbackCPUSeconds=(g_masterahsanyt_ESPDiagnostics.TotalCallbackCPUSeconds or 0)+elapsed
        g_masterahsanyt_ESPDiagnostics.CallbackSamples=(g_masterahsanyt_ESPDiagnostics.CallbackSamples or 0)+1
    end
end


_G.g_masterahsanyt_MasterShotESPForceRefresh = function()
    if _G.__MasterShotESPRunner~=g_masterahsanyt_ESPRunnerToken then return end
    g_masterahsanyt_ESPRunnerToken.RenderDue=nil
    g_masterahsanyt_ShotESP.LastScanClock = -999.0
    g_masterahsanyt_ShotESP.LastTransformClock = -999.0
    local due=g_masterahsanyt_ESPRunnerToken.Due
    if not due or due-g_masterahsanyt_ESPNow()>0.002 then g_masterahsanyt_ESPSchedule(0.001) end
end

-- Managed feature state. Source settings are data, never loaded as executable Lua.
do
    if type(_G.__LunarFeaturesCleanup) == "function" then pcall(_G.__LunarFeaturesCleanup) end
    local F = {Token={}, Diagnostics={Errors=0}, TimerClock=0, LastWorld=nil}
    _G.LunarFeatures=F
    local settings = _G.LunarFeatureSettings or {}
    _G.LunarFeatureSettings=settings
    F.Settings=settings
    local function number(value,lo,hi,fallback)
        local v=tonumber(value)
        if not v or v~=v or v==math.huge or v==-math.huge then v=fallback end
        return math.floor(math.max(lo,math.min(hi,v))+0.5)
    end
    F.Clamp=number
    settings.IpadFOV=number(settings.IpadFOV or _G.LexusState.CustomTextData.IpadViewFOV,90,120,120)
    settings.AimSpeed=number(settings.AimSpeed,100,120,100)
    settings.AimTarget=number(settings.AimTarget,1,3,1)
    settings.AimEnabled=settings.AimEnabled==true
    settings.WallEnabled=settings.WallEnabled==true
    settings.WallVisible=number(settings.WallVisible,1,7,1)
    settings.WallOccluded=number(settings.WallOccluded,1,7,2)
    settings.Aim2Enabled=settings.Aim2Enabled==true
    settings.MortarEnabled=settings.MortarEnabled==true
    _G.g_Botmater_ESPOptions=_G.g_Botmater_ESPOptions or {}
    for _,key in ipairs({"Name","Line","Health","Distance","EnemyCounter"}) do
        if _G.g_Botmater_ESPOptions[key]==nil then _G.g_Botmater_ESPOptions[key]=false end
    end
    local paths=g_masterahsanyt_ESPSettingsPaths()
    for i,path in ipairs(paths) do paths[i]=path:gsub("MASTERPIECE_UMG_ESP_settings.lua$","MASTERAHSAN_FEATURES_V3_settings.lua") end
    if io and io.open then
        for _,path in ipairs(paths) do
            local ok,file=pcall(io.open,path,"r")
            if ok and file then
                local readOK,payload=pcall(function() return file:read("*a") end)
                pcall(function() file:close() end)
                if readOK and type(payload)=="string" then
                    F.SettingsReadPath=path
                    for _,key in ipairs({"AimEnabled","WallEnabled","IpadEnabled","Aim2Enabled","MortarEnabled"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then
                            if key=="IpadEnabled" then _G.LexusConfig.IpadView=val=="true" else settings[key]=val=="true" end
                        end
                    end
                    for _,key in ipairs({"IpadFOV","AimSpeed","AimTarget"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*([%d%.%-]+)")
                        if val then settings[key]=number(val,key=="IpadFOV" and 90 or (key=="AimSpeed" and 100 or 1),key=="AimTarget" and 3 or 120,settings[key]) end
                    end
                    for _,key in ipairs({"WallVisible","WallOccluded"}) do
                        local val=payload:match("%f[%w_]"..key.."%s*=%s*([%d%.%-]+)")
                        if val then settings[key]=number(val,1,7,settings[key]) end
                    end
                    for _,key in ipairs({"Name","Line","Health","Distance","EnemyCounter"}) do
                        local val=payload:match("%f[%w_]V1_"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then _G.g_Botmater_ESPOptions[key]=val=="true" end
                    end
                    for _,key in ipairs({"Name","Line","Box","Health","Distance","Skeleton","Counter"}) do
                        local val=payload:match("%f[%w_]V2_"..key.."%s*=%s*(%a+)")
                        if val=="true" or val=="false" then _G.g_masterahsanyt_ESPOptions[key]=val=="true" end
                    end
                    break
                end
            end
        end
    end
    if not F.SettingsReadPath and g_masterahsanyt_ESPLoadedSettingsPath then
        F.SettingsReadPath=g_masterahsanyt_ESPLoadedSettingsPath:gsub("MASTERPIECE_UMG_ESP_settings%.lua$","MASTERAHSAN_FEATURES_V3_settings.lua")
    end
    if settings.Aim2Enabled then settings.AimEnabled=false end
    _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
    F.Now=function()
        local now=nil
        pcall(function()
            local world=g_masterahsanyt_ESPWorld()
            if world and GameplayStaticsESP and GameplayStaticsESP.GetRealTimeSeconds then now=GameplayStaticsESP.GetRealTimeSeconds(world) end
        end)
        return tonumber(now) or F.TimerClock
    end
    F.Save=function(force)
        if not F.Dirty or not io or not io.open then return end
        local lines={"return {", "  IpadEnabled = "..tostring(_G.LexusConfig.IpadView==true)..","}
        for _,key in ipairs({"AimEnabled","WallEnabled","Aim2Enabled","MortarEnabled","IpadFOV","AimSpeed","AimTarget","WallVisible","WallOccluded"}) do lines[#lines+1]="  "..key.." = "..tostring(settings[key]).."," end
        for _,key in ipairs({"Name","Line","Health","Distance","EnemyCounter"}) do lines[#lines+1]="  V1_"..key.." = "..tostring(_G.g_Botmater_ESPOptions[key]==true).."," end
        for _,key in ipairs({"Name","Line","Box","Health","Distance","Skeleton","Counter"}) do lines[#lines+1]="  V2_"..key.." = "..tostring(_G.g_masterahsanyt_ESPOptions[key]==true).."," end
        lines[#lines+1]="}"
        local payload=table.concat(lines,"\n")
        local savePaths=F.SettingsReadPath and {F.SettingsReadPath} or paths
        for _,path in ipairs(savePaths) do
            local wrote,reason,atomic=g_masterahsanyt_ESPWriteSettings(path,payload)
            if wrote then
                F.SettingsReadPath=path;F.Dirty=false;F.Diagnostics.LastSaveOK=true;F.Diagnostics.LastSavePath=path;F.Diagnostics.AtomicSave=atomic
                return true
            end
            F.Diagnostics.LastSaveError=reason
        end
        F.Diagnostics.LastSaveOK=false
        return false
    end
    F.MarkDirty=function(immediate) F.Dirty=true;if immediate then F.Save(true) end end
    F.SetIpad=function(enabled)
        _G.LexusConfig.IpadView=enabled==true or enabled==1
        _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
        pcall(g_masterahsanyt_ApplyiPadView)
        F.MarkDirty(true)
    end
    F.SetIpadFOV=function(value)
        settings.IpadFOV=number(value,90,120,120)
        _G.LexusState.CustomTextData.IpadViewFOV=settings.IpadFOV
        pcall(g_masterahsanyt_ApplyiPadView)
        F.MarkDirty()
    end
    F.SetAimSpeed=function(value)
        local previousSpeed=settings.AimSpeed
        settings.AimSpeed=number(value,100,120,100)
        if settings.AimSpeed~=previousSpeed then
            F.AimLastClock=nil;F.AimDue=0
            if _G.XthrlenState then _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0 end
        end
        if _G.XthrlenState and _G.XthrlenState.CustomTextData then
            local data=_G.XthrlenState.CustomTextData
            data.AimTouchHipSpeed=settings.AimSpeed
            data.AimTouchScopeSpeed=settings.AimSpeed
        end
        F.MarkDirty()
    end
    F.SetAimTarget=function(value) settings.AimTarget=number(value,1,3,1);F.MarkDirty(true) end
    -- ItemBase supports caller-owned event keys. Both native switches subscribe
    -- through its normal lifecycle; there are no saved widget references.
    F.AimSettingsEventType=-14050701
    F.AimSettingsEventID=1
    F.SetAimMode=function(value)
        local mode=F.Clamp(value,0,2,0)
        local changed=settings.AimEnabled~=(mode==1) or settings.Aim2Enabled~=(mode==2)
        settings.AimEnabled=mode==1
        settings.Aim2Enabled=mode==2
        _G.XthrlenConfig.AimTouchEnable=settings.AimEnabled
        if not settings.AimEnabled then
            _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0;F.AimLastClock=nil
        end
        if not settings.Aim2Enabled and F.Aim2 then F.Aim2.Stop() end
        if F.Aim2 then F.Aim2.Due=0 end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
        if changed and EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,F.AimSettingsEventType,F.AimSettingsEventID)
            if not ok then F.Error("Aim.SettingsRefresh",err) end
        end
    end
    F.SetAim=function(enabled)
        local on=enabled==true or enabled==1
        F.SetAimMode(on and 1 or (settings.Aim2Enabled and 2 or 0))
    end
    F.SetAim2=function(enabled)
        local on=enabled==true or enabled==1
        F.SetAimMode(on and 2 or (settings.AimEnabled and 1 or 0))
    end
    F.SetMortar=function(enabled)
        settings.MortarEnabled=enabled==true or enabled==1
        if not settings.MortarEnabled and F.Mortar then F.Mortar.Stop() end
        if F.Mortar then F.Mortar.Due=0 end
        F.MarkDirty(true)
        if F.Wake then F.Wake() end
    end

    F.RefreshWallSettings=function()
        if EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,-14050701,3)
            if not ok then F.Error("Wall.SettingsRefresh",err) end
        end
    end
    F.SetWall=function(enabled)
        local changed=settings.WallEnabled~=(enabled==true or enabled==1)
        settings.WallEnabled=enabled==true or enabled==1
        if not settings.WallEnabled and F.Wall then F.Wall.Stop() end
        F.MarkDirty(true)
        if changed then F.RefreshWallSettings() end
        if F.Wake then F.Wake() end
    end
    F.SetWallColor=function(key,value)
        if key~="WallVisible" and key~="WallOccluded" then return false end
        local v=number(value,1,7,settings[key])
        if settings[key]==v then return true end
        settings[key]=v
        if F.Wall then F.Wall.UpdateColors() end
        F.MarkDirty(true)
        F.RefreshWallSettings()
        if settings.WallEnabled and F.Wake then F.Wake() end
        return true
    end
    -- Feature correspondence is resolved at setting changes only, never per frame.
    local v1Keys={"Name","Line","Health","Distance","EnemyCounter"}
    local v2Keys={"Name","Line","Box","Health","Distance","Skeleton","Counter"}
    local v1ToV2={Name="Name",Line="Line",Health="Health",Distance="Distance",EnemyCounter="Counter"}
    local v2ToV1={Name="Name",Line="Line",Health="Health",Distance="Distance",Counter="EnemyCounter"}
    local v2Valid={Name=true,Line=true,Box=true,Health=true,Distance=true,Skeleton=true,Counter=true}
    F.ESPSettingsEventType=-14050701
    F.ESPSettingsEventID=2
    local function applyESP(version,key,on)
        local first,second=false,false
        local own=version==1 and _G.g_Botmater_ESPOptions or _G.g_masterahsanyt_ESPOptions
        local other=version==1 and _G.g_masterahsanyt_ESPOptions or _G.g_Botmater_ESPOptions
        local mapped=(version==1 and v1ToV2 or v2ToV1)[key]
        if (own[key]==true)~=on then own[key]=on;first=true end
        if on and mapped and other[mapped]==true then other[mapped]=false;second=true end
        if version==1 then return first,second end
        return second,first
    end
    local function commitESP(changedV1,changedV2)
        if not changedV1 and not changedV2 then
            if F.Dirty then return F.Save(true) end
            return true
        end
        if changedV1 and F.V1 then F.V1.Refresh();F.V1Due=0 end
        F.MarkDirty(true)
        if changedV2 then
            _G.g_masterahsanyt_MasterShotESPForceRefresh()
        else
            local due=g_masterahsanyt_ESPRunnerToken.Due
            if not due or due-g_masterahsanyt_ESPNow()>0.002 then g_masterahsanyt_ESPSchedule(0.001) end
        end
        if EventSystem and type(EventSystem.postEvent)=="function" then
            local ok,err=pcall(EventSystem.postEvent,EventSystem,F.ESPSettingsEventType,F.ESPSettingsEventID)
            if not ok then F.Error("ESP.SettingsRefresh",err) end
        end
        return true
    end
    F.SetESP=function(version,key,value)
        if version~=1 and version~=2 then return false end
        if (version==1 and not v1ToV2[key]) or (version==2 and not v2Valid[key]) then return false end
        local changedV1,changedV2=applyESP(version,key,value==true or value==1)
        return commitESP(changedV1,changedV2)
    end
    F.GetESPAll=function(version)
        if version~=1 and version~=2 then return false end
        local own=version==1 and _G.g_Botmater_ESPOptions or _G.g_masterahsanyt_ESPOptions
        for _,key in ipairs(version==1 and v1Keys or v2Keys) do if own[key]~=true then return false end end
        return true
    end
    F.SetESPAll=function(version,value)
        if version~=1 and version~=2 then return false end
        local changedV1,changedV2=false,false
        for _,key in ipairs(version==1 and v1Keys or v2Keys) do
            local a,b=applyESP(version,key,value==true or value==1)
            changedV1,changedV2=changedV1 or a,changedV2 or b
        end
        return commitESP(changedV1,changedV2)
    end
    -- Native OnSelected skips SetFunc when the same index is selected again.
    -- Bulk command rows must still apply to partial ESP state. Only these marked
    -- rows receive the additional click callback; every other native row is untouched.
    F.InstallNativeBulkSwitch=function(class)
        if type(class)~="table" or type(class.OnSelected)~="function" then return false end
        if class.__LunarBulkSwitchV7 then return true end
        local original=class.OnSelected
        class.OnSelected=function(self,index)
            local data=self.Data
            local repeatBulk=data and data.LunarBulk and self.UIRoot.Selector:GetSelectedIndex()==index
            local result=original(self,index)
            if repeatBulk then return data.SetFunc(data.Key,self:_IndexToValue(index)) end
            return result
        end
        class.__LunarBulkSwitchV7=true
        return true
    end
    F.SetV1=function(key,value) return F.SetESP(1,key,value) end
    F.SetV2=function(key,value) return F.SetESP(2,key,value) end
    -- Old versions allowed both copies on. Resolve old conflicts once at load,
    -- giving V1 priority; persist the merged state through the existing save pump.
    for key,mapped in pairs(v1ToV2) do
        if _G.g_Botmater_ESPOptions[key]==true and _G.g_masterahsanyt_ESPOptions[mapped]==true then
            _G.g_masterahsanyt_ESPOptions[mapped]=false
            F.MarkDirty()
        end
    end
    F.Error=function(area,err)
        F.Diagnostics.Errors=F.Diagnostics.Errors+1
        F.Diagnostics.LastError=area..": "..tostring(err)
    end
    _G.__LunarFeaturesCleanup=function()
        F.Token.Stopped=true
        if ESPShared.Events.UnbindAll then ESPShared.Events.UnbindAll() end
        if F.V1 then F.V1.Reset() end
        if F.Wall then F.Wall.Stop() end
        if F.Aim2 then F.Aim2.Stop() end
        if F.Mortar then F.Mortar.Stop() end
    end
end

do
local AimV2,AimGameplayStatics,AimMath,AimUI
pcall(function() AimV2=import("Vector2D") end)
pcall(function() AimGameplayStatics=import("GameplayStatics") end)
pcall(function() AimMath=import("KismetMathLibrary") end)
pcall(function() AimUI=require("client.common.ui_util") end)
_G.XthrlenConfig = _G.XthrlenConfig or {}
_G.XthrlenState = _G.XthrlenState or {}
_G.XthrlenState.CustomTextData = _G.XthrlenState.CustomTextData or {}

_G.XthrlenConfig.AimTouchEnable        = _G.LunarFeatures.Settings.AimEnabled
_G.XthrlenConfig.AimTouchHipfire       = true
_G.XthrlenConfig.AimTouchScopeAll      = true
_G.XthrlenConfig.AimTouchHipVisCheck   = true
_G.XthrlenConfig.AimTouchScopeVisCheck = true
_G.XthrlenConfig.AimTouchHipIgKnock    = true
_G.XthrlenConfig.AimTouchScopeIgKnock  = true

_G.XthrlenConfig.AimTouchHipIgBot      = false
_G.XthrlenConfig.AimTouchScopeIgBot    = false
_G.XthrlenConfig.AimTouchSG            = false
_G.XthrlenConfig.AimTouchSGAutoFire    = false
_G.XthrlenConfig.AimTouchScopeSniper   = false
_G.XthrlenConfig.AimTouchMortar        = false
_G.XthrlenConfig.EspFovCircle          = false

_G.XthrlenState.CustomTextData.AimTouchHipPrio    = 1
_G.XthrlenState.CustomTextData.AimTouchHipBone    = 1
_G.XthrlenState.CustomTextData.AimTouchHipCond    = 1
_G.XthrlenState.CustomTextData.AimTouchHipSpeed   = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchHipDist    = 120
_G.XthrlenState.CustomTextData.AimTouchHipFOV     = 30

_G.XthrlenState.CustomTextData.AimTouchScopePrio   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeBone   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeCond   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeSpeed  = _G.LunarFeatures.Settings.AimSpeed
_G.XthrlenState.CustomTextData.AimTouchScopeDist   = 120
_G.XthrlenState.CustomTextData.AimTouchScopeFOV    = 30
_G.XthrlenState.CustomTextData.AimTouchScopePred   = 0

_G.XthrlenState.offPitch = _G.XthrlenState.offPitch or 0
_G.XthrlenState.offYaw   = _G.XthrlenState.offYaw   or 0

local function clampAngles(angles)
    if angles.Pitch > 180 then angles.Pitch = angles.Pitch - 360 end
    if angles.Pitch < -180 then angles.Pitch = angles.Pitch + 360 end

    if angles.Pitch < -75 then
        angles.Pitch = -75
    elseif angles.Pitch > 75 then
        angles.Pitch = 75
    end

    while angles.Yaw < -180 do angles.Yaw = angles.Yaw + 360 end
    while angles.Yaw > 180  do angles.Yaw = angles.Yaw - 360 end

    return angles
end

_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()
    if not (slua and slua.isValid and slua.isValid(player)) then return result end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()
    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    local ok,err=pcall(function()
        if not _G.XthrlenConfig.AimTouchEnable then return end
        
        local player = GameplayData.GetPlayerCharacter()
        if not (slua and slua.isValid and slua.isValid(player)) then return end
        
        local pc = player:GetPlayerControllerSafety()
        if not (slua and slua.isValid and slua.isValid(pc)) then return end
        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        -- Both supplied hip/scope modes require firing. Return before scanning,
        -- weapon classification, visibility checks or imports during idle play.
        if not isFiring then return end
        
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        
        if _G.LunarFeatures.Settings.MortarEnabled and weapon and weapon.MortarState==2 then return end
        local isShotgun = false
        local isSniper = false
        local isMortar = false
        local currentAmmo = 1
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") then
                isSniper = true
            end
            if wName:lower():find("mortar") or wName:lower():find("cối") then
                isMortar = true
            end
            
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        if _G.XthrlenState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.XthrlenState.IsAutoFiring = false
        end

        if isShotgun and currentAmmo <= 0 then return end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 100
        local fovVal = 30
        local maxDistMeters = 100
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        local predVal = 0 

        if isMortar and _G.XthrlenConfig.AimTouchMortar then
            local isPlaced = false
            pcall(function()
                if weapon and weapon.MortarState == 2 then isPlaced = true end
            end)
            if not isPlaced then return end

            cond = 2 
            prioMode = 1  
            boneIdx = 4 
            speedVal = 100 
            fovVal = _G.XthrlenState.CustomTextData.AimTouchMortarFOV or 360 
            maxDistMeters = 2000 
            useVisCheck = false 
            igKnock = false
            igBot = false
            predVal = _G.XthrlenState.CustomTextData.AimTouchMortarPred or 0 
            
        elseif isShotgun and _G.XthrlenConfig.AimTouchSG then
            cond = _G.XthrlenState.CustomTextData.AimTouchSGCond or 1
            if _G.XthrlenConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.XthrlenState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.XthrlenState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.XthrlenState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.XthrlenState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.XthrlenConfig.AimTouchSGVisCheck
            igKnock = _G.XthrlenConfig.AimTouchSGIgKnock
            igBot = _G.XthrlenConfig.AimTouchSGIgBot
            
        elseif isADS then
            if isSniper and _G.XthrlenConfig.AimTouchScopeSniper then
                cond = _G.XthrlenState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.XthrlenState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.XthrlenState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.XthrlenConfig.AimTouchSniperVisCheck
                igKnock = _G.XthrlenConfig.AimTouchSniperIgKnock
                igBot = _G.XthrlenConfig.AimTouchSniperIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchSniperPred or 0
            elseif _G.XthrlenConfig.AimTouchScopeAll then
                cond = _G.XthrlenState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchScopeSpeed or 100
                fovVal = _G.XthrlenState.CustomTextData.AimTouchScopeFOV or 30
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchScopeDist or 100
                useVisCheck = _G.XthrlenConfig.AimTouchScopeVisCheck
                igKnock = _G.XthrlenConfig.AimTouchScopeIgKnock
                igBot = _G.XthrlenConfig.AimTouchScopeIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchScopePred or 0
            else
                return
            end
        else
            if not _G.XthrlenConfig.AimTouchHipfire then return end
            cond = _G.XthrlenState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.XthrlenState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = 1
            speedVal = _G.XthrlenState.CustomTextData.AimTouchHipSpeed or 100
            fovVal = _G.XthrlenState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchHipDist or 100
            useVisCheck = _G.XthrlenConfig.AimTouchHipVisCheck
            igKnock = _G.XthrlenConfig.AimTouchHipIgKnock
            igBot = _G.XthrlenConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100 
        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end
        
        local FVector2D = AimV2
        local UGameplayStatics = AimGameplayStatics
        local KismetMathLibrary = AimMath
        if not FVector2D or not UGameplayStatics or not KismetMathLibrary then return end
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = AimUI
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999 
        
        local selected=_G.LunarFeatures.Settings.AimTarget
        boneIdx=selected==2 and 2 or (selected==3 and 5 or 1)
        local selBoneName=selected==2 and "spine_03" or (selected==3 and "calf_l" or "head")

        for i, target in ipairs(enemies) do
            repeat
            if not slua.isValid(target) then break end
            
            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)
            
            if igKnock and target.HealthStatus == 1 then break end
            
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then break end
            end
            
            if useVisCheck then
                local curTime = _G.LunarFeatures.Now()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or curTime < _G.AimTouchVisCache[tId].time or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then break end
            end
            
            local tPos = target.GetBonePos and target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 70
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20
                        elseif boneIdx == 5 then tPos.Z = tPos.Z - 60 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then break end
            
            local screen = FVector2D()
            local success,outScreen = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if outScreen then screen=outScreen end
            if not success or screen.X <= 0 or screen.Y <= 0 then break end
            
            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            
            if distScreen > FOV_RADIUS then break end
            
            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end
            
            until true
        end
        
        local cache=_G.AimTouchVisCache
        local clock=_G.LunarFeatures.Now()
        if cache and (not _G.LunarFeatures.AimPruneDue or clock>=_G.LunarFeatures.AimPruneDue) then
            for key,entry in pairs(cache) do if clock<entry.time or clock-entry.time>1 then cache[key]=nil end end
            _G.LunarFeatures.AimPruneDue=clock+0.5
        end
        if not slua.isValid(bestTarget) then return end
        
        local finalBonePos = bestTarget.GetBonePos and bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20
                    elseif boneIdx == 5 then finalBonePos.Z = finalBonePos.Z - 60 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end
        
        local tVelocity = nil
        pcall(function()
            if type(bestTarget.GetVelocity) == "function" then
                tVelocity = bestTarget:GetVelocity()
            end
        end)

        if not isMortar and predVal > 0 then
            pcall(function()
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0) 
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        if isADS and isFiring then
            local dist = player:GetDistanceTo(bestTarget) / 100.0
            finalBonePos.Z = finalBonePos.Z - (dist * 1.1)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end

        if not isADS then
            _G.XthrlenState.offPitch = 0
            _G.XthrlenState.offYaw   = 0
        end

        local dPitch = rot.Pitch - currentRot.Pitch
        local dYaw   = rot.Yaw   - currentRot.Yaw

        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                dYaw   = dYaw   - (camRot.Yaw   - currentRot.Yaw)
                dPitch = dPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if dPitch~=dPitch or dYaw~=dYaw or math.abs(dPitch)==math.huge or math.abs(dYaw)==math.huge then return end
        dPitch=(dPitch+180)%360-180
        dYaw=(dYaw+180)%360-180

        -- Displayed settings remain 100..120. The requested maximum applies
        -- at most half the previous full correction; low settings are gentler.
        local now=_G.LunarFeatures.Now()
        local previous=_G.LunarFeatures.AimLastClock
        local dt=previous and math.max(0.001,math.min(0.05,now-previous)) or 0.011
        _G.LunarFeatures.AimLastClock=now
        local normalized=(_G.LunarFeatures.Clamp(speedVal,100,120,100)-100)/20.0
        local strength=0.02+0.48*normalized*normalized
        local alpha=math.min(0.5,1.0-(1.0-strength)^(dt/0.011))
        local maxTurnRate=10.0+35.0*normalized

        -- Camera-relative ADS error already accounts for view/controller offset.
        -- Repeatedly accumulating target error causes windup and unwanted swipes.
        _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0
        local apply={Pitch=currentRot.Pitch+dPitch,Yaw=currentRot.Yaw+dYaw,Roll=0}

        local pitchDelta=(apply.Pitch-currentRot.Pitch+180)%360-180
        local yawDelta=(apply.Yaw-currentRot.Yaw+180)%360-180
        local pitchStep,yawStep=pitchDelta*alpha,yawDelta*alpha
        local stepLength=math.sqrt(pitchStep*pitchStep+yawStep*yawStep)
        local stepLimit=maxTurnRate*dt
        if stepLength>stepLimit then
            local scale=stepLimit/stepLength
            pitchStep=pitchStep*scale;yawStep=yawStep*scale
        end
        local out={Pitch=currentRot.Pitch+pitchStep,Yaw=currentRot.Yaw+yawStep,Roll=0}

        out = clampAngles(out)
        pc:SetControlRotation(out, "AimTouch")
    end)
    if not ok then _G.LunarFeatures.Error("Aim",err) end
end



_G.LunarFeatures.Aim={Tick=_G.AimTouch}
end

-- Preserve the reference's DrawDyeing/Highlight/IdeaOutline settings and cadence.
-- Deduplicate mesh identities; do not assume the game leaves material flags alone.
do
    local F=_G.LunarFeatures
    local valid=g_masterahsanyt_ESPValid
    local classes={}
    for _,name in ipairs({"SkeletalMeshComponent","StaticMeshComponent"}) do
        local ok,value=pcall(import,name)
        if ok and value then classes[#classes+1]=value end
    end
    local W={Meshes={},Pawns={},LastTick=-999,LastCleanup=-999,CleanupInterval=1/60,ConsoleWorld=nil,Applied=0}
    F.Wall=W
    local properties={
        {"SetDrawDyeing","bDrawDyeing"},{"SetDrawHighlight","bDrawHighlight"},
        {"SetDrawIdeaOutline","bDrawIdeaOutline"},{"SetRenderCustomDepth","bRenderCustomDepth"}
    }
    local function calls(vis,occ)
        return {
            {"SetDrawDyeing",true},{"SetDrawDyeingMode",1},{"SetVisibleDyeingColor",vis},{"SetOccludedDyeingColor",occ},
            {"SetDyeingColorFadeDistance",99999.0},{"SetDyeingColorMinMaxDistance",0.0,99999.0},
            {"SetDrawHighlight",true},{"OverrideHighlightColor",vis},{"SetHighlightCanBeOccluded",false},
            {"SetDrawIdeaOutline",true},{"SetIdeaOutlineNew",true},{"SetIdeaOutlineOcclusionHighlight",true},
            {"OverrideIdeaOutlineColor",vis},{"SetIdeaOutlineOcclusionColor",occ},{"OverrideIdeaOutlineThickness",20.0},
            {"SetIdeaOverrideOutlineAndOcclusion",true},{"SetRenderCustomDepth",true},{"SetCustomDepthStencilValue",255}
        }
    end
    -- Wall shader colors retain the working intensity 100 and alpha 100.
    -- Slot 6 uses the supplied saffron RGB (100,1,0); slot 7 is red.
    local palette={{100,0,35},{100,100,100},{0,100,100},{0,100,0},
        {100,100,0},{100,1,0},{100,0,0}}
    W.Palette=palette
    local colorCalls
    W.UpdateColors=function()
        local a=palette[F.Settings.WallVisible] or palette[1]
        local b=palette[F.Settings.WallOccluded] or palette[2]
        local vis=g_masterahsanyt_ESPColor(a[1],a[2],a[3],100)
        local occ=g_masterahsanyt_ESPColor(b[1],b[2],b[3],100)
        colorCalls=calls(vis,occ)
        W.LastTick=-999
    end
    W.UpdateColors()
    local function invoke(mesh,call)
        local method=mesh[call[1]]
        if not method then return end
        if call[3]~=nil then method(mesh,call[2],call[3]) else method(mesh,call[2]) end
    end
    local function restore(mesh,state)
        if not valid(mesh) then return end
        for _,pair in ipairs(properties) do
            pcall(function() if mesh[pair[1]] then mesh[pair[1]](mesh,state[pair[2]]==true) end end)
        end
    end
    W.Stop=function()
        for mesh,state in pairs(W.Meshes) do restore(mesh,state) end
        W.Meshes={};W.Pawns={}
        W.LastTick=-999;W.LastCleanup=-999
    end
    local function relevant(pawn,myLocation,maxRange,pc)
        local entry=ESPShared.GetFrameRecord(pawn)
        return entry.Alive and ESPShared.InRange(entry,myLocation,maxRange)
            and pc and ESPShared.ProbeActor(pc,pawn).OnScreen
    end
    W.Cleanup=function(myLocation,maxRange,pc)
        for pawn,meshes in pairs(W.Pawns) do
            if not relevant(pawn,myLocation,maxRange,pc) then
                for mesh in pairs(meshes) do
                    local state=W.Meshes[mesh]
                    if state then restore(mesh,state);W.Meshes[mesh]=nil end
                end
                W.Pawns[pawn]=nil
            end
        end
    end
    local function apply(mesh,pawn,seen)
        if not valid(mesh) or seen[mesh] then return end
        seen[mesh]=true
        local original=W.Meshes[mesh]
        if not original then
            original={}
            for _,pair in ipairs(properties) do pcall(function() original[pair[2]]=mesh[pair[2]]==true end) end
            W.Meshes[mesh]=original
        end
        if original.Pawn and original.Pawn~=pawn then
            local old=W.Pawns[original.Pawn]
            if old then old[mesh]=nil;if next(old)==nil then W.Pawns[original.Pawn]=nil end end
        end
        original.Pawn=pawn
        local owned=W.Pawns[pawn]
        if not owned then owned={};W.Pawns[pawn]=owned end
        owned[mesh]=true
        -- Each protected setter is attempted independently. An unavailable optional
        -- extension does not prevent other reference rendering modes from applying.
        for _,call in ipairs(colorCalls) do
            local ok,err=pcall(invoke,mesh,call)
            if not ok then F.Error("Wall."..call[1],err) end
        end
        W.Applied=W.Applied+1
    end
    W.Tick=function(now,me,pc)
        if not F.Settings.WallEnabled then return end
        now=now or F.Now()
        me=me or g_masterahsanyt_ESPGetLocalCharacter()
        pc=pc or g_masterahsanyt_ESPGetController()
        if not valid(me) or not valid(pc) then W.Stop() return end
        local maxRange=tonumber(_G.g_masterahsanyt_MasterShotESP.MaxRangeMeters) or 450.0
        if maxRange~=maxRange or maxRange<=0 or maxRange==math.huge then maxRange=450.0 end
        local myLocation=ESPShared.GetFrameRecord(me).Location
        if now<W.LastCleanup or now-W.LastCleanup>=W.CleanupInterval-0.000001 then
            W.Cleanup(myLocation,maxRange,pc);W.LastCleanup=now
        end
        if now>=W.LastTick and now-W.LastTick<0.30-0.000001 then return end
        W.LastTick=now
        local world=g_masterahsanyt_ESPWorld()
        if world~=W.ConsoleWorld then
            local ok=pcall(function()
                if not world or not UKismetSystemLibrary.ExecuteConsoleCommand then return end
                for _,command in ipairs({"r.EnableDrawDyeingColor 1","r.CustomDepth 3","r.IdeaOutline.Enable 1","r.Highlight.Enable 1"}) do
                    UKismetSystemLibrary.ExecuteConsoleCommand(world,command)
                end
            end)
            if ok and world then W.ConsoleWorld=world end
        end
        local pawns=ESPShared.GetFramePawns()
        if not pawns then return end
        local seen={}
        local myTeam=me.TeamID or 0
        for _,pawn in pairs(pawns) do
            if valid(pawn) and pawn~=me and pawn.TeamID~=myTeam and relevant(pawn,myLocation,maxRange,pc) then
                pcall(function() apply(pawn.Mesh,pawn,seen) end)
                local avatar=nil
                pcall(function()
                    avatar=pawn.CharacterAvatarComp2_BP
                    if not avatar and pawn.getAvatarComponent2 then avatar=pawn:getAvatarComponent2() end
                end)
                if avatar and avatar.GetMeshCompBySlot then
                    for slot=0,7 do pcall(function() apply(avatar:GetMeshCompBySlot(slot),pawn,seen) end) end
                end
                for _,class in ipairs(classes) do
                    pcall(function()
                        if not pawn.GetComponentsByClass then return end
                        local components=pawn:GetComponentsByClass(class)
                        if components then for i=0,components:Num()-1 do apply(components:Get(i),pawn,seen) end end
                    end)
                end
                pcall(function()
                    local weapon=pawn.GetCurrentWeapon and pawn:GetCurrentWeapon()
                    if valid(weapon) then apply(weapon.Mesh,pawn,seen) end
                end)
            end
        end
        for mesh,state in pairs(W.Meshes) do
            if not seen[mesh] then
                restore(mesh,state);W.Meshes[mesh]=nil
                local owned=W.Pawns[state.Pawn]
                if owned then owned[mesh]=nil;if next(owned)==nil then W.Pawns[state.Pawn]=nil end end
            end
        end
    end
    _G.StartWallhack=function() F.SetWall(true) end
    _G.StopWallhack=function() F.SetWall(false) end
end

do
_G.g_Botmater_ESPOptions = _G.g_Botmater_ESPOptions or {
    Name = false,
    Line = false,
    Health = false,
    Distance = false,
    EnemyCounter = false,
}

_G.g_Botmater_MasterShotESP = _G.g_Botmater_MasterShotESP or {
    Enabled = true,
    MaxRangeMeters = 300.0,
    ScanInterval = 0.05,
    UpdateInterval = 1/60,
    TransformInterval = 0.033,
    MaxRendered = 10,
    TracerThickness = 1.0,
    NameGap = 2.0,
    NameFontSize = 9,
    DistanceFontSize = 10,
    DistanceBelowFeet = 14,
}
-- ESP V1 settings remain independent from _G.MasterShotESP (ESP V2).

local g_Botmater_ShotESP = {
    Canvas = nil,
    Enemies = {},
    Lines = {},
    Names = {},
    LastScanClock = -999.0,
    LastTransformClock = -999.0,
    LastWorld = nil,
    CanvasScaleX = 1.0,
    CanvasScaleY = 1.0,
    CanvasOffsetX = 0.0,
    CanvasOffsetY = 0.0,
    LastPawn=nil,
    LastController=nil,
    Active={},
    Alive={},
    LastProjected={},
    RealCount = 0,
    BotCount = 0,
}

local V2 = _G.FVector2D
if not V2 then pcall(function() V2 = import("Vector2D") end) end
local LinearColor = _G.FLinearColor
if not LinearColor then pcall(function() LinearColor = import("LinearColor") end) end
local SlateBlueprintLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
local WidgetLayoutLibrary = nil
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)

local function g_Botmater_ESPV2(x, y)
    if V2 then return V2(x, y) end
    return {X = x, Y = y}
end

local function g_Botmater_ESPColor(r, g, b, a)
    if LinearColor then return LinearColor(r, g, b, a or 1.0) end
    return {R=r, G=g, B=b, A=a or 1.0}
end

local COLOR_REAL_VIS_RED          = g_Botmater_ESPColor(1.00, 0.00, 0.00, 1.00)
local COLOR_BOT_VIS_CYAN          = g_Botmater_ESPColor(0.10, 1.00, 1.00, 1.00)

local COLOR_TEXT_WHITE            = g_Botmater_ESPColor(1.00, 1.00, 1.00, 1.00)
local COLOR_TEXT_BLACK            = g_Botmater_ESPColor(0.00, 0.00, 0.00, 1.00)


local CACHE_COUNTER_PLAYER_BG   = g_Botmater_ESPColor(0.07, 0.008, 0.008, 1.0)
local CACHE_COUNTER_BOT_BG      = g_Botmater_ESPColor(0.008, 0.07, 0.07, 1.0)
local CACHE_COUNTER_PLAYER_TEXT = g_Botmater_ESPColor(1.0,0.86,0.84,1.0)
local CACHE_COUNTER_BOT_TEXT    = g_Botmater_ESPColor(0.82,1.0,1.0,1.0)


local COLOR_HP = {
    RealText=g_Botmater_ESPColor(1.0,0.86,0.84,1.0),
    BotText=g_Botmater_ESPColor(0.82,1.0,1.0,1.0),
    RealMid=g_Botmater_ESPColor(0.78,0.0,0.0,1.0),
    RealLow=g_Botmater_ESPColor(0.55,0.0,0.0,1.0),
    BotMid=g_Botmater_ESPColor(0.075,0.75,0.75,1.0),
    BotLow=g_Botmater_ESPColor(0.055,0.55,0.55,1.0),
    RealBG=g_Botmater_ESPColor(0.06,0.005,0.005,0.75),
    BotBG=g_Botmater_ESPColor(0.005,0.06,0.06,0.75)}

-- Ensure old in-memory options do not retain the tiny shipped label fonts.
_G.g_Botmater_MasterShotESP.NameFontSize=math.max(12,tonumber(_G.g_Botmater_MasterShotESP.NameFontSize) or 12)
_G.g_Botmater_MasterShotESP.DistanceFontSize=math.max(12,tonumber(_G.g_Botmater_MasterShotESP.DistanceFontSize) or 12)

local function g_Botmater_ESPGetColors(isBot)
    if isBot then
        return COLOR_BOT_VIS_CYAN, COLOR_HP.BotText
    else
        return COLOR_REAL_VIS_RED, COLOR_HP.RealText
    end
end

local function g_Botmater_ESPValid(obj)
    if not obj then return false end
    local ok, valid = pcall(function() return slua.isValid(obj) end)
    return ok and valid == true
end

local function g_Botmater_ESPNow() return _G.LunarFeatures.Now() end

local function g_Botmater_ESPWorld()
    local w = nil
    pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
    return w
end

local function g_Botmater_ESPGetController() return g_masterahsanyt_ESPGetController() end
local function g_Botmater_ESPGetLocalCharacter() return g_masterahsanyt_ESPGetLocalCharacter() end

local function g_Botmater_ESPGetPlayerState(character)
    if not g_Botmater_ESPValid(character) then return nil end
    local ps = nil
    pcall(function()
        if character.GetPlayerStateSafety then ps = character:GetPlayerStateSafety() end
    end)
    if not g_Botmater_ESPValid(ps) then
        pcall(function() if character.GetPlayerState then ps = character:GetPlayerState() end end)
    end
    if not g_Botmater_ESPValid(ps) then
        pcall(function() ps = character.PlayerState end)
    end
    return g_Botmater_ESPValid(ps) and ps or nil
end

local function g_Botmater_ESPNormalizeName(value)
    if value == nil or value == false then return nil end
    local ok, text = pcall(tostring, value)
    if not ok or not text then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == "nil" or text == "None" or text == "NULL" then return nil end
    return text
end

local function g_Botmater_ESPResolvePlayerName(character)
    if not g_Botmater_ESPValid(character) then return nil end
    local name = nil
    local function take(value)
        if not name then name = g_Botmater_ESPNormalizeName(value) end
    end
    pcall(function() if character.GetPlayerNameSafety then take(character:GetPlayerNameSafety()) end end)
    pcall(function() if not name and character.GetPlayerName then take(character:GetPlayerName()) end end)
    pcall(function() if not name then take(character.PlayerName) end end)
    pcall(function() if not name then take(character.NickName) end end)
    if not name then
        local ps = g_Botmater_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
            pcall(function() if not name then take(ps.PlayerName) end end)
            pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
            pcall(function() if not name then take(ps.NickName) end end)
        end
    end
    return name
end

local function g_Botmater_ESPGetPlayerKey(c) return g_masterahsanyt_ESPGetPlayerKey(c) end

local function g_Botmater_ESPGetTeamID(character)
    if not g_Botmater_ESPValid(character) then return nil end
    local id = nil
    pcall(function() if character.GetTeamID then id = character:GetTeamID() end end)
    if id == nil then pcall(function() id = character.TeamID end) end
    if id == nil then
        local ps = g_Botmater_ESPGetPlayerState(character)
        if ps then
            pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
            if id == nil then pcall(function() id = ps.TeamID end) end
        end
    end
    return id
end

local function g_Botmater_ESPGetHealthPct(character)
    if not g_Botmater_ESPValid(character) then return 1.0 end
    local hp, maxHp = nil, nil
    pcall(function() hp = character.Health end)
    if type(hp) ~= "number" then pcall(function() hp = character.HP end) end
    pcall(function() maxHp = character.MaxHealth end)
    if type(maxHp) ~= "number" then pcall(function() maxHp = character.MaxHP end) end
    if not ESPShared.Finite(hp) then return 1.0 end
    if not ESPShared.Finite(maxHp) or maxHp <= 0 then maxHp = 100 end
    local pct = hp / maxHp
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end
    return pct
end

local function g_Botmater_ESPGetHealthColor(pct,isBot)
    pct = tonumber(pct) or 1.0
    if pct >= 0.75 then return isBot and COLOR_BOT_VIS_CYAN or COLOR_REAL_VIS_RED
    elseif pct >= 0.50 then return isBot and COLOR_HP.BotMid or COLOR_HP.RealMid
    else return isBot and COLOR_HP.BotLow or COLOR_HP.RealLow end
end

local function g_Botmater_ESPIsBot(c)
    g_Botmater_ShotESP._BotCache=g_Botmater_ShotESP._BotCache or {}
    return g_masterahsanyt_ESPIsBot(c,g_masterahsanyt_ESPGetPlayerKey(c),g_Botmater_ShotESP._BotCache,_G.LunarFeatures.Now())
end

-- Deferred cleanup owns widgets only, never an actor, key or player name.
-- Admission is stopped well below the hard limit while native cleanup fails.
local V1Cleanup={Items={},Members={},Count=0,Cursor=1,Due=0,Limit=512,AdmissionLimit=128}
function V1Cleanup.Try(widget)
    if not g_Botmater_ESPValid(widget) then return true end
    local hidden,accepted=pcall(function() return widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    if not hidden or accepted==false then pcall(function() widget:SetRenderOpacity(0) end) end
    local ok,result=pcall(function() return widget:RemoveFromParent() end)
    if not ok or result==false then return false end
    local checked,parent=pcall(function() return widget:GetParent() end)
    return not checked or parent==nil
end
function V1Cleanup.Retire(widget)
    if not widget then return true end
    if V1Cleanup.Members[widget] then return true end
    if V1Cleanup.Try(widget) then return true end
    if V1Cleanup.Count>=V1Cleanup.Limit then return false end
    V1Cleanup.Count=V1Cleanup.Count+1
    V1Cleanup.Items[V1Cleanup.Count]=widget
    V1Cleanup.Members[widget]=true
    return true
end
function V1Cleanup.Pump(now)
    if V1Cleanup.Count==0 then return end
    if now>=V1Cleanup.Due-0.05 and now<V1Cleanup.Due then return end
    V1Cleanup.Due=now+0.05
    local budget=math.min(8,V1Cleanup.Count)
    while budget>0 and V1Cleanup.Count>0 do
        budget=budget-1
        local i=V1Cleanup.Cursor
        if i>V1Cleanup.Count then i=1 end
        local widget=V1Cleanup.Items[i]
        if V1Cleanup.Try(widget) then
            V1Cleanup.Members[widget]=nil
            V1Cleanup.Items[i]=V1Cleanup.Items[V1Cleanup.Count]
            V1Cleanup.Items[V1Cleanup.Count]=nil
            V1Cleanup.Count=V1Cleanup.Count-1
            V1Cleanup.Cursor=i
        else
            V1Cleanup.Cursor=i+1
        end
    end
end
ESPWidgetPool.V1.Remove=V1Cleanup.Retire

local function g_Botmater_ESPDestroyWidgetData(data)
    if not data then return true end
    if ESPWidgetPool.Release(data) then return true end
    return V1Cleanup.Retire(data.Widget or data.Container)
end

local function g_Botmater_ESPResetWidgets()
    ESPShared.Frame.V1CanvasChecked=false
    ESPWidgetPool.V1.Enabled=false
    for _,registry in ipairs({g_Botmater_ShotESP.Lines,g_Botmater_ShotESP.Names}) do
        for key,data in pairs(registry) do
            if g_Botmater_ESPDestroyWidgetData(data) then registry[key]=nil end
        end
    end
    g_Botmater_ShotESP.Canvas=nil
    g_Botmater_ShotESP.RootUI=nil
    g_Botmater_ShotESP.Enemies={}
    g_Botmater_ShotESP._BotCache={}
    g_Botmater_ShotESP.Active={}
    g_Botmater_ShotESP.Alive={}
    g_Botmater_ShotESP.LastProjected={}
    g_Botmater_ShotESP.RealCount=0;g_Botmater_ShotESP.BotCount=0
    g_Botmater_ShotESP.LastScanClock=-999
    g_Botmater_ShotESP.LastTransformClock=-999
    g_Botmater_ShotESP.LastPawn=nil;g_Botmater_ShotESP.LastController=nil
    g_Botmater_ShotESP.CanvasScaleX=1;g_Botmater_ShotESP.CanvasScaleY=1
    g_Botmater_ShotESP.CanvasOffsetX=0;g_Botmater_ShotESP.CanvasOffsetY=0
    g_Botmater_ShotESP.TransformReady=false
    g_Botmater_ShotESP.TransformW=nil;g_Botmater_ShotESP.TransformH=nil
    ESPWidgetPool.Flush(ESPWidgetPool.V1)
    ESPWidgetPool.V1.Enabled=true
end

local function g_Botmater_ESPGetCanvas()
    -- Compare the current HUD identity; native validity alone does not mean
    -- that a retained canvas still belongs to the visible HUD.
    local frame=ESPShared.Frame
    if frame.Active and frame.V1CanvasChecked then
        return g_Botmater_ESPValid(g_Botmater_ShotESP.Canvas) and g_Botmater_ShotESP.Canvas or nil
    end
    local root
    pcall(function()
        local ui=require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if ui and ui.GetMainControlBaseUI then root=ui.GetMainControlBaseUI() end
    end)
    if not g_Botmater_ESPValid(root) then
        if g_Botmater_ShotESP.Canvas then g_Botmater_ESPResetWidgets() end
        return nil
    end
    local canvas
    pcall(function()
        if g_Botmater_ESPValid(root.CanvasPanel_0) then canvas=root.CanvasPanel_0
        elseif g_Botmater_ESPValid(root.CanvasPanel_42) then canvas=root.CanvasPanel_42 end
    end)
    if not g_Botmater_ESPValid(canvas) then
        if g_Botmater_ShotESP.Canvas then g_Botmater_ESPResetWidgets() end
        return nil
    end
    if g_Botmater_ShotESP.Canvas~=canvas or g_Botmater_ShotESP.RootUI~=root then
        g_Botmater_ESPResetWidgets()
        g_Botmater_ShotESP.Canvas=canvas;g_Botmater_ShotESP.RootUI=root
    end
    if frame.Active then frame.V1CanvasChecked=true end
    return canvas
end

local function g_Botmater_ESPViewport(pc) return g_masterahsanyt_ESPViewport(pc) end

local function g_Botmater_ESPGetCanvasLocalSize()
    local canvas = g_Botmater_ESPGetCanvas()
    if not g_Botmater_ESPValid(canvas) then return nil, nil end
    local cw, ch = nil, nil
    pcall(function()
        local geo = canvas:GetCachedGeometry()
        if not geo then return end
        local size = nil
        if geo.GetLocalSize then size = geo:GetLocalSize()
        elseif SlateBlueprintLibrary and SlateBlueprintLibrary.GetLocalSize then size = SlateBlueprintLibrary.GetLocalSize(geo) end
        if size and ESPShared.Finite(size.X) and ESPShared.Finite(size.Y) and size.X > 1 and size.Y > 1 then
            cw, ch = tonumber(size.X), tonumber(size.Y)
        end
    end)
    return cw, ch
end

local function g_Botmater_ESPUpdateCanvasTransform(pc)
    local state=g_Botmater_ShotESP
    local canvas=g_Botmater_ESPGetCanvas()
    if not g_Botmater_ESPValid(canvas) then return false end
    local width,height=ESPShared.ViewSize(pc)
    local sameViewport=state.TransformW==width and state.TransformH==height
    local calibrated=false
    pcall(function()
        local geo=canvas:GetCachedGeometry()
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal and geo then
            local p0=SlateBlueprintLibrary.AbsoluteToLocal(geo,g_Botmater_ESPV2(0,0))
            local p1=SlateBlueprintLibrary.AbsoluteToLocal(geo,g_Botmater_ESPV2(100,100))
            if p0 and p1 and ESPShared.Finite(p0.X) and ESPShared.Finite(p0.Y)
                and ESPShared.Finite(p1.X) and ESPShared.Finite(p1.Y)
                and math.abs(p0.X)<1e7 and math.abs(p0.Y)<1e7
                and p1.X>p0.X and p1.Y>p0.Y
                and p1.X-p0.X<10000 and p1.Y-p0.Y<10000 then
                state.CanvasScaleX=(p1.X-p0.X)/100
                state.CanvasScaleY=(p1.Y-p0.Y)/100
                state.CanvasOffsetX=p0.X;state.CanvasOffsetY=p0.Y
                calibrated=true
            end
        end
    end)
    -- A transient missing geometry sample must not toggle coordinate systems.
    if not calibrated and state.TransformReady and sameViewport then return true end
    if not calibrated then
        local scale=1
        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                local s=WidgetLayoutLibrary.GetViewportScale(pc)
                if ESPShared.Finite(s) and s>=0.01 and s<=100 then scale=s end
            end
        end)
        state.CanvasScaleX=1/scale;state.CanvasScaleY=1/scale
        state.CanvasOffsetX=0;state.CanvasOffsetY=0
    end
    state.TransformReady=true;state.TransformW=width;state.TransformH=height
    return true
end

local function g_Botmater_ESPSetFont(widget,size) g_masterahsanyt_ESPSetFont(widget,size,0) end
local function g_Botmater_ESPSetTextColor(widget,color) g_masterahsanyt_ESPSetTextColor(widget,color) end

local function g_Botmater_ESPCreateLine(color)
    if V1Cleanup.Count>=V1Cleanup.AdmissionLimit then return nil end
    local canvas = g_Botmater_ESPGetCanvas()
    if not g_Botmater_ESPValid(canvas) then return nil end
    local pooled=true and ESPWidgetPool.Take(ESPWidgetPool.V1,"Line",canvas)
    if pooled then
        local ok=pcall(function() pooled.Widget:SetBrushColor(color) end)
        if ok then pooled.Visible=false;return pooled end
        V1Cleanup.Retire(pooled.Widget)
    end
    local border = nil
    pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
    if not g_Botmater_ESPValid(border) then return nil end
    pcall(function()
        border:SetBrushColor(color)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        border:SetRenderTransformPivot(g_Botmater_ESPV2(0.0, 0.5))
    end)
    local slot = nil
    pcall(function() slot = canvas:AddChildToCanvas(border) end)
    if not slot then g_Botmater_ESPDestroyWidgetData({Widget=border}) return nil end
    pcall(function() slot:SetAutoSize(false) slot:SetZOrder(30) end)
    local data={Widget=border, Slot=slot, Visible=true}
    if true then ESPWidgetPool.Tag(ESPWidgetPool.V1,"Line",canvas,data) end
    return data
end

local function g_Botmater_ESPDrawLine(...) return g_masterahsanyt_ESPDrawLine(...) end

local function g_Botmater_ESPHide(data)
    if data and g_Botmater_ESPValid(data.Widget) then
        if data.Visible ~= false then
            pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            data.Visible = false
        end
    end
end

local function g_Botmater_ESPCreateNameTag(isBot)
    if V1Cleanup.Count>=V1Cleanup.AdmissionLimit then return nil end
    local canvas = g_Botmater_ESPGetCanvas()
    if not g_Botmater_ESPValid(canvas) then return nil end
    local pooled=ESPWidgetPool.Take(ESPWidgetPool.V1,"NameV1",canvas)
    if pooled then
        local mainColor,textColor=g_Botmater_ESPGetColors(isBot)
        local ok=pcall(function()
            pooled.BottomLine:SetBrushColor(mainColor)
            pooled.BottomLine:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            pooled.HealthBg:SetBrushColor(isBot and COLOR_HP.BotBG or COLOR_HP.RealBG)
            pooled.HealthFill:SetBrushColor(mainColor)
        end)
        if not ok then V1Cleanup.Retire(pooled.Widget);pooled=nil end
        if pooled then
            g_Botmater_ESPSetTextColor(pooled.Text,textColor)
            g_Botmater_ESPSetTextColor(pooled.DistanceText,textColor)
            g_Botmater_ESPSetFont(pooled.Text,tonumber(_G.g_Botmater_MasterShotESP.NameFontSize) or 9)
            g_Botmater_ESPSetFont(pooled.DistanceText,tonumber(_G.g_Botmater_MasterShotESP.DistanceFontSize) or 10)
            pooled.IsBot=isBot;pooled.Visible=false;pooled.LastHealthPct=-1
        end
        if pooled then return pooled end
    end

    local container = nil
    pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not g_Botmater_ESPValid(container) then return nil end

    local bottomLine = nil
    pcall(function() bottomLine = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)
    local nameText = nil
    pcall(function() nameText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    local distanceText = nil
    pcall(function() distanceText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)

    local healthBarBg = nil
    pcall(function() healthBarBg = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)
    local healthBarFill = nil
    pcall(function() healthBarFill = CGame:NewObjectFromPath("/Script/UMG.Border", container) end)

    if not g_Botmater_ESPValid(bottomLine)
        or not g_Botmater_ESPValid(nameText)
        or not g_Botmater_ESPValid(distanceText)
        or not g_Botmater_ESPValid(healthBarBg)
        or not g_Botmater_ESPValid(healthBarFill) then
        g_Botmater_ESPDestroyWidgetData({Widget=container})
        return nil
    end

    local mainColor,textColor=g_Botmater_ESPGetColors(isBot)
    local background=isBot and COLOR_HP.BotBG or COLOR_HP.RealBG

    pcall(function()
        bottomLine:SetBrushColor(mainColor)
        bottomLine:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        nameText:SetText("")
        distanceText:SetText("")
        nameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        distanceText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        if nameText.SetJustification then nameText:SetJustification(1) end
        if distanceText.SetJustification then distanceText:SetJustification(1) end
        healthBarBg:SetBrushColor(background)
        healthBarBg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        healthBarFill:SetBrushColor(mainColor)
        healthBarFill:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)

    g_Botmater_ESPSetTextColor(nameText, textColor)
    g_Botmater_ESPSetTextColor(distanceText, textColor)
    g_Botmater_ESPSetFont(nameText, tonumber(_G.g_Botmater_MasterShotESP.NameFontSize) or 9)
    g_Botmater_ESPSetFont(distanceText, tonumber(_G.g_Botmater_MasterShotESP.DistanceFontSize) or 10)

    local lineSlot, nameSlot, distanceSlot, mainSlot = nil, nil, nil, nil
    local healthBgSlot, healthFillSlot = nil, nil
    pcall(function() lineSlot = container:AddChildToCanvas(bottomLine) end)
    pcall(function() healthBgSlot = container:AddChildToCanvas(healthBarBg) end)
    pcall(function() healthFillSlot = container:AddChildToCanvas(healthBarFill) end)
    pcall(function() nameSlot = container:AddChildToCanvas(nameText) end)
    pcall(function() distanceSlot = container:AddChildToCanvas(distanceText) end)
    pcall(function() mainSlot = canvas:AddChildToCanvas(container) end)

    if not lineSlot or not nameSlot or not distanceSlot or not mainSlot or not healthBgSlot or not healthFillSlot then
        g_Botmater_ESPDestroyWidgetData({Widget=container})
        return nil
    end

    pcall(function()
        lineSlot:SetAutoSize(false) lineSlot:SetAlignment(g_Botmater_ESPV2(0.0, 0.0)) lineSlot:SetZOrder(1)
        healthBgSlot:SetAutoSize(false) healthBgSlot:SetAlignment(g_Botmater_ESPV2(0.0, 0.0)) healthBgSlot:SetZOrder(1)
        healthFillSlot:SetAutoSize(false) healthFillSlot:SetAlignment(g_Botmater_ESPV2(0.0, 0.0)) healthFillSlot:SetZOrder(2)
        nameSlot:SetAutoSize(true) nameSlot:SetAlignment(g_Botmater_ESPV2(0.5, 0.5)) nameSlot:SetZOrder(3)
        distanceSlot:SetAutoSize(true) distanceSlot:SetAlignment(g_Botmater_ESPV2(0.5, 0.5)) distanceSlot:SetZOrder(3)
        mainSlot:SetAutoSize(false) mainSlot:SetZOrder(35)
    end)

    local data={
        Widget       = container,
        BottomLine   = bottomLine,
        HealthBg     = healthBarBg,
        HealthFill   = healthBarFill,
        Text         = nameText,
        DistanceText = distanceText,
        LineSlot     = lineSlot,
        HealthBgSlot = healthBgSlot,
        HealthFillSlot = healthFillSlot,
        TextSlot     = nameSlot,
        DistanceSlot = distanceSlot,
        Slot         = mainSlot,
        IsBot        = isBot,
        Visible      = true,
        LastDistValue = nil,
        LastDistLabel = nil,
        LastHealthPct = -1,
    }
    return ESPWidgetPool.Tag(ESPWidgetPool.V1,"NameV1",canvas,data)
end

local function g_Botmater_ESPUpdateNameTag(key, character, headScreen, footScreen, isBot, distance, healthPct, pc)
    local showName     = _G.g_Botmater_ESPOptions.Name == true
    local showDistance = _G.g_Botmater_ESPOptions.Distance == true
    local showHealth = _G.g_Botmater_ESPOptions.Health == true

    local data = g_Botmater_ShotESP.Names[key]
    if not showName and not showDistance and not showHealth then
        if data and g_Botmater_ESPValid(data.Widget) then
            if data.Visible ~= false then
                pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                data.Visible = false
            end
        end
        return
    end

    if data and data.IsBot~=isBot then data.CachedName=nil end
    local name = nil
    if not showName then
        name=""
    elseif isBot then
        name = "BOT"
    else
        name = data and data.CachedName or nil
        if not name then
            name = g_Botmater_ESPResolvePlayerName(character)
            if data and name then data.CachedName = name end
        end
        if not name then name = showName and "UNKNOWN" or "" end
    end

    headScreen=headScreen or footScreen
    if not headScreen then
        if data and g_Botmater_ESPValid(data.Widget) then
            if data.Visible ~= false then
                pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                data.Visible = false
            end
        end
        return
    end

    if not data or not g_Botmater_ESPValid(data.Widget) then
        g_Botmater_ESPDestroyWidgetData(data)
        data = g_Botmater_ESPCreateNameTag(isBot)
        g_Botmater_ShotESP.Names[key] = data
        if data then data.CachedName = name end
    end
    if not data then return end

    if data.IsBot ~= isBot then
        local mainColor,textColor=g_Botmater_ESPGetColors(isBot)
        g_Botmater_ESPSetTextColor(data.Text,textColor)
        g_Botmater_ESPSetTextColor(data.DistanceText,textColor)
        local ok=pcall(function()
            data.BottomLine:SetBrushColor(mainColor)
            data.HealthBg:SetBrushColor(isBot and COLOR_HP.BotBG or COLOR_HP.RealBG)
        end)
        if ok then data.IsBot=isBot;data.LastHealthPct=nil end
    end

    local dist=math.floor(ESPShared.SafeNumber(distance,0,0,1e8)+0.5)
    local distanceLabel
    if data.LastDistValue ~= dist then
        distanceLabel = string.format("%d m", dist)
        data.LastDistValue = dist
        data.LastDistLabel = distanceLabel
    else
        distanceLabel = data.LastDistLabel or string.format("%d m", dist)
    end

    local hp=ESPShared.SafeNumber(healthPct,1.0,0.0,1.0)
    if hp < 0 then hp = 0 end
    if hp > 1 then hp = 1 end
    local healthChanged=data.LastHealthPct~=hp
    if healthChanged then
        local hpColor = g_Botmater_ESPGetHealthColor(hp,isBot)
        pcall(function()
            if data.HealthFill and g_Botmater_ESPValid(data.HealthFill) then
                data.HealthFill:SetBrushColor(hpColor)
            end
        end)
    end

    local bottomLineH = 4.32
    local baseFontSize=ESPShared.SafeNumber(_G.g_Botmater_MasterShotESP.NameFontSize,12,1,96)
    local baseBottomLineH = 3.6
    local fontSize = baseFontSize * (bottomLineH / baseBottomLineH)
    local paddingX    = 5.0
    local paddingY    = 2.0
    local nameHeight  = fontSize + paddingY * 2 + bottomLineH
    local gap=ESPShared.SafeNumber(_G.g_Botmater_MasterShotESP.NameGap,2,0,128)

    local nameChars = #name
    local textWidth = math.max(30.0, nameChars * (fontSize * 0.52))
    local boxWidth  = math.max(50.0, textWidth + paddingX * 2)
    local boxHeight = nameHeight

    local LINE_UP_SHIFT = boxHeight * 0.25

    local baseY = headScreen.Y - boxHeight - gap
    local containerY = baseY - LINE_UP_SHIFT

    local minX,minY,maxX,maxY=ESPShared.CanvasBounds(pc,g_Botmater_ShotESP)
    boxWidth=math.min(boxWidth,math.max(1,maxX-minX-4))
    local x=ESPShared.SafeNumber(headScreen.X-boxWidth*0.5,minX,minX,maxX-boxWidth)
    containerY=ESPShared.SafeNumber(containerY,minY,minY,math.max(minY,maxY-boxHeight))

    -- The meter label remains inside the HUD, including when feet are clipped.
    local anchor=footScreen or headScreen
    local df=ESPShared.SafeNumber(_G.g_Botmater_MasterShotESP.DistanceFontSize,12,1,96)
    local halfW=math.min(math.max(18,#distanceLabel*df*0.30),(maxX-minX)*0.49)
    local halfH=math.min(df*0.7+2,(maxY-minY)*0.49)
    local distAbsX=ESPShared.SafeNumber(anchor.X,headScreen.X,minX+halfW,maxX-halfW)
    local distAbsY=ESPShared.SafeNumber(anchor.Y+ESPShared.SafeNumber(_G.g_Botmater_MasterShotESP.DistanceBelowFeet,14,0,128),
        minY+halfH,minY+halfH,maxY-halfH)
    containerY=math.min(containerY,distAbsY-halfH)
    local distanceY=distAbsY-containerY
    local totalHeight=math.max(boxHeight,distanceY+halfH)

    local needsPosUpdate = true
    if data.LastBoxX and math.abs(x - data.LastBoxX) < 0.001
       and math.abs(containerY - data.LastBoxY) < 0.001
       and data.LastBoxW == boxWidth and data.LastDistanceY==distanceY then
        needsPosUpdate = false
    end

    local shownName     = showName and name or ""
    local shownDistance = showDistance and distanceLabel or ""

    pcall(function()
        if data.LastName ~= shownName then
            data.Text:SetText(shownName)
            data.LastName = shownName
        end
        if data.LastDistance ~= shownDistance then
            data.DistanceText:SetText(shownDistance)
            data.LastDistance = shownDistance
        end
    end)

    local lineWidth=boxWidth*0.68
    local lineOffsetX=(boxWidth-lineWidth)*0.5
    local healthWidth=lineWidth*hp
    if healthWidth<1 then healthWidth=0 end
    local geometryChanged=data.GeometryWidth~=boxWidth or data.GeometryHeight~=boxHeight
    if geometryChanged or healthChanged then
        local ok=pcall(function()
            if geometryChanged then
                data.HealthBgSlot:SetPosition(g_Botmater_ESPV2(lineOffsetX,boxHeight-bottomLineH))
                data.HealthBgSlot:SetSize(g_Botmater_ESPV2(lineWidth,bottomLineH))
                data.HealthFillSlot:SetPosition(g_Botmater_ESPV2(lineOffsetX,boxHeight-bottomLineH))
                data.TextSlot:SetPosition(g_Botmater_ESPV2(boxWidth*0.5,(boxHeight-bottomLineH)*0.5))
            end
            data.HealthFillSlot:SetSize(g_Botmater_ESPV2(healthWidth,bottomLineH))
        end)
        if ok then data.GeometryWidth=boxWidth;data.GeometryHeight=boxHeight;data.LastHealthPct=hp end
    end
    if needsPosUpdate then
        local ok=pcall(function() data.Slot:SetPosition(g_Botmater_ESPV2(x,containerY)) end)
        if ok then data.LastBoxX=x;data.LastBoxY=containerY;data.LastBoxW=boxWidth end
    end
    if data.LayoutW~=boxWidth or data.LayoutH~=totalHeight then
        local ok=pcall(function() data.Slot:SetSize(g_Botmater_ESPV2(boxWidth,totalHeight)) end)
        if ok then data.LayoutW=boxWidth;data.LayoutH=totalHeight end
    end
    local distX=distAbsX-x
    if data.LastDistanceX~=distX or data.LastDistanceY~=distanceY then
        local ok=pcall(function() data.DistanceSlot:SetPosition(g_Botmater_ESPV2(distX,distanceY)) end)
        if ok then data.LastDistanceX=distX;data.LastDistanceY=distanceY end
    end


    if data.LastHealthVis~=showHealth then
        local ok=pcall(function()
            local visibility=showHealth and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed
            data.HealthBg:SetWidgetVisibility(visibility)
            data.HealthFill:SetWidgetVisibility(visibility)
        end)
        if ok then data.LastHealthVis=showHealth end
    end
    if data.LastNameVis ~= showName then
        local ok=pcall(function() data.Text:SetWidgetVisibility(showName and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed) end)
        if ok then data.LastNameVis=showName end
    end
    if data.LastDistVis ~= showDistance then
        local ok=pcall(function() data.DistanceText:SetWidgetVisibility(showDistance and UEnums.ESlateVisibility.SelfHitTestInvisible or UEnums.ESlateVisibility.Collapsed) end)
        if ok then data.LastDistVis=showDistance end
    end

    if data.Visible ~= true then
        local ok=pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        if ok then data.Visible=true end
    end

    data.FinalX = x
    data.FinalY = containerY
    data.FinalW = boxWidth
    data.FinalH = boxHeight
    data.LineEndX = x + boxWidth * 0.5
    data.LineEndY = containerY + (boxHeight - bottomLineH)
end

local function g_Botmater_ESPScanEnemies()
    local pc = g_Botmater_ESPGetController()
    local me = g_Botmater_ESPGetLocalCharacter()
    if not pc or not me then
        g_Botmater_ShotESP.Enemies = {}
        g_Botmater_ShotESP.RealCount = 0
        g_Botmater_ShotESP.BotCount = 0
        return nil
    end
    local myLoc = ESPShared.GetFrameRecord(me).Location
    if not myLoc then
        g_Botmater_ShotESP.Enemies = {}
        g_Botmater_ShotESP.RealCount = 0
        g_Botmater_ShotESP.BotCount = 0
        return pc
    end
    local myTeam = g_Botmater_ESPGetTeamID(me)

    local list = {}
    local realCount = 0
    local botCount = 0
    local pawns=ESPShared.GetFramePawns()
    if not pawns then return pc end
    if pawns then
        for _, character in pairs(pawns) do
            if character~=me and ESPShared.GetFrameRecord(character).Alive and ESPShared.Events.Counted(character) then
                local team = g_Botmater_ESPGetTeamID(character)
                if myTeam == nil or team == nil or tostring(team) ~= tostring(myTeam) then
                    local loc = ESPShared.GetFrameRecord(character).Location
                    local dist = ESPShared.DistanceMetersFrom(ESPShared.GetFrameRecord(character),myLoc)
                    if dist <= (tonumber(_G.g_Botmater_MasterShotESP.MaxRangeMeters) or 300.0) then
                        local isBot = g_Botmater_ESPIsBot(character)
                        local k = g_Botmater_ESPGetPlayerKey(character)
                        if k then
                            list[#list+1] = {Character=character, Key=k, IsBot=isBot, Distance=dist}
                            if isBot then botCount = botCount + 1 else realCount = realCount + 1 end
                        end
                    end
                end
            end
        end
    end
    local maxRendered = math.floor(ESPShared.SafeNumber(_G.g_Botmater_MasterShotESP.MaxRendered,10,1,64))
    if #list > maxRendered then
        table.sort(list,function(a,b)
            if a.Distance==b.Distance then return a.Key<b.Key end
            return a.Distance<b.Distance
        end)
    end
    g_Botmater_ShotESP.Enemies = list
    g_Botmater_ShotESP.RealCount = realCount
    g_Botmater_ShotESP.BotCount = botCount
    return pc
end

local function g_Botmater_ESPPrune(active,alive)
    alive=alive or active
    for _,registry in ipairs({g_Botmater_ShotESP.Lines,g_Botmater_ShotESP.Names}) do
        for key,data in pairs(registry) do
            if not active[key] and g_Botmater_ESPDestroyWidgetData(data) then registry[key]=nil end
        end
    end
    for key in pairs(g_Botmater_ShotESP._BotCache or {}) do if not alive[key] then g_Botmater_ShotESP._BotCache[key]=nil end end
    for key in pairs(g_Botmater_ShotESP.LastProjected) do if not alive[key] then g_Botmater_ShotESP.LastProjected[key]=nil end end
end

ESPShared.Events.Clearers[#ESPShared.Events.Clearers+1]=function(actor)
    ESPShared.Events.ClearIn(g_Botmater_ShotESP,g_Botmater_ESPPrune,actor)
end

local g_Botmater_EnemyCounter = {
    Container = nil,
    Slot = nil,
    PlayerBG = nil,
    BotBG = nil,
    PlayerText = nil,
    BotText = nil,
    Width = 218.4,
    Height = 33.6,
    OffsetY = 22.5, -- If V2 counter is visible, shift V1 down to avoid overlap.
    FontSize = 13,
    FontScale = 1.2, -- Exact 20% glyph growth; native font Size is an integer.
    _LastPlayers = -1,
    _LastBots = -1,
    _PosVec = nil,
    _LastPosX = nil,
    _LastPosY = nil,
    CanvasCenterX = 0.0,
    CanvasCenterY = 0.0,
}

local function g_Botmater_CounterTextColor(widget,color)
    g_masterahsanyt_ESPSetTextColor(widget,color)
end

local function g_Botmater_CounterCreate()
    if V1Cleanup.Count>=V1Cleanup.AdmissionLimit then return false end
    if g_Botmater_EnemyCounter.Container and slua.isValid(g_Botmater_EnemyCounter.Container) then
        return true
    end
    local canvas = g_Botmater_ESPGetCanvas()
    if not canvas or not g_Botmater_ESPValid(canvas) then return false end

    local W, H = g_Botmater_EnemyCounter.Width, g_Botmater_EnemyCounter.Height
    local halfW = W * 0.5

    local Container, PlayerBG, BotBG, PlayerText, BotText = nil, nil, nil, nil, nil
    pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not Container or not slua.isValid(Container) then return false end
    pcall(function() PlayerBG = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)
    pcall(function() BotBG = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)
    pcall(function() PlayerText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    pcall(function() BotText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)

    if not PlayerBG or not BotBG or not PlayerText or not BotText
        or not slua.isValid(PlayerBG) or not slua.isValid(BotBG)
        or not slua.isValid(PlayerText) or not slua.isValid(BotText) then
        V1Cleanup.Retire(Container)
        return false
    end

    pcall(function()
        PlayerBG:SetBrushColor(CACHE_COUNTER_PLAYER_BG)
        PlayerBG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        BotBG:SetBrushColor(CACHE_COUNTER_BOT_BG)
        BotBG:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)

    local pbgSlot, bbgSlot = nil, nil
    pcall(function() pbgSlot = Container:AddChildToCanvas(PlayerBG) end)
    pcall(function() bbgSlot = Container:AddChildToCanvas(BotBG) end)
    if not pbgSlot or not bbgSlot then
        V1Cleanup.Retire(Container)
        return false
    end

    pcall(function()
        pbgSlot:SetAutoSize(false)
        pbgSlot:SetPosition(g_Botmater_ESPV2(0, 0))
        pbgSlot:SetSize(g_Botmater_ESPV2(halfW, H))
        pbgSlot:SetZOrder(0)
        bbgSlot:SetAutoSize(false)
        bbgSlot:SetPosition(g_Botmater_ESPV2(halfW, 0))
        bbgSlot:SetSize(g_Botmater_ESPV2(halfW, H))
        bbgSlot:SetZOrder(0)
    end)

    pcall(function()
        PlayerText:SetText("REAL: 0")
        BotText:SetText("BOT: 0")
        g_masterahsanyt_ESPSetFont(PlayerText,g_Botmater_EnemyCounter.FontSize,0)
        g_masterahsanyt_ESPSetFont(BotText,g_Botmater_EnemyCounter.FontSize,0)
        local scale=g_Botmater_EnemyCounter.FontScale
        PlayerText:SetRenderTransformPivot(g_Botmater_ESPV2(0.5,0.5))
        BotText:SetRenderTransformPivot(g_Botmater_ESPV2(0.5,0.5))
        PlayerText:SetRenderScale(g_Botmater_ESPV2(scale,scale))
        BotText:SetRenderScale(g_Botmater_ESPV2(scale,scale))
        PlayerText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        BotText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)

    g_Botmater_CounterTextColor(PlayerText, CACHE_COUNTER_PLAYER_TEXT)
    g_Botmater_CounterTextColor(BotText, CACHE_COUNTER_BOT_TEXT)

    local ptSlot, btSlot = nil, nil
    pcall(function() ptSlot = Container:AddChildToCanvas(PlayerText) end)
    pcall(function() btSlot = Container:AddChildToCanvas(BotText) end)
    if ptSlot then
        pcall(function()
            ptSlot:SetAutoSize(true)
            ptSlot:SetAlignment(g_Botmater_ESPV2(0.5, 0.5))
            ptSlot:SetPosition(g_Botmater_ESPV2(halfW * 0.5, H * 0.5))
            ptSlot:SetZOrder(2)
        end)
    end
    if btSlot then
        pcall(function()
            btSlot:SetAutoSize(true)
            btSlot:SetAlignment(g_Botmater_ESPV2(0.5, 0.5))
            btSlot:SetPosition(g_Botmater_ESPV2(halfW + halfW * 0.5, H * 0.5))
            btSlot:SetZOrder(2)
        end)
    end

    local mainSlot = nil
    pcall(function() mainSlot = canvas:AddChildToCanvas(Container) end)
    if not mainSlot then
        V1Cleanup.Retire(Container)
        return false
    end
    pcall(function()
        mainSlot:SetAutoSize(false)
        mainSlot:SetSize(g_Botmater_ESPV2(W, H))
        mainSlot:SetZOrder(50)
    end)

    g_Botmater_EnemyCounter.Container = Container
    g_Botmater_EnemyCounter.Slot = mainSlot
    g_Botmater_EnemyCounter.PlayerBG = PlayerBG
    g_Botmater_EnemyCounter.BotBG = BotBG
    g_Botmater_EnemyCounter.PlayerText = PlayerText
    g_Botmater_EnemyCounter.BotText = BotText
    g_Botmater_EnemyCounter._LastPlayers = -1
    g_Botmater_EnemyCounter._LastBots = -1
    g_Botmater_EnemyCounter._PosVec = nil
    g_Botmater_EnemyCounter._LastPosX = nil
    g_Botmater_EnemyCounter._LastPosY = nil

    pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    return true
end

local function g_Botmater_CounterUpdatePosition(pc)
    local slot = g_Botmater_EnemyCounter.Slot
    if not slot or not slua.isValid(slot) then return end
    if not pc or not g_Botmater_ESPValid(pc) then return end

    local canvasW, canvasH = g_Botmater_ESPGetCanvasLocalSize()
    if not canvasW or not canvasH then
        local vw, vh = g_Botmater_ESPViewport(pc)
        if not vw or vw <= 200 then return end
        local sx = g_Botmater_ShotESP.CanvasScaleX or 1.0
        local sy = g_Botmater_ShotESP.CanvasScaleY or 1.0
        local ox = g_Botmater_ShotESP.CanvasOffsetX or 0.0
        local oy = g_Botmater_ShotESP.CanvasOffsetY or 0.0
        canvasW = (vw * sx) - ox
        canvasH = (vh * sy) - oy
    end

    if not canvasW or not canvasH then return end

    local canvasCenterX = canvasW * 0.5
    local canvasCenterY = g_Botmater_EnemyCounter.OffsetY
    if _G.g_masterahsanyt_ESPOptions.Counter then canvasCenterY=106 end

    local x = canvasCenterX - g_Botmater_EnemyCounter.Width * 0.5
    local y = canvasCenterY

    g_Botmater_EnemyCounter.CanvasCenterX = canvasCenterX
    g_Botmater_EnemyCounter.CanvasCenterY = canvasCenterY + g_Botmater_EnemyCounter.Height * 0.5

    local lx, ly = g_Botmater_EnemyCounter._LastPosX, g_Botmater_EnemyCounter._LastPosY
    if lx ~= nil and ly ~= nil and math.abs(lx - x) < 0.1 and math.abs(ly - y) < 0.1 then return end
    g_Botmater_EnemyCounter._PosVec = g_Botmater_ESPV2(x, y)
    local ok = pcall(function() slot:SetPosition(g_Botmater_EnemyCounter._PosVec) end)
    if ok then
        g_Botmater_EnemyCounter._LastPosX = x
        g_Botmater_EnemyCounter._LastPosY = y
    end
end

local function g_Botmater_GetLineOrigin(pc)
    if _G.g_Botmater_ESPOptions.EnemyCounter then
        g_Botmater_CounterUpdatePosition(pc)
        return g_Botmater_ESPV2(g_Botmater_EnemyCounter.CanvasCenterX,g_Botmater_EnemyCounter.CanvasCenterY+g_Botmater_EnemyCounter.Height*0.5)
    end
    local width=g_Botmater_ESPGetCanvasLocalSize()
    if not width then
        local vw=g_Botmater_ESPViewport(pc)
        width=(vw or 2400)*g_Botmater_ShotESP.CanvasScaleX+g_Botmater_ShotESP.CanvasOffsetX
    end
    local top=_G.g_masterahsanyt_ESPOptions.Counter and 106 or g_Botmater_EnemyCounter.OffsetY
    return g_Botmater_ESPV2(width*0.5,top+g_Botmater_EnemyCounter.Height)
end

local function g_Botmater_CounterSetCounts(realCount, botCount)
    realCount = tonumber(realCount) or 0
    botCount = tonumber(botCount) or 0
    if g_Botmater_EnemyCounter._LastPlayers ~= realCount
        and g_Botmater_EnemyCounter.PlayerText and slua.isValid(g_Botmater_EnemyCounter.PlayerText) then
        local ok, applied = pcall(function()
            return g_Botmater_EnemyCounter.PlayerText:SetText(string.format("REAL: %d", realCount)) ~= false
        end)
        if ok and applied then g_Botmater_EnemyCounter._LastPlayers = realCount end
    end
    if g_Botmater_EnemyCounter._LastBots ~= botCount
        and g_Botmater_EnemyCounter.BotText and slua.isValid(g_Botmater_EnemyCounter.BotText) then
        local ok, applied = pcall(function()
            return g_Botmater_EnemyCounter.BotText:SetText(string.format("BOT: %d", botCount)) ~= false
        end)
        if ok and applied then g_Botmater_EnemyCounter._LastBots = botCount end
    end
end

local function g_Botmater_CounterStart(pc)
    if not g_Botmater_CounterCreate() then return end
    pcall(function()
        g_Botmater_EnemyCounter.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    g_Botmater_CounterUpdatePosition(pc)
end

local function g_Botmater_CounterStop()
    local container = g_Botmater_EnemyCounter.Container
    g_Botmater_EnemyCounter.Container = nil
    g_Botmater_EnemyCounter.Slot = nil
    g_Botmater_EnemyCounter.PlayerBG = nil
    g_Botmater_EnemyCounter.BotBG = nil
    g_Botmater_EnemyCounter.PlayerText = nil
    g_Botmater_EnemyCounter.BotText = nil
    g_Botmater_EnemyCounter._LastPlayers = -1
    g_Botmater_EnemyCounter._LastBots = -1
    g_Botmater_EnemyCounter._PosVec = nil
    g_Botmater_EnemyCounter._LastPosX = nil
    g_Botmater_EnemyCounter._LastPosY = nil
    g_Botmater_EnemyCounter.CanvasCenterX = 0.0
    g_Botmater_EnemyCounter.CanvasCenterY = 0.0
    if g_Botmater_ESPValid(container) then
        V1Cleanup.Retire(container)
    end
end

-- Each actor update is isolated. Death cleanup runs before projection/drawing.
local function g_Botmater_ESPRenderActor(item,pc,opt,origin,now)
    local state=g_Botmater_ShotESP
    local c,key,isBot=item.Character,item.Key,item.IsBot
    local head,feet,onScreen,reason=ESPShared.Events.Project(pc,c,state)
    if not onScreen then
        local last=state.LastProjected[key]
        if reason=="unavailable" and last and now>=last and now-last<=0.08 then
            state.Active[key]=true
        else
            state.LastProjected[key]=nil
        end
        return
    end
    local anchor=head or feet
    if not anchor then return end
    state.Active[key]=true;state.LastProjected[key]=now
    local color=g_Botmater_ESPGetColors(isBot)
    local hp=opt.Health and g_Botmater_ESPGetHealthPct(c) or 1
    g_Botmater_ESPUpdateNameTag(key,c,anchor,feet,isBot,item.Distance,hp,pc)
    local line=state.Lines[key]
    if opt.Line and (not line or line.Broken or not g_Botmater_ESPValid(line.Widget)
        or not g_Botmater_ESPValid(line.Slot)) then
        if not g_Botmater_ESPDestroyWidgetData(line) then return end
        line=g_Botmater_ESPCreateLine(color);state.Lines[key]=line
    end
    if opt.Line and line then
        local colorKey=isBot and "B" or "P"
        if line.ColorKey~=colorKey then
            local ok=pcall(function() line.Widget:SetBrushColor(color) end)
            if ok then line.ColorKey=colorKey end
        end
        local tag=state.Names[key]
        local x,y=tag and tag.LineEndX or anchor.X,tag and tag.LineEndY or anchor.Y
        g_Botmater_ESPDrawLine(line,origin.X,origin.Y,x,y,
            ESPShared.SafeNumber(_G.g_Botmater_MasterShotESP.TracerThickness,1,0.1,12))
    elseif line then g_Botmater_ESPHide(line) end
end

local function g_Botmater_ESPDrawCandidates(pc,opt,now)
    local state=g_Botmater_ShotESP
    local origin=g_Botmater_GetLineOrigin(pc)
    local limit=math.floor(ESPShared.SafeNumber(_G.g_Botmater_MasterShotESP.MaxRendered,10,1,64))
    for i,item in ipairs(state.Enemies) do
        if i>limit then break end
        local ok,err=pcall(g_Botmater_ESPRenderActor,item,pc,opt,origin,now)
        if not ok then
            state.Active[item.Key]=nil;state.LastProjected[item.Key]=nil
            local f=_G.LunarFeatures
            if f and f.Error then f.Error("V1.Actor",err) end
        end
    end
end

local function g_Botmater_ESPUpdate()
    local state=g_Botmater_ShotESP
    local opt=_G.g_Botmater_ESPOptions
    local details=opt and (opt.Name or opt.Line or opt.Health or opt.Distance)
    local counter=opt and opt.EnemyCounter
    local now=g_Botmater_ESPNow()
    V1Cleanup.Pump(now)
    if not _G.g_Botmater_MasterShotESP.Enabled or (not details and not counter) then
        g_Botmater_ESPResetWidgets();g_Botmater_CounterStop();return
    end
    local world=g_Botmater_ESPWorld()
    ESPShared.Events.WorldChanged(world)
    if world~=state.LastWorld then
        g_Botmater_ESPResetWidgets();g_Botmater_CounterStop();state.LastWorld=world
    end
    local oldCanvas=state.Canvas
    local canvas=g_Botmater_ESPGetCanvas()
    if canvas~=oldCanvas then g_Botmater_CounterStop() end
    if not canvas then return end
    local pc=g_Botmater_ESPGetController()
    if now<state.LastScanClock or now-state.LastScanClock>=(tonumber(_G.g_Botmater_MasterShotESP.ScanInterval) or 0.05) then
        pc=g_Botmater_ESPScanEnemies() or pc;state.LastScanClock=now
    end
    pc=pc or g_Botmater_ESPGetController()
    if not pc then g_Botmater_ESPResetWidgets();g_Botmater_CounterStop();return end
    local location=ESPShared.GetFrameRecord(g_Botmater_ESPGetLocalCharacter()).Location
    local active,alive=state.Active,state.Alive
    state.RealCount,state.BotCount=g_masterahsanyt_ESPFilterEnemies(state.Enemies,location,
        _G.g_Botmater_MasterShotESP.MaxRangeMeters,alive)
    -- Prune confirmed excluded actors BEFORE any fallible drawing operation.
    g_Botmater_ESPPrune(alive,alive)
    for k in pairs(active) do active[k]=nil end
    if now<state.LastTransformClock or now-state.LastTransformClock>=(tonumber(_G.g_Botmater_MasterShotESP.TransformInterval) or 0.033) then
        g_Botmater_ESPUpdateCanvasTransform(pc);state.LastTransformClock=now
    end
    if counter then
        pcall(g_Botmater_CounterStart,pc)
        pcall(g_Botmater_CounterSetCounts,state.RealCount,state.BotCount)
    else g_Botmater_CounterStop() end
    local ok,err=true,nil
    if details then ok,err=pcall(g_Botmater_ESPDrawCandidates,pc,opt,now) end
    -- This path also executes after an origin/projection/vector error.
    g_Botmater_ESPPrune(active,alive)
    if not ok then
        local f=_G.LunarFeatures
        if f and f.Error then f.Error("V1.Draw",err) end
    end
end

local F=_G.LunarFeatures
F.V1={State=g_Botmater_ShotESP,Counter=g_Botmater_EnemyCounter,Tick=g_Botmater_ESPUpdate,
    Cleanup=V1Cleanup,
    Reset=function() g_Botmater_ESPResetWidgets();g_Botmater_CounterStop() end,
    Refresh=function() g_Botmater_ShotESP.LastScanClock=-999;g_Botmater_ShotESP.LastTransformClock=-999 end}
end

-- Controls live entirely in the native game settings page.

-- Additional aim modes share the managed scheduler. No timer is created here.
do
    local F=_G.LunarFeatures
    local MathLib,Layout,HealthStates,PawnStates
    pcall(function() MathLib=import("KismetMathLibrary") end)
    pcall(function() Layout=import("WidgetLayoutLibrary") end)
    pcall(function() HealthStates=import("ECharacterHealthStatus") end)
    pcall(function() PawnStates=import("EPawnState") end)
    local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
    local function get(obj,key)
        if not obj then return nil end
        local ok,v=pcall(function() return obj[key] end)
        if ok then return v end
    end
    local function call(obj,key,...)
        local method=get(obj,key)
        if type(method)~="function" then return nil end
        local ok,v=pcall(method,obj,...)
        if ok then return v end
    end
    local function valid(obj) return obj and g_masterahsanyt_ESPValid(obj) end
    local function pos(v)
        if v and finite(v.X) and finite(v.Y) and finite(v.Z) then return {X=v.X,Y=v.Y,Z=v.Z} end
    end
    local function nativeVector(v) return g_masterahsanyt_ESPV3(v.X,v.Y,v.Z) end
    local function team(actor)
        local id=call(actor,"GetTeamID") or get(actor,"TeamID")
        if id==nil then
            local state=call(actor,"GetPlayerStateSafety")
            id=call(state,"GetTeamID") or get(state,"TeamID")
        end
        return id
    end
    local function dead(actor)
        if not valid(actor) then return true end
        local hp=call(actor,"GetHealth") or get(actor,"Health") or get(actor,"HP")
        if finite(hp) and hp<=0 then return true end
        if get(actor,"bIsDead")==true or get(actor,"bDead")==true or get(actor,"bIsDeadFlag")==true then return true end
        if HealthStates and HealthStates.FinishedLastBreath~=nil and get(actor,"HealthStatus")==HealthStates.FinishedLastBreath then return true end
        if PawnStates and PawnStates.Dead~=nil and call(actor,"HasPawnState",PawnStates.Dead)==true then return true end
        return false
    end
    local function weapon(player)
        local w=call(player,"GetCurrentWeapon") or get(player,"CurrentWeapon")
        if not valid(w) then
            local wm=get(player,"WeaponManagerComponent")
            w=get(wm,"CurrentWeaponReplicated") or get(wm,"CurrentWeapon")
        end
        return valid(w) and w or nil
    end
    local function kind(w)
        local name=call(w,"GetWeaponName")
        if type(name)~="string" or not name:find("%S") then return "unknown" end
        name=name:lower()
        if name:find("mortar",1,true) or name:find("cối",1,true) or name:find("cỐi",1,true) then return "mortar" end
        return "other"
    end
    local function context()
        local pc=g_masterahsanyt_ESPGetController()
        local player=g_masterahsanyt_ESPGetLocalCharacter()
        if valid(pc) and not dead(player) then return g_masterahsanyt_ESPWorld(),pc,player,weapon(player) end
    end
    local function pelvis(actor)
        local p=pos(call(actor,"GetBonePos","pelvis",{X=0,Y=0,Z=0}))
        if not p or (p.X==0 and p.Y==0 and p.Z==0) then p=pos(call(actor,"GetSocketLocation","pelvis")) end
        if not p or (p.X==0 and p.Y==0 and p.Z==0) then p=pos(call(actor,"K2_GetActorLocation")) end
        return p
    end
    local function allPlayers()
        local list
        pcall(function() if GameplayData.GetAllPlayerCharacters then list=GameplayData.GetAllPlayerCharacters() end end)
        return type(list)=="table" and list or {}
    end
    local function viewport(pc)
        local w,h=g_masterahsanyt_ESPViewport(pc)
        if not finite(w) or w<=0 or not finite(h) or h<=0 then return 1920,1080 end
        return w,h
    end
    local function project(pc,p)
        local screen=FVector2D(0,0)
        local ok,yes=pcall(function() return pc:ProjectWorldLocationToScreen(nativeVector(p),screen,false) end)
        if ok and (yes==true or yes==1) and finite(screen.X) and finite(screen.Y) then return screen.X,screen.Y end
    end
    local function camera(pc,player,fallback)
        local cm=call(pc,"GetPlayerCameraManager")
        if not valid(cm) then pcall(function() cm=GameplayStaticsESP.GetPlayerCameraManager(pc,0) end) end
        return pos(call(cm,"GetCameraLocation")) or fallback or pos(call(player,"K2_GetActorLocation"))
    end
    local function rotation(pc,target,source)
        if not target or not finite(target.Pitch) or not finite(target.Yaw) or not finite(target.Roll) then return false end
        local current=call(pc,"GetControlRotation")
        if current and finite(current.Pitch) and finite(current.Yaw) and finite(current.Roll or 0)
            and math.abs((target.Pitch-current.Pitch+180)%360-180)<0.00001
            and math.abs((target.Yaw-current.Yaw+180)%360-180)<0.00001
            and math.abs(target.Roll-(current.Roll or 0))<0.00001 then return true end
        local ok,accepted=pcall(function() return pc:SetControlRotation(target,source) end)
        if not ok then F.Error(source,accepted) end
        return ok and accepted~=false
    end
    -- A failed restore survives a script reload and remains eligible for retry.
    local pending=_G.__LunarAim2RestorePending or {}
    _G.__LunarAim2RestorePending=pending
    local A={Target=nil,Enabled=false,Due=0,LastTime=nil,Records=pending,RestoreErrors={}}
    F.Aim2=A
    local fields={"RecoilKickADS","GameDeviationFactor","GameDeviationAccuracy"}
    local function restore()
        for obj,record in pairs(A.Records) do
            if not valid(obj) then A.Records[obj]=nil;A.RestoreErrors[obj]=nil
            else
                for key,value in pairs(record) do
                    local ok,err=true,nil
                    if get(obj,key)~=value then ok,err=pcall(function() obj[key]=value end) end
                    if ok and get(obj,key)==value then record[key]=nil
                    elseif not A.RestoreErrors[obj] or not A.RestoreErrors[obj][key] then
                        A.RestoreErrors[obj]=A.RestoreErrors[obj] or {};A.RestoreErrors[obj][key]=true
                        F.Error("Aim2.Restore."..key,err or "native field did not accept restoration")
                    end
                end
                if next(record)==nil then A.Records[obj]=nil;A.RestoreErrors[obj]=nil end
            end
        end
    end
    function A.Stop()
        restore();A.Target=nil;A.Enabled=false;A.LastTime=nil;A.World=nil;A.PC=nil;A.Player=nil;A.Weapon=nil;A.Entity=nil;A.Due=0;A.Unsupported=nil;A.ApplyFailed=nil
    end
    function A.NextInterval(now)
        if not F.Settings.Aim2Enabled then return 0.5 end
        return math.max(0.001,A.Due-(finite(now) and now or F.Now()))
    end
    local function hard(entity)
        if not valid(entity) then return end
        local record=A.Records[entity]
        if not record then record={};A.Records[entity]=record end
        for _,key in ipairs(fields) do
            local current=get(entity,key)
            if finite(current) then
                if record[key]==nil then record[key]=current end
                if current~=0.01 then
                    local ok,err=pcall(function() entity[key]=0.01 end)
                    if not ok and (not A.ApplyFailed or not A.ApplyFailed[key]) then
                        A.ApplyFailed=A.ApplyFailed or {};A.ApplyFailed[key]=true;F.Error("Aim2.Apply."..key,err)
                    end
                end
            elseif not A.Unsupported or not A.Unsupported[key] then
                A.Unsupported=A.Unsupported or {};A.Unsupported[key]=true
                F.Error("Aim2.Unsupported",key.." is unreadable; left unchanged")
            end
        end
    end
    function A.Tick(now)
        now=finite(now) and now or F.Now()
        if not F.Settings.Aim2Enabled then if A.Player or next(A.Records) then A.Stop() end;return false end
        local world,pc,player,w=context()
        if not world or not w or kind(w)=="mortar" then A.Stop();A.Due=now+0.5;return false end
        local entity=get(w,"ShootWeaponEntityComp")
        if A.World~=world or A.PC~=pc or A.Player~=player or A.Weapon~=w or A.Entity~=entity then
            A.Stop();A.World=world;A.PC=pc;A.Player=player;A.Weapon=w;A.Entity=entity
        end
        if now<A.Due-0.000001 and (not A.LastTime or now>=A.LastTime) then return false end
        local dt=A.LastTime and now-A.LastTime or 0.5
        if not finite(dt) or dt<=0 then dt=0.5 end
        A.LastTime=now;A.Due=now+0.5;hard(entity)
        if get(player,"bIsWeaponAiming")~=true then A.Target=nil;A.Enabled=false;A.Due=now+0.2;return false end
        if not MathLib or not MathLib.FindLookAtRotation then return false end
        local myTeam=team(player)
        if myTeam==nil then return false end
        local width,height=viewport(pc)
        local scale=1
        pcall(function() if Layout and Layout.GetViewportScale then local s=Layout.GetViewportScale(pc);if finite(s) and s>0 then scale=s end end end)
        -- Reference circle is 150 UI units, with its inner 70% used for selection.
        local rx,ry=105*scale,105*scale
        local best,bestScore=nil,math.huge
        for _,enemy in pairs(allPlayers()) do
            if enemy~=player and not dead(enemy) then
                local enemyTeam=team(enemy)
                if enemyTeam~=nil and tostring(enemyTeam)~=tostring(myTeam) then
                    local p=pelvis(enemy)
                    if p then
                        local x,y=project(pc,p)
                        if x and x>=0 and y>=0 and x<=width and y<=height then
                            local dx,dy=(x-width/2)/rx,(y-height/2)/ry
                            local score=dx*dx+dy*dy
                            if finite(score) and score<=1 and score<bestScore then best,bestScore=enemy,score end
                        end
                    end
                end
            end
        end
        A.Target=best;A.Enabled=best~=nil
        if not best then return false end
        local loc,p=camera(pc,player),pelvis(best)
        if not loc or not p then return false end
        local desired=MathLib.FindLookAtRotation(nativeVector(loc),nativeVector(p))
        local current=call(pc,"GetControlRotation")
        if not desired or not current or not finite(desired.Pitch) or not finite(desired.Yaw) or not finite(current.Pitch) or not finite(current.Yaw) then return false end
        local dp,dy=(desired.Pitch-current.Pitch+180)%360-180,(desired.Yaw-current.Yaw+180)%360-180
        local dist=math.sqrt(dp*dp+dy*dy)
        local step=90*math.min(dt,0.5)
        local fraction=dist>step and step/dist or 1
        local final={Pitch=current.Pitch+dp*fraction,Yaw=current.Yaw+dy*fraction,Roll=current.Roll or 0}
        local w2,pc2,p2,wCurrent=context()
        if not F.Settings.Aim2Enabled or world~=w2 or pc~=pc2 or player~=p2 or w~=wCurrent or get(player,"bIsWeaponAiming")~=true or dead(best) then A.Stop();return false end
        return rotation(pc,final,"CircleAim")
    end
    local M={Target=nil,Candidates={},ScanDue=0,Due=0,LastTime=nil,Status="inactive",ActivePlaced=false}
    F.Mortar=M
    function M.Stop()
        M.Target=nil;M.Candidates={};M.ScanDue=0;M.Due=0;M.LastTime=nil;M.World=nil;M.PC=nil;M.Player=nil;M.Weapon=nil;M.ActivePlaced=false;M.Status="inactive"
    end
    local function distance(player,target)
        local d=call(player,"GetDistanceTo",target)
        if finite(d) and d>=0 then return d end
        local a,b=pos(call(player,"K2_GetActorLocation")),pos(call(target,"K2_GetActorLocation"))
        if a and b then local dx,dy,dz=a.X-b.X,a.Y-b.Y,a.Z-b.Z;d=math.sqrt(dx*dx+dy*dy+dz*dz);if finite(d) then return d end end
    end
    local function enemy(player,target)
        if target==player or dead(target) then return false end
        local mine,theirs=team(player),team(target)
        if mine~=nil and theirs~=nil and tostring(mine)==tostring(theirs) then return false end
        local d=distance(player,target)
        return finite(d) and d<=200000
    end
    local function trajectory(launch,V,G,target)
        if not pos(launch) or not pos(target) or not finite(V) or V<=0 or not finite(G) or G<=0 then return false,45,0,0 end
        local dx=math.max(500,math.sqrt((target.X-launch.X)^2+(target.Y-launch.Y)^2)-80)
        local dy=target.Z-launch.Z
        local minVSq=G*(dy+math.sqrt(dx*dx+dy*dy))
        if not finite(dx) or not finite(minVSq) then return false,45,0,0 end
        if V*V<minVSq then V=math.sqrt(math.max(0,minVSq))+100 end
        local v2=V*V
        local root=v2*v2-G*(G*dx*dx+2*dy*v2)
        if not finite(root) or root<0 then return false,45,0,dx end
        local rad=math.atan((v2+math.sqrt(root))/(G*dx))
        local deg,tof=math.deg(rad),dx/(V*math.cos(rad))
        if finite(deg) and finite(tof) and tof>0 and deg>=35 and deg<=89.5 then return true,deg,tof,dx end
        return false,45,0,dx
    end
    local function solve(launch,target)
        local okN,aN,tN,dN=trajectory(launch,9070,2744,target)
        local okF,aF,tF,dF=trajectory(launch,12520,3920,target)
        local okU,aU,tU,dU=trajectory(launch,16800,4410,target)
        if okN and dN<=25000 then return true,aN,tN,dN end
        if okF and dF<=40000 then return true,aF,tF,dF end
        if okU then return true,aU,tU,dU end
        if okN then return true,aN,tN,dN end
        return false,45,0,dN
    end
    M.SolveTrajectory=solve
    local function predict(target,base,launch)
        local velocity=call(target,"GetVelocity")
        if not velocity or not finite(velocity.X) or not finite(velocity.Y) or math.abs(velocity.X)+math.abs(velocity.Y)<0.01 then return base end
        local predicted={X=base.X,Y=base.Y,Z=base.Z}
        local fallback
        for _=1,2 do
            local ok,a,tof,d=solve(launch,predicted)
            if not ok then break end
            fallback={ok,a,tof,d}
            if tof<=0 or tof>15 then break end
            predicted.X=base.X+velocity.X*tof;predicted.Y=base.Y+velocity.Y*tof
            if not pos(predicted) then return base end
        end
        return predicted,fallback
    end
    function M.NextInterval(now)
        if not F.Settings.MortarEnabled then return 0.5 end
        return math.max(0.001,M.Due-(finite(now) and now or F.Now()))
    end
    function M.Tick(now)
        now=finite(now) and now or F.Now()
        if not F.Settings.MortarEnabled then if M.Player then M.Stop() end;return false end
        local world,pc,player,w=context()
        if not world or not w or kind(w)~="mortar" or get(w,"MortarState")~=2 then
            M.Stop();M.Status="not_placed_mortar";M.Due=now+0.5;return false
        end
        if M.World~=world or M.PC~=pc or M.Player~=player or M.Weapon~=w then
            M.Stop();M.World=world;M.PC=pc;M.Player=player;M.Weapon=w
        end
        if now<M.Due-0.000001 and (not M.LastTime or now>=M.LastTime) then return false end
        M.LastTime=now;M.Due=now+0.5;M.ActivePlaced=true;M.Status="targeting"
        if not enemy(player,M.Target) then
            M.Target=nil
            if now>=M.ScanDue then M.Candidates=allPlayers();M.ScanDue=now+0.25 end
            local width,height=viewport(pc)
            local best,score=nil,math.huge
            for _,target in pairs(M.Candidates) do
                if enemy(player,target) then
                    local p=pelvis(target)
                    if p then local x,y=project(pc,p)
                        if x and x>0 and y>0 then
                            local dx,dy=x-width/2,y-height/2
                            local d=dx*dx+dy*dy
                            if finite(d) and d<score and d<=(3.6*width/2)^2 then best,score=target,d end
                        end
                    end
                end
            end
            M.Target=best
        end
        local target=M.Target
        if not target then M.Status="no_target";return false end
        local base,launch=pelvis(target),pos(call(player,"K2_GetActorLocation"))
        if not base or not launch then M.Status="position_unavailable";return false end
        launch.Z=launch.Z+50
        local predicted,fallback=predict(target,base,launch)
        local ok,angle,tof=solve(launch,predicted)
        if not ok and fallback then ok,angle,tof=fallback[1],fallback[2],fallback[3] end
        if not ok or not finite(tof) or not finite(angle) then M.Status="unreachable";return false end
        if not MathLib or not MathLib.FindLookAtRotation then M.Status="math_unavailable";return false end
        local desired=MathLib.FindLookAtRotation(nativeVector(camera(pc,player,launch)),nativeVector(predicted))
        local current=call(pc,"GetControlRotation")
        if not desired or not current or not finite(desired.Yaw) or not finite(current.Pitch) or not finite(current.Yaw) then return false end
        local pitch=((angle-45)/43)*90-60
        local dp,dy=(pitch-current.Pitch+180)%360-180,(desired.Yaw-current.Yaw+180)%360-180
        local final={Pitch=current.Pitch+dp,Yaw=current.Yaw+dy,Roll=0}
        local world2,pc2,player2,w2=context()
        if not F.Settings.MortarEnabled or world2~=world or pc2~=pc or player2~=player or w2~=w or get(w,"MortarState")~=2 or not enemy(player,target) then M.Stop();return false end
        local accepted=rotation(pc,final,"MortarAim")
        M.Status=accepted and "rotation_call_accepted" or "rotation_failed"
        return accepted
    end
end

-- All features share the existing ESP render runner. No new repeating timer.
do
    local F=_G.LunarFeatures
    local function checked(fn,area,...)
        local ok,err=pcall(fn,...)
        if not ok then F.Error(area,err) end
    end
    F.V1Due=0;F.AimDue=0;F.IpadDue=0;F.SaveDue=0
    F.Pump=function(now)
        F.TimerClock=g_masterahsanyt_ShotESP.TimerClock
        now=now or F.Now()
        if F.V1 and F.V1.Cleanup then F.V1.Cleanup.Pump(now) end
        local login=_G.LunarLoginRuntime
        if login and login.NeedsUpdate and (not F.LoginDue or now>=F.LoginDue or now<(F.LoginLastClock or now)) then
            checked(login.Update,"Login.Update");F.LoginDue=now+0.5;F.LoginLastClock=now
        end
        if F.Dirty and now>=F.SaveDue then checked(F.Save,"Settings.Save");F.SaveDue=now+0.5 end
        if not (login and login.Authorized) then
            if not F.AuthLocked then
                checked(F.V1.Reset,"V1.Lock");checked(F.Wall.Stop,"Wall.Lock")
                checked(F.Aim2.Stop,"Aim2.Lock");checked(F.Mortar.Stop,"Mortar.Lock")
                _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0;F.AimLastClock=nil
                checked(g_masterahsanyt_ApplyiPadView,"Ipad.Lock")
            end
            F.AuthLocked=true
            if next(F.Aim2.Records) then checked(F.Aim2.Stop,"Aim2.LockRestore") end
            return
        end
        F.AuthLocked=false
        local world=g_masterahsanyt_ESPWorld()
        local pc=g_masterahsanyt_ESPGetController()
        local pawn=g_masterahsanyt_ESPGetLocalCharacter()
        if world~=F.LastWorld or pc~=F.LastPC or pawn~=F.LastPawn then
            if F.LastWorld~=nil and login.WelcomeUI then login.DestroyUI() end
            checked(F.V1.Reset,"V1.Reset")
            checked(F.Wall.Stop,"Wall.Reset")
            checked(F.Aim2.Stop,"Aim2.Reset")
            checked(F.Mortar.Stop,"Mortar.Reset")
            F.Wall.ConsoleWorld=nil
            _G.AimTouchVisCache={}
            _G.XthrlenState.offPitch=0;_G.XthrlenState.offYaw=0
            F.AimLastClock=nil
            F.V1Due=0;F.AimDue=0;F.IpadDue=0
            F.LastWorld,F.LastPC,F.LastPawn=world,pc,pawn
        end
        if F.V1.State.Canvas and not g_masterahsanyt_ESPValid(F.V1.State.Canvas) then checked(F.V1.Reset,"V1.CanvasReset");F.V1Due=0 end
        if not pc or not pawn then
            if F.Aim2.Player or next(F.Aim2.Records) then checked(F.Aim2.Stop,"Aim2.NoPlayer") end
            if F.Mortar.Player then checked(F.Mortar.Stop,"Mortar.NoPlayer") end
            if not F.V1Disabled then checked(F.V1.Reset,"V1.NoPlayer") end
            F.V1Disabled=true
            return
        end
        local o=_G.g_Botmater_ESPOptions
        local detail=o.Name or o.Line or o.Health or o.Distance
        local active=detail or o.EnemyCounter
        if not active then
            if not F.V1Disabled then checked(F.V1.Reset,"V1.Disable") end
            F.V1Disabled=true
        elseif now>=F.V1Due-0.000001 or (F.V1LastClock and now<F.V1LastClock) then
            F.V1Disabled=false
            checked(F.V1.Tick,"V1.Render")
            F.V1LastClock=now
            local interval=detail and (tonumber(_G.g_Botmater_MasterShotESP.UpdateInterval) or 1/60) or 0.05
            if interval~=interval or interval<=0 or math.abs(interval)==math.huge then interval=1/60 end
            F.V1Due=now+math.max(.001,interval)
            -- Equal render cadences share the V2 deadline, so adding V1 does
            -- not introduce a second phase of native render callbacks.
            local v2=_G.g_masterahsanyt_ESPOptions
            local detailedV2=_G.g_masterahsanyt_MasterShotESP.Enabled and (v2.Name or v2.Line or v2.Box or v2.Health or v2.Distance or v2.Skeleton)
            local shared=g_masterahsanyt_ESPRunnerToken.RenderDue
            if detail and detailedV2 and shared and shared>now and math.abs(interval-(tonumber(_G.g_masterahsanyt_MasterShotESP.UpdateInterval) or 1/60))<.000001 then F.V1Due=shared end
        end
        if F.Settings.Aim2Enabled and (now>=F.Aim2.Due-0.000001 or (F.Aim2.LastTime and now<F.Aim2.LastTime)) then
            checked(F.Aim2.Tick,"Aim2.Tick")
        elseif not F.Settings.Aim2Enabled and next(F.Aim2.Records) and now>=(F.Aim2RestoreDue or 0) then
            checked(F.Aim2.Stop,"Aim2.Restore")
            F.Aim2RestoreDue=now+0.5
        end
        if F.Settings.MortarEnabled and (now>=F.Mortar.Due-0.000001 or (F.Mortar.LastTime and now<F.Mortar.LastTime)) then checked(F.Mortar.Tick,"Mortar.Tick") end

        if F.Settings.AimEnabled then
            if now>=F.AimDue-0.000001 or (F.AimLastTick and now<F.AimLastTick) then
                checked(F.Aim.Tick,"Aim.Render")
                F.AimLastTick=now
                F.AimDue=now+((pawn and pawn.bIsWeaponFiring) and 0.011 or 0.05)
                if not (pawn and pawn.bIsWeaponFiring) then F.AimLastClock=nil end
            end
        end
        if F.Settings.WallEnabled then checked(F.Wall.Tick,"Wall.Tick",now,pawn,pc) end
        if _G.LexusConfig.IpadView and now>=F.IpadDue then
            checked(g_masterahsanyt_ApplyiPadView,"Ipad")
            F.IpadDue=now+0.5
        end
        if F.Dirty and now>=F.SaveDue then checked(F.Save,"Settings.Save");F.SaveDue=now+0.5 end
    end
    F.NextInterval=function(now)
        if not (_G.LunarLoginRuntime and _G.LunarLoginRuntime.Authorized) then return 0.50 end
        if not F.LastPC or not F.LastPawn then return 0.50 end
        local nextDelay=0.50
        local function due(deadline) nextDelay=math.min(nextDelay,math.max(0.001,(deadline or now)-now)) end
        local o=_G.g_Botmater_ESPOptions
        if o.Name or o.Line or o.Health or o.Distance or o.EnemyCounter then due(F.V1Due) end
        if F.Settings.AimEnabled then due(F.AimDue) end
        if F.Settings.Aim2Enabled then nextDelay=math.min(nextDelay,F.Aim2.NextInterval(now))
        elseif next(F.Aim2.Records) then due(F.Aim2RestoreDue) end
        if F.Settings.MortarEnabled then nextDelay=math.min(nextDelay,F.Mortar.NextInterval(now)) end
        if F.Settings.WallEnabled then due(F.Wall.LastTick+0.30);due(F.Wall.LastCleanup+F.Wall.CleanupInterval) end
        if _G.LexusConfig.IpadView then due(F.IpadDue) end
        if F.Dirty then due(F.SaveDue) end
        return nextDelay
    end
    F.Wake=function()
        if F.Token.Stopped then return end
        local login=_G.LunarLoginRuntime
        -- Login callbacks use this existing runner; do not wait for its idle deadline.
        if login and login.NeedsUpdate then F.LoginDue=0 end
        F.V1Due=0;F.AimDue=0
        if F.Aim2 then F.Aim2.Due=0 end
        if F.Mortar then F.Mortar.Due=0 end
        F.Wall.LastTick=-999
        local due=g_masterahsanyt_ESPRunnerToken.Due
        if not due or due-g_masterahsanyt_ESPNow()>0.002 then g_masterahsanyt_ESPSchedule(0.001) end
    end
end


-- Settings maintenance uses the working reference's native timer fallbacks.
local g_masterahsanyt_FastRunnerToken = {}
local previousSettingsRunner = _G.__MasterShotFastRunner
if type(previousSettingsRunner) == "table" and previousSettingsRunner.Timer and previousSettingsRunner.Owner then
    pcall(function() previousSettingsRunner.Owner:RemoveGameTimer(previousSettingsRunner.Timer) end)
end
_G.__MasterShotFastRunner = g_masterahsanyt_FastRunnerToken
local function g_masterahsanyt_FastTick()
    if _G.__MasterShotFastRunner ~= g_masterahsanyt_FastRunnerToken then return end
    g_masterahsanyt_EnsureHackMenu()
    local render=_G.__MasterShotESPRunner
    if not render or not render.Due then pcall(g_masterahsanyt_ApplyiPadView) end
end
do
    local token = g_masterahsanyt_FastRunnerToken
    local function member(object, key)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[key] end)
        if ok then return value end
    end
    local function valid(object)
        if object == nil then return false end
        if slua and type(slua.isValid) == "function" then
            local ok, value = pcall(slua.isValid, object)
            return ok and value == true
        end
        return false
    end
    local function timerOwnerReady(owner)
        return owner ~= nil and (owner == Game or valid(owner) or valid(member(owner, "Object")))
    end
    local function callback()
        if _G.__MasterShotFastRunner ~= token then
            if token.Timer and token.Owner then pcall(function() token.Owner:RemoveGameTimer(token.Timer) end) end
            token.Timer = nil
            return
        end
        g_masterahsanyt_FastTick()
        g_masterahsanyt_StartSettingsMaintenance()
    end
    g_masterahsanyt_StartSettingsMaintenance = function(owner)
        if _G.__MasterShotFastRunner ~= token then return false end
        if token.Pending then return true end
        if token.Timer and (token.Provider == "ticker" or timerOwnerReady(token.Owner)) then return true end
        if token.Timer and token.Owner then pcall(function() token.Owner:RemoveGameTimer(token.Timer) end) end
        token.Timer, token.Owner, token.Provider = nil, nil, nil

        local candidates = {}
        local function add(candidate, kind)
            if not timerOwnerReady(candidate) or type(member(candidate, "AddGameTimer")) ~= "function" then return end
            for _, entry in ipairs(candidates) do if entry.Object == candidate then return end end
            candidates[#candidates + 1] = {Object = candidate, Kind = kind}
        end
        local pc
        pcall(function() if GameplayData.GetPlayerController then pc = GameplayData.GetPlayerController() end end)
        if not valid(pc) then pcall(function() if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end end) end
        add(pc, "controller")
        add(owner, "character")
        add(Game, "game")
        for _, entry in ipairs(candidates) do
            local ok, timer = pcall(function() return entry.Object:AddGameTimer(1.0, true, callback) end)
            if ok and timer then
                token.Timer, token.Owner, token.Provider = timer, entry.Object, entry.Kind
                token.LastError = nil
                g_masterahsanyt_FastTick()
                return true
            end
        end
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker then
            if type(ticker.AddTimer) == "function" then
                local ok, timer = pcall(ticker.AddTimer, 1.0, true, callback)
                if ok and timer then
                    token.Timer, token.Owner, token.Provider = timer, ticker, "ticker"
                    token.LastError = nil
                    return true
                end
            end
            if type(ticker.AddTimerOnce) == "function" then
                token.Pending, token.Provider = true, "ticker_once"
                local ok, accepted = pcall(ticker.AddTimerOnce, 1.0, function()
                    token.Pending = false
                    callback()
                end)
                if ok and accepted ~= false then token.LastError = nil; return true end
                token.Pending, token.Provider = false, nil
                token.LastError = tostring(accepted)
            else token.LastError = "SETTINGS_TIMER_API_UNAVAILABLE" end
        else
            if package and package.loaded and type(package.loaded["common.time_ticker"]) ~= "table" then
                package.loaded["common.time_ticker"] = nil
            end
            token.LastError = tostring(ticker)
        end
        return false
    end
end


g_masterahsanyt_EnsureHackMenu()
if _G.LunarLoginRuntime then _G.LunarLoginRuntime.NeedsUpdate=true;_G.LunarLoginRuntime.BindSettingsPath(_G.LunarFeatures.SettingsReadPath) end
g_masterahsanyt_FastTick()
g_masterahsanyt_StartSettingsMaintenance()
g_masterahsanyt_ShotESP.Running=true
g_masterahsanyt_ESPTick()
end
local ok,startError=pcall(startBaselineHacks)
if not ok then
    _G.LunarOptionalStartupError=tostring(startError)
    if _G.LunarFeatures and _G.LunarFeatures.Error then _G.LunarFeatures.Error("Startup",startError) end
end
return originalExport
