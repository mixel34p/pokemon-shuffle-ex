extends Node

var equipo_pokemon: Array = []  # Array de índices que apuntan a all_pokemon (max 4)
var all_pokemon: Array = []  # Array de diccionarios con {id (STRING), nivel, exp}
var inventario: Dictionary = {}
var coins: int = 0
var nick: String = ""
var insignias: Array = []

# Referencia al JSON de datos de Pokémon
var pokemon_data: Dictionary = {}

func _ready():
	cargar_pokemon_data()

func cargar_pokemon_data():
	var archivo = FileAccess.open("res://data/pokemon.json", FileAccess.READ)
	if archivo:
		var json = JSON.new()
		var parse_result = json.parse(archivo.get_as_text())
		if parse_result == OK:
			pokemon_data = json.data
		archivo.close()

# === FUNCIONES PARA POKÉMON ===

func add_pokemon(pokemon_id: String, nivel: int = 1, exp: int = 0) -> int:
	"""
	Agrega un Pokémon a la colección.
	pokemon_id: ID completo como STRING (ej: "503" o "503_1")
	nivel: Nivel del Pokémon
	exp: Experiencia actual
	"""
	var nuevo_pokemon = {
		"id": pokemon_id,
		"nivel": nivel,
		"exp": exp,
		"exp_siguiente_nivel": calcular_exp_siguiente_nivel(nivel)
	}
	all_pokemon.append(nuevo_pokemon)
	
	var indice = all_pokemon.size() - 1
	return indice

func calcular_exp_siguiente_nivel(nivel: int) -> int:
	return int(pow(nivel, 3))

func agregar_a_equipo(indice_pokemon: int) -> bool:
	if equipo_pokemon.size() >= 4:
		return false
	
	if indice_pokemon >= all_pokemon.size():
		return false
	
	if equipo_pokemon.has(indice_pokemon):
		return false
	
	equipo_pokemon.append(indice_pokemon)
	return true

func delete_from_team(index: int):
	equipo_pokemon.erase(index)

func intercambiar_equipo(indice_equipo: int, indice_pokemon: int):
	if indice_equipo < equipo_pokemon.size() and indice_pokemon < all_pokemon.size():
		equipo_pokemon[indice_equipo] = indice_pokemon

func gain_experience(index: int, exp: int):
	if index >= all_pokemon.size():
		return
	
	var pokemon = all_pokemon[index]
	pokemon["exp"] += exp
	
	# Verificar si sube de nivel
	while pokemon["exp"] >= pokemon["exp_siguiente_nivel"]:
		raise_level(index)

func raise_level(index: int):
	if index >= all_pokemon.size():
		return
	
	var pokemon = all_pokemon[index]
	pokemon["nivel"] += 1
	pokemon["exp_siguiente_nivel"] = calcular_exp_siguiente_nivel(pokemon["nivel"])
	
	var datos = obtain_pkm_data(pokemon["id"])
	print(datos.get("nombre", "???"), " subió al nivel ", pokemon["nivel"], "!")

func obtain_pkm_data(pokemon_id: String) -> Dictionary:
	"""
	Obtiene los datos del JSON usando el ID completo.
	Si el ID tiene forma (ej: "503_1"), busca en forms.
	"""
	# Separar ID base y forma
	var parts = pokemon_id.split("_")
	var base_id = parts[0]
	
	if not pokemon_data.has(base_id):
		return {}
	
	var poke_data = pokemon_data[base_id]
	
	# Si tiene forma (ej: "503_1"), buscar en forms
	if parts.size() > 1:
		var form_id = parts[1]
		if poke_data.has("forms") and poke_data["forms"].has(form_id):
			return poke_data["forms"][form_id]
	
	return poke_data

func obtain_full_pokemon(index: int) -> Dictionary:
	if index >= all_pokemon.size():
		return {}
	
	var pokemon = all_pokemon[index]
	var datos = obtain_pkm_data(pokemon["id"])
	
	# Combinar datos del JSON con datos del jugador
	var pokemon_completo = datos.duplicate()
	pokemon_completo["id"] = pokemon["id"]
	pokemon_completo["nivel"] = pokemon["nivel"]
	pokemon_completo["exp"] = pokemon["exp"]
	pokemon_completo["exp_siguiente_nivel"] = pokemon["exp_siguiente_nivel"]
	
	return pokemon_completo

func obtain_full_team() -> Array:
	var equipo = []
	for indice in equipo_pokemon:
		equipo.append(obtain_full_pokemon(indice))
	return equipo

# === FUNCIONES PARA OBJETOS ===

func add_object(objeto_id: int, cantidad: int = 1):
	if inventario.has(objeto_id):
		inventario[objeto_id] += cantidad
	else:
		inventario[objeto_id] = cantidad

func use_object(objeto_id: int, cantidad: int = 1) -> bool:
	if inventario.has(objeto_id) and inventario[objeto_id] >= cantidad:
		inventario[objeto_id] -= cantidad
		if inventario[objeto_id] <= 0:
			inventario.erase(objeto_id)
		return true
	return false

func obtener_cantidad_objeto(objeto_id: int) -> int:
	return inventario.get(objeto_id, 0)

# === SISTEMA DE GUARDADO/CARGA ===

func guardar_datos():
	var datos = {
		"equipo_pokemon": equipo_pokemon,
		"all_pokemon": all_pokemon,
		"inventario": inventario,
		"coins": coins,
		"name": nick,
	}
	
	var archivo = FileAccess.open("user://save_game.dat", FileAccess.WRITE)
	if archivo:
		archivo.store_var(datos)
		archivo.close()
		print("Datos guardados correctamente")

func cargar_datos():
	if not FileAccess.file_exists("user://save_game.dat"):
		print("No hay datos guardados")
		return
	
	var archivo = FileAccess.open("user://save_game.dat", FileAccess.READ)
	if archivo:
		var datos = archivo.get_var()
		equipo_pokemon = datos.get("equipo_pokemon", [])
		all_pokemon = datos.get("all_pokemon", [])
		inventario = datos.get("inventario", {})
		coins = datos.get("coins", 0)
		nick = datos.get("nickname", "")
		insignias = datos.get("insignias", [])
		archivo.close()
