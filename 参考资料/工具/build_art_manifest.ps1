param(
    [string]$OutputRoot = "d:\new bee\generated_assets",
    [string]$DocsRoot = "d:\new bee\docs\generated",
    [switch]$DownloadStatic,
    [int]$StaticLimit = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Get-ImageSizeToken {
    param(
        [int]$Width,
        [int]$Height
    )

    if ($Width -eq $Height) {
        if ($Width -ge 1024) {
            return "square_hd"
        }
        return "square"
    }

    $ratio = [math]::Round(($Width / $Height), 4)

    if ($ratio -lt 1) {
        if ([math]::Abs($ratio - (9.0 / 16.0)) -lt [math]::Abs($ratio - (3.0 / 4.0))) {
            return "portrait_16_9"
        }
        return "portrait_4_3"
    }

    if ([math]::Abs($ratio - (16.0 / 9.0)) -lt [math]::Abs($ratio - (4.0 / 3.0))) {
        return "landscape_16_9"
    }
    return "landscape_4_3"
}

function New-Asset {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Category,
        [string]$Module,
        [string]$Priority,
        [int]$Width,
        [int]$Height,
        [int]$FrameCount,
        [bool]$TransparentBackground,
        [bool]$AutoGenerate,
        [string]$OutputRelativePath,
        [string]$Prompt,
        [string]$Notes = ""
    )

    [ordered]@{
        id = $Id
        name = $Name
        category = $Category
        module = $Module
        priority = $Priority
        width = $Width
        height = $Height
        frame_count = $FrameCount
        transparent_background = $TransparentBackground
        auto_generate = $AutoGenerate
        image_size = Get-ImageSizeToken -Width $Width -Height $Height
        output_relative_path = $OutputRelativePath
        output_path = Join-Path $OutputRoot $OutputRelativePath
        prompt = $Prompt
        notes = $Notes
    }
}

function Add-CharacterAssets {
    param([System.Collections.Generic.List[object]]$Assets)

    $characters = @(
        @{ id = "zs"; name = "破军"; weapon = "greatsword"; role = "frontline warrior"; style = "heavy armor, scarlet cape, bronze trims" },
        @{ id = "ck"; name = "穿杨"; weapon = "long spear"; role = "mid-range striker"; style = "light armor, emerald cloth, sharp silhouette" },
        @{ id = "fs"; name = "霜语"; weapon = "arcane staff"; role = "ranged mage"; style = "frost robes, crystal ornaments, blue-white palette" },
        @{ id = "fz"; name = "晨星"; weapon = "sacred warhammer"; role = "healer support"; style = "holy vestments, gold-white palette, radiant halo motifs" }
    )

    foreach ($character in $characters) {
        $basePrompt = "2D pixel art fantasy hero, three-quarter view, medieval roguelite, $($character.role), wielding $($character.weapon), $($character.style), no text"
        $Assets.Add((New-Asset -Id "$($character.id)_avatar" -Name "$($character.name)头像" -Category "角色" -Module "characters" -Priority "P0" -Width 128 -Height 128 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "characters/$($character.id)/avatar.png" -Prompt "$basePrompt, portrait icon, centered bust, transparent background"))
        $Assets.Add((New-Asset -Id "$($character.id)_battle_sprite" -Name "$($character.name)战斗精灵" -Category "角色" -Module "characters" -Priority "P0" -Width 512 -Height 512 -FrameCount 20 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "characters/$($character.id)/battle_sprite_sheet.png" -Prompt "$basePrompt, full body battle sprite sheet key art, transparent background" -Notes "4 idle + 6 attack + 2 hurt + 4 death + 4 cast")))

        for ($stage = 1; $stage -le 3; $stage++) {
            $Assets.Add((New-Asset -Id "$($character.id)_armor_stage_$stage" -Name "$($character.name)衣甲阶段$stage" -Category "角色" -Module "characters" -Priority "P0" -Width 256 -Height 256 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "characters/$($character.id)/armor_stage_$stage.png" -Prompt "$basePrompt, modular armor part concept, upgrade stage $stage, transparent background" -Notes "用于部件换装，不重画全身")))
        }
    }
}

function Add-SkillEffects {
    param([System.Collections.Generic.List[object]]$Assets)

    $skills = @(
        @{ id = "zs_lieshan"; name = "破军-裂山"; prompt = "pixel art slashing arc, heavy impact, earth crack, crimson energy" },
        @{ id = "zs_pozhen"; name = "破军-破阵"; prompt = "pixel art armor break burst, bronze fragments, shockwave" },
        @{ id = "zs_huifengzhan"; name = "破军-回风斩"; prompt = "pixel art spinning slash, circular blade trail, crimson arc" },
        @{ id = "zs_zhanhou"; name = "破军-战吼"; prompt = "pixel art taunt pulse, roaring aura, red-orange ring" },
        @{ id = "zs_duanzui"; name = "破军-断罪"; prompt = "pixel art execution strike, dark-red cleave, finishing flash" },
        @{ id = "ck_lianzhu"; name = "穿杨-连珠"; prompt = "pixel art double spear thrust trail, fast kinetic streaks" },
        @{ id = "ck_guanjia"; name = "穿杨-贯甲"; prompt = "pixel art piercing strike, armor-puncture flash, teal sparks" },
        @{ id = "ck_duopo"; name = "穿杨-夺魄"; prompt = "pixel art backline assassination impact, shadow lunge, teal trail" },
        @{ id = "ck_dunying"; name = "穿杨-遁影"; prompt = "pixel art stealth veil, fading silhouette, smoke shadow" },
        @{ id = "ck_qingxie"; name = "穿杨-倾泻"; prompt = "pixel art multi-hit barrage, rapid spear afterimages, teal burst" },
        @{ id = "fs_chiyan"; name = "霜语-炽焰"; prompt = "pixel art fire orb explosion, orange flame burst, mage cast" },
        @{ id = "fs_shuanghuan"; name = "霜语-霜环"; prompt = "pixel art frost ring, icy nova, pale blue shards" },
        @{ id = "fs_tianyun"; name = "霜语-天陨"; prompt = "pixel art meteor drop, arcane comet, blue-purple impact" },
        @{ id = "fs_midun"; name = "霜语-秘盾"; prompt = "pixel art magic shield bloom, crystal barrier, cyan glow" },
        @{ id = "fs_yanmie"; name = "霜语-湮灭"; prompt = "pixel art annihilation blast, void frost burst, bright core" },
        @{ id = "fz_shengyu"; name = "晨星-圣愈"; prompt = "pixel art healing rays, holy light, gentle upward particles" },
        @{ id = "fz_puzhao"; name = "晨星-普照"; prompt = "pixel art party heal aura, golden sunbeam, circular blessing" },
        @{ id = "fz_jinghua"; name = "晨星-净化"; prompt = "pixel art cleanse sparkles, holy purge burst, soft gold" },
        @{ id = "fz_zhudao"; name = "晨星-祝祷"; prompt = "pixel art blessing sigil, radiant emblem, support aura" },
        @{ id = "fz_poxiao"; name = "晨星-破晓"; prompt = "pixel art dawn miracle, invulnerability flash, sunrise halo" }
    )

    foreach ($skill in $skills) {
        $Assets.Add((New-Asset -Id $skill.id -Name "$($skill.name)特效" -Category "技能特效" -Module "effects" -Priority "P0" -Width 512 -Height 512 -FrameCount 8 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "effects/skills/$($skill.id).png" -Prompt "$($skill.prompt), 2D pixel art effect, transparent background, no text" -Notes "帧序列建议 6~12 帧")))
    }

    $commonEffects = @(
        @{ id = "common_basic_slash"; name = "普攻斩击"; prompt = "pixel art melee slash, bright steel arc" },
        @{ id = "common_arrow_trail"; name = "箭矢弹道"; prompt = "pixel art projectile trail, speed lines, glowing tip" },
        @{ id = "common_crit_flash"; name = "暴击闪光"; prompt = "pixel art critical hit flash, starburst, gold-white spark" },
        @{ id = "common_heal_rise"; name = "治疗上升光"; prompt = "pixel art healing rise, vertical light beam, green-gold particles" },
        @{ id = "common_levelup"; name = "升级光效"; prompt = "pixel art level up celebration, concentric glow, confetti runes" }
    )

    foreach ($effect in $commonEffects) {
        $Assets.Add((New-Asset -Id $effect.id -Name $effect.name -Category "通用特效" -Module "effects" -Priority "P0" -Width 384 -Height 384 -FrameCount 8 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "effects/common/$($effect.id).png" -Prompt "$($effect.prompt), 2D pixel art effect, transparent background, no text")))
    }
}

function Add-StatusAssets {
    param([System.Collections.Generic.List[object]]$Assets)

    $statusIcons = @(
        @{ id = "bleed"; name = "流血"; prompt = "blood drop status icon, crimson, sharp edges" },
        @{ id = "poison"; name = "中毒"; prompt = "toxic skull status icon, green fumes" },
        @{ id = "root"; name = "定身"; prompt = "binding chain status icon, iron links" },
        @{ id = "confuse"; name = "混乱"; prompt = "spiral eye status icon, chaotic purple swirl" },
        @{ id = "slow"; name = "减速"; prompt = "frozen boot status icon, pale frost" },
        @{ id = "armor_break"; name = "破甲"; prompt = "cracked shield status icon, bronze fracture" },
        @{ id = "taunt"; name = "嘲讽"; prompt = "roaring mask status icon, fiery orange" },
        @{ id = "fear"; name = "恐惧"; prompt = "shadow face status icon, dark mist" },
        @{ id = "stealth"; name = "潜伏"; prompt = "hooded silhouette status icon, muted teal" },
        @{ id = "thorns"; name = "反震"; prompt = "thorned armor status icon, red spike" },
        @{ id = "lifesteal"; name = "吸血"; prompt = "fang and drop status icon, dark ruby" },
        @{ id = "shield"; name = "护盾"; prompt = "magic barrier status icon, cyan hex shield" },
        @{ id = "invincible"; name = "无敌"; prompt = "golden crest status icon, radiant sun" },
        @{ id = "last_stand"; name = "免死"; prompt = "broken halo status icon, surviving spark" },
        @{ id = "revive"; name = "复活"; prompt = "phoenix feather status icon, sacred glow" },
        @{ id = "execute"; name = "斩杀"; prompt = "execution blade status icon, silver red slash" },
        @{ id = "dispel"; name = "驱散"; prompt = "purge swirl status icon, holy blue-white wind" }
    )

    foreach ($icon in $statusIcons) {
        $Assets.Add((New-Asset -Id "status_icon_$($icon.id)" -Name "$($icon.name)图标" -Category "状态图标" -Module "status" -Priority "P0" -Width 32 -Height 32 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "status/icons/$($icon.id).png" -Prompt "$($icon.prompt), 2D pixel art game icon, transparent background, no text")))
    }

    $statusEffects = @(
        @{ id = "bleed_splash"; name = "流血滴溅"; prompt = "pixel art blood splash effect, dynamic droplets" },
        @{ id = "poison_bubble"; name = "中毒气泡"; prompt = "pixel art poison bubble effect, toxic vapor" },
        @{ id = "shield_bubble"; name = "护盾罩"; prompt = "pixel art defensive barrier effect, shimmering sphere" },
        @{ id = "gold_body"; name = "无敌金身"; prompt = "pixel art invulnerability golden aura, metallic glow" },
        @{ id = "root_chain"; name = "定身锁链"; prompt = "pixel art binding chain effect, clamping motion" },
        @{ id = "fear_mist"; name = "恐惧黑雾"; prompt = "pixel art dark fear mist, shadow tendrils" },
        @{ id = "taunt_rage"; name = "嘲讽怒气"; prompt = "pixel art rage aura, red-orange pulse" },
        @{ id = "slow_frost"; name = "减速寒霜"; prompt = "pixel art frost slow effect, icy particles" }
    )

    foreach ($effect in $statusEffects) {
        $Assets.Add((New-Asset -Id "status_fx_$($effect.id)" -Name $effect.name -Category "状态特效" -Module "status" -Priority "P0" -Width 256 -Height 256 -FrameCount 8 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "status/effects/$($effect.id).png" -Prompt "$($effect.prompt), 2D pixel art effect, transparent background, no text")))
    }
}

function Add-Monsters {
    param([System.Collections.Generic.List[object]]$Assets)

    $themes = @(
        @{ id = "forest"; name = "森林"; normal = @("forest raider", "thorn beast", "mushroom shaman"); boss = "ancient treant tyrant" },
        @{ id = "snowfield"; name = "雪原"; normal = @("frost wolf", "ice marauder", "snow imp"); boss = "glacier mammoth king" },
        @{ id = "volcano"; name = "火山"; normal = @("lava hound", "ember cultist", "magma crawler"); boss = "obsidian drake" },
        @{ id = "tomb"; name = "墓穴"; normal = @("bone guard", "grave bat", "cursed priest"); boss = "lich sentinel" },
        @{ id = "desert"; name = "荒漠"; normal = @("sand scout", "scarab brute", "dune caster"); boss = "sunscale basilisk" },
        @{ id = "glacier"; name = "冰川"; normal = @("ice golem", "frozen harpy", "shard stalker"); boss = "white abyss wyrm" },
        @{ id = "abyss"; name = "深渊"; normal = @("void hound", "abyss acolyte", "spike fiend"); boss = "abyss watcher" },
        @{ id = "royalcity"; name = "王城"; normal = @("fallen knight", "arcane guard", "court shade"); boss = "corrupted regent" }
    )

    foreach ($theme in $themes) {
        for ($index = 0; $index -lt $theme.normal.Count; $index++) {
            $monsterId = "monster_$($theme.id)_0$($index + 1)"
            $priority = if ($theme.id -in @("forest", "snowfield") ) { "P0" } else { "P1" }
            $notes = if ($priority -eq "P0") { "阶段 1 首批小怪" } else { "按层主题扩展" }
            $Assets.Add((New-Asset -Id $monsterId -Name "$($theme.name)小怪$($index + 1)" -Category "怪物" -Module "monsters" -Priority $priority -Width 512 -Height 512 -FrameCount 16 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "monsters/$($theme.id)/$monsterId.png" -Prompt "2D pixel art monster sprite, three-quarter view, medieval fantasy, $($theme.normal[$index]), themed for $($theme.name) expedition, transparent background, no text" -Notes $notes)))
        }

        $bossPriority = if ($theme.id -eq "forest") { "P0" } else { "P1" }
        $bossNotes = if ($bossPriority -eq "P0") { "阶段 1 首批 BOSS" } else { "后续层级 BOSS" }
        $Assets.Add((New-Asset -Id "boss_$($theme.id)" -Name "$($theme.name)BOSS" -Category "怪物" -Module "monsters" -Priority $bossPriority -Width 640 -Height 640 -FrameCount 16 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "monsters/$($theme.id)/boss_$($theme.id).png" -Prompt "2D pixel art boss sprite, three-quarter view, medieval fantasy, $($theme.boss), epic silhouette, transparent background, no text" -Notes $bossNotes)))
    }

    for ($index = 1; $index -le 30; $index++) {
        $Assets.Add((New-Asset -Id ("monster_codex_{0:d2}" -f $index) -Name ("怪物图鉴半身像{0:d2}" -f $index) -Category "图鉴" -Module "monsters" -Priority "P2" -Width 256 -Height 256 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath ("monsters/codex/portrait_{0:d2}.png" -f $index) -Prompt "2D pixel art fantasy monster codex portrait, bust framing, dramatic lighting, transparent background, no text" -Notes "待与最终怪物表对齐")))
    }
}

function Add-Pets {
    param([System.Collections.Generic.List[object]]$Assets)

    $petPrompts = @(
        "mystic fox companion, agile, glowing tail",
        "stone turtle companion, sturdy shell, ancient runes",
        "ember cat companion, fiery whiskers, playful stance",
        "storm hawk companion, feather sparks, sharp gaze",
        "moon rabbit companion, ceremonial bells, pale glow",
        "bog frog companion, moss cape, alchemy vibe",
        "crystal deer companion, elegant antlers, blue shimmer",
        "shadow pup companion, dark fur, subtle violet eyes"
    )

    for ($index = 1; $index -le 8; $index++) {
        $prompt = $petPrompts[$index - 1]
        $petId = "pet_{0:d2}" -f $index
        $Assets.Add((New-Asset -Id "${petId}_avatar" -Name ("宠物头像{0:d2}" -f $index) -Category "宠物" -Module "pets" -Priority "P1" -Width 128 -Height 128 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "pets/$petId/avatar.png" -Prompt "2D pixel art pet portrait, $prompt, centered icon, transparent background, no text")))
        $Assets.Add((New-Asset -Id "${petId}_base_anim" -Name ("宠物初始形态{0:d2}" -f $index) -Category "宠物" -Module "pets" -Priority "P1" -Width 512 -Height 512 -FrameCount 13 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "pets/$petId/base_sprite.png" -Prompt "2D pixel art pet battle sprite, $prompt, three-quarter view, transparent background, no text" -Notes "4 idle + 4 attack + 2 hurt + 3 death")))
        $Assets.Add((New-Asset -Id "${petId}_evolved_anim" -Name ("宠物进化形态{0:d2}" -f $index) -Category "宠物" -Module "pets" -Priority "P1" -Width 512 -Height 512 -FrameCount 13 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "pets/$petId/evolved_sprite.png" -Prompt "2D pixel art evolved pet battle sprite, upgraded medieval fantasy design, $prompt, transparent background, no text" -Notes "每只 1 次进化")))
    }

    $petFx = @(
        @{ id = "pet_fx_claw"; name = "宠物爪击特效"; prompt = "pixel art beast claw slash, bright sparks" },
        @{ id = "pet_fx_bite"; name = "宠物撕咬特效"; prompt = "pixel art bite impact, curved motion lines" },
        @{ id = "pet_fx_elemental"; name = "宠物元素吐息"; prompt = "pixel art elemental breath, magical stream" },
        @{ id = "pet_fx_support"; name = "宠物辅助光环"; prompt = "pixel art pet support aura, soft circular energy" }
    )

    foreach ($effect in $petFx) {
        $Assets.Add((New-Asset -Id $effect.id -Name $effect.name -Category "宠物特效" -Module "pets" -Priority "P1" -Width 384 -Height 384 -FrameCount 8 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "pets/effects/$($effect.id).png" -Prompt "$($effect.prompt), 2D pixel art effect, transparent background, no text")))
    }
}

function Add-Mounts {
    param([System.Collections.Generic.List[object]]$Assets)

    $mounts = @(
        "war horse with bronze barding",
        "shadow panther with ceremonial armor",
        "mechanical boar with rune core",
        "ice elk with crystal reins",
        "lava drake hatchling with saddle harness",
        "storm lion with silk pennants"
    )

    for ($index = 1; $index -le 6; $index++) {
        $mountPrompt = $mounts[$index - 1]
        $mountId = "mount_{0:d2}" -f $index
        $Assets.Add((New-Asset -Id "${mountId}_portrait" -Name ("坐骑立绘{0:d2}" -f $index) -Category "坐骑" -Module "mounts" -Priority "P1" -Width 384 -Height 384 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "mounts/$mountId/portrait.png" -Prompt "2D pixel art mount concept, $mountPrompt, showcase pose, transparent background, no text")))
        $Assets.Add((New-Asset -Id "${mountId}_rider_layer" -Name ("坐骑骑乘层{0:d2}" -f $index) -Category "坐骑" -Module "mounts" -Priority "P1" -Width 512 -Height 512 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "mounts/$mountId/rider_layer.png" -Prompt "2D pixel art mount rider layer, $mountPrompt, side-ready compositing layer, transparent background, no text" -Notes "与人物层分离合成")))
        for ($stage = 1; $stage -le 2; $stage++) {
            $Assets.Add((New-Asset -Id "${mountId}_upgrade_$stage" -Name ("坐骑升阶{0:d2}-阶段{1}" -f $index, $stage) -Category "坐骑" -Module "mounts" -Priority "P2" -Width 384 -Height 384 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "mounts/$mountId/upgrade_$stage.png" -Prompt "2D pixel art upgraded mount concept, $mountPrompt, upgrade stage $stage, transparent background, no text")))
        }
        $Assets.Add((New-Asset -Id "${mountId}_entry_fx" -Name ("坐骑出场特效{0:d2}" -f $index) -Category "坐骑特效" -Module "mounts" -Priority "P2" -Width 384 -Height 384 -FrameCount 8 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "mounts/$mountId/entry_fx.png" -Prompt "2D pixel art mount summon effect themed to $mountPrompt, transparent background, no text")))
    }
}

function Add-MapAssets {
    param([System.Collections.Generic.List[object]]$Assets)

    $themes = @(
        @{ id = "forest"; name = "森林" },
        @{ id = "snowfield"; name = "雪原" },
        @{ id = "volcano"; name = "火山" },
        @{ id = "tomb"; name = "墓穴" },
        @{ id = "desert"; name = "荒漠" },
        @{ id = "glacier"; name = "冰川" },
        @{ id = "abyss"; name = "深渊" },
        @{ id = "royalcity"; name = "王城" }
    )

    foreach ($theme in $themes) {
        $Assets.Add((New-Asset -Id "bg_$($theme.id)" -Name "$($theme.name)战斗背景" -Category "背景" -Module "maps" -Priority "P0" -Width 480 -Height 800 -FrameCount 1 -TransparentBackground $false -AutoGenerate $true -OutputRelativePath "maps/backgrounds/$($theme.id).png" -Prompt "portrait fantasy game battle background, $($theme.name) theme, layered foreground and distant depth, medieval roguelite, no characters, no text")))
    }

    $nodes = @(
        @{ id = "start"; name = "起点"; prompt = "route node icon, glowing gate" },
        @{ id = "normal"; name = "普通"; prompt = "route node icon, crossed swords" },
        @{ id = "elite"; name = "精英"; prompt = "route node icon, horned crest" },
        @{ id = "event"; name = "事件"; prompt = "route node icon, exclamation sigil" },
        @{ id = "treasure"; name = "宝箱"; prompt = "route node icon, treasure chest" },
        @{ id = "shop"; name = "商店"; prompt = "route node icon, merchant bag" },
        @{ id = "campfire"; name = "篝火"; prompt = "route node icon, campfire flame" },
        @{ id = "boss"; name = "BOSS"; prompt = "route node icon, crown skull emblem" }
    )

    foreach ($node in $nodes) {
        $Assets.Add((New-Asset -Id "route_node_$($node.id)" -Name "$($node.name)节点" -Category "路线图" -Module "maps" -Priority "P0" -Width 96 -Height 96 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "maps/route/$($node.id).png" -Prompt "$($node.prompt), 2D pixel art icon, medieval fantasy UI, transparent background, no text")))
    }

    $Assets.Add((New-Asset -Id "route_board" -Name "路线图底板" -Category "路线图" -Module "maps" -Priority "P0" -Width 1024 -Height 768 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "maps/route/board.png" -Prompt "pixel art route map board UI, medieval fantasy parchment and carved stone frame, transparent background, no text")))
    $Assets.Add((New-Asset -Id "route_line" -Name "路线连接线" -Category "路线图" -Module "maps" -Priority "P0" -Width 512 -Height 128 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "maps/route/line.png" -Prompt "pixel art route connection line set, glowing path segments, transparent background, no text")))
    $Assets.Add((New-Asset -Id "main_bg" -Name "主界面背景" -Category "背景" -Module "maps" -Priority "P1" -Width 480 -Height 800 -FrameCount 1 -TransparentBackground $false -AutoGenerate $true -OutputRelativePath "maps/backgrounds/main.png" -Prompt "portrait fantasy game main menu background, ancient expedition city overlook, medieval roguelite, no text")))
    $Assets.Add((New-Asset -Id "abyss_pattern" -Name "深渊底纹" -Category "背景" -Module "maps" -Priority "P1" -Width 1024 -Height 1024 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "maps/backgrounds/abyss_pattern.png" -Prompt "pixel art abyss pattern texture, dark runes and violet cracks, transparent background, no text")))
    $Assets.Add((New-Asset -Id "endless_pattern" -Name "无尽底纹" -Category "背景" -Module "maps" -Priority "P1" -Width 1024 -Height 1024 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "maps/backgrounds/endless_pattern.png" -Prompt "pixel art endless mode pattern texture, celestial loops and gold-blue runes, transparent background, no text")))
}

function Add-UiAssets {
    param([System.Collections.Generic.List[object]]$Assets)

    $battleUi = @(
        "hp_bar_base","hp_bar_fill","energy_bar_base","energy_bar_fill","formation_slot_front","formation_slot_back","front_row_marker","back_row_marker","skill_slot_01","skill_slot_02","skill_slot_03","skill_slot_04","skill_slot_05","skill_cd_mask","auto_battle_button","switch_pet_button","floating_damage","floating_crit","floating_heal","battle_victory_panel","battle_defeat_panel"
    )

    foreach ($item in $battleUi) {
        $name = $item.Replace("_", " ")
        $Assets.Add((New-Asset -Id $item -Name "战斗UI-$name" -Category "战斗UI" -Module "ui_battle" -Priority "P0" -Width 256 -Height 128 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "ui/battle/$item.png" -Prompt "pixel art fantasy battle UI asset, $name, bronze and slate palette, transparent background, no text")))
    }

    for ($index = 1; $index -le 20; $index++) {
        $slotId = "battle_slot_grid_{0:d2}" -f $index
        $Assets.Add((New-Asset -Id $slotId -Name ("战斗站位格{0:d2}" -f $index) -Category "战斗UI" -Module "ui_battle" -Priority "P0" -Width 96 -Height 96 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "ui/battle/grids/$slotId.png" -Prompt "pixel art formation slot tile, tactical battle grid, transparent background, no text")))
    }

    $traitUi = @(
        @{ id = "trait_card_white"; name = "白色词条卡"; prompt = "pixel art trait card frame, common rarity, parchment white" },
        @{ id = "trait_card_blue"; name = "蓝色词条卡"; prompt = "pixel art trait card frame, rare rarity, blue glow" },
        @{ id = "trait_card_purple"; name = "紫色词条卡"; prompt = "pixel art trait card frame, epic rarity, purple glow" },
        @{ id = "trait_card_gold"; name = "金色词条卡"; prompt = "pixel art trait card frame, legendary rarity, gold glow" },
        @{ id = "trait_icon_bleed"; name = "流血流派图标"; prompt = "pixel art tribe icon, bleeding, crimson blade" },
        @{ id = "trait_icon_crit"; name = "暴击流派图标"; prompt = "pixel art tribe icon, critical, shining star" },
        @{ id = "trait_icon_thorns"; name = "反伤流派图标"; prompt = "pixel art tribe icon, thorns, spiked shield" },
        @{ id = "trait_icon_control"; name = "控制流派图标"; prompt = "pixel art tribe icon, control, chained orb" },
        @{ id = "trait_icon_energy"; name = "能量流派图标"; prompt = "pixel art tribe icon, energy, blue core" },
        @{ id = "trait_icon_summon"; name = "召唤流派图标"; prompt = "pixel art tribe icon, summon, magic sigil" },
        @{ id = "trait_double_edge"; name = "双刃标识"; prompt = "pixel art double-edged badge, twin blades" },
        @{ id = "trait_panel"; name = "词条面板"; prompt = "pixel art trait selection panel, medieval fantasy ui frame" }
    )

    foreach ($item in $traitUi) {
        $Assets.Add((New-Asset -Id $item.id -Name $item.name -Category "词条UI" -Module "ui_traits" -Priority "P0" -Width 256 -Height 256 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "ui/traits/$($item.id).png" -Prompt "$($item.prompt), transparent background, no text")))
    }

    $growthSystem = @(
        "talent_tree_panel","talent_icon_crit","talent_icon_survival","talent_icon_skill","equip_slot_weapon","equip_slot_armor","equip_slot_accessory","strengthen_panel","refine_panel","gem_panel","pet_panel","mount_panel","title_panel","currency_gold","currency_expedition","currency_soulstone","currency_honor","bag_slot","shop_panel","signin_template","exchange_template","settings_panel"
    )

    foreach ($item in $growthSystem) {
        $name = $item.Replace("_", " ")
        $Assets.Add((New-Asset -Id $item -Name "养成系统UI-$name" -Category "养成系统UI" -Module "ui_system" -Priority "P1" -Width 256 -Height 256 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "ui/system/$item.png" -Prompt "pixel art fantasy UI asset, $name, ornate frame, transparent background, no text")))
    }

    $gemColors = @("red", "blue", "green")
    foreach ($color in $gemColors) {
        for ($level = 1; $level -le 5; $level++) {
            $gemId = "gem_${color}_$level"
            $Assets.Add((New-Asset -Id $gemId -Name "宝石-$color-$level" -Category "养成系统UI" -Module "ui_system" -Priority "P1" -Width 96 -Height 96 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "ui/system/gems/$gemId.png" -Prompt "pixel art gem icon, $color gemstone, level $level, polished fantasy style, transparent background, no text")))
        }
    }

    for ($index = 1; $index -le 20; $index++) {
        $skillIconId = "skill_icon_{0:d2}" -f $index
        $Assets.Add((New-Asset -Id $skillIconId -Name ("技能图标{0:d2}" -f $index) -Category "养成系统UI" -Module "ui_system" -Priority "P1" -Width 96 -Height 96 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "ui/system/skills/$skillIconId.png" -Prompt "pixel art fantasy skill icon, dramatic action emblem, transparent background, no text" -Notes "需与 20 个人物技能对齐")))
    }

    for ($index = 1; $index -le 24; $index++) {
        $itemId = "item_icon_{0:d2}" -f $index
        $Assets.Add((New-Asset -Id $itemId -Name ("物品图标{0:d2}" -f $index) -Category "养成系统UI" -Module "ui_system" -Priority "P1" -Width 96 -Height 96 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "ui/system/items/$itemId.png" -Prompt "pixel art fantasy material item icon, crafting resource, transparent background, no text" -Notes "首批材料/消耗品")))
    }
}

function Add-PvpAndReleaseAssets {
    param([System.Collections.Generic.List[object]]$Assets)

    $pvpRanks = @("bronze", "silver", "gold", "platinum", "diamond")
    foreach ($rank in $pvpRanks) {
        $Assets.Add((New-Asset -Id "pvp_rank_$rank" -Name "PVP段位-$rank" -Category "PVP" -Module "pvp" -Priority "P1" -Width 160 -Height 160 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "pvp/ranks/$rank.png" -Prompt "pixel art pvp rank badge, $rank tier, polished fantasy medal, transparent background, no text")))
    }

    $pvpUi = @(
        "pvp_lobby_panel","pvp_matchmaking_panel","pvp_matchmaking_fx","pvp_room_panel","pvp_room_ready_button","pvp_room_invite_button","pvp_room_slot_01","pvp_room_slot_02","pvp_room_slot_03","pvp_room_slot_04","pvp_room_slot_05","pvp_room_slot_06","pvp_season_board","pvp_team_banner","pvp_opponent_banner"
    )

    foreach ($item in $pvpUi) {
        $name = $item.Replace("_", " ")
        $Assets.Add((New-Asset -Id $item -Name "PVP-$name" -Category "PVP" -Module "pvp" -Priority "P1" -Width 256 -Height 256 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "pvp/ui/$item.png" -Prompt "pixel art fantasy pvp ui asset, $name, transparent background, no text")))
    }

    $releaseAssets = @(
        @{ id = "game_logo"; name = "游戏Logo"; width = 1024; height = 512; prompt = "fantasy game logo emblem without text, sword and dawn motif, transparent background" },
        @{ id = "game_splash"; name = "启动Splash"; width = 480; height = 800; prompt = "portrait splash art for medieval fantasy roguelite, four heroes and expedition gate, no text" },
        @{ id = "loading_bar"; name = "加载进度条"; width = 512; height = 128; prompt = "pixel art loading bar ui, medieval fantasy, transparent background, no text" },
        @{ id = "app_icon"; name = "应用图标"; width = 512; height = 512; prompt = "fantasy app icon, heroic crest, polished emblem, no text" },
        @{ id = "achievement_icon_01"; name = "成就图标01"; width = 96; height = 96; prompt = "pixel art achievement icon, heroic trophy, transparent background, no text" },
        @{ id = "achievement_icon_02"; name = "成就图标02"; width = 96; height = 96; prompt = "pixel art achievement icon, treasure milestone, transparent background, no text" },
        @{ id = "achievement_icon_03"; name = "成就图标03"; width = 96; height = 96; prompt = "pixel art achievement icon, boss slayer medal, transparent background, no text" },
        @{ id = "achievement_icon_04"; name = "成就图标04"; width = 96; height = 96; prompt = "pixel art achievement icon, abyss conqueror badge, transparent background, no text" },
        @{ id = "title_icon_01"; name = "称号图标01"; width = 96; height = 96; prompt = "pixel art title icon, veteran badge, transparent background, no text" },
        @{ id = "title_icon_02"; name = "称号图标02"; width = 96; height = 96; prompt = "pixel art title icon, champion badge, transparent background, no text" }
    )

    foreach ($asset in $releaseAssets) {
        $Assets.Add((New-Asset -Id $asset.id -Name $asset.name -Category "发行物料" -Module "release" -Priority "P2" -Width $asset.width -Height $asset.height -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "release/$($asset.id).png" -Prompt $asset.prompt)))
    }

    for ($index = 1; $index -le 5; $index++) {
        $screenshotId = "store_screenshot_{0:d2}" -f $index
        $Assets.Add((New-Asset -Id $screenshotId -Name ("商店截图{0:d2}" -f $index) -Category "发行物料" -Module "release" -Priority "P2" -Width 480 -Height 800 -FrameCount 1 -TransparentBackground $false -AutoGenerate $true -OutputRelativePath "release/screenshots/$screenshotId.png" -Prompt "portrait store screenshot mockup for medieval fantasy roguelite game, polished ui scene, no text")))
    }
}

function Add-Npcs {
    param([System.Collections.Generic.List[object]]$Assets)

    $namedNpcs = @(
        @{ id = "merchant"; name = "旅行商人"; prompt = "traveling merchant, layered robes, backpack of wares" },
        @{ id = "blacksmith"; name = "铁匠"; prompt = "fantasy blacksmith, hammer, soot apron, sturdy build" },
        @{ id = "messenger"; name = "信使"; prompt = "swift messenger, courier cloak, scroll satchel" },
        @{ id = "mysterious_traveler"; name = "神秘旅者"; prompt = "mysterious traveler, hooded silhouette, glowing relic" },
        @{ id = "trapped_villager"; name = "被困村民"; prompt = "trapped villager, worn clothes, anxious expression" },
        @{ id = "wandering_knight"; name = "流浪骑士"; prompt = "wandering knight, weathered armor, noble posture" },
        @{ id = "fortune_teller"; name = "占卜师"; prompt = "fortune teller, tarot ornaments, moonlit fabrics" },
        @{ id = "abyss_cultist"; name = "深渊教徒"; prompt = "abyss cultist, dark ceremonial robes, violet aura" },
        @{ id = "abyss_gatekeeper"; name = "深渊看门人"; prompt = "abyss gatekeeper, imposing armor, key sigil" },
        @{ id = "arena_host"; name = "竞技场主持"; prompt = "arena host, flamboyant costume, herald staff" },
        @{ id = "healer_nun"; name = "修道医者"; prompt = "healer nun, calm face, medicinal satchel" },
        @{ id = "artifact_scholar"; name = "遗物学者"; prompt = "artifact scholar, notes and relic fragments" }
    )

    foreach ($npc in $namedNpcs) {
        $Assets.Add((New-Asset -Id "npc_$($npc.id)_bust" -Name "$($npc.name)半身像" -Category "NPC" -Module "npc" -Priority "P1" -Width 256 -Height 256 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "npc/$($npc.id)/bust.png" -Prompt "2D pixel art npc bust portrait, $($npc.prompt), transparent background, no text")))
        $priority = if ($npc.id -in @("merchant", "blacksmith", "messenger")) { "P0" } else { "P1" }
        $Assets.Add((New-Asset -Id "npc_$($npc.id)_avatar" -Name "$($npc.name)头像" -Category "NPC" -Module "npc" -Priority $priority -Width 128 -Height 128 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "npc/$($npc.id)/avatar.png" -Prompt "2D pixel art npc avatar icon, $($npc.prompt), transparent background, no text")))
    }

    $Assets.Add((New-Asset -Id "npc_messenger_idle" -Name "信使待机帧" -Category "NPC" -Module "npc" -Priority "P0" -Width 384 -Height 384 -FrameCount 3 -TransparentBackground $true -AutoGenerate $false -OutputRelativePath "npc/messenger/idle.png" -Prompt "2D pixel art npc idle animation, swift messenger, transparent background, no text" -Notes "3 帧")))
    $Assets.Add((New-Asset -Id "npc_dialog_bubble" -Name "对话气泡框件" -Category "NPC" -Module "npc" -Priority "P1" -Width 512 -Height 256 -FrameCount 1 -TransparentBackground $true -AutoGenerate $true -OutputRelativePath "npc/dialog/bubble.png" -Prompt "pixel art dialogue bubble ui, medieval fantasy theme, transparent background, no text")))
}

function Export-Artifacts {
    param([System.Collections.Generic.List[object]]$Assets)

    New-Directory -Path $DocsRoot
    New-Directory -Path $OutputRoot

    $jsonPath = Join-Path $DocsRoot "image_manifest.json"
    $csvPath = Join-Path $DocsRoot "image_manifest.csv"
    $staticCsvPath = Join-Path $DocsRoot "static_image_urls.csv"
    $summaryPath = Join-Path $DocsRoot "manifest_summary.md"

    $Assets | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $Assets | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    $staticAssets = foreach ($asset in $Assets) {
        if ($asset.auto_generate -and $asset.frame_count -eq 1) {
            $url = "https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=$([uri]::EscapeDataString($asset.prompt))&image_size=$($asset.image_size)"
            [pscustomobject]@{
                id = $asset.id
                name = $asset.name
                image_size = $asset.image_size
                output_path = $asset.output_path
                url = $url
            }
        }
    }

    $staticAssets | Export-Csv -LiteralPath $staticCsvPath -NoTypeInformation -Encoding UTF8

    $priorityGroups = $Assets | Group-Object priority | Sort-Object Name
    $moduleGroups = $Assets | Group-Object module | Sort-Object Name

    $summary = New-Object System.Collections.Generic.List[string]
    $summary.Add("# 图片生成汇总")
    $summary.Add("")
    $summary.Add("- 全量资产数: $($Assets.Count)")
    $summary.Add("- 可直接静态生成: $($staticAssets.Count)")
    $summary.Add("- 动画或需后处理: $((@($Assets | Where-Object { -not $_.auto_generate })).Count)")
    $summary.Add("")
    $summary.Add("## 按优先级")
    foreach ($group in $priorityGroups) {
        $summary.Add("- $($group.Name): $($group.Count)")
    }
    $summary.Add("")
    $summary.Add("## 按模块")
    foreach ($group in $moduleGroups) {
        $summary.Add("- $($group.Name): $($group.Count)")
    }
    $summary.Add("")
    $summary.Add("## 输出文件")
    $summary.Add("- image_manifest.json")
    $summary.Add("- image_manifest.csv")
    $summary.Add("- static_image_urls.csv")
    $summary.Add("")
    $summary.Add("## 下载说明")
    $summary.Add("- 运行 `pwsh -File 工具/build_art_manifest.ps1 -DownloadStatic` 下载全部静态图。")
    $summary.Add("- 使用 `-StaticLimit N` 可先试跑前 N 张。")
    $summary.Add("- 动画资产需要基于清单继续做逐帧统一风格出图和后处理。")
    $summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    return @{
        json = $jsonPath
        csv = $csvPath
        staticCsv = $staticCsvPath
        summary = $summaryPath
        staticAssets = $staticAssets
    }
}

function Download-StaticAssets {
    param(
        [object[]]$StaticAssets,
        [int]$Limit
    )

    $items = if ($Limit -gt 0) { $StaticAssets | Select-Object -First $Limit } else { $StaticAssets }
    foreach ($item in $items) {
        $targetDirectory = Split-Path -Parent $item.output_path
        New-Directory -Path $targetDirectory
        Invoke-WebRequest -Uri $item.url -OutFile $item.output_path
    }
}

$assets = [System.Collections.Generic.List[object]]::new()
Add-CharacterAssets -Assets $assets
Add-SkillEffects -Assets $assets
Add-StatusAssets -Assets $assets
Add-Monsters -Assets $assets
Add-Pets -Assets $assets
Add-Mounts -Assets $assets
Add-MapAssets -Assets $assets
Add-UiAssets -Assets $assets
Add-PvpAndReleaseAssets -Assets $assets
Add-Npcs -Assets $assets

$exportResult = Export-Artifacts -Assets $assets

if ($DownloadStatic) {
    Download-StaticAssets -StaticAssets @($exportResult.staticAssets) -Limit $StaticLimit
}

Write-Output "Manifest count: $($assets.Count)"
Write-Output "Static asset count: $((@($assets | Where-Object { $_.auto_generate -and $_.frame_count -eq 1 })).Count)"
Write-Output "JSON: $($exportResult.json)"
Write-Output "CSV: $($exportResult.csv)"
Write-Output "Static URLs: $($exportResult.staticCsv)"
Write-Output "Summary: $($exportResult.summary)"
