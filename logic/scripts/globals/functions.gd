extends Node

func set_type_color(type: String):
	var colors = {
		"fire": Color("ffb3a7"),      # Soft red
		"water": Color("a7d8ff"),     # Soft blue
		"grass": Color("b8f5b1"),     # Soft green
		"electric": Color("fff3a7"),  # Soft yellow
		"ice": Color("b3f0ff"),       # Soft cyan
		"fighting": Color("ffb6a7"),  # Soft orange
		"poison": Color("d1a7ff"),    # Soft violet
		"ground": Color("e6c89a"),    # Light brown
		"flying": Color("c6e6ff"),    # Sky blue
		"psychic": Color("ffb8e6"),   # Soft pink
		"bug": Color("d9ffb3"),       # Soft yellow-green
		"rock": Color("d8c4a3"),      # Beige
		"ghost": Color("cdb3ff"),     # Pale purple
		"dark": Color("b3b3b3"),      # Soft gray
		"dragon": Color("b3b8ff"),    # Lavender blue
		"steel": Color("d6e6f0"),     # Blue-gray
		"fairy": Color("ffd6f0")      # Light pink
	}
	
	var type_color = colors.get(type, Color("ffffff")) # Default to white
	
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = type_color
	
	# Add corner radius
	stylebox.corner_radius_top_left = 7
	stylebox.corner_radius_top_right = 7
	stylebox.corner_radius_bottom_left = 7
	stylebox.corner_radius_bottom_right = 7
	
	return stylebox
