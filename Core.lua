-- EditModeAnchors: Precise anchor point control for Edit Mode frames
-- TESTING INSTRUCTIONS:
-- 1. /ema debug  -> enables verbose logging
-- 2. Enter Edit Mode, select any frame
-- 3. The "Anchor Override" section appears below the native settings dialog
-- 4. Change any value -> frame repositions immediately
-- 5. Check chat for [EMA] logs showing anchorInfo before/after
-- 6. Click "Save Changes" in Edit Mode
-- 7. /reload
-- 8. Re-enter Edit Mode, select the same frame
-- 9. Check if your custom anchor values persisted in the dropdowns/sliders
-- 10. If values reverted to TOPLEFT/UIParent after reload, then C_EditMode.SaveLayouts
--     strips custom relativeTo values and we need to add SavedVariables as a backup.

local _, ns = ...
local LEM = ns.LibEditMode

-------------------------------------------------------------------------------
-- Debug Logging
-------------------------------------------------------------------------------
local debugEnabled = false

local function Log(msg, ...)
	if not debugEnabled then return end
	local formatted = msg
	if select("#", ...) > 0 then
		formatted = string.format(msg, ...)
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[EMA]|r " .. formatted)
end

SLASH_HYPEREDITMODEEMA1 = "/ema"
SlashCmdList["HYPEREDITMODEEMA"] = function(msg)
	local cmd = strtrim(msg):lower()
	if cmd == "debug" then
		debugEnabled = not debugEnabled
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[EMA]|r Debug logging " .. (debugEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[EMA]|r EditModeAnchors commands:")
		DEFAULT_CHAT_FRAME:AddMessage("  /ema debug  - Toggle debug logging")
	end
end

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
local ANCHOR_POINTS = {
	"TOPLEFT", "TOP", "TOPRIGHT",
	"LEFT", "CENTER", "RIGHT",
	"BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}

-- Build dropdown-compatible values table for anchor points
local function BuildAnchorPointValues()
	local values = {}
	for _, point in ipairs(ANCHOR_POINTS) do
		table.insert(values, { text = point, value = point })
	end
	return values
end

-- Build a dynamic dropdown list of all named frames available as anchor targets.
-- This is called as a function each time the dropdown opens, so the list stays fresh.
local function BuildFrameNameValues()
	local values = {}
	local seen = {}

	-- Always include UIParent as the first option
	table.insert(values, { text = "UIParent", value = "UIParent" })
	seen["UIParent"] = true

	-- Collect all registered Edit Mode system frames
	if EditModeManagerFrame and EditModeManagerFrame.registeredSystemFrames then
		for _, systemFrame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
			local name = systemFrame:GetName()
			if name and not seen[name] then
				table.insert(values, { text = name, value = name })
				seen[name] = true
			end
		end
	end

	-- Sort alphabetically (UIParent will sort to the end, but that's fine for consistency)
	table.sort(values, function(a, b) return a.text < b.text end)
	return values
end

-------------------------------------------------------------------------------
-- System Frame Helpers
-------------------------------------------------------------------------------

-- Resolve a system frame from system ID + optional sub-system index.
local function GetSystemFrame(systemID, subSystemID)
	if not EditModeManagerFrame then return nil end
	return EditModeManagerFrame:GetRegisteredSystemFrame(systemID, subSystemID)
end

-- Read the anchorInfo from a system frame's current layout data.
local function GetAnchorInfo(systemFrame)
	if systemFrame and systemFrame.systemInfo and systemFrame.systemInfo.anchorInfo then
		return systemFrame.systemInfo.anchorInfo
	end
	return nil
end

-- Apply an anchor override: write to anchorInfo, reposition the frame, mark dirty.
local function ApplyAnchorOverride(systemFrame, point, relativeTo, relativePoint, offsetX, offsetY)
	if not systemFrame or not systemFrame.systemInfo then
		Log("ApplyAnchorOverride: no systemFrame or systemInfo!")
		return
	end

	local info = systemFrame.systemInfo.anchorInfo
	if not info then
		Log("ApplyAnchorOverride: no anchorInfo on systemFrame!")
		return
	end

	Log("ApplyAnchorOverride BEFORE: point=%s relativeTo=%s relativePoint=%s offsetX=%.1f offsetY=%.1f",
		tostring(info.point), tostring(info.relativeTo), tostring(info.relativePoint),
		tonumber(info.offsetX) or 0, tonumber(info.offsetY) or 0)

	-- Write new values
	info.point = point
	info.relativeTo = relativeTo
	info.relativePoint = relativePoint
	info.offsetX = offsetX
	info.offsetY = offsetY

	-- Mark as no longer in default position
	systemFrame.systemInfo.isInDefaultPosition = false

	-- Clear secondary anchor if present (we're setting a single explicit anchor)
	systemFrame.systemInfo.anchorInfo2 = nil

	Log("ApplyAnchorOverride AFTER: point=%s relativeTo=%s relativePoint=%s offsetX=%.1f offsetY=%.1f",
		tostring(info.point), tostring(info.relativeTo), tostring(info.relativePoint),
		tonumber(info.offsetX) or 0, tonumber(info.offsetY) or 0)

	-- Reposition the frame using Blizzard's own method
	-- ApplySystemAnchor reads from anchorInfo and calls SetPoint
	local ok, err = pcall(function()
		systemFrame:ApplySystemAnchor()
	end)

	if ok then
		Log("ApplyAnchorOverride: ApplySystemAnchor() succeeded")
	else
		Log("ApplyAnchorOverride: ApplySystemAnchor() FAILED: %s", tostring(err))
	end

	-- Mark the system as having active (unsaved) changes
	systemFrame:SetHasActiveChanges(true)

	-- Update the native settings dialog if it's showing this system
	if EditModeSystemSettingsDialog and EditModeSystemSettingsDialog.attachedToSystem == systemFrame then
		EditModeSystemSettingsDialog:UpdateDialog(systemFrame)
	end
end

-------------------------------------------------------------------------------
-- Setting Builders
-- For each system, we create an identical set of anchor-override settings.
-- The closures capture systemID/subSystemID so they know which frame to target.
-------------------------------------------------------------------------------

local function CreateAnchorSettings(systemID, subSystemID)
	return {
		-- Divider / header
		{
			kind = LEM.SettingType.Divider,
			name = "Anchor Override",
			default = nil,
			get = function() end,
			set = function() end,
		},

		-- Anchor Point (this frame's point)
		{
			kind = LEM.SettingType.Dropdown,
			name = "Point",
			desc = "The anchor point on this frame",
			default = "TOPLEFT",
			values = BuildAnchorPointValues,
			get = function(layoutName)
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					Log("GET Point: system=%s sub=%s -> %s", tostring(systemID), tostring(subSystemID), tostring(info.point))
					return info.point
				end
				return "TOPLEFT"
			end,
			set = function(layoutName, value, fromReset)
				Log("SET Point: system=%s sub=%s -> %s", tostring(systemID), tostring(subSystemID), tostring(value))
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					ApplyAnchorOverride(frame, value, info.relativeTo, info.relativePoint, info.offsetX, info.offsetY)
				end
			end,
		},

		-- Relative To (target frame name)
		{
			kind = LEM.SettingType.Dropdown,
			name = "Relative To",
			desc = "The frame to anchor to",
			default = "UIParent",
			height = 400,
			values = BuildFrameNameValues,
			get = function(layoutName)
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					Log("GET RelativeTo: system=%s sub=%s -> %s", tostring(systemID), tostring(subSystemID), tostring(info.relativeTo))
					return info.relativeTo
				end
				return "UIParent"
			end,
			set = function(layoutName, value, fromReset)
				Log("SET RelativeTo: system=%s sub=%s -> %s", tostring(systemID), tostring(subSystemID), tostring(value))
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					ApplyAnchorOverride(frame, info.point, value, info.relativePoint, info.offsetX, info.offsetY)
				end
			end,
		},

		-- Relative Point (point on the target frame)
		{
			kind = LEM.SettingType.Dropdown,
			name = "Relative Point",
			desc = "The anchor point on the target frame",
			default = "TOPLEFT",
			values = BuildAnchorPointValues,
			get = function(layoutName)
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					Log("GET RelativePoint: system=%s sub=%s -> %s", tostring(systemID), tostring(subSystemID), tostring(info.relativePoint))
					return info.relativePoint
				end
				return "TOPLEFT"
			end,
			set = function(layoutName, value, fromReset)
				Log("SET RelativePoint: system=%s sub=%s -> %s", tostring(systemID), tostring(subSystemID), tostring(value))
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					ApplyAnchorOverride(frame, info.point, info.relativeTo, value, info.offsetX, info.offsetY)
				end
			end,
		},

		-- Offset X slider
		{
			kind = LEM.SettingType.Slider,
			name = "Offset X",
			desc = "Horizontal offset from the anchor point (raw, before scale)",
			default = 0,
			minValue = -2000,
			maxValue = 2000,
			valueStep = 1,
			get = function(layoutName)
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					local val = math.floor(info.offsetX + 0.5)
					Log("GET OffsetX: system=%s sub=%s -> %d", tostring(systemID), tostring(subSystemID), val)
					return val
				end
				return 0
			end,
			set = function(layoutName, value, fromReset)
				Log("SET OffsetX: system=%s sub=%s -> %s", tostring(systemID), tostring(subSystemID), tostring(value))
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					ApplyAnchorOverride(frame, info.point, info.relativeTo, info.relativePoint, value, info.offsetY)
				end
			end,
		},

		-- Offset Y slider
		{
			kind = LEM.SettingType.Slider,
			name = "Offset Y",
			desc = "Vertical offset from the anchor point (raw, before scale)",
			default = 0,
			minValue = -2000,
			maxValue = 2000,
			valueStep = 1,
			get = function(layoutName)
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					local val = math.floor(info.offsetY + 0.5)
					Log("GET OffsetY: system=%s sub=%s -> %d", tostring(systemID), tostring(subSystemID), val)
					return val
				end
				return 0
			end,
			set = function(layoutName, value, fromReset)
				Log("SET OffsetY: system=%s sub=%s -> %s", tostring(systemID), tostring(subSystemID), tostring(value))
				local frame = GetSystemFrame(systemID, subSystemID)
				local info = GetAnchorInfo(frame)
				if info then
					ApplyAnchorOverride(frame, info.point, info.relativeTo, info.relativePoint, info.offsetX, value)
				end
			end,
		},
	}
end

-------------------------------------------------------------------------------
-- Register Settings for All Edit Mode Systems
-------------------------------------------------------------------------------

-- Helper: safely register settings for a system, guarding against nil enums
-- on older clients where some systems may not exist yet.
local function SafeRegister(systemID, subSystemID)
	if systemID == nil then return end
	local settings = CreateAnchorSettings(systemID, subSystemID)
	LEM:AddSystemSettings(systemID, settings, subSystemID)
	Log("Registered anchor settings for system=%s sub=%s", tostring(systemID), tostring(subSystemID))
end

-- Helper: iterate an Enum table's values and register each as a sub-system.
local function RegisterSubSystems(systemID, indicesEnum)
	if not indicesEnum then return end
	for name, index in pairs(indicesEnum) do
		if type(index) == "number" then
			SafeRegister(systemID, index)
		end
	end
end

-- Systems that have sub-system indices
local function RegisterSystemsWithIndices()
	-- ActionBars have multiple sub-bars
	if Enum.EditModeActionBarSystemIndices then
		RegisterSubSystems(Enum.EditModeSystem.ActionBar, Enum.EditModeActionBarSystemIndices)
	end

	-- UnitFrames have Player, Target, Focus, Party, Raid, Boss, Arena, Pet
	if Enum.EditModeUnitFrameSystemIndices then
		RegisterSubSystems(Enum.EditModeSystem.UnitFrame, Enum.EditModeUnitFrameSystemIndices)
	end

	if Enum.EditModeCooldownViewerSystemIndices then
		RegisterSubSystems(Enum.EditModeSystem.CooldownViewer, Enum.EditModeCooldownViewerSystemIndices)
	end

	if Enum.EditModeEncounterEventsSystemIndices then
		RegisterSubSystems(Enum.EditModeSystem.EncounterEvents, Enum.EditModeEncounterEventsSystemIndices)
	end

	if Enum.EditModeAuraFrameSystemIndices then
		RegisterSubSystems(Enum.EditModeSystem.AuraFrame, Enum.EditModeAuraFrameSystemIndices)
	end

	if Enum.EditModeStatusTrackingBarSystemIndices then
		RegisterSubSystems(Enum.EditModeSystem.StatusTrackingBar, Enum.EditModeStatusTrackingBarSystemIndices)
	end
end

-- Simple systems (no sub-indices) -- register with subSystemID = nil
local function RegisterSimpleSystems()
	local simpleSystems = {
		Enum.EditModeSystem.CastBar,
		Enum.EditModeSystem.Minimap,
		Enum.EditModeSystem.EncounterBar,
		Enum.EditModeSystem.ExtraAbilities,
		Enum.EditModeSystem.TalkingHeadFrame,
		Enum.EditModeSystem.ChatFrame,
		Enum.EditModeSystem.VehicleLeaveButton,
		Enum.EditModeSystem.LootFrame,
		Enum.EditModeSystem.HudTooltip,
		Enum.EditModeSystem.ObjectiveTracker,
		Enum.EditModeSystem.MicroMenu,
		Enum.EditModeSystem.Bags,
		Enum.EditModeSystem.DurabilityFrame,
		Enum.EditModeSystem.TimerBars,
		Enum.EditModeSystem.VehicleSeatIndicator,
		Enum.EditModeSystem.ArchaeologyBar,
		Enum.EditModeSystem.PersonalResourceDisplay,
		Enum.EditModeSystem.DamageMeter
	}

	for _, systemID in ipairs(simpleSystems) do
		SafeRegister(systemID, nil)
	end
end

-- StatusTrackingBar is a special case -- it has sub-indices but they may not
-- be in a dedicated Enum table. Handle it by checking registered frames.
local function RegisterStatusTrackingBars()
	local systemID = Enum.EditModeSystem.StatusTrackingBar
	if not systemID then return end

	-- Check if there's a dedicated enum for sub-indices
	if Enum.EditModeStatusTrackingBarSystemIndices then
		RegisterSubSystems(systemID, Enum.EditModeStatusTrackingBarSystemIndices)
	else
		-- Fall back: register for known indices (0 = main bar, 1 = secondary bar)
		SafeRegister(systemID, 0)
		SafeRegister(systemID, 1)
	end
end

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

-- Register everything on addon load.
-- LibEditMode handles the timing -- it will only show the extension panel
-- when Edit Mode is active and a system frame is selected.
RegisterSystemsWithIndices()
RegisterSimpleSystems()
RegisterStatusTrackingBars()

Log("EditModeAnchors loaded. Type /ema debug to enable debug logging.")
