package main

import (
	"time"
)

type CompilationStep int

const (
	stepFrontend CompilationStep = iota
	stepTypecheck
	stepCodegen
	stepOutput
	stepBackend
)

var (
	started bool
	lastStep CompilationStep
	startTime time.Time
)

func getStepName(step CompilationStep) string {
	switch step {
	case stepFrontend:	return "Front-end compilation"
	case stepTypecheck: return "Typecheck"
	case stepCodegen:	return "Code generation"
	case stepOutput:	return "Output to ASM"
	case stepBackend:	return "Back-end compilation"
	default:			return "Unreachable"
	}
}

func timedFunction(step CompilationStep) {
	if started {
		elapsed := time.Since(startTime)
		ms := elapsed.Milliseconds()

		if ms >= 1000 {
			Stanczyk.Message("→ done in %.02fs\n", elapsed.Seconds())
		} else {
			Stanczyk.Message("→ done in %dms\n", ms)
		}
		started = false

		if step != lastStep {
			timedFunction(step)
		}
	} else {
		Stanczyk.Message("%s %-25s", MsgCliPrefix, getStepName(step))
		lastStep = step
		startTime = time.Now()
		started = true
	}
}

func RunTasks() {
	var (
		chunk Chunk
		asm   Assembly
	)

	timedFunction(stepFrontend)
	FrontendRun(&chunk)

	timedFunction(stepTypecheck)
	// typecheck.Run()

	timedFunction(stepCodegen)
	CodegenRun(chunk, &asm)

	timedFunction(stepOutput)
	OutputRun(asm)

	timedFunction(stepBackend)
	BackendRun()

	timedFunction(lastStep)
}
