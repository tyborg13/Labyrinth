"""Observed prose checks. Context-sensitive findings live in style_review.tsv."""
from __future__ import annotations

import re


WORD = re.compile(r"[+−-]?\d+(?:\.\d+)?%?|[^\W\d_]+(?:[’'-][^\W\d_]+)*", re.UNICODE)
SENTENCE = re.compile(r"[^.!?]+(?:[.!?]+|$)")
STYLE = "spec/card_text_style.md"
BRIEF = "unit brief §3"

# Contextual vocabulary such as "it", "near", "grant", and elemental family
# names is reviewed per row rather than treated as an unqualified substring.
VOCABULARY = {
    "R11": r"\b(?:every|everyone|anyone|whoever|everything|all connected)\b",
    "R14": r"\b(?:next to|around|beside|neighbou?ring|nearby|surrounding)\b",
    "R22": r"\b(?:sometimes|possibly|mostly|simply|some \w+)\b",
    "R24": r"\b(?:blast(?:s)?|cross(?:es)?|diamond(?:s)?|ring(?:s)?|splash|pattern|radius-\d+)\b",
    "R25": (
        r"\b(?:every|all|everyone|anyone|whoever|everything|next to|around|beside|nearby|"
        r"neighbou?ring|surrounding|battle|fight|foe|monster|hostile|character|actor|creature|"
        r"square|space|cell|spot|field|surfaces?|network|obstacle|objects?|"
        r"the player|the hero|under you|this round|next round|this encounter|"
        r"gets?|grants?|granting|receives?|suffers?|hurt|harm|hit for|strik(?:e|es|ing)|"
        r"blow up|shatters?|explodes?|clears?|dispels?|seen|concealed|that much)\b"
    ),
}
CARD_MECHANIC_CLAUSE = re.compile(r"\b(?:the card|this card|when played)(?![\w-])", re.I)
AREA = re.compile(
    r"\b(?:these tiles(?: centered on each tile you enter| centered on it| around you)?|"
    r"centered on your tile|a (?:cross|diamond|ring)|an area|blast(?:s| crosses)?|radius-\d+)\b", re.I
)


def hits(text: str, pattern: str | re.Pattern, *, ignore_case: bool = True) -> list[str]:
    regex = re.compile(pattern, re.I if ignore_case else 0) if isinstance(pattern, str) else pattern
    return list(dict.fromkeys(match[0] for match in regex.finditer(text)))


def entry(category: str, evidence: str, detail: str, *references: str) -> dict:
    return {"category": category, "evidence": evidence, "detail": detail, "references": list(references)}


def style_flags(text: str, hud_text: str, manual: list[dict]) -> list[dict]:
    findings = list(manual)
    for rule, pattern in VOCABULARY.items():
        matches = hits(text, pattern)
        if rule == "R25":
            matches = [word for word in matches if word not in {"Dispel", "Expend"}]
        if matches:
            findings.append(entry(rule, ", ".join(matches), "Vocabulary outside the applicable house rule.", STYLE))
    punctuation = hits(text, r"[;:!?()]|(?<=[\w])/(?=[\w])|(?<= )[-—–](?= )")
    if text.strip() and not text.rstrip().endswith("."):
        punctuation.append("missing final period")
    if punctuation:
        findings.append(entry("R19", " ".join(punctuation), "Non-period rules punctuation or termination.", STYLE))
    sentences = SENTENCE.findall(hud_text)
    decay_only = len(sentences) == 2 and sentences[1].strip() == "A later Blink replaces it."
    if len(sentences) > 1 and not decay_only:
        findings.append(entry(
            "R9", hud_text, "Multiple tooltip sentences, including content other than how the effect ends.",
            STYLE, "scripts/card_focus_tooltip_stack.gd:100",
        ))
    exceptions = hits(
        hud_text,
        r"\b(?:unless|but not)\b[^.]*|[^.]*\b(?:are excluded|neither count nor gain this bonus)\b",
    )
    if exceptions:
        findings.append(entry(
            "R10", "; ".join(exceptions),
            "Explicit exception appears in the HUD tooltip body copied from the relic description.",
            STYLE, "scripts/card_focus_tooltip_stack.gd:100",
        ))
    wording = hits(text, CARD_MECHANIC_CLAUSE)
    if wording:
        findings.append(entry("card_only", ", ".join(wording), "Card-specific phrasing in a relic description.", BRIEF))
    return findings
