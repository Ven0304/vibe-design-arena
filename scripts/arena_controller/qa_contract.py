from __future__ import annotations
from pathlib import Path
from typing import Any
from .errors import ArenaError
from .paths import absolute_path, child_path
from .schema import SchemaRegistry

STANDARD=("mobile","tablet","desktop")
UNIVERSAL=("primary","dense","touch-targets","keyboard-traversal","focus-visibility","focus-return","reduced-motion","rapid-toggle")
PRODUCT=("loading","empty","error","disabled","stale-data","long-text","missing-value","negative-number","extreme-number","container-overflow")

def validate_qa_result(result:dict[str,Any],*,schemas:SchemaRegistry,expected_arena_id:str,expected_style:str,expected_generation:int,expected_commit:str,result_path:str|Path,evidence_root:str|Path)->None:
    schemas.validate("qa-result",result)
    expected=(('arenaId',expected_arena_id),('style',expected_style),('candidateGeneration',expected_generation),('candidateCommit',expected_commit))
    for k,v in expected:
        if result.get(k)!=v:raise ArenaError(f"QA result identity mismatch for {k}. Expected {v!r}; got {result.get(k)!r}.")
    root=absolute_path(evidence_root,must_exist=True);child_path(root,result_path)
    if absolute_path(result["outputRoot"],must_exist=True)!=root:raise ArenaError("QA result outputRoot must be the registered candidate evidence directory.")
    if bool(result["environmentBlocked"])!=(result["overall"]=="BLOCKED"):raise ArenaError("QA result environmentBlocked is inconsistent with overall.")
    proxy=result["proxyDisclosure"]
    if proxy["name"]!="equivalent-200-percent-layout" or proxy["isRealBrowserZoom"] is not False or proxy["deviceScaleFactor"]!=1:raise ArenaError("QA result misstates the equivalent-200-percent-layout proxy.")
    evidence={}
    for item in result["evidence"]:
        if not item.get("id"):raise ArenaError("QA evidence item is missing id.")
        if item["id"] in evidence:raise ArenaError(f"Duplicate QA evidence ID: {item['id']}")
        evidence[item["id"]]=item
    executed=failed=0
    for check in result["checks"]:
        if check["applicability"] not in ("required","applicable","not-applicable"):raise ArenaError(f"QA check has invalid applicability: {check['id']}")
        for eid in check["evidenceIds"]:
            if eid not in evidence:raise ArenaError(f"QA check references unknown evidence ID: {eid}")
        if check["applicability"]=="not-applicable":
            if check["status"]!="NOT-APPLICABLE" or not str(check.get("reason") or '').strip() or not str(check.get("approvedBy") or '').strip() or not check["evidenceIds"]:raise ArenaError(f"Invalid not-applicable QA declaration: {check['id']}")
        else:
            executed+=1
            if check["status"] not in ("PASS","FAIL","BLOCKED"):raise ArenaError(f"Executable QA check has invalid status: {check['id']}")
            if check["status"]!="PASS":failed+=1
    if not result["checks"]:raise ArenaError("QA result contains no checks.")
    if result["coverage"]["executed"]!=executed or result["coverage"]["failed"]!=failed:raise ArenaError("QA result coverage counters do not match the check records.")
    if result["overall"]=="PASS" and failed:raise ArenaError("QA result claims PASS while an executable check did not pass.")
    if result["overall"]=="FAIL" and not failed:raise ArenaError("QA result claims FAIL without a failed executable check.")
    if result["overall"]=="BLOCKED" and not any(x["status"]=="BLOCKED" for x in result["checks"]):raise ArenaError("QA result claims BLOCKED without a blocked check.")
    if result["overall"]=="PASS":
        ids=[x["id"] for x in result["checks"]]
        if len(ids)!=len(set(ids)):raise ArenaError("Passing QA result contains duplicate check IDs.")
        for scenario in UNIVERSAL:
            for viewport in STANDARD:
                matches=[x for x in result["checks"] if x["scenarioId"]==scenario and x.get("viewportId")==viewport and x["applicability"]=="required" and x["status"]=="PASS"]
                if len(matches)!=1:raise ArenaError(f"Passing QA result lacks exactly one required PASS for {scenario} at {viewport}.")
        proxy_checks=[x for x in result["checks"] if x["scenarioId"]=="equivalent-200-percent-layout" and x.get("viewportId")=="desktop-equivalent-200-percent" and x["applicability"]=="required" and x["status"]=="PASS"]
        if len(proxy_checks)!=1:raise ArenaError("Passing QA result lacks the required equivalent-200-percent-layout proxy check.")
        for scenario in PRODUCT:
            checks=[x for x in result["checks"] if x["scenarioId"]==scenario]
            if not checks:raise ArenaError(f"Passing QA result omits product-state declaration: {scenario}")
            na=[x for x in checks if x["applicability"]=="not-applicable" and x["status"]=="NOT-APPLICABLE"]
            if na:
                if len(na)!=1 or len(checks)!=1:raise ArenaError(f"Product state {scenario} must be either one valid N/A declaration or executed checks, not both.")
            else:
                for viewport in STANDARD:
                    matches=[x for x in checks if x.get("viewportId")==viewport and x["applicability"] in ("required","applicable") and x["status"]=="PASS"]
                    if len(matches)!=1:raise ArenaError(f"Passing QA result lacks exactly one executed PASS for {scenario} at {viewport}.")
        for check in (x for x in result["checks"] if x["applicability"] in ("required","applicable")):
            types=[str(x.get("type")) for x in check["assertions"]]
            for required in ("overflow","axe","browser-errors"):
                if required not in types:raise ArenaError(f"Passing QA check {check['id']} lacks required {required} evidence.")
            refs=[evidence[x] for x in check["evidenceIds"]]
            if not any(x["kind"]=="screenshot" for x in refs):raise ArenaError(f"Passing QA check {check['id']} lacks screenshot evidence.")
            if not any(x["kind"]=="axe" for x in refs):raise ArenaError(f"Passing QA check {check['id']} lacks axe evidence.")
    for item in evidence.values():
        path=item.get("path")
        if item["kind"]=="screenshot":
            if not str(path or '').strip():raise ArenaError(f"Screenshot evidence is missing a path: {item['id']}")
            child_path(root,absolute_path(path,must_exist=True))
        elif path and not Path(path).is_file():raise ArenaError(f"QA evidence path does not exist: {path}")
    if result["overall"]=="PASS":
        for viewport in (*STANDARD,"desktop-equivalent-200-percent"):
            if not any(x["kind"]=="screenshot" and x.get("viewportId")==viewport for x in evidence.values()):raise ArenaError(f"Passing QA result lacks screenshot evidence for viewport: {viewport}")
