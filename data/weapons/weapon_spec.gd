extends Resource
## Base weapon parameters before a run applies temporary modifiers.

@export var id: StringName
@export var title: String
@export_range(1.0, 2000.0) var damage := 20.0
@export_range(0.05, 20.0) var interval_seconds := 0.42
@export_range(1.0, 2000.0) var projectile_speed := 710.0
