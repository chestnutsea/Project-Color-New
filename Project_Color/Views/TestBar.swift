import SwiftUI

// MARK: - 通用导航搜索组件（可复用）

struct NavigationSearchBar: View {

    // 外部输入
    @Binding var searchText: String
    var onBack: (() -> Void)?
    var onAdd: (() -> Void)?

    // 内部状态
    @State private var isSearching = false

    var body: some View {
        HStack {

            // MARK: - 左侧返回按钮
            if !isSearching {
                Button {
                    onBack?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            // MARK: - 右侧搜索区域
            HStack {

                if isSearching {
                    // --------------------------
                    // 搜索展开状态
                    // --------------------------
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("搜索", text: $searchText)
                            .foregroundColor(.primary)

                        Button {
                            withAnimation(.spring()) {
                                searchText = ""
                                isSearching = false     // 收起搜索栏
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                } else {
                    // --------------------------
                    // 默认状态：搜索 + 添加按钮
                    // --------------------------
                    HStack(spacing: 0) {

                        Button {
                            withAnimation(.spring()) {
                                isSearching = true
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        }

                        Button {
                            onAdd?()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.primary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}


#Preview {
    NavigationSearchBar(
        searchText: .constant(""),
        onBack: {},
        onAdd: {}
    )
    .padding()
}
