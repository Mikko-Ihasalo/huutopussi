extends Node2D

const CARD_SPACING = 58.0
const CARD_BACK_TEXTURE = preload("res://assets/cards/card-back.png")

@export var is_opponent: bool = false
@export var show_opponent_cards: bool = false
@export var leftover_pile: bool = false
var cards: Array[Node2D] = []
var layout_mode: StringName = &"line"

func add_card_to_hand(card: Node2D) -> void:
	if cards.has(card):
		return
	if card.get_parent():
		card.reparent(self)
	else:
		add_child(card)
	cards.append(card)
	card.visible_to_all = false
	card.legal_card = false
	card.activate_bloom()
	set_card_visibility(card)
	arrange_cards()

func remove_card_from_hand(card: Node2D) -> void:
	if cards.has(card):
		card.emit_signal("hovered_off", card)
		cards.erase(card)
		arrange_cards()

func clear_cards() -> void:
	cards.clear()

func set_legal_cards(legal_cards: Array[Node2D]) -> void:
	for card in cards:
		card.legal_card = not is_opponent and legal_cards.has(card)
		card.activate_bloom()

func refresh_card_visibility() -> void:
	for card in cards:
		set_card_visibility(card)

func has_card(card: Node2D) -> bool:
	return cards.has(card)

func arrange_cards() -> void:
	for index in cards.size():
		var card = cards[index]
		if layout_mode == &"selection":
			var slot := int(card.get_meta("hand_creation_slot", index))
			card.position = Vector2((slot % 8) * 92.0, (slot / 8) * 132.0)
			card.z_index = slot
		elif layout_mode == &"discard":
			card.position = Vector2((index % 3) * 92.0, (index / 3) * 132.0)
			card.z_index = index
		else:
			card.position = Vector2(index * CARD_SPACING, 0)
			card.z_index = index

func set_card_visibility(card: Node2D) -> void:
	var image = card.get_node("Sprite2D") as Sprite2D
	if is_opponent and not show_opponent_cards:
		image.texture = CARD_BACK_TEXTURE
	else:
		image.show_face()
