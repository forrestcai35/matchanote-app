import SwiftUI

struct HelpAndFeedbackView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var expandedFAQ: Int? = nil

    private let featurebaseURL = URL(string: "https://matchanote.featurebase.app/")
    private let privacyPolicyURL = URL(string: "https://matchanote.app/privacy-policy")
    private let termsURL = URL(string: "https://matchanote.app/terms-of-service")
    private let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id6744668137?action=write-review")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Help & Feedback")
                    .font(.jost(.largeTitle()))
                    .fontWeight(.bold)
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.matchabrown_dark : Color.matchabrown_light)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                colorScheme == .dark
                    ? Color.matchabackground_dark : Color.matchabackground_light)

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Feature Requests & Bug Reports
                        feedbackCard

                        // Rate the App
                        rateAppCard

                        // FAQ
                        faqCard

                        // Legal Links
                        legalCard

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                .scrollIndicators(.hidden)

                // Top fade effect
                VStack {
                    (colorScheme == .dark
                        ? Color.matchabackground_dark
                        : Color.matchabackground_light)
                        .mask(
                            LinearGradient(
                                colors: [Color.white, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 20)
                        .allowsHitTesting(false)

                    Spacer()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            colorScheme == .dark
                ? Color.matchabackground_dark : Color.matchabackground_light)
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                Text("Request a Feature or Report a Bug")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)

            Text("Help us improve Matcha by sharing your feedback, reporting bugs, or requesting new features.")
                .font(.jost(.caption()))
                .foregroundColor(.secondary)

            Button {
                if let url = featurebaseURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("Open Feedback Portal")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.jost(.subheadline()))
                .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill((colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light).opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }

    private var rateAppCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.yellow)
                Text("Rate Matcha")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)

            Text("Enjoying Matcha? Leave us a rating on the App Store to help others discover the app!")
                .font(.jost(.caption()))
                .foregroundColor(.secondary)

            Button {
                requestAppReview()
            } label: {
                HStack {
                    Text("Rate on App Store")
                    Spacer()
                    Image(systemName: "star")
                }
                .font(.jost(.subheadline()))
                .foregroundColor(.yellow)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }

    private var faqCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                Text("Frequently Asked Questions")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(FAQData.items) { item in
                    FAQItem(
                        index: item.id,
                        question: item.question,
                        answer: item.answer,
                        isExpanded: expandedFAQ == item.id,
                        onTap: { toggleFAQ(item.id) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }

    private var legalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                Text("Legal")
                    .font(.jost(.subheadline()))
                    .foregroundColor(.primary)
                Spacer()
            }

            VStack(spacing: 8) {
                Button {
                    if let url = privacyPolicyURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.jost(.caption()))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light).opacity(0.05))
                    )
                }
                .buttonStyle(.plain)

                Button {
                    if let url = termsURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.jost(.caption()))
                    .foregroundColor(colorScheme == .dark ? Color.matchabrown_dark : Color.matchabrown_light)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light).opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }

    private func toggleFAQ(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedFAQ = expandedFAQ == index ? nil : index
        }
    }

    private func requestAppReview() {
        if let url = appStoreReviewURL {
            UIApplication.shared.open(url)
        }
    }
}

struct FAQItem: View {
    let index: Int
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(question)
                        .font(.jost(.caption()))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isExpanded {
                    Text(answer)
                        .font(.jost(.caption()))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill((colorScheme == .dark ? Color.matchalight_dark : Color.matchalight_light).opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}
