--==================================================
-- CHICKEN ROLL CONFIG
-- Ordered list of all 50 chickens, weakest/common (#1) to
-- strongest/rarest (#50). "chance" is DISPLAY TEXT ONLY —
-- ChickenRollService does not use it to calculate real odds,
-- it only picks randomly within the player's Luck-based
-- progression window. Do not change this text.
--==================================================

local ChickenRollConfig = {}

ChickenRollConfig.RollSpeed = {
	Normal = 3.2,
	Fast = 0.8,
}

-- Above this many owned chickens, the worst one (by rarity rank,
-- lowest first) gets auto-deleted on the next roll. Keeps saved
-- data from growing unbounded over long AFK sessions.
ChickenRollConfig.MaxInventorySize = 30

-- "icon" is the rbxassetid:// (or rbxthumb://) image used by the roll
-- animation (RollClient). Left blank for now — fill these in with your
-- real chicken decal/image asset ids. Until filled, the animation will
-- just render an empty image for that chicken (no error).

ChickenRollConfig.Chickens = {
	{ name = "Brown Chicken",       chance = "1 in 2",                        icon = "rbxassetid://108651448672722" },
	{ name = "White Chicken",       chance = "1 in 4",                        icon = "rbxassetid://102174138576627" },
	{ name = "Spotted Chicken",     chance = "1 in 8",                        icon = "rbxassetid://125682854832092" },
	{ name = "Black Chicken",       chance = "1 in 15",                       icon = "rbxassetid://97344788003883" },
	{ name = "Red Chicken",         chance = "1 in 30",                       icon = "rbxassetid://76694344491462" },
	{ name = "Blue Chicken",        chance = "1 in 60",                       icon = "rbxassetid://140725341641457" }, -- placeholder, same as Green for now (confirmed OK to reuse until real art)
	{ name = "Green Chicken",       chance = "1 in 120",                      icon = "rbxassetid://140725341641457" }, -- placeholder, same as Blue for now (confirmed OK to reuse until real art)
	{ name = "Pink Chicken",        chance = "1 in 250",                      icon = "rbxassetid://98787682722430" },
	{ name = "Silver Chicken",      chance = "1 in 500",                      icon = "" },
	{ name = "Golden Chicken",      chance = "1 in 1,000",                    icon = "rbxassetid://114301394838158" },
	{ name = "Emerald Chicken",     chance = "1 in 2,000",                    icon = "" },
	{ name = "Lapis Chicken",       chance = "1 in 4,000",                    icon = "" },
	{ name = "Ruby Chicken",        chance = "1 in 8,000",                    icon = "" },
	{ name = "Diamond Chicken",     chance = "1 in 15,000",                   icon = "" },
	{ name = "Crystal Chicken",     chance = "1 in 30,000",                   icon = "" },
	{ name = "Obsidian Chicken",    chance = "1 in 50,000",                   icon = "" },
	{ name = "Magma Chicken",       chance = "1 in 75,000",                   icon = "" },
	{ name = "Ice Chicken",         chance = "1 in 100,000",                  icon = "" },
	{ name = "Storm Chicken",       chance = "1 in 150,000",                  icon = "" },
	{ name = "Toxic Chicken",       chance = "1 in 250,000",                  icon = "" },
	{ name = "Shadow Chicken",      chance = "1 in 500,000",                  icon = "" },
	{ name = "Light Chicken",       chance = "1 in 750,000",                  icon = "" },
	{ name = "Phantom Chicken",     chance = "1 in 1,000,000",                icon = "" },
	{ name = "Spirit Chicken",      chance = "1 in 2,000,000",                icon = "" },
	{ name = "Void Chicken",        chance = "1 in 5,000,000",                icon = "" },
	{ name = "Galaxy Chicken",      chance = "1 in 10,000,000",               icon = "" },
	{ name = "Nebula Chicken",      chance = "1 in 20,000,000",               icon = "" },
	{ name = "Solar Chicken",       chance = "1 in 35,000,000",               icon = "" },
	{ name = "Lunar Chicken",       chance = "1 in 50,000,000",               icon = "" },
	{ name = "Eclipse Chicken",     chance = "1 in 75,000,000",               icon = "" },
	{ name = "Comet Chicken",       chance = "1 in 100,000,000",              icon = "" },
	{ name = "Meteor Chicken",      chance = "1 in 150,000,000",              icon = "" },
	{ name = "Plasma Chicken",      chance = "1 in 250,000,000",              icon = "" },
	{ name = "Quantum Chicken",     chance = "1 in 500,000,000",              icon = "" },
	{ name = "Cosmic Chicken",      chance = "1 in 750,000,000",              icon = "" },
	{ name = "Celestial Chicken",   chance = "1 in 1,000,000,000",            icon = "" },
	{ name = "Ancient Chicken",     chance = "1 in 2,000,000,000",            icon = "" },
	{ name = "Mythic Chicken",      chance = "1 in 5,000,000,000",            icon = "" },
	{ name = "Divine Chicken",      chance = "1 in 10,000,000,000",           icon = "" },
	{ name = "Ethereal Chicken",    chance = "1 in 20,000,000,000",           icon = "" },
	{ name = "Infinity Chicken",    chance = "1 in 50,000,000,000",           icon = "" },
	{ name = "Omega Chicken",       chance = "1 in 100,000,000,000",          icon = "" },
	{ name = "Glitched Chicken",    chance = "1 in 250,000,000,000",          icon = "" },
	{ name = "Corrupted Chicken",   chance = "1 in 500,000,000,000",          icon = "" },
	{ name = "Reality Chicken",     chance = "1 in 1,000,000,000,000",        icon = "" },
	{ name = "Timekeeper Chicken",  chance = "1 in 2,500,000,000,000",        icon = "" },
	{ name = "Singularity Chicken", chance = "1 in 5,000,000,000,000",        icon = "" },
	{ name = "Creator Chicken",     chance = "1 in 10,000,000,000,000",       icon = "" },
	{ name = "Almighty Chicken",    chance = "1 in 50,000,000,000,000",       icon = "" },
	{ name = "The Chicken",         chance = "1 in 100,000,000,000,000",      icon = "" },
}

return ChickenRollConfig