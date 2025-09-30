import SwiftUI
import WatchKit

struct WatchChatView: View {
    @EnvironmentObject private var vm: WatchChatViewModel
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Meldingsliste
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(vm.messages) { msg in
                            bubble(for: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                }
                .onChange(of: vm.messages.count) {
                    if let lastId = vm.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // Inntastingslinje
            HStack(spacing: 6) {
                TextField("Skriv…", text: $vm.draft)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { vm.send() }

                Button {
                    WKInterfaceDevice.current().play(.click)
                    DictationHelper.present(
                        suggestions: ["Hei!", "Hva er planen i dag?", "Gi meg en treningsøkt"]
                    ) { text in
                        if let text = text {
                            vm.send(text: text)
                        }
                    }
                } label: {
                    Image(systemName: "mic.fill")
                        .accessibilityLabel("Dikter")
                }
                .disabled(vm.isSending)

                Button {
                    vm.send()
                } label: {
                    if vm.isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(vm.isSending)
            }
            .padding(6)
            .navigationTitle("Coach")
            .onAppear { inputFocused = true }
            .toolbar {
                // Valgfritt: en enkel "Ny" knapp for å starte på nytt
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.messages = [.init(.system, "Ny chat startet.")]
                    } label: { Image(systemName: "arrow.counterclockwise") }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func bubble(for msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        HStack {
            if isUser { Spacer(minLength: 0) }
            Text(msg.text)
                .font(.system(size: 13))
                .padding(8)
                .background(isUser ? .blue.opacity(0.25) : .gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            if !isUser { Spacer(minLength: 0) }
        }
    }
}

#Preview {
    WatchChatView()
        .environmentObject(WatchChatViewModel(engine: ChatServiceAdapter()))
}
