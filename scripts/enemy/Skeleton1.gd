extends CharacterBody2D

# --- Basic Vars --- 
var health: float = 3
var speed: float = 40

# --- Handlers ---
var mode := "idle"
var directionx := 0
var directiony := 0
var target = null

# --- Knockback Vars ---
var is_knockback: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 800.0
var immune: bool = false

# --- System Vars ---
@onready var main = get_node("../MainCharacter")
@onready var skeleton: AnimatedSprite2D = $SkeletonSprite
var starting_pos: Vector2 = Vector2.ZERO

# --- Attack Vars --- 
var meteor1 = Vector2.ZERO
var meteor2 = Vector2.ZERO
var meteor3 = Vector2.ZERO
var meteor1_tracking: bool = false
var meteor2_tracking: bool = false
var meteor3_tracking: bool = false

func _ready():
	skeleton.play("idle")
	starting_pos = global_position
	$meteor1.visible = false
	$meteor2.visible = false
	$meteor3.visible = false
	$meteor1/meteor1label  .visible = false
	$meteor2/meteor1label2.visible = false
	$meteor3/meteor1label3.visible = false

# --- Movement and Direction ---
func pursuit_start():
	mode = "pursuit"
	target = main

func pursuit_end():
	if mode == "pursuit":
		mode = "idle"
	target = null
	velocity = Vector2.ZERO

func _on_agro_range_body_exited(body):
	if body.is_in_group("Player"):
		pursuit_end()
		$Meteor1TrackerTimer.stop()

func _on_agro_range_body_entered(body):
	if body.is_in_group("Player"):
		pursuit_start()
		$Meteor1TrackerTimer.start()

func pursuit_update():
	velocity = (target.global_position - global_position).normalized() * speed

	directionx = sign(velocity.x)
	directiony = sign(velocity.y)

	move_and_slide()

func stop():
	set_physics_process(false)
	set_process(false)

func idle_update():
	var dist = starting_pos.distance_to(global_position)
	if dist > 2: 
		velocity = (starting_pos - global_position).normalized() * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	directionx = sign(velocity.x)
	directiony = sign(velocity.y)

# --- Animation ---
func animation_handler():
	if velocity == Vector2.ZERO or is_knockback:
		skeleton.play("idle")
		return

	if abs(directionx) > 0:
		if directionx == -1:
			skeleton.play("left")
		else:
			skeleton.play("right")
	elif directiony != 0:
		if directiony == -1:
			skeleton.play("front")
		else:
			skeleton.play("back")

# --- Deal and Receive Damage ---
func take_damage(from_position: Vector2):
	$"../MainCharacter/DamageDealtSoundEffect".play()
	if not immune:
		if not main.hit_charged:
			health -= 1
			main.combo += 1
			emit_signal("damaged")
		elif main.hit_charged:
			health = 0
		$DamageColourTimer.start()
		skeleton.modulate = Color(1, 0.5, 0.5, 1)
		$HitStunTimer.start()
		$ImmunityFrames.start()

		# --- Apply knockback ---
		var dir = (global_position - from_position).normalized()
		knockback_velocity = dir * 300
		is_knockback = true
		immune = true

	if health <= 0:
		die()

func die():
	emit_signal("died")
	queue_free()

func _on_damage_colour_timer_timeout():
	skeleton.modulate = Color(1, 1, 1, 1)

func _physics_process(delta):
	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
		speed = 0
		
	else:
		is_knockback = false

		if mode == "pursuit" and not main.is_invisible:
			pursuit_update()
		else:
			idle_update()

	animation_handler()

# --- Meteor 1 ---
	if meteor1_tracking and not main.is_invisible:
		$meteor1.global_position = main.global_position
		$Meteor1Area/Meteor1Hitbox.global_position = main.global_position
	else:
		$meteor1.global_position = meteor1
		$Meteor1Area/Meteor1Hitbox.global_position = meteor1

	# --- Meteor 2 ---
	if meteor2_tracking and not main.is_invisible:
		$meteor2.global_position = main.global_position
		$Meteor2Area/Meteor2Hitbox.global_position = main.global_position
	else:
		$meteor2.global_position = meteor2
		$Meteor2Area/Meteor2Hitbox.global_position = meteor2

	# --- Meteor 3 ---
	if meteor3_tracking and not main.is_invisible:
		$meteor3.global_position = main.global_position
		$Meteor3Area/Meteor3Hitbox.global_position = main.global_position
	else:
		$meteor3.global_position = meteor3
		$Meteor3Area/Meteor3Hitbox.global_position = meteor3

func _on_attack_area_body_entered(body):
	if body.is_in_group("Player"):
		body.take_damage(global_position)

func _on_hit_stun_timer_timeout():
	speed = 40

func _on_immunity_frames_timeout():
	immune = false

func _on_meteor_1_tracker_timer_timeout():
	$Meteor1TelegraphTimer.start()
	start_tracking()

func start_tracking():
	if main.is_dead:
		return

	meteor1_tracking = true
	$meteor1.visible = true
	$AnimationTree.play("meteor1_pulse")

	await get_tree().create_timer(0.33).timeout
	if main.is_dead:
		return
	
	meteor2_tracking = true
	$meteor2.visible = true
	$AnimationTree.play("meteor2_pulse")
	
	await get_tree().create_timer(0.33).timeout
	if main.is_dead:
		return

	meteor3_tracking = true
	$meteor3.visible = true
	$AnimationTree.play("meteor3_pulse")

func _on_meteor_1_telegraph_timer_timeout():
	$Meteor1AttackTimer.start()
	start_telegraphing()

func start_telegraphing():
	if main.is_dead:
		return

	meteor1 = main.global_position
	meteor1_tracking = false
	$AnimationTree.play("meteor1_fast_pulse")

	await get_tree().create_timer(0.33).timeout
	if main.is_dead:
		return

	meteor2 = main.global_position
	meteor2_tracking = false
	$AnimationTree2.play("meteor2_fast_pulse")

	await get_tree().create_timer(0.33).timeout
	if main.is_dead:
		return

	meteor3 = main.global_position
	meteor3_tracking = false
	$AnimationTree3.play("meteor3_fast_pulse")

func _on_meteor_1_attack_timer_timeout():
	$AudioStreamPlayer2D.play()
	launch_meteor_attack()

func launch_meteor_attack():
	if main.is_dead:
		return

	$meteor1.visible = false
	$meteor1/meteor1label.visible = true
	await get_tree().create_timer(0.33).timeout
	$meteor1/meteor1label.visible = false
	for body in $Meteor1Area.get_overlapping_bodies():
		if body.is_in_group("Player"):
			main.take_damage_from_meteor()

	$meteor2.visible = false
	$meteor2/meteor1label2.visible = true
	await get_tree().create_timer(0.33).timeout
	if main.is_dead:
		return

	$meteor2/meteor1label2.visible = false
	for body in $Meteor2Area.get_overlapping_bodies():
		if body.is_in_group("Player"):
			main.take_damage_from_meteor()

	$meteor3.visible = false
	$meteor3/meteor1label3.visible = true
	await get_tree().create_timer(0.33).timeout
	if main.is_dead:
		return

	$meteor3/meteor1label3.visible = false
	for body in $Meteor3Area.get_overlapping_bodies():
		if body.is_in_group("Player"):
			main.take_damage_from_meteor()

	if mode == "pursuit":
		$Meteor1TrackerTimer.start()
