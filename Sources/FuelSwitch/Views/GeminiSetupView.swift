import SwiftUI
import FuelSwitchCore

struct GeminiSetupView: View {
    @Bindable var model: AppModel
    let close: () -> Void

    @State private var clientID = ""
    @State private var clientSecret = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(FuelSwitchTheme.amber)
                    Text(model.t(.geminiSetupTitle))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                }

                Spacer()

                Button(model.t(.done), action: close)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(FuelSwitchTheme.amber.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(FuelSwitchTheme.amber.opacity(0.4), lineWidth: 0.8)
                    )
                    .foregroundStyle(FuelSwitchTheme.amber)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(FuelSwitchTheme.bgPanel)

            Divider().background(FuelSwitchTheme.borderSubtle)

            VStack(alignment: .leading, spacing: 14) {
                Text(model.t(.geminiSetupHelp))
                    .font(.system(size: 10.5))
                    .foregroundStyle(FuelSwitchTheme.textTertiary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.t(.geminiClientIdLabel))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                    TextField("", text: $clientID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.t(.geminiClientSecretLabel))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                    SecureField("", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                }

                Button {
                    model.saveGeminiCredentialsAndConnect(clientID: clientID, clientSecret: clientSecret)
                } label: {
                    Text(model.t(.saveAndConnect))
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(FuelSwitchTheme.amber.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(FuelSwitchTheme.amber.opacity(0.4), lineWidth: 0.8)
                )
                .foregroundStyle(FuelSwitchTheme.amber)
                .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty
                    || clientSecret.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .frame(minHeight: 340)
        .background(FuelSwitchTheme.bgDeep)
        .environment(\.layoutDirection, model.localization.currentLanguage.layoutDirection)
    }
}
