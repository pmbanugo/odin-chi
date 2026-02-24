package main

import "core:testing"
import "core:os/os2"
import "core:fmt"
import "core:strings"
import "core:path/filepath"

@(test)
test_hash_directory :: proc(t: ^testing.T) {
	tmp_dir := "test_tmp_hash"
	os2.make_directory(tmp_dir)
	defer os2.remove_all(tmp_dir)

	file1_path := filepath.join({tmp_dir, "file1.txt"}, context.allocator)
	file2_path := filepath.join({tmp_dir, "file2.txt"}, context.allocator)
	_ = os2.write_entire_file_from_string(file1_path, "hello world")
	_ = os2.write_entire_file_from_string(file2_path, "test content")

	hash1, ok1 := hash_directory(tmp_dir)
	testing.expect(t, ok1, "hash_directory should succeed")
	testing.expect(t, len(hash1) > 0, "hash should not be empty")
	testing.expect(t, strings.has_prefix(hash1, HASH_PREFIX), 
		fmt.tprintf("hash should start with %q", HASH_PREFIX))
	delete(hash1)
	delete(file1_path)
	delete(file2_path)

	tmp_dir2 := "test_tmp_hash2"
	os2.make_directory(tmp_dir2)
	defer os2.remove_all(tmp_dir2)

	file3_path := filepath.join({tmp_dir2, "file3.txt"}, context.allocator)
	_ = os2.write_entire_file_from_string(file3_path, "different content")

	hash2, ok2 := hash_directory(tmp_dir2)
	testing.expect(t, ok2, "hash_directory should succeed for different content")
	delete(hash2)
	delete(file3_path)
}

@(test)
test_hash_empty_directory :: proc(t: ^testing.T) {
	tmp_dir := "test_tmp_empty_hash"
	os2.make_directory(tmp_dir)
	defer os2.remove_all(tmp_dir)

	hash, ok := hash_directory(tmp_dir)
	testing.expect(t, !ok, "hash_directory should fail for empty directory")
	testing.expect(t, hash == "", "hash should be empty for empty directory")
}

@(test)
test_hash_nonexistent_directory :: proc(t: ^testing.T) {
	hash, ok := hash_directory("nonexistent_directory_12345")
	testing.expect(t, !ok, "hash_directory should fail for nonexistent directory")
	testing.expect(t, hash == "", "hash should be empty")
}

@(test)
test_verify_hash :: proc(t: ^testing.T) {
	tmp_dir := "test_tmp_verify"
	os2.make_directory(tmp_dir)
	defer os2.remove_all(tmp_dir)

	file_path := filepath.join({tmp_dir, "content.txt"}, context.allocator)
	_ = os2.write_entire_file_from_string(file_path, "some content to hash")

	actual_hash, ok := hash_directory(tmp_dir)
	testing.expect(t, ok, "hash_directory should succeed")
	defer delete(actual_hash)

	valid := verify_hash(tmp_dir, actual_hash)
	testing.expect(t, valid, "verify_hash should return true for correct hash")

	invalid := verify_hash(tmp_dir, "blake2b-incorrecthash12345678901234567890123456789012")
	testing.expect(t, !invalid, "verify_hash should return false for incorrect hash")
	delete(file_path)
}

@(test)
test_hash_excludes_git_directory :: proc(t: ^testing.T) {
	tmp_dir := "test_tmp_git_exclude"
	os2.make_directory(tmp_dir)
	defer os2.remove_all(tmp_dir)

	git_dir := filepath.join({tmp_dir, ".git"}, context.allocator)
	os2.make_directory(git_dir)
	git_file := filepath.join({git_dir, "config"}, context.allocator)
	_ = os2.write_entire_file_from_string(git_file, "git config content")
	main_file := filepath.join({tmp_dir, "main.txt"}, context.allocator)
	_ = os2.write_entire_file_from_string(main_file, "main content")

	hash, ok := hash_directory(tmp_dir)
	testing.expect(t, ok, "hash_directory should succeed")

	testing.expect(t, !strings.contains(hash, ".git"),
		"hash should not contain .git paths")
	delete(hash)
	delete(git_dir)
	delete(git_file)
	delete(main_file)
}
