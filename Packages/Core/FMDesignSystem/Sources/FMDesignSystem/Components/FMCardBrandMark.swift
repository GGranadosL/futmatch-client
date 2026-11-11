import SwiftUI

/// Card network mark drawn in SwiftUI, so no image assets are bundled.
/// Stripe brand ids: "visa", "mastercard", "amex", anything else (or nil) falls back
/// to a generic card.
public struct FMCardBrandMark: View {
    public enum Brand: Equatable {
        case visa, mastercard, amex, generic

        public init(stripeBrand: String?) {
            switch stripeBrand?.lowercased().replacingOccurrences(of: "_", with: "") {
            case "visa": self = .visa
            case "mastercard", "mc": self = .mastercard
            case "amex", "americanexpress": self = .amex
            default: self = .generic
            }
        }
    }

    private let brand: Brand
    private let width: CGFloat

    public init(brand: String?, width: CGFloat = 52) {
        self.brand = Brand(stripeBrand: brand)
        self.width = width
    }

    private var height: CGFloat { width * 0.62 }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.1)
                .fill(tileColor)
            mark
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private var tileColor: Color {
        switch brand {
        case .visa: return .white
        case .mastercard: return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .amex: return Color(red: 0.0, green: 0.44, blue: 0.80)
        // Theme-aware so the "no card" state doesn't glare in dark mode.
        case .generic: return FMColors.surfaceContainerHighest
        }
    }

    @ViewBuilder
    private var mark: some View {
        switch brand {
        case .mastercard:
            let d = height * 0.62
            ZStack {
                Circle().fill(Color(red: 0.92, green: 0.0, blue: 0.11))
                    .frame(width: d, height: d)
                    .offset(x: -d * 0.3)
                Circle().fill(Color(red: 0.97, green: 0.62, blue: 0.11))
                    .frame(width: d, height: d)
                    .offset(x: d * 0.3)
                    .opacity(0.9)
            }
        case .visa:
            Text("VISA")
                .font(.system(size: height * 0.42, weight: .heavy).italic())
                .foregroundColor(Color(red: 0.08, green: 0.2, blue: 0.6))
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.1)
                        .stroke(FMColors.outlineVariant, lineWidth: 0.5)
                        .frame(width: width, height: height)
                )
        case .amex:
            Text("AMEX")
                .font(.system(size: height * 0.34, weight: .black))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 4)
        case .generic:
            Image(systemName: "creditcard")
                .font(.system(size: height * 0.48, weight: .regular))
                .foregroundColor(FMColors.onSurfaceVariant)
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.1)
                        .stroke(FMColors.outlineVariant, lineWidth: 0.5)
                        .frame(width: width, height: height)
                )
        }
    }
}
