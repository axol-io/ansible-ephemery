# Bash Scripting Best Practices

This document outlines best practices for writing bash scripts in the Ephemery project, with examples of common issues and their solutions.

## Table of Contents

1. [Introduction](#introduction)
2. [Variable Quoting](#variable-quoting)
3. [Command Substitution](#command-substitution)
4. [Conditional Statements](#conditional-statements)
5. [Error Handling](#error-handling)
6. [Shellharden](#shellharden)

## Introduction

Writing robust and maintainable shell scripts requires following best practices. This document provides examples of common issues and their solutions, with a focus on using `shellharden` to automatically enforce these best practices.

## Variable Quoting

Always quote variables to prevent word splitting and globbing issues.

### Bad

```bash
# Variables not quoted - can cause unexpected word splitting
FILE_LIST=$(ls)
for file in $FILE_LIST; do
    rm $file
done

# Path concatenation without quotes
TARGET_DIR=/tmp/mydir
cd $TARGET_DIR/subdir
```

### Good

```bash
# Variables properly quoted
FILE_LIST="$(ls)"
for file in "${FILE_LIST}"; do
    rm "${file}"
done

# Path concatenation with quotes
TARGET_DIR="/tmp/mydir"
cd "${TARGET_DIR}/subdir"
```

## Command Substitution

Use `$()` instead of backticks for command substitution, and quote the results.

### Bad

```bash
# Using deprecated backticks
TODAY=`date +%Y-%m-%d`

# Not quoting command substitution
FILES=`find . -name "*.sh"`
for f in $FILES; do
    chmod +x $f
done
```

### Good

```bash
# Using $() syntax
TODAY="$(date +%Y-%m-%d)"

# Quoting command substitution
FILES="$(find . -name "*.sh")"
for f in "${FILES}"; do
    chmod +x "${f}"
done
```

## Conditional Statements

Use `[[` instead of `[` for conditionals, and quote variables inside conditionals.

### Bad

```bash
# Using single brackets and unquoted variables
if [ $STATUS = "OK" ]; then
    echo "Status is OK"
fi

# String comparison with = instead of ==
if [ $COUNT = 0 ]; then
    echo "Count is zero"
fi
```

### Good

```bash
# Using double brackets and quoted variables
if [[ "${STATUS}" == "OK" ]]; then
    echo "Status is OK"
fi

# Proper string comparison
if [[ "${COUNT}" -eq 0 ]]; then
    echo "Count is zero"
fi
```

## Error Handling

Always set error handling flags at the beginning of your scripts.

### Bad

```bash
#!/usr/bin/env bash

# No error handling flags
cd /nonexistent/directory
echo "Directory changed" # This will run even if cd fails
```

### Good

```bash
#!/usr/bin/env bash

# Proper error handling
set -euo pipefail

cd /nonexistent/directory || {
    echo "Error: Failed to change directory" >&2
    exit 1
}
echo "Directory changed" # This won't run if cd fails
```

## Shellharden

[Shellharden](https://github.com/anordal/shellharden) is a tool used in the Ephemery project to automatically enforce shell script best practices.

### Running Shellharden

You can run shellharden on your scripts using:

```bash
./scripts/testing/lint_shell_scripts.sh --check path/to/script.sh
```

To automatically fix issues:

```bash
./scripts/testing/lint_shell_scripts.sh --fix path/to/script.sh
```

### Common Issues Fixed by Shellharden

1. **Unquoted Variables**:
   - Before: `echo $VAR`
   - After: `echo "${VAR}"`

2. **Backtick Command Substitution**:
   - Before: ``RESULT=`command` ``
   - After: `RESULT="$(command)"`

3. **Unquoted Pathname Expansion**:
   - Before: `rm *.txt`
   - After: `rm ./*.txt`

4. **Unquoted Command Substitution**:
   - Before: `for file in $(ls)`
   - After: `for file in "$(ls)"`

### Setting Up Pre-commit Hook

To automatically check your shell scripts before each commit, run:

```bash
./scripts/utilities/setup_pre_commit.sh
```

This will install a git pre-commit hook that runs shellharden on staged shell scripts. 