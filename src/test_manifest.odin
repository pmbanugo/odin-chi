package main

import "core:testing"
import "core:os/os2"
import "core:fmt"
import "core:strings"
import "core:path/filepath"

@(test)
test_write_and_read_manifest :: proc(t: ^testing.T) {
	tmp_dir := "test_tmp_manifest"
	os2.make_directory(tmp_dir)
	defer os2.remove_all(tmp_dir)

	manifest_path := filepath.join({tmp_dir, "chi.odin"}, context.allocator)

	deps := make(map[string]Dependency)
	deps["odin-http"] = Dependency{
		url    = "github.com/laytan/odin-http",
		commit = "734920b8c4fe298dd162109e080e6fc92d1aad6a",
		hash   = "blake2b-f7b1842ffe1e499c91ba7d36f4ae4c1e7a1c5d3e",
	}
	deps["other-pkg"] = Dependency{
		url    = "github.com/user/other-pkg",
		commit = "abc123def456",
		hash   = "blake2b-abc123",
		path   = "/local/path",
	}

	ok := write_manifest(manifest_path, deps)
	testing.expect(t, ok, "write_manifest should succeed")

	for k, v in deps {
		delete(k)
		delete(v.url)
		delete(v.commit)
		delete(v.hash)
		delete(v.path)
	}
	delete(deps)

	read_deps, read_ok := read_manifest(manifest_path)
	testing.expect(t, read_ok, "read_manifest should succeed")
	testing.expect(t, len(read_deps) == 2, fmt.tprintf("expected 2 deps, got %d", len(read_deps)))

	dep1 := read_deps["odin-http"]
	testing.expect(t, dep1.url == "github.com/laytan/odin-http", 
		fmt.tprintf("expected url github.com/laytan/odin-http, got %q", dep1.url))
	testing.expect(t, dep1.commit == "734920b8c4fe298dd162109e080e6fc92d1aad6a",
		fmt.tprintf("expected commit, got %q", dep1.commit))
	testing.expect(t, dep1.hash == "blake2b-f7b1842ffe1e499c91ba7d36f4ae4c1e7a1c5d3e",
		fmt.tprintf("expected hash, got %q", dep1.hash))
	testing.expect(t, dep1.path == "",
		fmt.tprintf("expected empty path, got %q", dep1.path))

	dep2 := read_deps["other-pkg"]
	testing.expect(t, dep2.url == "github.com/user/other-pkg",
		fmt.tprintf("expected url, got %q", dep2.url))
	testing.expect(t, dep2.path == "/local/path",
		fmt.tprintf("expected path /local/path, got %q", dep2.path))

	for k, v in read_deps {
		delete(k)
		delete(v.url)
		delete(v.commit)
		delete(v.hash)
		delete(v.path)
	}
	delete(read_deps)
	delete(manifest_path)
}

@(test)
test_write_empty_manifest :: proc(t: ^testing.T) {
	tmp_dir := "test_tmp_empty"
	os2.make_directory(tmp_dir)
	defer os2.remove_all(tmp_dir)

	manifest_path := filepath.join({tmp_dir, "chi.odin"}, context.allocator)

	ok := write_empty_manifest(manifest_path)
	testing.expect(t, ok, "write_empty_manifest should succeed")

	deps, read_ok := read_manifest(manifest_path)
	testing.expect(t, read_ok, "read_manifest should succeed")
	testing.expect(t, len(deps) == 0, fmt.tprintf("expected 0 deps, got %d", len(deps)))

	delete(deps)
	delete(manifest_path)
}

@(test)
test_read_nonexistent_manifest :: proc(t: ^testing.T) {
	deps, ok := read_manifest("nonexistent_chi.odin")
	testing.expect(t, !ok, "read_manifest should fail for nonexistent file")
	testing.expect(t, len(deps) == 0, "deps should be empty")
}

@(test)
test_manifest_with_comments :: proc(t: ^testing.T) {
	tmp_dir := "test_tmp_comments"
	os2.make_directory(tmp_dir)
	defer os2.remove_all(tmp_dir)

	manifest_path := filepath.join({tmp_dir, "chi.odin"}, context.allocator)
	content := `
package deps

// This is a comment
Dependencies :: map[string]Dependency{
    "test-pkg" = {
        url    = "github.com/test/pkg",
        commit = "abc123",
        hash   = "blake2b-xyz",
    },
}

Dependency :: struct {
    url:    string,
    commit: string,
    hash:   string,
    path:   string,
}
`
	_ = os2.write_entire_file_from_string(manifest_path, content)

	deps, ok := read_manifest(manifest_path)
	testing.expect(t, ok, "read_manifest should succeed")
	testing.expect(t, len(deps) == 1, fmt.tprintf("expected 1 dep, got %d", len(deps)))

	dep := deps["test-pkg"]
	testing.expect(t, dep.url == "github.com/test/pkg",
		fmt.tprintf("expected url, got %q", dep.url))

	for k, v in deps {
		delete(k)
		delete(v.url)
		delete(v.commit)
		delete(v.hash)
		delete(v.path)
	}
	delete(deps)
	delete(manifest_path)
}
