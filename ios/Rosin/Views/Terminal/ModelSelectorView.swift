import SwiftUI

struct ModelSelectorView: View {
    let stageNumber: Int
    let selectedModel: LLMModel
    let onModelChange: (LLMModel) -> Void
    let disabled: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("[\(stageNumber)]")
                .font(RosinTheme.monoCaption2)
                .foregroundColor(RosinTheme.muted.opacity(0.8))

            Menu {
                ForEach(LLMProvider.allCases) { provider in
                    Section(provider.displayName) {
                        ForEach(provider.models, id: \.self) { model in
                            Button {
                                onModelChange(LLMModel(provider: provider, model: model))
                            } label: {
                                HStack {
                                    Text(model)
                                    if selectedModel.provider == provider && selectedModel.model == model {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                Text(selectedModel.model)
                    .font(RosinTheme.monoCaption2)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Rectangle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            }
            .disabled(disabled)
        }
    }
}
