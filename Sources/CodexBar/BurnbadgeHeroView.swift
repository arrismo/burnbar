import SwiftUI

struct BurnbadgeHeroView: View {
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                self.badgeMark

                VStack(alignment: .leading, spacing: 3) {
                    Text("Burnbadge")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
                    Text("Turn your AI usage into a shareable badge.")
                        .font(.caption)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Label("Generate", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.orange))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: self.width, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(self.isHighlighted ? 0.48 : 0.28),
                            Color(red: 0.14, green: 0.08, blue: 0.04).opacity(self.isHighlighted ? 0.72 : 0.50),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orange.opacity(self.isHighlighted ? 0.70 : 0.42), lineWidth: 1)
        }
    }

    private var badgeMark: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(self.isHighlighted ? 0.30 : 0.20))
            Image(systemName: "flame.fill")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, Color(red: 1.0, green: 0.78, blue: 0.28)],
                        startPoint: .top,
                        endPoint: .bottom))
        }
        .frame(width: 48, height: 48)
    }
}
