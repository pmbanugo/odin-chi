package main

import "core:fmt"
import os2 "core:os/os2"
import "core:path/filepath"
import "core:strings"

// Get the global cache directory (~/.cache/chi/)
get_cache_dir :: proc() -> (string, bool) {
	home, found := os2.lookup_env("HOME", context.allocator)
	if !found {
		return "", false
	}
	cache_dir := filepath.join({home, ".cache", "chi"}, context.allocator)
	delete(home)

	// Ensure directory exists
	if !os2.exists(cache_dir) {
		err := os2.make_directory_all(cache_dir)
		if err != nil {
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

// Copy directory contents from cache to vendor, excluding .git
copy_to_vendor :: proc(src_path: string, dest_path: string) -> bool {
	// Remove existing vendor directory first
	if os2.exists(dest_path) {
		os2.remove_all(dest_path)
	}

	// Create destination directory
	err := os2.make_directory_all(dest_path)
	if err != nil {
		return false
	}

	// Use rsync for copy, excluding .git
	src_trailing := strings.concatenate({src_path, "/"})
	defer delete(src_trailing)
	dest_trailing := strings.concatenate({dest_path, "/"})
	defer delete(dest_trailing)

	ok := run_cmd_silent({"rsync", "-a", "--exclude", ".git", src_trailing, dest_trailing})
	if ok {
		return true
	}

	// Fallback: cp -R then remove .git
	// First remove the dest we created and let cp create it
	os2.remove_all(dest_path)
	ok2 := run_cmd_silent({"cp", "-R", src_path, dest_path})
	if !ok2 {
		return false
	}

	// Remove .git from the copy
	git_dir := filepath.join({dest_path, ".git"}, context.allocator)
	defer delete(git_dir)
	if os2.exists(git_dir) {
		os2.remove_all(git_dir)
	}

	return true
}
