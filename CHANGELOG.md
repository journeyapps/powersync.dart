# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2024-05-30

### Changes

---

Packages with breaking changes:

 - [`powersync_attachments_helper` - `v0.3.0-alpha.2`](#powersync_attachments_helper---v030-alpha2)

Packages with other changes:

 - [`powersync` - `v1.3.0-alpha.5`](#powersync---v130-alpha5)

---

#### `powersync_attachments_helper` - `v0.3.0-alpha.2`

 - **FIX**: reset isProcessing when exception is thrown during sync process. (#81).
 - **FIX**: attachment queue duplicating requests (#68).
 - **FIX**(powersync-attachements-helper): pubspec file (#29).
 - **FEAT**(attachments): add error handlers (#65).
 - **DOCS**: update readmes (#38).
 - **BREAKING** **FEAT**(attachments): cater for subdirectories in storage (#78).

#### `powersync` - `v1.3.0-alpha.5`

 - **FIX**(powersync-attachements-helper): pubspec file (#29).
 - **DOCS**: update readme and getting started (#51).


## 2024-03-05

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`powersync` - `v1.3.0-alpha.3`](#powersync---v130-alpha3)
 - [`powersync_attachments_helper` - `v0.3.0-alpha.2`](#powersync_attachments_helper---v030-alpha2)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `powersync_attachments_helper` - `v0.3.0-alpha.2`

---

#### `powersync` - `v1.3.0-alpha.3`

 - Fixed issue where disconnectAndClear would prevent subsequent sync connection on native platforms and would fail to clear the database on web.


## 2024-02-15

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`powersync` - `v1.3.0-alpha.2`](#powersync---v130-alpha2)
 - [`powersync_attachments_helper` - `v0.3.0-alpha.2`](#powersync_attachments_helper---v030-alpha2)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `powersync_attachments_helper` - `v0.3.0-alpha.2`

---

#### `powersync` - `v1.3.0-alpha.2`

 - **FIX**(powersync-attachements-helper): pubspec file (#29).
 - **DOCS**: update readme and getting started (#51).

