import SwiftUI

struct CatalogView: View {
    @Environment(ThemeStore.self) private var themeStore
    let viewModel: CatalogViewModel

    private let gridColumns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        let palette = themeStore.palette
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(palette: palette)
                searchAndLayoutRow(palette: palette)
                chipsRow(palette: palette)
                content(palette: palette)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
        .background(palette.bg)
        .navigationDestination(for: Coffee.self) { coffee in
            DetailView(viewModel: DetailViewModel(coffee: coffee))
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func header(palette: Palette) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Collection")
                    .font(.hanken(30, weight: 800))
                    .foregroundStyle(palette.fg)
                Text(viewModel.metaLine)
                    .font(.dmMono(11))
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            Button {
                themeStore.cycle()
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(palette.accent).frame(width: 13, height: 13)
                    Text(themeStore.theme.label)
                        .font(.hanken(12, weight: 600))
                        .foregroundStyle(palette.fg)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(palette.surface, in: Capsule())
                .overlay(Capsule().stroke(palette.line, lineWidth: 1))
            }
        }
    }

    private func searchAndLayoutRow(palette: Palette) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.muted)
                TextField("Search flavor, origin, roaster", text: Bindable(viewModel).query)
                    .font(.hanken(14.5, weight: 500))
                    .foregroundStyle(palette.fg)
            }
            .padding(.horizontal, 13)
            .frame(height: 46)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.line, lineWidth: 1))

            Button {
                viewModel.toggleLayout()
            } label: {
                Image(systemName: viewModel.layout == .grid ? "square.grid.2x2.fill" : "list.bullet")
                    .foregroundStyle(palette.fg)
                    .frame(width: 46, height: 46)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.line, lineWidth: 1))
            }
        }
        .padding(.top, 18)
    }

    private func chipsRow(palette: Palette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.roastFilters, id: \.self) { filter in
                    let active = viewModel.roastFilter == filter
                    Button {
                        viewModel.roastFilter = filter
                    } label: {
                        Text(filter)
                            .font(.hanken(13, weight: 600))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 8)
                            .foregroundStyle(active ? palette.bg : palette.fg)
                            .background(active ? palette.fg : palette.surface, in: Capsule())
                            .overlay(Capsule().stroke(active ? .clear : palette.line, lineWidth: 1))
                    }
                }
            }
        }
        .padding(.top, 14)
    }

    @ViewBuilder
    private func content(palette: Palette) -> some View {
        if viewModel.filtered.isEmpty {
            VStack(spacing: 6) {
                Text("No coffees match")
                    .font(.hanken(15, weight: 600))
                    .foregroundStyle(palette.fg)
                Text("Try a different flavor, origin, or roast.")
                    .font(.hanken(13))
                    .foregroundStyle(palette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else if viewModel.layout == .grid {
            LazyVGrid(columns: gridColumns, spacing: 13) {
                ForEach(viewModel.filtered) { coffee in
                    NavigationLink(value: coffee) {
                        CoffeeGridCard(coffee: coffee, palette: palette)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 18)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.filtered) { coffee in
                    NavigationLink(value: coffee) {
                        CoffeeListRow(coffee: coffee, palette: palette)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 18)
        }
    }
}
