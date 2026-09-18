extends Node2D

signal hovered
signal hovered_off

const CARD_BACK_TEXTURE = preload("res://assets/cards/card-back.png")

var legal_card: bool = false
@export var visible_to_all: bool = false
var position_in_hand
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var card_area = get_node("Area2D") as Area2D
	card_area.mouse_entered.connect(_on_area_2d_mouse_entered)
	card_area.mouse_exited.connect(_on_area_2d_mouse_exited)
	var card_environment = get_node("WorldEnvironment") as WorldEnvironment
	card_environment.environment = card_environment.environment.duplicate()
	activate_bloom()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered",self)


func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off",self)

func set_visible_to_all(visible: bool = true) -> void:
	visible_to_all = visible
	if visible_to_all:
		get_node("Sprite2D").show_face()
	else:
		get_node("Sprite2D").texture = CARD_BACK_TEXTURE

func activate_bloom() -> void:
	var card_hand = get_parent()
	var is_opponent = card_hand != null and card_hand.get("is_opponent") == true
	var environment = get_node("WorldEnvironment") as WorldEnvironment
	environment.environment.glow_enabled = legal_card and not is_opponent
