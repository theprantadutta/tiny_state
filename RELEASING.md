# Releasing tiny_state

Releases are tag-driven. Pushing a `vX.Y.Z` tag runs
[`.github/workflows/publish.yml`](.github/workflows/publish.yml), which
re-verifies everything and publishes to pub.dev.

## One-time setup on pub.dev

Automated publishing has to be enabled on pub.dev before the workflow can
authenticate. Until this is done, the publish step will fail with an
authentication error — everything before it still runs.

1. Sign in to <https://pub.dev> as an uploader for `tiny_state`.
2. Open **Admin** → **Automated publishing**.
3. Enable **Publishing from GitHub Actions** and set:
   - Repository: `theprantadutta/tiny_state`
   - Tag pattern: `v{{version}}`
4. Leave "Require GitHub Actions environment" empty unless you add one to the
   workflow.

No secret is stored in this repository. The workflow requests a short-lived
OIDC token, which is why it declares `permissions: id-token: write`.

## Cutting a release

1. **Update the version** in `pubspec.yaml`.
2. **Add the section to `CHANGELOG.md`.** The top `## X.Y.Z` heading must match
   the pubspec version — CI enforces this, and so does the publish workflow.
3. **Verify locally:**

   ```bash
   flutter pub get
   dart format --output=none --set-exit-if-changed .
   flutter analyze --fatal-infos
   flutter test
   bash tool/check_version.sh
   flutter pub publish --dry-run
   ```

4. **Rehearse the pipeline** (optional but recommended for a major release):
   run the **Publish to pub.dev** workflow manually from the Actions tab with
   *Validate only* left checked. It does everything except the final publish.
5. **Merge to `master`** and wait for **Build and Test** to pass.
6. **Tag and push:**

   ```bash
   git tag v2.0.0
   git push origin v2.0.0
   ```

7. Watch the **Publish to pub.dev** run, then confirm the new version on
   <https://pub.dev/packages/tiny_state>.

## What CI checks

| Job | Blocking | What it covers |
| --- | --- | --- |
| `package` | yes | formatting, `analyze --fatal-infos`, tests + coverage, version consistency, `pub publish --dry-run` |
| `example` | yes | the example app analyzes and its widget test passes |
| `score` | no | `pana`, as an early warning for pub.dev score regressions |

The `score` job is advisory because pana's checks change with pub.dev; treat a
failure there as something to look at, not something to fix before merging.

## Notes

- **A published version cannot be replaced.** `pub publish` is final; only
  retraction is possible. This is why the dry run and the manual rehearsal
  exist.
- **Versioning.** This package follows semantic versioning. Anything that
  changes a signature, a default, or the behaviour of an existing call is a
  major bump — `2.0.0` was exactly that.
- **What ships.** `.pubignore` keeps the example's generated platform folders,
  CI config and internal notes out of the archive while keeping
  `example/lib/` (pub.dev renders it on the Example tab). Check what will be
  uploaded with `flutter pub publish --dry-run`.
