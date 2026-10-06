@tool
extends Node3D

@export var setup_children: bool = false:
	set(value):
		if value:
			print("Setting up children...")
			_setup_all_children()
			setup_children = false

func _setup_all_children():
	var scene_root = get_tree().edited_scene_root
	
	for child in get_children():
		if child is Marker3D:
			# Reset y position
			child.position.y = 0
			
			# Check if MeshInstance3D already exists
			var mesh_instance = null
			for existing_child in child.get_children():
				if existing_child is MeshInstance3D:
					mesh_instance = existing_child
					break
			
			# Create new MeshInstance3D if it doesn't exist
			if mesh_instance == null:
				mesh_instance = MeshInstance3D.new()
				mesh_instance.name = "CylinderMesh"
				child.add_child(mesh_instance)
				mesh_instance.owner = scene_root
			
			# Assign cylinder mesh
			var cylinder = CylinderMesh.new()
			# Optional: You can also adjust mesh properties directly
			# cylinder.top_radius = 0.5 
			# cylinder.bottom_radius = 0.5
			# cylinder.height = 0.2
			mesh_instance.mesh = cylinder
			
			# --- UPDATED SCALE HERE ---
			# Smaller size: 0.8 width/depth, 0.05 height
			mesh_instance.scale = Vector3(1.2, 0.05, 1.2)
			
			# Try to get space_type safely
			var space_type = null
			if child.get("space_type") != null:
				space_type = child.get("space_type")
			
			# Create material and assign color based on space_type
			var material = StandardMaterial3D.new()
			material.albedo_color = get_color_for_type(space_type)
			mesh_instance.material_override = material
			
			print("Processed: ", child.name, " | Scale set to small.")
	
	print("All children setup complete!")

func get_color_for_type(type) -> Color:
	# (Same color matching function as before)
	match type:
		Spaces.SpaceType.PAYDAY: return Color(0.0, 0.8, 0.0)
		Spaces.SpaceType.ACTION: return Color(1.0, 1.0, 0.0)
		Spaces.SpaceType.HOUSE: return Color(0.6, 0.4, 0.2)
		Spaces.SpaceType.START: return Color(1.0, 1.0, 1.0)
		Spaces.SpaceType.BOY: return Color(0.0, 0.5, 1.0)
		Spaces.SpaceType.GIRL: return Color(1.0, 0.4, 0.8)
		Spaces.SpaceType.SPIN2WIN: return Color(0.6, 0.0, 0.8)
		Spaces.SpaceType.TWINS: return Color(0.5, 0.75, 1.0)
		Spaces.SpaceType.STAR: return Color(1.0, 0.84, 0.0)
		Spaces.SpaceType.STOP: return Color(1.0, 0.0, 0.0)
		Spaces.SpaceType.BONUS: return Color(0.4, 1.0, 0.4)
		Spaces.SpaceType.DEBT: return Color(1.0, 0.5, 0.5)
		Spaces.SpaceType.END: return Color(1.0, 1.0, 1.0)
		Spaces.SpaceType.PET: return Color(1.0, 0.55, 0.15)
		Spaces.SpaceType.PARK: return Color(0.75, 0.72, 0.62)
		_: return Color(0.5, 0.5, 0.5)
