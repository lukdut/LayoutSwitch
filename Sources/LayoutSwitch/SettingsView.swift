import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var model: AppModel
    private let accent = Color(red: 0.33, green: 0.30, blue: 0.83)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "keyboard")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(accent.gradient, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("LayoutSwitch").font(.system(size: 23, weight: .semibold))
                    HStack(spacing: 6) {
                        Circle().fill(model.status == .running ? .green : .orange)
                            .frame(width: 7, height: 7)
                        Text(model.status.title).font(.callout).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Toggle("Включено", isOn: Binding(get: { model.settings.enabled }, set: model.setEnabled))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Переключать раскладку")
            }
            .padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !model.hasPermission { permissionSection }
                    if model.status == .secureInput {
                        notice("Защищённый ввод", text: "Переключение временно недоступно. Когда защищённый ввод закончится, LayoutSwitch продолжит работу автоматически.", symbol: "lock.shield")
                    }
                    if model.status == .failed {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Проверьте доступ к мониторингу ввода. После выдачи разрешения macOS может потребовать перезапуск приложения.")
                                Button("Повторить подключение", action: model.retryMonitoring)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                        }
                    }
                    shortcutSection
                    sourcesSection
                    startupSection
                    if let message = model.errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text(message).font(.callout)
                            Spacer()
                            Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel("Закрыть сообщение")
                        }.padding(12).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "hand.raised")
                Text("Работает локально. Набранный текст не читается и не сохраняется.")
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Dev")
                    .monospacedDigit()
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 12)
        }
        .tint(accent)
        .frame(minWidth: 580, minHeight: 590)
    }

    private var permissionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label("Разрешите мониторинг ввода", systemImage: "hand.raised.fill")
                    .font(.headline)
                Text("Он нужен, чтобы сочетание работало в других приложениях. В настройках macOS включите LayoutSwitch в разделе «Конфиденциальность и безопасность → Мониторинг ввода».")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Запросить доступ", action: model.requestPermission).buttonStyle(.borderedProminent)
                    Button("Открыть настройки macOS", action: model.openPrivacySettings)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
    }

    private var shortcutSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(model.settings.shortcuts, id: \.self) { shortcut in
                    HStack(spacing: 10) {
                        Text(shortcut.displayName)
                            .font(.system(size: 23, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("Сочетание")
                            .accessibilityValue(shortcut.displayName)
                        Button("Изменить…") { model.startRecording(replacing: shortcut) }
                            .disabled(model.isRecording)
                        Button { model.removeShortcut(shortcut) } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(model.isRecording || model.settings.shortcuts.count == 1)
                        .help("Удалить сочетание")
                        .accessibilityLabel("Удалить сочетание \(shortcut.displayName)")
                    }
                }
                if model.isRecording {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.recordingShortcut.map { "Замена \($0.displayName)" } ?? "Новое сочетание")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Нажмите сочетание…").font(.headline)
                            Text(model.recordingHint).font(.callout).foregroundStyle(accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Отмена", action: model.cancelRecording)
                    }
                    .padding(12)
                    .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack {
                        Button { model.startRecording() } label: {
                            Label("Добавить сочетание…", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                        Button("Оставить только Ctrl + Shift", action: model.restoreDefaultShortcut)
                            .disabled(model.settings.shortcuts == [.default])
                    }
                }
                if let error = model.shortcutError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.orange)
                }
                if !model.isRecording {
                    Text("Любое из этих сочетаний переключает раскладки по одному и тому же кругу.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("Два или больше модификаторов: Ctrl, Shift, Option, Command. Либо модификатор с одной обычной клавишей. Левые и правые клавиши равнозначны.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text("Срабатывает при отпускании любой клавиши сочетания. Можно удерживать остальные и повторно нажимать и отпускать одну клавишу. Дополнительная клавиша или действие мышью до отпускания отменяют переключение.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if model.settings.shortcuts.contains(where: { $0.keyCode != nil }) {
                        Label("Сочетание также получит активное приложение. Выберите свободное сочетание. Буквы обозначают физические клавиши английской раскладки.", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.padding(8)
        } label: {
            Label("Сочетания клавиш", systemImage: "command").font(.headline)
        }
    }

    private var sourcesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if model.sources.isEmpty {
                    Text("Добавьте раскладки в настройках клавиатуры macOS.").foregroundStyle(.secondary)
                }
                ForEach(model.sources) { source in
                    HStack(spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { model.selectedIDs.contains(source.id) },
                            set: { model.setIncluded(source.id, included: $0) }
                        )) {
                            HStack(spacing: 10) {
                                Text(source.badge).font(.system(size: 10, weight: .semibold))
                                    .frame(width: 30, height: 25)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                                Text(source.name)
                            }
                        }.toggleStyle(.checkbox)
                        Spacer()
                        if model.currentSource?.id == source.id {
                            Text("Активна").font(.caption).foregroundStyle(accent)
                        }
                        if let index = model.selectedIDs.firstIndex(of: source.id) {
                            Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                                .frame(width: 14)
                        }
                    }
                }
                if !model.canSwitch {
                    Label("Выберите хотя бы две раскладки.", systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.orange)
                }
                if model.unavailableSourceCount > 0 {
                    Text("Ранее выбранных раскладок, недоступных в macOS: \(model.unavailableSourceCount).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if model.sources.contains(where: { $0.isInputMethod && model.selectedIDs.contains($0.id) }) {
                    Text("При работе с иероглифическими методами ввода завершайте составление символа перед переключением.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Button("Все раскладки", action: model.useAllSources).disabled(model.usesAllSources)
                    Button("Настройки клавиатуры…", action: model.openKeyboardSettings)
                    Spacer()
                    Button { model.refreshSources() } label: { Image(systemName: "arrow.clockwise") }
                        .help("Обновить список раскладок").accessibilityLabel("Обновить список раскладок")
                }
                Text(model.usesAllSources ? "Новые раскладки macOS будут добавляться автоматически." : "Переключение по кругу в указанном порядке.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(8)
        } label: {
            Label("Раскладки", systemImage: "globe").font(.headline)
        }
    }

    private var startupSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Запускать при входе в macOS", isOn: Binding(get: { model.loginEnabled }, set: model.setLaunchAtLogin))
                    .toggleStyle(.switch)
                if model.loginStatus == .requiresApproval {
                    HStack {
                        Text("Подтвердите автозапуск в настройках macOS.").font(.caption)
                        Button("Открыть", action: model.openLoginSettings)
                    }
                }
                Text("После закрытия этого окна приложение остаётся в строке меню.")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
    }

    private func notice(_ title: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.headline)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
