package main

import (
	"strconv"
)

func IsDigit(c byte) bool {
	if _, err := strconv.Atoi(string(c)); err == nil {
		return true;
	}

	return false;
}

func Advance(c *byte, line string, index *int) bool {
	*index++
	if *index > len(line) - 1 {
		return false
	}
	*c = line[*index]
	return true
}
