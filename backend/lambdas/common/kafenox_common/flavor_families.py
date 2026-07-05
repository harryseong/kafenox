import boto3

bedrock = boto3.client("bedrock-runtime")

# Family names mirror FlavorFamily.all in the iOS app (FlavorFamily.swift).
# The client renders whatever family the backend stores and falls back to its
# own note lookup for coffees that predate categorization.
FLAVOR_FAMILIES = [
    "Fruity",
    "Floral & Tea",
    "Sweet",
    "Nutty & Cocoa",
    "Spice & Wood",
    "Other",
]

TOOL_NAME = "categorize_flavor_notes"

CATEGORIZATION_TOOL = {
    "toolSpec": {
        "name": TOOL_NAME,
        "description": "Assign each coffee tasting note to exactly one flavor family.",
        "inputSchema": {
            "json": {
                "type": "object",
                "properties": {
                    "assignments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "note": {"type": "string"},
                                "family": {"type": "string", "enum": FLAVOR_FAMILIES},
                            },
                            "required": ["note", "family"],
                        },
                    }
                },
                "required": ["assignments"],
            }
        },
    }
}


def categorize_flavor_notes(notes: list[str], model_id: str) -> dict[str, str]:
    """Map each flavor note to one of FLAVOR_FAMILIES via Bedrock Converse.

    Returns {note: family} covering every input note; notes the model skips
    or mislabels fall back to "Other". Bedrock/boto3 errors propagate --
    callers decide whether a categorization failure is fatal.
    """
    notes = [n for n in dict.fromkeys(notes) if n and isinstance(n, str)]
    if not notes:
        return {}

    note_lines = "\n".join(f"- {n}" for n in notes)
    response = bedrock.converse(
        modelId=model_id,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "text": (
                            "Categorize each of these coffee tasting notes into one "
                            f"flavor family using the {TOOL_NAME} tool. Repeat each "
                            "note exactly as written.\n\n"
                            f"{note_lines}"
                        )
                    }
                ],
            }
        ],
        toolConfig={
            "tools": [CATEGORIZATION_TOOL],
            "toolChoice": {"tool": {"name": TOOL_NAME}},
        },
    )

    assigned: dict[str, str] = {}
    content_blocks = response["output"]["message"]["content"]
    tool_use = next((b["toolUse"] for b in content_blocks if "toolUse" in b), None)
    assignments = ((tool_use or {}).get("input") or {}).get("assignments") or []
    for entry in assignments:
        if not isinstance(entry, dict):
            continue
        note, family = entry.get("note"), entry.get("family")
        if note in notes and family in FLAVOR_FAMILIES:
            assigned[note] = family
    return {n: assigned.get(n, "Other") for n in notes}
