import SwiftUI

struct StageBlockView: View {
    let stage: StageOutput

    @EnvironmentObject private var fontSizeManager: FontSizeManager
    @State private var cursorVisible = true

    private var responseFont: Font {
        RosinTheme.responseFont(for: fontSizeManager.sizeCategory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Stage header
            HStack(spacing: 6) {
                Text(">")
                    .foregroundColor(RosinTheme.muted)
                Text("STAGE [\(stage.stage)]:")
                    .fontWeight(.medium)
                Text("\(stage.model.provider.displayName) / \(stage.model.model)")
                    .foregroundColor(RosinTheme.muted)
                StatusIndicator(status: stage.status)
            }
            .font(RosinTheme.monoCaption)

            // Content
            HStack(alignment: .bottom, spacing: 0) {
                Text(stage.content)
                    .font(responseFont)
                    .lineSpacing(fontSizeManager.sizeCategory.lineSpacing)
                    .textSelection(.enabled)

                if stage.status == .streaming {
                    Text("_")
                        .font(responseFont)
                        .foregroundColor(RosinTheme.muted)
                        .opacity(cursorVisible ? 1 : 0)
                        .onAppear {
                            withAnimation(RosinTheme.pulseAnimation) {
                                cursorVisible.toggle()
                            }
                        }
                }
            }

            // Error message
            if let error = stage.error {
                Text("ERROR: \(error)")
                    .font(RosinTheme.monoCaption)
                    .foregroundColor(RosinTheme.destructive)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            stage.status == .streaming
                ? Color.primary.opacity(0.03)
                : Color.clear
        )
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }
}
