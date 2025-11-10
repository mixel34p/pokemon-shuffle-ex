# AudioManager.gd (autoload)
extends Node

var sfx := {
	"accept": preload("res://audio/se/grab_pokemon.wav"),
	"grab_pokemon": preload("res://audio/se/grab_pokemon.wav"),
	"release_pokemon": preload("res://audio/se/release_pokemon.wav"),
	"put_pokemon": preload("res://audio/se/put_pokemon.wav"),
	"attack": preload("res://audio/se/attack.wav"),
	"damage": preload("res://audio/se/damage.wav"),
	"combo_1": preload("res://audio/se/combo_1.wav"),
	"combo_2": preload("res://audio/se/combo_2.wav"),
	"combo_3": preload("res://audio/se/combo_3.wav"),
	"combo_4": preload("res://audio/se/combo_4.wav"),
	"combo_5": preload("res://audio/se/combo_5.wav"),
	"combo_6": preload("res://audio/se/combo_6.wav"),
	"combo_7": preload("res://audio/se/combo_7.wav"),
	"combo_8": preload("res://audio/se/combo_8.wav"),
	"combo_9": preload("res://audio/se/combo_9.wav"),
	"combo_10": preload("res://audio/se/combo_10.wav"),
	"combo_11": preload("res://audio/se/combo_11.wav"),
	"combo_12": preload("res://audio/se/combo_12.wav"),
	"combo_13": preload("res://audio/se/combo_13.wav"),
	"combo_14": preload("res://audio/se/combo_14.wav"),
	"combo_15": preload("res://audio/se/combo_15.wav"),
	"combo_16": preload("res://audio/se/combo_16.wav"),
	"combo_17": preload("res://audio/se/combo_17.wav"),
	"combo_18": preload("res://audio/se/combo_18.wav"),
	"combo_19": preload("res://audio/se/combo_19.wav"),
	"combo_20": preload("res://audio/se/combo_20.wav"),
	"combo_end_1": preload("res://audio/me/combo_end_1.wav"),
	"combo_end_2": preload("res://audio/me/combo_end_2.wav"),
	"combo_end_3": preload("res://audio/me/combo_end_3.wav"),
	"combo_end_4": preload("res://audio/me/combo_end_4.wav"),
	"disruption": preload("res://audio/se/disruption.wav"),
	"warning_disruption": preload("res://audio/se/warning_interference.wav"),
	"appear": preload("res://audio/se/appear.wav"),
	"start": preload("res://audio/se/start!.wav")
}

func play_sfx(name: String, volume := 0.0, pitch_range := Vector2(1.0, 1.0)):
	var stream = sfx.get(name)
	if stream == null:
		push_warning("Sound not found: %s" % name)
		return

	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	player.bus = "SFX"
	player.play()
	player.connect("finished", Callable(player, "queue_free"))
