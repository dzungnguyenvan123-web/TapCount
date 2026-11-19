import SwiftUI
import TapCountCore

extension TaskColor {
    var swiftUIColor: Color {
        switch self {
        case .blue: .blue
        case .cyan: .cyan
        case .teal: .teal
        case .green: .green
        case .mint: .mint
        case .yellow: .yellow
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        case .indigo: .indigo
        case .gray: .gray
        }
    }
}

enum IconCatalog {
    static let symbols: [String] = [
        // Hydration & Nutrition
        "drop.fill",
        "cup.and.saucer.fill",
        "mug.fill",
        "fork.knife",
        "carrot.fill",
        "pills.fill",
        // Activity & Wellness
        "figure.walk",
        "figure.run",
        "dumbbell.fill",
        "flame.fill",
        "heart.fill",
        "lungs.fill",
        "bed.double.fill",
        "moon.stars.fill",
        "sun.max.fill",
        // Focus & Work
        "checkmark.circle.fill",
        "laptopcomputer",
        "book.fill",
        "pencil.and.outline",
        "brain.head.profile",
        "timer",
        "phone.fill",
        "envelope.fill",
        "sparkles",
        // Life & Habits
        "leaf.fill",
        "pawprint.fill",
        "cart.fill",
        "house.fill",
        "music.note",
        "camera.fill",
        "star.fill",
        "bolt.fill",
    ]
}

enum DateFormatters {
    static let headerDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    static let compactDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    static let shortDayLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static let tapTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()
}
