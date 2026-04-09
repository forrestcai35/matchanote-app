import Foundation

struct FAQItemData: Identifiable {
    let id: Int
    let question: String
    let answer: String
}

struct FAQData {
    static let items: [FAQItemData] = [
        FAQItemData(
            id: 0,
            question: "How do I create a new note?",
            answer: "Tap the '+' button on the home screen and select 'New Note'. You can start writing or drawing immediately."
        ),
        FAQItemData(
            id: 1,
            question: "How do AI requests work?",
            answer: "Free users get 200 basic AI requests per month. Student tier gets 2000 basic requests. Pro users get unlimited basic requests and 500 premium requests monthly. Premium requests include advanced AI features like flashcard generation and study mode."
        ),
        FAQItemData(
            id: 2,
            question: "How do I upgrade my subscription?",
            answer: "Go to Settings > Account to view and manage your subscription. You can upgrade to Student or Pro tier directly from the app."
        ),
        FAQItemData(
            id: 3,
            question: "How do I cancel my subscription?",
            answer: "For Apple subscriptions, go to iOS Settings > [Your Name] > Subscriptions. For Stripe subscriptions (web purchases), manage them at matchanote.app/app/settings."
        )
    ]
}

