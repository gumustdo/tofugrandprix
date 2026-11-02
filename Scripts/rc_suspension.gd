extends Node3D

@export_group("Suspension")
@export var spring_strength: float = 100.0
@export var damping: float = 10.0
@export var rest_length: float = 0.45

@export_group("Tire Grip")
@export var lateral_grip: float = 20.0
@export var friction_coefficient: float = 1.0

@export_group("Debug")
@export var show_debug: bool = true

var vehicle: RigidBody3D
var suspension_rays: Array[RayCast3D] = []

func _ready() -> void:
	vehicle = get_parent() as RigidBody3D
	
	if vehicle == null:
		push_error("RCSuspension must be a child of RigidBody3D.")
		return
	
	# Find the four suspension rays.
	for wheel_anchor in get_children():
		var ray := wheel_anchor.get_node_or_null("SuspensionRay") as RayCast3D
		
		if ray != null:
			suspension_rays.append(ray)
			
	if suspension_rays.size() !=4:
		push_warning("Expected 4 suspension rays, found %d." % suspension_rays.size())

func _physics_process(_delta: float) -> void:
	if vehicle == null:
		return

	for ray in suspension_rays:
		ray.force_raycast_update()
		update_suspension(ray)

func update_suspension(ray: RayCast3D) -> void:
	if not ray.is_colliding():
		return

	var hit_point: Vector3 = ray.get_collision_point()

	var current_length: float = (
		ray.global_position.distance_to(hit_point)
	)

	var compression: float = rest_length - current_length

	# No suspension compression means no support force.
	if compression <= 0.0:
		return

	var suspension_up: Vector3 = (
		vehicle.global_basis.y.normalized()
	)

	var anchor_offset: Vector3 = (
		ray.global_position - vehicle.global_position
	)

	var point_velocity: Vector3 = (
		vehicle.linear_velocity
		+ vehicle.angular_velocity.cross(anchor_offset)
	)

	var suspension_velocity: float = (
		point_velocity.dot(suspension_up)
	)

	# 1. Calculate spring and damper force.
	var spring_force: float = (
		compression * spring_strength
		- suspension_velocity * damping
	)

	spring_force = maxf(spring_force, 0.0)

	var suspension_force: Vector3 = (
		suspension_up * spring_force
	)

	vehicle.apply_force(
		suspension_force,
		anchor_offset
	)

	# 2. Calculate sideways tire grip.
	var ground_normal: Vector3 = ray.get_collision_normal()

	var tire_right: Vector3 = (
	vehicle.global_basis.x
	- ground_normal
	* vehicle.global_basis.x.dot(ground_normal)
)

	if tire_right.length_squared() < 0.0001:
		return

	tire_right = tire_right.normalized()

	var contact_offset: Vector3 = (
		hit_point - vehicle.global_position
	)

	var contact_velocity: Vector3 = (
		vehicle.linear_velocity
		+ vehicle.angular_velocity.cross(contact_offset)
	)

	var lateral_speed: float = (
		contact_velocity.dot(tire_right)
	)

	var lateral_force_strength: float = (
		-lateral_speed * lateral_grip
	)

	# 3. Limit grip according to the suspension load.
	var max_lateral_force: float = (
		spring_force * friction_coefficient
	)

	lateral_force_strength = clampf(
		lateral_force_strength,
		-max_lateral_force,
		max_lateral_force
	)

	var lateral_force: Vector3 = (
		tire_right * lateral_force_strength
	)

	vehicle.apply_force(
		lateral_force,
		contact_offset
	)

	if show_debug:
		print(
            "Compression: %.3f | Spring: %.2f | Sideways: %.2f"
			% [
				compression,
				spring_force,
				lateral_force_strength
			]
		)
