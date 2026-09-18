extends BiddingAI

var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.randomize()

func choose_bid(state: Dictionary) -> int:
	var highest_bid: int = state.get("highest_bid", 0)
	var maximum_bid := 80 + player_id * 20
	if highest_bid < maximum_bid and highest_bid + 5 < 500:
		return 10 if highest_bid == 0 else highest_bid + 5
	return -1

func choose_discard_cards(state: Dictionary) -> Array[Node2D]:
	var cards: Array[Node2D] = state.get("cards", [])
	var legal_cards: Array[Node2D] = []
	for card in cards:
		var rank := StringName(str(card.get_meta("rank", "")))
		if rank != &"A" and rank != &"10":
			legal_cards.append(card)
	legal_cards.shuffle()
	return legal_cards.slice(0, mini(6, legal_cards.size()))

func choose_rebid(_state: Dictionary) -> int:
	return -1