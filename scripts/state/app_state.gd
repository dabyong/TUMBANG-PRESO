extends Node

enum AppMode { BOOT, MENU, MAP, DISCOVERY, DIFFICULTY, GAMEPLAY, FEEDBACK, VICTORY, FAILURE, RECOVERY_REQUIRED }

var mode: AppMode = AppMode.BOOT
var content_version := "foundation-1"
var offline_ready := false

func set_offline_ready(value: bool) -> void:
    offline_ready = value
    mode = AppMode.MENU if value else AppMode.RECOVERY_REQUIRED

