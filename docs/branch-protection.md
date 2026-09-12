# Main branch protection

Enabled September 12, 2026 at the owner's request for `rirachii/converty`. GitHub's active [Protect main ruleset](https://github.com/rirachii/converty/rules/23016475), ID `23016475`, targets exactly `refs/heads/main`. The intended configuration is tracked in [`.github/rulesets/main.json`](../.github/rulesets/main.json); GitHub settings enforce it, not the presence of this file.

## Enforced rules

- Changes must go through a pull request.
- Required `Landing page build`, `Native core tests`, and `Web checks` checks must come from the GitHub Actions integration (ID `15368`).
- The pull request must be up to date with `main` before merging.
- Review conversations must be resolved; new changes dismiss prior approvals.
- Force pushes and deletion are blocked.
- The bypass list is empty, including for repository administrators and automation.
- Existing merge, squash, and rebase methods remain available.

Approving-review count is zero because the repository currently has one collaborator, `rirachii`. Pull requests and CI remain mandatory without requiring a second person's approval. Revisit this setting when another maintainer is added. Do not add an admin or bot bypass to work around failing checks.

## Required check coverage

All three jobs in `.github/workflows/ci.yml` run on every pull request without path filters:

| Required check | Coverage |
| --- | --- |
| `Landing page build` | Builds the native app's marketing site in `site/`. |
| `Native core tests` | Runs the Swift core tests with FFmpeg on macOS. |
| `Web checks` | Type checks, unit tests, browser acceptance, and build for the web edition. |

These checks do not establish actual native app acceptance, signing, notarization, or website deployment. Continue following the relevant development and release runbooks.

## Repository boundaries

Converty source and releases remain here. Installer definitions for Converty and Chirpberry remain together in [`rirachii/homebrew-tap`](https://github.com/rirachii/homebrew-tap), including the canonical `Casks/converty.rb`. Keep the repositories separate so existing installation commands and upstream release URLs stay stable.

Both repositories use the same protection policy with their own required check names. Their rulesets are configured independently; a change in this repository does not automatically change the tap's settings.

## Verification and maintenance

After creation, GitHub reported `main.protected = true`, all four active rules applied to `main`, and no matching rules on an unrelated branch name. The settings update left the `main` commit unchanged. The live configuration matched the tracked check names, trusted integration, strict policy, zero required approvals, and empty bypass list. No force push or deletion was attempted against the live branch.

Read the live configuration before changing it:

```sh
gh api repos/rirachii/converty/rulesets/23016475
gh api repos/rirachii/converty/rules/branches/main
gh api repos/rirachii/converty/branches/main --jq '{name, protected}'
```

Keep this document and the JSON aligned with approved settings changes. Coordinate required check names and triggers with ruleset changes so passing, up-to-date pull requests can still merge. Editing the JSON alone does not update GitHub.
