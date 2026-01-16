extends Node2D
@export var level_scene: PackedScene
var level_nodes = []
var max_unlocked_level = 1
const START_POS := Vector2(400.0, 1308.0)
const LEVEL_SPACING := 220.0
var dragging := false
var last_mouse_y := 0.0
const ZIG_ZAG_AMOUNT := 70.0
@export var bg_height := 1024.0
var bg_nodes := []
const BACKGROUNDS_PER_WORLD := 3
@export var total_worlds := 10  # Ajusta según cuántos worlds tengas

var current_world := 1
var current_bg_in_world := 1
var bg_counter := 0

func _ready():
	# Crear 3 nodos de fondo para tener suficiente buffer
	for i in range(3):
		var sprite = Sprite2D.new()
		sprite.position = Vector2(360.0, -bg_height * i)
		$Background.add_child(sprite)
		bg_nodes.append(sprite)
		load_next_background(sprite)
	
	generate_levels(50)

func load_next_background(sprite: Sprite2D):
	var path = "res://assets/sprites/backgrounds/w%d-%d.png" % [current_world, current_bg_in_world]
	
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		push_warning("Background not found: " + path)
	
	# Avanzar al siguiente fondo
	current_bg_in_world += 1
	if current_bg_in_world > BACKGROUNDS_PER_WORLD:
		current_bg_in_world = 1
		current_world += 1
		if current_world > total_worlds:
			current_world = 1  # Reiniciar al primer world si se acaban

func _process(_delta):
	var min_y = START_POS.y - LEVEL_SPACING * level_nodes.size() + 400
	var max_y = START_POS.y - 400
	$Camera2D.position.y = clamp(
		$Camera2D.position.y,
		min_y,
		max_y
	)
	update_backgrounds()

func generate_levels(count: int):
	for i in range(1, count + 1):
		var node = level_scene.instantiate()
		node.level_id = i
		node.position = get_level_position(i)
		$LevelNodes.add_child(node)
		node.setup()
		level_nodes.append(node)
		
func get_level_position(id: int) -> Vector2:
	var y = START_POS.y - (id - 1) * LEVEL_SPACING
	var x = START_POS.x + sin(id * 0.6) * ZIG_ZAG_AMOUNT
	return Vector2(x, y)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		last_mouse_y = event.position.y
	elif event is InputEventMouseMotion and dragging:
		var delta_y = event.position.y - last_mouse_y
		$Camera2D.position.y -= delta_y
		last_mouse_y = event.position.y

func update_backgrounds():
	var cam_y = $Camera2D.position.y
	
	# Ordenar fondos por posición Y
	bg_nodes.sort_custom(func(a, b): return a.position.y < b.position.y)
	
	for bg in bg_nodes:
		var offset = bg.position.y - cam_y
		
		# Si el fondo está muy arriba (la cámara bajó), moverlo abajo y cargar nuevo
		if offset < -bg_height * 1.5:
			var lowest_y = bg_nodes[0].position.y
			for other_bg in bg_nodes:
				if other_bg != bg and other_bg.position.y > lowest_y:
					lowest_y = other_bg.position.y
			bg.position.y = lowest_y + bg_height
			load_next_background(bg)
		
		# Si el fondo está muy abajo (la cámara subió), moverlo arriba y cargar nuevo
		elif offset > bg_height * 0.5:
			var highest_y = bg_nodes[0].position.y
			for other_bg in bg_nodes:
				if other_bg != bg and other_bg.position.y < highest_y:
					highest_y = other_bg.position.y
			bg.position.y = highest_y - bg_height
			load_next_background(bg)
