import SwiftUI

// MARK: - Theme

enum VaultTheme {
    static let bgTop    = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let bgMid    = Color(red: 0.03, green: 0.03, blue: 0.05)
    static let bgBottom = Color.black
    static let card         = Color.white.opacity(0.07)
    static let cardStrong   = Color.white.opacity(0.10)
    static let cardSoft     = Color.white.opacity(0.05)
    static let stroke       = Color.white.opacity(0.10)
    static let strokeStrong = Color.white.opacity(0.16)
    static let gold   = Color(red: 0.91, green: 0.77, blue: 0.34)
    static let plum   = Color(red: 0.48, green: 0.24, blue: 0.74)
    static let cyan   = Color(red: 0.26, green: 0.78, blue: 0.95)
    static let green  = Color(red: 0.29, green: 0.82, blue: 0.54)
    static let orange = Color(red: 0.96, green: 0.59, blue: 0.20)
    static let red    = Color(red: 0.92, green: 0.31, blue: 0.33)
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    static let textTertiary  = Color.white.opacity(0.45)
    static let cardRadius:   CGFloat = 24
    static let smallRadius:  CGFloat = 16
    static let posterRadius: CGFloat = 28
    static let buttonRadius: CGFloat = 18
}

extension Color {
    init?(hex: String) {
        let t = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard t.count == 6, let int = Int(t, radix: 16) else { return nil }
        self = Color(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}

// MARK: - Enums

enum FormatType: String, CaseIterable, Identifiable, Codable {
    case uhd4K     = "4K UHD"
    case bluRay    = "Blu-ray"
    case dvd       = "DVD"
    case vhs       = "VHS"
    case laserDisc = "LaserDisc"
    case digital   = "Digital"
    var id: String { rawValue }
    var tint: Color {
        switch self {
        case .uhd4K:     return .orange
        case .bluRay:    return .blue
        case .dvd:       return .red
        case .vhs:       return .purple
        case .laserDisc: return .pink
        case .digital:   return .green
        }
    }
    var tintHex: String {
        switch self {
        case .uhd4K:     return "#E88A1A"
        case .bluRay:    return "#246BFF"
        case .dvd:       return "#D93F3F"
        case .vhs:       return "#7C3AED"
        case .laserDisc: return "#DB2777"
        case .digital:   return "#16A34A"
        }
    }
    static func infer(from text: String) -> FormatType? {
        let l = text.lowercased()
        if l.contains("4k") || l.contains("uhd")        { return .uhd4K }
        if l.contains("blu-ray") || l.contains("bluray") { return .bluRay }
        if l.contains("dvd")                             { return .dvd }
        if l.contains("vhs")                             { return .vhs }
        if l.contains("laserdisc")                       { return .laserDisc }
        if l.contains("digital")                         { return .digital }
        return nil
    }
}

enum EditionType: String, CaseIterable, Identifiable, Codable {
    case standard          = "Standard"
    case steelbook         = "Steelbook"
    case slipcover         = "Slipcover"
    case boxSet            = "Box Set"
    case collectorsEdition = "Collector's Edition"
    case mediabook         = "Mediabook"
    var id: String { rawValue }
    var titleComponent: String? {
        switch self {
        case .standard: return nil
        default:        return rawValue
        }
    }
    static func infer(from text: String) -> EditionType? {
        let l = text.lowercased()
        if l.contains("steelbook")                           { return .steelbook }
        if l.contains("slipcover") || l.contains("slipcase") { return .slipcover }
        if l.contains("box set")   || l.contains("boxset")  { return .boxSet }
        if l.contains("collector")                           { return .collectorsEdition }
        if l.contains("mediabook")                           { return .mediabook }
        return nil
    }
}

enum CollectionStatus: String, CaseIterable, Identifiable, Codable {
    case owned    = "Owned"
    case wishlist = "Wishlist"
    var id: String { rawValue }
}

enum OpenWatchStatus: String, CaseIterable, Identifiable, Codable {
    case sealed         = "Sealed"
    case openNotWatched = "Open, Not Watched"
    case openWatched    = "Open, Watched"
    var id: String { rawValue }
}

enum WatchStatus: String, CaseIterable, Identifiable, Codable {
    case unwatched             = "Unwatched"
    case watchedNotThisEdition = "Watched, Not This Edition"
    case watchedThisEdition    = "Watched This Edition"
    var id: String { rawValue }
    var shortLabel: String {
        switch self {
        case .unwatched:             return "Unwatched"
        case .watchedNotThisEdition: return "Watched Elsewhere"
        case .watchedThisEdition:    return "Watched Here"
        }
    }
    var tint: Color {
        switch self {
        case .unwatched:             return .gray
        case .watchedNotThisEdition: return .blue
        case .watchedThisEdition:    return .green
        }
    }
}

enum ConditionRating: String, CaseIterable, Identifiable, Codable {
    case mint     = "Mint"
    case veryGood = "Very Good"
    case good     = "Good"
    case fair     = "Fair"
    case damaged  = "Damaged"
    var id: String { rawValue }
}

enum WishlistPriority: Int, CaseIterable, Identifiable, Codable {
    case low = 1, medium = 2, high = 3, grail = 4
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        case .grail:  return "Grail"
        }
    }
    var tint: Color {
        switch self {
        case .low:    return .gray
        case .medium: return .blue
        case .high:   return .orange
        case .grail:  return .yellow
        }
    }
}

enum PurchaseUrgency: Int, CaseIterable, Identifiable, Codable {
    case someday = 1, keepAnEyeOnIt = 2, soon = 3, now = 4
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .someday:        return "Someday"
        case .keepAnEyeOnIt: return "Keep an Eye On It"
        case .soon:           return "Soon"
        case .now:            return "Now"
        }
    }
    var tint: Color {
        switch self {
        case .someday:        return .gray
        case .keepAnEyeOnIt: return .cyan
        case .soon:           return .orange
        case .now:            return .red
        }
    }
}

enum OOPRiskLevel: Int, CaseIterable, Identifiable, Codable {
    case none = 0, low = 1, medium = 2, high = 3
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .none:   return "None"
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
    var tint: Color {
        switch self {
        case .none:   return .gray
        case .low:    return .blue
        case .medium: return .orange
        case .high:   return .red
        }
    }
}

enum BuyRecommendation: String, CaseIterable, Identifiable, Codable {
    case buyNow      = "Buy Now"
    case waitForSale = "Wait For Sale"
    case passForNow  = "Pass For Now"
    var id: String { rawValue }
    var tint: Color {
        switch self {
        case .buyNow:      return .green
        case .waitForSale: return .orange
        case .passForNow:  return .gray
        }
    }
    var symbol: String {
        switch self {
        case .buyNow:      return "cart.fill.badge.plus"
        case .waitForSale: return "clock.arrow.circlepath"
        case .passForNow:  return "pause.circle"
        }
    }
}

enum DuplicateDisposition: String, CaseIterable, Identifiable, Codable {
    case keep  = "Keep"
    case sell  = "Sell"
    case trade = "Trade"
    case gift  = "Gift"
    var id: String { rawValue }
    var tint: Color {
        switch self {
        case .keep:  return .green
        case .sell:  return .orange
        case .trade: return .blue
        case .gift:  return .purple
        }
    }
}

enum OrderStatus: String, CaseIterable, Identifiable, Codable {
    case preorder  = "Preorder"
    case ordered   = "Ordered"
    case shipped   = "Shipped"
    case delivered = "Delivered"
    case cancelled = "Cancelled"
    var id: String { rawValue }
    var tint: Color {
        switch self {
        case .preorder:  return .orange
        case .ordered:   return .yellow
        case .shipped:   return .blue
        case .delivered: return .green
        case .cancelled: return .red
        }
    }
}

enum TransactionType: String, CaseIterable, Identifiable, Codable {
    case purchase = "Purchase"
    case sale     = "Sale"
    case tradeOut = "Trade Out"
    case tradeIn  = "Trade In"
    case refund   = "Refund"
    var id: String { rawValue }
}

enum WatchSourceType: String, CaseIterable, Identifiable, Codable {
    case thisEdition = "This Edition"
    case theatrical  = "Theatrical"
    case streaming   = "Streaming"
    case otherDisc   = "Other Disc"
    case unknown     = "Unknown"
    var id: String { rawValue }
}

enum WatchContext: String, CaseIterable, Identifiable, Codable {
    case homeDisc    = "Home Disc"
    case homeDigital = "Home Digital"
    case theater     = "Theater"
    case other       = "Other"
    var id: String { rawValue }
    var mappedSourceType: WatchSourceType {
        switch self {
        case .homeDisc:    return .thisEdition
        case .homeDigital: return .streaming
        case .theater:     return .theatrical
        case .other:       return .otherDisc
        }
    }
}

enum SmartCollectionKind: String, CaseIterable, Identifiable, Codable {
    case blindBuysUnwatched    = "Blind Buys Unwatched"
    case upgradesNeeded        = "Upgrade Candidates"
    case loanedOut             = "Loaned Out"
    case wishlistUnderTarget   = "Wishlist Under Target"
    case duplicateCandidates   = "Duplicate Candidates"
    case mostValuableUnwatched = "Most Valuable Unwatched"
    case sealedLongTerm        = "Sealed Over A Year"
    case premiumSpecs          = "Premium Specs"
    case buyNowCandidates      = "Buy Now Candidates"
    case highRiskWishlist      = "High Risk Wishlist"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .blindBuysUnwatched:    return "eye.slash"
        case .upgradesNeeded:        return "arrow.up.circle"
        case .loanedOut:             return "arrowshape.turn.up.right"
        case .wishlistUnderTarget:   return "tag"
        case .duplicateCandidates:   return "square.on.square"
        case .mostValuableUnwatched: return "banknote"
        case .sealedLongTerm:        return "clock.arrow.circlepath"
        case .premiumSpecs:          return "sparkles.tv"
        case .buyNowCandidates:      return "cart.fill.badge.plus"
        case .highRiskWishlist:      return "flame"
        }
    }
}

enum ImportDuplicateMode: String, CaseIterable, Identifiable, Codable {
    case skip           = "Skip Duplicates"
    case addAnyway      = "Add Anyway"
    case replaceMatches = "Replace Matches"
    var id: String { rawValue }
}

enum CollectionSort: String, CaseIterable, Identifiable, Codable {
    case titleAZ          = "Title A-Z"
    case titleZA          = "Title Z-A"
    case yearNewest       = "Year Newest"
    case yearOldest       = "Year Oldest"
    case acquiredNewest   = "Acquired Newest"
    case acquiredOldest   = "Acquired Oldest"
    case paidHighLow      = "Price High-Low"
    case paidLowHigh      = "Price Low-High"
    case valueHighLow     = "Value High-Low"
    case labelAZ          = "Label A-Z"
    case watchedFirst     = "Watched First"
    case unwatchedFirst   = "Unwatched First"
    case wishlistPriority = "Wishlist Priority"
    case urgency          = "Urgency"
    case targetGap        = "Closest To Target"
    case oopRisk          = "OOP Risk"
    case releaseDateSoonest = "Release Date Soonest"
    var id: String { rawValue }
}

enum CollectionViewMode: String, CaseIterable, Identifiable, Codable {
    case grouped = "Grouped"
    case grid    = "Grid"
    case list    = "List"
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .grouped: return "square.stack.3d.up"
        case .grid:    return "square.grid.2x2"
        case .list:    return "list.bullet"
        }
    }
}

enum CollectionTabFilter: String, CaseIterable, Identifiable, Codable {
    case all          = "All"
    case owned        = "Owned"
    case wishlist     = "Wishlist"
    case blindBuys    = "Blind Buys"
    case unwatched    = "Unwatched"
    case premiumSpecs = "Premium Specs"
    case buyNow       = "Buy Now"
    var id: String { rawValue }
}

enum OrderFilter: String, CaseIterable, Identifiable, Codable {
    case all       = "All"
    case preorder  = "Preorder"
    case ordered   = "Ordered"
    case shipped   = "Shipped"
    case delivered = "Delivered"
    var id: String { rawValue }
}

enum GroupByField: String, CaseIterable, Identifiable, Codable {
    case none     = "Nothing"
    case label    = "Label"
    case format   = "Format"
    case year     = "Year"
    case decade   = "Decade"
    case month    = "Month"
    case location = "Location"
    case priority = "Priority"
    case urgency  = "Urgency"
    case oopRisk  = "OOP Risk"
    var id: String { rawValue }
}

enum MetricKind: String, CaseIterable, Identifiable, Codable {
    case totalItemsOwned                 = "Total Items Owned"
    case wishlistCount                   = "Wishlist Count"
    case onOrderCount                    = "On Order Count"
    case backlogCount                    = "Backlog Count"
    case blindBuyHitRate                 = "Blind Buy Hit Rate"
    case watchCount                      = "Watch Count"
    case totalSpend                      = "Total Spend"
    case totalSales                      = "Total Sales"
    case netProfit                       = "Net Profit"
    case collectionValueEstimate         = "Collection Value Estimate"
    case averageRating                   = "Average Rating"
    case averageDaysPurchaseToFirstWatch = "Avg Days Purchase to First Watch"
    case buyNowCandidates                = "Buy Now Candidates"
    case wishlistTargetGap               = "Wishlist Target Gap"
    case preorderThisMonth               = "Preorders This Month"
    case recentPriceDrops                = "Recent Price Drops"
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .totalItemsOwned:                 return "film.stack"
        case .wishlistCount:                   return "heart.text.square"
        case .onOrderCount:                    return "shippingbox"
        case .backlogCount:                    return "clock.badge.exclamationmark"
        case .blindBuyHitRate:                 return "eye.slash"
        case .watchCount:                      return "play.circle"
        case .totalSpend:                      return "creditcard"
        case .totalSales:                      return "dollarsign.circle"
        case .netProfit:                       return "chart.line.uptrend.xyaxis"
        case .collectionValueEstimate:         return "banknote"
        case .averageRating:                   return "star"
        case .averageDaysPurchaseToFirstWatch: return "calendar.badge.clock"
        case .buyNowCandidates:                return "cart.fill.badge.plus"
        case .wishlistTargetGap:               return "tag"
        case .preorderThisMonth:               return "calendar"
        case .recentPriceDrops:                return "arrow.down.circle"
        }
    }
}

enum AnalyticsDateRange: String, CaseIterable, Identifiable, Codable {
    case allTime    = "All Time"
    case last30Days = "Last 30 Days"
    case last90Days = "Last 90 Days"
    case thisMonth  = "This Month"
    case thisYear   = "This Year"
    case lastYear   = "Last Year"
    var id: String { rawValue }
    func contains(_ date: Date, now: Date = Date()) -> Bool {
        let cal = Calendar.current
        switch self {
        case .allTime: return true
        case .last30Days:
            guard let start = cal.date(byAdding: .day, value: -30, to: now) else { return true }
            return date >= start && date <= now
        case .last90Days:
            guard let start = cal.date(byAdding: .day, value: -90, to: now) else { return true }
            return date >= start && date <= now
        case .thisMonth:
            guard let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { return true }
            return date >= start && date <= now
        case .thisYear:
            guard let start = cal.date(from: cal.dateComponents([.year], from: now)) else { return true }
            return date >= start && date <= now
        case .lastYear:
            guard
                let thisStart = cal.date(from: cal.dateComponents([.year], from: now)),
                let lastStart = cal.date(byAdding: .year, value: -1, to: thisStart)
            else { return true }
            return date >= lastStart && date < thisStart
        }
    }
}

enum ReportChartStyle: String, CaseIterable, Identifiable, Codable {
    case bar   = "Bar"
    case line  = "Line"
    case table = "Table"
    var id: String { rawValue }
}

enum BulkEditAction: String, CaseIterable, Identifiable {
    case watchedThisEdition      = "Mark Watched This Edition"
    case unwatched               = "Mark Unwatched"
    case addTag                  = "Add Tag"
    case removeTag               = "Remove Tag"
    case moveLocation            = "Move Location"
    case setCondition            = "Set Condition"
    case setDuplicateDisposition = "Set Duplicate Disposition"
    case setWishlistPriority     = "Set Wishlist Priority"
    case setUrgency              = "Set Urgency"
    var id: String { rawValue }
}

enum AppFeature: String, CaseIterable, Codable, Identifiable {
    case advancedAnalytics, savedReports, locationsAndLoans, marketValueTools,
         bulkEdit, smartFilters, dashboardEditor, boxSetManager,
         wishlistIntelligence, releaseCalendar, orderManager, reminders
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .advancedAnalytics:   return "Advanced Analytics"
        case .savedReports:        return "Saved Reports"
        case .locationsAndLoans:   return "Locations and Loans"
        case .marketValueTools:    return "Market Value Tools"
        case .bulkEdit:            return "Bulk Edit"
        case .smartFilters:        return "Smart Filters"
        case .dashboardEditor:     return "Dashboard Editor"
        case .boxSetManager:       return "Box Set Manager"
        case .wishlistIntelligence: return "Wishlist Intelligence"
        case .releaseCalendar:     return "Release Calendar"
        case .orderManager:        return "Order Manager"
        case .reminders:           return "Reminders"
        }
    }
}

enum ToastStyle: String, Codable {
    case success, warning, error, info
    var tint: Color {
        switch self {
        case .success: return .green
        case .warning: return .orange
        case .error:   return .red
        case .info:    return .cyan
        }
    }
    var symbol: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.octagon.fill"
        case .info:    return "info.circle.fill"
        }
    }
}

enum EditModePayload {
    case add(String?)
    case edit(MovieEdition)
    case addAnotherEdition(MovieEdition)
}

enum BarcodeImportState: Equatable {
    case idle
    case loading(String)
    case imported(ImportedEditionSeed)
    case noMatch(String)
    case failed(String)
}

enum VaultLoadingState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

// MARK: - Supporting Value Types

struct PricePoint: Identifiable, Hashable, Codable {
    var id       = UUID()
    var retailer:  String
    var amount:    Double
    var date:      Date
    var note:      String
}

struct RetailerLink: Identifiable, Hashable, Codable {
    var id              = UUID()
    var retailer:         String
    var urlString:        String
    var note:             String
    var currentPrice:     Double?
    var previousPrice:    Double?
    var lowestSeenPrice:  Double?
    var lastChecked:      Date?
    var isPreferred:      Bool
}

struct DiscInfo: Identifiable, Hashable, Codable {
    var id            = UUID()
    var discLabel:      String
    var discType:       String
    var regionCode:     String
    var runtimeMinutes: Int?
    var notes:          String
}

struct MarketPriceStats: Identifiable, Hashable, Codable {
    var id         = UUID()
    var lastUpdated: Date?
    var currency:    String
    var lowestSold:  Double?
    var highestSold: Double?
    var medianSold:  Double?
    var averageSold: Double?
    var sampleSize:  Int
    var source:      String
}

struct BarcodeHistoryEntry: Identifiable, Hashable, Codable {
    var id          = UUID()
    var barcode:      String
    var title:        String
    var lookupSource: String
    var timestamp:    Date
    var success:      Bool
}

struct AppToast: Identifiable, Equatable {
    let id      = UUID()
    let style:    ToastStyle
    let message:  String
}

// MARK: - Core Models

struct MovieEdition: Identifiable, Hashable, Codable {
    var id = UUID()
    var title:         String
    var originalTitle: String
    var year:          Int
    var editionTitle:  String
    var format:        FormatType
    var editionType:   EditionType
    var collectionStatus: CollectionStatus
    var openWatchStatus:  OpenWatchStatus
    var watchStatus:      WatchStatus
    var condition:        ConditionRating
    var label:      String
    var labelID:    UUID?
    var studio:     String
    var regionCode: String
    var barcode:    String
    var isBlindBuy:  Bool
    var isFavorite:  Bool
    var hasDamage:   Bool
    var damageNotes: String
    var coverSystemImage: String
    var accentHex:        String
    var coverImageID:     String?
    var remotePosterPath: String?
    var hasIMAXScenes:  Bool
    var hasDolbyVision: Bool
    var hasHDR10:       Bool
    var hasHDR10Plus:   Bool
    var hasDolbyAtmos:  Bool
    var hasDolbyAudio:  Bool
    var hasDTSX:        Bool
    var videoNotes:     String
    var audioNotes:     String
    var lowestKnownPrice:    Double?
    var purchasePrice:       Double?
    var estimatedValue:      Double?
    var marketStats:         MarketPriceStats?
    var pricePaidHistory:    [PricePoint]
    var retailerLinks:       [RetailerLink]
    var wishlistPriceHistory: [PricePoint]
    var isUpgradeCandidate:   Bool
    var duplicateDisposition: DuplicateDisposition
    var wishlistTargetPrice:  Double?
    var expectedReleaseDate:  Date?
    var wishlistPriority:     WishlistPriority
    var purchaseUrgency:      PurchaseUrgency
    var reasonWanted:         String
    var isLimitedPressing:    Bool
    var oopRiskLevel:         OOPRiskLevel
    var customTags:    [String]
    var tags:          [String]
    var franchiseName: String
    var boxSetName:    String
    var isBoxSet:      Bool
    var parentBoxSetID: UUID?
    var isLoanedOut: Bool
    var loanedTo:    String
    var loanedDate:  Date?
    var dueDate:     Date?
    var loanNotes:   String
    var cutName:           String
    var hasCommentary:     Bool
    var commentaryDetails: String
    var specialFeatures:   String
    var discs:             [DiscInfo]
    var storageLocationID: UUID?
    var acquiredDate:   Date?
    var dateCreated:    Date
    var dateModified:   Date
    var collectorNotes: String
    var timesWatched:    Int
    var lastWatchedDate: Date?

    var hasPremiumSpecs: Bool {
        hasIMAXScenes || hasDolbyVision || hasHDR10Plus || hasDolbyAtmos || hasDTSX
    }
    var filmKey: String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) + "|" + String(year)
    }
    var lastPaidPrice: Double? {
        pricePaidHistory.sorted { $0.date > $1.date }.first?.amount ?? purchasePrice
    }
    var sealedLongTerm: Bool {
        guard openWatchStatus == .sealed, let date = acquiredDate else { return false }
        return date <= Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    }
    var effectiveValue: Double {
        estimatedValue ?? marketStats?.medianSold ?? lowestKnownPrice ?? lastPaidPrice ?? 0
    }
    var bestRetailer: RetailerLink? {
        retailerLinks
            .filter { $0.currentPrice != nil }
            .sorted { ($0.currentPrice ?? Double.greatestFiniteMagnitude) < ($1.currentPrice ?? Double.greatestFiniteMagnitude) }
            .first
    }
    var bestCurrentPrice: Double? {
        bestRetailer?.currentPrice ?? lowestKnownPrice
    }
    var lowestSeenRetailerPrice: Double? {
        retailerLinks.compactMap(\.lowestSeenPrice).min()
    }
    var targetGap: Double? {
        guard let target = wishlistTargetPrice, let current = bestCurrentPrice else { return nil }
        return current - target
    }
    var bestRetailerPriceDrop: Double? {
        guard let r = bestRetailer,
              let current = r.currentPrice,
              let previous = r.previousPrice,
              previous > current else { return nil }
        return previous - current
    }
    var underTargetPrice: Bool {
        guard collectionStatus == .wishlist,
              let target = wishlistTargetPrice,
              let current = bestCurrentPrice ?? lowestKnownPrice else { return false }
        return current <= target
    }
    var targetSavingsText: String? {
        guard collectionStatus == .wishlist,
              let target = wishlistTargetPrice,
              let current = bestCurrentPrice else { return nil }
        if current <= target {
            return "Under target by " + currencyString(target - current)
        } else {
            return "Above target by " + currencyString(current - target)
        }
    }
    var buyRecommendation: BuyRecommendation {
        guard collectionStatus == .wishlist else { return .passForNow }
        let current  = bestCurrentPrice ?? lowestKnownPrice ?? Double.greatestFiniteMagnitude
        let target   = wishlistTargetPrice ?? current
        let priority = wishlistPriority.rawValue
        let urgency  = purchaseUrgency.rawValue
        let risk     = oopRiskLevel.rawValue + (isLimitedPressing ? 1 : 0)
        let hasDrop  = (bestRetailerPriceDrop ?? 0) >= 5
        if current <= target && (priority >= 3 || urgency >= 3 || risk >= 2)      { return .buyNow }
        if risk >= 3 && priority >= 2                                               { return .buyNow }
        if hasDrop && priority >= 3                                                 { return .buyNow }
        if current <= target * 1.12 && (priority >= 3 || urgency >= 3)             { return .buyNow }
        if current <= target * 1.20 || urgency >= 2 || priority >= 2 || risk >= 2  { return .waitForSale }
        return .passForNow
    }
    var recommendationReason: String {
        switch buyRecommendation {
        case .buyNow:
            if isLimitedPressing || oopRiskLevel == .high {
                return "Scarcity risk is high and this one is near the front of your collector brain."
            }
            if let drop = bestRetailerPriceDrop, drop > 0 {
                return "There is a live price drop that plays nicely with your urgency and priority."
            }
            if underTargetPrice { return "Current price is at or below your target." }
            return "This one lines up with your urgency and priority settings."
        case .waitForSale:
            if let gap = targetGap, gap > 0 { return "Close enough to stalk, but worth waiting for a better hit." }
            return "Promising title, but not yet a wallet-summoning event."
        case .passForNow:
            return "Low urgency, lower priority, or nothing dramatic enough in the pricing yet."
        }
    }
}

struct OrderItem: Identifiable, Hashable, Codable {
    var id               = UUID()
    var title:             String
    var editionTitle:      String
    var retailer:          String
    var orderStatus:       OrderStatus
    var releaseDate:       Date?
    var estimatedChargeDate: Date?
    var orderDate:         Date
    var trackingNumber:    String
    var orderNumber:       String
    var notes:             String
    var price:             Double
    var accentHex:         String
    var coverSystemImage:  String
    var linkedEditionID:   UUID?
    var lineItems:         [OrderLineItem]
}

struct OrderLineItem: Identifiable, Hashable, Codable {
    var id          = UUID()
    var editionID:    UUID?
    var title:        String
    var editionTitle: String
    var price:        Double
}

struct WatchEvent: Identifiable, Hashable, Codable {
    var id             = UUID()
    var editionID:       UUID?
    var filmKey:         String
    var watchedOn:       Date
    var sourceType:      WatchSourceType
    var ratingOutOfFive: Double?
    var notes:           String
    var rewatchNumber:   Int
}

struct Transaction: Identifiable, Hashable, Codable {
    var id             = UUID()
    var editionID:       UUID?
    var filmKey:         String
    var type:            TransactionType
    var amount:          Double
    var retailerOrBuyer: String
    var date:            Date
    var notes:           String
}

struct StorageLocation: Identifiable, Hashable, Codable {
    var id    = UUID()
    var name:   String
    var room:   String
    var shelf:  String
    var bin:    String
    var notes:  String
    var displayName: String {
        [room, shelf, bin].filter { !$0.isEmpty }.joined(separator: " - ")
    }
}

struct LoanRecord: Identifiable, Hashable, Codable {
    var id           = UUID()
    var editionID:     UUID
    var friendName:    String
    var dateLoaned:    Date
    var dueDate:       Date?
    var returnedDate:  Date?
    var notes:         String
    var isReturned: Bool { returnedDate != nil }
    var isOverdue: Bool {
        guard let due = dueDate, returnedDate == nil else { return false }
        return due < Date()
    }
}

struct LabelInfo: Identifiable, Hashable, Codable {
    var id           = UUID()
    var fullName:      String
    var shortCode:     String
    var logoAssetName: String?
}

struct DashboardTile: Identifiable, Hashable, Codable {
    var id         = UUID()
    var metricKind:  MetricKind
    var isPinned:    Bool
    var sortOrder:   Int
    var isHidden:    Bool = false
}

struct DashboardConfig: Codable {
    var tiles: [DashboardTile]
    static var defaultConfig: DashboardConfig {
        let metrics: [MetricKind] = [
            .totalItemsOwned, .wishlistCount, .onOrderCount, .backlogCount,
            .blindBuyHitRate, .buyNowCandidates, .wishlistTargetGap,
            .preorderThisMonth, .recentPriceDrops, .collectionValueEstimate
        ]
        return DashboardConfig(tiles: metrics.enumerated().map {
            DashboardTile(metricKind: $0.element, isPinned: true, sortOrder: $0.offset)
        })
    }
}

struct ReportFilter: Hashable, Codable {
    var onlyBlindBuys:    Bool    = false
    var onlyUnwatched:    Bool    = false
    var includeWishlist:  Bool    = true
    var format:           FormatType? = nil
    var labelID:          UUID?   = nil
    var maxPurchasePrice: Double? = nil
    var minRating:        Double? = nil
    var onlyBuyNow:       Bool    = false
    static let defaultFilter = ReportFilter()
}

struct SavedAnalyticsReport: Identifiable, Hashable, Codable {
    var id        = UUID()
    var name:       String
    var metric:     MetricKind
    var groupBy:    GroupByField
    var dateRange:  AnalyticsDateRange
    var filters:    ReportFilter
    var chartStyle: ReportChartStyle = .bar
    var notes:      String
}

struct ReportPoint: Identifiable, Hashable, Codable {
    var id    = UUID()
    var label:  String
    var value:  Double
}

struct ReportResult: Hashable, Codable {
    var title:    String
    var subtitle: String
    var points:   [ReportPoint]
    var total:    Double
}

struct AnalyticsInsight: Identifiable, Hashable, Codable {
    var id     = UUID()
    var title:   String
    var detail:  String
}

struct SmartCollectionPreset: Identifiable, Hashable, Codable {
    var id        = UUID()
    var kind:       SmartCollectionKind
    var customName: String?
    var title: String { customName?.isEmpty == false ? customName! : kind.rawValue }
}

struct FeatureEntitlements: Codable {
    var enabledFeatures: Set<AppFeature> = Set(AppFeature.allCases)
    func isEnabled(_ feature: AppFeature) -> Bool { enabledFeatures.contains(feature) }
}

struct FilmGroup: Identifiable, Hashable {
    let id:            String
    let title:         String
    let originalTitle: String
    let year:          Int
    let editions:      [MovieEdition]
    var representative: MovieEdition { editions.first(where: \.isFavorite) ?? editions[0] }
    var ownedCount:    Int { editions.filter { $0.collectionStatus == .owned }.count }
    var wishlistCount: Int { editions.filter { $0.collectionStatus == .wishlist }.count }
    var has4KOwned:    Bool { editions.contains { $0.collectionStatus == .owned && $0.format == .uhd4K } }
    var sellTradeCount: Int { editions.filter { $0.duplicateDisposition == .sell || $0.duplicateDisposition == .trade }.count }
    var boxSetParent:  MovieEdition? { editions.first(where: \.isBoxSet) }
}

struct ReleaseMonthGroup: Identifiable {
    let id        = UUID()
    let title:      String
    let monthDate:  Date
    let items:      [OrderItem]
    let total:      Double
}

struct CollectionSummary {
    var totalOwned:       Int    = 0
    var totalWishlist:    Int    = 0
    var totalFilms:       Int    = 0
    var totalEditions:    Int    = 0
    var total4Ks:         Int    = 0
    var totalBlindBuys:   Int    = 0
    var totalUnwatched:   Int    = 0
    var totalSealed:      Int    = 0
    var totalLoanedOut:   Int    = 0
    var buyNowCount:      Int    = 0
    var collectionValue:  Double = 0
    var totalSpend:       Double = 0
    var totalSales:       Double = 0
    var preorderPressure: Double = 0
    var blindBuyHitRate:  Double = 0
    var averageRating:    Double = 0
}

struct VaultBackup: Codable {
    static let currentSchemaVersion = 2
    var schemaVersion:          Int
    var editions:               [MovieEdition]
    var orders:                 [OrderItem]
    var watchEvents:            [WatchEvent]
    var transactions:           [Transaction]
    var storageLocations:       [StorageLocation]
    var loanRecords:            [LoanRecord]
    var labels:                 [LabelInfo]
    var barcodeHistory:         [BarcodeHistoryEntry]
    var dashboardConfig:        DashboardConfig
    var savedAnalyticsReports:  [SavedAnalyticsReport]
    var smartCollectionPresets: [SmartCollectionPreset]
    var entitlements:           FeatureEntitlements
    var exportedAt:             Date
}

struct ImportedEditionSeed: Equatable, Identifiable, Codable {
    let id            = UUID()
    var barcode:        String
    var title:          String
    var originalTitle:  String
    var year:           Int?
    var editionTitle:   String
    var format:         FormatType?
    var editionType:    EditionType?
    var label:          String
    var studio:         String
    var regionCode:     String
    var coverSystemImage: String
    var accentHex:      String
    var notes:          String
    var sourceName:     String
    var remotePosterPath: String?
}

// MARK: - Global Helpers

func buildEditionTitle(format: FormatType, editionType: EditionType) -> String {
    var parts = [format.rawValue]
    if let extra = editionType.titleComponent { parts.append(extra) }
    return parts.joined(separator: " ")
}

func normalizedFilmKey(title: String, year: Int) -> String {
    title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) + "|" + String(year)
}

func currencyString(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle  = .currency
    f.currencyCode = "USD"
    return f.string(from: NSNumber(value: value)) ?? "$0.00"
}

func parseTags(from text: String) -> [String] {
    text.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

func joinTags(_ tags: [String]) -> String { tags.joined(separator: ", ") }

func isValidHexColor(_ hex: String) -> Bool {
    let t = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
    guard t.count == 6 else { return false }
    return Int(t, radix: 16) != nil
}

func monthGroupTitle(for date: Date) -> String {
    date.formatted(.dateTime.year().month(.wide))
}

func parseISODate(_ string: String) -> Date? {
    guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return ISO8601DateFormatter().date(from: string)
}
