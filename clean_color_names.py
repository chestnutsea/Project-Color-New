#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
清理颜色名称数据库，删除不当词汇
"""

import csv
import shutil
from datetime import datetime

# 方案一：严格方案（官方/教育类应用）
STRICT_BLACKLIST = [
    # 严重敏感词
    'Bastard-amber',
    # 高度敏感词
    'Blood God', 'Blood of My Enemies', 'Blood Pact',
    'Blue Murder', 'Murder Mustard',
    'Che Guevara Red', 'Trump Tan',
    'Opium', 'Opium Mauve', 'Ecstasy', 'Orchid Ecstasy',
    # 中度敏感词（全部）
    'Ake Blood', 'Animal Blood', "Bat's Blood Soup", 'Bestial Blood',
    'Bite the Bullet', 'Blood', 'Blood Brother', 'Blood Burst', 'Blood Donor',
    'Blood Kiss', 'Blood Mahogany', 'Blood Omen', 'Blood Organ',
    'Blood Rose', 'Blood Rush', 'Blood Thorn', 'Choco Death', 'Dead 99',
    'Dead Blue Eyes', 'Dead Forest', 'Dead Grass', 'Dead Lake', 'Dead Pixel',
    'Death Guard', 'Death of a Star', 'Demon', 'Demon Princess',
    'Detailed Devil', 'Devil Blue', "Devil's Advocate", "Devil's Butterfly",
    "Devil's Flower Mantis", "Devil's Grass", "Devil's Lip", "Devil's Plum",
    "Dragon's Blood", 'Dried Blood', 'Electric Blood', 'Evil Centipede',
    'Evil Cigar', 'Evil Eye', 'Evil Forces', 'Evil Sunz Scarlet', 'Evil-Lyn',
    'Flare Gun', 'Go to Hell Black', 'Golden Blood', 'Golden Gun', 'Gun Barrel',
    'Gun Corps Brown', 'Gun Powder', 'Hell Rider', 'Highway to Hell',
    'Hotter Than Hell', 'Machine Gun Metal', 'Matt Demon', 'Mauvey Nude',
    'Naked Noodle', 'Naked Rose', 'Nipple', 'Nude Flamingo', 'Nude Lips',
    'Pink as Hell', 'Red Blood', 'Red Dead Redemption', 'Red Death', 'Red Devil',
    'Rondo of Blood', 'Satan', "Shojo's Blood", 'Silver Bullet', 'Sneaky Devil',
    'Speaking of the Devil', 'To Hell and Black', 'Venous Blood Red',
    'Walking Dead', 'Weapon Bronze', 'White Bullet',
]

# 方案二：适中方案（一般消费类应用）[推荐]
MODERATE_BLACKLIST = [
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

# 方案三：宽松方案（创意/设计类应用）
MINIMAL_BLACKLIST = [
    'Bastard-amber',
]

def clean_csv(input_file, output_file, blacklist, backup=True):
    """
    清理CSV文件，删除黑名单中的颜色名称
    
    Args:
        input_file: 输入CSV文件路径
        output_file: 输出CSV文件路径
        blacklist: 要删除的颜色名称列表
        backup: 是否备份原文件
    """
    # 备份原文件
    if backup:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = f"{input_file}.backup_{timestamp}"
        shutil.copy2(input_file, backup_file)
        print(f"✅ 已备份原文件到: {backup_file}")
    
    # 读取并过滤数据
    kept_rows = []
    removed_rows = []
    total_count = 0
    
    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        
        for row in reader:
            total_count += 1
            if row['name'] in blacklist:
                removed_rows.append(row)
            else:
                kept_rows.append(row)
    
    # 写入清理后的数据
    with open(output_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(kept_rows)
    
    return total_count, len(kept_rows), len(removed_rows), removed_rows

def main():
    print("=" * 80)
    print("颜色名称数据库清理工具")
    print("=" * 80)
    print()
    
    input_file = 'Project_Color/Resources/colornames.csv'
    
    print("请选择清理方案：")
    print()
    print("1. 严格方案（官方/教育类应用）")
    print(f"   删除 {len(STRICT_BLACKLIST)} 个颜色名称 (0.307%)")
    print("   删除所有严重、高度和中度敏感词汇")
    print()
    print("2. 适中方案（一般消费类应用）[推荐] ⭐")
    print(f"   删除 {len(MODERATE_BLACKLIST)} 个颜色名称 (0.060%)")
    print("   删除严重和高度敏感词汇，以及明显不当的中度敏感词")
    print()
    print("3. 宽松方案（创意/设计类应用）")
    print(f"   删除 {len(MINIMAL_BLACKLIST)} 个颜色名称 (0.003%)")
    print("   只删除严重侮辱性词汇")
    print()
    print("4. 查看详细信息（不执行清理）")
    print()
    print("0. 退出")
    print()
    
    choice = input("请输入选项 (0-4): ").strip()
    
    if choice == '0':
        print("已退出")
        return
    
    if choice == '4':
        print("\n" + "=" * 80)
        print("方案一：严格方案 - 删除列表")
        print("=" * 80)
        for i, name in enumerate(STRICT_BLACKLIST, 1):
            print(f"{i}. {name}")
        
        print("\n" + "=" * 80)
        print("方案二：适中方案 - 删除列表 [推荐]")
        print("=" * 80)
        for i, name in enumerate(MODERATE_BLACKLIST, 1):
            print(f"{i}. {name}")
        
        print("\n" + "=" * 80)
        print("方案三：宽松方案 - 删除列表")
        print("=" * 80)
        for i, name in enumerate(MINIMAL_BLACKLIST, 1):
            print(f"{i}. {name}")
        
        return
    
    # 选择黑名单
    if choice == '1':
        blacklist = STRICT_BLACKLIST
        scheme_name = "严格方案"
        output_file = 'Project_Color/Resources/colornames_clean_strict.csv'
    elif choice == '2':
        blacklist = MODERATE_BLACKLIST
        scheme_name = "适中方案"
        output_file = 'Project_Color/Resources/colornames_clean_moderate.csv'
    elif choice == '3':
        blacklist = MINIMAL_BLACKLIST
        scheme_name = "宽松方案"
        output_file = 'Project_Color/Resources/colornames_clean_minimal.csv'
    else:
        print("❌ 无效的选项")
        return
    
    print()
    print(f"正在执行清理（{scheme_name}）...")
    print()
    
    # 执行清理
    total, kept, removed, removed_rows = clean_csv(
        input_file, output_file, blacklist, backup=True
    )
    
    # 输出结果
    print("=" * 80)
    print("清理完成")
    print("=" * 80)
    print()
    print(f"📊 统计信息：")
    print(f"   原始颜色数量: {total:,}")
    print(f"   保留颜色数量: {kept:,}")
    print(f"   删除颜色数量: {removed:,} ({removed/total*100:.3f}%)")
    print()
    print(f"📄 输出文件: {output_file}")
    print()
    
    if removed_rows:
        print("🗑️  已删除的颜色：")
        for i, row in enumerate(removed_rows, 1):
            print(f"   {i}. {row['name']} ({row['hex']})")
        print()
    
    print("✅ 清理完成！")
    print()
    print("📝 下一步：")
    print(f"   1. 检查输出文件: {output_file}")
    print(f"   2. 如果满意，可以替换原文件:")
    print(f"      mv {output_file} {input_file}")
    print()

if __name__ == '__main__':
    main()

