extends RefCounted
class_name LifeJobs


func on_spin(rules, spinner: Dictionary, raw: int, movement: bool) -> bool:
	if bool(spinner.out):
		return false
	rules.dying.clear()
	_gifts(rules, spinner, raw)
	_specials(rules, spinner, raw)
	if movement and _dead(spinner):
		rules.note("spin", spinner, "The spin ends the move")
		return false
	return not _dead(spinner)


func _gifts(rules, spinner: Dictionary, raw: int) -> void:
	for other in rules.players:
		if bool(other.out) or other.career == null:
			continue
		var card: Dictionary = other.career
		if int(card.get("bonus", -1)) != raw:
			continue
		if int(card.get("gift", 0)) <= 0:
			continue
		rules.pay_other(spinner, other, 20, "bonus")


func _specials(rules, spinner: Dictionary, raw: int) -> void:
	for other in rules.players:
		if bool(other.out) or other.career == null:
			continue
		var card: Dictionary = other.career
		if int(card.get("bonus", -1)) != raw:
			continue
		match str(card.get("special", "")):
			"carpenter":
				rules.grant(other, 200, "hit song")
			"draymond":
				rules.pay_other(spinner, other, 200, "headlock")
			"thief":
				rules.pay_other(spinner, other, 200, "stolen")
			"assassin":
				_assassin(rules, spinner)
			"bee":
				_bee(rules, spinner, other)
	if _job_id(spinner) == "race_car_driver" and (raw == 9 or raw == 10):
		rules.queue_death(spinner, "death_return")
	_mirrors(rules)


func _assassin(rules, spinner: Dictionary) -> void:
	if bool(spinner.star_immune):
		return
	if _job_id(spinner) == "singer":
		var hits := int(spinner.assassin_hits)
		if hits <= 0:
			spinner.assassin_hits = 1
			spinner.silent = true
			rules.note("status", spinner, "The Singer goes quiet")
		elif hits == 1:
			spinner.assassin_hits = 2
			spinner.silent = false
			rules.note("status", spinner, "The Singer's voice returns")
		return
	rules.queue_death(spinner, "death_return")


func _bee(rules, spinner: Dictionary, keeper: Dictionary) -> void:
	rules.grant(keeper, 1000, "beekeeper")
	rules.queue_death(spinner, "snake_return")


func _mirrors(rules) -> void:
	var doomed: Array = rules.dying.duplicate()
	for hit in doomed:
		var kind := str(hit.get("kind", ""))
		for other in rules.players:
			if _job_id(other) != "lifeguard":
				continue
			if int(other.i) == int(hit.get("player", -1)):
				continue
			if bool(other.out) or other.purgatory != null:
				continue
			if bool(other.star_immune):
				continue
			var mirror := "death_return" if kind == "snakebite" else kind
			rules.queue_death(other, mirror)


func _job_id(me: Dictionary) -> String:
	if me.career == null:
		return ""
	return str(me.career.get("id", ""))


func _dead(me: Dictionary) -> bool:
	return bool(me.out) or me.purgatory != null
