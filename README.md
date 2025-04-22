# known-false-positives

OpenScanHub now automatically suppresses findings recorded in this repository.
Please put there only findings for which you are sure they are false positives.
Otherwise it could happen that a real security issue will be missed later on.

## Ignoring true positives findings
If developers don't want to get notified about some true positive findings
(e.g., the team is already working on a fix and wants to suppress the finding
in the meantime, considered as accepted/minimal risk or won't fix decision
supported by justification, etc...), you can specify them in a file named:
`${PKG_NAME}/true-positives-ignore.err`

This file has the same working as the `*/ignore.err` file and OpenScanHub will
suppress these findings.
Developers are responsible for maintaining this file updated.

## Excluding source directories with tests
Upstream developers of certain projects do not fix static analysis findings
in source code of test programs.  Moreover, some test programs intentionally
contain bugs to exercise how the system under test handles them.  In these
cases we might want to exclude static analysis findings from the test programs.
A list of directories in the source tree to be excluded from static analysis
findings can be specified in a file:
`${PKG_NAME}/exclude-paths.txt`

Each line of the file contains an extended regular expression specifying
the source paths to be excluded.  See the following file for an example:
`protobuf/exclude-paths.txt`

## Applying filters locally
To see what remains to be reviewed after suppressing known false positives,
you can use the csfilter-kfp tool, which is included in the csdiff package
available in Fedora and EPEL.
