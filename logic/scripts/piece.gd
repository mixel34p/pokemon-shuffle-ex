# ============================================
# PokemonPiece.gd - Ficha con sprite local
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

func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Cargar sprite local del Pokémon
	load_pokemon_sprite()

func load_pokemon_sprite():
	# Construir la ruta del sprite
	# Si es forma alternativa: id_form.png (ej: 1_1.png)
	# Si es forma base: id.png (ej: 1.png)
	var sprite_path = "res://assets/sprites/pokemon/icons/" + str(pokemon_id)
	if pokemon_form > 0:
		sprite_path += "_" + str(pokemon_form)
	sprite_path += ".png"
	
	# Intentar cargar el sprite
	if ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		
		var sprite = TextureRect.new()
		sprite.texture = texture
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.size = Vector2(tile_size, tile_size)
		sprite.position = Vector2(0, 0)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)
	else:
		# Si no encuentra el sprite, mostrar placeholder
		show_placeholder()

func show_placeholder():
	# Fondo gris si no hay sprite
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

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				piece_pressed.emit(self)
			else:
				piece_released.emit(self)
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			piece_dragged.emit(self, event.relative)
			get_viewport().set_input_as_handled()
