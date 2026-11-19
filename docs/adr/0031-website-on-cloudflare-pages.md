# ADR-0031: Static website at dadsaga.app on Cloudflare Pages, in this repository

**Status:** Accepted (2026-11-19). The owner chose Cloudflare Pages and keeping the site in this repository.

## Context
The App Store needs a Support URL and a Privacy Policy URL, and the app's Settings screen has a privacy row that stays
hidden until `DadSagaPrivacyPolicyURL` is set (ADR-0030). The owner bought `dadsaga.app` at Cloudflare and set up
`hello@dadsaga.app` with Cloudflare Email Routing, forwarding to the owner's Gmail. A small page that says what the app
is and where to get it is also wanted. It has to cost nothing to run.

## Decision

### 1. Plain static files in `web/`
- Three pages, each in English (`/`) and Greek (`/el/`): the landing page, `/privacy/` and `/support/`, plus a
  `404.html`. Hand-written HTML and one stylesheet (`web/assets/site.css`); no framework, no build step, no JavaScript.
- English is the default (`x-default`) for an App Store audience; every page links to its other language and declares
  `hreflang` alternates.
- Colours mirror `DSColor` (light and dark). The images come from the app: the launch screen's Super Dad and baby
  (ADR-0025) and the app icon's layers, flattened into `web/assets/icon.svg`. When the avatars change, copy the
  `LaunchLogo-*@3x.png` files again.
- No cookies, no analytics, no third-party requests. `_headers` sets a strict Content-Security-Policy (`script-src
  'none'`) so that stays true.

### 2. Content follows the product rules
- The copy follows ADR-0006: XP for the dad's actions, nothing lost, worlds by age, the Resilience branch. Example
  quests, bosses, firsts and worlds use their titles from the content JSON.
- The privacy policy states what ADR-0004 and ADR-0016 decided: everything on device, no account or server, the camera
  only on request, `PhotosPicker` without library access, local notifications. It must be updated **before** a release
  that changes how data is handled (for example iCloud sync in Phase 5).
- The guides are general information, not medical advice, as in the app.

### 3. Hosting: Cloudflare Pages, Git integration
- The Pages project builds from this GitHub repository with no build command and `web` as the output directory. Build
  watch paths are limited to `web/**`, so Swift-only changes don't deploy.
- `develop` is the production branch, not `main`. Under Gitflow (ADR-0009) `main` only moves at a release, but the
  Support and Privacy URLs must be live before the first App Store submission, and site copy fixes shouldn't wait for
  an app release. Every `feature/*` branch and PR gets its own preview URL. Revisit at the first release if the site
  ever needs to describe only what has shipped.
- CI (`ci.yml`) still runs on PRs that touch only `web/`; it is cheap enough at this size.
- Custom domains `dadsaga.app` and `www.dadsaga.app`. Email Routing's MX and TXT records stay as they are.

### 4. App Store link later
Until the app has an App Store ID, the page shows a "Coming soon to the App Store" button without Apple's logo. At
launch, in the same change that sets `DadSagaAppStoreID`: replace it with Apple's official "Download on the App Store"
badge (from Apple's marketing resources, used as Apple's guidelines say), link it to `apps.apple.com/app/id…`, and add
`<meta name="apple-itunes-app" content="app-id=…">` for Safari's Smart App Banner. At the same time set
`DadSagaPrivacyPolicyURL` to `https://dadsaga.app/privacy/`.

## Consequences
- Zero running cost; HTTPS and the CDN come with Pages.
- The site's privacy and support text sits next to the code it describes, so one PR can change both.
- Two languages are duplicated by hand across six pages. That is fine at this size; a generator becomes worth it only
  if the site grows.
- Site-only changes go through Gitflow like any other change.
