#!/bin/bash

# Shotcut资产清理脚本（修复版）
# 移除了 set -e，并处理了 rg/grep 的退出状态问题

# 配置路径（根据实际情况调整）
# 注意：这里使用用户主目录下的 Videos/ShotcutPro，而不是脚本所在目录
BASE_DIR=$(dirname "$(readlink -f "$0")")
ASSETS_DIR="${BASE_DIR}/Assets/Video"
PROJECTS_DIR="${BASE_DIR}/Projects"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查目录是否存在
check_directories() {
    echo -e "${YELLOW}检查目录...${NC}"
    
    if [ ! -d "$ASSETS_DIR" ]; then
        echo -e "${RED}错误：资产目录不存在: $ASSETS_DIR${NC}"
        echo "请确认Shotcut资产路径是否正确"
        return 1
    fi
    
    if [ ! -d "$PROJECTS_DIR" ]; then
        echo -e "${YELLOW}警告：项目目录不存在: $PROJECTS_DIR${NC}"
        echo -e "将只检查资产目录，但不进行引用检查"
        return 1
    fi
    
    echo -e "${GREEN}目录检查完成${NC}"
    return 0
}

# 检查必要的工具
check_tools() {
    echo -e "${YELLOW}检查必要的工具...${NC}"
    
    local has_rg=false
    local has_grep=false
    
    if command -v rg &> /dev/null; then
        echo -e "  ✓ 找到 rg (ripgrep)"
        has_rg=true
        SEARCH_CMD="rg"
        # 移除了可能引起问题的 --no-ignore 和 --hidden，除非你确实需要
        SEARCH_OPTS="--fixed-strings -l"
    else
        echo -e "  ! 未找到 rg，将使用 grep"
    fi
    
    if command -v grep &> /dev/null; then
        echo -e "  ✓ 找到 grep"
        has_grep=true
        if [ "$has_rg" = false ]; then
            SEARCH_CMD="grep"
            SEARCH_OPTS="-r -l"
        fi
    fi
    
    if [ "$has_rg" = false ] && [ "$has_grep" = false ]; then
        echo -e "${RED}错误：未找到 rg 或 grep，请安装其中之一${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}工具检查完成${NC}"
}

# 搜索文件是否在项目中被引用 (关键修复函数)
is_file_referenced() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    
    # 如果项目目录不存在，假设文件被引用（安全起见）
    if [ ! -d "$PROJECTS_DIR" ]; then
        return 0
    fi
    
    # 尝试多种搜索策略
    local search_patterns=(
        "$filename"                # 只搜索文件名
    )
    
    # 如果是视频文件，也尝试搜索不带扩展名的名称
    if [[ "$filename" =~ \.(mp4|mov|avi|mkv|m4v|mpg|mpeg|wmv|flv|webm)$ ]]; then
        local name_no_ext="${filename%.*}"
        search_patterns+=("$name_no_ext")
    fi
    
    # 尝试每个搜索模式
    for pattern in "${search_patterns[@]}"; do
        # 关键修复：使用 2>/dev/null 忽略错误，并通过 || 确保命令链成功
        if [ "$SEARCH_CMD" = "rg" ]; then
            if rg $SEARCH_OPTS -- "$pattern" "$PROJECTS_DIR" 2>/dev/null | grep -q . ; then
                return 0
            fi
        else
            if grep $SEARCH_OPTS -- "$pattern" "$PROJECTS_DIR" 2>/dev/null | grep -q . ; then
                return 0
            fi
        fi
    done
    
    return 1
}

# 主清理函数
clean_unused_assets() {
    echo -e "${YELLOW}开始扫描资产文件...${NC}"
    
    local total_files=0
    local unused_files=0
    local kept_files=0
    local deleted_files=()
    
    # 创建临时文件列表
    local tmp_file=$(mktemp)
    trap "rm -f '$tmp_file'" EXIT  # 确保脚本退出时删除临时文件
    
    # 查找所有视频文件，但排除.gitignore文件
    # 使用! -name ".gitignore"来排除.gitignore文件
    find "$ASSETS_DIR" -type f \( \
        -name "*.mp4" -o \
        -name "*.mov" -o \
        -name "*.avi" -o \
        -name "*.mkv" -o \
        -name "*.m4v" -o \
        -name "*.mpg" -o \
        -name "*.mpeg" -o \
        -name "*.wmv" -o \
        -name "*.flv" -o \
        -name "*.webm" \
    \) ! -name ".gitignore" > "$tmp_file"
    
    total_files=$(wc -l < "$tmp_file" 2>/dev/null || echo 0)
    echo -e "找到 ${GREEN}$total_files${NC} 个视频文件（已排除.gitignore文件）"
    
    if [ "$total_files" -eq 0 ]; then
        echo -e "${YELLOW}没有找到视频文件，退出${NC}"
        return
    fi
    
    echo -e "${YELLOW}开始检查文件引用...${NC}"
    
    # 逐行读取文件
    while IFS= read -r file || [[ -n "$file" ]]; do  # 修复的 read 循环，处理最后一行
        if [[ -z "$file" ]]; then continue; fi  # 跳过空行
        
        # 额外检查：确保不是.gitignore文件（尽管find已经排除了）
        if [[ "$(basename "$file")" == ".gitignore" ]]; then
            echo -e "${YELLOW}跳过.gitignore文件: $file${NC}"
            continue
        fi
        
        echo -n "检查: $(basename "$file")... "
        
        if is_file_referenced "$file"; then
            echo -e "${GREEN}已引用${NC}"
            ((kept_files++)) || true
        else
            echo -e "${RED}未引用${NC}"
            deleted_files+=("$file")
            ((unused_files++)) || true
        fi
    done < "$tmp_file"
    
    # 显示统计信息
    echo -e "\n${YELLOW}统计信息:${NC}"
    echo -e "  总文件数: $total_files"
    echo -e "  保留的文件: ${GREEN}$kept_files${NC}"
    echo -e "  未引用的文件: ${RED}$unused_files${NC}"
    
    # 处理未引用的文件
    if [ ${#deleted_files[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}以下文件未被引用:${NC}"
        for file in "${deleted_files[@]}"; do
            echo "  - $file"
        done
        
        # 确认删除
        echo -e "\n${YELLOW}是否删除这些未引用的文件？${NC}"
        read -p "输入 'yes' 确认删除，或按回车取消: " confirmation
        
        if [ "$confirmation" = "yes" ]; then
            echo -e "${YELLOW}开始删除文件...${NC}"
            for file in "${deleted_files[@]}"; do
                # 再次检查：确保不是.gitignore文件
                if [[ "$(basename "$file")" == ".gitignore" ]]; then
                    echo -e "${YELLOW}  警告：跳过.gitignore文件: $file${NC}"
                    continue
                fi
                
                echo "删除: $file"
                rm -- "$file" 2>/dev/null && echo "  删除成功" || echo "  删除失败或文件不存在"
            done
            echo -e "${GREEN}删除操作完成${NC}"
        else
            echo -e "${GREEN}取消删除操作${NC}"
        fi
    else
        echo -e "${GREEN}所有文件都被引用，无需清理${NC}"
    fi
}

# 主函数
main() {
    echo -e "${YELLOW}=== Shotcut资产清理脚本（修复版）===${NC}"
    echo ""
    
    check_directories
    check_tools
    
    echo ""
    echo -e "${YELLOW}配置摘要:${NC}"
    echo -e "  资产目录: $ASSETS_DIR"
    echo -e "  项目目录: $PROJECTS_DIR"
    echo -e "  搜索工具: $SEARCH_CMD"
    echo ""
    
    # 执行清理
    clean_unused_assets
    
    echo ""
    echo -e "${GREEN}脚本执行完成${NC}"
}

# 运行主函数
main "$@"
