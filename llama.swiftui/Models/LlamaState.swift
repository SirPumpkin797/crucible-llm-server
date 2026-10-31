import Foundation

struct Model: Identifiable {
    var id = UUID()
    var name: String
    var url: String
    var filename: String
    var status: String?
}

@MainActor
class LlamaState: ObservableObject {
    @Published var messageLog = ""
    @Published var cacheCleared = false
    @Published var downloadedModels: [Model] = []
    @Published var undownloadedModels: [Model] = []
    let NS_PER_S = 1_000_000_000.0

    @Published var serverRunning = false
    @Published var serverAddress = ""
    let httpServer = HTTPServer(port: 8080)

    private var llamaContext: LlamaContext?
    private var inferenceBusy = false
    private var activeModelFilename = ""
    private var defaultModelUrl: URL? {
        Bundle.main.url(forResource: "ggml-model", withExtension: "gguf", subdirectory: "models")
        // Bundle.main.url(forResource: "llama-2-7b-chat", withExtension: "Q2_K.gguf", subdirectory: "models")
    }

    init() {
        loadModelsFromDisk()
        loadDefaultModels()
    }

    private func loadModelsFromDisk() {
        do {
            let documentsURL = getDocumentsDirectory()
            let modelURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            for modelURL in modelURLs {
                let modelName = modelURL.deletingPathExtension().lastPathComponent
                downloadedModels.append(Model(name: modelName, url: "", filename: modelURL.lastPathComponent, status: "downloaded"))
            }
        } catch {
            print("Error loading models from disk: \(error)")
        }
    }

    private func loadDefaultModels() {
        do {
            try loadModel(modelUrl: defaultModelUrl)
        } catch {
            messageLog += "Error!\n"
        }

        for model in defaultModels {
            let fileURL = getDocumentsDirectory().appendingPathComponent(model.filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {

            } else {
                var undownloadedModel = model
                undownloadedModel.status = "download"
                undownloadedModels.append(undownloadedModel)
            }
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    private let defaultModels: [Model] = [
        Model(
            name: "Gemma-3-4B-IT (Q4_K_M, 2.9 GiB)",
            url: "https://huggingface.co/bartowski/google_gemma-3-4b-it-GGUF/resolve/main/google_gemma-3-4b-it-Q4_K_M.gguf?download=true",
            filename: "gemma-3-4b-it-Q4_K_M.gguf", status: "download"
        ),
        Model(
            name: "Qwen-3.5-4B (Q4_K_M, 2.7 GiB)",
            url: "https://huggingface.co/bartowski/Qwen_Qwen3.5-4B-GGUF/resolve/main/Qwen_Qwen3.5-4B-Q4_K_M.gguf?download=true",
            filename: "qwen3.5-4b-Q4_K_M.gguf", status: "download"
        ),
        Model(name: "TinyLlama-1.1B (Q4_0, 0.6 GiB)",url: "https://huggingface.co/TheBloke/TinyLlama-1.1B-1T-OpenOrca-GGUF/resolve/main/tinyllama-1.1b-1t-openorca.Q4_0.gguf?download=true",filename: "tinyllama-1.1b-1t-openorca.Q4_0.gguf", status: "download"),
        Model(
            name: "TinyLlama-1.1B Chat (Q8_0, 1.1 GiB)",
            url: "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q8_0.gguf?download=true",
            filename: "tinyllama-1.1b-chat-v1.0.Q8_0.gguf", status: "download"
        ),

        Model(
            name: "TinyLlama-1.1B (F16, 2.2 GiB)",
            url: "https://huggingface.co/ggml-org/models/resolve/main/tinyllama-1.1b/ggml-model-f16.gguf?download=true",
            filename: "tinyllama-1.1b-f16.gguf", status: "download"
        ),

        Model(
            name: "Phi-2.7B (Q4_0, 1.6 GiB)",
            url: "https://huggingface.co/ggml-org/models/resolve/main/phi-2/ggml-model-q4_0.gguf?download=true",
            filename: "phi-2-q4_0.gguf", status: "download"
        ),

        Model(
            name: "Phi-2.7B (Q8_0, 2.8 GiB)",
            url: "https://huggingface.co/ggml-org/models/resolve/main/phi-2/ggml-model-q8_0.gguf?download=true",
            filename: "phi-2-q8_0.gguf", status: "download"
        ),

        Model(
            name: "Mistral-7B-v0.1 (Q4_0, 3.8 GiB)",
            url: "https://huggingface.co/TheBloke/Mistral-7B-v0.1-GGUF/resolve/main/mistral-7b-v0.1.Q4_0.gguf?download=true",
            filename: "mistral-7b-v0.1.Q4_0.gguf", status: "download"
        ),
        Model(
            name: "OpenHermes-2.5-Mistral-7B (Q3_K_M, 3.52 GiB)",
            url: "https://huggingface.co/TheBloke/OpenHermes-2.5-Mistral-7B-GGUF/resolve/main/openhermes-2.5-mistral-7b.Q3_K_M.gguf?download=true",
            filename: "openhermes-2.5-mistral-7b.Q3_K_M.gguf", status: "download"
        )
    ]
    func loadModel(modelUrl: URL?) throws {
        guard !inferenceBusy else {
            messageLog += "Model is busy; wait for generation to finish\n"
            return
        }
        if let modelUrl {
            messageLog += "Loading model...\n"
            llamaContext = try LlamaContext.create_context(path: modelUrl.path())
            activeModelFilename = modelUrl.lastPathComponent.lowercased()
            messageLog += "Loaded model \(modelUrl.lastPathComponent)\n"

            // Assuming that the model is successfully loaded, update the downloaded models
            updateDownloadedModels(modelName: modelUrl.lastPathComponent, status: "downloaded")
        } else {
            messageLog += "Load a model from the list below\n"
        }
    }


    private func updateDownloadedModels(modelName: String, status: String) {
        undownloadedModels.removeAll { $0.name == modelName }
    }


    private func chatPrompt(_ text: String) -> String {
        // Use the instruction format expected by each supported model family.
        if activeModelFilename.contains("tinyllama") {
            if activeModelFilename.contains("openorca") {
                return "<|im_start|>user\n\(text)<|im_end|>\n<|im_start|>assistant\n"
            }
            return "<s>[INST] \(text) [/INST]"
        }
        // Qwen2.5 and other ChatML-compatible instruct models.
        return "<|im_start|>user\n\(text)<|im_end|>\n<|im_start|>assistant\n"
    }

    func complete(text: String) async {
        guard !inferenceBusy, llamaContext != nil else {
            messageLog += "Inference already in progress or no model loaded\n"
            return
        }
        inferenceBusy = true
        defer { inferenceBusy = false }
        let started = DispatchTime.now().uptimeNanoseconds
        let response = await runCompletion(text: text, maxTokens: 128)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / NS_PER_S
        messageLog += "\nUser: \(text)\nAssistant: \(response)\nElapsed: \(String(format: "%.2f", elapsed))s\n"
    }

    private func runCompletion(text: String, maxTokens: Int) async -> String {
        guard let llamaContext else { return "Error: No model loaded" }
        let prompt = text.contains("<|im_start|>") ? text : chatPrompt(text)
        await llamaContext.completion_init(text: prompt)
        var output = ""
        var generated = 0
        let limit = min(max(1, maxTokens), 256)
        while await !llamaContext.is_done && generated < limit {
            let piece = await llamaContext.completion_loop()
            output += piece
            generated += 1
        }
        await llamaContext.clear()
        if let end = output.range(of: "<|im_end|>") {
            output = String(output[..<end.lowerBound])
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func bench() async {
        guard !inferenceBusy, let llamaContext else { return }
        inferenceBusy = true
        defer { inferenceBusy = false }
        messageLog += "\n"
        messageLog += "Running benchmark...\n"
        messageLog += "Model info: "
        messageLog += await llamaContext.model_info() + "\n"

        let t_start = DispatchTime.now().uptimeNanoseconds
        let _ = await llamaContext.bench(pp: 8, tg: 4, pl: 1) // heat up
        let t_end = DispatchTime.now().uptimeNanoseconds

        let t_heat = Double(t_end - t_start) / NS_PER_S
        messageLog += "Heat up time: \(t_heat) seconds, please wait...\n"

        // if more than 5 seconds, then we're probably running on a slow device
        if t_heat > 5.0 {
            messageLog += "Heat up time is too long, aborting benchmark\n"
            return
        }

        let result = await llamaContext.bench(pp: 512, tg: 128, pl: 1, nr: 3)

        messageLog += "\(result)"
        messageLog += "\n"
    }

    func clear() async {
        guard !inferenceBusy, let llamaContext else {
            return
        }

        await llamaContext.clear()
        messageLog = ""
    }

    // MARK: - HTTP Server

    func toggleServer() {
        if serverRunning {
            httpServer.stop()
            serverRunning = false
            serverAddress = ""
            messageLog += "Server stopped\n"
        } else {
            do {
                try httpServer.start(llamaState: self)
                serverRunning = true
                let ip = httpServer.getLocalIP()
                serverAddress = "http://\(ip):8080"
                messageLog += "Server started at \(serverAddress)\n"
            } catch {
                messageLog += "Failed to start server: \(error)\n"
            }
        }
    }

    // Non-streaming completion for API use
    func completeForAPI(text: String, maxTokens: Int = 128) async -> String {
        guard !inferenceBusy, llamaContext != nil else {
            return "Error: Model busy or not loaded"
        }
        inferenceBusy = true
        defer { inferenceBusy = false }
        return await runCompletion(text: text, maxTokens: maxTokens)
    }
}
