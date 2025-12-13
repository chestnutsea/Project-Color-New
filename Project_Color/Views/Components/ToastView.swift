//
//  ToastView.swift
//  Project_Color
//
//  Toast 提示组件
//

import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.8))
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    Spacer()
                        .frame(height: 100)
                }
                .zIndex(999)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, duration: TimeInterval = 1.0) -> some View {
        self.modifier(ToastModifier(isPresented: isPresented, message: message, duration: duration))
    }
}

#Preview {
    VStack {
        Text("Content")
    }
    .toast(isPresented: .constant(true), message: L10n.Toast.featureInDevelopment.localized)
}

