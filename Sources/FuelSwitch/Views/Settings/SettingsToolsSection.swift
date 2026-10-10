import SwiftUI
import AppKit
import FuelSwitchCore

struct SettingsToolsSection: View {
    @ObservedObject var model: AppModel
    @State private var snippetCopied = false

    var body: some View {
        VStack(spacing: 12) {
            launcherCard
            statuslineCard
        }
    }

    private var launcherCard: some View {
        SettingsCard(title: model.t(.launcherTitle), icon: "terminal.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.t(.launcherExplanation))
                    .font(.system(size: 10.5))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    copyShellSnippet()
                } label: {
                    Text(snippetCopied ? model.t(.shellSnippetCopied) : model.t(.copyShellSnippet))
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(FuelSwitchTheme.amber.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(FuelSwitchTheme.amber.opacity(0.35), lineWidth: 0.8))
                .foregroundStyle(FuelSwitchTheme.amber)
                .disabled(model.accounts.isEmpty)
            }
        }
    }

    private var statuslineCard: some View {
        SettingsCard(title: model.t(.statuslineTitle), icon: "chart.bar.doc.horizontal") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    Text(model.t(.statuslineToggle))
                        .font(.system(size: 11))
                        .foregroundStyle(FuelSwitchTheme.textPrimary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 16)
                    Toggle("", isOn: $model.statuslineEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Text(model.t(.statuslineExplanation))
                    .font(.system(size: 10.5))
                    .foregroundStyle(FuelSwitchTheme.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    if model.isStatuslineInstalled {
                        model.uninstallStatusline()
                    } else {
                        model.installStatusline()
                    }
                } label: {
                    Text(model.isStatuslineInstalled ? model.t(.statuslineUninstall) : model.t(.statuslineInstall))
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(FuelSwitchTheme.amber.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(FuelSwitchTheme.amber.opacity(0.35), lineWidth: 0.8))
                .foregroundStyle(FuelSwitchTheme.amber)
            }
        }
    }

    private func copyShellSnippet() {
        let snippet = LauncherScriptGenerator.shellFunction(accounts: model.accounts)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        snippetCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            snippetCopied = false
        }
    }
}
