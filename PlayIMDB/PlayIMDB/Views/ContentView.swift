import SwiftUI

struct ContentView: View {
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var searchViewModel = SearchViewModel()
    @State private var selectedItem: IMDBItem?

    var body: some View {
        NavigationStack {
            Group {
                if searchViewModel.query.isEmpty {
                    HomeView(viewModel: homeViewModel, onItemTap: { item in
                        selectedItem = item
                    })
                } else {
                    ScrollView {
                        if searchViewModel.isSearching {
                            ProgressView()
                                .tint(.white)
                                .padding(.top, 40)
                        } else if searchViewModel.results.isEmpty && searchViewModel.query.count >= 2 {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("Sonuc bulunamadi")
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(searchViewModel.results) { item in
                                    SearchResultRow(item: item) {
                                        selectedItem = item
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .background(Color.black)
                }
            }
            .navigationTitle("PlayIMDB")
            .searchable(text: $searchViewModel.query, prompt: "Film veya dizi ara...")
            .onChange(of: searchViewModel.query) { _ in
                searchViewModel.searchTextChanged()
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .task {
                await homeViewModel.loadContent()
            }
            .navigationDestination(item: $selectedItem) { item in
                PlayerView(item: item)
            }
        }
    }
}
