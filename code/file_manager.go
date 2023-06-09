package main

import (
	"bufio"
	"os"
	"strings"
)

type FileManager struct {
	filename []string
	source   []string
}

func getParsedSourceFile(path string) string {
	f, err := os.Open(path)
	CheckError(err, "file_manager.go-1")
	defer f.Close()

	var result strings.Builder

	scanner := bufio.NewScanner(f)
	scanner.Split(bufio.ScanLines)

	for scanner.Scan() {
		line := scanner.Text()
		addingNumber := false

		for index := 0; index < len(line); index++ {
			c := line[index]

			if IsDigit(c) {
				result.WriteByte(c)
				for Advance(&c, line, &index) && c != ' ' {
					if c != '_' {
						result.WriteByte(c)
					}
				}

				result.WriteByte(' ')
				continue
			}

			if addingNumber {
				if c == '_' {
					continue
				}

				if c == ' ' {
					addingNumber = false
				}

				result.WriteByte(c)
			}

			if c == ';' {
				break
			}

			if IsDigit(c) {
				addingNumber = true
			}

			result.WriteByte(c)
		}

		result.WriteByte('\n')
	}

	return result.String()
}

func (this *FileManager) Open(filename string) {
	path := ""

	if (strings.Contains(filename, ".sk")) {
		path = Stanczyk.workspace.pDir + "/" + filename
	} else {
		path = Stanczyk.workspace.cDir + "/libs/" + filename + ".sk"
	}

	_, err := os.Stat(path)
	CheckError(err, "file_manager.go-2")

	this.filename = append(this.filename, path)
	this.source = append(this.source, getParsedSourceFile(path))
}
