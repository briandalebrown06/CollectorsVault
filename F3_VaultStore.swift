// CollectorVault — VaultStore.swift
// Central store coordinator.
// NOTE: Removed @MainActor class annotation for Swift Playgrounds compatibility.
// All UI-touching work is dispatched to MainActor explicitly where needed.

import SwiftUI
import Combine

// =====================================================
// MARK: - Loading State
// =====================================================

enum VaultLoadingState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

// =====================================================
// MARK: - VaultStore
// =====================================================

final class VaultStore: ObservableObject {

    // MARK: Loading State
    @Published private(set) var loadingState: VaultLoadingState = .idle

    // MARK: Domain Data
    @Published var editions:               [MovieEdition]         = []
    @Published var orders:                 [OrderItem]            = []
    @Published var watchEvents:            [WatchEvent]           = []
    @Published var transactions:           [Transaction]          = []
    @Published var storageLocations:       [StorageLocation]      = []
    @Published var loanRecords:            [LoanRecord]           = []
    @Published var labels:                 [LabelInfo]            = []
    @Published var barcodeHistory:         [BarcodeHistoryEntry]  = []
    @Published var dashboardConfig:        DashboardConfig        = .defaultConfig
    @Published var savedAnalyticsReports:  [SavedAnalyticsReport] = []
    @Published var smartCollectionPresets: [SmartCollectionPreset] = []
    @Published var savedAdvancedFilters:   [SavedAdvancedFilter]  = []
    @Published var entitlements:           FeatureEntitlements    = FeatureEntitlements()

    // MARK: Cached Summary
    @Published private(set) var summary: CollectionSummary = CollectionSummary()

    // MARK: Toast
    @Published var activeToast: AppToast?

    // MARK: Settings (small values — appropriate UserDefaults use)
    var remindersEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cv.remindersEnabled") }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: "cv.remindersEnabled")
        }
    }

    var cloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cv.cloudSyncEnabled") }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: "cv.cloudSyncEnabled")
        }
    }

    // MARK: Fast lookup indexes
    private(set) var editionsByFilmKey: [String: [MovieEdition]] = [:]
    private(set) var editionByID:       [UUID: MovieEdition]     = [:]

    // MARK: Services
    private let persistence = PersistenceService.shared

    // MARK: Init
    // Deliberately lightweight. Boot() does the real work.
    init() {}

    // =====================================================
    // MARK: - Boot
    // =====================================================
    // Safe async boot. Never blocks the main thread.
    // Called from .task {} in ContentView.

    func boot() async {
        guard loadingState == .idle else { return }

        await MainActor.run { loadingState = .loading }

        // Migrate legacy UserDefaults data if needed
        await persistence.migrateFromUserDefaultsIfNeeded()

        // Try loading from disk
        let didLoad = await loadAllFromDisk()

        await MainActor.run {
            if didLoad {
                self.reindexEditions()
                self.recomputeSummarySync()
                self.loadingState = .ready
            } else {
                self.applySampleData()
                self.loadingState = .ready
                // Save sample data to disk in background
                Task { await self.saveAll() }
            }
        }
    }

    // =====================================================
    // MARK: - Disk Load
    // =====================================================

    private func loadAllFromDisk() async -> Bool {
        // Load all files concurrently
        async let e   = persistence.load([MovieEdition].self,          from: "editions.json")
        async let o   = persistence.load([OrderItem].self,             from: "orders.json")
        async let we  = persistence.load([WatchEvent].self,            from: "watchEvents.json")
        async let tx  = persistence.load([Transaction].self,           from: "transactions.json")
        async let sl  = persistence.load([StorageLocation].self,       from: "storageLocations.json")
        async let lr  = persistence.load([LoanRecord].self,            from: "loanRecords.json")
        async let lb  = persistence.load([LabelInfo].self,             from: "labels.json")
        async let bh  = persistence.load([BarcodeHistoryEntry].self,   from: "barcodeHistory.json")
        async let dc  = persistence.load(DashboardConfig.self,         from: "dashboardConfig.json")
        async let sr  = persistence.load([SavedAnalyticsReport].self,  from: "savedReports.json")
        async let sc  = persistence.load([SmartCollectionPreset].self, from: "smartCollections.json")
        async let en  = persistence.load(FeatureEntitlements.self,     from: "entitlements.json")

        let (eds, ords, evts, txs, locs, loans, lbls, barcodes, dash, reports, smarts, ents) =
            await (e, o, we, tx, sl, lr, lb, bh, dc, sr, sc, en)

        // Editions must exist — everything else can be empty/default
        guard let eds else { return false }

        editions              = eds
        orders                = ords    ?? []
        watchEvents           = evts    ?? []
        transactions          = txs     ?? []
        storageLocations      = locs    ?? []
        loanRecords           = loans   ?? []
        labels                = lbls    ?? []
        barcodeHistory        = barcodes ?? []
        dashboardConfig       = dash    ?? .defaultConfig
        savedAnalyticsReports = reports ?? SampleDataFactory.savedAnalyticsReports()
        smartCollectionPresets = smarts ?? SampleDataFactory.smartCollections()
        entitlements          = ents    ?? FeatureEntitlements()

        refreshWatchStats()
        return true
    }

    // =====================================================
    // MARK: - Index Management
    // =====================================================

    func reindexEditions() {
        editionsByFilmKey = Dictionary(grouping: editions) { $0.filmKey }
        editionByID = Dictionary(uniqueKeysWithValues: editions.map { ($0.id, $0) })
    }

    // =====================================================
    // MARK: - Summary Cache
    // =====================================================
    // Synchronous version for use inside MainActor.run blocks.
    // Background version for use after mutations.

    func recomputeSummarySync() {
        var s = CollectionSummary()
        s.totalOwned     = editions.filter { $0.collectionStatus == .owned }.count
        s.totalWishlist  = editions.filter { $0.collectionStatus == .wishlist }.count
        s.totalFilms     = Set(editions.map(\.filmKey)).count
        s.totalEditions  = editions.count
        s.total4Ks       = editions.filter { $0.format == .uhd4K && $0.collectionStatus == .owned }.count
        s.totalBlindBuys = editions.filter { $0.isBlindBuy }.count
        s.totalUnwatched = editions.filter { $0.watchStatus == .unwatched && $0.collectionStatus == .owned }.count
        s.totalSealed    = editions.filter { $0.openWatchStatus == .sealed }.count
        s.totalLoanedOut = editions.filter { $0.isLoanedOut }.count
        s.buyNowCount    = editions.filter { $0.collectionStatus == .wishlist && $0.buyRecommendation == .buyNow }.count
        s.collectionValue = editions.reduce(0) { $0 + $1.effectiveValue }

        s.totalSpend = transactions
            .filter { $0.type == .purchase || $0.type == .tradeIn }
            .reduce(0) { $0 + $1.amount }
        s.totalSales = transactions
            .filter { $0.type == .sale || $0.type == .refund || $0.type == .tradeOut }
            .reduce(0) { $0 + $1.amount }

        let now = Date(); let cal = Calendar.current
        if let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
           let nextMonth  = cal.date(byAdding: .month, value: 1, to: monthStart) {
            s.preorderPressure = orders.filter {
                let d = $0.estimatedChargeDate ?? $0.releaseDate
                guard let d else { return false }
                return d >= monthStart && d < nextMonth
                    && $0.orderStatus != .cancelled
                    && $0.orderStatus != .delivered
            }.reduce(0) { $0 + $1.price }
        }

        let blindKeys    = Set(editions.filter(\.isBlindBuy).map(\.filmKey))
        let blindRatings = watchEvents
            .filter { blindKeys.contains($0.filmKey) }
            .compactMap(\.ratingOutOfFive)
        if !blindRatings.isEmpty {
            let hits = blindRatings.filter { $0 >= 3.5 }.count
            s.blindBuyHitRate = Double(hits) / Double(blindRatings.count) * 100
        }

        let allRatings = watchEvents.compactMap(\.ratingOutOfFive)
        s.averageRating = allRatings.isEmpty ? 0 :
            allRatings.reduce(0, +) / Double(allRatings.count)

        summary = s
    }

    // Background version — safe to call after any mutation
    func recomputeSummary() {
        let edSnap  = editions
        let weSnap  = watchEvents
        let ordSnap = orders
        let txSnap  = transactions

        Task.detached(priority: .userInitiated) { [weak self] in
            var s = CollectionSummary()
            s.totalOwned     = edSnap.filter { $0.collectionStatus == .owned }.count
            s.totalWishlist  = edSnap.filter { $0.collectionStatus == .wishlist }.count
            s.totalFilms     = Set(edSnap.map(\.filmKey)).count
            s.totalEditions  = edSnap.count
            s.total4Ks       = edSnap.filter { $0.format == .uhd4K && $0.collectionStatus == .owned }.count
            s.totalBlindBuys = edSnap.filter { $0.isBlindBuy }.count
            s.totalUnwatched = edSnap.filter { $0.watchStatus == .unwatched && $0.collectionStatus == .owned }.count
            s.totalSealed    = edSnap.filter { $0.openWatchStatus == .sealed }.count
            s.totalLoanedOut = edSnap.filter { $0.isLoanedOut }.count
            s.buyNowCount    = edSnap.filter { $0.collectionStatus == .wishlist && $0.buyRecommendation == .buyNow }.count
            s.collectionValue = edSnap.reduce(0) { $0 + $1.effectiveValue }

            s.totalSpend = txSnap.filter { $0.type == .purchase || $0.type == .tradeIn }.reduce(0) { $0 + $1.amount }
            s.totalSales = txSnap.filter { $0.type == .sale || $0.type == .refund || $0.type == .tradeOut }.reduce(0) { $0 + $1.amount }

            let now = Date(); let cal = Calendar.current
            if let ms = cal.date(from: cal.dateComponents([.year, .month], from: now)),
               let nm = cal.date(byAdding: .month, value: 1, to: ms) {
                s.preorderPressure = ordSnap.filter {
                    let d = $0.estimatedChargeDate ?? $0.releaseDate
                    guard let d else { return false }
                    return d >= ms && d < nm && $0.orderStatus != .cancelled && $0.orderStatus != .delivered
                }.reduce(0) { $0 + $1.price }
            }

            let bKeys = Set(edSnap.filter(\.isBlindBuy).map(\.filmKey))
            let bRat  = weSnap.filter { bKeys.contains($0.filmKey) }.compactMap(\.ratingOutOfFive)
            if !bRat.isEmpty { s.blindBuyHitRate = Double(bRat.filter { $0 >= 3.5 }.count) / Double(bRat.count) * 100 }

            let allR = weSnap.compactMap(\.ratingOutOfFive)
            s.averageRating = allR.isEmpty ? 0 : allR.reduce(0, +) / Double(allR.count)

            await MainActor.run { [weak self] in self?.summary = s }
        }
    }

    // =====================================================
    // MARK: - Film Groups
    // =====================================================

    var filmGroups: [FilmGroup] {
        editionsByFilmKey.values.map { group in
            let rep = group[0]
            return FilmGroup(
                id: rep.filmKey, title: rep.title,
                originalTitle: rep.originalTitle, year: rep.year,
                editions: group.sorted { $0.editionTitle < $1.editionTitle }
            )
        }
        .sorted { $0.year != $1.year ? $0.year > $1.year : $0.title < $1.title }
    }

    // =====================================================
    // MARK: - Edition Mutations
    // =====================================================

    func add(_ edition: MovieEdition) {
        var copy = edition
        copy.dateCreated  = Date()
        copy.dateModified = Date()
        editions.insert(copy, at: 0)
        reindexEditions()
        recomputeSummary()
        scheduleEditionSave()
        showToast(.success, "Edition added")
    }

    func update(_ edition: MovieEdition) {
        guard let idx = editions.firstIndex(where: { $0.id == edition.id }) else { return }
        var copy = edition
        copy.dateCreated  = editions[idx].dateCreated
        copy.dateModified = Date()
        editions[idx] = copy
        reindexEditions()
        recomputeSummary()
        scheduleEditionSave()
        showToast(.success, "Edition updated")
    }

    func delete(_ edition: MovieEdition) {
        editions.removeAll { $0.id == edition.id }
        loanRecords.removeAll { $0.editionID == edition.id }
        if let imageID = edition.coverImageID { ImageStore.shared.delete(id: imageID) }
        reindexEditions()
        recomputeSummary()
        scheduleEditionSave()
        showToast(.warning, "Edition deleted")
    }

    // =====================================================
    // MARK: - Order Mutations
    // =====================================================

    func addOrder(_ order: OrderItem) {
        orders.insert(order, at: 0)
        recomputeSummary()
        Task { await persistence.save(orders, to: "orders.json") }
        showToast(.success, "Order added")
    }

    func updateOrder(_ order: OrderItem) {
        guard let idx = orders.firstIndex(where: { $0.id == order.id }) else { return }
        orders[idx] = order
        recomputeSummary()
        Task { await persistence.save(orders, to: "orders.json") }
        showToast(.success, "Order updated")
    }

    func deleteOrder(_ order: OrderItem) {
        orders.removeAll { $0.id == order.id }
        recomputeSummary()
        Task { await persistence.save(orders, to: "orders.json") }
        showToast(.warning, "Order deleted")
    }

    // =====================================================
    // MARK: - Watch Events
    // =====================================================

    func addWatchEvent(_ event: WatchEvent) {
        watchEvents.insert(event, at: 0)
        refreshWatchStats()
        recomputeSummary()
        Task { await persistence.save(watchEvents, to: "watchEvents.json") }
        showToast(.success, "Watch logged")
    }

    func relatedWatchEvents(for edition: MovieEdition) -> [WatchEvent] {
        watchEvents.filter { $0.filmKey == edition.filmKey }.sorted { $0.watchedOn > $1.watchedOn }
    }

    // =====================================================
    // MARK: - Transactions
    // =====================================================

    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
        recomputeSummary()
        Task { await persistence.save(transactions, to: "transactions.json") }
        showToast(.success, "Transaction added")
    }

    func relatedTransactions(for edition: MovieEdition) -> [Transaction] {
        transactions.filter { $0.filmKey == edition.filmKey }.sorted { $0.date > $1.date }
    }

    // =====================================================
    // MARK: - Loans
    // =====================================================

    var activeLoans: [LoanRecord] {
        loanRecords.filter { !$0.isReturned }.sorted { $0.dateLoaned > $1.dateLoaned }
    }

    var overdueLoans: [LoanRecord] {
        activeLoans.filter(\.isOverdue)
    }

    func addOrUpdateLoan(
        for edition: MovieEdition,
        friendName: String,
        loanedDate: Date,
        dueDate: Date?,
        notes: String
    ) {
        if let existing = activeLoan(for: edition.id),
           let idx = loanRecords.firstIndex(where: { $0.id == existing.id }) {
            loanRecords[idx].friendName = friendName
            loanRecords[idx].dateLoaned = loanedDate
            loanRecords[idx].dueDate    = dueDate
            loanRecords[idx].notes      = notes
        } else {
            loanRecords.insert(LoanRecord(
                editionID:   edition.id,
                friendName:  friendName,
                dateLoaned:  loanedDate,
                dueDate:     dueDate,
                returnedDate: nil,
                notes:       notes
            ), at: 0)
        }
        if let idx = editions.firstIndex(where: { $0.id == edition.id }) {
            editions[idx].isLoanedOut  = true
            editions[idx].loanedTo     = friendName
            editions[idx].loanedDate   = loanedDate
            editions[idx].dueDate      = dueDate
            editions[idx].loanNotes    = notes
            editions[idx].dateModified = Date()
        }
        reindexEditions()
        Task { await persistence.save(loanRecords, to: "loanRecords.json") }
        Task { await persistence.save(editions,    to: "editions.json") }
    }

    func markLoanReturned(_ loanID: UUID, returnedDate: Date = Date()) {
        guard let loanIdx = loanRecords.firstIndex(where: { $0.id == loanID }) else { return }
        loanRecords[loanIdx].returnedDate = returnedDate
        let editionID = loanRecords[loanIdx].editionID
        if let eIdx = editions.firstIndex(where: { $0.id == editionID }) {
            editions[eIdx].isLoanedOut   = false
            editions[eIdx].loanedTo      = ""
            editions[eIdx].loanedDate    = nil
            editions[eIdx].dueDate       = nil
            editions[eIdx].loanNotes     = ""
            editions[eIdx].dateModified  = Date()
        }
        reindexEditions()
        Task { await persistence.save(loanRecords, to: "loanRecords.json") }
        Task { await persistence.save(editions,    to: "editions.json") }
        showToast(.success, "Loan marked returned")
    }

    func activeLoan(for editionID: UUID) -> LoanRecord? {
        activeLoans.first { $0.editionID == editionID }
    }

    func edition(for loan: LoanRecord) -> MovieEdition? {
        editionByID[loan.editionID]
    }

    func relatedLoanRecords(for edition: MovieEdition) -> [LoanRecord] {
        loanRecords.filter { $0.editionID == edition.id }.sorted { $0.dateLoaned > $1.dateLoaned }
    }

    // =====================================================
    // MARK: - Locations
    // =====================================================

    func editionsForLocation(_ locationID: UUID) -> [MovieEdition] {
        editions.filter { $0.storageLocationID == locationID }.sorted { $0.title < $1.title }
    }

    func moveEdition(_ editionID: UUID, to locationID: UUID?) {
        guard let idx = editions.firstIndex(where: { $0.id == editionID }) else { return }
        editions[idx].storageLocationID = locationID
        editions[idx].dateModified = Date()
        reindexEditions()
        scheduleEditionSave()
    }

    func locationName(for edition: MovieEdition) -> String {
        guard let id  = edition.storageLocationID,
              let loc = storageLocations.first(where: { $0.id == id }) else { return "Unassigned" }
        return loc.name
    }

    func addLocation(_ location: StorageLocation) {
        storageLocations.insert(location, at: 0)
        Task { await persistence.save(storageLocations, to: "storageLocations.json") }
        showToast(.success, "Location added")
    }

    func updateLocation(_ location: StorageLocation) {
        guard let idx = storageLocations.firstIndex(where: { $0.id == location.id }) else { return }
        storageLocations[idx] = location
        Task { await persistence.save(storageLocations, to: "storageLocations.json") }
        showToast(.success, "Location updated")
    }

    // =====================================================
    // MARK: - Smart Collections
    // =====================================================

    func smartCollectionItems(for kind: SmartCollectionKind) -> [MovieEdition] {
        switch kind {
        case .blindBuysUnwatched:
            return editions.filter { $0.isBlindBuy && $0.watchStatus == .unwatched }
        case .upgradesNeeded:
            return editions.filter(\.isUpgradeCandidate)
        case .loanedOut:
            return editions.filter(\.isLoanedOut)
        case .wishlistUnderTarget:
            return editions.filter(\.underTargetPrice)
        case .duplicateCandidates:
            let multiGroups = editionsByFilmKey.values.filter { $0.count > 1 }
            let ids = Set(multiGroups.flatMap { $0.map(\.id) })
            return editions.filter {
                ids.contains($0.id) ||
                $0.duplicateDisposition == .sell ||
                $0.duplicateDisposition == .trade
            }
        case .mostValuableUnwatched:
            return editions
                .filter { $0.collectionStatus == .owned && $0.watchStatus == .unwatched }
                .sorted { $0.effectiveValue > $1.effectiveValue }
        case .sealedLongTerm:
            return editions.filter(\.sealedLongTerm)
        case .premiumSpecs:
            return editions.filter(\.hasPremiumSpecs)
        case .buyNowCandidates:
            return editions.filter { $0.collectionStatus == .wishlist && $0.buyRecommendation == .buyNow }
        case .highRiskWishlist:
            return editions.filter {
                $0.collectionStatus == .wishlist &&
                ($0.oopRiskLevel == .high || $0.isLimitedPressing)
            }
        }
    }

    func recentPriceDropCandidates() -> [MovieEdition] {
        editions
            .filter { ($0.bestRetailerPriceDrop ?? 0) > 0 }
            .sorted { ($0.bestRetailerPriceDrop ?? 0) > ($1.bestRetailerPriceDrop ?? 0) }
    }

    // =====================================================
    // MARK: - Duplicate / Upgrade Helpers
    // =====================================================

    func titleYearDuplicates(title: String, year: Int, excluding id: UUID? = nil) -> [MovieEdition] {
        let key = normalizedFilmKey(title: title, year: year)
        return (editionsByFilmKey[key] ?? []).filter { id == nil || $0.id != id! }
    }

    func barcodeDuplicates(for barcode: String, excluding id: UUID? = nil) -> [MovieEdition] {
        let clean = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        return editions.filter { $0.barcode == clean && (id == nil || $0.id != id!) }
    }

    // =====================================================
    // MARK: - Bulk Edit
    // =====================================================

    func bulkSetWatchStatus(_ ids: Set<UUID>, to status: WatchStatus) {
        for idx in editions.indices where ids.contains(editions[idx].id) {
            editions[idx].watchStatus  = status
            editions[idx].dateModified = Date()
        }
        reindexEditions(); recomputeSummary(); scheduleEditionSave()
        showToast(.success, "Watch status updated")
    }

    func bulkAddTag(_ ids: Set<UUID>, tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        for idx in editions.indices where ids.contains(editions[idx].id) {
            if !editions[idx].customTags.contains(clean) {
                editions[idx].customTags.append(clean)
                editions[idx].dateModified = Date()
            }
        }
        scheduleEditionSave(); showToast(.success, "Tag added")
    }

    func bulkRemoveTag(_ ids: Set<UUID>, tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        for idx in editions.indices where ids.contains(editions[idx].id) {
            editions[idx].customTags.removeAll { $0.caseInsensitiveCompare(clean) == .orderedSame }
            editions[idx].tags.removeAll       { $0.caseInsensitiveCompare(clean) == .orderedSame }
            editions[idx].dateModified = Date()
        }
        scheduleEditionSave(); showToast(.success, "Tag removed")
    }

    func bulkMoveLocation(_ ids: Set<UUID>, locationID: UUID?) {
        for idx in editions.indices where ids.contains(editions[idx].id) {
            editions[idx].storageLocationID = locationID
            editions[idx].dateModified = Date()
        }
        reindexEditions(); scheduleEditionSave(); showToast(.success, "Location updated")
    }

    func bulkSetCondition(_ ids: Set<UUID>, condition: ConditionRating) {
        for idx in editions.indices where ids.contains(editions[idx].id) {
            editions[idx].condition    = condition
            editions[idx].dateModified = Date()
        }
        scheduleEditionSave(); showToast(.success, "Condition updated")
    }

    func bulkSetDuplicateDisposition(_ ids: Set<UUID>, disposition: DuplicateDisposition) {
        for idx in editions.indices where ids.contains(editions[idx].id) {
            editions[idx].duplicateDisposition = disposition
            editions[idx].dateModified = Date()
        }
        scheduleEditionSave(); showToast(.success, "Disposition updated")
    }

    func bulkSetWishlistPriority(_ ids: Set<UUID>, priority: WishlistPriority) {
        for idx in editions.indices where ids.contains(editions[idx].id) {
            editions[idx].wishlistPriority = priority
            editions[idx].dateModified = Date()
        }
        scheduleEditionSave(); showToast(.success, "Priority updated")
    }

    func bulkSetUrgency(_ ids: Set<UUID>, urgency: PurchaseUrgency) {
        for idx in editions.indices where ids.contains(editions[idx].id) {
            editions[idx].purchaseUrgency = urgency
            editions[idx].dateModified = Date()
        }
        scheduleEditionSave(); showToast(.success, "Urgency updated")
    }

    // =====================================================
    // MARK: - Market / Dashboard
    // =====================================================

    func updateMarketStats(for editionID: UUID, stats: MarketPriceStats?) {
        guard let idx = editions.firstIndex(where: { $0.id == editionID }) else { return }
        editions[idx].marketStats    = stats
        editions[idx].estimatedValue = stats?.medianSold ?? editions[idx].estimatedValue
        editions[idx].dateModified   = Date()
        reindexEditions(); recomputeSummary(); scheduleEditionSave()
    }

    func updateTileOrder(_ tiles: [DashboardTile]) {
        dashboardConfig.tiles = tiles.enumerated().map { idx, tile in
            var copy = tile; copy.sortOrder = idx; return copy
        }
        Task { await persistence.save(dashboardConfig, to: "dashboardConfig.json") }
        showToast(.success, "Dashboard saved")
    }

    // =====================================================
    // MARK: - Barcode History
    // =====================================================

    func logBarcodeLookup(barcode: String, title: String, source: String, success: Bool) {
        barcodeHistory.insert(BarcodeHistoryEntry(
            barcode: barcode, title: title,
            lookupSource: source, timestamp: Date(), success: success
        ), at: 0)
        if barcodeHistory.count > 250 { barcodeHistory = Array(barcodeHistory.prefix(250)) }
        Task { await persistence.save(barcodeHistory, to: "barcodeHistory.json") }
    }

    // =====================================================
    // MARK: - Import / Export
    // =====================================================

    func exportBackupData() -> Data {
        persistence.exportBackup(
            editions: editions, orders: orders, watchEvents: watchEvents,
            transactions: transactions, storageLocations: storageLocations,
            loanRecords: loanRecords, labels: labels, barcodeHistory: barcodeHistory,
            dashboardConfig: dashboardConfig, savedReports: savedAnalyticsReports,
            smartCollections: smartCollectionPresets, entitlements: entitlements
        )
    }

    func importBackupData(_ data: Data) -> Bool {
        guard let backup = persistence.importBackup(from: data) else { return false }
        editions              = backup.editions
        orders                = backup.orders
        watchEvents           = backup.watchEvents
        transactions          = backup.transactions
        storageLocations      = backup.storageLocations
        loanRecords           = backup.loanRecords
        labels                = backup.labels
        barcodeHistory        = backup.barcodeHistory
        dashboardConfig       = backup.dashboardConfig
        savedAnalyticsReports = backup.savedAnalyticsReports
        smartCollectionPresets = backup.smartCollectionPresets
        entitlements          = backup.entitlements
        refreshWatchStats()
        reindexEditions()
        recomputeSummary()
        Task { await saveAll() }
        showToast(.success, "Backup imported")
        return true
    }

    func applyImportedEditions(_ imported: [MovieEdition], mode: ImportDuplicateMode) -> Int {
        var applied = 0
        for item in imported {
            let bdups = !item.barcode.isEmpty ? barcodeDuplicates(for: item.barcode) : []
            let tdups = titleYearDuplicates(title: item.title, year: item.year)
            switch mode {
            case .skip:
                if !bdups.isEmpty || !tdups.isEmpty { continue }
                editions.append(item); applied += 1
            case .addAnyway:
                editions.append(item); applied += 1
            case .replaceMatches:
                if let match = bdups.first ?? tdups.first,
                   let idx = editions.firstIndex(where: { $0.id == match.id }) {
                    var copy = item
                    copy.id           = match.id
                    copy.dateCreated  = match.dateCreated
                    copy.dateModified = Date()
                    editions[idx] = copy
                } else {
                    editions.append(item)
                }
                applied += 1
            }
        }
        reindexEditions(); recomputeSummary(); scheduleEditionSave()
        return applied
    }

    func convertOrderToOwnedEdition(_ orderID: UUID) {
        guard let oidx = orders.firstIndex(where: { $0.id == orderID }) else { return }
        let order = orders[oidx]
        let year  = Calendar.current.component(.year, from: order.releaseDate ?? Date())
        let edition = MovieEdition(
            title: order.title, originalTitle: order.title, year: year,
            editionTitle: order.editionTitle,
            format: .bluRay, editionType: .standard,
            collectionStatus: .owned, openWatchStatus: .sealed,
            watchStatus: .unwatched, condition: .mint,
            label: "", labelID: nil, studio: "", regionCode: "", barcode: "",
            isBlindBuy: false, isFavorite: false, hasDamage: false, damageNotes: "",
            coverSystemImage: order.coverSystemImage, accentHex: order.accentHex,
            coverImageID: nil, remotePosterPath: nil,
            hasIMAXScenes: false, hasDolbyVision: false, hasHDR10: false,
            hasHDR10Plus: false, hasDolbyAtmos: false, hasDolbyAudio: false, hasDTSX: false,
            videoNotes: "", audioNotes: "",
            lowestKnownPrice: order.price, purchasePrice: order.price, estimatedValue: order.price,
            marketStats: nil,
            pricePaidHistory: [PricePoint(
                retailer: order.retailer, amount: order.price, date: order.orderDate, note: "From order"
            )],
            retailerLinks: [], wishlistPriceHistory: [],
            isUpgradeCandidate: false, duplicateDisposition: .keep,
            wishlistTargetPrice: nil, expectedReleaseDate: nil,
            wishlistPriority: .medium, purchaseUrgency: .keepAnEyeOnIt,
            reasonWanted: "", isLimitedPressing: false, oopRiskLevel: .none,
            customTags: [], tags: ["from-order"],
            franchiseName: "", boxSetName: "", isBoxSet: false, parentBoxSetID: nil,
            isLoanedOut: false, loanedTo: "", loanedDate: nil, dueDate: nil, loanNotes: "",
            cutName: "", hasCommentary: false, commentaryDetails: "", specialFeatures: "",
            discs: [], storageLocationID: nil,
            acquiredDate: Date(), dateCreated: Date(), dateModified: Date(),
            collectorNotes: "Created from order.",
            timesWatched: 0, lastWatchedDate: nil
        )
        editions.insert(edition, at: 0)
        orders[oidx].linkedEditionID = edition.id
        orders[oidx].orderStatus     = .delivered
        reindexEditions(); recomputeSummary(); scheduleEditionSave()
        Task { await persistence.save(orders, to: "orders.json") }
        showToast(.success, "Order converted to owned edition")
    }

    // =====================================================
    // MARK: - Template Helper
    // =====================================================

    func templateForAnotherEdition(from edition: MovieEdition) -> MovieEdition {
        MovieEdition(
            title: edition.title, originalTitle: edition.originalTitle, year: edition.year,
            editionTitle: buildEditionTitle(format: .bluRay, editionType: .standard),
            format: .bluRay, editionType: .standard,
            collectionStatus: .owned, openWatchStatus: .sealed,
            watchStatus: .unwatched, condition: .mint,
            label: edition.label, labelID: edition.labelID, studio: edition.studio,
            regionCode: edition.regionCode, barcode: "",
            isBlindBuy: false, isFavorite: false, hasDamage: false, damageNotes: "",
            coverSystemImage: edition.coverSystemImage, accentHex: edition.accentHex,
            coverImageID: nil, remotePosterPath: edition.remotePosterPath,
            hasIMAXScenes: false, hasDolbyVision: false, hasHDR10: false,
            hasHDR10Plus: false, hasDolbyAtmos: false, hasDolbyAudio: false, hasDTSX: false,
            videoNotes: "", audioNotes: "",
            lowestKnownPrice: nil, purchasePrice: nil, estimatedValue: nil,
            marketStats: nil, pricePaidHistory: [],
            retailerLinks: edition.retailerLinks, wishlistPriceHistory: [],
            isUpgradeCandidate: false, duplicateDisposition: .keep,
            wishlistTargetPrice: nil, expectedReleaseDate: nil,
            wishlistPriority: .medium, purchaseUrgency: .keepAnEyeOnIt,
            reasonWanted: "", isLimitedPressing: false, oopRiskLevel: .none,
            customTags: edition.customTags, tags: edition.tags,
            franchiseName: edition.franchiseName, boxSetName: edition.boxSetName,
            isBoxSet: false, parentBoxSetID: edition.parentBoxSetID,
            isLoanedOut: false, loanedTo: "", loanedDate: nil, dueDate: nil, loanNotes: "",
            cutName: "", hasCommentary: false, commentaryDetails: "", specialFeatures: "",
            discs: [], storageLocationID: edition.storageLocationID,
            acquiredDate: Date(), dateCreated: Date(), dateModified: Date(),
            collectorNotes: "", timesWatched: 0, lastWatchedDate: nil
        )
    }

    // =====================================================
    // MARK: - Orders / Calendar
    // =====================================================

    var preorderThisMonthCount: Int {
        let now = Date(); let cal = Calendar.current
        guard
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now)),
            let end   = cal.date(byAdding: .month, value: 1, to: start)
        else { return 0 }
        return orders.filter {
            guard $0.orderStatus == .preorder, let r = $0.releaseDate else { return false }
            return r >= start && r < end
        }.count
    }

    func groupedReleaseMonths() -> [ReleaseMonthGroup] {
        let cal = Calendar.current
        let upcoming = orders
            .filter { $0.orderStatus != .cancelled }
            .filter { ($0.releaseDate ?? .distantPast) >= cal.startOfDay(for: Date()) }
            .sorted { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) }

        let grouped = Dictionary(grouping: upcoming) { order -> Date in
            let d = order.releaseDate ?? Date()
            return cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
        }
        return grouped.map { key, items in
            ReleaseMonthGroup(
                title: monthGroupTitle(for: key),
                monthDate: key,
                items: items.sorted { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) },
                total: items.reduce(0) { $0 + $1.price }
            )
        }.sorted { $0.monthDate < $1.monthDate }
    }

    // =====================================================
    // MARK: - Toast
    // =====================================================

    func showToast(_ style: ToastStyle, _ message: String) {
        activeToast = AppToast(style: style, message: message)
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                if self.activeToast?.message == message { self.activeToast = nil }
            }
        }
    }

    // =====================================================
    // MARK: - Persistence Helpers
    // =====================================================

    private var editionSaveTask: Task<Void, Never>?

    private func scheduleEditionSave() {
        editionSaveTask?.cancel()
        let snapshot = editions
        editionSaveTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await persistence.save(snapshot, to: "editions.json")
        }
    }

    func saveAll() async {
        await persistence.save(editions,               to: "editions.json")
        await persistence.save(orders,                 to: "orders.json")
        await persistence.save(watchEvents,            to: "watchEvents.json")
        await persistence.save(transactions,           to: "transactions.json")
        await persistence.save(storageLocations,       to: "storageLocations.json")
        await persistence.save(loanRecords,            to: "loanRecords.json")
        await persistence.save(labels,                 to: "labels.json")
        await persistence.save(barcodeHistory,         to: "barcodeHistory.json")
        await persistence.save(dashboardConfig,        to: "dashboardConfig.json")
        await persistence.save(savedAnalyticsReports,  to: "savedReports.json")
        await persistence.save(smartCollectionPresets, to: "smartCollections.json")
        await persistence.save(entitlements,           to: "entitlements.json")
    }

    // =====================================================
    // MARK: - Watch Stat Cache
    // =====================================================

    private func refreshWatchStats() {
        let byKey = Dictionary(grouping: watchEvents) { $0.filmKey }
        for idx in editions.indices {
            let related = (byKey[editions[idx].filmKey] ?? []).sorted { $0.watchedOn > $1.watchedOn }
            editions[idx].timesWatched    = related.count
            editions[idx].lastWatchedDate = related.first?.watchedOn
        }
    }

    // =====================================================
    // MARK: - Sample Data
    // =====================================================

    func resetAllSampleData() {
        applySampleData()
        Task { await saveAll() }
        showToast(.warning, "Sample data restored")
    }

    func applySampleData() {
        let locs  = SampleDataFactory.locations()
        let lbls  = SampleDataFactory.labels()
        var eds   = SampleDataFactory.editions(locations: locs, labels: lbls)
        let ords  = SampleDataFactory.orders()
        let evts  = SampleDataFactory.watchEvents(editions: eds)
        let txs   = SampleDataFactory.transactions(editions: eds)
        let loans = SampleDataFactory.loanRecords(editions: eds)

        // Backfill watch stats into sample editions
        let byKey = Dictionary(grouping: evts) { $0.filmKey }
        for i in eds.indices {
            let related = (byKey[eds[i].filmKey] ?? []).sorted { $0.watchedOn > $1.watchedOn }
            eds[i].timesWatched    = related.count
            eds[i].lastWatchedDate = related.first?.watchedOn
        }

        storageLocations       = locs
        labels                 = lbls
        editions               = eds
        orders                 = ords
        watchEvents            = evts
        transactions           = txs
        loanRecords            = loans
        barcodeHistory         = []
        dashboardConfig        = .defaultConfig
        savedAnalyticsReports  = SampleDataFactory.savedAnalyticsReports()
        smartCollectionPresets = SampleDataFactory.smartCollections()
        entitlements           = FeatureEntitlements()

        reindexEditions()
        recomputeSummarySync()
    }
}

// =====================================================
// MARK: - SampleDataFactory
// =====================================================

enum SampleDataFactory {

    static func locations() -> [StorageLocation] {
        [
            StorageLocation(name: "Living Room Shelf A", room: "Living Room", shelf: "A", bin: "", notes: ""),
            StorageLocation(name: "Bedroom Closet Bin 1", room: "Bedroom", shelf: "", bin: "Bin 1", notes: "")
        ]
    }

    static func labels() -> [LabelInfo] {
        [
            LabelInfo(fullName: "Synapse Films", shortCode: "SYN"),
            LabelInfo(fullName: "Criterion",     shortCode: "CC"),
            LabelInfo(fullName: "Umbrella Entertainment", shortCode: "UMB")
        ]
    }

    static func editions(locations: [StorageLocation], labels: [LabelInfo]) -> [MovieEdition] {
        let syn  = labels.first { $0.fullName == "Synapse Films" }?.id
        let cc   = labels.first { $0.fullName == "Criterion" }?.id
        let boxID = UUID()
        let past = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()

        return [
            MovieEdition(
                id: boxID,
                title: "Argento Collection", originalTitle: "Argento Collection", year: 1977,
                editionTitle: "Limited Box Set",
                format: .bluRay, editionType: .boxSet,
                collectionStatus: .owned, openWatchStatus: .openWatched, watchStatus: .watchedThisEdition,
                condition: .veryGood, label: "Synapse Films", labelID: syn, studio: "Synapse Films",
                regionCode: "Region Free", barcode: "111111111111",
                isBlindBuy: false, isFavorite: false, hasDamage: false, damageNotes: "",
                coverSystemImage: "shippingbox.fill", accentHex: "#7C3AED",
                coverImageID: nil, remotePosterPath: nil,
                hasIMAXScenes: false, hasDolbyVision: false, hasHDR10: false,
                hasHDR10Plus: false, hasDolbyAtmos: false, hasDolbyAudio: true, hasDTSX: false,
                videoNotes: "", audioNotes: "",
                lowestKnownPrice: 79.99, purchasePrice: 89.99, estimatedValue: 95.00,
                marketStats: nil, pricePaidHistory: [], retailerLinks: [], wishlistPriceHistory: [],
                isUpgradeCandidate: false, duplicateDisposition: .keep,
                wishlistTargetPrice: nil, expectedReleaseDate: nil,
                wishlistPriority: .medium, purchaseUrgency: .keepAnEyeOnIt,
                reasonWanted: "", isLimitedPressing: false, oopRiskLevel: .none,
                customTags: ["box-set"], tags: ["owned"],
                franchiseName: "Argento", boxSetName: "Argento Collection",
                isBoxSet: true, parentBoxSetID: nil,
                isLoanedOut: false, loanedTo: "", loanedDate: nil, dueDate: nil, loanNotes: "",
                cutName: "", hasCommentary: false, commentaryDetails: "", specialFeatures: "",
                discs: [], storageLocationID: locations.first?.id,
                acquiredDate: past, dateCreated: past, dateModified: past,
                collectorNotes: "", timesWatched: 0, lastWatchedDate: nil
            ),
            MovieEdition(
                title: "Suspiria", originalTitle: "Suspiria", year: 1977,
                editionTitle: "4K UHD Steelbook",
                format: .uhd4K, editionType: .steelbook,
                collectionStatus: .owned, openWatchStatus: .openWatched, watchStatus: .watchedThisEdition,
                condition: .veryGood, label: "Synapse Films", labelID: syn, studio: "Synapse Films",
                regionCode: "Region Free", barcode: "191329262527",
                isBlindBuy: false, isFavorite: true, hasDamage: false, damageNotes: "",
                coverSystemImage: "sparkles.tv", accentHex: "#8B1E2D",
                coverImageID: nil, remotePosterPath: nil,
                hasIMAXScenes: false, hasDolbyVision: true, hasHDR10: true,
                hasHDR10Plus: false, hasDolbyAtmos: true, hasDolbyAudio: false, hasDTSX: false,
                videoNotes: "Rich color grading.", audioNotes: "Atmos mix blooms.",
                lowestKnownPrice: 29.99, purchasePrice: 31.49, estimatedValue: 35.00,
                marketStats: MarketPriceStats(
                    lastUpdated: Date(), currency: "USD",
                    lowestSold: 28, highestSold: 52, medianSold: 35, averageSold: 36.20,
                    sampleSize: 8, source: "Manual"
                ),
                pricePaidHistory: [PricePoint(retailer: "Amazon", amount: 31.49, date: past, note: "Launch sale")],
                retailerLinks: [RetailerLink(
                    retailer: "Synapse Films", urlString: "https://synapsefilms.com",
                    note: "Label store", currentPrice: 34.99, previousPrice: 39.99,
                    lowestSeenPrice: 31.99, lastChecked: Date(), isPreferred: true
                )],
                wishlistPriceHistory: [],
                isUpgradeCandidate: false, duplicateDisposition: .keep,
                wishlistTargetPrice: nil, expectedReleaseDate: nil,
                wishlistPriority: .medium, purchaseUrgency: .keepAnEyeOnIt,
                reasonWanted: "", isLimitedPressing: false, oopRiskLevel: .none,
                customTags: ["giallo", "favorite"], tags: ["favorite", "owned"],
                franchiseName: "Argento", boxSetName: "Argento Collection",
                isBoxSet: false, parentBoxSetID: boxID,
                isLoanedOut: false, loanedTo: "", loanedDate: nil, dueDate: nil, loanNotes: "",
                cutName: "Theatrical", hasCommentary: true, commentaryDetails: "Commentary included.",
                specialFeatures: "Interviews, trailers, booklet.",
                discs: [DiscInfo(discLabel: "Disc 1", discType: "4K UHD", regionCode: "Region Free", runtimeMinutes: 99, notes: "Main feature")],
                storageLocationID: locations.first?.id,
                acquiredDate: past, dateCreated: past, dateModified: Date(),
                collectorNotes: "One of the jewels in the vault.",
                timesWatched: 0, lastWatchedDate: nil
            ),
            MovieEdition(
                title: "Cure", originalTitle: "Cure", year: 1997,
                editionTitle: "Blu-ray",
                format: .bluRay, editionType: .standard,
                collectionStatus: .wishlist, openWatchStatus: .sealed, watchStatus: .unwatched,
                condition: .mint, label: "Criterion", labelID: cc, studio: "Criterion",
                regionCode: "A", barcode: "715515298615",
                isBlindBuy: true, isFavorite: false, hasDamage: false, damageNotes: "",
                coverSystemImage: "moon.stars", accentHex: "#A9A9A9",
                coverImageID: nil, remotePosterPath: nil,
                hasIMAXScenes: false, hasDolbyVision: false, hasHDR10: false,
                hasHDR10Plus: false, hasDolbyAtmos: false, hasDolbyAudio: true, hasDTSX: false,
                videoNotes: "", audioNotes: "",
                lowestKnownPrice: 19.99, purchasePrice: nil, estimatedValue: 19.99,
                marketStats: MarketPriceStats(
                    lastUpdated: Date(), currency: "USD",
                    lowestSold: 17.50, highestSold: 28, medianSold: 21, averageSold: 21.80,
                    sampleSize: 12, source: "Manual"
                ),
                pricePaidHistory: [],
                retailerLinks: [
                    RetailerLink(retailer: "Criterion", urlString: "https://criterion.com",
                        note: "Wishlist link", currentPrice: 24.99, previousPrice: 29.99,
                        lowestSeenPrice: 19.99, lastChecked: Date(), isPreferred: true),
                    RetailerLink(retailer: "Amazon", urlString: "",
                        note: "Watch for dents", currentPrice: 22.49, previousPrice: 22.49,
                        lowestSeenPrice: 20.99, lastChecked: Date(), isPreferred: false)
                ],
                wishlistPriceHistory: [
                    PricePoint(retailer: "Criterion", amount: 29.99,
                        date: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date(),
                        note: "Standard price"),
                    PricePoint(retailer: "Criterion", amount: 24.99, date: Date(), note: "Current")
                ],
                isUpgradeCandidate: true, duplicateDisposition: .keep,
                wishlistTargetPrice: 21.00,
                expectedReleaseDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
                wishlistPriority: .grail, purchaseUrgency: .soon,
                reasonWanted: "One of the biggest holes in the shelf.",
                isLimitedPressing: false, oopRiskLevel: .medium,
                customTags: ["wishlist", "psychological"], tags: ["blind-buy", "wishlist"],
                franchiseName: "", boxSetName: "", isBoxSet: false, parentBoxSetID: nil,
                isLoanedOut: false, loanedTo: "", loanedDate: nil, dueDate: nil, loanNotes: "",
                cutName: "", hasCommentary: false, commentaryDetails: "",
                specialFeatures: "Essay and interview.",
                discs: [DiscInfo(discLabel: "Disc 1", discType: "Blu-ray", regionCode: "A", runtimeMinutes: 111, notes: "")],
                storageLocationID: locations.last?.id,
                acquiredDate: nil, dateCreated: Date(), dateModified: Date(),
                collectorNotes: "", timesWatched: 0, lastWatchedDate: nil
            )
        ]
    }

    static func orders() -> [OrderItem] {
        [
            OrderItem(
                title: "Possession", editionTitle: "Limited 4K UHD",
                retailer: "Umbrella Entertainment", orderStatus: .preorder,
                releaseDate: Calendar.current.date(byAdding: .day, value: 18, to: Date()),
                estimatedChargeDate: Calendar.current.date(byAdding: .day, value: 11, to: Date()),
                orderDate: Date(), trackingNumber: "", orderNumber: "",
                notes: "Hope the slip survives shipping.", price: 49.99,
                accentHex: "#8156D8", coverSystemImage: "shippingbox",
                linkedEditionID: nil, lineItems: []
            ),
            OrderItem(
                title: "Opera", editionTitle: "4K UHD",
                retailer: "Severin", orderStatus: .ordered,
                releaseDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
                estimatedChargeDate: Calendar.current.date(byAdding: .day, value: 24, to: Date()),
                orderDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                trackingNumber: "", orderNumber: "",
                notes: "Wallet hissed but allowed it.", price: 42.99,
                accentHex: "#A3193D", coverSystemImage: "film.stack",
                linkedEditionID: nil, lineItems: []
            )
        ]
    }

    static func watchEvents(editions: [MovieEdition]) -> [WatchEvent] {
        guard let s = editions.first(where: { $0.title == "Suspiria" && $0.format == .uhd4K }) else { return [] }
        return [WatchEvent(
            editionID: s.id, filmKey: s.filmKey,
            watchedOn: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            sourceType: .thisEdition, ratingOutOfFive: 4.5, notes: "Looked incredible.", rewatchNumber: 2
        )]
    }

    static func transactions(editions: [MovieEdition]) -> [Transaction] {
        guard let s = editions.first(where: { $0.title == "Suspiria" && $0.format == .uhd4K }) else { return [] }
        return [Transaction(
            editionID: s.id, filmKey: s.filmKey, type: .purchase, amount: 31.49,
            retailerOrBuyer: "Amazon",
            date: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(),
            notes: "Launch sale"
        )]
    }

    static func loanRecords(editions: [MovieEdition]) -> [LoanRecord] {
        guard let s = editions.first(where: { $0.title == "Suspiria" && $0.format == .uhd4K }) else { return [] }
        return [LoanRecord(
            editionID: s.id, friendName: "Eli",
            dateLoaned: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            returnedDate: nil, notes: "Bring it back without shelf rash."
        )]
    }

    static func savedAnalyticsReports() -> [SavedAnalyticsReport] {
        [
            SavedAnalyticsReport(name: "Backlog by Label",  metric: .backlogCount,    groupBy: .label, dateRange: .allTime, filters: .default, chartStyle: .bar, notes: ""),
            SavedAnalyticsReport(name: "Buy Now by Label",  metric: .buyNowCandidates, groupBy: .label, dateRange: .allTime, filters: .default, chartStyle: .bar, notes: "")
        ]
    }

    static func smartCollections() -> [SmartCollectionPreset] {
        SmartCollectionKind.allCases.prefix(6).map { SmartCollectionPreset(kind: $0) }
    }
}
