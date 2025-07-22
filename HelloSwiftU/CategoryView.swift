//
//  CategoryView.swift
//  HelloSwiftU
//
//  Created by 今井悠翔 on 2025/07/22.
//

import Foundation
import SwiftUI

struct CategoryView: View {
    @State private var categories = ["食品", "日用品", "その他", "カスタムカテゴリ"]
    let presetColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]

    var body: some View {
        ZStack {
            Color(hex: "#D2986A")
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("カテゴリの整理：\(categories.count)件")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    ForEach(categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category)
                                .foregroundColor(.black)

                            if category != "食品" && category != "日用品" && category != "その他" {
                                Button(action: {
                                    deleteCategory(category)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }

                            HStack {
                                ForEach(presetColors, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            // カラー変更処理をここに
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .padding(.top, 16)
            }
            .scrollContentBackground(.hidden)
        }
    }

    func deleteCategory(_ category: String) {
        categories.removeAll { $0 == category }
    }
}
