package main

import "core:fmt"
import os2 "core:os/os2"

VERSION :: "0.1.0"

main :: proc() {
	args := os2.args

	if len(args) < 2 {
		print_usage()
		return
	}

	command := args[1]

	switch command {
	case "init":
		cmd_init()

	case "add":
		if len(args) < 3 {
			print_error("Usage: chi add <url>")
			os2.exit(1)
		}
		cmd_add(args[2])

	case "fetch":
		cmd_fetch()

	case "vendor":
		cmd_vendor()

	case "update":
		if len(args) < 3 {
			print_error("Usage: chi update <name>")
			os2.exit(1)
		}
		cmd_update(args[2])

	case "check":
		cmd_check()

	case "--version", "-v":
		fmt.printfln("chi %s", VERSION)

	case "--help", "-h", "help":
		print_usage()

	case:
		print_error(fmt.tprintf("Unknown command: %s", command))
		print_usage()
		os2.exit(1)
	}
}

print_usage :: proc() {
	fmt.println("chi — Minimalist Dependency Manager for Odin")
	fmt.printfln("Version %s\n", VERSION)
	fmt.println("Usage: chi <command> [arguments]\n")
	fmt.println("Commands:")
	fmt.println("  init          Initialize a chi.odin manifest")
	fmt.println("  add <url>     Add a dependency")
	fmt.println("  fetch         Download all dependencies to global cache")
	fmt.println("  vendor        Populate vendor/ from the cache")
	fmt.println("  update <name> Update a dependency to the latest commit")
	fmt.println("  check         Verify vendor/ matches manifest hashes")
	fmt.println("")
	fmt.println("Flags:")
	fmt.println("  --help, -h    Show this help message")
	fmt.println("  --version, -v Show version")
}
