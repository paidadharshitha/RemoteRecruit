// SmartChipsInput.swift
// RemoteRecruit

import SwiftUI

// MARK: - Smart Chips Input

/// A reusable chip-based input field with autocomplete suggestions.
/// Users type to add chips and tap the × button to remove them.
/// Supports both freeform text input and predefined suggestions.
public struct SmartChipsInput: View {

    // MARK: - Properties

    @Binding var chips: [String]
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    /// All available suggestions (filtered by input).
    var suggestions: [String] = []

    /// Placeholder text for the text field.
    var placeholder: String = "Type to add…"

    /// Whether to show suggestions based on the current input.
    var showSuggestions: Bool = true

    /// Optional chip color override.
    var chipColor: Color = DesignTokens.Colors.accent

    /// Maximum number of chips allowed (nil for unlimited).
    var maxChips: Int?

    // MARK: - Computed

    private var filteredSuggestions: [String] {
        let query = inputText.trimmingCharacters(in: .whitespaces).lowercased()
        guard showSuggestions, !query.isEmpty else { return [] }
        return suggestions
            .filter { $0.lowercased().contains(query) && !chips.contains($0) }
            .prefix(5)
            .map { $0 }
    }

    private var isAtLimit: Bool {
        if let max = maxChips { return chips.count >= max }
        return false
    }

    // MARK: - Init

    public init(
        chips: Binding<[String]>,
        suggestions: [String] = [],
        placeholder: String = "Type to add…",
        showSuggestions: Bool = true,
        chipColor: Color = DesignTokens.Colors.accent,
        maxChips: Int? = nil
    ) {
        self._chips = chips
        self.suggestions = suggestions
        self.placeholder = placeholder
        self.showSuggestions = showSuggestions
        self.chipColor = chipColor
        self.maxChips = maxChips
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Input row
            HStack(spacing: DesignTokens.Spacing.sm) {
                TextField(placeholder, text: $inputText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    #if os(iOS)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    #endif
                    .disabled(isAtLimit)
                    .onSubmit { addChip() }

                Button {
                    addChip()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : chipColor)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isAtLimit)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                DesignTokens.Colors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(isFocused ? chipColor.opacity(0.4) : DesignTokens.Colors.glassBorder, lineWidth: 1)
            )

            // Suggestion pills
            if !filteredSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button {
                                chips.append(suggestion)
                                inputText = ""
                                withAnimation(DesignTokens.Animations.quickSpring) { }
                            } label: {
                                Text(suggestion)
                                    .font(DesignTokens.Typography.captionSemibold)
                                    .foregroundStyle(chipColor)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(chipColor.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Selected chips
            if !chips.isEmpty {
                FlowLayout(spacing: DesignTokens.Spacing.sm) {
                    ForEach(chips, id: \.self) { chip in
                        chipView(for: chip)
                    }
                }
            }
        }
        .animation(DesignTokens.Animations.spring, value: chips)
    }

    // MARK: - Chip View

    private func chipView(for text: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(text)
                .font(DesignTokens.Typography.caption.weight(.medium))
                .foregroundStyle(chipColor)

            Button {
                withAnimation(DesignTokens.Animations.quickSpring) {
                    chips.removeAll { $0 == text }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(DesignTokens.Typography.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(chipColor.opacity(0.1), in: Capsule())
    }

    // MARK: - Actions

    private func addChip() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !chips.contains(trimmed), !isAtLimit else { return }
        withAnimation(DesignTokens.Animations.spring) {
            chips.append(trimmed)
            inputText = ""
        }
    }
}
