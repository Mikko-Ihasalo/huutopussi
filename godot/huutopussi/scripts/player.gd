extends Node2D

enum ControlMode { HUMAN, DUMMY_AI }

@export var player_id: int = 0
@export var control_mode: ControlMode = ControlMode.HUMAN
@export var is_opponent: bool = false
@export var show_opponent_cards: bool = false
@export var ai_move_delay: float = 2.0

@onready var hand: Node2D = $Hand
@onready var won_cards: Node2D = $WonCards
@onready var ai_controller: Node = $DummyAi

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
		_on_round_started()

func _on_round_started() -> void:
	for card in won_cards.get_children():
		card.queue_free()
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
	call_deferred("_continue_after_trick")

func _continue_after_trick() -> void:
	if game_engine and not game_engine.manual_trick_progession and game_engine.phase == &"trump_declaration":
		game_engine.continue_after_trick()

func _play_ai_turn() -> void:
	if not game_engine or game_engine.current_player != player_id:
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
