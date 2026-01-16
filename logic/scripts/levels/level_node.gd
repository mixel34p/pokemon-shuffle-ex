extends Node2D
@export var level_id: int
var unlocked := false
var cleared := false
var foe = {
	"id": "1",
}

func setup(is_unlocked = true , is_cleared = true):
	unlocked = is_unlocked
	cleared = is_cleared
	$Button.disabled = not unlocked
	$Label.text = id_stringer(level_id)
	
	# Cargar datos del JSON
	var levels_data = LevelDatabase.load_levels_from_json()
	
	# Acceder directamente al diccionario del nivel
	var level_key = str(level_id)
	if levels_data.has(level_key):
		var level_data = levels_data[level_key]
		
		# Acceder al enemy.id
		if level_data.has("enemy") and level_data["enemy"].has("id"):
			foe["id"] = level_data["enemy"]["id"]
			print("ID del enemigo cargado: ", foe["id"])
	else:
		push_warning("Nivel " + str(level_id) + " no encontrado en JSON")
	
	# Cargar sprite después de asignar el id
	load_foe_sprite()
	start_enemy_idle_animation()
func id_stringer(id):
	var intid = int(id)
	if intid < 10:
		var idstr = ("00"+str(id))
		return idstr
	elif intid >= 10 and intid < 100:
		var idstr = ("0"+str(id))
		return idstr
	else:
		return str(id)
		
func load_foe_sprite():
	var foe_form = parse_foe_id(foe["id"])
	print("Forma del foe: ", foe_form)
	var sprite_path = "res://assets/sprites/pokemon/icons/" + str(foe["id"])
	sprite_path += ".png"
	print("Supuesto path del sprite del foe: ", sprite_path)
	
	if ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		$Poke.texture = texture
	else:
		push_warning("Sprite no encontrado: " + sprite_path)

func parse_foe_id(id_string: String) -> int:
	"""
	Parsea un ID tipo '503_1' y retorna la forma
	Si no tiene forma, retorna 0
	"""
	if "_" in id_string:
		var parts = id_string.split("_")
		return int(parts[1])
	else:
		return 0
func start_enemy_idle_animation():
	var randtime = randf_range(1,6)
	await get_tree().create_timer(randtime).timeout
	if $Poke == null:
		return
	
	var original_pos = $Poke.position
	var original_scale = $Poke.scale
	
	await enemy_idle_jump_loop(original_pos, original_scale)
func enemy_idle_jump_loop(original_pos: Vector2, original_scale: Vector2):
	"""
	Idle tipo Pokémon:
	1. Se aplasta (squash)
	2. Salta (stretch leve)
	3. Recupera la escala mientras cae
	4. Rebote pequeño al aterrizar
	"""
	while is_instance_valid($Poke) and $Poke.get_parent() != null:
		
		# 🟠 FASE 1: Preparación (squash)
		var prep_tween = create_tween()
		prep_tween.set_ease(Tween.EASE_IN_OUT)
		prep_tween.set_trans(Tween.TRANS_SINE)
		prep_tween.tween_property($Poke, "scale:y", original_scale.y * 0.85, 0.12)
		prep_tween.tween_property($Poke, "position:y", original_pos.y + 3, 0.12)
		await prep_tween.finished
		
		# 🔵 FASE 2: Salto (stretch leve)
		var jump_tween = create_tween()
		jump_tween.set_ease(Tween.EASE_OUT)
		jump_tween.set_trans(Tween.TRANS_SINE)
		jump_tween.tween_property($Poke, "scale:y", original_scale.y * 1.05, 0.18)
		jump_tween.tween_property($Poke, "position:y", original_pos.y - 16, 0.18)
		await jump_tween.finished
		
		# 🟢 FASE 3: Caída (vuelve a escala normal durante la bajada)
		var fall_tween = create_tween()
		fall_tween.set_parallel(true)
		fall_tween.set_ease(Tween.EASE_IN)
		fall_tween.set_trans(Tween.TRANS_SINE)
		fall_tween.tween_property($Poke, "position:y", original_pos.y + 2, 0.20)
		fall_tween.tween_property($Poke, "scale:y", original_scale.y, 0.20)
		await fall_tween.finished
		
		# 🟣 FASE 4: Rebote leve (mini squash al aterrizar)
		var rebound_tween = create_tween()
		rebound_tween.set_parallel(true)
		rebound_tween.set_ease(Tween.EASE_OUT)
		rebound_tween.set_trans(Tween.TRANS_SINE)
		rebound_tween.tween_property($Poke, "position:y", original_pos.y, 0.12)
		rebound_tween.tween_property($Poke, "scale:y", original_scale.y * 0.96, 0.12)
		await rebound_tween.finished
		
		# 🩵 FASE 5: Recuperación final (vuelve suave a la forma exacta)
		var settle_tween = create_tween()
		settle_tween.set_ease(Tween.EASE_OUT)
		settle_tween.set_trans(Tween.TRANS_SINE)
		settle_tween.tween_property($Poke, "scale:y", original_scale.y, 0.10)
		await settle_tween.finished
		
		# 🌤️ Pequeña pausa antes del siguiente ciclo
		await get_tree().create_timer(randf_range(0.6, 0.9)).timeout


func _on_button_button_down() -> void:
	Datasharing.current_level = str(level_id)
	get_tree().change_scene_to_file("res://logic/scenes/main.tscn")
	print("Cargando nivel"+ Datasharing.current_level)
