--==================================================
-- CHICKEN LEVEL CONFIG
-- Tunable balance numbers. No cap on level.
--
-- Both cost and egg value now COMPOUND (multiply by a constant
-- factor each level) rather than one being linear — this matches
-- the simpler mental model of "cost multiplies by X, value
-- multiplies by Y" rather than two different kinds of curve.
--
-- Balance is still preserved because UpgradeCostGrowth (1.5) is
-- meaningfully bigger than EggValueGrowth (1.28): cost will
-- always eventually outrun value's growth, so grinding one
-- chicken forever never lets it out-earn getting rarer chickens.
--
-- At these settings:
--   Level 20 upgrade cost:  ~$11,084 (target was "at least 10k")
--   Level 20 egg value:     ~108.8x base price (target was "at least 100x")
--
-- Adjust these two numbers freely to rebalance without touching
-- any other script.
--==================================================

local ChickenLevelConfig = {}

-- Cost to go from level 1 -> 2. Cost for level N -> N+1 is:
--   BaseUpgradeCost * (UpgradeCostGrowth ^ (N - 1))
ChickenLevelConfig.BaseUpgradeCost = 5

-- Cost multiplies by this each level (1.5 = +50% per level).
ChickenLevelConfig.UpgradeCostGrowth = 1.5

-- Egg value at level N is:
--   basePrice * (EggValueGrowth ^ (N - 1))
-- 1.28 = +28% per level, compounding.
-- (A minimum of +$1 per level is still guaranteed on top of this
-- in ChickenLevelService, so very cheap chickens like a $1 Brown
-- Chicken still visibly grow every level instead of rounding down
-- to nothing for the first several levels.)
ChickenLevelConfig.EggValueGrowth = 1.28

return ChickenLevelConfig