extends RichTextLabel

var cheats = null
var active = false
var already_paused = false

const prompt_prefix = "> "

static func strip_prefix(input: String) -> String:
	return input.trim_prefix(prompt_prefix)

class KeySorter:
	static func sort_longest(a: String, b: String) -> bool:
		return a.length() < b.length()


	static func longest_item_length(strArr: Array) -> int:
		assert(typeof(strArr) == TYPE_ARRAY and typeof(strArr[0]) == TYPE_STRING,
				'Function requires string array of non-zero length.')

		var copy = Array(strArr)
		copy.sort_custom(KeySorter, "sort_longest")
		return copy[0].length() if copy[0] else -1

enum COMMANDS {
	HELP

	EXIT
	QUIT

	FFA
	JUMP
	INFIMPLANT
	AI
	INFAMMO
	NOCLIP
	DEBUGMENU
	INVISIBLE
	DEATHMODE
	GOD
}



class CompState:
	func _init(commands: Array):
		if commands.size() <= 0:
			push_error('Empty command list.')

	var last:        String
	var last_prefix: String
	var fresh:       bool
	var last_idx:    int


	func advance_idx() -> void:
		last_idx = (last_idx + 1) % command_count()

	func log(msg: String) -> void:
		Mod.mod_log(msg,  'CompState')



	func clear_state() -> void:
		last        = EMPTY_STR
		last_prefix = EMPTY_STR
		fresh       = false
		last_idx    = NULL_INDEX

	func dump_state() -> void:
		self.log(
			'State:\nlast_completion:        %s\nlast_completion_idx:    %s\nlast_completion_prefix: %s\nlast_completion_fresh:  %s' % [
			last,
			last_idx,
			last_prefix,
			fresh
		])






	var _commands

	func _set_commands_array(new_commands):
		if typeof(new_commands) == TYPE_ARRAY:
			_commands = new_commands

			_commands.sort_custom(KeySorter, "sort_longest")

			self.log('Set new command list.')

	func _get_commands_array() -> Array:
		return _commands

	var commands setget _set_commands_array, _get_commands_array



	func command_count() -> int:
		return _commands.size() if _commands else NULL_INDEX


	var _command_index =  -1


	func _get_current_command():
		if last_idx >= 0:
			return

	enum { NULL_INDEX = -1, }
	const EMPTY_STR = '\r'



var commands = Array(COMMANDS.keys())
var command_count = commands.size()

onready var longest_command_len = KeySorter.longest_item_length(commands)


var last_completion
var last_completion_prefix

var last_completion_fresh: bool = false
var last_completion_idx:   int  = -1


func reset_comp_state() -> void:
	if _online_blocked():
		return

	last_completion        = null
	last_completion_prefix = null
	last_completion_idx    = -1
	last_completion_fresh  = false

func dump_comp_state() -> void:
	if _online_blocked():
		return
	comp_log(
		'State:\nlast_completion:        %s\nlast_completion_idx:    %s\nlast_completion_prefix: %s\nlast_completion_fresh:  %s' % [
		last_completion,
		last_completion_idx,
		last_completion_prefix,
		last_completion_fresh
	])

func comp_log(msg: String) -> void:
	Mod.mod_log(msg,  'completion')



func complete_input(input: String) -> String:
	if _online_blocked():
		return ""







	if (input == "" and (null == last_completion_prefix or last_completion_prefix == "")) \
			or (last_completion_fresh and last_completion_prefix == "" and last_completion_idx >= 0):


		last_completion       = commands[last_completion_idx]
		last_completion_idx   = (last_completion_idx + 1) % command_count
		last_completion_fresh = true
		if last_completion_prefix == null:
			last_completion_prefix = ""

		return last_completion


	match input.length():
		0, longest_command_len:
			return input

		var input_len:
			if input_len > longest_command_len:
				return input

			var cmd: String
			for idx in command_count:
				cmd = commands[idx]

				if cmd.begins_with(input) and idx > last_completion_idx:

					last_completion        = cmd
					last_completion_idx    = idx
					last_completion_fresh  = true
					last_completion_prefix = input
					return cmd


			return input



func _input(ev: InputEvent):
	if _online_blocked():
		return
	if ev is InputEventKey and ev.is_pressed() and is_instance_valid(cheats):
		if Global.menu.visible:
			active = false
			self.hide()
			get_tree().paused = true
		else:
			if ev.get_scancode() == KEY_QUOTELEFT or ev.get_scancode() == KEY_F1:
				reset_comp_state()
				raise()
				active = !active
			if ev.get_scancode() == KEY_ENTER:
				reset_comp_state()
				active = false
				get_tree().paused = false
				self.hide()
				match strip_prefix(text):
					"NOCLIP":
						Global.player.UI.notify("Noclip activated, press V to toggle", Color(1, 1, 1))
						cheats.enabled.append("noclip")
						cheats.reset_noclip()
					"GOD":
						cheats.toggle_zombie()
					"INVISIBLE":
						cheats.toggle_vanish()
					"INFAMMO":
						cheats.toggle_infinite_magazine()
					"JUMP":
						cheats.toggle_infinite_jump()
					"INFIMPLANT":
						cheats.toggle_infinite_arm_aug()
					"AI":
						cheats.toggle_disable_ai()
					"DEATHMODE":
						cheats.toggle_death()
					"FFA":
						cheats.toggle_npc_ffa()
					"DEBUGMENU":
						cheats.enable_debug_menus()
					"QUIT", "EXIT":
						cheats.exit_game()

				self.text = prompt_prefix

			get_tree().paused = active
			self.visible = active

		if active and not ev.is_echo():
			var key = ev.as_text()
			if len(key) == 1:
				self.text += key

			match ev.get_scancode():
				KEY_ESCAPE:
					active = false
					self.hide()
				KEY_TAB:
					self.text = "%s%s" % [ prompt_prefix, complete_input(strip_prefix(self.text)) ]
				KEY_SPACE:
					reset_comp_state()
					self.text += " "
				KEY_BACKSPACE:
					reset_comp_state()
					if self.text.length() > 2:
						self.text = self.text.substr(0, self.text.length() - 1)
				var other_scancode:

					pass

func _online_blocked():
	var online = Global.get_node_or_null("Multiplayer")
	return online != null and is_instance_valid(online.Extensions) and not online.Extensions.resetting_cheats and online.Extensions.online_selected()
