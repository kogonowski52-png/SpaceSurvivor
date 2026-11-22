extends Resource
## Data for a future in-game catalog. A purchase flow can consume this resource.

@export var id: StringName
@export var display_name: String
@export var content_id: StringName
@export var currency_id: StringName
@export_range(0, 1000000) var price := 0
