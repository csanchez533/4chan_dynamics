#!/usr/bin/env python3

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional
import random
import numpy as np
import matplotlib.pyplot as plt
import statistics
import os
from bs4 import BeautifulSoup

import requests

CATALOG_URL = "https://a.4cdn.org/{board}/catalog.json"
THREAD_URL_TEMPLATE = "https://a.4cdn.org/{board}/thread/{thread_id}.json"
ARCHIVE_URL = "https://a.4cdn.org/{board}/archive.json"
QUOTE_RE = re.compile(r">>(\d+)")


class PostNode:
    post_id: int
    parent_id: Optional[int]
    subject: str
    author: str
    timestamp: int
    comment_html: str
    comment_text: str
    quoted_post_ids: List[int] = field(default_factory=list)
    children: List["PostNode"] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "post_id": self.post_id,
            "parent_id": self.parent_id,
            "subject": self.subject,
            "author": self.author,
            "timestamp": self.timestamp,
            "comment_text": self.comment_text,
            "quoted_post_ids": self.quoted_post_ids,
            "children": [child.to_dict() for child in self.children],
        }


def fetch_json(url: str, timeout: int = 20):
    headers = {
        "User-Agent": "x"
    }
    resp = requests.get(url, headers=headers, timeout=timeout)
    resp.raise_for_status()
    return resp.json()

def strip_comment_html(text):
    html = text

    soup = BeautifulSoup(html, "html.parser")
    
    # Fill empty quote links using the post ID from the href.
    for link in soup.select("a.quotelink"):
        href = link.get("href", "")
        match = re.search(r"#p(\d+)", href)
    
        if match and not link.get_text(strip=True):
            link.string = f">>{match.group(1)}"
    
    # Convert <br> tags to line breaks.
    for br in soup.find_all("br"):
        br.replace_with("\n")
    
    text = soup.get_text()
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    
    return text
    
def extract_quote_ids(comment_html: str) -> List[int]:
    """
    Pull out all >>123456 style references from the raw comment HTML/text.
    """
    if not comment_html:
        return []
    text = html.unescape(comment_html)
    return [int(m.group(1)) for m in QUOTE_RE.finditer(text)]


def save_matching_threads(min_posts,
                          max_posts,
                          out_dir, out,
                          board,
                          max_archive_tries = 200) -> int:
    try:
        archive_ids = fetch_json(f"https://a.4cdn.org/{board}/archive.json")
    except requests.RequestException as e:
        raise RuntimeError(f"Could not fetch archive for /{board}/: {e}")

    if not archive_ids:
        raise RuntimeError(f"No archived threads found for /{BOARD}/.")

    os.makedirs(out_dir, exist_ok=True)

    thread_ids = list(archive_ids)
    random.shuffle(thread_ids)

    saved = 0
    tries = 0

    threads = []
    for thread_id in thread_ids:
        if tries >= max_archive_tries:
            break
        tries += 1

        try:
            thread_json = fetch_json(
                THREAD_URL_TEMPLATE.format(board=BOARD, thread_id=thread_id)
            )
        except requests.RequestException:
            continue

        posts = thread_json.get("posts", [])
        total_posts = len(posts)

        if min_posts <= total_posts <= max_posts:
            threads.append(posts)

    saved = 0
    
    for thread in sorted(threads, key = lambda x: len(x)):
        if out == "":
            out = board
        out_path = os.path.join(out_dir, f"{out}_{saved}.jsonl")
        
        with open(out_path, "w", encoding="utf-8") as f:
            for post in thread:
                comment_html = post.get("com", "")
                comment_text = strip_comment_html(comment_html)
                
        
                record = {
                    "post_id": post.get("no"),
                    "parent_id": None if post.get("resto", 0) == 0 else post.get("resto"),
                    "author": post.get("name"),
                    "timestamp": post.get("time"),
                    "comment_text": comment_text,
                    "quoted_post_ids": extract_quote_ids(comment_html),
                }
        
                f.write(json.dumps(record, ensure_ascii=False) + "\n")

        saved += 1

    if saved == 0:
        raise RuntimeError(
            f"No archived threads found with {min_posts}–{max_posts} posts "
            f"after checking {tries} threads."
        )

    return saved
    
def build_tree(posts: List[dict]) -> PostNode:
    
    if not posts:
        raise RuntimeError("Thread contains no posts.")

    op_post = posts[0]
    op_id = int(op_post["no"])

    # First pass: build nodes
    nodes: Dict[int, PostNode] = {}
    for post in posts:
        post_id = int(post["no"])
        comment_html = post.get("com", "")
        node = PostNode(
            post_id=post_id,
            parent_id=None,
            subject=post.get("sub", ""),
            author=post.get("name", "Anonymous"),
            timestamp=int(post.get("time", 0)),
            comment_html=comment_html,
            comment_text=strip_comment_html(comment_html),
            quoted_post_ids=extract_quote_ids(comment_html),
        )
        nodes[post_id] = node

    # Second pass: assign parent
    for post in posts:
        post_id = int(post["no"])
        if post_id == op_id:
            continue

        node = nodes[post_id]

        # choose first in-thread quoted post as parent
        parent_id = None
        for quoted_id in node.quoted_post_ids:
            if quoted_id in nodes and quoted_id != post_id:
                parent_id = quoted_id
                break

        # default to OP when there is no in-thread quote target
        if parent_id is None:
            parent_id = op_id

        node.parent_id = parent_id
        nodes[parent_id].children.append(node)

    return nodes[op_id]


def main() -> int:
    parser = argparse.ArgumentParser()
    
    parser.add_argument("--board", type = str, required = True)
    parser.add_argument("--min", type = int, required = True)
    parser.add_argument("--max", type = int, required = True)
    parser.add_argument("--out_dir", type = str, default = "")
    parser.add_argument("--out", type = str, default = "")
    
    args = parser.parse_args()
    
    save_matching_threads(min_posts = args.min, max_posts = args.max, out_dir = args.out_dir, out = args.out)

if __name__ == "__main__":
    raise SystemExit(main())