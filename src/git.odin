package main

import "core:fmt"
import os2 "core:os/os2"
import "core:strings"

// Clone a repository to a destination directory
git_clone :: proc(url: string, dest: string) -> bool {
	git_url := make_git_url(url)
	defer delete(git_url)

	ok := run_cmd_silent({"git", "clone", "--quiet", git_url, dest})
	if !ok {
		print_error(fmt.tprintf("git clone failed for %s", url))
	}
	return ok
}

// Checkout a specific commit in a repository
git_checkout :: proc(repo_path: string, commit: string) -> bool {
	ok := run_cmd_silent({"git", "checkout", "--quiet", commit}, repo_path)
	if !ok {
		print_error(fmt.tprintf("git checkout failed for commit %s", commit))
	}
	return ok
}

// Resolve a tag, branch, or HEAD to a full commit SHA.
// If it fails, checks if the ref could be a direct commit hash.
git_resolve_commit :: proc(url: string, ref: string = "HEAD") -> (commit: string, ok: bool) {
	git_url := make_git_url(url)
	defer delete(git_url)

	output, cmd_ok := run_cmd({"git", "ls-remote", git_url, ref})
	if !cmd_ok {
		print_error(fmt.tprintf("git ls-remote failed for %s", url))
		return "", false
	}
	defer delete(output)

	if len(strings.trim_space(output)) == 0 {
		// Possibly a direct commit hash (short or full)
		if len(ref) >= 7 {
			return strings.clone(ref), true
		}
		print_error(fmt.tprintf("Ref '%s' not found on remote", ref))
		return "", false
	}

	// Output format is usually `<sha>\t<ref_name>\n`
	tab_idx := strings.index(output, "\t")
	if tab_idx < 0 {
		print_error("Unexpected output from git ls-remote")
		return "", false
	}

	return strings.clone(output[:tab_idx]), true
}

// Fetch a specific commit to the global cache
git_fetch_to_cache :: proc(url: string, commit: string) -> bool {
	if is_cached(url, commit) {
		print_info(fmt.tprintf("Already cached: %s@%s", url, commit[:min(len(commit), 12)]))
		return true
	}

	cache_path, ok := get_cached_path(url, commit)
	if !ok {
		print_error("Failed to determine cache path")
		return false
	}
	defer delete(cache_path)

	// Ensure parent directory exists
	parent_end := strings.last_index(cache_path, "/")
	if parent_end > 0 {
		parent := cache_path[:parent_end]
		if !os2.exists(parent) {
			err := os2.make_directory_all(parent)
			if err != nil {
				print_error("Failed to create cache directory")
				return false
			}
		}
	}

	print_info(fmt.tprintf("Fetching %s@%s ...", url, commit[:min(len(commit), 12)]))

	// Clone the repository
	if !git_clone(url, cache_path) {
		return false
	}

	// Checkout the specific commit
	if !git_checkout(cache_path, commit) {
		os2.remove_all(cache_path)
		return false
	}

	return true
}
