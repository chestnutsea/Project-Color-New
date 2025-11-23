import SwiftUI

struct PosterView: View {
    @State private var keyword = ""
    @State private var results: [[String: Any]] = []
    @State private var isLoading = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏 - 固定在顶部
                VStack(spacing: 0) {
                HStack {
                    TextField("搜索电影，例如：三体 / Inception", text: $keyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                        .onSubmit { search() }
                            .submitLabel(.search)
                    
                    Button("搜索") { search() }
                        .buttonStyle(.bordered)
                }
                .padding()
                
                if isLoading {
                    ProgressView("查询中…")
                            .padding(.bottom, 8)
                }
                
                    Divider()
                }
                .background(Color(.systemBackground))
                
                // 结果列表
                if results.isEmpty && !isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("输入电影名称开始搜索")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                List(Array(results.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        
                        if let urlString = item["cover_image_url"] as? String,
                           let url = URL(string: urlString) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 70, height: 100)
                            .clipped()
                            .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(item["title"] as? String ?? "无标题")
                                .font(.headline)
                            
                            if let year = item["year"] as? Int {
                                Text("\(year)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.plain)
                }
            }
            .navigationTitle("NeoDB 搜索")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture {
                // 点击空白处收起键盘
                isTextFieldFocused = false
            }
        }
    }
    
    func search() {
        guard !keyword.isEmpty else { return }
        isLoading = true
        results = []
        
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlString = "https://neodb.social/api/search?q=\(encoded)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async { self.isLoading = false }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let objects = json["objects"] as? [[String: Any]] else { return }
            
            DispatchQueue.main.async {
                self.results = objects
            }
        }.resume()
    }
}

#Preview {
    PosterView()
}
