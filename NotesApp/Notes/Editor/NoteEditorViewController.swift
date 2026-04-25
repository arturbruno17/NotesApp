//
//  NoteEditorViewController.swift
//  NotesApp
//
//  Created by Artur Bruno on 23/04/26.
//

import Foundation
import UIKit
import CoreData
import Combine

final class NoteEditorViewController: UIViewController, UITextViewDelegate {

    // MARK: - Dependencies
    private let viewModel: NoteEditorViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI
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

    // MARK: - Init
    init(viewModel: NoteEditorViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = viewModel.isEditingExistingNote ? "Editing note" : "New note"

        if viewModel.isEditingExistingNote {
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
        bindViewModel()

        // Seed UI with initial values
        titleTextField.text = viewModel.title
        descriptionTextView.text = viewModel.body
    }

    // MARK: - Bindings
    private func bindViewModel() {
        titleTextField.addTarget(self, action: #selector(titleChanged), for: .editingChanged)
        descriptionTextView.delegate = self
    }

    // MARK: - Setup UI
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

    // MARK: - Actions
    @objc private func titleChanged() {
        viewModel.title = titleTextField.text ?? ""
    }
    
    func textViewDidChange(_ textView: UITextView) {
        viewModel.body = textView.text
    }

    @objc private func createOrEditNote() {
        viewModel.title = titleTextField.text ?? ""
        viewModel.body = descriptionTextView.text ?? ""
        guard viewModel.validateInputs() else { return }

        viewModel.saveNote {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc private func deleteNote() {
        viewModel.deleteNote {
            self.navigationController?.popViewController(animated: true)
        }
    }
}
