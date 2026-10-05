extends RefCounted
## Shared runtime art approved from the town A/B review.
const FINISH := preload("res://image/style_review_20261005/character_finish.gdshader")
const TURTLE_SOURCE := preload("res://image/style_review_20261005/turtle_matched_v1.png")
static var _character_material: ShaderMaterial
static var _turtle_texture: ImageTexture

static func character_material(role_id: String) -> ShaderMaterial:
	if role_id != "fs": return null
	if _character_material == null:
		_character_material = ShaderMaterial.new()
		_character_material.shader = FINISH
	return _character_material

static func turtle_texture() -> Texture2D:
	if _turtle_texture == null:
		# Match the reviewed 96x96 nearest sampling and existing UI/companion sizing.
		var image := TURTLE_SOURCE.get_image()
		image.resize(96,96,Image.INTERPOLATE_NEAREST)
		_turtle_texture = ImageTexture.create_from_image(image)
	return _turtle_texture
