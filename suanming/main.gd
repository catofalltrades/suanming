extends Node2D

# I like to call the root node of the whole game "main".

## Set when a card sends a click_seen signal. Cleared every frame, after one of the clicked cards
## is chosen.
var click_seen = false

## Stores all cards that sent click_seen signals this frame. Cleared every frame.
var cards_clicked: Array[Card] = []

## A trick for quick development: Make hitting ESC quit the game. Later, we'll want to pull up a
## menu and things.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func on_card_click_seen(card: Card) -> void:
	click_seen = true
	cards_clicked.append(card)

## Comparator function for sorting by z_index
func comp_z_index(a: Variant, b: Variant) -> bool:
	return a.z_index < b.z_index

## Convenience function to return all known cards. This will have to change if we later have cards
## that have been instantiated but are not in play.
## It should return an Array[Card] but I don't know how to cast Array[Node] to Array[Card].
func all_cards() -> Array[Node]:
	return get_tree().get_nodes_in_group("cards")

## When a card is dropped, its z-index needs to stop being the special "above all others" value, but
## it needs to stay on top. My solution was to loop over every card (since there's at most 52, which
## we can easily do in one frame), in order of current z-index, and reassign their z-index values,
## from 0 on up.
func on_card_dropped(_card: Card) -> void:
	var cards_by_zindex = all_cards()
	cards_by_zindex.sort_custom(comp_z_index)
	var zindex = 0
	for card in cards_by_zindex:
		card.z_index = zindex
		zindex += 1

func _process(_delta: float) -> void:

	# Each frame, if any cards reported a click, tell the highest one it was clicked.
	if click_seen:
		cards_clicked.sort_custom(comp_z_index)
		cards_clicked[-1].start_drag()
		cards_clicked = []
		click_seen = false
