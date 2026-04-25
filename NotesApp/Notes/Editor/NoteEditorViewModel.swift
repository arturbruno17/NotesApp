//
//  NoteEditorViewModel.swift
//  NotesApp
//
//  Created by Artur Bruno on 25/04/26.
//

import Foundation
import CoreData
import Combine

/// ViewModel responsible for creating, editing and deleting notes.
final class NoteEditorViewModel: ObservableObject {

    // MARK: - Inputs/Outputs
    @Published var title: String
    @Published var body: String

    // MARK: - Dependencies
    private let database: NotesAppDatabase
    private let relativeFolderID: NSManagedObjectID?
    private let noteObjectID: NSManagedObjectID?

    // MARK: - State
    var isEditingExistingNote: Bool { noteObjectID != nil }

    // MARK: - Init
    /// - Parameters:
    ///   - database: The database instance to interact with Core Data.
    ///   - note: Optional existing note to edit. If nil, a new note will be created on save.
    ///   - relativeFolderID: Optional folder to associate the new/edited note with.
    init(database: NotesAppDatabase, note: Note?, relativeFolderID: NSManagedObjectID?) {
        self.database = database
        self.relativeFolderID = relativeFolderID
        self.noteObjectID = note?.objectID
        self.title = note?.title ?? ""
        self.body = note?.nDescription ?? ""
    }

    // MARK: - Validation
    func validateInputs() -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Persistence
    /// Creates or updates a note in a background context.
    /// - Parameter completion: Called on main queue after background task finishes.
    func saveNote(completion: (() -> Void)? = nil) {
        database.persistentContainer.performBackgroundTask { context in
            do {
                let note: Note
                if let noteObjectID = self.noteObjectID {
                    // Edit existing
                    guard let existing = try context.existingObject(with: noteObjectID) as? Note else {
                        DispatchQueue.main.async { completion?() }
                        return
                    }
                    note = existing
                } else {
                    note = Note(context: context)
                }

                note.title = self.title
                note.nDescription = self.body

                if let relativeFolderID = self.relativeFolderID {
                    if let folder = try? context.existingObject(with: relativeFolderID) as? Folder {
                        note.folder = folder
                    }
                }

                try context.save()
            } catch {
                // In a real app, propagate error state to the UI
                // For now, ignore and continue to call completion
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    /// Deletes the current note if editing one.
    /// - Parameter completion: Called on main queue after background task finishes.
    func deleteNote(completion: (() -> Void)? = nil) {
        guard let noteObjectID = self.noteObjectID else {
            DispatchQueue.main.async { completion?() }
            return
        }

        database.persistentContainer.performBackgroundTask { context in
            do {
                if let note = try context.existingObject(with: noteObjectID) as? Note {
                    context.delete(note)
                    try context.save()
                }
            } catch {
                // Ignore errors for now
            }
            DispatchQueue.main.async { completion?() }
        }
    }
}
