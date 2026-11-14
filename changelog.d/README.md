# Changelog fragments

Every PR adds one file here instead of editing `CHANGELOG.md`, so PRs never conflict on the changelog.

- **Name:** the branch name with `/` replaced by `-`, for example `feat-ci-cd-hardening.md`.
- **Content:** one line per change, starting with its Keep a Changelog section:

  ```
  Added: Post-deploy smoke check that opens a bug Issue when a deploy fails
  Fixed: SECRET_KEY_BASE under 64 bytes fails the deploy instead of serving 500s
  ```

  Sections: `Added`, `Changed`, `Fixed`, `Removed`. No PR number: `release-manager` adds it from the squash commit.
- **Release:** `release-manager` folds every fragment into the version's section of `CHANGELOG.md`, appends `(#N)` from the commit that added the fragment, and deletes the fragments in the release PR.

This README is not a fragment.
