import SwiftUI

struct RootView: View {
    @State private var themeStore = ThemeStore()
    @State private var catalogViewModel = CatalogViewModel()
    @State private var activeTab: Tab = .catalog
    @State private var catalogPath = NavigationPath()
    @State private var mapPath = NavigationPath()
    @State private var isScanPresented = false
    @State private var scanViewModel = ScanViewModel()

    var body: some View {
        let palette = themeStore.palette
        ZStack(alignment: .bottom) {
            Group {
                switch activeTab {
                case .catalog:
                    NavigationStack(path: $catalogPath) {
                        CatalogView(viewModel: catalogViewModel)
                    }
                case .map:
                    NavigationStack(path: $mapPath) {
                        OriginsMapView(viewModel: MapViewModel(catalog: catalogViewModel))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 88)
            }

            KafenoxTabBar(palette: palette, activeTab: $activeTab) {
                scanViewModel.reset()
                isScanPresented = true
            }
        }
        .environment(themeStore)
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
}
