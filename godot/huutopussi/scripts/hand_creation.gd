extends Control

const HUMAN_PLAYER_ID := 0

var game_engine: Node
var winner_player: Node2D
var winner_hand: Node2D
var winner_won_cards: Node2D
var discard_pile: Node2D
var discard_pile_default_position: Vector2
var status_label: Label
var start_button: Button
var raise_button: Button
var custom_bid_input: LineEdit
var custom_bid_button: Button

func _ready() -> void:
	game_engine = get_node_or_null("../gameEngine")
	winner_player = get_node_or_null("../Players/Human")
	winner_hand = get_node_or_null("../Players/Human/Hand")
	winner_won_cards = get_node_or_null("../Players/Human/WonCards")
	discard_pile = get_node_or_null("../piles/left_over_pile")
	if discard_pile:
		discard_pile_default_position = discard_pile.global_position
	_build_controls()
	visible = false
	if game_engine:
		game_engine.hand_creation_started.connect(_on_hand_creation_started)
		game_engine.hand_creation_updated.connect(_on_hand_creation_updated)

func _build_controls() -> void:
	var panel := Panel.new()
	panel.position = Vector2(350, 12)
	panel.size = Vector2(460, 150)
	add_child(panel)
	var contents := VBoxContainer.new()
	contents.position = Vector2(16, 10)
	contents.size = Vector2(428, 92)
	panel.add_child(contents)
	var title := Label.new()
	title.text = "Choose 6 cards to discard"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(title)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(status_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	contents.add_child(buttons)
	start_button = Button.new()
	start_button.text = "Start game"
	start_button.pressed.connect(_on_start_pressed)
	buttons.add_child(start_button)
	raise_button = Button.new()
	raise_button.text = "Raise bid by 5"
	raise_button.pressed.connect(_on_raise_pressed)
	buttons.add_child(raise_button)
	var custom_bid_row := HBoxContainer.new()
	custom_bid_row.alignment = BoxContainer.ALIGNMENT_CENTER
	contents.add_child(custom_bid_row)
	custom_bid_input = LineEdit.new()
	custom_bid_input.placeholder_text = "Custom bid"
	custom_bid_input.custom_minimum_size = Vector2(120, 0)
	custom_bid_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_bid_input.text_submitted.connect(_on_custom_bid_submitted)
	custom_bid_row.add_child(custom_bid_input)
	custom_bid_button = Button.new()
	custom_bid_button.text = "Set bid"
	custom_bid_button.pressed.connect(_on_custom_bid_pressed)
	custom_bid_row.add_child(custom_bid_button)

func _on_hand_creation_started(_winner_id: int, winning_bid: int) -> void:
	if not winner_hand or not discard_pile:
		return
	visible = true
	discard_pile.visible = true
	winner_hand.layout_mode = &"selection"
	discard_pile.layout_mode = &"discard"
	if winner_player:
		winner_hand.position = Vector2(0, -132)
		discard_pile.global_position = winner_player.global_position + Vector2(760, 0)
	winner_hand.arrange_cards()
	discard_pile.arrange_cards()
	_on_hand_creation_updated(0)

func _on_hand_creation_updated(discard_count: int) -> void:
	if not visible:
		return
	status_label.text = "%d of 6 selected. Discard pile: right side." % discard_count
	start_button.disabled = discard_count != 6
	raise_button.disabled = discard_count != 6
	custom_bid_button.disabled = discard_count != 6
	custom_bid_input.editable = discard_count == 6
	if winner_hand:
		winner_hand.arrange_cards()
	if discard_pile:
		discard_pile.arrange_cards()

func _on_start_pressed() -> void:
	if game_engine.finish_hand_creation(false):
		_close()

func _on_raise_pressed() -> void:
	if game_engine.finish_hand_creation(true):
		_close()

func _on_custom_bid_pressed() -> void:
	_submit_custom_bid()

func _on_custom_bid_submitted(_value: String) -> void:
	_submit_custom_bid()

func _submit_custom_bid() -> void:
	if not custom_bid_input.text.is_valid_int():
		status_label.text = "Enter a bid of at least %d." % game_engine.highest_bid
		return
	var bid_amount := int(custom_bid_input.text)
	if game_engine.finish_hand_creation_with_bid(bid_amount):
		_close()
	else:
		status_label.text = "Bid must be at least %d and below 500." % game_engine.highest_bid

func _close() -> void:
	_move_discarded_cards_to_won_pile()
	visible = false
	if winner_hand:
		winner_hand.layout_mode = &"line"
		winner_hand.position = Vector2.ZERO
		winner_hand.arrange_cards()
	if discard_pile:
		discard_pile.layout_mode = &"line"
		discard_pile.global_position = discard_pile_default_position
		discard_pile.visible = false

func _move_discarded_cards_to_won_pile() -> void:
	if not discard_pile or not winner_won_cards:
		return
	for card in discard_pile.cards.duplicate():
		discard_pile.remove_card_from_hand(card)
		card.reparent(winner_won_cards)
		card.position = Vector2((winner_won_cards.get_child_count() - 1) * 18, 0)
		card.z_index = winner_won_cards.get_child_count()
		card.set_visible_to_all(false)
		if not game_engine.won_cards[HUMAN_PLAYER_ID].has(card):
			game_engine.won_cards[HUMAN_PLAYER_ID].append(card)