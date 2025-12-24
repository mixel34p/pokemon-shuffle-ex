extends Control

@onready var pokeball := $Pokeball
var original_pos := Vector2()
var jump_height := 20
var squash_amount := Vector2(1.2, 0.8)

func _ready():
	original_pos = pokeball.position
	_bounce()

func _bounce():
	var tween = create_tween()


	tween.tween_property(pokeball, "position:y", original_pos.y - jump_height, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


	tween.tween_property(pokeball, "position:y", original_pos.y, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


	tween.connect("finished", Callable(self, "_squash"))

func _squash():

	var squash_tween = create_tween()
	squash_tween.tween_property(pokeball, "scale", squash_amount, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	
	squash_tween.tween_property(pokeball, "scale", Vector2(1, 1), 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


	squash_tween.connect("finished", Callable(self, "_bounce"))

func _continue():
	Audiomanager.play_sfx("accept")
	var fadeout_tween = create_tween()
	fadeout_tween.tween_property($".", "modulate", Color.BLACK,0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_button_button_down() -> void:
	_continue() # Replace with function body.
