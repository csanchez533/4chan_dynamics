from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Optional
import argparse
from math import log
import numpy as np
import re
@dataclass
class CommentNode:
	post_id: int
	parent_id: Optional[int]
	author: str
	timestamp: int
	comment_text: str
	quoted_post_ids: list[int] = field(default_factory=list)
	children: list["CommentNode"] = field(default_factory=list)

	def to_dict(self) -> dict:
		return {
			"post_id": self.post_id,
			"parent_id": self.parent_id,
			"author": self.author,
			"timestamp": self.timestamp,
			"comment_text": self.comment_text,
			"quoted_post_ids": self.quoted_post_ids,
			"children": [child.to_dict() for child in self.children],
		}


def parse_json(path: str) -> list[CommentNode]:
	comments: list[CommentNode] = []

	with open(path, "r", encoding="utf-8") as f:
		for line_num, line in enumerate(f, start=1):
			line = line.strip()
			if not line:
				continue

			try:
				record = json.loads(line)
			except json.JSONDecodeError as e:
				raise ValueError(f"Bad JSON on line {line_num} of {path}: {e}") from e

			quoted = record.get("quoted_post_ids", [])
			if quoted is None:
				quoted = []

			comments.append(
				CommentNode(
					post_id=int(record["post_id"]),
					parent_id=None,
					author=record.get("author", "Anonymous"),
					timestamp=int(record.get("timestamp", 0)),
					comment_text=record.get("comment_text", ""),
					quoted_post_ids=[int(x) for x in quoted],
				)
			)

	return comments


def build_tree(comments: list[CommentNode]) -> CommentNode:
	if not comments:
		raise ValueError("No comments found.")

	# Treat earliest comment as OP/root.
	comments_sorted = sorted(comments, key=lambda c: c.timestamp)
	root = comments_sorted[0]

	nodes = {comment.post_id: comment for comment in comments}
	seen_ids: set[int] = set()

	# Clear children in case function is reused on the same objects
	for node in comments:
		node.children = []
		node.parent_id = None

	for node in comments_sorted:
		seen_ids.add(node.post_id)

		if node.post_id == root.post_id:
			continue

		parent_id = None

		# Pick the first quoted post that exists in this thread
		# and is not the post itself.
		for quoted_id in node.quoted_post_ids:
			if quoted_id in nodes and quoted_id != node.post_id:
				parent_id = quoted_id
				break

		# Fallback: attach to root/OP
		if parent_id is None:
			parent_id = root.post_id

		node.parent_id = parent_id
		nodes[parent_id].children.append(node)

	return root

def get_indents(root):
	
	indents = {root.post_id: 0}
	def rec(node, indent):
		for i in sorted(node.children, key = lambda x: x.timestamp):
			indents[i.post_id] = indent + 1
			rec(i, indent + 1)
	rec(root, 0)
	return indents

def body(s):
	text = s.replace("\n", " ").strip()
	text = re.sub(r">>\d+", "", text)
	text = re.sub(r"\s+", " ", text).strip()
	
	return text
	

def tree_as_list(root, fmt = None):
	if fmt is None:
		fmt = FormatProfile()
	
	out = []
	
	def rec(node):
		t = body(node.comment_text)
		if not fmt.remove_blanks or t != "":
			out.append(node)
		for child in sorted(node.children, key = lambda x: x.timestamp):
			rec(child)

	rec(root)
	
	time_sort = sorted(out, key = lambda x: x.timestamp)
	n = len(time_sort) if fmt.n == -1 else fmt.n
	if fmt.chrono:
		return time_sort[:n]
	
	if fmt.n == -1:
		return out
		
	def position(c):
		for i in range(len(time_sort)):
			if c.post_id == time_sort[i].post_id:
				return i
		
	final = []
	for comment in out:
		if position(comment) < fmt.n:
			final.append(comment)
		
	return final
	
def print_thread(root, fmt, n = -1):
	flat = tree_as_list(root, fmt)
	indents = get_indents(root)
	
	l = len(flat) if n == -1 else n
	for i in range(l):
		print(fmt.f(flat[i], indent = indents[flat[i].post_id], number = i))

class FormatProfile:
	def __init__(self, indent = False, n = -1, cap = -1, numbered = False, remove_links = True, only_indents = True, remove_blanks = True, chrono = True):
		self.indent = indent
		self.cap = int(cap)
		self.numbered = numbered
		self.remove_links = remove_links
		self.remove_blanks = remove_blanks
		self.chrono = chrono
		self.only_indents = only_indents
		self.n = int(n)
	
	def f(self, comment, number = -1, indent = -1):
		number_str = ""
		indent_str = ""
		
		if self.only_indents:
			if indent == -1:
				raise Exception("Must specify indent number for FormatProfile with only_indent = True")
			else:
				return indent
				
		if self.numbered:
			if number == -1:
				raise Exception("Must specify comment number for FormatProfile with numbered = True")
			else:
				number_str = str(number) + ". "
		
		if self.indent:
			if indent == -1:
				raise Exception("Must specify indent number for FormatProfile with indent = True")
			else:
				indent_str = '  ' * indent
		
		text = comment.comment_text.replace("\n", " ").strip()
		
		
		text = text if self.cap == -1 else text[:min(len(text), self.cap)]
		
		if self.remove_links:
			text = re.sub(r">>\d+", "", text)
			
		text = re.sub(r"\s+", " ", text).strip()
		
		return f"{indent_str}{number_str}{text}"
		
if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("input", type = str)
	
	# display first n comments
	parser.add_argument("-n", type = int, default = -1)
	
	# display post number in time series
	parser.add_argument("-c", action = "store_true")
	
	#display indents
	parser.add_argument("-i", action = "store_true")
	
	# display in nested "reddit style" reply order
	parser.add_argument("--nested", action = "store_true")
	
	# cap comments to length cap
	parser.add_argument("--cap", type = int, default = -1)
	
	# remove blanks
	parser.add_argument("--leaveblanks", action = "store_true")
	parser.add_argument("--onlyindents", action = "store_true")
	
	args = parser.parse_args()
	path = args.input
	comments = parse_json(path)
	root = build_tree(comments)
	
	
	fmt = FormatProfile(indent = args.i, n = args.n, cap = args.cap, numbered = args.c, remove_links = True, remove_blanks = not args.leaveblanks, chrono = not args.nested, only_indents = args.onlyindents)

	print_thread(root, fmt)
	
		