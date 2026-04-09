import SwiftUI

struct ModelNameLabel: View {
    let name: String
    var font: Font? = nil
    
    var body: some View {
        let isPremium = ModelConfiguration.isPremiumModel(name)
        let text = Text(name)
        if let font = font {
            premiumStyled(text.font(font), isPremium: isPremium)
        } else {
            premiumStyled(text, isPremium: isPremium)
        }
    }
    
    @ViewBuilder
    private func premiumStyled(_ text: Text, isPremium: Bool) -> some View {
        if isPremium {
            text
                .foregroundStyle(LinearGradient.premiumGradient)
        } else {
            text
                .foregroundColor(.primary)
        }
    }
}

