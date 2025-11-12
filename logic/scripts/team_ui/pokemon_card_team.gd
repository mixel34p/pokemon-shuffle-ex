extends Control
class_name PokemonCard

# Nodos de la escena
var background: TextureRect
var id_label: Label
var sprite: TextureRect
var level_label: Label
var xp_bar: ProgressBar

# Datos
var pokemon_index: int = -1
var pokemon_data: Dictionary = {}
var is_in_team: bool = false

func _ready():
	# No establecer custom_minimum_size aquí - se hace desde el manager
	custom_minimum_size = Vector2(115, 105)
	# CRÍTICO: El Control raíz debe capturar los eventos
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Buscar nodos
	_find_nodes()
	
	# Hacer que TODOS los hijos ignoren el mouse
	_set_children_mouse_filter_ignore()

func _find_nodes():
	"""Busca los nodos después de estar en el árbol"""
	background = get_node_or_null("Bg")
	var content = get_node_or_null("Content")
	
	if content:
		id_label = content.get_node_or_null("IDLabel")
		sprite = content.get_node_or_null("Sprite")
		level_label = content.get_node_or_null("LevelLabel")
		xp_bar = content.get_node_or_null("XPBar")

func _set_children_mouse_filter_ignore():
	"""Establece IGNORE en todos los hijos para que el padre capture el input"""
	for child in get_children():
		_set_mouse_filter_recursive(child)

func _set_mouse_filter_recursive(node: Node):
	"""Recursivamente pone IGNORE en todos los controles hijos"""
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for child in node.get_children():
		_set_mouse_filter_recursive(child)

func setup(p_data: Dictionary, p_index: int, in_team: bool):
	"""Configura la card con los datos del pokémon"""
	# Si todavía no se buscaron los nodos, buscarlos ahora
	if background == null:
		_find_nodes()
	
	pokemon_data = p_data
	pokemon_index = p_index
	is_in_team = in_team
	
	# Mostrar/ocultar fondo según si está en equipo
	if background:
		background.visible = not in_team
	
	# ID solo si no está en equipo
	if id_label:
		id_label.visible = not in_team
		if not in_team:
			# Mostrar el ID REAL formateado (si tiene forma)
			var pokemon_id = str(pokemon_data.get("id", "?"))
			var display_id = _format_pokemon_id(pokemon_id)
			id_label.text = display_id
	
	# Cargar sprite - El ID ya viene como STRING completo (ej: "503_1" o "503")
	if sprite:
		var pokemon_id = pokemon_data.get("id", "1")
		var sprite_path = "res://assets/sprites/pokemon/icons/" + pokemon_id + ".png"
		
		print("Cargando sprite: ", sprite_path)
		
		if ResourceLoader.exists(sprite_path):
			sprite.texture = load(sprite_path)
		else:
			# Placeholder con el ID
			var placeholder = Label.new()
			placeholder.text = pokemon_id
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			placeholder.add_theme_font_size_override("font_size", 20)
			placeholder.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sprite.add_child(placeholder)
	
	# Nivel
	if level_label:
		level_label.text = str(pokemon_data.get("nivel", 1))
	
	# Barra de XP
	if xp_bar:
		var current_exp = pokemon_data.get("exp", 0)
		var next_level_exp = pokemon_data.get("exp_siguiente_nivel", 100)
		xp_bar.max_value = next_level_exp
		xp_bar.value = current_exp
	
	# CRÍTICO: Asegurar que el mouse_filter esté correcto después del setup
	mouse_filter = Control.MOUSE_FILTER_PASS
	_set_children_mouse_filter_ignore()

func get_sprite_texture() -> Texture2D:
	"""Devuelve la textura del sprite para el drag preview"""
	if sprite:
		return sprite.texture
	return null
func _format_pokemon_id(pokemon_id: String) -> String:
	"""Devuelve el ID formateado, mostrando (Forma X) si aplica"""
	var parts = pokemon_id.split("_")
	if parts.size() == 1:
		return parts[0]
	else:
		var base = parts[0]
		var form = parts[1]
		return "%s" % [base]
		
		
		
func play_selected():
	$AnimationPlayer.play("selected")
	
	
	
func stop_selected():
	$AnimationPlayer.play("RESET")
	$AnimationPlayer.stop()
	
