# `chi` — Minimalist Dependency Manager for Odin

`chi` is a lightweight, high-performance CLI tool for downloading and vendoring external dependencies for the Odin programming language.

It is built with minimalism and integrity in mind:
- **No Central Registry:** The internet (Git) is the source of truth.
- **Zero Magic:** No background daemons or hidden state. Everything is explicit.
- **Odin-First:** Configuration is written in pure Odin syntax (`chi.odin`).
- **Reproducible:** Uses BLAKE2b content hashing to verify vendored files haven't been tampered with. (*p.s* I'd like to switch to BLAKE3 when Odin has it in its core package).

## Installation

Download the binary for your OS from the [Releases](https://github.com/pmbanugo/odin-chi/releases) page and place it in your `$PATH`.

Or build from source:

```bash
git clone https://github.com/pmbanugo/odin-chi
cd odin-chi
odin build src/ -out:chi
```

## Testing

Run the test suite using Odin's built-in test runner:

```bash
odin test src/ -all-packages
```

Run specific tests:

```bash
# Test utility functions
odin test src/ -all-packages -define:ODIN_TEST_NAMES=main.test_url_to_dir_name,main.test_url_to_pkg_name

# Test manifest parsing
odin test src/ -all-packages -define:ODIN_TEST_NAMES=main.test_write_and_read_manifest

# Test hashing
odin test src/ -all-packages -define:ODIN_TEST_NAMES=main.test_hash_directory,main.test_verify_hash
```

The test suite includes:
- **Unit tests** for utility functions, manifest parsing, and hashing
- Uses `core:testing` with memory tracking enabled
- Tests are designed to be isolated, repeatable, and automatable

## Usage

### 1. Initialize

In your project root, run:

```bash
chi init
```

This creates a `chi.odin` manifest file. The manifest is written in pure Odin code so it can be integrated directly into your build scripts if desired.

### 2. Add Dependencies

Add a dependency by providing its Git URL. By default, `chi` fetches the latest commit (`HEAD`):

```bash
chi add github.com/laytan/odin-http
```

You can optionally pin to a specific branch, tag, or commit hash:

```bash
chi add github.com/laytan/odin-http v0.0.1
chi add github.com/laytan/odin-http 534ff16fe4ee697d
```

### 3. Fetch & Vendor

Download dependencies to the global cache (`~/.cache/chi`):

```bash
chi fetch
```

Populate the local `vendor/` directory from the cache:

```bash
chi vendor
```

> **Note**: `chi vendor` automatically verifies the BLAKE2b hash of the downloaded content against the hash stored in `chi.odin`. If the content was tampered with (e.g., via a force-pushed commit), vendoring will fail.

### 4. Update or Remove

Update an existing dependency to its latest commit:

```bash
chi update odin-http
```

Remove a dependency from the manifest and delete its `vendor/` directory:

```bash
chi remove odin-http
```

### 5. Integrity Check

At any time, you can verify that your local vendored files match the exact hashes recorded in your `chi.odin` manifest:

```bash
chi check
```

## The `chi.odin` Format

The manifest file generated and managed by `chi` looks like this:

```odin
package deps

Dependencies :: map[string]Dependency{
    "odin-http" = {
        url    = "github.com/laytan/odin-http",
        commit = "734920b8c4fe298dd162109e080e6fc92d1aad6a",
        hash   = "blake2b-f7b1842...",
    },
}

Dependency :: struct {
    url:    string,
    commit: string,
    hash:   string,
    path:   string, // Local override path
}
```

### Local Development Overrides

If you are developing a dependency locally, you can temporarily override the network fetch by manually adding a `path` property to your `chi.odin` entry:

```odin
    "odin-http" = {
        url    = "github.com/laytan/odin-http",
        commit = "734920b8...",
        hash   = "blake2b-f7b1842...",
        path   = "../local/my-odin-http-fork",
    },
```

When you run `chi vendor`, it will copy files entirely from your local path, ignoring the remote repository and skips the integrity check for that specific dependency.
