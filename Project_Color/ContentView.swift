//
//  ContentView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/8.
//

import SwiftUI
import CoreData
import Photos
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PhotoEntity.timestamp, ascending: true)],
        animation: .default)
    private var photos: FetchedResults<PhotoEntity>

    @State private var showPhotoPicker = false
    @State private var importedImages: [UIImage] = []

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

                if !importedImages.isEmpty {
                    Section("已选照片预览") {
                        ForEach(importedImages, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }
                }
            }
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showPhotoPicker = true }) {
                        Label("导入照片", systemImage: "photo.on.rectangle")
                    }
                }
                ToolbarItem {
                    Button(action: addPhoto) {
                        Label("Add Photo", systemImage: "plus")
                    }
                }
            }
            Text("Select a photo")
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView { results in
                // 处理选择的照片
                loadImages(from: results)
            }
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
    
    private func loadImages(from results: [PHPickerResult]) {
        importedImages.removeAll()
        
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self.importedImages.append(image)
                        }
                    }
                }
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
