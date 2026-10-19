class_name LanDiscovery
extends Node
## Ascolta gli annunci UDP broadcast degli host sulla stessa rete Wi-Fi.

signal hosts_changed

var udp := PacketPeerUDP.new()
var hosts: Dictionary = {}
var listening := false


func start_listen() -> bool:
	# Su Android abilitare il broadcast acquisisce il MulticastLock del Wi-Fi,
	# senza il quale molti telefoni scartano i pacchetti broadcast in arrivo.
	udp.set_broadcast_enabled(true)
	var err := udp.bind(NetSession.DISCOVERY_PORT, "*")
	listening = err == OK
	if not listening:
		push_warning("Ricerca partite non disponibile (porta %d): %s" % [NetSession.DISCOVERY_PORT, error_string(err)])
	return listening


func _exit_tree() -> void:
	udp.close()


func _process(_delta: float) -> void:
	if not listening:
		return
	var changed := false
	while udp.get_available_packet_count() > 0:
		var pkt := udp.get_packet()
		var ip := udp.get_packet_ip()
		var d: Variant = JSON.parse_string(pkt.get_string_from_utf8())
		if typeof(d) != TYPE_DICTIONARY or d.get("game", "") != NetSession.MAGIC:
			continue
		var entry: Dictionary = d
		entry["ip"] = ip
		entry["time"] = Time.get_ticks_msec()
		if not hosts.has(ip):
			changed = true
		hosts[ip] = entry
	var now := Time.get_ticks_msec()
	for ip in hosts.keys():
		if now - int(hosts[ip]["time"]) > 4000:
			hosts.erase(ip)
			changed = true
	if changed:
		hosts_changed.emit()
