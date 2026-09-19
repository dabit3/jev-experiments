# Reference and design

Research date: September 18, 2026.

- https://www.heyclicky.com/ — hotkey invocation, on-demand screen context, spoken teaching, agent tasks, private screen captures, contextual conversation.
- https://www.ycombinator.com/companies/heyclicky — cursor companion, pointing, background research, mentions Gmail/Calendar/Notion connections and building apps.
- https://github.com/farzaa/clicky — original April 2026 MIT source. The README explicitly says newer features are private. No source or assets are copied into Say.
- https://docs.typesafe.ai/api.md and `/cookbooks/function_calling.md` — Jev typed Choice/Noul API. Jev does not generate open-ended text.
- https://platform.openai.com/docs/api-reference/responses/create — supporting conversation and web-search service.

## Say’s implementation

Say uses a cobalt-and-ivory speech bubble with a cursor-shaped tail. The app icon, menu-bar mark, and README artwork use the same custom vector shape. Settings is a separate window with toolbar panes, built on `NSTabViewController` and grouped SwiftUI forms, the same structure Apple uses for Safari and Mail settings. The History window uses `NavigationSplitView`, system fonts, and the user's accent color. There are no third-party Swift dependencies or web views.

Jev routes spoken requests and chooses every Mac action from actual Accessibility controls, installed apps, explicit text spans and keyboard shortcuts. Screen OCR stays local; text context is sent only on request. OpenAI `gpt-live-transcribe` transcribes live microphone audio. Apple speaks answers. The required OpenAI key also enables free-form answers, web research with citations, and generated drafts. Commands are voice-only; typed entry and audio-file import are unavailable.

## Evidence limits

HeyClicky’s latest authenticated app, paid features and private integrations are not available in the public source. Exact product parity is not established. Gmail, Calendar and Notion can be operated through their accessible Mac/browser UIs; Say does not pretend to have their private OAuth/API integrations. It is not an unattended coding agent or a cloud service.

The clone-this plugin’s exact visual comparison gates conflict with the user’s requested redesign. Its inventory/evidence discipline is retained; zero-pixel parity is not a delivery claim. Microphone hardware and macOS privacy permission availability must be reported separately from provider tests and earlier engine tests that used typed or imported requests.
