#!/usr/bin/env bash

# 用于GitHub，删除旧发布和旧的工作流

# 设置默认值
github_per_page="100"  # 每次请求获取的数量
github_max_page="100"  # 最大请求页数

# 设置字体颜色
STEPS="[\033[95m 执行 \033[0m]"
INFO="[\033[94m 信息 \033[0m]"
NOTE="[\033[93m 注意 \033[0m]"
ERROR="[\033[91m 错误 \033[0m]"
SUCCESS="[\033[92m 成功 \033[0m]"

#==============================================================================================

error_msg() {
    echo -e "${ERROR} ${1}"
    exit 0
}

# 验证布尔值
validate_boolean() {
    local var="$1" param_name="$2"
    if [[ ! "$var" =~ ^(true|false)$ ]]; then
        error_msg "参数 $param_name 的值: $var 无效，必须是 'true' 或 'false'"
    fi
}

# 验证预发布选项
validate_prerelease() {
    local var="$1" param_name="$2"
    if [[ ! "$var" =~ ^(true|false|all)$ ]]; then
        error_msg "参数 $param_name 的值: $var 无效，必须是 'true', 'false', 或 'all'."
    fi
}

# 验证正整数（1-1000）
validate_positive_integer() {
    local var="$1" param_name="$2" max="$3"
    if ! [[ "$var" =~ ^[0-9][0-9]*$ ]]; then
        error_msg "参数 $param_name 的值: $var 无效，必须是正整数"
    fi
    if [[ "$var" -gt "$max" ]]; then
        error_msg "参数 $param_name 的值: $var 无效，最大值是 $max"
    fi
}

init_var() {
    echo -e "${STEPS} 开始初始化变量..."

    # 安装必要的依赖包
    sudo apt-get -qq update && sudo apt-get -qq install -y jq curl

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--repo) repo="$2"; shift 2 ;;
            -a|--delete_releases) delete_releases="$2"; shift 2 ;;
            -t|--delete_tags) delete_tags="$2"; shift 2 ;;
            -p|--prerelease_option) prerelease_option="$2"; shift 2 ;;
            -l|--releases_keep_latest) releases_keep_latest="$2"; shift 2 ;;
            -w|--releases_keep_keyword) IFS="/" read -r -a releases_keep_keyword <<< "$2"; shift 2 ;;
            -c|--max_releases_fetch) max_releases_fetch="$2"; shift 2 ;;
            -s|--delete_workflows) delete_workflows="$2"; shift 2 ;;
            -d|--workflows_keep_latest) workflows_keep_latest="$2"; shift 2 ;;
            -k|--workflows_keep_keyword) IFS="/" read -r -a workflows_keep_keyword <<< "$2"; shift 2 ;;
            -h|--max_workflows_fetch) max_workflows_fetch="$2"; shift 2 ;;
            -g|--gh_token) gh_token="$2"; shift 2 ;;
            -o|--out_log) out_log="$2"; shift 2 ;;
            *) error_msg "无效选项 [ $1 ]!"; shift ;;
        esac
    done

    # 参数验证
    validate_boolean "$delete_releases" "delete_releases"
    validate_boolean "$delete_tags" "delete_tags"
    validate_boolean "$delete_workflows" "delete_workflows"
    validate_boolean "$out_log" "out_log"

    # 验证预发布选项
    validate_prerelease "${prerelease_option}" "prerelease_option"

    # 验证整数值参数
    validate_positive_integer "$releases_keep_latest" "releases_keep_latest" 1000
    validate_positive_integer "$workflows_keep_latest" "workflows_keep_latest" 1000
    validate_positive_integer "$max_releases_fetch" "max_releases_fetch" 1000
    validate_positive_integer "$max_workflows_fetch" "max_workflows_fetch" 1000
    
    echo -e ""
    echo -e "${INFO} repo: [ ${repo} ]"
    echo -e "${INFO} delete_releases: [ ${delete_releases} ]"
    echo -e "${INFO} delete_tags: [ ${delete_tags} ]"
    echo -e "${INFO} prerelease_option: [ ${prerelease_option} ]"
    echo -e "${INFO} releases_keep_latest: [ ${releases_keep_latest} ]"
    echo -e "${INFO} releases_keep_keyword: [ $(echo ${releases_keep_keyword[@]} | xargs) ]"
    echo -e "${INFO} max_releases_fetch: [ ${max_releases_fetch} ]"
    echo -e "${INFO} delete_workflows: [ ${delete_workflows} ]"
    echo -e "${INFO} workflows_keep_latest: [ ${workflows_keep_latest} ]"
    echo -e "${INFO} workflows_keep_keyword: [ $(echo ${workflows_keep_keyword[@]} | xargs) ]"
    echo -e "${INFO} max_workflows_fetch: [ ${max_workflows_fetch} ]"
    echo -e "${INFO} out_log: [ ${out_log} ]"
    echo -e ""
}

get_releases_list() {
    echo -e "${STEPS} 开始查询发布列表..."

    # 创建文件存储结果
    all_releases_list="json_api_releases"
    echo -n "" >"${all_releases_list}"
    
    # 计算需要请求的总页数
    total_pages=$(( (max_releases_fetch + github_per_page - 1) / github_per_page ))
    if [[ "$total_pages" -gt "$github_max_page" ]]; then
        total_pages="$github_max_page"
        echo -e "${NOTE} 最大页数限制为 $github_max_page"
    fi

    # 获取发布列表（从最后一页开始）
    current_count=0
    for (( page=total_pages; page>=1; page-- )); do
        echo -e "${INFO} (1.1.${page}) 查询发布第 [ ${page} ] 页"
        
        response="$(
            curl -s -L -f \
                -H "Authorization: Bearer ${gh_token}" \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${repo}/releases?per_page=${github_per_page}&page=${page}"
        )" || {
            echo -e "${ERROR} 从GitHub API获取发布失败 (第 $page 页)"
            break
        }

        # 检查是否有返回内容
        if [[ -z "$response" || "$response" == "[]" ]]; then
            echo -e "${INFO} (1.1.${page}) 第 ${page} 页返回空结果"
            continue
        fi

        # 获取当前页返回的结果数量
        get_results_length="$(echo "${response}" | jq '. | length')"
        echo -e "${INFO} (1.1.${page}) 返回 [ ${get_results_length} ] 条发布结果"

        # 计算还需要获取的数量
        remaining=$(( max_releases_fetch - current_count ))
        if [[ "$remaining" -le 0 ]]; then
            break
        fi

        # 限制本次处理的数量
        if [[ "$get_results_length" -gt "$remaining" ]]; then
            echo "${response}" |
                jq -s '.[] | sort_by(.published_at)|reverse | .[0:'$remaining']' |
                jq -c '.[] | {date: .published_at, id: .id, prerelease: .prerelease, tag_name: .tag_name}' \
                    >>"${all_releases_list}"
            current_count=$(( current_count + remaining ))
            break
        else
            echo "${response}" |
                jq -s '.[] | sort_by(.published_at)|reverse' |
                jq -c '.[] | {date: .published_at, id: .id, prerelease: .prerelease, tag_name: .tag_name}' \
                    >>"${all_releases_list}"
            current_count=$(( current_count + get_results_length ))
        fi

        # 如果当前页返回的数量小于请求数量，说明已获取全部数据
        if [[ "$get_results_length" -lt "$github_per_page" ]]; then
            break
        fi
    done

    if [[ -s "${all_releases_list}" ]]; then
        # 移除空行
        sed -i '/^[[:space:]]*$/d' "${all_releases_list}"

        # 打印结果日志
        actual_count=$(cat "${all_releases_list}" | wc -l)
        echo -e "${INFO} (1.3.1) 获取发布信息请求成功"
        echo -e "${INFO} (1.3.2) 获取到的发布量总数: [ ${actual_count} / ${max_releases_fetch} ]"
        [[ "${out_log}" == "true" ]] && {
            echo -e "${INFO} (1.3.3) 所有发布列表:\n$(cat ${all_releases_list})"
        }
    else
        echo -e "${NOTE} (1.3.4) 发布列表为空，跳过"
    fi
}

out_releases_list() {
    echo -e "${STEPS} 开始输出发布列表..."

    # 临时文件定义
    filtered_by_prerelease="json_filtered_by_prerelease"
    filtered_by_keyword="json_filtered_by_keyword"
    keep_releases_list="json_keep_releases_list"

    if [[ -s "${all_releases_list}" ]]; then
        # 复制原始列表用于后续过滤
        cp "${all_releases_list}" "${filtered_by_prerelease}"

        # 根据预发布选项过滤(all/false/true)
        if [[ "${prerelease_option}" == "all" ]]; then
            echo -e "${NOTE} (1.4.1) 检查全部发布版本"
        elif [[ "${prerelease_option}" == "false" ]]; then
            echo -e "${INFO} (1.4.2) 过滤发布预发版选项: [ false ]"
            jq -c 'select(.prerelease == false)' "${filtered_by_prerelease}" > "${filtered_by_prerelease}.tmp"
            mv "${filtered_by_prerelease}.tmp" "${filtered_by_prerelease}"
        elif [[ "${prerelease_option}" == "true" ]]; then
            echo -e "${INFO} (1.4.3) 过滤发布预发版选项: [ true ]"
            jq -c 'select(.prerelease == true)' "${filtered_by_prerelease}" > "${filtered_by_prerelease}.tmp"
            mv "${filtered_by_prerelease}.tmp" "${filtered_by_prerelease}"
        fi
        [[ "${out_log}" == "true" ]] && echo -e "${INFO} (1.4.4) 预发布过滤后列表:\n$(cat ${filtered_by_prerelease})"

        # 按时间排序（最新的在前）
        jq -s 'sort_by(.date | fromdateiso8601) | reverse' "${filtered_by_prerelease}" > "${filtered_by_prerelease}.tmp"
        mv "${filtered_by_prerelease}.tmp" "${filtered_by_prerelease}"

        # 截取前N条（最新的）
        if [[ "$(cat ${filtered_by_prerelease} | jq length)" -gt "$releases_keep_latest" ]]; then
            head -n "$releases_keep_latest" "${filtered_by_prerelease}" > "${filtered_by_prerelease}.tmp"
            mv "${filtered_by_prerelease}.tmp" "${filtered_by_prerelease}"
            echo -e "${INFO} (1.4.5) 保留最新的 $releases_keep_latest 条发布"
        fi
        [[ "${out_log}" == "true" ]] && echo -e "${INFO} (1.4.6) 时间过滤后列表:\n$(cat ${filtered_by_prerelease})"

        # 匹配需要过滤的标签
        if [[ "${#releases_keep_keyword[@]}" -ge "1" && -s "${filtered_by_prerelease}" ]]; then
            # 匹配符合条件的标签
            echo -e "${INFO} (1.5.1) 发布的过滤标签关键词: [ $(echo ${releases_keep_keyword[@]} | xargs) ]"
            
            # 创建包含关键词的列表
            cp "${filtered_by_prerelease}" "${filtered_by_keyword}"
            for keyword in "${releases_keep_keyword[@]}"; do
                jq -c --arg keyword "$keyword" 'select(.tag_name | test($keyword))' "${filtered_by_keyword}" > "${filtered_by_keyword}.tmp"
                mv "${filtered_by_keyword}.tmp" "${filtered_by_keyword}"
            done
            
            [[ "${out_log}" == "true" && -s "${filtered_by_keyword}" ]] && {
                echo -e "${INFO} (1.5.2) 符合条件的发布标签列表:\n$(cat ${filtered_by_keyword})"
            }

            # 从原始列表中移除包含关键词的项
            if [[ -s "${filtered_by_keyword}" ]]; then
                # 创建不包含关键词的列表
                > "${all_releases_list}"  # 清空删除列表
                while IFS= read -r line; do
                    id=$(echo "$line" | jq -r '.id')
                    if ! grep -q "\"id\":$id" "${filtered_by_keyword}"; then
                        echo "$line" >> "${all_releases_list}"
                    fi
                done < "${filtered_by_prerelease}"
                
                echo -e "${INFO} (1.5.3) 发布的标签关键词过滤成功"
            fi

            # 过滤后的剩余标签列表
            [[ "${out_log}" == "true" ]] && echo -e "${INFO} (1.5.4) 当前发布列表:\n$(cat ${all_releases_list})"
        else
            echo -e "${NOTE} (1.5.5) 过滤关键词为空，跳过"
            cp "${filtered_by_prerelease}" "${all_releases_list}"
        fi

        # 匹配需要保留的最新标签
        if [[ -s "${all_releases_list}" ]]; then
            if [[ "${releases_keep_latest}" -eq "0" ]]; then
                echo -e "${INFO} (1.6.1) 删除所有发布"
            else
                # 按日期排序（最新的在前）
                jq -s 'sort_by(.date | fromdateiso8601) | reverse' "${all_releases_list}" > "${all_releases_list}.tmp"
                mv "${all_releases_list}.tmp" "${all_releases_list}"

                # 生成需要保留的标签列表（前N条）
                head -n "${releases_keep_latest}" "${all_releases_list}" > "${keep_releases_list}"
                echo -e "${INFO} (1.6.2) 保留标签列表生成成功"
                [[ "${out_log}" == "true" && -s "${keep_releases_list}" ]] && {
                    echo -e "${INFO} (1.6.3) 保留标签列表:\n$(cat ${keep_releases_list})"
                }

                # 从完整列表中移除需要保留的发布（保留后面的条目）
                tail -n +$((releases_keep_latest + 1)) "${all_releases_list}" > "${all_releases_list}.tmp"
                mv "${all_releases_list}.tmp" "${all_releases_list}"
            fi
        else
            echo -e "${NOTE} (1.6.4) 发布列表为空，跳过"
        fi

        # 删除列表
        if [[ -s "${all_releases_list}" ]]; then
            [[ "${out_log}" == "true" ]] && echo -e "${INFO} (1.6.5) 删除发布列表:\n$(cat ${all_releases_list})"
        else
            echo -e "${NOTE} (1.6.6) 删除发布列表为空，跳过"
        fi

    else
        echo -e "${NOTE} (1.4.7) 发布列表为空，跳过所有过滤步骤"
    fi

    echo -e ""
}

del_releases_file() {
    echo -e "${STEPS} 开始删除发布文件..."

    # 删除发布
    if [[ -s "${all_releases_list}" && -n "$(cat ${all_releases_list} | jq -r .id)" ]]; then
        total=$(cat ${all_releases_list} | wc -l)
        count=0
        
        cat ${all_releases_list} | jq -r .id | while read release_id; do
            count=$((count + 1))
            echo -e "${INFO} (1.7.1) 正在删除发布 ${count}/${total}"
            
            response=$(curl -s -o /dev/null -w "%{http_code}" \
                -X DELETE \
                -H "Authorization: Bearer ${gh_token}" \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${repo}/releases/${release_id}"
            )
                
            if [[ "$response" -eq 204 ]]; then
                echo -e "${SUCCESS} (1.7.2) 发布 ${count}：ID=${release_id} 删除成功"
            else
                echo -e "${ERROR} (1.7.3) 删除发布 ${count}：ID=${release_id} 失败: HTTP ${response}"
            fi
        done
        echo -e "${SUCCESS} (1.7.4) 发布删除完成"
    else
        echo -e "${NOTE} (1.7.5) 没有需要删除的发布，跳过"
    fi

    echo -e ""
}

del_releases_tags() {
    echo -e "${STEPS} 开始删除发布的关联标签..."

    # 删除与发布关联的标签
    if [[ "${delete_tags}" == "true" && -s "${all_releases_list}" && -n "$(cat ${all_releases_list} | jq -r .tag_name)" ]]; then
        total=$(cat ${all_releases_list} | wc -l)
        count=0
        
        cat ${all_releases_list} | jq -r .tag_name | while read tag_name; do
            count=$((count + 1))
            echo -e "${INFO} (1.8.1) 正在删除发布的关联标签 ${count}/${total}"
            
            response=$(curl -s -o /dev/null -w "%{http_code}" \
                -X DELETE \
                -H "Authorization: Bearer ${gh_token}" \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${repo}/git/refs/tags/${tag_name}"
                )
                
            if [[ "$response" -eq 204 ]]; then
                echo -e "${SUCCESS} (1.8.2) 发布的关联标签 ${tag_name} 删除成功"
            else
                echo -e "${ERROR} (1.8.3) 删除发布的关联标签 ${tag_name} 失败: HTTP ${response}"
            fi
        done
        echo -e "${SUCCESS} (1.8.4) 发布的关联标签删除完成"
    else
        echo -e "${NOTE} (1.8.5) 没有需要删除的发布关联标签，跳过"
    fi

    echo -e ""
}

get_workflows_list() {
    echo -e "${STEPS} 开始查询工作流列表..."

    # 创建文件存储结果
    all_workflows_list="json_api_workflows"
    echo -n "" >"${all_workflows_list}"
    
    # 计算需要请求的总页数
    total_pages=$(( (max_workflows_fetch + github_per_page - 1) / github_per_page ))
    if [[ "$total_pages" -gt "$github_max_page" ]]; then
        total_pages="$github_max_page"
        echo -e "${NOTE} 最大页数限制为 $github_max_page"
    fi

    # 获取工作流列表（从最后一页开始）
    current_count=0
    for (( page=total_pages; page>=1; page-- )); do
        echo -e "${INFO} (2.1.${page}) 查询工作流第 [ ${page} ] 页"
        
        response="$(
            curl -s -L -f \
                -H "Authorization: Bearer ${gh_token}" \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${repo}/actions/runs?per_page=${github_per_page}&page=${page}"
        )" || {
            echo -e "${ERROR} 从GitHub API获取工作流失败 (第 $page 页)"
            break
        }

        # 检查是否有返回内容
        if [[ -z "$response" ]]; then
            echo -e "${INFO} (2.1.${page}) 第 ${page} 页返回空结果"
            continue
        fi

        # 提取工作流运行列表
        workflow_runs="$(echo "${response}" | jq -c '.workflow_runs')"
        
        # 获取当前页返回的结果数量
        get_results_length="$(echo "${workflow_runs}" | jq '. | length')"
        echo -e "${INFO} (2.1.${page}) 返回 [ ${get_results_length} ] 条工作流结果"

        # 如果没有工作流运行，继续下一页
        if [[ "$get_results_length" -eq 0 ]]; then
            continue
        fi

        # 计算还需要获取的数量
        remaining=$(( max_workflows_fetch - current_count ))
        if [[ "$remaining" -le 0 ]]; then
            break
        fi

        # 处理当前页的工作流数据
        if [[ "$get_results_length" -gt "$remaining" ]]; then
            echo "${workflow_runs}" |
                jq -c ".[0:'$remaining'] | select(.status != \"in_progress\") | {date: .updated_at, id: .id, name: .name}" \
                >>"${all_workflows_list}"
            current_count=$(( current_count + remaining ))
            break
        else
            echo "${workflow_runs}" |
                jq -c '.[] | select(.status != "in_progress") | {date: .updated_at, id: .id, name: .name}' \
                >>"${all_workflows_list}"
            current_count=$(( current_count + get_results_length ))
        fi
    done

    if [[ -s "${all_workflows_list}" ]]; then
        # 移除空行
        sed -i '/^[[:space:]]*$/d' "${all_workflows_list}"

        # 按日期排序（最新的在前）
        jq -s 'sort_by(.date | fromdateiso8601) | reverse' "${all_workflows_list}" > "${all_workflows_list}.tmp"
        mv "${all_workflows_list}.tmp" "${all_workflows_list}"

        # 打印结果日志
        actual_count=$(cat "${all_workflows_list}" | wc -l)
        echo -e "${INFO} (2.3.1) 获取工作流信息请求成功"
        echo -e "${INFO} (2.3.2) 获取到的工作流数目总数: [ ${actual_count} / ${max_workflows_fetch} ]"
        [[ "${out_log}" == "true" ]] && {
            echo -e "${INFO} (2.3.3) 所有工作流运行列表:\n$(cat ${all_workflows_list})"
        }
    else
        echo -e "${NOTE} (2.3.4) 工作流列表为空，跳过"
    fi
}

out_workflows_list() {
    echo -e "${STEPS} 开始输出工作流列表..."

    # 临时文件定义
    filtered_by_time="json_filtered_by_time"
    filtered_by_keyword="json_filtered_by_keyword"
    keep_workflows_list="json_keep_workflows_list"

    if [[ -s "${all_workflows_list}" ]]; then
        # 复制原始列表用于后续过滤
        cp "${all_workflows_list}" "${filtered_by_time}"

        # 按时间排序（最新的在前）
        jq -s 'sort_by(.date | fromdateiso8601) | reverse' "${filtered_by_time}" > "${filtered_by_time}.tmp"
        mv "${filtered_by_time}.tmp" "${filtered_by_time}"

        # 截取前N条（最新的）
        if [[ "$(cat ${filtered_by_time} | jq length)" -gt "$workflows_keep_latest" ]]; then
            head -n "$workflows_keep_latest" "${filtered_by_time}" > "${filtered_by_time}.tmp"
            mv "${filtered_by_time}.tmp" "${filtered_by_time}"
            echo -e "${INFO} (2.4.1) 保留最新的 $workflows_keep_latest 条工作流"
        fi
        [[ "${out_log}" == "true" ]] && echo -e "${INFO} (2.4.2) 时间过滤后列表:\n$(cat ${filtered_by_time})"

        # 匹配需要保留的包含关键词的工作流
        if [[ "${#workflows_keep_keyword[@]}" -ge "1" && -s "${filtered_by_time}" ]]; then
            # 匹配符合关键词的工作流列表
            echo -e "${INFO} (2.4.3) 工作流过滤关键词: [ $(echo ${workflows_keep_keyword[@]} | xargs) ]"
            
            # 创建包含关键词的列表
            cp "${filtered_by_time}" "${filtered_by_keyword}"
            for keyword in "${workflows_keep_keyword[@]}"; do
                jq -c --arg keyword "$keyword" 'select(.name | test($keyword))' "${filtered_by_keyword}" > "${filtered_by_keyword}.tmp"
                mv "${filtered_by_keyword}.tmp" "${filtered_by_keyword}"
            done
            
            [[ "${out_log}" == "true" && -s "${filtered_by_keyword}" ]] && {
                echo -e "${INFO} (2.4.4) 符合条件的工作流列表:\n$(cat ${filtered_by_keyword})"
            }

            # 从原始列表中移除包含关键词的项
            if [[ -s "${filtered_by_keyword}" ]]; then
                # 创建不包含关键词的列表
                > "${all_workflows_list}"  # 清空删除列表
                while IFS= read -r line; do
                    id=$(echo "$line" | jq -r '.id')
                    if ! grep -q "\"id\":$id" "${filtered_by_keyword}"; then
                        echo "$line" >> "${all_workflows_list}"
                    fi
                done < "${filtered_by_time}"
                
                echo -e "${INFO} (2.4.5) 工作流关键词过滤成功"
            fi

            # 关键词过滤后的剩余工作流列表
            [[ "${out_log}" == "true" ]] && echo -e "${INFO} (2.4.6) 当前工作流运行列表:\n$(cat ${all_workflows_list})"
        else
            echo -e "${NOTE} (2.4.7) 工作流关键词过滤为空，跳过"
            cp "${filtered_by_time}" "${all_workflows_list}"
        fi

        # 生成需要保留的工作流列表
        if [[ -s "${all_workflows_list}" ]]; then
            if [[ "${workflows_keep_latest}" -eq "0" ]]; then
                echo -e "${INFO} (2.5.1) 删除所有工作流"
            else
                # 按日期排序（最新的在前）
                jq -s 'sort_by(.date | fromdateiso8601) | reverse' "${all_workflows_list}" > "${all_workflows_list}.tmp"
                mv "${all_workflows_list}.tmp" "${all_workflows_list}"

                # 保留最新的工作流
                head -n "${workflows_keep_latest}" "${all_workflows_list}" > "${keep_workflows_list}"
                echo -e "${INFO} (2.5.2) 保留工作流列表生成成功"
                [[ "${out_log}" == "true" && -s "${keep_workflows_list}" ]] && {
                    echo -e "${INFO} (2.5.3) 保留工作流列表:\n$(cat ${keep_workflows_list})"
                }

                # 从完整列表中移除需要保留的工作流（保留后面的条目）
                tail -n +$((workflows_keep_latest + 1)) "${all_workflows_list}" > "${all_workflows_list}.tmp"
                mv "${all_workflows_list}.tmp" "${all_workflows_list}"
            fi
        else
            echo -e "${NOTE} (2.5.4) 工作流列表为空，跳过"
        fi

        # 删除列表
        if [[ -s "${all_workflows_list}" ]]; then
            [[ "${out_log}" == "true" ]] && echo -e "${INFO} (2.5.5) 删除工作流列表:\n$(cat ${all_workflows_list})"
        else
            echo -e "${NOTE} (2.5.6) 删除工作流列表为空，跳过"
        fi

    else
        echo -e "${NOTE} (2.4.8) 工作流列表为空，跳过所有过滤步骤"
    fi

    echo -e ""
}

del_workflows_runs() {
    echo -e "${STEPS} 开始删除工作流..."

    # 删除工作流
    if [[ -s "${all_workflows_list}" && -n "$(cat ${all_workflows_list} | jq -r .id)" ]]; then
        total=$(cat ${all_workflows_list} | wc -l)
        count=0
        
        cat ${all_workflows_list} | jq -r .id | while read run_id; do
            count=$((count + 1))
            echo -e "${INFO} (2.6.1) 正在删除工作流 ${count}/${total}"
            
            response=$(curl -s -o /dev/null -w "%{http_code}" \
                -X DELETE \
                -H "Authorization: Bearer ${gh_token}" \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${repo}/actions/runs/${run_id}"
                )
                
            if [[ "$response" -eq 204 ]]; then
                echo -e "${SUCCESS} (2.6.2) 工作流 ${count}：ID=${run_id} 删除成功"
            else
                echo -e "${ERROR} (2.6.3) 删除工作流 ${count}：ID=${run_id} 失败: HTTP ${response}"
            fi
        done
        echo -e "${SUCCESS} (2.6.4) 工作流删除完成"
    else
        echo -e "${NOTE} (2.6.5) 没有需要删除的工作流，跳过"
    fi

    echo -e ""
}

# 显示欢迎信息
echo -e "${INFO} 欢迎使用删除旧发布和工作流工具!"

# 按顺序执行相关操作
init_var "${@}"

# 删除发布
if [[ "${delete_releases}" == "true" ]]; then
    get_releases_list
    out_releases_list
    del_releases_file
    del_releases_tags
else
    echo -e "${STEPS} 不启用删除发布和标签"
fi

# 删除工作流
if [[ "${delete_workflows}" == "true" ]]; then
    get_workflows_list
    out_workflows_list
    del_workflows_runs
else
    echo -e "${STEPS} 不启用删除工作流"
fi

wait    
