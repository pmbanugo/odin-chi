# `chi` — Minimalist Dependency Manager for Odin

`chi` is a lightweight, high-performance tool for downloading and vendoring external dependencies for the Odin programming language. It is inspired by the simplicity of **Go**, the integrity-first approach of **Zig**, and the minimalist philosophy of **gingerBill**.

## Core Philosophy

* **No Central Registry:** The internet (Git) is the source of truth.
* **Zero Magic:** No background daemons or hidden state. Everything is explicit.
* **Odin-First:** Configuration is written in Odin, making it a "Data-Only Odin" format.
* **Local Sovereignty:** Dependencies are meant to be read, vendored, and tweaked.

---

## 1. The Manifest: `chi.odin`

`chi` avoids JSON/TOML. It uses a subset of Odin syntax for high-performance parsing and ecosystem consistency.

```odin
package deps

// Chi looks for this specific constant
Dependencies :: map[string]Dependency{
    "http" = {
        url    = "github.com/laytan/odin-http",
        commit = "a1b2c3d4e5f6",
        hash   = "blake3-9f86d081884c...", // Content hash of the files
    },
}

Dependency :: struct {
    url:    string,
    commit: string,
    hash:   string,
    path:   string, // Optional: for local development overrides
}

```

---

## 2. Functional Requirements

### **A. Git-Based Fetching**

* Supports any remote Git repository (GitHub, GitLab, self-hosted).
* Uses **Git SHAs** for versioning rather than SemVer.
* Downloads are stored in a global system cache (`~/.cache/chi`) to avoid redundant network calls.

### **B. Local Vendoring**

* **`chi vendor`**: Synchronizes the project's local `vendor/` directory with the manifest.
* Dependencies are unpacked into `vendor/<pkg_name>`.
* Encourages "hermetic builds": the `vendor/` folder can be committed to source control if desired.

### **C. Integrity & Content Hashing**

* Every fetched package is hashed (ignoring the `.git` folder).
* If the remote content changes despite the Git SHA remaining the same (force-push), `chi` will refuse to vendor the package to prevent supply-chain attacks.

### **D. The "Tweak" Workflow**

* **`--fork=[name:path]`**: A CLI flag to temporarily override a dependency with a local directory for debugging or development.
* **`chi patch`**: Generates a `.patch` file if you modify code inside the `vendor/` directory, allowing you to re-apply local changes even after updating a dependency.

---

## 3. CLI Interface

| Command | Description |
| --- | --- |
| `chi init` | Initializes a `chi.odin` manifest. |
| `chi add <url>` | Adds a dependency, fetches it, and calculates the integrity hash. |
| `chi fetch` | Ensures all dependencies are in the global cache. |
| `chi vendor` | Populates the local `vendor/` folder from the cache. |
| `chi update <name>` | Checks for the latest commit on the remote and updates `chi.odin`. |
| `chi check` | Verifies that the local `vendor/` content matches the manifest hashes. |

---

## 4. Performance Goals

* **Binary Size:** Minimal dependencies; should be a single, small executable.
* **Speed:** Use [core:crypto/blake2b](https://pkg.odin-lang.org/core/crypto/blake2b/) for hashing and parallelize network fetches.
* **Parsing:** Use Odin's `core:odin/parser` to read the manifest directly, ensuring zero-cost integration for Odin users.
* Decide if we should use the systems `git` binary or use `curl` for making request. 

## 5. Additional resources

- https://pkg.odin-lang.org/core/os/
- https://pkg.odin-lang.org/vendor/curl/
- https://pkg.odin-lang.org/core/crypto/blake2b/
- https://odin-lang.org/docs/overview/
