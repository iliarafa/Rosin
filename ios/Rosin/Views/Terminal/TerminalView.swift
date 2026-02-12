import SwiftUI

struct TerminalView: View {
    @EnvironmentObject private var apiKeyManager: APIKeyManager
    @StateObject private var viewModel = TerminalViewModel()

    @State private var showSettings = false
    @State private var showReadme = false
    @State private var showRecommendations = false
    @State private var shareItem: ShareItem?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Scrollable output
            ScrollViewReader { proxy in
                ScrollView {
                    TerminalOutputView(
                        query: viewModel.query,
                        stages: viewModel.stages,
                        summary: viewModel.summary,
                        isProcessing: viewModel.isProcessing,
                        expectedStageCount: viewModel.stageCount,
                        onExportCSV: exportCSV,
                        onExportPDF: exportPDF
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

                HStack(spacing: 14) {
                    Button { showRecommendations = true } label: {
                        Text("[REC]")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                    }
                    Button { showReadme = true } label: {
                        Text("[README]")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                    }
                    Button { showSettings = true } label: {
                        Text("[KEYS]")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(RosinTheme.muted)
                    }
                }
            }

            // Model selectors row
            HStack {
                ForEach(0..<viewModel.stageCount, id: \.self) { index in
                    if index < viewModel.chain.count {
                        Spacer()
                        ModelSelectorView(
                            stageNumber: index + 1,
                            selectedModel: viewModel.chain[index],
                            onModelChange: { viewModel.updateModel(at: index, to: $0) },
                            disabled: viewModel.isProcessing
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
            stages: viewModel.stages
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("verification-\(Int(Date().timeIntervalSince1970)).pdf")
        try? pdfData.write(to: tempURL)
        shareItem = ShareItem(items: [tempURL])
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}
