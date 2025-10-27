extends AnimatedSprite2D

var not_walking = true
@onready var player = get_node("../MainCharacter")

func _process(delta):
	if player.is_walking and not_walking and $"../MainCharacter/CharacterSprite".frame == 1:
		not_walking = false
		animation = "default"
		position.x = player.position.x 
		position.y = player.position.y + 6
		$"../MainCharacter/FootStepsSoundEffect1".play()
		if player.is_walking and not $"../MainCharacter/FootStepsSoundEffect1".is_playing() and $"../MainCharacter/CharacterSprite".frame == 0:
			$"../MainCharacter/FootStepsSoundEffect1".play()
	if frame == 7:
		animation = "still"
		not_walking = true
	elif not player.is_walking:
		animation = "still"
		not_walking = true

	play()
