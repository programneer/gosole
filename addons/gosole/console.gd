extends Panel

var opened = false
var fullscreen = false
var dont_type = false
@onready var log = $ScrollContainer/Log
var eol = false
@onready var scroll = log.get_v_scroll_bar()
@onready var input = $Input
var cursor = '_'
var dont_tick_cursor = false
var time_to_tick_cur = .3
var cursor_time = time_to_tick_cur
var cursor_on = false
var input_prefix = "> "
var commands = {}
var aliases = {}
var history = []
var history_index = 0

enum CommandFlags {CONFIGABLE, CHEAT}

class ConsoleCommand:
	var function:Callable
	var description:String
	var param_count:int
	var help:String
	var flags:CommandFlags
	func _init(in_function:Callable, in_description:String, in_param_count:int, in_help:String, in_flags:CommandFlags):
		function = in_function
		description = in_description
		param_count = in_param_count
		help = in_help
		flags = in_flags

class ConsoleCommandAlias:
	var cmd:String
	func _init(in_cmd:String): cmd = in_cmd

signal terminalOpened
signal terminalClosed

func register_cmd(cmd, function:Callable, description="", param_count=0, help="", flags:CommandFlags=-1): commands[cmd] = ConsoleCommand.new(function, description, param_count, help, flags)
func register_alias(alias, cmd:String): aliases[alias] = ConsoleCommandAlias.new(cmd)
func unregister_cmd(cmd): commands.erase(cmd)
func unregister_alias(cmd): aliases.erase(cmd)

func open(fullscr=false,force=false,dont_tick_cur=false):
	terminalOpened.emit()
	opened = true
	visible = true
	input.text = input_prefix
	if fullscr: fullscreen = true
	if force:
		if fullscreen: anchor_bottom = 1
		else: anchor_bottom = .5
	if !dont_tick_cur:
		input.text += cursor
		cursor_on = true
		cursor_time = time_to_tick_cur

func close(force=false):
	terminalClosed.emit()
	opened = false
	input.text = ""
	if fullscreen: fullscreen = false
	if force: anchor_bottom = 0
	if cursor_on: cursor_on = false
	cursor_time = time_to_tick_cur

func reset_cursor():
	cursor_time = time_to_tick_cur
	if !cursor_on:
		input.text += cursor
		cursor_on = true

func _input(event):
	if event is InputEventKey && event.is_pressed():
		if event.keycode == KEY_QUOTELEFT:
			if !opened: open(event.is_shift_pressed())
			else:
				if event.is_shift_pressed():
					fullscreen = !fullscreen
					return
				close()
		if opened && !dont_type:
			var keystr = event.as_text()
			if event.is_shift_pressed(): keystr = keystr.substr(6)
			else: keystr = keystr.to_lower()
			if len(keystr) == 1:
				if input.text.length() > input_prefix.length() && cursor_on: input.text = input.text.substr(0, input.text.length() - cursor.length())+keystr+cursor
				else: input.text += keystr
				reset_cursor()
			elif event.keycode == KEY_SPACE:
				if input.text.length() > input_prefix.length() && cursor_on: input.text = input.text.substr(0, input.text.length() - cursor.length())+' '+cursor
				else: input.text += ' '
				reset_cursor()
			elif event.keycode == KEY_MINUS:
				if input.text.length() > input_prefix.length() && cursor_on:
					if event.is_shift_pressed(): input.text = input.text.substr(0, input.text.length() - cursor.length())+'_'+cursor
					else: input.text = input.text.substr(0, input.text.length() - cursor.length())+'-'+cursor
				elif event.is_shift_pressed(): input.text += '_'
				else: input.text += '-'
				reset_cursor()
			elif event.keycode == KEY_PERIOD:
				if input.text.length() > input_prefix.length() && cursor_on: input.text = input.text.substr(0, input.text.length() - cursor.length())+'.'+cursor
				else: input.text += '.'
				reset_cursor()
			elif event.keycode == KEY_BACKSPACE:
				if input.text.length() > input_prefix.length():
					if cursor_on:
						if input.text.length() <= input_prefix.length() + cursor.length(): return
						input.text = input.text.substr(0, input.text.length() - 2)
						input.text += cursor
					else: input.text = input.text.substr(0, input.text.length() - 1)
					reset_cursor()
			elif event.keycode == KEY_ENTER:
				if input.text == input_prefix || cursor_on && input.text == input_prefix + cursor: return
				input.text = input.text.substr(input_prefix.length())
				if cursor_on: input.text = input.text.substr(0, input.text.length() - cursor.length())
				command(input.text)
				input.text = input_prefix
				if !dont_tick_cursor:
					if cursor_on: input.text += cursor
					reset_cursor()
				else: dont_tick_cursor = false
			elif event.keycode == KEY_UP:
				if history_index > 0:
					history_index -= 1
					if history_index >= 0:
						if cursor_on: input.text = input_prefix+history[history_index]+cursor
						else: input.text = input_prefix+history[history_index]
					reset_cursor()
			elif event.keycode == KEY_DOWN:
				if history_index < history.size():
					history_index += 1
					if history_index < history.size():
						if cursor_on: input.text = input_prefix+history[history_index]+cursor
						else: input.text = input_prefix+history[history_index]
					else:
						if cursor_on: input.text = input_prefix+cursor
						else: input.text = input_prefix
					reset_cursor()

func _process(delta):
	if opened:
		if anchor_bottom != .5 && !fullscreen || anchor_bottom != 1:
			anchor_bottom = move_toward(anchor_bottom, 1 if fullscreen else .5, delta * 4)
			if anchor_top < 0: anchor_top = 0
			if !fullscreen && eol && anchor_bottom > .5: scroll_to_bottom()
		if !dont_type:
			cursor_time -= delta
			if cursor_on and cursor_time < 0:
				input.text = input.text.substr(0, input.text.length() - cursor.length())
				cursor_on = false
			elif cursor_time < 0:
				input.text += cursor
				cursor_on = true
			if cursor_time < 0: cursor_time = time_to_tick_cur
		if scroll.value == scroll.max_value - scroll.page && !eol: eol = true
		elif scroll.value != scroll.max_value - scroll.page && eol && anchor_bottom <= .5 || anchor_bottom == 1: eol = false
	else:
		if anchor_bottom > 0: anchor_bottom -= delta * 4
		elif visible: visible = false

func cprint(mesg,newLine=true):
	if log.text == "" || !newLine: log.text += mesg
	else: log.text += '\n' + mesg

func _ready():
	register_cmd("command_list", command_list, "Show an command list")
	register_cmd("quit", quit, "Quit the game")
	register_alias("exit", "quit")
	register_cmd("clear", clear, "Clear the log")
	register_cmd("version", version, "Show the engine version")
	register_alias("ver", "version")
	register_cmd("delete_history", resetHistory, "Reset the command history")

func scroll_to_bottom():
	await get_tree().create_timer(0.02).timeout # Delay to fix scroll issue.
	scroll.value = scroll.max_value - scroll.page

func exec(cmd, alias=false):
	match cmd.param_count:
		0: cmd.function.call()
		1: cmd.function.call(args[1] if args.size() > 1 else "")
		2: cmd.function.call(args[1] if args.size() > 1 else "", args[2] if args.size() > 2 else "")
		3: cmd.function.call(args[1] if args.size() > 1 else "", args[2] if args.size() > 2 else "", args[3] if args.size() > 3 else "")
		_: cprint("Commands with more than 3 parameters not supported.")

var args
var cmd
func command(text):
	text = text.to_lower()
	args = text.split(' ', true)
	cmd = args[0]
	if cmd != "clear": cprint("[color=gray][ " + text + "[/color]")
	if cmd != "delete_history": add_input_history(text)
	if commands.has(cmd): exec(commands[cmd])
	elif aliases.has(cmd): exec(commands[aliases[cmd].cmd], true)
	else: cprint("Invalid command")
	scroll_to_bottom()
	args.clear()
	cmd = null

func add_input_history(text):
	# Don't add consecutive duplicates
	if !history.size() || text != history.back(): history.append(text)
	history_index = history.size()

func _enter_tree():
	var history_file = FileAccess.open("user://console_history.txt", FileAccess.READ)
	if history_file:
		while !history_file.eof_reached():
			var line = history_file.get_line()
			if line.length(): add_input_history(line)

func _exit_tree():
	if !history: return
	var history_file = FileAccess.open("user://console_history.txt", FileAccess.WRITE)
	if history_file:
		var write_index = 0
		var start_write_index = history.size() - 50 # Max lines to write
		for line in history:
			if write_index >= start_write_index: history_file.store_line(line)
			write_index += 1

func inform_cmd(cmd, alias=false):
	var command_entry = aliases[cmd] if alias else commands[cmd]
	match (commands[command_entry.cmd] if alias else command_entry).flags:
		CommandFlags.CONFIGABLE: cprint("[color=cyan][CONFIGABLE][/color] ")
		CommandFlags.CHEAT:
			#if !cheatsEnabled: return
			cprint("[color=red][CHEAT][/color] ")
	var hasFlags = commands[command_entry.cmd].flags >= 0 if alias else command_entry.flags >= 0
	var com = cmd + ' ' + commands[command_entry.cmd].help if alias && commands[command_entry.cmd].help != "" else cmd + ' ' + command_entry.help if !alias && command_entry.help != "" else cmd
	if (commands[command_entry.cmd] if alias else command_entry).description != "":
		if alias: cprint("[b]" + com + "[/b](" + command_entry.cmd + "): " + commands[command_entry.cmd].description, !hasFlags)
		else: cprint("[b]" + com + "[/b]: " + command_entry.description, !hasFlags)
	else:
		if alias: cprint(com + "(" + command_entry.cmd + ")", !hasFlags)
		else: cprint(com, !hasFlags)

#Built-in commands
func command_list():
	for cmd in commands: inform_cmd(cmd)
	cprint("\nAliases:")
	for alias in aliases: inform_cmd(alias, true)

func quit(): get_tree().quit()
func clear(): log.text = ""

func version():
	var eVer = Engine.get_version_info()
	if eVer.patch != 0: cprint("Godot %s.%s.%s.%s.%s" % [eVer.major, eVer.minor, eVer.patch, eVer.status, eVer.build])
	else: cprint("Godot %s.%s.%s.%s" % [eVer.major, eVer.minor, eVer.status, eVer.build])

func resetHistory():
	history = []
	if history_index > 0: history_index = 0
	if FileAccess.file_exists("user://console_history.txt"): DirAccess.remove_absolute("user://console_history.txt")
