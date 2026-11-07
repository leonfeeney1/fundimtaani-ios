# FundiMtaani for iOS

A WKWebView wrapper around the live FundiMtaani web app
(https://fundimtaani.me/). It is a wrapper, not a native rebuild: every feature and
every pixel of the UI comes from the live site, so the app keeps 100%
of the web app's features and the exact same look. There is no native
API and no backend work in this project.

## What is in this build

- SwiftUI only, iOS 17+, iPhone-only, Swift 5, no external dependencies.
- `WKWebView` with a persistent default website data store, so the
  Flask session cookie (4-hour lifetime) survives app restarts. Cookies
  are never cleared by the app.
- Native mode pill (Live / Maintenance / Pre-launch / Unavailable /
  Offline), loading progress indicator, pull-to-refresh, back/forward
  swipe gestures, and a native offline screen with a Retry button.
- `wa.me`, `tel:` and `mailto:` links open externally; `target="_blank"`
  links open same-site documents in an in-app Safari sheet and
  everything else externally. Redirects are followed, never treated
  as errors. Failed logins are never auto-retried (the site rate-limits
  login at 10/hr and admin login at 3/hr).

## Customer app notes

- Entry URL is `https://fundimtaani.me/`. The mode pill in the toolbar
  shows Live, Maintenance, Pre-launch, Unavailable or Offline, detected
  from the HTTP status of the top-level load (200 vs 503) and, for 503,
  from the loaded page's wording. On a 503 the site's own maintenance
  or pre-launch page is shown as-is.
- This app never links to `/admin`. There is deliberately no public link
  to the admin console.

## How to open and run it

You need a Mac with Xcode 16 or later.

1. Open `FundiMtaani.xcodeproj` in Xcode.
2. Select a simulator (for example iPhone 16) and press Run.

## How to get a signed IPA

No signed IPA is produced by this workspace build. A signed IPA needs
all of the following, none of which exists on this Linux machine:

1. A Mac with Xcode.
2. An Apple Developer account (paid, for App Store / TestFlight
   distribution) or a free account for development sideloading.
3. A signing team selected in Xcode, under Signing and Capabilities.
4. The bundle id changed from the placeholder `me.starford.fundimtaani` to your own
   team id and bundle id, in the target settings.
5. A provisioning profile for that bundle id, created in the Apple
   Developer portal or by Xcode automatic signing.

Once those are in place, in Xcode choose Product, Archive, then
Distribute App, and pick the destination (App Store Connect, Ad Hoc,
or Development). Or push this project to GitHub and let the included
workflow build it: `.github/workflows/ios-build.yml` builds on
macOS-latest and uploads an **unsigned** IPA as an artifact. That
unsigned IPA proves the project builds; it does not install on a
phone without a signature.

## Honest limits of this build

- **No Xcode compile was run here.** This is a Linux machine with no
  Xcode and no Swift toolchain. The project files were verified by
  structure checks only (see `BUILD_NOTES.md` in the parent folder).
  The GitHub Actions workflow is the first real compile test.
- **No signed IPA was produced here.**
- **No live WKWebView session was tested.** The wrapper has never been
  run against the live site from an app; mode detection, the offline
  screen, downloads and the admin login flow are code-level only.
- The live site is currently returning HTTP 503 (the maintenance /
  pre-launch gate is active), so the customer app will show the site's
  own 503 page until the gate is lifted in `/admin/settings`.
- App Store review note: this is a wrapper around Kerry's own web app.
  Review it against the App Store Review Guidelines (notably the
  "minimum functionality" guidance for web-view apps) before any
  App Store submission; sideloading / TestFlight distribution is the
  safer first step.

## Brand

Real FundiMtaani logo-mark (`brand/logo-mark.svg`) rendered with
cairosvg. Deep green `#0F4C3A`, hover `#0A3327`, amber accent
`#D97706`, ink `#0F172A`. Native chrome uses the iOS system font
(Plus Jakarta Sans is a web font, not on iOS).

## Project layout

```
FundiMtaani.xcodeproj/project.pbxproj
FundiMtaani/
  FundiMtaaniApp.swift
  Brand.swift
  SiteMode.swift
  WebViewContainer.swift
  ContentView.swift
  Info.plist
  Assets.xcassets/
.github/workflows/ios-build.yml
README.md
```
