extends Node
## An authenticated HTTPS connection to the owner's purchase ledger.

var _endpoint := ""
var _mode := "test"
var _access_token := ""
var _account := ""
var _installation := ""
var _session_path := ""


func setup(endpoint: String, mode: String) -> void:
	if not endpoint.begins_with("https://") or mode not in ["test", "live"]:
		return
	_mode = mode
	_endpoint = endpoint.trim_suffix("/")
	_session_path = "user://play_session.json" if mode == "live" else "user://play_test_session.json"
	var install_path := "user://play_install.id" if mode == "live" else "user://play_test_install.id"
	_installation = _load_installation(install_path)
	if not FileAccess.file_exists(_session_path):
		return
	var session: Variant = JSON.parse_string(FileAccess.get_file_as_string(_session_path))
	if session is Dictionary and _is_access_token(session.get("access_token")) and _is_account(session.get("account")):
		_access_token = session.access_token
		_account = session.account


func endpoint_ready() -> bool:
	return not _endpoint.is_empty() and not _installation.is_empty()


func ready_to_verify() -> bool:
	return endpoint_ready() and not _access_token.is_empty()


func connect_account(token: String) -> Dictionary:
	if not endpoint_ready() or not _is_access_token(token):
		return {"ok": false, "error": "session_required"}
	var session := await _call("session", token, {})
	if not session.ok:
		return session
	var account: Variant = session.get("obfuscated_account_id")
	if not _is_account(account) or (not _account.is_empty() and _account != account):
		return {"ok": false, "error": "wrong_account"}
	var record := JSON.stringify({"access_token": token, "account": account})
	if not _write_file(_session_path, record):
		return {"ok": false, "error": "storage_error"}
	_access_token = token
	_account = account
	return {"ok": true}


func send(path: String, data: Dictionary = {}) -> Dictionary:
	if not ready_to_verify():
		return {"ok": false, "error": "session_required"}
	var response := await _call(path, _access_token, data)
	if path == "session" and response.ok and response.get("obfuscated_account_id") != _account:
		return {"ok": false, "error": "wrong_account"}
	return response


func _call(path: String, token: String, data: Dictionary) -> Dictionary:
	var node := HTTPRequest.new()
	node.timeout = 16.0
	node.max_redirects = 0
	node.body_size_limit = 131072
	add_child(node)
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + token])
	var body := data.duplicate()
	body.installation = _installation
	var error := node.request(_endpoint + "/v1/play/" + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		node.queue_free()
		return {"ok": false, "error": "server_unavailable"}
	var response: Array = await node.request_completed
	node.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "server_unavailable"}
	var decoded: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	if not decoded is Dictionary:
		return {"ok": false, "error": "server_unavailable"}
	if response[1] != 200 or decoded.get("ok") != true:
		return {"ok": false, "error": str(decoded.get("error", "server_unavailable"))}
	if decoded.get("play_mode") != _mode:
		return {"ok": false, "error": "wrong_purchase_environment"}
	return decoded


func _load_installation(path: String) -> String:
	if FileAccess.file_exists(path):
		var saved := FileAccess.get_file_as_string(path)
		return saved if saved.length() == 32 and saved.is_valid_hex_number() else ""
	var identity := Crypto.new().generate_random_bytes(16).hex_encode()
	return identity if _write_file(path, identity) else ""


func _write_file(path: String, value: String) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(temporary) != value:
		return false
	return DirAccess.rename_absolute(temporary, path) == OK


func _is_account(account: Variant) -> bool:
	return account is String and account.length() == 64 and account.is_valid_hex_number()


func _is_access_token(token: Variant) -> bool:
	if not token is String or token.length() < 24 or token.length() > 256:
		return false
	var allowed := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
	for character in token:
		if character not in allowed:
			return false
	return true
