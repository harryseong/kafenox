import json
import os

import boto3
from aws_lambda_powertools import Logger, Tracer
from kafenox_common.models import CoffeeModel

logger = Logger()
tracer = Tracer()

bedrock = boto3.client("bedrock-runtime")

MAX_HISTORY_TURNS = 20
MAX_TURN_CHARS = 2000

# System prompt taken from the v3 design's Ask AI spec.
SYSTEM_PROMPT = (
    "You are the insights assistant inside a personal coffee-logging app. "
    "The user's cupping log:\n\n{log}\n\n"
    "Answer questions about their coffee preferences and give recommendations "
    "grounded in this log. Be specific and concise: 2-4 short sentences. "
    "Plain text only, no markdown, no preamble."
)


def _log_line(item: CoffeeModel) -> str:
    name = item.coffeeName or "Unknown coffee"
    head = f"- {name}" + (f" ({item.roaster})" if item.roaster else "")
    parts = [head]
    origin = ", ".join(p for p in [item.originRegion, item.originCountry] if p)
    if origin:
        parts.append(origin)
    if item.roastLevel:
        parts.append(f"{item.roastLevel} roast")
    if item.process:
        parts.append(f"{item.process} process")
    if item.flavorNotes:
        parts.append("flavors: " + ", ".join(item.flavorNotes))
    if item.rating is not None:
        parts.append(f"my rating: {int(item.rating)}/10")
    return " · ".join(parts)


def _build_log_summary() -> str:
    items = CoffeeModel.scan(filter_condition=CoffeeModel.status == "COMPLETE")
    lines = [_log_line(item) for item in items]
    return "\n".join(lines) if lines else "(no coffees logged yet)"


def _conversation(history: list, question: str) -> list:
    """Build Converse messages: sanitized history + the new question.
    Converse requires strictly alternating roles starting with 'user', so
    consecutive same-role turns are merged and leading assistant turns
    dropped."""
    turns = []
    for turn in history[-MAX_HISTORY_TURNS:]:
        role = turn.get("role") if isinstance(turn, dict) else None
        text = (turn.get("text") or "").strip() if isinstance(turn, dict) else ""
        if role in ("user", "assistant") and text:
            turns.append((role, text[:MAX_TURN_CHARS]))
    turns.append(("user", question[:MAX_TURN_CHARS]))

    messages = []
    for role, text in turns:
        if messages and messages[-1]["role"] == role:
            messages[-1]["content"][0]["text"] += "\n" + text
        else:
            messages.append({"role": role, "content": [{"text": text}]})
    while messages and messages[0]["role"] != "user":
        messages.pop(0)
    return messages


def _response(status: int, payload: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"message": "Invalid JSON body"})

    question = (body.get("question") or "").strip()
    if not question:
        return _response(400, {"message": "question is required"})

    messages = _conversation(body.get("history") or [], question)
    system_prompt = SYSTEM_PROMPT.format(log=_build_log_summary())

    try:
        response = bedrock.converse(
            modelId=os.environ["BEDROCK_INSIGHTS_MODEL_ID"],
            system=[{"text": system_prompt}],
            messages=messages,
            inferenceConfig={"maxTokens": 600},
        )
        content_blocks = response["output"]["message"]["content"]
        answer = "".join(b.get("text", "") for b in content_blocks).strip()
    except Exception:
        logger.exception("Bedrock insights call failed")
        return _response(502, {"message": "Model request failed"})

    if not answer:
        return _response(502, {"message": "Model returned no answer"})

    logger.info("Answered insights question", history_turns=len(messages) - 1)
    return _response(200, {"answer": answer})
