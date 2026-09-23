extends Node
class_name GameplayAI

var game_engine: Node
var player_id: int = -1

const SUITS: Array[StringName] = [&"clubs", &"diamonds", &"hearts", &"spades"]
const CARD_VALUES: Dictionary = {
	&"6": 0,
	&"7": 1,
	&"8": 2,
	&"9": 3,
	&"J": 4,
	&"Q": 5,
	&"K": 6,
	&"10": 7,
	&"A": 8
}

func configure(engine: Node, controlled_player_id: int) -> void:
	game_engine = engine
	player_id = controlled_player_id

func get_gameplay_state() -> Dictionary:
	if not game_engine or not game_engine.has_method("get_gameplay_state"):
		return {}
	return game_engine.get_gameplay_state(player_id)

func get_count_of_suits() -> Dictionary:
	var suit_counts: Dictionary = {}
	var state: Dictionary = get_gameplay_state()
	for suit: StringName in SUITS:
		suit_counts[suit] = 0
	for card: Node2D in state.get("cards", []):
		var suit: StringName = StringName(str(card.get_meta("suit", "")))
		if suit_counts.has(suit):
			suit_counts[suit] += 1
	return suit_counts

func get_value_of_suits() -> Dictionary:
	var suit_values: Dictionary = {}
	var state: Dictionary = get_gameplay_state()
	for suit: StringName in SUITS:
		suit_values[suit] = 0
	for card: Node2D in state.get("cards", []):
		var suit: StringName = StringName(str(card.get_meta("suit", "")))
		var rank: StringName = StringName(str(card.get_meta("rank", "")))
		if suit_values.has(suit):
			suit_values[suit] += CARD_VALUES.get(rank, 0)
	return suit_values
	
func check_for_possible_trump() -> Dictionary:
	var trump_suits: Dictionary = {}
	for suit: StringName in SUITS:
		trump_suits[suit] = 0
	var state: Dictionary = get_gameplay_state()
	for card: Node2D in state.get("cards", []):
		var suit: StringName = StringName(str(card.get_meta("suit", "")))
		var rank: StringName = StringName(str(card.get_meta("rank", "")))
		if rank == "Q" or rank == "K": 
			trump_suits["suit"] += 1
	return trump_suits
	
func choose_card(_state: Dictionary) -> Node2D:
	return null

func choose_trump(_state: Dictionary) -> StringName:
	return &""
