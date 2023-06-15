package main

import (
	"os/exec"
	"strings"
)

func BackendRun() {
	compilerArgs := strings.Split("-f elf64 -g dwarf2 output.asm", " ")
	linkerArgs := strings.Split("-o output output.o", " ")

	_, err := exec.Command("yasm", compilerArgs...).Output()
	check(err, "backend.go-1")
	_, err = exec.Command("ld", linkerArgs...).Output()
	check(err, "backend.go-2")

	if Stanczyk.options.clean {
		_, err = exec.Command("rm", "output.o").Output()
	}

	// if Stanczyk.options.run {
	// 	_, err = exec.Command("./output").Output()
	// 	check(err)
	// }
}
