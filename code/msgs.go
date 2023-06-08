package main

const (
	TodoRemoveCliCannotGetDirectory = "Unable to find compiler directory, this is required to make the compiler work, and if not provided we cannot continue. [COMPILER BUG]\n\nFile Reporting: %s\nOS Reported error: %s"

	MsgCliPrefix = "[Stanczyk] "
	MsgErrorPrefix = "%s:%d:%d: "

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
		"a valid word is expected after the macro definition symbol\nE.g.:\n" +
			"\t:> my-macro : [...] .\n" +
			"\t   ^^^^^^^^\n" +
			"Name may be any word starting with a lowercase or uppercase character, but it may contain numbers, _ or -"

	MsgParseWordNotFound = "undefined word %s"
)
