import SwiftUI

/// Custom Case App Selection Screen.
/// Allows the user to toggle which specific apps and games appear in the custom unboxing spin.
public struct CustomAppsListView: View {
    @ObservedObject var model: InstalledAppsModel
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var selectedFilter: AppCategory? = nil

    private var filteredApps: [AppEntry] {
        var list = model.apps
        if let cat = selectedFilter {
            list = list.filter { $0.category == cat }
        }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q) }
        }
        return list
    }

    private var selectedCount: Int {
        model.count(for: .custom)
    }

    private var totalCount: Int {
        model.apps.count
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.08)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Search bar
                    searchBarView

                    // Category filter pills
                    categoryFilterBar

                    // Selection summary bar
                    summaryBar

                    // App checklist
                    if filteredApps.isEmpty {
                        emptyStateView
                    } else {
                        appsListView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }) {
                        Text("DONE")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.88, blue: 0.35),
                                        Color(red: 1.0, green: 0.72, blue: 0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.yellow.opacity(0.35), radius: 6, x: 0, y: 2)
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("CUSTOM CASE")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .kerning(1.5)
                            .foregroundColor(.white)
                        Text("\(selectedCount) OF \(totalCount) SELECTED")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.15))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        model.toggleAllOrNoneCustom()
                    }) {
                        Text("ALL / NONE")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.45))

            TextField("Search installed apps & games...", text: $query)
                .font(.system(size: 14))
                .autocorrectionDisabled(true)
                .foregroundColor(.white)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                CategoryFilterChip(
                    title: "ALL",
                    isSelected: selectedFilter == nil,
                    onTap: { selectedFilter = nil }
                )
                CategoryFilterChip(
                    title: "GAMES",
                    isSelected: selectedFilter == .games,
                    onTap: { selectedFilter = .games }
                )
                CategoryFilterChip(
                    title: "SOCIAL",
                    isSelected: selectedFilter == .social,
                    onTap: { selectedFilter = .social }
                )
                CategoryFilterChip(
                    title: "MEDIA",
                    isSelected: selectedFilter == .media,
                    onTap: { selectedFilter = .media }
                )
                CategoryFilterChip(
                    title: "FOOD",
                    isSelected: selectedFilter == .food,
                    onTap: { selectedFilter = .food }
                )
                CategoryFilterChip(
                    title: "TOOLS",
                    isSelected: selectedFilter == .tools,
                    onTap: { selectedFilter = .tools }
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var summaryBar: some View {
        HStack {
            if selectedCount == 0 {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("0 selected — all apps will be rolled as fallback")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.15))
                    Text("\(selectedCount) of \(totalCount) apps in custom roll")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text("No apps match \"\(query)\"")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appsListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredApps) { app in
                    CustomAppRow(
                        app: app,
                        isSelected: model.isCustomSelected(id: app.id),
                        onToggle: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            model.toggleCustomSelected(id: app.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Row Subview

struct CustomAppRow: View {
    let app: AppEntry
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // App icon
                if let icon = app.icon {
                    Image(uiImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(app.color).opacity(0.25))
                            .frame(width: 44, height: 44)
                        Image(systemName: app.systemIcon)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }

                // Title and badges
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(app.rarity.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(app.color).opacity(0.25))
                            .foregroundColor(Color(app.color))
                            .cornerRadius(4)

                        Text(app.category.title)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                Spacer()

                // Checkbox toggle
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.88, blue: 0.35),
                                        Color(red: 1.0, green: 0.72, blue: 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                            .shadow(color: Color.yellow.opacity(0.4), radius: 4)

                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.black)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 2)
                            .frame(width: 26, height: 26)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.07) : Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.yellow.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Chip Subview

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isSelected
                        ? Color(red: 1.0, green: 0.82, blue: 0.15)
                        : Color.white.opacity(0.08)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.yellow : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
