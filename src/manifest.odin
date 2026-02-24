package main

import "core:fmt"
import os2 "core:os/os2"
import "core:strings"

MANIFEST_FILE :: "chi.odin"

Dependency :: struct {
	url:    string,
	commit: string,
	hash:   string,
	path:   string, // optional: local development override
}

// Read and parse a chi.odin manifest file.
read_manifest :: proc(filepath: string) -> (deps: map[string]Dependency, ok: bool) {
	data, err := os2.read_entire_file_from_path(filepath, context.allocator)
	if err != nil {
		return deps, false
	}
	defer delete(data)

	content := string(data)
	deps = make(map[string]Dependency)

	in_entry := false
	current_name: string
	current_dep: Dependency

	lines := strings.split(content, "\n")
	defer delete(lines)

	for line in lines {
		trimmed := strings.trim_space(line)

		if len(trimmed) == 0 || strings.has_prefix(trimmed, "//") ||
		   strings.has_prefix(trimmed, "package ") ||
		   strings.has_prefix(trimmed, "Dependencies") ||
		   strings.has_prefix(trimmed, "Dependency") {
			continue
		}

		// Check if closing an entry block
		if in_entry && (trimmed == "}," || trimmed == "}") {
			deps[current_name] = current_dep
			in_entry = false
			current_dep = {}
			continue
		}

		// Look for entry opening: "name" = {
		if !in_entry && strings.contains(trimmed, "= {") {
			name := extract_quoted_string(trimmed)
			if name != "" {
				current_name = strings.clone(name)
				current_dep = {}
				in_entry = true
			}
			continue
		}

		// Inside an entry, parse field = "value" lines
		if in_entry {
			parse_field(trimmed, &current_dep)
		}
	}

	return deps, true
}

@(private = "file")
extract_field_value :: proc(line: string) -> string {
	first_quote := strings.index(line, "\"")
	if first_quote < 0 { return "" }
	rest := line[first_quote + 1:]
	second_quote := strings.index(rest, "\"")
	if second_quote < 0 { return "" }
	return rest[:second_quote]
}

@(private = "file")
extract_quoted_string :: proc(line: string) -> string {
	return extract_field_value(line)
}

@(private = "file")
parse_field :: proc(line: string, dep: ^Dependency) {
	trimmed := strings.trim_space(line)

	if strings.has_prefix(trimmed, "url") {
		val := extract_field_value(trimmed)
		if val != "" { dep.url = strings.clone(val) }
	} else if strings.has_prefix(trimmed, "commit") {
		val := extract_field_value(trimmed)
		if val != "" { dep.commit = strings.clone(val) }
	} else if strings.has_prefix(trimmed, "hash") {
		val := extract_field_value(trimmed)
		if val != "" { dep.hash = strings.clone(val) }
	} else if strings.has_prefix(trimmed, "path") {
		val := extract_field_value(trimmed)
		if val != "" { dep.path = strings.clone(val) }
	}
}

// Write a chi.odin manifest file.
write_manifest :: proc(filepath: string, deps: map[string]Dependency) -> bool {
	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	strings.write_string(&b, "package deps\n\n")

	strings.write_string(&b, "Dependencies :: map[string]Dependency{\n")
	for name, dep in deps {
		fmt.sbprintf(&b, "    \"%s\" = {{\n", name)
		fmt.sbprintf(&b, "        url    = \"%s\",\n", dep.url)
		fmt.sbprintf(&b, "        commit = \"%s\",\n", dep.commit)
		fmt.sbprintf(&b, "        hash   = \"%s\",\n", dep.hash)
		if dep.path != "" {
			fmt.sbprintf(&b, "        path   = \"%s\",\n", dep.path)
		}
		strings.write_string(&b, "    },\n")
	}
	strings.write_string(&b, "}\n\n")

	strings.write_string(&b, "Dependency :: struct {\n")
	strings.write_string(&b, "    url:    string,\n")
	strings.write_string(&b, "    commit: string,\n")
	strings.write_string(&b, "    hash:   string,\n")
	strings.write_string(&b, "    path:   string,\n")
	strings.write_string(&b, "}\n")

	err := os2.write_entire_file(filepath, transmute([]u8)strings.to_string(b))
	return err == nil
}

// Create an empty chi.odin manifest
write_empty_manifest :: proc(filepath: string) -> bool {
	deps := make(map[string]Dependency)
	defer delete(deps)
	return write_manifest(filepath, deps)
}
