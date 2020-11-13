local mod = get_mod("teleport")

mod.predefined_locations = require("scripts/mods/teleport/predefined_locations")

local _SAVED_LOCATION_SETTING_NAME = "saved_locations"

mod.saved_locations = mod:get(_SAVED_LOCATION_SETTING_NAME) or {}

local function can_access_player_position()
	return Managers and Managers.state and Managers.state.game_mode
		and (
			Managers.state.game_mode:game_mode_key() == "inn"
			or Managers.state.game_mode:game_mode_key() == "adventure"
			or Managers.state.game_mode:game_mode_key() == "survival"
		)
end

local function get_locations_object(custom)
	local level = Managers.state.game_mode:level_key()

	if custom then
		if mod.saved_locations[level] == nil then
			mod.saved_locations[level] = {}
		end
		return mod.saved_locations[level]
	else
		return mod.predefined_locations[level]
	end
end

local function set_saved_location(name, loc)
	get_locations_object(true)[name] = loc
	mod.set(mod, _SAVED_LOCATION_SETTING_NAME, mod.saved_locations)
end

-- Save Vector3 position and rotation objects as a location object
local function save_location(name, pos, rot)
	if type(name) ~= "string" then
		pos = name
		name = "default"
	end

	if pos == nil then
		mod:echo("ERROR: Invalid parameter for 'save_location'")
	end

	local rot_x, rot_y, rot_z, rot_w = Quaternion.to_elements(rot)

	local loc = {
		pos = {
			x = pos.x,
			y = pos.y,
			z = pos.z,
		},
		rot = {
			x = rot_x,
			y = rot_y,
			z = rot_z,
			w = rot_w,
		},
	}

	set_saved_location(name, loc)
end

local function verify_location_name(name)
	if name == nil or type(name) ~= "string" or name == "" then
		return "default"
	else
		return (name:gsub("^%s*(.-)%s*$", "%1"))
	end
end

local function get_location(name)
	name = verify_location_name(name)

	-- Custom locations have higher priority, therefore may override predefined ones
	local loc = get_locations_object(true)[name] or get_locations_object(false)[name]

	if loc == nil then
		return nil
	else
		return {
			name = name,
			pos = Vector3(loc.pos.x, loc.pos.y, loc.pos.z),
			rot = Quaternion.from_elements(loc.rot.x, loc.rot.y, loc.rot.z, loc.rot.w),
		}
	end
end

local function format_location(loc, show_rotation)
	local str = string.format("%s: X: %.2f, Y: %.2f, Z: %.2f", loc.name, loc.pos.x, loc.pos.y, loc.pos.z)

	if show_rotation then
		str = str .. string.format(", Rot: X: %.2f, Y: %.2f, Z: %.2f, W: %.2f", Quaternion.to_elements(loc.rot))
	end

	return str
end

local function show_command_help()
	mod:echo(
		"info:\n"..
		"usage teleport: Save or load current player location\n"..
		-- In-game chat does not use a monospaced font and tab characters don't work
		"help                  Show this help message\n"..
		"list                     List saved locations (Alias: ls)\n"..
		"[name]              Teleport to saved or predefined loction\n"..
		"\t                        (Alias: t, teleport)\n"..
		"save [name]    Save current location (Alias: s)\n"..
		"show [name]   Print location coordinates\n"..
		"delete [name]  Delete saved location (Alias: d)"
	)
end

local function save_current_location(name)
	if not can_access_player_position() then
		mod:echo("Error: Can't access player location right now.")
		return
	end

	name = verify_location_name(name)

	local player_unit = Managers.player:local_player().player_unit
	save_location(name, Unit.local_position(player_unit, 0), Unit.local_rotation(player_unit, 0))

	mod:echo("info: Saved current location as '%s'", name)
end

local function show_saved_location(name, dump)
	name = verify_location_name(name)
	local loc

	if name == "current" then
		if not can_access_player_position() then
			mod:echo("ERROR: Can't access player location right now.")
			return
		end

		local player_unit = Managers.player:local_player().player_unit
		loc = {
			name = "Current",
			pos = Unit.local_position(player_unit, 0),
			rot = Unit.local_rotation(player_unit, 0),
		}
	else
		loc = get_location(name)
	end

	if loc == nil then
		mod:echo("info: No location saved for '%s'.", name)
	else
		mod:echo(format_location(loc, dump))
	end
end

local function teleport_player(name, y, z)
	if not can_access_player_position() then
		mod:echo("ERROR: Can't access player location right now.")
		return
	end

	local player_unit = Managers.player:local_player().player_unit
	local locomotion_extension = ScriptUnit.extension(player_unit, "locomotion_system")

	if y ~= nil and z ~= nil then
		local x = tonumber(name)
		y = tonumber(y)
		z = tonumber(z)

		locomotion_extension:teleport_to(Vector3(x, y, z), Unit.local_rotation(player_unit, 0))
		mod:echo("info: Teleported to specified location")
	else
		name = verify_location_name(name)
		local loc = get_location(name)
		if loc == nil then
			mod:echo("ERROR: No location '%s' to teleport to.", name)
		else
			locomotion_extension:teleport_to(loc.pos, loc.rot or Unit.local_rotation(player_unit, 0))
			mod:echo("info: Teleported to '%s'", name)
		end
	end
end

local function show_available_locations()
	local str = "Saved locations:\nPredefined:\n"
	for name in pairs(get_locations_object(false)) do
		str = str .. format_location(get_location(name)) .. "\n"
	end
	str = str .. "\nCustom:\n"
	for name in pairs(get_locations_object(true)) do
		str = str .. format_location(get_location(name)) .. "\n"
	end
	mod:echo(str)
end

local function delete_saved_location(name)
	name = verify_location_name(name)

	set_saved_location(name, nil)
	mod:echo("info: Successfully deleted location '%s'", name)
end

local function tp_command(action, ...)
	-- Default action
	if action == nil then
		action = "help"
	end

	if action == "help" then show_command_help()
	-- elseif action == "cursor" then local function show_position_under_cursor()
	elseif action == "ls" or action == "list" then show_available_locations()
	elseif action == "show" then show_saved_location(...)
	elseif action == "s" or action == "save" then save_current_location(...)
	elseif action == "t" or action == "teleport" then teleport_player(...)
	elseif action == "d" or action == "delete" then delete_saved_location(...)
	else
		teleport_player(action, ...)
	end
end

mod:command("teleport", "Save or load current player location", tp_command)
mod:command("tp", "Save or load current player location", tp_command)
