//
//  ContentView.swift
//  Project Color
//
//  Created by Linya Huang on 2025/11/8.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PhotoEntity.timestamp, ascending: true)],
        animation: .default)
    private var photos: FetchedResults<PhotoEntity>

    var body: some View {
        NavigationView {
            List {
                ForEach(photos) { photo in
                    NavigationLink {
                        if let timestamp = photo.timestamp {
                            Text("Photo at \(timestamp, formatter: itemFormatter)")
                        } else {
                            Text("Photo details unavailable")
                        }
                    } label: {
                        if let timestamp = photo.timestamp {
                            Text(timestamp, formatter: itemFormatter)
                        } else {
                            Text("Unknown date")
                        }
                    }
                }
                .onDelete(perform: deletePhotos)
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addPhoto) {
                        Label("Add Photo", systemImage: "plus")
                    }
                }
            }
            Text("Select a photo")
        }
    }

    private func addPhoto() {
        withAnimation {
            let newPhoto = PhotoEntity(context: viewContext)
            newPhoto.id = UUID()
            newPhoto.assetLocalId = UUID().uuidString
            newPhoto.timestamp = Date()
            newPhoto.toneCategory = "neutral"

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deletePhotos(offsets: IndexSet) {
        withAnimation {
            offsets.map { photos[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, CoreDataManager.preview.viewContext)
}
