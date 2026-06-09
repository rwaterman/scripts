# utils

Standalone scripts that *do* something when run — operational one-offs and helpers, carved out of the former `devops` repo.

For copy-and-customize boilerplate (IaC, Dockerfiles, manifests, scaffolds), see [`templates`](https://github.com/rwaterman/templates).

## Layout

- `aws/redshift/` — `capacity_check.sh`: report Redshift cluster capacity.
- `aws/secretsmanager/` — `create_secrets_manager_secret.sh`: create a Secrets Manager secret.
- `aws/sqs/` — `purge_queues.sh`: purge SQS queues.
- `aws/stepfunctions/` — `check_state_machine.sh`: inspect a Step Functions execution.
- `git/` — `check_release_branch_for_missing_commits.sh`, `split_monorepo.sh` (history-preserving repo split via `git filter-repo`).
- `scripts/db/postgres/` — dump/restore helpers (`dump_csv`, `dump_sql`, `restore_sql_gz`, `copy_internal`).
- `scripts/db/sql_server/` — backup/restore helpers (`dump_bak`, `restore_bak`, `restore_bak_s3`).
- `scripts/mac/mem/` — `memwatch.sh`: watch memory usage on macOS.

## Convention

A script that performs an action on its own belongs here. Anything you copy and then edit belongs in `templates`.
