# Reference and design

Research date: September 18, 2026.

- https://www.heyclicky.com/ — hotkey invocation, on-demand screen context, spoken teaching, agent tasks, private screen captures, contextual conversation.
- https://www.ycombinator.com/companies/heyclicky — cursor companion, pointing, background research, mentions Gmail/Calendar/Notion connections and building apps.
- https://github.com/farzaa/clicky — original April 2026 MIT source. The README explicitly says newer features are private. No source or assets are copied into Talkie.
- https://docs.typesafe.ai/api.md and `/cookbooks/function_calling.md` — Jev typed Choice/Noul API. Jev does not generate open-ended text.
- https://platform.openai.com/docs/api-reference/responses/create — supporting conversation and web-search service.

## Talkie’s implementation

The user requested a new, exceptionally minimal native macOS design. Talkie therefore has its own warm ivory/ink/orange visual identity rather than a pixel clone of HeyClicky. SwiftUI/AppKit, no third-party packages or web view.

Jev routes spoken requests and chooses every Mac action from actual Accessibility controls, installed apps, explicit text spans and keyboard shortcuts. Screen OCR stays local; text context is sent only on request. Apple recognizes live speech and speaks answers. An optional OpenAI key enables free-form answers, web research with citations, and generated drafts. Commands are voice-only; typed entry and audio-file import are unavailable.

## Evidence limits

HeyClicky’s latest authenticated app, paid features and private integrations are not available in the public source. Exact product parity is not established. Gmail, Calendar and Notion can be operated through their accessible Mac/browser UIs; Talkie does not pretend to have their private OAuth/API integrations. It is not an unattended coding agent or a cloud service.

The clone-this plugin’s exact visual comparison gates conflict with the user’s requested redesign. Its inventory/evidence discipline is retained; zero-pixel parity is not a delivery claim. Microphone hardware and macOS privacy permission availability must be reported separately from provider tests and earlier engine tests that used typed or imported requests.
