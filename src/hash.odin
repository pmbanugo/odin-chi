package main

import "core:crypto/blake2b"
import os2 "core:os/os2"
import "core:strings"
import "core:slice"

HASH_PREFIX :: "blake2b-"

// Hash the contents of a directory (excluding .git) using BLAKE2b.
// Files are processed in sorted order for deterministic output.
hash_directory :: proc(dir_path: string) -> (hash_str: string, ok: bool) {
	// Normalize to absolute path for consistent relative path computation
	abs_path, abs_err := os2.get_absolute_path(dir_path, context.allocator)
	if abs_err != nil {
		return "", false
	}
	defer delete(abs_path)

	// Collect all file paths recursively
	file_paths := collect_files(abs_path) or_return

	if len(file_paths) == 0 {
		return "", false
	}
	defer {
		for p in file_paths {
			delete(p)
		}
		delete(file_paths)
	}

	// Sort for determinism
	slice.sort_by(file_paths[:], proc(a, b: string) -> bool {
		return a < b
	})

	// Hash all file contents in order
	ctx: blake2b.Context
	blake2b.init(&ctx)

	for file_path in file_paths {
		// Include the relative path in the hash
		rel_path := file_path[len(abs_path):]
		blake2b.update(&ctx, transmute([]u8)rel_path)

		// Read and hash file contents
		data, err := os2.read_entire_file_from_path(file_path, context.allocator)
		if err != nil {
			return "", false
		}
		blake2b.update(&ctx, data)
		delete(data)
	}

	// Finalize
	digest: [blake2b.DIGEST_SIZE]u8
	blake2b.final(&ctx, digest[:])

	hex := bytes_to_hex(digest[:])
	result := strings.concatenate({HASH_PREFIX, hex})
	delete(hex)

	return result, true
}

@(private = "file")
collect_files :: proc(dir_path: string) -> (paths: [dynamic]string, ok: bool) {
	paths = make([dynamic]string)
	collect_files_recursive(dir_path, &paths) or_return
	return paths, true
}

@(private = "file")
collect_files_recursive :: proc(dir_path: string, paths: ^[dynamic]string) -> (ok: bool) {
	entries, err := os2.read_all_directory_by_path(dir_path, context.allocator)
	if err != nil {
		return false
	}
	defer os2.file_info_slice_delete(entries, context.allocator)

	for entry in entries {
		// Skip .git directory
		if entry.name == ".git" {
			continue
		}

		full_path := strings.clone(entry.fullpath)

		if entry.type == .Directory {
			collect_files_recursive(full_path, paths) or_return
			delete(full_path)
		} else {
			append(paths, full_path)
		}
	}

	return true
}

// Verify that a directory's hash matches the expected hash
verify_hash :: proc(dir_path: string, expected_hash: string) -> bool {
	actual_hash, ok := hash_directory(dir_path)
	if !ok {
		return false
	}
	defer delete(actual_hash)
	return actual_hash == expected_hash
}
