class_name PlayerController
extends RefCounted
## Maps local input to a bike's physics inputs with smoothing for digital keys.

var players: Array = ["p1", "p2"] ## input prefixes merged for this player
var steer := 0.0
var throttle := 0.0
var enabled := true


func _init(p_players: Array = ["p1", "p2"]) -> void:
	players = p_players


func update(bike: Bike, delta: float) -> void:
	var ph := bike.physics
	if not enabled:
		ph.in_throttle = 0.0
		ph.in_brake = 0.0
		ph.in_rear = 0.0
		ph.in_steer = move_toward(ph.in_steer, 0.0, delta * 4.0)
		ph.in_tuck = false
		return
	var input := Controls.read_drive(players)
	var target_steer: float = input["steer"]
	# Digital keys give -1/0/1: ramp them; analog sticks get light smoothing.
	var rate := 3.6 if absf(target_steer) in [0.0, 1.0] else 12.0
	if signf(target_steer) != signf(steer) and target_steer != 0.0:
		rate *= 1.8
	steer = move_toward(steer, target_steer, rate * delta)
	throttle = move_toward(throttle, input["throttle"], delta * 6.0)
	ph.in_steer = steer
	ph.in_throttle = throttle
	ph.in_brake = input["brake"]
	ph.in_rear = input["rear_brake"]
	ph.in_tuck = input["tuck"]
