// CollectorVault — Analytics.swift
// AnalyticsStore: reads from VaultStore, computes metrics and report results.
// ReportEngine: runs a SavedAnalyticsReport against live data.
// No UI. No persistence. Pure computation.

import SwiftUI
import Charts

// =====================================================
// MARK: - AnalyticsStore
// =====================================================
// Reads from VaultStore. Does not own data.
// Designed to be instantiated inline in views:
//   let analytics = AnalyticsStore(store: store)

final class AnalyticsStore {
    private let store: VaultStore
    init(store: VaultStore) { self.store = store }

    // ---- Basic Metrics ----

    var totalItemsOwned:   Int    { store.summary.totalOwned }
    var wishlistCount:     Int    { store.summary.totalWishlist }
    var backlogCount:      Int    { store.summary.totalUnwatched }
    var buyNowCount:       Int    { store.summary.buyNowCount }
    var collectionValue:   Double { store.summary.collectionValue }
    var totalSpend:        Double { store.summary.totalSpend }
    var totalSales:        Double { store.summary.totalSales }
    var netProfit:         Double { totalSales - totalSpend }
    var blindBuyHitRate:   Double { store.summary.blindBuyHitRate }
    var averageRating:     Double { store.summary.averageRating }
    var preorderPressure:  Double { store.summary.preorderPressure }

    var onOrderCount: Int {
        store.orders.filter {
            $0.orderStatus == .preorder || $0.orderStatus == .ordered || $0.orderStatus == .shipped
        }.count
    }

    var watchCount: Int { store.watchEvents.count }

    var averageDaysPurchaseToFirstWatch: Double {
        var intervals: [Double] = []
        for edition in store.editions {
            guard let acquired = edition.acquiredDate else { continue }
            let related = store.watchEvents
                .filter { $0.filmKey == edition.filmKey }
                .sorted { $0.watchedOn < $1.watchedOn }
            guard let first = related.first else { continue }
            let days = first.watchedOn.timeIntervalSince(acquired) / 86_400
            if days >= 0 { intervals.append(days) }
        }
        guard !intervals.isEmpty else { return 0 }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    var wishlistBudgetPressure: Double {
        store.smartCollectionItems(for: .buyNowCandidates)
            .reduce(0) { $0 + ($1.bestCurrentPrice ?? $1.lowestKnownPrice ?? 0) }
    }

    var recentPriceDropsCount: Int { store.recentPriceDropCandidates().count }

    var collectorHealthScore: Int {
        let base = 100
        let backlog = min(backlogCount * 2, 30)
        let buyNow  = min(buyNowCount * 3, 20)
        let overdue = min(store.overdueLoans.count * 5, 15)
        return max(0, base - backlog - buyNow - overdue)
    }

    var walletDangerScore: Int {
        let bn    = buyNowCount * 8
        let drops = recentPriceDropsCount * 5
        let open  = onOrderCount * 4
        return min(100, bn + drops + open)
    }

    // ---- Formatted metric value for dashboard tiles ----

    func value(for metric: MetricKind) -> String {
        switch metric {
        case .totalItemsOwned:                return "\(totalItemsOwned)"
        case .wishlistCount:                  return "\(wishlistCount)"
        case .onOrderCount:                   return "\(onOrderCount)"
        case .backlogCount:                   return "\(backlogCount)"
        case .blindBuyHitRate:                return "\(String(format: "%.1f", blindBuyHitRate))%"
        case .watchCount:                     return "\(watchCount)"
        case .totalSpend:                     return currencyString(totalSpend)
        case .totalSales:                     return currencyString(totalSales)
        case .netProfit:                      return currencyString(netProfit)
        case .collectionValueEstimate:        return currencyString(collectionValue)
        case .averageRating:                  return averageRating == 0 ? "—" : String(format: "%.2f", averageRating)
        case .averageDaysPurchaseToFirstWatch: return averageDaysPurchaseToFirstWatch == 0 ? "—" : "\(String(format: "%.1f", averageDaysPurchaseToFirstWatch))d"
        case .buyNowCandidates:               return "\(buyNowCount)"
        case .wishlistTargetGap:
            let gap = store.editions.filter { $0.collectionStatus == .wishlist }.compactMap(\.targetGap)
            guard !gap.isEmpty else { return "—" }
            return currencyString(gap.reduce(0, +) / Double(gap.count))
        case .preorderThisMonth:              return "\(store.preorderThisMonthCount)"
        case .recentPriceDrops:               return "\(recentPriceDropsCount)"
        }
    }

    // ---- Insights ----

    func generateInsights() -> [AnalyticsInsight] {
        var list: [AnalyticsInsight] = []
        list.append(AnalyticsInsight(title: "Collector Health",
            detail: "Health score: \(collectorHealthScore)/100"))
        list.append(AnalyticsInsight(title: "Wallet Danger",
            detail: "Danger score: \(walletDangerScore)/100"))
        list.append(AnalyticsInsight(title: "Backlog",
            detail: "\(backlogCount) owned item(s) are still unwatched."))
        if blindBuyHitRate > 0 {
            list.append(AnalyticsInsight(title: "Blind Buy Hit Rate",
                detail: "Blind buys are landing at \(String(format: "%.1f", blindBuyHitRate))%."))
        }
        if buyNowCount > 0 {
            list.append(AnalyticsInsight(title: "Wishlist Pressure",
                detail: "\(buyNowCount) wishlist title(s) are in buy-now territory — about \(currencyString(wishlistBudgetPressure)) of immediate wallet exposure."))
        }
        if recentPriceDropsCount > 0 {
            list.append(AnalyticsInsight(title: "Price Drops",
                detail: "\(recentPriceDropsCount) wishlist title(s) show a price drop."))
        }
        if preorderPressure > 0 {
            list.append(AnalyticsInsight(title: "This Month",
                detail: "Projected preorder pressure this month: \(currencyString(preorderPressure))."))
        }
        return list
    }
}

// =====================================================
// MARK: - ReportEngine
// =====================================================

enum ReportEngine {
    static func run(_ report: SavedAnalyticsReport, store: VaultStore) -> ReportResult {
        let analytics = AnalyticsStore(store: store)
        let editions  = filteredEditions(store.editions, filters: report.filters)
        let events    = filteredWatchEvents(store.watchEvents, filters: report.filters, editions: editions)
        let txs       = filteredTransactions(store.transactions, editions: editions)

        let points: [ReportPoint]

        switch report.metric {
        case .backlogCount:
            points = editionCountPoints(groupBy: report.groupBy, editions: editions.filter {
                $0.collectionStatus == .owned && $0.watchStatus == .unwatched
            }, store: store)
        case .wishlistCount:
            points = editionCountPoints(groupBy: report.groupBy, editions: editions.filter {
                $0.collectionStatus == .wishlist
            }, store: store)
        case .totalItemsOwned:
            points = editionCountPoints(groupBy: report.groupBy, editions: editions.filter {
                $0.collectionStatus == .owned
            }, store: store)
        case .collectionValueEstimate:
            points = valuePoints(groupBy: report.groupBy, editions: editions, store: store)
        case .buyNowCandidates:
            points = editionCountPoints(groupBy: report.groupBy, editions: editions.filter {
                $0.collectionStatus == .wishlist && $0.buyRecommendation == .buyNow
            }, store: store)
        case .totalSpend:
            points = txPoints(groupBy: report.groupBy, transactions: txs.filter {
                ($0.type == .purchase || $0.type == .tradeIn) && report.dateRange.contains($0.date)
            }, editions: editions, store: store)
        case .totalSales:
            points = txPoints(groupBy: report.groupBy, transactions: txs.filter {
                ($0.type == .sale || $0.type == .refund || $0.type == .tradeOut) && report.dateRange.contains($0.date)
            }, editions: editions, store: store)
        case .watchCount:
            points = watchPoints(groupBy: report.groupBy, events: events.filter {
                report.dateRange.contains($0.watchedOn)
            }, editions: editions, store: store)
        case .averageRating:
            points = avgRatingPoints(groupBy: report.groupBy, events: events.filter {
                report.dateRange.contains($0.watchedOn) && $0.ratingOutOfFive != nil
            }, editions: editions, store: store)
        case .blindBuyHitRate:
            points = blindBuyPoints(groupBy: report.groupBy, events: events.filter {
                report.dateRange.contains($0.watchedOn)
            }, editions: editions, store: store)
        case .wishlistTargetGap:
            points = targetGapPoints(groupBy: report.groupBy, editions: editions.filter {
                $0.collectionStatus == .wishlist
            }, store: store)
        case .onOrderCount:
            points = [ReportPoint(label: "On Order", value: Double(analytics.onOrderCount))]
        case .averageDaysPurchaseToFirstWatch:
            points = [ReportPoint(label: "Avg Days", value: analytics.averageDaysPurchaseToFirstWatch)]
        case .preorderThisMonth:
            points = [ReportPoint(label: "This Month", value: Double(store.preorderThisMonthCount))]
        case .recentPriceDrops:
            points = [ReportPoint(label: "Price Drops", value: Double(analytics.recentPriceDropsCount))]
        case .netProfit:
            points = [ReportPoint(label: "Net Profit", value: analytics.netProfit)]
        }

        return ReportResult(
            title: report.name,
            subtitle: "\(report.metric.rawValue) by \(report.groupBy.rawValue)",
            points: points.sorted { $0.value > $1.value },
            total:  points.reduce(0) { $0 + $1.value }
        )
    }

    // MARK: - Filters

    private static func filteredEditions(_ editions: [MovieEdition], filters: ReportFilter) -> [MovieEdition] {
        editions.filter { e in
            if !filters.includeWishlist && e.collectionStatus == .wishlist { return false }
            if filters.onlyBlindBuys && !e.isBlindBuy { return false }
            if filters.onlyUnwatched && e.watchStatus != .unwatched { return false }
            if filters.onlyBuyNow && e.buyRecommendation != .buyNow { return false }
            if let fmt = filters.format, e.format != fmt { return false }
            if let lid = filters.labelID, e.labelID != lid { return false }
            if let max = filters.maxPurchasePrice, let paid = e.lastPaidPrice, paid > max { return false }
            return true
        }
    }

    private static func filteredWatchEvents(_ events: [WatchEvent], filters: ReportFilter, editions: [MovieEdition]) -> [WatchEvent] {
        let keys = Set(editions.map(\.filmKey))
        return events.filter { e in
            if !keys.contains(e.filmKey) { return false }
            if let min = filters.minRating, let r = e.ratingOutOfFive, r < min { return false }
            return true
        }
    }

    private static func filteredTransactions(_ txs: [Transaction], editions: [MovieEdition]) -> [Transaction] {
        let keys = Set(editions.map(\.filmKey))
        return txs.filter { keys.contains($0.filmKey) }
    }

    // MARK: - Point builders

    private static func groupingKey(for edition: MovieEdition?, groupBy: GroupByField, store: VaultStore) -> String {
        guard let e = edition else { return "Unknown" }
        switch groupBy {
        case .none:     return "Total"
        case .label:    return e.label.isEmpty ? "Unknown Label" : e.label
        case .format:   return e.format.rawValue
        case .year:     return String(e.year)
        case .decade:   return "\(e.year / 10 * 10)s"
        case .month:    return (e.acquiredDate ?? Date()).formatted(.dateTime.year().month(.abbreviated))
        case .location:
            if let id = e.storageLocationID, let loc = store.storageLocations.first(where: { $0.id == id }) {
                return loc.name
            }
            return "Unassigned"
        case .priority: return e.wishlistPriority.title
        case .urgency:  return e.purchaseUrgency.title
        case .oopRisk:  return e.oopRiskLevel.title
        }
    }

    private static func editionCountPoints(groupBy: GroupByField, editions: [MovieEdition], store: VaultStore) -> [ReportPoint] {
        if groupBy == .none { return [ReportPoint(label: "Total", value: Double(editions.count))] }
        let grouped = Dictionary(grouping: editions) { groupingKey(for: $0, groupBy: groupBy, store: store) }
        return grouped.map { ReportPoint(label: $0.key, value: Double($0.value.count)) }
    }

    private static func valuePoints(groupBy: GroupByField, editions: [MovieEdition], store: VaultStore) -> [ReportPoint] {
        if groupBy == .none { return [ReportPoint(label: "Total", value: editions.reduce(0) { $0 + $1.effectiveValue })] }
        let grouped = Dictionary(grouping: editions) { groupingKey(for: $0, groupBy: groupBy, store: store) }
        return grouped.map { ReportPoint(label: $0.key, value: $0.value.reduce(0) { $0 + $1.effectiveValue }) }
    }

    private static func targetGapPoints(groupBy: GroupByField, editions: [MovieEdition], store: VaultStore) -> [ReportPoint] {
        let with = editions.filter { $0.targetGap != nil }
        if groupBy == .none { return [ReportPoint(label: "Gap", value: with.reduce(0) { $0 + ($1.targetGap ?? 0) })] }
        let grouped = Dictionary(grouping: with) { groupingKey(for: $0, groupBy: groupBy, store: store) }
        return grouped.map { ReportPoint(label: $0.key, value: $0.value.reduce(0) { $0 + ($1.targetGap ?? 0) }) }
    }

    private static func txPoints(groupBy: GroupByField, transactions: [Transaction], editions: [MovieEdition], store: VaultStore) -> [ReportPoint] {
        if groupBy == .none { return [ReportPoint(label: "Total", value: transactions.reduce(0) { $0 + $1.amount })] }
        let edMap = Dictionary(uniqueKeysWithValues: editions.map { ($0.filmKey, $0) })
        let grouped = Dictionary(grouping: transactions) { tx -> String in
            if groupBy == .month { return tx.date.formatted(.dateTime.year().month(.abbreviated)) }
            return groupingKey(for: edMap[tx.filmKey], groupBy: groupBy, store: store)
        }
        return grouped.map { ReportPoint(label: $0.key, value: $0.value.reduce(0) { $0 + $1.amount }) }
    }

    private static func watchPoints(groupBy: GroupByField, events: [WatchEvent], editions: [MovieEdition], store: VaultStore) -> [ReportPoint] {
        if groupBy == .none { return [ReportPoint(label: "Total", value: Double(events.count))] }
        let edMap = Dictionary(uniqueKeysWithValues: editions.map { ($0.filmKey, $0) })
        let grouped = Dictionary(grouping: events) { event -> String in
            if groupBy == .month { return event.watchedOn.formatted(.dateTime.year().month(.abbreviated)) }
            return groupingKey(for: edMap[event.filmKey], groupBy: groupBy, store: store)
        }
        return grouped.map { ReportPoint(label: $0.key, value: Double($0.value.count)) }
    }

    private static func avgRatingPoints(groupBy: GroupByField, events: [WatchEvent], editions: [MovieEdition], store: VaultStore) -> [ReportPoint] {
        func avg(_ items: [WatchEvent]) -> Double {
            let r = items.compactMap(\.ratingOutOfFive)
            return r.isEmpty ? 0 : r.reduce(0, +) / Double(r.count)
        }
        if groupBy == .none { return [ReportPoint(label: "Average", value: avg(events))] }
        let edMap = Dictionary(uniqueKeysWithValues: editions.map { ($0.filmKey, $0) })
        let grouped = Dictionary(grouping: events) { groupingKey(for: edMap[$0.filmKey], groupBy: groupBy, store: store) }
        return grouped.map { ReportPoint(label: $0.key, value: avg($0.value)) }
    }

    private static func blindBuyPoints(groupBy: GroupByField, events: [WatchEvent], editions: [MovieEdition], store: VaultStore) -> [ReportPoint] {
        let blindKeys = Set(editions.filter(\.isBlindBuy).map(\.filmKey))
        let blind = events.filter { blindKeys.contains($0.filmKey) && $0.ratingOutOfFive != nil }
        func rate(_ items: [WatchEvent]) -> Double {
            let r = items.compactMap(\.ratingOutOfFive)
            guard !r.isEmpty else { return 0 }
            return Double(r.filter { $0 >= 3.5 }.count) / Double(r.count) * 100
        }
        if groupBy == .none { return [ReportPoint(label: "Blind Hit Rate", value: rate(blind))] }
        let edMap = Dictionary(uniqueKeysWithValues: editions.filter(\.isBlindBuy).map { ($0.filmKey, $0) })
        let grouped = Dictionary(grouping: blind) { groupingKey(for: edMap[$0.filmKey], groupBy: groupBy, store: store) }
        return grouped.map { ReportPoint(label: $0.key, value: rate($0.value)) }
    }
}

// =====================================================
// MARK: - Advanced Filter Engine
// =====================================================

enum AdvancedFilterEngine {
    static func apply(_ filter: SavedAdvancedFilter, to editions: [MovieEdition], store: VaultStore) -> [MovieEdition] {
        editions.filter { edition in
            let results = filter.rules.map { matches(edition, rule: $0, store: store) }
            switch filter.logic {
            case .and: return results.allSatisfy { $0 }
            case .or:  return results.contains(true)
            }
        }
    }

    private static func matches(_ edition: MovieEdition, rule: AdvancedFilterRule, store: VaultStore) -> Bool {
        switch rule.field {
        case .title:            return edition.title.localizedCaseInsensitiveContains(rule.value)
        case .label:            return edition.label.localizedCaseInsensitiveContains(rule.value)
        case .tag:              return (edition.tags + edition.customTags).contains { $0.localizedCaseInsensitiveContains(rule.value) }
        case .location:
            guard let id = edition.storageLocationID,
                  let loc = store.storageLocations.first(where: { $0.id == id }) else { return false }
            return loc.name.localizedCaseInsensitiveContains(rule.value)
        case .format:           return edition.format.rawValue.localizedCaseInsensitiveContains(rule.value)
        case .watchStatus:      return edition.watchStatus.rawValue.localizedCaseInsensitiveContains(rule.value)
        case .collectionStatus: return edition.collectionStatus.rawValue.localizedCaseInsensitiveContains(rule.value)
        case .wishlistPriority: return edition.wishlistPriority.title.localizedCaseInsensitiveContains(rule.value)
        case .purchaseUrgency:  return edition.purchaseUrgency.title.localizedCaseInsensitiveContains(rule.value)
        case .oopRisk:          return edition.oopRiskLevel.title.localizedCaseInsensitiveContains(rule.value)
        case .hasPremiumSpecs:  return rule.op == .isTrue ? edition.hasPremiumSpecs : !edition.hasPremiumSpecs
        case .isBlindBuy:       return rule.op == .isTrue ? edition.isBlindBuy : !edition.isBlindBuy
        case .isBoxSet:         return rule.op == .isTrue ? edition.isBoxSet : !edition.isBoxSet
        case .isLoanedOut:      return rule.op == .isTrue ? edition.isLoanedOut : !edition.isLoanedOut
        case .year:
            guard let v = Int(rule.value) else { return false }
            switch rule.op {
            case .equals:      return edition.year == v
            case .greaterThan: return edition.year > v
            case .lessThan:    return edition.year < v
            default:           return false
            }
        case .purchasePrice:
            guard let target = Double(rule.value), let price = edition.purchasePrice else { return false }
            switch rule.op {
            case .equals:      return price == target
            case .greaterThan: return price > target
            case .lessThan:    return price < target
            default:           return false
            }
        case .estimatedValue:
            guard let target = Double(rule.value), let val = edition.estimatedValue else { return false }
            switch rule.op {
            case .equals:      return val == target
            case .greaterThan: return val > target
            case .lessThan:    return val < target
            default:           return false
            }
        }
    }
}
