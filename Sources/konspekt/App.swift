import AppKit
import SwiftUI
import KonspektCore

let agentLabel = "ru.konspekt.agent"
let agentPlist = NSHomeDirectory() + "/Library/LaunchAgents/\(agentLabel).plist"
let agentTarget = "gui/\(getuid())/\(agentLabel)"

@discardableResult
func launchctl(_ args: String...) -> (status: Int32, output: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return (-1, "\(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self))
}

/// Writes the LaunchAgent plist when it is missing or points to another executable
/// (app installed from the release zip instead of scripts/install.sh, or moved).
/// Returns an error message, or nil on success.
func ensureAgentPlist() -> String? {
    guard let exe = Bundle.main.executablePath else { return "Не найден исполняемый файл приложения" }
    if exe.contains("/AppTranslocation/") {
        return "Переместите Konspekt.app в папку Программы и откройте его снова"
    }
    if (NSDictionary(contentsOfFile: agentPlist)?["ProgramArguments"] as? [String])?.first == exe { return nil }
    let log = NSHomeDirectory() + "/Library/Logs/konspekt.log"
    let plist: [String: Any] = [
        "Label": agentLabel,
        "ProgramArguments": [exe, "daemon"],
        "RunAtLoad": true,
        "KeepAlive": true,
        "StandardOutPath": log,
        "StandardErrorPath": log,
        "ProcessType": "Interactive",
    ]
    do {
        let fm = FileManager.default
        try fm.createDirectory(atPath: (agentPlist as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: (log as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: agentPlist), options: .atomic)
        return nil
    } catch {
        return "Не удалось создать LaunchAgent: \(error.localizedDescription)"
    }
}

struct CallRow: Identifiable {
    let session: Session
    let status: SessionStatus
    var id: String { session.name }
}

@MainActor
final class AppModel: ObservableObject {
    let configURL: URL
    @Published var running = false
    @Published var calls: [CallRow] = []
    @Published var folderReadable = true
    @Published var baseURL = ""
    @Published var apiKey = ""
    @Published var asrModel = ""
    @Published var llmModel = ""
    @Published var outputDir = ""
    @Published var models: [String] = []
    @Published var message = ""

    init(configURL: URL) {
        self.configURL = configURL
        let env = Config.parse((try? String(contentsOf: configURL, encoding: .utf8)) ?? "")
        baseURL = env["OPENAI_BASE_URL"] ?? ""
        apiKey = env["OPENAI_API_KEY"] ?? ""
        asrModel = env["OPENAI_MODEL_NAME"] ?? ""
        llmModel = env["SUMMARY_MODEL_NAME"] ?? ""
        outputDir = Config.outputDir(env).path
        refresh()
    }

    func refresh() {
        running = launchctl("print", agentTarget).output.contains("state = running")
        let fm = FileManager.default
        folderReadable = !fm.fileExists(atPath: outputDir) || (try? fm.contentsOfDirectory(atPath: outputDir)) != nil
        calls = SessionStore(root: URL(fileURLWithPath: outputDir)).all().suffix(5).reversed().compactMap { s in
            (try? s.readStatus()).map { CallRow(session: s, status: $0) }
        }
    }

    func toggleDaemon() {
        let r: (status: Int32, output: String)
        if running {
            r = launchctl("bootout", agentTarget)
        } else if launchctl("print", agentTarget).status == 0 {
            r = launchctl("kickstart", agentTarget)
        } else if !FileManager.default.fileExists(atPath: configURL.path) {
            message = "Сначала заполните и сохраните настройки инференса"
            return
        } else if let err = ensureAgentPlist() {
            message = err
            return
        } else {
            r = launchctl("bootstrap", "gui/\(getuid())", agentPlist)
        }
        message = r.status == 0 ? "" : "launchctl: \(r.output)"
        refresh()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: outputDir)
        if panel.runModal() == .OK, let url = panel.url {
            outputDir = url.path
            refresh()
        }
    }

    func loadModels() async {
        guard let url = URL(string: baseURL) else { message = "Неверный адрес API"; return }
        var r = URLRequest(url: url.appendingPathComponent("models"))
        r.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: r)
            let j = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let ids = (j?["data"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
            models = ids.sorted()
            message = ids.isEmpty ? "Список моделей пуст" : "Моделей: \(ids.count)"
        } catch {
            message = "Не удалось получить модели: \(error.localizedDescription)"
        }
    }

    func save() {
        let text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let out = Config.updating(text, with: [
            "OPENAI_BASE_URL": baseURL,
            "OPENAI_API_KEY": apiKey,
            "OPENAI_MODEL_NAME": asrModel,
            "SUMMARY_MODEL_NAME": llmModel,
            "KONSPEKT_DIR": outputDir,
        ])
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(out.utf8).write(to: configURL, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
            if running { launchctl("kickstart", "-k", agentTarget) }
            message = running ? "Сохранено, демон перезапущен" : "Сохранено"
        } catch {
            message = "Ошибка сохранения: \(error.localizedDescription)"
        }
        refresh()
    }
}

struct ModelField: View {
    let title: String
    @Binding var value: String
    let models: [String]
    var placeholder = ""
    var body: some View {
        HStack {
            TextField(title, text: $value, prompt: Text(placeholder))
            Menu("Выбрать") {
                ForEach(models, id: \.self) { m in Button(m) { value = m } }
            }
            .disabled(models.isEmpty)
            .fixedSize()
        }
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    static let stateNames: [SessionState: String] = [
        .recording: "идет запись", .recorded: "ожидает обработки", .transcribed: "расшифровано", .done: "готово",
    ]

    var body: some View {
        Form {
            Section("Демон") {
                HStack {
                    Circle().fill(model.running ? .green : .secondary).frame(width: 8, height: 8)
                    Text(model.running ? "Работает" : "Остановлен")
                    Spacer()
                    Button(model.running ? "Остановить" : "Запустить") { model.toggleDaemon() }
                }
            }
            Section("Последние звонки") {
                if !model.folderReadable {
                    Text("Нет доступа к папке записей").foregroundStyle(.red)
                } else if model.calls.isEmpty {
                    Text("Звонков пока нет").foregroundStyle(.secondary)
                }
                ForEach(model.calls) { c in
                    HStack {
                        Text(c.session.name).monospacedDigit()
                        Spacer()
                        Text(c.status.lastError == nil ? Self.stateNames[c.status.state] ?? "" : "ошибка")
                            .foregroundStyle(c.status.lastError == nil ? Color.secondary : Color.red)
                            .help(c.status.lastError ?? "")
                        Button("Открыть") { NSWorkspace.shared.open(c.session.dir) }
                    }
                }
            }
            Section("Папка с транскрипциями") {
                HStack {
                    Text(model.outputDir).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Изменить...") { model.chooseFolder() }
                    Button("Открыть") { NSWorkspace.shared.open(URL(fileURLWithPath: model.outputDir)) }
                }
            }
            Section("Инференс") {
                TextField("Адрес API", text: $model.baseURL)
                SecureField("Ключ API", text: $model.apiKey)
                ModelField(title: "Модель ASR", value: $model.asrModel, models: model.models)
                ModelField(title: "Модель LLM", value: $model.llmModel, models: model.models, placeholder: "qwen-3.8-27b")
                HStack {
                    Button("Загрузить модели") { Task { await model.loadModels() } }
                    Spacer()
                    Button("Сохранить") { model.save() }.keyboardShortcut("s")
                }
            }
            if !model.message.isEmpty {
                Text(model.message).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 720)
        .onReceive(timer) { _ in model.refresh() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

struct KonspektApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var model = AppModel(configURL: URL(fileURLWithPath: configPath))
    var body: some Scene {
        WindowGroup("Konspekt") { MainView(model: model) }
    }
}
