import fnmatch
import json
import re

_REGEX_META_CHARS = frozenset(".^$+?{}[]\\|()")


def from_jsonc(value):
    """Parse JSONC after removing comments and trailing commas."""
    cleaned = []
    quote = None
    escaped = False
    index = 0

    while index < len(value):
        char = value[index]
        following = value[index + 1:index + 2]

        if quote:
            cleaned.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
        elif char == '"':
            quote = char
            cleaned.append(char)
            index += 1
        elif char == "/" and following == "/":
            index += 2
            while index < len(value) and value[index] not in "\r\n":
                index += 1
        elif char == "/" and following == "*":
            end = value.find("*/", index + 2)
            if end == -1:
                raise ValueError("Unterminated JSONC block comment")
            index = end + 2
        else:
            cleaned.append(char)
            index += 1

    without_comments = "".join(cleaned)
    cleaned = []
    quote = None
    escaped = False
    index = 0

    while index < len(without_comments):
        char = without_comments[index]
        if quote:
            cleaned.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char == '"':
            quote = char
            cleaned.append(char)
        elif char == ",":
            following = index + 1
            while following < len(without_comments) and without_comments[following].isspace():
                following += 1
            if following == len(without_comments) or without_comments[following] not in "}]":
                cleaned.append(char)
        else:
            cleaned.append(char)
        index += 1

    return json.loads("".join(cleaned))


def _escape_regex_literal(text):
    """Escape regex metacharacters while keeping hyphens and slashes literal."""
    return "".join("\\" + char if char in _REGEX_META_CHARS else char for char in text)


def antigravity_command_rule(pattern):
    """Compile a command pattern into an Antigravity command(...) or command(regex:...) rule."""
    if "*" not in pattern:
        return f"command({pattern})"
    tokens = pattern.split()
    regex_tokens = [
        ".*".join(_escape_regex_literal(part) for part in token.split("*"))
        for token in tokens
    ]
    body = r"\s+".join(regex_tokens)
    suffix = "$" if pattern.rstrip().endswith("*") else r"(?:\s+.*)?$"
    return f"command(regex:^{body}{suffix})"


def antigravity_ask_conflicts(ask, managed_commands, managed_patterns):
    """Return True if an existing Antigravity ask rule conflicts with managed command rules."""
    if not isinstance(ask, str) or not (ask.startswith("command(") and ask.endswith(")")):
        return False
    inner = ask[8:-1]
    if inner == "*":
        return True
    if inner.startswith("regex:"):
        try:
            compiled = re.compile(inner[6:])
        except re.error:
            return False
        if any(compiled.search(command) for command in managed_commands):
            return True
        for pattern in managed_patterns:
            if ask == antigravity_command_rule(pattern):
                return True
            if compiled.search(pattern.replace("*", "x")) or compiled.search(pattern.replace("*", "")):
                return True
        return False
    for command in managed_commands:
        if inner == command or inner.startswith(command + " ") or command.startswith(inner + " "):
            return True
    return any(
        inner == pattern
        or fnmatch.fnmatchcase(inner, pattern)
        or fnmatch.fnmatchcase(pattern, inner)
        for pattern in managed_patterns
    )


class FilterModule:
    def filters(self):
        return {
            "from_jsonc": from_jsonc,
            "antigravity_command_rule": antigravity_command_rule,
            "antigravity_ask_conflicts": antigravity_ask_conflicts,
        }
