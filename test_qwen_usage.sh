#!/bin/bash
#
# Qwen API Usage 字段测试脚本
# 用于快速测试 API 是否返回 usage 统计信息
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 输出函数
print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 检查依赖
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        print_error "需要安装 curl"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "未安装 jq，JSON 输出将不会格式化"
        print_info "安装方法: brew install jq"
        USE_JQ=false
    else
        USE_JQ=true
    fi
}

# 检查 API Key
check_api_key() {
    if [ -z "$DASHSCOPE_API_KEY" ]; then
        print_error "未设置 DASHSCOPE_API_KEY 环境变量"
        echo ""
        echo "使用方法:"
        echo "  export DASHSCOPE_API_KEY=\"your-api-key\""
        echo "  ./test_qwen_usage.sh"
        exit 1
    fi
    
    print_success "API Key 已配置"
    print_info "长度: ${#DASHSCOPE_API_KEY} 字符"
    print_info "前缀: ${DASHSCOPE_API_KEY:0:8}..."
}

# 测试流式模式
test_streaming_mode() {
    print_header "🧪 测试 1: 流式模式 (stream=true)"
    
    local response_file="stream_response_$$.log"
    
    print_info "发送请求..."
    print_info "模型: qwen-vl-plus"
    print_info "流式: true"
    
    curl -s -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
        -H "Accept: text/event-stream" \
        -d '{
            "model": "qwen-vl-plus",
            "messages": [
                {"role": "user", "content": "你好，请说一个字"}
            ],
            "stream": true,
            "temperature": 0.7
        }' > "$response_file" 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "请求失败"
        cat "$response_file"
        rm -f "$response_file"
        return 1
    fi
    
    print_success "收到响应"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📡 原始 SSE 数据流:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 处理每一行
    local line_count=0
    local usage_found=false
    local usage_line=""
    
    while IFS= read -r line; do
        if [[ "$line" == data:* ]]; then
            ((line_count++))
            
            # 提取 JSON 部分
            json_part="${line#data: }"
            
            if [ "$json_part" = "[DONE]" ]; then
                echo -e "\n${YELLOW}[$line_count]${NC} data: [DONE]"
                continue
            fi
            
            # 检查是否包含 usage 字段
            if echo "$json_part" | grep -q '"usage"'; then
                usage_found=true
                usage_line="$json_part"
                echo -e "\n${GREEN}[$line_count] 🎯 发现 usage 字段！${NC}"
                
                if [ "$USE_JQ" = true ]; then
                    echo "$json_part" | jq '.'
                    
                    # 提取 usage 值
                    prompt_tokens=$(echo "$json_part" | jq -r '.usage.prompt_tokens // "N/A"')
                    completion_tokens=$(echo "$json_part" | jq -r '.usage.completion_tokens // "N/A"')
                    total_tokens=$(echo "$json_part" | jq -r '.usage.total_tokens // "N/A"')
                    
                    echo ""
                    echo "   prompt_tokens: $prompt_tokens"
                    echo "   completion_tokens: $completion_tokens"
                    echo "   total_tokens: $total_tokens"
                else
                    echo "$json_part"
                fi
            elif [ $line_count -le 3 ] || [ $line_count -ge $((line_count - 2)) ]; then
                # 只显示前 3 行和后 2 行
                echo -e "\n${YELLOW}[$line_count]${NC}"
                if [ "$USE_JQ" = true ]; then
                    echo "$json_part" | jq -c '.'
                else
                    echo "$json_part"
                fi
            fi
        fi
    done < "$response_file"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📊 流式模式测试结果:${NC}"
    echo "   总数据块数: $line_count"
    if [ "$usage_found" = true ]; then
        echo -e "   是否包含 usage: ${GREEN}✅ 是${NC}"
    else
        echo -e "   是否包含 usage: ${RED}❌ 否${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    rm -f "$response_file"
    
    return 0
}

# 测试非流式模式
test_non_streaming_mode() {
    print_header "🧪 测试 2: 非流式模式 (stream=false)"
    
    local response_file="non_stream_response_$$.json"
    
    print_info "发送请求..."
    print_info "模型: qwen-vl-plus"
    print_info "流式: false"
    
    curl -s -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
        -d '{
            "model": "qwen-vl-plus",
            "messages": [
                {"role": "user", "content": "你好，请说一个字"}
            ],
            "stream": false,
            "temperature": 0.7
        }' > "$response_file" 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "请求失败"
        cat "$response_file"
        rm -f "$response_file"
        return 1
    fi
    
    print_success "收到响应"
    
    # 检查文件大小
    local file_size=$(wc -c < "$response_file")
    print_info "响应大小: $file_size 字节"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📡 原始响应 JSON:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$USE_JQ" = true ]; then
        cat "$response_file" | jq '.'
        
        # 检查 usage 字段
        echo ""
        if cat "$response_file" | jq -e '.usage' > /dev/null 2>&1; then
            echo -e "${GREEN}🎯 发现 usage 字段！${NC}"
            echo ""
            prompt_tokens=$(cat "$response_file" | jq -r '.usage.prompt_tokens // "N/A"')
            completion_tokens=$(cat "$response_file" | jq -r '.usage.completion_tokens // "N/A"')
            total_tokens=$(cat "$response_file" | jq -r '.usage.total_tokens // "N/A"')
            
            echo "   prompt_tokens: $prompt_tokens"
            echo "   completion_tokens: $completion_tokens"
            echo "   total_tokens: $total_tokens"
        else
            echo -e "${RED}❌ 未找到 usage 字段${NC}"
        fi
    else
        cat "$response_file"
        echo ""
        if grep -q '"usage"' "$response_file"; then
            echo -e "${GREEN}🎯 发现 usage 字段！${NC}"
        else
            echo -e "${RED}❌ 未找到 usage 字段${NC}"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    rm -f "$response_file"
    
    return 0
}

# 测试带 stream_options 的流式模式
test_streaming_with_options() {
    print_header "🧪 测试 3: 流式模式 + stream_options (include_usage=true)"
    
    local response_file="stream_options_response_$$.log"
    
    print_info "发送请求..."
    print_info "模型: qwen-vl-plus"
    print_info "流式: true"
    print_info "stream_options: {include_usage: true}"
    
    curl -s -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
        -H "Accept: text/event-stream" \
        -d '{
            "model": "qwen-vl-plus",
            "messages": [
                {"role": "user", "content": "你好，请说一个字"}
            ],
            "stream": true,
            "temperature": 0.7,
            "stream_options": {
                "include_usage": true
            }
        }' > "$response_file" 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "请求失败"
        cat "$response_file"
        rm -f "$response_file"
        return 1
    fi
    
    print_success "收到响应"
    
    # 检查是否包含 usage
    if grep -q '"usage"' "$response_file"; then
        print_success "发现 usage 字段！stream_options 参数有效"
        
        if [ "$USE_JQ" = true ]; then
            echo ""
            echo "Usage 详情:"
            while IFS= read -r line; do
                if [[ "$line" == data:* ]]; then
                    json_part="${line#data: }"
                    if echo "$json_part" | grep -q '"usage"'; then
                        echo "$json_part" | jq '.usage'
                        break
                    fi
                fi
            done < "$response_file"
        fi
    else
        print_warning "即使添加 stream_options，仍未返回 usage"
        print_info "可能该 API 端点不支持此参数"
    fi
    
    rm -f "$response_file"
    
    return 0
}

# 主函数
main() {
    print_header "🧪 Qwen API Usage 字段测试工具"
    
    check_dependencies
    check_api_key
    
    # 运行测试
    test_streaming_mode
    echo ""
    test_non_streaming_mode
    echo ""
    test_streaming_with_options
    
    # 总结
    print_header "📝 测试总结"
    
    echo "根据以上测试结果："
    echo ""
    echo "1️⃣  如果流式模式返回了 usage："
    echo "   → 代码应该能正常工作，检查 SSEClient.swift 的解析逻辑"
    echo ""
    echo "2️⃣  如果只有非流式模式返回 usage："
    echo "   → 考虑在需要统计时使用非流式模式"
    echo "   → 或者实现本地 token 估算"
    echo ""
    echo "3️⃣  如果添加 stream_options 后返回 usage："
    echo "   → 修改 QwenVLService.swift 添加 stream_options 参数"
    echo ""
    echo "4️⃣  如果所有模式都不返回 usage："
    echo "   → 查阅 Qwen API 官方文档"
    echo "   → 实现本地 token 估算作为降级方案"
    echo ""
    
    print_info "详细分析和解决方案请查看: TOKEN_USAGE_ANALYSIS.md"
    
    print_header "✅ 测试完成"
}

# 运行主函数
main

