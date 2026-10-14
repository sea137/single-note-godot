extends Control

var points: Array = []
var chart_font: Font

func _ready():
	custom_minimum_size = Vector2(0,220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw():
	if points.is_empty() or not chart_font: return
	var left = 42.0
	var right = maxf(left+20,size.x-12)
	var top = 18.0
	var bottom = size.y-36
	for value in [0,25,50,75,100]:
		var y = bottom-(bottom-top)*value/100.0
		draw_line(Vector2(left,y),Vector2(right,y),Color("e0e5d9"),1)
		draw_string(chart_font,Vector2(0,y+5),str(value)+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("778078"))
	var previous = Vector2.ZERO
	for i in points.size():
		var x = (left+right)/2 if points.size() == 1 else lerpf(left,right,float(i)/(points.size()-1))
		var pos = Vector2(x,bottom-(bottom-top)*clampf(float(points[i].rate),0,100)/100)
		if i > 0: draw_line(previous,pos,Color("284e3e"),3,true)
		draw_circle(pos,4,Color("284e3e"))
		previous = pos
	draw_string(chart_font,Vector2(left,size.y-10),"1",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("778078"))
	if points.size() > 1: draw_string(chart_font,Vector2(right-16,size.y-10),str(points.size()),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("778078"))
