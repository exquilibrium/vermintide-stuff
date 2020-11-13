return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`teleport` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("teleport", {
			mod_script       = "scripts/mods/teleport/teleport",
			mod_data         = "scripts/mods/teleport/teleport_data",
			mod_localization = "scripts/mods/teleport/teleport_localization",
		})
	end,
	packages = {
		"resource_packages/teleport/teleport",
	},
}
