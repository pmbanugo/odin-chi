package main

import "core:testing"
import "core:strings"
import "core:fmt"

@(test)
test_url_to_dir_name :: proc(t: ^testing.T) {
	cases := []struct {
		input, expected: string
	}{
		{"github.com/laytan/odin-http", "github.com-laytan-odin-http"},
		{"github.com/user/repo", "github.com-user-repo"},
		{"github.com/pmbanugo/snake_game.odin", "github.com-pmbanugo-snake_game.odin"},
		{"git@github.com:pmbanugo/snake_game.odin.git", "git@github.com-pmbanugo-snake_game.odin.git"},
	}

	for c in cases {
		result := url_to_dir_name(c.input)
		testing.expect(t, result == c.expected, 
			fmt.tprintf("url_to_dir_name(%q) = %q, expected %q", c.input, result, c.expected))
	}
}

@(test)
test_url_to_pkg_name :: proc(t: ^testing.T) {
	cases := []struct {
		input, expected: string
	}{
		{"github.com/laytan/odin-http", "odin-http"},
		{"github.com/user/repo", "repo"},
		{"github.com/pmbanugo/snake_game.odin", "snake_game.odin"},
		{"simple", "simple"},
		{"", ""},
	}

	for c in cases {
		result := url_to_pkg_name(c.input)
		testing.expect(t, result == c.expected,
			fmt.tprintf("url_to_pkg_name(%q) = %q, expected %q", c.input, result, c.expected))
	}
}

@(test)
test_normalize_url :: proc(t: ^testing.T) {
	cases := []struct {
		input, expected: string
	}{
		{"github.com/laytan/odin-http", "github.com/laytan/odin-http"},
		{"https://github.com/laytan/odin-http", "github.com/laytan/odin-http"},
		{"http://github.com/laytan/odin-http", "github.com/laytan/odin-http"},
		{"github.com/laytan/odin-http.git", "github.com/laytan/odin-http"},
		{"https://github.com/laytan/odin-http.git", "github.com/laytan/odin-http"},
		{"github.com/pmbanugo/snake_game.odin", "github.com/pmbanugo/snake_game.odin"},
		{"git@github.com:pmbanugo/snake_game.odin.git", "git@github.com:pmbanugo/snake_game.odin"},
	}

	for c in cases {
		result := normalize_url(c.input)
		testing.expect(t, result == c.expected,
			fmt.tprintf("normalize_url(%q) = %q, expected %q", c.input, result, c.expected))
		delete(result)
	}
}

@(test)
test_make_git_url :: proc(t: ^testing.T) {
	cases := []struct {
		input, expected: string
	}{
		{"github.com/laytan/odin-http", "https://github.com/laytan/odin-http.git"},
		{"github.com/pmbanugo/snake_game.odin", "https://github.com/pmbanugo/snake_game.odin.git"},
	}

	for c in cases {
		result := make_git_url(c.input)
		testing.expect(t, result == c.expected,
			fmt.tprintf("make_git_url(%q) = %q, expected %q", c.input, result, c.expected))
		delete(result)
	}
}

@(test)
test_bytes_to_hex :: proc(t: ^testing.T) {
	test_data := []u8{0x00, 0x01, 0x02, 0xFF, 0xAB, 0xCD, 0xEF}
	result := bytes_to_hex(test_data)
	testing.expect(t, result == "000102ffabcdef",
		fmt.tprintf("bytes_to_hex = %q, expected %q", result, "000102ffabcdef"))
	delete(result)

	empty: []u8
	result_empty := bytes_to_hex(empty)
	testing.expect(t, result_empty == "", 
		fmt.tprintf("bytes_to_hex(empty) = %q, expected empty", result_empty))
	delete(result_empty)
}
