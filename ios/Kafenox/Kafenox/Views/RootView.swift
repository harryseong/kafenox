import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var themeStore = ThemeStore()
    @State private var settingsStore = SettingsStore.shared
    @State private var catalogViewModel = CatalogViewModel()
    @State private var activeTab: Tab = .catalog
    @State private var catalogPath = NavigationPath()
    @State private var insightsPath = NavigationPath()
    @State private var isScanPresented = false
    @State private var isMenuOpen = false
    @State private var isSettingsPresented = false
    @State private var scanViewModel = ScanViewModel()

    var body: some View {
        let palette = themeStore.palette
        // The tab bar is opaque, so stack it below the content instead of
        // overlaying it -- content (and safe-area-inset composers like Ask
        // AI's) is then genuinely bounded above the bar. A safeAreaInset on
        // this Group doesn't reliably propagate into the NavigationStacks.
        VStack(spacing: 0) {
            Group {
                switch activeTab {
                case .catalog:
                    NavigationStack(path: $catalogPath) {
                        CatalogView(
                            viewModel: catalogViewModel,
                            onMenu: openMenu,
                            onOpen: { catalogPath.append($0) }
                        )
                    }
                case .insights:
                    NavigationStack(path: $insightsPath) {
                        InsightsView(
                            viewModel: InsightsViewModel(catalog: catalogViewModel),
                            onMenu: openMenu
                        )
                    }
                }
            }

            KafenoxTabBar(palette: palette, activeTab: $activeTab) {
                scanViewModel.reset()
                isScanPresented = true
            }
        }
        .overlay {
            if isMenuOpen {
                SideMenuView(
                    palette: palette,
                    onSettings: {
                        isMenuOpen = false
                        isSettingsPresented = true
                    },
                    onClose: { withAnimation(.easeOut(duration: 0.2)) { isMenuOpen = false } }
                )
            }
        }
        .environment(themeStore)
        .onAppear { themeStore.systemIsDark = colorScheme == .dark }
        .onChange(of: colorScheme) { _, scheme in
            themeStore.systemIsDark = scheme == .dark
        }
        .fullScreenCover(isPresented: $isSettingsPresented) {
            SettingsView(settings: settingsStore)
                .environment(themeStore)
        }
        .fullScreenCover(isPresented: $isScanPresented) {
            ScanFlowView(
                viewModel: scanViewModel,
                onAdd: { coffee in
                    isScanPresented = false
                    activeTab = .catalog
                    catalogPath.append(coffee)
                    Task { await catalogViewModel.load() }
                },
                onClose: { isScanPresented = false }
            )
            .environment(themeStore)
        }
    }

    private func openMenu() {
        withAnimation(.easeOut(duration: 0.24)) { isMenuOpen = true }
    }
}
