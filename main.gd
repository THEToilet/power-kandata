extends Node2D
## ドット絵版。640x360 で描いて、2倍に拡大して表示する。
## 操作: W/↑ 登る  A/D 揺らす  Space 叫ぶ  R やり直し  N 新コース  F1 調整

const ThreadModel = preload("res://thread_model.gd")

const W := 640.0
const H := 360.0
const FIELD_W := 616.0       # 遊ぶ画面の幅（右端の細い高度バー以外ぜんぶ）
const THREAD_X := 308.0      # 揺れの中心
const PLAYER_SY := 236.0     # カンダタを置く高さ
const PPM := 3.5             # 1m あたりのドット
const LAVA_OFF := 16.0       # マグマの表面の描画位置（0m のとき、ちょうど地表にそろう）
const XS := 0.7              # モデルの横位置（px@1280）→ 画面ドット
const GHOST_GAP := 12.0
const MAP_X := 625.0         # 高度マップ（縦の再生バー）
const MAP_TOP := 34.0
const MAP_BOT := 330.0
const PANEL_X := 640.0
const TUNING_PATH := "user://tuning_v2.json"   # 標準から変えた値だけ保存する
# 開発用の機能（F1/TAB の調整パネル、保存した調整値の読み込み、プレイ中の R/N リスタート）。公開版は false
const DEV_TOOLS := false

# ---- パレット（地獄っぽい少色）
const C_BLACK := Color8(14, 8, 14)
const C_DARK := Color8(34, 18, 30)
const C_BLOOD := Color8(112, 20, 28)
const C_RED := Color8(178, 40, 40)
const C_ORANGE := Color8(236, 120, 40)
const C_YELLOW := Color8(250, 210, 90)
const C_GOLD := Color8(232, 180, 70)
const C_SKIN := Color8(236, 178, 120)
const C_HAIR := Color8(40, 24, 24)
const C_CLOTH := Color8(132, 84, 52)
const C_GHOST := Color8(150, 140, 190)
const C_GHOST_D := Color8(96, 86, 140)
const C_WHITE := Color8(240, 236, 228)
const C_GREY := Color8(120, 110, 112)
const C_ROCK := Color8(132, 116, 106)
const C_ROCK_D := Color8(86, 74, 70)
const C_ROCK_L := Color8(178, 162, 148)
const C_GREEN := Color8(96, 196, 96)
const C_CYAN := Color8(110, 210, 230)
const C_PURPLE := Color8(170, 150, 236)
const C_SKY_HI := Color8(58, 132, 228)
const C_SKY_LO := Color8(176, 222, 250)
const C_CLOUD := Color8(250, 250, 255)
const C_CLOUD_S := Color8(200, 214, 240)
const C_GRASS := Color8(88, 178, 72)
const C_GRASS_D := Color8(52, 130, 56)
const C_GRASS_L := Color8(150, 214, 96)
const C_HILL := Color8(120, 176, 170)
const C_HILL_D := Color8(92, 150, 150)

# ---- ドット絵（1文字 = 1ドット）
const SPR_KANDATA := [
	".....ss.....",
	"....s..s....",
	"...shhhhs...",
	"..hhhhhhhh..",
	"..hhhhhhhh..",
	"..hssssssh..",
	"..sksssksh..",
	"..ssssssss..",
	"...ssmmss...",
	"..cccccccc..",
	"..cccccccc..",
	"...cccccc...",
	"...cc..cc...",
	"...ss..ss...",
	"...ss..ss...",
	"..sss..sss..",
]
const SPR_KANDATA_JUMP := [
	"..s......s..",
	"..s......s..",
	"..sh....hs..",
	"..hhhhhhhh..",
	"..hhhhhhhh..",
	"..hssssssh..",
	"..sksssksh..",
	"..ssssssss..",
	"...ssmmss...",
	"..cccccccc..",
	"..cccccccc..",
	"..cccccccc..",
	"...cc..cc...",
	"..ss....ss..",
	".ss......ss.",
	"............",
]
# 蹴落とし: ためて（両ひざを引き上げる）→ 片足で真下を踏みつける
const SPR_KANDATA_KICK_A := [
	".....ss.....",
	"....s..s....",
	"...shhhhs...",
	"..hhhhhhhh..",
	"..hhhhhhhh..",
	"..hssssssh..",
	"..sksssksh..",
	"..ssssssss..",
	"...smmmms...",
	"..cccccccc..",
	"..cccccccc..",
	"..sccccccs..",
	"..ss....ss..",
	"............",
	"............",
	"............",
]
const SPR_KANDATA_KICK_B := [
	".....ss.....",
	"....s..s....",
	"...shhhhs...",
	"..hhhhhhhh..",
	"..hhhhhhhh..",
	"..hssssssh..",
	"..sksssksh..",
	"..ssssssss..",
	"...smmmms...",
	"..cccccccc..",
	"..cccccccc..",
	"...ccccccss.",
	"...cc....s..",
	"...ss.......",
	"...ss.......",
	"...sss......",
]
# 登りのモーション: 左手を上へ伸ばし、右手は腰で糸を握る。右足を引き上げる（左右反転で逆の手足）
const SPR_KANDATA_REACH := [
	".....ss.....",
	"....s.......",
	"...shhhhh...",
	"..shhhhhhh..",
	"..hhhhhhhh..",
	"..hssssssh..",
	"..sksssksh..",
	"..ssssssss..",
	"...ssmmss...",
	"..cccccccc..",
	"..ccccccccs.",
	"...cccccc.s.",
	"...cc..ccs..",
	"..sss..ss...",
	"........ss..",
	"........sss.",
]
# 罪人: カンダタと同じ立場の人間。顔つき・体つきは同じで、髪と腰布の色だけが違う
const SPR_GHOST := [
	"s.........",
	".s.hhhh...",
	"..hhhhhhh.",
	"..hhhhhhh.",
	"..hsssssh.",
	"..skssks..",
	"..sssssss.",
	"...smms...",
	"..ccccccc.",
	"..ccccccs.",
	"...cc.cc..",
	"...s...s..",
	"..ss...ss.",
]
const SPR_GHOST_RUN := [
	"s.........",
	".s..hhh...",
	"..shhhhh..",
	"..hhhhhhh.",
	"..hsssssh.",
	"..skssks..",
	"..sssssss.",
	"...smms...",
	"..ccccccc.",
	"..ccccccs.",
	"...ccccc..",
	"..s....s..",
	".ss.....ss",
]
# 鬼: 崖の岩棚に現れて、岩を投げてくる。赤い肌・角・虎の腰布
const SPR_ONI_UP := [   # 振りかぶり（両手で岩を頭上に）
	"r.y......y.r",
	"r.yy....yy.r",
	"rr.hhhhhh.rr",
	".rhhhhhhhhr.",
	"..hrrrrrrh..",
	"..rwkrrkwr..",
	"..rrrrrrrr..",
	"...rwwwwr...",
	"..rrrrrrrr..",
	"..rrddrrrr..",
	"..rrrrrrrr..",
	"...tbtbtt...",
	"...tbtbtb...",
	"...rr..rr...",
	"..rrr..rrr..",
]
const SPR_ONI_THROW := [   # 投げた（右へ腕を伸ばす）
	"..y......y..",
	"..yy....yy..",
	"...hhhhhh...",
	"..hhhhhhhh..",
	"..hrrrrrrh..",
	"..rwkrrkwr..",
	"..rrrrrrrr..",
	"...rwwwwr...",
	"..rrrrrrrrrr",
	".rrrddrrr...",
	"rr.rrrrrr...",
	"r..tbtbtt...",
	"...tbtbtb...",
	"...rr..rr...",
	"..rrr..rrr..",
]
const ONI_PAL := {"r": Color8(196, 52, 44), "d": Color8(140, 32, 30), "y": Color8(236, 226, 196), "h": Color8(30, 18, 18),
		"w": Color8(250, 248, 236), "k": Color8(20, 10, 10), "t": Color8(236, 184, 48), "b": Color8(30, 20, 16)}
const GHOST_HAIR := [Color8(40, 24, 24), Color8(24, 18, 20), Color8(64, 40, 30), Color8(52, 44, 44)]
const SPR_FIRE := [
	[
		"......y.....",
		".....yy.....",
		"....yyo.....",
		"...yyooo....",
		"...yowwo..o.",
		"..yowwwwoo..",
		"..owwwwwwo..",
		".oowwwwwwoo.",
		".oowwwwwwoo.",
		"..oowwwwoo..",
		"...oooooo...",
		".....oo.....",
	],
	[
		".....y......",
		".....yy.....",
		".....oyy....",
		"....oooyy...",
		".o..owwoy...",
		"..oowwwwoy..",
		"..owwwwwwo..",
		".oowwwwwwoo.",
		".oowwwwwwoo.",
		"..oowwwwoo..",
		"...oooooo...",
		".....oo.....",
	],
]
const SPR_LOTUS := [
	"...y...",
	"..yyy..",
	"y.yyy.y",
	"yyyyyyy",
	".yyyyy.",
]
const SPR_CLOUD := [
	".......wwww.............",
	".....wwwwwwww...........",
	"...wwwwwwwwwwww..wwww...",
	"..wwwwwwwwwwwwwwwwwwwww.",
	".wwwwwwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwwwwwwwwwww",
	".ssssssssssssssssssssss.",
	"..ssssssssssssssssssss..",
]
const SPR_SPIDER := [
	"l..l.....l..l",
	".l..l...l..l.",
	"..l.lbbbl.l..",
	"llllbbbbbllll",
	"....bebeb....",
	"llllbbbbbllll",
	"..l.lbbbl.l..",
	".l...bbb...l.",
	"l.....b.....l",
]
const SPR_LOTUS_FLOWER := [
	".....P.....",
	"...p.P.p...",
	"..pPpPpPp..",
	".pPPPyPPPp.",
	"..pPPPPPp..",
	"ggggggggggg",
	".ggggggggg.",
]
const SPR_LILY_PAD := [
	"..gggg.gggg..",
	".gggggggggggg",
	"ggggGggggGggg",
	".ggggggggggg.",
]
const SPR_BUDDHA := [
	"........hh........",
	".......hhhh.......",
	".....hhhhhhhh.....",
	"....hhhhhhhhhh....",
	"....hhhhhhhhhh....",
	"....ssssswssss....",
	"...sskkssssskks...",
	"...ssssssssssss...",
	"...s.sssssssss.s..",
	"...s..ssmmmss..s..",
	".......ssssss.....",
	".....rrrsssrrr....",
	"...rrrrrrssrrrrr..",
	"..rrrrrrrrrrrrRr..",
	"..rrRrrrrrrrrrRr..",
	".rrrRrrrrrrrrrRrr.",
	".rrrRrrsssssrrRrr.",
	".rrrRrrsssssrrRrr.",
	"rrrrrrrrrrrrrrrrrr",
	"rRRRRRRRRRRRRRRRRr",
	".rrrrrrrrrrrrrrrr.",
]
const SPR_PEDESTAL := [
	"..p..p..p..p..p..p..p..",
	".pPp.pPppPp.pPppPp.pPp.",
	"pPPPpPPPPPPpPPPPPPpPPPp",
	"ppppppppppppppppppppppp",
	".ggggggggggggggggggggg.",
]
const SPR_BIRD := [
	"b...b",
	".b.b.",
	"..b..",
]
const SPR_HEAD := [
	".hhhh.",
	"hhhhhh",
	"hssssh",
	"skssks",
	"ssssss",
	".ssss.",
]

enum Phase { TITLE, PLAY, RESULT }

var model: ThreadModel = ThreadModel.new()
var tuning: Dictionary = ThreadModel.DEFAULTS.duplicate()
var course := 1
var difficulty := 2              # 難易度は「むずかしい」だけ（選択はなくした。記録・ランキングもこの枠を使う）
const BEST_PATH := "user://records_v3.txt"   # 難易度ごとの最高到達（m）と、最速クリア（秒）
var best := [0, 0, 0]              # 最高到達 m
var best_time := [0.0, 0.0, 0.0]   # 最速クリア 秒（0 = まだクリアしていない）
const RANKING_PATH := "user://ranking_v1.json"   # 難易度ごとのクリアタイム上位10件
const RANKING_SIZE := 10
var ranking := [[], [], []]        # [{"t": 秒, "d": "MM/DD"}, ...] 速い順
var new_rank := -1                 # 今回のタイムが入った順位（0始まり、入らなければ -1）
var new_record := false
var phase := Phase.TITLE
var t := 0.0
var phase_t := 0.0
var cam_h := 0.0
var font: Font
var falling_ghosts: Array = []   # [pos, vel, rot]
var falling_thread: Array = []   # [world_h, x, age]
var popups: Array = []           # [text, world_h, x, age, color]
var fx_shout := 0.0
var shout_age := 99.0            # 叫んでからの実時間（ヒットストップ中も進む。文字の打ち込みや集中線に使う）
var shout_clutch := false        # 直前の叫びが九死に一生か
var hitstop_total := 0.0         # 直前のヒットストップの長さ
var slowmo := 0.0                # スローモーションの残り（九死に一生）
var invert_t := 0.0              # 白黒反転の残り（九死に一生の瞬間）
var invert_rect: ColorRect
var base_xf := Transform2D.IDENTITY   # 世界を描くときの変形（揺れ＋叫びのズーム）
var ripple_rect: ColorRect
var shout_hold := 0.0            # 叫んだ直後にカメラを留める残り時間
var hitstop := 0.0               # ヒットストップの残り時間（秒）
var hitstop_frames := 0          # ヒットストップに入ってからのフレーム数（最初の数フレームだけ光らせる）
var stomp_fx := 0.0              # 叫びの衝撃波（残り時間）
const BLAST_TIME := 0.5
var blast_at := Vector2.ZERO     # 衝撃波の中心（x: モデルpx, y: 高さ m）
var blast_px := 0.0              # 衝撃波の半径（画面px）
const C_SILK := Color8(226, 224, 236)   # 蜘蛛の糸の色
var ring_nope := 0.0
const NOPE_TIME := 0.7
const KICK_TIME := 0.24    # 蹴りのポーズを見せる長さ
var anim_h := 0.0                # 登りモーション用: 前のフレームの高さ
var climb_phase := 0.0           # 登った距離で進むモーションの位相
var climb_moving := 0.0          # 登っている最中なら 1（少し余韻を残す）
var last_climb_frame := 0
var tips_seen := {}              # 一度出した案内（このセッション中は二度と出さない）
var tip_queue: Array = []
var tip_text := ""
var tip_t := 0.0
const TIP_TIME := 3.2
var parts: Array = []            # パーティクル [pos, vel, life, max_life, color, size, gravity, drag]
var prev_cam := 0.0
var prev_state := 0
var shout_text := "降りろ！"
const SHOUT_LINES := ["降りろ！", "俺のものだ！"]
var early_t := 0.0               # 早すぎる Space の注意表示
var fx_hit := 0.0
var shake := 0.0
var fall_t := 0.0
var torn_x := 0.0               # 糸が切れた位置（上の糸が跳ね上がる起点）
const GAMEOVER_DELAY := 1.4     # 落ちていく様子を見せてから GAME OVER を出すまで（秒）
# クリア後: 極楽の景色 → ランキングの枠 → 1位から順に1行ずつ → 全部出たらリトライできる
const WIN_RANK_AT := 2.6        # ランキングの枠が出はじめる（秒）
const WIN_ROW_AT := 3.1         # 1位の行が出る
const WIN_ROW_STEP := 0.12      # 1行ずつの間隔
const WIN_READY := WIN_ROW_AT + WIN_ROW_STEP * 10 + 0.5   # これより前はリトライ不可
var go_jingled := false
var panel_open := false
var credits_open := false
var shout_armed := false   # スタートに使ったボタンを離したら true（それまで叫ばない）
var panel_sel := 0
var draw_off := Vector2.ZERO     # 画面揺れのオフセット（文字の拡大描画で使う）

# 自動プレイ（スクリーンショット・検証用）
var autopilot := false
var bot_climb := false
var bot_shout := false
var bot_swing := 0.0


func _ready() -> void:
	_setup_audio()
	_setup_invert()
	_setup_ripple()
	get_window().title = "パワーカンダタ"   # 記録の保存先が変わらないよう、プロジェクト名は変えずにウィンドウの題だけ変える
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 書き出し版（exe / Web）には ttf そのものは入らないので、インポート済みのフォントを読む。未インポートなら ttf を直接
	const FONT_PATH := "res://fonts/DotGothic16-Regular.ttf"
	var f: FontFile = null
	if ResourceLoader.exists(FONT_PATH):
		f = load(FONT_PATH) as FontFile
	if f == null:
		f = FontFile.new()
		if f.load_dynamic_font(FONT_PATH) != OK:
			f = null
	if f != null:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		var fb := SystemFont.new()
		fb.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Noto Sans CJK JP"])
		f.fallbacks = [fb]
		font = f
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "Noto Sans CJK JP"])
		font = sf
	_setup_pad()
	if DEV_TOOLS:
		_load_tuning()   # 公開版では保存した調整値を読まない（誰が遊んでも同じバランス）
	if FileAccess.file_exists(BEST_PATH):
		var parts2 := FileAccess.get_file_as_string(BEST_PATH).split(",")
		for k in range(mini(parts2.size(), 6)):
			if k < 3:
				best[k] = int(parts2[k])
			else:
				best_time[k - 3] = float(parts2[k])
	_load_ranking()
	course = randi_range(1, 999)
	_new_model()


func _setup_ripple() -> void:
	# 叫びの衝撃波で、背景が押し広げられる空間のゆがみ（画面を読み取ってずらす）
	var layer := CanvasLayer.new()
	layer.layer = 40
	ripple_rect = ColorRect.new()
	ripple_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ripple_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 center = vec2(320.0, 180.0);
uniform float radius = 0.0;
uniform float width = 26.0;
uniform float strength = 10.0;
void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 d = px - center;
	float dist = length(d);
	float band = clamp(1.0 - abs(dist - radius) / width, 0.0, 1.0);
	vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
	vec2 off = -dir * band * band * strength;          // 波の手前に押し寄せるようにずらす
	vec3 c = texture(screen_tex, (px + off) * SCREEN_PIXEL_SIZE).rgb;
	c += vec3(0.25, 0.18, 0.08) * band * band * (strength / 14.0);   // 波の頭がうっすら光る
	COLOR = vec4(c, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	ripple_rect.material = mat
	ripple_rect.visible = false
	layer.add_child(ripple_rect)
	add_child(layer)


func _update_ripple() -> void:
	if ripple_rect == null:
		return
	var on := stomp_fx > 0.0 and phase == Phase.PLAY
	ripple_rect.visible = on
	if not on:
		return
	var bk := 1.0 - stomp_fx / BLAST_TIME
	var grow := 1.0 - pow(1.0 - minf(bk / 0.6, 1.0), 2.0)
	var mat: ShaderMaterial = ripple_rect.material
	mat.set_shader_parameter("center", Vector2(_sx(blast_at.x), _sy(blast_at.y)) + draw_off)
	mat.set_shader_parameter("radius", blast_px * grow)
	mat.set_shader_parameter("width", 18.0 + 20.0 * grow)
	mat.set_shader_parameter("strength", (16.0 if shout_clutch else 11.0) * (1.0 - bk))


func _setup_invert() -> void:
	# 画面の白黒反転（九死に一生の瞬間だけ表示）
	var layer := CanvasLayer.new()
	layer.layer = 50
	invert_rect = ColorRect.new()
	invert_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	invert_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform sampler2D screen_tex : hint_screen_texture, filter_nearest;\nvoid fragment() { vec3 c = texture(screen_tex, SCREEN_UV).rgb; COLOR = vec4(vec3(1.0) - c, 1.0); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	invert_rect.material = mat
	invert_rect.visible = false
	layer.add_child(invert_rect)
	add_child(layer)


func _new_model() -> void:
	model = ThreadModel.new()
	# 調整パネルで標準から変えた値だけを、難易度の上に重ねる
	var changed := {}
	for k in tuning:
		if not is_equal_approx(tuning[k], ThreadModel.DEFAULTS[k]):
			changed[k] = tuning[k]
	model.setup(changed, course, difficulty)


func _restart() -> void:
	_new_model()
	cam_h = 0.0
	falling_ghosts.clear()
	falling_thread.clear()
	popups.clear()
	parts.clear()
	tip_queue.clear()
	tip_text = ""
	fx_shout = 0.0
	slowmo = 0.0
	invert_t = 0.0
	shout_age = 99.0
	fx_hit = 0.0
	shake = 0.0
	fall_t = 0.0
	go_jingled = false
	shout_armed = false
	phase = Phase.PLAY
	phase_t = 0.0


# ---------------------------------------------------------------- 音（audio/ の中身は tools/make_audio.py で作り直せる）

const SND_NAMES := ["bgm_title", "bgm_play", "bgm_heaven", "jingle_clear", "jingle_gameover",
		"se_shout", "se_shout_clutch", "se_kick", "se_catch", "se_grab", "se_snap", "se_fall",
		"se_hit_fire", "se_hit_rock", "se_burn", "se_throw", "se_warn", "se_leap", "se_start",
		"se_tick", "se_rank_new", "se_heart", "se_rumble", "se_whiff"]
const SND_LOOP := ["bgm_title", "bgm_play", "bgm_heaven", "se_rumble"]
# 音ごとの音量（dB）。うるさい・小さいと感じたらここをいじる
const SND_VOL := {
	"bgm_title": -8.0, "bgm_play": -10.0, "bgm_heaven": -9.0, "jingle_clear": -5.0, "jingle_gameover": -5.0,
	"se_shout": -2.0, "se_shout_clutch": 0.0, "se_kick": -12.0, "se_catch": -16.0, "se_grab": -13.0,
	"se_snap": -1.0, "se_fall": -7.0, "se_hit_fire": -3.0, "se_hit_rock": -4.0, "se_burn": -8.0,
	"se_throw": -15.0, "se_warn": -16.0, "se_leap": -22.0, "se_start": -5.0, "se_tick": -12.0,
	"se_rank_new": -4.0, "se_heart": -3.0, "se_whiff": -6.0,
}
var snd := {}
const MASTER_DB := -8.0   # 全体の音量（dB）。うるさければ下げる
var bgm_player: AudioStreamPlayer
var rumble_player: AudioStreamPlayer
var se_players: Array = []
var se_next := 0
var bgm_name := ""
var heart_prev := 0.0
var se_log := {}   # 鳴らした回数（検証用）


func _setup_audio() -> void:
	AudioServer.set_bus_volume_db(0, MASTER_DB)
	for n in SND_NAMES:
		var path: String = "res://audio/" + n + ".wav"
		var st = null
		if ResourceLoader.exists(path):
			st = load(path)
		elif FileAccess.file_exists(path):   # エディタで一度も開いていない（未インポート）ときは wav を直接読む
			st = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
		if st == null:
			continue
		if st is AudioStreamWAV and n in SND_LOOP:
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = int(round(st.get_length() * st.mix_rate))
		snd[n] = st
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	rumble_player = AudioStreamPlayer.new()
	add_child(rumble_player)
	if snd.has("se_rumble"):
		rumble_player.stream = snd["se_rumble"]
	for i in range(12):
		var p := AudioStreamPlayer.new()
		add_child(p)
		se_players.append(p)


func _se(n: String, pitch := 1.0, vol := 0.0) -> void:
	if not snd.has(n) or se_players.is_empty():
		return
	se_log[n] = int(se_log.get(n, 0)) + 1
	var p: AudioStreamPlayer = se_players[se_next]
	se_next = (se_next + 1) % se_players.size()
	p.stream = snd[n]
	p.pitch_scale = pitch
	p.volume_db = float(SND_VOL.get(n, 0.0)) + vol
	p.play()


func _bgm(n: String) -> void:
	if bgm_name == n or bgm_player == null:
		return
	bgm_name = n
	bgm_player.stop()
	if snd.has(n):
		bgm_player.stream = snd[n]
		bgm_player.volume_db = float(SND_VOL.get(n, 0.0))
		bgm_player.play()


func _update_audio(delta: float) -> void:
	# 場面ごとの曲
	if phase == Phase.TITLE:
		_bgm("bgm_title")
	elif phase == Phase.PLAY:
		_bgm("bgm_play")
	elif model.state == ThreadModel.State.WON:
		if bgm_name == "jingle_clear" and not bgm_player.playing:
			_bgm("bgm_heaven")   # ファンファーレが終わったら、極楽の曲
	elif not go_jingled and phase_t > GAMEOVER_DELAY:
		go_jingled = true
		_bgm("jingle_gameover")
	# マグマが近いほど地鳴りが大きくなる
	var near := 0.0
	if phase == Phase.PLAY and model.lava_h > 0.0:
		near = clampf(1.0 - (model.height - model.lava_h) / 40.0, 0.0, 1.0)
	if near > 0.01 and rumble_player.stream:
		if not rumble_player.playing:
			rumble_player.play()
		rumble_player.volume_db = lerpf(-30.0, -3.0, near)
	elif rumble_player.playing:
		rumble_player.stop()
	if phase != Phase.PLAY:
		return
	# 九死に一生の圏内: 画面の鼓動に合わせて、心臓の音
	if model.is_clutch() and model.can_shout():
		var hp := fmod(t, 0.8)
		if hp < heart_prev:
			_se("se_heart")
		elif heart_prev < 0.18 and hp >= 0.18:
			_se("se_heart", 1.0, -4.0)
		heart_prev = hp
	else:
		heart_prev = 0.79
	# 鬼が岩を構えたら「！」、投げたら風切り音（画面内のものだけ）
	for rk in model.rocks:
		var ry: float = _sy(rk.h)
		var on := ry > -20.0 and ry < H + 20.0
		if rk.state == 0 and on and not rk.has("_sw"):
			rk["_sw"] = true
			_se("se_warn")
		if rk.state == 1 and not rk.has("_st"):
			rk["_st"] = true
			if on:
				_se("se_throw", randf_range(0.9, 1.1))
	# 罪人が崖から跳んだ
	for j in model.jumpers:
		if not j.has("_sl"):
			j["_sl"] = true
			var jy: float = _sy(j.h0)
			if jy > -20.0 and jy < H + 20.0:
				_se("se_leap", randf_range(0.85, 1.2))


func _result_ready() -> bool:
	# 演出の途中ではリトライさせない（糸切れ: GAME OVER が出るまで / クリア: ランキングが出そろうまで）
	if phase != Phase.RESULT:
		return true
	if model.state == ThreadModel.State.TORN:
		return phase_t > GAMEOVER_DELAY + 0.6
	return phase_t > WIN_READY


# ---------------------------------------------------------------- 調整値の保存

func _load_tuning() -> void:
	if not FileAccess.file_exists(TUNING_PATH):
		return
	var f := FileAccess.open(TUNING_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		for k in data:
			if tuning.has(k):
				tuning[k] = float(data[k])


func _save_tuning() -> void:
	# 標準と同じ値は保存しない（標準を変えたとき、古い値が残らないように）
	var changed := {}
	for k in tuning:
		if not is_equal_approx(tuning[k], ThreadModel.DEFAULTS[k]):
			changed[k] = tuning[k]
	var f := FileAccess.open(TUNING_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(changed, "  "))


# ---------------------------------------------------------------- 入力

func _setup_pad() -> void:
	# PS コントローラー（DualShock 4 / DualSense）。Godot の標準配置: A=×  B=○  X=□  Y=△
	var defs := {
		"pad_up": [[JOY_AXIS_LEFT_Y, -1.0], [JOY_AXIS_TRIGGER_RIGHT, 1.0], JOY_BUTTON_DPAD_UP],
		"pad_left": [[JOY_AXIS_LEFT_X, -1.0], JOY_BUTTON_DPAD_LEFT],
		"pad_right": [[JOY_AXIS_LEFT_X, 1.0], JOY_BUTTON_DPAD_RIGHT],
		"pad_shout": [JOY_BUTTON_A, JOY_BUTTON_B],
	}
	for name in defs:
		if InputMap.has_action(name):
			continue
		InputMap.add_action(name, 0.25)
		for d in defs[name]:
			if d is Array:
				var ev := InputEventJoypadMotion.new()
				ev.axis = d[0]
				ev.axis_value = d[1]
				InputMap.action_add_event(name, ev)
			else:
				var eb := InputEventJoypadButton.new()
				eb.button_index = d
				InputMap.action_add_event(name, eb)


func _pad_to_key(b: int) -> int:
	# コントローラーのボタンを、同じ働きのキーに読み替える
	if panel_open:
		match b:
			JOY_BUTTON_DPAD_UP: return KEY_UP
			JOY_BUTTON_DPAD_DOWN: return KEY_DOWN
			JOY_BUTTON_DPAD_LEFT: return KEY_LEFT
			JOY_BUTTON_DPAD_RIGHT: return KEY_RIGHT
			JOY_BUTTON_X: return KEY_BACKSPACE
			JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START: return KEY_ESCAPE
		return KEY_NONE
	if phase == Phase.TITLE and b == JOY_BUTTON_DPAD_LEFT:
		return KEY_LEFT
	if phase == Phase.TITLE and b == JOY_BUTTON_DPAD_RIGHT:
		return KEY_RIGHT
	if credits_open:
		return KEY_ESCAPE   # クレジットはどのボタンでも閉じる
	match b:
		JOY_BUTTON_START:
			if phase == Phase.TITLE or phase == Phase.RESULT:
				return KEY_SPACE
			return KEY_F1 if DEV_TOOLS else KEY_NONE
		JOY_BUTTON_A:
			if phase == Phase.TITLE or phase == Phase.RESULT:
				return KEY_SPACE
		JOY_BUTTON_Y:
			if phase == Phase.TITLE:
				return KEY_C   # クレジット
			return KEY_R if DEV_TOOLS else KEY_NONE
		JOY_BUTTON_X:
			return KEY_N if DEV_TOOLS else KEY_NONE
	return KEY_NONE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		var pk := _pad_to_key(event.button_index)
		if pk != KEY_NONE:
			var kev := InputEventKey.new()
			kev.keycode = pk
			kev.pressed = true
			_unhandled_input(kev)
		return
	if not (event is InputEventKey and event.pressed):
		return
	var k: int = event.keycode
	if panel_open:
		_panel_key(k)
		return
	if event.echo:
		return
	if credits_open:
		credits_open = false   # どのキーでも閉じる
		return
	if DEV_TOOLS and (k == KEY_F1 or k == KEY_TAB):
		panel_open = true
	elif phase == Phase.TITLE and k == KEY_C:
		credits_open = true
	elif k == KEY_M:   # 音のオン・オフ
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	elif phase == Phase.TITLE and (k == KEY_SPACE or k == KEY_ENTER):
		_se("se_start")
		_restart()
	elif phase == Phase.RESULT and not _result_ready():
		return   # 演出中は R も N もスペースも受け付けない
	elif phase == Phase.RESULT and (k == KEY_SPACE or k == KEY_ENTER):
		course = randi_range(1, 999)   # 毎回ちがう地獄
		_se("se_start")
		_restart()
	elif DEV_TOOLS and k == KEY_R and phase != Phase.TITLE:
		_restart()
	elif DEV_TOOLS and k == KEY_N and phase != Phase.TITLE:
		course = randi_range(1, 999)
		_restart()


func _panel_key(k: int) -> void:
	var keys: Array = ThreadModel.TUNE_ORDER
	var key: String = keys[panel_sel]
	match k:
		KEY_UP, KEY_W:
			panel_sel = (panel_sel - 1 + keys.size()) % keys.size()
		KEY_DOWN, KEY_S:
			panel_sel = (panel_sel + 1) % keys.size()
		KEY_LEFT, KEY_A:
			tuning[key] = maxf(ThreadModel.TUNE_MIN[key], snappedf(tuning[key] - ThreadModel.TUNE_STEP[key], 0.01))
		KEY_RIGHT, KEY_D:
			tuning[key] = snappedf(tuning[key] + ThreadModel.TUNE_STEP[key], 0.01)
		KEY_BACKSPACE:
			tuning[key] = ThreadModel.DEFAULTS[key]
		KEY_0:
			tuning = ThreadModel.DEFAULTS.duplicate()
		KEY_F1, KEY_TAB, KEY_ESCAPE, KEY_ENTER:
			panel_open = false
			_save_tuning()
			if phase != Phase.TITLE:
				_restart()
			else:
				_new_model()


# ---------------------------------------------------------------- 更新

func _process(delta: float) -> void:
	if panel_open:
		queue_redraw()
		return
	_update_audio(delta)
	shout_age += delta
	invert_t = maxf(0.0, invert_t - delta)
	_update_ripple()
	if invert_rect:
		invert_rect.visible = invert_t > 0.0
	# ヒットストップ: 叫んだ瞬間、世界を一瞬止める（揺れだけは続ける）
	if hitstop > 0.0:
		hitstop -= delta
		hitstop_frames += 1
		queue_redraw()
		return
	# 九死に一生のあとは、跳び上がりをゆっくり見せる
	if slowmo > 0.0:
		slowmo -= delta
		delta *= 0.35
	t += delta
	var pt_before := phase_t
	phase_t += delta
	if phase == Phase.RESULT and model.state == ThreadModel.State.WON:
		for i in range(RANKING_SIZE):
			var rt := WIN_ROW_AT + WIN_ROW_STEP * i
			if pt_before < rt and phase_t >= rt:
				if i == new_rank:
					_se("se_rank_new")
				else:
					_se("se_tick", 1.0 + 0.04 * i)
	fx_shout = maxf(0.0, fx_shout - delta)
	stomp_fx = maxf(0.0, stomp_fx - delta)
	fx_hit = maxf(0.0, fx_hit - delta)
	shake = maxf(0.0, shake - delta * 3.0)

	if phase == Phase.PLAY:
		var climb := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_action_pressed("pad_up")
		var shout := Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("pad_shout")
		var swing := 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			swing -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			swing += 1.0
		# 左スティックは倒した分だけ強く揺らす
		swing = clampf(swing + Input.get_action_strength("pad_right") - Input.get_action_strength("pad_left"), -1.0, 1.0)
		# スタート（リトライ）に使ったボタンを押したままだと、すぐ叫んでしまう。一度離すまで叫びは受け付けない
		var held := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("pad_shout") or Input.is_key_pressed(KEY_ENTER)
		if not shout_armed:
			if held:
				shout = false
			else:
				shout_armed = true
		if autopilot:
			climb = bot_climb
			shout = bot_shout
			swing = bot_swing
			bot_shout = false
		early_t = maxf(0.0, early_t - delta)
		if shout and model.state == ThreadModel.State.CLIMBING and not model.can_shout() and early_t <= 0.0:
			early_t = 0.6
			ring_nope = NOPE_TIME   # 踏み台がいない: 下を蹴っても空振り。ゲージが震える
			_se("se_whiff")   # 足は空を切るだけ
		var shouts_before := model.shouts
		var hits_before := model.hits
		var rocks_before := model.rock_hits
		var crushed_before := model.ghosts_crushed
		var burned_before := model.ghosts_burned
		var caught_before := model.caught
		var ghosts_before := int(model.ghosts)
		var x_before := model.x
		var h_before := model.height
		model.step(delta, climb, shout, swing)
		if model.shouts > shouts_before:
			_on_shout(ghosts_before, x_before)
		if prev_state == ThreadModel.State.AIR and model.state == ThreadModel.State.CLIMBING:
			# 上の糸をつかんだ瞬間の火花
			_burst(Vector2(_sx(model.x), _player_sy() - 15.0), 14, [C_YELLOW, C_WHITE], 60.0, 1.0, 0.4, 0.0)
			_se("se_grab")
		if model.hits > hits_before:
			_burst(Vector2(_sx(model.x), _player_sy()), 30, [C_ORANGE, C_YELLOW, C_RED], 110.0, 2.0, 0.6, 60.0)
			fx_hit = 0.5
			shake = 0.9
			_se("se_hit_fire")
		if model.rock_hits > rocks_before:
			_se("se_hit_rock")
			_burst(Vector2(_sx(model.x), _player_sy() - 10.0), 22, [C_ROCK, C_ROCK_L, C_ROCK_D], 120.0, 2.0, 0.8, 300.0)
			_burst(Vector2(_sx(model.x), _player_sy() - 10.0), 12, [Color(C_GREY, 0.6)], 40.0, 3.0, 0.7, -20.0)
			fx_hit = 0.5
			shake = 0.9
		if model.caught > caught_before:
			_burst(Vector2(_sx(model.x), _player_sy() + 40.0), 14, [Color(C_GREY, 0.7), Color(C_CLIFF_L, 0.8)], 50.0, 2.0, 0.5, 40.0)
			shake = maxf(shake, 0.4)
			_se("se_catch", randf_range(0.92, 1.08))
		if model.ghosts_crushed > crushed_before:
			var n := model.ghosts_crushed - crushed_before
			_se("se_hit_rock", 1.3, -6.0)
			_drop_ghosts(n, model.height - 3.0, model.x)
		if model.ghosts_burned > burned_before:   # 業火に焼かれた罪人
			_burst(Vector2(_sx(model.x), _sy(model.lava_h) + LAVA_OFF), 18, [C_YELLOW, C_ORANGE, C_RED], 70.0, 2.0, 0.6, -60.0)
			_se("se_burn")
		prev_state = model.state
		if model.state == ThreadModel.State.WON or model.state == ThreadModel.State.TORN:
			new_rank = -1
			if model.state == ThreadModel.State.WON:
				_add_ranking(model.elapsed)
				new_record = best_time[difficulty] <= 0.0 or model.elapsed < best_time[difficulty]
				if new_record:
					best_time[difficulty] = model.elapsed
				best[difficulty] = int(ThreadModel.GOAL)
				_save_records()
				_bgm("jingle_clear")
			if model.state == ThreadModel.State.TORN:
				new_record = int(model.height) > best[difficulty]
				if new_record:
					best[difficulty] = int(model.height)
					_save_records()
				# 糸が切れる: 手元で「ブチッ」と火花、一瞬止まって、カメラはそのまま。カンダタたちが落ちていく
				_burst(Vector2(_sx(model.x), _player_sy() - 15.0), 26, [C_WHITE, C_YELLOW, C_SILK], 120.0, 2.0, 0.5, 80.0)
				shake = 1.0
				hitstop = 0.14
				hitstop_frames = 0
				shout_age = 99.0
				torn_x = model.x
				_bgm("")   # 曲が止まって、ブチッ → ひゅーっと落ちる
				_se("se_snap")
				_se("se_fall")
				if model.death == "lava":
					_se("se_burn", 0.8, 4.0)
				falling_thread.append([h_before, model.x, 0.0])
				_drop_ghosts(int(model.ghosts), model.height, model.x, false, true)
			phase = Phase.RESULT
			phase_t = 0.0

	if phase == Phase.RESULT and model.state == ThreadModel.State.TORN:
		fall_t += delta

	# カメラ: 跳んでいる間は着地点へ先回りして、上の景色を先に見せる
	var cam_target: float = model.air_to if model.state == ThreadModel.State.AIR else model.height
	if shout_hold > 0.0:   # 叫んだ直後は、カメラをその場に少し留めて、叫びと衝撃波を見せる
		shout_hold -= delta
		cam_target = model.air_from
	cam_h = lerpf(cam_h, cam_target, minf(1.0, delta * (9.0 if model.state == ThreadModel.State.AIR else 6.0)))
	# カンダタが画面の外へ出ないように
	cam_h = clampf(cam_h, model.height - (PLAYER_SY - 30.0) / PPM, model.height + (H - 40.0 - PLAYER_SY) / PPM)
	_update_particles(delta)
	ring_nope = maxf(0.0, ring_nope - delta)
	# 登りモーション: 実際に登った距離で手足を動かす（止まれば止まる）
	var dh := model.height - anim_h
	anim_h = model.height
	if model.state == ThreadModel.State.CLIMBING and dh > 0.0 and dh < 2.0:
		climb_phase += dh * 0.4
		climb_moving = 0.15
	else:
		climb_moving = maxf(0.0, climb_moving - delta)
	if phase == Phase.PLAY and model.height - model.lava_h < 15.0:
		shake = maxf(shake, 0.12)   # マグマが足元に迫ると地鳴り
	if phase == Phase.PLAY:
		_update_tips(delta)

	for f in falling_ghosts:
		if f.size() > 4 and f[4] > 0.0:   # 踏み台の連鎖: 上から順に光ってから弾かれる
			f[4] -= delta
			if f[4] <= 0.0:
				_burst(f[0], 8, [C_WHITE, C_YELLOW], 90.0, 2.0, 0.3, 0.0)
				_se("se_kick", 1.0 + 0.12 * float(f[3]))   # 連鎖するほど音が上がる
				shake = maxf(shake, 0.35)
			continue
		f[1].y += (230.0 if phase == Phase.RESULT and model.state == ThreadModel.State.TORN else 550.0) * delta   # 糸切れ時はゆっくり見せる
		f[0] += f[1] * delta
		f[2] += delta * 6.0
	falling_ghosts = falling_ghosts.filter(func(f): return f[0].y < H + 40.0)
	for th in falling_thread:
		th[2] += delta
	falling_thread = falling_thread.filter(func(th): return th[2] < 2.0)
	for p in popups:
		p[3] += delta
	popups = popups.filter(func(p): return p[3] < 1.2)
	queue_redraw()


func _load_ranking() -> void:
	if not FileAccess.file_exists(RANKING_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(RANKING_PATH))
	if typeof(data) != TYPE_ARRAY:
		return
	for k in range(mini(data.size(), 3)):
		if typeof(data[k]) == TYPE_ARRAY:
			var lst: Array = []
			for e in data[k]:
				if typeof(e) == TYPE_DICTIONARY and e.has("t"):
					var yr: int = int(e.get("y", Time.get_date_dict_from_system().year))   # 年がない古い記録は今年とみなす
					lst.append({"t": float(e["t"]), "d": str(e.get("d", "")), "y": yr})
			ranking[k] = lst


func _add_ranking(sec: float) -> void:
	# クリアタイムを上位10件に入れる。速い順。同タイムは先に出した方が上
	var dd := Time.get_date_dict_from_system()
	var entry := {"t": snappedf(sec, 0.01), "d": "%02d/%02d" % [dd.month, dd.day], "y": dd.year}
	var lst: Array = ranking[difficulty]
	var pos := lst.size()
	for i in range(lst.size()):
		if sec < float(lst[i]["t"]):
			pos = i
			break
	if pos >= RANKING_SIZE:
		return
	lst.insert(pos, entry)
	while lst.size() > RANKING_SIZE:
		lst.pop_back()
	ranking[difficulty] = lst
	new_rank = pos
	var f := FileAccess.open(RANKING_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(ranking))


func _save_records() -> void:
	var bf := FileAccess.open(BEST_PATH, FileAccess.WRITE)
	if bf:
		bf.store_string("%d,%d,%d,%.2f,%.2f,%.2f" % [best[0], best[1], best[2], best_time[0], best_time[1], best_time[2]])


func _on_shout(n_ghosts: int, from_x: float) -> void:
	var sp := Vector2(_sx(from_x), _sy(model.air_from))
	var big := clampi(model.last_stones, 1, 6)
	_se("se_shout_clutch" if model.last_clutch else "se_shout", 1.0 - 0.03 * big)
	_burst(sp, 20 + big * 10, [C_YELLOW, C_WHITE, C_ORANGE], 90.0 + big * 20.0, 2.0, 0.7, 0.0)   # 叫びの火花
	# 衝撃波で消し飛んだ岩と鬼火
	for b in model.last_blast:
		var bp := Vector2(_sx(b.x), _sy(b.h))
		if b.type == "fire":
			_burst(bp, 24, [C_YELLOW, C_ORANGE, C_WHITE], 120.0, 2.0, 0.6, -30.0)
		else:
			_burst(bp, 20, [C_ROCK, C_ROCK_L, C_ROCK_D], 150.0, 3.0, 0.7, 250.0)
	fx_shout = 1.1
	shout_text = SHOUT_LINES[randi() % SHOUT_LINES.size()]
	shake = minf(1.8, 0.8 + 0.14 * model.last_stones)   # 大勢を踏み台にするほど揺れる
	shout_age = 0.0
	shout_clutch = model.last_clutch
	# 糸が切れる瞬間: 足もとの切り口に火花
	_burst(sp + Vector2(0, 18), 18, [C_WHITE, C_YELLOW, C_ORANGE], 110.0, 2.0, 0.45, 120.0)
	if model.last_stones >= 5:
		_burst(sp, 40, [C_WHITE, C_CYAN], 220.0, 3.0, 0.9, 0.0)   # 大跳躍の衝撃波
	if model.last_clutch:
		shake = 1.5
		_burst(sp, 60, [C_GOLD, C_YELLOW, C_WHITE], 200.0, 3.0, 1.1, -20.0)
		shake = 2.0
		invert_t = 0.07      # 一瞬だけ白黒反転
		slowmo = 0.4         # 跳び上がりをスローで
	falling_thread.append([model.air_from, from_x, 0.0])
	_drop_ghosts(n_ghosts, model.air_from, from_x, true)
	stomp_fx = BLAST_TIME
	# ヒットストップ: 踏み台が多いほど長く止まる。九死に一生はさらに長く
	hitstop = minf(0.06 + 0.02 * model.last_stones, 0.16)
	if model.last_clutch:
		hitstop = 0.26
	hitstop_frames = 0
	hitstop_total = hitstop
	shout_hold = 0.3
	blast_at = Vector2(from_x, model.air_from)
	blast_px = model.blast_r


func _draw_blast() -> void:
	var bc := Vector2(_sx(blast_at.x), _sy(blast_at.y))
	var bk := 1.0 - stomp_fx / BLAST_TIME              # 0→1
	# 漫画のギザギザ吹き出し（大きさ＝範囲）。ポンと出て、すっと縮んで消える。まわりの空間のゆがみはシェーダー
	var pop := clampf(bk / 0.12, 0.0, 1.0)
	var shrink := clampf((bk - 0.55) / 0.45, 0.0, 1.0)
	var rad := blast_px * 0.62 * (0.6 + 0.4 * (1.0 - pow(1.0 - pop, 3.0))) * (1.0 - 0.5 * shrink)
	if rad > 4.0:
		var n := 10
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + int(blast_at.y)
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in range(n * 2):
			var ang := TAU * i / (n * 2) + 0.1
			var r := rad * (1.0 if i % 2 == 0 else 0.62) * (0.85 + rng.randf() * 0.3)
			outer.append(bc + Vector2(cos(ang), sin(ang)) * (r + 4.0))
			inner.append(bc + Vector2(cos(ang), sin(ang)) * r)
		var a := 1.0 - shrink
		var glow := PackedVector2Array()
		for v in outer:
			glow.append(bc + (v - bc) * 1.12)
		draw_colored_polygon(glow, Color(C_ORANGE, a * 0.35))      # 外側のぼんやりした光
		draw_colored_polygon(outer, Color(C_GOLD if shout_clutch else C_ORANGE, a * 0.9))   # 縁は黒でなく橙
		draw_colored_polygon(inner, Color(C_GOLD if shout_clutch else Color8(255, 246, 220), a))
		var inner2 := PackedVector2Array()
		for v in inner:
			inner2.append(bc + (v - bc) * 0.72)
		draw_colored_polygon(inner2, Color(C_ORANGE if shout_clutch else C_RED, a * 0.9))


func _draw_speed_lines(c: Vector2) -> void:
	# 集中線: カンダタに向かって、画面の外から細い三角の線が刺さる。止まっている間は濃く、そのあと消える
	var fade := 1.0 if shout_age < hitstop_total else maxf(0.0, 1.0 - (shout_age - hitstop_total) / 0.25)
	var col: Color = C_GOLD if shout_clutch else C_WHITE
	var n := 56 if shout_clutch else 44
	var rng := RandomNumberGenerator.new()
	rng.seed = int(shout_age * 30.0)   # 数フレームごとに線が入れ替わってチラつく
	for i in range(n):
		var a := TAU * (i + rng.randf() * 0.6) / n
		var dir := Vector2(cos(a), sin(a))
		var r_in := 46.0 + rng.randf() * 60.0
		var r_out := 520.0
		var wdt := 1.0 + rng.randf() * 3.0
		var side := Vector2(-dir.y, dir.x) * wdt
		draw_colored_polygon(PackedVector2Array([c + dir * r_out + side, c + dir * r_out - side, c + dir * r_in]),
				Color(col, (0.55 + rng.randf() * 0.35) * fade))


func _draw_shout_text(px: float, py: float) -> void:
	# 叫びの文字を一文字ずつ叩きつける: 大きく出て、ぐっと縮んで止まる。黒いふちと赤い影
	var sc_final := 2.0
	var full_w := font.get_string_size(shout_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * sc_final
	var sx := minf(px + 24.0, FIELD_W - full_w - 6.0)
	if sx < px + 24.0 and px - 24.0 - full_w > 6.0:
		sx = px - 24.0 - full_w
	var sy := clampf(py - 10.0, 40.0, H - 40.0)
	var alpha := minf(1.0, fx_shout * 2.5)
	var body: Color = C_GOLD if shout_clutch else C_YELLOW
	var x := sx
	for i in range(shout_text.length()):
		var ch := shout_text.substr(i, 1)
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var k := clampf((shout_age - i * 0.045) / 0.09, 0.0, 1.0)
		if k > 0.0:
			var sc := lerpf(4.0, sc_final, 1.0 - pow(1.0 - k, 3.0))   # 大きく出て縮む
			var center := Vector2(x + cw * sc_final * 0.5, sy - 8.0 * sc_final * 0.5)
			var p := (center / sc - Vector2(cw * 0.5, -6.0)).round()
			draw_set_transform_matrix(base_xf * Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO))
			draw_string(font, p + Vector2(1, 1), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(C_BLOOD, alpha))
			for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_string(font, p + o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(C_BLACK, alpha))
			draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(body if k >= 1.0 else C_WHITE, alpha))
			draw_set_transform_matrix(base_xf)
		x += cw * sc_final


func _drop_ghosts(n_ghosts: int, from_h: float, from_x: float, kicked := false, together := false) -> void:
	# kicked: 踏み台にされて真下へ蹴り落とされる（叫んだとき）
	var py := _sy(from_h)
	for i in range(n_ghosts):
		var gy := py + 46.0 + i * GHOST_GAP
		if gy > H + 20.0:
			break
		var v := Vector2(randf_range(-110, 110), randf_range(-130, -30))
		if kicked:
			v = Vector2(randf_range(-40, 40), randf_range(160, 260))
		elif together:   # 糸が切れて、カンダタと一緒にそのまま落ちる
			v = Vector2(randf_range(-25, 25), randf_range(-20, 10))
		falling_ghosts.append([Vector2(_gx(from_x, i) + (8.0 if i % 2 == 0 else -8.0), gy), v, 0.0, i, (0.05 + i * 0.05) if kicked else 0.0])


# ---------------------------------------------------------------- パーティクル

func _part(pos: Vector2, vel: Vector2, life: float, col: Color, size := 1.0, grav := 0.0, drag := 0.0) -> void:
	if parts.size() < 700:
		parts.append([pos, vel, life, life, col, size, grav, drag])


func _burst(pos: Vector2, n: int, cols: Array, speed: float, size: float, life: float, grav: float) -> void:
	for i in range(n):
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.3, 1.0)
		_part(pos, v, life * randf_range(0.6, 1.2), cols[i % cols.size()], roundf(randf_range(1.0, size)), grav, 2.0)


func _update_particles(delta: float) -> void:
	# カメラが上がった分だけ下へずらす（世界に貼りついて見えるように）
	var dy := (cam_h - prev_cam) * PPM
	prev_cam = cam_h
	for f in falling_ghosts:   # 落ちていく罪人も、カメラに合わせて流す
		f[0].y += dy
	for p in parts:
		p[0].y += dy
		p[1].y += p[6] * delta
		p[1] *= exp(-p[7] * delta)
		p[0] += p[1] * delta
		p[2] -= delta
	parts = parts.filter(func(p): return p[2] > 0.0)
	if panel_open:
		return
	var won := phase == Phase.RESULT and model.state == ThreadModel.State.WON and phase_t > 0.35
	if won:
		# 極楽: 後光から舞う金の粒、池のきらめき
		if randf() < 0.5:
			_part(Vector2(552 + randf_range(-40, 40), 214 + randf_range(-30, 30)), Vector2(randf_range(-5, 5), -12), 1.6, C_YELLOW, 1.0, -2.0)
		if randf() < 0.4:
			_part(Vector2(300 + randf_range(-140, 140), 298 + randf_range(-30, 30)), Vector2.ZERO, 0.4, C_CLOUD, 1.0)
		return
	if phase == Phase.TITLE:
		return
	# 鬼火の火の粉
	for o in model.obstacles:
		var fp: Vector2 = model.fire_pos(o)
		var sp := Vector2(_sx(fp.x), _sy(fp.y))
		if sp.y > -10 and sp.y < H + 10 and randf() < 0.5:
			_part(sp + Vector2(randf_range(-4, 4), randf_range(-4, 4)), Vector2(randf_range(-10, 10), randf_range(-40, -15)),
					randf_range(0.3, 0.7), [C_ORANGE, C_YELLOW, C_RED][randi() % 3], 1.0, -10.0)
	# 飛ぶ岩の砂ぼこり
	for rk in model.rocks:
		var ry: float = _sy(rk.h)
		if rk.state == 1 and ry > -10 and ry < H and randf() < 0.5:
			_part(Vector2(_sx(rk.x) + randf_range(-8, 8), ry - 10.0), Vector2(randf_range(-6, 6), -8), 0.5, Color(C_ROCK_L, 0.5), 1.0)
	if model.state == ThreadModel.State.CLIMBING:
		var py := _player_sy()
		var px := _sx(model.x)
		# 九死に一生の圏内: カンダタのまわりに金の火花
		if model.is_clutch() and model.can_shout() and randf() < 0.9:
			var ca := randf() * TAU
			_part(Vector2(px, py) + Vector2(cos(ca), sin(ca)) * 18.0, Vector2(cos(ca), sin(ca)) * 30.0, 0.35, C_GOLD, 2.0)
		# 糸がほつれる: 切れそうになると、頭上の糸から繊維が飛ぶ
		var snap := model.time_to_snap(true)
		if snap < 2.5 and randf() < (0.9 if snap < 1.2 else 0.4):
			_part(Vector2(px + randf_range(-2, 2), py - 20.0 - randf() * 20.0), Vector2(randf_range(-40, 40), randf_range(-20, 20)),
					0.6, Color(C_WHITE, 0.8), 1.0, 40.0, 1.0)
	# 蹴落とされた罪人の赤い尾
	# 業火の火の粉
	var lt := _sy(model.lava_h) + LAVA_OFF
	if lt < H + 4.0 and model.lava_h >= -1.0:
		if randf() < 0.12:   # 跳ねるしぶき
			var sx3 := randf() * FIELD_W
			for k in range(6):
				_part(Vector2(sx3, lt), Vector2(randf_range(-30, 30), randf_range(-110, -50)), randf_range(0.5, 0.8),
						[C_YELLOW, C_ORANGE][k % 2], 2.0, 260.0)
		for k in range(3):
			_part(Vector2(randf() * FIELD_W, lt), Vector2(randf_range(-8, 8), randf_range(-60, -25)), randf_range(0.5, 1.1),
					[C_ORANGE, C_YELLOW, C_RED][randi() % 3], 1.0, 10.0)
	# 極楽の穴から降る光の粒
	var goal_y := _sy(ThreadModel.GOAL)
	if goal_y > -60 and goal_y < H and randf() < 0.6:
		_part(Vector2(THREAD_X + randf_range(-50, 50), goal_y - 6.0), Vector2(randf_range(-4, 4), randf_range(10, 25)), 2.0, Color(C_CLOUD, 0.7), 1.0)


func _draw_particles() -> void:
	for p in parts:
		var a: float = clampf(p[2] / p[3], 0.0, 1.0)
		var c: Color = p[4]
		var sz: float = p[5]
		draw_rect(Rect2(roundf(p[0].x), roundf(p[0].y), sz, sz), Color(c, c.a * a))


# ---------------------------------------------------------------- 座標

func _sy(world_h: float) -> float:
	return roundf(PLAYER_SY - (world_h - cam_h) * PPM)


func _sx(x: float) -> float:
	return roundf(THREAD_X + x * XS)


func _gx(hand_x: float, i: float) -> float:
	# カンダタより下の糸は、手元の位置から少し遅れてぶら下がる
	var k := clampf(i / 14.0, 0.0, 1.0)
	return roundf(THREAD_X + (hand_x * (1.0 - 0.35 * k) + sin(t * 2.4 + i * 0.5) * model.ghosts * 1.6 * k) * XS)


func _player_sy() -> float:
	var y := _sy(model.height)
	if model.state == ThreadModel.State.TORN:
		y += roundf(fall_t * fall_t * 170.0)   # ゆっくり落ちていくのを見せる
	return y


func _h_to_map(h: float) -> float:
	return roundf(MAP_BOT - (MAP_BOT - MAP_TOP) * clampf(h / ThreadModel.GOAL, 0.0, 1.0))


# ---------------------------------------------------------------- ヒント（短め）

func _tip(key: String, kb: String, pad_txt := "") -> void:
	if tips_seen.has(key):
		return
	tips_seen[key] = true
	var use_pad := not Input.get_connected_joypads().is_empty() and pad_txt != ""
	tip_queue.append(pad_txt if use_pad else kb)


func _update_tips(delta: float) -> void:
	# 場面ごとの案内。一度出たら、そのセッションでは出さない
	# 案内は3つだけ: 登る・揺らしてよける / 罪人が踏み台になる / 叫んで跳ぶ（あとは遊べばわかる）
	if model.elapsed < 4.0 and model.height < 3.0:
		_tip("climb", "W / ↑ で登る　A / D で糸を揺らしてよけろ", "左スティックで登る・揺らしてよけろ")
	if not model.incoming_sinners().is_empty():
		_tip("sinner", "罪人が飛びつく。つかまらせれば踏み台になる")
	if model.can_shout():
		_tip("shout", "SPACEで叫べ！ 踏み台を蹴って跳ぶ", "×で叫べ！ 踏み台を蹴って跳ぶ")
	if model.is_clutch() and model.can_shout():
		pass   # 九死に一生は文字では案内しない（演出で見せる）
	if tip_text != "":
		tip_t += delta
		if tip_t >= TIP_TIME:
			tip_text = ""
	if tip_text == "" and not tip_queue.is_empty():
		tip_text = tip_queue.pop_front()
		tip_t = 0.0


func _hint() -> Array:
	if model.state == ThreadModel.State.AIR:
		return ["ちぎれた！ 上の糸をつかめ！", C_YELLOW]
	if model.stun_left > 0.0:
		return ["よろけて登れない…", C_ORANGE]
	var snap := model.time_to_snap(true)
	if model.is_clutch() and model.can_shout():
		return ["", C_GOLD]
	if snap < 1.5:
		if model.can_shout():
			return ["糸が切れる！ SPACEで叫べ！", C_RED]
		return ["踏み台がいない！ 罪人を捕まえろ！", C_RED]
	for rk0 in model.rocks:
		if rk0.state == 0 and _sy(rk0.h) > 0.0:
			return ["鬼が岩を投げる！ 赤い点線の通り道をよけろ", C_ORANGE]
	if not model.incoming_sinners().is_empty():
		return ["罪人が飛びかかる！ 踏み台にするか、A/Dでかわすか", C_PURPLE]
	for rk in model.rocks:
		if rk.state == 0 and not rk.hit_player:
			return ["鬼が岩を投げる！ 赤い点線の通り道をよけろ", C_ORANGE]
	for o in model.obstacles:
		var fh: float = model.fire_pos(o).y
		if fh > model.height and fh - model.height < 10.0:
			return ["鬼火が来る… A/Dでかわせ", C_ORANGE]
	if not model.can_shout():
		return ["罪人を踏み台に集めろ！ 1人ごとに高く跳べる", C_CYAN]
	return ["SPACEで跳べる。もう1人待つか、今跳ぶか", C_GOLD]


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	draw_off = Vector2.ZERO
	if shake > 0.0:
		draw_off = Vector2(roundf(randf_range(-1, 1) * shake * 4.0), roundf(randf_range(-1, 1) * shake * 4.0))
	var won := phase == Phase.RESULT and model.state == ThreadModel.State.WON
	if won and phase_t > 0.35:
		_draw_meadow()   # 極楽に着いたら、景色ごと切り替える
		if phase_t > WIN_RANK_AT:
			_draw_result()
	else:
		# 叫んだ瞬間、カメラがぐっと寄ってから戻る（止まっている間は寄ったまま）
		var z := 1.0
		if shout_age < hitstop_total + 0.35 and phase == Phase.PLAY:
			var f := 1.0 if shout_age < hitstop_total else 1.0 - smoothstep(0.0, 1.0, (shout_age - hitstop_total) / 0.35)
			z = 1.0 + (0.14 if shout_clutch else 0.08) * f
		var pivot := Vector2(_sx(blast_at.x), _sy(blast_at.y))
		base_xf = Transform2D(0.0, Vector2(z, z), 0.0, draw_off + pivot * (1.0 - z))
		draw_set_transform_matrix(base_xf)
		_draw_world()
		draw_off = Vector2.ZERO
		base_xf = Transform2D.IDENTITY
		draw_set_transform(Vector2.ZERO)
		if fx_hit > 0.0 and fmod(t, 0.1) < 0.05:
			draw_rect(Rect2(0, 0, FIELD_W, H), Color(C_RED, 0.25))
		if phase != Phase.TITLE:
			_draw_map()
			_draw_hud()
		if phase == Phase.TITLE:
			_draw_title()
		elif phase == Phase.RESULT and phase_t > (GAMEOVER_DELAY if model.state == ThreadModel.State.TORN else 0.9):
			_draw_result()
	if hitstop > 0.0 and hitstop_frames < 3:   # 止まった瞬間だけ画面を白く光らせる
		draw_rect(Rect2(0, 0, FIELD_W, H), Color(1, 1, 1, 0.35 if hitstop_frames < 2 else 0.15))
	if won and phase_t < 0.9:   # 到達の瞬間の白い光
		var fa := 1.0 - absf(phase_t - 0.35) / 0.55
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.95, clampf(fa, 0.0, 1.0)))
	if panel_open:
		_draw_panel()


func _spr(rows: Array, pos: Vector2, pal: Dictionary, flip := false, sc := 2) -> void:
	# ドット絵を描く。pos はスプライトの中心、sc は 1 文字あたりのドット数
	var h := rows.size()
	var w: int = rows[0].length()
	var ox := roundf(pos.x - w * sc * 0.5)
	var oy := roundf(pos.y - h * sc * 0.5)
	for yy in range(h):
		var row: String = rows[yy]
		for xx in range(w):
			var ch := row[w - 1 - xx] if flip else row[xx]
			if ch != "." and pal.has(ch):
				draw_rect(Rect2(ox + xx * sc, oy + yy * sc, sc, sc), pal[ch])


func _draw_world() -> void:
	# 背景: 高いほど地獄の赤 → 闇 → 極楽の金（帯で段階的に）
	var r := clampf(cam_h / ThreadModel.GOAL, 0.0, 1.0)
	var top := C_DARK.lerp(Color8(96, 76, 40), r)
	var bot := C_BLOOD.lerp(C_DARK, r)
	for i in range(9):
		draw_rect(Rect2(0, i * 40, FIELD_W, 40), top.lerp(bot, i / 8.0))
	# 舞い上がる火の粉
	for i in range(18):
		var ex := fmod(i * 53.0 + sin(t + i) * 6.0, FIELD_W)
		var ey := fmod(i * 71.0 - t * (12.0 + i % 5 * 4.0) + cam_h * PPM * 0.3, H)
		if ey < 0:
			ey += H
		draw_rect(Rect2(roundf(ex), roundf(ey), 1, 1), Color(C_ORANGE, 0.5))
	# 遠景の針山（手前よりゆっくり流れる）
	_draw_needle_mountains()
	# 左右の崖（揺れられる範囲の外）
	_draw_cliffs()

	# 高さの目盛り（左の暗がり）
	var m := floori((cam_h - 70.0) / 25.0) * 25
	while m < cam_h + 70.0:
		var y := _sy(m)
		if m >= 0 and m <= ThreadModel.GOAL and y > -10 and y < H + 10:
			draw_rect(Rect2(4, y, 10, 1), Color(C_WHITE, 0.3))
			_label(Vector2(16, y + 6), "%dm" % m, 16, Color(C_WHITE, 0.35))
		m += 25

	# 地獄の地面（0m）。カンダタはここから登り始める
	var ground_y := _sy(0.0) + 16.0
	if ground_y < H:
		draw_rect(Rect2(0, ground_y, FIELD_W, H - ground_y), Color8(46, 26, 28))
		draw_rect(Rect2(0, ground_y, FIELD_W, 2), Color8(96, 60, 52))
		for i in range(0, int(FIELD_W), 6):   # でこぼこの地表
			var bump := float((i * 13) % 4)
			draw_rect(Rect2(i, ground_y - bump, 6, bump), Color8(70, 42, 40))
		for i in range(9):   # ひび割れと、そこから漏れる赤い光
			var cx2 := float((i * 53 + 17) % int(FIELD_W))
			var cy2 := ground_y + 8.0 + float((i * 29) % 30)
			draw_rect(Rect2(cx2, cy2, 10, 1), Color(C_RED, 0.6 + 0.3 * sin(t * 2.0 + i)))
			draw_rect(Rect2(cx2 + 8, cy2 + 1, 6, 1), Color(C_RED, 0.5))
		for i in range(5):   # 小さな炎
			var fx2 := float((i * 97 + 40) % int(FIELD_W))
			_spr(SPR_FIRE[int(t * 8.0 + i) % 2], Vector2(fx2, ground_y - 4.0), {"y": C_YELLOW, "o": C_ORANGE, "w": C_RED}, i % 2 == 0, 1)

	# 極楽（ゴール）
	var goal_y := _sy(ThreadModel.GOAL)
	if goal_y > -120:
		_draw_goal(goal_y)

	# 鬼火
	for o in model.obstacles:
		var fp: Vector2 = model.fire_pos(o)
		var oy := _sy(fp.y)
		if oy < -20 or oy > H + 20:
			continue
		var cy0 := _sy(o.h)
		if int(model.cfg.fire_mode) % 2 == 0:   # 円の軌道をうっすら
			draw_arc(Vector2(_sx(o.cx), cy0), o.r * XS, 0, TAU, 24, Color(C_ORANGE, 0.15), 1.0)
		else:   # 上下の軌道をうっすら
			draw_rect(Rect2(_sx(o.cx), cy0 - 7.0 * PPM, 1, 14.0 * PPM), Color(C_ORANGE, 0.15))
		var frame := int(t * 8.0 + o.phase) % 2
		_spr(SPR_FIRE[frame], Vector2(_sx(fp.x), oy), {"y": C_YELLOW, "o": C_ORANGE, "w": C_WHITE}, o.w < 0.0)

	# 崖の岩棚と、画面の端から走ってくる罪人
	var cliff_l := _sx(-ThreadModel.X_LIMIT - ThreadModel.BODY_W)
	var cliff_r := _sx(ThreadModel.X_LIMIT + ThreadModel.BODY_W)
	for i in range(model.perches.size()):
		var pc: Dictionary = model.perches[i]
		var py0 := _sy(pc.h)
		if py0 < -30 or py0 > H + 30:
			continue
		var left: bool = pc.side < 0.0
		var lip: float = cliff_l if left else cliff_r
		# 岩棚: 画面の端から崖の縁まで続く道
		var sx_a: float = 0.0 if left else lip - 6.0
		var sw: float = lip + 6.0 if left else FIELD_W - lip + 6.0
		draw_rect(Rect2(sx_a, py0, sw, 5), C_CLIFF_D)
		draw_rect(Rect2(sx_a, py0, sw, 1), C_CLIFF_L)
		draw_rect(Rect2(lip - 2.0 if left else lip - 6.0, py0 + 5, 8, 2), C_CLIFF_D)
		# 近づくと、端から縁へ走ってくる（飛びかかる位置まで）
		var run_k := clampf((model.height - (pc.h - ThreadModel.SINNER_TRIGGER - 10.0)) / 10.0, 0.0, 1.0)
		if run_k <= 0.0:
			continue
		for k in range(pc.n - pc.fired):
			var start_x: float = -12.0 - k * 14.0 if left else FIELD_W + 12.0 + k * 14.0
			var end_x: float = lip - 6.0 - k * 12.0 if left else lip + 6.0 + k * 12.0
			var sx0 := lerpf(start_x, end_x, run_k)
			var running := run_k < 1.0
			var frame: int = int(t * 10.0 + k) % 2 if running else 0
			var spr: Array = SPR_GHOST_RUN if frame == 1 else SPR_GHOST
			var bob: float = 0.0 if running else roundf(absf(sin(t * 6.0 + i + k)) * 2.0)
			_spr(spr, Vector2(roundf(sx0), py0 - 13.0 - bob), _ghost_pal(i * 3 + k), left)

	# 飛びかかる罪人（外れたらそのまま落ちる）
	for j in model.jumpers:
		if j.state == 1:
			continue
		var left2: bool = j.side < 0.0
		var p0 := Vector2(cliff_l if left2 else cliff_r, _sy(j.h0) - 13.0)
		var p1 := Vector2(_sx(j.aim_x) + (8.0 if left2 else -8.0), _sy(j.target_h))
		var pos: Vector2
		var spr3: Array = SPR_GHOST
		if j.state == 0:
			var k2: float = j.t / ThreadModel.SINNER_FLIGHT
			pos = p0.lerp(p1, k2) + Vector2(0, -sin(k2 * PI) * 26.0)
		else:   # 糸をつかめなかった: 勢いのまま少し流れて、まっすぐ奈落へ落ちる
			var a2: float = j.age - ThreadModel.SINNER_FLIGHT
			pos = p1 + Vector2((40.0 if left2 else -40.0) * a2, a2 * a2 * 500.0)
			if int(a2 * 9.0) % 2 == 1:
				spr3 = SPR_GHOST_RUN
		_spr(spr3, pos.round(), _ghost_pal(int(j.h0)), not left2)

	# 崖の鬼と、投げられた岩
	var rr := ThreadModel.ROCK_R * XS
	for rk in model.rocks:
		var left3: bool = rk.side < 0.0
		var tau: float = model.rock_tau(rk)
		var hand0: Vector2 = model.rock_pos(rk, -1.0)
		var hx := _sx(hand0.x)
		var hy := _sy(hand0.y)
		var oni_c := Vector2(hx - rk.side * 4.0, hy + rr + 19.0)
		var feet := oni_c.y + 15.0
		var lip3: float = cliff_l if left3 else cliff_r
		# 鬼は振りかぶってから投げ、少しして岩棚の奥へ引っこむ
		var show_oni: bool = tau < 0.9
		if show_oni and feet > -20.0 and oni_c.y - 40.0 < H:
			var sx_b: float = 0.0 if left3 else lip3 - 10.0
			var sw2: float = lip3 + 10.0 if left3 else FIELD_W - lip3 + 10.0
			draw_rect(Rect2(sx_b, feet, sw2, 5), C_CLIFF_D)
			draw_rect(Rect2(sx_b, feet, sw2, 1), C_CLIFF_L)
			var rise := clampf(rk.t / 0.15, 0.0, 1.0)            # 岩棚の下から現れる
			var sink := clampf((tau - 0.6) / 0.3, 0.0, 1.0)      # 投げたあと引っこむ
			var off := roundf((1.0 - rise + sink) * 18.0)
			# 岩棚より下にはみ出さないように切り取る代わりに、岩棚の色で隠す
			var spr2: Array = SPR_ONI_UP if tau <= 0.0 else SPR_ONI_THROW
			_spr(spr2, oni_c + Vector2(0, off), ONI_PAL, not left3)
			if off > 0.0:   # 岩棚の下に隠れている部分を、崖の色で覆う
				draw_rect(Rect2(oni_c.x - 14.0, feet + 1.0, 28, off + 2.0), C_CLIFF_D)
			draw_rect(Rect2(sx_b, feet, sw2, 4), C_CLIFF_D)
			draw_rect(Rect2(sx_b, feet, sw2, 1), C_CLIFF_L)
		if tau <= 0.0:
			# 振りかぶり中: 頭上の岩と、飛んでいく道筋（赤い点線）
			var shake2 := roundf(sin(t * 50.0) * 1.0)
			var hold := Vector2(hx + shake2, hy + roundf((1.0 - clampf(rk.t / 0.15, 0.0, 1.0)) * 18.0))
			draw_circle(hold, rr + 1.0, C_BLACK)
			draw_circle(hold, rr, C_ROCK)
			draw_circle(hold + Vector2(2, 2), rr * 0.6, C_ROCK_D)
			var pulse := 0.55 + 0.45 * absf(sin(t * 10.0))
			var k3 := 0.0
			var f: float = model.cfg.rock_flight
			while k3 < f * 1.8:
				var pp: Vector2 = model.rock_pos(rk, k3)
				var dpos := Vector2(_sx(pp.x), _sy(pp.y)).round()
				draw_rect(Rect2(dpos.x - 2, dpos.y - 2, 4, 4), Color(C_BLACK, 0.5 * pulse))
				draw_rect(Rect2(dpos.x - 1, dpos.y - 1, 3, 3), Color(C_RED, pulse))
				k3 += 0.06
			if hy < 6.0 and fmod(t, 0.3) < 0.2:   # 画面の上にいる鬼の予告
				var wx := clampf(hx, 10.0, FIELD_W - 10.0)
				draw_rect(Rect2(wx - 5, 2, 11, 2), C_RED)
				draw_rect(Rect2(wx - 3, 4, 7, 2), C_RED)
				draw_rect(Rect2(wx - 1, 6, 3, 2), C_RED)
				_label(Vector2(wx, 26), "！", 16, C_RED, HORIZONTAL_ALIGNMENT_CENTER)
			elif hy > 0.0:
				_label(Vector2(hx, hy - rr - 8.0), "！", 16, C_RED, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var rky: float = _sy(rk.h)
		var rkx: float = _sx(rk.x)
		if rky < -20.0 or rky > H + 20.0:
			continue
		# 飛んでくる岩: 進む向きの後ろにうっすら残像
		var back: Vector2 = model.rock_pos(rk, maxf(tau - 0.06, 0.0))
		var bpos := Vector2(_sx(back.x), _sy(back.y))
		draw_circle(bpos, rr, Color(C_WHITE, 0.12))
		draw_circle(Vector2(rkx, rky), rr + 1.0, C_BLACK)
		draw_circle(Vector2(rkx, rky), rr, C_ROCK)
		var spin: float = tau * 12.0 * -rk.side
		draw_circle(Vector2(rkx, rky) + Vector2(cos(spin), sin(spin)) * 3.0, rr * 0.55, C_ROCK_D)
		draw_rect(Rect2(rkx + cos(spin + 2.5) * 5.0 - 1.0, rky + sin(spin + 2.5) * 5.0 - 1.0, 3, 3), C_ROCK_L)

	# 糸（上側）: 天から手元へ
	var py := _player_sy()
	var px := _sx(model.x)
	var hand := Vector2(px, py - 15.0)
	var thread_top := Vector2(THREAD_X, maxf(goal_y - 52.0, -4.0))   # 蜘蛛から垂れる
	# 糸の色は上下で同じ。傷むほど少しずつ赤みが差し、切れそうになると赤く点滅
	var tc := C_SILK
	if slowmo > 0.0:
		tc = C_GOLD   # 九死に一生のあと、糸が金に光る
	if model.state == ThreadModel.State.CLIMBING:
		tc = C_SILK.lerp(C_RED, (1.0 - model.durability / ThreadModel.DURABILITY_MAX) * 0.7)
		if model.time_to_snap(true) < 1.3 and fmod(t, 0.3) < 0.15:
			tc = C_RED
	if model.state == ThreadModel.State.TORN:
		# 切れた上の糸: 切り口が跳ね上がり、しなりながら天へ引き上げられていく
		var snap_y := _sy(model.height) - 15.0 - minf(fall_t * fall_t * 900.0 + fall_t * 120.0, 600.0)
		var amp := 10.0 * maxf(0.0, 1.0 - fall_t * 1.5)
		var pts := PackedVector2Array()
		var top_y := thread_top.y
		for k in range(17):
			var f := k / 16.0
			var yy := lerpf(top_y, snap_y, f)
			var xx := lerpf(thread_top.x, _sx(torn_x), f) + sin(f * 9.0 - fall_t * 24.0) * amp * f
			pts.append(Vector2(roundf(xx), roundf(yy)))
		if snap_y > top_y:
			draw_polyline(pts, C_SILK, 1.0)
	else:
		draw_line(thread_top, hand, tc, 1.0)

	# 糸（下側）と罪人と、糸の耐久度の○ゲージ
	if model.state == ThreadModel.State.CLIMBING:
		var snap := model.time_to_snap(true)
		# 下に余っている糸は、切った所（下端）まで。登るほど伸びていく
		var end_y := minf(_sy(model.thread_end) - 15.0, H + 20.0)
		end_y = minf(end_y, _sy(0.0) + 16.0)   # 糸は地面より下には垂れない（スタート地点で地面に届いて止まる）
		var pts := PackedVector2Array([hand])
		var i := 0.0
		while py + 18.0 + i * GHOST_GAP < end_y:
			pts.append(Vector2(_gx(model.x, i), py + 18.0 + i * GHOST_GAP))
			i += 1.0
		if end_y > hand.y and end_y < H:
			var last: Vector2 = pts[pts.size() - 1]
			var tip := Vector2(_gx(model.x, maxf(i - 1.0, 0.0)), end_y)
			if end_y < last.y:
				tip = last.lerp(Vector2(last.x, end_y), 1.0)
			pts.append(tip)
			if pts.size() >= 2:
				draw_polyline(pts, tc, 1.0)
			# ちぎれた端のほつれ
			draw_rect(Rect2(tip.x - 1, tip.y, 1, 2), Color(tc, 0.7))
			draw_rect(Rect2(tip.x + 1, tip.y + 1, 1, 2), Color(tc, 0.7))
		else:
			if pts.size() >= 2:
				draw_polyline(pts, tc, 1.0)
		for g in range(int(model.ghosts)):
			var gy := py + 46.0 + g * GHOST_GAP
			if gy > H + 10.0:
				break
			var side := g % 2 == 0
			_spr(SPR_GHOST, Vector2(_gx(model.x, g + 3) + (8.0 if side else -8.0), gy), _ghost_pal(g), not side)
		# 空振り: 蹴った足の先で、何もない空を切る「ヒュッ」という弧
		var nt := NOPE_TIME - ring_nope
		if ring_nope > 0.0 and nt > 0.06 and nt < 0.36 and int(model.ghosts) == 0:
			var foot := Vector2(_sx(model.x) - 5.0, py + 20.0)
			var wa := 1.0 - (nt - 0.06) / 0.3
			for k in range(3):
				var wr := 6.0 + k * 4.0 + (nt - 0.06) * 30.0
				draw_arc(foot, wr, PI * 0.15, PI * 0.85, 10, Color(C_WHITE, wa * (0.8 - k * 0.22)), 1.0)
		# 耐久ゲージは頭の上、天へ伸びる糸の上に付ける
		var top_pt := thread_top
		var ring_c := (hand + (top_pt - hand).normalized() * 20.0).round()
		_draw_frayed_thread(hand, top_pt)
		_draw_ring(ring_c, snap)

	# 叫びの衝撃波
	if stomp_fx > 0.0:
		_draw_blast()

	# ちぎれて落ちていく糸
	for th in falling_thread:   # 切れた糸: 鞭のようにしなりながら落ちていく
		var age: float = th[2]
		var ty: float = _sy(th[0]) + 16.0 + roundf(age * age * 450.0)
		var tx: float = _sx(th[1])
		var amp := 14.0 * maxf(0.0, 1.0 - age * 1.2)
		var tcol: Color = (C_GOLD if shout_clutch else C_SILK).lerp(C_RED, minf(age * 1.5, 1.0))
		var pts := PackedVector2Array()
		for k in range(24):
			var yy := ty + k * 14.0
			pts.append(Vector2(roundf(tx + sin(k * 0.55 - age * 18.0) * amp * (k / 23.0)), yy))
		draw_polyline(pts, Color(tcol, maxf(0.0, 1.0 - age * 0.6)), 1.0)
	for f in falling_ghosts:   # 落ちていく罪人（手足をばたつかせて、そのまま落下）
		var fr: int = int(f[2] * 1.5) % 2
		var fp: Vector2 = f[0]
		if f.size() > 4 and f[4] > 0.0:   # 弾かれる直前: 白く光る
			var wp := {"s": C_WHITE, "h": C_WHITE, "k": C_WHITE, "m": C_WHITE, "c": C_WHITE}
			_spr(SPR_GHOST, fp.round(), wp if fmod(t, 0.08) < 0.05 else _ghost_pal(int(f[3])), int(f[3]) % 2 == 0)
			continue
		_spr(SPR_GHOST_RUN if fr == 1 else SPR_GHOST, fp.round(), _ghost_pal(int(f[3]) if f.size() > 3 else 0), fr == 1)

	# カンダタ
	if not (model.invuln_left > 0.0 and fmod(t, 0.16) < 0.08):
		_draw_kandata(Vector2(px, py))

	# 叫び演出
	if shout_age < hitstop_total + 0.25:
		_draw_speed_lines(Vector2(px, py - 6.0))
	if fx_shout > 0.0:
		_draw_shout_text(px, py)
	for p in popups:
		var a: float = 1.0 - p[3] / 1.2
		var pc: Color = p[4]
		_label(Vector2(_sx(p[2]) + 12, _sy(p[1]) - roundf(p[3] * 20.0)), p[0], 16, Color(pc, a))

	_draw_lava()
	_draw_particles()
	_draw_heat_edge()
	_draw_clutch_heartbeat()

	# 案内: 初めてその場面になったときだけ、下にそっと出る
	if phase == Phase.PLAY and tip_text != "":
		var ta := clampf(minf(tip_t / 0.25, (TIP_TIME - tip_t) / 0.4), 0.0, 1.0)
		var tw2 := font.get_string_size(tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var tx := roundf(FIELD_W * 0.5 - tw2 * 0.5)
		draw_rect(Rect2(tx - 8, H - 26, tw2 + 16, 20), Color(C_BLACK, 0.65 * ta))
		_label(Vector2(tx, H - 10), tip_text, 16, Color(C_WHITE, ta))


const C_CLIFF := Color8(58, 40, 40)
const C_CLIFF_D := Color8(36, 24, 26)
const C_CLIFF_L := Color8(92, 66, 60)


func _draw_lava() -> void:
	# 下から迫るマグマ。地面より下にいるうちは、地面の割れ目から光が漏れるだけ
	# 地面の下にいるうちは、土の断面の中をゆっくりせり上がってくる（地表に届くと、あふれ出す）
	var top := _sy(model.lava_h) + LAVA_OFF
	var ground_y := _sy(0.0) + 16.0
	if model.lava_h < 0.0 and ground_y < H:
		# 近づくほど、地面の割れ目が明るく光る
		var glow := clampf(1.0 - (-model.lava_h) / 30.0, 0.0, 1.0)
		for i in range(0, int(FIELD_W), 23):
			var cy := ground_y + 6.0 + float((i * 7) % 20)
			if cy < minf(H, top):
				draw_rect(Rect2(i, cy, 8 + (i % 3) * 3, 1), Color(C_ORANGE, 0.2 + 0.6 * glow * (0.6 + 0.4 * sin(t * 4.0 + i))))
	if top > H + 8.0:
		return
	# 熱気: 上へ行くほど薄くなる橙の層（ゆらゆら）
	for i in range(10):
		var hy := top - 4.0 - i * 5.0
		draw_rect(Rect2(0, hy + roundf(sin(t * 2.0 + i) * 1.0), FIELD_W, 5), Color(C_ORANGE, 0.16 - i * 0.015))
	# 本体: 深いところほど暗い赤
	var depth_cols := [C_RED, Color8(170, 30, 24), Color8(130, 20, 22), C_BLOOD, Color8(70, 10, 16)]
	for i in range(5):
		draw_rect(Rect2(0, top + 4.0 + i * 8.0, FIELD_W, 8 if i < 4 else H - top + 10.0), depth_cols[i])
	# 表面: 二つの波を重ねた、うねる縁
	var x := 0.0
	while x < FIELD_W:
		var w1 := sin(x * 0.07 + t * 2.6) * 2.5 + sin(x * 0.023 - t * 1.7) * 3.0
		var wy := roundf(top + w1)
		draw_rect(Rect2(x, wy - 1.0, 2, 3), C_YELLOW)
		draw_rect(Rect2(x, wy + 2.0, 2, 4), C_ORANGE)
		if int(x * 0.5 + t * 30.0) % 19 < 2:
			draw_rect(Rect2(x, wy - 2.0, 2, 1), C_WHITE)   # きらめき
		x += 2.0
	# 表面を流れる黒い固まり（冷えた溶岩）と、その割れ目の光
	for k in range(9):
		var cx := fmod(k * 71.0 + t * (8.0 + k % 3 * 5.0) * (1.0 if k % 2 == 0 else -1.0), FIELD_W + 60.0)
		if cx < 0.0:
			cx += FIELD_W + 60.0
		cx -= 30.0
		var cw := 14.0 + float(k % 4) * 6.0
		var cy2 := top + 7.0 + float(k % 3) * 7.0
		draw_rect(Rect2(roundf(cx), roundf(cy2), cw, 3), Color8(60, 14, 14))
		draw_rect(Rect2(roundf(cx + cw * 0.4), roundf(cy2 + 1.0), 3, 1), C_ORANGE)
	# 泡: ふくらんで、はじける
	for k in range(7):
		var bx := fmod(k * 89.0 + 23.0 + floorf(t * 0.6 + k * 0.31) * 137.0, FIELD_W)
		var ph := fmod(t * 0.6 + k * 0.31, 1.0)
		if ph < 0.35:
			var rr := 1.0 + ph * 14.0
			draw_arc(Vector2(bx, top + 2.0), rr, PI, TAU, 10, C_YELLOW, 1.0)
			draw_circle(Vector2(bx, top + 3.0), rr - 1.0, Color(C_ORANGE, 0.8))


func _draw_clutch_heartbeat() -> void:
	# 九死に一生の圏内: 文字は出さず、画面が暗く沈み、縁が心臓の鼓動のように赤く脈打つ
	if phase != Phase.PLAY or not (model.is_clutch() and model.can_shout()):
		return
	var p := fmod(t, 0.8)
	var beat := 0.0
	if p < 0.09:
		beat = 1.0 - p / 0.09
	elif p > 0.18 and p < 0.27:
		beat = 0.7 * (1.0 - (p - 0.18) / 0.09)
	draw_rect(Rect2(0, 0, FIELD_W, H), Color(C_BLACK, 0.28 + 0.1 * beat))
	for i in range(10):
		var a := (0.5 * beat + 0.15) * (1.0 - i / 10.0)
		draw_rect(Rect2(0, i * 3.0, FIELD_W, 3), Color(C_RED, a))
		draw_rect(Rect2(0, H - 3.0 - i * 3.0, FIELD_W, 3), Color(C_RED, a))
		draw_rect(Rect2(i * 3.0, 0, 3, H), Color(C_RED, a))
		draw_rect(Rect2(FIELD_W - 3.0 - i * 3.0, 0, 3, H), Color(C_RED, a))


func _draw_heat_edge() -> void:
	# マグマが近いと、画面の下の縁が赤く脈打つ
	var gap: float = model.height - model.lava_h
	if gap > 25.0 or phase != Phase.PLAY:
		return
	var k := clampf(1.0 - gap / 25.0, 0.0, 1.0) * (0.6 + 0.4 * absf(sin(t * 6.0)))
	for i in range(8):
		draw_rect(Rect2(0, H - 8.0 - i * 6.0, FIELD_W, 6), Color(C_RED, 0.3 * k * (1.0 - i / 8.0)))
		draw_rect(Rect2(i * 4.0, 0, 4, H), Color(C_RED, 0.12 * k * (1.0 - i / 8.0)))
		draw_rect(Rect2(FIELD_W - 4.0 - i * 4.0, 0, 4, H), Color(C_RED, 0.12 * k * (1.0 - i / 8.0)))


func _cliff_edge(world_y: float, left: bool) -> float:
	# 崖の縁のでこぼこ（世界の高さに固定。登っても形が流れていくように）
	var n := sin(world_y * 0.9 + (0.0 if left else 2.0)) * 3.0 + sin(world_y * 0.23 + (1.0 if left else 4.0)) * 5.0
	var base: float = _sx(-ThreadModel.X_LIMIT - ThreadModel.BODY_W) if left else _sx(ThreadModel.X_LIMIT + ThreadModel.BODY_W)
	return roundf(base + (n - 4.0 if left else -n + 4.0))


func _draw_cliffs() -> void:
	for side in [true, false]:
		var left: bool = side
		var yy := 0.0
		while yy < H:
			var wy := (PLAYER_SY - yy) / PPM + cam_h   # この行の世界の高さ（m）
			var ex := _cliff_edge(wy, left)
			var x0: float = 0.0 if left else ex
			var w: float = ex if left else FIELD_W - ex
			# 岩の地層: 世界に固定した横縞
			var band := int(floorf(wy / 2.5)) % 3
			var col: Color = [C_CLIFF, C_CLIFF_D, Color8(48, 32, 34)][band]
			draw_rect(Rect2(x0, yy, w, 2), col)
			# 縁の明るい面と影
			draw_rect(Rect2(ex - 3.0 if left else ex, yy, 3, 2), C_CLIFF_L if left else C_CLIFF_D)
			draw_rect(Rect2(ex if left else ex - 2.0, yy, 2, 2), Color(C_BLACK, 0.35))
			yy += 2.0
		# ひび割れ（世界に固定）
		var m0 := floori(cam_h - 70.0)
		for k in range(m0, m0 + 140, 7):
			var cy := _sy(float(k))
			var cx: float = (8.0 + float((k * 37) % 50)) if left else (FIELD_W - 10.0 - float((k * 41) % 50))
			draw_rect(Rect2(cx, cy, 6, 1), C_CLIFF_D)
			draw_rect(Rect2(cx + 5, cy + 1, 4, 1), C_CLIFF_D)


func _draw_needle_mountains() -> void:
	var base := PLAYER_SY + 40.0 + cam_h * PPM * 0.3   # 登るほど下へ遠ざかる
	if base - 140.0 > H:
		return
	for layer in range(2):
		var far := layer == 0
		var col := Color8(36, 16, 22) if far else Color8(22, 10, 14)
		var needle := Color8(120, 104, 112) if far else Color8(176, 166, 172)
		var lb := base + (0.0 if far else 30.0)
		var x := 0.0
		while x < FIELD_W:
			var hh := 70.0 + 70.0 * absf(sin((x + layer * 70.0) * 0.016)) + 18.0 * sin(x * 0.05 + layer)
			if not far:
				hh *= 0.6
			var top := roundf(lb - hh)
			draw_rect(Rect2(x, top, 2, H - top + 40.0), col)
			# 針: 山肌から上へ突き出す
			if int(x) % 4 == 0:
				var nl := 5.0 + float(int(x * 7.0) % 6)
				draw_rect(Rect2(x, top - nl, 1, nl), needle)
			x += 2.0


func _draw_goal(goal_y: float) -> void:
	# 極楽への入り口: 岩の天井に穴が開いていて、その上の雲から糸が垂れている
	var ceil_top := goal_y - 46.0
	var ceil_bot := goal_y - 6.0
	# 天井より上は青空
	for i in range(6):
		var by := ceil_bot - (i + 1) * 30.0
		draw_rect(Rect2(0, by, FIELD_W, 30), C_SKY_LO.lerp(C_SKY_HI, i / 5.0))
	if ceil_bot - 180.0 > -400.0:
		draw_rect(Rect2(0, -400, FIELD_W, ceil_bot - 180.0 + 400.0), C_SKY_HI)
	# 穴から差し込む光
	for k in range(3):
		var spread := 40.0 + k * 34.0
		draw_colored_polygon(PackedVector2Array([Vector2(THREAD_X - 50, ceil_bot), Vector2(THREAD_X + 50, ceil_bot),
				Vector2(THREAD_X + 50 + spread, ceil_bot + 220), Vector2(THREAD_X - 50 - spread, ceil_bot + 220)]),
				Color(C_SKY_LO, 0.07))
	for k in range(5):
		var rx := THREAD_X - 40.0 + k * 20.0 + sin(t * 1.3 + k) * 3.0
		draw_rect(Rect2(roundf(rx), ceil_bot, 2, 160), Color(C_CLOUD, 0.05 + 0.03 * sin(t * 2.0 + k * 1.7)))
	# 岩の天井（穴は下ほど広い）
	var yy := ceil_top
	while yy < ceil_bot:
		var k := (yy - ceil_top) / (ceil_bot - ceil_top)
		var hw := roundf(46.0 + 20.0 * k + sin(yy * 0.7) * 3.0)
		var col := C_ROCK_D.lerp(C_ROCK, k)
		draw_rect(Rect2(0, yy, THREAD_X - hw, 2), col)
		draw_rect(Rect2(THREAD_X + hw, yy, FIELD_W - THREAD_X - hw, 2), col)
		yy += 2.0
	# 天井の下側のギザギザ
	for i in range(0, int(FIELD_W), 8):
		var cx := float(i)
		if absf(cx + 4.0 - THREAD_X) < 70.0:
			continue
		var dh := 2.0 + float((i * 7) % 5) * 2.0
		draw_rect(Rect2(cx, ceil_bot, 8, dh), C_ROCK)
		draw_rect(Rect2(cx + 2, ceil_bot + dh, 4, 2), C_ROCK_D)
	draw_rect(Rect2(0, ceil_top - 2, FIELD_W, 2), Color(C_BLACK, 0.4))
	# 雲（穴の向こうの景色）と、穴にいる蜘蛛（糸はここから垂れている）
	_spr(SPR_CLOUD, Vector2(THREAD_X - 70 + roundf(sin(t * 0.5) * 4.0), goal_y - 80.0), {"w": C_CLOUD, "s": C_CLOUD_S})
	draw_rect(Rect2(THREAD_X, ceil_top - 30.0, 1, 18), Color(C_WHITE, 0.6))
	_spr(SPR_SPIDER, Vector2(THREAD_X, goal_y - 52.0 - 9.0 + roundf(sin(t * 2.0))), {"l": C_BLACK, "b": Color8(46, 30, 40), "e": C_RED})


func _draw_meadow() -> void:
	# 極楽: 青空、流れる雲、遠くの丘、風に揺れる草原
	var horizon := 214.0
	for i in range(12):
		draw_rect(Rect2(0, i * 18.0, W, 18), C_SKY_HI.lerp(C_SKY_LO, i / 11.0))
	# 太陽
	var sun := Vector2(540, 56)
	draw_circle(sun, 26.0, Color(C_YELLOW, 0.25))
	draw_circle(sun, 18.0, Color8(255, 240, 160))
	for k in range(8):
		var a := TAU * k / 8.0 + t * 0.2
		var p0 := sun + Vector2(cos(a), sin(a)) * 32.0
		draw_rect(Rect2(roundf(p0.x) - 1, roundf(p0.y) - 1, 3, 3), Color8(255, 236, 150))
	# 流れる雲
	for i in range(5):
		var cx := fmod(i * 170.0 + t * (8.0 + i * 3.0), W + 120.0) - 60.0
		var cy := 40.0 + float(i % 3) * 38.0
		_spr(SPR_CLOUD, Vector2(roundf(cx), cy), {"w": C_CLOUD, "s": C_CLOUD_S}, i % 2 == 1)
	# 鳥
	for i in range(3):
		var bx := fmod(t * 30.0 + i * 90.0, W + 60.0) - 30.0
		var by := 90.0 + i * 14.0 + roundf(sin(t * 3.0 + i) * 3.0)
		_spr(SPR_BIRD, Vector2(roundf(bx), by), {"b": Color8(60, 70, 100)}, false, 1)
	# 遠くの丘
	for x in range(0, int(W), 2):
		var hh := 26.0 + sin(x * 0.012) * 14.0 + sin(x * 0.031 + 1.0) * 6.0
		draw_rect(Rect2(x, horizon - roundf(hh), 2, roundf(hh)), C_HILL)
		var hh2 := 12.0 + sin(x * 0.02 + 2.0) * 8.0
		draw_rect(Rect2(x, horizon - roundf(hh2), 2, roundf(hh2)), C_HILL_D)
	# 草原
	draw_rect(Rect2(0, horizon, W, H - horizon), C_GRASS)
	for i in range(5):
		draw_rect(Rect2(0, horizon + 10 + i * 28, W, 2), C_GRASS_D.lerp(C_GRASS, 0.5))
	# 風: 草がそよぐ
	var wind := sin(t * 1.6) * 0.5 + 0.5
	for i in range(220):
		var gx := float((i * 37) % int(W))
		var gy := horizon + 4.0 + float((i * 53) % int(H - horizon - 6.0))
		var ht := 4.0 + float(i % 4) * 2.0
		var sway := roundf((sin(t * 3.0 + gx * 0.04) * 1.5 + wind * 2.0) * (ht / 8.0))
		var gc := C_GRASS_L if i % 3 == 0 else C_GRASS_D
		draw_rect(Rect2(gx, gy - ht * 0.5, 1, ht * 0.5), gc)
		draw_rect(Rect2(gx + sway, gy - ht, 1, ht * 0.5), gc)
	# 花
	for i in range(40):
		var fx := float((i * 97 + 13) % int(W))
		var fy := horizon + 10.0 + float((i * 61) % int(H - horizon - 14.0))
		var fc: Color = [C_CLOUD, C_YELLOW, Color8(250, 150, 190)][i % 3]
		var fs := roundf(sin(t * 3.0 + fx * 0.04) * 1.0)
		draw_rect(Rect2(fx + fs - 1, fy, 3, 1), fc)
		draw_rect(Rect2(fx + fs, fy - 1, 1, 3), fc)
	# 風の筋と、舞う花びら
	for i in range(6):
		var wx := fmod(t * 140.0 + i * 120.0, W + 200.0) - 100.0
		var wy := 120.0 + i * 34.0 + roundf(sin(t * 2.0 + i) * 4.0)
		draw_rect(Rect2(roundf(wx), wy, 24, 1), Color(C_CLOUD, 0.5))
		draw_rect(Rect2(roundf(wx) + 30, wy + 2, 10, 1), Color(C_CLOUD, 0.35))
	for i in range(14):
		var px := fmod(t * (50.0 + i * 6.0) + i * 47.0, W + 40.0) - 20.0
		var py := 150.0 + fmod(i * 23.0 + sin(t * 2.0 + i) * 10.0, 180.0)
		draw_rect(Rect2(roundf(px), roundf(py), 2, 1), Color8(250, 170, 200))

	# 蓮池: 池の底から地獄へ糸が垂れている（原作どおり）
	var pond := Vector2(300, 298)
	var prx := 170.0
	var pry := 42.0
	for row in range(int(-pry) - 3, int(pry) + 3):
		var f := 1.0 - pow(row / (pry + 3.0), 2.0)
		if f <= 0.0:
			continue
		var hw := roundf((prx + 6.0) * sqrt(f))
		draw_rect(Rect2(pond.x - hw, pond.y + row, hw * 2, 1), Color8(120, 150, 90))   # 岸
	for row in range(int(-pry), int(pry)):
		var hw := roundf(prx * sqrt(1.0 - pow(row / pry, 2.0)))
		var wc := Color8(96, 176, 226).lerp(Color8(60, 130, 200), (row + pry) / (pry * 2.0))
		draw_rect(Rect2(pond.x - hw, pond.y + row, hw * 2, 1), wc)
	for i in range(16):   # さざ波
		var rx := pond.x - prx * 0.8 + fmod(i * 41.0 + t * 10.0, prx * 1.6)
		var ry := pond.y - pry * 0.7 + float((i * 23) % int(pry * 1.4))
		if pow((rx - pond.x) / prx, 2.0) + pow((ry - pond.y) / pry, 2.0) < 0.8:
			draw_rect(Rect2(roundf(rx), roundf(ry), 4 + i % 3 * 2, 1), Color(C_CLOUD, 0.55))
	# 蓮の葉と花（ゆらゆら）
	var pads := [Vector2(-120, -6), Vector2(-60, 22), Vector2(70, -18), Vector2(110, 16), Vector2(-20, -28), Vector2(140, -4), Vector2(30, 30)]
	for i in range(pads.size()):
		var pp: Vector2 = pond + pads[i] + Vector2(0, roundf(sin(t * 1.5 + i) * 1.0))
		_spr(SPR_LILY_PAD, pp, {"g": C_GRASS_D, "G": C_GRASS})
	var flowers := [Vector2(-130, -14), Vector2(-62, 14), Vector2(72, -26), Vector2(118, 8), Vector2(150, -12), Vector2(-150, 10)]
	for i in range(flowers.size()):
		var fp: Vector2 = pond + flowers[i] + Vector2(0, roundf(sin(t * 1.2 + i * 2.0) * 1.0))
		_spr(SPR_LOTUS_FLOWER, fp, {"p": Color8(226, 110, 150), "P": Color8(250, 196, 214), "y": C_YELLOW, "g": C_GRASS_D})

	# 真ん中の大きな蓮の葉と、蜘蛛。糸は葉の脇から池の中へ
	var leaf := pond + Vector2(0, 4)
	_spr(SPR_LILY_PAD, leaf, {"g": C_GRASS_D, "G": C_GRASS}, false, 4)
	var sp := leaf + Vector2(30, -8)
	draw_line(sp + Vector2(-6, 4), leaf + Vector2(20, 10), Color(C_GOLD, 0.9), 1.0)
	_spr(SPR_SPIDER, sp + Vector2(0, roundf(sin(t * 2.0))), {"l": C_BLACK, "b": Color8(46, 30, 40), "e": C_RED})

	# カンダタ: 水面からしぶきを上げて飛び出し、葉の上で両手を上げて喜ぶ
	var k := clampf((phase_t - 0.35) / 0.5, 0.0, 1.0)
	if phase_t > 0.35 and phase_t < 1.6:
		var sk := (phase_t - 0.35) / 1.25
		for j in range(3):
			var rr := roundf(8.0 + sk * 60.0 + j * 10.0)
			draw_arc(leaf, rr, PI * 1.05, PI * 1.95, 24, Color(C_CLOUD, maxf(0.0, 0.8 - sk)), 1.0)
		for j in range(8):
			var dx := (j - 3.5) * 6.0
			var dy := -sin(sk * PI) * (30.0 + (j % 3) * 10.0)
			draw_rect(Rect2(leaf.x + roundf(dx * (1.0 + sk * 2.0)), leaf.y - 6 + roundf(dy), 2, 2), Color(C_CLOUD, maxf(0.0, 1.0 - sk)))
	var ky := lerpf(leaf.y + 20.0, leaf.y - 24.0, 1.0 - (1.0 - k) * (1.0 - k)) - roundf(absf(sin(t * 5.0)) * 4.0) * k
	_spr(SPR_KANDATA_JUMP, Vector2(leaf.x - 4, roundf(ky)), {"s": C_SKIN, "h": C_HAIR, "k": C_BLACK, "m": C_RED, "c": C_CLOTH}, false, 3)

	# お釈迦様: 池のほとり、蓮の台座に座って静かに見守る
	var bud := Vector2(552, 244)
	var glow := 0.5 + 0.5 * sin(t * 1.2)
	var halo := bud + Vector2(0, -30)
	draw_circle(halo, 44.0, Color(C_YELLOW, 0.10 + 0.06 * glow))
	draw_circle(halo, 32.0, Color(C_YELLOW, 0.18))
	draw_arc(halo, 34.0, 0, TAU, 40, Color(C_GOLD, 0.85), 1.0)
	for k2 in range(12):   # 後光
		var a2 := TAU * k2 / 12.0
		var p2 := halo + Vector2(cos(a2), sin(a2)) * (38.0 + 2.0 * glow)
		draw_rect(Rect2(roundf(p2.x) - 1, roundf(p2.y) - 1, 2, 2), Color(C_YELLOW, 0.7))
	_spr(SPR_BUDDHA, bud, {"h": Color8(52, 62, 116), "s": Color8(242, 206, 132), "k": Color8(110, 70, 40),
			"m": Color8(200, 110, 90), "w": Color8(255, 250, 230), "r": Color8(222, 120, 46), "R": Color8(172, 84, 30)}, false, 3)
	_draw_particles()
	_spr(SPR_PEDESTAL, bud + Vector2(0, 38), {"p": Color8(226, 110, 150), "P": Color8(250, 196, 214), "g": C_GRASS_D}, false, 3)


func _draw_ring(c: Vector2, _snap: float) -> void:
	# 糸の耐久ゲージ: 頭上の糸に付いた横棒。色は残量で 緑→黄→赤
	var r := model.durability / ThreadModel.DURABILITY_MAX
	var col := C_GREEN
	if r <= 0.5:
		col = C_YELLOW
	if r <= 0.25:
		col = C_RED
	if ring_nope > 0.0:   # 踏み台がいないのに叫んだ: 棒が左右に震える
		c.x += roundf(sin(ring_nope * 60.0) * 2.0)
	var bw := 26.0
	var x0 := roundf(c.x - bw * 0.5)
	var y0 := roundf(c.y - 2.0)
	draw_rect(Rect2(x0 - 2, y0 - 2, bw + 4, 8), C_BLACK)   # 黒い縁で、どの背景でも浮かせる
	draw_rect(Rect2(x0, y0, bw, 4), Color(C_WHITE, 0.18))
	if r > 0.0:
		draw_rect(Rect2(x0, y0, maxf(1.0, roundf(bw * r)), 4), col)


func _draw_frayed_thread(hand: Vector2, top: Vector2) -> void:
	# 頭上の糸そのものが、傷むほど細く・赤く・ほつれていく。九死に一生の圏内（切れかけ）では、ところどころ途切れて見える
	var r := model.durability / ThreadModel.DURABILITY_MAX
	var dir := (top - hand).normalized()
	var a := hand + dir * 4.0
	var b := hand + dir * 70.0
	var w := 3.0 if r > 0.6 else (2.0 if r > 0.3 else 1.0)
	var col := C_SILK.lerp(C_RED, clampf(1.0 - r, 0.0, 1.0) * 0.8)
	draw_line(a, b, col, w)
	var n := int((1.0 - r) * 14.0)   # ほつれた繊維（傷むほど増える）
	for k in range(n):
		var f := fmod(k * 0.37 + 0.1, 1.0)
		var p := a.lerp(b, f).round()
		var sgn := 1.0 if k % 2 == 0 else -1.0
		var l := 2.0 + float(k % 3) + (1.0 - r) * 3.0
		draw_line(p, p + Vector2(sgn * l, -l * 0.6 + sin(t * 6.0 + k) * 1.5).round(), Color(col, 0.85), 1.0)
	if model.is_clutch() and fmod(t, 0.3) < 0.15:
		for k in range(3):
			var p2 := a.lerp(b, 0.25 + k * 0.25).round()
			draw_rect(Rect2(p2.x - 2, p2.y - 1, 5, 3), C_BLACK)


func _ghost_pal(i: int) -> Dictionary:
	# カンダタと同じ肌・黒い目・赤い口。肌の濃淡、髪、腰布の色だけ一人ずつ変える
	var skin := C_SKIN.lerp(Color8(196, 140, 100), float((i * 7) % 5) / 4.0)
	var cloths := [Color8(110, 96, 80), Color8(96, 70, 56), Color8(120, 110, 96), Color8(84, 76, 70)]
	return {"s": skin, "h": GHOST_HAIR[i % GHOST_HAIR.size()], "k": C_BLACK, "m": C_RED,
			"c": cloths[(i * 3) % cloths.size()]}


func _draw_kandata(p: Vector2) -> void:
	var pal := {"s": C_SKIN, "h": C_HAIR, "k": C_BLACK, "m": C_RED, "c": C_CLOTH}
	if model.is_clutch() and model.can_shout() and fmod(t, 0.16) < 0.08:
		pal["s"] = C_GOLD   # 九死に一生の圏内は金色に明滅
	if model.stun_left > 0.0:
		pal["s"] = Color8(250, 140, 120)
	var lean := clampf(model.vx * 0.01, -4.0, 4.0)
	# 蹴り: 叫んだ直後（罪人を蹴落とす）と、踏み台がいないのに叫んだとき（空振り）
	var kick_t := -1.0
	if shout_age < KICK_TIME and model.state != ThreadModel.State.TORN:
		kick_t = shout_age
	elif ring_nope > 0.0 and model.state == ThreadModel.State.CLIMBING:
		kick_t = NOPE_TIME - ring_nope
	if kick_t >= 0.0 and kick_t < KICK_TIME:
		if kick_t < 0.06:
			_spr(SPR_KANDATA_KICK_A, Vector2(p.x, p.y - 2.0), pal)   # ためる
		else:
			_spr(SPR_KANDATA_KICK_B, Vector2(p.x, p.y + 2.0), pal)   # 真下へ踏みつける
		return
	if model.state == ThreadModel.State.TORN:   # 落ちていく: 手足をばたつかせる
		_spr(SPR_KANDATA_JUMP, Vector2(p.x, p.y), pal, int(fall_t * 8.0) % 2 == 1)
		return
	if model.state == ThreadModel.State.AIR:
		_spr(SPR_KANDATA_JUMP, Vector2(p.x + roundf(lean), p.y), pal)
		return
	if model.state == ThreadModel.State.CLIMBING and climb_moving > 0.0:
		# 手を交互に伸ばす4コマ: 左手上 → 両手 → 右手上 → 両手。伸ばした瞬間に体が持ち上がる
		var fr := int(floorf(climb_phase)) % 4
		var bob := 0.0
		if fr % 2 == 0:
			_spr(SPR_KANDATA_REACH, Vector2(p.x + roundf(lean), p.y + bob), pal, fr == 2)
		else:
			_spr(SPR_KANDATA, Vector2(p.x + roundf(lean), p.y + bob), pal)
		return
	_spr(SPR_KANDATA, Vector2(p.x + roundf(lean), p.y), pal)


func _draw_map() -> void:
	# 右端の縦バー: 下が地獄、上の蓮が極楽。金=今の高さ、赤=マグマ、水色=叫べば届く高さ、白線=自己ベスト
	draw_rect(Rect2(FIELD_W, 0, W - FIELD_W, H), Color8(14, 8, 12))
	draw_rect(Rect2(FIELD_W, 0, 1, H), C_DARK)
	var bx := MAP_X - 1.0
	var bw := 8.0
	var cx := bx + bw * 0.5
	# 極楽の蓮（ゆっくり光る）
	var glow := 0.25 + 0.2 * sin(t * 2.0)
	draw_circle(Vector2(cx, MAP_TOP - 12.0), 9.0, Color(C_YELLOW, glow * 0.5))
	_spr(SPR_LOTUS, Vector2(cx, MAP_TOP - 12), {"y": C_YELLOW}, false, 2)
	# 枠と中身
	draw_rect(Rect2(bx - 1.0, MAP_TOP - 1.0, bw + 2.0, MAP_BOT - MAP_TOP + 2.0), C_DARK)
	draw_rect(Rect2(bx, MAP_TOP, bw, MAP_BOT - MAP_TOP), Color8(30, 14, 20))
	# 目盛り: 100m ごと、500m は長く
	for m in range(100, int(ThreadModel.GOAL), 100):
		var ty := _h_to_map(float(m))
		var long := m % 500 == 0
		draw_rect(Rect2(bx - (4.0 if long else 2.0), ty, 4.0 if long else 2.0, 1), Color(C_WHITE, 0.45 if long else 0.25))
	# 進んだ分（下から金色、上ほど明るく）
	var cur := _h_to_map(model.height)
	var yy := MAP_BOT - 2.0
	while yy >= cur:
		var k := (MAP_BOT - yy) / (MAP_BOT - MAP_TOP)
		draw_rect(Rect2(bx + 1.0, yy, bw - 2.0, 2), C_ORANGE.lerp(C_GOLD, k))
		yy -= 2.0
	# 自己ベストの高さ
	if best[difficulty] > 0 and best[difficulty] < int(ThreadModel.GOAL):
		var by := _h_to_map(float(best[difficulty]))
		draw_rect(Rect2(bx - 2.0, by, bw + 4.0, 1), Color(C_WHITE, 0.7))
	# 叫べば届く高さ
	if model.can_shout():
		var jy := _h_to_map(model.height + model.jump_height())
		draw_rect(Rect2(bx + 1.0, jy, bw - 2.0, cur - jy), Color(C_CYAN, 0.35 + 0.15 * sin(t * 8.0)))
		draw_rect(Rect2(bx - 2.0, jy, bw + 4.0, 1), C_CYAN)
	# マグマ: 波打つ上端
	if model.lava_h > 0.0:
		var lv := _h_to_map(model.lava_h)
		draw_rect(Rect2(bx + 1.0, lv, bw - 2.0, MAP_BOT - lv), C_RED)
		for i in range(int(bw) - 2):
			var wy := lv + roundf(sin(t * 6.0 + i * 1.3))
			draw_rect(Rect2(bx + 1.0 + i, wy - 1.0, 1, 2), C_YELLOW if (i + int(t * 10.0)) % 3 == 0 else C_ORANGE)
		if model.height - model.lava_h < 15.0 and fmod(t, 0.3) < 0.15:   # 迫ると枠が赤く点滅
			draw_rect(Rect2(bx - 1.0, MAP_TOP - 1.0, 1, MAP_BOT - MAP_TOP + 2.0), C_RED)
			draw_rect(Rect2(bx + bw, MAP_TOP - 1.0, 1, MAP_BOT - MAP_TOP + 2.0), C_RED)
	# カンダタの顔
	_spr(SPR_HEAD, Vector2(cx, cur), {"h": C_HAIR, "s": C_SKIN, "k": C_BLACK}, false, 2)
	_spr(SPR_FIRE[int(t * 6.0) % 2], Vector2(cx, MAP_BOT + 14), {"y": C_YELLOW, "o": C_ORANGE, "w": C_RED}, false, 1)


func _draw_hud() -> void:
	# ファミコン風: 画面の上の端に、タイムと高さだけ
	_shadow_label(Vector2(8, 20), "TIME %5.1f" % model.elapsed, C_WHITE)
	_shadow_label(Vector2(FIELD_W - 8, 20), "%d/%dm" % [int(model.height), int(ThreadModel.GOAL)], C_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)


func _shadow_label(p: Vector2, txt: String, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1)]:
		_label(p + o, txt, 16, C_BLACK, align)
	_label(p, txt, 16, col, align)


func _draw_title() -> void:
	# タイトル: 地獄の底から天へ伸びる一本の糸。カンダタがすがり、その下に罪人が連なる（原作の一場面）
	var cx := W * 0.5
	# 空: 上は闇、下ほどマグマに照らされて赤い
	for i in range(18):
		draw_rect(Rect2(0, i * 20, W, 20), C_BLACK.lerp(C_BLOOD, pow(i / 17.0, 1.6)))
	# 天から差す細い光（糸のまわり）
	for k in range(6):
		var lw := 6.0 + k * 10.0
		draw_rect(Rect2(cx - lw * 0.5, 0, lw, 200 - k * 18), Color(C_YELLOW, 0.035))
	# 舞い上がる火の粉
	for i in range(30):
		var ex := fmod(i * 61.0 + sin(t * 0.7 + i) * 8.0, W)
		var ey := fmod(i * 47.0 - t * (14.0 + i % 5 * 5.0), H)
		if ey < 0:
			ey += H
		draw_rect(Rect2(roundf(ex), roundf(ey), 1 + i % 2, 1 + i % 2), Color(C_ORANGE, 0.35 + 0.4 * float(i % 3) / 2.0))
	# 遠くの針の山（2層のシルエットに細い針）
	for layer in range(2):
		var far := layer == 0
		var base := 312.0 if far else 334.0
		var col := Color8(48, 14, 22) if far else Color8(26, 8, 14)
		var x := 0.0
		while x < W:
			var hh := (52.0 if far else 34.0) + 26.0 * absf(sin((x + layer * 90.0) * 0.019)) + 8.0 * sin(x * 0.07 + layer)
			var top := roundf(base - hh)
			draw_rect(Rect2(x, top, 2, H - top), col)
			if int(x) % 4 == 0:
				draw_rect(Rect2(x, top - 6.0 - float(int(x * 3.0) % 5), 1, 6.0 + float(int(x * 3.0) % 5)), Color8(150, 120, 120) if not far else Color8(90, 60, 66))
			x += 2.0
	# 地の底のマグマ
	var lt := 344.0
	draw_rect(Rect2(0, lt, W, H - lt), C_RED)
	var lx := 0.0
	while lx < W:
		var wy := roundf(lt + sin(lx * 0.06 + t * 2.4) * 2.0)
		draw_rect(Rect2(lx, wy - 1, 2, 2), C_YELLOW)
		draw_rect(Rect2(lx, wy + 1, 2, 3), C_ORANGE)
		lx += 2.0
	for i in range(8):
		draw_rect(Rect2(0, lt - 8.0 - i * 4.0, W, 4), Color(C_ORANGE, 0.06 - i * 0.007))
	# 糸と蜘蛛
	var sway := sin(t * 1.1) * 5.0
	var hand := Vector2(roundf(cx + sway), 150.0)
	draw_line(Vector2(cx, 0), hand, C_SILK, 1.0)
	_spr(SPR_SPIDER, Vector2(cx, 120 + roundf(sin(t * 2.0) * 2.0)), {"l": C_BLACK, "b": Color8(60, 40, 52), "e": C_RED})
	# カンダタと、その下に連なる罪人たち（糸は下へ続く）
	var pal := {"s": C_SKIN, "h": C_HAIR, "k": C_BLACK, "m": C_RED, "c": C_CLOTH}
	_spr(SPR_KANDATA, Vector2(hand.x, hand.y + 22.0), pal, false, 3)
	var prev := hand + Vector2(0, 42)
	for g in range(3):
		var gp := Vector2(roundf(cx + sway * (1.0 - 0.25 * (g + 1)) + (9.0 if g % 2 == 0 else -9.0)), 212.0 + g * 30.0)
		draw_line(prev, Vector2(roundf(cx + sway * (1.0 - 0.25 * (g + 1))), gp.y - 18.0), C_SILK, 1.0)
		prev = Vector2(roundf(cx + sway * (1.0 - 0.25 * (g + 1))), gp.y + 8.0)
		_spr(SPR_GHOST, gp, _ghost_pal(g), g % 2 == 1, 3)
	# 題字: 大きく、黒いふちと赤い影
	_draw_logo(Vector2(cx, 58), "パワーカンダタ")
	_label(Vector2(cx, 96), "― 蜘蛛の糸 ―", 16, Color(C_WHITE, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	if fmod(t, 1.0) < 0.65:
		_label(Vector2(cx, 334), "PUSH START", 16, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_label(Vector2(8, H - 8), "C : CREDITS", 16, Color(C_WHITE, 0.45))
	if credits_open:
		_draw_credits()


func _draw_credits() -> void:
	# ライセンス表記（全文は同梱の LICENSES.txt）
	draw_rect(Rect2(0, 0, W, H), Color(C_BLACK, 0.96))
	var cx := W * 0.5
	_label(Vector2(cx, 40), "CREDITS", 16, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var lines := [
		["パワーカンダタ", C_YELLOW],
		["原案  芥川龍之介「蜘蛛の糸」", C_WHITE],
		["", C_WHITE],
		["Font: DotGothic16", C_WHITE],
		["(c) 2020 The DotGothic16 Project Authors", Color(C_WHITE, 0.7)],
		["SIL Open Font License 1.1", Color(C_WHITE, 0.7)],
		["", C_WHITE],
		["Made with Godot Engine", C_WHITE],
		["(c) 2014-present Godot Engine contributors", Color(C_WHITE, 0.7)],
		["(c) 2007-2014 Juan Linietsky, Ariel Manzur", Color(C_WHITE, 0.7)],
		["MIT License", Color(C_WHITE, 0.7)],
		["", C_WHITE],
		["ライセンス全文は LICENSES.txt に同梱", Color(C_WHITE, 0.55)],
	]
	var y := 74.0
	for ln in lines:
		_label(Vector2(cx, y), ln[0], 16, ln[1], HORIZONTAL_ALIGNMENT_CENTER)
		y += 19.0
	if fmod(t, 1.0) < 0.65:
		_label(Vector2(cx, H - 14), "PUSH ANY KEY", 16, Color(C_WHITE, 0.8), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_logo(center: Vector2, text: String) -> void:
	# ドット文字を3倍にして、8方向の黒いふち＋赤い影＋金の本体で描く
	var sc := 3.0
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var p := Vector2(roundf(center.x / sc - tw * 0.5), roundf(center.y / sc + 6.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	for o in [Vector2(1, 2), Vector2(0, 2), Vector2(2, 2)]:
		draw_string(font, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_BLOOD)   # 影
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_string(font, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_BLACK)   # ふち
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_GOLD)
	draw_set_transform(Vector2.ZERO)


func _rank(sec: float) -> String:
	if sec < 45.0:
		return "S"
	if sec < 52.0:
		return "A"
	if sec < 60.0:
		return "B"
	return "C"


func _draw_result() -> void:
	if model.state == ThreadModel.State.WON:
		# 景色を隠さないよう、上に小さく
		var a := clampf((phase_t - WIN_RANK_AT) / 0.4, 0.0, 1.0)
		var wx := W * 0.5
		draw_rect(Rect2(wx - 170, 24, 340, 204), Color(C_BLACK, 0.6 * a))
		_label(Vector2(wx, 58), "極楽に到達！", 32, Color(C_YELLOW, a), HORIZONTAL_ALIGNMENT_CENTER)
		_label(Vector2(wx, 82), "TIME %.1f   RANK %s" % [model.elapsed, _rank(model.elapsed)], 16, Color(C_WHITE, a), HORIZONTAL_ALIGNMENT_CENTER)
		# 上位10件（左に1〜5位、右に6〜10位）。今回のタイムは点滅
		_label(Vector2(wx, 106), "― ランキング ―", 16, Color(C_GOLD, a), HORIZONTAL_ALIGNMENT_CENTER)
		var lst: Array = ranking[difficulty]
		# 1行 = 「順位」「タイム（秒・右そろえ）」「日付（薄く）」。左の列に1〜5位、右の列に6〜10位
		draw_rect(Rect2(wx, 122, 1, 92), Color(C_WHITE, 0.25 * a))   # 列の仕切り
		for i in range(RANKING_SIZE):
			if phase_t < WIN_ROW_AT + WIN_ROW_STEP * i:
				break   # 1位から順に1行ずつ出す
			var col_x := wx - 150.0 if i < 5 else wx + 10.0
			var row_y := 136.0 + float(i % 5) * 18.0
			var is_new := i == new_rank
			var blink := is_new and fmod(t, 0.4) < 0.28
			var rank_col: Color = [C_GOLD, Color8(210, 210, 220), C_ORANGE][i] if i < 3 else Color(C_WHITE, 0.7)
			if is_new:
				rank_col = C_YELLOW if blink else C_ORANGE
				_label(Vector2(col_x - 18.0, row_y), "＞", 16, Color(rank_col, a))   # 今回の記録の印
			_label(Vector2(col_x, row_y), "%d位" % (i + 1), 16, Color(rank_col, a))
			if i < lst.size():
				var tc: Color = (C_YELLOW if blink else C_ORANGE) if is_new else C_WHITE
				_label(Vector2(col_x + 92.0, row_y), "%.1f秒" % float(lst[i]["t"]), 16, Color(tc, a), HORIZONTAL_ALIGNMENT_RIGHT)
				_label(Vector2(col_x + 102.0, row_y), str(lst[i]["d"]), 16, Color(C_WHITE, 0.45 * a))   # 表示は月/日だけ（年は保存のみ）
			else:
				_label(Vector2(col_x + 92.0, row_y), "―", 16, Color(C_WHITE, 0.3 * a), HORIZONTAL_ALIGNMENT_RIGHT)
		if fmod(t, 1.0) < 0.6 and _result_ready():
			_label(Vector2(wx, 346), "PUSH START", 16, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var ga := clampf((phase_t - GAMEOVER_DELAY) / 0.4, 0.0, 1.0)   # ゆっくり暗くなる
	draw_rect(Rect2(0, 0, FIELD_W, H), Color(C_BLACK, 0.8 * ga))
	var cx := FIELD_W * 0.5
	_label(Vector2(cx, 120), "GAME OVER", 32, Color(C_RED, ga), HORIZONTAL_ALIGNMENT_CENTER)
	_label(Vector2(cx, 172), "%d/%dm" % [int(model.height), int(ThreadModel.GOAL)], 32, Color(C_GOLD, ga), HORIZONTAL_ALIGNMENT_CENTER)
	if new_record:
		if fmod(t, 0.4) < 0.28:
			_label(Vector2(cx, 200), "NEW RECORD!", 16, Color(C_YELLOW, ga), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_label(Vector2(cx, 200), "HI %dm" % best[difficulty], 16, Color(C_WHITE, 0.6 * ga), HORIZONTAL_ALIGNMENT_CENTER)
	if fmod(t, 1.0) < 0.6 and phase_t > GAMEOVER_DELAY + 0.6:
		_label(Vector2(cx, 280), "PUSH START", 16, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_panel() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(C_BLACK, 0.8))
	var px := 40.0
	var py := 34.0
	draw_rect(Rect2(px - 16, py - 26, 592, 336), Color8(24, 14, 26))
	draw_rect(Rect2(px - 16, py - 26, 592, 336), C_GOLD, false, 1.0)
	_label(Vector2(px, py), "調整パネル（一時停止中）", 16, C_GOLD)
	var keys: Array = ThreadModel.TUNE_ORDER
	for i in range(keys.size()):
		var k: String = keys[i]
		var y := py + 24.0 + i * 18.0
		var sel := i == panel_sel
		if sel:
			draw_rect(Rect2(px - 8, y - 14, 576, 18), Color(C_GOLD, 0.2))
		var changed: bool = not is_equal_approx(tuning[k], ThreadModel.DEFAULTS[k])
		_label(Vector2(px, y), ("＞" if sel else "　") + ThreadModel.TUNE_LABEL[k], 16, C_WHITE if sel else Color(C_WHITE, 0.75))
		var val := _fmt(tuning[k])
		_label(Vector2(px + 420, y), ("＜ %s ＞" % val) if sel else val, 16, C_GOLD if changed else C_CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
		if changed:
			_label(Vector2(px + 432, y), "標準%s" % _fmt(ThreadModel.DEFAULTS[k]), 16, Color(C_WHITE, 0.45))
	var by := py + 24.0 + keys.size() * 18.0 + 8.0
	_label(Vector2(px, by), "↑↓選ぶ ←→変える BS標準に 0全部標準", 16, Color(C_WHITE, 0.7))
	_label(Vector2(px, by + 18), "F1/Escで閉じる（保存して最初から）", 16, Color(C_WHITE, 0.7))


# ---------------------------------------------------------------- 部品

func _fmt(v: float) -> String:
	var s := "%.2f" % v
	while s.ends_with("0"):
		s = s.left(s.length() - 1)
	return s.trim_suffix(".")


func _label(pos: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# 右寄せ・中央寄せは pos.x を基準に。32 は 16 のドット文字を 2 倍に拡大して描く
	var sc := 2.0 if size >= 32 else 1.0
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * sc
	var p := pos.round()
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= tw
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= roundf(tw * 0.5)
	if sc > 1.0:
		draw_set_transform_matrix(base_xf * Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO))
		var lp := (p / sc).round()
		draw_string(font, lp + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(C_BLACK, col.a))
		draw_string(font, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		draw_set_transform_matrix(base_xf)
	else:
		draw_string(font, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(C_BLACK, col.a))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _pbar(r: Rect2, ratio: float, col: Color) -> void:
	draw_rect(r, C_DARK)
	draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * clampf(ratio, 0.0, 1.0)), r.size.y)), col)
