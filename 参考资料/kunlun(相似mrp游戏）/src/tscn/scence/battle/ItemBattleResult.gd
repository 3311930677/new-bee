extends TextureRect

var victory = load("res://assets/battle/victory.png")
var failure = load("res://assets/battle/failure.png")

func win():
	self.texture = victory
	pass
func lose():
	self.texture = failure
	pass
