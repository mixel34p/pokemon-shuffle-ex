extends Control

# Configuración
const SPAWN_Y = 50  # Y fija para spawn
const GRAVITY = 1000
const BOUNCE_STRENGTH = -400
const SPAWN_INTERVAL = 2.0
const SCREEN_WIDTH = 600

# Rutas a los sprites (ajusta estas rutas según tu proyecto)
const SPRITE_PATHS = [
	"res://assets/sprites/pokemon/icons/810.png", 
	"res://assets/sprites/pokemon/icons/813.png", 
	"res://assets/sprites/pokemon/icons/816.png",
	"res://assets/sprites/pokemon/icons/25.png", 
	"res://assets/sprites/pokemon/icons/52_2.png", 
	"res://assets/sprites/pokemon/icons/77_1.png", 
	"res://assets/sprites/pokemon/icons/78_1.png",
	"res://assets/sprites/pokemon/icons/83_1.png"  
]


# 8 tipos de objetos diferentes
enum ObjectType {
	CIRCLE,
	SQUARE,
	TRIANGLE,
	STAR,
	HEXAGON,
	DIAMOND,
	PENTAGON,
	CROSS
}

var spawn_timer = 0.0

# Referencia al Area2D (asignar en el editor o por código)
@export var bounce_area: Area2D

func _ready():
	$".".modulate = Color.BLACK
	var fadeout_tween = create_tween()
	fadeout_tween.tween_property($".", "modulate", Color.WHITE,0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fadeout_tween.finished
	randomize()
	$AudioStreamPlayer.play()
	# Si no se asignó el area, buscarla en la escena
	if bounce_area == null:
		bounce_area = get_node_or_null("BounceArea")
		if bounce_area == null:
			push_warning("No se encontró BounceArea. Crear una en la escena.")
		else:
			print("BounceArea encontrada en: ", bounce_area.position)

func _process(delta):
	spawn_timer += delta
	if spawn_timer >= SPAWN_INTERVAL:
		spawn_timer = 0.0
		spawn_object()

func spawn_object():
	var obj = FallingObject.new()
	obj.position = Vector2(randf() * SCREEN_WIDTH, SPAWN_Y)
	obj.object_type = randi() % 8
	obj.sprite_path = SPRITE_PATHS[obj.object_type]
	obj.custom_gravity = GRAVITY
	obj.bounce_strength = BOUNCE_STRENGTH
	obj.rotation_speed = randf_range(-3, 3) if randf() > 0.5 else 0
	obj.bounce_area = bounce_area
	obj.bounce_y = bounce_area.position.y if bounce_area != null else 400
	get_node("Pokemon").add_child(obj)

# Clase para objetos que caen
class FallingObject extends Area2D:
	var velocity = Vector2.ZERO
	var object_type = 0
	var has_bounced = false
	var custom_gravity = 500
	var bounce_strength = -400
	var rotation_speed = 0
	var bounce_area: Area2D
	var bounce_y = 400
	var sprite_path = ""
	var collision_shape: CollisionShape2D
	var sprite: Sprite2D
	var shadow: Node2D
	
	func _ready():
		# Crear CollisionShape2D
		collision_shape = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 25
		collision_shape.shape = shape
		add_child(collision_shape)
		
		# Crear Sprite2D para el objeto
		sprite = Sprite2D.new()
		if ResourceLoader.exists(sprite_path):
			sprite.texture = load(sprite_path)
			# Escalar el sprite (ajusta estos valores)
			sprite.scale = Vector2(0.75, 0.75)  # 50% del tamaño original
		else:
			# Si no existe el sprite, crear uno temporal
			print("Sprite no encontrado: ", sprite_path, " - Usando forma por defecto")
		add_child(sprite)
		
		# Crear nodo para la sombra
		shadow = ShadowNode.new()
		shadow.parent_obj = self
		add_child(shadow)
		
		# Conectar señal de colisión SOLO si bounce_area existe
		if bounce_area != null:
			area_entered.connect(_on_area_entered)
			print("Objeto creado. Esperando colisión con: ", bounce_area.name)
	
	func _process(delta):
		# Aplicar gravedad
		velocity.y += custom_gravity * delta
		position += velocity * delta
		
		# Aplicar rotación al sprite
		sprite.rotation += rotation_speed * delta
		
		# Si ya rebotó y está cayendo de nuevo, desactivar colisiones
		if has_bounced and velocity.y > 50:
			if monitoring or monitorable:
				monitoring = false
				monitorable = false
				print("Objeto atravesando el suelo...")
		
		# Actualizar sombra
		shadow.queue_redraw()
		
		# Eliminar cuando salga muy abajo de la pantalla
		if position.y > 2000:
			print("Objeto eliminado")
			queue_free()
	
	func _on_area_entered(area):
		print("¡Colisión con: ", area.name, "!")
		
		# Verificar que sea el área correcta y no haya rebotado
		if area == bounce_area and !has_bounced:
			has_bounced = true
			velocity.y = bounce_strength
			print("¡REBOTE! Velocidad Y ahora es: ", velocity.y)
			
			# Chance de cambiar rotación al rebotar
			if randf() > 0.7:
				rotation_speed = randf_range(-5, 5)

# Clase para dibujar la sombra
class ShadowNode extends Node2D:
	var parent_obj: Area2D
	
	func _draw():
		if parent_obj == null or parent_obj.bounce_area == null:
			return
		
		# Calcular distancia al suelo
		var distance_to_ground = parent_obj.bounce_y - parent_obj.position.y
		
		# Solo dibujar sombra si está por encima del suelo
		if distance_to_ground > 0 and not parent_obj.has_bounced:
			# Calcular tamaño y opacidad de la sombra según distancia
			var max_distance = 400.0
			var distance_ratio = clamp(1.0 - (distance_to_ground / max_distance), 0.0, 1.0)
			
			# Tamaño de la sombra (crece al acercarse)
			var shadow_size = 10 + (distance_ratio * 20)
			
			# Opacidad de la sombra (más visible al acercarse)
			var shadow_alpha = distance_ratio * 0.5
			
			# Posición de la sombra (en el suelo)
			var shadow_pos = Vector2(0, distance_to_ground)
			
			# Dibujar sombra elíptica
			draw_circle(shadow_pos, shadow_size, Color(0, 0, 0, shadow_alpha))
