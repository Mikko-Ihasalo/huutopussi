extends Node2D

const DUMMY_BIDDING_AI = preload("res://scripts/AI/dummy_bidding_ai.gd")
const DUMMY_GAMEPLAY_AI = preload("res://scripts/AI/dummy_gameplay_ai.gd")

var bidding_brain := DUMMY_BIDDING_AI.new()
var gameplay_brain := DUMMY_GAMEPLAY_AI.new()

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_child(bidding_brain)
	add_child(gameplay_brain)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func play_turn(game_engine: Node, player_id: int) -> void:
	gameplay_brain.configure(game_engine, player_id)
	var card: Node2D = gameplay_brain.choose_card(gameplay_brain.get_gameplay_state())
	if not card:
		return
	game_engine.play_card(player_id, card)

func choose_bid(game_engine: Node, player_id: int) -> int:
	bidding_brain.configure(game_engine, player_id)
	return bidding_brain.choose_bid(bidding_brain.get_bidding_state())

func choose_discard_cards(game_engine: Node, player_id: int) -> Array[Node2D]:
	bidding_brain.configure(game_engine, player_id)
	return bidding_brain.choose_discard_cards(bidding_brain.get_hand_creation_state())

func choose_rebid(game_engine: Node, player_id: int) -> int:
	bidding_brain.configure(game_engine, player_id)
	return bidding_brain.choose_rebid(bidding_brain.get_hand_creation_state())

func choose_trump(game_engine: Node, player_id: int) -> StringName:
	gameplay_brain.configure(game_engine, player_id)
	return gameplay_brain.choose_trump(gameplay_brain.get_gameplay_state())
