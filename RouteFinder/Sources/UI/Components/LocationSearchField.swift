import Contracts
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// OSM/Nominatim address search field with inline suggestions.
struct LocationSearchField: View {
    let placeholder: String
    @Binding var text: String
    var focusTag: UUID
    var focusedWaypointID: FocusState<UUID?>.Binding
    var isActive: Bool = false
    var resolutionStatus: EndpointResolutionStatus = .empty
    var snapHint: String? = nil
    var feedback: String? = nil
    let suggestions: [GeocodeSuggestion]
    let onQueryChange: (String) -> Void
    let onPinTap: () -> Void
    let onSelect: (GeocodeSuggestion) -> Void

    @State private var suppressQueryChange = false

    private var isFocused: Bool {
        focusedWaypointID.wrappedValue == focusTag
    }

    private var showSuggestions: Bool {
        isFocused && !suggestions.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            searchFieldRow

            if showSuggestions {
                suggestionsList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            statusLine
        }
        #if os(macOS)
        .animation(.easeOut(duration: 0.15), value: showSuggestions)
        #endif
        .onChange(of: focusedWaypointID.wrappedValue) { _, focusedID in
            #if os(macOS)
            if focusedID == focusTag { NSApp.activate(ignoringOtherApps: true) }
            #endif
        }
        .onChange(of: text) { _, newValue in
            guard newValue == text else { return }
            guard !suppressQueryChange else { return }
            onQueryChange(newValue)
        }
    }

    private var searchFieldRow: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused(focusedWaypointID, equals: focusTag)
                #if os(iOS)
                .textContentType(.fullStreetAddress)
                .submitLabel(.search)
                .onSubmit {
                    focusedWaypointID.wrappedValue = nil
                }
                #endif
                #if os(macOS)
                .onTapGesture {
                    NSApp.activate(ignoringOtherApps: true)
                }
                #endif

            Button(action: onPinTap) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(isActive ? RFColor.hazard : .secondary)
            }
            .buttonStyle(.plain)
            .help("Set location on map")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(fieldBorder)
        #if os(iOS)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            focusedWaypointID.wrappedValue = focusTag
        }
        #endif
    }

    private var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(
                isFocused ? RFColor.route.opacity(0.7) : (isActive ? RFColor.hazard.opacity(0.6) : .white.opacity(0.15)),
                lineWidth: isFocused || isActive ? 1.5 : 0.5
            )
    }

    @ViewBuilder
    private var statusLine: some View {
        if showSuggestions {
            EmptyView()
        } else if let snapHint, !snapHint.isEmpty, resolutionStatus == .resolved {
            Text(snapHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } else if let feedback, !feedback.isEmpty, isFocused {
            Text(feedback)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } else {
            Text(resolutionStatus.label)
                .font(.caption2)
                .foregroundStyle(resolutionStatus.color)
        }
    }

    private var suggestionsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(suggestions.prefix(8).enumerated()), id: \.element.id) { index, suggestion in
                    suggestionRow(suggestion)
                    if index < min(suggestions.count, 8) - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
        .frame(maxHeight: min(CGFloat(min(suggestions.count, 8)) * 52, 240))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            #if os(macOS)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            #else
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            #endif
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(RFColor.route.opacity(0.35), lineWidth: 1)
        )
    }

    private func suggestionRow(_ suggestion: GeocodeSuggestion) -> some View {
        Button {
            selectSuggestion(suggestion)
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(suggestion.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer()
                if suggestion.isLocal {
                    Text("OSM")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RFColor.route)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RFColor.route.opacity(0.15), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func selectSuggestion(_ suggestion: GeocodeSuggestion) {
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        suppressQueryChange = true
        text = suggestion.subtitle
        onSelect(suggestion)
        focusedWaypointID.wrappedValue = nil
        Task { @MainActor in
            suppressQueryChange = false
        }
        #else
        Task { @MainActor in
            focusedWaypointID.wrappedValue = nil
            dismissKeyboard()
            await Task.yield()
            suppressQueryChange = true
            text = suggestion.subtitle
            onSelect(suggestion)
            suppressQueryChange = false
        }
        #endif
    }
}

/// Resolution state shown under each search field.
enum EndpointResolutionStatus: Equatable {
    case empty
    case typing
    case needsSelection
    case resolved
    case error(String)

    var label: String {
        switch self {
        case .empty: return ""
        case .typing: return "Keep typing…"
        case .needsSelection: return "Pick a result from the list"
        case .resolved: return "Resolved ✓"
        case .error(let message): return message
        }
    }

    var color: Color {
        switch self {
        case .resolved: return RFColor.route
        case .error: return .red
        case .needsSelection: return .orange
        default: return .secondary
        }
    }
}
