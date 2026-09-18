extends Node2D

const COLLISION_MASK_CARD = 1
var screen_size
var card_being_dragged 
var is_hovering_on_card: bool = false
var player_hand_reference
var game_engine_reference
var played_cards_reference
var played_cards: Array[Node2D] = []

func _input(event: InputEvent) -> void:
	if game_engine_reference and game_engine_reference.phase == &"hand_creation":
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var selection_card = find_hand_creation_card(event.position)
			if selection_card:
				game_engine_reference.toggle_hand_creation_card(selection_card)
			return
	if game_engine_reference and game_engine_reference.phase != &"playing":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			var card = raycast_check_for_card()
			if card: 
				start_drag(card)
		else: 
			if card_being_dragged:
				finish_drag()
			#stuff
			
# Called when the node enters the scene tree for the first time.
func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return get_card_with_highest_z_index(result)
	return null

func find_hand_creation_card(mouse_position: Vector2) -> Node2D:
	var candidate_cards: Array[Node2D] = []
	var discard_pile = get_node_or_null("../piles/left_over_pile")
	if player_hand_reference:
		candidate_cards.append_array(player_hand_reference.cards)
	if discard_pile:
		candidate_cards.append_array(discard_pile.cards)
	for card in candidate_cards:
		var card_transform := card.get_global_transform_with_canvas()
		var top_left := card_transform * Vector2(-44.5, -61.0)
		var bottom_right := card_transform * Vector2(44.5, 61.0)
		var card_rect := Rect2(top_left, bottom_right - top_left)
		if card_rect.has_point(mouse_position):
			return card
	return null
func _ready() -> void:
	screen_size = get_viewport_rect().size
	call_deferred("find_player_hand")

func find_player_hand() -> void:
	await get_tree().process_frame
	player_hand_reference = get_node_or_null("../Players/Human/Hand")
	if not player_hand_reference:
		return
	for card in player_hand_reference.cards:
		connect_card_signals(card)
	game_engine_reference = get_node_or_null("../gameEngine")
	played_cards_reference = get_node_or_null("../playedCards")
	if game_engine_reference:
		if not game_engine_reference.round_started.is_connected(update_legal_cards):
			game_engine_reference.round_started.connect(update_legal_cards)
		if not game_engine_reference.auction_completed.is_connected(_on_auction_completed):
			game_engine_reference.auction_completed.connect(_on_auction_completed)
		if not game_engine_reference.turn_changed.is_connected(_on_turn_changed):
			game_engine_reference.turn_changed.connect(_on_turn_changed)
		update_legal_cards()

func _on_auction_completed(_winner_id: int, _winning_bid: int) -> void:
	for card in player_hand_reference.cards:
		connect_card_signals(card)
	update_legal_cards()

func _on_turn_changed(_player_id: int) -> void:
	update_legal_cards()

func update_legal_cards() -> void:
	if game_engine_reference and player_hand_reference:
		player_hand_reference.set_legal_cards(game_engine_reference.get_playable_cards(0))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if card_being_dragged: 
		var mouse_position = get_global_mouse_position()
		card_being_dragged.position = Vector2(
			clamp(
				mouse_position.x,0, screen_size.x
				),
			clamp(
				mouse_position.y,0,screen_size.y
				)
			)
func connect_card_signals(card):
	if not card.hovered.is_connected(on_hovered_card):
		card.hovered.connect(on_hovered_card)
	if not card.hovered_off.is_connected(on_hovered_off_card):
		card.hovered_off.connect(on_hovered_off_card)

func on_hovered_card(card):
	if not player_hand_reference or not player_hand_reference.has_card(card):
		return
	if !is_hovering_on_card:
		highlight_card(card, true)
		is_hovering_on_card = true
func on_hovered_off_card(card):
	if card_being_dragged and player_hand_reference and player_hand_reference.has_card(card):
		return
	highlight_card(card,false)
	var new_card_hovered = raycast_check_for_card()
	if new_card_hovered and player_hand_reference and player_hand_reference.has_card(new_card_hovered):
		highlight_card(new_card_hovered,true)
	else:
		is_hovering_on_card = false
	
func highlight_card(card, hovered):
	if hovered:
		card.scale = Vector2(1.05,1.05)
		card.z_index = 2
	else: 
		card.scale = Vector2(1,1)
		card.z_index = 1
		
func get_card_with_highest_z_index(cards):
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index
	for i in range(1, cards.size()):
		var current_card = cards[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card
	
func start_drag(card):
	if not player_hand_reference or not player_hand_reference.has_card(card) or not card.legal_card:
		return
	card_being_dragged = card
	card.scale = Vector2(1,1)
func finish_drag():
	if not player_hand_reference or not game_engine_reference or not played_cards_reference:
		card_being_dragged = null
		return
	var played_card = card_being_dragged
	card_being_dragged = null
	if game_engine_reference.play_card(0, played_card):
		update_legal_cards()
	else:
		player_hand_reference.add_card_to_hand(played_card)
	
