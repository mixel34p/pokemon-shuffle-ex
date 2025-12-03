extends Control

# Referencias a nodos
@onready var team_container: HBoxContainer = $CanvasLayer/PokemonTeam/TeamSection/TeamContainer
@onready var all_pokemon_scroll: ScrollContainer = $CanvasLayer/ScrollContainer
@onready var all_pokemon_grid: GridContainer = $CanvasLayer/ScrollContainer/PokemonGrid
@onready var back_button: Button = $CanvasLayer/ConfirmButton

# Escena de la card
const POKEMON_CARD_SCENE = preload("res://logic/scenes/ui_elements/pokemon_card_team.tscn")

# Constantes
const TEAM_SLOT_SIZE = Vector2(90, 90)
const GRID_SLOT_SIZE = Vector2(115, 105)
const GRID_COLUMNS = 5
const POKEMON_DATA_PATH = "res://logic/data/pokemon.json"

# Variables
var team_slots: Array[Control] = []
var pokemon_cards: Array[PokemonCard] = []
var dragging_card: PokemonCard = null
var drag_preview: Control = null
var hover_slot: Control = null

# Variables de drag
var can_move := false
var click_position := Vector2.ZERO
var has_moved := false
var smooth_follow_speed := 20.0
var drag_offset := Vector2.ZERO

# Datos de Pokémon
var pokemon_database: Dictionary = {}

# Panel de información
var info_panel: Control = null

# NUEVA VARIABLE: Card seleccionada actualmente
var selected_card: PokemonCard = null
var foe_pokemon_type = null


func _ready():
	load_pokemon_database()
	
	if UserData.all_pokemon.is_empty():
		for i in range(386):
			UserData.add_pokemon(str(i+1), 1)
	UserData.add_pokemon("58_1", 1)
	UserData.add_pokemon("59_1", 1)
	var test_data = get_pokemon_data_from_id("1_1")
	print("=== TEST VER DATOS DE UN POKÉMON ===")
	print("Nombre: ", test_data.get("name", "?"))
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
	
	load_team_pokemon()

func create_team_slot(index: int) -> Control:
	"""Crea una casilla del equipo transparente"""
	var slot = Control.new()
	slot.custom_minimum_size = TEAM_SLOT_SIZE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var pokemon_container = Control.new()
	pokemon_container.custom_minimum_size = TEAM_SLOT_SIZE
	pokemon_container.name = "PokemonContainer"
	pokemon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(pokemon_container)
	
	slot.set_meta("slot_index", index)
	slot.set_meta("pokemon_container", pokemon_container)
	
	return slot

func load_team_pokemon():
	"""Carga los pokémon del equipo"""
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
	"""Carga todos los pokémon en el grid (las formas quedan junto al base)."""
	all_pokemon_grid.columns = GRID_COLUMNS
	all_pokemon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_pokemon_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	all_pokemon_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Construir lista intermedia con información clara (array_index, data, full_id, base_id, form_id)
	var pokemon_list: Array = []
	for i in range(UserData.all_pokemon.size()):
		var entry = UserData.all_pokemon[i]
		var full_id: String = ""

		# Soportar distintos formatos de almacenamiento
		if typeof(entry) == TYPE_DICTIONARY:
			# si el entry es un diccionario, intentar obtener el campo "id"
			full_id = str(entry.get("id", str(i)))
		else:
			# si es string u otro, convertir a string directamente
			full_id = str(entry)

		# Obtener datos completos desde UserData (usa el índice real)
		var pokemon_data = UserData.obtain_full_pokemon(i)
		if pokemon_data.is_empty():
			continue

		# Parsear base y forma de forma segura
		var parts = full_id.split("_")
		var base_id_str = parts[0]
		var form_id_str = "0"
		if parts.size() > 1:
			form_id_str = parts[1]

		# Añadir a la lista
		pokemon_list.append({
			"array_index": i,
			"data": pokemon_data,
			"full_id": full_id,
			"base_id": int(base_id_str),
			"form_id": int(form_id_str)
		})

	# Ordenar: primero por base_id, luego por form_id (ambos numéricos)
	pokemon_list.sort_custom(func(a, b):
		if a["base_id"] != b["base_id"]:
			return a["base_id"] < b["base_id"]
		return a["form_id"] < b["form_id"]
	)

	# Añadir las cards al grid
	for pokemon_entry in pokemon_list:
		var card = create_pokemon_card(
			pokemon_entry["data"],
			pokemon_entry["array_index"],
			false
		)
		# Asegurar tamaño para que GridContainer las distribuya correctamente
		card.custom_minimum_size = GRID_SLOT_SIZE
		all_pokemon_grid.add_child(card)
		pokemon_cards.append(card)


func create_pokemon_card(pokemon_data: Dictionary, pokemon_index: int, in_team: bool) -> PokemonCard:
	"""Instancia una card desde la escena"""
	var card = POKEMON_CARD_SCENE.instantiate() as PokemonCard
	
	# CRÍTICO: Esperar a que esté en el árbol para configurar
	call_deferred("_setup_card_deferred", card, pokemon_data, pokemon_index, in_team)
	
	return card

func _setup_card_deferred(card: PokemonCard, pokemon_data: Dictionary, pokemon_index: int, in_team: bool):
	"""Configura la card después de añadirla al árbol"""
	if not is_instance_valid(card):
		return
	
	card.setup(pokemon_data, pokemon_index, in_team)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Asegurar que todos los hijos ignoren el mouse
	for child in card.get_children():
		_set_mouse_filter_recursive(child, Control.MOUSE_FILTER_IGNORE)
	
	card.gui_input.connect(_on_card_gui_input.bind(card))

func _set_mouse_filter_recursive(node: Node, filter: int):
	"""Establece el mouse_filter recursivamente"""
	if node is Control:
		node.mouse_filter = filter
	
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func create_pokemon_card_in_slot(pokemon_data: Dictionary, container: Control, pokemon_index: int, in_team: bool):
	"""Crea una card dentro de un slot del equipo"""
	for child in container.get_children():
		child.queue_free()
	
	var card = create_pokemon_card(pokemon_data, pokemon_index, in_team)
	container.add_child(card)

# ==================== SELECCIÓN ====================

func select_card(card: PokemonCard):
	"""Selecciona una card y deselecciona la anterior"""
	if selected_card == card:
		return
	
	# Deseleccionar la anterior (solo si NO está en el equipo)
	if selected_card != null and is_instance_valid(selected_card):
		if not selected_card.is_in_team:
			selected_card.stop_selected()
	
	# Seleccionar la nueva
	selected_card = card
	# Reproducir animación solo si NO está en el equipo
	if selected_card != null and is_instance_valid(selected_card):
		if not selected_card.is_in_team:
			selected_card.play_selected()

func deselect_current_card():
	"""Deselecciona la card actual sin seleccionar otra"""
	if selected_card != null and is_instance_valid(selected_card):
		selected_card.stop_selected()
		selected_card = null

# ==================== INPUT Y DRAG ====================

func _on_card_gui_input(event: InputEvent, card: PokemonCard):
	"""Maneja el input de las cards"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if dragging_card != null:
				return
			
			click_position = get_global_mouse_position()
			has_moved = false
			can_move = false
			
			animate_pick_up(card)
			get_viewport().set_input_as_handled()
		else:
			if dragging_card == card:
				if not has_moved:
					print("Click sin arrastrar - cancelando")
					animate_release(card)
					cleanup_drag()
					get_viewport().set_input_as_handled()
				else:
					end_drag(card)
					get_viewport().set_input_as_handled()

func animate_pick_up(card: PokemonCard):
	"""Animación al agarrar - Preview grande y transparente"""
	Audiomanager.play_sfx("grab_pokemon")
	dragging_card = card
	
	# SELECCIONAR la card al empezar a arrastrar (siempre)
	select_card(card)
	
	# Crear preview en la posición de la card
	drag_preview = create_drag_preview(card)
	find_child("CanvasLayer").find_child("DragPreview").add_child(drag_preview)
	
	# Centrar preview en la card
	var card_center = card.global_position + card.size / 2
	drag_preview.global_position = card_center - drag_preview.size / 2
	drag_preview.z_index = 100
	
	# Calcular offset DESPUÉS de posicionar
	drag_offset = get_global_mouse_position() - drag_preview.global_position
	
	# Transparentar card original
	card.modulate.a = 0.3
	
	# Animación del preview
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(drag_preview, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(drag_preview, "modulate:a", 0.6, 0.15)
	
	await tween.finished
	can_move = true
	
	show_pokemon_info_panel(card)

func create_drag_preview(card: PokemonCard) -> TextureRect:
	"""Crea un preview simple usando la textura del sprite"""
	var preview = TextureRect.new()
	preview.texture = card.get_sprite_texture()
	preview.custom_minimum_size = Vector2(50, 50)
	preview.size = Vector2(50, 50)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1, 1, 1, 0.7)
	preview.pivot_offset = preview.size / 2
	
	return preview

func animate_release(card: PokemonCard):
	"""Restaura la opacidad de la card"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card, "modulate:a", 1.0, 0.2)
	await tween.finished

func end_drag(card: PokemonCard):
	"""Termina el arrastre de una card"""
	if card == null or not is_instance_valid(card):
		cleanup_drag()
		return
	
	var placed = false
	var was_over_team_area = false
	
	# Verificar si está sobre un slot del equipo
	if hover_slot != null and is_instance_valid(hover_slot):
		was_over_team_area = true
		placed = try_place_in_slot(card, hover_slot)
	
	# Solo sacar del equipo si:
	# 1. Era del equipo
	# 2. NO estaba sobre el área de equipo (se soltó fuera)
	# 3. NO se colocó exitosamente
	if not placed and card.is_in_team:
		if not was_over_team_area:
			# Se soltó FUERA del área de equipo - sacarlo
			var pokemon_index = card.pokemon_index
			UserData.delete_from_team(pokemon_index)
			print("Pokémon sacado del equipo: ", pokemon_index)
			Audiomanager.play_sfx("release_pokemon")
			if is_instance_valid(card):
				await animate_release(card)
			refresh_ui()
		else:
			# Se soltó sobre el área de equipo pero no se colocó
			print("ERROR: Sobre equipo pero no colocado - manteniendo")
			Audiomanager.play_sfx("cancel")
			if is_instance_valid(card):
				await animate_release(card)
	elif not placed and not card.is_in_team:
		# Pokémon del grid que no se colocó - simplemente cancelar
		Audiomanager.play_sfx("cancel")
		if is_instance_valid(card):
			await animate_release(card)
	else:
		# Se colocó exitosamente
		if is_instance_valid(card):
			await animate_release(card)
	
	cleanup_drag()


func cleanup_drag():
	"""Limpia el estado de drag de forma segura"""
	if drag_preview != null and is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null
	
	hide_pokemon_info_panel()
	
	dragging_card = null
	hover_slot = null
	can_move = false
	has_moved = false


func try_place_in_slot(card: PokemonCard, slot: Control) -> bool:
	"""Intenta colocar una card en un slot del equipo"""
	var slot_index = slot.get_meta("slot_index")
	var pokemon_index = card.pokemon_index
	var pokemon_container = slot.get_meta("pokemon_container")
	var card_in_team = card.is_in_team
	
	# VALIDACIÓN: Evitar duplicados en el equipo
	if not card_in_team:
		# Verificar si este pokémon ya está en el equipo
		if UserData.equipo_pokemon.has(pokemon_index):
			print("ERROR: Este Pokémon ya está en el equipo")
			Audiomanager.play_sfx("cancel")
			return false
	
	# Verificar si el slot ya tiene un pokémon (de forma segura)
	var slot_card = get_card_from_container(pokemon_container)
	var has_pokemon = slot_card != null
	
	# CASO 1: El pokémon YA está en el equipo
	if card_in_team:
		var old_slot_index = find_card_slot_index(pokemon_index)
		if old_slot_index == -1:
			print("ERROR: Pokémon marcado como in_team pero no está en equipo_pokemon")
			return false
		
		# Si arrastramos al mismo slot, mantener en su posición
		if old_slot_index == slot_index:
			print("Mismo slot - manteniendo posición")
			return true
		
		if has_pokemon:
			# SWAP: intercambiar posiciones
			var slot_pokemon_index = slot_card.pokemon_index
			
			# Validación adicional: verificar que ambos índices existen
			if old_slot_index >= UserData.equipo_pokemon.size() or slot_index >= UserData.equipo_pokemon.size():
				print("ERROR: Índices fuera de rango")
				return false
			
			# Verificar que los índices del array coinciden con las cards
			if UserData.equipo_pokemon[old_slot_index] != pokemon_index:
				print("ERROR: Inconsistencia - card no coincide con equipo_pokemon[", old_slot_index, "]")
				return false
			
			if UserData.equipo_pokemon[slot_index] != slot_pokemon_index:
				print("ERROR: Inconsistencia - slot_card no coincide con equipo_pokemon[", slot_index, "]")
				return false
			
			# Intercambiar directamente
			var temp = UserData.equipo_pokemon[old_slot_index]
			UserData.equipo_pokemon[old_slot_index] = UserData.equipo_pokemon[slot_index]
			UserData.equipo_pokemon[slot_index] = temp
			
			print("SWAP: slot ", old_slot_index, " (pokemon ", pokemon_index, ") <-> slot ", slot_index, " (pokemon ", slot_pokemon_index, ")")
		else:
			# Mover a slot vacío
			var removed_index = UserData.equipo_pokemon[old_slot_index]
			UserData.equipo_pokemon.remove_at(old_slot_index)
			
			# Ajustar slot_index si es necesario (si estamos moviendo a la derecha)
			var adjusted_slot_index = slot_index
			if slot_index > old_slot_index:
				adjusted_slot_index -= 1
			
			# Insertar en la posición correcta
			if adjusted_slot_index >= UserData.equipo_pokemon.size():
				UserData.equipo_pokemon.append(removed_index)
			else:
				UserData.equipo_pokemon.insert(adjusted_slot_index, removed_index)
			
			print("MOVE: slot ", old_slot_index, " -> ", adjusted_slot_index, " (pokemon ", pokemon_index, ")")
	
	# CASO 2: El pokémon NO está en el equipo (viene del grid)
	else:
		if has_pokemon:
			# Reemplazar el pokémon existente en el slot
			if slot_index < UserData.equipo_pokemon.size():
				UserData.equipo_pokemon[slot_index] = pokemon_index
			else:
				UserData.equipo_pokemon.append(pokemon_index)
			
			print("REPLACE: slot ", slot_index, " con pokemon ", pokemon_index)
		else:
			# Slot vacío - agregar al equipo
			if UserData.equipo_pokemon.size() >= 4:
				print("ADVERTENCIA: Equipo lleno")
				Audiomanager.play_sfx("cancel")
				return false
			
			# Insertar en la posición correcta manteniendo el orden
			if slot_index >= UserData.equipo_pokemon.size():
				UserData.equipo_pokemon.append(pokemon_index)
			else:
				UserData.equipo_pokemon.insert(slot_index, pokemon_index)
			
			print("ADD: pokemon ", pokemon_index, " en slot ", slot_index)
	
	# Mantener máximo 4 pokémon
	if UserData.equipo_pokemon.size() > 4:
		UserData.equipo_pokemon.resize(4)
	
	# VALIDACIÓN FINAL: Verificar que no hay duplicados
	var seen = {}
	for i in range(UserData.equipo_pokemon.size()):
		var idx = UserData.equipo_pokemon[i]
		if seen.has(idx):
			print("ERROR CRÍTICO: Duplicado detectado en equipo_pokemon")
			UserData.equipo_pokemon.remove_at(i)
			refresh_ui()
			return false
		seen[idx] = true
	
	# Debug: Mostrar estado final del equipo
	print("Estado equipo_pokemon: ", UserData.equipo_pokemon)
	
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
	"""Refresca toda la UI de forma segura"""
	# Guardar referencia a la card seleccionada actual
	var was_selected_index = -1
	if selected_card != null and is_instance_valid(selected_card):
		was_selected_index = selected_card.pokemon_index
	
	# Limpiar slots del equipo
	for slot in team_slots:
		var container = slot.get_meta("pokemon_container")
		if container == null:
			continue
		for child in container.get_children():
			if is_instance_valid(child):
				child.queue_free()
	
	# Limpiar grid
	for child in all_pokemon_grid.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	pokemon_cards.clear()
	selected_card = null
	
	# Esperar un frame para asegurar que las cards se eliminaron
	await get_tree().process_frame
	
	# Recargar
	load_team_pokemon()
	load_all_pokemon()
	
	# Esperar otro frame para que las cards estén listas
	await get_tree().process_frame
	
	# Restaurar la selección si es posible (SOLO en el grid, nunca en el equipo)
	if was_selected_index != -1:
		var card_to_select: PokemonCard = null
		
		# Buscar SOLO en el grid (no en el equipo)
		for card in pokemon_cards:
			if card.pokemon_index == was_selected_index and not card.is_in_team:
				card_to_select = card
				break
		
		# Reseleccionar solo si se encontró en el grid
		if card_to_select != null:
			select_card(card_to_select)

func _process(delta):
	if drag_preview != null and dragging_card != null and can_move:
		var mouse_pos = get_global_mouse_position()
		
		# Detectar movimiento
		if not has_moved and click_position.distance_to(mouse_pos) > 10:
			has_moved = true
		
		# Posición objetivo (smooth follow)
		var target_pos = mouse_pos - drag_offset
		
		drag_preview.global_position = drag_preview.global_position.lerp(
			target_pos,
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
	"""Resalta un slot con efecto visual"""
	var pokemon_container = slot.get_meta("pokemon_container")
	
	if pokemon_container.get_node_or_null("Highlight") != null:
		return
	
	var highlight = ColorRect.new()
	highlight.name = "Highlight"
	highlight.color = Color(0.3, 0.6, 1.0, 0.2)
	highlight.size = TEAM_SLOT_SIZE
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.z_index = -1
	
	pokemon_container.add_child(highlight)
	pokemon_container.move_child(highlight, 0)

func unhighlight_slot(slot: Control):
	"""Quita el resaltado de un slot"""
	var pokemon_container = slot.get_meta("pokemon_container")
	var highlight = pokemon_container.get_node_or_null("Highlight")
	if highlight:
		highlight.queue_free()

func _on_back_pressed():
	"""Vuelve a la escena anterior"""
	UserData.guardar_datos()
	get_tree().change_scene_to_file("res://logic/scenes/main.tscn")

func _on_back_button_button_down() -> void:
	"""Vuelve a la escena anterior"""
	UserData.guardar_datos()
	get_tree().change_scene_to_file("res://logic/scenes/main.tscn")

# ==================== DATOS POKÉMON ====================

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
	"""Parsea un ID de Pokémon"""
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
	"""Obtiene los datos completos de un Pokémon"""
	var parsed = parse_pokemon_id(pokemon_id_string)
	var base_id = parsed["base_id"]
	var form_id = parsed["form_id"]
	var has_form = parsed["has_form"]
	
	if not pokemon_database.has(base_id):
		print("ERROR: Pokémon con ID ", base_id, " no encontrado")
		return {
			"name": "Unknown",
			"type": "normal",
			"base_atk": 30,
			"max_atk": 50,
			"skill": "none"
		}
	
	var base_data = pokemon_database[base_id]
	
	if not has_form:
		return base_data.duplicate()
	
	if not base_data.has("forms") or not base_data["forms"].has(form_id):
		print("ERROR: Forma ", form_id, " no existe para Pokémon ", base_id)
		return base_data.duplicate()
	
	var form_data = base_data["forms"][form_id]
	var final_data = base_data.duplicate()
	for key in form_data.keys():
		final_data[key] = form_data[key]
	
	return final_data

# ==================== PANEL DE INFORMACIÓN ====================

func show_pokemon_info_panel(card: PokemonCard):
	"""Muestra panel de información del Pokémon"""
	if info_panel != null:
		info_panel.queue_free()
	
	replace_info_panel(card)
	
func hide_pokemon_info_panel():
	pass

func replace_info_panel(card: PokemonCard):
	$CanvasLayer/InfoPanel/NoSelectedText.hide()
	$CanvasLayer/InfoPanel/Info.show()
	var full_data = get_pokemon_data_from_id(card.pokemon_data.get("id", "1"))
	
	var sprite_path = "res://assets/sprites/pokemon/icons/" + card.pokemon_data.get("id", "1") + ".png"
	$CanvasLayer/InfoPanel/Info/PokemonIcon.texture = load(sprite_path)
	var parseid = parse_pokemon_id(card.pokemon_data.get("id", "1"))
	$CanvasLayer/InfoPanel/Info/ID.text = id_stringer(parseid["base_id"])
	$CanvasLayer/InfoPanel/Info/Pokemon.text = full_data["name"]
	$CanvasLayer/InfoPanel/Info/PokemonIcon/Type/TypeLabel.text = Translator.translate_type(full_data["type"],TranslationServer.get_locale())
	var type_style = Functions.set_type_color(full_data["type"])
	$CanvasLayer/InfoPanel/Info/PokemonIcon/Type.add_theme_stylebox_override("panel", type_style)
	if int(parseid["form_id"]) > 0:
		$CanvasLayer/InfoPanel/Info/Form.show()
		$CanvasLayer/InfoPanel/Info/Form.text = full_data["form_name"]
	else:
		$CanvasLayer/InfoPanel/Info/Form.hide()
	var pokemon_info = UserData.obtain_full_pokemon(card.pokemon_index)
	var level = pokemon_info.get("level", 1)
	$CanvasLayer/InfoPanel/Info/AttckPanel/int.text = str(calculate_attack_stat(full_data["base_atk"],full_data["max_atk"],level))
	$CanvasLayer/InfoPanel/Info/SkillPanel/Label.text = full_data["skill"]
	
func id_stringer(id):
	var intid = int(id)
	if intid < 10:
		var idstr = ("000"+id)
		return idstr
	elif intid >= 10 and intid < 100:
		var idstr = ("00"+id)
		return idstr
	elif intid >= 100 and intid < 1000:
		var idstr = ("0"+id)
		return idstr
	else:
		return id
func calculate_attack_stat(base_atk: int, max_atk: int, level: int) -> int:
	var max_level = 10
	var atk_per_level = float(max_atk - base_atk) / (max_level - 1)
	var current_atk = base_atk + int(atk_per_level * (level - 1))
	return current_atk
func get_card_from_container(container: Control) -> PokemonCard:
	"""Obtiene la PokemonCard de un contenedor de forma segura"""
	for child in container.get_children():
		if child is PokemonCard:
			return child
	return null
