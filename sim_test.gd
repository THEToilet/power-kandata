extends SceneTree
## ヘッドレスでバランスを確認する: godot --headless --path . -s sim_test.gd
## 落石と鬼火をよけるボット（揺らしてかわし、切れる margin 秒前に叫ぶ）を何コースも走らせる

const ThreadModel = preload("res://thread_model.gd")


static func target_x(m, mode := "swing", cap := 99) -> float:
	# 近づいてくる落石・鬼火から離れた位置を目指す（なければ中央）
	# mode: avoid=罪人もかわす  greedy=罪人を受け止めに行く  cap=cap 人まで受けて、それ以上はかわす
	var tgt := 0.0
	var want: bool = mode == "greedy" or (mode == "cap" and m.ghosts < cap)
	var avoid: bool = mode == "avoid" or (mode == "cap" and m.ghosts >= cap)
	if mode == "smart":   # 飛びつかれても糸に余裕があるなら受け、危ないならかわす
		var safe: bool = m.durability - m.cfg.catch_damage > float(cap)
		want = safe
		avoid = not safe
	for j in m.incoming_sinners():
		if want:
			tgt = j.aim_x
		elif avoid and absf(j.aim_x - tgt) < 60.0:
			tgt = j.aim_x + (100.0 if j.aim_x < 0.0 else -100.0)
	for pass_i in range(2):
		for o in m.obstacles:
			var fp: Vector2 = m.fire_pos(o)
			var dh2: float = fp.y - m.height
			if dh2 > -2.0 and dh2 < 8.0 and absf(fp.x - tgt) < 90.0:
				tgt = fp.x + (130.0 if fp.x < 0.0 else -130.0)
	return clampf(tgt, -ThreadModel.X_LIMIT + 20.0, ThreadModel.X_LIMIT - 20.0)


static func rock_hits_if(m, climb: bool, px: float) -> bool:
	# 登り続けたら / 止まったら、飛んでくる岩に当たるか
	var f: float = m.cfg.rock_flight
	for r in m.rocks:
		if r.hit_player:
			continue
		var tau: float = m.rock_tau(r)
		var x0: float = r.side * ThreadModel.ONI_X
		var vx: float = (r.aim_x - x0) / f
		var tc: float = (px - x0) / vx   # 岩がカンダタの横位置に来る時刻
		var dt: float = tc - tau
		if dt < -0.15 or dt > 2.5:
			continue
		var my_h: float = m.height + (m.cfg.climb_speed * maxf(dt, 0.0) if climb else 0.0) + ThreadModel.HEAD * 0.5
		if absf(m.rock_pos(r, tc).y - my_h) < 4.0:
			return true
	return false


static func want_climb(m) -> bool:
	if m.state != ThreadModel.State.CLIMBING:
		return true
	if rock_hits_if(m, true, m.x) and not rock_hits_if(m, false, m.x):
		return false
	return true


static func bot_inputs(m, margin: float, mode: String, smode := "swing", cap := 99) -> Array:
	var swing := clampf((target_x(m, smode, cap) - m.x) * 0.05 - m.vx * 0.01, -1.0, 1.0)
	if mode == "noswing":
		swing = 0.0
	var shout := false
	if m.state == ThreadModel.State.CLIMBING:
		var snap: float = m.time_to_snap()
		if mode == "never":
			shout = false
		elif mode == "spam":   # 窓が開いたらすぐ叫ぶ
			shout = m.can_shout()
		elif mode == "clutch":   # 九死に一生を狙う（切れる直前まで粘る）
			shout = m.can_shout() and (m.is_clutch() or snap < 0.12)
		elif m.can_shout() and snap < margin:
			shout = true
		elif mode.begins_with("n") and m.can_shout() and m.stepping_stones() >= int(mode.substr(1)):
			shout = true   # n3 = 3人集まったら叫ぶ（糸が危なければその前でも）
	return [want_climb(m), shout, swing]


func run_one(seed_value: int, margin: float, mode: String, cfg := {}, smode := "greedy", diff := 1):
	var m = ThreadModel.new()
	m.setup(cfg, seed_value, diff)
	while (m.state == ThreadModel.State.CLIMBING or m.state == ThreadModel.State.AIR) and m.elapsed < 240.0:
		var inp := bot_inputs(m, margin, mode, smode, 30)
		m.step(1.0 / 60.0, inp[0], inp[1], inp[2])
	return m


func summary(label: String, margin: float, mode: String, cfg := {}, smode := "greedy", diff := 1) -> void:
	var wins := 0
	var t_sum := 0.0
	var fire := 0
	var rock := 0
	var crushed := 0
	var heights := 0.0
	var deaths := {}
	var clutch := 0
	var stones := 0
	var sh := 0
	var n := 20
	for s in range(1, n + 1):
		var m = run_one(s, margin, mode, cfg, smode, diff)
		deaths[m.death] = deaths.get(m.death, 0) + 1
		clutch += m.clutches
		stones += m.total_stones
		sh += m.shouts
		heights += m.height
		fire += m.hits
		rock += m.rock_hits
		crushed += m.ghosts_crushed
		if m.state == ThreadModel.State.WON:
			wins += 1
			t_sum += m.elapsed
	print("%-26s clear %2d/%d  avg_time %5.1fs  avg_height %5.1fm  rock %.1f  fire %.1f  crushed %.1f" % [
		label, wins, n, t_sum / maxi(wins, 1), heights / n, float(rock) / n, float(fire) / n, float(crushed) / n])
	print("      stones/shout %.2f  clutch %.1f  deaths %s" % [float(stones) / maxi(sh, 1), float(clutch) / n, str(deaths)])


func _init() -> void:
	# エンドレス: どこまで登れたか（avg_height）で比べる
	for d in [2]:   # 遊べるのは「むずかしい」だけ
		print("== ", ThreadModel.DIFFICULTY_NAMES[d])
		for md in ["n1", "n2", "n3", "n5", "clutch"]:
			summary("%s smart" % md, 1.0, md, {}, "smart", d)
	quit()
