extends RefCounted
## 蜘蛛の糸プロトタイプ v4 のコアモデル（描画・入力に依存しない純粋なロジック）
## 叫ぶ = しがみつく罪人を全員踏み台にして蹴り落とし、その反動で跳んで上の糸をつかみ直す。
## ジャンプの高さ = 基本 + 蹴落とした人数 × 1人あたり。
## 左右に糸を揺らして、上から降ってくる落石と、横に往復する鬼火を避ける。
## 罪人は左右の崖で待ち構えていて、近づくと糸めがけて飛びかかってくる（揺らせばかわせる）。

# 調整パネル（F1）で変えられる値。高さは m、横位置は px
const DEFAULTS := {
	"climb_speed": 6.0,      # 登る速さ（m/秒）
	"climb_wear": 3.0,       # 登っている間の糸の傷み（/秒）
	"sinner_gap_low": 10.0,  # 崖の罪人の間隔・低いところ（m）
	"sinner_gap_high": 10.0, # 崖の罪人の間隔・高いところ（m）
	"drain_ghost": 2.0,      # 罪人の重さによる耐久度減少（/秒）。人数^ghost_power 倍
	"ghost_power": 1.8,      # 罪人の重さの効き方（1=人数に比例、大きいほど大勢でいきなり重くなる）
	"ghost_slow": 0.0,       # 罪人1人あたり登る速さが落ちる割合
	"catch_damage": 5.0,
	"slack_need": 3.0,       # 叫んで糸を切ったあと、これだけ登って糸が余るまで罪人はつかめない（m）     # 罪人が飛びついた瞬間の糸の傷み
	"jump_base": 4.0,        # 踏み台なしで叫んだときのジャンプ（m）
	"jump_per_sinner": 8.0,  # 踏み台のジャンプ（m）。人数^jump_power 倍
	"jump_power": 1.5,       # 溜めるほど伸びる度合い（1=比例。1.5 で 1人12m 3人46m 5人93m）
	"clutch_frac": 0.10,     # 九死に一生: 耐久がこの割合を切ってから叫ぶと
	"clutch_mult": 1.5,      #   ジャンプがこの倍率
	"shout_window": 1.5,     # 叫べるのは「切れるまで残り何秒」から（秒）
	"swing_power": 900.0,    # 揺らす力
	"rock_interval": 2.4,    # 鬼が岩を投げる平均間隔（秒）
	"rock_flight": 1.1,      # 投げた岩が狙った場所に届くまで（秒）。短いほど速い
	"fire_gap": 55.0,        # 鬼火の平均間隔（m）
	"fire_speed": 1.0,       # 鬼火の速さ（倍率）
	"fire_mode": 0.0,        # 鬼火の動き 0=円（その場でぐるぐる） 1=波（その場で上下にふわふわ）
	"hit_ghost_drop": 1.0,   # 落石・鬼火に当たったとき振り落とされる罪人（人）
	"hazard_damage": 25.0,   # 落石・鬼火に当たったときの糸の傷み
	"lava_speed": 4.0,       # 下から迫る業火の速さ（m/秒、はじめ）
	"lava_accel": 0.12,      # 業火が1秒ごとに速くなる量（m/秒）
	"lava_leash": 60.0,      # 業火はカンダタのこれより下には離れない（m）
}
const TUNE_ORDER := ["climb_speed", "climb_wear", "sinner_gap_low", "sinner_gap_high", "drain_ghost", "ghost_power", "ghost_slow", "catch_damage", "slack_need", "jump_base", "jump_per_sinner", "jump_power", "clutch_frac", "clutch_mult",
		"swing_power", "rock_interval", "rock_flight", "fire_gap", "fire_speed", "fire_mode", "hit_ghost_drop", "hazard_damage", "lava_speed", "lava_accel", "lava_leash"]
const TUNE_LABEL := {
	"climb_speed": "登る速さ", "slack_need": "切った後つかまれない余り（m）", "ghost_power": "大勢の重さ（べき乗）", "jump_power": "溜めジャンプの伸び（べき乗）",
	"clutch_frac": "九死に一生の残り耐久（割合）", "clutch_mult": "九死に一生の倍率",
	"climb_wear": "登ると糸が傷む速さ", "sinner_gap_low": "崖の罪人の間隔（低所m）",
	"sinner_gap_high": "崖の罪人の間隔（高所m）", "drain_ghost": "罪人による糸の傷み",
	"ghost_slow": "罪人の重さ（登りが遅くなる）", "catch_damage": "飛びつかれた瞬間の糸の傷み",
	"jump_base": "踏み台なしのジャンプ（m）", "jump_per_sinner": "踏み台1人あたりのジャンプ（m）", "shout_window": "叫べる時間（切れる何秒前から）",
	"swing_power": "揺らす強さ", "rock_interval": "鬼が岩を投げる間隔（秒）", "rock_flight": "岩が届くまで（秒）",
	"fire_gap": "鬼火の間隔（m）", "fire_speed": "鬼火の速さ", "fire_mode": "鬼火の動き（0円 1波）", "hit_ghost_drop": "当たると落ちる罪人（人）", "hazard_damage": "落石・鬼火の糸の傷み",
	"lava_speed": "業火の速さ（はじめ）", "lava_accel": "業火の加速", "lava_leash": "業火との最大距離（m）",
}
const TUNE_STEP := {
	"climb_speed": 0.5, "slack_need": 1.0, "ghost_power": 0.1, "jump_power": 0.1, "clutch_frac": 0.02, "clutch_mult": 0.1, "climb_wear": 0.5, "sinner_gap_low": 1.0, "sinner_gap_high": 1.0, "drain_ghost": 0.25, "ghost_slow": 0.02, "catch_damage": 2.5, "jump_base": 1.0, "jump_per_sinner": 1.0,
	"shout_window": 0.25, "swing_power": 100.0, "rock_interval": 0.2, "rock_flight": 0.1,
	"fire_gap": 5.0, "fire_speed": 0.25, "fire_mode": 1.0, "hit_ghost_drop": 1.0, "hazard_damage": 5.0,
	"lava_speed": 0.5, "lava_accel": 0.01, "lava_leash": 5.0,
}
const TUNE_MIN := {
	"climb_speed": 0.5, "slack_need": 0.0, "ghost_power": 1.0, "jump_power": 1.0, "clutch_frac": 0.0, "clutch_mult": 1.0, "climb_wear": 0.0, "sinner_gap_low": 2.0, "sinner_gap_high": 2.0, "drain_ghost": 0.25, "ghost_slow": 0.0, "catch_damage": 0.0, "jump_base": 0.0, "jump_per_sinner": 0.0,
	"shout_window": 0.25, "swing_power": 100.0, "rock_interval": 0.2, "rock_flight": 0.1,
	"fire_gap": 10.0, "fire_speed": 0.0, "fire_mode": 0.0, "hit_ghost_drop": 0.0, "hazard_damage": 0.0,
	"lava_speed": 0.0, "lava_accel": 0.0, "lava_leash": 10.0,
}

# 難易度: 標準値の上に重ねる値（調整パネルで変えた値は、さらにその上に乗る）
const DIFFICULTY_NAMES := ["やさしい", "ふつう", "むずかしい"]
const DIFFICULTY_PRESETS := [
	{"lava_speed": 3.0, "lava_accel": 0.08, "rock_interval": 3.2, "fire_gap": 80.0, "hazard_damage": 18.0, "climb_wear": 2.5, "sinner_gap_low": 8.0, "sinner_gap_high": 8.0},
	{},
	{"lava_speed": 5.0, "lava_accel": 0.16, "rock_interval": 1.8, "fire_gap": 48.0, "hazard_damage": 30.0, "climb_wear": 4.0, "sinner_gap_low": 12.0, "sinner_gap_high": 12.0},
]

const GOAL := 1.0e9         # エンドレス（ゴールなし）。どこまで登れるかが記録
const DIFF_RAMP := 1500.0     # この高さまでで、難しさが最大になる（m）
const GEN_AHEAD := 200.0      # カンダタの何 m 上までコースを作っておくか
const DURABILITY_MAX := 100.0
const FIRE_ORBIT := 110.0      # 鬼火の円の半径（px、固定）
const FIRE_LANES := [-140.0, 0.0, 140.0]   # 鬼火の円の中心: 左・中央・右
const SINNER_TRIGGER := 8.0   # 崖の罪人が飛びかかってくる距離（m 手前）
const SINNER_FLIGHT := 0.75   # 飛びかかってから糸に届くまで（秒）
const SINNER_STAGGER := 0.45  # 同じ崖の罪人が続けて飛ぶ間隔（秒）
const SINNER_CATCH := 70.0    # これより近ければ糸につかまれる（px）
const CLIFF_X := X_LIMIT + 60.0
const GAUGE_BASE := 1.0
const AIR_TIME := 0.8
const X_LIMIT := 260.0        # 揺れの最大幅（px）
const SPRING := 2.5           # 中央に戻ろうとする力
const DAMP := 1.4             # 揺れの減衰
const GHOST_HEAVY := 0.08     # 罪人1人あたりの重さ（揺らしにくくなる）
const GHOST_JITTER := 14.0    # 罪人が勝手に揺らす力
const BODY_W := 14.0          # カンダタの半幅（px）
const HEAD := 2.0             # 頭の高さ（m）
const ROCK_R := 22.0          # 落石の半径（px）
const ONI_WINDUP := 0.8       # 鬼が岩を振りかぶっている時間（秒）。この間に軌道が見える
const ONI_X := X_LIMIT + 40.0 # 鬼の手の位置（崖の上、px）
const ONI_ABOVE := 8.0        # 鬼の手は狙う高さの何 m 上か
const ROCK_VUP := 5.0         # 投げ上げる速さ（m/秒）
const ROCK_DAMAGE := 35.0
const ROCK_STUN := 0.5        # 落石に当たったときのよろけ（秒、登れない）
const ROCK_KNOCK := 300.0
const GHOST_SPACING := 3.4    # 罪人の列の間隔（m）。画面の 24px / 7px毎m
const FIRE_R := 20.0          # 鬼火の半径（px）
const FIRE_DAMAGE := 35.0
const FIRE_KNOCK := 450.0
const INVULN := 1.0

enum State { CLIMBING, AIR, WON, TORN }

var cfg: Dictionary = DEFAULTS.duplicate()
var obstacles: Array = []     # 鬼火 {"type":"fire","h","amp","w","phase"}
var rocks: Array = []         # 鬼の投げる岩 {"side","state"(0振りかぶり 1飛行),"t","aim_x","aim_h","h","x","hit_player","hit_ghosts"}
var perches: Array = []       # 崖の罪人 {"h","side","n","fired","timer"}
var jumpers: Array = []       # 飛びかかり中 {"side","h0","aim_x","t","target_h","state"(0飛行 1つかまった 2外れ),"age"}
var caught := 0               # 糸につかまった罪人の合計
var dodged := 0               # かわした罪人の合計
var rng := RandomNumberGenerator.new()
var rock_timer := 0.0

var height := 0.0
var x := 0.0
var vx := 0.0
var ghosts := 0.0
var durability := DURABILITY_MAX
var gauge := 0.0
var cooldown_left := 0.0       # （未使用。旧クールタイム）
var window_open := false      # 叫べる窓が開いているか
var air_left := 0.0
var air_from := 0.0
var air_to := 0.0
var stun_left := 0.0
var dashing := false          # 全力登り中
var dash_time := 0.0          # 全力登りした合計秒数
var invuln_left := 0.0
var hits := 0                 # 鬼火に当たった回数
var rock_hits := 0            # 落石に当たった回数
var ghosts_burned := 0       # 業火に焼かれた罪人
var ghosts_crushed := 0       # 落石・鬼火で落ちた罪人
var elapsed := 0.0
var shouts := 0
var best_jump := 0.0
var last_jump := 0.0
var last_stones := 0          # 直前の叫びで踏み台にした人数
var total_stones := 0         # 踏み台にした合計
var last_clutch := false      # 直前の叫びが九死に一生だったか
var clutches := 0             # 九死に一生の回数
var thread_end := -30.0       # 手元から下へ垂れている糸の下端（m）。叫んで切ると、つかみ直した所が下端になる
var lava_h := -45.0           # 下から迫る業火の高さ（m）
var gen_fire_h := 35.0        # 次に鬼火を置く高さ
var gen_perch_h := 12.0       # 次に罪人を置く高さ
var gen_last_lane := -1
var state := State.CLIMBING
var death := ""               # 落ちた原因（検証用）


func setup(c: Dictionary, seed_value: int, difficulty := 1) -> void:
	cfg = DEFAULTS.duplicate()
	var preset: Dictionary = DIFFICULTY_PRESETS[clampi(difficulty, 0, 2)]
	for k in preset:
		cfg[k] = float(preset[k])
	for k in c:
		if cfg.has(k):
			cfg[k] = float(c[k])
	_generate(seed_value)


func ramp(h: float) -> float:
	# 高さに応じた難しさ 0〜1
	return clampf(h / DIFF_RAMP, 0.0, 1.0)


func _generate(seed_value: int) -> void:
	obstacles.clear()
	rocks.clear()
	perches.clear()
	jumpers.clear()
	rng.seed = seed_value
	gen_fire_h = 35.0
	gen_perch_h = 12.0
	gen_last_lane = -1
	lava_h = -45.0
	rock_timer = 2.5   # 最初の岩までの猶予
	_generate_ahead()


func _generate_ahead() -> void:
	# エンドレス: 登った分だけ、上にコースを継ぎ足していく。通り過ぎたものは捨てる
	while gen_fire_h < height + GEN_AHEAD:
		# 中心は 左・中央・右 の三択（同じ場所が続かないように）。円の大きさは固定
		var lane := rng.randi_range(0, 2)
		while lane == gen_last_lane:
			lane = rng.randi_range(0, 2)
		gen_last_lane = lane
		obstacles.append({"type": "fire", "h": gen_fire_h, "cx": FIRE_LANES[lane], "lane": lane,
				"r": FIRE_ORBIT, "w": rng.randf_range(1.6, 2.4) * (1.0 if rng.randf() < 0.5 else -1.0),
				"phase": rng.randf() * TAU})
		gen_fire_h += cfg.fire_gap * lerpf(1.3, 0.65, ramp(gen_fire_h)) * rng.randf_range(0.7, 1.3)
	while gen_perch_h < height + GEN_AHEAD:
		var n := 1
		if rng.randf() < 0.25 + 0.2 * ramp(gen_perch_h):   # ときどき2人組（上ほど多い）
			n += 1
		perches.append({"h": gen_perch_h, "side": -1.0 if rng.randf() < 0.5 else 1.0, "n": n, "fired": 0, "timer": 0.0})
		gen_perch_h += lerpf(cfg.sinner_gap_low, cfg.sinner_gap_high, ramp(gen_perch_h)) * rng.randf_range(0.75, 1.25)
	obstacles = obstacles.filter(func(o): return o.h > height - 120.0)
	perches = perches.filter(func(p): return p.h > height - 120.0)


func lava_speed() -> float:
	return cfg.lava_speed + cfg.lava_accel * elapsed


func fire_pos(o: Dictionary) -> Vector2:
	# 鬼火の今の位置（x は px、y は高さ m）
	var a: float = elapsed * o.w * cfg.fire_speed + o.phase
	if int(cfg.fire_mode) % 2 == 0:   # 円: 画面上で丸く見えるよう、高さ方向は px→m に換算
		return Vector2(o.cx + o.r * cos(a), o.h + o.r * 0.5 / 3.5 * sin(a))
	return Vector2(o.cx, o.h + 7.0 * sin(a))   # 波: 上下に ±7m


func fire_x(o: Dictionary) -> float:
	return fire_pos(o).x


func stepping_stones() -> int:
	# 今叫んだら踏み台にできる罪人の数
	return int(floorf(ghosts))


func jump_for(n: int) -> float:
	# 踏み台 n 人で跳べる高さ（九死に一生は含まない）。溜めるほど伸びる
	if n <= 0:
		return cfg.jump_base
	return cfg.jump_base + cfg.jump_per_sinner * pow(float(n), cfg.jump_power)


func is_clutch() -> bool:
	# 九死に一生: 糸が切れる寸前に叫ぶと大きく跳べる
	return state == State.CLIMBING and durability < DURABILITY_MAX * cfg.clutch_frac


func jump_height() -> float:
	var j := jump_for(stepping_stones())
	if is_clutch():
		j *= cfg.clutch_mult
	return j


func ghost_drain() -> float:
	# しがみつく罪人の重さ（/秒）。大勢になるほど急に重くなる
	if ghosts <= 0.0:
		return 0.0
	return cfg.drain_ghost * pow(ghosts, cfg.ghost_power)


func can_shout() -> bool:
	# 踏み台にする罪人が1人以上しがみついていれば、いつでも叫べる
	return state == State.CLIMBING and stepping_stones() >= 1


func drain_rate(climbing: bool, _dash := false) -> float:
	# 罪人ぶんを除いた耐久度の減り（/秒）。何もしていなければ減らない
	return cfg.climb_wear if climbing else 0.0


func time_to_snap(climbing := true, _dash := false) -> float:
	# 今のまま続けたら何秒で耐久度が 0 になるか
	# 罪人は勝手には増えないので、今の減り方が続くとして計算する
	var a: float = drain_rate(climbing) + ghost_drain()
	if a <= 0.0:
		return INF
	return durability / maxf(a, 0.01)


func step(delta: float, want_climb: bool, want_shout: bool, swing: float, want_dash := false) -> void:
	if state != State.CLIMBING and state != State.AIR:
		return
	elapsed += delta
	cooldown_left = maxf(0.0, cooldown_left - delta)
	stun_left = maxf(0.0, stun_left - delta)
	invuln_left = maxf(0.0, invuln_left - delta)

	# --- 左右の揺れ（振り子っぽいばね）
	var heavy := 1.0 + GHOST_HEAVY * ghosts
	vx += swing * cfg.swing_power / heavy * delta
	vx += -x * SPRING * delta
	vx += sin(elapsed * 1.7) * ghosts * GHOST_JITTER * delta
	vx *= exp(-DAMP * delta)
	x += vx * delta
	if absf(x) > X_LIMIT:
		x = signf(x) * X_LIMIT
		vx = -vx * 0.4

	_generate_ahead()
	_update_lava(delta)
	if state == State.TORN:
		return
	_update_rocks(delta)
	_update_sinners(delta)
	_check_fire()
	if state == State.TORN:
		return

	if state == State.AIR:
		air_left = maxf(0.0, air_left - delta)
		var k := 1.0 - air_left / AIR_TIME
		height = air_from + (air_to - air_from) * (1.0 - (1.0 - k) * (1.0 - k))
		if air_left <= 0.0:
			height = air_to
			state = State.CLIMBING
		return

	if want_shout and can_shout():
		var j := jump_height()
		last_clutch = is_clutch()
		if last_clutch:
			clutches += 1
		last_stones = stepping_stones()
		total_stones += last_stones
		last_jump = j
		best_jump = maxf(best_jump, j)
		air_from = height
		air_to = height + j
		thread_end = air_to
		air_left = AIR_TIME
		ghosts = 0.0
		gauge = 0.0
		durability = DURABILITY_MAX
		window_open = false
		shouts += 1
		state = State.AIR
		return

	var climbing := want_climb and stun_left <= 0.0
	dashing = false   # 全力登りは廃止
	var speed := 1.0 if climbing else 0.0
	height += cfg.climb_speed * speed / (1.0 + cfg.ghost_slow * ghosts) * delta   # しがみつかれるほど重い
	durability -= (drain_rate(climbing) + ghost_drain()) * delta

	if durability <= 0.0:
		durability = 0.0
		state = State.TORN
		death = "wear"
	_update_window()


func _update_window() -> void:
	# 切れるまで残り shout_window 秒（普通に登った場合）を切ったら、叫べる窓が開く。一度開いたら閉じない
	if state == State.CLIMBING and not window_open and time_to_snap(true, false) < cfg.shout_window:
		window_open = true


func rock_pos(r: Dictionary, tau: float) -> Vector2:
	# 投げてから tau 秒後の岩の位置（x px, 高さ m）。tau < 0 は振りかぶり中で、鬼の手の中
	var x0: float = r.side * ONI_X
	var h0: float = r.aim_h + ONI_ABOVE
	if tau <= 0.0:
		return Vector2(x0, h0)
	var f: float = cfg.rock_flight
	var g: float = 2.0 * (ONI_ABOVE + ROCK_VUP * f) / (f * f)
	return Vector2(x0 + (r.aim_x - x0) / f * tau, h0 + ROCK_VUP * tau - 0.5 * g * tau * tau)


func rock_tau(r: Dictionary) -> float:
	# 投げてからの経過秒（振りかぶり中は負）
	return r.t - ONI_WINDUP


func _update_rocks(delta: float) -> void:
	# 崖の鬼が岩を投げる。狙いは「今の場所」か「登り続けたら来る場所」のどちらか
	rock_timer -= delta
	if rock_timer <= 0.0:
		rock_timer = cfg.rock_interval * lerpf(1.3, 0.6, ramp(height)) * rng.randf_range(0.6, 1.4)
		var lead: float = cfg.climb_speed * (ONI_WINDUP + cfg.rock_flight) if rng.randf() < 0.5 else 0.0
		var ax: float = x + rng.randf_range(-30.0, 30.0) if rng.randf() < 0.6 else rng.randf_range(-X_LIMIT * 0.7, X_LIMIT * 0.7)
		var r0 := {"side": -1.0 if rng.randf() < 0.5 else 1.0, "state": 0, "t": 0.0,
				"aim_x": clampf(ax, -X_LIMIT, X_LIMIT), "aim_h": height + lead + rng.randf_range(-1.0, 1.0),
				"hit_player": false, "hit_ghosts": false}
		var p0 := rock_pos(r0, -1.0)
		r0["x"] = p0.x
		r0["h"] = p0.y
		rocks.append(r0)
	for r in rocks:
		r.t += delta
		var tau := rock_tau(r)
		var rp := rock_pos(r, tau)
		r.x = rp.x
		r.h = rp.y
		if tau <= 0.0:
			continue
		r.state = 1
		# カンダタに当たる
		if not r.hit_player and invuln_left <= 0.0 and absf(r.h - (height + HEAD * 0.5)) < 2.5 \
				and absf(r.x - x) < ROCK_R + BODY_W:
			r.hit_player = true
			rock_hits += 1
			durability -= cfg.hazard_damage
			stun_left = ROCK_STUN
			invuln_left = INVULN
			vx += signf(x - r.x + 0.01) * ROCK_KNOCK
			_shake_off_ghosts()
			if durability <= 0.0:
				durability = 0.0
				state = State.TORN
				death = "rock"
		# 下の罪人の列に当たる（列はカンダタの真下、約 3.4 m 間隔）
		if not r.hit_ghosts and state == State.CLIMBING and ghosts >= 1.0:
			var depth: float = height - r.h
			var line_len := ghosts * GHOST_SPACING
			if depth > 2.0 and depth < line_len and absf(r.x - x * (1.0 - 0.35 * depth / 48.0)) < ROCK_R + 14.0:
				r.hit_ghosts = true
				var n: float = minf(cfg.hit_ghost_drop, ghosts)
				ghosts -= n
				ghosts_crushed += int(n)
	rocks = rocks.filter(func(r): return r.h > height - 70.0 and absf(r.x) < ONI_X + 120.0)


func _update_lava(delta: float) -> void:
	# 下から業火がせり上がる。離れすぎないように、カンダタの lava_leash m 下までは詰めてくる
	lava_h += lava_speed() * delta
	lava_h = maxf(lava_h, height - cfg.lava_leash)
	# ぶら下がった罪人は、下の者から焼かれて落ちる
	if state == State.CLIMBING and ghosts >= 1.0:
		var room := floorf((height - lava_h) / GHOST_SPACING) - 1.0
		if ghosts > maxf(room, 0.0):
			var n := ghosts - maxf(room, 0.0)
			ghosts -= n
			ghosts_burned += int(n)
	if lava_h >= height - 1.0:
		state = State.TORN
		death = "lava"


func _check_fire() -> void:
	if invuln_left > 0.0:
		return
	for o in obstacles:
		if o.type != "fire":
			continue
		var fp := fire_pos(o)
		if absf(fp.y - (height + HEAD * 0.5)) < 2.2 and absf(fp.x - x) < FIRE_R + BODY_W:
			durability -= cfg.hazard_damage
			vx += signf(x - fp.x + 0.01) * FIRE_KNOCK
			_shake_off_ghosts()
			invuln_left = INVULN
			hits += 1
			if durability <= 0.0:
				durability = 0.0
				state = State.TORN
				death = "fire"
			return


func _update_sinners(delta: float) -> void:
	# 近づくと、崖の罪人がカンダタの今の位置めがけて飛びかかる
	for p in perches:
		if p.fired >= p.n or height < p.h - SINNER_TRIGGER:
			continue
		# 糸が切れたばかりで下に余りがないうちは、崖で待つ（届かない糸には飛ばない）
		if state != State.CLIMBING or slack() < cfg.slack_need:
			continue
		if p.h < height - 12.0:   # 跳んで追い越した罪人は、もう届かない
			continue
		p.timer -= delta
		if p.timer <= 0.0:
			p.fired += 1
			p.timer = SINNER_STAGGER
			jumpers.append({"side": p.side, "h0": p.h, "aim_x": x, "t": 0.0,
					"target_h": height - 4.0, "state": 0, "age": 0.0})
	for j in jumpers:
		j.age += delta
		if j.state != 0:
			continue
		j.t += delta
		if j.t >= SINNER_FLIGHT:
			if state == State.CLIMBING and absf(x - j.aim_x) < SINNER_CATCH and slack() >= cfg.slack_need:
				j.state = 1
				ghosts += 1.0
				caught += 1
				durability -= cfg.catch_damage   # 飛びつかれた衝撃で、糸がガクンと傷む
				if durability <= 0.0:
					durability = 0.0
					state = State.TORN
					death = "catch"
				else:
					_update_window()
			else:
				j.state = 2
				dodged += 1
	jumpers = jumpers.filter(func(j): return j.state == 0 or j.age < SINNER_FLIGHT + 2.0)


func slack() -> float:
	# 手元より下に余っている糸の長さ（m）
	return height - thread_end


func incoming_sinners() -> Array:
	# 飛びかかり中で、まだ届いていない罪人
	return jumpers.filter(func(j): return j.state == 0)


func _shake_off_ghosts() -> void:
	# 本人に当たった衝撃で、後ろの罪人が何人か振り落とされる
	var n: float = minf(cfg.hit_ghost_drop, floorf(ghosts))
	ghosts -= n
	ghosts_crushed += int(n)
