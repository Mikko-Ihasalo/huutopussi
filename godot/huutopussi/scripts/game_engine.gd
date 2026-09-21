extends Node

@export var manual_trick_progession: bool = false

signal round_started
signal auction_started
signal auction_updated(highest_bid: int, highest_bidder: int, current_player: int)
signal auction_turn_changed(player_id: int)
signal auction_completed(winner_id: int, winning_bid: int)
signal hand_creation_started(winner_id: int, winning_bid: int)
signal hand_creation_updated(discard_count: int)
signal card_played(player_id: int, card: Node2D)
signal turn_changed(player_id: int)
signal trick_completed(winner_id: int, trick: Array)
signal trump_changed(suit: StringName, player_id: int)
signal round_completed(round_points: Array, cumulative_points: Array)
signal game_won(winner_id: int, cumulative_points: Array)

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
var auction_active: Array[bool] = [true, true, true]
var auction_history: Array[Dictionary] = []
var highest_bid: int = 0
var highest_bidder: int = -1
var hand_creation_player: int = -1
var discarded_cards: Array[Node2D] = []

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
	phase = &"auction"
	auction_active = [true, true, true]
	auction_history.clear()
	highest_bid = 0
	highest_bidder = -1
	var discard_pile = get_node_or_null("../piles/left_over_pile")
	if discard_pile:
		discard_pile.visible = true
	round_started.emit()
	auction_started.emit()
	auction_turn_changed.emit(current_player)
	return true

func place_bid(player_id: int, amount: int) -> bool:
	if phase != &"auction" or player_id != current_player or not auction_active[player_id]:
		return false
	if cumulative_points[player_id] <= -500:
		return false
	if amount <= highest_bid or amount >= 500 or amount % 5 != 0:
		return false
	if highest_bid == 0 and amount % 10 != 0:
		return false
	highest_bid = amount
	highest_bidder = player_id
	auction_history.append({"player_id": player_id, "action": &"bid", "amount": amount})
	_advance_auction()
	return true

func pass_auction(player_id: int) -> bool:
	if phase != &"auction" or player_id != current_player or not auction_active[player_id]:
		return false
	auction_active[player_id] = false
	auction_history.append({"player_id": player_id, "action": &"pass", "amount": 0})
	_advance_auction()
	return true

func get_bidding_state(player_id: int) -> Dictionary:
	return {
		"phase": phase,
		"player_id": player_id,
		"current_player": current_player,
		"highest_bid": highest_bid,
		"highest_bidder": highest_bidder,
		"auction_active": auction_active.duplicate(),
		"auction_history": auction_history.duplicate(true),
		"cards": hands[player_id].duplicate() if _is_valid_player(player_id) else []
	}

func get_hand_creation_state(player_id: int) -> Dictionary:
	var other_players_cards: Array[Array] = []
	for other_player_id in PLAYER_COUNT:
		if other_player_id != player_id:
			other_players_cards.append(hands[other_player_id].duplicate())
	return {
		"phase": phase,
		"player_id": player_id,
		"cards": hands[player_id].duplicate() if _is_valid_player(player_id) else [],
		"other_players_cards": other_players_cards,
		"discarded_cards": discarded_cards.duplicate()
	}

func _advance_auction() -> void:
	var active_count := 0
	var last_active_player := -1
	for player_id in PLAYER_COUNT:
		if auction_active[player_id]:
			active_count += 1
			last_active_player = player_id
	if active_count <= 1:
		_finish_auction(last_active_player)
		return
	for offset in range(1, PLAYER_COUNT + 1):
		var next_player := (current_player + offset) % PLAYER_COUNT
		if auction_active[next_player]:
			current_player = next_player
			break
	auction_updated.emit(highest_bid, highest_bidder, current_player)
	auction_turn_changed.emit(current_player)

func _finish_auction(last_active_player: int) -> void:
	var winner_id := highest_bidder if highest_bidder >= 0 else last_active_player
	if winner_id < 0:
		winner_id = current_player
	_prepare_winning_hand(winner_id)
	current_leader = winner_id
	current_player = winner_id
	auction_completed.emit(winner_id, highest_bid)
	if winner_id == 0:
		phase = &"hand_creation"
		hand_creation_player = winner_id
		hand_creation_started.emit(winner_id, highest_bid)
		hand_creation_updated.emit(0)
	else:
		if _auto_discard_for_ai(winner_id):
			_finish_hand_creation()

func _prepare_winning_hand(winner_id: int) -> void:
	var deck = get_node_or_null("../deck")
	var players = get_node_or_null("../Players")
	var leftover_hand = get_node_or_null("../piles/left_over_pile")
	if not deck or not players or winner_id < 0 or winner_id >= players.get_child_count() or not leftover_hand:
		return
	var winner_hand = players.get_child(winner_id).get_node_or_null("Hand")
	if not winner_hand:
		return
	winner_hand.show_opponent_cards = winner_id == 0
	for card in leftover_hand.cards.duplicate():
		winner_hand.add_card_to_hand(card)
		hands[winner_id].append(card)
	leftover_hand.clear_cards()
	for index in winner_hand.cards.size():
		winner_hand.cards[index].set_meta("hand_creation_slot", index)
	discarded_cards.clear()

func _auto_discard_for_ai(winner_id: int) -> bool:
	var players = get_node_or_null("../Players")
	var discard_pile = get_node_or_null("../piles/left_over_pile")
	if not players or not discard_pile:
		return false
	var winner_hand = players.get_child(winner_id).get_node_or_null("Hand")
	var ai_controller = players.get_child(winner_id).get_node_or_null("DummyAi")
	if not winner_hand or not ai_controller or not ai_controller.has_method("choose_discard_cards"):
		return false
	var cards_to_discard: Array[Node2D] = ai_controller.choose_discard_cards(self, winner_id)
	if cards_to_discard.size() != 6:
		return false
	for card in cards_to_discard:
		if not winner_hand.has_card(card) or _card_rank_name(card) == &"A" or _card_rank_name(card) == &"10":
			return false
	for card in cards_to_discard:
		winner_hand.remove_card_from_hand(card)
		discard_pile.add_card_to_hand(card)
		hands[winner_id].erase(card)
	_move_ai_discarded_cards_to_won_pile(winner_id, discard_pile)
	var rebid: int = ai_controller.choose_rebid(self, winner_id)
	if rebid > highest_bid and rebid < 500 and rebid % 5 == 0:
		highest_bid = rebid
		auction_history.append({"player_id": winner_id, "action": &"rebid", "amount": rebid})
	return true

func _move_ai_discarded_cards_to_won_pile(winner_id: int, discard_pile: Node2D) -> void:
	var players = get_node_or_null("../Players")
	if not players or winner_id < 0 or winner_id >= players.get_child_count():
		return
	var won_cards = players.get_child(winner_id).get_node_or_null("WonCards")
	if not won_cards:
		return
	for card in discard_pile.cards.duplicate():
		discard_pile.remove_card_from_hand(card)
		card.reparent(won_cards)
		card.position = Vector2((won_cards.get_child_count() - 1) * 18, 0)
		card.z_index = won_cards.get_child_count()
		card.set_visible_to_all(false)
		if not self.won_cards[winner_id].has(card):
			self.won_cards[winner_id].append(card)

func toggle_hand_creation_card(card: Node2D) -> bool:
	if phase != &"hand_creation" or hand_creation_player != 0:
		return false
	var winner_hand = get_node_or_null("../Players").get_child(0).get_node_or_null("Hand")
	var discard_pile = get_node_or_null("../piles/left_over_pile")
	if not winner_hand or not discard_pile:
		return false
	if winner_hand.has_card(card):
		if _card_rank_name(card) == &"A" or _card_rank_name(card) == &"10" or discarded_cards.size() >= 6:
			return false
		hands[0].erase(card)
		winner_hand.remove_card_from_hand(card)
		discard_pile.add_card_to_hand(card)
		discarded_cards.append(card)
	else:
		if not discard_pile.has_card(card):
			return false
		discard_pile.remove_card_from_hand(card)
		winner_hand.add_card_to_hand(card)
		hands[0].append(card)
		discarded_cards.erase(card)
	hand_creation_updated.emit(discarded_cards.size())
	return true

func finish_hand_creation(increase_bid: bool) -> bool:
	if phase != &"hand_creation" or hand_creation_player != 0 or discarded_cards.size() != 6:
		return false
	if increase_bid:
		highest_bid += 5
	_finish_hand_creation()
	return true

func finish_hand_creation_with_bid(bid_amount: int) -> bool:
	if phase != &"hand_creation" or hand_creation_player != 0 or discarded_cards.size() != 6:
		return false
	if bid_amount < highest_bid or bid_amount >= 500 or bid_amount % 5 != 0:
		return false
	highest_bid = bid_amount
	_finish_hand_creation()
	return true

func _finish_hand_creation() -> void:
	_commit_discarded_cards_to_won_cards()
	var leader_id := highest_bidder if highest_bidder >= 0 else current_player
	phase = &"playing"
	hand_creation_player = -1
	current_leader = leader_id
	current_player = leader_id
	turn_changed.emit(current_player)

func _commit_discarded_cards_to_won_cards() -> void:
	if not _is_valid_player(hand_creation_player):
		return
	for card: Node2D in discarded_cards:
		if not won_cards[hand_creation_player].has(card):
			won_cards[hand_creation_player].append(card)

func get_playable_cards(player_id: int) -> Array[Node2D]:
	if not _is_valid_player(player_id) or phase != &"playing" or current_player != player_id:
		return []
	var player_hand: Array = hands[player_id]
	if current_trick.is_empty():
		return player_hand.duplicate()

	var led_suit: StringName = _card_suit(current_trick[0].card)
	var current_winning_card: Node2D = _get_current_winning_card(led_suit)
	var suited_cards: Array[Node2D] = []
	for card in player_hand:
		if _card_suit(card) == led_suit:
			suited_cards.append(card)
	if not suited_cards.is_empty():
		var overplaying_suited_cards: Array[Node2D] = []
		for card in suited_cards:
			if _card_beats(card, current_winning_card, led_suit):
				overplaying_suited_cards.append(card)
		if not overplaying_suited_cards.is_empty():
			return overplaying_suited_cards
		return suited_cards

	if trump_suit != &"":
		var trump_cards: Array[Node2D] = []
		for card in player_hand:
			if _card_suit(card) == trump_suit:
				trump_cards.append(card)
		if not trump_cards.is_empty():
			var overplaying_trump_cards: Array[Node2D] = []
			for card in trump_cards:
				if _card_beats(card, current_winning_card, led_suit):
					overplaying_trump_cards.append(card)
			if not overplaying_trump_cards.is_empty():
				return overplaying_trump_cards
			return trump_cards

	return player_hand.duplicate()

func get_gameplay_state(player_id: int) -> Dictionary:
	var played_cards_with_players: Array[Dictionary] = []
	for trick in completed_tricks:
		for play in trick:
			played_cards_with_players.append(play.duplicate())
	for play in current_trick:
		played_cards_with_players.append(play.duplicate())
	return {
		"phase": phase,
		"player_id": player_id,
		"cards": hands[player_id].duplicate() if _is_valid_player(player_id) else [],
		"legal_cards": get_playable_cards(player_id),
		"trump_suit": trump_suit,
		"active_trump": trump_suit != &"",
		"can_declare_trump": not get_declarable_trump_suits(player_id).is_empty(),
		"declarable_trump_suits": get_declarable_trump_suits(player_id),
		"played_cards": played_cards_with_players,
		"current_trick": current_trick.duplicate(true),
		"completed_tricks": completed_tricks.duplicate(true)
	}

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

func continue_after_trick(player_id: int = -1) -> bool:
	if phase != &"trump_declaration" and phase != &"awaiting_trick_progression":
		return false
	if phase == &"trump_declaration" and player_id >= 0 and player_id != pending_trump_player:
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

func get_declarable_trump_suits(player_id: int) -> Array[StringName]:
	var declarable_suits: Array[StringName] = []
	if phase != &"trump_declaration" or player_id != pending_trump_player:
		return declarable_suits
	for suit in TRUMP_POINTS:
		if suit in declared_trump_suits:
			continue
		if _player_has_rank_and_suit(player_id, StringName(suit), &"K") and _player_has_rank_and_suit(player_id, StringName(suit), &"Q"):
			declarable_suits.append(StringName(suit))
	return declarable_suits

func _resolve_trick() -> void:
	var winner_id := _get_trick_winner(current_trick)
	var completed_trick := current_trick.duplicate()
	var winner_led_trick: bool = completed_trick[0].player_id == winner_id
	completed_tricks.append(completed_trick)
	for play in completed_trick:
		won_cards[winner_id].append(play.card)
	current_leader = winner_id
	current_player = winner_id
	current_trick.clear()
	trick_completed.emit(winner_id, completed_trick)
	_refresh_won_cards_visibility(completed_trick)

	if completed_tricks.size() == TOTAL_TRICKS:
		_finish_round()
	elif manual_trick_progession:
		phase = &"awaiting_trick_progression"
		pending_trump_player = winner_id
	elif winner_led_trick:
		phase = &"trump_declaration"
		pending_trump_player = winner_id
		turn_changed.emit(current_player)
	else:
		phase = &"playing"
		pending_trump_player = -1
		turn_changed.emit(current_player)

func _refresh_won_cards_visibility(recent_trick: Array) -> void:
	var players = get_node_or_null("../Players")
	if not players:
		return
	for player in players.get_children():
		var won_cards = player.get_node_or_null("WonCards")
		if not won_cards:
			continue
		for card in won_cards.get_children():
			card.set_visible_to_all(false)
	for play in recent_trick:
		var card: Node2D = play.card
		card.visible = true

func _get_trick_winner(trick: Array[Dictionary]) -> int:
	var led_suit: StringName = _card_suit(trick[0].card)
	var winning_play: Dictionary = trick[0]
	for play in trick.slice(1):
		if _card_beats(play.card, winning_play.card, led_suit):
			winning_play = play
	return winning_play.player_id

func _get_current_winning_card(led_suit: StringName) -> Node2D:
	var winning_card: Node2D = current_trick[0].card
	for play in current_trick.slice(1):
		if _card_beats(play.card, winning_card, led_suit):
			winning_card = play.card
	return winning_card

func _card_beats(candidate: Node2D, current: Node2D, led_suit: StringName) -> bool:
	var candidate_suit := _card_suit(candidate)
	var current_suit := _card_suit(current)
	var candidate_is_trump := _is_trump_card(candidate)
	var current_is_trump := _is_trump_card(current)

	if candidate_is_trump:
		if not current_is_trump:
			return true
		return _card_rank(candidate) > _card_rank(current)
	if current_is_trump:
		return false
	if candidate_suit == current_suit:
		return _card_rank(candidate) > _card_rank(current)
	if candidate_suit == led_suit:
		return true
	return false

func _is_trump_card(card: Node2D) -> bool:
	return trump_suit != &"" and _card_suit(card) == trump_suit

func _finish_round() -> void:
	var collected_points: Array[int] = [0, 0, 0]
	for player_id in PLAYER_COUNT:
		for card in won_cards[player_id]:
			collected_points[player_id] += CARD_POINTS.get(_card_rank_name(card), 0)
	if not completed_tricks.is_empty():
		var last_trick: Array = completed_tricks.back()
		var last_winner: int = _get_trick_winner(last_trick)
		collected_points[last_winner] += 20
	if trump_maker >= 0:
		collected_points[trump_maker] += TRUMP_POINTS.get(trump_suit, 0)

	var bidder_won_trick := not won_cards[highest_bidder].is_empty() if _is_valid_player(highest_bidder) else false
	for player_id in PLAYER_COUNT:
		if player_id == highest_bidder:
			round_points[player_id] = highest_bid * (-2 if not bidder_won_trick else (1 if collected_points[player_id] >= highest_bid else -1))
		elif won_cards[player_id].is_empty():
			round_points[player_id] = -highest_bid
		else:
			round_points[player_id] = collected_points[player_id]
	for player_id in PLAYER_COUNT:
		cumulative_points[player_id] += round_points[player_id]
	var winning_score: int = round_points.max()
	var round_winner: int = round_points.find(winning_score)
	print("Round winner: Player %d with %d points" % [round_winner + 1, winning_score])
	phase = &"round_complete"
	round_completed.emit(round_points.duplicate(), cumulative_points.duplicate())
	var game_winner := _get_game_winner()
	if game_winner >= 0:
		phase = &"game_over"
		game_won.emit(game_winner, cumulative_points.duplicate())
		return
	call_deferred("_start_next_round")

func _get_game_winner() -> int:
	var winner_id := -1
	var winning_score := 499
	for player_id in PLAYER_COUNT:
		if cumulative_points[player_id] >= 500 and cumulative_points[player_id] > winning_score:
			winner_id = player_id
			winning_score = cumulative_points[player_id]
	return winner_id

func _start_next_round() -> void:
	if phase != &"round_complete":
		return
	var deck = get_node_or_null("../deck")
	if not deck:
		return
	deck.deal_cards()
	start_round([deck.hands[0].cards, deck.hands[1].cards, deck.hands[2].cards], current_leader)

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
