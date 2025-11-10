# Main.gd - Escena principal del juego con animaciones
extends Node2D

const GRID_WIDTH = 6
const GRID_HEIGHT = 6
const TILE_SIZE = 118

# Opciones de gameplay
@export var require_match_to_count = true
@export var dim_non_matching = true

# Rutas de recursos
const POKEMON_DATA_PATH = "res://logic/data/pokemon.json"
const SPRITES_PATH = "res://assets/sprites/pokemon/icons/"

# Equipo del jugador (EXACTAMENTE 4 Pokémon por ID)
# Formato: ID_FORMA (ej: "503_1" = Pokémon 503, forma 1)
var team = [
	{"id": "503_1", "level": 5},      # Bulbasaur forma 1
	{"id": "899", "level": 7},        # Charmander
	{"id": "852", "level": 6},        # Squirtle
	{"id": "543", "level": 8}         # Pikachu
]

# Enemigo actual (por ID)
var foe = {
	"id": "1",  # Rattata (puede ser "9" o "9_1" para formas)
	"hp": 9000000,
	"turns_for_interference": 2, 
	"disruption_patterns": [
		{
		  "type": "barrier",
		  "positions": "random",
		  "count": 2,
		  "pokemon_id": "815"
		}
	]
}
var initial_grid_config: GridInitialConfig = null

# Datos del enemigo cargados del JSON
var foe_data = {}
var grid_clouds = {}
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
var drag_offset = Vector2.ZERO  # Offset entre el cursor y el centro de la pieza
var drag_start_grid_x = 0
var drag_start_grid_y = 0
var moves_left = 60

var can_move = false 
var is_processing_matches = false

# Para el sistema de hover
var last_hovered_piece = null

# 🎬 Variables para animación de inicio
var intro_playing = true

# Turn counter for disruption system
var turn_count = 0
var countdown = 0
var countdown_start = 0
var level = "ES1"
@onready var grid_container = $GridContainer
@onready var moves_label = $UI/TurnsLeftBack/MovesLeft/MovesLabel
@onready var hp_label = $UI/HPLabel
@onready var enemy_sprite = $UI/EnemySprite
@onready var stagelabel: Label = $UI/StageBack/Stage/StageLabel
@onready var cooldown_number: Label = $UI/Cooldown/CooldownNumber
@onready var type_base: Panel = $UI/PokePanel/Type
@onready var grid_ui: Control = $Grids


func _ready():
	var team_data = UserData.obtain_full_team()
	team = [
		{"id": str(team_data[0]["id"]), "level": team_data[0]["nivel"]},      # Bulbasaur forma 1
		{"id": str(team_data[1]["id"]), "level": team_data[1]["nivel"]},        # Charmander
		{"id": str(team_data[2]["id"]), "level": team_data[2]["nivel"]},        # Squirtle
		{"id": str(team_data[3]["id"]), "level": team_data[3]["nivel"]}         # Pikachu
	]
	print(team)
	for i in range(4):
		pass
	# 🎬 OCULTAR TODO AL INICIO
	grid_ui.modulate.a = 0.0  # Grid invisible
	$UI/TurnsLeftBack.modulate.a = 0.0  # Panel de movimientos
	$UI/StageBack.modulate.a = 0.0  # Panel de fase
	$UI/ScoreBack.modulate.a = 0.0
	$UI/Cooldown.modulate.a = 0.0  # Panel de cooldown
	$UI/HPLabel.modulate.a = 0.0  # Barra de HP
	$UI/EnemySprite.modulate.a = 0.0  # Sprite enemigo
	$UI/PokePanel.modulate.a = 0.0  # Panel de info enemigo
	
	load_pokemon_data()
	load_foe_data()
	setup_grid() 
	
	var foe_info = get_pokemon_info(foe["id"])
	var type_style = Functions.set_type_color(foe_info["type"])
	$UI/PokePanel/Type/TypeLabel.text = Translator.translate_type(foe_info["type"],TranslationServer.get_locale())
	$UI/PokePanel/Type.add_theme_stylebox_override("panel", type_style)
	load_foe_sprite()
	
	$UI/PokePanel/PokeLabel.text = foe_info["name"]
	countdown_start = foe["turns_for_interference"]
	countdown = countdown_start
	
	## Cargar configuración de nivel
	var levels_data = LevelDatabase.load_levels_from_json()
	var config = LevelDatabase.get_level_config_from_json(str(level), levels_data)
	initial_grid_config = config
	
	if initial_grid_config == null:
		initial_grid_config = GridInitialConfig.create_default()
	
	if initial_grid_config.validate():
		generate_board_from_config(initial_grid_config)
	else:
		push_error("Configuración inválida, usando generación por defecto")
		generate_initial_board()
	
	# 🔥 OCULTAR TODAS LAS PIEZAS DEL GRID AL INICIO
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != null:
				grid[y][x].modulate.a = 0.0
	
	update_ui()
	
	# 🎬 INICIAR ANIMACIÓN DE INTRO
	await play_intro_animation()
	


func load_pokemon_data():
	var file = FileAccess.open(POKEMON_DATA_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.get_data()
			pokemon_database = data
		file.close()
	else:
		push_error("No se pudo cargar pokemon_data.json")

func parse_pokemon_id(id_string: String) -> Dictionary:
	"""
	Parsea un ID tipo '503_1' y retorna {pokemon_id: 503, form_id: 1}
	Si no tiene forma, retorna {pokemon_id: 503, form_id: 0}
	"""
	if "_" in id_string:
		var parts = id_string.split("_")
		return {
			"pokemon_id": int(parts[0]),
			"form_id": int(parts[1])
		}
	else:
		return {
			"pokemon_id": int(id_string),
			"form_id": 0
		}

func get_pokemon_info(id_string: String) -> Dictionary:
	var parsed = parse_pokemon_id(id_string)
	var pokemon_id = parsed["pokemon_id"]
	var form_id = parsed["form_id"]
	
	var id_str = str(pokemon_id)
	
	if pokemon_database.has(id_str):
		var poke_data = pokemon_database[id_str]
		
		if form_id > 0:
			var form_str = str(form_id)
			if poke_data.has("forms") and poke_data["forms"].has(form_str):
				return poke_data["forms"][form_str]
		
		return poke_data
	
	return {
		"name": "Unknown",
		"type": "normal",
		"base_atk": 30,
		"max_atk": 50,
		"skill": "none"
	}

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
			var piece_type = randi() % 4
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
	var parsed = parse_pokemon_id(pokemon_data["id"])
	
	var piece = PokemonPiece.new()
	piece.setup(x, y, type, TILE_SIZE, parsed["pokemon_id"], pokemon_data["level"], parsed["form_id"])
	piece.position = grid_container.position + Vector2(x * TILE_SIZE, y * TILE_SIZE)
	piece.piece_pressed.connect(_on_piece_pressed)
	piece.piece_dragged.connect(_on_piece_dragged)
	piece.piece_released.connect(_on_piece_released)
	add_child(piece)
	grid[y][x] = piece

func calculate_attack_stat(base_atk: int, max_atk: int, level: int) -> int:
	var max_level = 10
	var atk_per_level = float(max_atk - base_atk) / (max_level - 1)
	var current_atk = base_atk + int(atk_per_level * (level - 1))
	return current_atk

func get_type_effectiveness(attacker_type: String, defender_type: String) -> float:
	if type_chart.has(attacker_type):
		if type_chart[attacker_type].has(defender_type):
			return type_chart[attacker_type][defender_type]
	return 1.0

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

	drag_offset = get_global_mouse_position() - piece.global_position

func _on_piece_dragged(piece, motion):
	
	if not dragging or selected_piece != piece:
		return
	if not is_instance_valid(piece):
		return
	if piece.get_parent() == null:
		return
	if dragging and !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_processing_matches == false:
		_on_piece_released(piece)
		return
	var mouse_pos = get_global_mouse_position()
	piece.global_position = mouse_pos - drag_offset

	check_hover_piece(piece)

func check_hover_piece(dragged_piece):
	"""Detecta si la pieza arrastrada está sobre otra pieza y activa animación"""
	var local_pos = dragged_piece.position - grid_container.position
	var hover_x = int(round(local_pos.x / TILE_SIZE))
	var hover_y = int(round(local_pos.y / TILE_SIZE))

	# Verificar límites
	if hover_x < 0 or hover_x >= GRID_WIDTH or hover_y < 0 or hover_y >= GRID_HEIGHT:
		if last_hovered_piece != null and is_instance_valid(last_hovered_piece):
			last_hovered_piece.animate_hover_exit()
			last_hovered_piece = null
		return

	var hovered_piece = grid[hover_y][hover_x]

	# Si pasamos sobre una pieza diferente
	if hovered_piece != null and hovered_piece != dragged_piece and is_instance_valid(hovered_piece):
		# Evitar hover sobre piezas que tengan interferencia
		if hovered_piece.interference_type != "":
			if last_hovered_piece != null and is_instance_valid(last_hovered_piece):
				last_hovered_piece.animate_hover_exit()
				last_hovered_piece = null
			return

		if hovered_piece != last_hovered_piece:
			# Salir de la pieza anterior
			if last_hovered_piece != null and is_instance_valid(last_hovered_piece):
				last_hovered_piece.animate_hover_exit()

			# Entrar en la nueva pieza
			hovered_piece.animate_hover_over()
			last_hovered_piece = hovered_piece
	elif hovered_piece == null or hovered_piece == dragged_piece:
		# No hay pieza o es la misma que arrastramos
		if last_hovered_piece != null and is_instance_valid(last_hovered_piece):
			last_hovered_piece.animate_hover_exit()
			last_hovered_piece = null

func _on_piece_released(piece):
	print("🟢 [RELEASE] Iniciando release")
	print("🟢 [RELEASE] can_move:", can_move, " | is_processing:", is_processing_matches)
	
	if not dragging or selected_piece != piece:
		print("🔴 [RELEASE] No dragging o pieza incorrecta - cleanup")
		finish_move_cleanup()
		return

	if not is_instance_valid(piece):
		print("🔴 [RELEASE] Pieza inválida - cleanup")
		finish_move_cleanup()
		return
	if piece.get_parent() == null:
		print("🔴 [RELEASE] Pieza sin parent - cleanup")
		finish_move_cleanup()
		return

	if not piece.can_be_moved():
		print("🔴 [RELEASE] Pieza no se puede mover - cleanup")
		piece.animate_release()
		dragging = false
		selected_piece = null
		piece.z_index = 0
		finish_move_cleanup()
		return

	if last_hovered_piece != null and is_instance_valid(last_hovered_piece):
		last_hovered_piece.animate_hover_exit()
		last_hovered_piece = null

	print("🟡 [RELEASE] Restaurando colores antes de bloquear")
	if dim_non_matching:
		restore_all_colors()

	print("🟡 [RELEASE] Bloqueando input: can_move=false, is_processing=true")
	can_move = false
	is_processing_matches = true

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

		# 🔥 PERMITIR MOVIMIENTO A CASILLAS VACÍAS (null)
		if other_piece == null:
			print("🟢 [RELEASE] Movimiento a casilla vacía")
			# Mover la pieza a la casilla vacía
			grid[drag_start_grid_y][drag_start_grid_x] = null
			grid[target_y][target_x] = piece
			
			piece.grid_x = target_x
			piece.grid_y = target_y
			
			var tween = create_tween()
			tween.tween_property(piece, "position",
				grid_container.position + Vector2(target_x * TILE_SIZE, target_y * TILE_SIZE), 0.2)
			await tween.finished
		
		elif not other_piece.can_be_moved():
			print("🔴 [RELEASE] Objetivo no se puede mover - devolviendo")
			piece.animate_release()
			var tween = create_tween()
			tween.tween_property(piece, "position",
				grid_container.position + Vector2(drag_start_grid_x * TILE_SIZE, drag_start_grid_y * TILE_SIZE), 0.2)
			await tween.finished
			finish_move_cleanup()
			return

		elif other_piece != piece and is_instance_valid(other_piece) and is_instance_valid(piece):
			print("🟢 [RELEASE] Swap válido")
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
			print("🟡 [RELEASE] Sin swap - devolviendo a origen")
			piece.grid_x = drag_start_grid_x
			piece.grid_y = drag_start_grid_y

			var tween = create_tween()
			tween.tween_property(piece, "position", drag_start_pos, 0.2)
			await tween.finished

	else:
		print("🟡 [RELEASE] Misma posición - devolviendo")
		var tween = create_tween()
		tween.tween_property(piece, "position",
			grid_container.position + Vector2(drag_start_grid_x * TILE_SIZE, drag_start_grid_y * TILE_SIZE), 0.2)
		await tween.finished

	var matches = find_all_matches()
	print("🔍 [RELEASE] Matches encontrados:", matches.size())

	if require_match_to_count and matches.is_empty():
		print("❌ [RELEASE] Sin matches - devolviendo pieza")
		Audiomanager.play_sfx("release_pokemon")
		await return_piece_to_start(piece)
		finish_move_cleanup()
		update_ui()
		return
	else:
		print("✅ [RELEASE] Con matches - procesando")
		Audiomanager.play_sfx("attack")
		moves_left -= 1
		update_ui()
		
		await process_matches()

		var should_apply_disruptions = (turn_count + 1) % foe["turns_for_interference"] == 0 and foe["hp"] > 0
		
		if should_apply_disruptions:
			print("👹 [RELEASE] Enemigo ataca después de matches")
			await enemy_attack_phase()

		turn_count += 1
		countdown -= 1
		
		if countdown == 0:
			reset_countdown()
		update_ui()
		print("✅ [RELEASE] Restaurando estado final")
		finish_move_cleanup()

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
	print("🔥 [PROCESS] ===== INICIANDO PROCESS_MATCHES =====")
	var total_damage = 0
	var combo_count = 0
	var first_match = true
	var did_dim = false
	var safety_counter = 0  # 🔥 CONTADOR DE SEGURIDAD
	var MAX_COMBOS = 50  # 🔥 LÍMITE DE SEGURIDAD

	while safety_counter < MAX_COMBOS:
		safety_counter += 1
		print("🔍 [PROCESS] BUSCANDO MATCHES... (Combo actual: ", combo_count, ") [Iteración: ", safety_counter, "]")
		var matches = find_all_matches()
		print("✅ [PROCESS] Matches encontrados: ", matches.size())
		
		if matches.is_empty():
			print("❌ [PROCESS] NO HAY MÁS MATCHES - SALIENDO DEL BUCLE")
			break
		
		combo_count += 1

		if combo_count == 1:
			pass
		else:
			Audiomanager.play_sfx("combo_" + str(clamp(combo_count - 1, 1, 20)))

		if combo_count > 1:
			await get_tree().create_timer(0.2).timeout
		
		if dim_non_matching and first_match:
			print("🌑 [PROCESS] Aplicando DIM a todas las piezas")
			dim_all_pieces()
			first_match = false
			did_dim = true
		
		print("💡 [PROCESS] Restaurando color de ", matches.size(), " piezas del match")
		for piece in matches:
			if is_instance_valid(piece):
				piece.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		await mark_matches_sequentially(matches)
		
		var damage = calculate_damage(matches, combo_count)
		total_damage += damage
		
		show_match_damage(matches, damage)
		
		var cleared_disruptions = await check_and_clear_adjacent_disruptions(matches)
		
		await get_tree().create_timer(0.25).timeout
		
		if combo_count > 1:
			show_combo_text(combo_count, damage)
		
		print("💥 [PROCESS] Eliminando ", matches.size(), " piezas")
		for piece in matches:
			if not is_instance_valid(piece):
				continue
			
			# 🔥 Limpiar barriers e interferencias SINCRÓNICAMENTE
			if piece.interference_type == "barrier":
				piece.clear_interference_sync()
			
			if piece.interference_type == "cloud":
				if piece.has_method("clear_cloud_from_grid"):
					piece.clear_cloud_from_grid()
			
			grid[piece.grid_y][piece.grid_x] = null
			piece.queue_free()
		
		await get_tree().create_timer(0.1).timeout
		print("⬇️ [PROCESS] Llamando a drop_and_fill_pieces()")
		await drop_and_fill_pieces()
		print("⬆️ [PROCESS] drop_and_fill_pieces() completado")

	if safety_counter >= MAX_COMBOS:
		print("⚠️ [PROCESS] LÍMITE DE SEGURIDAD ALCANZADO - FORZANDO SALIDA")

	print("🎨 [PROCESS] Restaurando todos los colores al final")
	restore_all_colors()
	
	if total_damage > 0:
		deal_damage(total_damage)
		show_damage_text(total_damage)
	
	if combo_count > 1:
		show_final_combo_message(combo_count)
	
	print("🔥 [PROCESS] ===== PROCESS_MATCHES COMPLETADO =====")


		
func find_all_matches() -> Array:
	var all_matched_pieces = {}
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] == null:
				continue
			
			var piece = grid[y][x]
			
			# Skip pieces that can't be matched (rock/block disruptions)
			if not piece.is_matchable():
				continue
			
			# Check horizontal matches
			var h_count = 1
			var h_pieces = [piece]
			for i in range(x + 1, GRID_WIDTH):
				if grid[y][i] != null and grid[y][i].is_matchable() and pieces_can_match(piece, grid[y][i]):
					h_count += 1
					h_pieces.append(grid[y][i])
				else:
					break
			
			if h_count >= 3:
				for p in h_pieces:
					all_matched_pieces[p] = true
			
			# Check vertical matches
			var v_count = 1
			var v_pieces = [piece]
			for i in range(y + 1, GRID_HEIGHT):
				if grid[i][x] != null and grid[i][x].is_matchable() and pieces_can_match(piece, grid[i][x]):
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
	
	print("🎯 find_all_matches() retorna ", matches.size(), " piezas")
	for piece in matches:
		print("   - Pieza en [", piece.grid_x, ",", piece.grid_y, "] tipo:", piece.type, " matchable:", piece.is_matchable())
	
	return matches
	
	for piece in all_matched_pieces.keys():
		matches.append(piece)
	
	print("🎯 find_all_matches() retorna ", matches.size(), " piezas")
	for piece in matches:
		print("   - Pieza en [", piece.grid_x, ",", piece.grid_y, "] tipo:", piece.type, " matchable:", piece.is_matchable())
	
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
	
	for piece in matches:
		piece.animate_match_pop()

func calculate_damage(matches: Array, combo: int) -> int:
	var total_damage = 0
	Audiomanager.play_sfx("damage")
	
	for piece in matches:
		# 🔥 SKIP barriers para el cálculo de daño
		if piece.interference_type == "barrier":
			continue
		
		var pokemon_data = null
		var poke_info = null
		var level = 1
		
		# 🔥 NUEVO: Detectar si es un non_support_pokemon (type >= 4)
		if piece.type >= 4:
			# Es un Pokémon que no está en el equipo
			# Obtener su info directamente por su pokemon_id
			poke_info = get_pokemon_info(str(piece.pokemon_id))
			level = 1  # Los non_support siempre nivel 1
		else:
			# Es un Pokémon del equipo normal
			pokemon_data = team[piece.type]
			poke_info = get_pokemon_info(pokemon_data["id"])
			level = pokemon_data["level"]
		
		var attack = calculate_attack_stat(
			poke_info["base_atk"],
			poke_info["max_atk"],
			level
		)
		
		var effectiveness = get_type_effectiveness(poke_info["type"], foe_data["type"])
		print(poke_info["name"], " (", poke_info["type"], ") vs ", foe_data["type"])
		
		if effectiveness > 1:
			print("Super Efectivo")
		elif effectiveness == 1:
			print("Efectivo")
		elif effectiveness < 1:
			print("Poco efectivo")
		else:
			print("No hay efectividad...")
		
		var piece_damage = attack * effectiveness
		total_damage += piece_damage
	
	var combo_multiplier = 1.0 + (combo - 1) * 0.5
	total_damage = int(total_damage * combo_multiplier)
	
	return total_damage


func drop_and_fill_pieces():
	print("📦 [DROP] ===== INICIANDO DROP AND FILL =====")
	var all_tweens = []

	for x in range(GRID_WIDTH):
		print("📦 [DROP] Procesando columna ", x)
		
		# 🔥 PASO 1: Identificar barriers (no se mueven) - ordenadas de arriba a abajo
		var barrier_positions = []
		for y in range(GRID_HEIGHT):
			if grid[y][x] != null:
				var piece = grid[y][x]
				if piece.interference_type == "barrier":
					barrier_positions.append(y)
		
		barrier_positions.sort()  # De arriba (0) a abajo (5)
		print("📦 [DROP] Columna ", x, " tiene barriers en: ", barrier_positions)
		
		# 🔥 PASO 2: Dividir la columna en segmentos separados por barriers
		# Cada segmento es independiente
		var segments = []
		var current_segment_start = 0
		
		for barrier_y in barrier_positions:
			if barrier_y > current_segment_start:
				segments.append({"start": current_segment_start, "end": barrier_y - 1})
			current_segment_start = barrier_y + 1
		
		# Añadir último segmento (desde última barrier hasta el final)
		if current_segment_start < GRID_HEIGHT:
			segments.append({"start": current_segment_start, "end": GRID_HEIGHT - 1})
		
		print("📦 [DROP] Segmentos de columna: ", segments)
		
		# 🔥 PASO 3: Procesar cada segmento independientemente
		for segment in segments:
			var seg_start = segment["start"]
			var seg_end = segment["end"]
			
			print("📦 [DROP] Procesando segmento [", seg_start, "-", seg_end, "]")
			
			# Recolectar piezas móviles del segmento
			var pieces_in_segment: Array = []
			for y in range(seg_start, seg_end + 1):
				if grid[y][x] != null:
					var piece = grid[y][x]
					if piece.interference_type != "barrier":
						pieces_in_segment.append(piece)
						grid[y][x] = null
			
			print("📦 [DROP] Segmento tiene ", pieces_in_segment.size(), " piezas")
			
			# Identificar posiciones vacías en el segmento
			var empty_positions = []
			for y in range(seg_start, seg_end + 1):
				if grid[y][x] == null:
					empty_positions.append(y)
			
			empty_positions.sort()  # De arriba a abajo
			print("📦 [DROP] Posiciones vacías en segmento: ", empty_positions)
			
			# Calcular cuántas piezas nuevas necesitamos SOLO si es el primer segmento (arriba)
			var new_pieces: Array = []
			if seg_start == 0:  # Solo crear piezas nuevas en el segmento superior
				var missing = empty_positions.size() - pieces_in_segment.size()
				print("📦 [DROP] Segmento necesita ", missing, " piezas nuevas")
				
				for i in range(missing):
					var piece_type = randi() % 4
					var pokemon_data = team[piece_type]
					var parsed = parse_pokemon_id(pokemon_data["id"])
					
					var piece = PokemonPiece.new()
					piece.setup(x, 0, piece_type, TILE_SIZE, parsed["pokemon_id"], pokemon_data["level"], parsed["form_id"])
					var start_y = -missing + i
					piece.position = grid_container.position + Vector2(x * TILE_SIZE, start_y * TILE_SIZE)
					
					piece.scale = Vector2(0.0, 0.0)
					
					if dim_non_matching:
						piece.modulate = Color(0.4, 0.4, 0.4, 0.0)
					else:
						piece.modulate = Color(1.0, 1.0, 1.0, 0.0)

					piece.piece_pressed.connect(_on_piece_pressed)
					piece.piece_dragged.connect(_on_piece_dragged)
					piece.piece_released.connect(_on_piece_released)
					add_child(piece)
					
					var pop_tween = create_tween()
					pop_tween.set_ease(Tween.EASE_OUT)
					pop_tween.set_trans(Tween.TRANS_BACK)
					pop_tween.set_parallel(true)
					pop_tween.tween_property(piece, "scale", Vector2(1.0, 1.0), 0.2)
					pop_tween.tween_property(piece, "modulate:a", 1.0, 0.2)

					new_pieces.append(piece)
			
			# Combinar: nuevas primero (arriba) + existentes (abajo)
			var all_segment_pieces: Array = new_pieces + pieces_in_segment
			
			print("📦 [DROP] Total piezas en segmento: ", all_segment_pieces.size())
			
			# Asignar piezas de abajo hacia arriba (llenar desde el fondo del segmento)
			var reversed_positions = empty_positions.duplicate()
			reversed_positions.reverse()  # De abajo a arriba
			
			var pieces_reversed = all_segment_pieces.duplicate()
			pieces_reversed.reverse()  # Las últimas piezas van abajo
			
			for i in range(min(reversed_positions.size(), pieces_reversed.size())):
				var target_y = reversed_positions[i]
				var piece = pieces_reversed[i]
				
				# Asignar al grid
				grid[target_y][x] = piece
				piece.grid_x = x
				piece.grid_y = target_y
				
				print("📦 [DROP] Asignando pieza a [", target_y, ",", x, "]")
				
				# Calcular animación de caída
				var current_y_pos = (piece.position.y - grid_container.position.y) / TILE_SIZE
				var distance = target_y - current_y_pos
				
				if distance > 0:
					var speed = 600.0
					var pixels_to_fall = distance * TILE_SIZE
					var fall_time = min(pixels_to_fall / speed, 0.3)
					
					var fall_tween = create_tween()
					fall_tween.set_parallel(true)
					
					fall_tween.tween_property(
						piece, "position:y",
						grid_container.position.y + (target_y * TILE_SIZE),
						fall_time
					).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
					
					fall_tween.tween_property(
						piece, "scale",
						Vector2(0.9, 1.2),
						fall_time * 0.1
					).set_ease(Tween.EASE_OUT)
					
					fall_tween.chain().tween_callback(piece.animate_land_squish)
					
					all_tweens.append(fall_tween)
				else:
					# Sin caída, solo ajustar posición visual
					piece.position = grid_container.position + Vector2(x * TILE_SIZE, target_y * TILE_SIZE)
					piece.scale = Vector2(1.0, 1.0)

	if all_tweens.size() > 0:
		print("📦 [DROP] Esperando a ", all_tweens.size(), " tweens")
		await all_tweens[-1].finished
		await get_tree().create_timer(0.05).timeout
	else:
		print("📦 [DROP] Sin tweens que esperar")
	
	print("📦 [DROP] ===== DROP AND FILL COMPLETADO =====")
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
	print("🎨 [RESTORE] Restaurando colores de todas las piezas")
	var restored_count = 0
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != null and is_instance_valid(grid[y][x]):
				grid[y][x].modulate = Color(1.0, 1.0, 1.0, 1.0)
				restored_count += 1
	print("🎨 [RESTORE] Restaurados:", restored_count, " piezas")
				
				
func finish_move_cleanup():
	print("🔧 [CLEANUP] Iniciando cleanup")
	print("🔧 [CLEANUP] Estado ANTES: can_move=", can_move, " | is_processing=", is_processing_matches)
	
	is_processing_matches = false
	can_move = true

	if dim_non_matching:
		print("🔧 [CLEANUP] Restaurando colores")
		restore_all_colors()

	if last_hovered_piece != null and is_instance_valid(last_hovered_piece):
		last_hovered_piece.animate_hover_exit()
		last_hovered_piece = null
	
	print("🔧 [CLEANUP] Estado DESPUÉS: can_move=", can_move, " | is_processing=", is_processing_matches)

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
	combo_text.text = "¡COMBO x" + str(combo) + "!"
	combo_text.add_theme_font_size_override("font_size", 36 + combo * 2)
	combo_text.modulate = Color(1, 0.9 - (combo * 0.05), 0, 1)
	combo_text.position = Vector2(250, 320 - combo * 5)
	combo_text.scale = Vector2(0.8, 0.8)
	add_child(combo_text)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(combo_text, "scale", Vector2(1.3, 1.3), 0.2)
	tween.chain().tween_property(combo_text, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(combo_text, "position:y", combo_text.position.y - 30, 0.6)
	tween.tween_property(combo_text, "modulate:a", 0.0, 0.6).set_delay(0.2)
	
	await tween.finished
	combo_text.queue_free()
	
	var damage_text = Label.new()
	damage_text.text = "+" + str(damage) + " daño"
	damage_text.add_theme_font_size_override("font_size", 28)
	damage_text.modulate = Color(1, 1, 0.5, 1)
	damage_text.position = Vector2(270, 350)
	add_child(damage_text)
	
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(damage_text, "position:y", damage_text.position.y - 40, 0.6)
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
	moves_label.text = str(moves_left)
	stagelabel.text = str(level)
	hp_label.text = "HP Enemigo: " + str(foe["hp"]) + "/" + str(foe["max_hp"])
	cooldown_number.text = str(countdown)
func check_game_over():
	if foe["hp"] <= 0:
		print("¡Victoria!")
		await get_tree().create_timer(1.0).timeout
		get_tree().reload_current_scene()
	elif moves_left <= 0:
		print("¡Derrota!")
		await get_tree().create_timer(1.0).timeout
		get_tree().reload_current_scene()

func show_final_combo_message(combo_count: int):
	var message := ""
	var sound_name := ""
	
	match combo_count:
		1,2:
			pass
		3,4:
			message = "¡Genial!"
			sound_name = "combo_end_1"
		5,6,7,8,9:
			message = "¡Fantástico!"
			sound_name = "combo_end_2"
		10,11,12,13,14,15,16,17,18,19:
			message = "¡Increíble!"
			sound_name = "combo_end_3"
		_:
			message = "¡Asombroso!"
			sound_name = "combo_end_4"
	
	Audiomanager.play_sfx(sound_name)
	
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 48 + combo_count * 2)
	label.modulate = Color(1, 1, 0.8, 1)
	label.position = Vector2(200, 250)
	label.scale = Vector2(0.7, 0.7)
	add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.3)
	tween.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.4)
	
	await tween.finished
	label.queue_free()

# Disruption System Functions
func apply_disruption_pattern(pattern: Dictionary):
	"""Applies a disruption pattern to the grid"""
	var disruption_type = pattern.get("type", "")
	var positions = pattern.get("positions", [])
	var count = pattern.get("count", 1)
	var hp = pattern.get("hp", 1)
	var pokemon_id = pattern.get("pokemon_id", -1)
	
	# Convert pokemon_id to integer if it's a string
	if typeof(pokemon_id) == TYPE_STRING:
		pokemon_id = int(pokemon_id)
	elif pokemon_id == -1:
		pokemon_id = -1
	
	if disruption_type == "":
		return
	
	# 🔥 USAR POSICIONES RESUELTAS SI EXISTEN (de show_disruption_warning_animation)
	if pattern.has("resolved_positions"):
		positions = pattern["resolved_positions"]
	elif positions is String and positions == "random":
		positions = get_random_available_positions(count)
	elif typeof(positions) == TYPE_ARRAY and positions.size() == 0:
		return
	
	# Apply disruption to each position
	for pos in positions:
		if pos is Array and pos.size() == 2:
			var row = pos[0]
			var col = pos[1]
			
			if row >= 0 and row < GRID_HEIGHT and col >= 0 and col < GRID_WIDTH:
				if grid[row][col] != null:
					apply_disruption_to_piece(grid[row][col], disruption_type, hp, pokemon_id)

func get_random_available_positions(count: int) -> Array:
	"""Gets random available positions for disruptions"""
	var available_positions = []
	
	# Find all empty positions (positions without disruptions)
	for row in range(GRID_HEIGHT):
		for col in range(GRID_WIDTH):
			if grid[row][col] != null:
				var piece = grid[row][col]
				# Check if position doesn't have rock/block disruptions
				if piece.interference_type != "rock" and piece.interference_type != "block":
					available_positions.append([row, col])
	
	# Shuffle available positions
	for i in range(available_positions.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = available_positions[i]
		available_positions[i] = available_positions[j]
		available_positions[j] = temp
	
	# Return up to 'count' positions
	return available_positions.slice(0, min(count, available_positions.size()))

func apply_disruption_to_piece(piece: PokemonPiece, disruption_type: String, hp: int, pokemon_id: int):
	"""Applies a specific disruption to a piece"""
	match disruption_type:
		"rock", "block":
			# Reemplazar completamente la pieza por la disrupción
			var x = piece.grid_x
			var y = piece.grid_y
			piece.queue_free()
			grid[y][x] = null
			
			# Crear nueva pieza de disrupción
			var disruption_piece = PokemonPiece.new()
			disruption_piece.setup_as_disruption(x, y, disruption_type, TILE_SIZE, hp)
			disruption_piece.position = grid_container.position + Vector2(x * TILE_SIZE, y * TILE_SIZE)
			disruption_piece.piece_pressed.connect(_on_piece_pressed)
			disruption_piece.piece_dragged.connect(_on_piece_dragged)
			disruption_piece.piece_released.connect(_on_piece_released)
			add_child(disruption_piece)
			grid[y][x] = disruption_piece
		
		"barrier":
			# Congelar el pokemon existente (no afectado por gravedad)
			piece.set_interference(disruption_type, hp)
		
		"cloud":
			create_cloud_overlay(piece.grid_x, piece.grid_y)
		
		"non_support_pokemon":
			# 🔥 NUEVO: Reemplazar el Pokémon por uno que NO está en el equipo
			var x = piece.grid_x
			var y = piece.grid_y
			piece.queue_free()
			grid[y][x] = null
			if pokemon_id == -1:
				var available_pokemon = []
				for pokemon_key in pokemon_database.keys():
			# Permite claves tipo "503" o "503_1"
					var parsed = parse_pokemon_id(pokemon_key)
					if not is_pokemon_in_team(parsed["pokemon_id"]):
						available_pokemon.append(pokemon_key)

				if available_pokemon.size() > 0:
					pokemon_id = available_pokemon[randi() % available_pokemon.size()]
				else:
					pokemon_id = int("19")  # Fallback como string
			
			# Crear un nuevo Pokémon normal (no interferencia)
			var parsed = parse_pokemon_id(str(pokemon_id))
			var actual_id = parsed["pokemon_id"]
			var form_id = parsed["form_id"]
			# Usar type = 4 para indicar que es un quinto "tipo" (no support)
			# Pero realmente no importa el type, porque es un Pokémon independiente
			var new_piece = PokemonPiece.new()
	# type = 4 para indicar que es un Pokémon no del equipo
			new_piece.setup(x, y, 4, TILE_SIZE, actual_id, 1, form_id)
			new_piece.position = grid_container.position + Vector2(x * TILE_SIZE, y * TILE_SIZE)

			new_piece.piece_pressed.connect(_on_piece_pressed)
			new_piece.piece_dragged.connect(_on_piece_dragged)
			new_piece.piece_released.connect(_on_piece_released)
			add_child(new_piece)
			grid[y][x] = new_piece


func is_pokemon_in_team(pokemon_id: int) -> bool:
	"""Checks if a pokemon is in the player's team"""
	for pokemon in team:
		var parsed = parse_pokemon_id(pokemon["id"])
		if parsed["pokemon_id"] == pokemon_id:
			return true
	return false

func check_and_clear_adjacent_disruptions(matched_pieces: Array):
	"""Checks for disruptions adjacent to matched pieces and clears clouds"""
	var directions = [[-1, 0], [1, 0], [0, -1], [0, 1]]
	var cleared_disruptions = []
	var pieces_to_clear = []
	
	# 🔥 PASO 1: Recopilar todas las piezas a eliminar SIN esperar
	for piece in matched_pieces:
		var row = piece.grid_y
		var col = piece.grid_x
		
		for dir in directions:
			var new_row = row + dir[0]
			var new_col = col + dir[1]
			
			if new_row >= 0 and new_row < GRID_HEIGHT and new_col >= 0 and new_col < GRID_WIDTH:
				if grid[new_row][new_col] != null:
					var adjacent_piece = grid[new_row][new_col]
					
					# Rock y Block se debilitan
					if adjacent_piece.interference_type in ["rock", "block"]:
						if adjacent_piece.weaken_interference():
							# Agregar a la lista pero NO esperar todavía
							pieces_to_clear.append(adjacent_piece)
							cleared_disruptions.append(adjacent_piece)
	
	# 🔥 PASO 2: Animar y eliminar TODAS las piezas en paralelo
	if pieces_to_clear.size() > 0:
		for piece in pieces_to_clear:
			piece.animate_match_pop()
		
		# Solo una espera para TODAS las animaciones
		await get_tree().create_timer(0.1).timeout
		
		for piece in pieces_to_clear:
			grid[piece.grid_y][piece.grid_x] = null
			piece.queue_free()
	
	return cleared_disruptions

func apply_multiple_disruption_patterns(patterns: Array):
	"""Applies multiple disruption patterns at once"""
	for pattern in patterns:
		apply_disruption_pattern(pattern)

# Example disruption patterns for testing
func get_example_disruption_patterns() -> Array:
	return [
		{"type": "rock", "positions": [[1,1], [3,4]]},
		{"type": "block", "positions": [[2,2]], "hp": 2},
		{"type": "barrier", "positions": [[0,0], [5,5]]},
		{"type": "cloud", "positions": "random", "count": 3},
		{"type": "non_support_pokemon", "pokemon_id": 19, "positions": "random", "count": 2}
	]

# Test functions for disruption system
func test_disruption_system():
	"""Test function to apply various disruptions"""
	print("Testing disruption system...")
	
	# Test 1: Apply rocks at fixed positions
	var rock_pattern = {"type": "rock", "positions": [[1,1], [3,3], [5,0]]}
	apply_disruption_pattern(rock_pattern)
	print("Applied rocks at positions: [1,1], [3,3], [5,0]")
	
	# Wait a bit
	await get_tree().create_timer(1.0).timeout
	
	# Test 2: Apply random clouds
	var cloud_pattern = {"type": "cloud", "positions": "random", "count": 4}
	apply_disruption_pattern(cloud_pattern)
	print("Applied 4 random clouds")
	
	await get_tree().create_timer(1.0).timeout
	
	# Test 3: Apply barrier
	var barrier_pattern = {"type": "barrier", "positions": [[0,0], [2,2]]}
	apply_disruption_pattern(barrier_pattern)
	print("Applied barriers at positions: [0,0], [2,2]")
	
	await get_tree().create_timer(1.0).timeout
	
	# Test 4: Apply block with 2 HP
	var block_pattern = {"type": "block", "positions": [[4,4]], "hp": 2}
	apply_disruption_pattern(block_pattern)
	print("Applied block at position [4,4] with 2 HP")
	
	print("Disruption test completed!")

func apply_random_disruption():
	"""Apply a random disruption pattern"""
	var patterns = [
		{"type": "rock", "positions": "random", "count": randi_range(2, 4)},
		{"type": "cloud", "positions": "random", "count": randi_range(2, 5)},
		{"type": "barrier", "positions": "random", "count": randi_range(1, 3)},
		{"type": "block", "positions": "random", "count": randi_range(1, 2), "hp": 2},
		{"type": "non_support_pokemon", "positions": "random", "count": randi_range(1, 3)}
	]
	
	var random_pattern = patterns[randi() % patterns.size()]
	apply_disruption_pattern(random_pattern)
	print("Applied random disruption: ", random_pattern.type)

func get_disruption_summary() -> Dictionary:
	"""Get a summary of current disruptions on the board"""
	var summary = {
		"total_disruptions": 0,
		"rocks": 0,
		"blocks": 0,
		"barriers": 0,
		"clouds": 0,
		"non_support_pokemon": 0
	}
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != null:
				var piece = grid[y][x]
				if piece.interference_type != "":
					summary["total_disruptions"] += 1
					match piece.interference_type:
						"rock":
							summary["rocks"] += 1
						"block":
							summary["blocks"] += 1
						"barrier":
							summary["barriers"] += 1
						"cloud":
							summary["clouds"] += 1
						"non_support_pokemon":
							summary["non_support_pokemon"] += 1
	
	return summary

# Enemy turn disruption system
func enemy_attack_phase():
	print("👹 [ENEMY] Fase de ataque enemigo iniciada")
	
	await show_enemy_attack_effect()
	
	await show_disruption_warning_animation()
	
	enemy_turn_apply_disruptions()
	
	print("👹 [ENEMY] Restaurando colores después de ataque")
	if dim_non_matching:
		restore_all_colors()
	
	await get_tree().create_timer(0.5).timeout
	print("👹 [ENEMY] Fase de ataque completada")

func show_disruption_warning_animation():
	
	var patterns = foe["disruption_patterns"]
	if patterns.size() == 0:
		return
	
	var pattern_index = turn_count % patterns.size()
	var pattern = patterns[pattern_index]
	
	# 🔥 CALCULAR POSICIONES ANTES DE MOSTRAR ADVERTENCIAS
	var positions = pattern.get("positions", [])
	var count = pattern.get("count", 1)
	var affected_positions = []
	
	if positions is String and positions == "random":
		affected_positions = get_random_available_positions(count)
		# 🔥 GUARDAR LAS POSICIONES RANDOM PARA USARLAS DESPUÉS
		pattern["resolved_positions"] = affected_positions
	elif typeof(positions) == TYPE_ARRAY:
		affected_positions = positions
	
	# Mostrar advertencias en todas las posiciones afectadas
	var warning_overlays = []
	for pos in affected_positions:
		if pos is Array and pos.size() == 2:
			var row = pos[0]
			var col = pos[1]
			
			if row >= 0 and row < GRID_HEIGHT and col >= 0 and col < GRID_WIDTH:
				var warning_overlay = ColorRect.new()
				warning_overlay.color = Color(1.0, 0.0, 0.0, 0.0)
				warning_overlay.size = Vector2(TILE_SIZE, TILE_SIZE)
				warning_overlay.position = grid_container.position + Vector2(col * TILE_SIZE, row * TILE_SIZE)
				warning_overlay.z_index = 5
				add_child(warning_overlay)
				warning_overlays.append(warning_overlay)
				Audiomanager.play_sfx("warning_disruption")
	# Animar todas las advertencias simultáneamente
	if warning_overlays.size() > 0:
		for overlay in warning_overlays:
			var tween = create_tween()
			tween.set_loops(3)
			tween.tween_property(overlay, "color:a", 0.5, 0.3)
			tween.tween_property(overlay, "color:a", 0.0, 0.3)
		
		await get_tree().create_timer(1.8).timeout
		
		for overlay in warning_overlays:
			overlay.queue_free()
			
func show_enemy_attack_effect():
	Audiomanager.play_sfx("disruption")
	"""Show visual effect for enemy attack"""
	var enemy_sprite = get_node("UI/EnemySprite")
	if enemy_sprite == null:
		return
	
	# Guardar posición original
	var original_pos = enemy_sprite.position
	
	# Crear texto de ataque
	var attack_label = Label.new()
	attack_label.text = "¡ATAQUE!"
	attack_label.add_theme_font_size_override("font_size", 42)
	attack_label.modulate = Color(1, 0.2, 0.2, 0)
	attack_label.position = Vector2(enemy_sprite.position.x - 50, enemy_sprite.position.y + 50)
	attack_label.z_index = 100
	add_child(attack_label)
	
	# Animación del sprite (shake más pronunciado)
	var tween_sprite = create_tween()
	tween_sprite.set_loops(4)
	tween_sprite.tween_property(enemy_sprite, "position:x", original_pos.x + 10, 0.05)
	tween_sprite.tween_property(enemy_sprite, "position:x", original_pos.x - 10, 0.05)
	
	# Animación del texto
	var tween_text = create_tween()
	tween_text.set_parallel(true)
	tween_text.tween_property(attack_label, "modulate:a", 1.0, 0.2)
	tween_text.tween_property(attack_label, "scale", Vector2(1.3, 1.3), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween_text.chain().tween_property(attack_label, "modulate:a", 0.0, 0.3).set_delay(0.2)
	
	# Esperar a que terminen las animaciones
	await tween_sprite.finished
	
	# Restaurar posición
	enemy_sprite.position = original_pos
	
	await tween_text.finished
	attack_label.queue_free()

func enemy_turn_apply_disruptions():
	"""Apply disruptions during enemy turn based on foe data patterns"""
	if not foe.has("disruption_patterns") or foe["disruption_patterns"].size() == 0:
		return null
	
	var patterns = foe["disruption_patterns"]
	var current_pattern = null
	
	# Select pattern based on turn count or other conditions
	if patterns.size() > 0:
		var pattern_index = turn_count % patterns.size()
		current_pattern = patterns[pattern_index]
		apply_disruption_pattern(current_pattern)
		print("Enemy applied disruption pattern after attack: ", current_pattern.type if current_pattern.has("type") else "unknown")
	
	return current_pattern

func get_enemy_disruption_patterns() -> Array:
	"""Get predefined enemy disruption patterns that can be used during enemy turns"""
	return [
		# Early game patterns (turns 1-3)
		{"type": "rock", "positions": "random", "count": 2},
		{"type": "cloud", "positions": "random", "count": 3},
		
		# Mid game patterns (turns 4-6)
		{"type": "barrier", "positions": "random", "count": 2},
		{"type": "non_support_pokemon", "positions": "random", "count": 2},
		
		# Late game patterns (turns 7+)
		{"type": "block", "positions": "random", "count": 2, "hp": 2},
		{"type": "rock", "positions": "random", "count": 4},
		
		# Complex patterns
		{"type": "barrier", "positions": [[0,0], [0,1], [1,0], [1,1]]},  # 2x2 block
		{"type": "cloud", "positions": "random", "count": 5},
		{"type": "non_support_pokemon", "positions": "random", "count": 3}
	]

func apply_progressive_disruptions(difficulty_level: int):
	"""Apply disruptions based on difficulty level or progression"""
	match difficulty_level:
		1:  # Easy
			apply_disruption_pattern({"type": "rock", "positions": "random", "count": 1})
			apply_disruption_pattern({"type": "cloud", "positions": "random", "count": 1})
		2:  # Medium
			apply_disruption_pattern({"type": "rock", "positions": "random", "count": 2})
			apply_disruption_pattern({"type": "barrier", "positions": "random", "count": 1})
		3:  # Hard
			apply_disruption_pattern({"type": "block", "positions": "random", "count": 1, "hp": 2})
			apply_disruption_pattern({"type": "non_support_pokemon", "positions": "random", "count": 2})
		4:  # Very Hard
			apply_multiple_disruption_patterns([
				{"type": "rock", "positions": "random", "count": 3},
				{"type": "barrier", "positions": "random", "count": 2},
				{"type": "cloud", "positions": "random", "count": 3}
			])
		_:  # Default
			apply_random_disruption()
func create_cloud_overlay(grid_x: int, grid_y: int):
	"""Crea un sprite de nube que se superpone a una casilla específica"""
	var cloud_key = str(grid_x) + "," + str(grid_y)
	
	# Si ya hay una nube en esa casilla, no crear otra
	if grid_clouds.has(cloud_key):
		return
	
	var cloud_sprite = TextureRect.new()
	cloud_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_sprite.size = Vector2(TILE_SIZE, TILE_SIZE)
	cloud_sprite.position = grid_container.position + Vector2(grid_x * TILE_SIZE, grid_y * TILE_SIZE)
	cloud_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloud_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cloud_sprite.z_index = 15  # Por encima de las piezas normales
	cloud_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	var texture_path = "res://assets/sprites/grid/disruptions/Black_Cloud.png"
	if ResourceLoader.exists(texture_path):
		cloud_sprite.texture = load(texture_path)
	
	add_child(cloud_sprite)
	
	# Animación de aparición
	cloud_sprite.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(cloud_sprite, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Guardar referencia
	grid_clouds[cloud_key] = cloud_sprite
	
	Audiomanager.play_sfx("grab_pokemon")
func remove_cloud_overlay(grid_x: int, grid_y: int):
	"""Elimina una nube de una casilla específica"""
	var cloud_key = str(grid_x) + "," + str(grid_y)
	
	if grid_clouds.has(cloud_key):
		var cloud_sprite = grid_clouds[cloud_key]
		
		if is_instance_valid(cloud_sprite):
			# Animación de desaparición
			var tween = create_tween()
			tween.tween_property(cloud_sprite, "scale", Vector2(0.0, 0.0), 0.2).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(cloud_sprite, "modulate:a", 0.0, 0.2)
			await tween.finished
			cloud_sprite.queue_free()
		
		grid_clouds.erase(cloud_key)
		Audiomanager.play_sfx("release_pokemon")
		

func test_non_support_pokemon():
	"""Función de prueba para verificar que non_support_pokemon funciona correctamente"""
	print("=== PRUEBA DE NON_SUPPORT_POKEMON ===")
	
	# Aplicar 3 non_support_pokemon aleatorios
	var pattern = {
		"type": "non_support_pokemon",
		"positions": "random",
		"count": 3
	}
	apply_disruption_pattern(pattern)
	
	print("Se aplicaron 3 non_support_pokemon al tablero")
	print("Verifica visualmente que:")
	print("1. Son Pokémon diferentes a los de tu equipo")
	print("2. Se pueden mover y combinar normalmente")
	print("3. Hacen daño cuando coinciden 3 o más")
	print("=====================================")

func generate_board_from_config(config: GridInitialConfig):
	"""Genera el tablero inicial basado en una configuración"""
	print("🎮 [GRID INIT] Generando tablero desde configuración")
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell = config.grid_config[y][x]
			
			match cell.type:
				GridInitialConfig.CellType.DEFAULT:
					var piece_type = randi() % 4
					while check_would_match(x, y, piece_type):
						piece_type = randi() % 4
					create_piece(x, y, piece_type)
				
				GridInitialConfig.CellType.TEAM_POKEMON:
					if cell.team_index >= 0 and cell.team_index < team.size():
						create_piece(x, y, cell.team_index)
				
				GridInitialConfig.CellType.NON_SUPPORT:
					create_non_support_piece(x, y, cell.pokemon_id)
				
				GridInitialConfig.CellType.ROCK:
					create_disruption_piece(x, y, "rock", cell.hp)
				
				GridInitialConfig.CellType.BLOCK:
					create_disruption_piece(x, y, "block", cell.hp)
				
				GridInitialConfig.CellType.BARRIER:
					var piece_type = randi() % 4
					create_piece(x, y, piece_type)
					if grid[y][x] != null:
						grid[y][x].set_interference("barrier", cell.hp)
				
				GridInitialConfig.CellType.CLOUD:
					var piece_type = randi() % 4
					create_piece(x, y, piece_type)
					create_cloud_overlay(x, y)
				
				GridInitialConfig.CellType.EMPTY:
					grid[y][x] = null

func create_non_support_piece(x: int, y: int, pokemon_id: int):
	"""Crea una pieza de Pokémon no soporte"""
	var piece = PokemonPiece.new()
	piece.setup(x, y, 4, TILE_SIZE, pokemon_id, 1, 0)
	piece.position = grid_container.position + Vector2(x * TILE_SIZE, y * TILE_SIZE)
	piece.piece_pressed.connect(_on_piece_pressed)
	piece.piece_dragged.connect(_on_piece_dragged)
	piece.piece_released.connect(_on_piece_released)
	add_child(piece)
	grid[y][x] = piece

func create_disruption_piece(x: int, y: int, disruption_type: String, hp: int):
	
	"""Crea una pieza de interferencia (rock/block)"""
	var piece = PokemonPiece.new()
	piece.setup_as_disruption(x, y, disruption_type, TILE_SIZE, hp)
	piece.position = grid_container.position + Vector2(x * TILE_SIZE, y * TILE_SIZE)
	piece.piece_pressed.connect(_on_piece_pressed)
	piece.piece_dragged.connect(_on_piece_dragged)
	piece.piece_released.connect(_on_piece_released)
	add_child(piece)
	grid[y][x] = piece
func reset_countdown():
	countdown = countdown_start


### FOE


func load_foe_sprite():
	var foe_form = parse_foe_id(foe["id"])
	print("Forma del foe: ",foe_form)
	var sprite_path = "res://assets/sprites/pokemon/icons/" + str(foe["id"])
	sprite_path += ".png"
	print("Supuesto path del sprite del foe: ",sprite_path)

	
	if ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		
		enemy_sprite.texture = texture
	start_enemy_idle_animation()


func parse_foe_id(id_string: String) -> int:
	"""
	Parsea un ID tipo '503_1' y retorna {pokemon_id: 503, form_id: 1}
	Si no tiene forma, retorna {pokemon_id: 503, form_id: 0}
	"""
	if "_" in id_string:
		var parts = id_string.split("_")
		return int(parts[1])
	else:
		return 0
# Animación idle del enemigo tipo Pokémon Shuffle
func start_enemy_idle_animation():
	if enemy_sprite == null:
		return
	
	var original_pos = enemy_sprite.position
	var original_scale = enemy_sprite.scale
	
	await enemy_idle_jump_loop(original_pos, original_scale)


func enemy_idle_jump_loop(original_pos: Vector2, original_scale: Vector2):
	"""
	Idle tipo Pokémon:
	1. Se aplasta (squash)
	2. Salta (stretch leve)
	3. Recupera la escala mientras cae
	4. Rebote pequeño al aterrizar
	"""
	while is_instance_valid(enemy_sprite) and enemy_sprite.get_parent() != null:
		
		# 🟠 FASE 1: Preparación (squash)
		var prep_tween = create_tween()
		prep_tween.set_ease(Tween.EASE_IN_OUT)
		prep_tween.set_trans(Tween.TRANS_SINE)
		prep_tween.tween_property(enemy_sprite, "scale:y", original_scale.y * 0.85, 0.12)
		prep_tween.tween_property(enemy_sprite, "position:y", original_pos.y + 3, 0.12)
		await prep_tween.finished
		
		# 🔵 FASE 2: Salto (stretch leve)
		var jump_tween = create_tween()
		jump_tween.set_ease(Tween.EASE_OUT)
		jump_tween.set_trans(Tween.TRANS_SINE)
		jump_tween.tween_property(enemy_sprite, "scale:y", original_scale.y * 1.05, 0.18)
		jump_tween.tween_property(enemy_sprite, "position:y", original_pos.y - 16, 0.18)
		await jump_tween.finished
		
		# 🟢 FASE 3: Caída (vuelve a escala normal durante la bajada)
		var fall_tween = create_tween()
		fall_tween.set_parallel(true)
		fall_tween.set_ease(Tween.EASE_IN)
		fall_tween.set_trans(Tween.TRANS_SINE)
		fall_tween.tween_property(enemy_sprite, "position:y", original_pos.y + 2, 0.20)
		fall_tween.tween_property(enemy_sprite, "scale:y", original_scale.y, 0.20)
		await fall_tween.finished
		
		# 🟣 FASE 4: Rebote leve (mini squash al aterrizar)
		var rebound_tween = create_tween()
		rebound_tween.set_parallel(true)
		rebound_tween.set_ease(Tween.EASE_OUT)
		rebound_tween.set_trans(Tween.TRANS_SINE)
		rebound_tween.tween_property(enemy_sprite, "position:y", original_pos.y, 0.12)
		rebound_tween.tween_property(enemy_sprite, "scale:y", original_scale.y * 0.96, 0.12)
		await rebound_tween.finished
		
		# 🩵 FASE 5: Recuperación final (vuelve suave a la forma exacta)
		var settle_tween = create_tween()
		settle_tween.set_ease(Tween.EASE_OUT)
		settle_tween.set_trans(Tween.TRANS_SINE)
		settle_tween.tween_property(enemy_sprite, "scale:y", original_scale.y, 0.10)
		await settle_tween.finished
		
		# 🌤️ Pequeña pausa antes del siguiente ciclo
		await get_tree().create_timer(randf_range(0.6, 0.9)).timeout
func pieces_can_match(piece1: PokemonPiece, piece2: PokemonPiece) -> bool:
	"""Determina si dos piezas pueden hacer match"""
	# Si ambos son del equipo (type 0-3), solo comparan type
	if piece1.type < 4 and piece2.type < 4:
		return piece1.type == piece2.type
	
	# Si alguno es non_support (type 4+), deben tener el mismo pokemon_id
	if piece1.type >= 4 or piece2.type >= 4:
		return piece1.pokemon_id == piece2.pokemon_id
	
	return false
func play_intro_animation():
	print("🎬 [INTRO] Iniciando animación de introducción")
	
	# 🟢 FASE 1: Mostrar texto de objetivo desde la derecha
	await show_objective_text()
	
	# 🟢 FASE 2: Fade in del grid
	await fade_in_grid()
	
	# 🟢 FASE 3: Deslizar texto hacia la izquierda
	await slide_out_objective_text()
	
	# 🟢 FASE 4: Mostrar paneles del UI
	await show_ui_panels()
	
	# 🟢 FASE 5: Aparecer Pokémon del grid uno por uno
	await spawn_grid_pokemon()
	
	# 🟢 FASE 6: Aparecer enemigo con efecto de polvo
	await spawn_enemy_with_dust()
	
	# 🟢 FASE 7: Mostrar barra de vida y panel de info
	await show_enemy_info()
	
	# 🟢 FASE 8: Texto "¡Prepárate!" y "¡Ya!"
	await show_ready_go_text()
	
	# 🟢 FASE 9: Habilitar controles
	intro_playing = false
	can_move = true
	print("🎬 [INTRO] Animación completada - Juego activo")

func show_objective_text():
	var objective_label = Label.new()
	objective_label.name = "ObjectiveText"
	objective_label.text = "¡Completa la fase en un\nmáximo de " + str(moves_left) + " turnos!"
	objective_label.add_theme_font_size_override("font_size", 42)
	objective_label.add_theme_color_override("font_color", Color.BLACK)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.modulate = Color(1, 1, 1, 0)
	objective_label.z_index = 200
	add_child(objective_label)
	
	objective_label.size = objective_label.get_minimum_size()
	
	# Posición objetivo (centrado en GridTextsPosition)
	var target_pos = $GridTextsPosition.position - (objective_label.size / 2)
	
	# Posición inicial (fuera de pantalla a la derecha)
	objective_label.position = Vector2(900, target_pos.y)
	
	# Animar entrada desde la derecha
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(objective_label, "position", target_pos, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(objective_label, "modulate:a", 1.0, 0.4)
	
	await tween.finished
	await get_tree().create_timer(1.2).timeout

func fade_in_grid():
	var tween = create_tween()
	tween.tween_property(grid_ui, "modulate:a", 1.0, 0.5)
	await tween.finished

func slide_out_objective_text():
	var objective_label = get_node_or_null("ObjectiveText")
	if objective_label == null:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(objective_label, "position:x", -400, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(objective_label, "modulate:a", 0.0, 0.4)
	
	await tween.finished
	objective_label.queue_free()

func show_ui_panels():
	var panels = [
		$UI/ScoreBack, 
		$UI/StageBack, 
		$UI/TurnsLeftBack
	]
	
	for i in range(panels.size()):
		var panel = panels[i]
		var tween = create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.3)
		
		if i < panels.size() - 1:
			await get_tree().create_timer(0.15).timeout
	
	await get_tree().create_timer(0.3).timeout

func spawn_grid_pokemon():
	# Crear array de todas las piezas
	var all_pieces = []
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid[y][x] != null:
				all_pieces.append(grid[y][x])
	
	# Mezclar aleatoriamente
	all_pieces.shuffle()
	
	# Aparecer cada pieza con efecto pop
	for piece in all_pieces:
		if not is_instance_valid(piece):
			continue
		
		piece.scale = Vector2(0.0, 0.0)
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "scale", Vector2(1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(piece, "modulate:a", 1.0, 0.2)
		
		await get_tree().create_timer(0.05).timeout
	Audiomanager.play_sfx("appear")
	await get_tree().create_timer(1.2).timeout

func spawn_enemy_with_dust():
	# Crear partículas de polvo
	var dust_particles = []
	
	# Obtener el rectángulo del sprite para calcular su centro visual
	var enemy_rect = $UI/EnemySprite.get_rect()
	var enemy_center = $UI/EnemySprite.global_position + (enemy_rect.size / 2)
	
	for i in range(12):
		var dust = TextureRect.new()
		dust.texture = load("res://assets/sprites/pokemon/appear_dust.png")
		dust.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dust.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var dust_size = randf_range(60, 70)  # Tamaño más grande
		dust.size = Vector2(dust_size, dust_size)
		dust.z_index = 99
		
		# Rotar aleatoriamente para variedad
		dust.rotation = randf_range(0, TAU)
		
		add_child(dust)
		
		# Posición inicial MUY cerca del centro
		var offset_x = randf_range(-20, 20)
		var offset_y = randf_range(-20, 20)
		dust.global_position = enemy_center + Vector2(offset_x, offset_y) - (dust.size / 2)  # Centrar el dust
		
		dust_particles.append(dust)
		
		# Guardar posición inicial para animar
		var start_pos = dust.global_position
		
		# Movimiento más amplio y aleatorio
		var angle = randf() * TAU  # Ángulo aleatorio
		var distance = randf_range(60, 100)  # Distancia más grande
		var end_x = start_pos.x + cos(angle) * distance
		var end_y = start_pos.y + sin(angle) * distance
		
		# Animar polvo con duración más larga
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(dust, "global_position:x", end_x, 1.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(dust, "global_position:y", end_y, 1.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(dust, "modulate:a", 0.0, 1.0).set_delay(0.2)  # Empieza a desaparecer más tarde
		tween.tween_property(dust, "scale", Vector2(2.0, 2.0), 1.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(dust, "rotation", dust.rotation + randf_range(-PI, PI), 1.2)  # Rotar mientras se expande
	
	# Aparecer sprite del enemigo
	$UI/EnemySprite.scale = Vector2(0.0, 0.0)
	var enemy_tween = create_tween()
	enemy_tween.set_parallel(true)
	enemy_tween.tween_property($UI/EnemySprite, "scale", Vector2(1.0, 1.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	enemy_tween.tween_property($UI/EnemySprite, "modulate:a", 1.0, 0.4)
	
	await enemy_tween.finished
	$UI/EnemyShadow.show()
	# Esperar a que el polvo termine de desaparecer
	await get_tree().create_timer(0.8).timeout
	
	# Limpiar polvo
	for dust in dust_particles:
		if is_instance_valid(dust):
			dust.queue_free()
	
	await get_tree().create_timer(0.2).timeout
func show_enemy_info():
	var elements = [
		$UI/HPLabel,
		$UI/PokePanel,
		$UI/Cooldown
	]
	
	for element in elements:
		element.scale = Vector2(0.8, 0.8)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(element, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(element, "modulate:a", 1.0, 0.25)
		
		await get_tree().create_timer(0.2).timeout
	
	await get_tree().create_timer(0.3).timeout

func show_ready_go_text():
	# Texto "¡Prepárate!"
	var ready_label = Label.new()
	ready_label.text = "¡Prepárate!"
	ready_label.add_theme_font_size_override("font_size", 72)

	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_label.modulate = Color(1, 0.9, 0.2, 0)
	ready_label.position = $GridTextsPosition.position
	ready_label.scale = Vector2(0.5, 0.5)
	ready_label.z_index = 300
	add_child(ready_label)
	
	var ready_tween = create_tween()
	ready_tween.set_parallel(true)
	ready_tween.tween_property(ready_label, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	ready_tween.tween_property(ready_label, "modulate:a", 1.0, 0.2)
	$Other/IntroMusic.stop()
	Audiomanager.play_sfx("start")
	await ready_tween.finished
	await get_tree().create_timer(0.6).timeout
	
	# Fade out "¡Prepárate!"
	var ready_out = create_tween()
	ready_out.tween_property(ready_label, "modulate:a", 0.0, 0.2)
	await ready_out.finished
	ready_label.queue_free()
	
	# Texto "¡Ya!"
	var go_label = Label.new()
	go_label.text = "¡Ya!"
	go_label.add_theme_font_size_override("font_size", 96)
	go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_label.modulate = Color(0.2, 1, 0.2, 0)
	go_label.position = $GridTextsPosition.position
	go_label.scale = Vector2(0.3, 0.3)
	go_label.z_index = 300
	add_child(go_label)
	
	var go_tween = create_tween()
	go_tween.set_parallel(true)
	go_tween.tween_property(go_label, "scale", Vector2(1.5, 1.5), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	go_tween.tween_property(go_label, "modulate:a", 1.0, 0.15)
	
	await go_tween.finished
	await get_tree().create_timer(0.4).timeout
	
	# Fade out "¡Ya!"
	var go_out = create_tween()
	go_out.set_parallel(true)
	go_out.tween_property(go_label, "modulate:a", 0.0, 0.3)
	go_out.tween_property(go_label, "scale", Vector2(2.0, 2.0), 0.3)
	await go_out.finished
	$Other/LevelMusic.play()
	go_label.queue_free()
