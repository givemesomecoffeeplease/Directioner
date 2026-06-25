//
//  ContentView.swift
//  ClickTrackInserter
//
//  Created by 한희 on 6/25/26.
//

import SwiftUI

// 추후 설정 화면에서 사용할 뷰 (현재는 플레이스홀더)
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("ClickTrack Inserter")
                .font(.headline)
            Text("설정 기능은 추후 추가됩니다.")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 300, height: 120)
    }
}
