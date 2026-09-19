import AppKit
import SayCore
import SwiftUI

struct VoiceControlView: View {
  @ObservedObject var model: SayModel

  private var title: String {
    if model.listening { return model.voice.finishing ? "Transcribing…" : "Listening…" }
    if model.busy { return model.status }
    return "Say"
  }
  private var hint: String {
    if model.listening {
      return model.voice.finishing ? "Esc to cancel" : "Click to finish · Esc to cancel"
    }
    return model.busy ? "Esc to cancel" : "Hold ⌃ ⌥ Space to talk"
  }
  private var buttonLabel: String {
    if model.busy { return "Stop task" }
    if model.voice.finishing { return "Cancel transcription" }
    return model.listening ? "Finish recording" : "Start microphone"
  }
  private var buttonColor: Color {
    if model.voice.finishing || model.busy || !model.connected {
      return Color(nsColor: .systemGray)
    }
    return model.listening ? .red : .accentColor
  }

  var body: some View {
    HStack(spacing: 12) {
      Button {
        model.busy ? model.stop() : model.toggleMicrophone()
      } label: {
        Image(systemName: model.busy || model.listening ? "stop.fill" : "mic.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(buttonColor.gradient, in: Circle())
      }
      .buttonStyle(.plain).disabled(model.pending != nil || !model.connected)
      .accessibilityLabel(buttonLabel).help(buttonLabel)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline).lineLimit(1)
        if model.listening, !model.voice.transcript.isEmpty {
          Text(model.voice.transcript).font(.subheadline).foregroundStyle(.secondary)
            .lineLimit(2)
            .accessibilityLabel("Live transcript")
            .accessibilityValue(model.voice.transcript)
        } else {
          Text(hint).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
    }
    .frame(minHeight: 40)
  }
}

struct ListenerModeMenu: View {
  @ObservedObject var model: SayModel

  var body: some View {
    Menu {
      Picker("Mode", selection: $model.mode) {
        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
    } label: {
      Text(model.mode.rawValue).font(.caption)
    }
    .menuStyle(.borderlessButton).fixedSize()
    .disabled(model.busy || model.listening || model.pending != nil)
    .foregroundStyle(.secondary).accessibilityLabel("Listener mode").help("Choose a mode")
  }
}

struct CloseListenerButton: View {
  @ObservedObject var model: SayModel

  var body: some View {
    Button {
      model.dismissListener()
    } label: {
      Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary).frame(width: 24, height: 24).contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Close listener")
    .help(model.listening || model.busy ? "Cancel and close (Esc)" : "Close listener (Esc)")
  }
}

struct ApprovalView: View {
  @ObservedObject var model: SayModel
  let pending: PendingAction

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "hand.raised.fill")
          .font(.system(size: 26)).foregroundStyle(Color.accentColor)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text("Allow this action in \(pending.appName)?").font(.headline)
          Text(pending.action.label).textSelection(.enabled)
          Text("Say will not continue until you decide.")
            .font(.subheadline).foregroundStyle(.secondary)
        }
      }
      HStack {
        Spacer()
        Button("Cancel") { model.confirm(false) }
        Button("Allow") { model.confirm(true) }.buttonStyle(.borderedProminent)
      }
    }
  }
}

struct QuickView: View {
  @ObservedObject var model: SayModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 6) {
        VoiceControlView(model: model)
        ListenerModeMenu(model: model)
        CloseListenerButton(model: model)
      }
      if let pending = model.pending {
        Divider()
        ScrollView { ApprovalView(model: model, pending: pending) }
      } else if let notice = model.notice {
        Divider()
        ScrollView { NoticeBar(text: notice) { model.notice = nil } }
      } else if let reply = model.quickReply {
        Divider()
        ScrollView { MessageView(message: reply, compact: true).padding(.trailing, 4) }
      } else if !model.connected {
        Divider()
        HStack {
          Text("Add your API keys to get started.").font(.callout).foregroundStyle(.secondary)
          Spacer(minLength: 8)
          Button("Set Up…") { model.openSettings(.connections) }
        }
      }
    }
    .padding(16).frame(width: model.quickWidth, height: model.quickHeight)
    .background(PanelSurface())
    .onExitCommand { model.dismissListener() }
  }
}

struct CompanionView: View {
  @ObservedObject var model: SayModel

  private var title: String {
    if model.listening { return model.voice.finishing ? "Transcribing…" : "Listening…" }
    if model.busy { return "Working…" }
    return model.quickReply != nil ? "Done" : "Say"
  }
  private var detail: String {
    if model.listening, !model.voice.transcript.isEmpty { return model.voice.transcript }
    if model.busy { return model.status }
    return model.quickReply != nil ? "Click to review" : "Hold ⌃ ⌥ Space"
  }
  private var buttonLabel: String {
    if model.busy { return "Stop task" }
    if model.voice.finishing { return "Cancel transcription" }
    return model.listening ? "Finish recording" : "Start microphone"
  }

  var body: some View {
    HStack(spacing: 10) {
      Button {
        model.openListener()
      } label: {
        SayMark(size: 26, active: model.listening || model.busy)
      }
      .buttonStyle(.plain).accessibilityLabel("Ask Say")
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.weight(.medium))
        Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer(minLength: 0)
      Button {
        model.busy ? model.stop() : model.toggleMicrophone()
      } label: {
        Image(systemName: model.busy || model.listening ? "stop.fill" : "mic.fill")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 26, height: 26)
          .background(
            (model.listening ? Color.red : Color.accentColor).gradient, in: Circle())
      }
      .buttonStyle(.plain).accessibilityLabel(buttonLabel)
      if model.listening || model.busy {
        CloseListenerButton(model: model)
      }
    }
    .padding(.horizontal, 14).frame(width: 260, height: 60)
    .background(PanelSurface(radius: 20))
  }
}
