extends Node2D

enum ControlMode { HUMAN, DUMMY_AI }

@export var player_id: int = 0
@export var control_mode: ControlMode = ControlMode.HUMAN
@export var is_opponent: bool = false
@export var show_opponent_cards: bool = false
@export var ai_move_delay: float = 2.0
@export var display_name: String = ""

@onready var hand: Node2D = $Hand
@onready var won_cards: Node2D = $WonCards
@onready var ai_controller: Node = $DummyAi
@onready var name_label: Label = $PlayerInfo/Name
@onready var points_label: Label = $PlayerInfo/Points
@onready var bid_label: Label = $PlayerInfo/Bid
@onready var trump_buttons: HBoxContainer = $TrumpControls/Buttons

var game_engine: Node
var played_cards_view: Node2D
var ai_turn_pending: bool = false

func _ready() -> void:
	call_deferred("_connect_to_game")

func _connect_to_game() -> void:
	game_engine = get_node_or_null("../../gameEngine")
	played_cards_view = get_node_or_null("../../playedCards")
	hand.is_opponent = is_opponent
	hand.show_opponent_cards = show_opponent_cards
	hand.refresh_card_visibility()
	if game_engine:
		game_engine.card_played.connect(_on_card_played)
		game_engine.turn_changed.connect(_on_turn_changed)
		game_engine.trick_completed.connect(_on_trick_completed)
		game_engine.round_started.connect(_on_round_started)
		game_engine.auction_completed.connect(_on_auction_completed)
		game_engine.round_completed.connect(_on_round_completed)
		game_engine.trick_completed.connect(_on_trump_phase_changed)
		game_engine.trump_changed.connect(_on_trump_phase_changed)
		_update_player_info()
		_setup_trump_controls()
		_on_round_started()

func _setup_trump_controls() -> void:
	var suits := ["clubs", "diamonds", "hearts", "spades"]
	for suit in suits:
		var button := trump_buttons.get_node(suit.capitalize()) as Button
		button.pressed.connect(_on_trump_button_pressed.bind(StringName(suit)))
	_update_trump_controls()

func _on_trump_button_pressed(suit: StringName) -> void:
	if game_engine and game_engine.declare_trump(player_id, suit):
		_update_trump_controls.call_deferred()

func _update_trump_controls() -> void:
	if not game_engine or not trump_buttons:
		return
	var is_decision_player: bool = game_engine.phase == &"trump_declaration" and game_engine.pending_trump_player == player_id
	var declarable_suits: Array[StringName] = game_engine.get_declarable_trump_suits(player_id)
	for button in trump_buttons.get_children():
		button.disabled = not is_decision_player or not declarable_suits.has(StringName(button.name.to_lower()))

func _update_player_info() -> void:
	name_label.text = display_name if not display_name.is_empty() else "Player %d" % (player_id + 1)
	points_label.text = "Points: %d" % game_engine.cumulative_points[player_id] if game_engine else "Points: 0"

func _on_auction_completed(winner_id: int, winning_bid: int) -> void:
	if winner_id == player_id:
		bid_label.text = "Final bid: %d" % winning_bid
	else:
		bid_label.text = "Final bid: -"

func _on_round_completed(_round_points: Array, cumulative_points: Array) -> void:
	points_label.text = "Points: %d" % cumulative_points[player_id]

func _on_trump_phase_changed(_first_value = null, _second_value = null) -> void:
	_update_trump_controls()

func _on_round_started() -> void:
	for card in won_cards.get_children():
		card.queue_free()
	_update_trump_controls()
	if control_mode == ControlMode.DUMMY_AI:
		_play_ai_turn.call_deferred()

func _on_card_played(played_player_id: int, card: Node2D) -> void:
	if played_player_id == player_id:
		hand.remove_card_from_hand(card)
		card.set_visible_to_all()
		if played_cards_view:
			card.reparent(played_cards_view)
			card.position = Vector2((game_engine.current_trick.size() - 1) * 100, 0)
			card.z_index = game_engine.current_trick.size()

func _on_turn_changed(changed_player_id: int) -> void:
	_update_trump_controls()
	if game_engine.phase != &"playing":
		return
	if control_mode == ControlMode.DUMMY_AI and changed_player_id == player_id:
		_play_ai_turn.call_deferred()

func _on_trick_completed(winner_id: int, trick: Array) -> void:
	if winner_id != player_id:
		return
	for play in trick:
		var card: Node2D = play.card
		card.reparent(won_cards)
		card.position = Vector2((won_cards.get_child_count() - 1) * 18, 0)
		card.z_index = won_cards.get_child_count()
	_update_trump_controls.call_deferred()
	call_deferred("_continue_after_trick")

func _continue_after_trick() -> void:
	if not game_engine or game_engine.manual_trick_progession or game_engine.phase != &"trump_declaration":
		return
	var legal_suits: Array[StringName] = game_engine.get_declarable_trump_suits(player_id)
	if legal_suits.is_empty():
		game_engine.continue_after_trick(player_id)
	elif control_mode == ControlMode.DUMMY_AI:
		var suit: StringName = ai_controller.choose_trump(game_engine, player_id)
		if suit != &"":
			game_engine.declare_trump(player_id, suit)

func _play_ai_turn() -> void:
	if not game_engine or game_engine.phase != &"playing" or game_engine.current_player != player_id:
		return
	if ai_turn_pending:
		return
	ai_turn_pending = true
	await ai_controller.wait(ai_move_delay)
	ai_turn_pending = false
	if not game_engine or game_engine.current_player != player_id:
		return
	if not game_engine.manual_trick_progession and game_engine.phase == &"trump_declaration":
		game_engine.continue_after_trick()
	if game_engine.phase != &"playing":
		return
	ai_controller.play_turn(game_engine, player_id)
