import SwiftUI

struct PosterCard: View {
    let item: IMDBItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder
                case .empty:
                    placeholder
                        .overlay(ProgressView().tint(.white))
                @unknown default:
                    placeholder
                }
            }
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .white.opacity(0.1), radius: 8)
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 120, height: 180)
    }
}
