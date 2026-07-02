---
sidebar_position: 1
---

# Getting Started

Heln is a multi-track animation controller for Roblox Luau. It plays KeyframeSequences directly on a rig's Motor6D joints, without going through AnimationController or Animator.

---

## Installation

Drop `Heln` into `ReplicatedStorage` and require it.

```lua
local Heln = require(ReplicatedStorage.Heln)
```

Heln has no external dependencies.

---

## Creating a Track

```lua
local Heln = require(ReplicatedStorage.Heln)

local rig = workspace.MyRig
local keyframeSequence = script.MyAnimation

local track = Heln.new(rig, keyframeSequence)
```

`rig` is any `Model` with named `Motor6D` joints. `keyframeSequence` is a `KeyframeSequence` instance, the same kind you would otherwise publish and load through the Animator.

Joints are resolved by matching each Pose's name against `Motor6D.Part1.Name` on the rig. This happens lazily and is cached per rig, so joints added to the rig after `Heln.new` still animate once they exist.

---

## Playing and Stopping

```lua
track:Play()
task.wait(1)
track:Stop()
```

```lua
-- fade in over 0.3s, fade out over 0.5s
track:Play(0.3)
track:Stop(0.5)
```

---

## Listening for Events

```lua
track.Ended:Connect(function()
    print("track finished")
end)

track.KeyframeReached:Connect(function(name, value)
    print("marker:", name, value)
end)
```

---

## Quick Reference

| I want to... | Method |
|--------------|--------|
| Create a track | [`Heln.new`](../api/Heln#new) |
| Play a track | [`track:Play`](../api/Heln#Play) |
| Pause a track | [`track:Pause`](../api/Heln#Pause) |
| Stop a track | [`track:Stop`](../api/Heln#Stop) |
| Add a marker | [`track:SetMarker`](../api/Heln#SetMarker) |
| Find a keyframe's time | [`track:GetTimeOfKeyframe`](../api/Heln#GetTimeOfKeyframe) |
| Listen for markers | [`track:GetMarkerReachedSignal`](../api/Heln#GetMarkerReachedSignal) |
| Clean up a track | [`track:Destroy`](../api/Heln#Destroy) |
| See practical examples | [Use Cases](./guides/use-cases) |
