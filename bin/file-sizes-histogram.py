#!/usr/bin/env python3

import os
import pdb
import matplotlib.pyplot as plt
import bisect
import math

def file_sizes(directory):
    file_sizes = []
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            file_sizes.append(float(os.path.getsize(file_path)))
    return file_sizes

def transform(data):
    # Put data into bins
    size0 = float(1024)                  # 1k
    max_size = 1024 * 1024 * 1024 * 1024 # 1 TiB
    bin_sizes = [int(size0)]
    index = 0.0
    factor = 10.0
    while bin_sizes[-1] < max_size:
        index += 1.0
        bin_sizes.append(float(int(pow(size0, 1.0 + index / factor))))
    bin_sizes.pop() # Remove the last element

    # Calculate the bytes for each class of file
    sizes = [0] * len(bin_sizes)
    counts = [0] * len(bin_sizes)
    indices = [bisect.bisect_left(bin_sizes, x) for x in data]
    for index, x in zip(indices, data):
        sizes[index] += float(x)
        counts[index] += 1
    return bin_sizes, sizes, counts
    

def plot_bar(ax, categories, values, ylabel, title):
    ax.bar(categories, values)
    ax.set_xlabel("File Size, 2^X bytes")
    ax.set_ylabel(ylabel)
    ax.set_title(title)

    
if __name__ == "__main__":
    directory = os.getcwd()
    print(f"Getting file sizes, directory: {directory}")
    one_mib = 1024.0 * 1024.0
    one_gib = 1024.0 * 1024.0 * 1024.0
    raw_sizes = file_sizes(directory)
    bin_sizes, bin_totals, bin_counts = transform(raw_sizes)
    #@ pdb.set_trace()

    categories = [f"{int(math.log2(x))}" for x in bin_sizes]
    bin_sizes_gib = [x / one_gib for x in bin_totals]
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
    
    print(f"Plotting histogram, len(data): {len(raw_sizes)}")
    plot_bar(ax1, categories, bin_counts, "File Count", "Historgram")

    
    print(f"Plotting bar-char, len(data): {len(raw_sizes)}")
    plot_bar(ax2, categories, bin_sizes_gib, "Total Size (GiB)", "Disk Usage")
 
    plt.show()
    
