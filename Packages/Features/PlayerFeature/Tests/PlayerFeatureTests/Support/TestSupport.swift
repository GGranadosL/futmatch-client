import Foundation
@testable import PlayerFeature

// MARK: - Shared test error

enum TestError: Error, Equatable {
    case boom
}

// MARK: - Domain model stubs

extension MatchItem {
    static func stub(
        id: String = "match-1",
        venueName: String = "Cancha Central",
        timeRange: String = "20:00 - 21:00",
        price: String = "$150",
        matchType: String = "Mixto",
        spotsLeft: Int = 4
    ) -> MatchItem {
        MatchItem(
            id: id,
            venueName: venueName,
            timeRange: timeRange,
            price: price,
            matchType: matchType,
            spotsLeft: spotsLeft
        )
    }
}

extension JoinMatchData {
    static func stub(
        clientSecret: String = "secret",
        paymentId: String = "pay-1",
        provider: String = "stripe",
        amountInCents: Int = 15_000,
        currency: String = "mxn",
        customer: String = "cus_1",
        customerSessionClientSecret: String = "css_1",
        publishableKey: String = "pk_test",
        reservationTtlMs: Int = 600_000
    ) -> JoinMatchData {
        JoinMatchData(
            clientSecret: clientSecret,
            paymentId: paymentId,
            provider: provider,
            amountInCents: amountInCents,
            currency: currency,
            customer: customer,
            customerSessionClientSecret: customerSessionClientSecret,
            publishableKey: publishableKey,
            reservationTtlMs: reservationTtlMs
        )
    }
}

extension CustomerSessionData {
    static func stub(
        customerId: String = "cus_1",
        customerSessionClientSecret: String = "css_1",
        publishableKey: String = "pk_test"
    ) -> CustomerSessionData {
        CustomerSessionData(
            customerId: customerId,
            customerSessionClientSecret: customerSessionClientSecret,
            publishableKey: publishableKey
        )
    }
}

extension PaymentHistoryItem {
    static func stub(
        id: String = "ph-1",
        amount: Int = 15_000,
        currency: String = "mxn",
        status: String = "SUCCEEDED",
        createdAt: Int64 = 0,
        paidAt: Int64? = nil,
        paymentMethod: PaymentMethodInfo? = nil,
        refund: RefundInfo? = nil
    ) -> PaymentHistoryItem {
        PaymentHistoryItem(
            id: id,
            amount: amount,
            currency: currency,
            status: status,
            createdAt: createdAt,
            paidAt: paidAt,
            paymentMethod: paymentMethod,
            refund: refund
        )
    }
}

extension PaymentPollData {
    static func stub(status: String = "SUCCEEDED", isFinal: Bool = true, isSuccess: Bool = true) -> PaymentPollData {
        PaymentPollData(status: status, isFinal: isFinal, isSuccess: isSuccess)
    }
}

extension PaymentStatusData {
    static func stub(status: String) -> PaymentStatusData {
        PaymentStatusData(paymentId: "pay-1", providerPaymentId: "pi_1", status: status, provider: "stripe")
    }
}

extension MatchPlayersSnapshot {
    static func stub(
        teamA: [MatchPlayer] = [],
        teamB: [MatchPlayer] = [],
        reservations: [String: Date] = [:]
    ) -> MatchPlayersSnapshot {
        MatchPlayersSnapshot(teamAPlayers: teamA, teamBPlayers: teamB, reservationsByPlayerId: reservations)
    }
}
