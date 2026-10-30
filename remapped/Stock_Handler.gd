extends Node





var t = 0
var rng = RandomNumberGenerator.new()
var stocks:Array
var FISH_FOUND:Array
var ORGANS_FOUND:Array
var timer:Timer
var total_assets = 0
var market_events_applied:Array = []
var market_news_history:Array = []
var market_impact_display_time:float = 0.0
var market_hq_revealed:bool = false
const MARKET_IMPACT_SECONDS = 20.0

# Each eligible built-in mission has disclosed stock impacts, realized once per save.
const MISSION_MARKET_EVENTS = {
0: {"mission": "Cruelty Squad Headquarters", "outlook": "The death of Cruelty Squad's CEO will bring new leadership, sending the company's stock soaring while Security, Redefined suffers.", "effects": [
		{"ticker": "CRUS", "percent": 200},
		{"ticker": "SCRD", "percent": -35}]},
	1: {"mission": "Pharmakokinetiks", "outlook": "The internal cleanup will slightly benefit Cruelty Squad, while the biological-currency scandal prompts a small G-Tech sell-off.", "effects": [
		{"ticker": "CRUS", "percent": 8},
		{"ticker": "GTC ", "percent": -7}]},
	2: {"mission": "Paradise", "outlook": "Eliminating G-Tech's executives will bring the company close to collapse. Veggo's Meatoids stands to gain substantially, while Pizza House will see a small loss.", "effects": [
		{"ticker": "VEME", "percent": 68},
		{"ticker": "GTC ", "percent": -90},
		{"ticker": "PIHO", "percent": -8}]},
	3: {"mission": "Sin Space Engineering", "outlook": "AOI will gain leadership aligned with the Mercury project, lifting its stock. Cruelty Squad will benefit slightly, while demand for Pure Optics' survival equipment will fall.", "effects": [
		{"ticker": "AOI ", "percent": 15},
		{"ticker": "CRUS", "percent": 6},
		{"ticker": "PURE", "percent": -8}]},
	4: {"mission": "Androgen Assault", "outlook": "The loss of police leadership will increase demand for rival private security, while Cruelty Squad loses some of its influence.", "effects": [
		{"ticker": "SCRD", "percent": 16},
		{"ticker": "CRUS", "percent": -10}]},
	5: {"mission": "Mall Madness", "outlook": "Gurney's death will send GamesGames into an extraordinary speculative surge. Cruelty Squad and Consumer Softproducts will also benefit, while damage to the mall hurts Pizza House slightly.", "effects": [
		{"ticker": "GAGA", "percent": 286},
		{"ticker": "CRUS", "percent": 18},
		{"ticker": "CSFT", "percent": 12},
		{"ticker": "PIHO", "percent": -8}]},
	6: {"mission": "Apartment Atrocity", "outlook": "The GamesGames boom will end in bankruptcy. The hunt for Cruelty Squad's operative will benefit Security, Redefined, while the internal conflict weighs on Cruelty Squad.", "effects": [
		{"ticker": "SCRD", "percent": 14},
		{"ticker": "GAGA", "percent": -100},
		{"ticker": "CRUS", "percent": -12}]},
	7: {"mission": "Seaside Shock", "outlook": "The government contract will benefit Cruelty Squad, and removing the seasteaders will favor established shipping. Security, Redefined will lose a little ground.", "effects": [
		{"ticker": "CRUS", "percent": 18},
		{"ticker": "PWR ", "percent": 12},
		{"ticker": "SCRD", "percent": -8}]},
	8: {"mission": "Bog Business", "outlook": "Safer fracking operations and supply routes will benefit Power Monger Shipping and Godhead Heavy Industries. Security, Redefined will see a slight loss.", "effects": [
		{"ticker": "PWR ", "percent": 16},
		{"ticker": "GDHD", "percent": 10},
		{"ticker": "SCRD", "percent": -7}]},
	9: {"mission": "Casino Catastrophe", "outlook": "The casino owner's death will cause severe losses for Fatberg Casino and a smaller loss for Security, Redefined. Completing the contract will slightly benefit Cruelty Squad.", "effects": [
		{"ticker": "CRUS", "percent": 8},
		{"ticker": "FBCA", "percent": -64},
		{"ticker": "SCRD", "percent": -8}]},
	10: {"mission": "Idiot Party", "outlook": "Attacking the gathering of elites will increase demand for private security, while Godhead Heavy Industries and Fatberg Casino lose business.", "effects": [
		{"ticker": "SCRD", "percent": 14},
		{"ticker": "GDHD", "percent": -12},
		{"ticker": "FBCA", "percent": -10}]},
	11: {"mission": "Office", "outlook": "Destabilizing the security hierarchy will cause major losses for Cruelty Squad and Security, Redefined. Pure Optics will gain as personal defense becomes more valuable.", "effects": [
		{"ticker": "PURE", "percent": 12},
		{"ticker": "CRUS", "percent": -44},
		{"ticker": "SCRD", "percent": -25}]},
	12: {"mission": "Archon Grid", "outlook": "The eventual rise of opportunity will send every company stock soaring.", "effects": [
		{"ticker": "ALL", "percent": 99}]},
	13: {"mission": "Darkworld", "outlook": "Cruelty Squad will suffer a slight loss after spending resources on a redundant, unusually dangerous contract.", "effects": [
		{"ticker": "CRUS", "percent": -6}]},
	14: {"mission": "Alpine Hospitality", "outlook": "Removing executives of competing firms will benefit Cruelty Squad and Godhead Heavy Industries, while Security, Redefined loses ground.", "effects": [
		{"ticker": "CRUS", "percent": 18},
		{"ticker": "GDHD", "percent": 10},
		{"ticker": "SCRD", "percent": -12}]},
	15: {"mission": "Miner's Miracle", "outlook": "The death of Godhead's CEO will cause major losses for the company. Cruelty Squad and Power Monger Shipping will see smaller gains.", "effects": [
		{"ticker": "CRUS", "percent": 8},
		{"ticker": "PWR ", "percent": 8},
		{"ticker": "GDHD", "percent": -42}]},
	16: {"mission": "Neuron Activator", "outlook": "The collapse of the redevelopment venture will hurt Godhead Heavy Industries, while violence in the arcology increases demand for Security, Redefined.", "effects": [
		{"ticker": "SCRD", "percent": 12},
		{"ticker": "GDHD", "percent": -15}]},
	18: {"mission": "Trauma Loop", "outlook": "???", "effects": [
		{"ticker": "ALL", "percent": -99}]}
}

var TOILET_FISH = ["BNBO"]
var POSSIBLE_FISH = [
	["SLRP", "FLSH", "CIV ", "BRNY"], 
	["POOL", "DRMP", "BRNY", "BLLS"], 
	["POOL", "GLOM", "SMLL", "BIG ", "NGHT", "HUMN", "BRST"], 
	["FISH", "ZOOP", "BLRP", "MOON", "NGHT", "CARB", "EEL ", "FLND", "GFLD", "DEAD", "HDRA"], 
	["PSYK", "GLOM", "NGHT", "HUMN", "DEAD", "BNCY"], 
	["FISH", "DEAD"], 
	["FISH", "DEAD"], 
	["UNI ", "BUBL", "DRMP", "FISH", "FLIP", "NGHT", "NOCT", "OCTO", "HEXA", "DLPH", "GRAB", "FRAG", "SKIP", "DEAD"], 
	["SLRP", "BOG ", "SWMP", "SBOG", "HUMN", "SPKE", "GEEL", "PIPE"], 
	["LUCK", "BNBO", "WLTH", "COIN", "WOF ", "ZIPP", "PAIN"], 
	["BRRN", "AGON", "CREP", "DLTA", "ETRN"], 
	["DOS ", "POOL", "DEAD", "DRMP", "BRNY"], 
	["MSTK", "FISH", "CUBE", "SLRP", "DEAD", "SCCS", "SUN "], 
	["GLRM", "DSLR", "DFSH", "DSCK"], 
	["ICE ", "ICBE"], 
	["BLSM", "CHTH", "ENGN", "HEAD", "POND", "HELI"], 
	["SLRP", "FLSH", "CIV ", "PSYK", "TRNC"], 
	["HELI", "FUZZ", "SCCS", "BLLS"], 
	["HEAD", "DLTA", "MSTK", "PSYK", "PAIN", "SOUL", "GLOM", "HDRA", "DEAD", "HUMN"], 
]

class stock:
	var price:float = 100
	
	
	var description:String = "We're currently gathering data on this asset."
	var index = 0
	var asset_type:String = "equity"
	var values:Array
	var issued_shares:float = 1238299
	var last_price:float = 100
	var max_price:float = 200
	var min_price:float = 20
	var extreme_action:float = 200
	var ticker = "TST"
	var s_name = "Test Stock"
	var owned:float = 0
	var bankrupt = 600
	var price_action_day = 600
	var price_action = 0.1
	var volatility:float = 1
	var trend:float = 0
	var night = false
	var starting_price = price
	var starting_trend = trend
	var market_state:int = 0
	var market_state_time:float = 0.0
	var market_impulse:float = 0.0
	var market_impulse_time:float = 0.0
	var market_collapse_time:float = 0.0
	var market_collapse_start_price:float = 0.0
	var market_event_floor:float = 0.0
	var permanently_bankrupt:bool = false
	var fish_speed = 1
	var fish_chance = 100
	var fish_night = false
	var fish_rain = false
	var fish_hell = false
	func get_data()->Dictionary:
		var stock_data = {
			"ticker":ticker, 
			"owned":owned, 
			"price":price, 
			"l_price":last_price, 
			"trend":trend,
			"market_state":market_state,
			"market_state_time":market_state_time,
			"market_impulse":market_impulse,
			"market_impulse_time":market_impulse_time,
			"market_collapse_time":market_collapse_time,
			"market_collapse_start_price":market_collapse_start_price,
			"market_event_floor":market_event_floor,
			"permanently_bankrupt":permanently_bankrupt
		}
		return stock_data

func _enter_tree():
	
	var new_stock = stock.new()
	new_stock.ticker = "CRUS"
	new_stock.s_name = "Cruelty Squad"
	new_stock.description = "Steady bluechip company in the security business."
	new_stock.price = 1237
	new_stock.issued_shares = 2912812
	new_stock.max_price = 1999
	new_stock.min_price = 500
	new_stock.trend = 0.01
	new_stock.volatility = 1
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "GDHD"
	new_stock.description = "Once a great company, has recently lost influence."
	new_stock.s_name = "Godhead Heavy Industries"
	new_stock.price = 732
	new_stock.min_price = 12
	new_stock.max_price = 820
	new_stock.volatility = 1.5
	new_stock.trend = - 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	
	new_stock = stock.new()
	new_stock.ticker = "GTC "
	new_stock.description = "Hot new startup looking to revolutionize computing and food. Buy."
	new_stock.s_name = "G-Tech"
	new_stock.max_price = 600
	new_stock.price = 89
	new_stock.volatility = 7
	new_stock.trend = 0.1
	new_stock.bankrupt = 3
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "PIHO"
	new_stock.description = "The greatest fast food chain ever to exist with history spanning centuries and tens of thousands of locations open worldwide. The peeperoni pizza is a delight for the senses."
	new_stock.s_name = "Pizza House"
	new_stock.max_price = 510
	new_stock.price = 123
	new_stock.volatility = 7
	new_stock.trend = 0.05
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "AOI "
	new_stock.description = "22nd century space-faring solutions."
	new_stock.s_name = "Advanced Orbital Instruments"
	new_stock.max_price = 774
	new_stock.price = 530
	new_stock.volatility = 5
	new_stock.trend = 0.02
	new_stock.price_action_day = 4
	new_stock.price_action = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "GAGA"
	new_stock.s_name = "GamesGames"
	new_stock.description = "Failing game store chain."
	new_stock.max_price = 700
	new_stock.price = 165
	new_stock.extreme_action = 6
	new_stock.bankrupt = 7
	
	
	new_stock.volatility = 10
	new_stock.trend = - 0.05
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)


	new_stock = stock.new()
	new_stock.ticker = "PWR "
	new_stock.description = "Originally became known for heavily arming its fleet to counter pirates, but acquired a monopoly status when it was discovered that you can also sink your competition."
	new_stock.s_name = "Power Monger Shipping Company"
	new_stock.max_price = 1500
	new_stock.price = 205
	new_stock.volatility = 7
	new_stock.trend = - 0.05
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	
	new_stock = stock.new()
	new_stock.ticker = "VEME"
	new_stock.s_name = "Veggo's Meatoids"
	new_stock.description = "Mysterious newcomer in the vegan meat industry. Competitor of G-TECH's goofood business."
	new_stock.max_price = 1521
	new_stock.price = 20
	new_stock.volatility = 15
	new_stock.price_action_day = 3
	new_stock.price_action = 0.02
	new_stock.trend = 0.02
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)


	new_stock = stock.new()
	new_stock.ticker = "FBCA"
	new_stock.s_name = "Fatberg Casino"
	new_stock.description = "Sir Fatberg's famous casino in the western swamplands."
	new_stock.max_price = 643
	new_stock.price = 405
	new_stock.volatility = 7
	new_stock.trend = 0.05
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	
	new_stock = stock.new()
	new_stock.ticker = "SCRD"
	new_stock.description = "Not much is known about this security company, the workers seem a bit off and don't seem to be able to talk. Rabid fanbase."
	new_stock.s_name = "Security, Redefined"
	new_stock.max_price = 320
	new_stock.price = 153
	new_stock.volatility = 7
	new_stock.trend = - 0.05
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "PURE"
	new_stock.s_name = "Pure Optics"
	new_stock.max_price = 1200
	new_stock.price = 630
	new_stock.description = "Military grade optics, among other things."
	new_stock.volatility = 4
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "CSFT"
	new_stock.s_name = "Consumer Softproducts"
	new_stock.description = "Developer of the smash hit video game Gorbino's Quest."
	new_stock.max_price = 1200
	new_stock.price = 413
	new_stock.volatility = 3
	new_stock.trend = 0.05
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "BRN "
	new_stock.s_name = "Brain"
	new_stock.description = "Raw material used by the AI industry."
	new_stock.asset_type = "part"
	new_stock.max_price = 99
	new_stock.min_price = 2
	new_stock.price = 40
	new_stock.volatility = 3
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "AUGB"
	new_stock.s_name = "Augmented Brain"
	new_stock.description = "A low quality augmented brain. High processing speed at the cost of extreme neuroticism."
	new_stock.asset_type = "part"
	new_stock.max_price = 200
	new_stock.min_price = 120
	new_stock.price = 130
	new_stock.volatility = 0.1
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "PSYB"
	new_stock.s_name = "Psycho Brain"
	new_stock.description = "The brain of a psychogenic controller, or psyker. Capable of sentience."
	new_stock.asset_type = "part"
	new_stock.max_price = 3000
	new_stock.min_price = 1500
	new_stock.price = 2000
	new_stock.volatility = 0.1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "WRMB"
	new_stock.s_name = "Worm Brain"
	new_stock.description = "Crawling with lab grown parasites."
	new_stock.asset_type = "part"
	new_stock.max_price = 3000
	new_stock.min_price = 1500
	new_stock.price = 2000
	new_stock.volatility = 0.1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "LIVR"
	new_stock.s_name = "Liver"
	new_stock.description = "Most commonly needed spare part for executives."
	new_stock.asset_type = "part"
	new_stock.max_price = 52
	new_stock.min_price = 2
	new_stock.price = 20
	new_stock.volatility = 2
	new_stock.trend = - 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "TLVR"
	new_stock.s_name = "Tactical Liver"
	new_stock.description = "It looks cool."
	new_stock.asset_type = "part"
	new_stock.max_price = 200
	new_stock.min_price = 100
	new_stock.price = 150
	new_stock.volatility = 1
	new_stock.trend = - 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "KDNY"
	new_stock.s_name = "Kidney"
	new_stock.description = "Plentiful and easily replaced, more so than others."
	new_stock.asset_type = "part"
	new_stock.max_price = 20
	new_stock.min_price = 2
	new_stock.price = 10
	new_stock.volatility = 0.5
	new_stock.trend = - 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "HERT"
	new_stock.s_name = "Heart"
	new_stock.description = "A disgustingly persistent little biological pump."
	new_stock.asset_type = "part"
	new_stock.max_price = 300
	new_stock.min_price = 150
	new_stock.price = 200
	new_stock.volatility = 1
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BHRT"
	new_stock.s_name = "Black Heart"
	new_stock.description = "A heart running at optimal capacity."
	new_stock.asset_type = "part"
	new_stock.max_price = 2000
	new_stock.min_price = 1000
	new_stock.price = 1500
	new_stock.volatility = 1
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "INTS"
	new_stock.s_name = "Intestine"
	new_stock.description = "The one in the driver's seat. The homunculus."
	new_stock.asset_type = "part"
	new_stock.max_price = 400
	new_stock.min_price = 200
	new_stock.price = 300
	new_stock.volatility = 1
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "PINT"
	new_stock.s_name = "Putrid Intestine"
	new_stock.description = "The worst smell you have ever experienced. What has this thing been eating?"
	new_stock.asset_type = "part"
	new_stock.max_price = 500
	new_stock.min_price = 300
	new_stock.price = 400
	new_stock.volatility = 1
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "APNX"
	new_stock.s_name = "Appendix"
	new_stock.description = "The primitive seat of the soul."
	new_stock.asset_type = "part"
	new_stock.max_price = 2000
	new_stock.min_price = 1000
	new_stock.price = 1500
	new_stock.volatility = 1
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "SPNE"
	new_stock.s_name = "Spine"
	new_stock.description = "Mark of a celestial prisoner."
	new_stock.asset_type = "part"
	new_stock.max_price = 1200
	new_stock.min_price = 600
	new_stock.price = 800
	new_stock.volatility = 1
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "RSPN"
	new_stock.s_name = "Rotten Spine"
	new_stock.description = "The internal scaffolding of a being selected for eternal punishment."
	new_stock.asset_type = "part"
	new_stock.max_price = 5200
	new_stock.min_price = 600
	new_stock.price = 3000
	new_stock.volatility = 1
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "GUT "
	new_stock.s_name = "Stomach"
	new_stock.description = "The origin of Death."
	new_stock.asset_type = "part"
	new_stock.max_price = 127
	new_stock.min_price = 84
	new_stock.price = 101
	new_stock.volatility = 0.5
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "NGUT"
	new_stock.s_name = "Nuclear Stomach"
	new_stock.description = "Capable of turning fissile material into biological energy. Doesn't protect the surroundings from radiation."
	new_stock.asset_type = "part"
	new_stock.max_price = 1270
	new_stock.min_price = 840
	new_stock.price = 1010
	new_stock.volatility = 0.5
	new_stock.trend = 0.01
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "PNCR"
	new_stock.s_name = "Pancreas"
	new_stock.description = "Manages the regulation of blood sugar levels. Completely superfluous due to advances in the food industry."
	new_stock.asset_type = "part"
	new_stock.max_price = 1
	new_stock.min_price = 1
	new_stock.price = 1
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "ADVP"
	new_stock.s_name = "Advanced Pancreas"
	new_stock.description = "This pancreas has been modified to secrete synthetic stimulants."
	new_stock.asset_type = "part"
	new_stock.max_price = 1000
	new_stock.min_price = 500
	new_stock.price = 603
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "FLSH"
	new_stock.s_name = "Fleshrat"
	new_stock.description = "Hey! That's a fleshrat! Disgusting."
	new_stock.asset_type = "fish"
	new_stock.fish_chance = 30
	new_stock.fish_speed = 0.7
	new_stock.max_price = 10
	new_stock.min_price = 2
	new_stock.price = 5
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "CIV "
	new_stock.s_name = "Civilian"
	new_stock.description = "These are all over the place. Not worth much"
	new_stock.asset_type = "fish"
	new_stock.fish_chance = 5
	new_stock.fish_speed = 0.7
	new_stock.max_price = 5
	new_stock.min_price = 1
	new_stock.price = 2.5
	new_stock.volatility = 0.05
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BRNY"
	new_stock.s_name = "Brainy"
	new_stock.description = "Too intelligent for its own good, it despises living in fish society."
	new_stock.asset_type = "fish"
	new_stock.fish_night = true
	new_stock.fish_chance = 30
	new_stock.max_price = 400
	new_stock.min_price = 170
	new_stock.price = 200
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "POOL"
	new_stock.s_name = "Poolsucker"
	new_stock.description = "Lives on poolgunk."
	new_stock.asset_type = "fish"
	new_stock.max_price = 56
	new_stock.min_price = 3
	new_stock.price = 32
	new_stock.volatility = 2
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BRST"
	new_stock.s_name = "Brimstone"
	new_stock.description = "Gets its beautiful color from a coating of sulfur."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 30
	new_stock.max_price = 500
	new_stock.min_price = 300
	new_stock.price = 400
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "DRMP"
	new_stock.s_name = "Drimp"
	new_stock.description = "A sought after beautiful decorative fish."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 50
	new_stock.max_price = 200
	new_stock.min_price = 25
	new_stock.price = 120
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "GLOM"
	new_stock.s_name = "Gloomoid"
	new_stock.description = "Consumes sin."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 40
	new_stock.max_price = 300
	new_stock.min_price = 40
	new_stock.price = 200
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "SMLL"
	new_stock.s_name = "Smallman"
	new_stock.description = "Tricky to catch. Considered a delicacy but contains carcinogens."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.35
	new_stock.fish_chance = 15
	new_stock.max_price = 1000
	new_stock.min_price = 310
	new_stock.price = 765
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BIG "
	new_stock.s_name = "Bigman"
	new_stock.description = ""
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.45
	new_stock.fish_hell = true
	new_stock.fish_chance = 15
	new_stock.max_price = 2000
	new_stock.min_price = 620
	new_stock.price = 1420
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "FISH"
	new_stock.s_name = "Fish"
	new_stock.description = "The platonic ideal of a fish."
	new_stock.asset_type = "fish"
	new_stock.max_price = 52
	new_stock.min_price = 2
	new_stock.price = 25
	new_stock.volatility = 2
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "NGHT"
	new_stock.s_name = "Nightfreak"
	new_stock.description = "Emerges from the depths at night. The reflection you see in its eyes is not you."
	new_stock.asset_type = "fish"
	new_stock.fish_night = true
	new_stock.fish_chance = 50
	new_stock.max_price = 200
	new_stock.min_price = 15
	new_stock.price = 111
	new_stock.volatility = 2
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "ZOOP"
	new_stock.s_name = "Zooper"
	new_stock.description = "Zoopers follow container ships and make strange noises."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.8
	new_stock.fish_chance = 80
	new_stock.max_price = 100
	new_stock.min_price = 5
	new_stock.price = 52
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "CARB"
	new_stock.s_name = "Carabino"
	new_stock.description = "A deranged combatant beyond help."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.32
	new_stock.fish_chance = 80
	new_stock.max_price = 600
	new_stock.min_price = 300
	new_stock.price = 400
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "MOON"
	new_stock.s_name = "Moonfish"
	new_stock.description = "A beautiful fish known for its use in chemical weapons."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 2
	new_stock.fish_night = true
	new_stock.max_price = 10000
	new_stock.min_price = 3000
	new_stock.price = 8000
	new_stock.volatility = 6
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "EEL "
	new_stock.s_name = "Eel"
	new_stock.description = "Snakelike slippery fish that loves the rain."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 80
	new_stock.fish_rain = true
	new_stock.max_price = 500
	new_stock.min_price = 300
	new_stock.price = 400
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "FLND"
	new_stock.s_name = "Flounder"
	new_stock.description = "Deformed by sin. A cowardly fish."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 60
	new_stock.fish_rain = true
	new_stock.max_price = 700
	new_stock.min_price = 400
	new_stock.price = 522
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "GFLD"
	new_stock.s_name = "Gigaflounder"
	new_stock.description = "Deformed by power. A wrathful fish."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 10
	new_stock.fish_rain = true
	new_stock.fish_night = true
	new_stock.max_price = 20000
	new_stock.min_price = 15000
	new_stock.price = 10000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BLRP"
	new_stock.s_name = "Blurpo"
	new_stock.description = "Blurpo is the smelliest saltwater fish on the market, an acquired taste."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.7
	new_stock.fish_chance = 50
	new_stock.max_price = 200
	new_stock.min_price = 10
	new_stock.price = 101
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "HDRA"
	new_stock.s_name = "Hydra"
	new_stock.description = "God among fish."
	new_stock.asset_type = "fish"
	new_stock.fish_hell = true
	new_stock.fish_night = true
	new_stock.fish_speed = 0.25
	new_stock.fish_chance = 1
	new_stock.max_price = 1100000
	new_stock.min_price = 990000
	new_stock.price = 1000000
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "PSYK"
	new_stock.s_name = "Psychofish"
	new_stock.description = "Saps the psychic energies of nearby humans."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 35
	new_stock.max_price = 620
	new_stock.min_price = 120
	new_stock.price = 320
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BNCY"
	new_stock.s_name = "Bouncy Castle"
	new_stock.description = "This fish has come into contact with an experimental super-androgen."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 35
	new_stock.fish_rain = true
	new_stock.max_price = 2000
	new_stock.min_price = 1200
	new_stock.price = 1000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "UNI "
	new_stock.s_name = "Unidor"
	new_stock.description = "Rare tropical fish with many uses in the biotech industry."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 5
	new_stock.max_price = 5000
	new_stock.min_price = 1400
	new_stock.price = 3000
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "NOCT"
	new_stock.s_name = "Nocter"
	new_stock.description = "Tropical fish drawn to the energy of high frequency commercial transactions."
	new_stock.asset_type = "fish"
	new_stock.fish_night = true
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 5
	new_stock.max_price = 10000
	new_stock.min_price = 5000
	new_stock.price = 7500
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "HUMN"
	new_stock.s_name = "Human"
	new_stock.description = "Strange fish covered in shiny black plastic. Smells pretty bad."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 5
	new_stock.max_price = 1
	new_stock.min_price = 10
	new_stock.price = 5
	new_stock.volatility = 0.1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BUBL"
	new_stock.s_name = "Bubblefish"
	new_stock.description = "Not prepared properly has a high chance of causing a stomach ulcer. Very cute, please put it back."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 1.0
	new_stock.fish_chance = 60
	new_stock.max_price = 300
	new_stock.min_price = 100
	new_stock.price = 160
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "FRAG"
	new_stock.s_name = "Fragfish"
	new_stock.description = "Explodes into high speed metal fragments when threatened. Can puncture a ship's hull easily."
	new_stock.asset_type = "fish"
	new_stock.fish_hell = true
	new_stock.fish_speed = 1.0
	new_stock.fish_chance = 60
	new_stock.max_price = 2000
	new_stock.min_price = 1000
	new_stock.price = 1600
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "FLIP"
	new_stock.s_name = "Flippy"
	new_stock.description = "Common tropical fish. Collective intelligence, launches suicide assaults on ship engines."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 90
	new_stock.max_price = 200
	new_stock.min_price = 50
	new_stock.price = 99
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "SKIP"
	new_stock.s_name = "Skippy"
	new_stock.description = "Rotates its disc-like body to skip across water."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 60
	new_stock.max_price = 500
	new_stock.min_price = 300
	new_stock.price = 360
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "GRAB"
	new_stock.s_name = "Grabshark"
	new_stock.description = "Pressurizes swimmers by dragging them to the bottom of the ocean."
	new_stock.asset_type = "fish"
	new_stock.fish_hell = true
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 15
	new_stock.max_price = 5000
	new_stock.min_price = 3100
	new_stock.price = 4200
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "DLPH"
	new_stock.s_name = "Dolphin"
	new_stock.description = "Said to be the result of human ichthyosation."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 15
	new_stock.max_price = 1200
	new_stock.min_price = 650
	new_stock.price = 800
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "OCTO"
	new_stock.s_name = "Octosaur"
	new_stock.description = "Loves drowning divers by releasing a cloud of acid."
	new_stock.asset_type = "fish"
	new_stock.fish_rain = true
	new_stock.fish_speed = 0.8
	new_stock.fish_chance = 60
	new_stock.max_price = 600
	new_stock.min_price = 300
	new_stock.price = 450
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "HEXA"
	new_stock.s_name = "Hexasaur"
	new_stock.description = "Holds absolute power over octosaurs."
	new_stock.asset_type = "fish"
	new_stock.fish_rain = true
	new_stock.fish_speed = 0.3
	new_stock.fish_chance = 4
	new_stock.max_price = 23000
	new_stock.min_price = 19000
	new_stock.price = 20000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "SLRP"
	new_stock.s_name = "Slurper"
	new_stock.description = "Come on that's disgusting. Who would want that?"
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 1.0
	new_stock.fish_chance = 100
	new_stock.max_price = 10
	new_stock.min_price = 1
	new_stock.price = 4
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "PIPE"
	new_stock.s_name = "Piper"
	new_stock.description = "Makes the sound of water rushing through plumbing."
	new_stock.asset_type = "fish"
	new_stock.fish_hell = true
	new_stock.fish_speed = 1.0
	new_stock.fish_chance = 100
	new_stock.max_price = 20
	new_stock.min_price = 8
	new_stock.price = 15
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BOG "
	new_stock.s_name = "Bogdo"
	new_stock.description = "Emerges from deep in the swamp and makes disgusting grunting sounds. Eats corpses."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 70
	new_stock.max_price = 450
	new_stock.min_price = 100
	new_stock.price = 350
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "SBOG"
	new_stock.s_name = "Super Bogdo"
	new_stock.description = "A terrifying scream reverberates over the swamplands. It's Super Bogdo. Eats bogdos."
	new_stock.asset_type = "fish"
	new_stock.fish_night = true
	new_stock.fish_speed = 0.3
	new_stock.fish_chance = 3
	new_stock.max_price = 22000
	new_stock.min_price = 20000
	new_stock.price = 18000
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "SWMP"
	new_stock.s_name = "Swampsucker"
	new_stock.description = "Unlike the benign poolsucker, this one only eats human flesh."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 30
	new_stock.max_price = 700
	new_stock.min_price = 400
	new_stock.price = 620
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "SPKE"
	new_stock.s_name = "Spiker"
	new_stock.description = "The spikes are hard enough to go through protective steel plates. Popular as a booby trap."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 50
	new_stock.max_price = 500
	new_stock.min_price = 250
	new_stock.price = 400
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "GEEL"
	new_stock.s_name = "Gunk Eel"
	new_stock.description = "Covered in a thick odorous hallucinogenic paste."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 80
	new_stock.fish_rain = true
	new_stock.max_price = 1000
	new_stock.min_price = 600
	new_stock.price = 800
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "LUCK"
	new_stock.s_name = "Lucksucker"
	new_stock.description = "A pulsating, writhing sensation fills your head. Feeds on luck and shits out misfortune."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.3
	new_stock.fish_chance = 3
	new_stock.max_price = 20000
	new_stock.min_price = 15000
	new_stock.price = 10000
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "BNBO"
	new_stock.s_name = "Bonbo"
	new_stock.description = "Sewage network traveler. Smiles at you and winks."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 10
	new_stock.max_price = 2000
	new_stock.min_price = 1000
	new_stock.price = 1500
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "WLTH"
	new_stock.s_name = "Fish of Wealth"
	new_stock.description = "Considered a symbol of good wealth. Not worth much though."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.7
	new_stock.fish_chance = 80
	new_stock.max_price = 600
	new_stock.min_price = 200
	new_stock.price = 300
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "COIN"
	new_stock.s_name = "Coiny"
	new_stock.description = "Avoids predators by hiding among coins."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.7
	new_stock.fish_chance = 95
	new_stock.max_price = 1
	new_stock.min_price = 1
	new_stock.price = 1
	new_stock.volatility = 3
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "WOF "
	new_stock.s_name = "Wheel of Fortune"
	new_stock.description = "A sign of demonic luck."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 0.5
	new_stock.max_price = 1000000
	new_stock.min_price = 1000000
	new_stock.price = 1000000
	new_stock.volatility = 0
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "PAIN"
	new_stock.s_name = "Wheel of Pain"
	new_stock.description = "A sign of celestial punishment."
	new_stock.asset_type = "fish"
	new_stock.fish_hell = true
	new_stock.fish_night = true
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 0.5
	new_stock.max_price = 2000000
	new_stock.min_price = 2000000
	new_stock.price = 2000000
	new_stock.volatility = 0
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "ZIPP"
	new_stock.s_name = "Zippy 3000 (Broken)"
	new_stock.description = "So close."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 10.0
	new_stock.fish_chance = 0.5
	new_stock.max_price = 1
	new_stock.min_price = 1
	new_stock.price = 1
	new_stock.volatility = 0
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)



	new_stock = stock.new()
	new_stock.ticker = "AGON"
	new_stock.s_name = "Agon"
	new_stock.description = "The sleeper."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 2.0
	new_stock.fish_chance = 40
	new_stock.max_price = 1500
	new_stock.min_price = 500
	new_stock.price = 1000
	new_stock.volatility = 0
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BRRN"
	new_stock.s_name = "Bororion"
	new_stock.description = "A primordial being."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 1.0
	new_stock.fish_chance = 20
	new_stock.max_price = 3000
	new_stock.min_price = 1000
	new_stock.price = 2000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "CREP"
	new_stock.s_name = "Creep"
	new_stock.description = "It won't leave you alone."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 5
	new_stock.max_price = 5000
	new_stock.min_price = 3000
	new_stock.price = 4000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "DLTA"
	new_stock.s_name = "Deltaforce"
	new_stock.description = "A celestial aggressor."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.3
	new_stock.fish_chance = 2.5
	new_stock.max_price = 110000
	new_stock.min_price = 90000
	new_stock.price = 100000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "ETRN"
	new_stock.s_name = "Eternity Slurper"
	new_stock.description = "A primitive subterranean form of the slurper."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 5
	new_stock.max_price = 5000
	new_stock.min_price = 3000
	new_stock.price = 4000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "DOS "
	new_stock.s_name = "DOSfish"
	new_stock.description = "Ancient machine that radiates knowledge attained by a legendary fishing expert."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.2
	new_stock.fish_chance = 1
	new_stock.max_price = 3500000
	new_stock.min_price = 2500000
	new_stock.price = 3000000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "MSTK"
	new_stock.s_name = "Mistake"
	new_stock.description = "Sometimes things just go wrong."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 1.0
	new_stock.fish_chance = 30
	new_stock.max_price = 600
	new_stock.min_price = 300
	new_stock.price = 350
	new_stock.volatility = 10
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "SCCS"
	new_stock.s_name = "Success"
	new_stock.description = "Now that's what I'm talking about."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.2
	new_stock.fish_chance = 2
	new_stock.max_price = 120000
	new_stock.min_price = 90000
	new_stock.price = 100000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "SUN "
	new_stock.s_name = "Sunfish"
	new_stock.description = "Went extinct in the 20th century."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 2.0
	new_stock.fish_chance = 2
	new_stock.max_price = 12000
	new_stock.min_price = 4000
	new_stock.price = 10000
	new_stock.volatility = 10
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "CUBE"
	new_stock.s_name = "Cubert"
	new_stock.description = "Some kind of speculative biology leaking from [REDACTED]'s head."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 1.0
	new_stock.fish_chance = 70
	new_stock.max_price = 700
	new_stock.min_price = 250
	new_stock.price = 500
	new_stock.volatility = 2
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "GLRM"
	new_stock.s_name = "Glurm"
	new_stock.description = "Thrives in complete darkness."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 50
	new_stock.max_price = 1200
	new_stock.min_price = 800
	new_stock.price = 1000
	new_stock.volatility = 2
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "DFSH"
	new_stock.s_name = "Darkfish"
	new_stock.description = "This fish is a malignant narcissist."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 50
	new_stock.max_price = 700
	new_stock.min_price = 500
	new_stock.price = 600
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "DSLR"
	new_stock.s_name = "Darkslurper"
	new_stock.description = "Contains fissile material. Victim of overfishing."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.3
	new_stock.fish_chance = 3
	new_stock.max_price = 100000
	new_stock.min_price = 90000
	new_stock.price = 95000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "DSCK"
	new_stock.s_name = "Darksucker"
	new_stock.description = "Darkness makes suckers slow and dull."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 2.0
	new_stock.fish_chance = 90
	new_stock.max_price = 200
	new_stock.min_price = 100
	new_stock.price = 152
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "ICE "
	new_stock.s_name = "Icefish"
	new_stock.description = "A fish perfectly adapted to sub-zero temperatures."
	new_stock.asset_type = "fish"
	new_stock.max_price = 300
	new_stock.min_price = 132
	new_stock.price = 150
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "ICBE"
	new_stock.s_name = "Ice Cubert"
	new_stock.description = "Its body temperature is almost 0 kelvin."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 1.0
	new_stock.fish_chance = 50
	new_stock.max_price = 800
	new_stock.min_price = 300
	new_stock.price = 632
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "BLSM"
	new_stock.s_name = "Blossom"
	new_stock.description = "Fills your mind with happy thoughts."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.6
	new_stock.fish_chance = 60
	new_stock.max_price = 2000
	new_stock.min_price = 1000
	new_stock.price = 1500
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "CHTH"
	new_stock.s_name = "Chthonner"
	new_stock.description = "A transnistrian cave dweller. Herbivore."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 40
	new_stock.max_price = 2100
	new_stock.min_price = 1100
	new_stock.price = 1620
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "HEAD"
	new_stock.s_name = "Head"
	new_stock.description = "Someone's head infected with an extraterrestrial parasite."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 30
	new_stock.max_price = 2300
	new_stock.min_price = 1300
	new_stock.price = 1800
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "POND"
	new_stock.s_name = "Pondman"
	new_stock.description = "Reminds you of a friend long gone."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 6
	new_stock.max_price = 4000
	new_stock.min_price = 3200
	new_stock.price = 3700
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "HELI"
	new_stock.s_name = "Helipod"
	new_stock.description = "As it spends the days flying around eating small insects it's usually only caught at night."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.35
	new_stock.fish_night = true
	new_stock.fish_chance = 50
	new_stock.max_price = 2000
	new_stock.min_price = 1000
	new_stock.price = 1200
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "ENGN"
	new_stock.s_name = "Engine of Chaos"
	new_stock.description = "Whirrs and gyrates with terrifying force as you try to make sense of your life."
	new_stock.asset_type = "fish"
	new_stock.fish_hell = true
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 10
	new_stock.max_price = 12000
	new_stock.min_price = 7000
	new_stock.price = 10000
	new_stock.volatility = 0.5
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "DEAD"
	new_stock.s_name = "Dead Fish"
	new_stock.description = "Animated by regret."
	new_stock.asset_type = "fish"
	new_stock.fish_hell = true
	new_stock.max_price = 104
	new_stock.min_price = 25
	new_stock.price = 50
	new_stock.volatility = 0
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "TRNC"
	new_stock.s_name = "Trancer"
	new_stock.description = "Mutated by malignant soundwaves and research chemicals."
	new_stock.asset_type = "fish"
	new_stock.max_price = 3000
	new_stock.min_price = 2000
	new_stock.fish_speed = 0.5
	new_stock.fish_chance = 10
	new_stock.price = 2500
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "FUZZ"
	new_stock.s_name = "Fuzzoid"
	new_stock.description = "Exists in boundaries, limits, edges. Primitive killer."
	new_stock.asset_type = "fish"
	new_stock.max_price = 30000
	new_stock.min_price = 20000
	new_stock.price = 25000
	new_stock.volatility = 3
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 10
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	new_stock = stock.new()
	new_stock.ticker = "SOUL"
	new_stock.s_name = "Soul"
	new_stock.description = "You caught a soul. It feels sticky to touch."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.2
	new_stock.fish_chance = 0.5
	new_stock.max_price = 6500000
	new_stock.min_price = 4500000
	new_stock.price = 5000000
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)
	
	new_stock = stock.new()
	new_stock.ticker = "BLLS"
	new_stock.s_name = "Ballsfish"
	new_stock.description = "By popular demand, as seen on television."
	new_stock.asset_type = "fish"
	new_stock.fish_speed = 0.4
	new_stock.fish_chance = 0.5
	new_stock.max_price = 450
	new_stock.min_price = 40
	new_stock.price = 200
	new_stock.volatility = 1
	new_stock.trend = 0
	new_stock.starting_price = new_stock.price
	new_stock.starting_trend = new_stock.trend
	stocks.append(new_stock)

	slot_stock_defaults = stock_save().duplicate(true)
	load_stocks()

var slot_stock_defaults = {}

func reset_slot_data():
	market_events_applied = []
	market_news_history = []
	market_impact_display_time = 0.0
	market_hq_revealed = false
	var fish = slot_stock_defaults.get("fish_found")
	var organs = slot_stock_defaults.get("org_found")
	FISH_FOUND = fish.duplicate(true) if fish is Array else []
	ORGANS_FOUND = organs.duplicate(true) if organs is Array else []
	for stock in stocks:
		var data = slot_stock_defaults.get(stock.ticker, {})
		stock.price = data.get("price", stock.starting_price)
		stock.last_price = data.get("l_price", stock.price)
		stock.trend = data.get("trend", stock.starting_trend)
		stock.owned = data.get("owned", 0)
		stock.market_state = data.get("market_state", 0)
		stock.market_state_time = data.get("market_state_time", 0.0)
		stock.market_impulse = data.get("market_impulse", 0.0)
		stock.market_impulse_time = data.get("market_impulse_time", 0.0)
		stock.market_collapse_time = data.get("market_collapse_time", 0.0)
		stock.market_collapse_start_price = data.get("market_collapse_start_price", 0.0)
		stock.market_event_floor = data.get("market_event_floor", 0.0)
		stock.permanently_bankrupt = data.get("permanently_bankrupt", false)
		stock.values.clear()
	total_assets = 0

func _ready():
	rng.randomize()
	timer = Timer.new()
	add_child(timer)
	timer.wait_time = 1
	timer.one_shot = false
	timer.connect("timeout", self, "stock_tick")
	timer.start()

func stock_tick():
	_capture_hq_reveal()
	var asset_value = 0
	for stock in stocks:
		if stock.asset_type == "equity":
			_tick_company(stock, timer.wait_time)
			asset_value += stock.price * stock.owned
			continue
		
			
		
		
		stock.last_price = stock.price
		var trend = stock.trend
		if Global.LEVELS_UNLOCKED == 6:
			trend += 0.1
		if Global.LEVELS_UNLOCKED >= stock.price_action_day and stock.price < stock.max_price and stock.price > stock.min_price:
			trend += stock.price_action
		if Global.LEVELS_UNLOCKED == stock.extreme_action:
			trend += 1
		stock.price += sqrt(0.03333 * 0.5) * rng.randfn() * stock.volatility + trend
		if not stock.bankrupt:
			stock.price = clamp(stock.price, stock.min_price, stock.max_price)
		else :
			stock.price = clamp(stock.price, 0.87, 10000000)
		if stock.bankrupt < Global.LEVELS_UNLOCKED:
			stock.trend -= 0.01

		elif (stock.price <= stock.min_price + 5 and stock.trend < 0) or (stock.price >= stock.max_price - 5 and stock.trend > 0):
			stock.trend *= - 1
		if stock.min_price == stock.max_price:
			stock.price = stock.min_price
		stock.values.append(stock.price)
		if stock.values.size() > 100:
			stock.values.pop_front()
		asset_value += stock.price * stock.owned
		var color = Color(1, 0, 0)
		if stock.last_price <= stock.price:
			color = Color(0, 1, 0)
	total_assets = asset_value
	market_impact_display_time = max(0.0, market_impact_display_time - timer.wait_time)

func _capture_hq_reveal()->void:
	if not market_hq_revealed and Global.hope_discarded and Global.death:
		market_hq_revealed = true
		save_stocks()

func _tick_company(company, elapsed:float)->void:
	company.last_price = company.price
	if company.permanently_bankrupt:
		company.price = 0.0
		company.values.append(0.0)
		if company.values.size() > 100:
			company.values.pop_front()
		return
	if company.market_collapse_time > 0.0:
		company.market_collapse_time = max(0.0, company.market_collapse_time - elapsed)
		company.price = company.market_collapse_start_price * company.market_collapse_time / MARKET_IMPACT_SECONDS
		if company.market_collapse_time <= 0.0:
			company.price = 0.0
			company.permanently_bankrupt = true
		company.values.append(company.price)
		if company.values.size() > 100:
			company.values.pop_front()
		return
	company.market_state_time -= elapsed
	if company.market_state_time <= 0.0:
		# Calm, growth, decline, and crash/recovery periods have different risks.
		var roll = rng.randf()
		if roll < 0.35:
			company.market_state = 0
		elif roll < 0.62:
			company.market_state = 1
		elif roll < 0.92:
			company.market_state = -1
		else:
			company.market_state = -2
		company.market_state_time = rng.randf_range(90.0, 240.0)
		if company.price < company.starting_price * 0.12 and company.market_state < 1:
			company.market_state = 1
	var drift = 0.00005
	var noise = 0.006 + min(company.volatility, 15.0) * 0.0005
	match company.market_state:
		1:
			drift = 0.0012
		-1:
			drift = -0.0006
		-2:
			drift = -0.002
	var change = drift * elapsed + rng.randfn() * noise * sqrt(elapsed)
	if company.market_impulse_time > 0.0:
		var impulse_step = min(elapsed, company.market_impulse_time)
		var impulse_change = company.market_impulse * impulse_step / company.market_impulse_time
		change += impulse_change
		company.market_impulse -= impulse_change
		company.market_impulse_time -= impulse_step
	var price_floor = max(0.9, company.starting_price * 0.03)
	if company.market_event_floor > 0.0:
		price_floor = min(price_floor, company.market_event_floor)
	company.price = clamp(company.price * exp(change), price_floor, max(company.starting_price * 20.0, company.last_price))
	company.values.append(company.price)
	if company.values.size() > 100:
		company.values.pop_front()

func market_outlook(level_index:int)->String:
	_capture_hq_reveal()
	if level_index == 0 and not market_hq_revealed:
		return ""
	if not MISSION_MARKET_EVENTS.has(level_index) or market_events_applied.has(level_index):
		return ""
	var event = MISSION_MARKET_EVENTS[level_index]
	return event.mission + ": " + event.outlook

func stock_outlook(ticker:String)->String:
	for level_index in MISSION_MARKET_EVENTS:
		if market_events_applied.has(level_index):
			continue
		for effect in MISSION_MARKET_EVENTS[level_index].effects:
			if effect.ticker == ticker or effect.ticker == "ALL":
				return market_outlook(level_index)
	return ""

func market_forecast_entries()->Array:
	_capture_hq_reveal()
	var entries = []
	for level_index in range(19):
		if level_index == 0 and not market_hq_revealed:
			continue
		if not MISSION_MARKET_EVENTS.has(level_index):
			continue
		if market_events_applied.has(level_index):
			continue
		if level_index <= 12 and level_index > Global.LEVELS_UNLOCKED:
			continue
		if level_index >= 13 and not Global.BONUS_UNLOCK.has(Global.BONUS_LEVELS[level_index - 13]):
			continue
		var event = MISSION_MARKET_EVENTS[level_index]
		entries.append({"mission": event.mission, "description": event.outlook, "effects": event.effects})
	return entries

func market_forecast_lines()->Array:
	var lines = []
	for entry in market_forecast_entries():
		lines.append(entry.mission + ":\n" + entry.description)
	return lines

func market_news_entries()->Array:
	var entries = market_news_history.duplicate(true)
	entries.invert()
	return entries

func apply_mission_market_event(level_index:int)->void:
	if not MISSION_MARKET_EVENTS.has(level_index) or market_events_applied.has(level_index):
		return
	var event = MISSION_MARKET_EVENTS[level_index]
	for effect in event.effects:
		for company in stocks:
			if effect.ticker == "ALL":
				if company.asset_type != "equity":
					continue
			elif company.ticker != effect.ticker:
				continue
			if level_index == 12 and company.ticker == "GAGA" and company.permanently_bankrupt:
				company.permanently_bankrupt = false
				company.market_collapse_time = 0.0
				company.market_collapse_start_price = 0.0
				company.market_impulse = 0.0
				company.market_impulse_time = 0.0
				company.market_event_floor = 0.0
				company.price = company.starting_price
				company.last_price = company.price
			if effect.percent == -100:
				company.market_collapse_start_price = company.price
				company.market_collapse_time = MARKET_IMPACT_SECONDS
				company.market_impulse = 0.0
				company.market_impulse_time = 0.0
				if effect.ticker != "ALL":
					break
				continue
			if company.permanently_bankrupt or company.market_collapse_time > 0.0:
				if effect.ticker != "ALL":
					break
				continue
			if effect.percent == -99:
				company.market_event_floor = max(0.001, company.price * 0.001)
			company.market_impulse += log(1.0 + float(effect.percent) / 100.0)
			company.market_impulse_time = MARKET_IMPACT_SECONDS
			company.market_state = 1 if effect.percent > 0 else -1
			company.market_state_time = rng.randf_range(120.0, 240.0)
			if effect.ticker != "ALL":
				break
	market_events_applied.append(level_index)
	market_news_history.append({"mission": event.mission, "effects": event.effects.duplicate(true)})
	market_impact_display_time = MARKET_IMPACT_SECONDS
	save_stocks()

func implant_company_ticker(implant)->String:
	if implant.i_name == "Surveillance Eyecam PRO MAX":
		return "SCRD"
	var ticker = "CSFT"
	if implant.head:
		ticker = "PURE"
	elif implant.torso:
		ticker = "GDHD"
	elif implant.legs:
		ticker = "GTC "
	elif implant.arms:
		ticker = "SCRD"
	return ticker

func implant_company_name(implant)->String:
	if implant.price <= 0:
		return ""
	var ticker = implant_company_ticker(implant)
	for company in stocks:
		if company.ticker == ticker:
			return company.s_name + " (" + ticker.strip_edges() + ")"
	return ""

func implant_price(implant)->int:
	if implant.price <= 0:
		return implant.price
	var ticker = implant_company_ticker(implant)
	for company in stocks:
		if company.ticker == ticker:
			var relative = company.price / max(company.starting_price, 0.9)
			return int(max(1, round(implant.price * clamp(1.0 + 0.15 * log(relative), 0.75, 1.35))))
	return implant.price


func _physics_process(delta):
	if Global.implants.head_implant.market_enhancer:
		timer.wait_time = 0.1
	else :
		timer.wait_time = 1
	
		
	t += 1
		
	
	if fmod(t, 10) != 0:
			return 
	


func stock_save()->Dictionary:
	var stocks_dict:Dictionary
	stocks_dict["market_events_version"] = 7
	stocks_dict["market_events_applied"] = market_events_applied
	stocks_dict["market_news_history"] = market_news_history
	stocks_dict["market_impact_display_time"] = market_impact_display_time
	stocks_dict["market_hq_revealed"] = market_hq_revealed
	for stock in stocks:
		
		stocks_dict[stock.ticker] = stock.get_data()
		stocks_dict["fish_found"] = FISH_FOUND
		stocks_dict["org_found"] = ORGANS_FOUND
	return stocks_dict

func save_stocks(path = "user://stocks.save")->void :
	if Global.campaign_save.active:
		return
	if path in ["user://stocks.save", "user://stock_backup.save"]:
		path = Global.slot_path(path.get_file())
	var st = File.new()
	st.open(path, File.WRITE)
	st.store_line(to_json(stock_save()))
	st.close()

func load_stocks()->void :
	var stocks_save = File.new()
	var primary_path = Global.slot_path("stocks.save")
	var backup_path = Global.slot_path("stock_backup.save")
	if not stocks_save.file_exists(primary_path):
		save_stocks("user://stocks.save")
	
	
	
	

	
	

	
	
	stocks_save.open(primary_path, File.READ)
	if stocks_save.get_len() < 2:
		stocks_save.close()
		if not stocks_save.file_exists(backup_path):
			save_stocks()
			stocks_save.open(primary_path, File.READ)
		else :
			stocks_save.open(backup_path, File.READ)
			if stocks_save.get_len() < 2:
				stocks_save.close()
				save_stocks()
				stocks_save.open(primary_path, File.READ)
	
	var parsedJSON:Dictionary = {}
	parsedJSON = parse_json(stocks_save.get_line())
	var saved_market_event_version = int(parsedJSON.get("market_events_version", 0))
	market_events_applied = []
	market_news_history = []
	market_impact_display_time = float(parsedJSON.get("market_impact_display_time", 0.0)) if saved_market_event_version >= 5 else 0.0
	market_hq_revealed = bool(parsedJSON.get("market_hq_revealed", false)) if saved_market_event_version >= 5 else false
	if saved_market_event_version >= 3:
		for level_index in parsedJSON.get("market_events_applied", []):
			var normalized_index = int(level_index)
			if not market_events_applied.has(normalized_index):
				market_events_applied.append(normalized_index)
	if saved_market_event_version >= 4:
		market_news_history = parsedJSON.get("market_news_history", []).duplicate(true)
	elif saved_market_event_version == 3:
		for level_index in market_events_applied:
			if not MISSION_MARKET_EVENTS.has(level_index):
				continue
			var old_event = MISSION_MARKET_EVENTS[level_index]
			var old_effects = old_event.effects.duplicate(true)
			if level_index == 13:
				old_effects[0].percent = 6
			market_news_history.append({"mission": old_event.mission, "effects": old_effects})
	if saved_market_event_version == 5:
		for changed_level in [12, 17, 18]:
			market_events_applied.erase(changed_level)
		var retained_history = []
		for old_entry in market_news_history:
			if ["Archon Grid", "House", "Trauma Loop"].has(old_entry.mission):
				continue
			retained_history.append(old_entry)
		market_news_history = retained_history
		market_impact_display_time = 0.0
	if saved_market_event_version >= 5 and saved_market_event_version < 7:
		market_events_applied.erase(0)
		var hq_was_latest = not market_news_history.empty() and market_news_history.back().mission == "Cruelty Squad Headquarters"
		var retained_hq_history = []
		for old_entry in market_news_history:
			if old_entry.mission == "Cruelty Squad Headquarters":
				continue
			retained_hq_history.append(old_entry)
		market_news_history = retained_hq_history
		if hq_was_latest:
			market_impact_display_time = 0.0
	var fish_found = parsedJSON.get("fish_found")
	if fish_found != null:
		FISH_FOUND = fish_found
	var org_found = parsedJSON.get("org_found")
	if org_found != null:
		ORGANS_FOUND = org_found
	for stock in stocks:
		var stock_data = parsedJSON.get(stock.ticker)
		if stock_data:
			var price = stock_data["price"]
			stock.price = price
			var trend = stock_data["trend"]
			stock.trend = trend
			var owned = stock_data["owned"]
			stock.owned = owned
			stock.market_state = stock_data.get("market_state", 0)
			stock.market_state_time = stock_data.get("market_state_time", 0.0)
			stock.market_impulse = stock_data.get("market_impulse", 0.0)
			stock.market_impulse_time = stock_data.get("market_impulse_time", 0.0)
			stock.market_collapse_time = stock_data.get("market_collapse_time", 0.0)
			stock.market_collapse_start_price = stock_data.get("market_collapse_start_price", 0.0)
			stock.market_event_floor = stock_data.get("market_event_floor", 0.0)
			stock.permanently_bankrupt = stock_data.get("permanently_bankrupt", false)
			if saved_market_event_version < 3:
				stock.market_impulse = 0.0
				stock.market_impulse_time = 0.0
			elif saved_market_event_version == 4:
				stock.market_impulse_time *= 2.0
				if stock.market_collapse_time > 0.0:
					stock.market_collapse_time *= 2.0
					stock.market_collapse_start_price = stock.price * MARKET_IMPACT_SECONDS / stock.market_collapse_time
			if stock.permanently_bankrupt:
				stock.price = 0.0
				stock.market_collapse_time = 0.0
	stocks_save.close()



