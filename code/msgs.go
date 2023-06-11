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


	/*    ___ ___  __  __ ___ ___ _      _ _____ ___ ___  _  _
	 *   / __/ _ \|  \/  | _ \_ _| |    /_\_   _|_ _/ _ \| \| |
	 *  | (_| (_) | |\/| |  _/| || |__ / _ \| |  | | (_) | .` |
	 *   \___\___/|_|  |_|_| |___|____/_/ \_\_| |___\___/|_|\_|
	 */
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

	MsgParseDotOrphanTokenFound =
		"'.' must have an associated block\n" +
			"E.g.:\n" +
			"\t\tif [condition] do [...] else [...] .\n" +
			"\t\t^^                                 ^\n"

	MsgParseCallMainFunctionMissing =
		"entry point is not defined\n" +
			"define a 'main' function"


	MsgParseWordNotFound = "undefined word %s"

	MsgParseErrorProgramScope =
		"cannot do this in global scope"

	MsgParseFunctionMissingName =
		"invalid or missing function name\n" +
			"\t\tfunction my-func do [...] .\n" +
			"\t\t         ^^^^^^^"
	MsgParseFunctionUnknownType =
		"type '%s' is unknown"
	MsgParseFunctionNoReturnSpecified =
		"no return values specified after '->'\n" +
			"\t\tfunction my-func -> do [...] .\n" +
			"\t\t                 ^^"
	MsgParseFunctionMissingDo =
		"missing 'do' keyword\n" +
			"\t\tfunction my-func do [...] .\n" +
			"\t\t                 ^^"
	MsgParseFunctionMissingDot =
		"missing '.'\n" +
			"\t\tfunction my-func do [...] .\n" +
			"\t\t                          ^"



	/*   _______   _____ ___ ___ _  _ ___ ___ _  __
	 *  |_   _\ \ / / _ \ __/ __| || | __/ __| |/ /
	 *    | |  \ V /|  _/ _| (__| __ | _| (__| ' <
	 *    |_|   |_| |_| |___\___|_||_|___\___|_|\_\
	 */
	MsgTypecheckMainFunctionNoArgumentsOrReturn =
		"function main must have no arguments and no return values"
	MsgTypecheckArgumentsTypeMismatch =
		"incorrect arguments to call %s\n" +
			"\t\thave (%s)\n" +
			"\t\twant (%s)"
	MsgTypecheckNotExplicitlyReturned =
		"unhandled stack values\n" +
			"\t\tfunction %s\n" +
			"\t\t(%s)"
	MsgTypecheckMissingEntryPoint =
		"function main is undeclared"
)
