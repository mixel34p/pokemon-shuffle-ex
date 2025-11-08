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
var pokemon_sprite: TextureRect  # 🔥 FALTABA ESTA VARIABLE
var idle_timer: Timer
var is_in_idle_animation: bool = false
var is_being_dragged := false
var dragging := false
var can_move := false
var drag_offset := Vector2.ZERO
var hover_tween : Tween
var smooth_follow_speed := 20.00
var click_position := Vector2.ZERO
var has_moved := false

# Disruption system variables
var interference_type: String = ""  # "", "rock", "block", "barrier", "cloud", "non_support"
var interference_hp: int = 1
var interference_overlay: TextureRect = null
var original_pokemon_data: Dictionary = {}
var is_non_support_pokemon: bool = false
var is_pure_disruption: bool = false
var cloud_grid_position: Array = []


func setup(x: int, y: int, piece_type: int, tile_size_val: int, poke_id: int, level: int, form: int = 0):
	grid_x = x
	grid_y = y
	type = piece_type
	tile_size = tile_size_val
	pokemon_id = poke_id
	pokemon_form = form
	pokemon_level = level
	
	# Store original pokemon data for potential restoration
	original_pokemon_data = {
		"id": poke_id,
		"form": form,
		"level": level
	}
	
	custom_minimum_size = Vector2(tile_size_val, tile_size_val)
	size = Vector2(tile_size_val, tile_size_val)
	
	# Establecer el pivot en el centro para que escale desde ahí
	pivot_offset = Vector2(tile_size_val / 2.0, tile_size_val / 2.0)
func setup_as_disruption(x: int, y: int, disruption_type: String, tile_size_val: int, hp: int = 1):
	"""Setup this piece as a pure disruption (rock/block) without pokemon"""
	grid_x = x
	grid_y = y
	type = -1  # No type (not matchable)
	tile_size = tile_size_val
	pokemon_id = -1
	pokemon_form = 0
	pokemon_level = 1
	is_pure_disruption = true
	
	custom_minimum_size = Vector2(tile_size_val, tile_size_val)
	size = Vector2(tile_size_val, tile_size_val)
	pivot_offset = Vector2(tile_size_val / 2.0, tile_size_val / 2.0)
	
	# Configurar la disrupción
	interference_type = disruption_type
	interference_hp = hp
func setup_as_cloud_disruption(x: int, y: int, tile_size_val: int):
	"""Setup this piece as a pure cloud disruption (no pokemon underneath)"""
	grid_x = x
	grid_y = y
	type = -1  # No type (not matchable)
	tile_size = tile_size_val
	pokemon_id = -1
	pokemon_form = 0
	pokemon_level = 1
	is_pure_disruption = true
	interference_type = "cloud"
	interference_hp = 1
	
	custom_minimum_size = Vector2(tile_size_val, tile_size_val)
	size = Vector2(tile_size_val, tile_size_val)
	pivot_offset = Vector2(tile_size_val / 2.0, tile_size_val / 2.0)
func _ready():
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	if not is_pure_disruption:
		load_pokemon_sprite()
		setup_idle_animation()
	
	# Si es disrupción pura, crear el overlay directamente
	if is_pure_disruption:
		update_interference_visual()


func load_pokemon_sprite():
	var sprite_path = "res://assets/sprites/pokemon/icons/" + str(pokemon_id)
	if pokemon_form > 0:
		sprite_path += "_" + str(pokemon_form)
	sprite_path += ".png"
	
	# 🔥 LIMPIAR SPRITE ANTERIOR SI EXISTE
	if sprite_node != null:
		sprite_node.queue_free()
		sprite_node = null
	
	if pokemon_sprite != null:
		pokemon_sprite.queue_free()
		pokemon_sprite = null
	
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
		
		# 🔥 ASIGNAR REFERENCIA A pokemon_sprite
		pokemon_sprite = sprite_node
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
	Audiomanager.play_sfx("grab_pokemon")
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
	
	if is_pure_disruption:
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
	
	if is_pure_disruption:
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
			print("Se ha pulsado.")
			if is_being_dragged == true or dragging == true:
				return
			# Verificar si la pieza se puede mover
			if not can_be_moved():
				print("Pieza con interferencia - no se puede mover")
				return
			print("Se ha dejado pasar ya que: is_being_dragged = ", str(is_being_dragged)," y dragging =", str(dragging))
			drag_offset = get_global_mouse_position() - global_position
			click_position = get_global_mouse_position()
			has_moved = false
			can_move = false
			animate_pick_up()
			get_viewport().set_input_as_handled()
		else:
			# Si estábamos arrastrando
			if dragging:
				# Si NO se movió significativamente, cancelar
				if not has_moved:
					print("Clic sin arrastrar - volviendo a posición original")
					animate_release()
					dragging = false
					can_move = false
					is_being_dragged = false
					# Volver a la posición sin emitir released
					get_viewport().set_input_as_handled()
				else:
					# Sí hubo arrastre real
					animate_release()
					dragging = false
					can_move = false
					piece_released.emit(self)
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		pass

func _process(delta):
	var board = get_parent()
	if dragging and !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and board.is_processing_matches == false:
		animate_release()
		dragging = false
		return
	
	if dragging and can_move:
		var mouse_pos = get_global_mouse_position()
		
		# Detectar si se ha movido significativamente (más de 10 píxeles)
		if not has_moved and click_position.distance_to(mouse_pos) > 10:
			has_moved = true
		
		global_position = global_position.lerp(mouse_pos - drag_offset, delta * smooth_follow_speed)
	piece_dragged.emit(self, Vector2.ZERO) # 🔥 emite para hover

# Disruption system methods
func set_interference(interference_t: String, hp := 1, non_support_pokemon_id: int = -1):
	"""Sets a disruption on this piece"""
	interference_type = interference_t
	interference_hp = hp
	
	match interference_t:  # 🔥 ERA "match type:" !!!
		"barrier":
			# Congelar el pokemon (se queda visible pero no se puede mover)
			stop_idle_animation()
			if pokemon_sprite != null:
				pokemon_sprite.modulate = Color(0.7, 0.9, 1.0, 1.0)  # Tinte azulado de hielo
			update_interference_visual()
		
		"cloud":
			# Esta versión NO se debería usar, usar set_cloud_interference en su lugar
			if pokemon_sprite != null:
				pokemon_sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)
			update_interference_visual()
		
		"non_support_pokemon":
			# 🔥 CAMBIAR COMPLETAMENTE EL POKEMON (type también)
			if non_support_pokemon_id != -1:
				is_non_support_pokemon = true
				pokemon_id = non_support_pokemon_id
				pokemon_form = 0
				pokemon_level = 1
				type = -1  # No matchea con piezas normales del equipo
				load_pokemon_sprite()
		
		"rock", "block":
			# Estos tipos no deberían llegar aquí si usamos setup_as_disruption
			if pokemon_sprite != null:
				pokemon_sprite.visible = false
			pokemon_id = -1
			update_interference_visual()
	
	# Sonidos
	match interference_t:  # 🔥 ERA "match type:" !!!
		"rock":
			Audiomanager.play_sfx("damage")
		"block":
			Audiomanager.play_sfx("damage")
		"barrier":
			Audiomanager.play_sfx("accept")
		"cloud":
			Audiomanager.play_sfx("grab_pokemon")
		"non_support_pokemon":
			Audiomanager.play_sfx("put_pokemon")


func weaken_interference() -> bool:
	"""Reduces interference HP and removes it if HP reaches 0"""
	if interference_type == "":
		return false
	
	# Barrier y cloud NO se debilitan con matches adyacentes
	if interference_type == "barrier" or interference_type == "cloud":
		return false
	
	# Rock y block SÍ se debilitan
	if interference_type == "rock" or interference_type == "block":
		interference_hp -= 1
		
		if interference_hp <= 0:
			# Si es disrupción pura (rock/block), la pieza se destruye completamente
			if is_pure_disruption:
				Audiomanager.play_sfx("release_pokemon")
				return true  # Señal para eliminar la pieza
			else:
				# Si tenía pokemon debajo, restaurarlo
				clear_interference()
				return false
		else:
			# Actualizar visual para mostrar daño
			update_interference_visual()
			return false
	
	return false

func update_interference_visual():
	"""Updates the visual overlay for the current interference"""
	if interference_overlay != null:
		interference_overlay.queue_free()
		interference_overlay = null
	
	if interference_type == "":
		return
	
	interference_overlay = TextureRect.new()
	interference_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interference_overlay.size = Vector2(tile_size, tile_size)
	interference_overlay.position = Vector2(0, 0)
	interference_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	interference_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var texture_path = ""
	match interference_type:
		"rock":
			texture_path = "res://assets/sprites/grid/disruptions/Rock.png"
		"block":
			texture_path = "res://assets/sprites/grid/disruptions/Block.png"
			# Mostrar más dañado si tiene menos HP
			if interference_hp == 1:
				interference_overlay.modulate = Color(0.7, 0.7, 0.7, 1.0)
		"barrier":
			texture_path = "res://assets/sprites/ui/disruption_barrier.svg"
			interference_overlay.modulate = Color(0.8, 1.0, 1.0, 0.7)  # Tinte azul hielo semi-transparente
		"cloud":
			texture_path = "res://assets/sprites/grid/disruptions/Black_Cloud.png"
			interference_overlay.modulate = Color(1.0, 1.0, 1.0, 0.8)  # Nube oscura
		"non_support_pokemon":
			return  # No necesita overlay
	
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		interference_overlay.texture = texture
		add_child(interference_overlay)
		
		# Animación de aparición
		interference_overlay.scale = Vector2(0.1, 0.1)
		var tween = create_tween()
		tween.tween_property(interference_overlay, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func clear_interference():
	"""Removes the interference and restores normal behavior"""
	var was_barrier = (interference_type == "barrier")
	var was_cloud = (interference_type == "cloud")
	var was_non_support = is_non_support_pokemon
	
	# Reset interference data
	interference_type = ""
	interference_hp = 1
	is_non_support_pokemon = false
	cloud_grid_position = []
	
	# Animar salida del overlay
	if interference_overlay != null:
		var tween = create_tween()
		tween.tween_property(interference_overlay, "scale", Vector2(0.0, 0.0), 0.2).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(interference_overlay, "modulate:a", 0.0, 0.2)
		
		await tween.finished
		interference_overlay.queue_free()
		interference_overlay = null
	
	# Restaurar pokemon
	if was_barrier:
		# 🔥 DESCONGELAR: El pokemon vuelve a la normalidad pero NO SE ELIMINA
		if pokemon_sprite != null:
			pokemon_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		resume_idle_animation()
		# NO restaurar datos originales, el pokemon sigue siendo el mismo
	
	elif was_cloud:
		# Quitar la nube y restaurar brillo del pokemon
		if pokemon_sprite != null:
			pokemon_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	elif was_non_support and not original_pokemon_data.is_empty():
		# Restaurar pokemon original si era non-support
		pokemon_id = original_pokemon_data["id"]
		pokemon_form = original_pokemon_data["form"]
		pokemon_level = original_pokemon_data["level"]
		# 🔥 RESTAURAR EL TYPE TAMBIÉN
		# Esto requiere calcular el type correcto del team original
		load_pokemon_sprite()
	
	# Sonido solo si NO es barrier (barrier no hace sonido al descongelarse)
	if not was_barrier:
		Audiomanager.play_sfx("release_pokemon")

func clear_interference_sync():
	"""Versión síncrona de clear_interference (sin await) para barriers en matches"""
	var was_barrier = (interference_type == "barrier")
	var was_cloud = (interference_type == "cloud")
	var was_non_support = is_non_support_pokemon
	
	# Reset interference data
	var old_interference = interference_type
	interference_type = ""
	interference_hp = 1
	is_non_support_pokemon = false
	cloud_grid_position = []
	
	# Animar salida del overlay SIN AWAIT
	if interference_overlay != null:
		var tween = create_tween()
		tween.tween_property(interference_overlay, "scale", Vector2(0.0, 0.0), 0.2).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(interference_overlay, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): 
			if interference_overlay != null and is_instance_valid(interference_overlay):
				interference_overlay.queue_free()
				interference_overlay = null
		)
	
	# Restaurar pokemon
	if was_barrier:
		# 🔥 DESCONGELAR: El pokemon vuelve a la normalidad pero NO SE ELIMINA
		if pokemon_sprite != null:
			pokemon_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if idle_timer != null and is_instance_valid(idle_timer):
			resume_idle_animation()
	
	elif was_cloud:
		# Quitar la nube y restaurar brillo del pokemon
		if pokemon_sprite != null:
			pokemon_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	elif was_non_support and not original_pokemon_data.is_empty():
		# Restaurar pokemon original si era non-support
		pokemon_id = original_pokemon_data["id"]
		pokemon_form = original_pokemon_data["form"]
		pokemon_level = original_pokemon_data["level"]
		# 🔥 RESTAURAR EL TYPE TAMBIÉN
		if original_pokemon_data.has("type"):
			type = original_pokemon_data["type"]
		load_pokemon_sprite()
	
	# Sonido solo si NO es barrier
	if not was_barrier:
		Audiomanager.play_sfx("release_pokemon")


func can_be_moved() -> bool:
	"""Returns true if this piece can be moved/swapped"""
	# Disrupciones puras (rock/block/cloud) NO se pueden mover manualmente
	if is_pure_disruption:
		return false
	
	# Barriers congelados NO se pueden mover
	if interference_type == "barrier":
		return false
	
	# Cloud independiente NO se puede mover
	if interference_type == "cloud" and pokemon_id == -1:
		return false
	
	return true

func is_matchable() -> bool:
	"""Returns true if this piece can be part of a match"""
	# Disrupciones puras NO son matcheables
	if is_pure_disruption:
		return false
	
	# Rock, block y CLOUD NO son matcheables
	if interference_type in ["rock", "block", "cloud"]:
		return false
	
	# Barriers SÍ son matcheables
	return true

func get_interference_resistance() -> int:
	"""Returns the resistance value for match-based destruction"""
	match interference_type:
		"rock":
			return 1  # Breaks with 1 adjacent match
		"block":
			return interference_hp  # Requires multiple hits
		"barrier":
			return 1  # Breaks with 1 match including this piece
		"cloud":
			return 1  # Clears with 1 match including this piece
		_:
			return 0  # No resistance
func set_cloud_interference(grid_pos: Array):
	"""Establece una nube FIJA en una posición de grid específica"""
	interference_type = "cloud"
	interference_hp = 1
	cloud_grid_position = grid_pos  # Guardar posición fija
	
	# Oscurecer el pokemon
	if pokemon_sprite != null:
		pokemon_sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)
	
	update_interference_visual()
	Audiomanager.play_sfx("grab_pokemon")
func clear_cloud_from_grid():
	"""Limpia la nube del sistema de grid (cuando el pokemon se elimina en match)"""
	if interference_type == "cloud":
		cloud_grid_position = []
