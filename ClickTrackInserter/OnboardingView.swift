//
//  OnboardingView.swift
//  ClickTrackInserter
//

import SwiftUI
import ApplicationServices

struct OnboardingView: View {
    @State private var step = 0
    @State private var axGranted = AXIsProcessTrusted()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                Text("Directioner에 오신 것을 환영합니다")
                    .font(.title2).bold()
                Text("Logic Pro에 클릭 트랙을 빠르게 삽입하는 도구입니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            Divider()

            // 스텝
            VStack(spacing: 0) {
                StepRow(
                    number: 1,
                    title: "손쉬운 사용 권한 허용",
                    description: "단축키 감지를 위해 필요합니다.",
                    isActive: step == 0,
                    isDone: axGranted
                ) {
                    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
                    AXIsProcessTrustedWithOptions(options)
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }

                Divider().padding(.leading, 52)

                StepRow(
                    number: 2,
                    title: "오디오 파일 등록",
                    description: "클릭 트랙 파일과 약어를 매핑합니다.",
                    isActive: step == 1,
                    isDone: step > 1
                ) {
                    onFinish()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
                    }
                }

                Divider().padding(.leading, 52)

                StepRow(
                    number: 3,
                    title: "사용 방법",
                    description: "Shift 두 번 → 약어 입력 → Logic Pro에서 클릭",
                    isActive: step == 2,
                    isDone: false,
                    actionLabel: nil,
                    action: nil
                )
            }
            .padding(.vertical, 8)

            Divider()

            // 하단 버튼
            HStack {
                Spacer()
                Button("시작하기") { onFinish() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!axGranted)
                    .help(axGranted ? "" : "먼저 손쉬운 사용 권한을 허용해주세요")
            }
            .padding(16)
        }
        .frame(width: 480)
        .onReceive(timer) { _ in
            let granted = AXIsProcessTrusted()
            if granted != axGranted {
                axGranted = granted
                if granted && step == 0 { step = 1 }
            }
        }
        .onAppear {
            if axGranted { step = 1 }
        }
    }
}

// MARK: - StepRow

struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    let isActive: Bool
    let isDone: Bool
    var actionLabel: String? = "열기"
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 번호 뱃지
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isActive ? Color.accentColor : Color.secondary.opacity(0.3)))
                    .frame(width: 28, height: 28)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isActive ? .white : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isActive || isDone ? .primary : .secondary)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let label = actionLabel, let action = action, !isDone {
                Button(label, action: action)
                    .buttonStyle(.bordered)
                    .disabled(!isActive)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
