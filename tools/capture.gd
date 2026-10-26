extends Node
## 画面確認用: ボットに自動プレイさせてスクリーンショットを保存する
## godot --path . --fixed-fps 60 res://tools/capture.tscn -- <outdir> <course> <margin> [panel]

const Bot = preload("res://sim_test.gd")
const ThreadModel = preload("res://thread_model.gd")

var main: Node
var frame := 0
var outdir := "user://shots"
var course := 1
var margin := 1.0
var want_panel := false
var shots := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		outdir = args[0]
	if args.size() > 1:
		course = int(args[1])
	if args.size() > 2:
		margin = float(args[2])
	want_panel = args.size() > 3 and args[3] == "panel"
	var wave := args.has("wave")
	DirAccess.make_dir_recursive_absolute(outdir)
	main = load("res://main.tscn").instantiate()
	add_child(main)
	main.autopilot = true
	if wave:
		main.tuning["fire_mode"] = 1.0


func _snap(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(outdir + "/" + n + ".png")
	print("saved ", n)


func _process(_d: float) -> void:
	frame += 1
	if frame == 20:
		_snap("00_title")
		main.course = course
		main._restart()
	if want_panel and frame == 40:
		main.panel_open = true
		main.panel_sel = 0
		main.tuning["climb_speed"] = 5.0
	if want_panel and frame == 45:
		_snap("panel")
		get_tree().quit()
		return
	var m = main.model
	if main.phase == main.Phase.PLAY and not main.panel_open:
		var inp: Array = Bot.bot_inputs(m, margin, "n2", "smart", 30)
		main.bot_climb = inp[0]
		main.bot_shout = inp[1]
		main.bot_swing = inp[2]
		main.bot_dash = inp[3]
		if m.height > 280.0 and not shots.has("goal"):
			shots["goal"] = true
			_snap("goal")
		for ts in [3.0, 9.0, 16.0, 24.0]:
			var key := "t%02d" % int(ts)
			if m.elapsed >= ts and not shots.has(key):
				shots[key] = true
				_snap(key)
		var running := false
		for pc in m.perches:
			var rk: float = (m.height - (pc.h - 8.0 - 10.0)) / 10.0
			if rk > 0.3 and rk < 0.8 and pc.fired < pc.n:
				running = true
		if running and m.height > 40.0 and not shots.has("run"):
			shots["run"] = true
			_snap("run")
		if not m.incoming_sinners().is_empty() and m.height > 60.0 and not shots.has("leap"):
			shots["leap"] = true
			_snap("leap")
		if m.can_shout() and m.elapsed > 2.0 and not shots.has("window"):
			shots["window"] = true
			_snap("window")
		if m.is_clutch() and m.can_shout() and not shots.has("clutch"):
			shots["clutch"] = true
			_snap("clutch")
		if m.shouts > 0 and m.last_clutch and m.state == ThreadModel.State.AIR and not shots.has("clutch_jump"):
			shots["clutch_jump"] = true
			_snap("clutch_jump")
		if m.dashing and m.elapsed > 1.0 and not shots.has("dash"):
			shots["dash"] = true
			_snap("dash")
		if m.state == ThreadModel.State.AIR and m.air_to - m.air_from > 40.0:
			var kk: float = 1.0 - m.air_left / ThreadModel.AIR_TIME
			for nm in ["bigjump_a", "bigjump_b", "bigjump_c"]:
				var th: float = {"bigjump_a": 0.15, "bigjump_b": 0.5, "bigjump_c": 0.9}[nm]
				if kk > th and not shots.has(nm):
					shots[nm] = true
					_snap(nm)
		var gap: float = m.height - m.lava_h
		if gap < 34.0 and m.lava_h > 0.0 and not shots.has("lava1"):
			shots["lava1"] = true
			_snap("lava1")
		if gap < 16.0 and m.lava_h > 0.0 and not shots.has("lava2"):
			shots["lava2"] = true
			_snap("lava2")
		for rk in m.rocks:
			var tau: float = m.rock_tau(rk)
			if tau > -0.4 and tau < -0.3 and m.elapsed > 4.0 and not shots.has("oni"):
				shots["oni"] = true
				_snap("oni")
			if tau > 0.35 and tau < 0.45 and m.elapsed > 4.0 and not shots.has("throw"):
				shots["throw"] = true
				_snap("throw")
			if tau > 0.9 and tau < 1.0 and m.elapsed > 8.0 and not shots.has("throw2"):
				shots["throw2"] = true
				_snap("throw2")
		if m.ghosts_crushed > 0 and main.popups.size() > 0 and not shots.has("crush"):
			shots["crush"] = true
			_snap("crush")
		if main.fx_hit > 0.3 and main.fx_hit < 0.4 and not shots.has("hit"):
			shots["hit"] = true
			_snap("hit")
		if main.hitstop > 0.0 and main.hitstop_frames == 1 and m.elapsed > 4.0 and not shots.has("hitstop"):
			shots["hitstop"] = true
			_snap("hitstop")
		if main.fx_shout > 0.7 and not shots.has("shout"):
			shots["shout"] = true
			_snap("shout")
	if main.phase == main.Phase.RESULT and m.state == m.State.WON:
		for pt in [0.3, 1.0, 2.6]:
			var key := "win_%.1f" % pt
			if main.phase_t >= pt and not shots.has(key):
				shots[key] = true
				_snap(key)
	if main.phase == main.Phase.RESULT and main.phase_t > 2.8:
		_snap("result")
		print("RESULT ", m.State.keys()[m.state], " t=", snapped(m.elapsed, 0.1), " h=", int(m.height), " shouts=", m.shouts, " hits=", m.hits)
		get_tree().quit()
	if frame > 60 * 150:
		get_tree().quit()
