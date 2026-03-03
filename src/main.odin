package main

import "core:fmt"
import os2 "core:os/os2"
import "core:strings"

VERSION :: "0.2.0"

// Fork overrides from --fork=name:path flags (not persisted in manifest)
fork_overrides: map[string]string

main :: proc() {
	args := os2.args

	if len(args) < 2 {
		print_usage()
		return
	}

	// Parse --fork flags and collect remaining args
	remaining: [dynamic]string
	defer delete(remaining)

	for arg in args {
		if strings.has_prefix(arg, "--fork=") {
			payload := arg[len("--fork="):]
			// Split on first colon only (allows Windows paths like C:\...)
			colon_idx := strings.index(payload, ":")
			if colon_idx <= 0 || colon_idx == len(payload) - 1 {
				print_error(fmt.tprintf("Invalid --fork format: '%s'. Expected --fork=name:path", arg))
				os2.exit(1)
			}
			name := payload[:colon_idx]
			path := payload[colon_idx + 1:]
			if !os2.exists(path) {
				print_error(fmt.tprintf("Fork path does not exist: %s", path))
				os2.exit(1)
			}
			if fork_overrides == nil {
				fork_overrides = make(map[string]string)
			}
			fork_overrides[name] = path
		} else {
			append(&remaining, arg)
		}
	}

	if len(remaining) < 2 {
		print_usage()
		return
	}

	command := remaining[1]

	switch command {
	case "init":
		cmd_init()

	case "add":
		if len(remaining) < 3 {
			print_error("Usage: chi add <url> [commit/tag]")
			os2.exit(1)
		}
		ref := "HEAD"
		if len(remaining) >= 4 {
			ref = remaining[3]
		}
		cmd_add(remaining[2], ref)

	case "remove":
		if len(remaining) < 3 {
			print_error("Usage: chi remove <name>")
			os2.exit(1)
		}
		cmd_remove(remaining[2])

	case "fetch":
		cmd_fetch()

	case "vendor":
		cmd_vendor()

	case "update":
		if len(remaining) < 3 {
			print_error("Usage: chi update <name>")
			os2.exit(1)
		}
		cmd_update(remaining[2])

	case "list":
		cmd_list()

	case "check":
		cmd_check()

	case "patch":
		cmd_patch()

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
	fmt.println("  init            Initialize a chi.odin manifest")
	fmt.println("  add <url> [ref] Add a dependency (ref is a tag, branch, or commit hash)")
	fmt.println("  remove <name>   Remove a dependency and its vendored files")
	fmt.println("  fetch           Download all dependencies to global cache")
	fmt.println("  vendor          Populate vendor/ from the cache")
	fmt.println("  update <name>   Update a dependency to the latest commit")
	fmt.println("  list            List all dependencies in the manifest")
	fmt.println("  check           Verify vendor/ matches manifest hashes")
	fmt.println("  patch           Generate .patch files for modified vendored dependencies")
	fmt.println("")
	fmt.println("Flags:")
	fmt.println("  --fork=name:path  Override a dependency with a local directory")
	fmt.println("  --help, -h        Show this help message")
	fmt.println("  --version, -v     Show version")
}
