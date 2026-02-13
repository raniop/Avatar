import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var appRouter

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let user = authManager.currentUser {
                        LabeledContent("Name", value: user.displayName)
                        LabeledContent("Email", value: user.email)
                    }
                }

                Section("Language") {
                    Picker("App Language", selection: Bindable(appRouter).currentLocale) {
                        ForEach(AppLocale.allCases, id: \.self) { locale in
                            Text(locale.displayName).tag(locale)
                        }
                    }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        authManager.logout()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

extension Bindable where Value == AppRouter {
    var currentLocale: Binding<AppLocale> {
        Binding(
            get: { self.wrappedValue.currentLocale },
            set: { self.wrappedValue.currentLocale = $0 }
        )
    }
}
