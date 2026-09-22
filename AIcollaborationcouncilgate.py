import os
import sys
import json
import asyncio
from typing import Dict, Any

# ==========================================
# Client Initializations
# ==========================================

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
NIM_API_KEY = os.getenv("NIM_API_KEY")
NIM_BASE_URL = os.getenv("NIM_BASE_URL", "https://integrate.api.nvidia.com/v1")

SYSTEM_PROMPT = """You are a strict voting member of the AI Collaboration Council.
Your task is to inspect the submitted git diff and context for:
1. Syntax correctness and breaking logic.
2. In-memory continuation-resolution schema compliance.
3. Obvious bugs, security vulnerabilities, or regression risks.

You MUST reply ONLY with valid JSON in this exact structure:
{"vote": "APPROVE" | "REJECT", "reason": "<Concise 1-2 sentence explanation>"}"""


def parse_vote_response(raw_text: str, provider: str) -> Dict[str, Any]:
    """Helper to safely parse JSON response from models."""
    try:
        cleaned = raw_text.strip()
        if "```json" in cleaned:
            cleaned = cleaned.split("```json")[1].split("```")[0].strip()
        elif "```" in cleaned:
            cleaned = cleaned.split("```")[1].split("```")[0].strip()
        
        data = json.loads(cleaned)
        vote = data.get("vote", "REJECT").upper()
        if vote not in ["APPROVE", "REJECT"]:
            vote = "REJECT"
        return {"provider": provider, "vote": vote, "reason": data.get("reason", "No reason supplied.")}
    except Exception as e:
        return {"provider": provider, "vote": "REJECT", "reason": f"Failed to parse JSON response: {str(e)}"}


# ==========================================
# Model Evaluators
# ==========================================

async def evaluate_gemini(diff_payload: str) -> Dict[str, Any]:
    if not GEMINI_API_KEY:
        return {"provider": "gemini", "vote": "ABSTAIN", "reason": "GEMINI_API_KEY missing."}
    
    try:
        from google import genai
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        prompt = f"{SYSTEM_PROMPT}\n\nGit Diff to review:\n{diff_payload}"
        
        # Async execution offload
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(
            None,
            lambda: client.models.generate_content(
                model="gemini-2.5-flash",
                contents=prompt
            )
        )
        return parse_vote_response(response.text, "gemini")
    except Exception as err:
        return {"provider": "gemini", "vote": "REJECT", "reason": f"Execution error: {str(err)}"}


async def evaluate_anthropic(diff_payload: str) -> Dict[str, Any]:
    if not ANTHROPIC_API_KEY:
        return {"provider": "anthropic", "vote": "ABSTAIN", "reason": "ANTHROPIC_API_KEY missing."}
    
    try:
        from anthropic import AsyncAnthropic
        client = AsyncAnthropic(api_key=ANTHROPIC_API_KEY)
        
        message = await client.messages.create(
            model="claude-3-5-sonnet-latest",
            max_tokens=256,
            system=SYSTEM_PROMPT,
            messages=[
                {"role": "user", "content": f"Review this git diff:\n\n{diff_payload}"}
            ]
        )
        raw_text = message.content[0].text
        return parse_vote_response(raw_text, "anthropic")
    except Exception as err:
        return {"provider": "anthropic", "vote": "REJECT", "reason": f"Execution error: {str(err)}"}


async def evaluate_openai(diff_payload: str) -> Dict[str, Any]:
    if not OPENAI_API_KEY:
        return {"provider": "openai", "vote": "ABSTAIN", "reason": "OPENAI_API_KEY missing."}
    
    try:
        from openai import AsyncOpenAI
        client = AsyncOpenAI(api_key=OPENAI_API_KEY)
        
        response = await client.chat.completions.create(
            model="gpt-4o",
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Review this git diff:\n\n{diff_payload}"}
            ],
            temperature=0.1
        )
        raw_text = response.choices[0].message.content
        return parse_vote_response(raw_text, "openai")
    except Exception as err:
        return {"provider": "openai", "vote": "REJECT", "reason": f"Execution error: {str(err)}"}


async def evaluate_nim(diff_payload: str) -> Dict[str, Any]:
    if not NIM_API_KEY:
        return {"provider": "nim", "vote": "ABSTAIN", "reason": "NIM_API_KEY missing."}
    
    try:
        from openai import AsyncOpenAI
        # NIM exposes standard OpenAI-compatible completions
        client = AsyncOpenAI(
            base_url=NIM_BASE_URL,
            api_key=NIM_API_KEY
        )
        
        response = await client.chat.completions.create(
            model="meta/llama-3.1-70b-instruct",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Review this git diff:\n\n{diff_payload}"}
            ],
            temperature=0.1
        )
        raw_text = response.choices[0].message.content
        return parse_vote_response(raw_text, "nim")
    except Exception as err:
        return {"provider": "nim", "vote": "REJECT", "reason": f"Execution error: {str(err)}"}


# ==========================================
# Orchestrator
# ==========================================

async def run_council(diff_text: str):
    # Cap diff to 8,000 characters to prevent prompt blowout
    truncated_diff = diff_text[:8000] if diff_text.strip() else "Empty diff."

    print("==================================================")
    print("      AI Collaboration Council Review Gate        ")
    print("==================================================")

    tasks = [
        evaluate_gemini(truncated_diff),
        evaluate_anthropic(truncated_diff),
        evaluate_openai(truncated_diff),
        evaluate_nim(truncated_diff)
    ]

    results = await asyncio.gather(*tasks)

    approvals = 0
    rejections = 0
    abstentions = 0

    for res in results:
        prov = res["provider"].upper().ljust(10)
        vote = res["vote"]
        reason = res["reason"]

        if vote == "APPROVE":
            color = "\033[92m" # Green
            approvals += 1
        elif vote == "REJECT":
            color = "\033[91m" # Red
            rejections += 1
        else:
            color = "\033[93m" # Yellow
            abstentions += 1
            
        print(f"[{prov}] {color}{vote:<8}\033[0m : {reason}")

    print("--------------------------------------------------")
    print(f"Final Tallies -> Approve: {approvals} | Reject: {rejections} | Abstain: {abstentions}")

    # Gate policy: Push fails if ANY active reviewer rejects
    if rejections > 0:
        print("\033[91m\n[GATE FAILED] Council consensus was not reached. Push blocked.\033[0m")
        sys.exit(1)
    
    if approvals == 0:
        print("\033[93m\n[GATE WARNING] All models abstained (check API keys). Clearance allowed with caution.\033[0m")
        sys.exit(0)

    print("\033[92m\n[GATE PASSED] All active members approved. Safe to push.\033[0m")
    sys.exit(0)


if __name__ == "__main__":
    stdin_data = sys.stdin.read() if not sys.stdin.isatty() else ""
    asyncio.run(run_council(stdin_data))