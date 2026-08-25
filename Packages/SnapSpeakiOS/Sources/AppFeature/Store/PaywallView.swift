import DesignSystem
import SwiftUI

public struct PaywallView: View {
    @ObservedObject var dependencies: AppDependencies
    let reason: String
    var onClose: () -> Void

    @State private var isWorking = false
    @State private var statusKey: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        dependencies: AppDependencies,
        reason: String,
        onClose: @escaping () -> Void
    ) {
        self.dependencies = dependencies
        self.reason = reason
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("paywall.title")
                    .font(Typography.title)
                    .accessibilityAddTraits(.isHeader)
                Text("paywall.subtitle")
                    .font(Typography.body)
                offeringSection
                productButtons
                if isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityLabel("paywall.working")
                }
                if let statusKey {
                    Text(LocalizedStringKey(statusKey))
                        .font(Typography.caption)
                        .foregroundStyle(Colors.secondaryFill)
                        .accessibilityLabel(LocalizedStringKey(statusKey))
                }
                SecondaryButton("paywall.restore") {
                    Task { await restore() }
                }
                .disabled(isWorking)
                .accessibilityHint("paywall.restore_a11y")
                links
            }
            .padding()
        }
        .navigationTitle("paywall.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onClose) {
                    Text("paywall.close")
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .task {
            dependencies.analytics.track(.paywallShown(reason: reason))
        }
    }

    private var offeringSection: some View {
        CardContainer {
            Text("paywall.offering")
                .font(Typography.headline)
            Label("paywall.offering.courses", systemImage: "books.vertical")
                .font(Typography.body)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            Label("paywall.offering.composition", systemImage: "text.bubble")
                .font(Typography.body)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("paywall.offering_a11y")
    }

    @ViewBuilder
    private var productButtons: some View {
        if dependencies.offerings.isEmpty {
            Text("paywall.unavailable")
                .font(Typography.body)
                .foregroundStyle(Colors.secondaryFill)
        } else {
            ForEach(dependencies.offerings) { offering in
                productButton(offering)
            }
        }
    }

    private func productButton(_ offering: StoreOffering) -> some View {
        let title = localizedKey(productTitleKey(offering.productID))
        let period = localizedKey(periodKey(offering.periodCode))
        return Button {
            Task { await purchase(offering.productID) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(productTitleKey(offering.productID)))
                    .font(Typography.headline)
                Text(offering.displayPrice)
                    .font(Typography.title)
                    .monospacedDigit()
                Text(LocalizedStringKey(periodKey(offering.periodCode)))
                    .font(Typography.caption)
                    .foregroundStyle(Colors.secondaryFill)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            LocalizedFormat.string("paywall.subscribe_a11y", title, offering.displayPrice, period)
        )
        .accessibilityAddTraits(.isButton)
    }

    private var links: some View {
        AdaptiveStack {
            if let url = StoreLinks.terms {
                externalLink("paywall.terms", url: url)
            }
            if let url = StoreLinks.privacy {
                externalLink("paywall.privacy", url: url)
            }
        }
    }

    private func purchase(_ productID: String) async {
        isWorking = true
        statusKey = nil
        let outcome = await dependencies.purchase(productID: productID)
        isWorking = false
        switch outcome {
        case .success:
            if !reduceMotion {
                statusKey = "paywall.success"
            }
            onClose()
        case .cancelled:
            statusKey = "paywall.error.cancelled"
        case .pending:
            statusKey = "paywall.error.pending"
        case .failed:
            statusKey = "paywall.error.generic"
        }
    }

    private func restore() async {
        isWorking = true
        statusKey = nil
        let outcome = await dependencies.restorePurchases()
        isWorking = false
        switch outcome {
        case .success:
            if dependencies.entitlement.isPro {
                onClose()
            } else {
                statusKey = "paywall.restore.empty"
            }
        case .cancelled:
            statusKey = "paywall.error.cancelled"
        case .pending:
            statusKey = "paywall.error.pending"
        case .failed:
            statusKey = "paywall.error.generic"
        }
    }

    private func productTitleKey(_ productID: String) -> String {
        productID == StoreProductID.yearly ? "paywall.product.yearly" : "paywall.product.monthly"
    }

    private func periodKey(_ code: String) -> String {
        switch code {
        case "year": return "paywall.period.year"
        case "month": return "paywall.period.month"
        case "week": return "paywall.period.week"
        case "day": return "paywall.period.day"
        default: return "paywall.period.generic"
        }
    }

    private func localizedKey(_ key: String) -> String {
        String(localized: String.LocalizationValue(stringLiteral: key))
    }

    private func externalLink(_ titleKey: LocalizedStringKey, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(titleKey)
                Image(systemName: "arrow.up.right.square")
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityHint("privacy.policy_external_hint")
    }
}
