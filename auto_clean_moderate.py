#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自动清理颜色词典 - 适中方案（删除18个敏感词）
"""

import csv
import shutil
from datetime import datetime

# 方案二：适中方案 - 删除18个敏感词
BLACKLIST = [
    # 严重敏感词
    'Bastard-amber',
    # 高度敏感词
    'Blood God', 'Blood of My Enemies', 'Blood Pact',
    'Blue Murder', 'Murder Mustard',
    'Che Guevara Red', 'Trump Tan',
    'Opium', 'Opium Mauve', 'Ecstasy', 'Orchid Ecstasy',
    # 中度敏感词（明显不当的）
    'Nipple',
    'Go to Hell Black', 'Highway to Hell', 'Hotter Than Hell',
    'Pink as Hell', 'To Hell and Black',
]

def main():
    input_file = 'Project_Color/Resources/colornames.csv'
    output_file = 'Project_Color/Resources/colornames_cleaned.csv'
    
    print("=" * 80)
    print("颜色词典自动清理工具 - 适中方案")
    print("=" * 80)
    print()
    print(f"将删除 {len(BLACKLIST)} 个敏感词汇")
    print()
    
    # 备份原文件
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_file = f"{input_file}.backup_{timestamp}"
    shutil.copy2(input_file, backup_file)
    print(f"✅ 已备份原文件到: {backup_file}")
    print()
    
    # 读取并过滤数据
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
    
    # 写入清理后的数据
    with open(output_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(kept_rows)
    
    # 输出结果
    print("=" * 80)
    print("清理完成")
    print("=" * 80)
    print()
    print(f"📊 统计信息：")
    print(f"   原始颜色数量: {total_count:,}")
    print(f"   保留颜色数量: {len(kept_rows):,} ({len(kept_rows)/total_count*100:.3f}%)")
    print(f"   删除颜色数量: {len(removed_rows):,} ({len(removed_rows)/total_count*100:.3f}%)")
    print()
    
    if removed_rows:
        print("🗑️  已删除的颜色：")
        for i, row in enumerate(removed_rows, 1):
            print(f"   {i:2d}. {row['name']:30s} ({row['hex']})")
        print()
    
    print(f"📄 输出文件: {output_file}")
    print()
    print("=" * 80)
    print("✅ 清理成功！")
    print("=" * 80)
    print()
    print("📝 下一步：")
    print("   1. 检查输出文件确认无误")
    print("   2. 如果满意，替换原文件:")
    print(f"      cp {output_file} {input_file}")
    print()
    print("   或者恢复备份:")
    print(f"      cp {backup_file} {input_file}")
    print()

if __name__ == '__main__':
    main()


