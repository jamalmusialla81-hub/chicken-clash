--[[ GoldenChickenAnimationSpecs (editor-only)
	Declarative pose specs for every required Golden Chicken production animation, consumed by
	GoldenChickenAnimationAuthoring.Build. Values were chosen from the joint manifest's safe rotation
	ranges and the animation quality doctrine (torso leads, legs/wings follow, head fourth, tail/crown/
	halo last; anticipation before force, compressed impact, follow-through, recovery). Sign polarity per
	joint was spot-checked with screenshots as each animation was authored, not assumed from calibration
	alone (see calibration_report.json for the shared axis mapping that IS proven rig-wide). ]]

local Authoring = require(game.ReplicatedStorage.ChickenClash.GoldenChickenAnimationAuthoring)
local L = Authoring.Local
local M = Authoring.MirrorLocal

local Specs = {}

-- convenience: build a Joints table where the right side mirrors the left side automatically.
local function bilateral(leftJoints)
	local out = {}
	for name, cf in pairs(leftJoints) do
		out[name] = cf
	end
	return out
end

--============================== IDLE ==============================--
Specs.Idle = {
	Name = "GoldenChicken_Idle",
	FPS = 24,
	Loop = true,
	Priority = Enum.AnimationPriority.Idle,
	Keys = {
		[0] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4, 0, 0), Neck = L(2, 0, 0), Head = L(-4, 0, 0),
			LeftWingUpper = L(4, 6, 6), RightWingUpper = M(4, 6, 6),
			Tail = L(2, 0, 0), Comb = L(2,0,0), Halo = L(0,0,0),
		}},
		[24] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(5, 0, 0), Chest = L(7, 0, 0), Neck = L(3, 0, 0), Head = L(-3, 0, 0),
			LeftWingUpper = L(5, 7, 7), RightWingUpper = M(5, 7, 7),
			Tail = L(3, 0, 0), Comb = L(3,0,0), Halo = L(0,0,0),
		}},
		[48] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4, 0, 0), Neck = L(4, 8, 0), Head = L(-2, 14, 0),
			LeftWingUpper = L(6, 10, 4), RightWingUpper = M(2, 4, 8),
			Tail = L(4, -3, 0), Comb = L(2,0,0), Halo = L(0,0,0),
		}},
		[72] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4, 0, 0), Neck = L(2, 2, 0), Head = L(-4, 3, 0),
			LeftWingUpper = L(4, 6, 6), RightWingUpper = M(4, 6, 6),
			Tail = L(2, 0, 0), Comb = L(2,0,0), Halo = L(0,0,0),
		}},
		[96] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4, 0, 0), Neck = L(2, 0, 0), Head = L(-4, 0, 0),
			LeftWingUpper = L(4, 6, 6), RightWingUpper = M(4, 6, 6),
			Tail = L(2, 0, 0), Comb = L(2,0,0), Halo = L(0,0,0),
		}},
	},
}

--============================== WALK ==============================--
Specs.Walk = {
	Name = "GoldenChicken_Walk",
	FPS = 24,
	Loop = true,
	Priority = Enum.AnimationPriority.Movement,
	Keys = {
		[0] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(2, 0, -2), Chest = L(3, 0, 0),
			LeftUpperLeg = L(-22, 0, 0), LeftLowerLeg = L(10, 0, 0), LeftFoot = L(8, 0, 0),
			RightUpperLeg = L(20, 0, 0), RightLowerLeg = L(-6, 0, 0), RightFoot = L(-4, 0, 0),
			LeftWingUpper = L(2, 0, -8), RightWingUpper = L(2, 0, 8),
			Head = L(-2,0,0), Tail = L(2,4,0),
		}, Markers = {{Name="LeftFootstep", Value="Walk"}}},
		[3] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(1, 0, 0), Chest = L(2, 0, 0),
			LeftUpperLeg = L(-10, 0, 0), LeftLowerLeg = L(20, 0, 0), LeftFoot = L(4, 0, 0),
			RightUpperLeg = L(10, 0, 0), RightLowerLeg = L(-4, 0, 0), RightFoot = L(2, 0, 0),
			LeftWingUpper = L(2, 0, -4), RightWingUpper = L(2, 0, 4),
			Head = L(-2,0,0), Tail = L(1,2,0),
		}},
		[6] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(0, 0, 0), Chest = L(1, 0, 0),
			LeftUpperLeg = L(0, 0, 0), LeftLowerLeg = L(8, 0, 0), LeftFoot = L(0, 0, 0),
			RightUpperLeg = L(0, 0, 0), RightLowerLeg = L(0, 0, 0), RightFoot = L(0, 0, 0),
			LeftWingUpper = L(2, 0, 0), RightWingUpper = L(2, 0, 0),
			Head = L(-2,0,0), Tail = L(0,0,0),
		}},
		[9] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(1, 0, 2), Chest = L(2, 0, 0),
			LeftUpperLeg = L(14, 0, 0), LeftLowerLeg = L(-4, 0, 0), LeftFoot = L(-6, 0, 0),
			RightUpperLeg = L(-16, 0, 0), RightLowerLeg = L(16, 0, 0), RightFoot = L(6, 0, 0),
			LeftWingUpper = L(2, 0, 4), RightWingUpper = L(2, 0, -4),
			Head = L(-2,0,0), Tail = L(1,-2,0),
		}},
		[12] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(2, 0, 2), Chest = L(3, 0, 0),
			LeftUpperLeg = L(20, 0, 0), LeftLowerLeg = L(-6, 0, 0), LeftFoot = L(-4, 0, 0),
			RightUpperLeg = L(-22, 0, 0), RightLowerLeg = L(10, 0, 0), RightFoot = L(8, 0, 0),
			LeftWingUpper = L(2, 0, 8), RightWingUpper = L(2, 0, -8),
			Head = L(-2,0,0), Tail = L(2,-4,0),
		}, Markers = {{Name="RightFootstep", Value="Walk"}}},
		[15] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(1, 0, 0), Chest = L(2, 0, 0),
			LeftUpperLeg = L(10, 0, 0), LeftLowerLeg = L(-4, 0, 0), LeftFoot = L(-2, 0, 0),
			RightUpperLeg = L(-10, 0, 0), RightLowerLeg = L(20, 0, 0), RightFoot = L(4, 0, 0),
			LeftWingUpper = L(2, 0, 4), RightWingUpper = L(2, 0, -4),
			Head = L(-2,0,0), Tail = L(1,-2,0),
		}},
		[18] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(0, 0, 0), Chest = L(1, 0, 0),
			LeftUpperLeg = L(0, 0, 0), LeftLowerLeg = L(0, 0, 0), LeftFoot = L(0, 0, 0),
			RightUpperLeg = L(0, 0, 0), RightLowerLeg = L(8, 0, 0), RightFoot = L(0, 0, 0),
			LeftWingUpper = L(2, 0, 0), RightWingUpper = L(2, 0, 0),
			Head = L(-2,0,0), Tail = L(0,0,0),
		}},
		[21] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(1, 0, -2), Chest = L(2, 0, 0),
			LeftUpperLeg = L(-16, 0, 0), LeftLowerLeg = L(16, 0, 0), LeftFoot = L(6, 0, 0),
			RightUpperLeg = L(14, 0, 0), RightLowerLeg = L(-4, 0, 0), RightFoot = L(-6, 0, 0),
			LeftWingUpper = L(2, 0, -4), RightWingUpper = L(2, 0, 4),
			Head = L(-2,0,0), Tail = L(1,2,0),
		}},
		[24] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(2, 0, -2), Chest = L(3, 0, 0),
			LeftUpperLeg = L(-22, 0, 0), LeftLowerLeg = L(10, 0, 0), LeftFoot = L(8, 0, 0),
			RightUpperLeg = L(20, 0, 0), RightLowerLeg = L(-6, 0, 0), RightFoot = L(-4, 0, 0),
			LeftWingUpper = L(2, 0, -8), RightWingUpper = L(2, 0, 8),
			Head = L(-2,0,0), Tail = L(2,4,0),
		}, Markers = {{Name="LeftFootstep", Value="Walk"}}},
	},
}

--============================== RUN ==============================--
Specs.Run = {
	Name = "GoldenChicken_Run",
	FPS = 24,
	Loop = true,
	Priority = Enum.AnimationPriority.Movement,
	Keys = {
		[0] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(12, 0, -3), Chest = L(10, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(-38, 0, 0), LeftLowerLeg = L(20, 0, 0), LeftFoot = L(14, 0, 0),
			RightUpperLeg = L(34, 0, 0), RightLowerLeg = L(-30, 0, 0), RightFoot = L(-10, 0, 0),
			LeftWingUpper = L(6, 0, -20), RightWingUpper = L(6, 0, 20), Tail = L(6, 6, 0),
		}, Markers = {{Name="LeftFootstep", Value="Run"}}},
		[2] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(14, 0, -1), Chest = L(12, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(-25, 0, 0), LeftLowerLeg = L(35, 0, 0), LeftFoot = L(10, 0, 0),
			RightUpperLeg = L(20, 0, 0), RightLowerLeg = L(-20, 0, 0), RightFoot = L(-6, 0, 0),
			LeftWingUpper = L(6, 0, -14), RightWingUpper = L(6, 0, 14), Tail = L(5, 3, 0),
		}},
		[4] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(10, 0, 0), Chest = L(9, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(0, 0, 0), LeftLowerLeg = L(15, 0, 0), LeftFoot = L(0, 0, 0),
			RightUpperLeg = L(-5, 0, 0), RightLowerLeg = L(10, 0, 0), RightFoot = L(0, 0, 0),
			LeftWingUpper = L(6, 0, -6), RightWingUpper = L(6, 0, 6), Tail = L(4, 0, 0),
		}},
		[6] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(12, 0, 3), Chest = L(11, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(30, 0, 0), LeftLowerLeg = L(-25, 0, 0), LeftFoot = L(-10, 0, 0),
			RightUpperLeg = L(-30, 0, 0), RightLowerLeg = L(30, 0, 0), RightFoot = L(12, 0, 0),
			LeftWingUpper = L(6, 0, 16), RightWingUpper = L(6, 0, -16), Tail = L(5, -4, 0),
		}},
		[8] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(12, 0, 3), Chest = L(10, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(34, 0, 0), LeftLowerLeg = L(-30, 0, 0), LeftFoot = L(-10, 0, 0),
			RightUpperLeg = L(-38, 0, 0), RightLowerLeg = L(20, 0, 0), RightFoot = L(14, 0, 0),
			LeftWingUpper = L(6, 0, 20), RightWingUpper = L(6, 0, -20), Tail = L(6, -6, 0),
		}, Markers = {{Name="RightFootstep", Value="Run"}}},
		[10] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(14, 0, 1), Chest = L(12, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(20, 0, 0), LeftLowerLeg = L(-20, 0, 0), LeftFoot = L(-6, 0, 0),
			RightUpperLeg = L(-25, 0, 0), RightLowerLeg = L(35, 0, 0), RightFoot = L(10, 0, 0),
			LeftWingUpper = L(6, 0, 14), RightWingUpper = L(6, 0, -14), Tail = L(5, -3, 0),
		}},
		[12] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(10, 0, 0), Chest = L(9, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(-5, 0, 0), LeftLowerLeg = L(10, 0, 0), LeftFoot = L(0, 0, 0),
			RightUpperLeg = L(0, 0, 0), RightLowerLeg = L(15, 0, 0), RightFoot = L(0, 0, 0),
			LeftWingUpper = L(6, 0, 6), RightWingUpper = L(6, 0, -6), Tail = L(4, 0, 0),
		}},
		[14] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(12, 0, -3), Chest = L(11, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(-30, 0, 0), LeftLowerLeg = L(30, 0, 0), LeftFoot = L(12, 0, 0),
			RightUpperLeg = L(30, 0, 0), RightLowerLeg = L(-25, 0, 0), RightFoot = L(-10, 0, 0),
			LeftWingUpper = L(6, 0, -16), RightWingUpper = L(6, 0, 16), Tail = L(5, 4, 0),
		}},
		[16] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(12, 0, -3), Chest = L(10, 0, 0), Head = L(-8, 0, 0),
			LeftUpperLeg = L(-38, 0, 0), LeftLowerLeg = L(20, 0, 0), LeftFoot = L(14, 0, 0),
			RightUpperLeg = L(34, 0, 0), RightLowerLeg = L(-30, 0, 0), RightFoot = L(-10, 0, 0),
			LeftWingUpper = L(6, 0, -20), RightWingUpper = L(6, 0, 20), Tail = L(6, 6, 0),
		}, Markers = {{Name="LeftFootstep", Value="Run"}}},
	},
}

--============================== JUMPSTART ==============================--
Specs.JumpStart = {
	Name = "GoldenChicken_JumpStart",
	FPS = 24,
	Loop = false,
	Priority = Enum.AnimationPriority.Movement,
	Keys = {
		[0] = { Joints = { Body = L(2,0,0), LeftUpperLeg = L(0,0,0), RightUpperLeg = L(0,0,0) } },
		[3] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(-8, 0, 0), Chest = L(-6,0,0),
			LeftUpperLeg = L(30, 0, 0), LeftLowerLeg = L(-40, 0, 0),
			RightUpperLeg = L(30, 0, 0), RightLowerLeg = L(-40, 0, 0),
			LeftWingUpper = L(-10,0,-25), RightWingUpper = L(-10,0,25),
		}},
		[6] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(-12, 0, 0), Chest = L(-10,0,0),
			LeftUpperLeg = L(42, 0, 0), LeftLowerLeg = L(-55, 0, 0),
			RightUpperLeg = L(42, 0, 0), RightLowerLeg = L(-55, 0, 0),
			LeftWingUpper = L(-15,0,-35), RightWingUpper = L(-15,0,35),
		}},
		[8] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.In, Joints = {
			Body = L(8, 0, 0), Chest = L(6,0,0),
			LeftUpperLeg = L(-20, 0, 0), LeftLowerLeg = L(10, 0, 0),
			RightUpperLeg = L(-20, 0, 0), RightLowerLeg = L(10, 0, 0),
			LeftWingUpper = L(15,0,20), RightWingUpper = L(15,0,-20),
		}, Markers = {{Name="Takeoff", Value="JumpStart"}}},
		[10] = { Joints = {
			Body = L(6, 0, 0), Chest = L(5,0,0),
			LeftUpperLeg = L(-28, 0, 0), LeftLowerLeg = L(20, 0, 0),
			RightUpperLeg = L(-28, 0, 0), RightLowerLeg = L(20, 0, 0),
			LeftWingUpper = L(10,0,15), RightWingUpper = L(10,0,-15),
		}},
		[12] = { Joints = {
			Body = L(4, 0, 0), Chest = L(3,0,0),
			LeftUpperLeg = L(-25, 0, 0), LeftLowerLeg = L(15, 0, 0),
			RightUpperLeg = L(-25, 0, 0), RightLowerLeg = L(15, 0, 0),
			LeftWingUpper = L(6,0,10), RightWingUpper = L(6,0,-10),
		}},
	},
}

--============================== FALL ==============================--
Specs.Fall = {
	Name = "GoldenChicken_Fall",
	FPS = 24,
	Loop = true,
	Priority = Enum.AnimationPriority.Movement,
	Keys = {
		[0] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(4, 0, 0), Chest = L(3, 0, 0), Head = L(-3,0,0),
			LeftUpperLeg = L(-18, 0, 0), LeftLowerLeg = L(12, 0, 0),
			RightUpperLeg = L(-18, 0, 0), RightLowerLeg = L(12, 0, 0),
			LeftWingUpper = L(8, 0, -22), RightWingUpper = L(8, 0, 22),
			Tail = L(6,0,0),
		}},
		[12] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(5, 0, 0), Chest = L(4, 0, 0), Head = L(-2,0,0),
			LeftUpperLeg = L(-20, 0, 0), LeftLowerLeg = L(14, 0, 0),
			RightUpperLeg = L(-16, 0, 0), RightLowerLeg = L(10, 0, 0),
			LeftWingUpper = L(9, 0, -25), RightWingUpper = L(7, 0, 20),
			Tail = L(7,2,0),
		}},
		[24] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(4, 0, 0), Chest = L(3, 0, 0), Head = L(-3,0,0),
			LeftUpperLeg = L(-18, 0, 0), LeftLowerLeg = L(12, 0, 0),
			RightUpperLeg = L(-18, 0, 0), RightLowerLeg = L(12, 0, 0),
			LeftWingUpper = L(8, 0, -22), RightWingUpper = L(8, 0, 22),
			Tail = L(6,0,0),
		}},
	},
}

--============================== LAND ==============================--
Specs.Land = {
	Name = "GoldenChicken_Land",
	FPS = 24,
	Loop = false,
	Priority = Enum.AnimationPriority.Movement,
	Keys = {
		[0] = { Joints = {
			Body = L(4, 0, 0), LeftUpperLeg = L(-18, 0, 0), LeftLowerLeg = L(12, 0, 0),
			RightUpperLeg = L(-18, 0, 0), RightLowerLeg = L(12, 0, 0),
			LeftWingUpper = L(8, 0, -22), RightWingUpper = L(8, 0, 22),
		}},
		[2] = { EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(10, 0, 0), LeftUpperLeg = L(-30, 0, 0), LeftLowerLeg = L(35, 0, 0),
			RightUpperLeg = L(-30, 0, 0), RightLowerLeg = L(35, 0, 0),
			LeftWingUpper = L(4, 0, -10), RightWingUpper = L(4, 0, 10),
		}, Markers = {{Name="Land", Value="Land"}}},
		[5] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(16, 0, 0), Chest = L(-4,0,0), Head = L(6,0,0),
			LeftUpperLeg = L(-48, 0, 0), LeftLowerLeg = L(58, 0, 0),
			RightUpperLeg = L(-48, 0, 0), RightLowerLeg = L(58, 0, 0),
			LeftWingUpper = L(2, 0, 12), RightWingUpper = L(2, 0, -12),
		}},
		[8] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(6, 0, 0), Chest = L(2,0,0), Head = L(-6,0,0),
			LeftUpperLeg = L(-25, 0, 0), LeftLowerLeg = L(28, 0, 0),
			RightUpperLeg = L(-25, 0, 0), RightLowerLeg = L(28, 0, 0),
			LeftWingUpper = L(4, 0, -14), RightWingUpper = L(4, 0, 14),
		}},
		[12] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4,0,0), Head = L(-4,0,0),
			LeftUpperLeg = L(-4, 0, 0), LeftLowerLeg = L(6, 0, 0),
			RightUpperLeg = L(-4, 0, 0), RightLowerLeg = L(6, 0, 0),
			LeftWingUpper = L(4, 0, 4), RightWingUpper = L(4, 0, -4),
		}, Markers = {{Name="Recover", Value="Land"}}},
		[16] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4,0,0), Head = L(-4,0,0),
			LeftUpperLeg = L(0, 0, 0), LeftLowerLeg = L(0, 0, 0),
			RightUpperLeg = L(0, 0, 0), RightLowerLeg = L(0, 0, 0),
			LeftWingUpper = L(4, 0, 6), RightWingUpper = L(4, 0, -6),
		}},
	},
}

--============================== DASH ==============================--
Specs.Dash = {
	Name = "GoldenChicken_Dash",
	FPS = 24,
	Loop = false,
	Priority = Enum.AnimationPriority.Action,
	Keys = {
		[0] = { Joints = { Body = L(3,0,0), Chest = L(4,0,0) } },
		[2] = { EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(-10, 0, 0), Chest = L(-8, 0, 0), Head = L(6,0,0),
			LeftUpperLeg = L(20, 0, 0), LeftLowerLeg = L(-25, 0, 0),
			RightUpperLeg = L(-8, 0, 0), RightLowerLeg = L(6, 0, 0),
			LeftWingUpper = L(-6,0,-30), RightWingUpper = L(-6,0,30),
			Tail = L(-4,0,0),
		}, Markers = {{Name="Windup", Value="Dash"}}},
		[5] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.In, Joints = {
			Body = L(20, 0, 0), Chest = L(16, 0, 0), Head = L(-10,0,0),
			LeftUpperLeg = L(-30, 0, 0), LeftLowerLeg = L(20, 0, 0),
			RightUpperLeg = L(-34, 0, 0), RightLowerLeg = L(24, 0, 0),
			LeftWingUpper = L(-14,0,-40), RightWingUpper = L(-14,0,40),
			Tail = L(10,0,0),
		}, Markers = {{Name="DashStart", Value="Dash"}, {Name="VFX", Value="DashTrail"}}},
		[7] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(26, 0, 0), Chest = L(20, 0, 0), Head = L(-14,0,0),
			LeftUpperLeg = L(-40, 0, 0), LeftLowerLeg = L(10, 0, 0),
			RightUpperLeg = L(-40, 0, 0), RightLowerLeg = L(10, 0, 0),
			LeftWingUpper = L(-18,0,-45), RightWingUpper = L(-18,0,45),
			Tail = L(14,0,0),
		}},
		[12] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(22, 0, 0), Chest = L(17, 0, 0), Head = L(-12,0,0),
			LeftUpperLeg = L(-32, 0, 0), LeftLowerLeg = L(16, 0, 0),
			RightUpperLeg = L(-32, 0, 0), RightLowerLeg = L(16, 0, 0),
			LeftWingUpper = L(-14,0,-40), RightWingUpper = L(-14,0,40),
			Tail = L(12,3,0),
		}},
		[14] = { Joints = {
			Body = L(-6, 0, 0), Chest = L(-4, 0, 0), Head = L(4,0,0),
		}, Markers = {{Name="DashEnd", Value="Dash"}}},
		[15] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(-10, 0, 0), Chest = L(-6, 0, 0), Head = L(6,0,0),
			LeftUpperLeg = L(-10, 0, 0), LeftLowerLeg = L(14, 0, 0),
			RightUpperLeg = L(10, 0, 0), RightLowerLeg = L(-6, 0, 0),
			LeftWingUpper = L(4,0,-10), RightWingUpper = L(4,0,10),
		}},
		[18] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4, 0, 0), Head = L(0,0,0),
			LeftUpperLeg = L(0,0,0), LeftLowerLeg = L(0,0,0), RightUpperLeg = L(0,0,0), RightLowerLeg = L(0,0,0),
			LeftWingUpper = L(4,6,6), RightWingUpper = M(4,6,6),
		}, Markers = {{Name="Recover", Value="Dash"}}},
	},
}

--============================== M1_1 ==============================--
Specs.M1_1 = {
	Name = "GoldenChicken_M1_1",
	FPS = 24,
	Loop = false,
	Priority = Enum.AnimationPriority.Action,
	Keys = {
		[0] = { Joints = { Body = L(3,0,0), Chest = L(4,0,0) } },
		[2] = { EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(-6, -8, 0), Chest = L(-4, -10, 0), Head = L(4, -6, 0),
			LeftWingUpper = L(-12, -20, -35), LeftWingLower = L(-10, 0, -15),
			RightWingUpper = L(4, 10, 12),
		}, Markers = {{Name="Windup", Value="M1_1"}}},
		[5] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.In, Joints = {
			Body = L(8, 14, 0), Chest = L(10, 18, 0), Head = L(-6, 10, 0),
			LeftUpperLeg = L(6,0,0), RightUpperLeg = L(-10,0,0),
		}, Markers = {{Name="OnSwing", Value="M1_1"}}},
		[7] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(10, 22, 0), Chest = L(14, 30, 0), Head = L(-8, 18, 0),
			LeftWingUpper = L(6, 40, 30), LeftWingLower = L(4, 0, 20),
			RightWingUpper = L(2, -6, -8),
		}, Markers = {{Name="ActiveStart", Value="M1_1"}}},
		[8] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(10, 26, 0), Chest = L(16, 36, 0), Head = L(-9, 22, 0),
			LeftWingUpper = L(8, 48, 34), LeftWingLower = L(6, 0, 24),
			RightWingUpper = L(2, -8, -10),
		}, Markers = {{Name="Impact", Value="M1_1"}, {Name="VFX", Value="M1_1_Hit"}, {Name="Sound", Value="M1_1_Hit"}}},
		[9] = { Joints = {
			Body = L(8, 20, 0), Chest = L(12, 28, 0), Head = L(-8, 16, 0),
		}, Markers = {{Name="ComboOpen", Value="M1_1"}}},
		[12] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(6, 10, 0), Chest = L(8, 14, 0), Head = L(-6, 8, 0),
			LeftWingUpper = L(4, 20, 10), LeftWingLower = L(2, 0, 5),
			RightWingUpper = L(3, 4, 4),
		}, Markers = {{Name="ActiveEnd", Value="M1_1"}}},
		[14] = { Joints = {
			Body = L(4, 4, 0), Chest = L(5, 5, 0), Head = L(-4, 3, 0),
		}, Markers = {{Name="ComboClose", Value="M1_1"}}},
		[18] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4, 0, 0), Head = L(0,0,0),
			LeftWingUpper = L(4,6,6), RightWingUpper = M(4,6,6),
		}, Markers = {{Name="Recover", Value="M1_1"}}},
	},
}

--============================== M1_2 ==============================--
Specs.M1_2 = {
	Name = "GoldenChicken_M1_2",
	FPS = 24,
	Loop = false,
	Priority = Enum.AnimationPriority.Action,
	Keys = {
		[0] = { Joints = { Body = L(3, 0, 0), Chest = L(4, 0, 0) } },
		[2] = { EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(-6, 10, 0), Chest = L(-4, 12, 0), Head = L(4, 8, 0),
			RightWingUpper = L(-14, 22, 38), RightWingLower = L(-10, 0, 18),
			LeftWingUpper = L(4, -10, -12),
		}, Markers = {{Name="Windup", Value="M1_2"}}},
		[5] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.In, Joints = {
			Body = L(9, -18, 0), Chest = L(12, -24, 0), Head = L(-7, -14, 0),
			LeftUpperLeg = L(-8,0,0), RightUpperLeg = L(8,0,0),
		}},
		[8] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(12, -28, 0), Chest = L(16, -38, 0), Head = L(-9, -22, 0),
			RightWingUpper = L(8, -50, -38), RightWingLower = L(6, 0, -26),
			LeftWingUpper = L(2, 8, 10),
		}, Markers = {{Name="ActiveStart", Value="M1_2"}}},
		[9] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(13, -32, 0), Chest = L(18, -42, 0), Head = L(-10, -26, 0),
			RightWingUpper = L(10, -56, -42), RightWingLower = L(8, 0, -30),
		}, Markers = {{Name="Impact", Value="M1_2"}, {Name="VFX", Value="M1_2_Hit"}, {Name="Sound", Value="M1_2_Hit"}}},
		[10] = { Joints = {
			Body = L(10, -26, 0), Chest = L(14, -34, 0), Head = L(-8, -20, 0),
		}, Markers = {{Name="ComboOpen", Value="M1_2"}}},
		[13] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(7, -14, 0), Chest = L(9, -18, 0), Head = L(-6, -10, 0),
			RightWingUpper = L(5, -24, -14), RightWingLower = L(3, 0, -6),
		}, Markers = {{Name="ActiveEnd", Value="M1_2"}}},
		[16] = { Joints = {
			Body = L(4, -5, 0), Chest = L(5, -6, 0), Head = L(-4, -3, 0),
		}, Markers = {{Name="ComboClose", Value="M1_2"}}},
		[20] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4, 0, 0), Head = L(0,0,0),
			LeftWingUpper = L(4,6,6), RightWingUpper = M(4,6,6),
		}, Markers = {{Name="Recover", Value="M1_2"}}},
	},
}

--============================== M1_3 (heavy finisher) ==============================--
Specs.M1_3 = {
	Name = "GoldenChicken_M1_3",
	FPS = 24,
	Loop = false,
	Priority = Enum.AnimationPriority.Action,
	Keys = {
		[0] = { Joints = { Body = L(3, 0, 0), Chest = L(4, 0, 0) } },
		[2] = { EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(-14, 0, 0), Chest = L(-10, 0, 0), Head = L(8, 0, 0),
			LeftUpperLeg = L(-25, 0, 0), LeftLowerLeg = L(35, 0, 0),
			RightWingUpper = L(-20, 0, 40), LeftWingUpper = L(-16, 0, -30),
		}, Markers = {{Name="Windup", Value="M1_3"}}},
		[7] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(-20, 0, 0), Chest = L(-16, 0, 0), Head = L(12, 0, 0),
			LeftUpperLeg = L(-40, 0, 0), LeftLowerLeg = L(55, 0, 0),
			RightWingUpper = L(-28, 0, 48), LeftWingUpper = L(-22, 0, -38),
			Tail = L(-10,0,0),
		}, Markers = {{Name="Charge", Value="M1_3"}}},
		[10] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.In, Joints = {
			Body = L(14, 0, 0), Chest = L(18, 0, 0), Head = L(-14, 0, 0),
			LeftUpperLeg = L(30, 0, 0), LeftLowerLeg = L(-20, 0, 0), LeftFoot = L(-15,0,0),
		}, Markers = {{Name="OnSwing", Value="M1_3"}}},
		[13] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(24, 0, 0), Chest = L(30, 0, 0), Head = L(-20, 0, 0),
			LeftUpperLeg = L(45, 0, 0), LeftLowerLeg = L(-40, 0, 0), LeftFoot = L(-25,0,0),
		}, Markers = {{Name="ActiveStart", Value="M1_3"}}},
		[14] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(28, 0, 0), Chest = L(34, 0, 0), Head = L(-22, 0, 0),
			LeftUpperLeg = L(50, 0, 0), LeftLowerLeg = L(-48, 0, 0), LeftFoot = L(-30,0,0),
		}, Markers = {{Name="Impact", Value="M1_3"}, {Name="VFX", Value="M1_3_Hit"}, {Name="Sound", Value="M1_3_Hit"}}},
		[17] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(20, 0, 0), Chest = L(24, 0, 0), Head = L(-15, 0, 0),
			LeftUpperLeg = L(30, 0, 0), LeftLowerLeg = L(-25, 0, 0),
		}, Markers = {{Name="ActiveEnd", Value="M1_3"}}},
		[22] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(8, 0, 0), Chest = L(10, 0, 0), Head = L(-6, 0, 0),
			LeftUpperLeg = L(5, 0, 0), LeftLowerLeg = L(0, 0, 0),
		}, Markers = {{Name="ComboClose", Value="M1_3"}}},
		[28] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(3, 0, 0), Chest = L(4, 0, 0), Head = L(0,0,0),
			LeftUpperLeg = L(0,0,0), LeftLowerLeg = L(0,0,0),
			LeftWingUpper = L(4,6,6), RightWingUpper = M(4,6,6),
		}, Markers = {{Name="Recover", Value="M1_3"}}},
	},
}

--============================== ENTRANCE ==============================--
Specs.Entrance = {
	Name = "GoldenChicken_Entrance",
	FPS = 24,
	Loop = false,
	Priority = Enum.AnimationPriority.Action,
	Keys = {
		[0] = { Joints = {
			Body = L(-20, 0, 0), Chest = L(-15,0,0), Head = L(15,0,0),
			LeftWingUpper = L(-20,0,-15), RightWingUpper = L(-20,0,15),
		}, Markers = {{Name="EntranceStart", Value="Entrance"}}},
		[20] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(-8, 0, 0), Chest = L(-6,0,0), Head = L(8,0,0),
			LeftUpperLeg = L(-10,0,0), RightUpperLeg = L(-10,0,0),
			LeftWingUpper = L(0,0,10), RightWingUpper = L(0,0,-10),
		}},
		[36] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(6, 0, 0), Chest = L(8,0,0), Head = L(-6,0,0),
			LeftUpperLeg = L(0,0,0), RightUpperLeg = L(0,0,0),
			LeftWingUpper = L(10,0,35), RightWingUpper = L(10,0,-35),
		}, Markers = {{Name="AuraOn", Value="Entrance"}}},
		[54] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(8, 0, 0), Chest = L(10,0,0), Head = L(-8,0,0),
			LeftWingUpper = L(6,0,20), RightWingUpper = L(6,0,-20),
			Halo = L(0,0,0),
		}, Markers = {{Name="CameraBeat", Value="Entrance"}}},
		[66] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(6, 0, 0), Chest = L(8,0,0), Head = L(-6,0,0),
			LeftWingUpper = L(4,0,10), RightWingUpper = L(4,0,-10),
		}, Markers = {{Name="Title", Value="Entrance"}}},
		[90] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(5, 0, 0), Chest = L(6,0,0), Head = L(-5,0,0),
			LeftWingUpper = L(4,6,6), RightWingUpper = M(4,6,6),
		}, Markers = {{Name="EntranceEnd", Value="Entrance"}}},
	},
}

--============================== VICTORY ==============================--
Specs.Victory = {
	Name = "GoldenChicken_Victory",
	FPS = 24,
	Loop = false,
	Priority = Enum.AnimationPriority.Action,
	Keys = {
		[0] = { Joints = {
			Body = L(6, 0, 0), Chest = L(4,0,0), Head = L(-4,0,0),
		}, Markers = {{Name="VictoryStart", Value="Victory"}}},
		[18] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(-6, 0, 0), Chest = L(-8,0,0), Head = L(8,0,0),
			LeftUpperLeg = L(-12,0,0), RightUpperLeg = L(-12,0,0),
			LeftWingUpper = L(-10,0,-20), RightWingUpper = L(-10,0,20),
		}},
		[34] = { EasingStyle = Enum.PoseEasingStyle.Cubic, EasingDirection = Enum.PoseEasingDirection.Out, Joints = {
			Body = L(14, 0, 0), Chest = L(18,0,0), Head = L(-16,0,0),
			LeftUpperLeg = L(0,0,0), RightUpperLeg = L(0,0,0),
			LeftWingUpper = L(15,0,50), RightWingUpper = L(15,0,-50),
		}, Markers = {{Name="VFX", Value="VictoryBurst"}, {Name="Sound", Value="VictoryFanfare"}}},
		[54] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(12, 0, 0), Chest = L(15,0,0), Head = L(-14,0,0),
			LeftWingUpper = L(10,0,35), RightWingUpper = L(10,0,-35),
		}},
		[90] = { EasingStyle = Enum.PoseEasingStyle.Cubic, Joints = {
			Body = L(12, 0, 0), Chest = L(15,0,0), Head = L(-14,0,0),
			LeftUpperLeg = L(0,0,0), RightUpperLeg = L(0,0,0),
			LeftWingUpper = L(8,0,25), RightWingUpper = L(8,0,-25),
		}, Markers = {{Name="FinalPose", Value="Victory"}, {Name="VictoryEnd", Value="Victory"}}},
	},
}

return Specs
