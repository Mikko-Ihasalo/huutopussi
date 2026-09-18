extends Control

const HUMAN_PLAYER_ID := 0

@onready var status_label: Label = $Panel/Contents/Status
@onready var bid_label: Label = $Panel/Contents/Bid
@onready var custom_bid: LineEdit = $Panel/Contents/CustomBid
@onready var pass_button: Button = $Panel/Contents/Buttons/Pass
@onready var quick_bid_button: Button = $Panel/Contents/Buttons/QuickBid
@onready var custom_bid_button: Button = $Panel/Contents/Buttons/CustomBid

var game_engine: Node
var ai_turn_pending := false

func _ready() -> void:
	game_engine = get_node_or_null("../gameEngine")
	pass_button.pressed.connect(_on_pass_pressed)
	quick_bid_button.pressed.connect(_on_quick_bid_pressed)
	custom_bid_button.pressed.connect(_on_custom_bid_pressed)
	custom_bid.text_submitted.connect(_on_custom_bid_submitted)
	if game_engine:
		game_engine.auction_started.connect(_on_auction_started)
		game_engine.auction_updated.connect(_on_auction_updated)
		game_engine.auction_turn_changed.connect(_on_auction_turn_changed)
		game_engine.auction_completed.connect(_on_auction_completed)
		if game_engine.phase == &"auction":
			_on_auction_started()

func _on_auction_started() -> void:
	show()
	_update_controls()

func _on_auction_updated(_bid: int, _bidder: int, _player: int) -> void:
	_update_controls()

func _on_auction_turn_changed(_player_id: int) -> void:
	_update_controls()
	if _player_id != HUMAN_PLAYER_ID:
		_play_ai_turn.call_deferred()

func _update_controls() -> void:
	if not game_engine:
		return
	var current_player: int = game_engine.current_player
	var is_human_turn: bool = current_player == HUMAN_PLAYER_ID and game_engine.auction_active[HUMAN_PLAYER_ID]
	var can_bid : bool = game_engine.cumulative_points[HUMAN_PLAYER_ID] > -500
	status_label.text = "Your turn" if is_human_turn and can_bid else ("You must pass" if is_human_turn else "Player %d is bidding" % (current_player + 1))
	bid_label.text = "Highest bid: %d" % game_engine.highest_bid if game_engine.highest_bid > 0 else "No bids yet"
	pass_button.disabled = not is_human_turn
	quick_bid_button.disabled = not is_human_turn or not can_bid or game_engine.highest_bid + 5 >= 500 or (game_engine.highest_bid == 0)
	custom_bid_button.disabled = not is_human_turn or not can_bid
	custom_bid.editable = is_human_turn and can_bid

func _on_pass_pressed() -> void:
	game_engine.pass_auction(HUMAN_PLAYER_ID)

func _on_quick_bid_pressed() -> void:
	game_engine.place_bid(HUMAN_PLAYER_ID, game_engine.highest_bid + 5)

func _on_custom_bid_pressed() -> void:
	_submit_custom_bid()

func _on_custom_bid_submitted(_value: String) -> void:
	_submit_custom_bid()

func _submit_custom_bid() -> void:
	if custom_bid.text.is_valid_int():
		game_engine.place_bid(HUMAN_PLAYER_ID, int(custom_bid.text))
	custom_bid.clear()

func _play_ai_turn() -> void:
	if ai_turn_pending or not game_engine or game_engine.phase != &"auction":
		return
	ai_turn_pending = true
	await get_tree().create_timer(0.7).timeout
	ai_turn_pending = false
	if not game_engine or game_engine.phase != &"auction" or game_engine.current_player == HUMAN_PLAYER_ID:
		return
	if game_engine.cumulative_points[game_engine.current_player] <= -500:
		game_engine.pass_auction(game_engine.current_player)
		return
	var maximum_bid: int = 80 + game_engine.current_player * 20
	if game_engine.highest_bid < maximum_bid and game_engine.highest_bid + 5 < 500:
		var amount : int = 10 if game_engine.highest_bid == 0 else game_engine.highest_bid + 5
		game_engine.place_bid(game_engine.current_player, amount)
	else:
		game_engine.pass_auction(game_engine.current_player)

func _on_auction_completed(_winner_id: int, _winning_bid: int) -> void:
	hide()
