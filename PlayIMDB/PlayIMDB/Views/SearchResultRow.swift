import SwiftUI

struct SearchResultRow: View {
    let item: IMDBItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: item.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.bold())
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let year = item.year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    if let typeText = item.typeText {
                        Text(typeText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
