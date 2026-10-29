import SwiftUI
import LinkPresentation
import UIKit

struct ContentView: View {
    @State private var targetURL = "https://example.com/"
    @State private var isFetching = false
    @State private var metadata: LPLinkMetadata?
    @State private var status = "Ready. Enter the HTTPS page you control that serves the test HEIC as og:image."
    @State private var logText = PersistentLog.read()
    @State private var provider: LPMetadataProvider?

    var body: some View {
        NavigationView {
            Form {
                Section("Safety / scope") {
                    Text("Research-only harness. Use only on a device you own and a test page you control. This app records preview-fetch results; it cannot prove memory corruption by itself.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("Test target") {
                    TextField("https://your-controlled-host/", text: $targetURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Button {
                            fetchPreview()
                        } label: {
                            if isFetching {
                                HStack { ProgressView(); Text("Fetching…") }
                            } else {
                                Text("Fetch Link Preview")
                            }
                        }
                        .disabled(isFetching)

                        if isFetching {
                            Button("Cancel", role: .cancel) { cancelFetch() }
                        }
                    }
                    Text(status)
                        .font(.footnote)
                        .textSelection(.enabled)
                }

                if let metadata {
                    Section("LinkPresentation result") {
                        LinkPreviewRepresentable(metadata: metadata)
                            .frame(minHeight: 140)
                        LabeledContent("Title", value: metadata.title ?? "(none)")
                        LabeledContent("Resolved URL", value: metadata.url?.absoluteString ?? "(none)")
                        LabeledContent("Original URL", value: metadata.originalURL?.absoluteString ?? "(none)")
                    }
                }

                Section("Run log") {
                    Text(logText.isEmpty ? "No log entries yet." : logText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ShareLink(item: logText.isEmpty ? "No log entries." : logText) {
                        Label("Export log", systemImage: "square.and.arrow.up")
                    }
                    Button("Clear log", role: .destructive) {
                        PersistentLog.clear()
                        logText = ""
                        addLog("Log cleared by user")
                    }
                }
            }
            .navigationTitle("CVE-2026-112621 Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onDisappear { provider?.cancel() }
    }

    private func fetchPreview() {
        let trimmed = targetURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.host != nil,
              let url = components.url else {
            status = "Invalid URL. Enter a complete HTTPS URL."
            addLog("Rejected target: URL is not a valid HTTPS URL")
            return
        }

        provider?.cancel()
        metadata = nil
        isFetching = true
        status = "Requesting LinkPresentation metadata…"
        addLog("START metadata fetch: \(url.absoluteString)")

        let newProvider = LPMetadataProvider()
        provider = newProvider
        newProvider.startFetchingMetadata(for: url) { result, error in
            DispatchQueue.main.async {
                self.isFetching = false
                self.provider = nil
                if let error {
                    self.status = "Fetch failed: \(error.localizedDescription)"
                    self.addLog("ERROR metadata fetch: \(error.localizedDescription)")
                }
                if let result {
                    self.metadata = result
                    self.status = "Metadata fetch completed. Rendering the returned preview below. A successful fetch is not proof of a vulnerability; a crash is not proof of exploitability."
                    self.addLog("SUCCESS metadata fetch; title=\(result.title ?? "(none)"); url=\(result.url?.absoluteString ?? "(none)")")
                    self.addLog("Image provider present: \(result.imageProvider != nil)")
                }
                if result == nil && error == nil {
                    self.status = "No metadata and no error were returned."
                    self.addLog("EMPTY metadata result; no error supplied")
                }
            }
        }
    }

    private func cancelFetch() {
        provider?.cancel()
        provider = nil
        isFetching = false
        status = "Request cancelled."
        addLog("CANCEL requested by user")
    }

    private func addLog(_ message: String) {
        logText = PersistentLog.append(message)
    }
}

private struct LinkPreviewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        LPLinkView(metadata: metadata)
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}

private enum PersistentLog {
    private static let fileName = "cve-2026-112621-lab.log"

    private static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }

    static func read() -> String {
        guard let fileURL, let value = try? String(contentsOf: fileURL, encoding: .utf8) else { return "" }
        return value
    }

    @discardableResult
    static func append(_ message: String) -> String {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] \(message)\n"
        guard let fileURL, let data = line.data(using: .utf8) else { return read() + line }
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.synchronize()
                try handle.close()
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            // Keep the in-memory log usable even if persistent storage is unavailable.
        }
        return read()
    }

    static func clear() {
        guard let fileURL else { return }
        try? Data().write(to: fileURL, options: .atomic)
    }
}
