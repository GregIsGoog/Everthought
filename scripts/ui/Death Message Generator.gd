extends Node2D

var death_messages = ["You lowkey suck", "Your dumbass died", "Major skill issue", "Uninstall", "Try easy mode if you're having trouble!"]
var death_message_value: float = 0

func _physics_process(delta): 
	death_message_value = randi() % 5

func death_message_randomizer():
	$DeathMessage.text = death_messages[death_message_value]
