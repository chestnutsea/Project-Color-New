#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
精准检查颜色名称中的敏感词汇（排除误报）
"""

import csv
import re
from typing import List, Tuple

# 1. 严重敏感词（必须删除）
CRITICAL_KEYWORDS = {
    # 种族歧视词（真正的歧视词汇）
    'nigger', 'nigga', 'negro', 'coon', 'spook',
    'chink', 'chinaman', 'gook', 'slant',
    'jap', 'nip', 'zipperhead',
    'kike', 'hymie', 'yid',
    'wetback', 'beaner', 'spic', 'greaser',
    'towelhead', 'raghead', 'sandnigger',
    # 性相关粗俗词汇
    'fuck', 'fucking', 'fucker', 'motherfucker',
    'shit', 'shitty', 'bullshit',
    'pussy', 'cunt', 'cock', 'penis', 'vagina',
    'tits', 'boobs', 'ass', 'asshole',
    'porn', 'porno', 'pornography', 'xxx',
    'rape', 'molest',
    'whore', 'prostitute',
    # 侮辱性词汇
    'bastard', 'bitch', 'dickhead',
    'retard', 'retarded',
}

# 2. 高度敏感词（强烈建议删除）
HIGH_SENSITIVE_KEYWORDS = {
    # 政治人物
    'hitler', 'nazi', 'trump tan',  # Trump Tan 是指特朗普的肤色
    'che guevara',
    # 毒品（真正的毒品，不是pot/weed这种多义词）
    'cocaine', 'heroin', 'meth', 'methamphetamine',
    'opium', 'morphine', 'fentanyl',
    'ecstasy', 'mdma', 'lsd',
    # 暴力倾向明显的
    'blood of my enemies', 'blood god', 'blood pact',
    'murder', 'genocide', 'massacre',
    # 恐怖主义
    'terrorist', 'terrorism', 'jihad',
}

# 3. 中度敏感词（需要审查，但很多是合理的文化引用）
MODERATE_KEYWORDS = {
    # 暴力相关（但很多是合理的）
    'blood', 'death', 'dead', 'kill',
    # 宗教相关（但很多是文化引用）
    'devil', 'demon', 'satan', 'hell', 'evil',
    # 身体相关
    'nude', 'naked', 'nipple', 'breast',
    # 武器
    'weapon', 'bomb', 'gun', 'bullet',
}

# 完全合理的例外（不应标记）
ACCEPTABLE_CONTEXTS = {
    # 自然/植物/动物
    'blood orange', 'blood moon', "dragon's blood", 'dragon blood',
    'blue blood', 'royal blood',  # 贵族
    'dead sea', 'dead nettle', 'death valley', 'death cap',  # 地名/植物
    'crack willow',  # 植物
    'garden weed', 'jewel weed', 'gulf weed', 'ocean weed',  # 植物
    # 艺术/文化引用
    'blue nude',  # 马蒂斯名画
    'moby dick',  # 文学作品
    'death by chocolate',  # 甜品
    'blue screen of death',  # 技术术语
    'bullet hell',  # 游戏类型
    # 食物/物品
    'cherry bomb', 'ice bomb', 'blush bomb',  # 鞭炮/甜品/化妆品
    "devil's flower mantis", "devil's ivy",  # 昆虫/植物
    # 历史/地理
    'empire',  # 帝国（常见于颜色命名，如Empire State）
    'imperial',  # 帝王的
    'army',  # 军队（Army Green是常见颜色）
    'soldier',  # 士兵
    # 其他合理词汇
    'heaven', 'paradise', 'angel',  # 常见文化意象
    'god',  # 在很多语境中是合理的（如"God-Given"天赐的）
    'cross',  # 十字（也是几何形状）
    'buddha',  # 佛（文化引用）
    'karma',  # 因果（文化概念）
    'spell',  # 咒语（也指"拼写"）
    'curse',  # 诅咒（也是常见表达）
    'ghost', 'vampire', 'zombie',  # 流行文化
    'monster', 'beast', 'creature',  # 常见比喻
    'dark', 'darkness', 'shadow',  # 颜色深浅
    'master',  # 大师/主人（常见词）
    'slave',  # 在某些历史语境中
    'propaganda',  # 宣传（中性词）
    'revolution',  # 革命（可以是工业革命等）
    'riot',  # 暴动（也可指"色彩缤纷"）
    'rebellion',  # 反叛（也是文化概念）
    'desire', 'lust',  # 欲望（也可以是对生活的渴望）
    'bang',  # 爆炸（也是Big Bang宇宙大爆炸）
    'strip',  # 条纹
    'hump',  # 驼峰
    'hooker',  # Hooker's Green是著名的颜色名（以植物学家命名）
    'pot',  # 罐子（flower pot等）
    'addiction',  # 上瘾（Coffee Addiction咖啡成瘾是常见表达）
    'atomic',  # 原子的（Atomic Tangerine等是常见颜色）
    'nuclear',  # 核的
    'shoot',  # 射击（也指"嫩芽"bamboo shoot）
    'assault',  # 攻击（也是颜色名）
    'assassin',  # 刺客（历史/游戏引用）
    'terror', 'horror',  # 恐怖（流行文化）
    'crazy', 'lunatic',  # 疯狂的（常见比喻）
    'mental',  # 精神的（Mental Note等）
    'plague',  # 瘟疫（也是历史词汇）
    'casino',  # 赌场（地点名称）
}

def is_acceptable(name: str, keyword: str) -> bool:
    """检查是否在可接受的上下文中"""
    name_lower = name.lower()
    
    # 检查完整短语匹配
    for context in ACCEPTABLE_CONTEXTS:
        if context in name_lower:
            return True
    
    # 特殊规则
    # "Hooker's Green" 是以植物学家William Hooker命名的颜色
    if 'hooker' in keyword and "hooker's green" in name_lower:
        return True
    
    # "Pot" 在 "flower pot", "pot of gold" 等语境中完全合理
    if keyword == 'pot' and any(x in name_lower for x in ['flower pot', 'pot of', 'pot black', 'clay pot', 'copper pot']):
        return True
    
    # "Weed" 在植物学语境中是"杂草"
    if keyword == 'weed' and any(x in name_lower for x in ['weed', 'seaweed']):
        return True
    
    # "Empire" 在历史/地理语境中合理
    if keyword == 'empire':
        return True
    
    # "Army" 在颜色命名中常见
    if keyword == 'army':
        return True
    
    # 其他在ACCEPTABLE_CONTEXTS中的词汇
    if keyword in ACCEPTABLE_CONTEXTS:
        return True
    
    return False

def check_critical(name: str) -> Tuple[bool, List[str]]:
    """检查严重敏感词"""
    name_lower = name.lower()
    found = []
    
    for keyword in CRITICAL_KEYWORDS:
        pattern = r'\b' + re.escape(keyword) + r'\b'
        if re.search(pattern, name_lower):
            found.append(keyword)
    
    return len(found) > 0, found

def check_high_sensitive(name: str) -> Tuple[bool, List[str]]:
    """检查高度敏感词"""
    name_lower = name.lower()
    found = []
    
    for keyword in HIGH_SENSITIVE_KEYWORDS:
        if ' ' in keyword:  # 多词短语
            if keyword in name_lower:
                found.append(keyword)
        else:
            pattern = r'\b' + re.escape(keyword) + r'\b'
            if re.search(pattern, name_lower):
                if not is_acceptable(name, keyword):
                    found.append(keyword)
    
    return len(found) > 0, found

def check_moderate(name: str) -> Tuple[bool, List[str]]:
    """检查中度敏感词"""
    name_lower = name.lower()
    found = []
    
    for keyword in MODERATE_KEYWORDS:
        pattern = r'\b' + re.escape(keyword) + r'\b'
        if re.search(pattern, name_lower):
            if not is_acceptable(name, keyword):
                found.append(keyword)
    
    return len(found) > 0, found

def main():
    csv_file = 'Project_Color/Resources/colornames.csv'
    
    print("=" * 80)
    print("颜色名称数据库精准敏感词审查")
    print("（已排除误报和合理的文化引用）")
    print("=" * 80)
    print()
    
    critical_items = []
    high_items = []
    moderate_items = []
    total_count = 0
    
    try:
        with open(csv_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                total_count += 1
                name = row['name']
                hex_color = row['hex']
                
                # 检查严重敏感词
                has_critical, critical_words = check_critical(name)
                if has_critical:
                    critical_items.append({
                        'name': name,
                        'hex': hex_color,
                        'keywords': critical_words
                    })
                
                # 检查高度敏感词
                has_high, high_words = check_high_sensitive(name)
                if has_high:
                    high_items.append({
                        'name': name,
                        'hex': hex_color,
                        'keywords': high_words
                    })
                
                # 检查中度敏感词
                has_moderate, moderate_words = check_moderate(name)
                if has_moderate:
                    moderate_items.append({
                        'name': name,
                        'hex': hex_color,
                        'keywords': moderate_words
                    })
    
    except FileNotFoundError:
        print(f"❌ 错误：找不到文件 {csv_file}")
        return
    except Exception as e:
        print(f"❌ 错误：{e}")
        return
    
    # 输出统计
    print(f"📊 统计信息")
    print(f"   总颜色数量: {total_count:,}")
    print(f"   严重敏感词: {len(critical_items)} ({len(critical_items)/total_count*100:.3f}%)")
    print(f"   高度敏感词: {len(high_items)} ({len(high_items)/total_count*100:.3f}%)")
    print(f"   中度敏感词: {len(moderate_items)} ({len(moderate_items)/total_count*100:.3f}%)")
    print()
    
    # 输出详情
    if critical_items:
        print("=" * 80)
        print("🔴 严重敏感词（必须删除）")
        print("=" * 80)
        print()
        for i, item in enumerate(critical_items, 1):
            print(f"{i}. {item['name']} ({item['hex']})")
            print(f"   敏感词: {', '.join(item['keywords'])}")
            print()
    else:
        print("✅ 未发现严重敏感词")
        print()
    
    if high_items:
        print("=" * 80)
        print("🟠 高度敏感词（强烈建议删除）")
        print("=" * 80)
        print()
        for i, item in enumerate(high_items, 1):
            print(f"{i}. {item['name']} ({item['hex']})")
            print(f"   敏感词: {', '.join(item['keywords'])}")
            print()
    else:
        print("✅ 未发现高度敏感词")
        print()
    
    if moderate_items:
        print("=" * 80)
        print("🟡 中度敏感词（建议根据应用场景审查）")
        print(f"   共 {len(moderate_items)} 个")
        print("=" * 80)
        print()
        for i, item in enumerate(moderate_items[:20], 1):
            print(f"{i}. {item['name']} ({item['hex']})")
            print(f"   关键词: {', '.join(item['keywords'])}")
            print()
        if len(moderate_items) > 20:
            print(f"... 还有 {len(moderate_items) - 20} 个")
            print()
    
    # 保存报告
    report_file = 'accurate_sensitive_report.txt'
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write("=" * 80 + "\n")
        f.write("颜色名称数据库精准敏感词审查报告\n")
        f.write("=" * 80 + "\n\n")
        
        f.write(f"总颜色数量: {total_count:,}\n")
        f.write(f"严重敏感词: {len(critical_items)}\n")
        f.write(f"高度敏感词: {len(high_items)}\n")
        f.write(f"中度敏感词: {len(moderate_items)}\n\n")
        
        if critical_items:
            f.write("严重敏感词（必须删除）\n")
            f.write("=" * 80 + "\n")
            for i, item in enumerate(critical_items, 1):
                f.write(f"{i}. {item['name']} ({item['hex']}) - {', '.join(item['keywords'])}\n")
            f.write("\n")
        
        if high_items:
            f.write("高度敏感词（强烈建议删除）\n")
            f.write("=" * 80 + "\n")
            for i, item in enumerate(high_items, 1):
                f.write(f"{i}. {item['name']} ({item['hex']}) - {', '.join(item['keywords'])}\n")
            f.write("\n")
        
        if moderate_items:
            f.write("中度敏感词（建议审查）\n")
            f.write("=" * 80 + "\n")
            for i, item in enumerate(moderate_items, 1):
                f.write(f"{i}. {item['name']} ({item['hex']}) - {', '.join(item['keywords'])}\n")
    
    print(f"📄 完整报告已保存到: {report_file}")
    print()
    
    # 最终评估
    print("=" * 80)
    print("📋 最终评估")
    print("=" * 80)
    print()
    
    total_issues = len(critical_items) + len(high_items) + len(moderate_items)
    clean_percentage = 100 - (total_issues / total_count * 100)
    
    print(f"✅ 完全没问题: {clean_percentage:.2f}%")
    print(f"🔴 严重问题: {len(critical_items)} 个（{len(critical_items)/total_count*100:.3f}%）")
    print(f"🟠 高度敏感: {len(high_items)} 个（{len(high_items)/total_count*100:.3f}%）")
    print(f"🟡 中度敏感: {len(moderate_items)} 个（{len(moderate_items)/total_count*100:.3f}%）")
    print()
    
    if len(critical_items) == 0 and len(high_items) == 0:
        print("🎉 数据库质量优秀！未发现严重敏感词汇。")
    elif len(critical_items) + len(high_items) < 20:
        print("👍 数据库质量良好，只需删除少量不当词汇。")
    else:
        print("⚠️  数据库需要清理，建议删除敏感词汇。")
    print()

if __name__ == '__main__':
    main()

