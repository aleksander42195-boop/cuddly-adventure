import SwiftUI

struct CoachingView: View {
    @EnvironmentObject var engineManager: CoachEngineManager
    @StateObject private var vm = CoachVM(service: OfflineHeuristicsService())

    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                Text(vm.reply)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            TextField("Skriv til coach …", text: $input)
                .textFieldStyle(.roundedBorder)
            Button("Send") {
                Task {
                    // Henter aktuell motor når du trykker, slik at bytte i Settings tar effekt umiddelbart
                    let svc = engineManager.makeService()
                    // Oppdaterer VM "on the fly"
                    let tmp = CoachVM(service: svc)
                    await tmp.ask(input)
                    vm.reply = tmp.reply
                }
            }
        }
        .padding()
        .onAppear {
            // initial service
            let svc = engineManager.makeService()
            vm.updateService(svc)
        }
    }
}

#Preview {
    CoachingView()
        .environmentObject(CoachEngineManager())
}
