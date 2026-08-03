class_name PerfProbe
extends RefCounted

## Lightweight FPS sampling for densest-scene measurement — Steam S5.
##
## Implements: docs/STEAM_PHASE_PLAN.md Phase S5
##
## Does not raise the 20-ship budget. CI only asserts the instrument returns a
## finite fps > 0; 60fps is a play target, not a headless gate.


## Average Engine.get_frames_per_second over `frame_count` process frames.
## Returns 0.0 when tree is missing or frame_count < 1.
static func sample_average_fps(tree: SceneTree, frame_count: int) -> float:
	if tree == null or frame_count < 1:
		return 0.0
	var total: float = 0.0
	var samples: int = 0
	var i: int = 0
	while i < frame_count:
		await tree.process_frame
		var fps: float = Engine.get_frames_per_second()
		if is_finite(fps) and fps >= 0.0:
			total += fps
			samples += 1
		i += 1
	if samples <= 0:
		return 0.0
	return total / float(samples)


## Snapshot one frame's reported FPS (non-async). Useful for unit smoke.
static func snapshot_fps() -> float:
	var fps: float = Engine.get_frames_per_second()
	if not is_finite(fps) or fps < 0.0:
		return 0.0
	return fps
