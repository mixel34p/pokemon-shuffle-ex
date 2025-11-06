# ============================================
# PokemonPiece.gd - Ficha con sprite y animaciones
# ============================================
class_name PokemonPiece
extends Control

signal piece_pressed(piece)
signal piece_dragged(piece, motion)
signal piece_released(piece)

var grid_x: int
var grid_y: int
var type: int
var tile_size: int
var pokemon_id: int
var pokemon_form: int
var pokemon_level: int

var sprite_node: TextureRect
var idle_timer: Timer
var is_in_idle_animation: bool = false
var is_being_dragged := false
var dragging := false
var can_move := false
var drag_offset := Vector2.ZERO
var hover_tween : Tween
var smooth_follow_speed := 20.00

func setup(x: int, y: int, piece_type: int, tile_size_val: int, poke_id: int, level: int, form: int = 0):
	grid_x = x
	grid_y = y
	type = piece_type
	tile_size = tile_size_val
	pokemon_id = poke_id
	pokemon_form = form
	pokemon_level = level
	
	custom_minimum_size = Vector2(tile_size_val, tile_size_val)
	size = Vector2(tile_size_val, tile_size_val)
	
	# Establecer el pivot en el centro para que escale desde ahí
	pivot_offset = Vector2(tile_size_val / 2.0, tile_size_val / 2.0)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	load_pokemon_sprite()
	setup_idle_animation()

func load_pokemon_sprite():
	var sprite_path = "res://assets/sprites/pokemon/icons/" + str(pokemon_id)
	if pokemon_form > 0:
		sprite_path += "_" + str(pokemon_form)
	sprite_path += ".png"
	
	if ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		
		sprite_node = TextureRect.new()
		sprite_node.texture = texture
		sprite_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_node.size = Vector2(tile_size, tile_size)
		sprite_node.position = Vector2(0, 0)
		sprite_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite_node)
	else:
		show_placeholder()

func show_placeholder():
	var background = ColorRect.new()
	background.size = Vector2(tile_size, tile_size)
	background.position = Vector2(0, 0)
	background.color = Color(0.3, 0.3, 0.35, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	
	var label = Label.new()
	label.text = str(pokemon_id)
	if pokemon_form > 0:
		label.text += "_" + str(pokemon_form)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(tile_size, tile_size)
	label.position = Vector2(0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func animate_pick_up() -> void:
	is_being_dragged = true
	stop_idle_animation()

	if hover_tween:
		hover_tween.kill()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(self, "modulate:a", 0.7, 0.15)

	await tween.finished
	can_move = true
	dragging = true
	piece_pressed.emit(self)


func animate_release() -> void:
	is_being_dragged = false

	if hover_tween:
		hover_tween.kill()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

	await tween.finished
	resume_idle_animation()


func animate_hover_over():
	"""Animación cuando la pieza arrastrada pasa sobre esta"""
	if is_being_dragged:
		return
	
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Aumentar escala ligeramente
	hover_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)

func animate_hover_exit():
	"""Animación cuando la pieza arrastrada deja de estar sobre esta"""
	if is_being_dragged:
		return
	
	if hover_tween:
		hover_tween.kill()
	
	hover_tween = create_tween()
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Volver a escala normal
	hover_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func setup_idle_animation():
	"""Configura el timer para las animaciones idle aleatorias"""
	idle_timer = Timer.new()
	idle_timer.one_shot = false
	# Random entre 3 y 8 segundos
	idle_timer.wait_time = randf_range(3.0, 8.0)
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	add_child(idle_timer)
	idle_timer.start()

func _on_idle_timer_timeout():
	if not is_being_dragged and not is_in_idle_animation:
		play_idle_wiggle()
	# Resetear tiempo aleatorio
	idle_timer.wait_time = randf_range(3.0, 8.0)

func play_idle_wiggle():
	"""Animación idle: girar suavemente de lado a lado"""
	is_in_idle_animation = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Girar a la derecha
	tween.tween_property(self, "rotation", deg_to_rad(8), 0.15)
	# Girar a la izquierda
	tween.tween_property(self, "rotation", deg_to_rad(-8), 0.3)
	# Volver al centro
	tween.tween_property(self, "rotation", 0.0, 0.15)
	
	await tween.finished
	is_in_idle_animation = false

func stop_idle_animation():
	"""Detiene el timer de animación idle"""
	if idle_timer:
		idle_timer.stop()

func resume_idle_animation():
	"""Reanuda el timer de animación idle"""
	if idle_timer:
		idle_timer.wait_time = randf_range(3.0, 8.0)
		idle_timer.start()

func animate_match_pop():
	"""Animación al hacer match: crece y luego se encoge hasta desaparecer"""
	stop_idle_animation()
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(0.0, 0.0), 0.2)
	
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)

func animate_land_squish():
	"""Animación al caer: efecto squish (aplastamiento)"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	
	tween.tween_property(self, "scale", Vector2(1.15, 0.85), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

func _gui_input(event):
	var board = get_parent()
	if ("is_processing_matches") in board and (board.is_processing_matches or not board.can_move):
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_offset = get_global_mouse_position() - global_position
			can_move = false
			animate_pick_up()
			get_viewport().set_input_as_handled()
		else:
			animate_release()
			dragging = false
			piece_released.emit(self)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		pass
func _process(delta):
	if dragging and can_move:
		var mouse_pos = get_global_mouse_position()
		global_position = global_position.lerp(mouse_pos - drag_offset, delta * smooth_follow_speed)
		piece_dragged.emit(self, Vector2.ZERO) # 🔥 emite para hover
		
