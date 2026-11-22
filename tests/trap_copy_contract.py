"""trp-01 director-approved copy supersedes the historical tooltip fixtures."""

# pla-01 (exception strip) supersedes trp-01's short line; the Grimoire body stays trp-01's.
TRAP_DEFINITION = "Trigger when entered or attacked, hitting the unit on them and spreading their element around them."
TRAP_BODY = [
    "A trap triggers when a unit enters its tile or an attack hits that tile. The trap damages the unit on its tile, then leaves its element on that tile and each tile next to it. An Air trap leaves no ground: it pushes each unit next to it 1 tile away.",
    "Trigger when entered or attacked. Damage the unit on them, then leave their element on their tile and each tile next to it.",
]
