#!/usr/bin/env python3
"""
将 VisionAnalyzer.swift 添加到 Xcode 项目
"""

import re
import uuid

def generate_uuid():
    """生成 Xcode 风格的 24 字符 UUID"""
    return uuid.uuid4().hex[:24].upper()

def add_vision_file_to_project():
    project_file = "Project_Color.xcodeproj/project.pbxproj"
    
    # 生成 UUID
    file_ref_uuid = generate_uuid()
    build_file_uuid = generate_uuid()
    vision_group_uuid = generate_uuid()
    
    print(f"📝 生成的 UUID:")
    print(f"   File Reference: {file_ref_uuid}")
    print(f"   Build File: {build_file_uuid}")
    print(f"   Vision Group: {vision_group_uuid}")
    
    # 读取项目文件
    with open(project_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 备份
    with open(f"{project_file}.backup", 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ 已备份项目文件")
    
    # 1. 添加 PBXFileReference
    file_ref_entry = f'\t\t{file_ref_uuid} /* VisionAnalyzer.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VisionAnalyzer.swift; sourceTree = "<group>"; }};\n'
    
    file_ref_pattern = r'(/\* Begin PBXFileReference section \*/\n)'
    if re.search(file_ref_pattern, content):
        content = re.sub(file_ref_pattern, r'\1' + file_ref_entry, content)
        print("✅ 添加了 PBXFileReference")
    
    # 2. 添加 PBXBuildFile
    build_file_entry = f'\t\t{build_file_uuid} /* VisionAnalyzer.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* VisionAnalyzer.swift */; }};\n'
    
    build_file_pattern = r'(/\* Begin PBXBuildFile section \*/\n)'
    if re.search(build_file_pattern, content):
        content = re.sub(build_file_pattern, r'\1' + build_file_entry, content)
        print("✅ 添加了 PBXBuildFile")
    
    # 3. 查找或创建 Vision group
    # 先查找 Services group UUID
    services_pattern = r'([A-F0-9]{24}) /\* Services \*/ = \{'
    services_match = re.search(services_pattern, content)
    
    if not services_match:
        print("❌ 未找到 Services group")
        return False
    
    services_uuid = services_match.group(1)
    print(f"✅ 找到 Services group: {services_uuid}")
    
    # 检查 Vision group 是否已存在
    vision_group_pattern = r'([A-F0-9]{24}) /\* Vision \*/ = \{'
    vision_group_match = re.search(vision_group_pattern, content)
    
    if vision_group_match:
        # Vision group 已存在
        existing_vision_uuid = vision_group_match.group(1)
        print(f"✅ 找到现有 Vision group: {existing_vision_uuid}")
        
        # 添加文件到 Vision group
        group_pattern = f'{existing_vision_uuid} /\\* Vision \\*/ = {{[^}}]+children = \\(([^)]+)\\);'
        group_match = re.search(group_pattern, content, re.DOTALL)
        
        if group_match:
            children_content = group_match.group(1)
            # 检查文件是否已存在
            if 'VisionAnalyzer.swift' not in children_content:
                new_children = children_content.rstrip() + f'\n\t\t\t\t{file_ref_uuid} /* VisionAnalyzer.swift */,\n\t\t\t'
                content = content.replace(children_content, new_children)
                print("✅ 添加文件到现有 Vision group")
            else:
                print("⚠️ 文件已存在于 Vision group")
    else:
        # 创建新的 Vision group
        print("📁 创建新的 Vision group")
        
        # 在 PBXGroup section 中添加 Vision group
        vision_group_entry = f'''\t\t{vision_group_uuid} /* Vision */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{file_ref_uuid} /* VisionAnalyzer.swift */,
\t\t\t);
\t\t\tpath = Vision;
\t\t\tsourceTree = "<group>";
\t\t}};
'''
        
        # 找到 PBXGroup section 并添加
        group_section_pattern = r'(/\* Begin PBXGroup section \*/\n)'
        if re.search(group_section_pattern, content):
            content = re.sub(group_section_pattern, r'\1' + vision_group_entry, content)
            print("✅ 创建了 Vision group")
            
            # 将 Vision group 添加到 Services group 的 children
            services_group_pattern = f'{services_uuid} /\\* Services \\*/ = {{[^}}]+children = \\(([^)]+)\\);'
            services_group_match = re.search(services_group_pattern, content, re.DOTALL)
            
            if services_group_match:
                services_children = services_group_match.group(1)
                new_services_children = services_children.rstrip() + f'\n\t\t\t\t{vision_group_uuid} /* Vision */,\n\t\t\t'
                content = content.replace(services_children, new_services_children)
                print("✅ 将 Vision group 添加到 Services")
    
    # 4. 添加到 PBXSourcesBuildPhase
    # 找到 Project_Color target 的 Sources phase
    sources_pattern = r'([A-F0-9]{24}) /\* Sources \*/ = \{[^}}]*isa = PBXSourcesBuildPhase;[^}}]*files = \(([^)]+)\);'
    sources_match = re.search(sources_pattern, content, re.DOTALL)
    
    if sources_match:
        sources_files = sources_match.group(2)
        # 检查文件是否已添加
        if 'VisionAnalyzer.swift' not in sources_files:
            new_sources_files = sources_files.rstrip() + f'\n\t\t\t\t{build_file_uuid} /* VisionAnalyzer.swift in Sources */,\n\t\t\t'
            content = content.replace(sources_files, new_sources_files)
            print("✅ 添加到 Sources build phase")
        else:
            print("⚠️ 文件已存在于 Sources build phase")
    else:
        print("⚠️ 未找到 Sources build phase")
    
    # 写回文件
    with open(project_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ VisionAnalyzer.swift 已添加到 Xcode 项目")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    return True

if __name__ == "__main__":
    try:
        success = add_vision_file_to_project()
        if success:
            print("\n📋 下一步：")
            print("   1. 在 Xcode 中打开项目")
            print("   2. 验证 Services/Vision/VisionAnalyzer.swift 是否出现")
            print("   3. 尝试构建项目")
        else:
            print("\n❌ 添加失败")
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()

