extends RigidBody3D

@export_group("Motor")
@export var acceleration: float = 12.0
@export var max_speed: float = 12.0
@export var reverse_speed: float = 5.0
@export var braking_strength: float = 8.0

@export_group("Steering")
@export var steering_strength: float = 3.0

@export_group("Reverse")
@export var reverse_acceleration: float = 6.0
@export var direction_threshold: float = 0.2


func _physics_process(_delta: float) -> void:
	apply_motor()
	apply_steering()


func apply_motor() -> void:
	var throttle: float = Input.get_action_strength("accelerate")
	var brake: float = Input.get_action_strength("brake")

	var forward: Vector3 = -global_basis.z
	var forward_speed: float = linear_velocity.dot(forward)

	# Forward acceleration
	if throttle > 0.0:
		if forward_speed < max_speed:
			apply_central_force(
				forward * acceleration * mass * throttle
			)

	# Brake while moving forward
	elif brake > 0.0:
		if forward_speed > direction_threshold:
			apply_central_force(
				-forward * braking_strength * mass * brake
			)

		# Reverse after vehicle has nearly stopped
		elif forward_speed <= direction_threshold:
			if forward_speed > -reverse_speed:
				apply_central_force(
					-forward * reverse_acceleration * mass * brake
				)


func apply_steering() -> void:
	var steering: float = (
		Input.get_action_strength("steer_left")
		- Input.get_action_strength("steer_right")
	)

	var forward_speed: float = linear_velocity.dot(-global_basis.z)

	if absf(forward_speed) < 0.2:
		return

	var speed_factor: float = clampf(
		absf(forward_speed) / 3.0,
		0.0,
		1.0
	)

	# Reverse steering direction when driving backward
	var reverse_factor: float = signf(forward_speed)

	apply_torque(
		Vector3.UP
		* steering
		* steering_strength
		* speed_factor
		* reverse_factor
		* mass
	)
