local AdminConfig = {}

AdminConfig.AUTHORIZED_IDS = {
	8866841971,
	10599282502,
	8630893989,
}

function AdminConfig.isAdmin(player)
	local uid = player.UserId
	for _, id in ipairs(AdminConfig.AUTHORIZED_IDS) do
		if uid == id then return true end
	end
	return false
end

return AdminConfig
