# # Movie Collectors

A local-first physical media collection app for serious movie collectors.

Movie Collectors is designed for people who care about more than just whether they "own the movie." It is built to track titles, editions, box sets, slipcovers, steelbooks, alternate artwork, disc swaps, preorder pipelines, upgrade opportunities, and collector-specific details that most apps ignore.

## Core vision

This app should feel like:

- a beautiful personal movie library
- a collector's catalog
- a wishlist and preorder tracker
- a visual shelf browser
- a long-term collector vault

It should **not** feel like a generic spreadsheet or a streaming watchlist clone.

## Product goals

- Local-first data storage
- Clean, scalable SwiftUI architecture
- Title-first, edition-second browsing model
- Strong support for collector edge cases
- Attractive dark-mode-friendly visual design
- Easy expansion into advanced and online features later

## Intended audience

This app is for collectors of:

- movies
- TV seasons and series
- box sets
- steelbooks
- boutique label releases
- alternate editions
- physical media with packaging and condition nuance

## Platform

- iPhone first
- iPad-friendly later
- SwiftUI app
- Local-first architecture
- Future support for cloud sync, release alerts, package tracking, and recommendation systems

## Tier structure

The app is organized into three product tiers:

- **Free Tier**
  - Core manual collection management
  - Tags, lists, statuses, notes, and local backup
- **Collector Pro**
  - One-time purchase
  - Advanced collector tools like barcode scanning, duplicate detection, upgrade warnings, box set structure, shelf mapping, and richer artwork support
- **Vault+**
  - Subscription
  - Cloud sync, online backups, shipping automation, alerts, and review-informed recommendation features

See `FEATURE_TIERS.md` for the full breakdown.

## Documentation files

- `README.md`
  - Project overview and identity
- `PROJECT_SPEC.md`
  - Full locked product spec and architecture direction
- `FEATURE_TIERS.md`
  - Tier-by-tier feature breakdown

## Non-negotiable build rules

- Use SwiftUI
- Keep the architecture modular and scalable
- Do not build this as a giant tangled one-file app
- Model both title-level and edition-level data
- Support multiple editions per title
- Leave room for box sets, slipcovers, disc swaps, alternate artwork, and upgrade intelligence
- Prioritize local-first behavior
- Do not fake completed online integrations
- If a future feature needs an API or service, build a clean placeholder or abstraction layer instead

## Codex guidance

When working on this repository:

1. Read `PROJECT_SPEC.md` and `FEATURE_TIERS.md` before making changes.
2. Build in phases rather than trying to implement everything in one pass.
3. Implement Free tier features fully first.
4. Scaffold Pro and Vault+ features cleanly without pretending unfinished integrations are complete.
5. Keep the UI premium, collector-friendly, and visually satisfying.

## Current status

Initial planning and product specification phase.