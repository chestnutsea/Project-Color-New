#!/bin/bash

echo "========================================"
echo "📋 验证 InfoPlist.strings 配置"
echo "========================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查文件是否存在
echo "1️⃣ 检查文件是否存在..."

if [ -f "Project_Color/en.lproj/InfoPlist.strings" ]; then
    echo -e "${GREEN}✅ 英文版本存在${NC}"
else
    echo -e "${RED}❌ 英文版本不存在${NC}"
fi

if [ -f "Project_Color/zh-Hans.lproj/InfoPlist.strings" ]; then
    echo -e "${GREEN}✅ 中文版本存在${NC}"
else
    echo -e "${RED}❌ 中文版本不存在${NC}"
fi

echo ""
echo "2️⃣ 检查文件编码..."

# 检查编码
EN_ENCODING=$(file -I "Project_Color/en.lproj/InfoPlist.strings" | grep -o "charset=.*" | cut -d'=' -f2)
ZH_ENCODING=$(file -I "Project_Color/zh-Hans.lproj/InfoPlist.strings" | grep -o "charset=.*" | cut -d'=' -f2)

echo "   英文版本编码: $EN_ENCODING"
if [[ "$EN_ENCODING" == *"utf-8"* ]]; then
    echo -e "   ${GREEN}✅ UTF-8 编码正确${NC}"
else
    echo -e "   ${RED}❌ 编码不正确，应为 UTF-8${NC}"
fi

echo "   中文版本编码: $ZH_ENCODING"
if [[ "$ZH_ENCODING" == *"utf-8"* ]]; then
    echo -e "   ${GREEN}✅ UTF-8 编码正确${NC}"
else
    echo -e "   ${RED}❌ 编码不正确，应为 UTF-8${NC}"
fi

echo ""
echo "3️⃣ 检查关键 Key 是否存在..."

# 检查英文版本
echo "   检查英文版本..."
if grep -q "NSPhotoLibraryUsageDescription" "Project_Color/en.lproj/InfoPlist.strings"; then
    echo -e "   ${GREEN}✅ NSPhotoLibraryUsageDescription${NC}"
else
    echo -e "   ${RED}❌ 缺少 NSPhotoLibraryUsageDescription${NC}"
fi

if grep -q "NSPhotoLibraryAddUsageDescription" "Project_Color/en.lproj/InfoPlist.strings"; then
    echo -e "   ${GREEN}✅ NSPhotoLibraryAddUsageDescription${NC}"
else
    echo -e "   ${RED}❌ 缺少 NSPhotoLibraryAddUsageDescription${NC}"
fi

# 检查中文版本
echo ""
echo "   检查中文版本..."
if grep -q "NSPhotoLibraryUsageDescription" "Project_Color/zh-Hans.lproj/InfoPlist.strings"; then
    echo -e "   ${GREEN}✅ NSPhotoLibraryUsageDescription${NC}"
else
    echo -e "   ${RED}❌ 缺少 NSPhotoLibraryUsageDescription${NC}"
fi

if grep -q "NSPhotoLibraryAddUsageDescription" "Project_Color/zh-Hans.lproj/InfoPlist.strings"; then
    echo -e "   ${GREEN}✅ NSPhotoLibraryAddUsageDescription${NC}"
else
    echo -e "   ${RED}❌ 缺少 NSPhotoLibraryAddUsageDescription${NC}"
fi

echo ""
echo "4️⃣ 检查 Xcode 项目配置..."

# 检查 project.pbxproj
if grep -q "InfoPlist.strings" "Project_Color.xcodeproj/project.pbxproj"; then
    echo -e "${GREEN}✅ InfoPlist.strings 已添加到 Xcode 项目${NC}"
else
    echo -e "${RED}❌ InfoPlist.strings 未添加到 Xcode 项目${NC}"
fi

if grep -q "PBXVariantGroup" "Project_Color.xcodeproj/project.pbxproj"; then
    echo -e "${GREEN}✅ PBXVariantGroup 配置存在${NC}"
else
    echo -e "${RED}❌ PBXVariantGroup 配置缺失${NC}"
fi

if grep -q '"zh-Hans"' "Project_Color.xcodeproj/project.pbxproj"; then
    echo -e "${GREEN}✅ zh-Hans 本地化已配置${NC}"
else
    echo -e "${RED}❌ zh-Hans 本地化未配置${NC}"
fi

echo ""
echo "5️⃣ 预览本地化内容..."
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}英文版本 (en.lproj)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
grep -E "^(NSPhotoLibrary|CFBundle)" "Project_Color/en.lproj/InfoPlist.strings" || echo "无法读取内容"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}中文版本 (zh-Hans.lproj)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
grep -E "^(NSPhotoLibrary|CFBundle)" "Project_Color/zh-Hans.lproj/InfoPlist.strings" || echo "无法读取内容"

echo ""
echo "========================================"
echo -e "${GREEN}✅ 验证完成！${NC}"
echo "========================================"
echo ""
echo "📝 下一步："
echo "   1. 在 Xcode 中打开项目"
echo "   2. 清理构建 (Shift + Cmd + K)"
echo "   3. 运行应用测试本地化效果"
echo ""


