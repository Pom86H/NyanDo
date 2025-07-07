//
//  ottieView.swift
//  HelloSwiftU
//
//  Created by 今井悠翔 on 2025/07/04.
//

import Foundation
import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    var filename: String

    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: filename)
        animationView.loopMode = .loop
        animationView.play()
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // ここは今は空でOK！
    }
}
