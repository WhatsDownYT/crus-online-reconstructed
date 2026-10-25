extends Node

var failures = 0

func check(condition, label):
	print("MARKET_CHECK ", label, "=", condition)
	if not condition:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(5), "timeout")
	Global.select_save_slot(2)
	var market = Global.STOCKS
	market.timer.stop()
	market.market_events_applied.clear()
	market.save_stocks()
	check(market.market_outlook(5).find("GamesGames") >= 0, "mission forecast visible")
	check(market.stock_outlook("GAGA").find("speculative surge") >= 0, "company forecast uses descriptive copy")
	check(market.market_outlook(5).find("%") == -1, "forecast hides exact percentages")
	check(market.MISSION_MARKET_EVENTS.size() == 18 and not market.MISSION_MARKET_EVENTS.has(17), "House has no market event")
	check(market.MISSION_MARKET_EVENTS[12].effects[0].ticker == "ALL" and market.MISSION_MARKET_EVENTS[12].effects[0].percent == 99, "Archon raises every company stock")
	check(market.MISSION_MARKET_EVENTS[18].effects[0].ticker == "ALL" and market.MISSION_MARKET_EVENTS[18].effects[0].percent == -99, "Trauma lowers every company stock")
	var decisive_copy = true
	for market_event in market.MISSION_MARKET_EVENTS.values():
		if market_event.outlook.find(" may ") >= 0:
			decisive_copy = false
	check(decisive_copy, "market descriptions use will rather than may")
	market.market_hq_revealed = false
	var previous_hope = Global.hope_discarded
	var previous_death = Global.death
	Global.hope_discarded = false
	Global.death = false
	check(market.market_outlook(0) == "", "HQ outlook hidden before both states")
	Global.hope_discarded = true
	Global.death = true
	check(market.market_outlook(0).find("Headquarters") >= 0, "HQ outlook appears after both states")
	check(market.MISSION_MARKET_EVENTS[0].effects[0].percent == 200 and market.MISSION_MARKET_EVENTS[0].effects[1].percent == -35, "HQ takeover raises CRUS and lowers SCRD")
	Global.hope_discarded = previous_hope
	Global.death = previous_death
	market.save_stocks()
	market.load_stocks()
	check(market.market_hq_revealed, "HQ outlook unlock persists in slot")
	check(market.MISSION_MARKET_EVENTS[13].effects.size() == 1 and market.MISSION_MARKET_EVENTS[13].effects[0].percent == -6, "Darkworld has only a small CRUS loss")
	var valid_outlooks = true
	for entry in market.market_forecast_entries():
		if entry.effects.empty() or entry.description.empty() or entry.description.find("%") >= 0:
			valid_outlooks = false
	check(valid_outlooks, "market outlooks group varying effects")
	var gamesgames = null
	var pizza = null
	for company in market.stocks:
		if company.ticker == "GAGA":
			gamesgames = company
		if company.ticker == "PIHO":
			pizza = company
	check(gamesgames != null, "company exists")
	check(pizza != null, "falling company exists")
	if gamesgames != null and pizza != null:
		gamesgames.price = gamesgames.starting_price
		gamesgames.last_price = gamesgames.price
		gamesgames.permanently_bankrupt = false
		gamesgames.market_collapse_time = 0.0
		gamesgames.market_collapse_start_price = 0.0
		gamesgames.market_impulse = 0.0
		gamesgames.market_impulse_time = 0.0
		pizza.price = pizza.starting_price
		pizza.market_impulse = 0.0
		pizza.market_impulse_time = 0.0
		market.apply_mission_market_event(5)
		check(gamesgames.market_impulse > 0.0 and gamesgames.market_impulse_time == 20.0, "mission starts twenty-second impact")
		check(pizza.market_impulse < 0.0 and pizza.market_impulse_time == 20.0, "mission starts paired decline")
		check(market.market_outlook(5) == "", "realized forecast clears")
		check(market.market_news_entries()[0].effects[0].percent == 286, "completed event appears in market news")
		for second in range(20):
			market._tick_company(gamesgames, 1.0)
		check(gamesgames.price > gamesgames.starting_price * 3.0, "Mall sharply raises GAGA")
		for second in range(20):
			market._tick_company(pizza, 1.0)
		check(pizza.price < pizza.starting_price, "mission lowers paired company over time")
		var first_price = gamesgames.price
		market.apply_mission_market_event(5)
		check(gamesgames.price == first_price, "mission event cannot repeat")
		market.save_stocks()
		market.load_stocks()
		check(market.market_events_applied.has(5), "event persists in slot")
		check(market.market_news_entries()[0].effects[0].percent == 286, "market news persists in slot")
		check(is_equal_approx(gamesgames.price, first_price), "company price persists in slot")
		market.apply_mission_market_event(6)
		check(gamesgames.market_collapse_time == 20.0, "Apartment starts twenty-second GAGA collapse")
		for second in range(10):
			market._tick_company(gamesgames, 1.0)
		check(gamesgames.price > 0.0 and gamesgames.price < first_price, "GAGA declines during collapse")
		market.save_stocks()
		market.load_stocks()
		check(gamesgames.market_collapse_time == 10.0, "collapse countdown persists in slot")
		for second in range(10):
			market._tick_company(gamesgames, 1.0)
		check(gamesgames.price == 0.0 and gamesgames.permanently_bankrupt, "GAGA reaches permanent zero")
		for second in range(30):
			market._tick_company(gamesgames, 1.0)
		check(gamesgames.price == 0.0, "bankrupt GAGA cannot recover")
		market.save_stocks()
		market.load_stocks()
		check(gamesgames.price == 0.0 and gamesgames.permanently_bankrupt, "bankruptcy persists in slot")
	var head = null
	for implant in Global.implants.IMPLANTS:
		if implant.head and implant.price > 0:
			head = implant
			break
	check(head != null, "priced implant exists")
	if head != null:
		var pure = null
		for company in market.stocks:
			if company.ticker == "PURE":
				pure = company
				break
		check(pure != null, "linked company exists")
		if pure != null:
			check(market.implant_company_name(head).find("PURE") >= 0, "implant company disclosed")
			pure.price = pure.starting_price
			check(market.implant_price(head) == head.price, "baseline quote unchanged")
			pure.price = pure.starting_price * 10.0
			check(market.implant_price(head) > head.price, "rising shares raise quote")
			pure.price = pure.starting_price * 0.05
			check(market.implant_price(head) < head.price, "falling shares lower quote")
	var menu = Global.menu
	menu.show()
	if head != null:
		var equipment = menu.get_node("Character_Menu/Character_Container")
		var equipment_panel = menu.get_node("Character_Menu")
		var implant_index = Global.implants.IMPLANTS.find(head)
		equipment_panel.show()
		equipment._show_implant_info(implant_index)
		var tooltip_panel = equipment.hover_info.get_parent()
		equipment_panel.hide()
		tooltip_panel.hide()
		for company in market.stocks:
			if company.ticker == "PURE":
				company.price *= 1.1
				break
		equipment._process(0.0)
		check(not tooltip_panel.visible and equipment.hovered_implant_index == -1, "closed implant menu cannot rewrite tooltip")
	var stock_screen = menu.get_node("Stock_Menu")
	stock_screen.show()
	stock_screen.raise()
	if gamesgames != null:
		var market_ui = stock_screen.get_node("Character_Container")
		market_ui.selected_stock = gamesgames
		var owned_before = gamesgames.owned
		market_ui._on_Buy_Button_pressed(1)
		check(gamesgames.owned == owned_before, "bankrupt GAGA cannot be bought")
		market_ui.t = 4
		market_ui._physics_process(0.0)
		check(market_ui.get_node("VBoxContainer/ColorRect2/VBoxContainer/BuyHBox/Buy_Button").disabled, "bankrupt GAGA buy control is disabled")
		market_ui._refresh_outlook()
		check(market_ui.outlook_scroll.visible and market_ui.outlook_list.get_child_count() > 0, "market outlook displays descriptive forecasts")
		var hq_group = market_ui.outlook_list.get_child(0)
		check(hq_group.get_child(0).text == "Cruelty Squad Headquarters:" and hq_group.get_child(2).get_child_count() == 2, "rising and falling tickers have separate rows")
		var previous_level_unlock = Global.LEVELS_UNLOCKED
		var had_trauma_unlock = Global.BONUS_UNLOCK.has("END")
		Global.LEVELS_UNLOCKED = 12
		if not had_trauma_unlock:
			Global.BONUS_UNLOCK.append("END")
		market_ui._refresh_outlook()
		var company_count = 0
		for asset in market.stocks:
			if asset.asset_type == "equity":
				company_count += 1
		var archon_group = null
		var trauma_group = null
		for outlook_group in market_ui.outlook_list.get_children():
			if outlook_group.get_child(0).text == "Archon Grid:":
				archon_group = outlook_group
			if outlook_group.get_child(0).text == "Trauma Loop:":
				trauma_group = outlook_group
		check(archon_group != null and archon_group.get_child(2).get_child_count() == company_count and archon_group.get_child(2).get_child(0).text == "CRUS UP", "Archon lists each company on its own line")
		check(trauma_group != null and trauma_group.get_child(2).get_child_count() == company_count and trauma_group.get_child(2).get_child(0).text == "CRUS DOWN", "Trauma lists each company on its own line")
		Global.LEVELS_UNLOCKED = previous_level_unlock
		if not had_trauma_unlock:
			Global.BONUS_UNLOCK.erase("END")
		market_ui._refresh_outlook()
		market_ui._refresh_latest_impact()
		check(market_ui.impact_row.get_child_count() == 3, "latest mission impacts appear on the outlook header")
		yield(get_tree(), "idle_frame")
		var outlook_preview = get_viewport().get_texture().get_data()
		outlook_preview.flip_y()
		outlook_preview.save_png("res://market_outlook_preview.png")
		market.market_news_history.append({"mission": "Mall Madness", "effects": market.MISSION_MARKET_EVENTS[5].effects.duplicate(true)})
		market_ui._refresh_latest_impact()
		yield(get_tree(), "idle_frame")
		check(market_ui.impact_row.rect_global_position.x + market_ui.impact_row.rect_size.x <= market_ui.outlook_scroll.rect_global_position.x + market_ui.outlook_scroll.rect_size.x, "four-impact summary fits in outlook header")
		var outlook_heading = market_ui.impact_row.get_parent().get_child(0)
		check(outlook_heading.rect_global_position.x + outlook_heading.rect_size.x <= market_ui.impact_row.rect_global_position.x, "outlook heading and impacts stay separate")
		var full_impact_preview = get_viewport().get_texture().get_data()
		full_impact_preview.flip_y()
		full_impact_preview.save_png("res://market_full_impact_preview.png")
		market.market_news_history.pop_back()
		market.market_impact_display_time = 1.0
		market.stock_tick()
		market_ui._refresh_latest_impact()
		check(market.market_impact_display_time == 0.0 and market_ui.impact_row.get_child_count() == 0, "impact summary clears when movement ends")
		var previous_events = market.market_events_applied.duplicate()
		market.market_events_applied = market.MISSION_MARKET_EVENTS.keys()
		market_ui._refresh_outlook()
		check(market_ui.outlook_list.get_child_count() == 1 and market_ui.outlook_list.get_child(0).text == "No outlooks available.", "empty outlook message is concise")
		market.market_events_applied = previous_events
		var non_company = null
		for asset in market.stocks:
			if asset.asset_type != "equity":
				non_company = asset
				break
		var non_company_price = non_company.price if non_company != null else 0.0
		market.apply_mission_market_event(12)
		check(not gamesgames.permanently_bankrupt and is_equal_approx(gamesgames.price, gamesgames.starting_price), "Archon revives GAGA at its listing price")
		var all_archon_impacted = true
		for asset in market.stocks:
			if asset.asset_type == "equity" and asset.market_impulse_time != 20.0:
				all_archon_impacted = false
		check(all_archon_impacted, "Archon affects every company")
		check(non_company == null or non_company.price == non_company_price, "market-wide event excludes fish and body parts")
		for second in range(20):
			market._tick_company(gamesgames, 1.0)
		check(gamesgames.price > gamesgames.starting_price * 1.7, "revived GAGA receives the Archon gain")
		var previous_prices = {}
		for asset in market.stocks:
			if asset.asset_type == "equity":
				previous_prices[asset.ticker] = asset.price
		market.apply_mission_market_event(18)
		var all_trauma_impacted = true
		for asset in market.stocks:
			if asset.asset_type != "equity":
				continue
			for second in range(20):
				market._tick_company(asset, 1.0)
			if asset.price > previous_prices[asset.ticker] * 0.05:
				all_trauma_impacted = false
		check(all_trauma_impacted, "Trauma's loss reaches every company below the normal price floor")
		var crus_company = null
		var scrd_company = null
		for asset in market.stocks:
			if asset.ticker == "CRUS":
				crus_company = asset
			if asset.ticker == "SCRD":
				scrd_company = asset
		if crus_company != null and scrd_company != null:
			for asset in [crus_company, scrd_company]:
				asset.price = asset.starting_price
				asset.market_impulse = 0.0
				asset.market_impulse_time = 0.0
				asset.market_event_floor = 0.0
			market.apply_mission_market_event(0)
			for second in range(20):
				market._tick_company(crus_company, 1.0)
				market._tick_company(scrd_company, 1.0)
			check(crus_company.price > crus_company.starting_price * 2.5, "CEO takeover sends CRUS sharply upward")
			check(scrd_company.price < scrd_company.starting_price * 0.75, "CEO takeover hurts SCRD")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var preview = get_viewport().get_texture().get_data()
	preview.flip_y()
	preview.save_png("res://market_ui_preview.png")
	var clearing = menu._on_ClearSave_pressed()
	menu._on_ConfirmationDialog_confirmed()
	if clearing is GDScriptFunctionState:
		yield(clearing, "completed")
	yield(get_tree().create_timer(6), "timeout")
	check(not Global.save_slot_selected and not Global.force_save_selector, "clear save returned to slot selection")
	if gamesgames != null:
		check(not gamesgames.permanently_bankrupt and gamesgames.price == gamesgames.starting_price, "clear save resets GAGA bankruptcy")
	var selector_preview = get_viewport().get_texture().get_data()
	selector_preview.flip_y()
	selector_preview.save_png("res://market_clear_slot_preview.png")
	print("MARKET_TEST_RESULT failures=", failures)
	get_tree().quit(1 if failures else 0)
