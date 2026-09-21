local ServerScriptService = game:GetService("ServerScriptService")

local CmdrModule = require(ServerScriptService.Packages.Cmdr)
local CmdrFolder = ServerScriptService.Cmdr

local Commands = CmdrFolder.Commands
local Hooks = CmdrFolder.Hooks
local Types = CmdrFolder.Types

local m = {}
function m:init()
	CmdrModule:RegisterDefaultCommands()
	
	CmdrModule:RegisterCommandsIn(Commands)
	CmdrModule:RegisterHooksIn(Hooks)
	CmdrModule:RegisterTypesIn(Types)
end
return m

