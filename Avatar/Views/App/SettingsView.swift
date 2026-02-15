import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var appRouter

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        NavigationStack {
            List {
                Section(L.account) {
                    if let user = authManager.currentUser {
                        LabeledContent(L.name, value: user.displayName)
                        LabeledContent(L.email, value: user.email)
                    }
                }

                Section(L.language) {
                    Picker(L.appLanguage, selection: Bindable(appRouter).currentLocale) {
                        ForEach(AppLocale.allCases, id: \.self) { locale in
                            Text(locale.displayName).tag(locale)
                        }
                    }
                }

                // Show "Switch Player" only in child mode when parent has multiple children
                if appRouter.activeRole == .child {
                    Section {
                        Button {
                            appRouter.switchChild()
                        } label: {
                            Label(L.switchChild, systemImage: "person.2.circle")
                        }
                    }
                }

                Section {
                    Button {
                        appRouter.switchRole()
                    } label: {
                        Label(L.switchRole, systemImage: "arrow.left.arrow.right")
                    }
                }

                Section {
                    Button(L.logOut, role: .destructive) {
                        appRouter.activeRole = nil
                        authManager.logout()
                    }
                }
            }
            .environment(\.layoutDirection, L.layoutDirection)
            .navigationTitle(L.settings)
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
