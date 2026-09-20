import AppKit
import SwiftUI

enum Theme {
  static let background = Color(red: 0.07, green: 0.075, blue: 0.09)
  static let surface = Color.white.opacity(0.07)
  static let border = Color.white.opacity(0.10)
  static let text = Color(red: 0.94, green: 0.945, blue: 0.96)
  static let dim = Color(red: 0.56, green: 0.58, blue: 0.64)
  static let faint = Color(red: 0.38, green: 0.40, blue: 0.46)
  static let accent = Color(red: 0.42, green: 0.78, blue: 1.0)
  static let ready = Color(red: 0.45, green: 0.92, blue: 0.58)
  static let warn = Color(red: 1.0, green: 0.72, blue: 0.36)
  static let danger = Color(red: 1.0, green: 0.46, blue: 0.46)
}

struct LauncherView: View {
  @ObservedObject var model: LauncherModel
  @FocusState private var focused: Bool

  var body: some View {
    VStack(spacing: 0) {
      header
        .frame(height: LauncherPanelController.headerHeight)
      scopeBar
        .frame(height: LauncherPanelController.scopeHeight)
      Divider().overlay(Theme.border)
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider().overlay(Theme.border)
      StatsFooter(model: model)
        .frame(height: LauncherPanelController.footerHeight)
    }
    .frame(width: LauncherPanelController.panelWidth)
    .frame(maxHeight: .infinity)
    .background {
      ZStack {
        Blur()
        Theme.background.opacity(0.86)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Theme.border, lineWidth: 1)
    )
    .preferredColorScheme(.dark)
    .onAppear { focused = true }
    .onChange(of: model.savingWorkspace) { _, saving in if !saving { focused = true } }
  }

  private var header: some View {
    HStack(spacing: 14) {
      Image(systemName: "bolt.fill")
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(model.isReady ? Theme.ready : Theme.faint)
        .animation(.easeOut(duration: 0.15), value: model.isReady)
      TextField("Say what you mean…", text: $model.query)
        .textFieldStyle(.plain)
        .font(.system(size: 24, weight: .regular, design: .rounded))
        .foregroundStyle(Theme.text)
        .focused($focused)
        .accessibilityLabel("Search apps, files, links and workspaces")
      if let error = model.lastError {
        Image(systemName: "exclamationmark.icloud")
          .foregroundStyle(Theme.warn)
          .help(error)
          .accessibilityLabel(error)
      } else if model.isLocalOnly {
        Image(systemName: "lock.shield")
          .foregroundStyle(Theme.dim)
          .help("Local search. Online ranking is disabled.")
      } else if let status = model.status {
        Image(systemName: "checkmark.circle")
          .foregroundStyle(Theme.ready)
          .help(status)
          .accessibilityLabel(status)
      }
      Circle()
        .fill(Theme.accent)
        .frame(width: 6, height: 6)
        .opacity(model.inFlight > 0 || model.isIndexing ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: model.inFlight > 0)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, 22)
  }

  private var scopeBar: some View {
    HStack(spacing: 4) {
      ForEach(SearchScope.allCases) { scope in
        Button {
          model.scope = scope
        } label: {
          Text(scope.rawValue)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(model.scope == scope ? Theme.text : Theme.dim)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
              model.scope == scope ? Theme.surface : Color.clear,
              in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Filter to \(scope.rawValue.lowercased()). Tab cycles filters.")
        .accessibilityAddTraits(model.scope == scope ? .isSelected : [])
      }
      Spacer()
      if model.topHit != nil {
        Button {
          model.actionsVisible.toggle()
        } label: {
          HStack(spacing: 5) {
            Text("Actions")
            Text("⌘K").foregroundStyle(Theme.faint)
          }
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Theme.dim)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Actions for selected result")
      }
    }
    .padding(.horizontal, 18)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var content: some View {
    if let confirmation = model.confirmation {
      VStack(alignment: .leading, spacing: 14) {
        Label(confirmation.title, systemImage: "exclamationmark.triangle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(Theme.warn)
        Text("This permanently deletes everything in the Trash.")
          .foregroundStyle(Theme.dim)
        HStack {
          Button("Cancel") { _ = model.cancelOverlay() }
          Spacer()
          Button("Empty Trash") { model.executeSelection() }
            .tint(Theme.danger)
        }
      }
      .padding(24)
    } else if model.savingWorkspace {
      WorkspaceEditor(model: model)
    } else if model.actionsVisible {
      ActionList(model: model)
    } else if model.isEmptyQuery && model.hits.isEmpty {
      EmptyHint(model: model)
    } else if model.hits.isEmpty {
      VStack(spacing: 8) {
        Image(systemName: "magnifyingglass").font(.system(size: 23, weight: .light))
        Text("No \(model.scope.rawValue.lowercased()) results")
        Text("Try a name, a file type, or another filter.")
          .font(.system(size: 12))
      }
      .foregroundStyle(Theme.dim)
    } else {
      ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
          LazyVStack(spacing: 0) {
            ForEach(Array(model.hits.enumerated()), id: \.element.id) { index, hit in
              HStack(spacing: 0) {
                if model.hasEditableGroup && hit.candidate.isOpenable {
                  Button {
                    model.toggleMember(hit.candidate)
                  } label: {
                    Image(systemName: hit.inSet ? "checkmark.circle.fill" : "circle")
                      .foregroundStyle(hit.inSet ? Theme.accent : Theme.faint)
                      .font(.system(size: 17))
                      .frame(width: 30, height: LauncherPanelController.rowHeight)
                  }
                  .buttonStyle(.plain)
                  .accessibilityLabel(
                    "\(hit.inSet ? "Exclude" : "Include") \(hit.candidate.title) in group")
                }
                HitRow(
                  hit: hit, selected: index == model.selection,
                  ready: model.isReady && index == 0,
                  stale: !model.judgmentIsFresh && hit.jevProbability != nil,
                  pinned: model.library.isPinned(hit.candidate)
                )
                .frame(height: LauncherPanelController.rowHeight)
                .onTapGesture(count: 2) {
                  model.select(index)
                  model.executeSelection()
                }
                .onTapGesture { model.select(index) }
                .accessibilityAction(named: "Open") {
                  model.select(index)
                  model.executeSelection()
                }
              }
              .id(hit.id)
            }
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 6)
        }
        .onChange(of: model.selection) { _, selection in
          if model.hits.indices.contains(selection) {
            proxy.scrollTo(model.hits[selection].id)
          }
        }
      }
    }
  }
}

/// Native window blur behind the panel so it reads as part of the desktop, like Spotlight.
struct Blur: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct HitRow: View {
  let hit: RankedHit
  let selected: Bool
  let ready: Bool
  let stale: Bool
  var pinned = false

  var body: some View {
    HStack(spacing: 14) {
      CandidateIcon(candidate: hit.candidate)
      VStack(alignment: .leading, spacing: 2) {
        Text(hit.candidate.title)
          .font(.system(size: 15, weight: .medium, design: .rounded))
          .foregroundStyle(Theme.text)
          .lineLimit(1)
        Text(hit.candidate.subtitle)
          .font(.system(size: 12))
          .foregroundStyle(Theme.dim)
          .lineLimit(1)
      }
      Spacer(minLength: 12)
      if pinned {
        Image(systemName: "pin.fill")
          .font(.system(size: 11))
          .foregroundStyle(Theme.accent.opacity(0.7))
          .help("Pinned")
      }
      Confidence(probability: hit.jevProbability, emphasized: selected, stale: stale)
      if ready {
        Text("↵")
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .frame(width: 24, height: 22)
          .background(Theme.ready.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
          .foregroundStyle(Theme.ready)
          .transition(.opacity)
      }
    }
    .padding(.horizontal, 12)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(selected ? Theme.surface : Color.clear)
    )
    .animation(.easeOut(duration: 0.12), value: ready)
    .animation(.easeOut(duration: 0.12), value: hit.inSet)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(hit.candidate.title), \(hit.candidate.kind.label)")
    .accessibilityValue(selected ? "Selected" : "")
  }
}

/// Jev's probability that this row is the intended target. Quiet on every row but the selected one.
struct Confidence: View {
  let probability: Double?
  let emphasized: Bool
  let stale: Bool

  var body: some View {
    if let probability {
      let percent = Int((min(max(probability, 0), 1) * 100).rounded())
      HStack(spacing: 8) {
        Capsule()
          .fill(Theme.faint.opacity(0.35))
          .frame(width: 40, height: 3)
          .overlay(alignment: .leading) {
            Capsule()
              .fill(emphasized ? Theme.accent : Theme.faint)
              .frame(width: 40 * CGFloat(min(max(probability, 0), 1)))
              .animation(.easeOut(duration: 0.15), value: probability)
          }
        Text("\(percent)%")
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .monospacedDigit()
          .foregroundStyle(emphasized ? Theme.text : Theme.faint)
          .frame(width: 38, alignment: .trailing)
      }
      .opacity(stale ? 0.45 : 1)
    }
  }
}

/// The real app or document icon where one exists; a tinted glyph for everything synthetic.
struct CandidateIcon: View {
  let candidate: Candidate

  var body: some View {
    switch candidate.payload {
    case .app(let url), .file(let url):
      Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
        .resizable()
        .interpolation(.high)
        .frame(width: 32, height: 32)
    case .group(let members):
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(tint)
          .frame(width: 32, height: 32)
        Image(systemName: "square.stack.3d.up.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Theme.text)
        Text("\(members.count)")
          .font(.system(size: 9, weight: .bold, design: .rounded))
          .foregroundStyle(Theme.background)
          .padding(.horizontal, 4)
          .frame(height: 13)
          .background(Theme.accent, in: Capsule())
          .offset(x: 13, y: -12)
      }
      .frame(width: 32, height: 32)
    default:
      Image(systemName: symbol)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Theme.text)
        .frame(width: 32, height: 32)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint))
    }
  }

  private var symbol: String {
    switch candidate.kind {
    case .openApp: return "app.fill"
    case .openFile: return "doc.fill"
    case .openURL: return "link"
    case .webSearch: return "globe"
    case .calculate: return "equal"
    case .systemToggle: return "switch.2"
    case .runShortcut: return "command"
    case .send: return sendSymbol
    case .remind: return "bell.badge.fill"
    case .unclear: return "questionmark"
    }
  }

  private var sendSymbol: String {
    guard case .send(let delivery) = candidate.payload else { return "paperplane.fill" }
    switch delivery.channel {
    case .email: return "envelope.fill"
    case .message: return "message.fill"
    case .airDrop: return "dot.radiowaves.left.and.right"
    }
  }

  private var tint: Color {
    switch candidate.kind {
    case .send: return Color(red: 0.25, green: 0.60, blue: 0.95)
    case .remind: return Color(red: 0.90, green: 0.35, blue: 0.35)
    case .calculate: return Color(red: 0.95, green: 0.55, blue: 0.25)
    case .webSearch: return Color(red: 0.30, green: 0.55, blue: 0.95)
    case .openURL: return Color(red: 0.25, green: 0.62, blue: 0.85)
    case .systemToggle: return Color(red: 0.50, green: 0.52, blue: 0.60)
    case .runShortcut: return Color(red: 0.62, green: 0.40, blue: 0.95)
    default: return Theme.faint
    }
  }
}

struct EmptyHint: View {
  @ObservedObject var model: LauncherModel
  private let examples = [
    "the pdf I just downloaded", "links I visited today", "15% of 240",
  ]

  var body: some View {
    VStack(spacing: 12) {
      if model.scope == .workspaces {
        Image(systemName: "square.stack.3d.up")
          .font(.system(size: 23, weight: .light))
        Text("Save a group from Actions to reopen it by name.")
          .font(.system(size: 13))
      } else {
        HStack(spacing: 8) {
          ForEach(examples, id: \.self) { example in
            Button {
              model.scope = .all
              model.query = example
            } label: {
              Text(example)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Theme.surface, in: Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .foregroundStyle(Theme.dim)
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Two numbers, nothing else: the last round-trip on the left, the running cost on the right.
/// Everything else (p50/p95, decisions, tokens) lives in the hover tooltip.
struct StatsFooter: View {
  @ObservedObject var model: LauncherModel

  var body: some View {
    let stats = model.stats
    HStack(spacing: 0) {
      if let last = stats.lastMs {
        Text("\(ms(last)) ms")
          .foregroundStyle(tint(last))
          .fontWeight(.semibold)
      } else {
        Text("– ms")
          .foregroundStyle(Theme.faint)
      }
      Spacer(minLength: 12)
      Text(String(format: "$%.4f", stats.estimatedCostUSD))
        .foregroundStyle(stats.requests > 0 ? Theme.dim : Theme.faint)
    }
    .help(
      String(
        format: "p50 %@ ms · p95 %@ ms · %d decisions · %.0f input tokens per decision",
        ms(stats.p50Ms), ms(stats.p95Ms), stats.requests, stats.tokensPerDecision)
    )
    .font(.system(size: 12, weight: .regular, design: .monospaced))
    .monospacedDigit()
    .padding(.horizontal, 22)
  }

  private func ms(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.0f", value)
  }

  private func tint(_ value: Double) -> Color {
    if value < 250 { return Theme.ready }
    if value < 600 { return Theme.warn }
    return Theme.danger
  }
}
