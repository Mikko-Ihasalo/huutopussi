extends Node

var game_engine: Node
var player_id: int = -1
var def_bid_limit:int = 0
var original_bid: int = -1

# Hyper parameters to change variance in certain aspects.
const ALPHA: float = 2.0 # Used to decrease value of 10's
const BETA: float = 1.5
const GAMMA: float = 1.0 # Used to decrease value of normal points.
const USE_EXPECTED :float = 0.5 # How often the ai uses expected vs normal.
const BID_MU: float = 0.0 # How much the bid normal distribution is moved up or down. High value leads to more aggressive AI.
const BID_SIGMA :float = 0 # variance of the bid normal distribution


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
const AVERAGE_TRUMP_POINTS:int = 70
const ACES_PROBABILITY_PATH := "res://data/statistical_constants/probability_of_aces_given_hand.csv"
const TRUMPS_PROBABILITY_PATH := "res://data/statistical_constants/probability_of_trumps_given_hand.csv"

var aces_probabilities: Dictionary = {}
var trump_probabilities: Dictionary = {}
var statistical_data_loaded := false

func configure(engine: Node, controlled_player_id: int) -> void:
	game_engine = engine
	player_id = controlled_player_id

func _ensure_statistical_data_loaded() -> void:
	if statistical_data_loaded:
		return
	statistical_data_loaded = true
	aces_probabilities = _load_ace_probabilities(ACES_PROBABILITY_PATH)
	trump_probabilities = _load_trump_probabilities(TRUMPS_PROBABILITY_PATH)

func _load_ace_probabilities(path: String) -> Dictionary:
	var probabilities: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open ace probability data: %s" % path)
		return probabilities

	var headers: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < headers.size() or row[0].is_empty():
			continue
		var aces_in_hand := row[0].to_int()
		var distribution: Dictionary = {}
		for column_index in range(1, headers.size()):
			var total_aces := headers[column_index].replace("prob_", "").replace("_ace_after", "").replace("_aces_after", "").to_int()
			distribution[total_aces] = row[column_index].to_float()
		probabilities[aces_in_hand] = distribution
	return probabilities

func _load_trump_probabilities(path: String) -> Dictionary:
	var probabilities: Dictionary = {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open trump probability data: %s" % path)
		return probabilities

	var headers: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < headers.size() or row[0].is_empty():
			continue
		var complete_combos := row[0].to_int()
		var singleton_halves := row[1].to_int()
		var distribution: Dictionary = {}
		for column_index in range(2, headers.size()):
			var total_combos := headers[column_index].replace("prob_", "").replace("_trump_after", "").replace("_trumps_after", "").to_int()
			distribution[total_combos] = row[column_index].to_float()
		if not probabilities.has(complete_combos):
			probabilities[complete_combos] = {}
		probabilities[complete_combos][singleton_halves] = distribution
	return probabilities

func get_ace_probability_distribution(aces_in_hand: int) -> Dictionary:
	_ensure_statistical_data_loaded()
	return aces_probabilities.get(aces_in_hand, {})

func get_trump_probability_distribution(complete_combos: int, singleton_halves: int) -> Dictionary:
	_ensure_statistical_data_loaded()
	var complete_distributions: Dictionary = trump_probabilities.get(complete_combos, {})
	return complete_distributions.get(singleton_halves, {})

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
			if not aces.has(suit):
				divider = ALPHA
			final_sum += 10 * float(tens.get(suit, 0)) / divider
	return round(final_sum)
	
func evaluate_trumps_before_devils_deck(_state: Dictionary) -> int:
	"""Calculates the quaranteed points from a trump declaration.
	However, if there is no ace in the opening hand return 0."""
	var count_of_aces: int = get_all_cards_with_given_rank(_state,"A").size()
	var trump:Dictionary = check_for_possible_trump()
	var quaranteed_trumps: int = 0
	for suit in SUITS:
		quaranteed_trumps += trump[suit]*TRUMP_POINTS[suit]
	return min(count_of_aces,1)*quaranteed_trumps

func evaluate_normal_points_before_devils_deck(_state: Dictionary) -> int:
	"""Gamma is used to decrease the value of normal point cards, since they are not guaranteed"""
	var points: float = 0.0
	points += 5*get_all_cards_with_given_rank(_state,"J").size()/GAMMA
	return round(points)

func _evaluate_ace_points(total_aces: int) -> float:
	var points := total_aces * 10
	if total_aces >= 3:
		points += 20
	return points

func _calculate_trump_features() -> Vector2i:
	var trump_suits := check_for_possible_trump()
	var complete_combos := 0
	var singleton_halves := 0
	for suit in SUITS:
		var cards_in_suit: int = trump_suits.get(suit, 0)
		if cards_in_suit >= 2:
			complete_combos += 1
		elif cards_in_suit == 1:
			singleton_halves += 1
	return Vector2i(complete_combos, singleton_halves)

func estimate_expected_aces_points(state: Dictionary) -> float:
	var aces_in_hand := get_all_cards_with_given_rank(state, "A").size()
	var expected_points := 0.0
	for total_aces in get_ace_probability_distribution(aces_in_hand):
		expected_points += get_ace_probability_distribution(aces_in_hand)[total_aces] * _evaluate_ace_points(total_aces)
	return expected_points

func estimate_expected_trump_points() -> float:
	var trump_features := _calculate_trump_features()
	var distribution := get_trump_probability_distribution(trump_features.x, trump_features.y)
	var average_trump_points := 0.0
	var current_trump_scenario = check_for_possible_trump()
	
	for suit in SUITS:
		var trump_mult :float = 1.0
		if current_trump_scenario[suit] < 2: 
			trump_mult = (current_trump_scenario[suit]+0.5)/(0.5+BETA)
		average_trump_points += TRUMP_POINTS[suit] * trump_mult
	average_trump_points /= SUITS.size()

	var expected_points := 0.0
	for total_combos in distribution:
		expected_points += distribution[total_combos] * total_combos * average_trump_points
	return expected_points

func estimate_expected_tens_points(state) -> float:
	var expected_points :float = 0.0
	var aces_in_hand := get_all_cards_with_given_rank(state, "A").size()
	var tens_in_hand := get_all_cards_with_given_rank(state, "10").size()
	for total_aces in get_ace_probability_distribution(aces_in_hand):
		expected_points += get_ace_probability_distribution(aces_in_hand)[total_aces] * 5
	for total_tens in get_ace_probability_distribution(tens_in_hand): # Distribution is the same for aces as well as tens.
		expected_points +=get_ace_probability_distribution(tens_in_hand)[total_tens] * 5
	return expected_points
	
func estimate_expected_points_after_devils_deck(state: Dictionary) -> float:
	var aces = estimate_expected_aces_points(state)
	var trumps = estimate_expected_trump_points()
	var tens = estimate_expected_tens_points(state)
	var normal_points = evaluate_normal_points_before_devils_deck(state) + 10 # Constant of expected poinst as normal points from devils deck.
	print("Points from Aces:", aces)
	print("Points from Tens:", tens)
	print("Points from trumps:", trumps)
	print("Points from normal cards:", normal_points + 10)
	return (
		estimate_expected_aces_points(state)
		+ estimate_expected_trump_points()
		+ estimate_expected_tens_points(state)
		+ evaluate_normal_points_before_devils_deck(state) + 10 # Constant of expected poinst as normal points from devils deck.
	)
	
	
func full_evaluation_before_devils_deck(_state :Dictionary) -> int:
	var ace = evaluate_aces_before_devils_deck(
		_state
		)
	var tens = evaluate_tens_before_devils_deck(
			_state
			)
	var trumps = evaluate_trumps_before_devils_deck(
				_state
				)
	var normal = evaluate_normal_points_before_devils_deck(_state)
	
	print("Points from Aces:", ace)
	print("Points from Tens:", tens)
	print("Points from trumps", trumps)
	print("Points from normal cards", normal)
	
	return ace+tens+trumps+normal

func choose_bid(state: Dictionary) -> int:
	var highest_bid: int = state.get("highest_bid", 0)
	var bid_limit :float = 0
	if USE_EXPECTED <= randf_range(0,1):
		print("USING AGGRO")
		bid_limit = estimate_expected_points_after_devils_deck(state)
	else: 
		print("USING SAFE")
		bid_limit = full_evaluation_before_devils_deck(state)
	
	var final_bid_limit: int = round(randfn(bid_limit + BID_MU,BID_SIGMA))
	def_bid_limit = min(50,final_bid_limit)
	print(final_bid_limit)
	if highest_bid == 0:
		original_bid = 50
	elif highest_bid + 5 <= final_bid_limit:
		original_bid = highest_bid + 5
	else:
		original_bid = -1
	return original_bid

func choose_discard_cards(_state: Dictionary) -> Array[Node2D]:
	var cards: Array[Node2D] = _state.get("cards", [])
	var legal_cards: Array[Node2D] = []
	var suit_counts: Dictionary = {}
	var suit_has_queen: Dictionary = {}
	var suit_has_king: Dictionary = {}
	for suit: StringName in SUITS:
		suit_counts[suit] = 0
		suit_has_queen[suit] = false
		suit_has_king[suit] = false
	for card: Node2D in cards:
		var suit: StringName = StringName(str(card.get_meta("suit", "")))
		var rank := StringName(str(card.get_meta("rank", "")))
		if suit_counts.has(suit):
			suit_counts[suit] += 1
			if rank == &"Q":
				suit_has_queen[suit] = true
			elif rank == &"K":
				suit_has_king[suit] = true
		if rank != &"A" and rank != &"10":
			legal_cards.append(card)

	var protected_trump_suit: StringName = &""
	var protected_trump_count: int = -1
	for suit: StringName in SUITS:
		if not suit_has_queen[suit] or not suit_has_king[suit]:
			continue
		var legal_cards_outside_suit: int = 0
		for card: Node2D in legal_cards:
			if StringName(str(card.get_meta("suit", ""))) != suit:
				legal_cards_outside_suit += 1
		if legal_cards_outside_suit >= 6 and int(suit_counts[suit]) > protected_trump_count:
			protected_trump_suit = suit
			protected_trump_count = int(suit_counts[suit])

	var discard_candidates: Array[Node2D] = []
	for card: Node2D in legal_cards:
		var suit: StringName = StringName(str(card.get_meta("suit", "")))
		if protected_trump_suit == &"" or suit != protected_trump_suit:
			discard_candidates.append(card)
	discard_candidates.sort_custom(func(first: Node2D, second: Node2D) -> bool:
		return _get_card_value(first) < _get_card_value(second)
	)
	return discard_candidates.slice(0, mini(6, discard_candidates.size()))

func _get_card_value(card: Node2D) -> int:
	var rank: StringName = StringName(str(card.get_meta("rank", "")))
	return int(CARD_VALUES.get(rank, 0))

func choose_rebid(_state: Dictionary) -> int:
	return original_bid
