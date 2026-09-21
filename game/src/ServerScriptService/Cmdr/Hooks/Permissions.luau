local Rep = game:GetService("ReplicatedStorage")
local GeneralConfig = require(Rep.Configuration.General)

return function (registry)
	registry:RegisterHook("BeforeRun", function (context)
		local userId = context.Executor.UserId
		local isAdmin = table.find(GeneralConfig.Admins, userId)
		local isAdminCommand = 	context.Group == "Admin"
		if not isAdmin or (isAdminCommand and not isAdmin) then return "You can't execute this command." end
	end)
end