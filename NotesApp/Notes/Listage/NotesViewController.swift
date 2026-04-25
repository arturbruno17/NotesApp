//
//  ViewController.swift
//  NotesApp
//
//  Created by Artur Bruno on 22/04/26.
//

import UIKit
import CoreData
import Combine

class NotesViewController: UITableViewController {
    
    private let viewModel: NotesViewModel
    private var cancellables = Set<AnyCancellable>()
    private var snapshot: [Listable] = []
    
    init(viewModel: NotesViewModel) {
        self.viewModel = viewModel
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
        view.backgroundColor = .systemBackground
        title = "Notes"
        
        var rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(goToNoteEditorWithoutNote)),
            UIBarButtonItem(barButtonSystemItem: .organize, target: self, action: #selector(showCreateFolderSheet))
        ]
        
        if viewModel.relativeFolder != nil {
            rightBarButtonItems.append(
                UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteCurrentFolder))
            )
        }
        
        navigationItem.rightBarButtonItems = rightBarButtonItems
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showRenameFolderSheet))
        tableView.addGestureRecognizer(longPress)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        viewModel.notesAndFoldersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                guard let self else { return }
                self.snapshot = list
                self.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        viewModel.fetchNotesAndFolders()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancellables.removeAll()
    }
    
    private func goToNoteEditor(with note: Note?) {
        let vc = NoteEditorViewController(note: note, relativeFolderID: viewModel.relativeFolder?.objectID)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func goToNoteEditorWithoutNote() {
        goToNoteEditor(with: nil)
    }
    
    @objc private func showCreateFolderSheet() {
        let alert = UIAlertController(title: "Create Folder",
                                      message: "Enter a name for the new folder",
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in textField.placeholder = "Folder name" }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] _ in
            guard let folderName = alert.textFields?.first?.text else { return }
            self?.viewModel.createFolder(named: folderName)
        }))
        
        present(alert, animated: true)
    }
    
    @objc private func showRenameFolderSheet(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }

        guard let folder = snapshot[indexPath.row] as? Folder else { return }
        
        let alert = UIAlertController(title: "Rename Folder",
                                      message: "Enter a new name for your folder",
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Folder name"
            textField.text = folder.name
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { [weak self] _ in
            guard let folderName = alert.textFields?.first?.text else { return }
            self?.viewModel.renameFolder(folder, to: folderName)
        }))
        
        present(alert, animated: true)
    }
    
    @objc private func deleteCurrentFolder() {
        viewModel.deleteCurrentFolder {
            self.navigationController?.popViewController(animated: true)
        }
    }
}

extension NotesViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        snapshot.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "General", for: indexPath)
        let listable = snapshot[indexPath.row]
        
        let configuration: any UIContentConfiguration
        
        switch listable {
        case let note as Note:
            var tmpConfiguration = UIListContentConfiguration.subtitleCell()
            tmpConfiguration.text = note.title
            tmpConfiguration.secondaryText = note.nDescription
            configuration = tmpConfiguration
        case let folder as Folder:
            var tmpConfiguration = UIListContentConfiguration.cell()
            tmpConfiguration.text = folder.name
            tmpConfiguration.image = .init(systemName: "folder")
            configuration = tmpConfiguration
        default:
            fatalError("snapshot[indexPath.row] should return only Note or Folder instances.")
        }
        
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let note = snapshot[indexPath.row] as? Note {
            goToNoteEditor(with: note)
        } else if let folder = snapshot[indexPath.row] as? Folder {
            let vc = NotesViewController(
                viewModel: NotesViewModel(
                    database: NotesAppDatabase.shared,
                    relativeFolder: folder
                )
            )
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}
