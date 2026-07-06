//
//  TemplatesService.swift
//  Owns templates in memory, persists locally, and (later) syncs with backend.
//  - Stays @MainActor for UI safety
//  - Moves I/O off the main thread with Task.detached
//  - Persists activeTemplateID in UserDefaults
//

import Foundation
import Combine

@MainActor
final class TemplatesService: ObservableObject {
    @Published private(set) var templates: [ScentsTemplate] = []
    @Published private(set) var activeTemplateID: UUID?

    private let local: TemplatesRepository
    var remote: RemoteAPI? // future

    // Key for persisting active selection
    private let activeKey = "templates_active_id_v1"

    // MARK: - Init (Load Path UX)
    init(local: TemplatesRepository? = nil) {
        self.local = local ?? LocalTemplatesRepository()

        // Load templates + restore active id asynchronously.
        // The repository handles background work; we hop back to the main actor to publish.
        let repo = self.local
        Task {
            let loaded = await repo.loadAll()
            await MainActor.run {
                self.templates = loaded

                if let s = UserDefaults.standard.string(forKey: self.activeKey),
                   let restored = UUID(uuidString: s) {
                    self.activeTemplateID = restored
                } else {
                    self.activeTemplateID = loaded.first?.id
                }
            }
        }
    }

    /// Loads templates from local storage into memory (off the main thread).
    func load() async {
        let list = await local.loadAll()
        self.templates = list
        if let id = self.activeTemplateID,
           list.first(where: { $0.id == id }) == nil {
            self.activeTemplateID = nil
            self.persistActiveID()
        }
    }

    /// Returns the currently active template, if any.
    var activeTemplate: ScentsTemplate? {
        guard let id = activeTemplateID else { return nil }
        return templates.first { $0.id == id }
    }

    /// Sets the active template ID and persists state locally.
    func setActiveTemplateID(_ id: UUID?) {
        activeTemplateID = id
        persistActiveID()
    }

    /// Adds a new template, persists, and (optionally) sets it active.
    func add(_ t: ScentsTemplate, setActive: Bool = true) {
        templates.append(t)
        if setActive { activeTemplateID = t.id; persistActiveID() }
        persistTemplates()
    }

    /// Imports a downloaded template into My Templates, replacing the catalog copy if it already exists.
    func importDownloaded(_ template: ScentsTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        persistTemplates()
    }

    /// Updates a template by ID; no-op if not found.
    func update(_ t: ScentsTemplate) {
        guard let i = templates.firstIndex(where: { $0.id == t.id }) else { return }
        templates[i] = t
        persistTemplates()
    }

    /// Removes a template and clears active if it was active.
    func remove(id: UUID) {
        templates.removeAll { $0.id == id }
        if activeTemplateID == id {
            activeTemplateID = nil
            persistActiveID()
        }
        persistTemplates()
    }

    // MARK: - Persistence (off main)

    private func persistTemplates() {
        let snapshot = templates
        let repo = local  // capture dependency explicitly to avoid capturing self in the Task closure
        Task {
            await repo.saveAll(snapshot) // suspends on main; repo does its own background work
        }
    }

    private func persistActiveID() {
        let s = activeTemplateID?.uuidString
        // This write is tiny; OK on main, but you can also detach if you prefer.
        UserDefaults.standard.set(s, forKey: activeKey)
    }
    
    // MARK: - Template Playlist

    var activeTemplateIndex: Int? {
        guard let id = activeTemplateID else { return nil }
        return templates.firstIndex(where: { $0.id == id })
    }

    var canGoPrevious: Bool {
        guard let i = activeTemplateIndex else { return false }
        return i > 0
    }

    var canGoNext: Bool {
        guard let i = activeTemplateIndex else { return false }
        return i < templates.count - 1
    }

    @discardableResult
    func previousTemplate() -> ScentsTemplate? {
        guard let i = activeTemplateIndex, i > 0 else { return nil }
        let template = templates[i - 1]
        setActiveTemplateID(template.id)
        return template
    }

    @discardableResult
    func nextTemplate() -> ScentsTemplate? {
        guard let i = activeTemplateIndex, i < templates.count - 1 else { return nil }
        let template = templates[i + 1]
        setActiveTemplateID(template.id)
        return template
    }
}
