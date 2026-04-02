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
    @State private var showAPIKeys = false
    // MARK: - Dropdown state (only one open at a time)
    @State private var showModelPickerForStage: Int?
    @State private var showStagePicker = false
    /// Drives the holographic breathing glow pulse on model pills
    @State private var pillGlowPulse = false
    /// Boot sequence → input transition
    @State private var bootFinished = false
    @FocusState private var queryFocused: Bool

    var body: some View {
        ZStack {
            // ── Main screen ──
            VStack(spacing: 0) {
                header

                if !bootFinished {
                    // Boot sequence plays first, then reveals input
                    BootSequenceView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            bootFinished = true
                        }
                        // Auto-focus the text input after boot
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            queryFocused = true
                        }
                    }
                } else {
                    // ── Full-area text input ──
                    queryInputArea
                }

                Divider()

                // ── EXECUTE button ──
                executeButton

                Divider()

                // ── Bottom navigation bar ──
                BottomNavBar(
                    isLiveResearch: $viewModel.isLiveResearch,
                    isAdversarialMode: $viewModel.isAdversarialMode,
                    onKeysTap: { showAPIKeys = true }
                )
            }
            .overlay {
                if showMenu {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) { dismissAllDropdowns() }
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
            // ── Model picker dropdown (same glass style as [...] menu) ──
            .overlay {
                if let stageIndex = showModelPickerForStage, stageIndex < viewModel.chain.count {
                    let currentModel = viewModel.chain[stageIndex]

                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) { showModelPickerForStage = nil }
                        }

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(LLMProvider.allCases.enumerated()), id: \.element) { providerIdx, provider in
                            // Provider section header
                            Text(provider.displayName)
                                .font(RosinTheme.monoCaption2)
                                .foregroundColor(RosinTheme.muted)
                                .padding(.horizontal, 16)
                                .padding(.top, providerIdx == 0 ? 4 : 2)
                                .padding(.bottom, 4)

                            ForEach(provider.models, id: \.self) { modelName in
                                let isSelected = currentModel.model == modelName && currentModel.provider == provider
                                modelMenuItem(
                                    label: modelName,
                                    isSelected: isSelected
                                ) {
                                    viewModel.updateModel(
                                        at: stageIndex,
                                        to: LLMModel(provider: provider, model: modelName)
                                    )
                                }
                            }

                            if providerIdx < LLMProvider.allCases.count - 1 {
                                menuDivider
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(width: 260)
                    .modifier(LiquidGlassModifier())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 100)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: showModelPickerForStage)
            // ── Stage count picker dropdown ──
            .overlay {
                if showStagePicker {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) { showStagePicker = false }
                        }

                    VStack(alignment: .leading, spacing: 0) {
                        stageCountMenuItem(count: 1)
                        stageCountMenuItem(count: 2)
                        stageCountMenuItem(count: 3)
                    }
                    .padding(.vertical, 8)
                    .frame(width: 160)
                    .modifier(LiquidGlassModifier())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 52)
                    .padding(.leading, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: showStagePicker)
        }
        .background(RosinTheme.background)
        .onAppear {
            viewModel.setup(apiKeyManager: apiKeyManager)
            // Start holographic breathing pulse on model pills
            pillGlowPulse = true
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
        .sheet(isPresented: $showAPIKeys) {
            APIKeysView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                // STAGES: [N] — tap to open stage count picker
                HStack(spacing: 6) {
                    Text("STAGES:")
                        .font(RosinTheme.monoCaption2)
                        .foregroundColor(RosinTheme.muted)

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            dismissAllDropdowns()
                            showStagePicker.toggle()
                        }
                    } label: {
                        Text("\(viewModel.stageCount)")
                            .font(RosinTheme.monoCaption2)
                            .foregroundColor(showStagePicker ? RosinTheme.green : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(
                                Rectangle()
                                    .stroke(
                                        showStagePicker ? RosinTheme.green.opacity(0.5) : Color.primary.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .disabled(viewModel.isProcessing)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            dismissAllDropdowns()
                            showMenu.toggle()
                        }
                    } label: {
                        Text("[···]")
                            .font(RosinTheme.monoCaption)
                            .foregroundColor(showMenu ? RosinTheme.green : RosinTheme.muted)
                    }
                }
            }

            // Row 2: Model pills — tap to open custom dropdown (same style as [...] menu)
            HStack(spacing: 0) {
                ForEach(0..<viewModel.stageCount, id: \.self) { index in
                    if index < viewModel.chain.count {
                        let stageData = viewModel.stages.first { $0.id == index + 1 }
                        let isActive = stageData?.status == .streaming
                        let isOpen = showModelPickerForStage == index
                        let model = viewModel.chain[index]

                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                dismissAllDropdowns()
                                showModelPickerForStage = isOpen ? nil : index
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("[\(index + 1)]")
                                    .font(RosinTheme.monoCaption2)
                                    .foregroundColor(isActive || isOpen ? RosinTheme.green : RosinTheme.green.opacity(0.5))
                                Text(model.provider.shortName)
                                    .font(RosinTheme.monoCaption)
                                    .foregroundColor(isActive || isOpen ? RosinTheme.green : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RosinTheme.green.opacity(
                                    isOpen ? 0.15
                                    : (isActive ? 0.12 : (pillGlowPulse ? 0.04 : 0.02))
                                )
                            )
                            .overlay(
                                Rectangle()
                                    .stroke(
                                        isOpen
                                            ? RosinTheme.green.opacity(0.6)
                                            : (isActive
                                                ? RosinTheme.green.opacity(0.5)
                                                : RosinTheme.green.opacity(pillGlowPulse ? 0.25 : 0.12)),
                                        lineWidth: isOpen ? 1.5 : 1
                                    )
                            )
                            .shadow(
                                color: RosinTheme.green.opacity(
                                    isOpen ? 0.5
                                    : (isActive ? 0.4 : (pillGlowPulse ? 0.20 : 0.08))
                                ),
                                radius: isOpen ? 10 : (isActive ? 8 : (pillGlowPulse ? 8 : 4))
                            )
                            .shadow(
                                color: Color.cyan.opacity(pillGlowPulse ? 0.08 : 0.0),
                                radius: pillGlowPulse ? 12 : 0
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isProcessing)
                    }
                }
            }
            // Subtle breathing scale on all pills
            .scaleEffect(pillGlowPulse ? 1.005 : 0.995)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pillGlowPulse)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Dropdown Helpers

    /// Closes all custom dropdowns (stage picker, model picker, [...] menu)
    private func dismissAllDropdowns() {
        showMenu = false
        showModelPickerForStage = nil
        showStagePicker = false
    }

    /// Stage count picker item — same style as [...] menu items
    private func stageCountMenuItem(count: Int) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { showStagePicker = false }
            viewModel.updateStageCount(count)
        } label: {
            HStack(spacing: 12) {
                Text("\(count) stage\(count == 1 ? "" : "s")")
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(viewModel.stageCount == count ? RosinTheme.green : .primary)
                Spacer()
                if viewModel.stageCount == count {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(RosinTheme.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Model picker item — matches the [...] menu item style with checkmark for selection
    private func modelMenuItem(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { showModelPickerForStage = nil }
            action()
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(isSelected ? RosinTheme.green : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(RosinTheme.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { dismissAllDropdowns() }
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

    // MARK: - Full-Area Query Input

    private var queryInputArea: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder when empty
            if viewModel.query.isEmpty {
                Text("Enter your query...")
                    .font(RosinTheme.monoBody)
                    .foregroundColor(RosinTheme.green.opacity(0.25))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 28)
            }

            TextEditor(text: $viewModel.query)
                .font(RosinTheme.monoBody)
                .scrollContentBackground(.hidden)
                .focused($queryFocused)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RosinTheme.background)
        .onTapGesture { queryFocused = true }
        .transition(.opacity)
    }

    // MARK: - Execute Button

    private var executeButton: some View {
        let isEmpty = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Button {
            queryFocused = false
            viewModel.run()
            withAnimation(.easeOut(duration: 0.25)) { showResults = true }
        } label: {
            (Text("RETURN ").font(.system(.subheadline, design: .monospaced).bold()) + Text("⏎").font(.system(.title3, design: .monospaced)))
                .tracking(3)
                .foregroundColor(isEmpty ? RosinTheme.muted : RosinTheme.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(
                    Rectangle()
                        .stroke(
                            isEmpty ? Color.primary.opacity(0.15) : RosinTheme.green.opacity(0.4),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isEmpty ? .clear : RosinTheme.green.opacity(0.15),
                    radius: isEmpty ? 0 : 8
                )
        }
        .disabled(isEmpty)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
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
