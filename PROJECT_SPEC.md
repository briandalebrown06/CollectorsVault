# # Movie Collectors
## Locked Product Specification

This is the locked product spec for the Movie Collectors app.

It reflects the current agreed-upon feature canon and should be treated as the source of truth for architecture, data modeling, screen planning, and phased implementation.

---

# 1. Product identity

Movie Collectors is a local-first physical media collection app for serious collectors.

It is built for users who care about:

- movies
- TV seasons and TV series
- box sets
- boutique label releases
- steelbooks
- slipcovers
- alternate artwork
- preorder pipelines
- delivery tracking
- upgrades and release comparisons
- collector-specific packaging and condition details

This app is **not** meant to be a generic streaming watchlist or a minimal movie diary.

---

# 2. Product vision

The app should feel like:

- a personal movie vault
- a beautiful collector's catalog
- a preorder and wishlist organizer
- a shelf browser
- a long-term collection brain

The tone of the product should be:

- premium
- visual
- polished
- collector-focused
- dark-mode beautiful
- flexible enough for edge cases

The app should not feel like:

- a spreadsheet
- a generic list manager
- a streaming clone
- a casual-only app

---

# 3. Core architecture principles

The app must be built with the following principles:

- SwiftUI
- modular architecture
- local-first data model
- scalable structure
- reusable views and components
- clean separation of models, state, persistence, and UI
- future-ready service layers for features that require online integrations

Important:
- Do not build the app as a giant one-file tangle
- Do not pretend network-dependent features are complete if they are only scaffolded
- Leave room for future import/export, cloud sync, release alerts, shipping updates, and recommendation systems

---

# 4. Browsing model

The app must support a **title-first, edition-second** structure.

This means:

- each movie has a main title-level hub
- each title can have multiple attached editions
- users should not need to hunt separate isolated entries for every edition
- title pages should clearly show owned, wishlisted, and related editions
- users should be able to compare editions from the title hub
- title pages should support edition selection from one central place

This structure is critical for collectors.

---

# 5. Core data model

The app must support both title-level and edition-level records.

## 5.1 Title-level fields

Each title should support:

- title
- sort title
- original title
- release year
- media type
- director
- cast
- genre
- synopsis
- franchise or series relationship
- poster art
- tags
- notes
- related editions

### Media type values
Suggested support:

- movie
- TV season
- TV series
- box set
- collection
- special release
- other

---

## 5.2 Edition-level fields

Each edition should support:

- edition name
- format
- label or distributor
- UPC
- region code
- catalog number or spine number
- disc count
- packaging type
- slipcover data
- steelbook data
- condition
- damage notes
- collection status
- watch/open status
- purchase and order details
- retailer
- tracking number
- shipping status
- purchase notes
- shelf location
- tags
- custom lists
- artwork assets
- upgrade flags
- comparison data
- custom configuration or disc swap data

### Format values
Suggested support:

- VHS
- DVD
- Blu-ray
- 4K UHD
- combo
- digital combo
- steelbook
- boutique release
- custom

---

# 6. Status systems

## 6.1 Collection status

The app must support:

- Owned
- Wishlist
- Preorder
- On Order
- Delivered
- Sold / Removed

## 6.2 Watch / open status

The app must support:

- Sealed
- Open, not watched
- Open and watched

## 6.3 Condition status

The app must support:

- Mint
- Very Good
- Good
- Fair
- Damaged

The app must also support damage notes.

---

# 7. Artwork system

Artwork is a first-class feature.

The app must support:

- poster art
- release cover art
- user-uploaded photo of the collector's own copy
- alternate poster art
- steelbook art
- slipcover photos
- back cover photo
- spine photo
- disc art photo

The user must be able to:

- upload their own images
- store multiple images per item in higher tiers
- choose the primary display image
- switch between poster-focused and release-focused display
- attach custom artwork to specific editions
- attach condition or ownership photos to their actual copy

The data model should prefer a flexible artwork asset structure rather than a single image field.

Suggested artwork asset tagging:

- poster
- front cover
- back cover
- spine
- disc
- slipcover
- steelbook
- custom
- shelf photo
- owner photo

---

# 8. Slipcover support

Slipcover tracking is important and should be treated as a real collector feature.

Support:

- slipcover present yes/no
- original slipcover yes/no
- replacement or custom slipcover
- slipcover condition
- slipcover notes
- slipcover photos
- filters for with slipcover / without slipcover

---

# 9. Disc swap and custom configuration support

The app must support collector cases where physical components are mixed.

Examples:

- one edition's disc inside another edition's case
- custom replacement disc
- premium shell with alternate disc contents
- mixed packaging configuration

Minimum viable support:

- custom configuration toggle
- case-from field
- disc-from field
- notes field
- visible badge indicating a custom or disc-swapped item

Future-ready support:
- separate component records for case, discs, inserts, and slipcovers

---

# 10. Upgrade intelligence

The app must support release-upgrade logic.

## 10.1 Direct upgrade flags

The app should support direct upgrade opportunities such as:

- DVD to Blu-ray
- Blu-ray to 4K
- 5.1 to Atmos
- HDR to Dolby Vision
- weak transfer to major restoration
- barebones release to loaded edition

Suggested fields:

- hasUpgradeAvailable
- upgradeType
- upgradeReason
- upgradeTargetEdition
- upgradePriority

## 10.2 Upgrade utility signals

The app should also support logic for:

- owned but inferior
- owned and already optimal
- upgrade loses features warning
- compare current edition to better edition

---

# 11. Best release logic

The app should be able to compare releases of the same title and eventually recommend:

- best overall release
- best budget release
- best extras release
- best packaging release
- best audio/video release

Future logic may consider:

- transfer quality
- audio quality
- HDR quality
- bonus features
- packaging quality
- slipcover presence
- restoration quality
- label reputation
- price/value
- user preference weighting

---

# 12. Home screen requirements

The home screen should support cards or sections for:

- collection stats
- recently added
- favorites
- wishlist highlights
- orders in transit
- recently delivered
- upgrade opportunities
- worth-it upgrade picks
- random pick
- release alerts
- completeness highlights

---

# 13. Collection screen requirements

The main collection screen must support:

- list view
- grid view
- search
- filtering
- sorting
- title-level browsing
- edition-level access

Filters should support:

- collection status
- watch/open status
- condition
- slipcover
- upgrade available
- worth-it upgrade
- disc-swapped items
- retailer
- shipping status
- shelf location
- duplicates
- format
- label
- year
- tags
- custom lists

---

# 14. Item detail page requirements

Each detail page should support:

- primary artwork
- artwork gallery where applicable
- title identity
- edition identity
- format / label / packaging
- collection status
- condition and damage notes
- retailer and order info
- slipcover status
- disc swap details
- upgrade availability
- upgrade worth-it guidance
- related editions
- best release recommendation
- comparison actions

---

# 15. Add / edit flows

The app must support clear add/edit flows for both title-level and edition-level data.

These flows should support:

- quick entry
- advanced collector fields
- artwork selection
- condition notes
- retailer info
- tags
- custom lists
- shelf location
- custom configuration fields
- status selection
- validation and save behavior that is simple and reliable

---

# 16. Stats requirements

The stats area should support:

- total items
- by format
- by label
- by retailer
- by shelf
- sealed vs open
- watched vs unwatched
- upgrade opportunities
- duplicates
- box set counts
- slipcover percentage
- preorder / delivery pipeline
- estimated spend / value

---

# 17. Import / export requirements

The app must support import/export planning from the beginning.

Minimum support:
- local backup export

Higher-tier support:
- CSV export
- CSV import
- JSON import/export
- field mapping
- duplicate merge review
- import preview
- import health report
- easier migration from other collector apps or spreadsheets

The architecture should leave room for these features cleanly.

---

# 18. Social and sharing direction

The app may support social and sharing features in higher tiers.

Planned capabilities:

- public profile link
- public/private collection controls
- collection comparison
- social reactions
- emoji reactions
- shareable custom lists
- friend activity syncing

These should be treated as optional advanced layers, not part of the core offline foundation.

---

# 19. Shipping and order automation direction

Advanced versions of the app may support:

- live package tracking
- automatic carrier lookup
- in-app delivery timeline
- push notifications for shipping updates

These require service layers or online integrations and should be scaffolded honestly if not fully implemented.

---

# 20. Cloud and sync direction

Advanced versions of the app may support:

- cloud sync
- online backups
- cross-device sync for artwork and images

The core architecture should not block future cloud support.

---

# 21. Release intelligence and alert direction

Advanced versions may support:

- release alerts
- coming soon live feed
- retailer drop / preorder alerts
- label follow alerts
- friend activity sync
- price watch / deal alerts

These should be planned as future network-dependent features.

---

# 22. Review-informed recommendation layer

Future advanced versions may support:

- "Is the 4K worth it?" guidance
- review-informed upgrade scoring
- source-backed release summaries
- release recommendation systems tied to AV quality, extras, packaging, and value

This should be treated as a future intelligence layer, with clean abstraction boundaries.

---

# 23. Tier implementation priorities

Implementation should follow this order:

1. Free tier fully functional
2. Pro tier architecture and local-first advanced collector tools
3. Vault+ online and sync features
4. Review-informed recommendation layer
5. UI polish, performance tuning, and long-term refinements

---

# 24. Non-negotiable rules for implementation

- Build in phases
- Keep code modular
- Keep naming consistent
- Avoid giant files unless explicitly requested
- Do not fake finished integrations
- Document assumptions clearly
- Make the app feel premium and collector-focused
- Preserve the distinction between title-level and edition-level data
- Support serious collector edge cases from the model layer upward

---

# 25. Codex working instructions

When Codex reads this project, it should:

1. read this file before making changes
2. build the foundation in small, clear steps
3. fully implement Free tier first
4. scaffold higher-tier features cleanly
5. create roadmap notes for what is implemented versus stubbed
6. keep the UI polished and dark-mode friendly
7. preserve scalability for future features