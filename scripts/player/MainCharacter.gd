extends CharacterBody2D

# --- Signals ---
signal object_hit(dir: Vector2)

# --- Basic vars ---
var speed: int = 85
var current_hp: int = 5
var max_hp: int = 5
var combo: int = 0
var attack_cd: bool = false
var weapon_damage: float = 1
var attack_dir: String = "front" 
var is_dead: bool = false

# --- Healing vars ---
var heal_timer: float = 0
var heal_hold: bool = false
var vitality: int = 2
var heal_mode: bool = false
var heal_time: float = 3

# --- Invisibility vars ---
var is_invisible: bool = false
var invis_cd: bool = false

# --- Movement vars ---
var input_vector := Vector2.ZERO
var is_walking: bool = false
var walking_dir: String = "front"
var afterimage_frame_counter = 0

# --- Knockback ---
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 600.0
var is_knockback: bool = false
var immunity_frames: bool = false
var meteor_stunned: bool = false
var is_shaking: bool = false

# --- Power Hit ---
var power_hit_damage_multi: int = 10000
var hit_charged: bool = false
var hit_charging: bool = false
var hit_charge_timer: float = 0
var hit_charge_time: float = 1.5

# --- Directions ---
var attack_offsets = {
	"front": Vector2(0,8),
	"back": Vector2(0,-8),
	"left": Vector2(-8,0),
	"right": Vector2(8,0)
}
var attack_rotations = {
	"front": PI/2,
	"back": -PI/2,
	"left": -PI,
	"right": 0
}
var dir_to_anim = {
	Vector2(1, 0): "right",
	Vector2(-1, 0): "left",
	Vector2(0, -1): "back",
	Vector2(0, 1): "front"
}

# --- System Vars ---
@onready var sprite: AnimatedSprite2D = $CharacterSprite
@onready var e = "res://scenes/sub/scene_sub_skeleton.tscn"

# --- Ready ---
func _ready():
	$AttackAnimation.visible = false
	$ColorRect.visible = false

# --- Main Loop ---
func _physics_process(delta):
	health_display_manage()
	combo_manage()
	get_input()
	update_animation()
	if if_can_move():
		move_character(delta)
		attack_manager()
		invis()
		heal(delta)

	if combo >= 5:
		afterimage_frame_counter += 1
		if afterimage_frame_counter % 2 == 0: 
			spawn_afterimage()

	# Knockback processing
	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	else:
		is_knockback = false

	if not $AttackTimer.is_stopped():
		attack_location_manager()
	if hit_charged:
		weapon_damage * power_hit_damage_multi

# --- Blanket Bans ---
func stop_all_audio():
	get_tree().call_group("Audio", "stop")

# --- Return Functions ---
func if_can_move() -> bool:
	return not is_knockback and not meteor_stunned and not is_dead

func get_current_speed() -> int:
	if is_knockback or meteor_stunned or heal_hold:
		return 0
	elif is_invisible:
		return 190
	elif hit_charging:
		return 40
	elif combo == 5:
		return 115
	elif combo >= 10:
		return 145
	else:
		return 85

# --- Attack ---
func attack_manager():
	if Input.is_action_just_pressed("attack") and not attack_cd and not is_knockback:
		attack_cd = true
		$AttackTimer.start()
		$SwordSoundEffect.play()
		$AttackAnimation.visible = true
		$AttackAnimation.play()
		attack_dir = walking_dir
		attack_location_manager()

		for body in $AttackArea.get_overlapping_bodies():
			if body.is_in_group("Enemy") and body.has_method("take_damage"):
				body.take_damage(global_position)

func _on_attack_area_body_entered(body):
	if not $AttackTimer.is_stopped():
		if body.is_in_group("Object"):
			var dir = (global_position - body.global_position).normalized()
			knockback_velocity = dir * 150
			emit_signal("object_hit", dir)
		elif body.is_in_group("Enemy") and body.has_method("take_damage") and not body.is_in_group("Object"):
			body.take_damage(global_position)

	if hit_charged:
		hit_charged = false

func _on_attack_timer_timeout():
	$AttackCooldown.start()
	$AttackAnimation.visible = false
	$AttackAnimation.stop()
	$AttackAnimation.frame = 0

func _on_attack_cooldown_timeout():
	attack_cd = false

func attack_location_manager():
	var offset = attack_offsets.get(attack_dir, Vector2.ZERO)
	var rotation_angle = attack_rotations.get(attack_dir, 0)
	$AttackArea.position = sprite.position + offset
	$AttackArea.rotation = rotation_angle
	$AttackAnimation.position = $AttackArea.position
	$AttackAnimation.rotation = rotation_angle

# --- Damage & Knockback ---
func take_damage(from_position: Vector2):
	current_hp -= 1
	$HitColourTimer.start()
	$HitStunTimer.start()
	immunity_frames = true
	$ImmunityFrames.start()
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	$PlayerDamageRecievedSoundEffect.play()
	combo = 0

	var dir = (global_position - from_position).normalized()
	knockback_velocity = dir * 150
	is_knockback = true

	if current_hp > max_hp:
		current_hp = max_hp
	if current_hp <= 0:
		die()

func take_damage_from_meteor(source_position: Vector2):
	current_hp -= 2
	$HitColourTimer.start()
	$MeteorHitStunTimer.start()
	immunity_frames = true
	$ImmunityFrames.start()
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	sprite.animation = "front_idle"
	$PlayerDamageRecievedSoundEffect.play()
	combo = 0

	# Set knockback from meteor
	var dir = (global_position - source_position).normalized()
	knockback_velocity = dir * 200   # you can tweak the strength
	meteor_stunned = true
	is_knockback = true

	if current_hp > max_hp:
		current_hp = max_hp
	if current_hp <= 0:
		die()

func _on_meteor_hit_stun_timer_timeout():
	meteor_stunned = false

func _on_hit_colour_timer_timeout():
	sprite.modulate = Color(1, 1, 1, 1)

func _on_hit_stun_timer_timeout():
	is_knockback = false

func _on_immunity_frames_timeout():
	immunity_frames = false

func die():
	current_hp = 0
	if is_dead:
		return
	is_dead = true

	get_tree().call_group("Enemies", "set_physics_process", false)
	get_tree().call_group("Enemies", "set_process", false)
	set_physics_process(false)
	set_process(false)

	velocity = Vector2.ZERO
	if not is_dead:
		$PlayerDeathSoundEffect.play()
	elif is_dead:
		return
	stop_all_audio()
	sprite.animation = "death"
	sprite.play()

	is_knockback = true
	attack_cd = true
	is_invisible = true

	if walking_dir == "left":
		$MainCharacterAnimation.play("Player_Death_Left")
	elif walking_dir == "right":
		$MainCharacterAnimation.play("Player_Death_Right")
	else:
		$MainCharacterAnimation.play("Player_Death_Right")


	await get_tree().create_timer(2.79).timeout
	$PlayerDeathSoundEffect.stop()
	await get_tree().create_timer(0.21).timeout
	await wait_for_input()
	get_tree().reload_current_scene()

func wait_for_input():
	while true:
		await get_tree().process_frame
		if Input.is_anything_pressed():
			break

# --- Combo ---
func combo_manage():
	$ManaGauge.text = str(combo)
	$ComboTimer.start()
	if combo >= 5 and not $AudioStreamPlayer2D.playing and not $FlowStateActivated.playing:
		$FlowStateActivated.play()
		sprite.animation = "front_idle"
		Engine.time_scale = 0.5
		await get_tree().create_timer(1.325).timeout
		$AudioStreamPlayer2D.play()
		$FlowStateActivated.stop()
		$ColorRect.visible = true
		Engine.time_scale = 1
	if combo >= 10:
		weapon_damage * 1.5
		$CharacterSprite.speed_scale = 1.5
	if combo >= 15:
		weapon_damage * 3
	if combo <= 0 and $AudioStreamPlayer2D.playing:
		$AudioStreamPlayer2D.stop()
		if speed == 115:
			weapon_damage / 1.5
		if speed == 145:
			weapon_damage / 3
		$ColorRect.visible = false

func combo_increase():
	combo += 1

# --- Health ---
func health_display_manage():
	$HealthBar.text = str(current_hp) + "/" + str(max_hp)

# --- Healing ---
func heal(delta):
	if Input.is_action_just_pressed("heal") and combo >= 6:
		$HealSoundEffect.play()
	if Input.is_action_pressed("heal") and not heal_mode and combo >= 16 and current_hp < max_hp and not is_knockback and not meteor_stunned:
		heal_timer += delta
		heal_hold = true
		sprite.animation = walking_dir + "_idle"
		if heal_timer >= heal_time:
			heal_timer = 0
			combo -= 15
			current_hp += 1
			heal_mode = false
			$HealTimer.start()
			$ChargeAttackSoundEffect.stop()
	if Input.is_action_just_released("heal"):
		heal_timer = 0
		heal_hold = false
		$HealSoundEffect.stop()

func _on_heal_timer_timeout():
	heal_mode = false

# --- Invisibility ---
func invis():
	if Input.is_action_just_pressed("invis") and not invis_cd and not is_knockback and not is_invisible:
		if combo >= 6:
			combo -= 10
			sprite.modulate.a = 0.5
			$InvisTimer.start()
			is_invisible = true
			$InvisSoundEffect.play()

func _on_invis_timer_timeout():
	sprite.modulate.a = 1.0
	is_invisible = false
	$InvisCDTimer.start()
	invis_cd = true

func _on_invis_cd_timer_timeout():
	invis_cd = false

# --- Power Hit ---
func power_hit(delta):
	if Input.is_action_pressed("charge_hit") and not is_knockback and not hit_charged:
		hit_charge_timer += delta
		hit_charging = true
		if hit_charge_timer >= hit_charge_time:
			hit_charge_timer = 0
			hit_charged = true
			hit_charging = false
	if Input.is_action_just_released("charge_hit"):
		hit_charge_timer = 0
		hit_charging = 0
		if not hit_charged:
			$ChargeAttackSoundEffect.stop()

# --- Afterimage ---
func spawn_afterimage():
	var afterimage1 = $CharacterSprite.duplicate()

	get_parent().add_child(afterimage1)

	afterimage1.global_position = $CharacterSprite.global_position

	afterimage1.modulate = Color(1, 1, 1, 0.5)

	var fade_time = 0.3
	for t in range(1, 31):  # roughly 30 frames = 0.3 seconds at 60fps
		await get_tree().process_frame
		afterimage1.modulate.a = 0.5 * (1 - t / 30.0)

	afterimage1.queue_free()

# --- Input & Movement ---
func get_input():
	input_vector = Vector2.ZERO
	if Input.is_action_pressed("right"):
		input_vector.x += 1
	if Input.is_action_pressed("left"):
		input_vector.x -= 1
	if Input.is_action_pressed("up"):
		input_vector.y -= 1
	if Input.is_action_pressed("down"):
		input_vector.y += 1
	input_vector = input_vector.normalized()
	velocity = input_vector * get_current_speed()

func move_character(delta):
	move_and_slide()
	is_walking = input_vector.length() > 0

func update_animation():
	if not is_knockback:
		if input_vector.x > 0 and not meteor_stunned:
			sprite.animation = "right"
			walking_dir = "right"
		elif input_vector.x < 0 and not meteor_stunned:
			sprite.animation = "left"
			walking_dir = "left"
		elif input_vector.y < 0 and input_vector.x == 0 and not meteor_stunned:
			sprite.animation = "back"
			walking_dir = "back"
		elif input_vector.y > 0 and input_vector.x == 0 and not meteor_stunned:
			sprite.animation = "front"
			walking_dir = "front"

	if input_vector == Vector2.ZERO:
		sprite.animation = walking_dir + "_idle"

	sprite.play()

