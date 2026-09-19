import SwiftUI

enum LauncherAction: String, Identifiable {
  case open, preview, reveal, copy, pin, member, reviewGroup, saveWorkspace, deleteWorkspace
  var id: String { rawValue }

  var title: String {
    switch self {
    case .open: return "Open"
    case .preview: return "Quick Look"
    case .reveal: return "Reveal in Finder"
    case .copy: return "Copy path, link or result"
    case .pin: return "Pin for quick access"
    case .member: return "Include or exclude from group"
    case .reviewGroup: return "Review and edit items"
    case .saveWorkspace: return "Save group as workspace"
    case .deleteWorkspace: return "Delete workspace"
    }
  }

  var symbol: String {
    switch self {
    case .open: return "arrow.up.forward"
    case .preview: return "eye"
    case .reveal: return "folder"
    case .copy: return "doc.on.doc"
    case .pin: return "pin"
    case .member: return "checkmark.circle"
    case .reviewGroup: return "list.bullet"
    case .saveWorkspace: return "square.stack.3d.up"
    case .deleteWorkspace: return "trash"
    }
  }

  var keys: String {
    switch self {
    case .open: return "↵"
    case .preview: return "⌘Y"
    case .reveal: return "⌘R"
    case .copy: return "⇧⌘C"
    case .pin: return "⌘P"
    case .member: return "⌘Space"
    case .reviewGroup, .saveWorkspace, .deleteWorkspace: return ""
    }
  }
}

struct ActionList: View {
  @ObservedObject var model: LauncherModel

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 3) {
          if let candidate = model.topHit?.candidate {
            Text(candidate.title)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(Theme.dim)
              .lineLimit(1)
              .padding(.bottom, 8)
            ForEach(model.availableActions.indices, id: \.self) { index in
              actionRow(model.availableActions[index], index: index, candidate: candidate).id(index)
            }
          }
        }
        .padding(18)
      }
      .onChange(of: model.actionSelection) { _, index in proxy.scrollTo(index) }
    }
  }

  private func actionRow(_ action: LauncherAction, index: Int, candidate: Candidate) -> some View {
    let title = action == .pin && model.library.isPinned(candidate) ? "Unpin" : action.title
    return Button {
      model.performAction(action)
    } label: {
      HStack(spacing: 10) {
        Image(systemName: action.symbol).frame(width: 18).foregroundStyle(Theme.dim)
        Text(title).foregroundStyle(Theme.text)
        Spacer()
        Text(action.keys).foregroundStyle(Theme.faint)
      }
      .font(.system(size: 13))
      .padding(.horizontal, 10)
      .padding(.vertical, 9)
      .background(
        model.actionSelection == index ? Theme.surface : Color.clear,
        in: RoundedRectangle(cornerRadius: 7)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct WorkspaceEditor: View {
  @ObservedObject var model: LauncherModel
  @FocusState private var focused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Save \(model.selectedMembers.count) items as a workspace")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Theme.text)
      TextField("Name this workspace", text: $model.workspaceName)
        .textFieldStyle(.roundedBorder)
        .focused($focused)
        .onSubmit { model.saveWorkspace() }
      HStack {
        Button("Cancel") { model.savingWorkspace = false }
        Spacer()
        Button("Save workspace") { model.saveWorkspace() }
          .disabled(model.workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24)
    .onAppear { focused = true }
  }
}
