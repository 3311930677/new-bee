extends RefCounted

const ENDPOINT := "/v1/rooms/positions"
const BUFFER_LIMIT := 64 * 1024
const IDLE_MS := 2500

var _http: HTTPClient
var _headers: PackedStringArray
var _path := ""
var _sent := false
var _pending := PackedByteArray()
var _last_data := 0


func open(base: String, token: String, content_version: String, tls: TLSOptions) -> bool:
	close()
	var uri := RegEx.create_from_string("^(https?)://(\\[[0-9A-Fa-f:.]+\\]|[^:/?#@\\s]+)(?::([0-9]{1,5}))?(/[^?#@\\s]*)?$").search(base)
	if uri == null or token.is_empty():
		return false
	var https := uri.get_string(1) == "https"
	var port := int(uri.get_string(3))
	if port > 65535:
		return false
	if port == 0:
		port = 443 if https else 80
	var target := uri.get_string(2).trim_prefix("[").trim_suffix("]")
	_path = uri.get_string(4).trim_suffix("/") + ENDPOINT
	_headers = PackedStringArray([
		"Accept: application/x-ndjson",
		"Authorization: Bearer %s" % token,
		"X-Content-Version: %s" % content_version,
	])
	_http = HTTPClient.new()
	_http.read_chunk_size = 8192
	var options := tls if tls != null else TLSOptions.client()
	if _http.connect_to_host(target, port, options if https else null) != OK:
		close()
		return false
	_last_data = Time.get_ticks_msec()
	return true


func is_open() -> bool:
	return _http != null


func close() -> void:
	if _http != null:
		_http.close()
	_http = null
	_sent = false
	_pending.clear()
	_headers.clear()


func poll_latest() -> Dictionary:
	if _http == null:
		return {}
	if Time.get_ticks_msec() - _last_data > IDLE_MS or _http.poll() != OK:
		close()
		return {}
	match _http.get_status():
		HTTPClient.STATUS_CONNECTED:
			if _sent:
				close()
			elif _http.request(HTTPClient.METHOD_GET, _path, _headers) != OK:
				close()
			else:
				_headers.clear()
				_sent = true
		HTTPClient.STATUS_BODY:
			if _http.get_response_code() == 200:
				return _read_available()
			close()
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
			pass
		_:
			close()
	return {}


func _read_available() -> Dictionary:
	var latest := {}
	for chunk in range(8):
		if _http.get_status() != HTTPClient.STATUS_BODY:
			break
		var bytes := _http.read_response_body_chunk()
		if bytes.is_empty():
			break
		_last_data = Time.get_ticks_msec()
		_pending.append_array(bytes)
		if _pending.size() > BUFFER_LIMIT:
			close()
			return {}
		var newline := _pending.find(10)
		while newline >= 0:
			var item: Variant = JSON.parse_string(_pending.slice(0, newline).get_string_from_utf8())
			if item is Dictionary and int(item.get("tick", 0)) > int(latest.get("tick", 0)):
				latest = item
			_pending = _pending.slice(newline + 1)
			newline = _pending.find(10)
	return latest
