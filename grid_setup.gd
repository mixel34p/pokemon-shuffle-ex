# GridInitialConfig.gd
# Sistema de configuración inicial del tablero
# Coloca este archivo en res://logic/config/GridInitialConfig.gd

extends Resource
class_name GridInitialConfig

# Tipos de contenido de casilla
enum CellType {
	DEFAULT,           # Generación aleatoria normal
	TEAM_POKEMON,      # Pokémon del equipo (índice 0-3)
	NON_SUPPORT,       # Pokémon no soporte (por ID)
	ROCK,              # Interferencia: roca
	BLOCK,             # Interferencia: bloque
	BARRIER,           # Interferencia: barrera
	CLOUD,             # Interferencia: nube
	EMPTY              # Casilla vacía
}

# Configuración de una casilla individual
class CellConfig:
	var type: CellType = CellType.DEFAULT
	var team_index: int = -1      # Índice del equipo (0-3) si es TEAM_POKEMON
	var pokemon_id: int = -1       # ID del Pokémon si es NON_SUPPORT
	var hp: int = 1                # HP si es BLOCK o ROCK
	
	func _init(p_type: CellType = CellType.DEFAULT, p_team_index: int = -1, p_pokemon_id: int = -1, p_hp: int = 1):
		type = p_type
		team_index = p_team_index
		pokemon_id = p_pokemon_id
		hp = p_hp

# Grid 6x6 (cada posición [y][x])
var grid_config: Array = []

func _init():
	# Inicializar grid vacío con DEFAULT
	for y in range(6):
		var row = []
		for x in range(6):
			row.append(CellConfig.new(CellType.DEFAULT))
		grid_config.append(row)

# ========== MÉTODOS DE CONFIGURACIÓN ==========

func set_cell(x: int, y: int, type: CellType, team_index: int = -1, pokemon_id: int = -1, hp: int = 1):
	"""Configura una casilla específica"""
	if x >= 0 and x < 6 and y >= 0 and y < 6:
		grid_config[y][x] = CellConfig.new(type, team_index, pokemon_id, hp)

func set_all_default():
	"""Establece todo el grid como generación aleatoria normal"""
	for y in range(6):
		for x in range(6):
			grid_config[y][x] = CellConfig.new(CellType.DEFAULT)

func set_region(x_start: int, y_start: int, x_end: int, y_end: int, type: CellType, team_index: int = -1, pokemon_id: int = -1, hp: int = 1):
	"""Configura una región rectangular"""
	for y in range(y_start, y_end + 1):
		for x in range(x_start, x_end + 1):
			set_cell(x, y, type, team_index, pokemon_id, hp)

func set_pattern(positions: Array, type: CellType, team_index: int = -1, pokemon_id: int = -1, hp: int = 1):
	"""Configura múltiples posiciones con el mismo tipo
	positions = [[x, y], [x, y], ...]"""
	for pos in positions:
		if pos.size() == 2:
			set_cell(pos[0], pos[1], type, team_index, pokemon_id, hp)

# ========== CREACIÓN DESDE ARRAYS Y STRINGS ==========

static func from_array(grid_array: Array) -> GridInitialConfig:
	"""
	Crea configuración desde array 6x6 de caracteres
	Formato: [[fila0], [fila1], ..., [fila5]]
	
	Símbolos:
	'.' = DEFAULT (random)
	'0'-'3' = TEAM_POKEMON (índice 0-3)
	'R' = ROCK
	'B' = BLOCK (HP=1)
	'B2', 'B3' = BLOCK con HP específico
	'X' = BARRIER
	'C' = CLOUD
	'_' = EMPTY
	'N:19' = NON_SUPPORT con ID 19
	"""
	var config = GridInitialConfig.new()
	
	if grid_array.size() != 6:
		push_error("GridInitialConfig.from_array: Debe tener 6 filas")
		return config
	
	for y in range(6):
		var row = grid_array[y]
		if row.size() != 6:
			push_error("GridInitialConfig.from_array: Fila " + str(y) + " debe tener 6 columnas")
			continue
		
		for x in range(6):
			var cell_data = row[x]
			_parse_cell_data(config, x, y, cell_data)
	
	return config

static func from_string(grid_string: String) -> GridInitialConfig:
	"""
	Crea configuración desde string multi-línea
	Ejemplo:
	'''
	. . . . . .
	R . 0 1 . R
	. X . . X .
	. . C C . .
	. B . . B .
	. . . . . .
	'''
	"""
	var config = GridInitialConfig.new()
	var lines = grid_string.strip_edges().split("\n")
	
	# Filtrar líneas vacías
	var valid_lines = []
	for line in lines:
		var stripped = line.strip_edges()
		if stripped != "":
			valid_lines.append(stripped)
	
	if valid_lines.size() != 6:
		push_error("GridInitialConfig.from_string: Debe tener 6 filas")
		return config
	
	for y in range(6):
		var cells = valid_lines[y].split(" ", false)  # false = no empty strings
		
		if cells.size() != 6:
			push_error("GridInitialConfig.from_string: Fila " + str(y) + " debe tener 6 columnas (tiene " + str(cells.size()) + ")")
			continue
		
		for x in range(6):
			_parse_cell_data(config, x, y, cells[x])
	
	return config

static func from_compact_string(compact: String) -> GridInitialConfig:
	"""
	Crea configuración desde string compacto (sin espacios)
	Ejemplo: "......R.01.R..X..X...CC.....B..B......."
	36 caracteres (6x6)
	"""
	var config = GridInitialConfig.new()
	
	# Remover espacios y saltos de línea
	compact = compact.replace(" ", "").replace("\n", "").replace("\t", "")
	
	if compact.length() != 36:
		push_error("GridInitialConfig.from_compact_string: Debe tener exactamente 36 caracteres (tiene " + str(compact.length()) + ")")
		return config
	
	for y in range(6):
		for x in range(6):
			var index = y * 6 + x
			var cell_char = compact[index]
			_parse_cell_data(config, x, y, cell_char)
	
	return config

static func from_dictionary(dict: Dictionary) -> GridInitialConfig:
	"""
	Crea configuración desde diccionario
	Formato:
	{
		"default": "all",  # o array de posiciones [[x,y], ...]
		"rocks": [[0,0], [5,5]],
		"blocks": {"positions": [[1,1]], "hp": 2},
		"barriers": [[2,2], [3,3]],
		"clouds": [[1,2], [4,3]],
		"team_pokemon": {"0": [[0,1]], "1": [[1,1]]},  # índice: posiciones
		"non_support": {"19": [[2,3]], "25": [[3,4]]},  # id: posiciones
		"empty": [[5,0]]
	}
	"""
	var config = GridInitialConfig.new()
	
	# Default
	if dict.has("default"):
		if dict["default"] == "all":
			config.set_all_default()
		elif dict["default"] is Array:
			for pos in dict["default"]:
				if pos.size() == 2:
					config.set_cell(pos[0], pos[1], CellType.DEFAULT)
	
	# Rocks
	if dict.has("rocks") and dict["rocks"] is Array:
		for pos in dict["rocks"]:
			if pos.size() == 2:
				config.set_cell(pos[0], pos[1], CellType.ROCK)
	
	# Blocks
	if dict.has("blocks"):
		var hp = 1
		var positions = []
		
		if dict["blocks"] is Dictionary:
			hp = dict["blocks"].get("hp", 1)
			positions = dict["blocks"].get("positions", [])
		elif dict["blocks"] is Array:
			positions = dict["blocks"]
		
		for pos in positions:
			if pos.size() == 2:
				config.set_cell(pos[0], pos[1], CellType.BLOCK, -1, -1, hp)
	
	# Barriers
	if dict.has("barriers") and dict["barriers"] is Array:
		for pos in dict["barriers"]:
			if pos.size() == 2:
				config.set_cell(pos[0], pos[1], CellType.BARRIER)
	
	# Clouds
	if dict.has("clouds") and dict["clouds"] is Array:
		for pos in dict["clouds"]:
			if pos.size() == 2:
				config.set_cell(pos[0], pos[1], CellType.CLOUD)
	
	# Team Pokemon
	if dict.has("team_pokemon") and dict["team_pokemon"] is Dictionary:
		for team_index_str in dict["team_pokemon"].keys():
			var team_index = int(team_index_str)
			var positions = dict["team_pokemon"][team_index_str]
			for pos in positions:
				if pos.size() == 2:
					config.set_cell(pos[0], pos[1], CellType.TEAM_POKEMON, team_index)
	
	# Non-support Pokemon
	if dict.has("non_support") and dict["non_support"] is Dictionary:
		for pokemon_id_str in dict["non_support"].keys():
			var pokemon_id = int(pokemon_id_str)
			var positions = dict["non_support"][pokemon_id_str]
			for pos in positions:
				if pos.size() == 2:
					config.set_cell(pos[0], pos[1], CellType.NON_SUPPORT, -1, pokemon_id)
	
	# Empty
	if dict.has("empty") and dict["empty"] is Array:
		for pos in dict["empty"]:
			if pos.size() == 2:
				config.set_cell(pos[0], pos[1], CellType.EMPTY)
	
	return config

static func _parse_cell_data(config: GridInitialConfig, x: int, y: int, data):
	"""Helper para parsear datos de celda desde array o string"""
	var data_str = str(data).strip_edges()
	
	# Default
	if data_str == ".":
		config.set_cell(x, y, CellType.DEFAULT)
	
	# Team Pokemon (0-3)
	elif data_str in ["0", "1", "2", "3"]:
		config.set_cell(x, y, CellType.TEAM_POKEMON, int(data_str))
	
	# Rock
	elif data_str == "R":
		config.set_cell(x, y, CellType.ROCK)
	
	# Block con HP
	elif data_str.begins_with("B"):
		var hp = 1
		if data_str.length() > 1:
			hp = int(data_str.substr(1))
		config.set_cell(x, y, CellType.BLOCK, -1, -1, hp)
	
	# Barrier
	elif data_str == "X":
		config.set_cell(x, y, CellType.BARRIER)
	
	# Cloud
	elif data_str == "C":
		config.set_cell(x, y, CellType.CLOUD)
	
	# Empty
	elif data_str == "_":
		config.set_cell(x, y, CellType.EMPTY)
	
	# Non-support Pokemon (formato N:ID)
	elif data_str.begins_with("N:"):
		var pokemon_id = int(data_str.substr(2))
		config.set_cell(x, y, CellType.NON_SUPPORT, -1, pokemon_id)
	
	else:
		# Si no reconoce, usar default
		config.set_cell(x, y, CellType.DEFAULT)

# ========== CONFIGURACIONES PREDEFINIDAS (SIMPLIFICADAS) ==========

static func create_default() -> GridInitialConfig:
	"""Grid normal - generación aleatoria completa"""
	return from_string("""
		. . . . . .
		. . . . . .
		. . . . . .
		. . . . . .
		. . . . . .
		. . . . . .
	""")

static func create_tutorial_1() -> GridInitialConfig:
	"""Tutorial nivel 1: Fila superior con barriers"""
	return from_string("""
		X X X X X X
		. . . . . .
		. . . . . .
		. . . . . .
		. . . . . .
		. . . . . .
	""")

static func create_tutorial_2() -> GridInitialConfig:
	"""Tutorial nivel 2: Rocas en esquinas"""
	return from_string("""
		R . . . . R
		. . . . . .
		. . . . . .
		. . . . . .
		. . . . . .
		R . . . . R
	""")

static func create_challenge_cross() -> GridInitialConfig:
	"""Desafío: Cruz de barriers en el centro"""
	return from_string("""
		. . X X . .
		. . X X . .
		X X X X X X
		X X X X X X
		. . X X . .
		. . X X . .
	""")

static func create_boss_pattern() -> GridInitialConfig:
	"""Patrón de jefe: Múltiples interferencias"""
	return from_dictionary({
		"default": "all",
		"blocks": {"positions": [[1,1], [4,1], [1,4], [4,4]], "hp": 2},
		"clouds": [[2,2], [3,2], [2,3], [3,3]],
		"non_support": {"19": [[0,2], [5,3]]}
	})

# ========== VALIDACIÓN ==========

func validate() -> bool:
	"""Valida que la configuración sea correcta"""
	var has_at_least_one_playable = false
	
	for y in range(6):
		for x in range(6):
			var cell = grid_config[y][x]
			
			if cell.type == CellType.DEFAULT or cell.type == CellType.TEAM_POKEMON:
				has_at_least_one_playable = true
			
			if cell.type == CellType.TEAM_POKEMON:
				if cell.team_index < 0 or cell.team_index > 3:
					push_error("GridInitialConfig: team_index inválido en [" + str(x) + "," + str(y) + "]")
					return false
			
			if cell.type == CellType.NON_SUPPORT:
				if cell.pokemon_id < 0:
					push_error("GridInitialConfig: pokemon_id inválido en [" + str(x) + "," + str(y) + "]")
					return false
			
			if cell.type in [CellType.BLOCK, CellType.ROCK]:
				if cell.hp < 1:
					push_error("GridInitialConfig: HP inválido en [" + str(x) + "," + str(y) + "]")
					return false
	
	if not has_at_least_one_playable:
		push_warning("GridInitialConfig: El grid no tiene casillas jugables")
	
	return true

# ========== UTILIDADES ==========

func print_config():
	"""Imprime la configuración del grid en consola (útil para debug)"""
	print("=== GRID INITIAL CONFIG ===")
	for y in range(6):
		var row_str = "Fila " + str(y) + ": "
		for x in range(6):
			var cell = grid_config[y][x]
			match cell.type:
				CellType.DEFAULT:
					row_str += "[DEF] "
				CellType.TEAM_POKEMON:
					row_str += "[T" + str(cell.team_index) + "] "
				CellType.NON_SUPPORT:
					row_str += "[NS:" + str(cell.pokemon_id) + "] "
				CellType.ROCK:
					row_str += "[ROCK] "
				CellType.BLOCK:
					row_str += "[BLK:" + str(cell.hp) + "] "
				CellType.BARRIER:
					row_str += "[BAR] "
				CellType.CLOUD:
					row_str += "[CLD] "
				CellType.EMPTY:
					row_str += "[EMP] "
		print(row_str)
	print("===========================")

func to_compact_string() -> String:
	"""Exporta la configuración a string compacto (útil para guardar niveles)"""
	var result = ""
	for y in range(6):
		for x in range(6):
			var cell = grid_config[y][x]
			match cell.type:
				CellType.DEFAULT:
					result += "."
				CellType.TEAM_POKEMON:
					result += str(cell.team_index)
				CellType.ROCK:
					result += "R"
				CellType.BLOCK:
					if cell.hp == 1:
						result += "B"
					else:
						result += "B" + str(cell.hp)
				CellType.BARRIER:
					result += "X"
				CellType.CLOUD:
					result += "C"
				CellType.EMPTY:
					result += "_"
				CellType.NON_SUPPORT:
					result += "N"  # Simplificado para compact
	return result
