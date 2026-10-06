extends Marker2D
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
	END
}

@export var space_type: SpaceType

@export var next_spaces: Array[NodePath] = []
