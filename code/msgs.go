package main

const (
	TodoRemoveCliCannotGetDirectory = "Unable to find compiler directory, this is required to make the compiler work, and if not provided we cannot continue. [COMPILER BUG]\n\nFile Reporting: %s\nOS Reported error: %s"

	MsgCliPrefix = "[Stanczyk] "
	MsgErrorPrefix = "%s:%d:%d:"


	MsgCliUnknownArgument =
		"argument %s is not a known argument. Please, check the allowed arguments by using: skc help"
	MsgCliUnknownCommand =
		"first argument should be a known command, but instead got %s\nE.g.\n" +
			"\tskc run myfile.sk\n" +
			"\t    ^^^"
	MsgCliWelcome =
		"Usage:\n" +
			"\tskc <command> [arguments]\n" +
			"Commands:\n" +
			"\tbuild  compile the entry .sk file and it's includes.\n" +
			"\trun    same as 'build', but it runs the result and cleans up the executable.\n\n" +
			"For more information about what the compiler can do, you can use: skc help.\n"


	MsgParseMacroMissingWord =
		"invalid or missing word\n" +
			"macro name required. Name may be any word except for the reserved ones\n" +
			"\t\tmacro my-macro do [...] .\n" +
			"\t\t      ^^^^^^^^"
	MsgParseMacroMissingDo =
		"missing 'do' keyword\n" +
			"blocks in Stańczyk use the keyword do for block initiation\n" +
			"\t\tmacro my-macro do [...] .\n" +
			"\t\t               ^^"
	MsgParseMacroMissingContent =
		"empty macro\n" +
			"macros must have content in Stańczyk\n" +
			"\t\tmacro my-macro do [...] .\n" +
			"\t\t                  ^^^^^"
	MsgParseMacroMissingDot =
		"missing '.'\n" +
			"macro definition must end with a '.' (dot)\n" +
			"\t\tmacro my-macro do [...] .\n" +
			"\t\t                        ^"

	MsgParseDoOrphanTokenFound =
		"only use 'do' when starting a block statement\nE.g.:\n\tif [condition] do [...] else [...] .\n\t^^             ^^\n'do' can be used in other blocks like function and loops"

	MsgParseElseOrphanTokenFound =
		"only use 'else' after starting an 'if' statement\nE.g.:\n\tif [condition] do [...] else [...] .\n\t^^                      ^^^^"


	MsgParseWordNotFound = "undefined word %s"
)
