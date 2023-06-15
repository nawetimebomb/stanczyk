package main

const (
	_BOLD_      = "\033[1m"
	_RED_       = "\033[31m"
	_RESET_     = "\033[0m"
	_UNDERLINE_ = "\033[4m"
)

const (
	CodeOK = iota
	CodeCliError
)

const (
	TodoRemoveCliCannotGetDirectory = "Unable to find compiler directory, this is required to make the compiler work, and if not provided we cannot continue. [COMPILER BUG]\n\nFile Reporting: %s\nOS Reported error: %s"

	MsgCliPrefix = _RED_ + "[Stanczyk]" + _RESET_
	MsgCliUnknownArgument = "argument %s is not a known argument. Please, check the allowed arguments by using: skc help"
	MsgCliUnknownCommand =
		"first argument should be a known command, but instead got %s\nE.g.\n" +
			"\tskc run myfile.sk\n" + _RED_ +
			"\t    ^^^" + _RESET_
	MsgCliWelcome =
		_BOLD_ + "Usage:\n" + _RESET_ +
			"\tskc " + _UNDERLINE_ + "command" + _RESET_ + " [arguments]\n" +
			_BOLD_ + "Commands:\n" + _RESET_ +
			"\tbuild  compile the entry .sk file and it's includes.\n" +
			"\trun    same as 'build', but it runs the result and cleans up the executable.\n\n" +
			"For more information about what the compiler can do, you can use: skc help.\n"
)
