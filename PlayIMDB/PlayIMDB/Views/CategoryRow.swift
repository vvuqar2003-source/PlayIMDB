import SwiftUI

struct CategoryRow: View {
    let category: ContentCategory
    let onItemTap: (IMDBItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.title)
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(category.items) { item in
                        PosterCard(item: item) {
                            onItemTap(item)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
