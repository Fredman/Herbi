extends Sprite

func _ready():
	pass

func _on_Area2D_body_enter( body ):
	if body.get_name() == "player":
		queue_free()
		get_node("/root/world").add_life()