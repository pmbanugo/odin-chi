package main

import "core:testing"
import "core:os/os2"
import "core:fmt"
import "core:path/filepath"

@(test)
test_get_cache_dir :: proc(t: ^testing.T) {
	cache_dir, ok := get_cache_dir()
	testing.expect(t, ok, "get_cache_dir should succeed")
	testing.expect(t, len(cache_dir) > 0, "cache_dir should not be empty")
	testing.expect(t, os2.exists(cache_dir), "cache_dir should exist after call")
	delete(cache_dir)
}

@(test)
test_copy_to_vendor_basic :: proc(t: ^testing.T) {
	src_dir := "test_tmp_copy_src"
	dest_dir := "test_tmp_copy_dest"
	os2.make_directory(src_dir)
	defer os2.remove_all(src_dir)
	defer os2.remove_all(dest_dir)

	// Create some source files
	file1 := filepath.join({src_dir, "main.odin"}, context.allocator)
	file2 := filepath.join({src_dir, "utils.odin"}, context.allocator)
	_ = os2.write_entire_file_from_string(file1, "package main")
	_ = os2.write_entire_file_from_string(file2, "package main\nutils :: proc() {}")
	delete(file1)
	delete(file2)

	// Copy
	ok := copy_to_vendor(src_dir, dest_dir)
	testing.expect(t, ok, "copy_to_vendor should succeed")

	// Verify files exist in destination
	dest_file1 := filepath.join({dest_dir, "main.odin"}, context.allocator)
	dest_file2 := filepath.join({dest_dir, "utils.odin"}, context.allocator)
	testing.expect(t, os2.exists(dest_file1), "main.odin should exist in dest")
	testing.expect(t, os2.exists(dest_file2), "utils.odin should exist in dest")

	// Verify content
	data, err := os2.read_entire_file_from_path(dest_file1, context.allocator)
	testing.expect(t, err == nil, "should read copied file")
	testing.expect(t, string(data) == "package main",
		fmt.tprintf("expected 'package main', got %q", string(data)))
	delete(data)
	delete(dest_file1)
	delete(dest_file2)
}

@(test)
test_copy_to_vendor_excludes_git :: proc(t: ^testing.T) {
	src_dir := "test_tmp_copy_git_src"
	dest_dir := "test_tmp_copy_git_dest"
	os2.make_directory(src_dir)
	defer os2.remove_all(src_dir)
	defer os2.remove_all(dest_dir)

	// Create source files and a .git directory
	main_file := filepath.join({src_dir, "main.odin"}, context.allocator)
	_ = os2.write_entire_file_from_string(main_file, "package main")
	delete(main_file)

	git_dir := filepath.join({src_dir, ".git"}, context.allocator)
	os2.make_directory(git_dir)
	git_config := filepath.join({git_dir, "config"}, context.allocator)
	_ = os2.write_entire_file_from_string(git_config, "[core]\n\tbare = false")
	delete(git_config)
	delete(git_dir)

	// Copy
	ok := copy_to_vendor(src_dir, dest_dir)
	testing.expect(t, ok, "copy_to_vendor should succeed")

	// Verify main.odin was copied
	dest_main := filepath.join({dest_dir, "main.odin"}, context.allocator)
	testing.expect(t, os2.exists(dest_main), "main.odin should exist in dest")
	delete(dest_main)

	// Verify .git was NOT copied
	dest_git := filepath.join({dest_dir, ".git"}, context.allocator)
	testing.expect(t, !os2.exists(dest_git),
		".git directory should NOT be copied to vendor")
	delete(dest_git)
}

@(test)
test_copy_to_vendor_nested :: proc(t: ^testing.T) {
	src_dir := "test_tmp_copy_nested_src"
	dest_dir := "test_tmp_copy_nested_dest"
	os2.make_directory(src_dir)
	defer os2.remove_all(src_dir)
	defer os2.remove_all(dest_dir)

	// Create nested structure: src/sub/deep/file.txt
	sub_dir := filepath.join({src_dir, "sub"}, context.allocator)
	os2.make_directory(sub_dir)
	deep_dir := filepath.join({sub_dir, "deep"}, context.allocator)
	os2.make_directory(deep_dir)
	deep_file := filepath.join({deep_dir, "file.txt"}, context.allocator)
	_ = os2.write_entire_file_from_string(deep_file, "nested content")
	delete(sub_dir)
	delete(deep_dir)
	delete(deep_file)

	// Copy
	ok := copy_to_vendor(src_dir, dest_dir)
	testing.expect(t, ok, "copy_to_vendor should succeed for nested dirs")

	// Verify nested file exists
	dest_file := filepath.join({dest_dir, "sub", "deep", "file.txt"}, context.allocator)
	testing.expect(t, os2.exists(dest_file), "nested file should exist in dest")

	data, err := os2.read_entire_file_from_path(dest_file, context.allocator)
	testing.expect(t, err == nil, "should read nested file")
	testing.expect(t, string(data) == "nested content",
		fmt.tprintf("expected 'nested content', got %q", string(data)))
	delete(data)
	delete(dest_file)
}

@(test)
test_copy_to_vendor_overwrites :: proc(t: ^testing.T) {
	src_dir := "test_tmp_copy_overwrite_src"
	dest_dir := "test_tmp_copy_overwrite_dest"
	os2.make_directory(src_dir)
	defer os2.remove_all(src_dir)
	defer os2.remove_all(dest_dir)

	// Create initial dest with old content
	os2.make_directory(dest_dir)
	old_file := filepath.join({dest_dir, "old.txt"}, context.allocator)
	_ = os2.write_entire_file_from_string(old_file, "old content")

	// Create source with new content
	new_file := filepath.join({src_dir, "new.txt"}, context.allocator)
	_ = os2.write_entire_file_from_string(new_file, "new content")
	delete(new_file)

	// Copy should overwrite (remove old dest first)
	ok := copy_to_vendor(src_dir, dest_dir)
	testing.expect(t, ok, "copy_to_vendor should succeed")

	// Old file should be gone
	testing.expect(t, !os2.exists(old_file), "old file should not exist after overwrite")
	delete(old_file)

	// New file should exist
	dest_new := filepath.join({dest_dir, "new.txt"}, context.allocator)
	testing.expect(t, os2.exists(dest_new), "new file should exist")
	delete(dest_new)
}
