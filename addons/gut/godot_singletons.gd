
# This file is auto-generated as part of the release process.  GUT maintainers
# should not change this file manually.
#
# PATCHED for hive_mind_rpg issue #40: the released GUT 9.7.1 file referenced
# every singleton as a bare identifier, and identifiers that don't exist in
# the running engine (AccessibilityServer under Godot 4.6.x) are parse errors
# that abort headless runs. Singletons are now resolved by name at load time,
# so the list works on any engine version and unknown names are just skipped.
# class_ref still holds the singleton instances themselves, preserving the
# identity semantics double_singleton()/is_singleton() rely on.
static var _singleton_names := [
	"AccessibilityServer",
	"AudioServer",
	"CameraServer",
	"ClassDB",
	"DisplayServer",
	# excluded: EditorInterface,
	"Engine",
	"EngineDebugger",
	"GDExtensionManager",
	# excluded: GDScriptLanguageProtocol,
	"Geometry2D",
	"Geometry3D",
	"IP",
	"Input",
	"InputMap",
	"JavaClassWrapper",
	"JavaScriptBridge",
	"Marshalls",
	"NativeMenu",
	"NavigationMeshGenerator",
	"NavigationServer2D",
	"NavigationServer2DManager",
	"NavigationServer3D",
	"NavigationServer3DManager",
	"OS",
	"Performance",
	"PhysicsServer2D",
	"PhysicsServer2DManager",
	"PhysicsServer3D",
	"PhysicsServer3DManager",
	"ProjectSettings",
	"RenderingServer",
	"ResourceLoader",
	"ResourceSaver",
	"ResourceUID",
	"TextServerManager",
	"ThemeDB",
	"Time",
	"TranslationServer",
	"WorkerThreadPool",
	"XRServer"
]
static var class_ref = []
static var names := []
static func _static_init():
	for singleton_name in _singleton_names:
		if(Engine.has_singleton(singleton_name)):
			class_ref.append(Engine.get_singleton(singleton_name))
			names.append(singleton_name)
