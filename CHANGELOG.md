# Changelog

All notable changes to Samla are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Website categories in *What to block*, each blocked whole or site by site, including **AI Tools**.
- *No Internet Mode*: block everything except allowed apps.
- Starter lists (Sleep, Focus, Social Media) for a first list in one tap.
- *Skip Today* for unprotected scheduled lists, with *Resume Now*.
- Confirmation before starting a Hard Mode or Partner list.
- Duration presets with a *Custom* option.
- VoiceOver announcements for saves, errors and list changes.

### Changed
- Home focuses on what's happening now; *Later Today* moved to Lists.
- Protection and breaks fold under *Extra Options* in the list editor.
- Text colors and section captions meet WCAG 2.1 AA contrast; layouts adapt to the largest text sizes.

### Fixed
- Arabic translations for every string, enforced by a unit test.
- The schedule editor no longer drops days picked without tapping *Add Slot*.
- A started list shows as active immediately instead of after 30 seconds.
- Swiping a sheet down no longer discards unsaved edits.
