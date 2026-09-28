extends Node
## LAN / online multiplayer over ENet (host or join by IP). Up to 4 human riders; AI fills
## the remaining grid slots. Each peer simulates its own bike and sends 20 Hz snapshots to
## the host; the host simulates the AI and relays every bike's state to all peers. Results
## are decided by the host.

signal lobby_changed
signal connection_failed(reason: String)
signal session_ended(reason: String)
signal race_starting

const DEFAULT_PORT := 24040
const MAX_HUMANS := 4
const SEND_RATE := 20.0
const TOTAL_RIDERS := 8

var peer: ENetMultiplayerPeer
var is_host := false
var players: Dictionary = {} ## peer_id -> {"name", "bike", "paint", "accent", "ready"}
var lobby_settings := {"track": "ramon", "laps": 2, "difficulty": "medium"}
var race: Node
var race_config: Dictionary = {}
var host_results: Array = []

var _send_accum := 0.0
var _loaded: Dictionary = {}
var _countdown_sent := false
var _net_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func local_info() -> Dictionary:
	var bike: String = Save.progress.get("selected_bike", "naked")
	var paint := Save.get_paint(bike)
	var suit: Dictionary = Save.progress.get("suit", {"main": 2, "accent": 0})
	return {"name": Game.player_name(), "bike": bike, "paint": paint["body"], "accent": paint["accent"],
		"suit_main": suit.get("main", 2), "suit_accent": suit.get("accent", 0), "ready": false}


# --- Session ------------------------------------------------------------------

func host(port := DEFAULT_PORT) -> Error:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_HUMANS - 1)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	players = {1: local_info()}
	players[1]["ready"] = true
	lobby_changed.emit()
	return OK


func join(address: String, port := DEFAULT_PORT) -> Error:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), port)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	players = {}
	return OK


func leave() -> void:
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	players.clear()
	race = null
	_loaded.clear()
	_countdown_sent = false
	host_results.clear()


func _on_peer_connected(id: int) -> void:
	if is_host and players.size() >= MAX_HUMANS:
		peer.disconnect_peer(id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	players.erase(id)
	_loaded.erase(id)
	_broadcast_lobby()
	if race and is_instance_valid(race):
		race.call("net_peer_left", id)


func _on_connected() -> void:
	_register.rpc_id(1, local_info())


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("NET_ERR_CONNECT")


func _on_server_disconnected() -> void:
	leave()
	session_ended.emit("NET_ERR_HOST_LEFT")


# --- Lobby RPCs ---------------------------------------------------------------

@rpc("any_peer", "reliable")
func _register(info: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	info["ready"] = false
	players[id] = info
	_broadcast_lobby()


@rpc("any_peer", "reliable")
func _update_info(info: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id] = info
		_broadcast_lobby()


func set_local_info(info: Dictionary) -> void:
	if is_host:
		players[1] = info
		_broadcast_lobby()
	elif is_online():
		_update_info.rpc_id(1, info)


func set_lobby_settings(s: Dictionary) -> void:
	if not is_host:
		return
	lobby_settings = s
	_broadcast_lobby()


func _broadcast_lobby() -> void:
	_lobby_sync.rpc(players, lobby_settings)
	lobby_changed.emit()


@rpc("authority", "reliable", "call_local")
func _lobby_sync(p: Dictionary, settings: Dictionary) -> void:
	players = p
	lobby_settings = settings
	lobby_changed.emit()


func all_ready() -> bool:
	for id in players:
		if not players[id].get("ready", false):
			return false
	return true


## Host: builds the shared rider list and starts the race on every peer.
func start_race() -> void:
	if not is_host:
		return
	var riders := []
	var ids := players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = players[id]
		riders.append({"kind": "human", "peer": id, "name": p["name"], "bike": p["bike"],
			"paint": p.get("paint", 0), "accent": p.get("accent", 10), "suit_main": p.get("suit_main", 2), "suit_accent": p.get("suit_accent", 0)})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool := ["sport", "naked", "supermoto", "cafe"]
	var ai_i := 0
	while riders.size() < TOTAL_RIDERS:
		riders.append({"kind": "ai", "name": GameData.rider_name(ai_i), "bike": pool[rng.randi_range(0, 3)], "seed": rng.randi()})
		ai_i += 1
	# Grid: humans spread through the middle of the pack.
	var slots := range(TOTAL_RIDERS)
	slots.shuffle()
	for i in riders.size():
		riders[i]["grid"] = slots[i]
	var cfg := {"mode": "online", "track": lobby_settings["track"], "laps": lobby_settings["laps"],
		"difficulty": lobby_settings["difficulty"], "riders": riders,
		"autopilot": lobby_settings.get("autopilot", false)}
	_begin.rpc(cfg)


@rpc("authority", "reliable", "call_local")
func _begin(cfg: Dictionary) -> void:
	race_config = cfg
	host_results.clear()
	_loaded.clear()
	_countdown_sent = false
	race_starting.emit()
	Game.start_race(cfg)


# --- Race -------------------------------------------------------------------------

func attach_race(r: Node) -> void:
	race = r
	_net_time = 0.0
	if is_host:
		_loaded[1] = true
	else:
		_client_loaded.rpc_id(1)


@rpc("any_peer", "reliable")
func _client_loaded() -> void:
	if is_host:
		_loaded[multiplayer.get_remote_sender_id()] = true


## Called by the race every physics tick.
func race_tick(r: Node, delta: float) -> void:
	if race != r:
		return
	_net_time += delta
	if is_host and not _countdown_sent:
		var ready_all := true
		for id in players:
			if not _loaded.get(id, false):
				ready_all = false
		# Start anyway after a timeout so one slow peer can't hold everyone.
		if ready_all or _net_time > 20.0:
			_countdown_sent = true
			_start_countdown.rpc()
	_send_accum += delta
	if _send_accum < 1.0 / SEND_RATE:
		return
	_send_accum = 0.0
	if is_host:
		_world_state.rpc(r.call("net_pack_all"), _net_time)
	else:
		var mine: PackedByteArray = r.call("net_pack_local")
		if not mine.is_empty():
			_client_state.rpc_id(1, mine)


@rpc("authority", "reliable", "call_local")
func _start_countdown() -> void:
	if race and is_instance_valid(race):
		race.call("net_start_countdown")


@rpc("any_peer", "unreliable_ordered")
func _client_state(data: PackedByteArray) -> void:
	if is_host and race and is_instance_valid(race):
		race.call("net_apply_peer_state", multiplayer.get_remote_sender_id(), data)


@rpc("authority", "unreliable_ordered")
func _world_state(data: PackedByteArray, t: float) -> void:
	if race and is_instance_valid(race):
		race.call("net_apply_world_state", data, t)


func send_results(results: Array) -> void:
	if is_host:
		_results.rpc(results)


@rpc("authority", "reliable", "call_local")
func _results(results: Array) -> void:
	host_results = results
	if race and is_instance_valid(race):
		race.call("net_results_received", results)


func end_race() -> void:
	race = null
