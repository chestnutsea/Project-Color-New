#!/usr/bin/env python3
"""
脚本：将 InfoPlist.strings 本地化文件添加到 Xcode 项目
"""

import sys
import uuid

def generate_uuid():
    """生成24位唯一ID（Xcode格式）"""
    return uuid.uuid4().hex[:24].upper()

def add_infoplist_strings_to_xcode(pbxproj_path):
    """将 InfoPlist.strings 文件添加到 Xcode 项目"""
    
    try:
        with open(pbxproj_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"❌ 无法读取 {pbxproj_path}: {e}")
        return False
    
    # 生成唯一 ID
    variant_group_id = generate_uuid()
    en_file_ref_id = generate_uuid()
    zh_file_ref_id = generate_uuid()
    en_build_file_id = generate_uuid()
    zh_build_file_id = generate_uuid()
    
    print("🔧 生成的 ID:")
    print(f"   Variant Group: {variant_group_id}")
    print(f"   EN File Ref:   {en_file_ref_id}")
    print(f"   ZH File Ref:   {zh_file_ref_id}")
    
    # 1. 添加 PBXBuildFile 部分
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_entries = f"""\t\t{en_build_file_id} /* InfoPlist.strings in Resources */ = {{isa = PBXBuildFile; fileRef = {variant_group_id} /* InfoPlist.strings */; }};
"""
    
    if build_file_section in content:
        content = content.replace(
            build_file_section,
            build_file_section + "\n" + build_file_entries
        )
        print("✅ 添加 PBXBuildFile 条目")
    else:
        print("⚠️  未找到 PBXBuildFile section")
    
    # 2. 添加 PBXFileReference 部分
    file_ref_section = "/* Begin PBXFileReference section */"
    file_ref_entries = f"""\t\t{en_file_ref_id} /* en */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = en; path = en.lproj/InfoPlist.strings; sourceTree = "<group>"; }};
\t\t{zh_file_ref_id} /* zh-Hans */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = "zh-Hans"; path = "zh-Hans.lproj/InfoPlist.strings"; sourceTree = "<group>"; }};
"""
    
    if file_ref_section in content:
        content = content.replace(
            file_ref_section,
            file_ref_section + "\n" + file_ref_entries
        )
        print("✅ 添加 PBXFileReference 条目")
    else:
        print("⚠️  未找到 PBXFileReference section")
    
    # 3. 添加 PBXVariantGroup 部分
    variant_group_section = "/* Begin PBXVariantGroup section */"
    if variant_group_section not in content:
        # 如果没有 PBXVariantGroup section，需要创建
        resource_build_phase_end = "/* End PBXResourcesBuildPhase section */"
        variant_group_content = f"""/* End PBXResourcesBuildPhase section */

/* Begin PBXVariantGroup section */
\t\t{variant_group_id} /* InfoPlist.strings */ = {{
\t\t\tisa = PBXVariantGroup;
\t\t\tchildren = (
\t\t\t\t{en_file_ref_id} /* en */,
\t\t\t\t{zh_file_ref_id} /* zh-Hans */,
\t\t\t);
\t\t\tname = InfoPlist.strings;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXVariantGroup section */
"""
        content = content.replace(resource_build_phase_end, variant_group_content)
        print("✅ 创建并添加 PBXVariantGroup section")
    else:
        variant_group_entry = f"""\t\t{variant_group_id} /* InfoPlist.strings */ = {{
\t\t\tisa = PBXVariantGroup;
\t\t\tchildren = (
\t\t\t\t{en_file_ref_id} /* en */,
\t\t\t\t{zh_file_ref_id} /* zh-Hans */,
\t\t\t);
\t\t\tname = InfoPlist.strings;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
        content = content.replace(
            variant_group_section,
            variant_group_section + "\n" + variant_group_entry
        )
        print("✅ 添加 PBXVariantGroup 条目")
    
    # 4. 在 Project_Color 组中添加引用
    # 查找 Project_Color 的 children 数组
    import re
    project_color_pattern = r'(/\* Project_Color \*/\s*=\s*\{[^}]*children\s*=\s*\([^)]*)'
    match = re.search(project_color_pattern, content, re.DOTALL)
    
    if match:
        children_section = match.group(1)
        new_children_section = children_section + f"\n\t\t\t\t{variant_group_id} /* InfoPlist.strings */,"
        content = content.replace(children_section, new_children_section)
        print("✅ 添加到 Project_Color 组")
    else:
        print("⚠️  未找到 Project_Color 组的 children 部分")
    
    # 5. 在 Resources Build Phase 中添加
    resources_pattern = r'(/\* Resources \*/\s*=\s*\{[^}]*files\s*=\s*\([^)]*)'
    match = re.search(resources_pattern, content, re.DOTALL)
    
    if match:
        files_section = match.group(1)
        new_files_section = files_section + f"\n\t\t\t\t{en_build_file_id} /* InfoPlist.strings in Resources */,"
        content = content.replace(files_section, new_files_section)
        print("✅ 添加到 Resources Build Phase")
    else:
        print("⚠️  未找到 Resources Build Phase")
    
    # 6. 添加本地化语言（如果还没有）
    # 查找 knownRegions
    regions_pattern = r'(knownRegions\s*=\s*\([^)]*)'
    match = re.search(regions_pattern, content)
    
    if match:
        regions_section = match.group(1)
        if 'en,' not in regions_section:
            new_regions = regions_section + "\n\t\t\t\ten,"
            content = content.replace(regions_section, new_regions)
            print("✅ 添加 en 到 knownRegions")
        if '"zh-Hans"' not in regions_section and 'zh-Hans' not in regions_section:
            new_regions = regions_section + '\n\t\t\t\t"zh-Hans",'
            content = content.replace(regions_section, new_regions)
            print("✅ 添加 zh-Hans 到 knownRegions")
    
    # 保存修改
    try:
        with open(pbxproj_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n✅ 成功更新 {pbxproj_path}")
        return True
    except Exception as e:
        print(f"❌ 无法写入 {pbxproj_path}: {e}")
        return False

def main():
    pbxproj_path = "Project_Color.xcodeproj/project.pbxproj"
    
    print("=" * 60)
    print("📦 添加 InfoPlist.strings 到 Xcode 项目")
    print("=" * 60)
    
    if add_infoplist_strings_to_xcode(pbxproj_path):
        print("\n✅ 完成！请在 Xcode 中重新加载项目。")
        print("\n📝 后续步骤：")
        print("   1. 关闭 Xcode")
        print("   2. 重新打开项目")
        print("   3. 验证 InfoPlist.strings 文件已添加")
        print("   4. 检查本地化设置")
        return 0
    else:
        print("\n❌ 添加失败，请检查错误信息。")
        return 1

if __name__ == "__main__":
    sys.exit(main())

