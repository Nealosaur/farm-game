class_name State
extends Node
## One state of a StateMachine. Subclass and override the hooks.
## `machine` is injected by StateMachine on ready.

var machine: StateMachine


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
