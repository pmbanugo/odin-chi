package main

import "core:fmt"
import "core:strings"
import os2 "core:os/os2"

// Convert a URL like "github.com/laytan/odin-http" to a safe directory name "github.com-laytan-odin-http"
url_to_dir_name :: proc(url: string) -> string {
	buf := make([]u8, len(url))
	for i := 0; i < len(url); i += 1 {
		c := url[i]
		if c == '/' || c == ':' {
			buf[i] = '-'
		} else {
			buf[i] = c
		}
	}
	return string(buf)
}

// Extract package name from URL (last segment)
// e.g., "github.com/laytan/odin-http" -> "odin-http"
url_to_pkg_name :: proc(url: string) -> string {
	idx := strings.last_index(url, "/")
	if idx < 0 {
		return strings.clone(url)
	}
	return strings.clone(url[idx + 1:])
}

// Convert byte slice to hex string
bytes_to_hex :: proc(data: []u8, allocator := context.allocator) -> string {
	hex_chars := [16]u8{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'}
	buf := make([]u8, len(data) * 2, allocator)
	for i := 0; i < len(data); i += 1 {
		buf[i * 2] = hex_chars[data[i] >> 4]
		buf[i * 2 + 1] = hex_chars[data[i] & 0x0F]
	}
	return string(buf)
}

print_error :: proc(msg: string) {
	fmt.eprintfln("\x1b[31merror:\x1b[0m %s", msg)
}

print_success :: proc(msg: string) {
	fmt.printfln("\x1b[32m✓\x1b[0m %s", msg)
}

print_info :: proc(msg: string) {
	fmt.printfln("\x1b[36mℹ\x1b[0m %s", msg)
}

print_warn :: proc(msg: string) {
	fmt.printfln("\x1b[33m⚠\x1b[0m %s", msg)
}

// Normalize a git URL: strip https:// prefix and .git suffix
normalize_url :: proc(url: string) -> string {
	s := url
	if strings.has_prefix(s, "https://") {
		s = s[len("https://"):]
	} else if strings.has_prefix(s, "http://") {
		s = s[len("http://"):]
	}
	if strings.has_suffix(s, ".git") {
		s = s[:len(s) - len(".git")]
	}
	return strings.clone(s)
}

// Build a full git clone URL from a normalized URL
make_git_url :: proc(url: string) -> string {
	return strings.concatenate({"https://", url, ".git"})
}

// Run a command and return stdout as string. Returns (stdout_string, success).
run_cmd :: proc(command: []string, working_dir: string = "") -> (output: string, ok: bool) {
	state, stdout, stderr, err := os2.process_exec(
		os2.Process_Desc{
			command     = command,
			working_dir = working_dir,
		},
		context.allocator,
	)
	defer delete(stderr)

	if err != nil {
		delete(stdout)
		return "", false
	}

	if state.exit_code != 0 {
		delete(stdout)
		return "", false
	}

	return string(stdout), true
}

// Run a command, discarding output. Returns success.
run_cmd_silent :: proc(command: []string, working_dir: string = "") -> bool {
	state, stdout, stderr, err := os2.process_exec(
		os2.Process_Desc{
			command     = command,
			working_dir = working_dir,
		},
		context.allocator,
	)
	defer delete(stdout)
	defer delete(stderr)

	if err != nil {
		return false
	}

	return state.exit_code == 0
}
