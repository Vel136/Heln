-- ─── Services ────────────────────────────────────────────────────────────────

local RunService = game:GetService("RunService")

-- ─── Modules ─────────────────────────────────────────────────────────────────

local Signal = require(script.Signal)
local Player = require(script.Player)
local PlaybackTypes = require(script.PlaybackTypes)

-- ─── Types ───────────────────────────────────────────────────────────────────

export type FadeStyle = "Linear" | "Constant" | "Elastic" | "Cubic" | "Bounce"

export type PlaybackTypeName =
	"Persistent"
	| "Reversible"
	| "ReversibleResume"
	| "MarkerReversible"
	| "NearestMarker"
	| "LoopPersistent"
	| "LoopMarkerReversible"

export type Marker = {
	Time: number,
	Name: string,
	Value: any,
}

export type Track = {
	read Animation: Animation?,
	read IsPlaying: boolean,
	read Length: number,
	Looped: boolean,
	PlaybackType: PlaybackTypeName,
	Priority: Enum.AnimationPriority,
	Speed: number,
	TimePosition: number,
	WeightCurrent: number,
	WeightTarget: number,

	read DidLoop: Signal.Signal<() -> ()>,
	read Ended: Signal.Signal<() -> ()>,
	read KeyframeReached: Signal.Signal<(name: string, value: any) -> ()>,
	read Stopped: Signal.Signal<() -> ()>,

	Play: (self: Track, fadeTime: number?, fadeStyle: FadeStyle?, weight: number?, speed: number?) -> (),
	Pause: (self: Track) -> (),
	Stop: (self: Track, fadeTime: number?, fadeStyle: FadeStyle?) -> (),
	SetMarker: (self: Track, time: number, name: string?, value: any) -> (),
	GetMarkerReachedSignal: (self: Track, name: string) -> Signal.Signal<(name: string, value: any) -> ()>,
	GetTimeOfKeyframe: (self: Track, keyframeName: string) -> number?,
	GetPreviousMarker: (self: Track, fromTime: number) -> Marker?,
	GetNextMarker: (self: Track, fromTime: number) -> Marker?,
	GetNearestMarker: (self: Track, fromTime: number) -> Marker?,
	Destroy: (self: Track) -> (),
}

-- ─── Module ──────────────────────────────────────────────────────────────────

local Controller = {}
Controller.__index = Controller

-- ─── Constants ───────────────────────────────────────────────────────────────

local PRIORITY_ORDER = {
	[Enum.AnimationPriority.Core] = 1,
	[Enum.AnimationPriority.Idle] = 2,
	[Enum.AnimationPriority.Movement] = 3,
	[Enum.AnimationPriority.Action] = 4,
}

local function priorityRank(priority)
	return PRIORITY_ORDER[priority] or PRIORITY_ORDER[Enum.AnimationPriority.Action]
end

-- ─── Rig registry ────────────────────────────────────────────────────────────

local rigControllers = setmetatable({}, { __mode = "k" })

local function getOrCreateRigController(rig)
	local existing = rigControllers[rig]
	if existing then
		return existing
	end

	local self = setmetatable({}, Controller)
	self._rig = rig
	self._tracks = {}

	self._events = setmetatable({}, { __mode = "k" })

	self._jointCache = {}
	self._connection = nil

	rig.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Motor6D") then
			table.clear(self._jointCache)
		end
	end)
	rig.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("Motor6D") then
			table.clear(self._jointCache)
		end
	end)

	rigControllers[rig] = self
	return self
end

-- ─── Internal: registration ──────────────────────────────────────────────────

function Controller:_register(track)
	self._tracks[track] = true
	if not self._connection then
		self._connection = RunService.PreSimulation:Connect(function(dt)
			self:_step(dt)
		end)
	end
end

function Controller:_unregister(track)
	self._tracks[track] = nil
	if next(self._tracks) == nil and self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

function Controller:_findMotors(jointName)
	local cached = self._jointCache[jointName]
	if cached ~= nil then
		return cached or nil
	end

	local motors = nil
	for _, descendant in ipairs(self._rig:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Part1 and descendant.Part1.Name == jointName then
			motors = motors or {}
			table.insert(motors, descendant)
		end
	end

	self._jointCache[jointName] = motors or false
	return motors
end

-- ─── Internal: frame composition ─────────────────────────────────────────────

function Controller:_step(dt)
	local contributions = {}

	local finished = nil

	for track in pairs(self._tracks) do
		local events = self._events[track]
		local justFinished = false

		track:_AdvanceFrame(dt,
			function(t) events.DidLoop:Fire() end,
			function(t)
				justFinished = true
				events.Stopped:Fire()
				events.Ended:Fire()
			end,
			function(t, from, to) t:_FireMarkersBetween(from, to, events.KeyframeReached, events.markerSignals) end
		)

		track:_AdvanceFade(dt)
		track:_AdvanceReverse(dt)

		if track._stoppingAfterFade and not track._reversing
			and (track._weightCurrent <= 0 or track._finishAfterReverse)
		then
			track._stoppingAfterFade = false
			track._finishAfterReverse = false
			justFinished = true
			events.Stopped:Fire()
		end

		if track:_IsContributing() or justFinished then
			local rank = priorityRank(track._priority)
			local weight = track._weightCurrent

			if weight > 0 or justFinished then
				for jointName, cframe in track:_EvaluatePose() do
					local list = contributions[jointName]
					if not list then
						list = {}
						contributions[jointName] = list
					end
					table.insert(list, { Priority = rank, Order = track._id, Weight = weight, CFrame = cframe })
				end
			end
		end

		if justFinished then
			finished = finished or {}
			finished[track] = true
		end
	end

	if finished then
		for track in pairs(finished) do
			track._fadeTo = nil
			self:_unregister(track)
		end
	end

	for jointName, list in pairs(contributions) do
		table.sort(list, function(a, b)
			if a.Priority ~= b.Priority then
				return a.Priority < b.Priority
			end
			return a.Order < b.Order
		end)

		local result = nil
		local i = 1
		while i <= #list do
			local rank = list[i].Priority

			local levelResult = nil
			local levelWeight = 0
			while i <= #list and list[i].Priority == rank do
				local contrib = list[i]
				if levelResult == nil then
					levelResult = contrib.CFrame
					levelWeight = contrib.Weight
				else
					local totalWeight = levelWeight + contrib.Weight
					local alpha = totalWeight > 0 and (contrib.Weight / totalWeight) or 0
					levelResult = levelResult:Lerp(contrib.CFrame, alpha)
					levelWeight = totalWeight
				end
				i += 1
			end

			result = (result or CFrame.identity):Lerp(levelResult, math.clamp(levelWeight, 0, 1))
		end
	
		local motors = self:_findMotors(jointName)
		if motors and result then
			for _, motor in ipairs(motors) do
				motor.Transform = result
			end
		end
	end
end

-- ─── Public proxy ────────────────────────────────────────────────────────────

local Proxy

local READONLY = { Length = true }

local GETTERS = {
	Animation = function(track) return track._animation end,
	IsPlaying = function(track) return track._playing end,
	Length = function(track) return track._length end,
	Looped = function(track) return track._looped end,
	PlaybackType = function(track) return track._playbackType end,
	Priority = function(track) return track._priority end,
	Speed = function(track) return track._speed end,
	TimePosition = function(track) return track._time end,
	WeightCurrent = function(track) return track._weightCurrent end,
	WeightTarget = function(track) return track._weightTarget end,
}

local function setTimePosition(proxy, track, time)
	local clamped = math.clamp(time, 0, track._length)
	local from = track._time
	track._time = clamped
	if clamped > from then
		local events = Proxy._events[proxy]
		track:_FireMarkersBetween(from, clamped, events.KeyframeReached, events.markerSignals)
	end
end

local function setPlaybackType(proxy, track, value)
	if not PlaybackTypes[value] then
		error(("'%s' is not a valid PlaybackType"):format(tostring(value)), 3)
	end
	track._playbackType = value
end

local SETTERS = {
	Looped = function(proxy, track, value) track._looped = value end,
	PlaybackType = setPlaybackType,
	Priority = function(proxy, track, value) track._priority = value end,
	Speed = function(proxy, track, value) track._speed = value end,
	TimePosition = setTimePosition,
	WeightCurrent = function(proxy, track, value) track._weightCurrent = value end,
	WeightTarget = function(proxy, track, value) track._weightTarget = value end,
}

local METHODS = {}

function METHODS:Play(fadeTime, fadeStyle, weight, speed)
	local track, rigController = Proxy._tracks[self], Proxy._rigControllers[self]
	if not track then
		return
	end

	if speed then
		track._speed = speed
	end

	track._weightTarget = weight or track._weightTarget
	track._stoppingAfterFade = false
	track._finishAfterReverse = false
	track._reversing = false

	if track._playing then
		track:_BeginFade(track._weightTarget, fadeTime, fadeStyle)
		return
	end

	if not track._paused and track._time >= track._length then
		track._time = 0
	end

	track._startMarkersPending = track._time == 0

	track._playing = true
	track._paused = false
	rigController:_register(track)
	track:_BeginFade(track._weightTarget, fadeTime, fadeStyle)
	track:_TriggerPlaybackPlay()
end

function METHODS:Pause()
	local track = Proxy._tracks[self]
	if not track then
		return
	end

	if not track._playing then
		return
	end

	track._playing = false
	track._paused = true
end

function METHODS:Stop(fadeTime, fadeStyle)
	local track, rigController = Proxy._tracks[self], Proxy._rigControllers[self]
	if not track then
		return
	end
	local wasActive = track._playing or track._paused

	track._playing = false
	track._paused = false

	if not wasActive then
		if not track:_PlaybackTypeReversesFromFinished() or track._time <= 0 then
			return
		end
		rigController:_register(track)
	end

	track:_TriggerPlaybackStop()

	if track._reversing then
		rigController:_register(track)
		track._stoppingAfterFade = true
		track._finishAfterReverse = true
		track._fadeTo = nil
	elseif fadeTime and fadeTime > 0 then
		track._stoppingAfterFade = true
		track:_BeginFade(0, fadeTime, fadeStyle)
	else
		track._stoppingAfterFade = false
		rigController:_unregister(track)
		Proxy._events[self].Stopped:Fire()
	end
end

function METHODS:GetTimeOfKeyframe(keyframeName)
	return Proxy._tracks[self]:GetTimeOfKeyframe(keyframeName)
end

function METHODS:SetMarker(time, name, value)
	Proxy._tracks[self]:SetMarker(time, name, value)
end

function METHODS:GetPreviousMarker(fromTime)
	return Proxy._tracks[self]:GetPreviousMarker(fromTime)
end

function METHODS:GetNextMarker(fromTime)
	return Proxy._tracks[self]:GetNextMarker(fromTime)
end

function METHODS:GetNearestMarker(fromTime)
	return Proxy._tracks[self]:GetNearestMarker(fromTime)
end

function METHODS:GetMarkerReachedSignal(name)
	local events = Proxy._events[self]
	local signal = events.markerSignals[name]
	if not signal then
		signal = Signal.new()
		events.markerSignals[name] = signal
	end
	return signal
end

function METHODS:Destroy()
	local track = Proxy._tracks[self]
	if not track then
		return
	end
	local rigController = Proxy._rigControllers[self]
	local events = Proxy._events[self]

	local wasActive = track._playing or track._paused or track._stoppingAfterFade or track._reversing
	track._playing = false
	track._paused = false
	track._stoppingAfterFade = false
	track._finishAfterReverse = false
	track._reversing = false
	track._fadeTo = nil
	rigController:_unregister(track)

	if wasActive then
		events.Stopped:Fire()
	end

	events.DidLoop:Destroy()
	events.Ended:Destroy()
	events.KeyframeReached:Destroy()
	events.Stopped:Destroy()
	for _, signal in pairs(events.markerSignals) do
		signal:Destroy()
	end

	rigController._events[track] = nil
	Proxy._tracks[self] = nil
	Proxy._rigControllers[self] = nil
	Proxy._events[self] = nil
end

Proxy = {}

Proxy._tracks = setmetatable({}, { __mode = "k" })
Proxy._rigControllers = setmetatable({}, { __mode = "k" })
Proxy._events = setmetatable({}, { __mode = "k" })

Proxy.__index = function(proxy, key)
	local track = Proxy._tracks[proxy]

	if not track then
		return METHODS[key]
	end

	local getter = GETTERS[key]
	if getter then
		return getter(track)
	end

	local method = METHODS[key]
	if method then
		return method
	end

	local events = Proxy._events[proxy]
	if events[key] then
		return events[key]
	end

	return nil
end

Proxy.__newindex = function(proxy, key, value)
	if READONLY[key] then
		error(("%s is a read-only member of AnimationTrack"):format(key), 2)
	end

	local track = Proxy._tracks[proxy]
	if not track then
		error("cannot set properties of a destroyed track", 2)
	end

	local setter = SETTERS[key]
	if setter then
		setter(proxy, track, value)
		return
	end

	error(("%s is not a settable member of AnimationTrack"):format(key), 2)
end

-- ─── Constructor ─────────────────────────────────────────────────────────────

function Controller.new(rig: Model, keyframeSequence: KeyframeSequence): Track
	local track = Player.new(rig, keyframeSequence)
	local rigController = getOrCreateRigController(rig)

	local events = {
		DidLoop = Signal.new(),
		Ended = Signal.new(),
		KeyframeReached = Signal.new(),
		Stopped = Signal.new(),
		markerSignals = {},
	}

	local proxy = setmetatable({}, Proxy)
	Proxy._tracks[proxy] = track
	Proxy._rigControllers[proxy] = rigController
	Proxy._events[proxy] = events
	rigController._events[track] = events

	return (proxy :: any) :: Track
end

export type Heln = {
	new: (rig: Model, keyframeSequence: KeyframeSequence) -> Track,
}

return Controller :: Heln
