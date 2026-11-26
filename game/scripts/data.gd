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
	{"id": "food", "name": "Food trucks", "kind": "van", "cost": 4999.0, "unit": "truck", "units": "trucks",
		"unit_cost": 1900.0, "unit_income": 110.0, "stage_mult": 1.45, "exp_cost": 15000.0, "exp_growth": 3.3, "exp_min": 2.5,
		"names": ["Hatch & Ladle", "Kerbside Kitchen", "Low Tide Eats"]},
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
	{"id": "gym", "name": "Gym chain", "kind": "gym", "cost": 90000.0, "unit": "gym", "units": "gyms",
		"unit_cost": 32000.0, "unit_income": 1250.0, "stage_mult": 1.45, "exp_cost": 300000.0, "exp_growth": 3.3, "exp_min": 12.0,
		"names": ["Ironhall Fitness", "Pulse Yard", "Concrete Club"]},
	{"id": "it", "name": "IT company", "kind": "screen", "cost": 350000.0, "unit": "team", "units": "teams",
		"unit_cost": 120000.0, "unit_income": 4800.0, "stage_mult": 1.45, "exp_cost": 1.2e6, "exp_growth": 3.3, "exp_min": 15.0,
		"names": ["Lumen Systems", "Quillsoft", "Northlight Code"]},
	{"id": "hotel", "name": "Hotel", "kind": "hotel", "cost": 1.5e6, "unit": "floor", "units": "floors",
		"unit_cost": 5.2e5, "unit_income": 12000.0, "stage_mult": 1.45, "exp_cost": 5.0e6, "exp_growth": 3.2, "exp_min": 18.0,
		"names": ["The Brutal Grand", "Slate House Hotel", "Harbour Lights Inn"]},
	{"id": "tv", "name": "TV station", "kind": "mast", "cost": 4.0e6, "unit": "channel", "units": "channels",
		"unit_cost": 1.4e6, "unit_income": 32000.0, "stage_mult": 1.45, "exp_cost": 1.4e7, "exp_growth": 3.1, "exp_min": 22.0,
		"names": ["Signal Nine", "Redmast TV", "Northwave Broadcast"]},
	{"id": "bank", "name": "Bank", "kind": "bank", "cost": 1.0e7, "unit": "branch", "units": "branches",
		"unit_cost": 3.5e6, "unit_income": 120000.0, "stage_mult": 1.45, "exp_cost": 3.5e7, "exp_growth": 3.0, "exp_min": 25.0,
		"names": ["Ostrava Bank", "Hearth & Crown Bank", "Meridian Savings"]},
	{"id": "sports", "name": "Sports club", "kind": "stadium", "cost": 4.0e7, "unit": "player", "units": "players",
		"unit_cost": 1.4e7, "unit_income": 440000.0, "stage_mult": 1.45, "exp_cost": 1.4e8, "exp_growth": 2.9, "exp_min": 35.0,
		"names": ["Port Ellis Athletic", "Redmoor Rovers", "Halcyon United"]},
	{"id": "mining", "name": "Mining", "kind": "mine", "cost": 2.5e8, "unit": "shaft", "units": "shafts",
		"unit_cost": 8.5e7, "unit_income": 1.7e6, "stage_mult": 1.45, "exp_cost": 8.5e8, "exp_growth": 2.85, "exp_min": 42.0,
		"names": ["Greyvein Mining", "Cinder Hill Ores", "Deepcut Minerals"]},
	{"id": "oil", "name": "Oil and gas", "kind": "rig", "cost": 1.5e9, "unit": "rig", "units": "rigs",
		"unit_cost": 5.0e8, "unit_income": 1.4e7, "stage_mult": 1.45, "exp_cost": 5.0e9, "exp_growth": 2.8, "exp_min": 50.0,
		"names": ["Norvale Energy", "Deepwell Petroleum", "Black Tern Oil"]},
	{"id": "airline", "name": "Airline", "kind": "plane", "cost": 1.3e10, "unit": "plane", "units": "planes",
		"unit_cost": 4.5e9, "unit_income": 1.1e8, "stage_mult": 1.45, "exp_cost": 4.5e10, "exp_growth": 2.6, "exp_min": 70.0,
		"names": ["Red Sun Air", "Kestrel Airways", "Highline Air"]},
	{"id": "space", "name": "Space launch", "kind": "rocket", "cost": 1.2e11, "unit": "rocket", "units": "rockets",
		"unit_cost": 4.0e10, "unit_income": 8.5e8, "stage_mult": 1.45, "exp_cost": 4.0e11, "exp_growth": 2.5, "exp_min": 90.0,
		"names": ["Red Sun Orbital", "Farline Launch", "Kestrel Space"]},
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
const COINS := [ # symbol, name, base price (rough real price in £), volatility, lock rate per hour
	["SOL", "Solana", 140.0, 0.012, 0.0012], ["XRP", "XRP", 2.1, 0.018, 0.0024],
	["DOGE", "Dogecoin", 0.15, 0.025, 0.0036], ["BTC", "Bitcoin", 75000.0, 0.008, 0.0006],
	["LINK", "Chainlink", 14.0, 0.015, 0.0018], ["SHIB", "Shiba Inu", 0.000015, 0.03, 0.0045],
	["ADA", "Cardano", 0.6, 0.02, 0.003], ["TRX", "Tron", 0.2, 0.022, 0.003],
	["ETH", "Ethereum", 2800.0, 0.012, 0.0015], ["PEPE", "Pepe", 0.000008, 0.035, 0.006],
	["AVAX", "Avalanche", 25.0, 0.02, 0.0027], ["DOT", "Polkadot", 5.0, 0.024, 0.0033],
	["LTC", "Litecoin", 80.0, 0.014, 0.0018],
]
# 1.1 switched to real coins. Old saves are moved over by _migrate (v10),
# keeping each holding's value in £.
const COIN_RENAME := {"KRV": "SOL", "LMN": "XRP", "ASH": "DOGE", "MRC": "BTC", "TDE": "LINK", "EMB": "SHIB",
	"NVA": "ADA", "PBL": "TRX", "GLT": "ETH", "DRF": "PEPE", "VLT": "AVAX", "QRT": "DOT", "HLO": "LTC"}

const STAKE_LOCK_H := 24.0
# Mining (1.1): buy rigs for a coin; they mine that coin all the time.
# Rig prices climb across ALL coins (spreading out doesn't dodge it).
const RIG_BASE := 25000.0
const RIG_GROWTH := 1.7         # each miner costs 70% more than the last
const RIG_MAX := 40              # miners in total
const MINE_YIELD := 0.04         # a miner earns 4% of its price an hour (pays back in about a day)
const MINE_CAP := 0.02           # all mining pays at most 2% of hourly income...
const MINE_CAP_PER_RIG := 0.0015 # ...plus 0.15% per miner owned (11% with all 60), so every miner counts
const NEWS_MINE_UP := ["%s mining gets faster", "%s miners earn more"]
const NEWS_MINE_DOWN := ["%s mining pays less", "%s miners earn less"]

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
	["Back Row Terrace", "Port Ellis", 25000.0, "terrace"], ["Millbrook Cottage", "Saltmarsh", 32000.0, "cottage"],
	["Quay View Flat", "Port Ellis", 65000.0, "flats"], ["Larch House", "Redmoor", 140000.0, "house"],
	["Station Lofts", "Ironmere", 380000.0, "loft"],
	["The Granary", "Coldharbour", 1.2e6, "granary"], ["Cliff Top Villa", "Saltmarsh", 2.6e6, "villa"],
	["Northgate Offices", "Ironmere", 5.4e6, "offices"], ["Harbour Row", "Port Ellis", 9.78e6, "flats"], ["Meridian Hotel", "Redmoor", 2.2e7, "hotel"],
	["Kestrel Point", "Port Ellis", 4.8e7, "tower"], ["Halcyon Resort", "Black Tern Isle", 1.1e8, "resort"],
	["Granite Plaza", "Ironmere", 2.6e8, "offices"], ["Red Sun Tower", "Port Ellis", 6.0e8, "tower"],
	["Lantern Bay Resort", "Tern Islands", 1.4e9, "resort"], ["Skyline One", "Redmoor", 3.2e9, "spire"],
	["Ellis Arena", "Port Ellis", 7.5e9, "arena"], ["Sunken Garden Isle", "Tern Islands", 1.2e10, "island"],
	["The Spire", "Port Ellis", 2.0e10, "spire"], ["Crown Sphere", "Redmoor", 2.8e10, "sphere"],
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
	["Terrace house", "Saltmarsh", 120000.0, "terrace"],
	["Town house", "Redmoor", 900000.0, "house"],
	["Harbour penthouse", "Port Ellis", 8.0e6, "tower"],
	["Cliff villa", "Saltmarsh", 9.0e7, "villa"],
	["Country estate", "Coldharbour", 1.2e9, "cottage"],
	["Sky mansion", "Redmoor", 1.8e10, "spire"],
	["Island palace", "Tern Islands", 3.0e11, "island"],
]
const HOME_BONUS := 0.01  # extra income per step up (kept small on purpose)

# ---- managers ------------------------------------------------------------
# ---- milestones and synergies (v1.1) ----------------------------------------
# Owning this many units of one company multiplies its income (they stack).
const MILESTONES := [[5, 1.1], [25, 1.15], [50, 1.25]]
# One-off upgrades: when one company reaches a stage, it can boost another.
# id, name, source company, source stage, target company, income multiplier, cost
const SYNERGIES := [
	["delivery", "Taxi deliveries", "taxi", 3, "food", 1.3, 6.0e4],
	["own_fleet", "Own lorry fleet", "shipping", 3, "shop", 1.3, 5.0e4],
	["parts", "Factory parts", "factory", 4, "dealer", 1.25, 6.0e5],
	["site_gym", "Gyms on site", "construction", 4, "gym", 1.25, 2.0e6],
	["hotel_tv", "Hotel TV", "tv", 3, "hotel", 1.25, 4.0e7],
	["tech_desk", "Bank tech desk", "it", 5, "bank", 1.2, 6.0e7],
	["sponsor", "Club sponsor", "bank", 4, "sports", 1.2, 6.0e8],
	["ore", "Ore to factory", "mining", 3, "factory", 1.3, 4.0e8],
	["fuel", "Jet fuel deal", "oil", 3, "airline", 1.2, 3.0e11],
	["launch_fuel", "Rocket fuel", "oil", 6, "space", 1.2, 1.5e12],
]
# One dial for all company income, set so 1.1's new bonuses keep the same pace.
const INCOME_SCALE := 0.8
const ACH_BONUS := 0.002      # each achievement adds 0.2% to all income (cap lands near the last ones)
const ACH_BONUS_CAP := 0.15   # but never more than +15% in total
# ---- head office (1.1): one-off upgrades that change the rules -----------
# id, name, what it does, cost
const UPGRADES := [
	["tap", "Stronger taps", "Taps earn ×1.5", 5.0e4],
	["deals", "Dealmaker", "Deals come 25% sooner", 3.0e5],
	["away1", "Night shift", "Earn while away up to 10 h", 1.0e6],
	["fast1", "Fast builders", "Expansions 15% quicker", 3.0e6],
	["sun", "Lucky skies", "One more golden sun a day", 2.0e7],
	["lock", "Better vault", "Locked coins earn 25% more", 1.0e8],
	["mine", "Cooler miners", "Miners earn 25% more", 1.0e9],
	["away2", "Weekend staff", "Earn while away up to 12 h", 2.0e10],
	["fast2", "Express permits", "Expansions another 15% quicker", 2.0e11],
	["mgr", "Better managers", "Managers take 6%, not 10%", 2.0e12],
]
const MANAGER_CUT := 0.10        # share of that company's income they keep
const MANAGER_COST_X := 1.5      # hire cost = this x the next expansion cost

# ---- golden sun (a small surprise while playing) -------------------------
const SUN_EVERY_MIN := [15.0, 30.0]  # minutes of play between suns
const REBIRTH_MIN := 1.0e10          # net worth needed to rebirth (gives 10 RBP)
const SUN_PER_DAY := 4                # never more than this a day
# What a caught sun gives: chance of a cash prize, else a short buff (1.1).
const SUN_CASH_CHANCE := 0.5
const SUN_FRENZY_CHANCE := 0.3       # the rest is a Rush
const FRENZY_MULT := 5.0             # taps ×5 (instead of the ×3 boost, not on top)
const FRENZY_S := 20.0
const RUSH_S := 600.0                # +1× income for 10 minutes, only while playing
const CRIT_BASE := 0.04              # chance of a critical tap, +0.2% per level
const CRIT_PER_LEVEL := 0.002
const CRIT_MULT := 5.0
const SUN_STAY_S := 9.0               # how long it drifts before it's gone
const SUN_PRIZES := [[0.5, 10.0], [0.3, 20.0], [0.15, 30.0], [0.05, 60.0]]  # chance, minutes of income

# ---- deals ---------------------------------------------------------------
const DEAL_EVERY_MIN := [12.0, 25.0]  # minutes of play (app open) between deals
const SELL_SPREAD := 0.005  # shares and coins sell for 0.5% under the price
const STAKE_CAP := 0.05     # all staking together pays at most 5% of hourly income

# ---- rivals --------------------------------------------------------------
# Made-up tycoons to overtake. Their fortunes are fixed targets.
const RIVALS := [ # name, what they run, net worth
	["Dara Quill", "Corner shops", 5.0e4],
	["Otto Brannigan", "Taxis", 5.0e5],
	["Maeve Holloway", "Shipping", 5.0e6],
	["Rufus Penrose", "Factories", 5.0e7],
	["Ines Calloway", "Property", 5.0e8],
	["Bram Okonkwo", "Banking", 5.0e9],
	["Saskia Thorne", "Football", 5.0e10],
	["Lorcan Vey", "Oil", 5.0e11],
	["Hester Marchbank", "Airlines", 5.0e12],
	["The Ashgrove Family", "Everything", 5.0e13],
	["Corvin Hale", "Space", 5.0e14],
	["Odile Varga", "Shipping lanes", 5.0e15],
	["The Lantern Trust", "Old money", 1.5e16],
]

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
	{"id": "retail", "name": "Retail Group", "cost": 6.0e+06, "boost": ["shop", "dealer", "factory", "food", "gym"], "mult": 1.5,
		"needs": [["biz", "shop", 5], ["biz", "dealer", 3], ["biz", "factory", 3]]},
	{"id": "transit", "name": "Transit Group", "cost": 7.5e+07, "boost": ["taxi", "shipping"], "mult": 1.5,
		"needs": [["biz", "taxi", 5], ["biz", "shipping", 5], ["props", 5]]},
	{"id": "build", "name": "Build Corp", "cost": 7.5e+08, "boost": ["construction", "factory", "mining"], "mult": 1.5,
		"needs": [["biz", "construction", 6], ["biz", "factory", 6], ["props", 8]]},
	{"id": "tech", "name": "Coin Exchange", "cost": 4.5e+09, "boost": ["it", "bank", "tv"], "mult": 1.5,
		"needs": [["biz", "it", 5], ["crypto", 5.0e7], ["shares", 1.0e8]]},
	{"id": "skysea", "name": "Sky & Sea", "cost": 1.5e+11, "boost": ["airline", "shipping", "oil", "space", "hotel"], "mult": 1.5,
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


static func synergy(id: String) -> Array:
	for sy in SYNERGIES:
		if sy[0] == id:
			return sy
	return []


static func coin(sym: String) -> Array:
	for c in COINS:
		if c[0] == sym:
			return c
	return []


static func business(id: String) -> Dictionary:
	for b in BUSINESSES:
		if b["id"] == id:
			return b
	return {}


# ---- what's new (shown from Profile) -------------------------------------
const RELEASE := "1.1"
const WHATS_NEW := [
	"Money in pounds, to the penny.",
	"Buy ×1, ×10, ×100 or Max.",
	"More units and Partners raise income.",
	"Big taps, and golden sun bonuses.",
	"Real coins; miners dig the one you pick.",
	"Sound, a Stats page and a growing tower.",
	"Buy, sell or lock any amount: slide or type.",
	"Convert coins, and watch your miners work.",
	"Rebirth for RBP and grow the 152-node tree.",
]
