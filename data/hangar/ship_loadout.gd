extends Resource
## A ship hull and its starting weapon. Mission upgrades live in the arena.

const WeaponSpec := preload("res://data/weapons/weapon_spec.gd")

@export var id: StringName
@export var title: String
@export var sprite: Texture2D
@export var primary_weapon: WeaponSpec
