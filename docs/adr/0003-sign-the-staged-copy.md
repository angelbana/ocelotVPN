# 3. Sign the staged copy, then assemble the installer with makensis

## Status

Accepted, 2026-09-13.

## Context

The Windows installer and the program inside it both have to carry a signature.
The program asks for administrator privileges on every start, so an unsigned
program inside a signed installer still makes Windows report an unknown
publisher at the moment it matters most.

Signing the built executable before packaging does not work. CPack copies the
program into a staging tree and *then* rewrites it there - `fixup_bundle` and
`windeployqt` both edit the binary in place - so the signature is discarded
before the installer is assembled. This was not a theory: two consecutive runs
reported success while the program inside the published installer was unsigned,
which only surfaced by extracting the installer and asking Windows itself:

    Status : NotSigned

An attempt to work around it by packing once, signing the settled executable and
packing again failed too, for the same reason: the second pass rewrites the
staged copy again.

## Decision

Stage, sign, then assemble:

1. `cpack` prepares the staging tree and its NSIS script;
2. the signing action signs the staged copy of the program in that tree;
3. `makensis` builds the installer from the staging tree, reading the files that
   are already there;
4. the signing action signs the installer.

`cpack` is not used for step 3 - it would run its install step again and
overwrite the signature that step 2 just applied.

## Consequences

The step depends on CPack's internal layout: the path
`build/_CPack_Packages/win64/NSIS/` and the generated `project.nsi` are
implementation details of CPack, and a future version may change them. The
directory name also carries the version, so the path is resolved at run time
rather than written down.

Verified end to end: the published installer and the program inside it both
report `Valid` with a timestamp, checked with `Get-AuthenticodeSignature` on the
file downloaded from the release rather than on anything the build reported
about itself.
