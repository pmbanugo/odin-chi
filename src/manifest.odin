package main

import "core:fmt"
import "core:mem"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import os2 "core:os/os2"
import "core:slice"
import "core:strings"

MANIFEST_FILE :: "chi.odin"

Dependency :: struct {
	url:    string,
	commit: string,
	hash:   string,
	path:   string, // optional: local development override
}

// Read and parse a chi.odin manifest file using Odin's AST parser.
read_manifest :: proc(filepath: string) -> (deps: map[string]Dependency, ok: bool) {
	data, err := os2.read_entire_file_from_path(filepath, context.allocator)
	if err != nil {
		return deps, false
	}
	defer delete(data)

	src := string(data)
	caller_allocator := context.allocator

	// Use an arena allocator for AST nodes so they can all be freed at once
	arena: mem.Arena
	mem.arena_init(&arena, make([]u8, 1024 * 64))
	defer delete(arena.data)

	// Parse the file into an AST using the arena
	p := parser.default_parser()
	p.err = proc(pos: tokenizer.Pos, msg: string, args: ..any) {
		fmt.eprintf("%s(%d:%d): ", pos.file, pos.line, pos.column)
		fmt.eprintf(msg, ..args)
		fmt.eprintf("\n")
	}
	file := ast.File{
		src      = src,
		fullpath = filepath,
	}

	context.allocator = mem.arena_allocator(&arena)
	if !parser.parse_file(&p, &file) {
		return deps, false
	}
	if file.syntax_error_count > 0 {
		return deps, false
	}

	// Find the Dependencies declaration
	deps_expr := find_dependencies_decl(&file) or_return

	// Decode using the caller's allocator (strings.clone uses context.allocator)
	context.allocator = caller_allocator
	return decode_dependencies_map(deps_expr)
}

// Find the `Dependencies :: map[string]Dependency{ ... }` declaration and return its initializer expr.
@(private = "file")
find_dependencies_decl :: proc(file: ^ast.File) -> (expr: ^ast.Expr, ok: bool) {
	for decl in file.decls {
		vd, is_vd := decl.derived_stmt.(^ast.Value_Decl)
		if !is_vd { continue }

		// Check if any name is "Dependencies"
		for name_expr in vd.names {
			ident, is_ident := name_expr.derived_expr.(^ast.Ident)
			if !is_ident { continue }
			if ident.name != "Dependencies" { continue }

			// Must have exactly one value (the initializer)
			if len(vd.values) != 1 { return nil, false }
			return vd.values[0], true
		}
	}

	return nil, false
}

// Decode the map compound literal into our deps map.
@(private = "file")
decode_dependencies_map :: proc(expr: ^ast.Expr) -> (deps: map[string]Dependency, ok: bool) {
	comp, is_comp := expr.derived_expr.(^ast.Comp_Lit)
	if !is_comp { return deps, false }

	deps = make(map[string]Dependency)

	for elem in comp.elems {
		fv, is_fv := elem.derived_expr.(^ast.Field_Value)
		if !is_fv {
			delete(deps)
			return {}, false
		}

		// Key must be a string literal
		name := decode_string_literal(fv.field) or_return

		// Value must be a compound literal (struct fields)
		dep := decode_dependency_literal(fv.value) or_return

		deps[strings.clone(name)] = dep
	}

	return deps, true
}

// Decode a compound literal like `{ url = "...", commit = "...", ... }` into a Dependency.
@(private = "file")
decode_dependency_literal :: proc(expr: ^ast.Expr) -> (dep: Dependency, ok: bool) {
	comp, is_comp := expr.derived_expr.(^ast.Comp_Lit)
	if !is_comp { return {}, false }

	for elem in comp.elems {
		fv, is_fv := elem.derived_expr.(^ast.Field_Value)
		if !is_fv { continue }

		field_ident, is_ident := fv.field.derived_expr.(^ast.Ident)
		if !is_ident { continue }

		val := decode_string_literal(fv.value) or_continue

		switch field_ident.name {
		case "url":
			dep.url = strings.clone(val)
		case "commit":
			dep.commit = strings.clone(val)
		case "hash":
			dep.hash = strings.clone(val)
		case "path":
			dep.path = strings.clone(val)
		}
	}

	return dep, true
}

// Extract the string value from a Basic_Lit string token (strips quotes).
@(private = "file")
decode_string_literal :: proc(expr: ^ast.Expr) -> (val: string, ok: bool) {
	bl, is_bl := expr.derived_expr.(^ast.Basic_Lit)
	if !is_bl { return "", false }
	if bl.tok.kind != .String { return "", false }

	text := bl.tok.text
	if len(text) < 2 { return "", false }

	// Strip surrounding quotes
	return text[1:len(text) - 1], true
}

// Write a chi.odin manifest file.
write_manifest :: proc(filepath: string, deps: map[string]Dependency) -> bool {
	b := strings.builder_make()
	defer strings.builder_destroy(&b)

	strings.write_string(&b, "package deps\n\n")

	strings.write_string(&b, "Dependencies :: map[string]Dependency{\n")

	// Sort keys for deterministic output
	sorted_keys := make([dynamic]string, 0, len(deps))
	defer delete(sorted_keys)
	for name in deps {
		append(&sorted_keys, name)
	}
	slice.sort(sorted_keys[:])

	for name in sorted_keys {
		dep := deps[name]
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
