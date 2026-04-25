//
//  Note+CoreDataProperties.swift
//  NotesApp
//
//  Created by Artur Bruno on 24/04/26.
//
//

public import Foundation
public import CoreData


public typealias NoteCoreDataPropertiesSet = NSSet

extension Note: Listable {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }

    @NSManaged public var nDescription: String?
    @NSManaged public var title: String?
    @NSManaged public var folder: Folder?

    var name: String? { title ?? nDescription }
    
}

extension Note : Identifiable {

}
