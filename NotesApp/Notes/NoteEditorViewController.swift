//
//  NoteEditorViewController.swift
//  NotesApp
//
//  Created by Artur Bruno on 23/04/26.
//

import Foundation
import UIKit
import CoreData

class NoteEditorViewController : UIViewController {
    
    let note: Note?
    let relativeFolderID: NSManagedObjectID?
    
    let titleTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Enter your title"
        textField.font = .systemFont(ofSize: 24, weight: .bold)
        return textField
    }()
    
    let descriptionTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .systemGroupedBackground
        textView.layer.cornerRadius = 8
        textView.font = .systemFont(ofSize: 18)
        return textView
    }()
    
    init(note: Note? = nil, relativeFolderID: NSManagedObjectID? = nil) {
        self.note = note
        self.relativeFolderID = relativeFolderID

        super.init(nibName: nil, bundle: nil)
        
        titleTextField.text = note?.title
        descriptionTextView.text = note?.nDescription
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = self.note == nil ? "New note" : "Editing note"
        
        if self.note != nil {
            navigationItem.rightBarButtonItems = [
                .init(barButtonSystemItem: .done, target: self, action: #selector(createOrEditNote)),
                .init(barButtonSystemItem: .trash, target: self, action: #selector(deleteNote))
            ]
        } else {
            navigationItem.rightBarButtonItems = [
                .init(barButtonSystemItem: .done, target: self, action: #selector(createOrEditNote))
            ]
        }
        
        setupViews()
        setupConstraints()
    }
    
    private func setupViews() {
        view.addSubview(titleTextField)
        view.addSubview(descriptionTextView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleTextField.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            titleTextField.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            titleTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            titleTextField.heightAnchor.constraint(equalToConstant: 44)
        ])
        NSLayoutConstraint.activate([
            descriptionTextView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            descriptionTextView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            descriptionTextView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor),
            descriptionTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    @objc private func createOrEditNote() {
        guard let title = titleTextField.text, !title.isEmpty else { return }
        guard let description = descriptionTextView.text, !description.isEmpty else { return }
        
        let database = NotesAppDatabase.shared
        database.persistentContainer.performBackgroundTask { context in
            let note = self.note ?? Note(entity: Note.entity(), insertInto: context)
            note.title = title
            note.nDescription = description
            if let relativeFolderID = self.relativeFolderID {
                note.folder = try? context.existingObject(with: relativeFolderID) as? Folder
            }
            do {
                try context.save()
            } catch {
                print(error.localizedDescription)
            }
        }
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func deleteNote() {
        guard let note = self.note else { return }
        
        let database = NotesAppDatabase.shared
        database.persistentContainer.performBackgroundTask { _ in
            database.context.delete(note)
            do {
                try database.context.save()
            } catch {
                print(error.localizedDescription)
            }
        }
        navigationController?.popViewController(animated: true)
    }
    
}
