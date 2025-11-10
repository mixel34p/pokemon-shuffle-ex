# ============================================
# PokemonTeamSelector.gd - Pantalla de selección de equipo
# ============================================
extends Control

# Referencias a nodos
@onready var team_container: HBoxContainer = $CanvasLayer/PokemonTeam/TeamSection/TeamContainer
@onready var all_pokemon_scroll: ScrollContainer = $CanvasLayer/ScrollContainer
@onready var all_pokemon_grid: GridContainer = $CanvasLayer/ScrollContainer/PokemonGrid
@onready var back_button: Button = $CanvasLayer/ConfirmButton

# Constantes
const TEAM_SLOT_SIZE = 120
const POKEMON_CARD_SIZE = 100
const GRID_COLUMNS = 5
const POKEMON_DATA_PATH = "res://logic/data/pokemon.json"

# Variables
var team_slots: Array[Control] = []
var pokemon_cards: Array[Control] = []
var dragging_card: Control = null
var drag_preview: Control = null
var hover_slot: Control = null

# Variables estilo PokemonPiece
var can_move := false
var click_position := Vector2.ZERO
var has_moved := false
var smooth_follow_speed := 20.0
var drag_offset := Vector2.ZERO

# Datos de Pokémon cargados del JSON
var pokemon_database: Dictionary = {}

func _ready():
	load_pokemon_database()
	
	# Crear equipo de prueba solo si no hay datos
	if UserData.all_pokemon.is_empty():
		for i in range(50):
			UserData.add_pokemon(str(i+1), 1)
	
	# Agregar Pokémon de prueba con forma
	
	# TEST: Probar la función de obtener datos
	var test_data = get_pokemon_data_from_id("1_1")
	print("=== TEST VER DATOS DE UN POKÉMON ===")
	print("Nombre: ", test_data.get("name", "?"))
	print("Forma: ", test_data.get("form_name", "(sin forma)"))
	print("Tipo: ", test_data.get("type", "?"))
	print("Base ATK: ", test_data.get("base_atk", "?"))
	print("Max ATK: ", test_data.get("max_atk", "?"))
	print("Habilidad: ", test_data.get("skill", "?"))
	print("==========================")
	
	setup_team_slots()
	load_all_pokemon()
	back_button.pressed.connect(_on_back_pressed)

func setup_team_slots():
	"""Crea las 4 casillas del equipo"""
	for i in range(4):
		var slot = create_team_slot(i)
		team_container.add_child(slot)
		team_slots.append(slot)
	
	# Cargar pokémon del equipo actual
	load_team_pokemon()

func create_team_slot(index: int) -> Control:
	"""Crea una casilla del equipo - SIN FONDO, solo borde"""
	var slot = Control.new()
	slot.custom_minimum_size = Vector2(TEAM_SLOT_SIZE, TEAM_SLOT_SIZE + 40)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = slot.custom_minimum_size
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)
	
	# Label del slot
	var label = Label.new()
	label.text = "Slot " + str(index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)
	
	# Contenedor para el pokemon (con borde sutil)
	var pokemon_container = PanelContainer.new()
	pokemon_container.custom_minimum_size = Vector2(TEAM_SLOT_SIZE, TEAM_SLOT_SIZE)
	pokemon_container.name = "PokemonContainer"
	pokemon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Estilo: solo borde, sin fondo
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Transparente
	style.border_color = Color(0.4, 0.4, 0.45, 0.5)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	pokemon_container.add_theme_stylebox_override("panel", style)
	
	vbox.add_child(pokemon_container)
	
	slot.set_meta("slot_index", index)
	slot.set_meta("pokemon_container", pokemon_container)
	
	return slot

func load_team_pokemon():
	"""Carga los pokémon que ya están en el equipo"""
	var equipo_indices = UserData.equipo_pokemon
	
	for i in range(equipo_indices.size()):
		if i >= team_slots.size():
			break
		
		var pokemon_index = equipo_indices[i]
		var pokemon_data = UserData.obtain_full_pokemon(pokemon_index)
		
		if not pokemon_data.is_empty():
			var slot = team_slots[i]
			var pokemon_container = slot.get_meta("pokemon_container")
			create_pokemon_card_in_slot(pokemon_data, pokemon_container, pokemon_index, true)

func load_all_pokemon():
	"""Carga todos los pokémon del jugador en el grid"""
	all_pokemon_grid.columns = GRID_COLUMNS
	
	for i in range(UserData.all_pokemon.size()):
		var pokemon_data = UserData.obtain_full_pokemon(i)
		
		if not pokemon_data.is_empty():
			# Solo mostrar si NO está en el equipo
			if not UserData.equipo_pokemon.has(i):
				var card = create_pokemon_card(pokemon_data, i, false)
				all_pokemon_grid.add_child(card)
				pokemon_cards.append(card)

func create_pokemon_card(pokemon_data: Dictionary, pokemon_index: int, in_team: bool) -> Control:
	"""Crea una tarjeta de pokémon draggeable CON FONDO (TextureRect)"""
	var card = Control.new()
	card.custom_minimum_size = Vector2(POKEMON_CARD_SIZE, POKEMON_CARD_SIZE + 40)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.pivot_offset = Vector2(POKEMON_CARD_SIZE / 2.0, (POKEMON_CARD_SIZE + 40) / 2.0)
	
	# 🔥 FONDO: TextureRect con imagen
	var background = TextureRect.new()
	background.custom_minimum_size = Vector2(POKEMON_CARD_SIZE, POKEMON_CARD_SIZE + 40)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Cargar textura de fondo
	var bg_path = "res://assets/sprites/grid/pokemon_card_bg.png"
	if ResourceLoader.exists(bg_path):
		background.texture = load(bg_path)
	else:
		# Placeholder con color
		background.modulate = Color(0.15, 0.15, 0.2, 1.0)
	
	card.add_child(background)
	
	# VBox para organizar contenido
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = card.custom_minimum_size
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)
	
	# Sprite del pokémon
	var sprite = create_pokemon_sprite(pokemon_data)
	sprite.custom_minimum_size = Vector2(POKEMON_CARD_SIZE, POKEMON_CARD_SIZE)
	sprite.name = "Sprite"
	vbox.add_child(sprite)
	
	# Info container
	var info_container = VBoxContainer.new()
	info_container.add_theme_constant_override("separation", 2)
	info_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info_container)
	
	# Nivel
	var level_label = Label.new()
	level_label.text = "Nv. " + str(pokemon_data.get("nivel", 1))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.name = "LevelLabel"
	info_container.add_child(level_label)
	
	# Barra de XP
	var xp_bar = create_xp_bar(pokemon_data)
	xp_bar.name = "XPBar"
	info_container.add_child(xp_bar)
	
	# Metadata
	card.set_meta("pokemon_index", pokemon_index)
	card.set_meta("pokemon_data", pokemon_data)
	card.set_meta("in_team", in_team)
	
	# Señales
	card.gui_input.connect(_on_card_gui_input.bind(card))
	
	return card

func create_pokemon_card_in_slot(pokemon_data: Dictionary, container: Control, pokemon_index: int, in_team: bool):
	"""Crea una card dentro de un slot del equipo"""
	# Limpiar slot primero
	for child in container.get_children():
		child.queue_free()
	
	var card = create_pokemon_card(pokemon_data, pokemon_index, in_team)
	container.add_child(card)

func create_pokemon_sprite(pokemon_data: Dictionary) -> TextureRect:
	"""Crea el sprite del pokémon"""
	var sprite = TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# El ID ya viene como STRING completo (ej: "503_1" o "503")
	var pokemon_id = pokemon_data.get("id", "1")
	var sprite_path = "res://assets/sprites/pokemon/icons/" + pokemon_id + ".png"
	
	print("Cargando sprite: ", sprite_path)
	
	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
	else:
		# Placeholder con el ID
		var label = Label.new()
		label.text = pokemon_id
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		sprite.add_child(label)
	
	return sprite

func create_xp_bar(pokemon_data: Dictionary) -> ProgressBar:
	"""Crea la barra de experiencia"""
	var xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(POKEMON_CARD_SIZE - 10, 8)
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var current_exp = pokemon_data.get("exp", 0)
	var next_level_exp = pokemon_data.get("exp_siguiente_nivel", 100)
	
	xp_bar.max_value = next_level_exp
	xp_bar.value = current_exp
	
	# Estilo de la barra
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	style_bg.corner_radius_top_left = 4
	style_bg.corner_radius_top_right = 4
	style_bg.corner_radius_bottom_left = 4
	style_bg.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.3, 0.7, 1.0, 1.0)
	style_fg.corner_radius_top_left = 4
	style_fg.corner_radius_top_right = 4
	style_fg.corner_radius_bottom_left = 4
	style_fg.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("fill", style_fg)
	
	return xp_bar

func _on_card_gui_input(event: InputEvent, card: Control):
	"""Maneja el input de las cards de pokémon"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 🔥 INICIO DEL DRAG
			if dragging_card != null:
				return
			
			drag_offset = get_global_mouse_position() - card.global_position
			click_position = get_global_mouse_position()
			has_moved = false
			can_move = false
			
			animate_pick_up(card)
			get_viewport().set_input_as_handled()
		else:
			# 🔥 SOLTAR
			if dragging_card == card:
				if not has_moved:
					# Clic sin arrastrar - cancelar
					print("Clic sin arrastrar - cancelando")
					animate_release(card)
					cleanup_drag()
					get_viewport().set_input_as_handled()
				else:
					# Arrastre real - intentar colocar
					end_drag(card)
					get_viewport().set_input_as_handled()

func animate_pick_up(card: Control):
	"""Animación al agarrar - CON PREVIEW"""
	Audiomanager.play_sfx("grab_pokemon")
	dragging_card = card
	
	# 🔥 Crear preview visual en la posición global de la card
	drag_preview = create_drag_preview(card)
	add_child(drag_preview)
	drag_preview.global_position = card.global_position
	drag_preview.z_index = 100
	
	# 🔥 Ocultar card original (NO moverla)
	card.modulate.a = 0.3
	
	# 🔥 ANIMACIÓN DEL PREVIEW (no de la card original)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(drag_preview, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(drag_preview, "modulate:a", 0.7, 0.15)
	
	await tween.finished
	can_move = true

func create_drag_preview(original_card: Control) -> Control:
	"""Crea una copia visual de la card para arrastrar"""
	var preview = Control.new()
	preview.custom_minimum_size = original_card.custom_minimum_size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.pivot_offset = Vector2(POKEMON_CARD_SIZE / 2.0, (POKEMON_CARD_SIZE + 40) / 2.0)
	
	# Copiar el fondo
	var bg = TextureRect.new()
	bg.custom_minimum_size = original_card.custom_minimum_size
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg_path = "res://assets/sprites/grid/pokemon_card_bg.png"
	if ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)
	else:
		bg.modulate = Color(0.15, 0.15, 0.2, 1.0)
	
	preview.add_child(bg)
	
	# Copiar contenido visual
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = preview.custom_minimum_size
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(vbox)
	
	# Copiar sprite
	var pokemon_data = original_card.get_meta("pokemon_data")
	var sprite = create_pokemon_sprite(pokemon_data)
	sprite.custom_minimum_size = Vector2(POKEMON_CARD_SIZE, POKEMON_CARD_SIZE)
	vbox.add_child(sprite)
	
	# Copiar info
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info)
	
	var level_label = Label.new()
	level_label.text = "Nv. " + str(pokemon_data.get("nivel", 1))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(level_label)
	
	var xp_bar = create_xp_bar(pokemon_data)
	info.add_child(xp_bar)
	
	return preview

func animate_release(card: Control):
	"""Animación al soltar - ANIMAR EL PREVIEW"""
	# 🔥 Restaurar visibilidad de la card original
	card.modulate.a = 1.0
	
	# 🔥 ANIMAR EL PREVIEW (no la card)
	if drag_preview != null:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(drag_preview, "scale", Vector2.ONE, 0.15)
		tween.tween_property(drag_preview, "modulate:a", 1.0, 0.15)
		
		await tween.finished

func end_drag(card: Control):
	"""Termina el arrastre de una card"""
	if card == null:
		cleanup_drag()
		return
	
	var placed = false
	
	# Verificar si está sobre un slot del equipo
	if hover_slot != null:
		placed = try_place_in_slot(card, hover_slot)
	
	# 🔥 Si NO se colocó pero estaba en el equipo, SACARLO del equipo
	if not placed:
		var card_in_team = card.get_meta("in_team")
		if card_in_team:
			var pokemon_index = card.get_meta("pokemon_index")
			UserData.delete_from_team(pokemon_index)
			print("Pokémon sacado del equipo: ", pokemon_index)
			Audiomanager.play_sfx("release_pokemon")
			# Esperar animación antes de refrescar
			await animate_release(card)
			refresh_ui()
		else:
			Audiomanager.play_sfx("cancel")
			await animate_release(card)
	else:
		await animate_release(card)
	
	cleanup_drag()

func cleanup_drag():
	"""Limpia el estado de drag"""
	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null
	
	dragging_card = null
	hover_slot = null
	can_move = false
	has_moved = false

func try_place_in_slot(card: Control, slot: Control) -> bool:
	"""Intenta colocar una card en un slot del equipo"""
	var slot_index = slot.get_meta("slot_index")
	var pokemon_index = card.get_meta("pokemon_index")
	var pokemon_container = slot.get_meta("pokemon_container")
	var card_in_team = card.get_meta("in_team")
	
	# Verificar si el slot ya tiene un pokémon
	var has_pokemon = pokemon_container.get_child_count() > 0
	
	if has_pokemon:
		# SWAP: intercambiar pokémon
		var slot_card = pokemon_container.get_child(0)
		var slot_pokemon_index = slot_card.get_meta("pokemon_index")
		
		if card_in_team:
			# 🔥 Swap entre dos slots del equipo (mantener posiciones)
			var card_slot_index = find_card_slot_index(pokemon_index)
			if card_slot_index != -1:
				# Intercambiar en el array directamente
				var temp = UserData.equipo_pokemon[card_slot_index]
				UserData.equipo_pokemon[card_slot_index] = UserData.equipo_pokemon[slot_index]
				UserData.equipo_pokemon[slot_index] = temp
		else:
			# 🔥 Reemplazar: poner el nuevo en la MISMA posición del slot
			UserData.equipo_pokemon[slot_index] = pokemon_index
	else:
		# Slot vacío
		if card_in_team:
			# 🔥 Mover de un slot a otro vacío (mantener índice)
			var old_slot_index = find_card_slot_index(pokemon_index)
			if old_slot_index != -1:
				UserData.equipo_pokemon[old_slot_index] = -1
				UserData.equipo_pokemon[slot_index] = pokemon_index
				# Limpiar slots vacíos del array
				UserData.equipo_pokemon = UserData.equipo_pokemon.filter(func(idx): return idx != -1)
		else:
			# 🔥 Agregar del grid al slot específico
			# Insertar en la posición del slot
			if slot_index < UserData.equipo_pokemon.size():
				UserData.equipo_pokemon.insert(slot_index, pokemon_index)
			else:
				UserData.equipo_pokemon.append(pokemon_index)
			
			# Mantener máximo 4 pokémon
			if UserData.equipo_pokemon.size() > 4:
				UserData.equipo_pokemon.resize(4)
	
	# Actualizar visual
	refresh_ui()
	Audiomanager.play_sfx("put_pokemon")
	return true

func find_card_slot_index(pokemon_index: int) -> int:
	"""Encuentra el índice del slot donde está un pokémon"""
	for i in range(UserData.equipo_pokemon.size()):
		if UserData.equipo_pokemon[i] == pokemon_index:
			return i
	return -1

func refresh_ui():
	"""Refresca toda la UI"""
	# Limpiar todo
	for slot in team_slots:
		var container = slot.get_meta("pokemon_container")
		for child in container.get_children():
			child.queue_free()
	
	for child in all_pokemon_grid.get_children():
		child.queue_free()
	
	pokemon_cards.clear()
	
	# Recargar
	load_team_pokemon()
	load_all_pokemon()

func _process(delta):
	if drag_preview != null and dragging_card != null and can_move:
		# 🔥 Mover el preview con lerp smooth
		var mouse_pos = get_global_mouse_position()
		
		# Detectar movimiento significativo
		if not has_moved and click_position.distance_to(mouse_pos) > 10:
			has_moved = true
		
		drag_preview.global_position = drag_preview.global_position.lerp(
			mouse_pos - drag_offset,
			delta * smooth_follow_speed
		)
		
		# Detectar hover sobre slots
		var new_hover_slot = get_slot_under_mouse()
		if new_hover_slot != hover_slot:
			if hover_slot != null:
				unhighlight_slot(hover_slot)
			hover_slot = new_hover_slot
			if hover_slot != null:
				highlight_slot(hover_slot)

func get_slot_under_mouse() -> Control:
	"""Obtiene el slot del equipo bajo el cursor"""
	for slot in team_slots:
		var rect = slot.get_global_rect()
		if rect.has_point(get_global_mouse_position()):
			return slot
	return null

func highlight_slot(slot: Control):
	"""Resalta un slot"""
	var pokemon_container = slot.get_meta("pokemon_container")
	var style = pokemon_container.get_theme_stylebox("panel").duplicate()
	style.border_color = Color(0.3, 0.8, 1.0, 1.0)
	style.set_border_width_all(3)
	pokemon_container.add_theme_stylebox_override("panel", style)

func unhighlight_slot(slot: Control):
	"""Quita el resaltado de un slot"""
	var pokemon_container = slot.get_meta("pokemon_container")
	var style = pokemon_container.get_theme_stylebox("panel").duplicate()
	style.border_color = Color(0.4, 0.4, 0.45, 0.5)
	style.set_border_width_all(2)
	pokemon_container.add_theme_stylebox_override("panel", style)

func _on_back_pressed():
	"""Vuelve a la escena anterior"""
	print("adios")
	UserData.guardar_datos()
	get_tree().change_scene_to_file("res://logic/scenes/main.tscn")

func _on_back_button_button_down() -> void:
	"""Vuelve a la escena anterior"""
	print("adios")
	UserData.guardar_datos()
	get_tree().change_scene_to_file("res://logic/scenes/main.tscn")

# ============================================
# FUNCIONES PARA CARGAR Y PARSEAR DATOS POKÉMON
# ============================================

func load_pokemon_database():
	"""Carga el JSON de datos de Pokémon"""
	var file = FileAccess.open(POKEMON_DATA_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			pokemon_database = json.get_data()
		file.close()
	else:
		push_error("No se pudo cargar pokemon.json")

func parse_pokemon_id(pokemon_id_string: String) -> Dictionary:
	"""
	Parsea un ID de Pokémon y separa el ID base de la forma.
	
	Ejemplos:
	  "503" → {base_id: "503", form_id: "0", has_form: false}
	  "503_1" → {base_id: "503", form_id: "1", has_form: true}
	"""
	var parts = pokemon_id_string.split("_")
	
	if parts.size() > 1:
		return {
			"base_id": parts[0],
			"form_id": parts[1],
			"has_form": true
		}
	else:
		return {
			"base_id": parts[0],
			"form_id": "0",
			"has_form": false
		}

func get_pokemon_data_from_id(pokemon_id_string: String) -> Dictionary:
	"""
	Obtiene los datos completos de un Pokémon desde pokemon_database.
	Si el ID tiene forma (ej: "503_1"), los datos de la forma REEMPLAZAN los datos base.
	
	Args:
	  pokemon_id_string: ID completo como string (ej: "503" o "503_1")
	
	Returns:
	  Dictionary con todos los datos del Pokémon (name, type, base_atk, max_atk, skill, flags)
	"""
	var parsed = parse_pokemon_id(pokemon_id_string)
	var base_id = parsed["base_id"]
	var form_id = parsed["form_id"]
	var has_form = parsed["has_form"]
	
	# Verificar que existe el Pokémon base
	if not pokemon_database.has(base_id):
		print("ERROR: Pokémon con ID ", base_id, " no encontrado en pokemon.json")
		return {
			"name": "Unknown",
			"type": "normal",
			"base_atk": 30,
			"max_atk": 50,
			"skill": "none"
		}
	
	var base_data = pokemon_database[base_id]
	
	# Si NO tiene forma, retornar datos base
	if not has_form:
		return base_data.duplicate()
	
	# Si tiene forma, verificar que exista
	if not base_data.has("forms") or not base_data["forms"].has(form_id):
		print("ERROR: Forma ", form_id, " no existe para Pokémon ", base_id)
		return base_data.duplicate()
	
	var form_data = base_data["forms"][form_id]
	
	# Los datos de la forma REEMPLAZAN los datos base
	var final_data = base_data.duplicate()
	for key in form_data.keys():
		final_data[key] = form_data[key]
	
	return final_data
