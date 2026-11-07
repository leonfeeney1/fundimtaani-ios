# FundiMtaani iOS

Two WKWebView wrapper apps for FundiMtaani (fundimtaani.me) — wrappers, not
native rebuilds, so they keep 100% of the web app's features and the exact
same UI. No native API, no backend changes.

- **FundiMtaani/** — customer app. Bundle `me.starford.fundimtaani`,
  entry `https://fundimtaani.me/`. iOS 17+, iPhone-only, SwiftUI, no
  dependencies. Shows a native Live / Maintenance / Pre-launch / Offline
  mode pill read from the site's own responses (there is no health
  endpoint); on a 503 it shows the site's own holding page as-is.
- **FundiMtaaniAdmin/** — admin app, separate bundle
  `me.starford.fundimtaani.admin`, entry `https://fundimtaani.me/admin`
  (bypasses the maintenance/pre-launch gate). Password + optional TOTP
  login inside the WebView; downloads for backup `.sql` files and CSV
  exports. Distinct dark-ink icon so the two apps are never confused.

## Builds

GitHub Actions builds unsigned IPAs on every push to `main` (one workflow
per app, path-filtered):

- `ios-build-customer.yml` → artifact `FundiMtaani-unsigned-ipa`
- `ios-build-admin.yml` → artifact `FundiMtaaniAdmin-unsigned-ipa`

Download the artifact from the green run and sideload. The IPAs are
unsigned; they are not App Store builds. See `BUILD_NOTES.md` and
`AUDIT.md` for the full audit, the mode-detection design, and what was
and was not verified (no Xcode compile was run on Linux; the Actions
runs are the first real compile).
