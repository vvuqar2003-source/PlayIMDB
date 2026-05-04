import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let onItemTap: (IMDBItem) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                if let hero = viewModel.heroItem {
                    HeroView(item: hero) {
                        onItemTap(hero)
                    }
                }

                ForEach(viewModel.categories) { category in
                    CategoryRow(category: category, onItemTap: onItemTap)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.black)
    }
}
