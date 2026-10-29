# CVE-2026-112621 Lab (iOS + GitHub Actions)

This repository is a small **manual, opt-in LinkPresentation test harness** for research on CVE-2026-112621. It builds an unsigned iOS app and generates the HEIC fixture from the supplied upstream PoC source. It does **not** automatically deploy the test page anywhere.

## What it does

- The app asks `LPMetadataProvider` to fetch link metadata for an HTTPS URL that you enter.
- If metadata is returned, it renders it with `LPLinkView` and records the result in an in-app log.
- The log is also appended to `Documents/cve-2026-112621-lab.log` so entries already written remain after an app crash.
- GitHub Actions builds an unsigned IPA and a separate ZIP containing `trigger.heic` plus the HTML template.

A successful metadata request does not prove the vulnerability is present. An app crash alone does not prove controllable memory corruption or code execution. This harness cannot identify the faulting process if the system kills another process; inspect the iOS Analytics Data/crash report separately.

## Build with GitHub Actions

1. Create a new private GitHub repository and upload these files to its `main` branch.
2. Open **Actions** and run **Build CVE-2026-112621 Lab** (or push a commit).
3. Download both workflow artifacts:
   - `CVE-2026-112621-Lab-IPA`
   - `CVE-2026-112621-HEIC-Fixture`
4. The IPA is intentionally unsigned. Install/sign it with your normal test-device sideloading workflow.

## Prepare a test page you control

The fixture ZIP contains `trigger.heic` and `index.html`. Before serving them, replace `{{PUBLIC_BASE_URL}}` in `index.html` with the HTTPS origin that will serve `trigger.heic` (for example, `https://your-own-test-host.example`). Serve `trigger.heic` with the content type `image/heic`. The URL entered into the app must be the page URL (the HTML page with the `og:image` metadata), not the HEIC file URL.

Do not publish the fixture to a public site or send the test link to other people. Use a private test host and a device you own or are explicitly authorized to test. Keep the device offline from sensitive accounts during testing; the expected outcome is unknown and may include an app or system-service crash. Do not repeat the test if the device begins rebooting or becomes unstable.

## Interpretation

- `SUCCESS metadata fetch` means LinkPresentation returned metadata; it is **not** a vulnerability verdict.
- `ERROR metadata fetch` means the metadata request failed for some reason; it does not show the CVE is absent.
- If the app exits unexpectedly, reopen it and export the saved log. Then check **Settings → Privacy & Security → Analytics & Improvements → Analytics Data** for a matching crash report. Match timestamps and process names before drawing conclusions.
- This project is a reproduction harness only. It contains no exploit chain, code-execution payload, sandbox escape, or kernel access logic.

## Source/license note

`PoCFixture/gen_heic.m`, `PoCFixture/index.html`, and the accompanying license were included from the supplied Xplo8E PoC archive. The generator includes a small portability adjustment for explicit UTF-8 path conversion. Preserve the included GPL-3.0-only license when redistributing those fixture sources.
