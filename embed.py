from openai import OpenAI
client = OpenAI()
import sys
import numpy as np
import argparse

import matplotlib.pyplot as plt

vlist = []
for line in sys.stdin:
    vr = client.embeddings.create(input=line.strip(), model="text-embedding-3-large")
    vlist.append(vr.data[0].embedding)
          
m = np.array(vlist)
mdp = np.dot(m, m.T)
for row in mdp:
    print(*row,sep=',')