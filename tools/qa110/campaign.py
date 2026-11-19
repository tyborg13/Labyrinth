#!/usr/bin/env python3
"""Run the QA-101 whole-run policy with QA-110's decision-boundary observer."""

import sys

import campaign_base as campaign

TASK_ID = "qa-110"
DRIVER = "tools/qa110/whole_run.gd"


def command_for(seed, directory, args):
    command = campaign.command_for(seed, directory, args)
    command[command.index("--task-id") + 1] = TASK_ID
    return command


if __name__ == "__main__":
    campaign.run_hunt.MAX_PROCESSES = 1
    campaign.run_hunt.command_for = command_for
    campaign.run_hunt.write_json = campaign.write_json
    sys.argv.extend(("--script", DRIVER))
    raise SystemExit(campaign.run_hunt.main())
