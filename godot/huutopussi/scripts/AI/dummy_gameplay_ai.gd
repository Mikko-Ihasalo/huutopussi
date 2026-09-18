extends GameplayAI

var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.randomize()

func choose_card(state: Dictionary) -> Node2D:
	var legal_cards: Array[Node2D] = state.get("legal_cards", [])
	if legal_cards.is_empty():
		return null
	return legal_cards[random.randi_range(0, legal_cards.size() - 1)]

func choose_trump(state: Dictionary) -> StringName:
	var legal_suits: Array[StringName] = state.get("declarable_trump_suits", [])
	return legal_suits[0] if not legal_suits.is_empty() else &""