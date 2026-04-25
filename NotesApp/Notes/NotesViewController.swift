//
//  ViewController.swift
//  NotesApp
//
//  Created by Artur Bruno on 22/04/26.
//

import UIKit
import CoreData

class NotesViewController: UITableViewController {
    
    let relativeFolder: Folder?
    
    // Note & Folder classes
    var notesAndFolders: [Listable] = [] {
        didSet { tableView.reloadData() }
    }
    
    init(relativeFolder: Folder? = nil) {
        self.relativeFolder = relativeFolder
        super.init(style: .plain)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "General")
        tableView.separatorInset = .zero
        tableView.separatorInsetReference = .fromAutomaticInsets
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = .systemBackground
        title = "Notes"
        
        var rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(goToNoteEditorWithoutNote)),
            UIBarButtonItem(barButtonSystemItem: .organize, target: self, action: #selector(showCreateFolderSheet)),
        ]
        
        if relativeFolder != nil {
            rightBarButtonItems.append(
                UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteFolder))
            )
        }
    
        navigationItem.rightBarButtonItems = rightBarButtonItems
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showRenameFolderSheet))
        tableView.addGestureRecognizer(longPress)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchNotesAndFolders()
    }
    
    private func fetchNotesAndFolders() {
        let viewContext = NotesAppDatabase.shared.context
        
        let noteFetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Note.title, ascending: true)]
        
        let folderFetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        folderFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Folder.name, ascending: true)]
        
        if let folder = relativeFolder {
            noteFetchRequest.predicate = NSPredicate(format: "folder == %@", folder)
            folderFetchRequest.predicate = NSPredicate(format: "parentFolder == %@", folder)
        } else {
            noteFetchRequest.predicate = NSPredicate(format: "folder == nil")
            folderFetchRequest.predicate = NSPredicate(format: "parentFolder == nil")
        }
        
        let notes: [Listable] = (try? viewContext.fetch(noteFetchRequest)) ?? []
        let folders: [Listable] = (try? viewContext.fetch(folderFetchRequest)) ?? []
        
        self.notesAndFolders = (notes + folders)
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    @objc private func deleteFolder() {
        let database = NotesAppDatabase.shared
        guard let folderObjectiveID = relativeFolder?.objectID else { return }
        
        database.persistentContainer.performBackgroundTask { context in
            let object = try? context.existingObject(with: folderObjectiveID)
            if let object {
                context.delete(object)
                try? context.save()
            }
        }
        navigationController?.popViewController(animated: true)
    }
    
    private func goToNoteEditor(with note: Note?) {
        let vc = NoteEditorViewController(note: note, relativeFolderID: relativeFolder?.objectID)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func goToNoteEditorWithoutNote() {
        goToNoteEditor(with: nil)
    }
    
    @objc private func showCreateFolderSheet() {
        let alert = UIAlertController(title: "Create Folder",
                                      message: "Enter a name for the new folder",
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in textField.placeholder = "Folder name"}
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { _ in
            guard let folderName = alert.textFields?.first?.text else { return }
            
            let database = NotesAppDatabase.shared
            database.persistentContainer.performBackgroundTask { context in
                let folder = Folder(entity: Folder.entity(), insertInto: context)
                folder.name = folderName
                try? context.save()
                DispatchQueue.main.async { self.fetchNotesAndFolders() }
            }
        }))
        
        present(alert, animated: true)
    }
    
    @objc private func showRenameFolderSheet(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }

        guard let folder = notesAndFolders[indexPath.row] as? Folder else { return }
        
        let alert = UIAlertController(title: "Rename Folder",
                                      message: "Enter a new name for your folder",
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Folder name"
            textField.text = folder.name
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { _ in
            guard let folderName = alert.textFields?.first?.text else { return }
            
            let database = NotesAppDatabase.shared
            database.persistentContainer.performBackgroundTask { context in
                guard let folder = try? context.existingObject(with: folder.objectID) as? Folder else { return }
                folder.name = folderName
                try? context.save()
                DispatchQueue.main.async { self.fetchNotesAndFolders() }
            }
        }))
        
        present(alert, animated: true)
    }
}

extension NotesViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        notesAndFolders.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "General", for: indexPath)
        let listable = notesAndFolders[indexPath.row]
        
        let configuration: any UIContentConfiguration
        
        switch listable {
        case let note as Note:
            var tmpConfiguration = UIListContentConfiguration.subtitleCell()
            tmpConfiguration.text = note.title
            tmpConfiguration.secondaryText = note.nDescription
            configuration = tmpConfiguration
            break
        case let folder as Folder:
            var tmpConfiguration = UIListContentConfiguration.cell()
            tmpConfiguration.text = folder.name
            tmpConfiguration.image = .init(systemName: "folder")
            configuration = tmpConfiguration
            break
        default:
            fatalError("notesAndFolders[indexPath.row] should return only Note or Folder instances.")
            break
        }
        
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let note = notesAndFolders[indexPath.row] as? Note {
            goToNoteEditor(with: note)
        } else if let folder = notesAndFolders[indexPath.row] as? Folder {
            let vc = NotesViewController(relativeFolder: folder)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
