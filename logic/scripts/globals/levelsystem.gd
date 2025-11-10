# LevelDatabase.gd
# Base de datos de niveles escalable
# Coloca este archivo en res://logic/data/LevelDatabase.gd

extends Node
class_name LevelDatabase

# ========== OPCIÓN 1: ARRAY DE STRINGS COMPACTOS ==========
# La más simple y eficiente para muchos niveles

const LEVELS_COMPACT = [
	# Nivel 1 (36 caracteres = 6x6 grid)
	"......R.01.R..X..X...CC.....B..B......",
	
	# Nivel 2
	"R....R............XX............R....R",
	
	# Nivel 3
	"XXXXXX........................XXXXXX",
	
	# Nivel 4
	"..BB....BB......................BB..BB",
	
	# Nivel 5
	"CCCCCC..............................",
	
	# Puedes añadir 1000+ niveles aquí fácilmente
	# Cada string = 1 nivel
]

static func get_level_config_compact(level_number: int) -> GridInitialConfig:
	"""Obtiene configuración de nivel desde array compacto"""
	if level_number < 1 or level_number > LEVELS_COMPACT.size():
		push_warning("Nivel " + str(level_number) + " no existe, usando default")
		return GridInitialConfig.create_default()
	
	return GridInitialConfig.from_compact_string(LEVELS_COMPACT[level_number - 1])


# ========== OPCIÓN 2: DICCIONARIO DE NIVELES ==========
# Más legible, ideal para niveles con patrones complejos

const LEVELS_DICT = {
	1: {
		"default": "all",
		"rocks": [[0,0], [5,5]]
	},
	2: {
		"default": "all",
		"barriers": [[2,2], [3,3]],
		"clouds": [[1,1], [4,4]]
	},
	3: {
		"default": "all",
		"blocks": {"positions": [[1,1], [4,4]], "hp": 2},
		"non_support": {"19": [[2,3]]}
	},
	# ... más niveles
}

static func get_level_config_dict(level_number: int) -> GridInitialConfig:
	"""Obtiene configuración de nivel desde diccionario"""
	if not LEVELS_DICT.has(level_number):
		push_warning("Nivel " + str(level_number) + " no existe, usando default")
		return GridInitialConfig.create_default()
	
	return GridInitialConfig.from_dictionary(LEVELS_DICT[level_number])


# ========== OPCIÓN 3: ARCHIVO JSON EXTERNO ==========
# Ideal para editar niveles sin recompilar

static func load_levels_from_json(json_path: String = "res://logic/data/levels.json") -> Dictionary:
	"""
	Carga niveles desde JSON
	Formato del JSON:
	{
		"1": {
			"grid": "......R.01.R..X..X...CC.....B..B......",
			"moves": 20,
			"enemy_hp": 5000
		},
		"2": {
			"grid": "R....R............XX............R....R",
			"moves": 25,
			"enemy_hp": 6000
		}
	}
	"""
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("No se pudo abrir " + json_path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Error parseando JSON: " + json_path)
		return {}
	
	return json.get_data()

static func get_level_config_from_json(level_number: String, levels_data: Dictionary) -> GridInitialConfig:
	"""Obtiene configuración desde datos JSON cargados"""
	var level_key = str(level_number)
	
	if not levels_data.has(level_key):
		push_warning("Nivel " + str(level_number) + " no existe en JSON")
		return GridInitialConfig.create_default()
	
	var level_data = levels_data[level_key]
	var grid_data = level_data.get("grid", "")
	
	# 🔥 Soportar ambos formatos
	if grid_data is Array:
		return GridInitialConfig.from_array(grid_data)
	elif grid_data is String:
		return GridInitialConfig.from_compact_string(grid_data)
	else:
		push_error("Formato de grid inválido en nivel " + level_number)
		return GridInitialConfig.create_default()


# ========== OPCIÓN 4: GENERACIÓN PROCEDURAL ==========
# Genera niveles automáticamente según reglas

static func generate_procedural_level(level_number: int) -> GridInitialConfig:
	"""Genera nivel proceduralmente según número de nivel"""
	var config = GridInitialConfig.new()
	config.set_all_default()
	
	# Dificultad aumenta con el número de nivel
	var difficulty = min(level_number / 10, 10)
	
	# Añadir rocas según dificultad
	var num_rocks = int(difficulty / 2)
	for i in range(num_rocks):
		var x = randi() % 6
		var y = randi() % 6
		config.set_cell(x, y, GridInitialConfig.CellType.ROCK)
	
	# Añadir barriers en niveles altos
	if level_number > 20:
		var num_barriers = int(difficulty / 3)
		for i in range(num_barriers):
			var x = randi() % 6
			var y = randi() % 6
			config.set_cell(x, y, GridInitialConfig.CellType.BARRIER)
	
	# Añadir blocks en niveles muy altos
	if level_number > 50:
		var num_blocks = int(difficulty / 4)
		for i in range(num_blocks):
			var x = randi() % 6
			var y = randi() % 6
			config.set_cell(x, y, GridInitialConfig.CellType.BLOCK, -1, -1, 2)
	
	return config


# ========== OPCIÓN 5: PATRONES REUTILIZABLES ==========
# Define patrones base y combínalos

const PATTERN_TEMPLATES = {
	"corners_rocks": [[0,0], [5,0], [0,5], [5,5]],
	"center_cross": [[2,2], [3,2], [2,3], [3,3], [1,2], [4,2], [2,1], [2,4]],
	"top_barrier": [[0,0], [1,0], [2,0], [3,0], [4,0], [5,0]],
	"diagonal": [[0,0], [1,1], [2,2], [3,3], [4,4], [5,5]],
}

static func create_from_patterns(patterns: Dictionary) -> GridInitialConfig:
	"""
	Crea nivel combinando patrones
	Ejemplo:
	{
		"corners_rocks": "ROCK",
		"center_cross": "BARRIER",
		"diagonal": "CLOUD"
	}
	"""
	var config = GridInitialConfig.new()
	config.set_all_default()
	
	for pattern_name in patterns.keys():
		if not PATTERN_TEMPLATES.has(pattern_name):
			continue
		
		var positions = PATTERN_TEMPLATES[pattern_name]
		var cell_type_str = patterns[pattern_name]
		
		for pos in positions:
			if pos.size() == 2:
				match cell_type_str:
					"ROCK":
						config.set_cell(pos[0], pos[1], GridInitialConfig.CellType.ROCK)
					"BLOCK":
						config.set_cell(pos[0], pos[1], GridInitialConfig.CellType.BLOCK)
					"BARRIER":
						config.set_cell(pos[0], pos[1], GridInitialConfig.CellType.BARRIER)
					"CLOUD":
						config.set_cell(pos[0], pos[1], GridInitialConfig.CellType.CLOUD)
	
	return config


# ========== GESTOR COMPLETO DE NIVELES ==========

class LevelManager:
	var levels_data: Dictionary = {}
	var current_level: int = 1
	
	func _init():
		# Cargar datos de niveles al inicializar
		levels_data = LevelDatabase.load_levels_from_json()
	
	func get_current_level_config() -> GridInitialConfig:
		"""Obtiene configuración del nivel actual"""
		return get_level_config(current_level)
	
	func get_level_config(level_number: int) -> GridInitialConfig:
		"""Obtiene configuración de cualquier nivel"""
		# Prioridad: JSON > Array Compacto > Procedural
		
		# 1. Intentar cargar desde JSON
		if levels_data.size() > 0:
			return LevelDatabase.get_level_config_from_json(str(level_number), levels_data)
		
		# 2. Intentar cargar desde array compacto
		if level_number <= LevelDatabase.LEVELS_COMPACT.size():
			return LevelDatabase.get_level_config_compact(level_number)
		
		# 3. Generar proceduralmente
		return LevelDatabase.generate_procedural_level(level_number)
	
	func next_level():
		"""Avanza al siguiente nivel"""
		current_level += 1
	
	func reset_to_level(level_number: int):
		"""Reinicia a un nivel específico"""
		current_level = level_number


# ========== EJEMPLOS DE USO ==========

# Ejemplo: Cargar nivel específico
static func example_load_level():
	var config = get_level_config_compact(1)
	# Usar config con Main.gd
	
# Ejemplo: Sistema completo
static func example_full_system():
	var manager = LevelManager.new()
	var config = manager.get_current_level_config()
	# Pasar config a Main.gd
	manager.next_level()


# ========== HERRAMIENTA DE CREACIÓN DE NIVELES ==========

static func visual_editor_to_compact(visual_grid: Array) -> String:
	"""
	Convierte grid visual a string compacto
	Útil para crear niveles visualmente
	
	visual_grid = [
		[".", ".", "R", ".", ".", "."],
		["X", ".", ".", ".", ".", "X"],
		...
	]
	"""
	var result = ""
	for row in visual_grid:
		for cell in row:
			result += cell
	return result

static func print_grid_template():
	"""Imprime plantilla para crear niveles fácilmente"""
	print("=== PLANTILLA DE NIVEL ===")
	print(". . . . . .")
	print(". . . . . .")
	print(". . . . . .")
	print(". . . . . .")
	print(". . . . . .")
	print(". . . . . .")
	print("=== SÍMBOLOS ===")
	print(". = Default (random)")
	print("0-3 = Team Pokemon (índice)")
	print("R = Rock")
	print("B = Block (HP=1)")
	print("B2 = Block (HP=2)")
	print("X = Barrier")
	print("C = Cloud")
	print("_ = Empty")
	print("N:19 = Non-support Pokemon (ID)")
	print("====================")
