# Lessons Learned

Correction memory for whoever (or whatever) regenerates `AI/CONTEXT.md`. Short, imperative entries only. Prune an entry once the generator stops making the mistake.

## Repo-specific facts the code reads as the opposite of

- `examples/test_app` is a deliberate stub (one comment line) that exists only so terrappy's LocalStack plan/apply jobs pass; ElastiCache is a LocalStack Pro feature. Do not describe it as an example or as test coverage. The real example is `real_examples/test_app/main.tf`, and no workflow reads it.
- Green CI does not mean the module was planned, applied or validated. Do not write that releases are "tested on LocalStack".
- Redis is supported and ships in `0.0.7`, despite the `engine` variable description saying "Only memcached is supported". Do not repeat the description as fact.
- `transit_encryption_enabled` is always `false` for Redis because `local.transit_encryption_enabled` requires `var.engine == "memcached"`. This is correct, not a bug: AWS supports Redis/Valkey TLS only on replication groups, and `aws_elasticache_cluster` rejects it (at plan time since provider 6.62.0). Do not recommend removing the engine check. The provider docs from 5.95.0 up to 6.62.0 wrongly claimed Redis support; do not cite them.
- `security_group_rules` replaces the default ingress rule and silently discards `allowed_cidrs`; `security_group_ids` is additive and keeps the VPC-CIDR rule. The comment in `real_examples/test_app/main.tf` says otherwise — follow the code.
- `project` and `stage` appear in tags only, never in resource names. The label module's `namespace` has no effect because only `.tags` is used.
- `acc` is the default branch and PR target. CI merges `acc` into `master` and tags from `acc`. Do not call `master` the main branch.
- `.terraform.lock.hcl`, `.terraform/` and `terraform.tfstate*` under the root and the example dirs are untracked (globally ignored). Do not cite their provider versions or state as committed facts.

## Generation traps hit on the first pass

- Evaluate version expressions in `terraform console` before characterising them. The family local is right for Redis `7.1` but wrong for `6.2`. Reading the HCL gives the wrong impression.
- Check the AWS provider's `engine_version` validation before calling an input realistic. Memcached must be `major.minor.patch`, so `"1.6"` never reaches the TLS check, which is correct for every current Memcached version. Do not describe the check as a live fail-open bug; it is a dormant risk for a future `1.7.0`-style release.
- Read terrappy's `tfc-test-helper-module-apply.yaml@v1` before describing the release gate. Its `completed` job passes when no `.tf` changed, which is what `workflow-change`'s condition relies on. That is correct; the real gap is the stub example.
- This repo is public. Do not reproduce branch-protection settings or bypass lists from the private repo that manages them. Point at the branch settings instead.
- Do not describe gaps in review or merge controls, even ones you can infer from files in this repo. In a public file, next to the CI auto-release description, that maps out a supply-chain path. Raise such gaps with the owner privately.
- Do not name private repos as consumers in the file. Only the public Terrappy consumers belong in the inventory.
- Keep framing proportionate: most defects fail closed (plan/apply errors). The misleading access-control comment in `real_examples` is the only live fail-open issue; the Memcached TLS check could fail open only for a future version.
- Never raise `review_confidence` because the draft was thorough. Only human validation raises it.
