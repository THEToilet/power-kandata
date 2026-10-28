extends Node
## 宣伝動画の素材録り: ボットに遊ばせて、Godot のムービーメーカーで録画する。
## 見どころ（叫び・九死に一生・投石・クリア・糸切れ）のフレーム番号を "EVT" 行で出す。
## godot --path . --write-movie out.avi --fixed-fps 60 --resolution 1280x720 res://tools/promo_rec.tscn -- [course=N] [mode=n2|n3|clutch] [snap_at=秒] [idle_until=秒] [start_at=フレーム] [quit_at=フレーム] [nobgm]

const Bot = preload("res://sim_test.gd")
const ThreadModel = preload("res://thread_model.gd")

var main: Node
var frame := 0
var course := 1
var mode := "n2"
var snap_at := -1.0
var nobgm := false
var idle_until := -1.0
var start_at := 90       # 何フレーム目にスタートするか（それまではタイトル画面）
var quit_at := -1        # このフレームで録画を終える
var prev_shouts := 0
var prev_phase := -1
var end_frame := -1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("course="):
			course = int(a.substr(7))
		elif a.begins_with("mode="):
			mode = a.substr(5)
		elif a.begins_with("snap_at="):
			snap_at = float(a.substr(8))
		elif a.begins_with("idle_until="):
			idle_until = float(a.substr(11))
		elif a.begins_with("start_at="):
			start_at = int(a.substr(9))
		elif a.begins_with("quit_at="):
			quit_at = int(a.substr(8))
		elif a == "nobgm":
			nobgm = true
	main = load("res://main.tscn").instantiate()
	add_child(main)
	main.autopilot = true
	main.tips_seen = {"climb": true, "sinner": true, "shout": true}   # 動画では案内の文字を出さない


func _evt(name: String, extra := "") -> void:
	print("EVT ", name, " f=", frame, " ", extra)


func _process(_d: float) -> void:
	frame += 1
	if nobgm and main.bgm_player:
		main.bgm_player.volume_db = -80.0   # 曲は編集で別に敷くので、効果音だけ録る
	if quit_at > 0 and frame >= quit_at:
		get_tree().quit()
		return
	if frame == start_at:
		_evt("start")
		main.course = course
		main._se("se_start")
		main._restart()
	var m = main.model
	if main.phase != prev_phase:
		prev_phase = main.phase
		if main.phase == main.Phase.RESULT:
			_evt("won" if m.state == ThreadModel.State.WON else "torn", "h=%d" % int(m.height))
			end_frame = frame + (420 if m.state == ThreadModel.State.WON else 200)
	if end_frame > 0 and frame >= end_frame:
		get_tree().quit()
		return
	if main.phase != main.Phase.PLAY:
		return
	if snap_at > 0.0 and m.elapsed > snap_at and m.ghosts >= 2.0 and m.state == ThreadModel.State.CLIMBING:
		m.durability = 0.0
	var inp: Array = Bot.bot_inputs(m, 1.0, mode, "smart", 30)
	if snap_at > 0.0 and m.elapsed > snap_at:
		inp[1] = false
	if m.elapsed < idle_until:   # 出だしで待って、マグマが地面から上がってくるのを見せる
		inp = [false, false, 0.0]
	main.bot_climb = inp[0]
	main.bot_shout = inp[1]
	main.bot_swing = inp[2]
	if m.shouts > prev_shouts:
		prev_shouts = m.shouts
		_evt("shout", "stones=%d clutch=%s h=%d" % [m.last_stones, str(m.last_clutch), int(m.height)])
	for rk in m.rocks:
		if rk.state == 1 and not rk.has("_pe"):
			rk["_pe"] = true
			var ry: float = main._sy(rk.h)
			if ry > 0.0 and ry < 360.0:
				_evt("throw", "h=%d" % int(m.height))
	if m.height - m.lava_h < 20.0 and m.lava_h > 0.0 and frame % 30 == 0:
		_evt("lava", "gap=%d" % int(m.height - m.lava_h))
	if frame % 600 == 0:
		_evt("tick", "t=%.1f h=%d" % [m.elapsed, int(m.height)])
