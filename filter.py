import sys
import argparse
import parse_thread

parser = argparse.ArgumentParser()
parser.add_argument("--min", type=int, default = 1)
parser.add_argument("--max", type=int, default = 10000)

args = parser.parse_args()
		
def img_ratio(thread):
	n = 0
	for t in thread:
		if t.comment_text.strip() == "" or t.comment_text.strip() == "IMG":
			n += 1
	return (n / len(thread))
	
output = []
for line in sys.stdin:
	l = line.strip()
	thread = parse_thread.parse_json(l)
	root = parse_thread.build_tree(thread)
	fmt_without = parse_thread.FormatProfile()
	fmt_with = parse_thread.FormatProfile(remove_blanks = False)
	
	flat = parse_thread.tree_as_list(root, fmt_without)
	with_blanks = parse_thread.tree_as_list(root, fmt_with)
	
	if len(flat) >= args.min and len(flat) <= args.max and img_ratio(with_blanks[:200]) < 0.05:
		output.append(l)
		
for line in output:
	print(line)