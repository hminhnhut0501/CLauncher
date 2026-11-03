import SwiftUI

public enum AppCategoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case productivity = "Productivity"
    case graphicsAndDesign = "Design"
    case developer = "Developer"
    case media = "Media"
    case utilities = "Utilities"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .productivity: return "briefcase.fill"
        case .graphicsAndDesign: return "paintpalette.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .media: return "play.tv.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        }
    }
}

public struct CategoryPillsBar: View {
    @Binding public var selectedCategory: AppCategoryFilter

    public init(selectedCategory: Binding<AppCategoryFilter>) {
        self._selectedCategory = selectedCategory
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(AppCategoryFilter.allCases) { category in
                let isSelected = selectedCategory == category
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selectedCategory = category
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: category.iconName)
                            .font(.system(size: 11, weight: .semibold))
                        Text(category.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.28))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
                                    )
                                    .shadow(color: Color.white.opacity(0.2), radius: 6)
                            } else {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .liquidGlass(cornerRadius: 20, opacity: 0.12, borderOpacity: 0.25)
    }
}
