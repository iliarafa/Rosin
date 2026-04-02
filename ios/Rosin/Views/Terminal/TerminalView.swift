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
    // Two-screen flow: when true, the results page is shown full-screen
    @State private var showResults = false

    var body: some View {
        ZStack {
            // ── Main screen (idle + header + input) ──
            VStack(spacing: 0) {
                header

                ScrollView {
                    EmptyStateView(onQuerySelect: { viewModel.query = $0 })
                }

                VStack(spacing: 0) {
                    Divider()
                    TerminalInputView(
                        query: $viewModel.query,
                        isProcessing: false,
                        onSubmit: {
                            viewModel.run()
                            withAnimation(.easeOut(duration: 0.25)) { showResults = true }
                        },
                        onCancel: {}
                    )
                }
                .background(.ultraThinMaterial)
            }
            .overlay {
                if showMenu {
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
                    .padding(.vertical, 8)
                    .frame(width: 220)
                    .modifier(LiquidGlassModifier())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 52)
                    .padding(.trailing, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: showMenu)
        }
        .background(RosinTheme.background)
        .onAppear {
            viewModel.setup(apiKeyManager: apiKeyManager)
        }
        // ── Results page (clean output-only, full-screen cover) ──
        .fullScreenCover(isPresented: $showResults) {
            ResultsView(
                viewModel: viewModel,
                onDone: {
                    withAnimation(.easeOut(duration: 0.25)) { showResults = false }
                },
                onExportCSV: exportCSV,
                onExportPDF: exportPDF,
                shareItem: $shareItem
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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

    // MARK: - Header (Two spacious rows)

    private var header: some View {
        VStack(spacing: 14) {
            // Row 1: STAGES + toggles + menu
            HStack {
                StageCountSelectorView(
                    value: viewModel.stageCount,
                    onChange: { viewModel.updateStageCount($0) },
                    disabled: viewModel.isProcessing
                )

                Spacer()

                HStack(spacing: 12) {
                    Button { viewModel.isLiveResearch.toggle() } label: {
                        Text("[LIVE]")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(viewModel.isLiveResearch ? RosinTheme.green : RosinTheme.muted)
                    }
                    .disabled(viewModel.isProcessing)

                    Button { viewModel.isAdversarialMode.toggle() } label: {
                        Text("[ADV]")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(viewModel.isAdversarialMode ? RosinTheme.destructive : RosinTheme.muted)
                    }
                    .disabled(viewModel.isProcessing)

                    Button { withAnimation(.easeOut(duration: 0.15)) { showMenu.toggle() } } label: {
                        Text("[···]")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(showMenu ? RosinTheme.green : RosinTheme.muted)
                    }
                }
            }

            // Row 2: Segmented model control (full-width)
            HStack(spacing: 0) {
                ForEach(0..<viewModel.stageCount, id: \.self) { index in
                    if index < viewModel.chain.count {
                        let stageData = viewModel.stages.first { $0.id == index + 1 }
                        let isActive = stageData?.status == .streaming
                        let model = viewModel.chain[index]

                        Menu {
                            ForEach(LLMProvider.allCases) { provider in
                                Section(provider.displayName) {
                                    ForEach(provider.models, id: \.self) { modelName in
                                        Button {
                                            viewModel.updateModel(at: index, to: LLMModel(provider: provider, model: modelName))
                                        } label: {
                                            HStack {
                                                Text(modelName)
                                                if model.model == modelName { Image(systemName: "checkmark") }
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("[\(index + 1)]")
                                    .font(RosinTheme.monoCaption2)
                                    .foregroundColor(isActive ? RosinTheme.green : RosinTheme.muted)
                                Text(model.provider.shortName)
                                    .font(RosinTheme.monoCaption)
                                    .foregroundColor(isActive ? RosinTheme.green : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                isActive
                                    ? RosinTheme.green.opacity(0.1)
                                    : Color.primary.opacity(0.04)
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(
                                        isActive ? RosinTheme.green.opacity(0.4) : Color.primary.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                            // Green glow when streaming
                            .shadow(color: isActive ? RosinTheme.green.opacity(0.25) : .clear, radius: 6)
                        }
                        .disabled(viewModel.isProcessing)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
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
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(width: 18)
                    .foregroundColor(RosinTheme.muted)
                Text(label)
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
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

// MARK: - Results View (clean output-only page)
// Shows only the streaming results with a [CANCEL] button during processing
// and a [DONE] / [NEW QUERY] button when verification completes.

private struct ResultsView: View {
    @ObservedObject var viewModel: TerminalViewModel
    let onDone: () -> Void
    let onExportCSV: () -> Void
    let onExportPDF: () -> Void
    @Binding var shareItem: ShareItem?
    @EnvironmentObject private var fontSizeManager: FontSizeManager

    var body: some View {
        VStack(spacing: 0) {
            // Slim top bar: query + cancel/done
            HStack {
                Text("VERIFYING")
                    .font(RosinTheme.monoCaption)
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.isProcessing ? RosinTheme.green : .primary)

                if viewModel.isProcessing {
                    Text("[RUN]")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.muted)
                        .opacity(0.6)
                }

                Spacer()

                if viewModel.isProcessing {
                    Button {
                        viewModel.cancel()
                        onDone()
                    } label: {
                        Text("[CANCEL]")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(RosinTheme.destructive)
                    }
                } else {
                    Button(action: onDone) {
                        Text("[DONE]")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(RosinTheme.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay(
                                Rectangle()
                                    .stroke(RosinTheme.green.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) { Divider() }

            // Scrollable output — same TerminalOutputView but in clean context
            ScrollViewReader { proxy in
                ScrollView {
                    TerminalOutputView(
                        query: viewModel.query,
                        stages: viewModel.stages,
                        summary: viewModel.summary,
                        isProcessing: viewModel.isProcessing,
                        expectedStageCount: viewModel.stageCount,
                        onExportCSV: onExportCSV,
                        onExportPDF: onExportPDF,
                        onQuerySelect: nil,
                        researchStatus: viewModel.researchStatus
                    )
                    .id("output")
                    Color.clear.frame(height: 1).id("bottom")
                }
                .onChange(of: viewModel.stages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: viewModel.stages.last?.content) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .background(RosinTheme.background)
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
