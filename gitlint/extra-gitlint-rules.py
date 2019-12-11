from gitlint.rules import CommitRule, RuleViolation
import re

# v/ https://jorisroovers.com/gitlint/user_defined_rules/

class IssueTrackerReference(CommitRule):
    """
    This rule enforces that the title contains either a bug tracker reference or
    either of the words "trivial", "typo", or "noref".
    """

    name = "issue-tracker-reference"
    id = "SD1"

    def validate(self, commit):
        # This can definitely be improved upon. In particular, it does not
        # check whether there maybe is a bug reference at the beginning/in
        # the middle of the title. Maybe that should be another rule though.
        issuepattern = re.compile(r'^.*\((((bsc#|boo#|FATE#|jsc#[A-Z]+-|SOC-)[0-9]+(,\s)?)+|trivial|typo|noref)\)$')
        if issuepattern.fullmatch(commit.message.title):
            return

        return [RuleViolation(self.id, "Title contains no bug tracker reference(s) or explanation of omission thereof at its end.\n  Recognized issue tracker references: bsc#, boo#, jsc#, FATE#, SOC-.\n  Alternatively, explain the omission of a reference with any of the values \"trivial\", \"typo\", or \"noref\".\n  Valid example 1: \"Fixed the blub (bsc#999000, jsc#SLE-9900)\"\n  Valid example 2: \"Changed the blab (trivial)\"", line_nr=1)]
