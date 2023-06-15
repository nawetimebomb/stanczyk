package main

import (
	"fmt"
	"os"
)

type ErrorCode int

const (
	CodeOK ErrorCode = iota
	CodeCliError
	CodeParseError
)

func ReportParseError(msg string, file string, line int, column int) {
	prefix := fmt.Sprintf(MsgErrorPrefix, file, line, column)
	fmt.Fprintf(os.Stderr, "%s %s\n", prefix, msg);
}

func ExitWithError(error ErrorCode) {
	os.Exit(int(error))
}
