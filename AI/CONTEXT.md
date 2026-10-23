---
repo: terraform-aws-helper-elasticache
project_name: Helper ElastiCache (Terrappy framework)
owner: Cinfra
domain: infrastructure
criticality: medium
summary: Terraform helper module that creates one single-node-group AWS ElastiCache cluster (Memcached or Redis OSS, via `aws_elasticache_cluster`, not a replication group) together with its parameter group, subnet group and a dedicated security group inside an existing VPC. Published to the public Terraform Registry as `guidion-digital/helper-elasticache/aws` and consumed by the Terrappy app modules (`terraform-aws-app-api-lambda`, `terraform-aws-app-apigw-lambda`) and by `terraform-aws-helper-shared-resources`. Relevant for questions about: ElastiCache cluster naming, cache access control (security group rules, VPC CIDR default), engine/version handling, parameter-group family derivation, and the module's input/output contract. Not relevant for: VPC or subnet creation, application cache usage, Redis replication/failover, or Terraform execution (HCP Terraform workspaces live in the consumers).
main_stack:
  - Terraform (HCL)
  - AWS ElastiCache (Memcached, Redis OSS)
  - GitHub Actions
main_systems:
  - AWS ElastiCache
  - AWS VPC / security groups
  - Terraform Registry
  - Terrappy (guidion-digital/terrappy)
  - LocalStack (CI only, effectively bypassed)
last_reviewed: 2026-10-20
review_confidence: low
generated_by: AI-assisted
validated_by: none
---

# Helper ElastiCache (terraform-aws-helper-elasticache)

## Overview

A small, flat Terraform module (no submodules) that turns a handful of inputs into one ElastiCache cluster plus the three supporting resources it needs. Callers are other Terrappy modules, which loop it with `for_each` over a map of caches; nobody runs it as a root module in production. It exists so every Terrappy application gets caches with the same naming, tagging and default "VPC-only" network access.

- **Owner:** Cinfra (the GitHub `project-team` repo property is `cinfra`)
- **Main stack:** Terraform/HCL, AWS ElastiCache, GitHub Actions
- **Environment:** Whatever AWS account/region the consuming module runs in. The only concrete environment in this repo is `real_examples/test_app/main.tf`, which targets `eu-central-1` (`eu-central-1a`, `eu-central-1b`) in `vpc-0e2c8dacf04f80915`.

---

## Purpose and responsibilities

Does:

- Create exactly one `aws_elasticache_cluster` — `memcached` or `redis`, selected by `count` on `var.engine` (`main.tf`).
- Create an `aws_elasticache_parameter_group` with a family derived from `var.engine` + `var.engine_version` (`local.parameter_group_family`), populated from `var.parameters`.
- Create an `aws_elasticache_subnet_group` over caller-supplied `var.subnet_ids`.
- Create a dedicated `aws_security_group` in `var.vpc_id` and attach it, plus any `var.security_group_ids`, to the cluster.
- Default the security group to a single TCP ingress rule on the engine port from the VPC's primary CIDR (`data.aws_vpc.this.cidr_block`), unless the caller supplies `allowed_cidrs` or `security_group_rules`.
- Default the port (11211 Memcached / 6379 Redis), force `num_cache_nodes` to at least 2 when `az_mode = "cross-az"`, and gate in-transit encryption on engine/version (`variables.tf`).
- Tag resources via `cloudposse/label/null` `0.25.0` (`module.these_tags`).

Does not do (delegated to):

- VPC, subnets, routing, NAT → caller (README: "No networking resources other than security groups will be created"); in the app modules this is their own `module.vpc`.
- Redis replication groups, automatic failover, Multi-AZ Redis, cluster mode → not supported anywhere; would need `aws_elasticache_replication_group`.
- Redis AUTH / RBAC users, at-rest encryption, snapshots/backups, log delivery → not exposed; `aws_elasticache_cluster` defaults apply (no snapshots, no auth).
- Valkey and ElastiCache Serverless → not supported; `var.engine` validation allows only `memcached` and `redis`.
- SNS topic for notifications → caller passes `notification_topic_arn`.
- Terraform execution, state, workspaces → consumers (HCP Terraform per the Terrappy framework).

---

## Source of truth / data ownership

| Domain object / data                                                            | Source of truth                                           | This system role                       | Notes                                                                                               |
| ------------------------------------------------------------------------------- | --------------------------------------------------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------- |
| ElastiCache cluster definition (engine, version, node type, port, AZ placement) | This module's inputs as set by the consuming module       | Owns (writes via Terraform)            | Drift is reconciled on the consumer's next apply                                                    |
| Cache contents (keys/values)                                                    | The consuming application                                 | Neither reads nor writes               | Ephemeral for Memcached; for Redis there are no snapshots, so contents are lost on node replacement |
| Cluster / SG / subnet group / parameter group names                             | This module (`local.name`, `${local.name}-${var.engine}`) | Owns                                   | Naming contract — see "Module interface contract and consumer inventory"                            |
| VPC and subnets                                                                 | Caller (app module `module.vpc`, or explicit IDs)         | Reads (`data "aws_vpc" "this"`)        | Only the VPC's primary `cidr_block` is read                                                         |
| Effective engine version                                                        | AWS ElastiCache                                           | Reads (`engine_version_actual` output) | AWS resolves the latest patch for the requested version                                             |
| Resource tags                                                                   | This module + provider `default_tags` of the caller       | Writes                                 | `tags_all` output exposes the merged set                                                            |

---

## External integrations

| System                                                        | Type                              | Direction  | Notes                                                                                                                                  |
| ------------------------------------------------------------- | --------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| AWS ElastiCache API                                           | Terraform AWS provider            | → outbound | Creates cluster, parameter group, subnet group                                                                                         |
| AWS EC2 API (VPC, security groups)                            | Terraform AWS provider            | → outbound | Reads VPC CIDR; creates SG and SG rules                                                                                                |
| `cloudposse/label/null` `0.25.0`                              | Terraform Registry module         | → outbound | Only `.tags` is used; its `id` (which would include `namespace = var.project`) is ignored                                              |
| Terraform Registry (`guidion-digital/helper-elasticache/aws`) | Module distribution               | ← inbound  | Consumers download tagged releases from here                                                                                           |
| `terraform-aws-app-api-lambda`                                | Terraform module consumer         | ← inbound  | `memcached.tf`, `version = "~> 0.0"`, `for_each = var.elasticache`                                                                     |
| `terraform-aws-app-apigw-lambda`                              | Terraform module consumer         | ← inbound  | `memcached.tf`, `version = "~> 0.0"`, `for_each = var.elasticache`                                                                     |
| `terraform-aws-helper-shared-resources`                       | Terraform module consumer         | ← inbound  | `elasticache.tf`, pinned `version = "0.0.7"`, also passes `num_cache_nodes`                                                            |
| `guidion-digital/terrappy`                                    | Reusable GitHub Actions workflows | → outbound | `tfc-test-helper-module-plan.yaml@v1`, `tfc-test-helper-module-apply.yaml@v1`                                                          |
| `guidion-digital/release-workflows`                           | Reusable GitHub Actions workflows | → outbound | `github-test-workflow.yaml@v2`, `github-merge-into-master.yaml@v2`, `github-release-tag.yaml@v2`, `github-release-tag-dry-run.yaml@v2` |
| LocalStack                                                    | CI test target                    | → outbound | Used by terrappy workflows; ElastiCache is a LocalStack Pro feature, so the module itself is never exercised (see Known risks)         |

Consumer rows were read from each consumer's default branch on GitHub on 2026-10-20, not from a pinned revision.

---

## APIs exposed

This is a Terraform module; its interface is its variables and outputs.

| Endpoint / method               | Purpose                                                                                                                                         | Consumer                                |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| Output `arn`                    | ARN of the created cluster                                                                                                                      | Terrappy app modules / shared-resources |
| Output `engine_version_actual`  | Running engine version after AWS patch resolution                                                                                               | Same                                    |
| Output `cache_nodes`            | List of node objects (`id`, `address`, `port`, `availability_zone`) — the only way to get a Redis endpoint                                      | Same                                    |
| Output `cluster_address`        | Memcached DNS name without port; `null` for Redis                                                                                               | Same; used by `real_examples`           |
| Output `configuration_endpoint` | Memcached discovery endpoint; for Redis returns the Redis attribute (null for a single-node cluster) despite the "(Memcached only)" description | Same                                    |
| Output `tags_all`               | Tags including provider `default_tags`                                                                                                          | Same                                    |
| Inputs (`variables.tf`)         | See "Module interface contract and consumer inventory"                                                                                          | Same                                    |

---

## APIs / services consumed

| Service                                                         | Purpose                                                               | Authentication                                                                     |
| --------------------------------------------------------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| AWS ElastiCache API                                             | Cluster / parameter group / subnet group lifecycle                    | Caller's AWS provider credentials (no provider block in this module)               |
| AWS EC2 API                                                     | `aws_vpc` data source, security group and rules                       | Same                                                                               |
| Terraform Registry                                              | Download `cloudposse/label/null` `0.25.0`                             | Anonymous                                                                          |
| GitHub Actions reusable workflows (terrappy, release-workflows) | Plan/apply tests, merge `acc` → `master`, semver tag + GitHub Release | `GITHUB_TOKEN` with `contents: write` / `pull-requests: write` as declared per job |

---

## Module interface contract and consumer inventory

Inputs, as declared in `variables.tf`:

| Input                                                | Type / default                  | Behaviour that is not obvious                                                                                                                                                   |
| ---------------------------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `project`                                            | string, required                | Only used for tags (`project`) and as label `namespace`, which has no effect on any resource name                                                                               |
| `application_name`                                   | string, required                | Tag `application`; becomes the name when `name` is null                                                                                                                         |
| `name`                                               | string, `null`                  | `local.name`; becomes `cluster_id` verbatim and the prefix of SG/subnet group/parameter group names. Consumers pass `"${var.application_name}-${each.key}"`                     |
| `stage`                                              | string, required                | Tag only — **not part of any resource name**                                                                                                                                    |
| `engine`                                             | string, `"memcached"`           | `memcached` or `redis`. Description still says "Only memcached is supported" — stale; Redis was added in `3135598`/`39ec815` and ships in `0.0.7`                               |
| `engine_version`                                     | string, `"1.6.17"`              | Feeds the parameter-group family and the TLS gate; see Known risks                                                                                                              |
| `transit_encryption_enabled`                         | bool, `true`                    | Effective value is `true` only for Memcached with digits-concatenated version ≥ 1612. Always `false` for Redis, deliberately: AWS supports Redis TLS only on replication groups |
| `node_type`                                          | string, `"cache.t4g.micro"`     | —                                                                                                                                                                               |
| `subnet_ids`                                         | list(string), `[]`              | Empty default; callers must supply subnets in practice                                                                                                                          |
| `vpc_id`                                             | string, required                | Also drives the default ingress CIDR                                                                                                                                            |
| `security_group_ids`                                 | list(string), `[]`              | Extra SGs attached _in addition to_ the module's SG; does not remove the default VPC-CIDR rule                                                                                  |
| `security_group_rules`                               | map(object), `{}`               | When non-empty, **replaces** the default rule entirely and `allowed_cidrs` is ignored                                                                                           |
| `allowed_cidrs`                                      | list(string), `null`            | Replaces the VPC CIDR in the default rule; ignored if `security_group_rules` is set                                                                                             |
| `az_mode`                                            | string, `"single-az"`           | `cross-az` bumps `num_cache_nodes` to 2. Passed only to the Memcached resource                                                                                                  |
| `availability_zone` / `preferred_availability_zones` | `null`                          | `preferred_availability_zones` is Memcached-only (not passed to Redis)                                                                                                          |
| `num_cache_nodes`                                    | number, `1`                     | Must be 1 for Redis (AWS rule); Memcached 1–40                                                                                                                                  |
| `port`                                               | number, `null`                  | Defaults to 11211 / 6379                                                                                                                                                        |
| `maintenance_window`                                 | string, `"sun:05:00-sun:09:00"` | UTC per AWS                                                                                                                                                                     |
| `apply_immediately`                                  | bool, `false`                   | Changes otherwise wait for the maintenance window                                                                                                                               |
| `auto_minor_version_upgrade`                         | bool, `null`                    | —                                                                                                                                                                               |
| `parameters`                                         | list({name, value}), `[]`       | Rendered into the parameter group                                                                                                                                               |
| `ip_discovery` / `network_type`                      | `"ipv4"`                        | `ip_discovery` validated to ipv4/ipv6; `network_type` unvalidated                                                                                                               |
| `notification_topic_arn`                             | string, `null`                  | —                                                                                                                                                                               |

Naming contracts (renaming any of these forces replacement of the resource; for the cluster that means a new, empty cache and a new endpoint):

| Resource                                              | Name / identifier             | Notes                                                                                                                                            |
| ----------------------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `aws_elasticache_cluster.memcached[0]` / `.redis[0]`  | `cluster_id = local.name`     | A namespaced `/applications/<app>/<name>` id was tried in `f172ebc` and reverted in `46dc370` because ElastiCache identifiers cannot contain `/` |
| `aws_elasticache_parameter_group.this`                | `${local.name}-${var.engine}` | Untagged; fixed name, no `create_before_destroy`                                                                                                 |
| `aws_elasticache_subnet_group.this`                   | `${local.name}-${var.engine}` | —                                                                                                                                                |
| `aws_security_group.this`                             | `${local.name}-${var.engine}` | Untagged; no egress rules (Terraform strips AWS's default egress)                                                                                |
| `aws_security_group_rule.these["default"]`            | map key `default`             | Present only when `security_group_rules` is empty                                                                                                |
| Resource addresses `memcached` / `redis` with `count` | —                             | Changing `var.engine` destroys one cluster and creates the other                                                                                 |

Consumer inventory (default branches, read 2026-10-20):

| Consumer                                | File             | Version constraint | Inputs not passed                                        |
| --------------------------------------- | ---------------- | ------------------ | -------------------------------------------------------- |
| `terraform-aws-app-api-lambda`          | `memcached.tf`   | `~> 0.0`           | `num_cache_nodes` (gets default 1, or 2 when `cross-az`) |
| `terraform-aws-app-apigw-lambda`        | `memcached.tf`   | `~> 0.0`           | `num_cache_nodes`                                        |
| `terraform-aws-helper-shared-resources` | `elasticache.tf` | `0.0.7`            | —                                                        |

All three default `vpc_id` / `subnet_ids` to their own `module.vpc[0]` outputs (private subnets) when the map entry leaves them null.

---

## Deployment

**CI/CD:** GitHub Actions, entirely via reusable workflows. `test-plan.yaml` runs on PRs to `acc`: `github-test-workflow.yaml@v2` → terrappy `tfc-test-helper-module-plan.yaml@v1` → `github-release-tag-dry-run.yaml@v2`. `test-apply-and-release.yaml` runs on push to `acc`: terrappy `tfc-test-helper-module-apply.yaml@v1` (`environment_name: "localstack"`), then either `workflow-change` (no `.tf` changed: merge `acc` → `master` without a release) or `terraform-module-change` + `release-module-version` (apply succeeded: merge `acc` → `master`, then `mathieudutour/github-tag-action@v6.2` bumps the tag and `ncipollo/release-action` creates a GitHub Release).

**Infra:** Nothing is deployed from this repo. Releases are git tags (no prefix, e.g. `0.0.7`) picked up by the Terraform Registry. Consumers apply the module from their own workspaces.

**Branch strategy:** `acc` is the default branch and the only PR target; `master` is written only by CI's merge-from-`acc` job. Tags are bumped from `acc` (`release_branches: ${{ github.ref_name }}`); default bump is patch, driven by Conventional Commit messages. Pre-release tags such as `0.0.6-alpha-0.0.1` exist from earlier development. Branch protection is managed as code outside this repo; check the repository's branch settings rather than relying on this file.

**Environments:**

- CI: LocalStack only, and only against `examples/test_app` (a stub — see Known risks).
- Manual: `real_examples/test_app/main.tf` (Memcached `1.6.17` cross-az + Redis `7.1` single-az) against `vpc-0e2c8dacf04f80915` / `subnet-01c97996cb4fb3ac8`, `subnet-093bd49986fbbdf89`, `subnet-044c17047e72dc07d` in `eu-central-1`. State and lock files from local runs exist in the working tree but are untracked/ignored.
- Production: whatever accounts the consuming modules deploy to; not visible from this repo.

---

## Architectural notes and key decisions

- **`aws_elasticache_cluster`, not a replication group.** Simpler and enough for Memcached; for Redis it means a single node with no replica, no failover, no AUTH, no in-transit and no at-rest encryption (AWS offers these for Redis only on replication groups). Anything needing durable or HA Redis should not use this module as-is.
- **Two resources selected by `count` instead of one resource with conditional arguments.** Memcached-only arguments (`az_mode`, `preferred_availability_zones`) are simply omitted from the `redis` resource. Outputs pick between `memcached[0]` and `redis[0]` with a ternary on `var.engine`.
- **Network access defaults to "anything in the VPC".** With no `allowed_cidrs`/`security_group_rules`, ingress is opened on the engine port from the VPC's primary CIDR. This is the intended convenience default for Terrappy apps whose Lambdas sit in the same VPC.
- **Names are not namespaced by project or stage.** `cluster_id = local.name` after the `/applications/...` attempt was reverted (`46dc370`). Isolation between stages therefore relies on stages living in different AWS accounts/regions, or on callers putting the stage into `name`.
- **No `terraform {}` / `required_providers` block.** Provider version is entirely the caller's choice. Only the label module is pinned (`0.25.0`).
- **CI cannot test the module.** ElastiCache is a LocalStack Pro feature that Guidion does not have, so `examples/test_app` was deliberately reduced to a comment so that terrappy's mandatory plan/apply jobs pass. Real usage examples live in `real_examples/`, which no workflow reads.

---

## Known risks / fragile areas

- **Redis versions other than 7 cannot get a valid parameter group (dormant).** `local.parameter_group_family` builds `redis${major}`, giving `redis7` for `7.1` (valid) but `redis6` for `6.2` and `redis5` for `5.0.6`; AWS's families are `redis6.x` and `redis5.0`. Introduced by `7304f6f` (which fixed `7.1` → `redis7.1`). Dormant while every caller uses Redis 7; the first Redis 6 caller fails at apply on the parameter group.
- **Memcached TLS version check works by joining the version's digits (dormant).** `local.engine_version_as_int = tonumber(replace(var.engine_version, ".", ""))` turns `1.6.17` into 1617 and compares it with 1612. The AWS provider only accepts Memcached versions as `major.minor.patch`, and within that format the comparison gives the right answer for every Memcached version AWS currently offers. A future release with a single-digit patch above 1.6 (e.g. `1.7.0` → 170) would fail the check, and TLS would be turned off without warning. Replace the check with a real version comparison before such a release is adopted.
- **Redis clusters from this module cannot have in-transit encryption (by AWS design, silently).** The `var.engine == "memcached"` term in `local.transit_encryption_enabled` is correct and necessary: AWS supports TLS for Redis/Valkey only on replication groups, and `CreateCacheCluster` rejects it (`InvalidParameterCombination: Encryption feature is not supported for engine REDIS`). AWS provider ≥ 6.62.0 rejects it at plan time. Without the term, every Redis caller would fail, because the input defaults to `true`. The only weakness is that a Redis caller's `true` is dropped without warning, rather than rejected. Redis TLS (and AUTH) would need `aws_elasticache_replication_group`. Together with the VPC-wide default ingress, Redis traffic from this module is plaintext and unauthenticated inside the VPC.
- **`6.x` breaks plan for Redis.** The provider accepts `6.x` as a Redis version, but `tonumber("6x")` errors because the local is evaluated for every engine. Fails closed; Redis 6 is broken anyway by the parameter-group family (above).
- **`cross-az` with Redis fails at apply.** `local.num_cache_nodes` bumps to 2 for `cross-az` regardless of engine; Redis requires 1. `az_mode` itself is not passed to the Redis resource. Fails closed.
- **Access-control comment in `real_examples/test_app/main.tf` is partly wrong.** The comment correctly says the VPC CIDR has access by default, and that `security_group_rules` or `allowed_cidrs` on its own replaces that default. It is wrong in two places. First, it claims the default is "overridden if any of these methods are used", but `security_group_ids` only attaches extra SGs and leaves the module SG's VPC-CIDR rule in place. Because SGs combine as a union, a caller who adds `security_group_ids` expecting to restrict access keeps VPC-wide access (fails open). Second, it claims the methods "are all cumulative", but when `security_group_rules` is set, `allowed_cidrs` is silently discarded, so those CIDRs lose access (fails closed). The commented `security_group_rules` sample uses `cidr_blocks = ["0.0.0.0/0"]`.
- **Default ingress covers only the VPC's primary CIDR.** Hosts in secondary VPC CIDRs, or reaching the cache through Transit Gateway/peering, are blocked unless `allowed_cidrs` or `security_group_rules` is set. Fails closed.
- **Engine major upgrades likely need manual intervention (unverified).** The parameter group has a fixed name and no `create_before_destroy`; a family change (e.g. Memcached 1.6 → future 1.7, Redis 7 → 8) forces replacement of a group that is still attached to the cluster and has the same name. Expect a failed apply or a destroy/recreate sequence; test before attempting.
- **Stage collisions within one account/region.** Because neither `project` nor `stage` is in any name, two consumers (or two stages) using the same `name` in the same account and region collide on `cluster_id` and on the `${name}-${engine}` SG/subnet/parameter group names. Harmless if every stage has its own account; a real collision otherwise.
- **Labels that disagree with the wiring.** Tag `service = "memcached"` is hardcoded and also applied to Redis clusters. The `engine` description claims Memcached-only. The `configuration_endpoint` output is described as Memcached-only but returns the Redis attribute. The README links `./examples/example/main.tf`, which does not exist (the real example is `real_examples/test_app/main.tf`). The parameter group and security group get no tags at all.
- **No provider version constraint.** Arguments such as `ip_discovery` and `network_type` need a reasonably recent AWS provider; a consumer on an old provider gets an unsupported-argument error rather than a clear constraint failure.
- **Hardcoded example identifiers will drift.** `vpc-0e2c8dacf04f80915` and the three subnet IDs in `real_examples/test_app/main.tf` are literal; if that VPC is recreated the example breaks silently until someone runs it.

---

## AI assistant guidance

When modifying this repo:

- Treat every variable, output, resource address (`memcached`, `redis`, `this`, `these`) and name pattern as a published interface consumed from the Terraform Registry by three Guidion modules. Renames, type changes and new required inputs are breaking; resource-name changes replace live caches.
- Do not change `cluster_id = local.name` or the `${local.name}-${var.engine}` pattern without a migration plan; `cluster_id` cannot contain `/`.
- Do not trust green CI. Before proposing a merge, run `terraform init && terraform plan` (and ideally apply/destroy) in `real_examples/test_app` against a real account, and say whether you did.
- Do not put new examples in `examples/` — anything there is applied against LocalStack, where ElastiCache is unavailable. Use `real_examples/`.
- When touching engine/version logic, test expressions with `terraform console` against at least `1.6.6`, `1.6.17`, `1.7.0`, `6.2`, `6.x` and `7.1` before claiming they work. Check the AWS provider's own `engine_version` validation (`internal/service/elasticache/engine_version.go`) before calling an input "valid".
- Keep fixes fail-closed: prefer validation errors over silently ignoring inputs (as happens today with `allowed_cidrs` and Redis `transit_encryption_enabled`).
- Use Conventional Commit subjects (`feat:`, `fix:`, `chore:`); the release workflow derives the version bump from them.
- PRs target `acc`. Never push to `master`.
- Ask for Cinfra review when changing security group defaults, encryption handling, naming, or the output contract.

If this file contradicts the actual code, the code wins — flag the discrepancy to the repo owner instead of trusting the doc

---

## Roadmap / active migrations

No roadmap is recorded in the repo. Open items implied by the code and history (none are tracked as committed work):

- [ ] Fix the Redis parameter-group family for Redis 5/6 (or validate `engine_version` to Redis 7 only)
- [ ] Replace the digit-concatenation TLS gate with a proper version comparison, and reject (rather than silently drop) `transit_encryption_enabled = true` for Redis
- [ ] Update the stale `engine` description, the hardcoded `service` tag and the README example link
- [ ] Add a `terraform {}` block with `required_version` / `required_providers`
- [ ] Decide whether Valkey, Redis replication groups or snapshots are in scope

---

## Freshness

- **Last reviewed:** 2026-10-20
- **Review confidence:** low
- **Generated by:** AI-assisted
- **Validated by:** none
- **Update when:** integrations change, stack changes, exposed APIs change, data ownership changes, or a relevant architectural decision is made

First-generation bootstrap. Every tracked file in the repo (12 files) was read in full: `main.tf`, `variables.tf`, `outputs.tf`, `README.md`, both `examples/test_app` files, both `real_examples/test_app` files, both workflows, `.gitignore`, `.detect-secrets.baseline`. The repo is smaller than the playbook's 20-file coverage floor, so external sources were also read in full: terrappy's `tfc-test-helper-module-plan.yaml@v1` and `tfc-test-helper-module-apply.yaml@v1`, release-workflows' `github-release-tag.yaml@v2`, and the ElastiCache module blocks of all three consumers. Release-workflows' merge, dry-run and test workflows were characterised by name only. Version-handling expressions were evaluated in `terraform console` (Terraform 1.6.1), Redis TLS support was checked against the AWS in-transit encryption guide and provider PR #49114 (released in 6.62.0). The provider docs between 5.95.0 and 6.62.0 wrongly said standalone Redis clusters support TLS, so do not rely on those versions' docs. AWS parameter-group family names (`redis6.x`, `redis5.0`) come from AWS documentation and were not queried or applied live. Confidence stays `low` because no human has validated this draft.
