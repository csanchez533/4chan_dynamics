import parse_thread
import argparse
import sys
import numpy as np
import re
from collections import defaultdict

def is_child(node, child):
	if node.post_id == child.post_id:
		return True
		
	for i in node.children:
		if is_child(i, child):
			return True
			
	return False

def lca(root, u, v):
	for child in root.children:
		if is_child(child, u) and is_child(child, v):
			return lca(child, u, v)
	return root

def depth(root, target):
    def rec(node, d):
        if node.post_id == target.post_id:
            return d

        for child in node.children:
            result = rec(child, d + 1)
            if result != -1:
                return result

        return -1

    return rec(root, 0)
    
def lifespan(thread):
	s = sorted(thread, key = lambda x: x.timestamp)
	l = s[-1].timestamp - s[0].timestamp
	return l
	
def vel(thread):
	return len(thread) / lifespan(thread)
	
def img_ratio(thread):
	n = 0
	for t in thread:
		if t.comment_text.strip() == "" or t.comment_text.strip() == "IMG":
			n += 1
	return (n / len(thread))
	
def general(text):
	text = text.lower()
	return (
	    bool(re.search(r"(\bprev(?:ious)?\b|\bedition\b|\bgeneral\b|\bmegathread\b)", text)) 
	    or bool(re.search(r"#\d+", text))
	    #or bool(re.search(r">>\d{6,}", text))
	    
	)
	
def avg_comment_len(thread):
	total = 0
	for c in thread:
		total += len(c.comment_text)
	return total / len(thread)


if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	
	#min and max thread size
	parser.add_argument("--min", type = int, default = 0)
	parser.add_argument("--max", type = int, default = -1)
	
	#what IV to sort the threads by
	parser.add_argument("--sort", type = str, default = "vel")
	
	#use within-thread z-scores or just the raw values
	parser.add_argument("--raw", action = "store_true")
	
	#sort threads by velocity capped at --cap
	parser.add_argument("--cap", type = int, default = -1)
	
	args = parser.parse_args()
	
	boards = defaultdict(list)
	
	for line in sys.stdin:
		thread = line.strip()
		comments = parse_thread.parse_json(thread)
		root = parse_thread.build_tree(comments)
		flat = parse_thread.tree_as_list(root)
		
		board_name = thread.split("_")[0]
		
		if len(flat) > 1:
			boards[board_name].append([thread, root])
	
	thread_stats = defaultdict(dict)
	def cap(arr, l):
		return arr if l == -1 else arr[:l]
		#return arr
	
	all_threads = []
	for board, threads in boards.items():
	    for thread in threads:
	        all_threads.append(thread[1])
	
	
	for board, threads in boards.items():
		
		for thread in threads:
			name = thread[0]
			root = thread[1]
			
			fmt_with_blanks = parse_thread.FormatProfile(remove_blanks = False)
			fmt = parse_thread.FormatProfile()
			
			flat_with_blanks = parse_thread.tree_as_list(root, fmt_with_blanks)
			flat = parse_thread.tree_as_list(root, fmt)
			
			avg_cl = avg_comment_len(cap(flat, args.cap))
			
			words = 0
			chars = 0
			for i in flat:
				words += len(i.comment_text.split(" "))
				chars += sum([len(x) for x in i.comment_text.split(" ")])
				
			avg_depth = 0
			for comment in flat:
				avg_depth += depth(root, comment)
			avg_depth = avg_depth / len(flat)
			
			thread_stats[name]["vel"] = vel(cap(flat, args.cap))
			thread_stats[name]["len"] = len(flat)
			thread_stats[name]["ratio"] = img_ratio(flat_with_blanks[:200])
			thread_stats[name]["general"] = 1 if general(flat[0].comment_text) else 0
			
			thread_stats[name]["avg_cl"] = avg_cl
			thread_stats[name]["avg_words"] = words / len(flat)
			thread_stats[name]["avg_depth"] = avg_depth
			thread_stats[name]["avg_word_len"] = chars / words
			thread_stats[name]["board"] = board
			thread_stats[name]["time_lags"]=[]
			for i in range(0, len(flat)):
				thread_stats[name]["time_lags"].append(flat[i].timestamp)
				
			nlink = 0
			rdeg=0
			nq=0
			for i in flat:
				if '?' in i.comment_text:
					nq += 1
				if len(i.quoted_post_ids) > 0:
					nlink += 1
					if flat[0].post_id in i.quoted_post_ids:
						rdeg += 1
				
			thread_stats[name]["nlinks"] = nlink
			thread_stats[name]["rdeg"] = rdeg
			thread_stats[name]["nq"] = nq
			
				
	output_lines = []
	for file_name, stats in sorted(thread_stats.items(), key = lambda x: x[1][args.sort], reverse = True):
		thread = None
		for board, threads in boards.items():
			for t in threads:
				if t[0] == file_name:
					thread = t[1]
					
		length = len(parse_thread.tree_as_list(thread))
		
		if length >= args.min and length <= args.max:
			thread_name = file_name.replace('.jsonl', '')
			name_parts = thread_name.split("_")
			
			vel = stats["vel"] *60
			length = stats["len"]
			ratio = stats["ratio"]
			
			b = stats["board"]
			general = stats["general"]
			
			avg_cl = stats["avg_cl"]
			nlinks = stats["nlinks"]
			rdeg=stats["rdeg"]
			nq=stats["nq"]
			avg_words=stats["avg_words"]
			avg_depth=stats["avg_depth"]
			avg_word_len = stats["avg_word_len"]
			lags=" ".join(str(l) for l in stats["time_lags"])
			
			#					   1             2         3        4     5       6        7    
			output_lines.append(f"{thread_name} {general} {length} {vel} {ratio} {avg_cl} {nlinks} {rdeg} {nq} {avg_words} {avg_depth} {avg_word_len} {lags}")
			#8      9    10          11          12             
	for l in output_lines:
		print(l)