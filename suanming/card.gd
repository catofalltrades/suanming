@tool
class_name Card
extends Area2D

# This node implements a playing card. It can be clicked and dragged (usually works with either a
# mouse or a touchscreen), flipped to the front or back, made unmovable, and can be moved to a
# programmatically-specified location. It signals when it is first clicked, and when it is "dropped"

# The suit and rank can be configured, and it belongs to the group "cards" to make it easy to loop
# over every card.

# It has the concept of a "zone", a space on the playing field for cards that it is currently in
# and may implement special rules. Cards dropped into zones can be accepted, in which case they move
# fully onto the zone, or rejected, in which case they use `fall_outside()` to land nearby on the
# playing field.

# Zones should be non-overlapping nodes in the playing field, representing decks and other places
# one or more cards get stacked.

# Zones are implemented in the CardZone node, but I wasn't able to get that to be recognized as a
# type in this file, for some reason.

# You should be able to transform and rotate this node without much difficulty, though the movement
# when a card is rejected from a zone might be slightly messy under rotation. Do not scale this node
# because of complexities with CollisionShape2D.

## Emitted when the card thinks it was clicked and could be moved. Used so a parent node can choose
## which card should be considered held by the user in case of multiple stacked cards.
signal click_seen(card: Card)

## Emitted when the card has been dropped. Useful for ensuring cards have the right z-index ordering
signal card_dropped(card: Card)

## Height in pixels of the card, after any scaling or other modification of the sprite.
const H = 107

## Cards use z-index to ensure they display in the proper order on the playing field. This z-index
## is used to ensure that a card being dragged is rendered on top of the entire playing field.
const Z_INDEX_TOP_CARD = 52

## True if the card is currently being dragged, false otherwise.
var dragging = false

## True if the card can be selected by the user to drag. False otherwise.
var selectable = true

## If `moving` is true, target is used for the the pixel location that the center of the card moves
## towards each frame.
var target: Vector2

## If true, the center of the card moves towards `target` each frame. Set while dragging and for
## actions like dealing cards into predetermined stacks.
var moving: bool = false

## If set, the "zone" this card is currently in. Used to check that the card can be removed from
## the zone, and to inform the zone that the card is leaving.
var zone: Node2D = null

enum SUITS {
	CLUBS,
	DIAMONDS,
	HEARTS,
	SPADES,
}

## Rank goes from 1 (Ace) up through 13 (King). Changing it, in the Inspector or in code, causes
## the node to pick out a new card face according to its new rank (and suit).
@export var rank = 1 :
	set(value):
		rank = value
		refresh_sprite()
## Changing the suit, in the Inspector or in code, causes the node to pick out a new card face
## according to its new suit (and rank).
@export var suit: SUITS = SUITS.SPADES :
	set(value):
		suit = value
		refresh_sprite()

func _ready():
	refresh_sprite()
	
	# It's good to allow nodes to be run as toplevel scenes, so don't error if there's no parent.
	# But, if there is a parent, automatically wire up the two main signals.
	if get_parent():
		click_seen.connect(get_parent().on_card_click_seen)
		card_dropped.connect(get_parent().on_card_dropped)

## Flip the card face down (showing the art on the back)
func flip_face_down() -> void:
	$FaceSprite.hide()
	$BackSprite.show()

## Flip the card face up (showing the suit and rank)
func flip_face_up() -> void:
	$FaceSprite.show()
	$BackSprite.hide()

## Returns a string description of the card.
func desc() -> String:
	var srank = str(rank)
	if rank == 1:
		srank = "Ace"
	if rank == 11:
		srank = "Jack"
	if rank == 12:
		srank = "Queen"
	if rank == 13:
		srank = "King"
	
	return srank + " of " + SUITS.keys()[suit].capitalize()

## These mappings were determined by the card art assets.
var SUIT_FILENAME_PARTS = {
	SUITS.CLUBS: "c",
	SUITS.DIAMONDS: "d",
	SUITS.HEARTS: "h",
	SUITS.SPADES: "s",
}

## The filename was determined from the card art assets.
func refresh_sprite():
	$FaceSprite.texture = load("res://assets/cards/" + SUIT_FILENAME_PARTS[suit] + ("%02d" % rank) + ".png")

func _process(delta):
	if dragging:
		target = get_viewport().get_mouse_position()
		moving = true
	if moving:
		position = lerp(position, target, 25 * delta)

## Call this function to inform a card it has begun being dragged. Usually
## this will be called by the node which was connected to the `click_seen`
## signal, once it has chosen which emitter of that signal is the correct one
## for the user to start dragging.
func start_drag():
	dragging = true
	z_index = Z_INDEX_TOP_CARD
	if zone:
		zone.lost(self)
		zone = null

## This is called automatically when the user releases the mouse (or touchscreen), but could also
## be called any time a card should be dropped.
func stop_drag():
	if dragging == true:
		drop()
	dragging = false

## Chooses where a card should slide to if it was "rejected" when it tried to be added to a zone.
## For now, just moves the card lower on the screen than the zone is.
func fall_outside(other_zone: Node2D) -> void:
	target = other_zone.position + (H + 5) * Vector2.DOWN

## Implements the card being dropped in a location. This means signalling, and detecting whether
## the card was dropped on a zone. If so, the zone has some say: it gets to accept or reject the
## card.
func drop() -> void:
	moving = false
	zone = null
	for node in get_overlapping_areas():
		if node.is_in_group("card_zones"):
			moving = true
			if node.accepts_card(self):
				target = node.position
				zone = node
			else:
				fall_outside(node)
	card_dropped.emit(self)

func _on_input_event(_viewport, event, _shape_idx):
	if event.is_action_pressed("click"):
		if selectable and (not zone or not zone.pick_top_only or zone.card_is_top(self)):
			click_seen.emit(self)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				stop_drag()
