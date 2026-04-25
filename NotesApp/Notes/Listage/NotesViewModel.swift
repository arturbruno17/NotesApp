import UIKit
import CoreData
import Combine


/// ViewModel for NotesViewController implementing business logic in MVVM pattern.
final class NotesViewModel {
    let relativeFolder: Folder?

    private let database: NotesAppDatabase

    @Published private var notesAndFolders: [Listable] = []
    var notesAndFoldersPublisher: AnyPublisher<[Listable], Never> {
        return $notesAndFolders.eraseToAnyPublisher()
    }

    /// Initializes the view model.
    /// - Parameters:
    ///   - database: The database instance to interact with Core Data.
    ///   - relativeFolder: The folder relative to which notes and folders are fetched.
    init(database: NotesAppDatabase, relativeFolder: Folder? = nil) {
        self.database = database
        self.relativeFolder = relativeFolder
    }

    func fetchNotesAndFolders() {
        let context = database.context

        context.perform {
            var results: [Listable] = []

            let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
            let folderRequest: NSFetchRequest<Folder> = Folder.fetchRequest()

            if let relativeFolder = self.relativeFolder {
                noteRequest.predicate = NSPredicate(format: "folder == %@", relativeFolder)
                folderRequest.predicate = NSPredicate(format: "parentFolder == %@", relativeFolder)
            } else {
                noteRequest.predicate = NSPredicate(format: "folder == nil")
                folderRequest.predicate = NSPredicate(format: "parentFolder == nil")
            }

            noteRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.title, ascending: true)]
            folderRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]

            do {
                let notes = try context.fetch(noteRequest)
                let folders = try context.fetch(folderRequest)
                results.append(contentsOf: folders)
                results.append(contentsOf: notes)
            } catch {
                // Silently ignore fetch errors and emit empty array
                results = []
            }

            DispatchQueue.main.async { self.notesAndFolders = results }
        }
    }

    func deleteCurrentFolder(completion: (() -> Void)? = nil) {
        guard let relativeFolder else { return }

        let objectID = relativeFolder.objectID
        database.persistentContainer.performBackgroundTask { backgroundContext in
            do {
                let folderInContext = try backgroundContext.existingObject(with: objectID) as? Folder
                if let folderInContext = folderInContext {
                    backgroundContext.delete(folderInContext)
                    try backgroundContext.save()
                }
            } catch {
                // Ignore errors
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    func createFolder(named name: String) {
        database.persistentContainer.performBackgroundTask { backgroundContext in
            let folder = Folder(context: backgroundContext)
            folder.name = name

            if let parentObjectID = self.relativeFolder?.objectID{
                do {
                    let parentFolder = try backgroundContext.existingObject(with: parentObjectID) as? Folder
                    folder.parentFolder = parentFolder
                } catch {
                    // Ignore error, create folder without parent
                }
            }

            do {
                try backgroundContext.save()
            } catch {
                // Ignore save errors
            }

            DispatchQueue.main.async { self.fetchNotesAndFolders() }
        }
    }

    func renameFolder(_ folder: Folder, to newName: String) {
        let folderObjectID = folder.objectID
        database.persistentContainer.performBackgroundTask { backgroundContext in
            do {
                if let folderInContext = try backgroundContext.existingObject(with: folderObjectID) as? Folder {
                    folderInContext.name = newName
                    try backgroundContext.save()
                }
            } catch {
                // Ignore errors
            }
            DispatchQueue.main.async { self.fetchNotesAndFolders() }
        }
    }
}

