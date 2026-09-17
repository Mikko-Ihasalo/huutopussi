extends Node

@export var manual_trick_progession: bool = false

signal round_started
signal card_played(player_id: int, card: Node2D)
signal turn_changed(player_id: int)
signal trick_completed(winner_id: int, trick: Array)
signal trump_changed(suit: StringName, player_id: int)
signal round_completed(round_points: Array, cumulative_points: Array)

const PLAYER_COUNT = 3
const HAND_SIZE = 10
const TRICK_SIZE = 3
const TOTAL_TRICKS = 10
const RANK_STRENGTH = {
	"6": 0,
	"7": 1,
	"8": 2,
	"9": 3,
	"J": 4,
	"Q": 5,
	"K": 6,
	"10": 7,
	"A": 8
}
const CARD_POINTS = {
	"A": 10,
	"10": 10,
	"K": 5,
	"Q": 5,
	"J": 5
}
const TRUMP_POINTS = {
	"clubs": 40,
	"diamonds": 60,
	"hearts": 80,
	"spades": 100
}

var phase: StringName = &"idle"
var hands: Array[Array] = [[], [], []]
var current_trick: Array[Dictionary] = []
var completed_tricks: Array[Array] = []
var played_cards: Array[Node2D] = []
var won_cards: Array[Array] = [[], [], []]
var round_points: Array[int] = [0, 0, 0]
var cumulative_points: Array[int] = [0, 0, 0]
var current_leader: int = 0
var current_player: int = 0
var trump_suit: StringName = &""
var trump_maker: int = -1
var declared_trump_suits: Array[StringName] = []
var pending_trump_player: int = -1

func _ready() -> void:
	call_deferred("_start_from_scene")

func _unhandled_input(event: InputEvent) -> void:
	if manual_trick_progession and event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		continue_after_trick()

func _start_from_scene() -> void:
	var deck = get_node_or_null("../deck")
	if deck and deck.hands.size() == PLAYER_COUNT:
		start_round([deck.hands[0].cards, deck.hands[1].cards, deck.hands[2].cards])

func start_round(player_hands: Array, leader: int = 0) -> bool:
	if player_hands.size() != PLAYER_COUNT:
		return false
	for player_hand in player_hands:
		if player_hand.size() != HAND_SIZE:
			return false

	hands = [player_hands[0].duplicate(), player_hands[1].duplicate(), player_hands[2].duplicate()]
	current_trick.clear()
	completed_tricks.clear()
	played_cards.clear()
	won_cards = [[], [], []]
	round_points = [0, 0, 0]
	current_leader = leader % PLAYER_COUNT
	current_player = current_leader
	trump_suit = &""
	trump_maker = -1
	declared_trump_suits.clear()
	pending_trump_player = -1
	phase = &"playing"
	round_started.emit()
	return true

func get_playable_cards(player_id: int) -> Array[Node2D]:
	if not _is_valid_player(player_id) or phase != &"playing" or current_player != player_id:
		return []
	var player_hand: Array = hands[player_id]
	if current_trick.is_empty():
		return player_hand.duplicate()

	var led_suit: StringName = _card_suit(current_trick[0].card)
	var suited_cards: Array[Node2D] = []
	for card in player_hand:
		if _card_suit(card) == led_suit:
			suited_cards.append(card)
	if not suited_cards.is_empty():
		return suited_cards

	if trump_suit != &"":
		var trump_cards: Array[Node2D] = []
		for card in player_hand:
			if _card_suit(card) == trump_suit:
				trump_cards.append(card)
		if not trump_cards.is_empty():
			return trump_cards

	return player_hand.duplicate()

func is_card_legal(player_id: int, card: Node2D) -> bool:
	return get_playable_cards(player_id).has(card)

func play_card(player_id: int, card: Node2D) -> bool:
	if phase != &"playing" or player_id != current_player or not is_card_legal(player_id, card):
		return false
	var card_index := hands[player_id].find(card)
	hands[player_id].remove_at(card_index)
	current_trick.append({"player_id": player_id, "card": card})
	played_cards.append(card)
	card_played.emit(player_id, card)

	if current_trick.size() == TRICK_SIZE:
		_resolve_trick()
	else:
		current_player = (current_player + 1) % PLAYER_COUNT
		turn_changed.emit(current_player)
	return true

func continue_after_trick() -> bool:
	if phase != &"trump_declaration" and phase != &"awaiting_trick_progression":
		return false
	pending_trump_player = -1
	phase = &"playing"
	current_player = current_leader
	turn_changed.emit(current_player)
	return true

func declare_trump(player_id: int, suit: StringName) -> bool:
	if phase != &"trump_declaration" or player_id != pending_trump_player:
		return false
	if suit not in TRUMP_POINTS or suit in declared_trump_suits:
		return false
	if not _player_has_rank_and_suit(player_id, suit, "K") or not _player_has_rank_and_suit(player_id, suit, "Q"):
		return false
	trump_suit = suit
	trump_maker = player_id
	declared_trump_suits.append(suit)
	trump_changed.emit(suit, player_id)
	return continue_after_trick()

func _resolve_trick() -> void:
	var winner_id := _get_trick_winner(current_trick)
	var completed_trick := current_trick.duplicate()
	completed_tricks.append(completed_trick)
	for play in completed_trick:
		won_cards[winner_id].append(play.card)
	current_leader = winner_id
	current_player = winner_id
	current_trick.clear()
	trick_completed.emit(winner_id, completed_trick)

	if completed_tricks.size() == TOTAL_TRICKS:
		_finish_round()
	elif manual_trick_progession:
		phase = &"awaiting_trick_progression"
		pending_trump_player = winner_id
	else:
		phase = &"trump_declaration"
		pending_trump_player = winner_id
		turn_changed.emit(current_player)

func _get_trick_winner(trick: Array[Dictionary]) -> int:
	var led_suit: StringName = _card_suit(trick[0].card)
	var winning_play: Dictionary = trick[0]
	for play in trick.slice(1):
		if _card_beats(play.card, winning_play.card, led_suit):
			winning_play = play
	return winning_play.player_id

func _card_beats(candidate: Node2D, current: Node2D, led_suit: StringName) -> bool:
	var candidate_suit := _card_suit(candidate)
	var current_suit := _card_suit(current)
	var candidate_is_trump := trump_suit != &"" and candidate_suit == trump_suit
	var current_is_trump := trump_suit != &"" and current_suit == trump_suit
	if candidate_is_trump != current_is_trump:
		return candidate_is_trump
	if candidate_suit != current_suit:
		if candidate_suit == led_suit:
			return true
		return false
	return _card_rank(candidate) > _card_rank(current)

func _finish_round() -> void:
	for player_id in PLAYER_COUNT:
		for card in won_cards[player_id]:
			round_points[player_id] += CARD_POINTS.get(_card_rank_name(card), 0)
	if not completed_tricks.is_empty():
		var last_trick: Array = completed_tricks.back()
		var last_winner: int = _get_trick_winner(last_trick)
		round_points[last_winner] += 20
	if trump_maker >= 0:
		round_points[trump_maker] += TRUMP_POINTS.get(trump_suit, 0)
	for player_id in PLAYER_COUNT:
		cumulative_points[player_id] += round_points[player_id]
	var winning_score: int = round_points.max()
	var round_winner: int = round_points.find(winning_score)
	print("Round winner: Player %d with %d points" % [round_winner + 1, winning_score])
	phase = &"round_complete"
	round_completed.emit(round_points.duplicate(), cumulative_points.duplicate())

func _player_has_rank_and_suit(player_id: int, suit: StringName, rank: StringName) -> bool:
	for card in hands[player_id]:
		if _card_suit(card) == suit and _card_rank_name(card) == rank:
			return true
	return false

func _card_suit(card: Node2D) -> StringName:
	return StringName(str(card.get_meta("suit", "")))

func _card_rank_name(card: Node2D) -> StringName:
	return StringName(str(card.get_meta("rank", "")))

func _card_rank(card: Node2D) -> int:
	return RANK_STRENGTH.get(_card_rank_name(card), -1)

func _is_valid_player(player_id: int) -> bool:
	return player_id >= 0 and player_id < PLAYER_COUNT
