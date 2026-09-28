class_name PageSettings
extends MenuPage
## Settings page hosting the shared settings panel.

var _panel: SettingsPanel


func _ready() -> void:
	_panel = SettingsPanel.new()
	add_child(_panel)
	_panel.closed.connect(func(): menu.back())


func handle_back() -> bool:
	# The panel handles ui_back itself (it may be capturing a key).
	return true
