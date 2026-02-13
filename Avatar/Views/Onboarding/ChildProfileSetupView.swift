import SwiftUI

struct ChildProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChildProfileViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Child's Name", text: $viewModel.name)
                    Stepper("Age: \(viewModel.age)", value: $viewModel.age, in: 2...12)
                    Picker("Gender", selection: $viewModel.gender) {
                        Text("Boy").tag("boy")
                        Text("Girl").tag("girl")
                        Text("Other").tag("other")
                    }
                }

                Section("Interests") {
                    InterestTagsView(
                        allInterests: viewModel.availableInterests,
                        selectedInterests: $viewModel.selectedInterests
                    )
                }

                Section("Development Goals") {
                    Text("What would you like to work on?")
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    InterestTagsView(
                        allInterests: viewModel.availableGoals,
                        selectedInterests: $viewModel.selectedGoals
                    )
                }

                Section("Language") {
                    Picker("Primary Language", selection: $viewModel.locale) {
                        Text("English").tag(AppLocale.english)
                        Text("Hebrew").tag(AppLocale.hebrew)
                    }
                }
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveChild()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.name.isEmpty)
                }
            }
        }
    }
}

struct InterestTagsView: View {
    let allInterests: [String]
    @Binding var selectedInterests: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(allInterests, id: \.self) { interest in
                let isSelected = selectedInterests.contains(interest)

                Text(interest)
                    .font(AppTheme.Fonts.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? AppTheme.Colors.primary : Color.gray.opacity(0.15))
                    .foregroundStyle(isSelected ? .white : AppTheme.Colors.textPrimary)
                    .clipShape(Capsule())
                    .onTapGesture {
                        if isSelected {
                            selectedInterests.removeAll { $0 == interest }
                        } else {
                            selectedInterests.append(interest)
                        }
                    }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
