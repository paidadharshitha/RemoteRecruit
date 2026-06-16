// JobDetailView.swift
// RemoteRecruit

import SwiftUI

struct JobDetailView: View {

    let job: Job

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerCard
                metadataSection
                if !job.tags.isEmpty {
                    tagsSection
                }
                descriptionSection
            }
            .padding()
        }
        .navigationTitle(job.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // TODO: Implement share functionality
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.tint.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(String(job.companyName.prefix(1)))
                            .font(.title2.bold())
                            .foregroundStyle(.tint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(job.companyName)
                        .font(.title3.bold())

                    Text(job.location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(spacing: 16) {
            detailRow(icon: "banknote", color: .green, title: "Salary Range", value: job.salaryRange)
            detailRow(icon: "mappin", color: .blue, title: "Location", value: job.location)
            detailRow(icon: "wifi", color: .indigo, title: "Work Type", value: "Fully Remote")

            if !job.tags.isEmpty {
                detailRow(icon: "tag", color: .orange, title: "Tags", value: job.tags.joined(separator: ", "))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            WrapLayout(tags: job.tags)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Job Description")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(job.jobDescription)
                .font(.body)
                .lineSpacing(6)
        }
    }

    // MARK: - Helpers

    private func detailRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }

            Spacer()
        }
    }
}

// MARK: - Wrap Layout

private struct WrapLayout: View {

    let tags: [String]

    var body: some View {
        FlowLayoutView(items: tags) { tag in
            Text(tag)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.fill.tertiary, in: Capsule())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Simple Flow Layout

private struct FlowLayoutView<Item: Hashable, Content: View>: View {

    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        VStack {
            GeometryReader { geo in
                SelfSizingLayout(
                    items: items,
                    content: content,
                    containerWidth: geo.size.width,
                    heightBinding: $totalHeight
                )
            }
            .frame(height: totalHeight)
        }
    }
}

private struct SelfSizingLayout<Item: Hashable, Content: View>: View {

    let items: [Item]
    let content: (Item) -> Content
    let containerWidth: CGFloat
    @Binding var heightBinding: CGFloat

    init(
        items: [Item],
        content: @escaping (Item) -> Content,
        containerWidth: CGFloat,
        heightBinding: Binding<CGFloat>
    ) {
        self.items = items
        self.content = content
        self.containerWidth = containerWidth
        self._heightBinding = heightBinding
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > containerWidth {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        width = -d.width
                        return result
                    }
                    .alignmentGuide(.top) { d in
                        if abs(width - d.width) > containerWidth {
                            width = 0
                            height -= d.height
                        }
                        let result = height
                        if width <= 0 {
                            height = -d.height
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { h in
            heightBinding = h
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
