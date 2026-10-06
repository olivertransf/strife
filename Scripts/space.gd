@tool
extends Marker3D
class_name Spaces

enum SpaceType {
	PAYDAY,
	ACTION,
	HOUSE,
	START,
	BOY,
	GIRL,
	SPIN2WIN,
	TWINS,
	STAR,
	STOP,
	BONUS,
	DEBT,
	END,
	PET,
	PARK
}

@export var space_type: SpaceType
@export var stop_kind: String = ""
@export var baby_count: int = 0

@export var next_spaces: Array[NodePath] = []
