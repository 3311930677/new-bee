extends RefCounted
## Inventory help describes the existing use of each item; inspecting never consumes it.
const USES := {
	"ticket_ten":"用于祈愿十连抽，在祈愿页面发起抽取时使用。",
	"ticket_sweep":"用于扫荡已满足条件的关卡，在历练的扫荡入口使用。",
	"enhance_stone":"装备强化材料。在养成 → 装备中选择器物进行强化。",
	"refine_stone":"装备精炼材料。在养成 → 装备中进行精炼，调整装备词条。",
	"lock_rune":"精炼时锁定想保留的词条，避免该词条随本次精炼改变。",
	"pet_food":"宠物培养材料。在养成 → 宠物中喂养宠物。",
	"break_crystal":"宠物突破材料。在养成 → 宠物的突破操作中使用。",
	"aptitude_fruit":"宠物资质培养材料。在养成 → 宠物中调整资质。",
	"evolve_crystal":"宠物进化材料。满足进化条件后，在养成 → 宠物中使用。",
	"tide_egg":"潮纹宠物的孵化凭据。推进港口主线后，可在对应孵化入口使用。",
	"stele_fragment":"失声碑窟相关的碑文凭据，供沿途主线或委托核验。",
	"salt_ledger":"盐车留下的账页，供盐道相关任务核验。",
	"gate_clue":"潮蚀水闸的调查线索，供水闸主线核验。",
	"tide_core":"潮蚀水闸相关的机关凭据，随对应任务推进使用。",
	"frost_letter":"霜关来信，供霜关相关任务核验与交付。",
	"mine_record":"矿道调查记录，供裂谷矿道相关任务核验。",
	"gate_stamp":"关闸通行的铁印凭据，供沿路任务核验。",
	"frost_reply":"双关往来的回讯，交付给对应任务人物。",
	"veil_seal":"雪幕关相关的封印凭据，随对应任务推进使用。",
	"rift_echo":"来自渊口的回响，供归路主线核验。",
	"stele_key":"进入归路相关区域的凭证，随主线推进核验。",
	"stable_seal":"碑阵稳定后的封记，供后续主线核验。",
	"stele_record":"碑心调查记录，供碑心相关任务核验。",
	"frost_nameplate":"裂纹名牌，交付给霜关对应任务人物。",
	"frost_parcel":"寒路药包，交付给对应委托人物。",
	"wind_chime":"沿途收集的旧风铃，供对应委托交付。",
	"salt_pack":"封好的盐包，供盐道相关委托交付。",
	"return_old_letter":"折角家书，供归路送信委托交付。",
	"return_mailbag":"归路邮袋，供沿途邮递委托交付。",
}

static func describe(id: String) -> String:
	if id.begins_with("gem_"):
		var stat := {"atk":"攻击","def":"防御","hp":"生命"}
		var attribute: String = stat.get(id.get_slice("_",1),"属性")
		var value := G.equip_gem_value(id)
		if value<=0:return "宝石资料暂未登记，暂不能镶嵌。"
		var level := int(id.get_slice("_",2))
		var highest := 0
		for color in G.equip_gem_colors():
			if color.id==id.get_slice("_",1):highest=color.get("values",[]).size()
		return "镶嵌后%s +%d。\n养成 → 装备 → 宝石，可镶嵌到装备孔位。%s" % [attribute,value,"3 颗同级同色宝石可合成 1 颗高一级宝石。" if level<highest else "已是当前最高等级。"]
	if id.begins_with("fish_"):
		return "垂钓收获，可在垂钓页面制成宠物粮；对应委托需要时也可交付。"
	if id.begins_with("trade_"):
		return "行商货物，可在沿路商点买卖；价格与可交易数量以商点页面为准。"
	return USES.get(id,"随行物品，当前没有登记额外用途，请查看相关任务或功能页面。")
