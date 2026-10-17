# Umbra Review Inbox (owner feedback channel)

Owner 2026-10-17: post anything that needs the owner's eyes or ears to a separate place instead of burying it in the
work thread, as targeted quick-look/listen items (clips with sound, images, comparison sheets), and keep playtests
periodic. Live page: https://claude.ai/artifact/SWBweH8njp6JEy9GBpguyE (private; opens in the Claude app's
Artifacts pane).

- The page is the record (`artifact` capability): its state lives in the `inbox-state` JSON block. Owner verdicts
  (Approve / Needs changes / Send note) are sent to Claude as a comment on the item (`comments.sendToClaude`, which
  notifies the watching session) and then saved into the page by a self-publish.
- Media are artifact assets (`assets`): upload with the Artifact tool (`url`, `asset: true`, `file_paths`) and put the
  returned `/_blob/<id>` url in the item's `media`. Keep each file ≤ 15 MB.
- To post or close items: Artifact `read` the live page (it may hold owner verdicts) → `inbox.py extract` → edit the
  state (new items `status: open`; set `reply` + `status: done` on handled ones) → `inbox.py render STATE OUT reset.css`
  → publish the same file path / `url`. Never publish without reading the live version first.
- Reply in the item's comment thread (ArtifactComments reply) and resolve it once handled.
