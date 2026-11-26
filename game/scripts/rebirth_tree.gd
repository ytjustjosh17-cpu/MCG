class_name RebirthTree
extends RefCounted
## The RBP tree: a centre ("Sol"), an inner ring of eight gates, eight
## branches that fork into two arms each, and bridges between neighbouring
## branches. Every node has a fixed string id (saves store ids, so the tree
## can be retuned later without breaking them). Built once, then cached.
##
## Node: {id, name, kind ("core", "small", "notable", "key"), branch, x, y,
##        fx: {stat: amount}, cost: int, links: [ids], icon}
## Stats (all added together per stat, see Game.rb()):
##   income   company income (+0.05 = +5%)      rent   property rent
##   div      dividends                          all    companies, rent, dividends
##   mine     mining value                       stake  locked-coin rate
##   tap      tap value                          crit   big-tap chance (+0.01 = +1 point)
##   critx    big taps pay ×10 instead of ×5     away   hours more while away
##   speed    expansions quicker (0.03 = 3%)     sun    golden suns a day
##   start    cash at the start of a new run     level  starting level
##   mgr0     managers take nothing              rbp    more RBP per rebirth
##   deals    deals come sooner                  casino higher casino limits

const STEP := 92.0          # distance between rings, in tree pixels
const COST_BASE := 3.0
const COST_GROWTH := 1.32

# id prefix, name, icon, small effect, notable effect, two keystones
const BRANCHES := [
	["emp", "Empire", "business", {"income": 0.06}, {"income": 0.3},
		[["Iron empire", {"income": 1.0}], ["Loyal staff", {"mgr0": 1.0}]]],
	["hand", "Hands", "earn", {"tap": 0.12}, {"crit": 0.01},
		[["Thunder taps", {"critx": 1.0}], ["Golden hands", {"tap": 1.5}]]],
	["est", "Estates", "home", {"rent": 0.08}, {"rent": 0.35},
		[["Landlord", {"rent": 1.2}], ["Skyline", {"all": 0.15}]]],
	["mkt", "Markets", "invest", {"div": 0.08}, {"stake": 0.25},
		[["Blue chips", {"div": 1.2}], ["Vault keys", {"stake": 0.6}]]],
	["dig", "Mining", "cpu", {"mine": 0.08}, {"mine": 0.35},
		[["Deep shafts", {"mine": 1.2}], ["Second sun", {"sun": 1.0}]]],
	["time", "Time", "clock", {"away": 0.25}, {"speed": 0.06},
		[["Long nights", {"away": 4.0}], ["Fast crews", {"speed": 0.15}]]],
	["start", "Head start", "bolt", {"start": 1.0}, {"level": 3.0},
		[["Old money", {"start": 4.0}], ["Born ready", {"level": 10.0}]]],
	["soul", "Rebirth", "sparkle", {"rbp": 0.03}, {"deals": 0.1},
		[["Reborn", {"rbp": 0.2}], ["High roller", {"casino": 1.0}]]],
]

# Unlock nodes open new parts of the game. They sit between two branches,
# linked to both gates, so even a first rebirth can reach one.
# id, name, slot (between branch i and i+1), cost, stat, icon
const UNLOCKS := [
	["u_casino", "Sol Casino", 0, 6, "u_casino", "coins"],
	["u_tables", "High tables", 4, 20, "u_tables", "diamond"],
	["u_frontier", "Frontier", 7, 60, "u_frontier", "gauge"],
	["u_isles", "Island estates", 2, 45, "u_isles", "home"],
	["u_relics", "Relic hunters", 5, 50, "u_relics", "crown"],
]

# "start" amounts: each step of `start` is worth more than the last, so the
# head start keeps mattering in later runs. start total -> cash.
static func start_cash(total: float) -> float:
	if total <= 0.0:
		return 0.0
	return 2.0e4 * pow(2.5, total - 1.0)

static var _nodes: Array = []
static var _by_id: Dictionary = {}


static func nodes() -> Array:
	if _nodes.is_empty():
		_build()
	return _nodes


static func node(id: String) -> Dictionary:
	if _nodes.is_empty():
		_build()
	return _by_id.get(id, {})


static func _cost(depth: int, kind: String) -> int:
	var c := COST_BASE * pow(COST_GROWTH, float(depth - 1))
	if kind == "notable":
		c *= 2.0
	elif kind == "key":
		c *= 4.0
	return maxi(1, int(round(c)))


static func _add(id: String, name: String, kind: String, branch: String, pos: Vector2, fx: Dictionary, depth: int, icon: String) -> void:
	var n := {"id": id, "name": name, "kind": kind, "branch": branch, "x": pos.x, "y": pos.y,
		"fx": fx, "cost": 0 if kind == "core" else _cost(depth, kind), "links": [], "icon": icon, "depth": depth}
	_nodes.append(n)
	_by_id[id] = n


static func _link(a: String, b: String) -> void:
	(_by_id[a]["links"] as Array).append(b)
	(_by_id[b]["links"] as Array).append(a)


static func _polar(r: float, ang: float) -> Vector2:
	return Vector2(cos(ang), sin(ang)) * r


static func _build() -> void:
	_nodes = []
	_by_id = {}
	_add("core", "Sol", "core", "", Vector2.ZERO, {}, 0, "sun")
	var n_b := BRANCHES.size()
	for bi in range(n_b):
		var br: Array = BRANCHES[bi]
		var p: String = br[0]
		var bname: String = br[1]
		var icon: String = br[2]
		var ang := -PI / 2.0 + TAU * float(bi) / float(n_b)
		# Gate on the inner ring.
		_add(p + "_g", bname + " gate", "small", p, _polar(STEP * 1.6, ang), br[3], 1, icon)
		_link("core", p + "_g")
		# Trunk: five steps out, the middle one is notable.
		var prev := p + "_g"
		for k in range(1, 6):
			var id := "%s_t%d" % [p, k]
			var notable := k == 3
			_add(id, bname + (" focus" if notable else " " + str(k)), "notable" if notable else "small", p,
				_polar(STEP * (1.6 + float(k)), ang), br[4] if notable else br[3], 1 + k, icon)
			_link(prev, id)
			prev = id
		# Two arms of six, bending away from each other; ending in keystones.
		for arm in range(2):
			var side := -1.0 if arm == 0 else 1.0
			var aprev := p + "_t5"
			for k in range(1, 7):
				var id := "%s_%s%d" % [p, "a" if arm == 0 else "b", k]
				var r := STEP * (6.6 + float(k) * 0.92)
				var spread := side * (0.07 + 0.045 * float(k))
				var kind := "key" if k == 6 else ("notable" if k == 3 else "small")
				var nm := bname + " " + str(5 + k)
				var fx: Dictionary = br[3]
				if kind == "notable":
					nm = bname + (" mastery" if arm == 0 else " insight")
					fx = br[4]
				elif kind == "key":
					nm = String(br[5][arm][0])
					fx = br[5][arm][1]
				_add(id, nm, kind, p, _polar(r, ang + spread), fx, 6 + k, icon)
				_link(aprev, id)
				aprev = id
	# Inner ring: neighbouring gates link, so you can walk around the centre.
	for bi in range(n_b):
		var a: String = BRANCHES[bi][0] + "_g"
		var b: String = BRANCHES[(bi + 1) % n_b][0] + "_g"
		_link(a, b)
	# Unlocks: between two gates, a little further out.
	for u in UNLOCKS:
		var slot: int = u[2]
		var ang := -PI / 2.0 + TAU * (float(slot) + 0.5) / float(n_b)
		_add(String(u[0]), String(u[1]), "unlock", "unlock", _polar(STEP * 2.3, ang), {String(u[4]): 1.0}, 2, String(u[5]))
		_by_id[u[0]]["cost"] = int(u[3])
		_link(String(BRANCHES[slot][0]) + "_g", String(u[0]))
		_link(String(u[0]), String(BRANCHES[(slot + 1) % n_b][0]) + "_g")
	# Bridges between neighbouring trunks (+3% to companies, rent, dividends).
	for bi in range(n_b):
		var pa: String = BRANCHES[bi][0]
		var pb: String = BRANCHES[(bi + 1) % n_b][0]
		var ang := -PI / 2.0 + TAU * (float(bi) + 0.5) / float(n_b)
		var id := "bridge_%d" % bi
		_add(id, "Crossroads", "small", "bridge", _polar(STEP * 4.9, ang), {"all": 0.03}, 5, "plus")
		_link(pa + "_t3", id)
		_link(id, pb + "_t3")


static func describe(fx: Dictionary) -> String:
	## Plain words for what a node gives.
	var parts: Array = []
	for k in fx.keys():
		var v := float(fx[k])
		match k:
			"income": parts.append("Company income +%d%%" % int(round(v * 100.0)))
			"rent": parts.append("Rent +%d%%" % int(round(v * 100.0)))
			"div": parts.append("Dividends +%d%%" % int(round(v * 100.0)))
			"all": parts.append("Companies, rent and dividends +%d%%" % int(round(v * 100.0)))
			"mine": parts.append("Mining +%d%%" % int(round(v * 100.0)))
			"stake": parts.append("Locked coins earn +%d%%" % int(round(v * 100.0)))
			"tap": parts.append("Taps +%d%%" % int(round(v * 100.0)))
			"crit": parts.append("Big tap chance +%d point%s" % [int(round(v * 100.0)), "" if int(round(v * 100.0)) == 1 else "s"])
			"critx": parts.append("Big taps pay ×10 instead of ×5")
			"away": parts.append("Earn while away +%s h" % str(snappedf(v, 0.25)))
			"speed": parts.append("Expansions %d%% quicker" % int(round(v * 100.0)))
			"sun": parts.append("One more golden sun a day")
			"start": parts.append("Start each new run with more cash")
			"level": parts.append("Start each new run at level %d" % (1 + int(v)))
			"mgr0": parts.append("Managers take no cut")
			"rbp": parts.append("RBP from rebirths +%d%%" % int(round(v * 100.0)))
			"deals": parts.append("Deals come %d%% sooner" % int(round(v * 100.0)))
			"casino": parts.append("Casino limits doubled")
			"u_casino": parts.append("Opens Sol Casino: three slot machines, with chips you buy and cash out")
			"u_tables": parts.append("Opens the casino tables: roulette and blackjack (needs Sol Casino)")
			"u_frontier": parts.append("Two new top companies: Fusion plant and Orbital yards")
			"u_isles": parts.append("Three new properties: a lighthouse, an observatory and a skyport")
			"u_relics": parts.append("A new collection: six relics, +8% income when complete")
	return ", ".join(parts)
