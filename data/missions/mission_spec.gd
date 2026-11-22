extends Resource
## Metadata and tuning shared by the mission selector and arena.

@export var id: StringName
@export var title: String
@export var location: String
@export_range(60.0, 1800.0) var duration_seconds := 240.0
