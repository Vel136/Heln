-- ─── Module ──────────────────────────────────────────────────────────────────

local Easing = {}

-- ─── Internal: raw curve functions ──────────────────────────────────────────

local function easeIn(t, func)
	return func(t)
end

local function easeOut(t, func)
	return 1 - func(1 - t)
end

local function bounce(t)
	if t < 0.36363636 then
		return 7.5625 * t * t
	elseif t < 0.72727272 then
		t = t - 0.54545454
		return 7.5625 * t * t + 0.75
	elseif t < 0.90909090 then
		t = t - 0.81818181
		return 7.5625 * t * t + 0.9375
	else
		t = t - 0.95454545
		return 7.5625 * t * t + 0.984375
	end
end

local ease = {}

ease.Linear = function(val) return val end

ease.ConstantIn = function() return 1 end
ease.ConstantOut = function() return 0 end
ease.ConstantInOut = function() return 0.5 end

ease.ElasticIn = function(val)
	local p = 0.3
	local t = 1 - val
	local s = p / 4
	return 1 - (1 + 2 ^ (-10 * t) * math.sin((t - s) * (math.pi * 2) / p))
end
ease.ElasticOut = function(val)
	local p = 0.3
	local t = val
	local s = p / 4
	return (1 + 2 ^ (-10 * t) * math.sin((t - s) * (math.pi * 2) / p))
end
ease.ElasticInOut = function(val)
	local t = (1 - val) * 2
	local p = 0.3 * 1.5
	local s = p / 4
	if t < 1 then
		t = t - 1
		return 1 - (-0.5 * 2 ^ (10 * t) * math.sin((t - s) * (math.pi * 2) / p))
	else
		t = t - 1
		return 1 - (1 + 0.5 * 2 ^ (-10 * t) * math.sin((t - s) * (math.pi * 2) / p))
	end
end

ease.CubicIn = function(val) return val ^ 3 end
ease.CubicOut = function(val) return easeOut(val, ease.CubicIn) end
ease.CubicInOut = function(val)
	val = val * 2
	if val < 1 then
		return easeIn(val, ease.CubicIn) * 0.5
	else
		return 0.5 + easeOut(val - 1, ease.CubicIn) * 0.5
	end
end

ease.BounceIn = function(val) return easeOut(val, bounce) end
ease.BounceOut = function(val) return bounce(val) end
ease.BounceInOut = function(val)
	val = val * 2
	if val < 1 then
		return easeOut(val, bounce) * 0.5
	else
		return 0.5 + easeIn(val - 1, bounce) * 0.5
	end
end

ease.QuadIn = function(val) return val * val end
ease.QuadOut = function(val) return -val * val + 2 * val end
ease.QuadInOut = function(val)
	return val < 0.5 and 2 * val * val or -2 * val * val + 4 * val - 1
end

ease.SineIn = function(val) return math.sin(math.pi / 2 * val - math.pi / 2) + 1 end
ease.SineOut = function(val) return math.sin(math.pi / 2 * val) end
ease.SineInOut = function(val) return 0.5 * math.sin(math.pi * val - math.pi / 2) + 0.5 end

ease.CircIn = function(val) return -math.sqrt(1 - val * val) + 1 end
ease.CircOut = function(val) return math.sqrt(-(val - 1) ^ 2 + 1) end
ease.CircInOut = function(val)
	return val < 0.5 and -math.sqrt(-val * val + 0.25) + 0.5 or math.sqrt(-(val - 1) ^ 2 + 0.25) + 0.5
end

-- ─── Style table ─────────────────────────────────────────────────────────────

local STYLES = {
	Linear = { In = ease.Linear, Out = ease.Linear, InOut = ease.Linear, OutIn = ease.Linear },
	Constant = { In = ease.ConstantIn, Out = ease.ConstantOut, InOut = ease.ConstantInOut, OutIn = ease.ConstantInOut },
	Elastic = { In = ease.ElasticIn, Out = ease.ElasticOut, InOut = ease.ElasticInOut, OutIn = ease.ElasticInOut },
	Cubic = { In = ease.CubicIn, Out = ease.CubicOut, InOut = ease.CubicInOut, OutIn = ease.CubicInOut },
	Bounce = { In = ease.BounceIn, Out = ease.BounceOut, InOut = ease.BounceInOut, OutIn = ease.BounceInOut },
}

-- ─── Public API ──────────────────────────────────────────────────────────────

function Easing.Ease(style, direction, alpha)
	local styleName = typeof(style) == "EnumItem" and style.Name or style
	local dirName = typeof(direction) == "EnumItem" and direction.Name or direction

	local styleTbl = STYLES[styleName] or STYLES.Linear
	local func = styleTbl[dirName] or styleTbl.In

	return func(alpha)
end

return Easing
