#!/bin/bash

# Shotcut项目资源路径修复脚本
# 功能：递归遍历.mlt文件，检查resource路径指向的文件是否存在，如果存在且目标目录不存在同名文件，则拷贝并更新路径

# 配置路径（根据实际情况调整）
BASE_DIR=$(dirname "$(readlink -f "$0")")
PROJECTS_DIR="${BASE_DIR}/Projects"
ASSETS_VIDEO_DIR="${BASE_DIR}/Assets/Video"
BACKUP_DIR="${BASE_DIR}/Backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${BASE_DIR}/resource_fix_$(date +%Y%m%d_%H%M%S).log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 初始化日志
init_log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "===== Shotcut资源修复日志 $(date) =====" > "$LOG_FILE"
    echo "项目目录: $PROJECTS_DIR" >> "$LOG_FILE"
    echo "资源目录: $ASSETS_VIDEO_DIR" >> "$LOG_FILE"
    echo "备份目录: $BACKUP_DIR" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# 日志函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $level in
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "PROCESS") echo -e "${CYAN}[PROCESS]${NC} $message" ;;
        "SUMMARY") echo -e "${MAGENTA}[SUMMARY]${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 检查目录是否存在，不存在则创建
ensure_directory() {
    local dir="$1"
    local description="$2"
    
    if [ ! -d "$dir" ]; then
        log "WARNING" "$description 不存在: $dir"
        mkdir -p "$dir"
        if [ $? -eq 0 ]; then
            log "INFO" "已创建目录: $dir"
            return 0
        else
            log "ERROR" "无法创建目录: $dir"
            return 1
        fi
    fi
    return 0
}

# 备份原始.mlt文件
backup_mlt_file() {
    local mlt_file="$1"
    local relative_path="${mlt_file#$PROJECTS_DIR/}"
    local backup_path="${BACKUP_DIR}/${relative_path}"
    
    mkdir -p "$(dirname "$backup_path")"
    cp "$mlt_file" "$backup_path"
    
    if [ $? -eq 0 ]; then
        log "INFO" "已备份文件: $mlt_file -> $backup_path"
        return 0
    else
        log "WARNING" "备份失败: $mlt_file"
        return 1
    fi
}

# 提取文件名（处理可能存在的URL编码或特殊字符）
extract_filename() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    
    # 解码常见的URL编码字符
    filename=$(echo "$filename" | sed '
        s/%20/ /g;    # 空格
        s/%21/!/g;    # !
        s/%23/#/g;    # #
        s/%24/$/g;    # $
        s/%26/\&/g;   # &
        s/%27/'\''/g; # 单引号
        s/%28/(/g;    # (
        s/%29/)/g;    # )
        s/%2C/,/g;    # ,
        s/%2B/+/g;    # +
        s/%3A/:/g;    # :
        s/%3B/;/g;    # ;
        s/%3D/=/g;    # =
        s/%3F/?/g;    # ?
        s/%40/@/g;    # @
        s/%5B/[/g;    # [
        s/%5D/]/g;    # ]
    ')
    
    echo "$filename"
}

# 检查目标目录是否存在同名文件
check_duplicate_in_target() {
    local filename="$1"
    local target_dir="$2"
    
    # 检查完全相同的文件名
    if [ -f "${target_dir}/${filename}" ]; then
        echo "exact"
        return 0
    fi
    
    # 检查文件名（不区分大小写） - 用于提示
    local lower_filename=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
    for f in "$target_dir"/*; do
        if [ -f "$f" ]; then
            local f_lower=$(basename "$f" | tr '[:upper:]' '[:lower:]')
            if [ "$f_lower" = "$lower_filename" ]; then
                echo "case_insensitive"
                return 0
            fi
        fi
    done
    
    echo "none"
    return 0
}

# 生成唯一文件名
generate_unique_filename() {
    local original_filename="$1"
    local target_dir="$2"
    
    local name_no_ext="${original_filename%.*}"
    local extension="${original_filename##*.}"
    local counter=1
    local new_filename="$original_filename"
    
    # 如果文件已存在，添加数字后缀直到找到不存在的文件名
    while [ -f "${target_dir}/${new_filename}" ]; do
        new_filename="${name_no_ext}_${counter}.${extension}"
        ((counter++))
    done
    
    echo "$new_filename"
}

# 处理单个.mlt文件
process_mlt_file() {
    local mlt_file="$1"
    local file_changed=false
    local local_updates=0
    local local_copies=0
    local local_warnings=0
    
    log "PROCESS" "处理文件: $mlt_file"
    
    # 备份原始文件
    backup_mlt_file "$mlt_file"
    
    # 创建临时文件
    local temp_file=$(mktemp)
    
    # 读取文件行数
    local line_number=0
    
    # 逐行读取和处理
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number++))
        
        # 检查是否是resource属性行
        if [[ "$line" =~ \<property\ name=\"resource\"\>([^\<]+)\</property\> ]]; then
            local original_path="${BASH_REMATCH[1]}"
            local filename=$(extract_filename "$original_path")
            
            log "INFO" "  第${line_number}行发现资源: $original_path"
            log "INFO" "  文件名: $filename"
            
            # 检查原始文件是否存在
            if [ -f "$original_path" ]; then
                # 检查目标目录是否存在同名文件
                local duplicate_check=$(check_duplicate_in_target "$filename" "$ASSETS_VIDEO_DIR")
                
                if [ "$duplicate_check" = "exact" ]; then
                    log "INFO" "  目标目录已存在同名文件: $filename"
                    # 目标文件已存在，直接使用现有文件路径
                    local target_path="${ASSETS_VIDEO_DIR}/${filename}"
                    ((local_updates++))
                elif [ "$duplicate_check" = "case_insensitive" ]; then
                    log "WARNING" "  目标目录存在仅大小写不同的文件，为避免问题跳过此文件"
                    echo "$line" >> "$temp_file"
                    ((local_warnings++))
                    continue
                else
                    # 目标目录不存在同名文件，进行拷贝
                    local target_path="${ASSETS_VIDEO_DIR}/${filename}"
                    
                    # 拷贝文件
                    cp "$original_path" "$target_path"
                    if [ $? -eq 0 ]; then
                        log "SUCCESS" "  文件已拷贝: $original_path -> $target_path"
                        ((local_copies++))
                        ((local_updates++))
                    else
                        log "ERROR" "  文件拷贝失败: $original_path -> $target_path"
                        echo "$line" >> "$temp_file"
                        continue
                    fi
                fi
                
                # 更新路径为新位置（使用绝对路径）
                local new_line="    <property name=\"resource\">${target_path}</property>"
                echo "$new_line" >> "$temp_file"
                
                log "INFO" "  路径已更新: $original_path -> $target_path"
                file_changed=true
                
            else
                log "WARNING" "  原始文件不存在: $original_path"
                # 保留原始行
                echo "$line" >> "$temp_file"
                ((local_warnings++))
            fi
        else
            # 不是resource属性行，直接写入
            echo "$line" >> "$temp_file"
        fi
    done < "$mlt_file"
    
    # 如果文件有更改，替换原文件
    if [ "$file_changed" = true ]; then
        mv "$temp_file" "$mlt_file"
        log "SUCCESS" "  文件已更新: $mlt_file (${local_updates}处路径更新, ${local_copies}个文件拷贝)"
    else
        rm "$temp_file"
        log "INFO" "  文件未更改: $mlt_file"
    fi
    
    # 返回处理统计
    echo "$local_updates:$local_copies:$local_warnings"
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r进度: ["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' ' '
    printf "] %3d%% (%d/%d)" "$percentage" "$current" "$total"
}

# 主函数
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}    Shotcut项目资源路径修复工具        ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # 初始化日志
    init_log
    
    # 检查并创建必要的目录
    log "INFO" "检查目录..."
    
    if ! ensure_directory "$PROJECTS_DIR" "项目目录"; then
        log "ERROR" "项目目录不存在且创建失败，请检查路径: $PROJECTS_DIR"
        exit 1
    fi
    
    ensure_directory "$ASSETS_VIDEO_DIR" "资源视频目录"
    ensure_directory "$BACKUP_DIR" "备份目录"
    
    # 查找所有.mlt文件
    log "INFO" "查找.mlt文件..."
    
    # 使用数组存储找到的.mlt文件
    local mlt_files=()
    while IFS= read -r -d '' file; do
        mlt_files+=("$file")
    done < <(find "$PROJECTS_DIR" -type f -name "*.mlt" -print0)
    
    local total_files=${#mlt_files[@]}
    
    if [ "$total_files" -eq 0 ]; then
        log "WARNING" "未找到任何.mlt文件: $PROJECTS_DIR"
        log "SUMMARY" "处理完成: 未找到.mlt文件"
        echo "提示：请确保您的项目文件扩展名为 .mlt"
        exit 0
    fi
    
    log "SUCCESS" "找到 ${total_files} 个.mlt文件"
    echo ""
    
    # 统计信息
    local total_updates=0
    local total_copies=0
    local total_warnings=0
    local processed_files=0
    local current_file=0
    
    # 处理每个.mlt文件
    for mlt_file in "${mlt_files[@]}"; do
        ((current_file++))
        show_progress "$current_file" "$total_files"
        
        echo ""  # 换行以便显示处理日志
        log "PROCESS" "--------------------------------------------------"
        
        # 处理文件并获取统计信息
        local result=$(process_mlt_file "$mlt_file")
        IFS=':' read -r updates copies warnings <<< "$result"
        
        if [ "$updates" -gt 0 ] || [ "$warnings" -gt 0 ]; then
            ((total_updates+=updates))
            ((total_copies+=copies))
            ((total_warnings+=warnings))
            ((processed_files++))
        fi
        
        # 如果文件较多，每处理10个文件显示一次进度
        if [ "$total_files" -gt 10 ] && [ $((current_file % 10)) -eq 0 ]; then
            echo ""
            show_progress "$current_file" "$total_files"
        fi
    done
    
    echo ""  # 换行
    echo ""
    
    # 输出总结报告
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}              执行完毕                  ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    log "SUMMARY" "处理完成!"
    echo ""
    
    echo -e "${MAGENTA}详细统计信息:${NC}"
    echo "----------------------------------------"
    echo -e "  扫描目录:        ${PROJECTS_DIR}"
    echo -e "  找到.mlt文件:    ${total_files} 个"
    echo -e "  处理文件:        ${processed_files} 个"
    echo -e "  总路径更新:      ${total_updates} 处"
    echo -e "  文件拷贝:        ${total_copies} 个"
    echo -e "  警告/未找到:     ${total_warnings} 个"
    echo -e "  资源目录:        ${ASSETS_VIDEO_DIR}"
    echo -e "  备份位置:        ${BACKUP_DIR}"
    echo -e "  日志文件:        ${LOG_FILE}"
    echo "----------------------------------------"
    echo ""
    
    echo -e "${YELLOW}处理结果摘要:${NC}"
    if [ "$total_copies" -gt 0 ]; then
        echo -e "  ✓ ${GREEN}成功拷贝 ${total_copies} 个文件到资源目录${NC}"
    fi
    if [ "$total_updates" -gt 0 ]; then
        echo -e "  ✓ ${GREEN}成功更新 ${total_updates} 处资源路径${NC}"
    fi
    if [ "$total_warnings" -gt 0 ]; then
        echo -e "  ⚠ ${YELLOW}发现 ${total_warnings} 个问题（文件不存在或已存在）${NC}"
    fi
    if [ "$total_copies" -eq 0 ] && [ "$total_updates" -eq 0 ] && [ "$total_warnings" -eq 0 ]; then
        echo -e "  ℹ 没有需要处理的资源路径"
    fi
    echo ""
    
    echo -e "${YELLOW}下一步操作建议:${NC}"
    echo "  1. 在Shotcut中重新打开项目，检查所有资源是否正确加载"
    echo "  2. 如果遇到问题，可以恢复备份文件: ${BACKUP_DIR}"
    echo "  3. 查看详细日志: ${LOG_FILE}"
    echo ""
    
    echo -e "${GREEN}脚本执行完成！所有资源文件已整理到统一目录。${NC}"
}

# 运行主函数
main "$@"
