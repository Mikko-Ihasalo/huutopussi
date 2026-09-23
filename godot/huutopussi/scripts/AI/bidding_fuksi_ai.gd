extends Node
class_name BiddingAI

var game_engine: Node
var player_id: int = -1

# Hyper parameters to change variance in certain aspects.
const ALPHA: float = 2.0 # Used to decrease value of 10's
const BETA: float = 1.0
const GAMMA: float = 1.0 # Used to decrease value of normal points.

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

const TRUMP_POINTS: Dictionary = {
	"spades":40,"clubs":60, "diamonds":80, "hearts":100,
}
func configure(engine: Node, controlled_player_id: int) -> void:
	game_engine = engine
	player_id = controlled_player_id

func get_bidding_state() -> Dictionary:
	if not game_engine or not game_engine.has_method("get_bidding_state"):
		return {}
	return game_engine.get_bidding_state(player_id)

func get_hand_creation_state() -> Dictionary:
	if not game_engine or not game_engine.has_method("get_hand_creation_state"):
		return {}
	return game_engine.get_hand_creation_state(player_id)
	
func get_all_cards_with_given_rank(_state :Dictionary,given_rank: String) -> Dictionary:
	var return_cards: Dictionary = {}
	for card: Node2D in _state.get("cards", []):
		var suit: StringName = StringName(str(card.get_meta("suit", "")))
		var rank: StringName = StringName(str(card.get_meta("rank", "")))
		if rank == given_rank:
			return_cards[suit] = 1
	return return_cards

func check_for_possible_trump() -> Dictionary:
	"""Dictionary containing: 
		0 -> no trump,
		1 -> half of a trump,
		2 -> full trump
		"""
	var trump_suits: Dictionary = {}
	for suit: StringName in SUITS:
		trump_suits[suit] = 0
	var state: Dictionary = get_hand_creation_state()
	for card: Node2D in state.get("cards", []):
		var suit: StringName = StringName(str(card.get_meta("suit", "")))
		var rank: StringName = StringName(str(card.get_meta("rank", "")))
		if rank == "Q" or rank == "K": 
			trump_suits[suit] += 1
	return trump_suits


func evaluate_aces_before_devils_deck(_state :Dictionary) -> int:
	"""10 points per ace, + 20 for the assumed 'final round' if more than 20 aces."""
	var aces: int = get_all_cards_with_given_rank(_state,"A").size()
	if aces >= 3: 
		return aces * 10 + 20
	return aces * 10
	
func evaluate_tens_before_devils_deck(_state :Dictionary) -> int:
	"""10 points for each ten, if a the same suit ace exists, otherwise 5"""
	var tens: Dictionary = get_all_cards_with_given_rank(_state,"10")
	var aces: Dictionary = get_all_cards_with_given_rank(_state,"A")
	var final_sum : float = 0.0
	if not tens.is_empty():
		for suit in SUITS:
			var divider: float = 1.0
			if aces[suit] == 0:
				divider = ALPHA
			final_sum += tens[suit]/divider
	return round(final_sum)
	
func evaluate_trumps_before_devils_deck(_state: Dictionary) -> int:
	"""Calculates the quaranteed points from a trump declaration.
	However, if there is no ace in the opening hand return 0."""
	var count_of_aces: int = get_all_cards_with_given_rank(_state,"A").size()
	var trump:Dictionary = check_for_possible_trump()
	var quaranteed_trumps: int = 0
	for suit in SUITS:
		quaranteed_trumps += min(trump[suit] -1,0)*TRUMP_POINTS[suit]
	return min(count_of_aces,1)*quaranteed_trumps

func evaluate_normal_points_before_devils_deck(_state: Dictionary) -> int:
	"""Gamma is used to decrease the value of normal point cards, since they are not guaranteed"""
	var points: float = 0.0
	points += 5*get_all_cards_with_given_rank(_state,"J").size()/GAMMA
	return round(points)
	
	
func full_evaluation_before_devils_deck(_state :Dictionary) -> int:
	return evaluate_aces_before_devils_deck(
		_state
		) + evaluate_tens_before_devils_deck(
			_state
			) + evaluate_trumps_before_devils_deck(
				_state
				) + evaluate_trumps_before_devils_deck(
					_state
					)
	
func evaluate_aces_after_devils_deck(_state: Dictionary) -> int: 
	return evaluate_aces_before_devils_deck(_state) 

func choose_bid(_state: Dictionary) -> int:
	return -1

func choose_discard_cards(_state: Dictionary) -> Array[Node2D]:
	return []

func choose_rebid(_state: Dictionary) -> int:
	return -1
