extends Node



var click_node;
var click_m;

func set_text(text):
	$Cancle.text = text
	

func set_click_handler(click_node, click_m):
	self.click_node = click_node
	self.click_m = click_m
	

func _on_Cancle_pressed():
	if (click_node != null):
		click_node.call(click_m)
