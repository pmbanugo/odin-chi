package main

import os2 "core:os/os2"
import "core:path/filepath"

// Get the global cache directory (e.g., ~/.cache/chi/ on Linux, ~/Library/Caches/chi/ on macOS, AppData/Local/chi/ on Windows)
get_cache_dir :: proc() -> (string, bool) {
	cache_base, err := os2.user_cache_dir(context.allocator)
	if err != nil {
		return "", false
	}
	cache_dir := filepath.join({cache_base, "chi"}, context.allocator)
	delete(cache_base)

	// Ensure directory exists
	if !os2.exists(cache_dir) {
		mk_err := os2.make_directory_all(cache_dir)
		if mk_err != nil {
			delete(cache_dir)
			return "", false
		}
	}

	return cache_dir, true
}

// Get the cached path for a specific dependency version
get_cached_path :: proc(url: string, commit: string) -> (string, bool) {
	cache_dir, ok := get_cache_dir()
	if !ok { return "", false }

	dir_name := url_to_dir_name(url)
	result := filepath.join({cache_dir, dir_name, commit}, context.allocator)
	delete(cache_dir)
	delete(dir_name)

	return result, true
}

// Check if a dependency is already in the cache
is_cached :: proc(url: string, commit: string) -> bool {
	path, ok := get_cached_path(url, commit)
	if !ok { return false }
	defer delete(path)

	return os2.exists(path)
}

// Copy directory contents from src to dest, excluding .git directories.
// Uses pure Odin filesystem APIs for cross-platform compatibility.
copy_to_vendor :: proc(src_path: string, dest_path: string) -> bool {
	// Remove existing vendor directory first
	if os2.exists(dest_path) {
		os2.remove_all(dest_path)
	}

	return copy_dir_recursive(src_path, dest_path)
}

// Recursively copy a directory, skipping .git directories.
@(private = "file")
copy_dir_recursive :: proc(src: string, dest: string) -> bool {
	// Create destination directory
	err := os2.make_directory_all(dest)
	if err != nil {
		return false
	}

	// Read source directory entries
	entries, read_err := os2.read_all_directory_by_path(src, context.allocator)
	if read_err != nil {
		return false
	}
	defer os2.file_info_slice_delete(entries, context.allocator)

	for entry in entries {
		// Skip .git directory
		if entry.name == ".git" {
			continue
		}

		src_child := filepath.join({src, entry.name}, context.allocator)
		defer delete(src_child)
		dest_child := filepath.join({dest, entry.name}, context.allocator)
		defer delete(dest_child)

		if entry.type == .Directory {
			// Recurse into subdirectories
			if !copy_dir_recursive(src_child, dest_child) {
				return false
			}
		} else {
			// Copy file contents
			data, file_err := os2.read_entire_file_from_path(src_child, context.allocator)
			if file_err != nil {
				return false
			}
			write_err := os2.write_entire_file(dest_child, data)
			delete(data)
			if write_err != nil {
				return false
			}
		}
	}

	return true
}
