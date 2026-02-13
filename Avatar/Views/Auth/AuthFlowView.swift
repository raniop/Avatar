import SwiftUI

struct AuthFlowView: View {
    @State private var showRegister = false

    var body: some View {
        Group {
            if showRegister {
                RegisterView(showRegister: $showRegister)
            } else {
                LoginView(showRegister: $showRegister)
            }
        }
    }
}
