#!/usr/bin/env python3
"""Auto-generate the top-level README.md from each add-on's config.yaml and docs."""

import os
import yaml

HEADER = (
    "# Conall's Home Assistant Add-ons\n"
    "\n"
    "My personal collection of add-ons for [Home Assistant](https://www.home-assistant.io/).\n"
    "\n"
    "## Installation\n"
    "\n"
    "Add this repository to your Home Assistant add-on store:\n"
    "\n"
    "[![Add repository](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)]"
    "(https://my.home-assistant.io/redirect/supervisor_add_addon_repository/"
    "?repository_url=https%3A%2F%2Fgithub.com%2Fconallob%2Fhassio-addons)\n"
    "\n"
    "Or manually: **Settings** → **Add-ons** → **Add-on Store** → **⋮** → **Repositories**"
    " and add `https://github.com/conallob/hassio-addons`.\n"
    "\n"
    "---\n"
    "\n"
    "## Add-ons\n"
    "\n"
)


def find_addons():
    addons = []
    for entry in sorted(os.listdir(".")):
        if not os.path.isdir(entry) or entry.startswith("."):
            continue
        config_path = os.path.join(entry, "config.yaml")
        if not os.path.exists(config_path):
            continue
        with open(config_path) as f:
            config = yaml.safe_load(f)
        addons.append((entry, config))
    return addons


def read_addon_docs(directory):
    for fname in ("DOCS.md", "README.md"):
        p = os.path.join(directory, fname)
        if os.path.exists(p):
            with open(p) as f:
                return f.read().strip()
    return None


def addon_section(directory, config):
    name = config.get("name", directory)
    version = str(config.get("version", ""))
    description = config.get("description", "")
    external_image = config.get("image")
    source_url = config.get("url")

    link = source_url if source_url else "./" + directory
    lines = ["### [{}]({})".format(name, link), ""]

    meta = []
    if version:
        meta.append("**Version**: {}".format(version))
    if external_image:
        meta.append("**Image**: external (`{}`)".format(external_image))
    if meta:
        lines.append("  ".join(meta))
        lines.append("")

    if description:
        lines.append(description)
        lines.append("")

    if external_image and source_url:
        lines.append(
            "> The container image for this add-on is built and published by"
            " [{}]({}).".format(source_url, source_url)
            + " Only the Home Assistant add-on metadata is hosted in this repository."
        )
        lines.append("")

    docs = read_addon_docs(directory)
    if docs:
        doc_lines = docs.splitlines()
        if doc_lines and doc_lines[0].startswith("# "):
            doc_lines = doc_lines[1:]
        while doc_lines and not doc_lines[0].strip():
            doc_lines = doc_lines[1:]
        doc_lines = [("#" + l if l.startswith("#") else l) for l in doc_lines]
        lines.extend(doc_lines)
        lines.append("")

    lines.append("---")
    lines.append("")
    return "\n".join(lines)


def main():
    addons = find_addons()
    body = HEADER + "".join(addon_section(d, c) for d, c in addons)
    body = body.rstrip() + "\n"

    with open("README.md", "w") as f:
        f.write(body)

    print("Generated README.md with {} add-on(s):".format(len(addons)))
    for d, c in addons:
        note = " (external image)" if c.get("image") else ""
        print("  {}: {} v{}{}".format(d, c.get("name", "?"), c.get("version", "?"), note))


if __name__ == "__main__":
    main()
