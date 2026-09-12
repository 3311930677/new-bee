extends Node
class_name RankingInfoManage


signal load_rank_data_success

var NetContext

func _init() -> void :
	NetContext = Global.get("NetContext")
	NetContext.set_handler("RankingRoleRemote", "getRankInfo", self, "_on_load_ranking_info_success")
	pass


func request_rank(type):
	NetContext.request_service("RankingRoleRemote", "getRankInfo", {
		"type": type
	}, true)
	pass


func _on_load_ranking_info_success(data):
	data = data["data"]
	emit_signal("load_rank_data_success", data)
	pass
