extends Node2D
## ドット絵版。640x360 で描いて、2倍に拡大して表示する。
## 操作: W/↑ 登る  A/D 揺らす  Space 叫ぶ  R やり直し  N 新コース  F1 調整

const ThreadModel = preload("res://thread_model.gd")

const W := 640.0
const H := 360.0
const FIELD_W := 616.0       # 遊ぶ画面の幅（右端の細い高度バー以外ぜんぶ）
const THREAD_X := 308.0      # 揺れの中心
const PLAYER_SY := 236.0     # カンダタを置く高さ
const PPM := 4.2             # 1m あたりのドット
const XS := 0.85              # モデルの横位置（px@1280）→ 画面ドット
const GHOST_GAP := 14.0
const SC := 3                # キャラと障害物のドット1粒の大きさ（PICO-8 っぽく大きめ）
const MAP_X := 625.0         # 高度マップ（縦の再生バー）
const MAP_TOP := 34.0
const MAP_BOT := 330.0
const PANEL_X := 640.0
const TUNING_PATH := "user://tuning_v2.json"   # 標準から変えた値だけ保存する

# ---- パレット: PICO-8 の16色だけを使う（最後に画面全体もこの16色へ寄せる）
const P_BLACK := Color8(0, 0, 0)
const P_DBLUE := Color8(29, 43, 83)
const P_DPURP := Color8(126, 37, 83)
const P_DGREEN := Color8(0, 135, 81)
const P_BROWN := Color8(171, 82, 54)
const P_DGREY := Color8(95, 87, 79)
const P_LGREY := Color8(194, 195, 199)
const P_WHITE := Color8(255, 241, 232)
const P_RED := Color8(255, 0, 77)
const P_ORANGE := Color8(255, 163, 0)
const P_YELLOW := Color8(255, 236, 39)
const P_GREEN := Color8(0, 228, 54)
const P_BLUE := Color8(41, 173, 255)
const P_LAV := Color8(131, 118, 156)
const P_PINK := Color8(255, 119, 168)
const P_PEACH := Color8(255, 204, 170)
const PICO8 := [P_BLACK, P_DBLUE, P_DPURP, P_DGREEN, P_BROWN, P_DGREY, P_LGREY, P_WHITE,
		P_RED, P_ORANGE, P_YELLOW, P_GREEN, P_BLUE, P_LAV, P_PINK, P_PEACH]

# 役割ごとの色（すべて上の16色）
const C_BLACK := P_BLACK
const C_DARK := P_DBLUE
const C_BLOOD := P_DPURP
const C_RED := P_RED
const C_ORANGE := P_ORANGE
const C_YELLOW := P_YELLOW
const C_GOLD := P_YELLOW
const C_SKIN := P_PEACH
const C_HAIR := P_BLACK
const C_CLOTH := P_BROWN
const C_GHOST := P_LAV
const C_GHOST_D := P_DGREY
const C_WHITE := P_WHITE
const C_GREY := P_LAV
const C_ROCK := P_DGREY
const C_ROCK_D := P_DBLUE
const C_ROCK_L := P_LGREY
const C_GREEN := P_GREEN
const C_CYAN := P_BLUE
const C_PURPLE := P_LAV
const C_SKY_HI := P_BLUE
const C_SKY_LO := P_WHITE
const C_CLOUD := P_WHITE
const C_CLOUD_S := P_LGREY
const C_GRASS := P_GREEN
const C_GRASS_D := P_DGREEN
const C_GRASS_L := P_YELLOW
const C_HILL := P_LAV
const C_HILL_D := P_DGREEN

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
const ONI_PAL := {"r": P_RED, "d": P_DPURP, "y": P_WHITE, "h": P_BLACK,
		"w": P_WHITE, "k": P_BLACK, "t": P_YELLOW, "b": P_BLACK}
const GHOST_HAIR := [P_BLACK, P_DBLUE, P_BROWN, P_DGREY]
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
# 背景の地獄の炎の文様（絵巻の炎をドットで）
const SPR_HELLFLAME := [
	[
		"....f....",
		"...ff....",
		"...fff...",
		"..fff.f..",
		"..ff..ff.",
		".fff..ff.",
		".ff....f.",
		".ff.f..ff",
		"ff..ff.ff",
		"ff.fff.ff",
		".ff.f.ff.",
		"..fffff..",
	],
	[
		".....f...",
		"....ff...",
		"...fff...",
		"..f.fff..",
		".ff..ff..",
		".ff..fff.",
		".f....ff.",
		"ff..f.ff.",
		"ff.ff..ff",
		"ff.fff.ff",
		".ff.f.ff.",
		"..fffff..",
	],
]
# 鬼の投げる岩（2コマで回る）
const SPR_ROCK := [
	[
		"...kkkkk...",
		"..klllddk..",
		".kllldddk..",
		"kllddddddk.",
		"kldddddddk.",
		"kdddddddddk",
		"kddkddddddk",
		".kdddddddk.",
		".kddddkddk.",
		"..kdddddk..",
		"...kkkkk...",
	],
	[
		"...kkkkk...",
		"..kddddlk..",
		".kdddddllk.",
		"kddddddlllk",
		"kdkdddddddk",
		"kdddddddddk",
		"kdddddddkdk",
		".kdddddddk.",
		".kddkddddk.",
		"..kdddddk..",
		"...kkkkk...",
	],
]
const ROCK_PAL := {"k": P_BLACK, "d": P_DGREY, "l": P_LGREY}
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
var difficulty := 1              # 0 やさしい / 1 ふつう / 2 むずかしい
const DIFF_PATH := "user://difficulty.txt"
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
var stomp_fx := 0.0              # 叫びの衝撃波（残り時間）
const BLAST_TIME := 0.5
var blast_at := Vector2.ZERO     # 衝撃波の中心（x: モデルpx, y: 高さ m）
var blast_px := 0.0              # 衝撃波の半径（画面px）
const C_SILK := P_LGREY   # 蜘蛛の糸の色
var ring_nope := 0.0
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
var panel_open := false
var panel_sel := 0
var draw_off := Vector2.ZERO     # 画面揺れのオフセット（文字の拡大描画で使う）

# 自動プレイ（スクリーンショット・検証用）
var autopilot := false
var bot_climb := false
var bot_shout := false
var bot_swing := 0.0
var bot_dash := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var f := FontFile.new()
	if f.load_dynamic_font("res://fonts/DotGothic16-Regular.ttf") == OK:
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
	_setup_pico8_filter()
	_load_tuning()
	if FileAccess.file_exists(DIFF_PATH):
		difficulty = clampi(int(FileAccess.get_file_as_string(DIFF_PATH)), 0, 2)
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


func _setup_pico8_filter() -> void:
	# いちばん上に全画面の板を置き、描いた絵を PICO-8 の16色へ寄せる
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/pico8.gdshader")
	rect.material = mat
	layer.add_child(rect)
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
	fx_hit = 0.0
	shake = 0.0
	fall_t = 0.0
	phase = Phase.PLAY
	phase_t = 0.0


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
		"pad_dash": [[JOY_AXIS_TRIGGER_LEFT, 1.0], JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER],
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
	match b:
		JOY_BUTTON_START:
			return KEY_SPACE if phase == Phase.TITLE else KEY_F1
		JOY_BUTTON_A:
			if phase == Phase.TITLE:
				return KEY_SPACE
			if phase == Phase.RESULT:
				return KEY_R
		JOY_BUTTON_Y: return KEY_R
		JOY_BUTTON_X: return KEY_N
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
	if k == KEY_F1 or k == KEY_TAB:
		panel_open = true
	elif phase == Phase.TITLE and (k == KEY_SPACE or k == KEY_ENTER):
		_restart()
	elif phase == Phase.TITLE and (k == KEY_LEFT or k == KEY_A or k == KEY_RIGHT or k == KEY_D):
		difficulty = clampi(difficulty + (-1 if (k == KEY_LEFT or k == KEY_A) else 1), 0, 2)
		var f := FileAccess.open(DIFF_PATH, FileAccess.WRITE)
		if f:
			f.store_string(str(difficulty))
		_new_model()
	elif phase == Phase.RESULT and phase_t > 0.9 and (k == KEY_SPACE or k == KEY_ENTER):
		course = randi_range(1, 999)   # 毎回ちがう地獄
		_restart()
	elif k == KEY_R and phase != Phase.TITLE:
		_restart()
	elif k == KEY_N and phase != Phase.TITLE:
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
	t += delta
	if panel_open:
		queue_redraw()
		return
	phase_t += delta
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
		var dash := false   # 全力登りは廃止
		if autopilot:
			climb = bot_climb
			shout = bot_shout
			swing = bot_swing
			dash = bot_dash
			bot_shout = false
		early_t = maxf(0.0, early_t - delta)
		if shout and model.state == ThreadModel.State.CLIMBING and not model.can_shout() and early_t <= 0.0:
			early_t = 0.6
			ring_nope = 0.4   # 踏み台がいないときは、○ゲージが首を振るだけ
		var shouts_before := model.shouts
		var hits_before := model.hits
		var rocks_before := model.rock_hits
		var crushed_before := model.ghosts_crushed
		var burned_before := model.ghosts_burned
		var caught_before := model.caught
		var ghosts_before := int(model.ghosts)
		var x_before := model.x
		var h_before := model.height
		model.step(delta, climb, shout, swing, dash)
		if model.shouts > shouts_before:
			_on_shout(ghosts_before, x_before)
		if prev_state == ThreadModel.State.AIR and model.state == ThreadModel.State.CLIMBING:
			# 上の糸をつかんだ瞬間の火花
			_burst(Vector2(_sx(model.x), _player_sy() - 22.0), 14, [C_YELLOW, C_WHITE], 60.0, 1.0, 0.4, 0.0)
		if model.hits > hits_before:
			_burst(Vector2(_sx(model.x), _player_sy()), 30, [C_ORANGE, C_YELLOW, C_RED], 110.0, 2.0, 0.6, 60.0)
			fx_hit = 0.5
			shake = 0.9
		if model.rock_hits > rocks_before:
			_burst(Vector2(_sx(model.x), _player_sy() - 10.0), 22, [C_ROCK, C_ROCK_L, C_ROCK_D], 120.0, 2.0, 0.8, 300.0)
			_burst(Vector2(_sx(model.x), _player_sy() - 10.0), 12, [Color(C_GREY, 0.6)], 40.0, 3.0, 0.7, -20.0)
			fx_hit = 0.5
			shake = 0.9
		if model.caught > caught_before:
			_burst(Vector2(_sx(model.x), _player_sy() + 40.0), 14, [Color(C_GREY, 0.7), Color(C_CLIFF_L, 0.8)], 50.0, 2.0, 0.5, 40.0)
			shake = maxf(shake, 0.4)
		if model.ghosts_crushed > crushed_before:
			var n := model.ghosts_crushed - crushed_before
			_drop_ghosts(n, model.height - 3.0, model.x)
		if model.ghosts_burned > burned_before:   # 業火に焼かれた罪人
			_burst(Vector2(_sx(model.x), _sy(model.lava_h)), 18, [C_YELLOW, C_ORANGE, C_RED], 70.0, 2.0, 0.6, -60.0)
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
			if model.state == ThreadModel.State.TORN:
				new_record = int(model.height) > best[difficulty]
				if new_record:
					best[difficulty] = int(model.height)
					_save_records()
				_burst(Vector2(_sx(model.x), _player_sy()), 60, [C_RED, C_BLOOD, C_ORANGE], 140.0, 2.0, 1.0, 120.0)
				shake = 1.0
				falling_thread.append([h_before, model.x, 0.0])
				_drop_ghosts(int(model.ghosts), model.height, model.x)
			phase = Phase.RESULT
			phase_t = 0.0

	if phase == Phase.RESULT and model.state == ThreadModel.State.TORN:
		fall_t += delta

	# カメラ: 跳んでいる間は着地点へ先回りして、上の景色を先に見せる
	var cam_target: float = model.air_to if model.state == ThreadModel.State.AIR else model.height
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
		f[1].y += 550.0 * delta
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
					lst.append({"t": float(e["t"]), "d": str(e.get("d", ""))})
			ranking[k] = lst


func _add_ranking(sec: float) -> void:
	# クリアタイムを上位10件に入れる。速い順。同タイムは先に出した方が上
	var dd := Time.get_date_dict_from_system()
	var entry := {"t": snappedf(sec, 0.01), "d": "%02d/%02d" % [dd.month, dd.day]}
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
	_burst(sp, 20 + big * 10, [C_YELLOW, C_WHITE, C_ORANGE], 90.0 + big * 20.0, 2.0, 0.7, 0.0)   # 叫びの火花
	# 衝撃波で消し飛んだ岩と鬼火
	for b in model.last_blast:
		var bp := Vector2(_sx(b.x), _sy(b.h))
		if b.type == "fire":
			_burst(bp, 24, [C_YELLOW, C_ORANGE, C_WHITE], 120.0, 2.0, 0.6, -30.0)
		else:
			_burst(bp, 20, [C_ROCK, C_ROCK_L, C_ROCK_D], 150.0, 3.0, 0.7, 250.0)
	fx_shout = 0.9
	shout_text = SHOUT_LINES[randi() % SHOUT_LINES.size()]
	shake = minf(1.4, 0.5 + 0.12 * model.last_stones)   # 大勢を踏み台にするほど揺れる
	if model.last_stones >= 5:
		_burst(sp, 40, [C_WHITE, C_CYAN], 220.0, 3.0, 0.9, 0.0)   # 大跳躍の衝撃波
	if model.last_clutch:
		shake = 1.5
		_burst(sp, 60, [C_GOLD, C_YELLOW, C_WHITE], 200.0, 3.0, 1.1, -20.0)
		popups.append(["九死に一生！", model.air_from + 16.0, from_x - 80.0, 0.0, C_GOLD])
	falling_thread.append([model.air_from, from_x, 0.0])
	_drop_ghosts(n_ghosts, model.air_from, from_x, true)
	stomp_fx = BLAST_TIME
	blast_at = Vector2(from_x, model.air_from)
	blast_px = model.blast_r


func _drop_ghosts(n_ghosts: int, from_h: float, from_x: float, kicked := false) -> void:
	# kicked: 踏み台にされて真下へ蹴り落とされる（叫んだとき）
	var py := _sy(from_h)
	for i in range(n_ghosts):
		var gy := py + 66.0 + i * GHOST_GAP
		if gy > H + 20.0:
			break
		var v := Vector2(randf_range(-110, 110), randf_range(-130, -30))
		if kicked:
			v = Vector2(randf_range(-40, 40), randf_range(160, 260))
		falling_ghosts.append([Vector2(_gx(from_x, i) + (8.0 if i % 2 == 0 else -8.0), gy), v, 0.0, i])


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
		var snap := model.time_to_snap(true, model.dashing)
		if snap < 2.5 and randf() < (0.9 if snap < 1.2 else 0.4):
			_part(Vector2(px + randf_range(-2, 2), py - 20.0 - randf() * 20.0), Vector2(randf_range(-40, 40), randf_range(-20, 20)),
					0.6, Color(C_WHITE, 0.8), 1.0, 40.0, 1.0)
	# 蹴落とされた罪人の赤い尾
	# 業火の火の粉
	var lt := _sy(model.lava_h)
	if lt < H + 4.0 and model.lava_h >= 0.0:
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
		y += roundf(fall_t * fall_t * 450.0)
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
	if model.elapsed < 4.0 and model.height < 3.0:
		_tip("climb", "W / ↑ で登る　A / D で糸を揺らす", "左スティックで登る・揺らす")
	if not model.incoming_sinners().is_empty():
		_tip("sinner", "罪人が飛びつく。つかまらせれば踏み台になる")
	if model.can_shout():
		_tip("shout", "SPACEで叫べ！ 踏み台を蹴って跳ぶ", "×で叫べ！ 踏み台を蹴って跳ぶ")
	if model.stepping_stones() >= 2:
		_tip("hoard", "溜めるほど高く跳ぶ。ただし重いと糸が切れる")
	for rk in model.rocks:
		if rk.state == 0 and _sy(rk.h) > 0.0:
			_tip("oni", "鬼が岩を投げる。赤い点線をよけろ（止まるのも手）")
	for o in model.obstacles:
		var dh: float = model.fire_pos(o).y - model.height
		if dh > 0.0 and dh < 14.0:
			_tip("fire", "鬼火は糸を揺らしてかわせ")
	if model.height - model.lava_h < 35.0 and model.elapsed > 3.0:
		_tip("lava", "下から業火が迫る！ 溜めて大きく跳べ")
	if model.is_clutch() and model.can_shout():
		_tip("clutch", "切れる寸前の叫びは、九死に一生の大跳躍！")
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
	var snap := model.time_to_snap(true, model.dashing)
	if model.is_clutch() and model.can_shout():
		return ["九死に一生！ 今叫べば×%s" % _fmt(model.cfg.clutch_mult), C_GOLD]
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
		if phase_t > 1.8:
			_draw_result()
	else:
		draw_set_transform(draw_off)
		_draw_world()
		draw_off = Vector2.ZERO
		draw_set_transform(Vector2.ZERO)
		if fx_hit > 0.0 and fmod(t, 0.1) < 0.05:
			draw_rect(Rect2(0, 0, FIELD_W, H), Color(C_RED, 0.25))
		if phase != Phase.TITLE:
			_draw_map()
			_draw_hud()
		if phase == Phase.TITLE:
			_draw_title()
		elif phase == Phase.RESULT and phase_t > 0.9:
			_draw_result()
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
	# 空の帯: 下のマグマに照らされて、下ほど赤紫、上ほど暗い。境目は1行おきの横線で（PICO-8 風）
	var r := clampf(cam_h / ThreadModel.GOAL, 0.0, 1.0)
	var bands: Array = [P_BLACK, P_DBLUE, P_DPURP, P_RED] if r < 0.75 else [P_DBLUE, P_DBLUE, P_LAV, P_BLUE]
	var edges := [0.0, 0.28, 0.62, 0.9]     # 各色の始まり（画面の高さの割合）
	for bi in range(bands.size()):
		var y0: float = H * edges[bi]
		var y1: float = H * (edges[bi + 1] if bi + 1 < edges.size() else 1.0)
		draw_rect(Rect2(0, y0, FIELD_W, y1 - y0), bands[bi])
		if bi > 0:   # 境目: 前の色の横線を1行おきに残す
			for k in range(4):
				draw_rect(Rect2(0, y0 + k * 4.0, FIELD_W, 2 if k < 2 else 1), bands[bi - 1])
	# 遠くの岩の塔（シルエット、ゆっくり流れる）。てっぺんで炎がゆれる
	var scroll := cam_h * PPM * 0.25
	var seg := 90.0
	var first := floori(scroll / seg) - 1
	for n in range(first, first + int(H / seg) + 3):
		var hsh := absi(n * 7919) % 97
		var sx := float(hsh * 37 % int(FIELD_W - 120)) + 60.0
		var base_y := H - (float(n) * seg - scroll) - 40.0
		var tall := 60.0 + float(hsh % 5) * 18.0
		var wid := 18.0 + float(hsh % 3) * 8.0
		var tip := Vector2(roundf(sx), roundf(base_y - tall))
		draw_colored_polygon(PackedVector2Array([Vector2(sx - wid, base_y + 30), Vector2(sx - wid * 0.4, base_y - tall * 0.6),
				tip, Vector2(sx + wid * 0.4, base_y - tall * 0.5), Vector2(sx + wid, base_y + 30)]), P_BLACK)
		if hsh % 3 == 0:
			_spr(SPR_FIRE[int(t * 6.0 + n) % 2], tip + Vector2(0, -8), {"y": P_YELLOW, "o": P_ORANGE, "w": P_RED}, false, 2)
	# 舞い上がる火の粉
	for i in range(18):
		var ex := fmod(i * 53.0 + sin(t + i) * 6.0, FIELD_W)
		var ey := fmod(i * 71.0 - t * (12.0 + i % 5 * 4.0) + cam_h * PPM * 0.3, H)
		if ey < 0:
			ey += H
		draw_rect(Rect2(roundf(ex), roundf(ey), 2, 2), P_ORANGE if i % 3 else P_RED)
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
	var ground_y := _sy(0.0) + 24.0
	if ground_y < H:
		draw_rect(Rect2(0, ground_y, FIELD_W, H - ground_y), P_DPURP)
		draw_rect(Rect2(0, ground_y, FIELD_W, 3), P_PINK)
		for i in range(0, int(FIELD_W), 6):   # でこぼこの地表
			var bump := float((i * 13) % 4)
			draw_rect(Rect2(i, ground_y - bump, 6, bump), P_DPURP)
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
		var frame := int(t * 8.0 + o.phase) % 2
		_spr(SPR_FIRE[frame], Vector2(_sx(fp.x), oy), {"y": C_YELLOW, "o": C_ORANGE, "w": C_WHITE}, o.w < 0.0, SC)

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
			var start_x: float = -18.0 - k * 21.0 if left else FIELD_W + 18.0 + k * 21.0
			var end_x: float = lip - 9.0 - k * 18.0 if left else lip + 9.0 + k * 18.0
			var sx0 := lerpf(start_x, end_x, run_k)
			var running := run_k < 1.0
			var frame: int = int(t * 10.0 + k) % 2 if running else 0
			var spr: Array = SPR_GHOST_RUN if frame == 1 else SPR_GHOST
			var bob: float = 0.0 if running else roundf(absf(sin(t * 6.0 + i + k)) * 2.0)
			_spr(spr, Vector2(roundf(sx0), py0 - 19.0 - bob), _ghost_pal(i * 3 + k), left, SC)

	# 飛びかかる罪人（外れたらそのまま落ちる）
	for j in model.jumpers:
		if j.state == 1:
			continue
		var left2: bool = j.side < 0.0
		var p0 := Vector2(cliff_l if left2 else cliff_r, _sy(j.h0) - 19.0)
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
		_spr(spr3, pos.round(), _ghost_pal(int(j.h0)), not left2, SC)

	# 崖の鬼と、投げられた岩
	var rr := ThreadModel.ROCK_R * XS
	for rk in model.rocks:
		var left3: bool = rk.side < 0.0
		var tau: float = model.rock_tau(rk)
		var hand0: Vector2 = model.rock_pos(rk, -1.0)
		var hx := _sx(hand0.x)
		var hy := _sy(hand0.y)
		var oni_c := Vector2(hx - rk.side * 10.0, hy + 45.0)
		var feet := oni_c.y + 23.0
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
			var off := roundf((1.0 - rise + sink) * 27.0)
			# 岩棚より下にはみ出さないように切り取る代わりに、岩棚の色で隠す
			var spr2: Array = SPR_ONI_UP if tau <= 0.0 else SPR_ONI_THROW
			_spr(spr2, oni_c + Vector2(0, off), ONI_PAL, not left3, SC)
			if off > 0.0:   # 岩棚の下に隠れている部分を、崖の色で覆う
				draw_rect(Rect2(oni_c.x - 20.0, feet + 1.0, 40, off + 2.0), C_CLIFF)
			draw_rect(Rect2(sx_b, feet, sw2, 4), C_CLIFF_D)
			draw_rect(Rect2(sx_b, feet, sw2, 1), C_CLIFF_L)
		if tau <= 0.0:
			# 振りかぶり中: 頭上の岩と、飛んでいく道筋（赤い点線）
			var shake2 := roundf(sin(t * 50.0) * 1.0)
			var hold := Vector2(hx + shake2, hy + roundf((1.0 - clampf(rk.t / 0.15, 0.0, 1.0)) * 27.0))
			_spr(SPR_ROCK[0], hold, ROCK_PAL, false, 4)
			var pulse := 0.55 + 0.45 * absf(sin(t * 10.0))
			var k3 := 0.0
			var f: float = model.cfg.rock_flight
			while k3 < f * 1.8:
				var pp: Vector2 = model.rock_pos(rk, k3)
				var dpos := Vector2(_sx(pp.x), _sy(pp.y)).round()
				if pulse > 0.4 or int(k3 / 0.06) % 2 == 0:   # 点滅は 16色のまま（半透明にしない）
					draw_rect(Rect2(dpos.x - 1, dpos.y - 1, 3, 3), P_BLACK)
					draw_rect(Rect2(dpos.x, dpos.y, 2, 2), P_RED if pulse > 0.75 else P_PINK)
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
		# 飛んでくる岩: 2コマで回りながら飛ぶ
		var rf := int(tau * 10.0) % 2
		_spr(SPR_ROCK[rf], Vector2(rkx, rky), ROCK_PAL, rk.side > 0.0, 4)

	# 糸（上側）: 天から手元へ
	var py := _player_sy()
	var px := _sx(model.x)
	var hand := Vector2(px, py - 22.0)
	var thread_top := Vector2(THREAD_X, maxf(goal_y - 52.0, -4.0))   # 蜘蛛から垂れる
	# 糸の色は上下で同じ。傷むほど少しずつ赤みが差し、切れそうになると赤く点滅
	var tc := C_SILK
	if model.state == ThreadModel.State.CLIMBING:
		tc = C_SILK.lerp(C_RED, (1.0 - model.durability / ThreadModel.DURABILITY_MAX) * 0.7)
		if model.time_to_snap(true, false) < 1.3 and fmod(t, 0.3) < 0.15:
			tc = C_RED
	draw_line(thread_top, hand, tc, 2.0)

	# 糸（下側）と罪人と、糸の耐久度の○ゲージ
	if model.state == ThreadModel.State.CLIMBING:
		var snap := model.time_to_snap(true, model.dashing)
		# 下に余っている糸は、切った所（下端）まで。登るほど伸びていく
		var end_y := minf(_sy(model.thread_end) - 22.0, H + 20.0)
		var pts := PackedVector2Array([hand])
		var i := 0.0
		while py + 27.0 + i * GHOST_GAP < end_y:
			pts.append(Vector2(_gx(model.x, i), py + 27.0 + i * GHOST_GAP))
			i += 1.0
		if end_y > hand.y and end_y < H:
			var last: Vector2 = pts[pts.size() - 1]
			var tip := Vector2(_gx(model.x, maxf(i - 1.0, 0.0)), end_y)
			if end_y < last.y:
				tip = last.lerp(Vector2(last.x, end_y), 1.0)
			pts.append(tip)
			if pts.size() >= 2:
				draw_polyline(pts, tc, 2.0)
			# ちぎれた端のほつれ
			draw_rect(Rect2(tip.x - 1, tip.y, 1, 2), Color(tc, 0.7))
			draw_rect(Rect2(tip.x + 1, tip.y + 1, 1, 2), Color(tc, 0.7))
		else:
			if pts.size() >= 2:
				draw_polyline(pts, tc, 2.0)
		for g in range(int(model.ghosts)):
			var gy := py + 66.0 + g * GHOST_GAP
			if gy > H + 10.0:
				break
			var side := g % 2 == 0
			_spr(SPR_GHOST, Vector2(_gx(model.x, g + 3) + (12.0 if side else -12.0), gy), _ghost_pal(g), not side, SC)
		# ○ゲージは頭の上、天へ伸びる糸の上に付ける
		var top_pt := thread_top
		var ring_c := (hand + (top_pt - hand).normalized() * 26.0).round()
		_draw_ring(ring_c, snap)

	# ちぎれて落ちていく糸
	for th in falling_thread:
		var age: float = th[2]
		var ty: float = _sy(th[0]) + roundf(age * age * 450.0)
		var tx: float = _sx(th[1])
		draw_line(Vector2(tx, ty), Vector2(tx + roundf(5.0 * age), ty + 350.0), Color(C_RED, maxf(0.0, 1.0 - age * 0.6)), 1.0)
	for f in falling_ghosts:   # 落ちていく罪人（手足をばたつかせて、そのまま落下）
		var fr: int = int(f[2] * 1.5) % 2
		var fp: Vector2 = f[0]
		_spr(SPR_GHOST_RUN if fr == 1 else SPR_GHOST, fp.round(), _ghost_pal(int(f[3]) if f.size() > 3 else 0), fr == 1, SC)

	# カンダタ
	if not (model.invuln_left > 0.0 and fmod(t, 0.16) < 0.08):
		_draw_kandata(Vector2(px, py))

	# 叫びの衝撃波: 円が一気に広がって、中の障害を消し飛ばす
	if stomp_fx > 0.0:
		var bc := Vector2(_sx(blast_at.x), _sy(blast_at.y))
		var bk := 1.0 - stomp_fx / BLAST_TIME              # 0→1
		var grow := 1.0 - pow(1.0 - minf(bk / 0.45, 1.0), 3.0)   # すばやく広がって止まる
		var rr2 := roundf(blast_px * grow)
		var fade := 1.0 - maxf(bk - 0.45, 0.0) / 0.55
		draw_circle(bc, rr2, Color(C_WHITE, 0.18 * fade))
		draw_arc(bc, rr2, 0, TAU, 48, Color(C_YELLOW, fade), 3.0)
		draw_arc(bc, maxf(rr2 - 6.0, 0.0), 0, TAU, 48, Color(C_WHITE, 0.6 * fade), 1.0)
		for k in range(16):   # 放射状の線
			var ang := TAU * k / 16.0 + 0.2
			var r0 := rr2 * 0.55
			draw_line(bc + Vector2(cos(ang), sin(ang)) * r0, bc + Vector2(cos(ang), sin(ang)) * rr2, Color(C_WHITE, 0.5 * fade), 1.0)

	# 叫び演出
	if fx_shout > 0.0:
		var c := Vector2(_sx(falling_thread[-1][1]) if not falling_thread.is_empty() else px, _sy(model.air_from))
		var sw := font.get_string_size(shout_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 2.0
		var sx := minf(c.x + 18.0, FIELD_W - sw - 6.0)   # 画面の右端からはみ出さないように
		_label(Vector2(sx, c.y - 4.0), shout_text, 32, Color(C_YELLOW, minf(1.0, fx_shout * 2)))
	for p in popups:
		var a: float = 1.0 - p[3] / 1.2
		var pc: Color = p[4]
		_label(Vector2(_sx(p[2]) + 12, _sy(p[1]) - roundf(p[3] * 20.0)), p[0], 16, Color(pc, a))

	_draw_lava()
	_draw_particles()
	_draw_heat_edge()

	# 案内: 初めてその場面になったときだけ、下にそっと出る
	if phase == Phase.PLAY and tip_text != "":
		var ta := clampf(minf(tip_t / 0.25, (TIP_TIME - tip_t) / 0.4), 0.0, 1.0)
		var tw2 := font.get_string_size(tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var tx := roundf(FIELD_W * 0.5 - tw2 * 0.5)
		draw_rect(Rect2(tx - 8, H - 26, tw2 + 16, 20), Color(C_BLACK, 0.65 * ta))
		_label(Vector2(tx, H - 10), tip_text, 16, Color(C_WHITE, ta))


const C_CLIFF := P_DBLUE
const C_CLIFF_D := P_DGREY
const C_CLIFF_L := P_LGREY


func _draw_lava() -> void:
	# 下から迫るマグマ。地面より下にいるうちは、地面の割れ目から光が漏れるだけ
	var top := _sy(model.lava_h)
	var ground_y := _sy(0.0) + 24.0
	if model.lava_h < 0.0:
		if ground_y < H:
			var glow := clampf(1.0 - (-model.lava_h) / 40.0, 0.0, 1.0)
			for i in range(0, int(FIELD_W), 23):
				var cy := ground_y + 6.0 + float((i * 7) % 20)
				if cy < H:
					draw_rect(Rect2(i, cy, 8 + (i % 3) * 3, 1), Color(C_ORANGE, 0.25 + 0.6 * glow * (0.6 + 0.4 * sin(t * 4.0 + i))))
		return
	if top > H + 8.0:
		return
	# 熱気: 上へ行くほど薄くなる橙の層（ゆらゆら）
	for i in range(10):
		var hy := top - 4.0 - i * 5.0
		draw_rect(Rect2(0, hy + roundf(sin(t * 2.0 + i) * 1.0), FIELD_W, 5), Color(C_ORANGE, 0.16 - i * 0.015))
	# 本体: 深いところほど暗い赤
	var depth_cols := [P_RED, P_RED, P_DPURP, P_DPURP, P_DBLUE]
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
		draw_rect(Rect2(roundf(cx), roundf(cy2), cw, 3), P_DPURP)
		draw_rect(Rect2(roundf(cx + cw * 0.4), roundf(cy2 + 1.0), 3, 1), C_ORANGE)
	# 泡: ふくらんで、はじける
	for k in range(7):
		var bx := fmod(k * 89.0 + 23.0 + floorf(t * 0.6 + k * 0.31) * 137.0, FIELD_W)
		var ph := fmod(t * 0.6 + k * 0.31, 1.0)
		if ph < 0.35:
			var rr := 1.0 + ph * 14.0
			draw_arc(Vector2(bx, top + 2.0), rr, PI, TAU, 10, C_YELLOW, 1.0)
			draw_circle(Vector2(bx, top + 3.0), rr - 1.0, Color(C_ORANGE, 0.8))


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
			draw_rect(Rect2(x0, yy, w, 2), P_DBLUE)
			# 石積みの目地（世界に固定。段ごとに縦の目地をずらす）
			var wpx := wy * PPM
			var course_i := int(floorf(wpx / 24.0))
			if fmod(wpx, 24.0) < 3.0:
				draw_rect(Rect2(x0, yy, w, 2), P_BLACK)
			else:
				var jx := 16.0 if course_i % 2 == 0 else 0.0
				var gx2 := jx
				while gx2 < w:
					var bxx: float = (x0 + gx2) if left else (ex + gx2)
					draw_rect(Rect2(bxx, yy, 3, 2), P_BLACK)
					if (course_i * 3 + int(gx2 / 32.0) * 5) % 7 == 0:   # ところどころ紫の石
						draw_rect(Rect2(bxx + 3.0, yy, minf(29.0, w - gx2 - 3.0), 2), P_DPURP)
					gx2 += 32.0
			# 縁: 岩肌の明るい面と、輪郭
			draw_rect(Rect2(ex - 3.0 if left else ex, yy, 3, 2), P_LAV)
			draw_rect(Rect2(ex - 3.0 if left else ex + 2.0, yy, 1, 2), P_WHITE if band == 0 else P_LAV)
			yy += 2.0
		# ひび割れ（世界に固定）
		var m0 := floori(cam_h - 70.0)
		for k in range(m0, m0 + 140, 7):
			var cy := _sy(float(k))
			var cx: float = (8.0 + float((k * 37) % 50)) if left else (FIELD_W - 10.0 - float((k * 41) % 50))
			draw_rect(Rect2(cx, cy, 6, 2), P_BLACK)


func _draw_needle_mountains() -> void:
	# 針の山: とがった山の影に、白い針がびっしり立つ。登るほど下へ遠ざかる
	var base := PLAYER_SY + 40.0 + cam_h * PPM * 0.3
	if base - 160.0 > H:
		return
	for layer in range(2):
		var far := layer == 0
		var col := P_DBLUE if far else P_DPURP
		var needle := P_LAV if far else P_WHITE
		var lb := base + (0.0 if far else 34.0)
		var peaks := 7 if far else 9
		var span := FIELD_W / peaks
		for k in range(peaks + 1):
			var px := k * span + (span * 0.5 if far else 0.0) - span * 0.5
			var ph := (90.0 if far else 60.0) + float((k * 37 + layer * 11) % 5) * 12.0
			var tip := Vector2(roundf(px + span * 0.5), roundf(lb - ph))
			draw_colored_polygon(PackedVector2Array([Vector2(px, lb + 200.0), tip, Vector2(px + span, lb + 200.0)]), col)
			# 斜面に沿って針を立てる
			var steps := int(ph / 6.0)
			for st in range(1, steps):
				var f := float(st) / steps
				var ly := roundf(lerpf(tip.y, lb, f))
				var half := span * 0.5 * f
				var nl := 3.0 + float((st * 7 + k) % 4)
				draw_rect(Rect2(roundf(tip.x - half), ly - nl, 1, nl), needle)
				draw_rect(Rect2(roundf(tip.x + half), ly - nl, 1, nl), needle)
			draw_rect(Rect2(tip.x, tip.y - 6.0, 1, 6), needle)


func _draw_goal(goal_y: float) -> void:
	# 極楽への入り口 = 極楽の蓮池の底。岩の天井の穴から見上げると、澄んだ水と蓮の葉の影、
	# その向こうの光が見える（原作では、お釈迦様が蓮池の水越しに地獄をのぞいて糸を下ろす）
	var ceil_top := goal_y - 46.0
	var ceil_bot := goal_y - 6.0
	var surf := goal_y - 150.0          # 池の水面（下から見上げた面）
	if surf > -400.0:
		draw_rect(Rect2(0, -400, FIELD_W, surf + 400.0), P_WHITE)       # 水面の向こう: 極楽の光
		draw_rect(Rect2(0, surf - 10.0, FIELD_W, 10), P_PEACH)
	# 水: 水面に近いほど明るい青、天井に近いほど深い藍
	var yy := surf
	while yy < ceil_bot:
		var k := clampf((yy - surf) / (ceil_bot - surf), 0.0, 1.0)
		draw_rect(Rect2(0, yy, FIELD_W, 4), P_BLUE if k < 0.4 else P_DBLUE)
		yy += 4.0
	# 水面のゆらめき
	var x := 0.0
	while x < FIELD_W:
		var wy := roundf(surf + sin(x * 0.09 + t * 2.0) * 1.5)
		draw_rect(Rect2(x, wy, 2, 2), P_WHITE)
		x += 2.0
	# 水の中の光の網（コースティクス）
	for i in range(18):
		var cx := fmod(i * 67.0 + t * (6.0 + i % 4 * 3.0), FIELD_W + 40.0) - 20.0
		var cy := surf + 8.0 + float((i * 29) % int(maxf(ceil_top - surf - 16.0, 8.0)))
		var near := (cy - surf) / maxf(ceil_top - surf, 1.0) < 0.45
		draw_rect(Rect2(roundf(cx), roundf(cy + sin(t * 2.0 + i) * 2.0), 6 + i % 3 * 3, 1), P_WHITE if near else P_BLUE)
	# 蓮の葉（下から見ると黒い影）と、水中へ垂れる茎
	var leaves := [40.0, 120.0, 210.0, 400.0, 480.0, 570.0]
	for i in range(leaves.size()):
		var lx: float = leaves[i] + sin(t * 0.6 + i) * 3.0
		var lw := 22.0 + float(i % 3) * 6.0
		for row in range(4):
			var hw := roundf(lw * sqrt(1.0 - pow((row - 1.5) / 2.0, 2.0)))
			draw_rect(Rect2(roundf(lx - hw), surf + 1.0 + row, hw * 2.0, 1), P_DGREEN)
		draw_rect(Rect2(roundf(lx), surf + 5.0, 1, 30.0 + float(i % 3) * 18.0), P_DGREEN)
	# 水面の上に咲く白い蓮
	for i in range(3):
		var fx: float = [160.0, 440.0, 540.0][i]
		_spr(SPR_LOTUS_FLOWER, Vector2(fx, surf - 9.0), {"p": P_LGREY, "P": P_WHITE, "y": P_YELLOW, "g": P_DGREEN}, false, SC)
	# 穴から差し込む光の筋（細い縦線を間引いて、ドットらしく）
	for k in range(-9, 10):
		var x0 := THREAD_X + k * 5.0
		var len := 140.0 - absf(k) * 6.0 + sin(t * 2.0 + k) * 12.0
		var spread_x := k * 2.5
		var step := 0.0
		while step < len:
			var f := step / len
			if int(step / 2.0) % (2 if f < 0.5 else 3) == 0:
				draw_rect(Rect2(roundf(x0 + spread_x * f * 4.0), ceil_bot + step, 1, 2), P_BLUE if f < 0.6 else P_DBLUE.lerp(P_BLUE, 1.0 - f))
			step += 2.0
	# 岩の天井（穴は下ほど広い）
	yy = ceil_top
	while yy < ceil_bot:
		var k := (yy - ceil_top) / (ceil_bot - ceil_top)
		var hw := roundf(46.0 + 20.0 * k + sin(yy * 0.7) * 3.0)
		var col: Color = P_BLACK if k < 0.5 else P_DBLUE
		draw_rect(Rect2(0, yy, THREAD_X - hw, 2), col)
		draw_rect(Rect2(THREAD_X + hw, yy, FIELD_W - THREAD_X - hw, 2), col)
		draw_rect(Rect2(THREAD_X - hw - 2.0, yy, 2, 2), P_LAV)   # 穴のふち
		draw_rect(Rect2(THREAD_X + hw, yy, 2, 2), P_LAV)
		yy += 2.0
	draw_rect(Rect2(0, ceil_top - 2, FIELD_W, 2), P_DGREY)
	for i in range(0, int(FIELD_W), 8):   # 天井の下側のギザギザ
		if absf(i + 4.0 - THREAD_X) < 70.0:
			continue
		var dh := 2.0 + float((i * 7) % 5) * 2.0
		draw_rect(Rect2(i, ceil_bot, 8, dh), P_DBLUE)
		draw_rect(Rect2(i + 2, ceil_bot + dh, 4, 2), P_BLACK)
	# 蜘蛛と、水面へ続く糸
	var spy := goal_y - 61.0 + roundf(sin(t * 2.0))
	draw_rect(Rect2(THREAD_X, surf, 1, spy - surf), P_LGREY)
	_spr(SPR_SPIDER, Vector2(THREAD_X, spy), {"l": P_WHITE, "b": P_DGREY, "e": P_RED}, false, SC)


func _draw_meadow() -> void:
	# 極楽: 青空、流れる雲、遠くの丘、風に揺れる草原
	var horizon := 214.0
	# 朝の空: 上は青、地平線に近づくほど白い横線が増えていく（PICO-8 の網かけ風）
	draw_rect(Rect2(0, 0, W, horizon), P_BLUE)
	var sy := horizon - 90.0
	while sy < horizon:
		var f := (sy - (horizon - 90.0)) / 90.0
		var every := 4 if f < 0.35 else (2 if f < 0.7 else 1)
		if int((sy - (horizon - 90.0)) / 2.0) % every == 0:
			draw_rect(Rect2(0, sy, W, 1), P_WHITE if f > 0.5 else P_LGREY)
		sy += 2.0
	# 太陽
	var sun := Vector2(540, 56)
	draw_circle(sun, 26.0, Color(P_YELLOW, 0.3))
	draw_circle(sun, 18.0, P_WHITE)
	for k in range(8):
		var a := TAU * k / 8.0 + t * 0.2
		var p0 := sun + Vector2(cos(a), sin(a)) * 32.0
		draw_rect(Rect2(roundf(p0.x) - 1, roundf(p0.y) - 1, 3, 3), P_YELLOW)
	# 流れる雲
	for i in range(5):
		var cx := fmod(i * 170.0 + t * (8.0 + i * 3.0), W + 120.0) - 60.0
		var cy := 40.0 + float(i % 3) * 38.0
		_spr(SPR_CLOUD, Vector2(roundf(cx), cy), {"w": C_CLOUD, "s": C_CLOUD_S}, i % 2 == 1)
	# 鳥
	for i in range(3):
		var bx := fmod(t * 30.0 + i * 90.0, W + 60.0) - 30.0
		var by := 90.0 + i * 14.0 + roundf(sin(t * 3.0 + i) * 3.0)
		_spr(SPR_BIRD, Vector2(roundf(bx), by), {"b": P_DBLUE}, false, 1)
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
		var fc: Color = [P_WHITE, P_YELLOW, P_PINK][i % 3]
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
		draw_rect(Rect2(roundf(px), roundf(py), 2, 1), P_PINK)

	# 蓮池: 池の底から地獄へ糸が垂れている（原作どおり）
	var pond := Vector2(300, 298)
	var prx := 170.0
	var pry := 42.0
	for row in range(int(-pry) - 3, int(pry) + 3):
		var f := 1.0 - pow(row / (pry + 3.0), 2.0)
		if f <= 0.0:
			continue
		var hw := roundf((prx + 6.0) * sqrt(f))
		draw_rect(Rect2(pond.x - hw, pond.y + row, hw * 2, 1), P_DGREEN)   # 岸
	for row in range(int(-pry), int(pry)):
		var hw := roundf(prx * sqrt(1.0 - pow(row / pry, 2.0)))
		var wc := P_BLUE.lerp(P_DBLUE, (row + pry) / (pry * 2.0) * 0.5)
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
		_spr(SPR_LILY_PAD, pp, {"g": P_DGREEN, "G": P_GREEN})
	var flowers := [Vector2(-130, -14), Vector2(-62, 14), Vector2(72, -26), Vector2(118, 8), Vector2(150, -12), Vector2(-150, 10)]
	for i in range(flowers.size()):
		var fp: Vector2 = pond + flowers[i] + Vector2(0, roundf(sin(t * 1.2 + i * 2.0) * 1.0))
		_spr(SPR_LOTUS_FLOWER, fp, {"p": P_LGREY, "P": P_WHITE, "y": P_YELLOW, "g": P_DGREEN})   # 玉のように白い蓮

	# 真ん中の大きな蓮の葉と、蜘蛛。糸は葉の脇から池の中へ
	var leaf := pond + Vector2(0, 4)
	_spr(SPR_LILY_PAD, leaf, {"g": P_DGREEN, "G": P_GREEN}, false, 4)
	var sp := leaf + Vector2(30, -8)
	draw_line(sp + Vector2(-6, 4), leaf + Vector2(20, 10), Color(C_GOLD, 0.9), 1.0)
	_spr(SPR_SPIDER, sp + Vector2(0, roundf(sin(t * 2.0))), {"l": P_BLACK, "b": P_DGREY, "e": P_RED})

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
	_spr(SPR_BUDDHA, bud, {"h": P_DBLUE, "s": P_YELLOW, "k": P_BROWN,
			"m": P_ORANGE, "w": P_WHITE, "r": P_ORANGE, "R": P_BROWN}, false, 3)
	_draw_particles()
	_spr(SPR_PEDESTAL, bud + Vector2(0, 38), {"p": P_PINK, "P": P_PEACH, "g": P_DGREEN}, false, 3)


func _draw_ring(c: Vector2, snap: float) -> void:
	# 糸の耐久度を、糸に付いた○ゲージで表す
	var r := model.durability / ThreadModel.DURABILITY_MAX
	var col := C_GREEN
	if snap < 3.0:
		col = C_YELLOW
	if snap < 1.3:
		col = C_RED
	draw_circle(c, 9.0, C_BLACK)
	draw_arc(c, 6.0, 0, TAU, 24, Color(C_WHITE, 0.2), 3.0)
	if r > 0.0:
		draw_arc(c, 6.0, -PI * 0.5, -PI * 0.5 + TAU * r, 24, col, 3.0)
	if ring_nope > 0.0:   # 踏み台がいないのに叫んだ: ○が左右に震える
		c.x += roundf(sin(ring_nope * 60.0) * 2.0)
	if snap < 1.5:   # 切れそう: 赤く脈打つ
		col = C_RED if fmod(t, 0.3) < 0.18 else C_YELLOW
		draw_arc(c, 11.0 + roundf(absf(sin(t * 12.0)) * 2.0), 0, TAU, 24, col, 1.0)
		if model.can_shout():
			_label(Vector2(c.x + 14, c.y + 6), "叫べ！", 16, col)


func _ghost_pal(i: int) -> Dictionary:
	# カンダタと同じ肌・黒い目・赤い口。肌の濃淡、髪、腰布の色だけ一人ずつ変える
	var skin := C_SKIN
	var cloths := [P_DGREY, P_BROWN, P_LAV, P_DPURP]
	return {"s": skin, "h": GHOST_HAIR[i % GHOST_HAIR.size()], "k": C_BLACK, "m": C_RED,
			"c": cloths[(i * 3) % cloths.size()]}


func _draw_kandata(p: Vector2) -> void:
	var pal := {"s": C_SKIN, "h": C_HAIR, "k": C_BLACK, "m": C_RED, "c": C_CLOTH}
	if model.is_clutch() and model.can_shout() and fmod(t, 0.16) < 0.08:
		pal["s"] = C_GOLD   # 九死に一生の圏内は金色に明滅
	if model.stun_left > 0.0:
		pal["s"] = P_PINK
	var lean := clampf(model.vx * 0.01, -4.0, 4.0)
	if model.state == ThreadModel.State.AIR:
		_spr(SPR_KANDATA_JUMP, Vector2(p.x + roundf(lean), p.y), pal, false, SC)
		return
	if model.state == ThreadModel.State.CLIMBING and climb_moving > 0.0:
		# 手を交互に伸ばす4コマ: 左手上 → 両手 → 右手上 → 両手。伸ばした瞬間に体が持ち上がる
		var fr := int(floorf(climb_phase)) % 4
		var bob := 0.0
		if fr % 2 == 0:
			_spr(SPR_KANDATA_REACH, Vector2(p.x + roundf(lean), p.y + bob), pal, fr == 2, SC)
		else:
			_spr(SPR_KANDATA, Vector2(p.x + roundf(lean), p.y + bob), pal, false, SC)
		return
	_spr(SPR_KANDATA, Vector2(p.x + roundf(lean), p.y), pal, false, SC)


func _draw_map() -> void:
	# 右端の縦バー: 下が地獄、上の蓮が極楽。金=今の高さ、赤=マグマ、水色=叫べば届く高さ、白線=自己ベスト
	draw_rect(Rect2(FIELD_W, 0, W - FIELD_W, H), P_BLACK)
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
	draw_rect(Rect2(bx, MAP_TOP, bw, MAP_BOT - MAP_TOP), P_DBLUE)
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
	# PICO-8 っぽく: 黒地に、登場するものを色とりどりに並べる
	draw_rect(Rect2(0, 0, W, H), P_BLACK)
	var cx := W * 0.5
	# またたく星（火の粉）
	for i in range(40):
		var sx := float((i * 97 + 31) % int(W))
		var sy := float((i * 53 + 17) % int(H))
		var tw := fmod(t * 1.5 + i * 0.37, 1.0)
		if tw < 0.5:
			var sc2: Color = [P_RED, P_ORANGE, P_YELLOW, P_PINK, P_WHITE][i % 5]
			draw_rect(Rect2(sx, sy, 2, 2), sc2)
			if tw < 0.15:   # きらっ
				draw_rect(Rect2(sx - 2, sy, 6, 2), sc2)
				draw_rect(Rect2(sx, sy - 2, 2, 6), sc2)
	draw_line(Vector2(cx, 0), Vector2(cx, 150), P_WHITE, 2.0)   # 糸（文字の後ろ）
	draw_rect(Rect2(cx - 150, 64, 300, 60), P_BLACK)
	_label(Vector2(cx, 92), "パワーカンダタ（仮）", 32, P_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_label(Vector2(cx, 116), "蜘蛛の糸から、極楽へ", 16, P_PINK, HORIZONTAL_ALIGNMENT_CENTER)
	# 蜘蛛と、ぶら下がるカンダタ
	_spr(SPR_SPIDER, Vector2(cx, 132 + roundf(sin(t * 2.0) * 2.0)), {"l": P_WHITE, "b": P_DGREY, "e": P_RED}, false, 2)
	var bob := roundf(sin(t * 3.0) * 2.0)
	_spr(SPR_KANDATA, Vector2(cx, 176 + bob), {"s": C_SKIN, "h": C_HAIR, "k": C_BLACK, "m": C_RED, "c": C_CLOTH}, false, 4)
	# 登場するものたち
	var hop := func(i: int) -> float: return -roundf(absf(sin(t * 4.0 + i)) * 4.0)
	_spr(SPR_ONI_UP, Vector2(cx - 210, 190 + hop.call(0)), ONI_PAL, false, 3)
	_spr(SPR_ROCK[int(t * 4.0) % 2], Vector2(cx - 210, 150 + hop.call(0)), ROCK_PAL, false, 3)
	_spr(SPR_FIRE[int(t * 8.0) % 2], Vector2(cx - 130, 196 + hop.call(1)), {"y": P_YELLOW, "o": P_ORANGE, "w": P_WHITE}, false, 3)
	_spr(SPR_GHOST, Vector2(cx + 120, 192 + hop.call(2)), _ghost_pal(1), true, 3)
	_spr(SPR_GHOST_RUN, Vector2(cx + 165, 192 + hop.call(3)), _ghost_pal(2), true, 3)
	_spr(SPR_LOTUS_FLOWER, Vector2(cx + 225, 196 + hop.call(4)), {"p": P_LGREY, "P": P_WHITE, "y": P_YELLOW, "g": P_DGREEN}, false, 3)
	var dcol: Color = [P_GREEN, P_YELLOW, P_RED][difficulty]
	_label(Vector2(cx, 256), "＜ %s ＞" % ThreadModel.DIFFICULTY_NAMES[difficulty], 16, dcol, HORIZONTAL_ALIGNMENT_CENTER)
	if best_time[difficulty] > 0.0:
		_label(Vector2(cx, 278), "BEST %.1f" % best_time[difficulty], 16, P_LAV, HORIZONTAL_ALIGNMENT_CENTER)
	if fmod(t, 1.0) < 0.6:
		_label(Vector2(cx, 316), "PUSH START", 16, P_WHITE, HORIZONTAL_ALIGNMENT_CENTER)


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
		var a := clampf((phase_t - 1.8) / 0.5, 0.0, 1.0)
		var wx := W * 0.5
		draw_rect(Rect2(wx - 160, 24, 320, 196), Color(C_BLACK, 0.5 * a))
		_label(Vector2(wx, 58), "極楽に到達！", 32, Color(C_YELLOW, a), HORIZONTAL_ALIGNMENT_CENTER)
		_label(Vector2(wx, 82), "TIME %.1f   RANK %s" % [model.elapsed, _rank(model.elapsed)], 16, Color(C_WHITE, a), HORIZONTAL_ALIGNMENT_CENTER)
		# 上位10件（左に1〜5位、右に6〜10位）。今回のタイムは点滅
		_label(Vector2(wx, 106), "― %s ランキング ―" % ThreadModel.DIFFICULTY_NAMES[difficulty], 16, Color(C_GOLD, a), HORIZONTAL_ALIGNMENT_CENTER)
		var lst: Array = ranking[difficulty]
		for i in range(RANKING_SIZE):
			var col_x := wx - 148.0 if i < 5 else wx + 8.0
			var row_y := 130.0 + float(i % 5) * 18.0
			var txt := "%2d  ----.-" % (i + 1)
			var c := Color(C_WHITE, 0.45 * a)
			if i < lst.size():
				txt = "%2d  %6.1f  %s" % [i + 1, float(lst[i]["t"]), lst[i]["d"]]
				c = Color(C_WHITE, 0.9 * a)
			if i == new_rank:
				c = Color(C_YELLOW, a) if fmod(t, 0.4) < 0.28 else Color(C_ORANGE, a)
			_label(Vector2(col_x, row_y), txt, 16, c)
		if fmod(t, 1.0) < 0.6 and a >= 1.0:
			_label(Vector2(wx, 346), "PUSH START", 16, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	draw_rect(Rect2(0, 0, FIELD_W, H), Color(C_BLACK, 0.8))
	var cx := FIELD_W * 0.5
	_label(Vector2(cx, 120), "GAME OVER", 32, C_RED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(Vector2(cx, 172), "%d/%dm" % [int(model.height), int(ThreadModel.GOAL)], 32, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	if new_record:
		if fmod(t, 0.4) < 0.28:
			_label(Vector2(cx, 200), "NEW RECORD!", 16, C_YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_label(Vector2(cx, 200), "HI %dm" % best[difficulty], 16, Color(C_WHITE, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	if fmod(t, 1.0) < 0.6:
		_label(Vector2(cx, 280), "PUSH START", 16, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_panel() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(C_BLACK, 0.8))
	var px := 40.0
	var py := 34.0
	draw_rect(Rect2(px - 16, py - 26, 592, 336), P_BLACK)
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
		draw_set_transform(draw_off, 0.0, Vector2(sc, sc))
		var lp := (p / sc).round()
		draw_string(font, lp + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(C_BLACK, col.a))
		draw_string(font, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		draw_set_transform(draw_off)
	else:
		draw_string(font, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(C_BLACK, col.a))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _pbar(r: Rect2, ratio: float, col: Color) -> void:
	draw_rect(r, C_DARK)
	draw_rect(Rect2(r.position, Vector2(roundf(r.size.x * clampf(ratio, 0.0, 1.0)), r.size.y)), col)
