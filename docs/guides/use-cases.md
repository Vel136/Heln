---
sidebar_position: 1
---

# Use Cases

Practical patterns for common Heln scenarios.

---

## Basic Setup

Create a track and play it.

```lua
local Heln = require(ReplicatedStorage.Heln)

local rig = workspace.MyRig
local track = Heln.new(rig, script.Idle)

track:Play()
```

---

## Fading Between States

Crossfade weight in and out instead of snapping.

```lua
track:Play(0.25) -- fade in over a quarter second
task.wait(2)
track:Stop(0.5) -- fade out over half a second
```

---

## Layering Idle and Action Animations

Play an always-on idle at a low priority and layer a one-off action on top.

```lua
local idle = Heln.new(rig, script.Idle)
idle.Priority = Enum.AnimationPriority.Idle
idle.Looped = true
idle:Play()

local wave = Heln.new(rig, script.Wave)
wave.Priority = Enum.AnimationPriority.Action

local function playWave()
    wave:Play(0.15)
    wave.Ended:Once(function()
        wave:Stop(0.15)
    end)
end
```

---

## Snapping Back to a Rest Pose on Stop

Use `Reversible` so releasing an action eases back to the start instead of freezing mid-pose.

```lua
local reach = Heln.new(rig, script.Reach)
reach.PlaybackType = "Reversible"

local function onInputBegan()
    reach:Play()
end

local function onInputEnded()
    reach:Stop()
end
```

---

## Resumable Reversing for Held Actions

Use `ReversibleResume` for actions that can be re-triggered mid-release, like a held aim animation.

```lua
local aim = Heln.new(rig, script.Aim)
aim.PlaybackType = "ReversibleResume"

local function setAiming(isAiming)
    if isAiming then
        aim:Play()
    else
        aim:Stop()
    end
end

-- rapid toggles resume forward instead of restarting from 0
setAiming(true)
task.wait(0.3)
setAiming(false)
task.wait(0.1)
setAiming(true)
```

---

## Reversing to the Last Footstep Marker

Use `MarkerReversible` combined with keyframe-named markers so stopping mid-stride eases back to the last planted foot instead of the very start.

```lua
local walk = Heln.new(rig, script.Walk)
walk.PlaybackType = "MarkerReversible"
walk:Play()

-- Walk.Time markers include "LeftStep" and "RightStep" keyframes
```

---

## Looping a Cycle Indefinitely

```lua
local run = Heln.new(rig, script.Run)
run.PlaybackType = "LoopPersistent"
run:Play()

-- later
run:Stop(0.3)
```

---

## Listening for Footstep Events

React to named keyframes without polling `TimePosition`.

```lua
local walk = Heln.new(rig, script.Walk)

walk.KeyframeReached:Connect(function(name, value)
    if name == "Footstep" then
        playFootstepSound(value)
    end
end)

walk:Play()
```

---

## Scoped Marker Listening

Subscribe to just one marker name instead of filtering inside a shared handler.

```lua
local footstepSignal = walk:GetMarkerReachedSignal("Footstep")

footstepSignal:Connect(function(name, value)
    playFootstepSound(value)
end)
```

---

## Custom Markers Not Tied to Keyframes

Add markers at arbitrary times, useful for syncing effects that were not part of the original animation authoring.

```lua
local attack = Heln.new(rig, script.Attack)
attack:SetMarker(0.4, "HitFrame")

attack:GetMarkerReachedSignal("HitFrame"):Connect(function()
    dealDamage()
end)

attack:Play()
```

---

## Scrubbing to a Specific Point

Jump straight to a named keyframe, for example to preview a pose or resume from a checkpoint.

```lua
local time = track:GetTimeOfKeyframe("Landed")
if time then
    track.TimePosition = time
end
```

---

## Cleaning Up on Character Removal

Destroy tracks when a rig is going away to release their signals and unregister from the controller.

```lua
local tracks = {}

local function onCharacterAdded(character)
    local track = Heln.new(character, script.Idle)
    tracks[character] = track
    track:Play()
end

local function onCharacterRemoving(character)
    local track = tracks[character]
    if track then
        track:Destroy()
        tracks[character] = nil
    end
end
```

---

## Slowed and Reversed Playback

`Speed` accepts negative values for manual reverse playback, independent of `PlaybackType`.

```lua
track.Speed = -0.5
track:Play()
```
