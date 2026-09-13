extends Sprite2D

@export var card_index: int = 5
@export var card_suit : String = "clubs"

const CARD_WIDTH = 88
const CARD_HEIGHT = 124
const SUIT_IMAGE_PATH_MAP = {
	"clubs":"res://assets/cards/clubs.png",
	"hearts":"res://assets/cards/hearts.png",
	"spads":"res://assets/cards/spades.png",
	"diamonds":"res://assets/cards/diamonds.png"
}

func _ready():
	var atlas = AtlasTexture.new()
	var image_path = SUIT_IMAGE_PATH_MAP[card_suit]
	atlas.atlas = load(image_path)

	var column = card_index % 5
	var row = card_index / 5

	atlas.region = Rect2(
		column * CARD_WIDTH,
		row * CARD_HEIGHT,
		CARD_WIDTH,
		CARD_HEIGHT
	)

	texture = atlas


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
