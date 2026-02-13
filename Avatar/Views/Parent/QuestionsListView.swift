import SwiftUI

struct QuestionsListView: View {
    let child: Child
    @State private var viewModel: QuestionsViewModel

    init(child: Child) {
        self.child = child
        self._viewModel = State(initialValue: QuestionsViewModel(childId: child.id))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.questions) { question in
                    QuestionRow(question: question)
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await viewModel.deleteQuestion(viewModel.questions[index])
                        }
                    }
                }
            } header: {
                Text("Active Questions")
            } footer: {
                Text("These questions will be naturally woven into your child's next conversation with their avatar.")
            }
        }
        .navigationTitle("Questions for \(child.name)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showAddQuestion = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddQuestion) {
            AddQuestionSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadQuestions()
        }
    }
}

struct QuestionRow: View {
    let question: ParentQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(question.questionText)
                .font(AppTheme.Fonts.body)

            HStack {
                if let topic = question.topic {
                    Text(topic)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                if question.isRecurring {
                    Label("Recurring", systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                Text("Priority: \(question.priority)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddQuestionSheet: View {
    @Bindable var viewModel: QuestionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var questionText = ""
    @State private var topic = ""
    @State private var priority = 1
    @State private var isRecurring = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("What would you like to ask?", text: $questionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Details") {
                    TextField("Topic (optional)", text: $topic)

                    Stepper("Priority: \(priority)", value: $priority, in: 0...5)

                    Toggle("Recurring", isOn: $isRecurring)
                }

                Section {
                    Text("Example questions:")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("How was your day at school?")
                        .font(.caption)
                    Text("Did anyone bother you today?")
                        .font(.caption)
                    Text("What made you happy today?")
                        .font(.caption)
                }
            }
            .navigationTitle("Add Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await viewModel.addQuestion(
                                text: questionText,
                                topic: topic.isEmpty ? nil : topic,
                                priority: priority,
                                isRecurring: isRecurring
                            )
                            dismiss()
                        }
                    }
                    .disabled(questionText.isEmpty)
                }
            }
        }
    }
}
