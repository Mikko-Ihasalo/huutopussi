extends Node2D

const CARD_SCENE = preload("res://scenes/card.tscn")
const SUITS = ["clubs", "diamonds", "hearts", "spades"]
const RANKS = ["6", "7", "8", "9", "J", "Q", "K", "10", "A"]
const CARD_IMAGE_INDEX = {
	"6": 5,
	"7": 6,
	"8": 7,
	"9": 8,
	"J": 10,
	"Q": 11,
	"K": 12,
	"10": 9,
	"A": 0
}
const PLAYER_COUNT = 3
const CARDS_PER_PLAYER = 10
const LEFTOVER_COUNT = 6

var hands: Array[Node2D] = []
var leftover_hand: Node2D
var leftover_pile: Array[Node2D] = []
var all_cards: Array[Node2D] = []

func _ready() -> void:
	create_piles()
	create_deck()
	deal_cards()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
		deal_cards()

func create_piles() -> void:
	var hand_container = get_node("../playerHands")
	for hand in hand_container.get_children():
		if hand.leftover_pile:
			assert(leftover_hand == null)
			leftover_hand = hand
		else:
			hands.append(hand)

	assert(hands.size() == PLAYER_COUNT)
	assert(leftover_hand != null)

func create_deck() -> void:
	for suit in SUITS:
		for rank in RANKS:
			var card = CARD_SCENE.instantiate() as Node2D
			card.name = "%s_%s" % [rank, suit]
			card.set_meta("suit", suit)
			card.set_meta("rank", rank)
			var image = card.get_node("Sprite2D")
			image.card_suit = suit
			image.card_index = CARD_IMAGE_INDEX[rank]
			add_child(card)
			all_cards.append(card)

func deal_cards() -> void:
	assert(all_cards.size() == SUITS.size() * RANKS.size())
	for hand in hands:
		hand.clear_cards()
	leftover_hand.clear_cards()
	for card in all_cards:
		card.reparent(self)
	leftover_pile.clear()
	all_cards.shuffle()

	var card_index = 0
	for hand in hands:
		for _card_number in CARDS_PER_PLAYER:
			hand.add_card_to_hand(all_cards[card_index])
			card_index += 1

	for _card_number in LEFTOVER_COUNT:
		var card = all_cards[card_index]
		leftover_hand.add_card_to_hand(card)
		leftover_pile.append(card)
		card_index += 1

	assert(card_index == all_cards.size())
