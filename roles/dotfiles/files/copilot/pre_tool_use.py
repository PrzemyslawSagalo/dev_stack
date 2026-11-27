#!/usr/bin/env python3

import fnmatch
import json
import os
import re
import shlex
import sys

ARGUMENT_SENSITIVE_COMMANDS = frozenset({"rg", "git", "bats", "pre-commit", "gh"})
CONTROL_PREFIXES = frozenset({"(", "{", "!", "if", "then", "elif", "else", "while", "until", "do"})
CONTROL_SUFFIXES = frozenset({")", "}", ";", "fi", "done", "esac"})
RESTRICTED_FLAG_PREFIXES = (
    "--pre",
    "--upload-pack",
    "--exec",
    "--output",
    "--ext-diff",
    "--hostname-bin",
)
ANSI_C_ESCAPES = {
    "'": "'",
    '"': '"',
    "\\": "\\",
    "a": "\a",
    "b": "\b",
    "e": "\x1b",
    "E": "\x1b",
    "f": "\f",
    "n": "\n",
    "r": "\r",
    "t": "\t",
    "v": "\v",
}


def strip_line_continuations(command):
    """Remove unquoted Bash backslash-LF continuations outside comments and single quotes."""
    result = []
    quote = None
    word_start = True
    index = 0
    length = len(command)
    while index < length:
        char = command[index]
        if quote is None and char == "#" and word_start:
            end = command.find("\n", index)
            if end == -1:
                result.append(command[index:])
                break
            result.append(command[index:end + 1])
            index = end + 1
            word_start = True
            continue
        if quote == "'":
            result.append(char)
            if char == "'":
                quote = None
            index += 1
            continue
        if quote == "$'":
            if char == "\\" and index + 1 < length:
                result.append(command[index:index + 2])
                index += 2
                continue
            result.append(char)
            if char == "'":
                quote = None
            index += 1
            continue
        if char == "\\":
            if command[index + 1:index + 2] == "\n":
                index += 2
                continue
            if index + 1 < length:
                result.append(command[index:index + 2])
                index += 2
                word_start = False
                continue
        if quote is None and command[index:index + 2] == "$'":
            quote = "$'"
            result.append("$'")
            index += 2
            word_start = False
            continue
        if char in ("'", '"'):
            if quote is None:
                quote = char
            elif quote == char:
                quote = None
            word_start = False
            result.append(char)
            index += 1
            continue
        word_start = char in " \t\n;|&()<>" if quote is None else False
        result.append(char)
        index += 1
    return "".join(result)


def _decode_ansi_c_body(text, start):
    """Decode an ANSI-C $'...' body starting after $' and return (decoded, next_index)."""
    chars = []
    index = start
    length = len(text)
    while index < length:
        char = text[index]
        if char == "'":
            return "".join(chars), index + 1
        if char != "\\" or index + 1 >= length:
            chars.append(char)
            index += 1
            continue
        esc = text[index + 1]
        if esc in ANSI_C_ESCAPES:
            chars.append(ANSI_C_ESCAPES[esc])
            index += 2
        elif esc == "x":
            match = re.match(r"[0-9a-fA-F]{1,2}", text[index + 2:])
            if match:
                chars.append(chr(int(match.group(0), 16)))
                index += 2 + match.end()
            else:
                chars.append("\\x")
                index += 2
        elif esc == "u":
            match = re.match(r"[0-9a-fA-F]{1,4}", text[index + 2:])
            if match:
                chars.append(chr(int(match.group(0), 16)))
                index += 2 + match.end()
            else:
                chars.append("\\u")
                index += 2
        elif esc == "U":
            match = re.match(r"[0-9a-fA-F]{1,8}", text[index + 2:])
            if match:
                code = int(match.group(0), 16)
                chars.append(chr(code) if code <= 0x10FFFF else "\\U" + match.group(0))
                index += 2 + match.end()
            else:
                chars.append("\\U")
                index += 2
        elif esc in "01234567":
            match = re.match(r"[0-7]{1,3}", text[index + 1:])
            chars.append(chr(int(match.group(0), 8) & 0xFF))
            index += 1 + match.end()
        else:
            chars.append("\\" + esc)
            index += 2
    return "".join(chars), index


def decode_ansi_c_quotes(command):
    """Replace unquoted $'...' ANSI-C strings with shlex-safe single-quoted strings."""
    if "$'" not in command:
        return command
    result = []
    quote = None
    index = 0
    length = len(command)
    while index < length:
        char = command[index]
        if quote == "'":
            result.append(char)
            if char == "'":
                quote = None
            index += 1
            continue
        if char == "\\":
            if index + 1 < length and (
                quote is None or command[index + 1] in ('"', "\\", "$", "`", "\n")
            ):
                result.append(command[index:index + 2])
                index += 2
                continue
        if quote is None and command[index:index + 2] == "$'":
            decoded, next_index = _decode_ansi_c_body(command, index + 2)
            result.append(shlex.quote(decoded))
            index = next_index
            continue
        if char in ("'", '"'):
            if quote is None:
                quote = char
            elif quote == char:
                quote = None
        result.append(char)
        index += 1
    return "".join(result)


def _parse_heredoc_header(command, index):
    """Parse << or <<- heredoc delimiter starting at index."""
    cursor = index + 2
    strip_tabs = False
    length = len(command)
    if cursor < length and command[cursor] == "-":
        strip_tabs = True
        cursor += 1
    while cursor < length and command[cursor] in (" ", "\t"):
        cursor += 1
    delimiter_chars = []
    quoted = False
    delim_quote = None
    saw_token = False
    while cursor < length:
        char = command[cursor]
        if delim_quote is None:
            if char in " \t\n;|&()<>":
                break
            saw_token = True
            if char == "\\":
                quoted = True
                if cursor + 1 < length:
                    delimiter_chars.append(command[cursor + 1])
                    cursor += 2
                    continue
                cursor += 1
                continue
            if char in ("'", '"'):
                quoted = True
                delim_quote = char
                cursor += 1
                continue
            delimiter_chars.append(char)
            cursor += 1
        else:
            saw_token = True
            if (
                delim_quote == '"'
                and char == "\\"
                and cursor + 1 < length
                and command[cursor + 1] in ('"', "\\", "$", "`")
            ):
                delimiter_chars.append(command[cursor + 1])
                cursor += 2
                continue
            if char == delim_quote:
                delim_quote = None
                cursor += 1
                continue
            delimiter_chars.append(char)
            cursor += 1
    valid = saw_token and delim_quote is None
    return "".join(delimiter_chars), strip_tabs, quoted, cursor, valid


def _consume_heredocs(command, pos, pending_heredocs, unquoted_heredoc_bodies):
    """Consume pending heredoc bodies starting at pos, returning (new_pos, unterminated)."""
    unterminated = False
    length = len(command)
    for delimiter, strip_tabs, quoted in pending_heredocs:
        body_start = pos
        found = False
        while pos <= length:
            next_nl = command.find("\n", pos)
            if next_nl == -1:
                line = command[pos:]
                next_pos = length
            else:
                line = command[pos:next_nl]
                next_pos = next_nl + 1
            cmp_line = line.lstrip("\t") if strip_tabs else line
            if cmp_line == delimiter:
                if not quoted:
                    unquoted_heredoc_bodies.append(command[body_start:pos])
                pos = next_pos
                found = True
                break
            if next_nl == -1:
                break
            pos = next_pos
        if not found:
            unterminated = True
            if not quoted:
                unquoted_heredoc_bodies.append(command[body_start:])
            pos = length
    return pos, unterminated


def _extract_dollar_paren(text, start):
    """Extract the inner command of $(...) starting after '$('."""
    depth = 1
    quote = None
    word_start = True
    index = start
    length = len(text)
    while index < length and depth > 0:
        char = text[index]
        if quote == "'":
            if char == "'":
                quote = None
            index += 1
            continue
        if quote == "$'":
            if char == "\\" and index + 1 < length:
                index += 2
                continue
            if char == "'":
                quote = None
            index += 1
            continue
        if quote is None and char == "#" and word_start:
            end = text.find("\n", index)
            if end == -1:
                return text[start:], length
            index = end + 1
            word_start = True
            continue
        if char == "\\":
            if index + 1 < length and (
                quote is None or text[index + 1] in ('"', "\\", "$", "`", "\n")
            ):
                index += 2
                word_start = False
                continue
        if quote is None and text[index:index + 2] == "$'":
            quote = "$'"
            index += 2
            word_start = False
            continue
        if char in ("'", '"'):
            if quote is None:
                quote = char
            elif quote == char:
                quote = None
            word_start = False
            index += 1
            continue
        if quote is None:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    return text[start:index], index + 1
            word_start = char in " \t\n;|&()<>"
        else:
            word_start = False
        index += 1
    return text[start:], length


def _extract_backtick(text, start, in_double_quotes):
    """Extract the inner command of `...` starting after opening backtick."""
    chars = []
    index = start
    length = len(text)
    while index < length:
        char = text[index]
        if char == "\\" and index + 1 < length:
            nxt = text[index + 1]
            if nxt in ("$", "`", "\\") or (in_double_quotes and nxt == '"'):
                chars.append(nxt)
                index += 2
                continue
            if nxt == "\n":
                index += 2
                continue
            chars.append(text[index:index + 2])
            index += 2
            continue
        if char == "`":
            return "".join(chars), index + 1
        chars.append(char)
        index += 1
    return "".join(chars), length


def extract_command_substitutions(text, in_heredoc=False):
    """Extract executable $(...) and `...` command substitution strings outside single quotes."""
    substitutions = []
    quote = None
    word_start = True
    index = 0
    length = len(text)
    while index < length:
        char = text[index]
        if not in_heredoc:
            if quote == "'":
                if char == "'":
                    quote = None
                index += 1
                continue
            if quote == "$'":
                if char == "\\" and index + 1 < length:
                    index += 2
                    continue
                if char == "'":
                    quote = None
                index += 1
                continue
            if quote is None and char == "#" and word_start:
                end = text.find("\n", index)
                if end == -1:
                    break
                index = end + 1
                word_start = True
                continue
        if char == "\\" and index + 1 < length:
            nxt = text[index + 1]
            if (quote is None and not in_heredoc) or nxt in ('"', "\\", "$", "`", "\n"):
                index += 2
                word_start = False
                continue
        if not in_heredoc:
            if quote is None and text[index:index + 2] == "$'":
                quote = "$'"
                index += 2
                word_start = False
                continue
            if char in ("'", '"'):
                if quote is None:
                    quote = char
                elif quote == char:
                    quote = None
                word_start = False
                index += 1
                continue
        if text[index:index + 2] == "$(":
            inner, index = _extract_dollar_paren(text, index + 2)
            substitutions.append(inner)
            word_start = False
            continue
        if char == "`":
            inner, index = _extract_backtick(text, index + 1, quote == '"')
            substitutions.append(inner)
            word_start = False
            continue
        word_start = not in_heredoc and quote is None and char in " \t\n;|&()<>"
        index += 1
    return substitutions


def _has_brace_expansion(command, index):
    """Return True if '{' at index introduces a Bash brace expansion."""
    depth = 1
    cursor = index + 1
    expansion = False
    while cursor < len(command) and depth:
        if command[cursor] == "{":
            depth += 1
        elif command[cursor] == "}":
            depth -= 1
        elif depth and (command[cursor] == "," or command[cursor:cursor + 2] == ".."):
            expansion = True
        cursor += 1
    return expansion and depth == 0


def split_command(command):
    """Split a command into segments, flag unsafe syntax, and collect command substitutions."""
    command = strip_line_continuations(command)
    segments = []
    segment_has_vars = []
    outer_parts = []
    unquoted_heredoc_bodies = []
    pending_heredocs = []
    start = 0
    outer_start = 0
    quote = None
    unsafe = False
    segment_has_var = False
    word_start = True
    index = 0
    while index < len(command):
        char = command[index]
        if quote == "'":
            if char == "'":
                quote = None
            word_start = False
            index += 1
            continue
        if quote == "$'":
            if char == "\\" and index + 1 < len(command):
                index += 2
                continue
            if char == "'":
                quote = None
            word_start = False
            index += 1
            continue
        if quote is None and char == "#" and word_start:
            end = command.find("\n", index)
            command = command[:index] + (command[end:] if end != -1 else "")
            continue
        if char == "\\":
            if quote is None or command[index + 1:index + 2] in ('"', "\\", "$", "`", "\n"):
                if command[index + 1:index + 2] != "\n":
                    word_start = False
                index += 2
                continue
        if quote is None and command[index:index + 2] == "$'":
            unsafe = True
            quote = "$'"
            word_start = False
            index += 2
            continue
        if char in ("'", '"'):
            word_start = False
            if quote is None:
                quote = char
            elif quote == char:
                quote = None
            index += 1
            continue
        if char == "`" or command[index:index + 2] in ("$(", "${", "$'", '$"'):
            unsafe = True
        elif char == "$" and index + 1 < len(command):
            nxt = command[index + 1]
            if nxt.isalnum() or nxt in "_@*?!#-":
                segment_has_var = True
        if quote is None:
            if char in "*?[":
                unsafe = True
            elif command[index:index + 3] == "<<<":
                unsafe = True
                word_start = True
                index += 3
                continue
            elif command[index:index + 2] == "<<":
                delimiter, strip_tabs, quoted_delim, next_cursor, valid = _parse_heredoc_header(
                    command, index
                )
                if valid:
                    pending_heredocs.append((delimiter, strip_tabs, quoted_delim))
                    if not quoted_delim:
                        unsafe = True
                    word_start = True
                    index = next_cursor
                    continue
                unsafe = True
                word_start = True
                index += 2
                continue
            elif char in "<>":
                unsafe = True
            elif char in ";|&()\n":
                if char in "&()" and command[index:index + 2] != "&&":
                    unsafe = True
                if command[start:index].strip():
                    segments.append(command_tokens(decode_ansi_c_quotes(command[start:index])))
                    segment_has_vars.append(segment_has_var)
                if char == "\n" and pending_heredocs:
                    outer_parts.append(command[outer_start:index + 1])
                    pos, unterminated = _consume_heredocs(
                        command, index + 1, pending_heredocs, unquoted_heredoc_bodies
                    )
                    if unterminated:
                        unsafe = True
                    pending_heredocs.clear()
                    start = pos
                    outer_start = pos
                    segment_has_var = False
                    word_start = True
                    index = pos
                    continue
                if command[index:index + 2] in ("&&", "||"):
                    index += 1
                start = index + 1
                segment_has_var = False
                word_start = True
                index += 1
                continue
            elif char in (" ", "\t"):
                word_start = True
            else:
                word_start = False
            if char == "{" and _has_brace_expansion(command, index):
                unsafe = True
        else:
            word_start = False
        index += 1
    if command[start:].strip():
        segments.append(command_tokens(decode_ansi_c_quotes(command[start:])))
        segment_has_vars.append(segment_has_var)
    if pending_heredocs:
        unsafe = True
    outer_parts.append(command[outer_start:])
    substitutions = extract_command_substitutions("".join(outer_parts))
    for body in unquoted_heredoc_bodies:
        substitutions.extend(extract_command_substitutions(body, in_heredoc=True))
    return segments, segment_has_vars, unsafe, substitutions


def command_tokens(command):
    """Tokenize a command using shell-like syntax."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=';|&<>')
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def strip_environment(tokens):
    """Remove leading environment assignments from command tokens."""
    while tokens and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tokens[0]):
        tokens.pop(0)
    return tokens


def policy_rules(policy, key):
    """Parse and validate command rules from a policy key."""
    commands = policy.get(key)
    if not isinstance(commands, list):
        raise ValueError("Malformed policy")
    rules = []
    for command in commands:
        if not isinstance(command, str) or not command.strip():
            raise ValueError("Malformed policy")
        tokens = command_tokens(command)
        if not tokens:
            raise ValueError("Malformed policy")
        rules.append(tokens)
    return rules


def policy_patterns(policy, key):
    """Parse and validate optional glob pattern strings from a policy key."""
    if key not in policy:
        return []
    patterns = policy.get(key)
    if not isinstance(patterns, list) or any(
        not isinstance(pattern, str) or not pattern.strip() for pattern in patterns
    ):
        raise ValueError("Malformed policy")
    return patterns


def matches_rule(tokens, rules):
    """Return the first rule matching the start of command tokens."""
    return next(
        (rule for rule in rules if tokens[:len(rule)] == rule),
        None,
    )


def matches_glob_pattern(text, pattern):
    """Match a command string against a glob pattern, allowing trailing arguments."""
    if fnmatch.fnmatchcase(text, pattern):
        return True
    if not pattern.endswith("*"):
        return fnmatch.fnmatchcase(text, pattern + " *")
    return False


def matches_any_glob(segment, normalized, patterns):
    """Return the first glob pattern matching either raw or normalized segment tokens."""
    raw_text = " ".join(segment)
    normalized_text = " ".join(normalized)
    for pattern in patterns:
        if matches_glob_pattern(raw_text, pattern) or matches_glob_pattern(normalized_text, pattern):
            return pattern
    return None


def _strip_exec_options(tokens):
    """Strip exec wrapper options (-c, -l, -a name, --) from tokens in place."""
    while tokens:
        option = tokens[0]
        if option in ("-c", "-l", "--"):
            tokens.pop(0)
            if option == "--":
                break
        elif option == "-a":
            tokens.pop(0)
            if tokens:
                tokens.pop(0)
        elif option.startswith("-a") and option != "-a":
            tokens.pop(0)
        else:
            break


def _strip_env_options(tokens):
    """Strip env wrapper options and assignments from tokens in place."""
    while tokens:
        option = tokens[0]
        if option in ("-i", "--ignore-environment", "-0", "--null", "--"):
            tokens.pop(0)
        elif option in ("-u", "--unset", "-C", "--chdir", "-S", "--split-string"):
            tokens.pop(0)
            if tokens:
                value = tokens.pop(0)
                if option in ("-S", "--split-string"):
                    tokens[0:0] = shlex.split(value)
        elif option.startswith("--split-string="):
            tokens.pop(0)
            tokens[0:0] = shlex.split(option.split("=", 1)[1])
        elif option.startswith("-S") and option != "-S":
            tokens.pop(0)
            tokens[0:0] = shlex.split(option[2:])
        elif option.startswith("--") and "=" in option:
            tokens.pop(0)
        elif re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", option):
            tokens.pop(0)
        else:
            break


def normalize_for_deny(tokens):
    """Normalize control-flow prefixes, shell wrappers, paths, Git options, and rm flags."""
    tokens = tokens[:]
    while tokens and tokens[-1] in CONTROL_SUFFIXES:
        tokens.pop()
    while tokens:
        executable = os.path.basename(tokens[0])
        if tokens[0] in CONTROL_PREFIXES:
            tokens.pop(0)
        elif executable == "exec":
            tokens.pop(0)
            _strip_exec_options(tokens)
        elif executable == "time":
            tokens.pop(0)
            while tokens and tokens[0] in ("-p", "--"):
                option = tokens.pop(0)
                if option == "--":
                    break
        elif executable == "command":
            tokens.pop(0)
            while tokens and tokens[0] in ("-p", "--"):
                tokens.pop(0)
        elif executable == "builtin":
            tokens.pop(0)
            if tokens and tokens[0] == "--":
                tokens.pop(0)
        elif executable == "noglob":
            tokens.pop(0)
        elif executable == "env":
            tokens.pop(0)
            _strip_env_options(tokens)
        elif executable != tokens[0]:
            tokens[0] = executable
        else:
            break
    if tokens and os.path.basename(tokens[0]) == "git":
        tokens[0] = "git"
        index = 1
        while index < len(tokens):
            option = tokens[index]
            if option in ("-C", "-c", "--git-dir", "--work-tree", "--namespace",
                          "--exec-path", "--super-prefix", "--config-env"):
                if index + 1 >= len(tokens):
                    break
                index += 2
            elif option.startswith(("-C", "-c")) and option not in ("-C", "-c"):
                index += 1
            elif option in (
                "-P", "-p", "--paginate", "--no-pager", "--bare",
                "--no-replace-objects", "--no-lazy-fetch", "--no-optional-locks",
                "--no-advice", "--literal-pathspecs", "--glob-pathspecs",
                "--noglob-pathspecs", "--icase-pathspecs",
            ):
                index += 1
            elif option.startswith((
                "--git-dir=", "--work-tree=", "--namespace=", "--exec-path=",
                "--super-prefix=", "--config-env=",
            )):
                index += 1
            else:
                break
        return [tokens[0], *tokens[index:]]
    if tokens and os.path.basename(tokens[0]) == "rm":
        tokens[0] = "rm"
        recursive = False
        force = False
        for token in tokens[1:]:
            if token == "--":
                break
            if token == "--recursive":
                recursive = True
            elif token == "--force":
                force = True
            elif token.startswith("-") and not token.startswith("--"):
                recursive |= "r" in token[1:] or "R" in token[1:]
                force |= "f" in token[1:]
        if recursive and force:
            return ["rm", "-rf"]
    return tokens


def find_denied_match(segments, substitutions, deny_rules, normalized_deny_rules, denied_patterns):
    """Return the first denied rule or pattern matching segments or nested substitutions."""
    for segment in segments:
        normalized = normalize_for_deny(segment)
        for rule, normalized_rule in zip(deny_rules, normalized_deny_rules):
            if normalized[:len(normalized_rule)] == normalized_rule:
                return " ".join(rule)
        matched_pattern = matches_any_glob(segment, normalized, denied_patterns)
        if matched_pattern:
            return matched_pattern
    for substitution in substitutions:
        raw_sub_segments, _, _, nested_substitutions = split_command(substitution)
        sub_segments = [strip_environment(segment[:]) for segment in raw_sub_segments]
        denied = find_denied_match(
            sub_segments,
            nested_substitutions,
            deny_rules,
            normalized_deny_rules,
            denied_patterns,
        )
        if denied:
            return denied
    return None


def main():
    """Read the hook payload and emit a permission decision when applicable."""
    try:
        policy_path = os.environ.get("AI_PERMISSIONS_FILE")
        if not policy_path:
            policy_path = os.path.expanduser("~/.config/ai/permissions.json")
        with open(policy_path, encoding="utf-8") as policy_file:
            policy = json.load(policy_file)
        if not isinstance(policy, dict):
            raise ValueError("Malformed policy")
        allow_rules = policy_rules(policy, "allow")
        deny_rules = policy_rules(policy, "deny")
        restricted_patterns = policy_patterns(policy, "restricted_patterns")
        denied_patterns = policy_patterns(policy, "denied_patterns")
        normalized_deny_rules = [normalize_for_deny(rule) for rule in deny_rules]
    except (OSError, ValueError, TypeError):
        print('{"permissionDecision":"deny","permissionDecisionReason":"AI permissions policy is missing or invalid."}')
        return

    try:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict):
            return
        tool_args = payload.get("toolArgs")
        if isinstance(tool_args, str):
            tool_args = json.loads(tool_args)
        if not isinstance(tool_args, dict):
            return
        command = tool_args.get("command")
        if not isinstance(command, str) or not command.strip():
            return

        raw_segments, segment_has_vars, unsafe, substitutions = split_command(command)
        segments = [strip_environment(segment[:]) for segment in raw_segments]
        unsafe |= any(len(raw) != len(segment) for raw, segment in zip(raw_segments, segments))
        unsafe |= any(
            has_var and segment and os.path.basename(segment[0]) in ARGUMENT_SENSITIVE_COMMANDS
            for segment, has_var in zip(segments, segment_has_vars)
        )
        unsafe |= any(
            token.startswith(RESTRICTED_FLAG_PREFIXES)
            for segment in segments for token in segment
        )
        unsafe |= any(
            matches_any_glob(segment, normalize_for_deny(segment), restricted_patterns) is not None
            for segment in segments
        )

        denied = find_denied_match(
            segments,
            substitutions,
            deny_rules,
            normalized_deny_rules,
            denied_patterns,
        )
        if denied:
            print(json.dumps({
                "permissionDecision": "deny",
                "permissionDecisionReason": "Command matches denied rule: " + denied,
            }, separators=(",", ":")))
            return

        if not segments or any(not segment for segment in segments):
            return

        if not unsafe and all(matches_rule(segment, allow_rules) for segment in segments):
            print('{"permissionDecision":"allow"}')
    except (OSError, ValueError, TypeError):
        return


if __name__ == "__main__":
    main()
