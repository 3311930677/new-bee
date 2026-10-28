# HapticFeedback.gd —— 移动端触觉反馈系统
# 针对不同操作层级提供触觉响应：轻震（常规点击）、中震（操作确认/购买/交付）、强震（神兵获得/突破成功/印章砸落）
# 带有节流保护（最小间隔 40ms），在非移动端平台安全空跑。
class_name HapticFeedback
extends RefCounted

static var _last_vibrate_ms := 0


## 轻震：普通按钮点击、标签页切换（约 18ms）
static func light() -> void:
	_vibrate(18)


## 中震：确认操作、任务交付、购买成功、宝石合成（约 45ms）
static func medium() -> void:
	_vibrate(45)


## 强震：稀有装备获得、突破成功、印章落地重震（约 90ms）
static func heavy() -> void:
	_vibrate(90)


static func _vibrate(duration_ms: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_vibrate_ms < 40:
		return
	_last_vibrate_ms = now
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		Input.vibrate_handheld(duration_ms)
