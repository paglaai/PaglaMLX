import Foundation
import Observation
import SwiftUI

// MARK: - SettingsManager

/// Singleton ObservableObject that persists all user preferences to UserDefaults.
/// Access via `SettingsManager.shared` everywhere; pass as @EnvironmentObject for view binding.
@MainActor
@Observable final class SettingsManager {

    static let shared = SettingsManager()
    private let defaults = UserDefaults.standard
    
    // MARK: - Types
    
    struct Persona: Codable, Identifiable, Hashable {
        var id = UUID()
        var name: String
        var systemPrompt: String
    }
    
    struct Preset: Codable, Identifiable, Hashable {
        var id = UUID()
        var name: String
        var temp: Double
        var topP: Double
        var topK: Int
        var minP: Double
        var maxTokens: Int
        var chatTemplateArgs: String
    }

    // MARK: Python

    var pythonPath: String {
        didSet { defaults.set(pythonPath, forKey: K.pythonPath) }
    }
    var pythonStatus: PythonStatus = .unchecked

    // MARK: Server Defaults

    var temp: Double {
        didSet { defaults.set(temp, forKey: K.temp) }
    }
    var topP: Double {
        didSet { defaults.set(topP, forKey: K.topP) }
    }
    var topK: Int {
        didSet { defaults.set(topK, forKey: K.topK) }
    }
    var minP: Double {
        didSet { defaults.set(minP, forKey: K.minP) }
    }
    var maxTokens: Int {
        didSet { defaults.set(maxTokens, forKey: K.maxTokens) }
    }
    var logLevel: LogLevel {
        didSet { defaults.set(logLevel.rawValue, forKey: K.logLevel) }
    }
    var trustRemoteCode: Bool {
        didSet { defaults.set(trustRemoteCode, forKey: K.trustRemoteCode) }
    }

    // MARK: Network

    /// Comma-separated allowed origins for CORS, or "*" for any (--allowed-origins)
    var allowedOrigins: String {
        didSet { defaults.set(allowedOrigins, forKey: K.allowedOrigins) }
    }
    /// Bind host for the HTTP server (--host)
    var host: String {
        didSet { defaults.set(host, forKey: K.host) }
    }
    var apiKey: String {
        didSet { defaults.set(apiKey, forKey: K.apiKey) }
    }

    // MARK: BYOK & Cloud

    var openrouterKey: String {
        didSet { defaults.set(openrouterKey, forKey: K.openrouterKey) }
    }
    var anthropicKey: String {
        didSet { defaults.set(anthropicKey, forKey: K.anthropicKey) }
    }
    var openaiKey: String {
        didSet { defaults.set(openaiKey, forKey: K.openaiKey) }
    }
    var geminiKey: String {
        didSet { defaults.set(geminiKey, forKey: K.geminiKey) }
    }
    var groqKey: String {
        didSet { defaults.set(groqKey, forKey: K.groqKey) }
    }
    var togetherKey: String {
        didSet { defaults.set(togetherKey, forKey: K.togetherKey) }
    }
    var freeRouterKey: String {
        didSet { defaults.set(freeRouterKey, forKey: K.freeRouterKey) }
    }
    var freeRouterEnabled: Bool {
        didSet { defaults.set(freeRouterEnabled, forKey: K.freeRouterEnabled) }
    }

    // MARK: KV Cache

    /// Maximum number of in-memory KV cache slots (--prompt-cache-size, 0 = default)
    var promptCacheSize: Int {
        didSet { defaults.set(promptCacheSize, forKey: K.promptCacheSize) }
    }
    /// Maximum KV cache size in bytes (--prompt-cache-bytes, 0 = unlimited)
    var promptCacheBytes: Int {
        didSet { defaults.set(promptCacheBytes, forKey: K.promptCacheBytes) }
    }

    // MARK: System Prompt

    var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: K.systemPrompt) }
    }
    var chatTemplateArgs: String {
        didSet { defaults.set(chatTemplateArgs, forKey: K.chatTemplateArgs) }
    }
    
    var personas: [Persona] {
        didSet {
            if let data = try? JSONEncoder().encode(personas) {
                defaults.set(data, forKey: K.personas)
            }
        }
    }
    
    var presets: [Preset] {
        didSet {
            if let data = try? JSONEncoder().encode(presets) {
                defaults.set(data, forKey: K.presets)
            }
        }
    }

    // MARK: App Behaviour

    var port: Int {
        didSet { defaults.set(port, forKey: K.port) }
    }
    var modelsDirectory: String {
        didSet { defaults.set(modelsDirectory, forKey: K.modelsDirectory) }
    }
    var menuBarMode: Bool {
        didSet {
            defaults.set(menuBarMode, forKey: K.menuBarMode)
            // If menu bar mode turns off, also disable hide-dock-icon
            if !menuBarMode { hideDockIcon = false }
        }
    }
    var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: K.hideDockIcon) }
    }
    var lastSettingsTab: Int {
        didSet { defaults.set(lastSettingsTab, forKey: K.lastSettingsTab) }
    }

    // MARK: Init

    static let defaultModelsDir = "/Volumes/CastingC0UCH/M0DEL/MLX"

    private init() {
        let d = UserDefaults.standard
        pythonPath       = d.string(forKey: K.pythonPath)  ?? ""
        temp             = d.object(forKey: K.temp)        as? Double ?? 0.0
        topP             = d.object(forKey: K.topP)        as? Double ?? 1.0
        topK             = d.object(forKey: K.topK)        as? Int    ?? 0
        minP             = d.object(forKey: K.minP)        as? Double ?? 0.0
        maxTokens        = d.object(forKey: K.maxTokens)   as? Int    ?? 512
        logLevel         = LogLevel(rawValue: d.string(forKey: K.logLevel) ?? "") ?? .info
        trustRemoteCode  = d.bool(forKey: K.trustRemoteCode)
        allowedOrigins   = d.string(forKey: K.allowedOrigins) ?? "*"
        host             = d.string(forKey: K.host) ?? "127.0.0.1"
        
        let existingKey = d.string(forKey: K.apiKey) ?? ""
        if existingKey.isEmpty {
            let newKey = "sk-mlx-" + UUID().uuidString.lowercased()
            d.set(newKey, forKey: K.apiKey)
            apiKey = newKey
        } else {
            apiKey = existingKey
        }

        promptCacheSize  = d.object(forKey: K.promptCacheSize) as? Int ?? 0
        promptCacheBytes = d.object(forKey: K.promptCacheBytes) as? Int ?? 0
        systemPrompt     = d.string(forKey: K.systemPrompt)    ?? ""
        chatTemplateArgs = d.string(forKey: K.chatTemplateArgs) ?? ""
        port             = d.object(forKey: K.port) as? Int  ?? 2525
        modelsDirectory  = d.string(forKey: K.modelsDirectory)  ?? SettingsManager.defaultModelsDir
        menuBarMode      = d.bool(forKey: K.menuBarMode)
        hideDockIcon     = d.bool(forKey: K.hideDockIcon)
        lastSettingsTab  = d.object(forKey: K.lastSettingsTab) as? Int ?? 0

        openrouterKey     = d.string(forKey: K.openrouterKey) ?? ""
        anthropicKey      = d.string(forKey: K.anthropicKey) ?? ""
        openaiKey         = d.string(forKey: K.openaiKey) ?? ""
        geminiKey         = d.string(forKey: K.geminiKey) ?? ""
        groqKey           = d.string(forKey: K.groqKey) ?? ""
        togetherKey       = d.string(forKey: K.togetherKey) ?? ""
        freeRouterKey     = d.string(forKey: K.freeRouterKey) ?? ""
        freeRouterEnabled = d.bool(forKey: K.freeRouterEnabled)
        
        if let data = d.data(forKey: K.personas), let p = try? JSONDecoder().decode([Persona].self, from: data) {
            personas = p
        } else {
            personas = [Persona(name: "Default", systemPrompt: "You are a helpful AI assistant.")]
        }
        
        if let data = d.data(forKey: K.presets), let p = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = p
        } else {
            presets = [
                Preset(name: "Creative", temp: 0.8, topP: 0.9, topK: 40, minP: 0.05, maxTokens: 1024, chatTemplateArgs: ""),
                Preset(name: "Precise", temp: 0.2, topP: 1.0, topK: 0, minP: 0.0, maxTokens: 1024, chatTemplateArgs: ""),
                Preset(name: "ChatML Enforced", temp: 0.7, topP: 1.0, topK: 0, minP: 0.0, maxTokens: 1024, chatTemplateArgs: "{\"chat_template\": \"{% for message in messages %}{{'<|im_start|>' + message['role'] + '\\n' + message['content'] + '<|im_end|>' + '\\n'}}{% endfor %}{% if add_generation_prompt %}{{ '<|im_start|>assistant\\n' }}{% endif %}\"}")
            ]
        }
    }

    // MARK: - Types

    enum PythonStatus: Equatable {
        case unchecked
        case checking
        case valid(String)
        case invalid(String)

        var isChecking: Bool { if case .checking = self { true } else { false } }
        var isValid:    Bool { if case .valid    = self { true } else { false } }

        var description: String {
            switch self {
            case .unchecked:        return "Not verified yet"
            case .checking:         return "Detecting…"
            case .valid(let p):     return p
            case .invalid(let m):   return m
            }
        }
    }

    enum LogLevel: String, CaseIterable, Identifiable {
        case debug   = "DEBUG"
        case info    = "INFO"
        case warning = "WARNING"
        case error   = "ERROR"
        var id: String { rawValue }
    }

    // MARK: - UserDefaults Keys

    private enum K {
        static let pythonPath       = "pythonPath"
        static let temp             = "temp"
        static let topP             = "topP"
        static let topK             = "topK"
        static let minP             = "minP"
        static let maxTokens        = "maxTokens"
        static let logLevel         = "logLevel"
        static let trustRemoteCode  = "trustRemoteCode"
        static let allowedOrigins   = "allowedOrigins"
        static let host             = "host"
        static let apiKey           = "apiKey"
        static let promptCacheSize  = "promptCacheSize"
        static let promptCacheBytes = "promptCacheBytes"
        static let systemPrompt     = "systemPrompt"
        static let chatTemplateArgs = "chatTemplateArgs"
        static let port             = "port"
        static let modelsDirectory  = "modelsDirectory"
        static let menuBarMode      = "menuBarMode"
        static let hideDockIcon     = "hideDockIcon"
        static let lastSettingsTab  = "lastSettingsTab"
        static let openrouterKey    = "openrouterKey"
        static let anthropicKey     = "anthropicKey"
        static let openaiKey        = "openaiKey"
        static let geminiKey        = "geminiKey"
        static let groqKey           = "groqKey"
        static let togetherKey       = "togetherKey"
        static let freeRouterKey     = "freeRouterKey"
        static let freeRouterEnabled = "freeRouterEnabled"
        static let personas         = "personas"
        static let presets          = "presets"
    }
}
