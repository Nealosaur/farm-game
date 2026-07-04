class_name StateMachine
extends Node
## Generic node-based FSM. Children are State nodes; transition by node name.

@export var initial_state: State

var current: State


func _ready() -> void:
	for child in get_children():
		if child is State:
			child.machine = self
	if initial_state != null:
		if owner != null and not owner.is_node_ready():
			await owner.ready
		current = initial_state
		current.enter()


func _process(delta: float) -> void:
	if current != null:
		current.update(delta)


func _physics_process(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func transition(to_name: String) -> void:
	var next := get_node_or_null(NodePath(to_name)) as State
	if next == null:
		push_warning("StateMachine: unknown state " + to_name)
		return
	if current != null:
		current.exit()
	current = next
	current.enter()
