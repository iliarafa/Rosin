import SwiftUI

struct TerminalView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @StateObject private var viewModel = TerminalViewModel()

    @State private var showSettings = false
    @State private var showReadme = false
    @State private var showRecommendations = false
    @State private var showHistory = false
    @State private var showStats = false
    @State private var shareItem: ShareItem?
    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Scrollable output with subtle CRT scanlines
            ScrollViewReader { proxy in
                ScrollView {
                    TerminalOutputView(
                        query: viewModel.query,
                        stages: viewModel.stages,
                        summary: viewModel.summary,
                        isProcessing: viewModel.isProcessing,
                        expectedStageCount: viewModel.stageCount,
                        onExportCSV: exportCSV,
                        onExportPDF: exportPDF,
                        onQuerySelect: { viewModel.query = $0 },
                        researchStatus: viewModel.researchStatus
                    )
                    .id("output")

                    // Scroll anchor
                    Color.clear.frame(height: 1).id("bottom")
                }
                .onChange(of: viewModel.stages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.stages.last?.content) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }

            // Footer input
            VStack(spacing: 0) {
                Divider()
                TerminalInputView(
                    query: $viewModel.query,
                    isProcessing: viewModel.isProcessing,
                    onSubmit: viewModel.run,
                    onCancel: viewModel.cancel
                )
            }
            .background(.ultraThinMaterial)
        }
        .overlay {
            if showMenu {
                // Dismiss backdrop
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) { showMenu = false }
                    }

                // Dropdown menu
                VStack(alignment: .leading, spacing: 0) {
                    menuItem(icon: "clock", label: "History") { showHistory = true }
                    menuItem(icon: "chart.bar", label: "Stats") { showStats = true }
                    menuDivider
                    menuItem(icon: "lightbulb", label: "Recommendations") { showRecommendations = true }
                    menuItem(icon: "doc.text", label: "Readme") { showReadme = true }
                    menuItem(icon: "gearshape", label: "Settings") { showSettings = true }
                    menuDivider
                    menuItem(
                        icon: appearanceManager.isDark(currentScheme: colorScheme) ? "moon" : "sun.max",
                        label: appearanceManager.isDark(currentScheme: colorScheme) ? "Theme: Dark" : "Theme: Light"
                    ) {
                        appearanceManager.toggle(currentScheme: colorScheme)
                    }
                }
                .padding(.vertical, 6)
                .frame(width: 180)
                .modifier(LiquidGlassModifier())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 52)
                .padding(.trailing, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: showMenu)
        .background(RosinTheme.background)
        .onAppear {
            viewModel.setup(apiKeyManager: apiKeyManager)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showReadme) {
            ReadmeView()
        }
        .sheet(isPresented: $showRecommendations) {
            RecommendationsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .sheet(isPresented: $showStats) {
            DisagreementStatsView()
        }
        .sheet(item: $shareItem) { item in
            ShareSheetRepresentable(items: item.items)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            // Top row: stage selector, nav buttons
            HStack {
                StageCountSelectorView(
                    value: viewModel.stageCount,
                    onChange: { viewModel.updateStageCount($0) },
                    disabled: viewModel.isProcessing
                )

                Spacer()

                Button { viewModel.isLiveResearch.toggle() } label: {
                    Text("[LIVE]")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(viewModel.isLiveResearch ? RosinTheme.green : RosinTheme.muted)
                }
                .disabled(viewModel.isProcessing)

                Button { viewModel.isAdversarialMode.toggle() } label: {
                    Text("[ADV]")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(viewModel.isAdversarialMode ? RosinTheme.destructive : RosinTheme.muted)
                }
                .disabled(viewModel.isProcessing)

                Button { withAnimation(.easeOut(duration: 0.15)) { showMenu.toggle() } } label: {
                    Text("[···]")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(showMenu ? RosinTheme.green : RosinTheme.muted)
                }
            }

            // Model selectors row
            HStack {
                ForEach(0..<viewModel.stageCount, id: \.self) { index in
                    if index < viewModel.chain.count {
                        // Highlight the model pill for the currently streaming stage
                        let stageData = viewModel.stages.first { $0.id == index + 1 }
                        let isActive = stageData?.status == .streaming
                        Spacer()
                        ModelSelectorView(
                            stageNumber: index + 1,
                            selectedModel: viewModel.chain[index],
                            onModelChange: { viewModel.updateModel(at: index, to: $0) },
                            disabled: viewModel.isProcessing,
                            isActive: isActive
                        )
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Menu Helpers

    private func menuItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { showMenu = false }
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 16)
                    .foregroundColor(RosinTheme.muted)
                Text(label)
                    .font(RosinTheme.monoCaption2)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
    }

    // MARK: - Export

    private func exportCSV() {
        let csv = ExportService.generateCSV(
            query: viewModel.query,
            stages: viewModel.stages
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("verification-\(Int(Date().timeIntervalSince1970)).csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        shareItem = ShareItem(items: [tempURL])
    }

    private func exportPDF() {
        let pdfData = ExportService.generatePDF(
            query: viewModel.query,
            stages: viewModel.stages,
            summary: viewModel.summary
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rosin-report-\(Int(Date().timeIntervalSince1970)).pdf")
        try? pdfData.write(to: tempURL)
        shareItem = ShareItem(items: [tempURL])
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct LiquidGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
