/* The Stańczyk Programming Language
 *
 *            ¿«fº"└└-.`└└*∞▄_              ╓▄∞╙╙└└└╙╙*▄▄
 *         J^. ,▄▄▄▄▄▄_      └▀████▄ç    JA▀            └▀v
 *       ,┘ ▄████████████▄¿     ▀██████▄▀└      ╓▄██████▄¿ "▄_
 *      ,─╓██▀└└└╙▀█████████      ▀████╘      ▄████████████_`██▄
 *     ;"▄█└      ,██████████-     ▐█▀      ▄███████▀▀J█████▄▐▀██▄
 *     ▌█▀      _▄█▀▀█████████      █      ▄██████▌▄▀╙     ▀█▐▄,▀██▄
 *    ▐▄▀     A└-▀▌  █████████      ║     J███████▀         ▐▌▌╙█µ▀█▄
 *  A╙└▀█∩   [    █  █████████      ▌     ███████H          J██ç ▀▄╙█_
 * █    ▐▌    ▀▄▄▀  J█████████      H    ████████          █    █  ▀▄▌
 *  ▀▄▄█▀.          █████████▌           ████████          █ç__▄▀ ╓▀└ ╙%_
 *                 ▐█████████      ▐    J████████▌          .└╙   █¿   ,▌
 *                 █████████▀╙╙█▌└▐█╙└██▀▀████████                 ╙▀▀▀▀
 *                ▐██▀┘Å▀▄A └▓█╓▐█▄▄██▄J▀@└▐▄Å▌▀██▌
 *                █▄▌▄█M╨╙└└-           .└└▀**▀█▄,▌
 *                ²▀█▄▄L_                  _J▄▄▄█▀└
 *                     └╙▀▀▀▀▀MMMR████▀▀▀▀▀▀▀└
 *
 *
 * ███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗██╗   ██╗██╗  ██╗
 * ██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝╚══███╔╝╚██╗ ██╔╝██║ ██╔╝
 * ███████╗   ██║   ███████║██╔██╗ ██║██║       ███╔╝  ╚████╔╝ █████╔╝
 * ╚════██║   ██║   ██╔══██║██║╚██╗██║██║      ███╔╝    ╚██╔╝  ██╔═██╗
 * ███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗   ██║   ██║  ██╗
 * ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝
 */
#ifndef STANCZYK_ERRORS_H
#define STANCZYK_ERRORS_H

/*    ___ ___  __  __ ___ ___ _      _ _____ ___ ___  _  _
 *   / __/ _ \|  \/  | _ \_ _| |    /_\_   _|_ _/ _ \| \| |
 *  | (_| (_) | |\/| |  _/| || |__ / _ \| |  | | (_) | .` |
 *   \___\___/|_|  |_|_| |___|____/_/ \_\_| |___\___/|_|\_|
 */
#define ERROR__INCLUDE__FILE_OR_NAME_MISSING "file or library name expected after '#include'\nE.g.:\n\t#include \"io\"\n\t         ^^^^\nYou can find a list of libraries running skc -help"
#define ERROR__INCLUDE__FAILED_TO_FIND_FILE  "failed to find library to include: %s\nMake sure the name is correct. If it is an internal Stańczyk library, you\nmust omit the '.sk' in the name. If it is your code, then you must have '.sk'\nThe relative path to your libraries starts from the entry point base path\nE.g.:\n\t#include \"my/code.sk\"\nThis means the file is inside a folder called 'my', adjacent to the entry file"

#define ERROR__MACRO__MISSING_NAME "a valid word is expected after the macro definition symbol\nE.g.:\n\t:> my-macro : [...] .\n\t   ^^^^^^^^\nName may be any word starting with a lowercase or uppercase character, but it may contain numbers, _ or -"
#define ERROR__MACRO__ALREADY_IN_USE "word %s already in use\nYou cannot override existing declarations in Stańczyk,\nmust select a different name for this macro"
#define ERROR__MACRO__MISSING_COLON "':' expected after the name of this macro\nE.g.:\n\t:> my-macro : [...] .\n\t            ^\nMacro declaration statements must be enclosed in ':' and '.'"
#define ERROR__MACRO__MISSING_CONTENT "missing macro content after ':'. Empty macros are not allowed in Stanczyk\nE.g.:\n\t:> my-macro : [...] .\n\t              ^^^^^\nMacro content may be anything, including other macros, but not the same macro"
#define ERROR__MACRO__BLOCKS_NOT_ALLOWED "block starter keywords are not allowed inside a macro\nYou cannot use 'if', 'loop' or 'macro' as this macro content."
#define ERROR__MACRO__MISSING_DOT "'.' symbol expected after macro declaration\nE.g.:\n\t:> my-macro : [...] .\n\t                    ^\nMacro declaration must end with the '.' (dot) symbol"

#define ERROR__WORD__UNKNOWN_WORD "unknown word\nThe word definition has not been found yet in the code\nCheck if the definition is after this line or if you mispelled the word"

/*   _______   _____ ___ ___ _  _ ___ ___ _  __
 *  |_   _\ \ / / _ \ __/ __| || | __/ __| |/ /
 *    | |  \ V /|  _/ _| (__| __ | _| (__| ' <
 *    |_|   |_| |_| |___\___|_||_|___\___|_|\_\
 */
#define ERROR__TYPECHECK__INSUFFICIENT_ARGUMENTS "Not enough arguments to do this operation. Expected %d but got %d"

#endif
