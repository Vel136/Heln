-- ─── Modules ─────────────────────────────────────────────────────────────────

local Easing = require(script.Parent.Easing)
local PlaybackTypes = require(script.Parent.PlaybackTypes)

-- ─── Module ──────────────────────────────────────────────────────────────────

local Player = {}
Player.__index = Player

-- ─── Internal: rig/timeline setup ────────────────────────────────────────────
local nextTrackId = 0

local function buildFromKeyframeSequence(keyframeSequence)
	local timelines = {}
	local keyframeMarkers = {}
	local length = 0

	local function visitPose(pose, time)
		local list = timelines[pose.Name]
		if not list then
			list = {}
			timelines[pose.Name] = list
		end
		table.insert(list, {
			Time = time,
			CFrame = pose.CFrame,
			EasingStyle = pose.EasingStyle,
			EasingDirection = pose.EasingDirection,
		})
		for _, child in ipairs(pose:GetChildren()) do
			if child:IsA("Pose") then
				visitPose(child, time)
			end
		end
	end

	local keyframes = {}
	for _, child in ipairs(keyframeSequence:GetChildren()) do
		if child:IsA("Keyframe") then
			table.insert(keyframes, child)
		end
	end
	table.sort(keyframes, function(a, b) return a.Time < b.Time end)

	for _, keyframe in ipairs(keyframes) do
		if keyframe.Time > length then
			length = keyframe.Time
		end
		if keyframe.Name and keyframe.Name ~= "" then
			table.insert(keyframeMarkers, { Time = keyframe.Time, Name = keyframe.Name })
		end
		for _, pose in ipairs(keyframe:GetChildren()) do
			if pose:IsA("Pose") then
				visitPose(pose, keyframe.Time)
			end
		end
	end

	for _, list in pairs(timelines) do
		table.sort(list, function(a, b) return a.Time < b.Time end)
	end

	return timelines, keyframeMarkers, length
end

local function evaluateJoint(timeline, time)
	if #timeline == 0 then
		return nil
	end

	if time <= timeline[1].Time then
		return timeline[1].CFrame
	end
	if time >= timeline[#timeline].Time then
		return timeline[#timeline].CFrame
	end

	for i = 1, #timeline - 1 do
		local a, b = timeline[i], timeline[i + 1]
		if time >= a.Time and time <= b.Time then
			local span = b.Time - a.Time
			local alpha = span > 0 and (time - a.Time) / span or 1
			alpha = Easing.Ease(a.EasingStyle, a.EasingDirection, alpha)
			return a.CFrame:Lerp(b.CFrame, alpha)
		end
	end

	return timeline[#timeline].CFrame
end

-- ─── Constructor ─────────────────────────────────────────────────────────────

function Player.new(rig, keyframeSequence)
	local self = setmetatable({}, Player)

	self._rig = rig
	self._keyframeSequence = keyframeSequence

	nextTrackId += 1
	self._id = nextTrackId

	local timelines, keyframeMarkers, length = buildFromKeyframeSequence(keyframeSequence)
	self._timelines = timelines
	self._keyframeMarkers = keyframeMarkers
	self._length = length
	self._customMarkers = {}

	self._time = 0
	self._playing = false
	self._paused = false
	self._speed = 1

	self._animation = nil
	self._looped = keyframeSequence.Loop
	self._priority = keyframeSequence.Priority
	self._weightCurrent = 0
	self._weightTarget = 1

	self._fadeTo = nil
	self._fadeFrom = 0
	self._fadeDuration = 0
	self._fadeElapsed = 0
	self._fadeStyle = "Linear"
	self._stoppingAfterFade = false

	self._playbackType = PlaybackTypes.Default
	self._reversing = false
	self._reverseTarget = 0
	self._finishAfterReverse = false

	self._startMarkersPending = false

	return self
end

function Player:_EvaluatePose()
	local timelines = self._timelines
	local time = self._time
	local jointName, timeline = nil, nil

	return function()
		jointName, timeline = next(timelines, jointName)
		if jointName == nil then
			return nil
		end
		return jointName, evaluateJoint(timeline, time)
	end
end

function Player:_IsContributing()
	return self._playing or self._paused or self._stoppingAfterFade or self._reversing
end

function Player:_TriggerPlaybackStop()
	local playbackType = PlaybackTypes[self._playbackType] or PlaybackTypes[PlaybackTypes.Default]
	playbackType.OnStop(self)
end

function Player:_TriggerPlaybackPlay()
	local playbackType = PlaybackTypes[self._playbackType] or PlaybackTypes[PlaybackTypes.Default]
	playbackType.OnPlay(self)
end

function Player:_IsPlaybackTypeLooping()
	local playbackType = PlaybackTypes[self._playbackType] or PlaybackTypes[PlaybackTypes.Default]
	return playbackType.IsLooping
end

function Player:_PlaybackTypeReversesFromFinished()
	local playbackType = PlaybackTypes[self._playbackType] or PlaybackTypes[PlaybackTypes.Default]
	return playbackType.ReversesFromFinished == true
end

function Player:_BeginReverse(target)
	if self._time == target then
		self._reversing = false
		return
	end
	self._reversing = true
	self._reverseTarget = target
end

function Player:_AdvanceReverse(dt)
	if not self._reversing then
		return false
	end

	local rate = math.abs(self._speed)
	if rate == 0 then
		rate = 1
	end

	local step = rate * dt
	local remaining = self._reverseTarget - self._time

	if math.abs(remaining) <= step then
		self._time = self._reverseTarget
		self._reversing = false
		return true
	end

	self._time += (remaining > 0 and step or -step)
	return false
end

function Player:_BeginFade(targetWeight, duration, style)
	if not duration or duration <= 0 then
		self._weightCurrent = targetWeight
		self._fadeTo = nil
		return
	end

	self._fadeFrom = self._weightCurrent
	self._fadeTo = targetWeight
	self._fadeDuration = duration
	self._fadeElapsed = 0
	self._fadeStyle = style or "Linear"
end

function Player:_AdvanceFade(dt)
	if self._fadeTo == nil then
		return false
	end

	self._fadeElapsed += dt
	local alpha = math.clamp(self._fadeElapsed / self._fadeDuration, 0, 1)
	local eased = Easing.Ease(self._fadeStyle, "InOut", alpha)
	self._weightCurrent = self._fadeFrom + (self._fadeTo - self._fadeFrom) * eased

	if alpha >= 1 then
		self._weightCurrent = self._fadeTo
		self._fadeTo = nil
		return true
	end

	return false
end

function Player:_AdvanceFrame(dt, onLoop, onEnded, fireMarkers)
	if not self._playing then
		return
	end

	local from = self._time
	self._time += dt * self._speed

	local fromExclusive = from
	if self._startMarkersPending then
		self._startMarkersPending = false
		fromExclusive = -math.huge
	end

	if self._speed < 0 and self._time <= 0 then
		self._time = 0

		if self._looped or self:_IsPlaybackTypeLooping() then
			self._time = self._length
			onLoop(self)
		else
			self._playing = false
			onEnded(self)
		end
		return
	end

	if self._time >= self._length then
		local overshoot = self._time - self._length
		self._time = self._length
		fireMarkers(self, fromExclusive, self._time)

		if self._looped or self:_IsPlaybackTypeLooping() then
			self._time = self._length > 0 and (overshoot % self._length) or 0
			fireMarkers(self, -math.huge, self._time)
			onLoop(self)
		else
			self._playing = false
			onEnded(self)
		end
		return
	end

	fireMarkers(self, fromExclusive, self._time)
end

function Player:_AllMarkersSorted()
	local all = {}
	for _, marker in ipairs(self._keyframeMarkers) do
		table.insert(all, marker)
	end
	for _, marker in ipairs(self._customMarkers) do
		table.insert(all, marker)
	end
	table.sort(all, function(a, b) return a.Time < b.Time end)
	return all
end

function Player:_FireMarkersBetween(fromTime, toTime, KeyframeReached, markerSignals)
	if toTime < fromTime then
		return
	end

	local pending = {}
	for _, marker in ipairs(self._keyframeMarkers) do
		if marker.Time > fromTime and marker.Time <= toTime then
			table.insert(pending, marker)
		end
	end
	for _, marker in ipairs(self._customMarkers) do
		if marker.Time > fromTime and marker.Time <= toTime then
			table.insert(pending, marker)
		end
	end

	table.sort(pending, function(a, b) return a.Time < b.Time end)

	for _, marker in ipairs(pending) do
		KeyframeReached:Fire(marker.Name, marker.Value)
		local signal = markerSignals[marker.Name]
		if signal then
			signal:Fire(marker.Name, marker.Value)
		end
	end
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function Player:GetTimeOfKeyframe(keyframeName)
	for _, marker in ipairs(self._keyframeMarkers) do
		if marker.Name == keyframeName then
			return marker.Time
		end
	end
	return nil
end

function Player:SetMarker(time, name, value)
	table.insert(self._customMarkers, { Time = time, Name = name or "", Value = value })
end

function Player:GetPreviousMarker(fromTime)
	local all = self:_AllMarkersSorted()
	local best = nil
	for _, marker in ipairs(all) do
		if marker.Time < fromTime then
			best = marker
		else
			break
		end
	end
	return best
end

function Player:GetNextMarker(fromTime)
	local all = self:_AllMarkersSorted()
	for _, marker in ipairs(all) do
		if marker.Time > fromTime then
			return marker
		end
	end
	return nil
end

function Player:GetNearestMarker(fromTime)
	local previous = self:GetPreviousMarker(fromTime)
	local next_ = self:GetNextMarker(fromTime)

	if previous == nil then
		return next_
	end
	if next_ == nil then
		return previous
	end

	local distToPrevious = fromTime - previous.Time
	local distToNext = next_.Time - fromTime
	return distToNext <= distToPrevious and next_ or previous
end

return Player
