extends Node

signal continue_dialog

var text1 = ["Hey !", "Stop !"]
var text2 = ["What are you hoping", "doing those levels again and again ?"]
var text3 = ["Oh right, you probably", "followed that flickering button", "but you know, all of that,", "was totally scripted"]
var text4 = ["Anyway, I'd like to show you", "something pretty interesting"]
var text5 = ["Do you want to check it out ?", ["yes", "event_yes"], ["no", "event_no"]]

var text6 = ["Alright, I might ask you later", "", "Have fun", "", "If you can"]

var can_skip = false

onready var world = get_node("/root/world")
onready var event = get_node("event")

func _ready():
	event.connect("finished_writing", self, "set", ["can_skip", true])
	set_process_input(true)
	if global.level == 1 and save_manager.progression.first_finish and not save_manager.progression.first_contact:
		world.can_move = false
		write_texts([text1, text2, text3, text4, text5], [100, 100, 80, 100, 80])

func write_texts(texts_array, texts_pos_array):
	for i in range(texts_array.size()):
		can_skip = false
		event.new_text(texts_array[i], texts_pos_array[i])
		yield(self, "continue_dialog")
		event.destroy()

func _input(event):
	if event.is_action_pressed("jump") and can_skip:
		emit_signal("continue_dialog")

func event_yes():
	event.destroy()
	global.debug = true
	save_manager.progression.first_contact = true
	world.quit = true
	world.stop()

func event_no():
	event.destroy()
	write_texts([text6], [70])
	world.can_move = true