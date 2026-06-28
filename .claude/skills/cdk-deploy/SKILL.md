---
name: cdk-deploy
description: Safely deploy (or redeploy) an AWS CDK app to a real AWS account. Use this whenever the user asks to deploy, redeploy, push, or ship CDK/CloudFormation infrastructure to AWS, asks to "stand up the backend," or asks why a `cdk deploy` failed or hung. Covers verifying account identity and prerequisites before touching anything, validating with `cdk synth`/`cdk diff` first, getting explicit human sign-off on IAM-sensitive changes before any non-interactive deploy, the no-TTY pitfall that makes piped confirmations silently no-op, monitoring a slow multi-stack deploy without blocking, and safely retrieving outputs/secrets afterward. Make sure to use this skill any time real AWS resources are about to be created or changed, even if the user's request sounds like a one-liner ("just deploy it") — the safety steps matter most exactly when the request sounds casual.
---

# CDK Deploy

Deploying creates real, billable, IAM-governed resources in someone's actual AWS account. The point of this skill is to get a deploy done quickly *without* skipping the few checks that catch expensive or embarrassing mistakes — a stale config value that breaks at runtime, an IAM change nobody actually looked at, a deploy that silently no-op'd because of a missing TTY. None of the steps below are bureaucracy for its own sake; each one exists because skipping it caused a real problem in practice.

## 1. Confirm identity and target before anything else

Run this first, every time, even if you deployed five minutes ago:

```bash
aws sts get-caller-identity --output table
```

Surface the account ID and ARN to the user before proceeding if there's any chance the request is ambiguous about which account/region. Deploying to the wrong account is the single worst failure mode here — it's not always cleanly reversible, and the user may not notice until billing shows up.

## 2. Check prerequisites against the live account, not against what the code assumes

Before running anything that touches infrastructure, check:

- **Docker is running** (CDK bundles Lambda/layer assets via Docker for `PythonFunction`/`PythonLayerVersion` or any `bundling` config): `docker info >/dev/null 2>&1`. If it's not running, `open -a Docker` and poll (`until docker info >/dev/null 2>&1; do sleep 2; done`) rather than failing immediately — it just needs a minute to start.
- **CDK bootstrap status** in the target account/region: `aws cloudformation describe-stacks --stack-name CDKToolkit --region <region>`. If it doesn't exist, you need `cdk bootstrap aws://<account>/<region>` before any deploy will work — this is a one-time, low-risk setup step, safe to run without extra confirmation.
- **Any service-specific resource the code references by hardcoded ID is still valid in this account.** This is the step that's easy to skip and the one that actually bit us: a CDK config file had a hardcoded Bedrock cross-region inference profile ID that didn't exist in the deploying account, would have made every runtime invocation fail, and *looked* totally fine in `cdk synth` (synth doesn't call AWS to validate resource IDs that are just opaque strings in IAM policies or Lambda env vars). The lesson generalizes: **if the code hardcodes an ID for a resource that varies by account/region/time (model IDs, AMI IDs, AZ-specific resource IDs, account-specific ARNs treated as opaque strings), check it against a live `aws <service> list-*` / `describe-*` call for the actual target account before deploying** — don't trust that because it's in the repo, it's still valid. `cdk synth` succeeding proves the CDK code is internally consistent; it does not prove every embedded string still refers to something real.

## 3. Validate before deploying: `cdk synth`, then `cdk diff`

```bash
cd <cdk-app-dir>
source .venv/bin/activate  # create + `pip install -r requirements.txt` if missing
cdk synth --all
```

This is a free, side-effect-free check that the app/config is valid for *this* account/region (account/region get baked into ARNs and conditionals at synth time, so synth output can differ even when the CDK code hasn't changed). If this is a fresh checkout with Docker-bundled assets, it can take several minutes the first time (building the base bundling image) — run it in the background and poll rather than blocking, see §5.

Once synth is clean, run `cdk diff --all` and actually look at the output, specifically the **IAM Statement Changes** / **IAM Policy Changes** / **Security Group Changes** sections:

```bash
cdk diff --all 2>&1 | grep -A6 "IAM Statement Changes\|Security Group Changes"
```

For a brand-new deploy this will be a long list of `[+]` (everything is new — that's expected and fine). For a *redeploy* of existing infrastructure, scrutinize anything that looks like a new wildcard action, a new principal, or a broadened resource scope. This diff is also exactly what CDK's own interactive approval prompt would have shown a human at the terminal — you're substituting for that prompt, so actually read it before substituting for it.

## 4. Get explicit confirmation before any non-interactive deploy — don't just bypass the gate

`cdk deploy` has a built-in safety prompt that requires confirmation before applying changes with IAM/security implications. There are two ways this goes wrong if you're not careful:

**Don't reach for `--require-approval never` as a default.** It exists, and it is the correct flag to use eventually, but using it *before* a human has actually seen the security-relevant diff defeats its entire purpose. In an agent harness, blindly passing this flag to skip a known confirmation gate is exactly the kind of action that gets — and should get — blocked by safety tooling. The fix isn't to find a workaround; it's to do the thing the flag is meant to replace: show the user the diff from §3, ask them directly ("here's what would change, should I proceed?"), and only pass `--require-approval never` *after* they've said yes. At that point the human-in-the-loop requirement has been satisfied via chat instead of via terminal prompt, which is fine — the goal was the human seeing it, not the specific mechanism.

**Don't try to satisfy the interactive prompt by piping input.** `echo "y" | cdk deploy --all` looks like it should work and silently doesn't: CDK's prompt checks for an actual attached TTY, and when it doesn't find one it just declines to deploy that stack and moves on — no error, a changeset gets created and left un-executed, and the overall process can still exit 0. If you see `"--require-approval" is enabled and stack includes security-sensitive updates, but terminal (TTY) is not attached` in the output, that confirms it: nothing got deployed for that stack, regardless of what the exit code suggested. This is why §3's diff-then-ask-then-`--require-approval never` sequence is the right pattern, not a piped TTY workaround.

## 5. Run the deploy in the background and monitor — don't block on it

A multi-stack deploy with Docker-bundled Lambda assets and CloudFormation propagation delays (IAM eventual consistency, EventBridge rule propagation, etc.) routinely takes 5-20+ minutes. Don't run it as a blocking foreground call.

```bash
cdk deploy --all --require-approval never 2>&1 | tee /tmp/<app>-deploy.log | tail -60
```
Launch this with the background-execution mechanism your environment provides, then poll rather than tailing continuously:

```bash
aws cloudformation describe-stacks --region <region> --query 'Stacks[].{Name:StackName,Status:StackStatus}' --output table
```

A few things that are normal and not signs of failure, learned from watching this in practice:
- **Independent (sibling) stacks deploy concurrently.** If stack B doesn't actually reference any resource from stack A in the CDK code (no object passed between them at synth time), CDK will deploy them in parallel once their shared dependency is done — don't assume the order they're declared in `app.py` is the order they'll appear in CloudFormation. Use the actual cross-stack object-passing in the code to know what *should* depend on what.
- **`tee`'s/`tail`'s reported exit code is not the deploy command's exit code.** If you pipe `cdk deploy | tee ... | tail ...`, the exit status the shell reports belongs to the last command in the pipe. A background-task notification saying "completed (exit code 0)" tells you the *pipeline* finished, not that the deploy succeeded — always check the actual log content or CloudFormation stack status, not just the notification.
- When polling/waiting on a long deploy, prefer scheduling a wakeup measured in minutes over a tight poll loop — there's no benefit to checking every few seconds on something that takes 15 minutes.

## 6. After completion: report outputs, handle secrets correctly

Pull stack outputs (API URLs, ARNs, etc.) directly — these are fine to display and commit:

```bash
aws cloudformation describe-stacks --stack-name <stack> --region <region> --query 'Stacks[0].Outputs'
```

If anything generated is a genuine secret (API keys, passwords, tokens — e.g. `aws apigateway get-api-keys --include-values`):
- Report the value to the user in chat so they can store it themselves (Keychain, secrets manager, env var).
- **Never write it into a file that gets committed.** Update non-secret config (a base URL constant, an endpoint, a resource ARN) in the client code if that's part of the task, but leave secret values out of the diff entirely.

Do a quick smoke test of the live endpoint if one exists (`curl` against the new URL with the right auth header) before declaring the deploy done — `CREATE_COMPLETE` on the CloudFormation stack means the resources exist, not that the application logic actually works end-to-end.

## 7. Closing the loop with the user

Summarize: what got created (stack names + key resources), what the live endpoint/output values are, what secret the user needs to store and where, and any config files that were updated to point at the new deployment. If you fixed a stale-config bug along the way (per §2), call it out explicitly — it's the kind of thing that's easy to miss in a wall of deploy log output but matters more than almost anything else in the report.
