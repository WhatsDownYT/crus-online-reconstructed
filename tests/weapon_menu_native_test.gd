extends Node

var failures = 0

func check(condition, message):
	print("WEAPON_MENU_CHECK ", message, " = ", condition)
	if not condition:
		failures += 1

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	call_deferred("run")

func run():
	yield(get_tree().create_timer(6.0), "timeout")
	var game_menu = Global.menu
	var level_menu = game_menu.menu[game_menu.LEVEL_SELECT]
	check(level_menu.get_child(4).name == "Weapons", "one Weapons entry before Equipment")
	check(level_menu.get_child(5).name == "Equipment & Implants", "Equipment follows Weapons")
	check(level_menu.get_child(1).name == "Online" and level_menu.get_child(2).name == "Goals" and level_menu.get_child(3).name == "Statistics", "Online, Goals and Statistics moved to level select")
	check(game_menu.menu[game_menu.START].get_child_count() == 7, "main menu no longer contains those buttons")
	for icon_entry in [[level_menu.get_child(4), "weapons.png"], [level_menu.get_child(2), "goals.png"], [level_menu.get_child(3), "stats.png"], [game_menu.menu[game_menu.START].get_child(6), "news.png"]]:
		var source_icon = Image.new()
		var loaded = source_icon.load("res://MOD_CONTENT/CruS Online/" + icon_entry[1]) == OK
		check(loaded and icon_entry[0].texture_normal != null and icon_entry[0].texture_normal.get_data().get_data() == source_icon.get_data(), icon_entry[1] + " used for menu square")
	var opening = game_menu.goto_menu(game_menu.START, game_menu.LEVEL_SELECT, game_menu.menu[game_menu.START].get_child(0))
	if opening is GDScriptFunctionState:
		yield(opening, "completed")
	game_menu._on_Weapon_1_Pressed(game_menu.LEVEL_SELECT, level_menu.get_child(4))
	yield(get_tree().create_timer(1.0), "timeout")
	check(game_menu.active_menus.back() == game_menu.menu[game_menu.WEAPON_SELECT], "weapon page opens")
	check(game_menu.weapon_menu_panel.visible, "implant-style weapon background visible")
	check(game_menu.weapon_menu_panel.get_stylebox("panel").texture == game_menu.get_node("Character_Menu").get_stylebox("panel").texture, "weapon page uses the implant background texture")
	check(game_menu.weapon_menu_panel.get_stylebox("panel").region_rect == game_menu.get_node("Character_Menu").get_stylebox("panel").region_rect, "weapon page keeps the implant frame layout")
	check(game_menu.weapon_menu_slot_buttons[0].texture_normal == game_menu.get_node("Weapon1_Viewport").get_texture(), "first slot uses live sidebar weapon preview")
	check(game_menu.weapon_menu_slot_buttons[1].texture_normal == game_menu.get_node("Weapon2_Viewport").get_texture(), "second slot uses live sidebar weapon preview")
	check(game_menu.weapon_menu_slot_buttons[0].rect_size == Vector2(185, 79), "weapon previews match sidebar size")
	check(level_menu.visible, "level-select squares remain behind weapon page")
	check(game_menu.weapon_menu_slot_buttons[0].rect_position.y == 140 and game_menu.weapon_menu_slot_outlines[0].rect_position.y == 12, "weapon previews sit above the grid")
	check(game_menu.weapon_menu_slot_outlines[0].material.get_shader_param("outline_width") == 1.25, "weapon outline is thinner than Statistics outline")
	check(game_menu.weapon_menu_panel.get_index() > level_menu.get_index() and game_menu.menu[game_menu.WEAPON_SELECT].get_index() > game_menu.weapon_menu_panel.get_index(), "weapon background covers level squares")
	check(game_menu.menu[game_menu.WEAPON_SELECT].get_child_count() == Global.WEAPONS_UNLOCKED.size() + 4, "two slots, all weapons, and two page arrows present")
	check(game_menu.weapon_page_buttons[0].rect_position == Vector2(160, 576) and game_menu.weapon_page_buttons[1].rect_position == Vector2(544, 576), "page arrows sit beneath the weapon grid")
	check(game_menu.weapon_page_buttons[0].visible and game_menu.weapon_page_buttons[1].visible, "page arrows show for the integrated F2500")
	check(game_menu.weapon_page_label.text == "Cruelty Squad", "base weapon page is labeled Cruelty Squad")
	check(game_menu.weapon_page_label.visible, "weapon page title shows with another page")
	check(game_menu.weapon_menu_portrait.rect_size == Vector2(152, 152) and game_menu.weapon_menu_description.rect_position.y == game_menu.weapon_menu_name.rect_position.y + game_menu.weapon_menu_name.rect_size.y + 4, "weapon portrait and description use the tighter layout")
	var x20_stats = game_menu._weapon_stats(game_menu.W_AR)
	check(x20_stats[0] == "Type: Assault Rifle" and x20_stats[1] == "Ammo: 45/90 (135)" and x20_stats[4] == "Damage: 20" and x20_stats[5] == "Weight: Medium" and x20_stats[6] == "Armor Piercing: No", "K&H X20 stats match weapon data")
	check(x20_stats[3].begins_with("Ammunition: 4.73") and x20_stats[3].ends_with("33mm Caseless"), "K&H X20 uses correct caseless ammunition")
	var all_stats_present = true
	for weapon_index in range(29):
		if game_menu._weapon_stats(weapon_index).size() != 7:
			all_stats_present = false
	check(all_stats_present, "every base weapon has its six stats and an optional launcher row")
	game_menu._on_Weapon_Next_Page_Pressed(game_menu.WEAPON_SELECT, game_menu.weapon_page_buttons[1])
	check(game_menu.weapon_page_label.text == "Custom" and game_menu.custom_weapon_buttons[0].visible, "integrated F2500 appears on Custom page")
	game_menu._on_Weapon_Prev_Page_Pressed(game_menu.WEAPON_SELECT, game_menu.weapon_page_buttons[0])
	check(game_menu._weapon_button_for_index(game_menu.W_ROD).texture_normal == game_menu.MYSTERY or Global.WEAPONS_UNLOCKED[game_menu.W_ROD], "locked weapon uses mystery portrait")
	if not Global.WEAPONS_UNLOCKED[game_menu.W_ROD]:
		var locked_weapon = game_menu._weapon_button_for_index(game_menu.W_ROD)
		check(locked_weapon.modulate == Color.white and locked_weapon.name != "???", "mystery portrait is not red or renamed")
		game_menu._weapon_detail_button(locked_weapon)
		check(game_menu.weapon_menu_name.text == "???", "locked weapon detail is exactly three question marks")
	game_menu._on_Weapon_Menu_Slot_2_Pressed(game_menu.WEAPON_SELECT, game_menu.weapon_menu_slot_buttons[1])
	check(game_menu.current_weapon_select == 2, "slot two selected without closing page")
	check(game_menu.weapon_menu_slot_outlines[1].material.get_shader_param("selected") and not game_menu.weapon_menu_slot_outlines[0].material.get_shader_param("selected"), "selected preview uses the Statistics green outline")
	var closing = game_menu.go_back(game_menu.WEAPON_SELECT, level_menu.get_child(4))
	if closing is GDScriptFunctionState:
		yield(closing, "completed")
	check(game_menu.active_menus.back() == level_menu, "weapon page closes to level select")
	check(not game_menu.weapon_menu_panel.visible, "weapon background hidden on exit")
	check(level_menu.visible, "level-select squares remain visible on exit")
	check(level_menu.get_child(0).rect_position.y == game_menu.level_select_origin.y + game_menu.button_size.y, "level return moves down one cell")
	check(level_menu.get_child(1).rect_position.y == game_menu.level_select_origin.y + game_menu.button_size.y * 2, "Online sits above Weapons")
	check(level_menu.get_child(4).rect_position.y == game_menu.level_select_origin.y + game_menu.button_size.y * 3, "Weapons moves down two cells")
	game_menu._on_Goals_Button_Pressed(game_menu.LEVEL_SELECT, level_menu.get_child(2))
	yield(get_tree().create_timer(0.25), "timeout")
	check(game_menu.active_menus.back() == game_menu.menu[game_menu.GOALS], "Goals opens from level select")
	var goals_close = game_menu.go_back(game_menu.GOALS, game_menu.menu[game_menu.GOALS].get_child(0))
	if goals_close is GDScriptFunctionState:
		yield(goals_close, "completed")
	game_menu._on_Statistics_Button_Pressed(game_menu.LEVEL_SELECT, level_menu.get_child(3))
	yield(get_tree().create_timer(0.25), "timeout")
	check(game_menu.active_menus.back() == game_menu.menu[game_menu.STATS], "Statistics opens from level select")
	var stats_close = game_menu.go_back(game_menu.STATS, game_menu.menu[game_menu.STATS].get_child(0))
	if stats_close is GDScriptFunctionState:
		yield(stats_close, "completed")
	game_menu._on_Multiplayer_Button_Pressed(game_menu.LEVEL_SELECT, level_menu.get_child(1))
	yield(get_tree().create_timer(1.0), "timeout")
	check(game_menu.online_navigation_active, "Online opens from level select")
	check(level_menu.get_child(1).name == "Online" and level_menu.get_child(1).get_meta("display_name") == "Return", "Online Return label does not rename the node")
	game_menu._on_mouse_entered(game_menu.LEVEL_SELECT, level_menu.get_child(1))
	check(game_menu.hover_info.get_node("Name").text == "Return", "Online hover shows plain Return")
	var online_close = game_menu.close_online_navigation()
	if online_close is GDScriptFunctionState:
		yield(online_close, "completed")
	check(not game_menu.online_navigation_active, "Online closes back to level select")
	check(not level_menu.get_child(1).has_meta("display_name"), "Online label resets when its panel closes")
	var level_close = game_menu.go_back(game_menu.LEVEL_SELECT, level_menu.get_child(0))
	if level_close is GDScriptFunctionState:
		yield(level_close, "completed")
	var main_buttons = game_menu.menu[game_menu.START].get_children()
	check(main_buttons[5].rect_position == main_buttons[1].rect_position + Vector2(game_menu.button_size.x, 0), "Quit sits next to Settings")
	game_menu.register_campaigns([{"id": "cruelty_squad", "name": "Cruelty Squad", "indices": range(19)}, {"id": "custom_missions", "name": "Custom Missions", "indices": []}])
	check(game_menu.campaign_pages.size() == 1 and game_menu.page_buttons.empty(), "empty custom missions do not add campaign arrows")
	var implant_menu = game_menu.get_node("Character_Menu/Character_Container")
	var implant_pages = implant_menu._available_pages()
	check(implant_pages is Array and implant_pages.size() == 2 and implant_pages.has(0) and implant_pages.has(1), "empty custom implants are excluded from navigation")
	game_menu._on_News_Button_Pressed(game_menu.START, main_buttons[6])
	yield(get_tree().create_timer(0.25), "timeout")
	check(game_menu.menu[game_menu.NEWS].get_child(0).rect_position == main_buttons[6].rect_position + Vector2(0, game_menu.button_size.y), "News Return sits one square lower")
	var news_close = game_menu.go_back(game_menu.NEWS, game_menu.menu[game_menu.NEWS].get_child(0))
	if news_close is GDScriptFunctionState:
		yield(news_close, "completed")
	game_menu._on_Settings_Button_Pressed(game_menu.START, main_buttons[1])
	yield(get_tree().create_timer(0.25), "timeout")
	check(game_menu.menu[game_menu.SETTINGS].get_child(0).rect_position == main_buttons[1].rect_position + Vector2(0, game_menu.button_size.y), "Settings Return sits one square lower")
	print("WEAPON_MENU_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
