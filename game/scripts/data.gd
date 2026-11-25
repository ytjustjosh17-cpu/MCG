class_name Data
extends RefCounted
## All game content and tuning numbers live here.
## Every name is made up.

const MAX_STAGE := 10
const UNITS_PER_STAGE := 5
const UNIT_PRICE_GROWTH := 1.13
const OFFLINE_CAP_H := 8.0
const MAX_LEVEL := 25
const SELL_TAX := 0.12
const ITEM_RESALE := 0.8

# ---- businesses --------------------------------------------------------
# cost: opening price. unit: what you buy to grow it. unit_cost/unit_income
# are for the first unit at stage 1. stage_mult multiplies all unit income
# per stage. exp_cost: first expansion price (x exp_growth per stage).
# exp_min: first expansion time in minutes (x2 per stage, capped).
const BUSINESSES := [
	{"id": "shop", "name": "Shop", "kind": "shop", "cost": 1999.0, "unit": "outlet", "units": "outlets",
		"unit_cost": 900.0, "unit_income": 55.0, "stage_mult": 1.45, "exp_cost": 8000.0, "exp_growth": 3.3, "exp_min": 2.0,
		"names": ["Kettle & Co.", "Corner Larder", "Ellis Goods", "Northgate Store"]},
	{"id": "taxi", "name": "Taxi company", "kind": "taxi", "cost": 9999.0, "unit": "car", "units": "cars",
		"unit_cost": 3200.0, "unit_income": 180.0, "stage_mult": 1.45, "exp_cost": 25000.0, "exp_growth": 3.3, "exp_min": 3.0,
		"names": ["Halden Taxis", "Ringway Cabs", "Lamplight Cars", "Quay Street Taxis"]},
	{"id": "shipping", "name": "Shipping company", "kind": "ship", "cost": 19899.0, "unit": "lorry", "units": "lorries",
		"unit_cost": 7000.0, "unit_income": 360.0, "stage_mult": 1.45, "exp_cost": 60000.0, "exp_growth": 3.3, "exp_min": 5.0,
		"names": ["Port Ellis Freight", "Saltmarsh Haulage", "Brakewater Lines"]},
	{"id": "factory", "name": "Factory", "kind": "factory", "cost": 24999.0, "unit": "line", "units": "lines",
		"unit_cost": 9000.0, "unit_income": 430.0, "stage_mult": 1.45, "exp_cost": 80000.0, "exp_growth": 3.3, "exp_min": 6.0,
		"names": ["Ironmere Works", "Coldharbour Mills", "Redstack Foundry"]},
	{"id": "construction", "name": "Construction", "kind": "crane", "cost": 35400.0, "unit": "crew", "units": "crews",
		"unit_cost": 13000.0, "unit_income": 600.0, "stage_mult": 1.45, "exp_cost": 120000.0, "exp_growth": 3.3, "exp_min": 8.0,
		"names": ["Granite & Vale", "Hollow Oak Build", "Steelyard Construction"]},
	{"id": "dealer", "name": "Car dealer", "kind": "dealer", "cost": 40000.0, "unit": "showroom", "units": "showrooms",
		"unit_cost": 15000.0, "unit_income": 680.0, "stage_mult": 1.45, "exp_cost": 140000.0, "exp_growth": 3.3, "exp_min": 10.0,
		"names": ["Marlow Motors", "Brisk Autos", "Velle Showrooms"]},
	{"id": "it", "name": "IT company", "kind": "screen", "cost": 350000.0, "unit": "team", "units": "teams",
		"unit_cost": 120000.0, "unit_income": 4800.0, "stage_mult": 1.45, "exp_cost": 1.2e6, "exp_growth": 3.3, "exp_min": 15.0,
		"names": ["Lumen Systems", "Quillsoft", "Northlight Code"]},
	{"id": "bank", "name": "Bank", "kind": "bank", "cost": 1.0e7, "unit": "branch", "units": "branches",
		"unit_cost": 3.5e6, "unit_income": 120000.0, "stage_mult": 1.45, "exp_cost": 3.5e7, "exp_growth": 3.0, "exp_min": 25.0,
		"names": ["Ostrava Bank", "Hearth & Crown Bank", "Meridian Savings"]},
	{"id": "sports", "name": "Sports club", "kind": "stadium", "cost": 4.0e7, "unit": "player", "units": "players",
		"unit_cost": 1.4e7, "unit_income": 440000.0, "stage_mult": 1.45, "exp_cost": 1.4e8, "exp_growth": 2.9, "exp_min": 35.0,
		"names": ["Port Ellis Athletic", "Redmoor Rovers", "Halcyon United"]},
	{"id": "oil", "name": "Oil and gas", "kind": "rig", "cost": 1.5e9, "unit": "rig", "units": "rigs",
		"unit_cost": 5.0e8, "unit_income": 1.4e7, "stage_mult": 1.45, "exp_cost": 5.0e9, "exp_growth": 2.8, "exp_min": 50.0,
		"names": ["Norvale Energy", "Deepwell Petroleum", "Black Tern Oil"]},
	{"id": "airline", "name": "Airline", "kind": "plane", "cost": 1.3e10, "unit": "plane", "units": "planes",
		"unit_cost": 4.5e9, "unit_income": 1.1e8, "stage_mult": 1.45, "exp_cost": 4.5e10, "exp_growth": 2.6, "exp_min": 70.0,
		"names": ["Red Sun Air", "Kestrel Airways", "Highline Air"]},
]

# ---- shares -------------------------------------------------------------
# price, yearly-ish dividend shown as %; div_h is the share of price paid per hour.
const STOCKS := [
	# symbol, name, price, dividend, sector
	["NRV", "Norvale Energy", 75.32, 0.0061, "Energy"], ["OSB", "Ostrava Bank", 41.08, 0.0054, "Finance"],
	["QLM", "Quillon Motors", 92.37, 0.0048, "Transport"], ["BWM", "Brightwave Media", 367.23, 0.0039, "Tech"],
	["LMG", "Lumen Grid", 113.53, 0.0032, "Energy"], ["HCF", "Halcyon Foods", 55.46, 0.0029, "Food"],
	["KST", "Kestrel Air", 28.10, 0.0044, "Transport"], ["MRL", "Marlow Retail", 19.84, 0.0051, "Retail"],
	["DPW", "Deepwell Oil", 61.70, 0.0058, "Energy"], ["GVL", "Granite & Vale", 143.20, 0.0035, "Industry"],
	["QSF", "Quillsoft", 612.40, 0.0018, "Tech"], ["NLC", "Northlight", 288.90, 0.0022, "Tech"],
	["IRM", "Ironmere", 37.55, 0.0047, "Industry"], ["SLT", "Saltmarsh", 12.30, 0.0063, "Transport"],
	["HRC", "Hearth & Crown", 88.10, 0.0041, "Finance"], ["MRD", "Meridian", 204.60, 0.0027, "Finance"],
	["RDR", "Redmoor Group", 9.45, 0.0069, "Retail"], ["CLH", "Coldharbour", 51.20, 0.0038, "Industry"],
	["VLL", "Velle Auto", 176.30, 0.0030, "Transport"], ["BTN", "Black Tern", 33.80, 0.0055, "Energy"],
	["LDF", "Larder Foods", 24.60, 0.0046, "Food"], ["TFS", "Tern Fisheries", 14.85, 0.0052, "Food"],
]
const STOCK_DIV_SCALE := 0.006  # dividend per hour = price * div * scale
const SECTORS := ["Energy", "Finance", "Tech", "Transport", "Retail", "Food", "Industry"]
const SECTOR_VOL := {"Energy": 0.007, "Finance": 0.005, "Tech": 0.009, "Transport": 0.006,
	"Retail": 0.006, "Food": 0.004, "Industry": 0.005}
const STOCK_GROWTH := 0.000004  # slow long-run rise per minute

# ---- crypto ------------------------------------------------------------
# symbol, name, price, volatility per minute, staking reward per hour
const COINS := [
	["KRV", "Korva coin", 115.23, 0.012, 0.0004], ["LMN", "Lumen token", 2.41, 0.018, 0.0008],
	["ASH", "Ashcoin", 0.083, 0.025, 0.0012], ["MRC", "Meridian coin", 41000.0, 0.008, 0.0002],
	["TDE", "Tide", 9.12, 0.015, 0.0006], ["EMB", "Ember", 0.0042, 0.03, 0.0015],
	["NVA", "Nova", 1.84, 0.02, 0.001], ["PBL", "Pebble", 0.31, 0.022, 0.001],
	["GLT", "Glint", 640.0, 0.012, 0.0005], ["DRF", "Drift", 0.0009, 0.035, 0.002],
]
const STAKE_LOCK_H := 24.0

# ---- market news ---------------------------------------------------------
const NEWS_STOCK_UP := ["%s wins a big contract", "%s profits beat forecasts", "%s reports record sales", "%s expands overseas"]
const NEWS_STOCK_DOWN := ["%s misses its targets", "%s faces an inquiry", "%s recalls products", "%s boss resigns"]
const NEWS_SECTOR_UP := ["%s shares rally", "Strong week for %s"]
const NEWS_SECTOR_DOWN := ["%s sell-off", "%s shares slide"]
const NEWS_COIN_UP := ["%s soars as big buyers move in", "%s listed on a major exchange"]
const NEWS_COIN_DOWN := ["%s crashes after a hack", "%s whales sell off"]
const NEWS_EVERY_MIN := 45.0  # average minutes between news

# ---- property ----------------------------------------------------------
# name, place, price, kind (house/flats/tower/resort)
const PROPERTIES := [
	["Back Row Terrace", "Port Ellis", 25000.0, "house"], ["Millbrook Cottage", "Saltmarsh", 32000.0, "house"],
	["Quay View Flat", "Port Ellis", 65000.0, "flats"], ["Larch House", "Redmoor", 140000.0, "house"],
	["Station Lofts", "Ironmere", 380000.0, "flats"],
	["The Granary", "Coldharbour", 1.2e6, "flats"], ["Cliff Top Villa", "Saltmarsh", 2.6e6, "house"],
	["Northgate Offices", "Ironmere", 5.4e6, "tower"], ["Harbour Row", "Port Ellis", 9.78e6, "flats"], ["Meridian Hotel", "Redmoor", 2.2e7, "tower"],
	["Kestrel Point", "Port Ellis", 4.8e7, "tower"], ["Halcyon Resort", "Black Tern Isle", 1.1e8, "resort"],
	["Granite Plaza", "Ironmere", 2.6e8, "tower"], ["Red Sun Tower", "Port Ellis", 6.0e8, "tower"],
	["Lantern Bay Resort", "Tern Islands", 1.4e9, "resort"], ["Skyline One", "Redmoor", 3.2e9, "tower"],
	["Ellis Arena", "Port Ellis", 7.5e9, "tower"], ["Sunken Garden Isle", "Tern Islands", 1.2e10, "resort"],
	["The Spire", "Port Ellis", 2.0e10, "tower"], ["Crown Sphere", "Redmoor", 2.8e10, "tower"],
]
const RENT_PER_H := 0.022  # share of price paid as rent each hour
const IMPROVEMENTS := [
	["Fresh paint", 0.04, 0.10], ["New kitchens", 0.08, 0.15], ["Fast internet", 0.03, 0.08],
	["Parking", 0.06, 0.12], ["Rooftop garden", 0.12, 0.20],
]  # name, cost as share of price, extra rent share

# ---- homes -------------------------------------------------------------
# Where you live. Moving up is a big one-off cost; each home adds a little
# to all income for good. Index 0 is where everyone starts.
const HOMES := [ # name, place, price, scene
	["Rented room", "Ironmere", 0.0, "flats"],
	["Studio flat", "Port Ellis", 15000.0, "flats"],
	["Terrace house", "Saltmarsh", 120000.0, "house"],
	["Town house", "Redmoor", 900000.0, "house"],
	["Harbour penthouse", "Port Ellis", 8.0e6, "tower"],
	["Cliff villa", "Saltmarsh", 9.0e7, "house"],
	["Country estate", "Coldharbour", 1.2e9, "house"],
	["Sky mansion", "Redmoor", 1.8e10, "tower"],
	["Island palace", "Tern Islands", 3.0e11, "resort"],
]
const HOME_BONUS := 0.01  # extra income per step up (kept small on purpose)

# ---- collections -------------------------------------------------------
const COLLECTIONS := [
	{"id": "watches", "name": "Watches", "bonus": 0.05, "items": [
		["Fenwick Field", 8000.0], ["Glaskov Pilot", 26000.0], ["Morrow Diver", 90000.0],
		["Voss Moonphase", 300000.0], ["Atelier Tourbillon", 1.1e6], ["Red Sun No. 1", 4.0e6]]},
	{"id": "art", "name": "Paintings", "bonus": 0.05, "items": [
		["Harbour at Dusk", 60000.0], ["Two Cranes", 240000.0], ["Ironmere Smoke", 900000.0],
		["The Long Quay", 3.5e6], ["Red Sun Rising", 1.3e7], ["Portrait in Teal", 5.0e7]]},
	{"id": "cars", "name": "Classic cars", "bonus": 0.05, "items": [
		["Rook Roadster", 180000.0], ["Velle GT 66", 520000.0], ["Marlow Sport", 1.6e6],
		["Brisk Spyder", 5.0e6], ["Kestrel Coupe", 1.6e7], ["The Lamplight", 5.0e7]]},
	{"id": "jets", "name": "Private jets", "bonus": 0.08, "items": [
		["Tern 4", 4.0e6], ["Highline 7", 1.2e7], ["Kestrel Lark", 3.5e7],
		["Meridian 9", 1.1e8], ["Red Sun One", 3.5e8], ["Long Range X", 1.0e9]]},
	{"id": "yachts", "name": "Yachts", "bonus": 0.08, "items": [
		["Saltmarsh 40", 9.0e6], ["Black Tern", 3.0e7], ["Quay Queen", 9.0e7],
		["Lantern", 3.0e8], ["Harbour Light", 9.0e8], ["Red Sun", 3.0e9]]},
	{"id": "islands", "name": "Islands", "bonus": 0.12, "items": [
		["Gull Rock", 8.0e7], ["Little Tern", 2.5e8], ["Ash Key", 8.0e8],
		["Lantern Isle", 2.5e9], ["Sunken Garden", 8.0e9], ["Crown Isle", 2.5e10]]},
]

# ---- mergers -----------------------------------------------------------
# needs: list of [type, a, b]: ["biz", id, min_stage] | ["props", count] |
# ["shares", value] | ["crypto", value] | ["collection", id] | ["mergers", count]
const MERGERS := [
	{"id": "retail", "name": "Retail Group", "cost": 6.0e+06, "boost": ["shop", "dealer", "factory"], "mult": 1.5,
		"needs": [["biz", "shop", 5], ["biz", "dealer", 3], ["biz", "factory", 3]]},
	{"id": "transit", "name": "Transit Group", "cost": 7.5e+07, "boost": ["taxi", "shipping"], "mult": 1.5,
		"needs": [["biz", "taxi", 5], ["biz", "shipping", 5], ["props", 5]]},
	{"id": "build", "name": "Build Corp", "cost": 7.5e+08, "boost": ["construction", "factory"], "mult": 1.5,
		"needs": [["biz", "construction", 6], ["biz", "factory", 6], ["props", 8]]},
	{"id": "tech", "name": "Coin Exchange", "cost": 4.5e+09, "boost": ["it", "bank"], "mult": 1.5,
		"needs": [["biz", "it", 5], ["crypto", 5.0e7], ["shares", 1.0e8]]},
	{"id": "skysea", "name": "Sky & Sea", "cost": 1.5e+11, "boost": ["airline", "shipping", "oil"], "mult": 1.5,
		"needs": [["biz", "airline", 3], ["biz", "shipping", 8], ["collection", "yachts"]]},
	{"id": "holding", "name": "Sol Holdings", "cost": 7.5e+11, "boost": [], "mult": 2.0,
		"needs": [["biz", "bank", 8], ["biz", "oil", 5], ["shares", 1.0e10], ["mergers", 5]]},
]

# ---- tapping -----------------------------------------------------------
static func tap_base(level: int) -> float:
	return 2.5 * pow(1.64, level - 1)


static func level_cost(level: int) -> float:
	## Price to go from `level` to `level + 1`.
	return 1000.0 * pow(3.4, level - 1)


static func expansion_minutes(b: Dictionary, stage: int) -> float:
	## Real time for expanding from `stage` to `stage + 1`.
	return minf(float(b["exp_min"]) * 2.0 * pow(2.0, stage - 1), 48.0 * 60.0)


static func expansion_cost(b: Dictionary, stage: int) -> float:
	return float(b["exp_cost"]) * pow(float(b["exp_growth"]), stage - 1)


static func unit_price(b: Dictionary, owned_units: int) -> float:
	return float(b["unit_cost"]) * pow(UNIT_PRICE_GROWTH, owned_units)


static func business(id: String) -> Dictionary:
	for b in BUSINESSES:
		if b["id"] == id:
			return b
	return {}
