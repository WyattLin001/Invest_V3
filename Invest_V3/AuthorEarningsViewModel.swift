import SwiftUI
import Foundation

@MainActor
class AuthorEarningsViewModel: ObservableObject {
    @Published var totalEarnings: Double = 0
    @Published var subscriptionEarnings: Double = 0
    @Published var tipEarnings: Double = 0
    @Published var withdrawableAmount: Double = 0
    @Published var isLoading = false
    @Published var hasError = false

    private let supabaseService = SupabaseService.shared

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        // TODO: Replace with real data loading
        await Task.sleep(300_000_000) // simulate network delay
        totalEarnings = 1250
        subscriptionEarnings = 900
        tipEarnings = 350
        withdrawableAmount = 750
    }

    func refreshData() async {
        await loadData()
    }
}