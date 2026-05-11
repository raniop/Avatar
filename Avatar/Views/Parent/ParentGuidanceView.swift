import SwiftUI

struct ParentGuidanceView: View {
    let child: Child
    @Environment(AppRouter.self) private var appRouter
    @State private var viewModel: ParentGuidanceViewModel

    private var L: AppLocale { appRouter.currentLocale }

    init(child: Child) {
        self.child = child
        self._viewModel = State(initialValue: ParentGuidanceViewModel(childId: child.id))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.guidanceItems) { item in
                    GuidanceRow(item: item)
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await viewModel.deleteGuidance(viewModel.guidanceItems[index])
                        }
                    }
                }
            } header: {
                Text(L.activeGuidance)
            } footer: {
                Text(L.guidanceFooter)
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .navigationTitle(L.guidanceFor(child.name))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showAddGuidance = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddGuidance) {
            AddGuidanceSheet(viewModel: viewModel, locale: L)
        }
        .task {
            await viewModel.loadGuidance()
        }
    }
}

struct GuidanceRow: View {
    let item: ParentGuidance

    var body: some View {
        Text(item.instruction)
            .font(AppTheme.Fonts.body)
            .padding(.vertical, 2)
    }
}

struct AddGuidanceSheet: View {
    @Bindable var viewModel: ParentGuidanceViewModel
    let locale: AppLocale
    @Environment(\.dismiss) private var dismiss

    @State private var instruction = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(locale.guidance) {
                    TextField(locale.guidanceHint, text: $instruction, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Text(locale.guidanceExplanation)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text(locale.exampleG1)
                        .font(.caption)
                    Text(locale.exampleG2)
                        .font(.caption)
                    Text(locale.exampleG3)
                        .font(.caption)
                }
            }
            .navigationTitle(locale.addGuidance)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.add) {
                        Task {
                            await viewModel.addGuidance(instruction: instruction)
                            dismiss()
                        }
                    }
                    .disabled(instruction.isEmpty)
                }
            }
        }
    }
}
