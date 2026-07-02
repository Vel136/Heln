-- MIT License
--
-- Copyright (c) 2026 Ve Development

--[=[
	@class Heln

	A multi-track animation controller for Roblox rigs.

	Heln reads a KeyframeSequence into per-joint timelines once, then evaluates
	those timelines against a Model's Motor6D joints every frame and writes
	directly to Motor6D.Transform. This bypasses AnimationController and
	Animator, so animations do not need to be published as Roblox Animation
	assets and can run on any rig with matching joint names.

	Joints are resolved by matching each Pose's name against Motor6D.Part1.Name
	on the rig, cached per rig and invalidated when a Motor6D is added or
	removed.

	```lua
	local Heln = require(ReplicatedStorage.Heln)

	local track = Heln.new(rig, keyframeSequence)
	track:Play()

	track.Ended:Connect(function()
	    print("done")
	end)
	```
]=]
local Heln = {}

--[=[
	@function new
	@within Heln

	Creates a new Track that animates `rig` using `keyframeSequence`.

	```lua
	local track = Heln.new(workspace.MyRig, script.MyAnimation)
	```

	@param rig Model -- Rig containing named Motor6D joints.
	@param keyframeSequence KeyframeSequence -- Sequence to play.
	@return Track
]=]
function Heln.new(rig, keyframeSequence) end

--[=[
	@method Play
	@within Heln

	Starts or re-fades the track. If the track is already playing, this
	re-fades WeightCurrent toward `weight` instead of restarting.

	```lua
	track:Play()

	-- fade in over 0.3s at half weight, double speed
	track:Play(0.3, "Linear", 0.5, 2)
	```

	@param fadeTime number? -- Seconds to blend weight. Defaults to instant.
	@param fadeStyle string? -- "Linear", "Constant", "Elastic", "Cubic", or "Bounce". Defaults to "Linear".
	@param weight number? -- Target blend weight. Defaults to the current WeightTarget.
	@param speed number? -- Playback speed multiplier. Negative plays backward.
]=]
function Heln:Play(fadeTime, fadeStyle, weight, speed) end

--[=[
	@method Pause
	@within Heln

	Freezes the track at its current TimePosition. Calling Play again resumes
	from there.

	```lua
	track:Pause()
	```
]=]
function Heln:Pause() end

--[=[
	@method Stop
	@within Heln

	Stops the track, honoring its PlaybackType. Persistent playback types hold
	their current pose; reversible playback types begin playing backward
	toward time 0 or a marker before finishing.

	```lua
	track:Stop()

	-- fade weight to 0 over half a second before stopping
	track:Stop(0.5)
	```

	@param fadeTime number? -- Seconds to fade weight to 0 before stopping. Defaults to instant.
	@param fadeStyle string? -- Easing curve for the fade. Defaults to "Linear".
]=]
function Heln:Stop(fadeTime, fadeStyle) end

--[=[
	@method GetTimeOfKeyframe
	@within Heln

	Returns the time of a named keyframe from the sequence, or nil if no
	keyframe with that name exists.

	```lua
	local time = track:GetTimeOfKeyframe("Landed")
	```

	@param keyframeName string
	@return number?
]=]
function Heln:GetTimeOfKeyframe(keyframeName) end

--[=[
	@method SetMarker
	@within Heln

	Adds a custom marker at `time`, independent of any Keyframe instance.
	Custom markers are searched alongside keyframe-derived markers by
	GetPreviousMarker, GetNextMarker, and GetNearestMarker, and fire
	KeyframeReached the same way.

	```lua
	track:SetMarker(0.4, "HitFrame")
	```

	@param time number
	@param name string? -- Defaults to an empty string.
	@param value any -- Payload passed to KeyframeReached and marker signals.
]=]
function Heln:SetMarker(time, name, value) end

--[=[
	@method GetPreviousMarker
	@within Heln

	Returns the closest marker (keyframe-derived or custom) strictly before
	`fromTime`, or nil if there is none.

	```lua
	local marker = track:GetPreviousMarker(1.0)
	```

	@param fromTime number
	@return Marker?
]=]
function Heln:GetPreviousMarker(fromTime) end

--[=[
	@method GetNextMarker
	@within Heln

	Returns the closest marker strictly after `fromTime`, or nil if there is
	none.

	```lua
	local marker = track:GetNextMarker(1.0)
	```

	@param fromTime number
	@return Marker?
]=]
function Heln:GetNextMarker(fromTime) end

--[=[
	@method GetNearestMarker
	@within Heln

	Returns whichever marker is closest to `fromTime`, preferring the next
	marker on a tie.

	```lua
	local marker = track:GetNearestMarker(1.0)
	```

	@param fromTime number
	@return Marker?
]=]
function Heln:GetNearestMarker(fromTime) end

--[=[
	@method GetMarkerReachedSignal
	@within Heln

	Returns a signal scoped to markers with the exact name `name`, created
	lazily on first request.

	```lua
	track:GetMarkerReachedSignal("Footstep"):Connect(function(name, value)
	    playFootstepSound(value)
	end)
	```

	@param name string
	@return Signal
]=]
function Heln:GetMarkerReachedSignal(name) end

--[=[
	@method Destroy
	@within Heln

	Stops the track, unregisters it from the rig's update loop, and destroys
	all of its signals, including any created via GetMarkerReachedSignal.
	Reading or writing properties on a destroyed track raises an error.

	```lua
	track:Destroy()
	```
]=]
function Heln:Destroy() end

return Heln
