//
//  NotesAppDatabase.swift
//  NotesApp
//
//  Created by Artur Bruno on 23/04/26.
//

import Foundation
import CoreData

class NotesAppDatabase {
    static let shared = NotesAppDatabase()

    lazy var persistentContainer: NSPersistentContainer = {
        let nSPersistentContainer = NSPersistentContainer(name: "NotesApp")
        nSPersistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved error loading persistent store: \(error)")
            }
        }
        nSPersistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        nSPersistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        return nSPersistentContainer
    }()

    var context: NSManagedObjectContext { persistentContainer.viewContext }
    
    private init() {}
}
