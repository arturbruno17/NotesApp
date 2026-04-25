import UIKit
import CoreData
import Combine


/// ViewModel for NotesViewController implementing business logic in MVVM pattern.
final class NotesViewModel: NSObject, NSFetchedResultsControllerDelegate {
    
    let relativeFolder: Folder?
    private let database: NotesAppDatabase
    private let notesFRC: NSFetchedResultsController<Note>
    private let foldersFRC: NSFetchedResultsController<Folder>

    @Published private var notes: [Note] = []
    @Published private var folders: [Folder] = []

    var notesAndFoldersPublisher: AnyPublisher<[Listable], Never> {
        Publishers.CombineLatest($folders, $notes)
            .map { folders, notes -> [Listable] in
                (folders + notes).sorted { $0.name ?? "" < $1.name ?? "" }
            }.eraseToAnyPublisher()
    }

    /// Initializes the view model.
    /// - Parameters:
    ///   - database: The database instance to interact with `CoreData`.
    ///   - relativeFolder: The folder relative to which notes and folders are fetched.
    init(database: NotesAppDatabase, relativeFolder: Folder? = nil) {
        self.database = database
        self.relativeFolder = relativeFolder
        
        // Notes fetch request
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.title, ascending: true)]

        // Folders fetch request
        let folderRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        folderRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        // Predicates
        if let relativeFolder = self.relativeFolder {
            noteRequest.predicate = NSPredicate(format: "folder == %@", relativeFolder)
            folderRequest.predicate = NSPredicate(format: "parentFolder == %@", relativeFolder)
        } else {
            noteRequest.predicate = NSPredicate(format: "folder == nil")
            folderRequest.predicate = NSPredicate(format: "parentFolder == nil")
        }

        self.notesFRC = NSFetchedResultsController(
            fetchRequest: noteRequest,
            managedObjectContext: database.context,
            sectionNameKeyPath: nil,
            cacheName: nil)
        self.foldersFRC = NSFetchedResultsController(
            fetchRequest: folderRequest,
            managedObjectContext: database.context,
            sectionNameKeyPath: nil,
            cacheName: nil)

        super.init()
        
        notesFRC.delegate = self
        foldersFRC.delegate = self
    }

    func fetchNotesAndFolders() {
        do {
            try notesFRC.performFetch()
            try foldersFRC.performFetch()
            self.notes = notesFRC.fetchedObjects ?? []
            self.folders = foldersFRC.fetchedObjects ?? []
        } catch {
            // On failure, clear arrays and merged list
            self.notes = []
            self.folders = []
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
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if controller === notesFRC {
            self.notes = notesFRC.fetchedObjects ?? []
        } else if controller === foldersFRC {
            self.folders = foldersFRC.fetchedObjects ?? []
        }
    }
}

