extends Node

func translate_type(type: String, lang: String) -> String:
	type = type.to_lower() # Aseguramos formato interno consistente
	
	var translations = {
		"en": { 
			"normal": "Normal",
			"fire": "Fire",
			"water": "Water",
			"grass": "Grass",
			"electric": "Electric",
			"ice": "Ice",
			"fighting": "Fighting",
			"poison": "Poison",
			"ground": "Ground",
			"flying": "Flying",
			"psychic": "Psychic",
			"bug": "Bug",
			"rock": "Rock",
			"ghost": "Ghost",
			"dragon": "Dragon",
			"dark": "Dark",
			"steel": "Steel",
			"fairy": "Fairy"
		},
		"es": { # Español
			"normal": "Normal",
			"fire": "Fuego",
			"water": "Agua",
			"grass": "Planta",
			"electric": "Eléctrico",
			"ice": "Hielo",
			"fighting": "Lucha",
			"poison": "Veneno",
			"ground": "Tierra",
			"flying": "Volador",
			"psychic": "Psíquico",
			"bug": "Bicho",
			"rock": "Roca",
			"ghost": "Fantasma",
			"dragon": "Dragón",
			"dark": "Siniestro",
			"steel": "Acero",
			"fairy": "Hada"
		},
		"fr": { # Français (opcional, ejemplo)
			"normal": "Normal",
			"fire": "Feu",
			"water": "Eau",
			"grass": "Plante",
			"electric": "Électrik",
			"ice": "Glace",
			"fighting": "Combat",
			"poison": "Poison",
			"ground": "Sol",
			"flying": "Vol",
			"psychic": "Psy",
			"bug": "Insecte",
			"rock": "Roche",
			"ghost": "Spectre",
			"dragon": "Dragon",
			"dark": "Ténèbres",
			"steel": "Acier",
			"fairy": "Fée"
		}
	}
	
	var lang_dict = translations.get(lang, translations["en"])
	return lang_dict.get(type, type.capitalize())
