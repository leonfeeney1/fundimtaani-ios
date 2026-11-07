# FundiMtaani iOS — Build notes

Built 7 Nov 2026, workspace only. Kerry's laptop was not touched, nothing
was pushed to any repo, nothing was deployed. No repo exists yet for
fundimtaani-ios — Kerry must create it / say where it goes before anything
is pushed. The audit at `AUDIT.md` (live laptop code, HEAD `5964e8c`,
7 Nov 2026) was read first and followed exactly.

## What was built

Two separate WKWebView wrapper apps — wrappers, not native rebuilds, so
they keep 100% of the web app's features and the exact same UI. There is
no native API to build against and no backend work was needed. Both are
SwiftUI, iOS 17+, iPhone-only, Swift 5, zero external dependencies, no
emojis anywhere in the UI. Each has its own Xcode project, its own
workflow, its own cookie store and its own AppIcon.

### 1. FundiMtaani (customer) — `FundiMtaani/`

- Bundle id placeholder `me.starford.fundimtaani`. Entry URL
  `https://fundimtaani.me/`.
- `FundiMtaani/FundiMtaaniApp.swift` — `@main` entry.
- `FundiMtaani/Brand.swift` — brand colours (primary `#0F4C3A`, hover
  `#0A3327`, accent `#D97706`, ink `#0F172A`, body `#334155`), entry URL,
  site host. Native chrome uses the iOS system font (Plus Jakarta Sans
  is a web font, not on iOS).
- `FundiMtaani/SiteMode.swift` — mode enum + 503-page classifier.
- `FundiMtaani/WebViewContainer.swift` — WKWebView, navigation/UI
  delegates, progress KVO, pull-to-refresh, Safari sheet.
- `FundiMtaani/ContentView.swift` — mode pill toolbar, progress bar,
  offline screen with Retry.
- `FundiMtaani/Info.plist` — UILaunchScreen (LaunchBackground +
  LaunchLogo), `UIRequiredDeviceCapabilities` `arm64`,
  `TARGETED_DEVICE_FAMILY` 1.
- `FundiMtaani.xcodeproj/project.pbxproj` — hand-written minimal project.
- `.github/workflows/ios-build.yml` — simulator build, then an unsigned
  archive IPA; `xcodebuild -list` guard step first, fails clearly if no
  `.app` is found. Uses `-target` (not `-scheme`) because no shared
  scheme file is committed, as in PremiumSlots v1.
- `README.md` — open/run, signed-IPA steps, unsigned-IPA sideload
  caveat, honest limits.

### 2. FundiMtaani Admin — `FundiMtaaniAdmin/`

- Bundle id placeholder `me.starford.fundimtaani.admin`. Entry URL
  `https://fundimtaani.me/admin` — the `/admin` prefix bypasses the
  maintenance / pre-launch gate, so the admin app stays usable while
  the public site is down.
- Same 5 Swift files, same wrapper core. Differences from the customer
  app: entry URL, launch background (dark ink `#0F172A`), admin AppIcon
  and launch art (see below), and a `WKDownloadDelegate` in
  `WebViewContainer.swift`.
- Password + optional TOTP admin login runs inside the WebView on the
  site's own pages; no credentials are stored in the app.
- This app never links to the public site, and the customer app never
  links to `/admin` (verified: no `/admin` string in any customer Swift
  file). There is deliberately no public link to the console.

## Mode detection design

The site has **no** health / status endpoint, so the mode is only
visible from the HTTP status of the top-level load, captured in
`decidePolicyFor navigationResponse` for the main frame:

- `200` → **Live**
- `503` → maintenance **or** pre-launch. The two pages are told apart
  in `didFinish` by evaluating the loaded page's title + first 2,000
  characters of body text: wording containing "pre-launch" /
  "prelaunch" / "launching soon" / "coming soon" → Pre-launch;
  "maintenance" / "under maintenance" / "be right back" / "back soon"
  → Maintenance. If the wording cannot be read or matches neither,
  the pill falls back to **Unavailable** rather than guessing.
- Network failure (and nothing loaded yet) → **Offline**, with the
  native offline screen and Retry button.

On a 503 the site's own maintenance / pre-launch page is displayed
as-is. It is never replaced with a native screen.

## Navigation and download handling

- Top-level load only; the site sends `X-Frame-Options: DENY`.
- Persistent default website data store (`WKWebsiteDataStore.default()`),
  never cleared on restart — the Flask session cookie (4-hour lifetime)
  survives. Each app is a separate app, so each has its own store;
  customer and admin sessions wipe each other in the same cookie jar
  (`session.clear()` on login), which is why the two apps must never
  share one.
- `wa.me`, `tel:` and `mailto:` links are intercepted in
  `decidePolicyForNavigationAction` and opened externally via
  `UIApplication`.
- `target="_blank"` links are not swallowed: same-site document links
  open in an in-app Safari sheet (`SFSafariViewController`), everything
  else opens externally. `createWebViewWith` handles the same cases.
- Redirects are followed normally and never treated as errors (the
  technician join gate redirects on almost every endpoint).
- Failed logins are never auto-retried: login is rate-limited at
  10/hr and admin login at 3/hr, so a retry loop would lock the user
  out. The server's own error page is shown instead.
- Pull-to-refresh via `UIRefreshControl` on the web view's scroll view;
  back/forward swipe gestures via
  `allowsBackForwardNavigationGestures`.
- Downloads (admin app only): `WKDownloadDelegate` intercepts
  `/admin/backups/download/<name>` (`.sql`), `/admin/users.csv`,
  `/admin/export/bookings` and `/admin/export/workers` (CSV), saves to
  the Documents directory and offers the file through the system share
  sheet / Files picker. Verification documents are served inline and
  open in the Safari sheet, not as downloads. The customer app has no
  download delegate.

## Logo rendering

Real files only, from `brand/` (fetched live from the laptop, see
`AUDIT.md` §4). Nothing was redrawn or invented.

- `cairosvg` was installed (`pip install cairosvg
  --break-system-packages`, as for PremiumSlots) and used to render
  `brand/logo-mark.svg` to PNG.
- Customer AppIcon: the real mark rendered at 1024px, composited onto
  a solid deep-green `#0F4C3A` canvas (the SVG has transparent corners;
  compositing prevents black corners), then downscaled with Lanczos to
  every required size (20@2x/3x, 29@2x/3x, 40@2x/3x, 60@2x/3x, 76@2x,
  83.5@2x, 1024 marketing), all listed in `Contents.json`.
- Admin AppIcon: the same real mark at 76% composited onto a dark ink
  `#0F172A` canvas with an amber `#D97706` accent ring — visibly
  distinct from the customer icon at a glance, same logo.
- Launch logos: customer mark at 120/240/360px on deep green;
  admin mark at 120/240/360px on dark ink with the amber ring.
  Launch backgrounds: customer `#0F4C3A`, admin `#0F172A`
  (`LaunchBackground.colorset`); accent colour `#D97706`.
- Pixel verification (PIL): customer icon-1024 corner `(15, 76, 58)`
  (deep green), centre `(15, 76, 58)`; admin icon-1024 corner
  `(15, 23, 42)` (ink), centre `(15, 76, 58)` (the mark). Both icons
  are 81% / 47% green pixels respectively with white and amber mark
  detail — non-blank. An early render with transparent corners
  (black `(0, 0, 0)` corners) was caught by this check and fixed by
  compositing onto solid canvases.

## Checks run on 7 Nov 2026 (this Linux machine)

Full script: `/tmp/verify_fundimtaani_ios.py` (not kept in the repo).
**45/45 checks passed.**

- Every Swift file referenced in each `project.pbxproj` exists on disk
  (5 of 5 per app) and every Swift file on disk is referenced and in
  the Sources build phase.
- Each `project.pbxproj` parses with the `pbxproj` Python library
  (28 objects, 1 target, all IDs unique), braces and parentheses
  balance, zero double commas `,,` (the defect that broke the
  PremiumSlots project file before — zero tolerance).
- Each `Info.plist` parses (`plistlib`); UILaunchScreen present with
  LaunchLogo; `UIRequiredDeviceCapabilities` is `arm64`.
- Every asset `Contents.json` parses as JSON and every listed filename
  exists on disk (AppIcon, LaunchLogo, AccentColor, LaunchBackground).
- Both workflow files parse as YAML (jobs: build).
- Brace and parenthesis counts balance in every Swift file (10 of 10).
- Emoji scan over all Swift files: zero hits.
- No banned invented content in any Swift file: no `/api/status`, no
  `/health`, no fake/mock/dummy content. The wrapper loads the live
  site, so nothing is faked. Customer Swift contains no `/admin`
  string; admin Swift contains the download delegate and the `/admin`
  entry URL.
- AppIcon and LaunchLogo PNGs verified non-blank by pixel counts (see
  above).
- Live entry URLs checked from here with curl on 7 Nov 2026:
  `https://fundimtaani.me/` → **HTTP 503** (gate active, as the audit
  found); `https://fundimtaani.me/admin` → **HTTP 302** to
  `https://fundimtaani.me/admin/login` (reachable, redirects to the
  admin login as expected); `https://fundimtaani.me/fundis` → 503.

## What was NOT verified

- **No Xcode compile.** This is a Linux machine with no Xcode and no
  Swift toolchain. The projects have not been compiled, so a syntax or
  SwiftUI/WebKit API error could still be present. The GitHub Actions
  workflow is the first real compile test.
- **No signed IPA was produced here.** The workflow builds an unsigned
  IPA only, and it has not been run.
- **No live WKWebView session was tested.** Mode detection, the
  offline screen, pull-to-refresh, `target="_blank"` handling,
  downloads and the admin password + TOTP login flow are code-level
  only and have never run against the live site from an app.
- **No simulator or device run.** Launch screens, the mode pill, and
  the share sheet have not been seen on a device.
- App Store review note: these are wrappers around Kerry's own web
  app. Review them against the App Store Review Guidelines (notably
  the "minimum functionality" guidance for web-view apps) before any
  App Store submission; sideloading / TestFlight distribution is the
  safer first step.

## Next steps (parent agent owns these)

1. Kerry must create a repo for fundimtaani-ios (or say where these
   projects go) before anything is pushed. No repo exists yet.
2. Push both projects; wait for the GitHub Actions runs. If green,
   download the unsigned IPAs and deliver them for sideloading, as
   with PremiumSlots.
3. Ask Kerry to check on his phone: the customer app shows the site's
   503 page with the correct mode pill (Maintenance or Pre-launch)
   while the gate is active; the admin app reaches `/admin/login`
   while the public site is down; sign-in, booking and admin backup
   download all work inside the wrappers.
