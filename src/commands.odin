package main

import "core:fmt"
import os2 "core:os/os2"
import "core:path/filepath"
import "core:strings"

// Try to apply a patch file for a dependency if one exists in patches/
@(private = "file")
try_apply_patch :: proc(name: string) {
	patch_path := filepath.join({"patches", fmt.tprintf("%s.patch", name)}, context.allocator)
	defer delete(patch_path)

	if !os2.exists(patch_path) {
		return
	}

	print_info(fmt.tprintf("Applying patch for %s ...", name))
	if run_cmd_silent({"patch", "-p0", "-i", patch_path}) {
		print_success(fmt.tprintf("Applied patch for %s", name))
	} else {
		print_warn(fmt.tprintf("Failed to apply patch for %s (may need manual resolution)", name))
	}
}

// chi init — Create a new chi.odin manifest
cmd_init :: proc() {
	if os2.exists(MANIFEST_FILE) {
		print_warn("chi.odin already exists")
		return
	}

	if write_empty_manifest(MANIFEST_FILE) {
		print_success("Created chi.odin")
	} else {
		print_error("Failed to create chi.odin")
		os2.exit(1)
	}
}

// chi add <url> [ref] — Add a dependency
cmd_add :: proc(raw_url: string, ref: string) {
	url := normalize_url(raw_url)
	defer delete(url)

	// Read existing manifest or create one
	deps: map[string]Dependency
	manifest_ok: bool

	if os2.exists(MANIFEST_FILE) {
		deps, manifest_ok = read_manifest(MANIFEST_FILE)
		if !manifest_ok {
			print_error("Failed to read chi.odin")
			os2.exit(1)
		}
	} else {
		deps = make(map[string]Dependency)
	}

	pkg_name := url_to_pkg_name(url)
	defer delete(pkg_name)

	if pkg_name in deps {
		print_warn(fmt.tprintf("Dependency '%s' already exists. Use 'chi update %s' to update.", pkg_name, pkg_name))
		return
	}

	// Get target commit
	print_info(fmt.tprintf("Resolving commit for %s@%s ...", url, ref))
	commit, commit_ok := git_resolve_commit(url, ref)
	if !commit_ok {
		print_error("Failed to resolve commit")
		os2.exit(1)
	}
	defer delete(commit)

	// Fetch to cache
	if !git_fetch_to_cache(url, commit) {
		print_error("Failed to fetch dependency")
		os2.exit(1)
	}

	// Hash the cached content
	cache_path, cache_ok := get_cached_path(url, commit)
	if !cache_ok {
		print_error("Failed to get cache path")
		os2.exit(1)
	}
	defer delete(cache_path)

	hash, hash_ok := hash_directory(cache_path)
	if !hash_ok {
		print_error("Failed to hash dependency content")
		os2.exit(1)
	}
	defer delete(hash)

	// Add to manifest
	deps[strings.clone(pkg_name)] = Dependency{
		url    = strings.clone(url),
		commit = strings.clone(commit),
		hash   = strings.clone(hash),
	}

	if write_manifest(MANIFEST_FILE, deps) {
		print_success(fmt.tprintf("Added %s@%s", pkg_name, commit[:min(len(commit), 12)]))
	} else {
		print_error("Failed to write chi.odin")
		os2.exit(1)
	}
}

// chi fetch — Ensure all dependencies are in the global cache
cmd_fetch :: proc() {
	deps, ok := read_manifest(MANIFEST_FILE)
	if !ok {
		print_error("Failed to read chi.odin. Run 'chi init' first.")
		os2.exit(1)
	}

	if len(deps) == 0 {
		print_info("No dependencies to fetch")
		return
	}

	all_ok := true
	for name, dep in deps {
		if !git_fetch_to_cache(dep.url, dep.commit) {
			print_error(fmt.tprintf("Failed to fetch %s", name))
			all_ok = false
		}
	}

	if all_ok {
		print_success("All dependencies fetched")
	} else {
		print_error("Some dependencies failed to fetch")
		os2.exit(1)
	}
}

// chi vendor — Populate local vendor/ directory from cache
cmd_vendor :: proc() {
	deps, ok := read_manifest(MANIFEST_FILE)
	if !ok {
		print_error("Failed to read chi.odin. Run 'chi init' first.")
		os2.exit(1)
	}

	if len(deps) == 0 {
		print_info("No dependencies to vendor")
		return
	}

	// Ensure vendor directory exists
	if !os2.exists("vendor") {
		err := os2.make_directory("vendor")
		if err != nil {
			print_error("Failed to create vendor/ directory")
			os2.exit(1)
		}
	}

	all_ok := true
	for name, dep in deps {
		// Fork override takes highest precedence
		fork_path, has_fork := fork_overrides[name]
		if has_fork {
			print_info(fmt.tprintf("Using fork override for %s: %s", name, fork_path))
			vendor_path := filepath.join({"vendor", name}, context.allocator)
			defer delete(vendor_path)

			if !copy_to_vendor(fork_path, vendor_path) {
				print_error(fmt.tprintf("Failed to copy fork override for %s", name))
				all_ok = false
			} else {
				print_success(fmt.tprintf("Vendored %s (fork)", name))
			}
			continue
		}

		// Use local path override if set in manifest
		if dep.path != "" {
			print_info(fmt.tprintf("Using local override for %s: %s", name, dep.path))
			vendor_path := filepath.join({"vendor", name}, context.allocator)
			defer delete(vendor_path)

			if !copy_to_vendor(dep.path, vendor_path) {
				print_error(fmt.tprintf("Failed to copy local override for %s", name))
				all_ok = false
			} else {
				print_success(fmt.tprintf("Vendored %s (local)", name))
			}
			continue
		}

		// Ensure it's cached
		if !is_cached(dep.url, dep.commit) {
			print_info(fmt.tprintf("Fetching %s ...", name))
			if !git_fetch_to_cache(dep.url, dep.commit) {
				print_error(fmt.tprintf("Failed to fetch %s", name))
				all_ok = false
				continue
			}
		}

		cache_path, cache_ok := get_cached_path(dep.url, dep.commit)
		if !cache_ok {
			print_error(fmt.tprintf("Failed to get cache path for %s", name))
			all_ok = false
			continue
		}
		defer delete(cache_path)

		// Verify integrity before vendoring
		if !verify_hash(cache_path, dep.hash) {
			print_error(fmt.tprintf(
				"INTEGRITY FAILURE for %s! Cache content does not match manifest hash. " +
				"This may indicate a supply-chain attack (e.g., force-pushed commit). " +
				"Refusing to vendor.", name))
			all_ok = false
			continue
		}

		vendor_path := filepath.join({"vendor", name}, context.allocator)
		defer delete(vendor_path)

		if !copy_to_vendor(cache_path, vendor_path) {
			print_error(fmt.tprintf("Failed to vendor %s", name))
			all_ok = false
		} else {
			print_success(fmt.tprintf("Vendored %s", name))
			try_apply_patch(name)
		}
	}

	if all_ok {
		print_success("All dependencies vendored")
	} else {
		print_error("Some dependencies failed to vendor")
		os2.exit(1)
	}
}

// chi update <name> — Update a dependency to the latest commit
cmd_update :: proc(name: string) {
	deps, ok := read_manifest(MANIFEST_FILE)
	if !ok {
		print_error("Failed to read chi.odin")
		os2.exit(1)
	}

	dep, found := deps[name]
	if !found {
		print_error(fmt.tprintf("Dependency '%s' not found in chi.odin", name))
		os2.exit(1)
	}

	print_info(fmt.tprintf("Checking for updates to %s ...", name))
	new_commit, commit_ok := git_resolve_commit(dep.url, "HEAD")
	if !commit_ok {
		print_error("Failed to resolve latest commit")
		os2.exit(1)
	}
	defer delete(new_commit)

	if new_commit == dep.commit {
		print_info(fmt.tprintf("%s is already at the latest commit", name))
		return
	}

	// Fetch new version
	if !git_fetch_to_cache(dep.url, new_commit) {
		print_error("Failed to fetch updated dependency")
		os2.exit(1)
	}

	// Hash the new content
	cache_path, cache_ok := get_cached_path(dep.url, new_commit)
	if !cache_ok {
		print_error("Failed to get cache path")
		os2.exit(1)
	}
	defer delete(cache_path)

	new_hash, hash_ok := hash_directory(cache_path)
	if !hash_ok {
		print_error("Failed to hash updated dependency")
		os2.exit(1)
	}
	defer delete(new_hash)

	// Update manifest
	updated_dep := dep
	updated_dep.commit = strings.clone(new_commit)
	updated_dep.hash = strings.clone(new_hash)
	deps[name] = updated_dep

	if write_manifest(MANIFEST_FILE, deps) {
		print_success(fmt.tprintf("Updated %s: %s -> %s",
			name,
			dep.commit[:min(len(dep.commit), 12)],
			new_commit[:min(len(new_commit), 12)]))

		patch_path := filepath.join({"patches", fmt.tprintf("%s.patch", name)}, context.allocator)
		defer delete(patch_path)
		if os2.exists(patch_path) {
			print_info(fmt.tprintf("Patch exists for %s. Run 'chi vendor' to re-vendor and auto-apply it.", name))
		}
	} else {
		print_error("Failed to write chi.odin")
		os2.exit(1)
	}
}

// chi remove <name> — Remove a dependency and its vendored files
cmd_remove :: proc(name: string) {
	deps, ok := read_manifest(MANIFEST_FILE)
	if !ok {
		print_error("Failed to read chi.odin")
		os2.exit(1)
	}

	if !(name in deps) {
		print_error(fmt.tprintf("Dependency '%s' not found in chi.odin", name))
		os2.exit(1)
	}

	delete_key(&deps, name)

	if write_manifest(MANIFEST_FILE, deps) {
		print_success(fmt.tprintf("Removed %s from chi.odin", name))
	} else {
		print_error("Failed to write chi.odin")
		os2.exit(1)
	}

	vendor_path := filepath.join({"vendor", name}, context.allocator)
	defer delete(vendor_path)

	if os2.exists(vendor_path) {
		os2.remove_all(vendor_path)
		print_success(fmt.tprintf("Removed vendor directory for %s", name))
	}
}

// chi list — List all dependencies
cmd_list :: proc() {
	deps, ok := read_manifest(MANIFEST_FILE)
	if !ok {
		print_error("Failed to read chi.odin. Run 'chi init' first.")
		os2.exit(1)
	}

	if len(deps) == 0 {
		print_info("No dependencies")
		return
	}

	for name, dep in deps {
		commit_short := dep.commit[:min(len(dep.commit), 12)]
		if dep.path != "" {
			fmt.printfln("  %s  %s@%s  (local: %s)", name, dep.url, commit_short, dep.path)
		} else {
			fmt.printfln("  %s  %s@%s", name, dep.url, commit_short)
		}
	}
}

// chi check — Verify vendor/ matches manifest hashes
cmd_check :: proc() {
	deps, ok := read_manifest(MANIFEST_FILE)
	if !ok {
		print_error("Failed to read chi.odin")
		os2.exit(1)
	}

	if len(deps) == 0 {
		print_info("No dependencies to check")
		return
	}

	all_ok := true
	for name, dep in deps {
		// Skip hash check for forked dependencies
		if name in fork_overrides {
			print_info(fmt.tprintf("%s: skipping hash check (forked)", name))
			continue
		}

		vendor_path := filepath.join({"vendor", name}, context.allocator)
		defer delete(vendor_path)

		if !os2.exists(vendor_path) {
			print_error(fmt.tprintf("%s: not vendored (vendor/%s not found)", name, name))
			all_ok = false
			continue
		}

		actual_hash, hash_ok := hash_directory(vendor_path)
		if !hash_ok {
			print_error(fmt.tprintf("%s: failed to compute hash", name))
			all_ok = false
			continue
		}
		defer delete(actual_hash)

		if actual_hash != dep.hash {
			print_error(fmt.tprintf(
				"%s: HASH MISMATCH\n  expected: %s\n  actual:   %s",
				name, dep.hash, actual_hash))
			all_ok = false
		} else {
			print_success(fmt.tprintf("%s: verified", name))
		}
	}

	if all_ok {
		print_success("All dependencies verified")
	} else {
		print_error("Integrity check failed")
		os2.exit(1)
	}
}

// chi patch — Generate .patch files for modified vendored dependencies
cmd_patch :: proc() {
	deps, ok := read_manifest(MANIFEST_FILE)
	if !ok {
		print_error("Failed to read chi.odin. Run 'chi init' first.")
		os2.exit(1)
	}

	if len(deps) == 0 {
		print_info("No dependencies to patch")
		return
	}

	// Check that diff is available
	if !run_cmd_silent({"diff", "--version"}) {
		print_error("'diff' command not found. Install diffutils and ensure 'diff' is in your PATH.")
		os2.exit(1)
	}

	// Ensure patches directory exists
	if !os2.exists("patches") {
		err := os2.make_directory("patches")
		if err != nil {
			print_error("Failed to create patches/ directory")
			os2.exit(1)
		}
	}

	// Create temp directory for baseline copies
	tmp_dir := ".chi_tmp"
	if os2.exists(tmp_dir) {
		os2.remove_all(tmp_dir)
	}
	os2.make_directory(tmp_dir)
	defer os2.remove_all(tmp_dir)

	any_patches := false
	for name, dep in deps {
		vendor_path := filepath.join({"vendor", name}, context.allocator)
		defer delete(vendor_path)

		if !os2.exists(vendor_path) {
			continue
		}

		// Ensure the cached baseline exists
		if !is_cached(dep.url, dep.commit) {
			print_info(fmt.tprintf("Fetching baseline for %s ...", name))
			if !git_fetch_to_cache(dep.url, dep.commit) {
				print_error(fmt.tprintf("Failed to fetch baseline for %s", name))
				continue
			}
		}

		cache_path, cache_ok := get_cached_path(dep.url, dep.commit)
		if !cache_ok {
			print_error(fmt.tprintf("Failed to get cache path for %s", name))
			continue
		}
		defer delete(cache_path)

		// Copy baseline to temp dir (excluding .git)
		baseline_path := filepath.join({tmp_dir, name}, context.allocator)
		defer delete(baseline_path)

		if !copy_to_vendor(cache_path, baseline_path) {
			print_error(fmt.tprintf("Failed to copy baseline for %s", name))
			continue
		}

		// Run diff -ruN baseline vendor/<name>
		// diff exit code: 0 = no diff, 1 = differences found, >1 = error
		patch_path := filepath.join({"patches", fmt.tprintf("%s.patch", name)}, context.allocator)
		defer delete(patch_path)

		state, stdout, stderr, exec_err := os2.process_exec(
			os2.Process_Desc{
				command = {"diff", "-ruN", baseline_path, vendor_path},
			},
			context.allocator,
		)
		defer delete(stdout)
		defer delete(stderr)

		if exec_err != nil || state.exit_code > 1 {
			print_error(fmt.tprintf("Failed to run diff for %s", name))
			continue
		}

		diff_output := string(stdout)
		if state.exit_code == 0 {
			// No differences
			if os2.exists(patch_path) {
				os2.remove(patch_path)
			}
			print_info(fmt.tprintf("%s: no changes", name))
		} else {
			// exit_code == 1: differences found
			write_err := os2.write_entire_file_from_string(patch_path, diff_output)
			if write_err != nil {
				print_error(fmt.tprintf("Failed to write patch for %s", name))
				continue
			}
			print_success(fmt.tprintf("%s: patch saved to %s", name, patch_path))
			any_patches = true
		}
	}

	if !any_patches {
		print_info("No modifications detected in vendored dependencies")
	}
}
