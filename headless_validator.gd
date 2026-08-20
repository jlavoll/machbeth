extends SceneTree

func _init() -> void:
	print("==================================================")
	print("  STARTING HEADLESS VALIDATION CHECKS (Godot 4)")
	print("==================================================")
	
	var total_errors: int = 0
	var total_scripts: int = 0
	var total_scenes: int = 0
	
	var dir = DirAccess.open("res://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var scripts_to_test: Array[String] = []
		var scenes_to_test: Array[String] = []
		
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".gd") and file_name != "headless_validator.gd":
					scripts_to_test.append("res://" + file_name)
				elif file_name.ends_with(".tscn"):
					scenes_to_test.append("res://" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		
		print("\n--- [1/2] Checking %d GDScript files for compilation ---" % scripts_to_test.size())
		for script_path in scripts_to_test:
			total_scripts += 1
			var script_res = load(script_path)
			if script_res == null:
				print("  ❌ ERROR: Failed to load/compile script: ", script_path)
				total_errors += 1
		print("  ✅ %d scripts parsed and loaded." % total_scripts)
		
		print("\n--- [2/2] Checking %d PackedScenes for validity ---" % scenes_to_test.size())
		for scene_path in scenes_to_test:
			total_scenes += 1
			var scene_res = load(scene_path)
			if scene_res == null or not (scene_res is PackedScene):
				print("  ❌ ERROR: Failed to load PackedScene: ", scene_path)
				total_errors += 1
			else:
				var instance = scene_res.instantiate()
				if instance == null:
					print("  ❌ ERROR: Failed to instantiate PackedScene: ", scene_path)
					total_errors += 1
				else:
					instance.free()
		print("  ✅ %d scenes loaded and instantiated." % total_scenes)
	
	print("\n==================================================")
	if total_errors == 0:
		print("  ✅ HEADLESS VALIDATION PASSED: 0 ERRORS FOUND")
	else:
		print("  ❌ HEADLESS VALIDATION FAILED: %d ERRORS" % total_errors)
	print("==================================================")
	
	quit(0 if total_errors == 0 else 1)
