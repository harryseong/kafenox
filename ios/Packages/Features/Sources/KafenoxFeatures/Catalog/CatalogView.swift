import KafenoxCore
import KafenoxDesignSystem
import KafenoxNetworking
import SwiftUI

public struct CatalogView: View {
    @Environment(ThemeStore.self) private var themeStore
    let viewModel: CatalogViewModel
    var onMenu: () -> Void = {}
    /// Pushes a coffee's detail screen; provided by RootView, which owns
    /// the catalog NavigationPath (the swipeable list rows can't use
    /// NavigationLink -- see SwipeableCoffeeRow).
    var onOpen: (Coffee) -> Void = { _ in }

    public init(
        viewModel: CatalogViewModel,
        onMenu: @escaping () -> Void = {},
        onOpen: @escaping (Coffee) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onMenu = onMenu
        self.onOpen = onOpen
    }

    @State private var isScrolled = false
    /// photoId of the list row whose swipe actions are currently revealed.
    @State private var swipeOpenId: String?
    @State private var editingCoffee: Coffee?
    @State private var deletingCoffee: Coffee?
    @State private var isDeleting = false
    @State private var deleteError: String?

    private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    public var body: some View {
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
            .padding(.bottom, 40)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 52
        } action: { _, scrolled in
            withAnimation(.easeOut(duration: 0.18)) { isScrolled = scrolled }
        }
        .overlay(alignment: .top) {
            CompactHeaderBar(title: "Collection", visible: isScrolled, palette: palette)
        }
        .background(palette.bg)
        .navigationDestination(for: Coffee.self) { coffee in
            DetailView(viewModel: DetailViewModel(coffee: coffee, catalog: viewModel))
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(item: $editingCoffee) { coffee in
            EditCoffeeView(coffee: coffee) { updated in
                if let idx = viewModel.coffees.firstIndex(where: { $0.photoId == updated.photoId }) {
                    viewModel.coffees[idx] = updated
                }
            }
            .environment(themeStore)
        }
        .overlay {
            if deletingCoffee != nil {
                DeleteConfirmationView(
                    palette: palette,
                    isDeleting: isDeleting,
                    errorMessage: deleteError,
                    onCancel: { deletingCoffee = nil },
                    onDelete: { Task { await performDelete() } }
                )
            }
        }
    }

    @MainActor
    private func performDelete() async {
        guard let coffee = deletingCoffee else { return }
        isDeleting = true
        deleteError = nil
        do {
            try await APIClient.shared.deleteCoffee(photoId: coffee.photoId)
            viewModel.coffees.removeAll { $0.photoId == coffee.photoId }
            isDeleting = false
            deletingCoffee = nil
        } catch {
            isDeleting = false
            deleteError = "Couldn't delete — try again."
        }
    }

    private func header(palette: Palette) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Collection")
                    .font(.app(32, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(palette.fg)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(viewModel.metaLine)
                    .font(.app(13, weight: .medium))
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            MenuButton(palette: palette, action: onMenu)
                .padding(.top, 3)
        }
    }

    private func searchAndLayoutRow(palette: Palette) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.muted)
                    .accessibilityHidden(true)
                TextField("Search flavor, origin, roaster", text: Bindable(viewModel).query)
                    .font(.app(14))
                    .foregroundStyle(palette.fg)
            }
            .padding(.horizontal, 13)
            .frame(height: 40)
            .background(palette.surface2, in: RoundedRectangle(cornerRadius: 12))

            Button {
                viewModel.toggleLayout()
            } label: {
                Image(systemName: viewModel.layout == .grid ? "square.grid.2x2.fill" : "list.bullet")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.fg)
                    .frame(width: 40, height: 40)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.layout == .grid ? "Switch to list layout" : "Switch to grid layout")
        }
        .padding(.top, 18)
    }

    private func chipsRow(palette: Palette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(viewModel.roastFilters, id: \.self) { filter in
                    let active = viewModel.roastFilter == filter
                    Button {
                        viewModel.roastFilter = filter
                    } label: {
                        Text(filter)
                            .font(.app(13, weight: .semibold))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 7)
                            .foregroundStyle(active ? palette.bg : palette.muted)
                            .background(active ? palette.fg : palette.surface2, in: Capsule())
                    }
                    .buttonStyle(.plain)
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
                    .font(.app(15, weight: .semibold))
                    .foregroundStyle(palette.fg)
                Text("Try a different flavor, origin, or roast.")
                    .font(.app(13))
                    .foregroundStyle(palette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else if viewModel.layout == .grid {
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(viewModel.filtered) { coffee in
                    NavigationLink(value: coffee) {
                        CoffeeGridCard(coffee: coffee, palette: palette)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 18)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filtered) { coffee in
                    SwipeableCoffeeRow(
                        coffee: coffee,
                        palette: palette,
                        openId: $swipeOpenId,
                        onOpen: { onOpen(coffee) },
                        onEdit: { editingCoffee = coffee },
                        onDelete: {
                            deleteError = nil
                            deletingCoffee = coffee
                        }
                    )
                }
            }
            .padding(.top, 8)
        }
    }
}
