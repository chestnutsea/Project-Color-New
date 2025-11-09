//
//  PhotoPickerView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import SwiftUI
import PhotosUI
import Photos
import UIKit

struct PhotoPickerView: View {
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss

    @State private var showSystemPicker = false

    var body: some View {
        VStack(spacing: 20) {
            if selectedImages.isEmpty {
                Text("尚未选择照片")
                    .foregroundColor(.gray)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(selectedImages, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 90)
                                .clipped()
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            HStack(spacing: 16) {
                Button("重新选择照片") {
                    showSystemPicker = true
                }
                .buttonStyle(.borderedProminent)

                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .navigationTitle("选择照片")
        .onAppear(perform: checkPhotoPermission)
        .sheet(isPresented: $showSystemPicker) {
            PhotoPicker(images: $selectedImages)
        }
    }

    // MARK: - 检查与请求相册权限
    private func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            showSystemPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        showSystemPicker = true
                    }
                }
            }
        default:
            print("用户拒绝访问相册")
        }
    }
}

// MARK: - PHPicker 封装
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            parent.images.removeAll()

            for item in results {
                if item.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    item.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let uiImage = image as? UIImage {
                            DispatchQueue.main.async {
                                self.parent.images.append(uiImage)
                            }
                        }
                    }
                }
            }
        }
    }
}
