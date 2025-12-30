#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import csv
import shutil
from datetime import datetime

# 要删除的18个敏感词
BLACKLIST = [
    'Bastard-amber',
    'Blood God', 'Blood of My Enemies', 'Blood Pact',
    'Blue Murder', 'Murder Mustard',
    'Che Guevara Red', 'Trump Tan',
    'Opium', 'Opium Mauve', 'Ecstasy', 'Orchid Ecstasy',
    'Nipple',
    'Go to Hell Black', 'Highway to Hell', 'Hotter Than Hell',
    'Pink as Hell', 'To Hell and Black',
]

input_file = '/Users/linyahuang/Project_Color/Project_Color/Resources/colornames.csv'
output_file = '/Users/linyahuang/Project_Color/Project_Color/Resources/colornames_cleaned.csv'

# 备份
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
backup_file = f"{input_file}.backup_{timestamp}"
shutil.copy2(input_file, backup_file)

# 读取并过滤
kept_rows = []
removed_rows = []
total_count = 0

with open(input_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    
    for row in reader:
        total_count += 1
        if row['name'] in BLACKLIST:
            removed_rows.append(row)
        else:
            kept_rows.append(row)

# 写入
with open(output_file, 'w', encoding='utf-8', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(kept_rows)

# 输出结果
print("=" * 80)
print("颜色词典清理完成")
print("=" * 80)
print(f"\n原始数量: {total_count:,}")
print(f"保留数量: {len(kept_rows):,} ({len(kept_rows)/total_count*100:.3f}%)")
print(f"删除数量: {len(removed_rows):,} ({len(removed_rows)/total_count*100:.3f}%)")
print(f"\n备份文件: {backup_file}")
print(f"输出文件: {output_file}")
print("\n已删除的颜色:")
for i, row in enumerate(removed_rows, 1):
    print(f"  {i:2d}. {row['name']:30s} ({row['hex']})")

