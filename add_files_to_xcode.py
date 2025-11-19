#!/usr/bin/env python3
"""
通用脚本：将文件添加到 Xcode 项目
用法: python3 add_files_to_xcode.py <file1> <file2> ...
"""

import re
import uuid
import sys
import os

def generate_uuid():
    """生成 Xcode 风格的 24 字符 UUID"""
    return uuid.uuid4().hex[:24].upper()

def add_files_to_project(file_paths):
    project_file = "Project_Color.xcodeproj/project.pbxproj"
    
    # 读取项目文件
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 备份
    backup_file = f"{project_file}.backup3"
    with open(backup_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ 已备份项目文件到 {backup_file}")
    
    # 查找 Views group UUID
    views_pattern = r'([A-F0-9]{24}) /\* Views \*/ = \{'
    views_match = re.search(views_pattern, content)
    
    if not views_match:
        print("❌ 未找到 Views group")
        return False
    
    views_uuid = views_match.group(1)
    print(f"✅ 找到 Views group: {views_uuid}")
    
    for file_path in file_paths:
        # 获取文件名
        file_name = os.path.basename(file_path)
        
        # 检查文件是否已存在
        if file_name in content:
            print(f"⚠️ {file_name} 已存在于项目中，跳过")
            continue
        
        print(f"\n📝 添加 {file_name}...")
        
        # 生成 UUID
        file_ref_uuid = generate_uuid()
        build_file_uuid = generate_uuid()
        
        print(f"   File Reference: {file_ref_uuid}")
        print(f"   Build File: {build_file_uuid}")
        
        # 1. 添加 PBXFileReference
        file_ref_entry = f'\t\t{file_ref_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = "<group>"; }};\n'
        
        file_ref_pattern = r'(/\* Begin PBXFileReference section \*/\n)'
        content = re.sub(file_ref_pattern, r'\1' + file_ref_entry, content)
        print(f"   ✅ 添加了 PBXFileReference")
        
        # 2. 添加 PBXBuildFile
        build_file_entry = f'\t\t{build_file_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {file_name} */; }};\n'
        
        build_file_pattern = r'(/\* Begin PBXBuildFile section \*/\n)'
        content = re.sub(build_file_pattern, r'\1' + build_file_entry, content)
        print(f"   ✅ 添加了 PBXBuildFile")
        
        # 3. 添加到 Views group
        views_group_pattern = f'{views_uuid} /\\* Views \\*/ = {{[^}}]+children = \\(([^)]+)\\);'
        views_group_match = re.search(views_group_pattern, content, re.DOTALL)
        
        if views_group_match:
            children_content = views_group_match.group(1)
            new_children = children_content.rstrip() + f'\n\t\t\t\t{file_ref_uuid} /* {file_name} */,\n\t\t\t'
            content = content.replace(children_content, new_children)
            print(f"   ✅ 添加到 Views group")
        
        # 4. 添加到 PBXSourcesBuildPhase
        sources_pattern = r'([A-F0-9]{24}) /\* Sources \*/ = \{[^}}]*isa = PBXSourcesBuildPhase;[^}}]*files = \(([^)]+)\);'
        sources_match = re.search(sources_pattern, content, re.DOTALL)
        
        if sources_match:
            sources_files = sources_match.group(2)
            new_sources_files = sources_files.rstrip() + f'\n\t\t\t\t{build_file_uuid} /* {file_name} in Sources */,\n\t\t\t'
            content = content.replace(sources_files, new_sources_files)
            print(f"   ✅ 添加到 Sources build phase")
    
    # 写回文件
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ 文件已添加到 Xcode 项目")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python3 add_files_to_xcode.py <file1> <file2> ...")
        sys.exit(1)
    
    file_paths = sys.argv[1:]
    
    try:
        success = add_files_to_project(file_paths)
        if success:
            print("\n📋 下一步：")
            print("   1. 在 Xcode 中打开项目")
            print("   2. 验证文件是否出现在 Views 文件夹")
            print("   3. 尝试构建项目")
        else:
            print("\n❌ 添加失败")
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()

