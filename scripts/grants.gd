class_name Grants
extends RefCounted
## Grant offers the player can accept: each has a goal, a deadline and a payout.

var g
var rng := RandomNumberGenerator.new()
var offers: Array = []
var active: Array = []
var completed := 0
const MAX_ACTIVE := 3


func _init(game) -> void:
	g = game
	rng.seed = game.rng.randi()
	offers.append(_make("trails"))
	offers.append(_make("education"))


func _make(kind: String) -> Dictionary:
	var gr := {kind = kind, title = "", desc = "", reward = 0, days = 8, expires = g.day + 6, deadline = 0, streak = 0, target = 0.0, sp = -1}
	match kind:
		"trails":
			gr.target = g.world.trail_tiles.size() + 30
			gr.title = "Trail Access Grant"
			gr.desc = "Build 30 more tiles of trail (reach %d)." % int(gr.target)
			gr.reward = 2500
		"education":
			gr.target = g.total_visitors + 200
			gr.title = "Outdoor Education Fund"
			gr.desc = "Have a Visitor Center and welcome 200 more visitors."
			gr.reward = 3500
			gr.days = 9
		"eco":
			gr.title = "Biodiversity Stewardship Award"
			gr.desc = "Keep ecosystem health at 80% or above for 5 days in a row."
			gr.reward = 5000
			gr.days = 10
		"invasive":
			gr.title = "Invasive Species Control Grant"
			gr.desc = "Clear every invasive species tile from the park."
			gr.reward = 3000
		"safety":
			gr.title = "Visitor Safety Initiative"
			gr.desc = "Employ 2 rangers and go 6 days with no serious incident."
			gr.reward = 3500
			gr.days = 9
		"recovery":
			gr.title = "Species Recovery: %s" % D.SPECIES[gr.sp].name if gr.sp >= 0 else "Species Recovery"
			gr.reward = 6000
			gr.days = 14
		"research":
			gr.target = g.research_total + 50.0
			gr.title = "Field Research Fellowship"
			gr.desc = "Generate 50 research points."
			gr.reward = 3500
		"litter":
			gr.title = "Leave No Trace Challenge"
			gr.desc = "Welcome 60+ visitors in a day and end it with 3 or fewer littered tiles."
			gr.reward = 2000
			gr.days = 6
		"rating":
			gr.title = "Tourism Board Bonus"
			gr.desc = "Reach a 4-star visitor rating."
			gr.reward = 4000
			gr.days = 10
	return gr


func _random_offer() -> Dictionary:
	var kinds := ["trails", "eco", "safety", "research", "litter"]
	if g.world.invasive_tiles.size() > 3: kinds.append("invasive")
	if g.stars < 3.8: kinds.append("rating")
	if g.world.count_kind(D.B.VISITOR_CENTER) > 0: kinds.append("education")
	var weak := -1
	for i in D.SPECIES.size():
		if g.eco.ratio(i) < 0.75 and g.eco.pops[i] >= 1.0:
			weak = i
	if weak >= 0:
		kinds.append("recovery")
		kinds.append("recovery")
	for attempt in 8:
		var kind: String = kinds[rng.randi() % kinds.size()]
		var dup := false
		for o in offers + active:
			if o.kind == kind:
				dup = true
		if dup:
			continue
		var gr := _make(kind)
		if kind == "recovery":
			gr.sp = weak
			gr.title = "Species Recovery: %s" % D.SPECIES[weak].name
			gr.desc = "Restore the %s population to 90%% of its natural level." % D.SPECIES[weak].name.to_lower()
		return gr
	return {}


func accept(i: int) -> void:
	if i < 0 or i >= offers.size() or active.size() >= MAX_ACTIVE:
		return
	var gr: Dictionary = offers[i]
	offers.remove_at(i)
	gr.deadline = g.day + int(gr.days)
	# re-base targets at acceptance so progress starts from now
	match gr.kind:
		"trails": gr.target = g.world.trail_tiles.size() + 30
		"education": gr.target = g.total_visitors + 200
		"research": gr.target = g.research_total + 50.0
	active.append(gr)
	g.say("Grant accepted: %s" % gr.title, "info")


func progress(gr: Dictionary) -> String:
	match gr.kind:
		"trails": return "%d / %d trail tiles" % [g.world.trail_tiles.size(), int(gr.target)]
		"education": return "%d visitors to go%s" % [maxi(0, int(gr.target) - g.total_visitors), "" if g.world.count_kind(D.B.VISITOR_CENTER) > 0 else " (no Visitor Center yet)"]
		"eco": return "%d / 5 days (health now %d%%)" % [gr.streak, int(g.eco.health)]
		"invasive": return "%d invasive tiles left" % g.world.invasive_tiles.size()
		"safety": return "%d / 6 safe days, %d / 2 rangers" % [gr.streak, g.staffing.count("ranger")]
		"recovery": return "Population at %d%%" % int(g.eco.ratio(gr.sp) * 100.0)
		"research": return "%d research points to go" % maxi(0, int(ceil(gr.target - g.research_total)))
		"litter": return "%d littered tiles, %d visitors yesterday" % [g.world.litter_tiles.size(), g.visitors_yesterday]
		"rating": return "Rating now %.1f stars" % g.stars
	return ""


func _met(gr: Dictionary) -> bool:
	match gr.kind:
		"trails": return g.world.trail_tiles.size() >= int(gr.target)
		"education": return g.total_visitors >= int(gr.target) and g.world.count_kind(D.B.VISITOR_CENTER) > 0
		"eco":
			gr.streak = gr.streak + 1 if g.eco.health >= 80.0 else 0
			return gr.streak >= 5
		"invasive": return g.world.invasive_tiles.is_empty()
		"safety":
			gr.streak = gr.streak + 1 if (g.last_serious_day < g.day - 1 and g.staffing.count("ranger") >= 2) else 0
			return gr.streak >= 6
		"recovery": return g.eco.ratio(gr.sp) >= 0.9
		"research": return g.research_total >= gr.target
		"litter": return g.visitors_yesterday >= 60 and g.world.litter_tiles.size() <= 3
		"rating": return g.stars >= 4.0
	return false


func daily() -> void:
	for gr in active.duplicate():
		if _met(gr):
			active.erase(gr)
			completed += 1
			g.add_money(gr.reward, "Grants")
			g.say("Grant completed: %s! You received %s." % [gr.title, D.money(gr.reward)], "good")
		elif g.day >= gr.deadline:
			active.erase(gr)
			g.say("Grant expired: %s." % gr.title, "warn")
	for o in offers.duplicate():
		if g.day >= o.expires:
			offers.erase(o)
	if offers.size() < 3 and (g.day % 2 == 0 or offers.is_empty()):
		var o := _random_offer()
		if not o.is_empty():
			offers.append(o)
			g.say("New grant available: %s (%s)." % [o.title, D.money(o.reward)], "info")
