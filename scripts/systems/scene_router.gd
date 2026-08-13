## Lightweight scene navigation helper (no Autoload required).
class_name SceneRouter
extends RefCounted

const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const LEVEL_SELECT := "res://scenes/menu/level_select.tscn"
const RESEARCH_LAB := "res://scenes/menu/research_lab.tscn"
const SETTINGS := "res://scenes/menu/settings.tscn"
const GAMEPLAY := "res://scenes/main.tscn"


static func change_to(tree: SceneTree, scene_path: String) -> void:
	if tree == null:
		push_error("SceneRouter: SceneTree is null.")
		return
	var err: Error = tree.change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: failed to change to '%s' (error %d)." % [scene_path, err])


static func to_main_menu(tree: SceneTree) -> void:
	change_to(tree, MAIN_MENU)


static func to_level_select(tree: SceneTree) -> void:
	change_to(tree, LEVEL_SELECT)


static func to_research_lab(tree: SceneTree) -> void:
	change_to(tree, RESEARCH_LAB)


static func to_settings(tree: SceneTree) -> void:
	change_to(tree, SETTINGS)


static func to_gameplay(tree: SceneTree) -> void:
	change_to(tree, GAMEPLAY)
