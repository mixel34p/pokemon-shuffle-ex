# Main.gd - Escena principal del juego
extends Node2D

const GRID_WIDTH = 6
const GRID_HEIGHT = 6
const TILE_SIZE = 64

# Opciones de gameplay
@export var require_match_to_count = true
@export var dim_non_matching = true

# Rutas de recursos
const POKEMON_DATA_PATH = "res://logic/data/pokemon.json"
const SPRITES_PATH = "res://assets/sprites/pokemon/icons/"

# Equipo del jugador (EXACTAMENTE 4 Pokémon por ID)
var team = [
	{"id": 1, "level": 5},      # Bulbasaur
	{"id": 4, "level": 7},      # Charmander
	{"id": 7, "level": 6},      # Squirtle
	{"id": 25, "level": 8}      # Pikachu
]

# Enemigo actual (por ID)
var foe = {
	"id": 9,  # Rattata
	"hp": 1000
}

# Datos del enemigo cargados del JSON
var foe_data = {}

# Datos de todos los Pokémon
var pokemon_database = {}

# Tabla de efectividad de tipos
var type_chart = {
	"normal": {},
	"fire": {"grass": 2.0, "water": 0.5, "fire": 0.5, "rock": 0.5},
	"water": {"fire": 2.0, "water": 0.5, "grass": 0.5, "ground": 2.0, "rock": 2.0},
	"grass": {"water": 2.0, "ground": 2.0, "rock": 2.0, "fire": 0.5, "grass": 0.5, "poison": 0.5, "flying": 0.5, "bug": 0.5},
	"electric": {"water": 2.0, "flying": 2.0, "electric": 0.5, "grass": 0.5, "ground": 0.0},
	"ice": {"grass": 2.0, "ground": 2.0, "flying": 2.0, "dragon": 2.0, "fire": 0.5, "water": 0.5, "ice": 0.5},
	"fighting": {"normal": 2.0, "ice": 2.0, "rock": 2.0, "poison": 0.5, "flying": 0.5, "psychic": 0.5, "bug": 0.5, "fairy": 0.5, "ghost": 0.0},
	"poison": {"grass": 2.0, "fairy": 2.0, "poison": 0.5, "ground": 0.5, "rock": 0.5, "ghost": 0.5},
	"ground": {"fire": 2.0, "electric": 2.0, "poison": 2.0, "rock": 2.0, "grass": 0.5, "bug": 0.5, "flying": 0.0},
	"flying": {"grass": 2.0, "fighting": 2.0, "bug": 2.0, "electric": 0.5, "rock": 0.5},
	"psychic": {"fighting": 2.0, "poison": 2.0, "psychic": 0.5},
	"bug": {"grass": 2.0, "psychic": 2.0, "fighting": 0.5, "fire": 0.5, "flying": 0.5, "ghost": 0.5, "fairy": 0.5},
	"rock": {"fire": 2.0, "ice": 2.0, "flying": 2.0, "bug": 2.0, "fighting": 0.5, "ground": 0.5},
	"ghost": {"psychic": 2.0, "ghost": 2.0, "normal": 0.0},
	"dragon": {"dragon": 2.0, "fairy": 0.0},
	"dark": {"psychic": 2.0, "ghost": 2.0, "fighting": 0.5, "fairy": 0.5},
	"fairy": {"fighting": 2.0, "dragon": 2.0, "dark": 2.0, "fire": 0.5, "poison": 0.5}
}

var grid = []
var selected_piece = null
var dragging = false
var drag_start_pos = Vector2.ZERO
var drag_start_grid_x = 0
var drag_start_grid_y = 0
var moves_left = 15

var can_move = true
var is_processing_matches = false

@onready var grid_container = $GridContainer
@onready var moves_label = $UI/MovesLabel
@onready var hp_label = $UI/HPLabel

func _ready():
	load_pokemon_data()
	load_foe_data()
	setup_grid()
	generate_initial_board()
	update_ui()

func load_pokemon_data():
	var file = FileAccess.open(POKEMON_DATA_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.get_data()
			# El JSON ahora es un diccionario con IDs como claves
			pokemon_database = data
		file.close()
	else:
		push_error("No se pudo cargar pokemon_data.json")

func load_foe_data():
	foe_data = get_pokemon_info(foe["id"])
	if not foe.has("max_hp"):
		foe["max_hp"] = foe["hp"]

func setup_grid():
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append(null)
		grid.append(row)

func generate_initial_board():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var piece_type = randi() % 4  # Solo 4 tipos (tamaño del equipo)
			while check_would_match(x, y, piece_type):
				piece_type = randi() % 4
			
			create_piece(x, y, piece_type)

func check_would_match(x: int, y: int, type: int) -> bool:
	if x >= 2:
		if grid[y][x-1] != null and grid[y][x-2] != null:
			if grid[y][x-1].type == type and grid[y][x-2].type == type:
				return true
	
	if y >= 2:
		if grid[y-1][x] != null and grid[y-2][x] != null:
			if grid[y-1][x].type == type and grid[y-2][x].type == type:
				return true
	
	return false

func create_piece(x: int, y: int, type: int):
	var pokemon_data = team[type]
	var piece = PokemonPiece.new()
	piece.setup(x, y, type, TILE_SIZE, pokemon_data["id"], pokemon_data["level"])
	piece.position = grid_container.position + Vector2(x * TILE_SIZE, y * TILE_SIZE)
	piece.piece_pressed.connect(_on_piece_pressed)
	piece.piece_dragged.connect(_on_piece_dragged)
	piece.piece_released.connect(_on_piece_released)
	add_child(piece)
	grid[y][x] = piece

func get_pokemon_info(pokemon_id: int, form_id: int = 0) -> Dictionary:
	var id_str = str(pokemon_id)
	
	if pokemon_database.has(id_str):
		var poke_data = pokemon_database[id_str]
		
		# Si es una forma alternativa
		if form_id > 0:
			var form_str = str(form_id)
			if poke_data.has("forms") and poke_data["forms"].has(form_str):
				return poke_data["forms"][form_str]
		
		# Forma base
		return poke_data
	
	# Si no se encuentra, devolver datos por defecto
	return {
		"name": "Unknown",
		"type": "normal",
		"base_atk": 30,
		"max_atk": 50,
		"skill": "none"
	}

func calculate_attack_stat(base_atk: int, max_atk: int, level: int) -> int:
	# Fórmula: ataque crece linealmente desde base_atk (nivel 1) hasta max_atk (nivel 10)
	var max_level = 10
	var atk_per_level = float(max_atk - base_atk) / (max_level - 1)
	var current_atk = base_atk + int(atk_per_level * (level - 1))
	return current_atk

func get_type_effectiveness(attacker_type: String, defender_type: String) -> float:
	if type_chart.has(attacker_type):
		if type_chart[attacker_type].has(defender_type):
			return type_chart[attacker_type][defender_type]
	return 1.0  # Neutral

func _on_piece_pressed(piece):
	if not is_instance_valid(piece):
		return
	if piece.get_parent() == null:
		return
	if moves_left <= 0:
		return
	if dim_non_matching and (not can_move or is_processing_matches):
		return
	
	selected_piece = piece
	dragging = true
	drag_start_pos = piece.position
	drag_start_grid_x = piece.grid_x
	drag_start_grid_y = piece.grid_y
	piece.z_index = 10

func _on_piece_dragged(piece, motion):
	if not dragging or selected_piece != piece:
		return
	if not is_instance_valid(piece):
		return
	if piece.get_parent() == null:
		return
	
	piece.position += motion

func _on_piece_released(piece):
	if not is_instance_valid(piece):
		return
	if piece.get_parent() == null:
		return
	if not dragging:
		return
	dragging = false
	selected_piece = null
	piece.z_index = 0
	
	var local_pos = piece.position - grid_container.position
	var target_x = int(round(local_pos.x / TILE_SIZE))
	var target_y = int(round(local_pos.y / TILE_SIZE))
	
	target_x = clamp(target_x, 0, GRID_WIDTH - 1)
	target_y = clamp(target_y, 0, GRID_HEIGHT - 1)
	
	if target_x != drag_start_grid_x or target_y != drag_start_grid_y:
		var other_piece = grid[target_y][target_x]
		
		if other_piece != null and other_piece != piece and is_instance_valid(other_piece) and is_instance_valid(piece):
			grid[drag_start_grid_y][drag_start_grid_x] = other_piece
			grid[target_y][target_x] = piece
			
			other_piece.grid_x = drag_start_grid_x
			other_piece.grid_y = drag_start_grid_y
			piece.grid_x = target_x
			piece.grid_y = target_y
			
			var tween1 = create_tween()
			tween1.tween_property(piece, "position", 
				grid_container.position + Vector2(target_x * TILE_SIZE, target_y * TILE_SIZE), 0.2)
			
			var tween2 = create_tween()
			tween2.tween_property(other_piece, "position", 
				grid_container.position + Vector2(drag_start_grid_x * TILE_SIZE, drag_start_grid_y * TILE_SIZE), 0.2)
			
			await tween1.finished
		else:
			piece.grid_x = drag_start_grid_x
			piece.grid_y = drag_start_grid_y
			
			var tween = create_tween()
			tween.tween_property(piece, "position", drag_start_pos, 0.2)
			await tween.finished
	else:
		var tween = create_tween()
		tween.tween_property(piece, "position", 
			grid_container.position + Vector2(drag_start_grid_x * TILE_SIZE, drag_start_grid_y * TILE_SIZE), 0.2)
		await tween.finished
	
	var matches = find_all_matches()
	
	if require_match_to_count and matches.is_empty():
		print("¡No hay combos! Movimiento no válido")
		await return_piece_to_start(piece)
	else:
		moves_left -= 1
		is_processing_matches = true
		if dim_non_matching:
			can_move = false
		else:
			can_move = true
		await process_matches()
		is_processing_matches = false
		can_move = true
		update_ui()
		check_game_over()

func return_piece_to_start(piece):
	var current_x = piece.grid_x
	var current_y = piece.grid_y
	
	if current_x != drag_start_grid_x or current_y != drag_start_grid_y:
		var other_piece = grid[drag_start_grid_y][drag_start_grid_x]
		
		if other_piece != null and other_piece != piece:
			grid[current_y][current_x] = other_piece
			grid[drag_start_grid_y][drag_start_grid_x] = piece
			
			piece.grid_x = drag_start_grid_x
			piece.grid_y = drag_start_grid_y
			other_piece.grid_x = current_x
			other_piece.grid_y = current_y
			
			var tween2 = create_tween()
			tween2.tween_property(other_piece, "position", 
				grid_container.position + Vector2(current_x * TILE_SIZE, current_y * TILE_SIZE), 0.3)
		else:
			grid[current_y][current_x] = null
			grid[drag_start_grid_y][drag_start_grid_x] = piece
			piece.grid_x = drag_start_grid_x
			piece.grid_y = drag_start_grid_y
	
	var tween = create_tween()
	tween.tween_property(piece, "position", drag_start_pos, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	await tween.finished

func process_matches():
	var total_damage = 0
	var combo_count = 0
	var first_match = true
	
	while true:
		var matches = find_all_matches()
		if matches.is_empty():
			break
		
		combo_count += 1
		
		if combo_count > 1:
			await get_tree().create_timer(0.15).timeout
		
		if dim_non_matching and first_match:
			dim_all_pieces()
			first_match = false
		
		for piece in matches:
			piece.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		await mark_matches_sequentially(matches)
		
		var damage = calculate_damage(matches, combo_count)
		total_damage += damage
		
		show_match_damage(matches, damage)
		
		await get_tree().create_timer(0.25).timeout
		
		if combo_count > 1:
			show_combo_text(combo_count, damage)
		
		for piece in matches:
			grid[piece.grid_y][piece.grid_x] = null
			piece.queue_free()
		
		await get_tree().create_timer(0.1).timeout
		
		await drop_and_fill_pieces()
	
	if dim_non_matching:
		restore_all_colors()
	
	if total_damage > 0:
		deal_damage(total_damage)
		show_damage_text(total_damage)

func find_all_matches() -> Array:
	var all_matched_pieces = {}
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] == null:
				continue
			
			var piece = grid[y][x]
			var piece_type = piece.type
			
			var h_count = 1
			var h_pieces = [piece]
			for i in range(x + 1, GRID_WIDTH):
				if grid[y][i] != null and grid[y][i].type == piece_type:
					h_count += 1
					h_pieces.append(grid[y][i])
				else:
					break
			
			if h_count >= 3:
				for p in h_pieces:
					all_matched_pieces[p] = true
			
			var v_count = 1
			var v_pieces = [piece]
			for i in range(y + 1, GRID_HEIGHT):
				if grid[i][x] != null and grid[i][x].type == piece_type:
					v_count += 1
					v_pieces.append(grid[i][x])
				else:
					break
			
			if v_count >= 3:
				for p in v_pieces:
					all_matched_pieces[p] = true
	
	var matches = []
	for piece in all_matched_pieces.keys():
		matches.append(piece)
	
	return matches

func mark_matches_sequentially(matches: Array):
	matches.sort_custom(func(a, b): return a.grid_y < b.grid_y or (a.grid_y == b.grid_y and a.grid_x < b.grid_x))
	
	for i in range(matches.size()):
		var piece = matches[i]
		var tween = create_tween()
		tween.set_loops(2)
		tween.tween_property(piece, "modulate:a", 0.3, 0.1)
		tween.tween_property(piece, "modulate:a", 1.0, 0.1)
		
		if i < matches.size() - 1:
			await get_tree().create_timer(0.05).timeout

func calculate_damage(matches: Array, combo: int) -> int:
	var total_damage = 0
	
	# Calcular daño por cada pieza en el match
	for piece in matches:
		var pokemon_data = team[piece.type]
		var poke_info = get_pokemon_info(pokemon_data["id"])
		
		# Calcular ataque del Pokémon según su nivel
		var attack = calculate_attack_stat(
			poke_info["base_atk"],
			poke_info["max_atk"],
			pokemon_data["level"]
		)
		
		# Obtener efectividad de tipo
		var effectiveness = get_type_effectiveness(poke_info["type"], foe_data["type"])
		print(poke_info["name"],poke_info["type"], foe_data["type"])
		
		if effectiveness > 1:
			print("Super Efectivo")
		elif effectiveness == 1:
			print("Efectivo")
		elif effectiveness < 1:
			print("Poco efectivo")
		else:
			print("No hay efectividad...")
		# Daño base = ataque * efectividad
		var piece_damage = attack * effectiveness
		total_damage += piece_damage
	
	# Multiplicador de combo
	var combo_multiplier = 1.0 + (combo - 1) * 0.5
	total_damage = int(total_damage * combo_multiplier)
	
	return total_damage

func drop_and_fill_pieces():
	var all_tweens = []

	for x in range(GRID_WIDTH):
		var existing_bottom_up: Array = []

		for y in range(GRID_HEIGHT - 1, -1, -1):
			if grid[y][x] != null:
				existing_bottom_up.append(grid[y][x])
				grid[y][x] = null

		var missing := GRID_HEIGHT - existing_bottom_up.size()
		var column_top_down: Array = []

		for i in range(missing):
			var piece_type = randi() % 4
			var pokemon_data = team[piece_type]
			var piece = PokemonPiece.new()
			piece.setup(x, 0, piece_type, TILE_SIZE, pokemon_data["id"], pokemon_data["level"])
			var start_y = -missing + i
			piece.position = grid_container.position + Vector2(x * TILE_SIZE, start_y * TILE_SIZE)
			
			if dim_non_matching:
				piece.modulate = Color(0.4, 0.4, 0.4, 1.0)

			piece.piece_pressed.connect(_on_piece_pressed)
			piece.piece_dragged.connect(_on_piece_dragged)
			piece.piece_released.connect(_on_piece_released)
			add_child(piece)

			column_top_down.append(piece)

		for i in range(existing_bottom_up.size() - 1, -1, -1):
			column_top_down.append(existing_bottom_up[i])

		for target_y in range(GRID_HEIGHT):
			var piece = column_top_down[target_y]
			grid[target_y][x] = piece
			piece.grid_x = x
			piece.grid_y = target_y

			var current_y_pos = (piece.position.y - grid_container.position.y) / TILE_SIZE
			var distance = target_y - current_y_pos
			
			if distance > 0:
				var speed = 400.0
				var pixels_to_fall = distance * TILE_SIZE
				var fall_time = pixels_to_fall / speed
				
				var tween = create_tween()
				tween.tween_property(
					piece, "position:y",
					grid_container.position.y + (target_y * TILE_SIZE),
					fall_time
				).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				
				all_tweens.append(tween)

	if all_tweens.size() > 0:
		await all_tweens[-1].finished
		await get_tree().create_timer(0.1).timeout

func deal_damage(damage: int):
	foe["hp"] -= damage
	foe["hp"] = max(0, foe["hp"])
	print("Daño: ", damage, " | HP restante: ", foe["hp"])

func dim_all_pieces():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != null:
				grid[y][x].modulate = Color(0.4, 0.4, 0.4, 1.0)

func restore_all_colors():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != null:
				grid[y][x].modulate = Color(1.0, 1.0, 1.0, 1.0)

func show_match_damage(matches: Array, damage: int):
	var center_x = 0.0
	var center_y = 0.0
	for piece in matches:
		center_x += piece.position.x
		center_y += piece.position.y
	center_x /= matches.size()
	center_y /= matches.size()
	
	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.add_theme_font_size_override("font_size", 36)
	damage_label.modulate = Color(1, 1, 1, 1)
	damage_label.position = Vector2(center_x - 20, center_y - 20)
	damage_label.z_index = 50
	add_child(damage_label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", center_y - 60, 0.5)
	tween.tween_property(damage_label, "scale", Vector2(1.5, 1.5), 0.15)
	tween.chain().tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.3).set_delay(0.2)
	
	await tween.finished
	damage_label.queue_free()

func show_combo_text(combo: int, damage: int):
	var combo_text = Label.new()
	combo_text.text = "COMBO x" + str(combo) + "!"
	combo_text.add_theme_font_size_override("font_size", 42)
	combo_text.modulate = Color(1, 0.8, 0, 1)
	combo_text.position = Vector2(250, 300)
	add_child(combo_text)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(combo_text, "position:y", 250, 0.6)
	tween.tween_property(combo_text, "scale", Vector2(1.3, 1.3), 0.2)
	tween.chain().tween_property(combo_text, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(combo_text, "modulate:a", 0.0, 0.6).set_delay(0.3)
	
	await tween.finished
	combo_text.queue_free()
	
	var damage_text = Label.new()
	damage_text.text = "+" + str(damage) + " daño"
	damage_text.add_theme_font_size_override("font_size", 28)
	damage_text.modulate = Color(1, 1, 0.5, 1)
	damage_text.position = Vector2(270, 340)
	add_child(damage_text)
	
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(damage_text, "position:y", 290, 0.6)
	tween2.tween_property(damage_text, "modulate:a", 0.0, 0.6).set_delay(0.2)
	
	await tween2.finished
	damage_text.queue_free()

func show_damage_text(damage: int):
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage)
	damage_label.add_theme_font_size_override("font_size", 48)
	damage_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
	damage_label.position = Vector2(520, 120)
	damage_label.z_index = 100
	add_child(damage_label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", 60, 0.8)
	tween.tween_property(damage_label, "scale", Vector2(1.5, 1.5), 0.2)
	tween.chain().tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	
	await tween.finished
	damage_label.queue_free()

func update_ui():
	moves_label.text = "Movimientos: " + str(moves_left)
	hp_label.text = "HP Enemigo: " + str(foe["hp"]) + "/" + str(foe["max_hp"])

func check_game_over():
	if foe["hp"] <= 0:
		print("¡Victoria!")
		await get_tree().create_timer(1.0).timeout
		get_tree().reload_current_scene()
	elif moves_left <= 0:
		print("¡Derrota!")
		await get_tree().create_timer(1.0).timeout
		get_tree().reload_current_scene()
