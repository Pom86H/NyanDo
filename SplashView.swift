//
//  SplashView.swift
//  HelloSwiftU
//
//  Created by 今井悠翔 on 2025/07/11.
//

import SwiftUI

struct SplashView: View {
    // スプラッシュ画面を表示しているか
    @State private var isActive = false
    // ロゴの大きさと透明度を管理
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.5

    var body: some View {
        // isActive が true なら ContentView に遷移
        if isActive {
            ContentView()
        } else {
            ZStack {
                Color(red: 95/255, green: 127/255, blue: 103/255) // 背景

                VStack(spacing: 40) {
                    LottieView(name: "paws-animation", speed: 2.0)
                        .frame(width: 200, height: 200)
                        .offset(x: -198, y: -80)
                        .rotationEffect(.degrees(30))

                    Text("NyanDo 🐾")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    LottieView(name: "paws-animation", speed: 2.0)
                        .frame(width: 200, height: 200)
                        .offset(x: 240, y: 110)
                        .rotationEffect(.degrees(30))
                }
            }
            .ignoresSafeArea() // ← これで上下の白を消す！
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 70, damping: 6)) {
                    logoScale = 1.1
                    logoOpacity = 1.0
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                    logoScale = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
