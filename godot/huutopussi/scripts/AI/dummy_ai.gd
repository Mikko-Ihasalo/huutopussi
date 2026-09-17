extends Node2D

var random := RandomNumberGenerator.new()
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	random.randomize()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func play_turn(game_engine: Node, player_id: int) -> void:
	var legal_cards: Array[Node2D] = game_engine.get_playable_cards(player_id)
	if legal_cards.is_empty():
		return
	game_engine.play_card(player_id, legal_cards[random.randi_range(0, legal_cards.size() - 1)])
