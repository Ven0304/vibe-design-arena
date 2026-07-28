from __future__ import annotations

import os, shutil, socket, subprocess, time, urllib.request, uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

from .constants import CONTROLLER_COMMANDS, STYLES
from .errors import ArenaError
from .git import Git
from .integrity import DEFAULT_REFERENCE_FILES, canonical_text_facts, check_brief_attributes, reference_snapshot, sha256_file, utc_now
from .paths import absolute_path, assert_run_root_outside_repository, child_path
from .process import ProcessIdentity, ProcessSupervisor, validate_environment
from .qa_contract import validate_qa_result
from .records import write_derived_records
from .schema import SchemaRegistry
from .state import empty_review, invalidate_candidate_evidence
from .storage import StateStore, append_event, read_json, write_utf8_lf


def status_summary(s):
    r=s["repository"]
    return {"arenaId":s["arenaId"],"stateRevision":s["stateRevision"],"stage":s["stage"],"status":s["status"],"blockingReason":s.get("blockingReason"),"baseBranch":r["baseBranch"],"baseSha":r["baseSha"],"selection":s.get("selection"),"styles":s["styles"],"publication":s["publication"]}

def _style(s,n):
    try:return s["styles"][n]
    except KeyError as e:raise ArenaError(f"Unknown style in state: {n}") from e

def _review(): return empty_review()
def _pub(): return {k:{"published":False,"remote":None,"remoteSha":None,"publishedAt":None} for k in ("main",*STYLES)}
def _new_style(n,root):
    return {"branch":n,"worktree":str(root/n),"dispatchId":None,"candidateGeneration":1,"brief":{"frozenPath":None,"approvedSha256":None,"commit":None},"implementationCommit":None,"builderResultPath":None,"qaResultPath":None,"qaResultSha256":None,"preview":{"executable":None,"args":[],"port":None,"url":None,"pid":None,"processStartTimeUtc":None,"stdoutLog":None,"stderrLog":None,"httpStatus":None,"environmentBlocked":False,"lastError":None,"retryCommand":None},"reviews":{"visual":_review(),"direction":_review()},"qualification":{"briefIntegrity":"PENDING","validation":"PENDING","automatedQa":"PENDING","mainAgentVisualReview":"PENDING","directionConsistencyReview":"PENDING","overall":"PENDING"},"retainedCommit":None}
def _config(): return {"preview":{},"validation":[],"referenceFiles":list(DEFAULT_REFERENCE_FILES)}
def _req(o,k,msg):
    v=o.get(k)
    if v is None or v==[] or isinstance(v,str) and not v.strip(): raise ArenaError(msg)
    return v
def _iso(x): return datetime.fromtimestamp(x,timezone.utc).isoformat().replace("+00:00","Z")
def _epoch(x): return datetime.fromisoformat(x.replace("Z","+00:00")).timestamp()
def _ident(st):
    p=st["preview"]; return ProcessIdentity(int(p["pid"]),_epoch(p["processStartTimeUtc"]),str(p["executable"]),tuple(map(str,p.get("args") or [])),str(st["worktree"]))
def _port(port):
    try:
        with socket.create_connection(("127.0.0.1",port),timeout=.3):return True
    except OSError:return False
def _probe(url):
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    for _ in range(10):
        try:
            with opener.open(url,timeout=3) as r:return int(r.status)
        except Exception:time.sleep(.5)
    return 0
def _run_spec(spec,cwd):
    exe=spec.get("executable")
    if not exe:raise ArenaError("Command spec requires executable.")
    wd=str(spec.get("workingDirectory") or cwd)
    if not wd:raise ArenaError("Command spec requires workingDirectory.")
    args=list(map(str,spec.get("args") or [])); env=os.environ.copy();env.update(validate_environment(spec.get("environment"))); started=utc_now()
    try:r=subprocess.run([str(exe),*args],cwd=absolute_path(wd,must_exist=True),env=env,shell=False,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=False)
    except OSError as e:raise ArenaError(f"Unable to execute command spec: {e}") from e
    return {"executable":str(exe),"args":args,"workingDirectory":wd,"startedAt":started,"completedAt":utc_now(),"exitCode":r.returncode,"status":"PASS" if r.returncode==0 else "FAIL","output":r.stdout.decode("utf-8",errors="replace").rstrip()}

class Controller:
    """Canonical Python controller implementation."""
    def __init__(self,*,schemas=None,git=None,processes=None):self.schemas=schemas or SchemaRegistry();self.git=git or Git();self.processes=processes or ProcessSupervisor()
    def _store(self,p):return StateStore(p,schemas=self.schemas,record_writer=write_derived_records)
    def execute(self,command,options):
        if command not in CONTROLLER_COMMANDS:raise ArenaError(f"Unknown controller command: {command}")
        p=str(absolute_path(options["state"]))
        try:return getattr(self,f"cmd_{command.replace('-','_')}")(p,options)
        except Exception as e:
            try:
                rev=int(read_json(p)["stateRevision"]) if Path(p).is_file() else -1;append_event(p,command,"failure",revision=rev,message=str(e))
            except Exception:pass
            if isinstance(e,ArenaError):raise
            raise ArenaError(str(e)) from e
    def cmd_status(self,p,o):return status_summary(self._store(p).read())
    def _attrs(self,repo):
        path=Path(repo)/".gitattributes"; text=path.read_text(encoding="utf-8") if path.exists() else ""
        if text and not text.endswith("\n"):text+="\n"
        write_utf8_lf(path,text+"/DESIGN_BRIEF.md text eol=lf\n");self.git.run(repo,("add","--",".gitattributes"));staged=self.git.run(repo,("diff","--cached","--name-only")).stdout
        if staged!=".gitattributes":raise ArenaError(f"Preflight staged unexpected files:\n{staged}")
        self.git.run(repo,("commit","-m","Enforce LF for Vibe Design Arena briefs","--",".gitattributes"))
    def cmd_preflight(self,p,o):
        store=self._store(p);target=Path(p)
        if target.exists():
            def resume(s):
                if s["stage"]!="preflight":raise ArenaError("preflight can only resume during the preflight stage.")
                repo=s["repository"]["root"];dirty=self.git.run(repo,("status","--porcelain","--untracked-files=all")).stdout
                if dirty:raise ArenaError(f"Repository must be clean before resumed preflight:\n{dirty}")
                if not check_brief_attributes(repo,git=self.git)["valid"]:
                    if not o.get("apply_attributes"):raise ArenaError("Rerun with --apply-attributes only after the user confirms the generated patch.")
                    self._attrs(repo)
                if not check_brief_attributes(repo,git=self.git)["valid"]:raise ArenaError("DESIGN_BRIEF.md attributes remain invalid.")
                dirty=self.git.run(repo,("status","--porcelain","--untracked-files=all")).stdout
                if dirty:raise ArenaError(f"Repository is not clean after preflight:\n{dirty}")
                s["repository"]["baseBranch"]=self.git.run(repo,("branch","--show-current")).stdout;s["repository"]["baseSha"]=self.git.run(repo,("rev-parse","HEAD")).stdout;s["status"]="ready";s["blockingReason"]=None
            return store.mutate(operation="preflight",expected_revision=int(o["expected_revision"]),mutation=resume)
        repo=absolute_path(_req(o,"repo","preflight requires --repo when creating a new Arena state."),must_exist=True);gitroot=absolute_path(self.git.run(repo,("rev-parse","--show-toplevel")).stdout,must_exist=True)
        if os.path.normcase(str(repo))!=os.path.normcase(str(gitroot)):raise ArenaError(f"--repo must be the product Git root. Requested={repo} GitRoot={gitroot}")
        inside=self.git.run(repo,("rev-parse","--is-inside-work-tree"),allow_failure=True)
        if inside.exit_code or inside.stdout!="true":raise ArenaError(f"Not a Git worktree: {repo}")
        if self.git.run(repo,("rev-parse","HEAD"),allow_failure=True).exit_code:raise ArenaError("Repository has no baseline commit.")
        dirty=self.git.run(repo,("status","--porcelain","--untracked-files=all")).stdout
        if dirty:raise ArenaError(f"Repository must be clean before preflight:\n{dirty}")
        records=target.parent
        if records.name!="records":raise ArenaError("State must be stored at ARENA_RUN_ROOT/records/arena-state.json.")
        run=records.parent;assert_run_root_outside_repository(run,repo);work=run/"worktrees"
        for x in (records,work,records/"briefs",records/"candidates",records/"evidence",records/"generated"):x.mkdir(parents=True,exist_ok=True)
        config=read_json(o["config"]) if o.get("config") else _config();config.setdefault("preview",{});config.setdefault("validation",[]);refs=config.get("referenceFiles",list(DEFAULT_REFERENCE_FILES));skill=o.get("skill_root") or str(Path(__file__).resolve().parents[2]);attr=check_brief_attributes(repo,git=self.git)
        s={"schemaVersion":"1.0","stateRevision":0,"arenaId":uuid.uuid4().hex,"stage":"preflight","status":"ready","blockingReason":None,"createdAt":utc_now(),"updatedAt":utc_now(),"paths":{"runRoot":str(run),"recordsRoot":str(records),"worktreeRoot":str(work),"stateFile":p,"eventLog":str(records/"events.jsonl")},"repository":{"root":str(repo),"baseBranch":None,"baseSha":None},"skillSnapshot":reference_snapshot(skill,refs,git=self.git),"configuration":config,"styles":{n:_new_style(n,work) for n in STYLES},"selection":{"style":None,"branch":None,"selectedAt":None},"merge":{"status":"PENDING","method":None,"preMergeSha":None,"postMergeSha":None,"conflicts":[],"validation":[]},"cleanup":{"completedAt":None,"removedWorktrees":[]},"publication":_pub(),"handoff":{"generatedAt":None,"patchPath":None}}
        if not attr["valid"] and not o.get("apply_attributes"):
            patch=records/"generated"/"gitattributes.patch";write_utf8_lf(patch,"Required product-repository patch:\n\n--- .gitattributes\n+++ .gitattributes\n@@\n+/DESIGN_BRIEF.md text eol=lf\n");s["status"]="blocked";s["blockingReason"]=f"Confirm the generated .gitattributes patch, then rerun preflight with --apply-attributes. Patch: {patch}";return store.create(s,operation="preflight")
        if not attr["valid"]:self._attrs(str(repo))
        if not check_brief_attributes(repo,git=self.git)["valid"]:raise ArenaError("DESIGN_BRIEF.md text/eol attributes are still invalid.")
        dirty=self.git.run(repo,("status","--porcelain","--untracked-files=all")).stdout
        if dirty:raise ArenaError(f"Repository is not clean after .gitattributes handling:\n{dirty}")
        s["repository"]["baseBranch"]=self.git.run(repo,("branch","--show-current")).stdout
        if not s["repository"]["baseBranch"]:raise ArenaError("Detached HEAD is not supported for Arena base.")
        s["repository"]["baseSha"]=self.git.run(repo,("rev-parse","HEAD")).stdout;return store.create(s,operation="preflight")
    def cmd_create_worktrees(self,p,o):
        store=self._store(p);root=absolute_path(o.get("brief_root") or Path(p).parent/"briefs",must_exist=True);cur=store.read();expected=int(o["expected_revision"])
        if cur["stage"]=="preflight":
            def approve(s):
                if not s["repository"]["baseSha"]:raise ArenaError("preflight has not recorded the final BASE_SHA.")
                for n in STYLES:
                    path=root/n/"DESIGN_BRIEF.md";facts=canonical_text_facts(path)
                    if not facts.canonical:raise ArenaError(f"Approved brief is not UTF-8/no-BOM/LF: {path}")
                    _style(s,n)["brief"].update({"frozenPath":facts.path,"approvedSha256":facts.sha256})
                s["stage"]="briefs-approved";s["status"]="ready"
            approved=store.mutate(operation="approve-briefs",expected_revision=expected,mutation=approve)
        elif cur["stage"]=="briefs-approved":
            if int(cur["stateRevision"])!=expected:raise ArenaError(f"State revision mismatch. Expected={expected} Actual={cur['stateRevision']}. Run status and retry.")
            approved=cur
        else:raise ArenaError(f"create-worktrees cannot run from stage {cur['stage']}.")
        def create(s):
            repo=s["repository"]["root"];dirty=self.git.run(repo,("status","--porcelain","--untracked-files=all")).stdout
            if dirty:raise ArenaError(f"Repository must remain clean before worktree creation:\n{dirty}")
            if self.git.run(repo,("rev-parse","HEAD")).stdout!=s["repository"]["baseSha"]:raise ArenaError("Main HEAD changed after preflight. Restart preflight to establish a new final BASE_SHA.")
            for n in STYLES:
                st=_style(s,n);child_path(s["paths"]["worktreeRoot"],st["worktree"])
                if self.git.run(repo,("show-ref","--verify",f"refs/heads/{st['branch']}"),allow_failure=True).exit_code==0:raise ArenaError(f"Style branch already exists: {st['branch']}")
                if Path(st["worktree"]).exists():raise ArenaError(f"Style worktree path already exists: {st['worktree']}")
            for n in STYLES:
                st=_style(s,n);self.git.run(repo,("worktree","add","-b",st["branch"],st["worktree"],s["repository"]["baseSha"]));target=Path(st["worktree"])/"DESIGN_BRIEF.md";shutil.copyfile(st["brief"]["frozenPath"],target)
                if sha256_file(target)!=st["brief"]["approvedSha256"]:raise ArenaError(f"Materialized brief hash mismatch for {n}")
                self.git.run(st["worktree"],("add","--","DESIGN_BRIEF.md"));self.git.run(st["worktree"],("commit","-m",f"Add approved Vibe Design Arena brief for {n}","--","DESIGN_BRIEF.md"));st["brief"]["commit"]=self.git.run(st["worktree"],("rev-parse","HEAD")).stdout
                if self.git.blob_sha256(st["worktree"],st["brief"]["commit"])!=st["brief"]["approvedSha256"]:raise ArenaError(f"Committed brief blob mismatch for {n}")
                if self.git.run(st["worktree"],("status","--porcelain","--untracked-files=all")).stdout:raise ArenaError(f"Worktree is dirty after brief commit for {n}")
                st["dispatchId"]=uuid.uuid4().hex;st["qualification"]["briefIntegrity"]="PASS"
            s["stage"]="worktrees-ready";s["status"]="ready"
        return store.mutate(operation="create-worktrees",expected_revision=int(approved["stateRevision"]),mutation=create)
    def cmd_import_builder_result(self,p,o):
        path=absolute_path(_req(o,"result_path","import-builder-result requires --result-path."),must_exist=True);r=read_json(path);self.schemas.validate("builder-result",r)
        def mutate(s):
            if s["stage"] not in ("worktrees-ready","building","previews-ready","qualifying"):raise ArenaError("Builder results can only be imported before selection.")
            if r.get("schemaVersion")!="1.0" or r.get("arenaId")!=s["arenaId"]:raise ArenaError("Builder result schema or Arena ID mismatch.")
            st=_style(s,str(r.get("style")))
            if st["preview"]["pid"]:raise ArenaError(f"Stop the recorded preview before importing a revised builder result for {r['style']}.")
            if r.get("dispatchId")!=st["dispatchId"] or int(r.get("candidateGeneration",0))!=int(st["candidateGeneration"]):raise ArenaError("Stale builder result: dispatch ID or candidate generation mismatch.")
            if r.get("branch")!=st["branch"] or r.get("briefCommit")!=st["brief"]["commit"] or r.get("briefSha256")!=st["brief"]["approvedSha256"]:raise ArenaError("Builder result branch or brief identity mismatch.")
            head=self.git.run(st["worktree"],("rev-parse","HEAD")).stdout
            if head!=r.get("implementationCommit"):raise ArenaError("Builder implementation commit does not match worktree HEAD.")
            if sha256_file(Path(st["worktree"])/"DESIGN_BRIEF.md")!=st["brief"]["approvedSha256"] or self.git.blob_sha256(st["worktree"],head)!=st["brief"]["approvedSha256"]:raise ArenaError("Builder changed the approved brief.")
            target=Path(s["paths"]["recordsRoot"])/"candidates"/str(r["style"])/"builder-result.json";target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target);st["builderResultPath"]=str(target);st["implementationCommit"]=head;st["qualification"]["briefIntegrity"]="PASS";st["qualification"]["validation"]="PASS" if r["validation"]["overall"]=="PASS" else "FAIL";invalidate_candidate_evidence(st);s["stage"]="building";s["status"]="ready";s["blockingReason"]=None
        return self._store(p).mutate(operation="import-builder-result",expected_revision=int(o["expected_revision"]),mutation=mutate)
    def cmd_start_previews(self,p,o):
        def mutate(s):
            if s["stage"] not in ("building","previews-ready","qualifying"):raise ArenaError("start-previews requires imported builder results.")
            ready=True
            for n in STYLES:
                st=_style(s,n)
                if not st["implementationCommit"]:raise ArenaError(f"Missing builder result for {n}")
                spec=s["configuration"].get("preview",{}).get(n)
                if not spec:raise ArenaError(f"Missing structured preview configuration for {n}")
                if not spec.get("executable"):raise ArenaError(f"Preview command requires executable for {n}")
                port=int(spec["port"]);args=[str(x).replace("{{PORT}}",str(port)) for x in spec.get("args") or []];url=str(spec.get("url") or f"http://127.0.0.1:{port}").replace("{{PORT}}",str(port));retry=subprocess.list2cmdline([str(spec["executable"]),*args])
                if st["preview"]["pid"]:
                    self.processes.verify(_ident(st));code=_probe(url);st["preview"].update({"httpStatus":code,"url":url})
                    if code==200:st["preview"].update({"environmentBlocked":False,"lastError":None})
                    if code==0:ready=False
                    continue
                if _port(port):raise ArenaError(f"Preview port is already occupied: {port}")
                logs=Path(s["paths"]["recordsRoot"])/"evidence"/n/"logs";out=logs/"preview.stdout.log";err=logs/"preview.stderr.log";env={k:str(v).replace("{{PORT}}",str(port)) for k,v in (spec.get("environment") or {}).items()}
                try:
                    ident=self.processes.start(str(spec["executable"]),args,working_directory=st["worktree"],environment=env,stdout_path=out,stderr_path=err);code=_probe(url);log=err.read_text(encoding="utf-8",errors="replace") if err.exists() else "";st["preview"].update({"executable":str(spec["executable"]),"args":args,"port":port,"url":url,"pid":ident.pid,"processStartTimeUtc":_iso(ident.processStartTimeUtc),"stdoutLog":str(out),"stderrLog":str(err),"httpStatus":code,"environmentBlocked":code==0 and ("spawn EPERM" in log or "duplicate" in log and "Path" in log),"lastError":log or None if code==0 else None,"retryCommand":retry})
                    if code==0:ready=False
                except Exception as e:st["preview"].update({"environmentBlocked":any(x in str(e) for x in ("EPERM","Path","permission")),"stderrLog":str(err),"httpStatus":0,"lastError":str(e),"retryCommand":retry});ready=False
            if ready:s["stage"]="previews-ready";s["status"]="ready";s["blockingReason"]=None
            else:s["status"]="blocked";s["blockingReason"]="One or more previews did not respond. Inspect recorded logs and retry the exact structured command with the required approval."
        return self._store(p).mutate(operation="start-previews",expected_revision=int(o["expected_revision"]),mutation=mutate)
    def cmd_stop_previews(self,p,o):
        def mutate(s):
            for n in STYLES:
                st=_style(s,n);pr=st["preview"]
                if pr["pid"]:
                    try:self.processes.stop(_ident(st))
                    except ArenaError as e:
                        if "no longer running" not in str(e):raise
                    pr["pid"]=None;pr["processStartTimeUtc"]=None;pr["httpStatus"]=0
            s["status"]="ready";s["blockingReason"]=None
        return self._store(p).mutate(operation="stop-previews",expected_revision=int(o["expected_revision"]),mutation=mutate)
    def _qa_evidence(self,st,ids,kind):
        if not st["qaResultPath"] or not Path(st["qaResultPath"]).is_file():raise ArenaError("Review signing requires an imported QA result.")
        h=sha256_file(st["qaResultPath"])
        if h!=st["qaResultSha256"]:raise ArenaError("Imported QA result changed after import; re-import it before signing.")
        qa=read_json(st["qaResultPath"]);index={x["id"]:x for x in qa["evidence"]}
        if len(index)!=len(qa["evidence"]):raise ArenaError("Duplicate QA evidence ID.")
        for x in ids:
            if x not in index:raise ArenaError(f"Review references unknown evidence ID: {x}")
        evidence=[index[x] for x in ids]
        if not any(x["kind"]=="screenshot" for x in evidence):raise ArenaError(f"{kind} review requires screenshot evidence.")
        if kind=="visual":
            for v in ("mobile","tablet","desktop"):
                if not any(x["kind"]=="screenshot" and x.get("viewportId")==v for x in evidence):raise ArenaError(f"Visual review must cite an inspected {v} screenshot.")
        if kind=="direction" and not any(x["kind"]=="design-brief" for x in evidence):raise ArenaError("Direction review must cite the frozen design-brief evidence.")
        return h
    def cmd_import_qa_result(self,p,o):
        path=absolute_path(_req(o,"result_path","import-qa-result requires --result-path."),must_exist=True);qa=read_json(path)
        def mutate(s):
            if s["stage"] not in ("previews-ready","qualifying"):raise ArenaError("QA results can only be imported after all previews are ready and before selection.")
            st=_style(s,str(qa.get("style")));head=self.git.run(st["worktree"],("rev-parse","HEAD")).stdout;evidence=Path(s["paths"]["recordsRoot"])/"evidence"/str(qa.get("style"))
            validate_qa_result(qa,schemas=self.schemas,expected_arena_id=s["arenaId"],expected_style=str(qa.get("style")),expected_generation=int(st["candidateGeneration"]),expected_commit=head,result_path=path,evidence_root=evidence)
            if head!=st["implementationCommit"]:raise ArenaError("QA candidate commit does not match imported builder commit.")
            target=Path(s["paths"]["recordsRoot"])/"candidates"/str(qa["style"])/"qa-results.json";target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target);st["qaResultPath"]=str(target);st["qaResultSha256"]=sha256_file(target);st["reviews"]={"visual":_review(),"direction":_review()};st["qualification"].update({"automatedQa":qa["overall"],"mainAgentVisualReview":"PENDING","directionConsistencyReview":"PENDING","overall":"PENDING"});s["stage"]="qualifying"
            if qa["overall"]=="BLOCKED":s["status"]="blocked";s["blockingReason"]=str(qa.get("blocker"))
            else:s["status"]="ready";s["blockingReason"]=None
        return self._store(p).mutate(operation="import-qa-result",expected_revision=int(o["expected_revision"]),mutation=mutate)
    def _sign(self,p,o,kind):
        label=f"sign-{kind}-review";msg=f"{label} requires --style, --result, --reviewer, --candidate-commit, and --evidence-ids.";name=_req(o,"style",msg);result=_req(o,"result",msg);reviewer=_req(o,"reviewer",msg);commit=_req(o,"candidate_commit",msg);ids=_req(o,"evidence_ids",msg)
        def mutate(s):
            if s["stage"]!="qualifying":raise ArenaError(f"{kind.capitalize()} review can only be signed during qualifying.")
            st=_style(s,name);head=self.git.run(st["worktree"],("rev-parse","HEAD")).stdout
            if commit!=st["implementationCommit"] or commit!=head:raise ArenaError(f"{kind.capitalize()} review candidate commit is stale.")
            h=self._qa_evidence(st,ids,kind);st["reviews"][kind]={"status":result,"reviewer":reviewer,"timestamp":utc_now(),"candidateCommit":commit,"qaResultSha256":h,"evidenceIds":list(ids)};st["qualification"]["mainAgentVisualReview" if kind=="visual" else "directionConsistencyReview"]=result;st["qualification"]["overall"]="PENDING";s["status"]="ready";s["blockingReason"]=None
        return self._store(p).mutate(operation=label,expected_revision=int(o["expected_revision"]),mutation=mutate)
    def cmd_sign_visual_review(self,p,o):return self._sign(p,o,"visual")
    def cmd_sign_direction_review(self,p,o):return self._sign(p,o,"direction")
    def cmd_qualify(self,p,o):
        name=_req(o,"style","qualify requires --style.")
        def mutate(s):
            if s["stage"]!="qualifying":raise ArenaError("qualify can only run during qualifying.")
            st=_style(s,name);head=self.git.run(st["worktree"],("rev-parse","HEAD")).stdout
            if head!=st["implementationCommit"]:invalidate_candidate_evidence(st);s["stage"]="building";s["status"]="blocked";s["blockingReason"]=f"{name} changed after builder import. Import a builder result for commit {head}; old QA and review signatures are invalid.";return
            q=st["qualification"];q["briefIntegrity"]="PASS" if sha256_file(Path(st["worktree"])/"DESIGN_BRIEF.md")==st["brief"]["approvedSha256"] and self.git.blob_sha256(st["worktree"],head)==st["brief"]["approvedSha256"] else "FAIL"
            if st["qaResultPath"] and Path(st["qaResultPath"]).is_file() and sha256_file(st["qaResultPath"])==st["qaResultSha256"]:q["automatedQa"]=read_json(st["qaResultPath"])["overall"]
            else:q["automatedQa"]="PENDING"
            for kind,gate in (("visual","mainAgentVisualReview"),("direction","directionConsistencyReview")):
                r=st["reviews"][kind];q[gate]=r["status"] if r["candidateCommit"]==head and r["qaResultSha256"]==st["qaResultSha256"] else "PENDING"
            q["overall"]="PASS" if all(q[x]=="PASS" for x in ("briefIntegrity","validation","automatedQa","mainAgentVisualReview","directionConsistencyReview")) else "FAIL"
            if all(_style(s,n)["qualification"]["overall"]=="PASS" for n in STYLES):s["stage"]="selection-ready";s["status"]="ready";s["blockingReason"]=None
            elif q["overall"]=="PASS":s["stage"]="qualifying";s["status"]="ready";s["blockingReason"]=None
            else:s["stage"]="qualifying";s["status"]="blocked";s["blockingReason"]=f"{name} is not qualified. All five qualification gates must be PASS."
        return self._store(p).mutate(operation="qualify",expected_revision=int(o["expected_revision"]),mutation=mutate)
    def cmd_select(self,p,o):
        name=_req(o,"style","select requires --style.")
        def mutate(s):
            if s["stage"]!="selection-ready":raise ArenaError("All three candidates must qualify before selection.")
            st=_style(s,name)
            if st["qualification"]["overall"]!="PASS":raise ArenaError("Selected style is not qualified.")
            s["selection"]={"style":name,"branch":st["branch"],"selectedAt":utc_now()};s["stage"]="selected";s["status"]="ready"
        return self._store(p).mutate(operation="select",expected_revision=int(o["expected_revision"]),mutation=mutate)
    def cmd_merge(self,p,o):
        def mutate(s):
            if s["stage"]!="selected":raise ArenaError("merge requires a selected candidate.")
            if any(_style(s,n)["preview"]["pid"] for n in STYLES):raise ArenaError("Stop all recorded preview processes before merge.")
            repo=s["repository"]["root"];selected=_style(s,s["selection"]["style"]);mh=self.git.run(repo,("rev-parse","-q","--verify","MERGE_HEAD"),allow_failure=True)
            if mh.exit_code:self.git.run(repo,("switch",s["repository"]["baseBranch"]))
            elif self.git.run(repo,("branch","--show-current")).stdout!=s["repository"]["baseBranch"]:raise ArenaError("Merge conflict recovery is not on the recorded base branch.")
            if mh.exit_code==0:
                conflicts=self.git.run(repo,("diff","--name-only","--diff-filter=U"),allow_failure=True).stdout.splitlines()
                if conflicts:s["merge"].update({"status":"CONFLICT","conflicts":conflicts});s["status"]="blocked";s["blockingReason"]="Merge conflicts remain. Resolve them, inspect the focused diff with the user, then rerun merge.";return
                self.git.run(repo,("commit","-m",f"Merge selected Vibe Design Arena {selected['branch']}"));s["merge"]["method"]="merge-commit-resumed"
            else:
                dirty=self.git.run(repo,("status","--porcelain","--untracked-files=all")).stdout
                if dirty:raise ArenaError(f"Main worktree must be clean before merge:\n{dirty}")
                s["merge"]["preMergeSha"]=self.git.run(repo,("rev-parse","HEAD")).stdout
                if self.git.run(repo,("merge-base","--is-ancestor",selected["branch"],"HEAD"),allow_failure=True).exit_code:
                    if self.git.run(repo,("merge-base","--is-ancestor","HEAD",selected["branch"]),allow_failure=True).exit_code==0:self.git.run(repo,("merge","--ff-only",selected["branch"]));s["merge"]["method"]="fast-forward"
                    else:
                        r=self.git.run(repo,("merge","--no-ff",selected["branch"],"-m",f"Merge selected Vibe Design Arena {selected['branch']}"),allow_failure=True)
                        if r.exit_code:
                            conflicts=self.git.run(repo,("diff","--name-only","--diff-filter=U"),allow_failure=True).stdout.splitlines();s["merge"].update({"status":"CONFLICT","conflicts":conflicts});s["status"]="blocked";s["blockingReason"]="Merge conflicts require user judgment. No automatic resolution or abort was performed.";return
                        s["merge"]["method"]="merge-commit"
                elif not s["merge"]["method"]:s["merge"]["method"]="already-merged"
            post=self.git.run(repo,("rev-parse","HEAD")).stdout
            if sha256_file(Path(repo)/"DESIGN_BRIEF.md")!=selected["brief"]["approvedSha256"]:s["merge"]["status"]="BRIEF-INTEGRITY-FAIL";s["status"]="blocked";s["blockingReason"]="Merged DESIGN_BRIEF.md does not match the approved bytes.";return
            validation=[_run_spec(x,repo) for x in s["configuration"].get("validation",[])];s["merge"]["validation"]=validation
            if any(x["status"]!="PASS" for x in validation):s["merge"].update({"status":"VALIDATION-FAIL","postMergeSha":post});s["status"]="blocked";s["blockingReason"]="Post-merge validation failed. Repair the merged result before cleanup.";return
            s["merge"].update({"postMergeSha":post,"status":"PASS"});s["stage"]="merged";s["status"]="ready";s["blockingReason"]=None
        return self._store(p).mutate(operation="merge",expected_revision=int(o["expected_revision"]),mutation=mutate)
    def cmd_cleanup(self,p,o):
        store=self._store(p)
        def clean(s):
            if s["stage"]!="merged" or s["merge"]["status"]!="PASS":raise ArenaError("cleanup requires a verified merged result.")
            repo=s["repository"]["root"]
            lines=self.git.run(repo,("worktree","list","--porcelain")).stdout.splitlines()
            registered=[absolute_path(x[9:]) for x in lines if x.startswith("worktree ")]
            if len(registered)<4:raise ArenaError("Git worktree registry does not contain the main worktree plus all three candidates.")
            candidates=[]
            for n in STYLES:
                st=_style(s,n)
                if st["preview"]["pid"]:raise ArenaError(f"Preview process is still recorded for {n}")
                path=child_path(s["paths"]["worktreeRoot"],st["worktree"])
                if sum(os.path.normcase(str(x))==os.path.normcase(str(path)) for x in registered)!=1:raise ArenaError(f"Registered worktree mismatch for {n}: {path}")
                if self.git.run(path,("branch","--show-current")).stdout!=st["branch"]:raise ArenaError(f"Worktree branch mismatch for {n}")
                dirty=self.git.run(path,("status","--porcelain","--untracked-files=all")).stdout
                if dirty:raise ArenaError(f"Worktree contains uncommitted or untracked files; refusing cleanup for {n}\n{dirty}")
                candidates.append(path)
            removed=[]
            for path in candidates:
                self.git.run(repo,("worktree","remove",str(path)))
                removed.append(str(path))
            self.git.run(repo,("worktree","prune"))
            for n in STYLES:
                st=_style(s,n);sha=self.git.run(repo,("rev-parse",st["branch"])).stdout
                if st["implementationCommit"] and sha!=st["implementationCommit"]:raise ArenaError(f"Retained branch commit mismatch for {n}. Expected={st['implementationCommit']} Actual={sha}")
                st["retainedCommit"]=sha
            s["cleanup"]={"completedAt":utc_now(),"removedWorktrees":removed};s["stage"]="cleaned";s["status"]="ready"
        cleaned=store.mutate(operation="cleanup",expected_revision=int(o["expected_revision"]),mutation=clean)
        def complete(s):
            if s["stage"]!="cleaned":raise ArenaError("Internal cleanup completion transition requires cleaned stage.")
            s["stage"]="complete";s["status"]="complete"
        return store.mutate(operation="complete",expected_revision=int(cleaned["stateRevision"]),mutation=complete)
    def _remote(self,repo,remote,branch):
        r=self.git.run(repo,("ls-remote","--heads",remote,f"refs/heads/{branch}"),allow_failure=True);return r.stdout.split()[0] if not r.exit_code and r.stdout else None
    def cmd_publish_plan(self,p,o):
        s=self._store(p).read();repo=s["repository"]["root"];remote=o.get("remote") or "origin";branches=o.get("branches") or [s["repository"]["baseBranch"],*[_style(s,n)["branch"] for n in STYLES]];plan=[]
        for b in branches:
            local=self.git.run(repo,("rev-parse",b)).stdout;r=self._remote(repo,remote,b);plan.append({"branch":b,"localSha":local,"remoteSha":r,"action":"none" if local==r else "push"})
        return {"remote":remote,"branches":plan,"stateRevision":s["stateRevision"]}
    def cmd_publish(self,p,o):
        if not o.get("confirm_publish"):raise ArenaError("publish requires --confirm-publish after reviewing publish-plan.")
        branches=_req(o,"branches","publish requires an explicit --branches list.");remote=o.get("remote") or "origin"
        def mutate(s):
            repo=s["repository"]["root"];allowed=[s["repository"]["baseBranch"],*[_style(s,n)["branch"] for n in STYLES]]
            for b in branches:
                if b not in allowed:raise ArenaError(f"Branch is outside the Arena publication set: {b}")
                self.git.run(repo,("push",remote,f"{b}:refs/heads/{b}"));r=self._remote(repo,remote,b);local=self.git.run(repo,("rev-parse",b)).stdout
                if r!=local:raise ArenaError(f"Remote verification failed after publishing {b}")
                key="main" if b==s["repository"]["baseBranch"] else next(n for n in STYLES if _style(s,n)["branch"]==b);s["publication"][key]={"published":True,"remote":remote,"remoteSha":r,"publishedAt":utc_now()}
        return self._store(p).mutate(operation="publish",expected_revision=int(o["expected_revision"]),mutation=mutate)
    def cmd_handoff_docs(self,p,o):
        def mutate(s):
            if s["stage"] not in ("cleaned","complete"):raise ArenaError("handoff-docs is available only after cleanup.")
            path=Path(s["paths"]["recordsRoot"])/"generated"/"README.arena-patch.md";lines=["# README patch draft — Vibe Design Arena result","",f"- Selected direction: {s['selection']['style']}",f"- Selected branch: {s['selection']['branch']}",f"- Post-merge SHA: {s['merge']['postMergeSha']}","","## Alternative branches"]
            for n in STYLES:
                st=_style(s,n);pub=s["publication"][n];lines.append(f"- {st['branch']}: local={st['retainedCommit']}, remotePublished={str(pub['published'])}, remoteSha={pub['remoteSha'] or ''}")
            lines+=["","## Validation commands"]
            for spec in s["configuration"].get("validation",[]):lines.append(f"- {spec['executable']} {' '.join(map(str,spec.get('args') or []))}")
            write_utf8_lf(path,"\n".join(lines)+"\n");s["handoff"]={"generatedAt":utc_now(),"patchPath":str(path)}
        return self._store(p).mutate(operation="handoff-docs",expected_revision=int(o["expected_revision"]),mutation=mutate)
