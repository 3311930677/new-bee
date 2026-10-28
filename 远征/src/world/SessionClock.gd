extends RefCounted
## Session timers follow elapsed time; wall-clock changes cannot skip cooldowns.
var _unix := -1
var _ticks := 0

func now(system_sec: int, ticks_msec: int, watermark: int) -> int:
	if _unix < 0:
		_unix = maxi(system_sec, watermark)
		_ticks = ticks_msec
	var current := _unix + maxi(0, ticks_msec - _ticks) / 1000
	if watermark > current:
		_unix = watermark
		_ticks = ticks_msec
		current = watermark
	return current
