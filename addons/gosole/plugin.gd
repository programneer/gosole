@tool
extends EditorPlugin
const NAME = "Console"

func _enter_tree():
	add_autoload_singleton(NAME, "res://addons/gosole/console.tscn")
	pass

func _exit_tree():
	remove_autoload_singleton(NAME)
	pass
