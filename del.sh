filter_workflows() {
    echo -e "${STEPS} 开始过滤工作流列表..."

    all_workflows_list="${TMP_DIR}/A_all_workflows_list.json"
    keep_keyword_workflows_list="${TMP_DIR}/B_keep_keyword_workflows.json"
    > "${keep_keyword_workflows_list}"

    # 创建临时文件
    temp_file="${TMP_DIR}/temp_filtered.json"
    > "${temp_file}"

    if [[ "${#workflows_keep_keyword[@]}" -ge "1" && -s "${all_workflows_list}" ]]; then
        echo -e "${INFO} (2.4.1) 过滤工作流关键词: [ $(echo ${workflows_keep_keyword[@]} | xargs) ]"

        # 确保文件是有效的JSON数组
        if ! jq -e '. | type == "array"' "${all_workflows_list}" &>/dev/null; then
            # 如果不是数组，转换为数组
            jq -s '.' "${all_workflows_list}" > "${all_workflows_list}.tmp"
            mv "${all_workflows_list}.tmp" "${all_workflows_list}"
        fi

        # 提取匹配关键词的工作流到B文件
        for keyword in "${workflows_keep_keyword[@]}"; do
            jq -c --arg kw "$keyword" '.[] | select(.name | contains($kw))' "${all_workflows_list}" >> "${keep_keyword_workflows_list}"
        done

        # 提取不匹配关键词的工作流到临时文件
        jq -c '.[]' "${all_workflows_list}" | while read -r workflow; do
            match=false
            for keyword in "${workflows_keep_keyword[@]}"; do
                if echo "$workflow" | jq -e --arg kw "$keyword" 'select(.name | contains($kw))' &>/dev/null; then
                    match=true
                    break
                fi
            done
            if ! $match; then
                echo "$workflow" >> "${temp_file}"
            fi
        done

        # 更新主列表为不匹配的内容
        jq -s '.' "${temp_file}" > "${all_workflows_list}"

        if [[ "${out_log}" == "true" ]]; then
            if [[ -s "${keep_keyword_workflows_list}" ]]; then
                echo -e "${DISPLAY} (2.4.2) 过滤关键词的条目，将不会被删除:"
                jq -s '.' "${keep_keyword_workflows_list}" | jq -c '.[]'
                echo -e ""
            fi
            if [[ -s "${all_workflows_list}" ]]; then
                echo -e "${DISPLAY} (2.4.3) 关键词过滤后剩余列表:"
                jq -c '.[]' "${all_workflows_list}"
                echo -e ""
            else
                echo -e "${NOTE} (2.4.4) 关键词过滤后列表为空"
            fi
        fi
    else
        echo -e "${NOTE} (2.4.5) 过滤关键词为空，跳过"
    fi

    # 保留最新的指定数量工作流
    keep_latest_workflows_list="${TMP_DIR}/C_keep_latest_workflows.json"
    > "${keep_latest_workflows_list}"

    if [[ -s "${all_workflows_list}" ]]; then
        if [[ "${workflows_keep_latest}" -eq "0" ]]; then
            echo -e "${INFO} (2.5.1) 将删除所有剩余工作流"
        else
            # 按日期排序（从旧到新）
            jq -s 'sort_by(.date)' "${all_workflows_list}" | jq -c '.[]' > "${all_workflows_list}.tmp"
            mv "${all_workflows_list}.tmp" "${all_workflows_list}"

            # 计算总行数
            total_lines=$(wc -l < "${all_workflows_list}")
            
            if [[ "${total_lines}" -gt "${workflows_keep_latest}" ]]; then
                # 保留最新的N条记录（最后N条）
                tail -n "${workflows_keep_latest}" "${all_workflows_list}" > "${keep_latest_workflows_list}"

                # 从原始列表中移除保留的工作流
                head -n "-${workflows_keep_latest}" "${all_workflows_list}" > "${all_workflows_list}.tmp"
                mv "${all_workflows_list}.tmp" "${all_workflows_list}"
            else
                # 如果总数小于等于要保留的数量，全部保留
                cp "${all_workflows_list}" "${keep_latest_workflows_list}"
                > "${all_workflows_list}"
            fi

            if [[ "${out_log}" == "true" ]]; then
                if [[ -s "${keep_latest_workflows_list}" ]]; then
                    echo -e "${DISPLAY} (2.5.2) 保留时间靠前的工作流，将不会被删除:"
                    jq -c '.' "${keep_latest_workflows_list}"
                    echo -e ""
                fi
                if [[ -s "${all_workflows_list}" ]]; then
                    echo -e "${DISPLAY} (2.5.3) 将要删除的工作流列表:"
                    jq -c '.' "${all_workflows_list}"
                    echo -e ""
                else
                    echo -e "${NOTE} (2.5.4) 没有需要删除的工作流"
                fi
            fi
        fi
    else
        echo -e "${NOTE} (2.5.5) 工作流列表为空，跳过"
    fi
}
