#!/usr/bin/env python3
"""
_wf_recover.py — Workflow Journal 提取引擎
由 wf-recover.sh 调用。也可独立使用。
"""
import json, os, sys, glob

def extract_agent_output(jsonl_path):
    """Extract useful output from an agent transcript."""
    result = {
        "agent_id": os.path.basename(jsonl_path).replace(".jsonl", ""),
        "status": "unknown",
        "text_output": "",
        "structured_output": None,
        "tool_calls": [],
        "entry_count": 0,
        "thinking_chars": 0,
        "error": None
    }

    try:
        with open(jsonl_path) as f:
            entries = [json.loads(line) for line in f]
    except Exception as e:
        result["status"] = "unreadable"
        result["error"] = str(e)
        return result

    result["entry_count"] = len(entries)

    if len(entries) == 0:
        result["status"] = "empty"
        return result

    # Check if agent has any assistant entries
    assistant_entries = [e for e in entries if e.get("type") == "assistant"]
    if not assistant_entries:
        result["status"] = "no_response"
        return result

    # Process all assistant entries
    for e in assistant_entries:
        msg = e.get("message", {})
        content = msg.get("content", [])

        if isinstance(content, str):
            result["text_output"] += content
        elif isinstance(content, list):
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "text":
                    result["text_output"] += block.get("text", "")
                elif block.get("type") == "thinking":
                    result["thinking_chars"] += len(block.get("thinking", ""))
                elif block.get("type") == "tool_use":
                    tool_name = block.get("name", "?")
                    tool_input = block.get("input", {})
                    result["tool_calls"].append({
                        "name": tool_name,
                        "input_keys": list(tool_input.keys()) if isinstance(tool_input, dict) else []
                    })
                    # Capture StructuredOutput content
                    if tool_name == "StructuredOutput" and isinstance(tool_input, dict):
                        result["structured_output"] = tool_input
                    if "tools" in tool_input:
                        result["structured_output"] = tool_input

    # Infer status
    if result["tool_calls"]:
        last_tool = result["tool_calls"][-1]
        if last_tool["name"] == "StructuredOutput":
            if result["structured_output"]:
                result["status"] = "completed_structured"
            else:
                result["status"] = "partial_structured"
        else:
            result["status"] = "completed_tools"
    elif result["text_output"]:
        result["status"] = "completed_text"
    else:
        result["status"] = "thinking_only"

    return result


def recover(trans_dir, output_mode="summary", save_dir=None):
    """Main recovery function."""
    agent_files = sorted(glob.glob(os.path.join(trans_dir, "agent-*.jsonl")))
    journal_file = os.path.join(trans_dir, "journal.jsonl")

    results = [extract_agent_output(af) for af in agent_files]

    # Summary counts
    statuses = {}
    for r in results:
        s = r["status"]
        statuses[s] = statuses.get(s, 0) + 1

    # Extract prompts from journal
    prompts = {}
    if os.path.exists(journal_file):
        try:
            with open(journal_file) as f:
                for line in f:
                    entry = json.loads(line)
                    agent_id = entry.get("agentId", "")
                    key = entry.get("key", "")
                    if key:
                        prompts[agent_id] = key
        except:
            pass

    # Read meta files for labels
    for af in agent_files:
        meta_file = af.replace(".jsonl", ".meta.json")
        if os.path.exists(meta_file):
            try:
                with open(meta_file) as f:
                    meta = json.load(f)
                agent_id = os.path.basename(af).replace(".jsonl", "")
                if agent_id in prompts:
                    continue  # journal already has the label
                label = meta.get("label", "")
                if label:
                    prompts[agent_id] = label
            except:
                pass

    if output_mode == "json":
        output = {
            "transcript_dir": trans_dir,
            "total_agents": len(results),
            "status_summary": statuses,
            "recoverable": sum(1 for r in results if r["status"] in (
                "completed_structured", "completed_text", "completed_tools", "partial_structured"
            )),
            "lost": sum(1 for r in results if r["status"] in ("no_response", "empty")),
            "total_thinking_chars": sum(r["thinking_chars"] for r in results),
            "agents": []
        }
        for r in results:
            agent_data = {
                "agent_id": r["agent_id"],
                "label": prompts.get(r["agent_id"], r["agent_id"][:12]),
                "status": r["status"],
                "entry_count": r["entry_count"],
                "thinking_chars": r["thinking_chars"],
                "tool_calls": [t["name"] for t in r["tool_calls"]],
            }
            if r["text_output"]:
                agent_data["text_preview"] = r["text_output"][:200]
            if r["structured_output"]:
                so = r["structured_output"]
                if "tools" in so:
                    tools = so["tools"]
                    if isinstance(tools, list):
                        agent_data["structured_summary"] = f"{len(tools)} tools found"
                    else:
                        agent_data["structured_summary"] = "tools field present (non-list)"
                else:
                    agent_data["structured_summary"] = ", ".join(list(so.keys())[:5])
            if r["error"]:
                agent_data["error"] = r["error"]
            output["agents"].append(agent_data)
        print(json.dumps(output, ensure_ascii=False, indent=2))

    elif output_mode == "summary":
        print(f"Workflow Recovery Report")
        print(f"Transcript: {os.path.basename(trans_dir)}")
        print(f"Total agents: {len(results)}")
        print()
        for status, count in sorted(statuses.items()):
            icon = {
                "completed_structured": "OK", "completed_text": "OK", "completed_tools": "OK",
                "partial_structured": "??", "thinking_only": "..", "no_response": "XX",
                "empty": "--", "unreadable": "!!"
            }.get(status, "?")
            print(f"  [{icon}] {status}: {count}")
        print()
        recoverable = sum(1 for r in results if r["status"] in (
            "completed_structured", "completed_text", "completed_tools", "partial_structured"
        ))
        lost = sum(1 for r in results if r["status"] in ("no_response", "empty"))
        print(f"Recoverable: {recoverable} | Lost: {lost}")
        print(f"Thinking tokens burned: {sum(r['thinking_chars'] for r in results):,} chars")
        print()

        for r in results:
            icon = {
                "completed_structured": "OK", "completed_text": "OK", "completed_tools": "OK",
                "partial_structured": "??", "thinking_only": "..", "no_response": "XX",
                "empty": "--"
            }.get(r["status"], "?")
            label = prompts.get(r["agent_id"], r["agent_id"][:12])
            tools = ", ".join(t["name"] for t in r["tool_calls"]) if r["tool_calls"] else "none"
            so_note = ""
            if r.get("structured_output"):
                so = r["structured_output"]
                if "tools" in so and isinstance(so["tools"], list):
                    so_note = f" [{len(so['tools'])} tools]"
            print(f"  [{icon}] {label:35s} {r['status']:25s} tools={tools}{so_note}")

    elif output_mode == "full":
        print(f"Workflow: {os.path.basename(trans_dir)}")
        print(f"{len(results)} agents total")
        print()
        for r in results:
            if r["structured_output"]:
                label = prompts.get(r["agent_id"], r["agent_id"][:12])
                print(f"--- {label} [{r['status']}] ---")
                so = r["structured_output"]
                if "tools" in so:
                    tools = so["tools"]
                    if isinstance(tools, list):
                        for i, t in enumerate(tools[:5]):
                            if isinstance(t, dict):
                                name = t.get("name", "?")
                                score = t.get("automationScore", "?")
                                cli = str(t.get("cliEntry", "?"))[:40]
                                engine = str(t.get("sharedEngine", "?"))[:60]
                                print(f"  {i+1}. {name:25s} score={score} cli={cli}")
                                print(f"     engine: {engine}")
                            elif isinstance(t, str):
                                print(f"  {i+1}. {t}")
                        if len(tools) > 5:
                            print(f"  ... and {len(tools)-5} more")
                    else:
                        print(f"  {so['tools']}")
                else:
                    print(f"  Keys: {list(so.keys())}")
                print()
            elif r["text_output"]:
                label = prompts.get(r["agent_id"], r["agent_id"][:12])
                print(f"--- {label} [{r['status']}] ---")
                print(r["text_output"][:500])
                print()

    # Save to directory
    if save_dir:
        os.makedirs(save_dir, exist_ok=True)
        saved = 0
        for r in results:
            if r["structured_output"] or r["text_output"]:
                outfile = os.path.join(save_dir, f"{r['agent_id']}.json")
                with open(outfile, "w") as f:
                    json.dump({
                        "agent_id": r["agent_id"],
                        "label": prompts.get(r["agent_id"], "?"),
                        "status": r["status"],
                        "structured_output": r["structured_output"],
                        "text_output": r["text_output"][:2000] if r["text_output"] else ""
                    }, f, ensure_ascii=False, indent=2)
                saved += 1
        print(f"\nSaved {saved} agent outputs to {save_dir}")


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="Workflow Journal Recovery")
    ap.add_argument("transcript_dir", help="Path to Workflow transcript directory")
    ap.add_argument("--json", action="store_true", help="JSON output")
    ap.add_argument("--summary", action="store_true", help="Summary mode (default)")
    ap.add_argument("--full", action="store_true", help="Full output with extracted data")
    ap.add_argument("--save", type=str, default=None, help="Save extracted outputs to directory")
    args = ap.parse_args()

    mode = "summary"
    if args.json:
        mode = "json"
    elif args.full:
        mode = "full"

    recover(args.transcript_dir, mode, args.save)
