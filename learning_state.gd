extends RefCounted

# Initial product heuristics, not a calibrated or universal forgetting curve.
const DAY = 86400
const INTERVALS = [DAY, 3 * DAY, 7 * DAY, 14 * DAY, 30 * DAY]
var items: Dictionary = {}

func record(key: String, correct: bool, assisted: bool, guess: String, now: int):
	var item = items.get(key, {"stage":0,"due_at":0,"attempts":0,"correct":0,"blind_attempts":0,"blind_correct":0,"confusions":{},"last_review":0})
	var early = int(item.get("last_review",0)) > 0 and now < int(item.get("due_at",0))
	item.attempts = int(item.get("attempts",0)) + 1
	if correct: item.correct = int(item.get("correct",0)) + 1
	if not assisted:
		item.blind_attempts = int(item.get("blind_attempts",0)) + 1
		if correct: item.blind_correct = int(item.get("blind_correct",0)) + 1
	if not correct:
		item.stage = 0
		item.due_at = now + 600
		if guess != "":
			var confusions = item.get("confusions", {})
			confusions[guess] = int(confusions.get(guess,0)) + 1
			item.confusions = confusions
	elif assisted:
		item.due_at = mini(int(item.due_at), now + 3600) if int(item.due_at) > now else now + 3600
	elif not early:
		var stage = clampi(int(item.get("stage",0)),0,INTERVALS.size()-1)
		item.due_at = now + INTERVALS[stage]
		item.stage = mini(stage + 1, INTERVALS.size()-1)
	item.last_review = now
	items[key] = item

func due_keys(now: int) -> Array:
	var due: Array = []
	for key in items:
		if int(items[key].get("due_at",0)) <= now: due.append(key)
	due.sort_custom(func(a,b): return int(items[a].get("due_at",0)) < int(items[b].get("due_at",0)))
	return due

func import_items(saved):
	items.clear()
	if not saved is Dictionary: return
	for key in saved:
		if not key is String or not saved[key] is Dictionary: continue
		var note = key.left(key.length()-1)
		if note not in ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"] or key.right(1) not in ["3","4","5"]: continue
		var value = saved[key].duplicate(true)
		value.stage = clampi(int(value.get("stage",0)),0,INTERVALS.size()-1)
		value.due_at = maxi(0,int(value.get("due_at",0)))
		for counter in ["attempts","correct","blind_attempts","blind_correct","last_review"]: value[counter] = maxi(0,int(value.get(counter,0)))
		value.confusions = value.get("confusions",{}) if value.get("confusions",{}) is Dictionary else {}
		for guess in value.confusions: value.confusions[guess] = maxi(0,int(value.confusions[guess]))
		items[key] = value
