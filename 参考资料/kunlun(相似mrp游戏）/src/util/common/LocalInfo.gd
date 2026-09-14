class_name LocalInfo


var FileHelper
var path = "user://localinfo.conf"

var version = "1.1.21"
var info = {}

func _init() -> void :
	FileHelper = Global.get("FileHelper")
	read_info()
	pass


func read_info():
	if not FileHelper.file_exits(path): return
	info = FileHelper.read_encrypted(path, "e0-ss")


func is_read_notice():

	return false


func read():
	info.clear()
	info[version] = true
	FileHelper.save_encrypted(path, info, "e0-ss")


func get_notice():
	return notice
var notice = \
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
"\n[center]免责声明[/center]\n\n公益服[无充值，所有道具都在游戏内可获得，开局一根棍，装备全靠刷]\n本游戏代码完全原创，不收取任何费用，仅供玩家游玩或个人开发者学习交流使用。\n部分内容来源自网络，素材版权属于原作者，转载使用素材仅供大家体验和欣赏。\n如果侵害了您的合法权益，请您及时与我们联系，我们会在第一时间删除相关内容!\n请不要相信游戏内任何出售游戏道具行为，被骗概不负责。游戏内功能仅供参考，切勿\n以游戏功能做违法事情，发现即封号处理，不解封。点击确认或取消即为同意以上内容。\n拒绝以上内容请直接退出，并删除该软件。\n\n下方可查看更多更新\n\n[center]更新公告[/center]\n\n2023-11-17 更新日志\n[color=green][indent]1.修复卡蓝问题[/indent][/color]\n[color=green][indent]2.修复战斗退出后宠物无法操控问题[/indent][/color]\n[color=green][indent]3.修复部分技能问题[/indent][/color]\n[color=green][indent]4.增加 补全地图野怪[/indent][/color]\n[color=green][indent]5.增加 部分神宠[/indent][/color]\n[color=green][indent]6.增加 蓝耗减半[/indent][/color]\n[color=green][indent]7.增加 野外掉落小票[/indent][/color]\n[color=green][indent]8.增加 野外掉落部分宠物碎片[/indent][/color]\n[color=green][indent]9.增加 副本掉落小票[/indent][/color]\n[color=green][indent]10.调整 罗刹控制技能冷却-1.伤害增加，前期弱，后期强[/indent][/color]\n[color=green][indent]11.调整 幽冥前期中毒提高，后期降低，前期更加平滑[/indent][/color]\n[color=green][indent]11.调整 上调期货斗宠概率[/indent][/color]\n[color=green][indent]12.可能 装备增加更丰富的词条属性，用于平衡现阶段所有的技能和超标情况[/indent][/color]\n[color=green][indent]13.可能 宠物增加成长[/indent][/color]\n2022-11-17 更新日志\n[color=green][indent]1.修复宠物加点问题[/indent][/color]\n[color=green][indent]2.修复宠物使用忠诚丹后显示问题[/indent][/color]\n[color=green][indent]3.修复部分装备附加属性问题[/indent][/color]\n[color=green][indent]4.修复卡战斗[/indent][/color]\n[color=green][indent]5.修复部分职业的技能问题[/indent][/color]\n2022-10-30 更新日志\n[color=green][indent]1.修复装备的暴击属性不显示在面板[/indent][/color]\n[color=green][indent]2.菜单增加备忘选项(组队时也能看备忘了)[/indent][/color]\n[color=green][indent]3.修复组队不传送问题[/indent][/color]\n[color=green][indent]4.修复聊天信息容易刷没问题[/indent][/color]\n[color=green][indent]5.修复被刺不生效问题[/indent][/color]\n[color=green][indent]6.修复宠物忠诚度不实时刷新问题[/indent][/color]\n[color=green][indent]7.调整补给包容量[/indent][/color]\n[color=green][indent]8.商城增加大补给包购买[/indent][/color]\n[color=green][indent]9.上调1点大盘，期货，斗宠的最高倍数[/indent][/color]\n[color=green][indent]10.修复经验榜报错问题[/indent][/color]\n2022-10-30 更新日志\n[color=green][indent]1.调整一些显示问题[/indent][/color]\n[color=green][indent]2.增加90 100 副本[/indent][/color]\n[color=green][indent]3.修复部分野怪外显问题[/indent][/color]\n"

var notice_dev = \
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
\
"\n[center]更新公告[/center]\n\n\n2022-10-14 更新日志\n[color=green][indent]1.组队增加战斗时的信息[/indent][/color]\n[color=green][indent]2.修复师徒战斗时不加情义值的问题[/indent][/color]\n2022-10-12 更新日志\n[color=green][indent]1.增加擂台玩法[/indent][/color]\n[color=green][indent]2.增加师徒玩法[/indent][/color]\n[color=green][indent]3.增加钓鱼玩法[/indent][/color]\n[color=green][indent]4.增加玄兵塔玩法[/indent][/color]\n[color=green][indent]5.修复发烫问题[/indent][/color]\n[color=green][indent]6.修复角色抖动问题[/indent][/color]\n[color=green][indent]7.黑洞空间道具掉落提升至30%-60%[/indent][/color]\n2022-09-11 更新日志\n[color=green][indent]1.尝试修复网络切换导致的角色无法登陆的情况[/indent][/color]\n2022-09-04 更新日志\n[color=green][indent]1.增加排行榜功能[/indent][/color]\n[color=green][indent]2.修复援护没蓝打自己人情况[/indent][/color]\n[color=green][indent]3.聊天界面展示详细装备信息[/indent][/color]\n2022-09-01 更新日志\n[color=green][indent]1.完善寄卖功能[/indent][/color]\n[color=green][indent]2.修复取消练潜错误[/indent][/color]\n2022-08-30 更新日志\n[color=green][indent]1.优化善恶使者ui[/indent][/color]\n2022-08-27 更新日志\n[color=green][indent]1.增加寄卖ui（暂无功能）[/indent][/color]\n2022-08-26 更新日志\n[color=green][indent]1.完善仓库功能(银两存放，道具存放，仓库扩容等)[/indent][/color]\n2022-08-24 更新日志\n[color=green][indent]1.副本开放至70级[/indent][/color]\n2022-08-23 更新日志\n[color=green][indent]1.修复切换角色后战斗技能问题[/indent][/color]\n[color=green][indent]2.修复玉魄天晶1级可以使用的问题[/indent][/color]\n[color=green][indent]3.调整玉魄天晶的宠物奖励方法[/indent][/color]\n2022-08-05 更新日志\n[color=green][indent]1.完善邮件附件查询[/indent][/color]\n[color=green][indent]2.修复道具存入仓库有时报错问题[/indent][/color]\n2022-07-29 更新日志\n[color=green][indent]1.完善所有角色等级技能[/indent][/color]\n2022-07-25 更新日志\n[color=green][indent]1.修复部分技能没动作问题[/indent][/color]\n[color=green][indent]2.更改捕捉为技能[/indent][/color]\n[color=green][indent]3.新增防御动作[/indent][/color]\n2022-07-23 更新日志\n[color=green][indent]1.修复组队问题[/indent][/color]\n[color=green][indent]2.接入新的战斗系统[/indent][/color]\n[color=green][indent]3.重新构建战斗界面[/indent][/color]\n[color=green][indent]3.修复答题不弹出确认问题[/indent][/color]\n2022-06-29 更新日志\n[color=green][indent]1.优化内存泄露问题[/indent][/color]\n[color=green][indent]2.修复宠物显示生成了多次资源问题[/indent][/color]\n[color=green][indent]3.修改角色战斗特效组合[/indent][/color]\n2022-06-10 更新日志\n[color=green][indent]1.增加宠物的外显[/indent][/color]\n2022-06-03 更新日志\n[color=green][indent]1.优化组队跟随[/indent][/color]\n2022-06-02 更新日志\n[color=green][indent]1.修复周围人人气值不同玩家显示问题[/indent][/color]\n[color=green][indent]2.修复周围人能看见道具npc的问题[/indent][/color]\n2022-06-01 更新日志\n[color=green][indent]1.优化游戏流畅度[/indent][/color]\n[color=green][indent]2.修复好友界面可以偷袭问题[/indent][/color]\n2022-05-31 更新日志\n[color=green][indent]1.修复宝石提示是负的情况[/indent][/color]\n2022-05-30 更新日志\n[color=green][indent]1.修复锻造问题[/indent][/color]\n[color=green][indent]2.修复补给包装备问题[/indent][/color]\n[color=green][indent]3.修复修复宝石消耗过多情况[/indent][/color]\n2022-05-29 更新日志\n[color=green][indent]1.修复聊天吞信息的情况[/indent][/color]\n[color=green][indent]2.修复邮寄宠物时对方无法查看物品[/indent][/color]\n2022-05-28 更新日志\n[color=green][indent]1.新增50副本[/indent][/color]\n[color=green][indent]2.修复一些显示问题[/indent][/color]\n2022-05-22 更新日志\n[color=green][indent]1.增加怪物npc处理逻辑[/indent][/color]\n[color=green][indent]2.增加50级副本地图区域[/indent][/color]\n2022-05-14 更新日志\n[color=green][indent]1.修复部分技能不生效问题，完善偷袭功能[/indent][/color]\n[color=green][indent]2.修复部分其他bug问题[/indent][/color]\n2022-05-11 更新日志\n[color=green][indent]1.修复组队时队长退出导致其他成员无法移动的问题[/indent][/color]\n[color=green][indent]2.调整闪避计算[/indent][/color]\n[color=green][indent]3.调整经验参数[/indent][/color]\n[color=green][indent]4.完善偷袭掉落[抓捕流程缺少部分功能][/indent][/color]\n2022-05-10 更新日志\n[color=green][indent]1.优化数据传输[/indent][/color]\n[color=green][indent]2.修复角色个别动作模型的错误[/indent][/color]\n[color=green][indent]3.修复组队时跟随按钮还在显示的问题[/indent][/color]\n[color=green][indent]4.新增属性变化提示[/indent][/color]\n2022-05-07 更新日志\n[color=green][indent]1.新增宠物商人npc的功能[/indent][/color]\n2022-05-04 更新日志\n[color=green][indent]1.修复邮件能选中出战宠物的情况[/indent][/color]\n[color=green][indent]2.修复援护对自己释放的情况[/indent][/color]\n2022-05-04 更新日志\n[color=green][indent]1.修复战斗动画中出现选中目标的情况[/indent][/color]\n[color=green][indent]2.修复战斗复活时ui未及时得到变化的问题[/indent][/color]\n[color=green][indent]3.新增npc目标一键传送，支持任务，活动[/indent][/color]\n2022-05-03 更新日志\n[color=green][indent]1.修复装备在背包穿戴后上一个穿戴装备没有显示问题[/indent][/color]\n2022-05-02 更新日志\n[color=green][indent]1.修复组队的诸多问题，目前已正常[/indent][/color]\n[color=green][indent]2.宠物界面切换宠物的技能显示问题[/indent][/color]\n2022-05-01 更新日志\n[color=green][indent]1.修复银两商城内有大量装备问题[/indent][/color]\n[color=green][indent]2.修复锻造装备时有道具提示道具不足[/indent][/color]\n[color=green][indent]3.修复周围人显示问题[/indent][/color]\n[color=green][indent]4.修复对装备锻造修复等其他操作时数据不一致问题[/indent][/color]\n[color=green][indent]5.完善角色等级升级[/indent][/color]\n[color=green][indent]6.修复不能镶嵌宝石的bug[/indent][/color]\n[color=green][indent]7.修复消息的bug世界消息未识别系统[/indent][/color]\n2022-04-30 更新日志\n[color=green][indent]1.优化宠物允许加点长按[/indent][/color]\n2022-04-29 更新日志\n[color=green][indent]1.修复使用百里香串图[/indent][/color]\n[color=green][indent]2.修复装备商人里装备显示职业[/indent][/color]\n2022-04-28 更新日志\n[color=green][indent]1.优化网络流畅度[/indent][/color]\n[color=green][indent]2.修复角色诱敌自动遇怪问题[确定修复][/indent][/color]\n[color=green][indent]3.修复大部分bug[/indent][/color]\n[color=green][indent]4.修复仓库取出道具无法使用的情况[/indent][/color]\n[color=green][indent]5.修复聊天小窗口打完怪后不是自动滚动到最下的情况[/indent][/color]\n[color=green][indent]6.修复好友界面添加好友不弹输入框的问题[/indent][/color]\n[color=green][indent]7.修复出现的串图问题[/indent][/color]\n[color=green][indent]8.修复角色状态面板显示问题[/indent][/color]\n2022-04-27 更新日志\n[color=green][indent]1.去除无用的选项功能[/indent][/color]\n[color=green][indent]2.新增一键传送[复仇]和普通传送[/indent][/color]\n[color=green][indent]3.修复pk中能使用捕捉问题[/indent][/color]\n[color=green][indent]4.修复组队的显示问题[/indent][/color]\n[color=green][indent]5.修复无法通过聊天界面和周围查看对方宠物[/indent][/color]\n[color=green][indent]6.新增装备商人功能暂只支持购买[/indent][/color]\n2022-04-26 更新日志\n[color=green][indent]1.更改金币提示为银两[/indent][/color]\n[color=green][indent]2.修复角色界面没处理的异常情况[/indent][/color]\n[color=green][indent]3.修复帮派解散时界面没有刷新的情况[/indent][/color]\n[color=green][indent]4.修复遇怪报错时下次无法遇怪的问题[/indent][/color]\n[color=green][indent]5.新增服务控制的界面节点[/indent][/color]\n[color=green][indent]6.新增技能图片资源[/indent][/color]\n[color=green][indent]7.修复聊天检测帮派判断问题，修复帮派成员无法点击选项问题[/indent][/color]\n2022-04-24 更新日志\n[color=green][indent]1.战斗完后角色宠物主界面ui信息得到及时刷新[/indent][/color]\n[color=green][indent]2.部分宠物可以在升级时自动学习部分技能，目前大部分宠物技能学习数据为空[/indent][/color]\n2022-04-19 更新日志\n[color=green][indent]1.对接部分帮派操作功能无效果功能会提示功能不可用[/indent][/color]\n2022-04-12 更新日志\n[color=green][indent]1.修改任务界面奖励道具根据职业显示[/indent][/color]\n2022-04-10 更新日志\n[color=green][indent]1.新增帮派ui基本显示对接，暂未对接操作功能[/indent][/color]\n[color=green][indent]2.修复装备详情部位错乱问题[/indent][/color]\n2022-04-08 更新日志\n[color=green][indent]1.修复地图无法传送问题[/indent][/color]\n[color=green][indent]2.修复查看信息时ui错乱问题[/indent][/color]\n[color=green][indent]3.修复宠物界面的技能暂时顺序错乱[/indent][/color]\n[color=green][indent]4.修复加点属性过多问题【后端暂未更新】[/indent][/color]\n[color=green][indent]5.修复战斗时切换宠物释放了不存在的技能问题[/indent][/color]\n[color=green][indent]6.修复注册时有效字符的检测[/indent][/color]\n[color=green][indent]7.修复部分白色道具查看详情时，字体黑色被遮盖问题[/indent][/color]\n2022-04-07 更新日志\n[color=green][indent]1.修复技能无法多选的情况[/indent][/color]\n[color=green][indent]2.尝试修复串图问题[未测试][/indent][/color]\n2022-04-04 更新日志\n[color=green][indent]1.修复战斗完地图乱跳问题[/indent][/color]\n[color=green][indent]2.修复状态栏时间补零[/indent][/color]\n[color=green][indent]3.新增战斗时信息的显示[不予回合同步，测试使用][/indent][/color]\n[color=green][indent]4.新增宠物头像显示[/indent][/color]\n[color=green][indent]5.新增点击人物或宠物头像跳至对应信息界面[/indent][/color]\n[color=green][indent]6.增加角色装备面板显示练潜提示[/indent][/color]\n[color=green][indent]7.完成装备绑定,刻印,锻造,镶嵌,练潜,注潜,锻造宝石合成等功能[/indent][/color]\n\n\n\n\n"
