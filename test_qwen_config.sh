#!/bin/bash

echo "🔍 检查 Qwen API 配置..."
echo ""

# 检查环境变量
if [ -z "$QWEN_API_KEY" ]; then
    echo "❌ 环境变量 QWEN_API_KEY 未设置"
    echo ""
    echo "请运行以下命令设置："
    echo "export QWEN_API_KEY=\"sk-de3d9cc09dcd47d3b22fd53418851081\""
    echo ""
    exit 1
else
    echo "✅ 环境变量 QWEN_API_KEY 已设置"
    echo "   值: ${QWEN_API_KEY:0:10}...${QWEN_API_KEY: -10}"
    echo ""
fi

# 检查 API Key 格式
if [[ $QWEN_API_KEY == sk-* ]]; then
    echo "✅ API Key 格式正确（以 sk- 开头）"
else
    echo "⚠️  API Key 格式可能不正确（应以 sk- 开头）"
fi

# 检查 API Key 长度
KEY_LENGTH=${#QWEN_API_KEY}
if [ $KEY_LENGTH -gt 20 ]; then
    echo "✅ API Key 长度正常（$KEY_LENGTH 字符）"
else
    echo "⚠️  API Key 长度可能不正确（$KEY_LENGTH 字符）"
fi

echo ""
echo "🎯 配置检查完成！"
echo ""
echo "如果所有检查都通过，可以运行应用进行测试。"
echo "如果遇到问题，请查看 QWEN_VL_INTEGRATION.md 文档。"

