extends Node

var clips := {}


func setup() -> void:
	for clip_name in ["spin", "hop", "coin", "card", "stop", "cheer", "loan"]:
		var player := AudioStreamPlayer.new()
		player.stream = _wav("res://Assets/sfx/%s.wav" % clip_name)
		player.volume_db = -6.0
		add_child(player)
		clips[clip_name] = player


func play(clip_name: String) -> void:
	if not clips.has(clip_name):
		return
	var player: AudioStreamPlayer = clips[clip_name]
	if player.stream == null:
		return
	player.play()


func _wav(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() <= 44:
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = bytes.slice(44)
	return stream
