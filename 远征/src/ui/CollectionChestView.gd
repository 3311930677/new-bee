extends Control
const UI:=preload("res://src/ui/TravelChestUI.gd")
const Page:=preload("res://src/ui/ChestPageUI.gd")
const Flow:=preload("res://src/ui/FlowChestUI.gd")
const Fix:=preload("res://src/ui/ReviewFixUI.gd")
var host:Control
var system:="codex"
var shell:Control
var _art:Control
var _pool:TextureRect
var _prev:Button
var _next:Button
var _index:Label
var _progress:Label
var _go:Button
var _strip:ScrollContainer
var _pedestal:TextureRect
var _frame:Control
var _shadow:Control
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell=Flow.Shell.new("灵宠图鉴" if system=="codex" else "技能研习",448 if system=="codex" else 376)
	shell.closed=func():host.closed.emit()
	add_child(shell)
	shell.background.queue_free()
	shell.background=Fix.ContextStage.new("niche" if system=="codex" else "skill")
	shell.add_child(shell.background);shell.move_child(shell.background,0)
	host._content=shell.body
	host._deck=Flow.Selection.new()
	host._deck.page_count=host._pets.size() if system=="codex" else host._sids.size()
	host._deck.page_changed.connect(func(_i:int):refresh())
	add_child(host._deck)
	_pool=Page.picture(UI.texture("stage_pool"),Vector2(256,60))
	_pool.modulate.a=.25
	shell.stage.add_child(_pool)
	_frame=Showcase.new();shell.stage.add_child(_frame)
	_shadow=ContactShadow.new();shell.stage.add_child(_shadow)
	_pedestal=Page.picture(Fix.texture("pedestal"),Vector2(200,48));shell.stage.add_child(_pedestal)
	shell.stage.move_child(_shadow,shell.stage.get_child_count()-1)
	_prev=Flow.button("‹",func():host._deck.go(host._deck.current-1))
	_next=Flow.button("›",func():host._deck.go(host._deck.current+1))
	shell.stage.add_child(_prev)
	shell.stage.add_child(_next)
	_index=UI.label("","caption",UI.AGED)
	shell.stage.add_child(_index)
	_progress=UI.label("","caption",UI.GOLD)
	_progress.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_progress)
	_go=Flow.button("进化" if system=="codex" else "研习升级",func():
		if system=="codex":host._on_evolve()
		elif not host._sids.is_empty():host._on_upgrade(String(host._sids[host._deck.current])),true)
	shell.footer.add_child(_go)
	if system=="skill":
		for i in host._sids.size():
			var index:int=i
			shell.tab(String(TableCache.get_skill(String(host._sids[i])).get("name","")),func():host._deck.go(index))
	get_viewport().size_changed.connect(layout)
	layout()
func refresh() -> void:
	Page.clear(shell.body)
	if is_instance_valid(_art):_art.queue_free()
	if system=="codex":_codex()
	else:_skill()
	layout()
	Flow.wire_focus(self)
func _codex() -> void:
	if host._pets.is_empty():return
	var p:Dictionary=host._pets[host._deck.current]
	var pid:=String(p.id)
	var owned:=G.owns_pet(pid)
	shell.tray_height=448 if owned else 396
	var state:=G.pet_stat(pid) if owned else {}
	var tex:=Fix.pet(pid)
	_art=Page.picture(tex,Vector2(192,192))
	_art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_art.modulate=Color.WHITE
	if not owned:
		var shader:=Shader.new()
		shader.code="shader_type canvas_item; void fragment(){vec4 t=texture(TEXTURE,UV); float a=0.0; for(int x=-1;x<=1;x++){for(int y=-1;y<=1;y++){a=max(a,texture(TEXTURE,UV+vec2(float(x),float(y))/64.0).a);}} COLOR=t.a>0.1?vec4(vec3(0.169,0.141,0.125),t.a):vec4(vec3(0.761,0.604,0.357),a*0.5);}"
		var material:=ShaderMaterial.new();material.shader=shader;_art.material=material
	_pool.modulate.a=.25 if owned else .08
	shell.stage.add_child(_art)
	_index.text="灵宠 %02d / %02d · %s"%[host._deck.current+1,host._pets.size(),"已结伴" if owned else "待结缘"]
	_progress.text="%d/%d"%[G.owned_pets().size(),host._pets.size()]
	shell.body.add_child(Flow.text(String(p.name) if owned else "？？？","object"))
	var lineage:=G.pet_unlock_text(pid) if owned else "尚未结缘 · 旅途中寻找线索"
	if owned:lineage+=" · "+String(G.RARITY_NAME.get(String(p.get("rarity","white")),"普通"))+" · "+String(host.ROLE_NAME.get(String(p.get("role","")),"同行"))
	shell.body.add_child(Flow.text(lineage,"body",UI.AGED))
	if owned:
		var base:Dictionary=p.get("base",{})
		shell.body.add_child(Flow.text("生命 %d · 攻击 %d · 防御 %d"%[int(base.get("hp",0)),int(base.get("atk",0)),int(base.get("def",0))],"caption",UI.AGED))
		var names:PackedStringArray=[]
		for s in p.get("skills",[]):names.append(String(s.get("name","")))
		shell.body.add_child(Flow.text("技能 · "+" · ".join(names),"caption",UI.AGED))
	_strip=ScrollContainer.new()
	_strip.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_strip.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_strip.custom_minimum_size.y=64
	shell.body.add_child(_strip)
	var thumbs:=HBoxContainer.new()
	thumbs.add_theme_constant_override("separation",8)
	_strip.add_child(thumbs)
	for i in host._pets.size():
		var cfg:Dictionary=host._pets[i]
		var b:=Page.ItemCell.new()
		b.custom_minimum_size=Vector2(56,64)
		b.item_image.texture=Fix.pet(String(cfg.id))
		b.item_image.modulate=Color.WHITE if G.owns_pet(String(cfg.id)) else Color("17141a")
		b.heading.text=""
		b.selected=i==host._deck.current
		var index:int=i
		b.pressed.connect(func():host._deck.go(index))
		thumbs.add_child(b)
		if b.selected:_strip.ensure_control_visible.call_deferred(b)
	var mile:=HBoxContainer.new()
	shell.body.add_child(mile)
	host._ms_l=Flow.text("","caption",UI.AGED)
	mile.add_child(host._ms_l)
	host._claim_btn=Flow.button("领取",host._on_claim)
	host._claim_btn.custom_minimum_size.x=88
	host._claim_btn.size_flags_horizontal=Control.SIZE_SHRINK_END
	mile.add_child(host._claim_btn)
	host._refresh_milestone()
	host._ms_l.add_theme_color_override("font_color",UI.GOLD if not G.codex_next_ready().is_empty() else UI.AGED)
	host._claim_btn.disabled=G.codex_next_ready().is_empty()
	host._claim_btn.caption.add_theme_font_size_override("font_size",14)
	var ev:Dictionary=p.get("evolve",{})
	var n:=maxi(1,int(ev.get("cost",{}).get("evolve_crystal",3)))
	_go.visible=owned
	_go.disabled=state.get("evolved",false) or ev.is_empty() or G.item_count("evolve_crystal")<n
	_go.caption.text="已进化" if state.get("evolved",false) else "进化"
	if owned and not ev.is_empty():
		var invest:=Fix.Investment.new("进化后 · 全属性" if not state.get("evolved",false) else "已进化","+%d%%"%roundi(float(ev.get("hp_pct",.25))*100),"",[],true)
		invest.costs.add_child(Fix.CostChip.new("进化晶石",n,G.item_count("evolve_crystal"),G.res_tex(G.item_icon("evolve_crystal"))))
		shell.body.add_child(invest)
		_go.subtitle.text="进化晶石差%d"%(n-G.item_count("evolve_crystal")) if G.item_count("evolve_crystal")<n else "进化晶石 %d"%n
	else:
		var card:=PanelContainer.new();var box:=StyleBoxFlat.new();box.bg_color=UI.FACE;box.border_color=UI.BRONZE;box.set_border_width_all(1);box.set_content_margin_all(16);card.add_theme_stylebox_override("panel",box)
		var content:=VBoxContainer.new();content.add_theme_constant_override("separation",8);card.add_child(content)
		content.add_child(Flow.text("如何结缘","section"));content.add_child(Flow.text(G.pet_unlock_text(pid),"body",UI.AGED));content.add_child(Flow.text("结缘后可在出征筹备中选择为同行伙伴。","caption",UI.AGED));shell.body.add_child(card)
		shell.body.move_child(mile,shell.body.get_child_count()-1)
func _skill() -> void:
	if host._sids.is_empty():return
	var sid:=String(host._sids[host._deck.current])
	var sd:=TableCache.get_skill(sid)
	var lv:=G.skill_level(sid)
	var mx:=G.skill_max_level()
	_art=preload("res://src/ui/SkillShowcase.gd").new()
	_art.skill_id=sid
	_art.role_id=G.selected_role
	shell.stage.add_child(_art)
	_index.text="招式预览"
	_progress.text="远征币 %d"%int(G.wallet.get("expedition",0))
	shell.body.add_child(Flow.text(String(sd.get("name",sid)),"object"))
	var range_words:Dictionary={"enemy_single":"单体","enemy_front_all":"前排全体","enemy_all":"敌方全体","enemy_back_single":"后排单体","enemy_random":"随机单体","ally_single":"友方单体","ally_all":"友方全体","self":"自身"}
	shell.body.add_child(Flow.text("冷却 %s 秒 · 耗能 %d · %s"%[str(sd.get("cd",0)),int(sd.get("cost",0)),range_words.get(String(sd.get("target","")),"单体")],"caption",UI.AGED))
	var description:=String(sd.get("desc","")).replace("MaxHP","最大生命").replace("ATK","攻击").replace("DEF","防御").replace("HP","生命")
	shell.body.add_child(Flow.text(description))
	var level:=Fix.Gauge.new("研习等级",UI.BLUE);level.custom_minimum_size.y=30;level.update(lv,mx);shell.body.add_child(level)
	var k:=float(sd.get("k",0))
	var increment:=float(TableCache.skillbook_config().get("k_per_level",.05))
	var studyable:=SkillSystem.can_study(sd)
	var effect:Variant=sd.get("effect")
	var kind:=String(effect.get("type","")) if effect is Dictionary else ""
	var effect_name:="伤害系数" if k>0 else "治疗量" if kind in ["heal","invincible_heal"] else "护盾量" if kind=="shield" else "攻击增益"
	var factor:=k if k>0 else 1.0
	var result:="效果固定 · 纯功能招式无需研习" if not studyable else "%s ×%.2f"%[effect_name,factor*(1+increment*(lv-1))] if lv>=mx else "%s ×%.2f → ×%.2f"%[effect_name,factor*(1+increment*(lv-1)),factor*(1+increment*lv)]
	var invest:=Fix.Investment.new(result,"效果 +%.2f"%(factor*increment) if studyable and lv<mx else "")
	shell.body.add_child(invest)
	var cost:=G.skill_upgrade_cost(sid)
	invest.costs.add_child(Fix.CostChip.new("远征币",cost,int(G.wallet.get("expedition",0)),G.res_tex("cur_expedition")))
	_go.disabled=not studyable or lv>=mx or int(G.wallet.get("expedition",0))<cost
	_go.caption.text="无需研习" if not studyable else "研习已满" if lv>=mx else "研习升级"
	_go.visible=true
	_go.subtitle.text="远征币不足 · 差%d"%(cost-int(G.wallet.get("expedition",0))) if int(G.wallet.get("expedition",0))<cost else "远征币 %d"%cost
	for i in shell.tabs.get_child_count():shell.tabs.get_child(i).selected=i==host._deck.current;shell.tabs.get_child(i).queue_redraw()
func layout(safe_override:Rect2=Rect2()) -> void:
	shell.layout(safe_override)
	if system=="codex" and not _go.visible:
		shell.footer.visible=false;shell.scroll.size.y=shell.safe.end.y-shell.scroll.position.y-16
	Page.place(_prev,Vector2(16,shell.stage.size.y*.5-28),Vector2(44,56))
	Page.place(_next,Vector2(shell.stage.size.x-60,shell.stage.size.y*.5-28),Vector2(44,56))
	Page.place(_index,Vector2(28,12),Vector2(360,26))
	Page.place(_pool,Vector2(shell.stage.size.x*.5-128,shell.stage.size.y-76),Vector2(256,60))
	Page.place(_frame,Vector2(16,48),Vector2(shell.stage.size.x-32,shell.stage.size.y-64))
	Page.place(_pedestal,Vector2(shell.stage.size.x*.5-100,shell.stage.size.y-64),Vector2(200,48))
	_pedestal.visible=system=="codex"
	_frame.visible=system=="codex"
	Page.place(_progress,Vector2(shell.safe.end.x-172,shell.safe.position.y+14),Vector2(160,28))
	if is_instance_valid(_art):
		var dimensions:=Vector2(shell.stage.size.x-144,maxf(1,shell.stage.size.y-64))
		if system=="codex" and (_art as TextureRect).texture!=null:
			var source:=(_art as TextureRect).texture.get_size()
			var factor:=minf(3,minf(dimensions.x/source.x,minf(200,dimensions.y-32)/source.y))
			if factor>=1:factor=maxf(1,floorf(factor))
			dimensions=source*factor
		var feet:=1.0
		if system=="codex":
			var texture:Texture2D=(_art as TextureRect).texture
			var used:=preload("res://src/ui/NameTagLayout.gd").opaque_bounds(texture)
			feet=float(used.end.y)/texture.get_height()
		Page.place(_art,Vector2((shell.stage.size.x-dimensions.x)*.5,shell.stage.size.y-40-dimensions.y*feet) if system=="codex" else Vector2(72,44),dimensions)
		var shadow_width:=64.0
		if system=="codex":shadow_width=preload("res://src/ui/NameTagLayout.gd").opaque_bounds((_art as TextureRect).texture).size.x*dimensions.x/(_art as TextureRect).texture.get_width()*.8
		Page.place(_shadow,Vector2((shell.stage.size.x-shadow_width)*.5,shell.stage.size.y-45),Vector2(shadow_width,10));_shadow.visible=system=="codex";_shadow.queue_redraw()
		shell.stage.move_child(_prev,shell.stage.get_child_count()-1)
		shell.stage.move_child(_next,shell.stage.get_child_count()-1)

class ContactShadow extends Control:
	func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_set_transform(Vector2(size.x*.5,5),0,Vector2(1,10/maxf(1,size.x)));draw_circle(Vector2.ZERO,size.x*.5,Color("0a090b",.55))
class Showcase extends Control:
	const Fix=preload("res://src/ui/ReviewFixUI.gd")
	const UI=preload("res://src/ui/TravelChestUI.gd")
	func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _draw() -> void:UI.nine(self,Fix.texture("showcase_frame"),size)
