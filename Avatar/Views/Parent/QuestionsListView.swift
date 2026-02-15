import SwiftUI

struct QuestionsListView: View {
    let child: Child
    @Environment(AppRouter.self) private var appRouter
    @State private var viewModel: QuestionsViewModel

    private var L: AppLocale { appRouter.currentLocale }

    init(child: Child) {
        self.child = child
        self._viewModel = State(initialValue: QuestionsViewModel(childId: child.id))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.questions) { question in
                    QuestionRow(question: question, locale: L)
                }
                .onDelete { indexSet in
                    Task {
                        for index in indexSet {
                            await viewModel.deleteQuestion(viewModel.questions[index])
                        }
                    }
                }
            } header: {
                Text(L.activeQuestions)
            } footer: {
                Text(L.questionsFooter)
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .navigationTitle(L.questionsFor(child.name))
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
            AddQuestionSheet(viewModel: viewModel, locale: L)
        }
        .task {
            await viewModel.loadQuestions()
        }
    }
}

struct QuestionRow: View {
    let question: ParentQuestion
    let locale: AppLocale

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
                    Label(locale.recurring, systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                Text(locale.priorityLabel(question.priority))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddQuestionSheet: View {
    @Bindable var viewModel: QuestionsViewModel
    let locale: AppLocale
    @Environment(\.dismiss) private var dismiss

    @State private var questionText = ""
    @State private var topic = ""
    @State private var priority = 1
    @State private var isRecurring = false

    var body: some View {
        NavigationStack {
            Form {
                Section(locale.question) {
                    TextField(locale.whatToAsk, text: $questionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section(locale.details) {
                    TextField(locale.topicOptional, text: $topic)

                    Stepper(locale.priorityLabel(priority), value: $priority, in: 0...5)

                    Toggle(locale.recurring, isOn: $isRecurring)
                }

                Section {
                    Text(locale.exampleQuestions)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text(locale.exampleQ1)
                        .font(.caption)
                    Text(locale.exampleQ2)
                        .font(.caption)
                    Text(locale.exampleQ3)
                        .font(.caption)
                }
            }
            .navigationTitle(locale.addQuestion)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locale.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.add) {
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
