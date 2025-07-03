-- api_gateway.lua

local cjson = require "cjson"
local http = require "resty.http"
local auth = require "modules.auth"

local LLM_SERVICE_URL = "http://127.0.0.1:5002"

-- 初始化共享内存字典，用于限流
local shared_dict_exists, _ = pcall(function() return ngx.shared.limit_store end)
if not shared_dict_exists then
    ngx.log(ngx.ERR, "请在 nginx.conf 的 http 块添加: lua_shared_dict limit_store 10m;")
end

-- 先进行认证
local function authenticate_request()
    if ngx.var.uri == "/health" then
        return true  -- 健康检查接口不需要认证
    end
    return auth.authenticate()
end

if not authenticate_request() then
    return  -- 认证失败，auth 模块已经输出了错误响应
end

-- 转换 OpenAI 格式到内部格式
local function convert_openai_to_internal(openai_request)
    local messages = openai_request.messages
    if not messages or #messages == 0 then
        return nil, "No messages provided"
    end

    -- 构建提示词
    local prompt = ""
    for _, msg in ipairs(messages) do
        if msg.role == "system" then
            prompt = prompt .. "[SYSTEM] " .. msg.content .. "\n"
        elseif msg.role == "user" then
            prompt = prompt .. "[USER] " .. msg.content .. "\n"
        elseif msg.role == "assistant" then
            prompt = prompt .. "[ASSISTANT] " .. msg.content .. "\n"
        end
    end

    -- 构建内部请求格式
    return {
        prompts = {prompt},
        temperature = openai_request.temperature or 0.7,
        max_tokens = openai_request.max_tokens or 100,
        top_p = openai_request.top_p or 1,
        stream = openai_request.stream or false
    }
end

-- 转换内部响应格式到 OpenAI 格式
local function extract_latest_assistant_response(full_text)
    local assistant_marker = "[ASSISTANT]"
    local last_assistant_marker_start = nil
    local current_pos = 1
    while true do
        local start_pos, end_pos = string.find(full_text, assistant_marker, current_pos, true) -- true for plain text search
        if start_pos then
            last_assistant_marker_start = start_pos
            current_pos = end_pos + 1
        else
            break
        end
    end

    if not last_assistant_marker_start then
        return full_text
    end

    local potential_response = string.sub(full_text, last_assistant_marker_start + string.len(assistant_marker .. " "))

    -- 查找内部独白或下一个用户/助手对话的起始位置
    -- 内部独白通常以双换行符加 "好的，现在用户在重复" 开始
    local monologue_start = string.find(potential_response, "\n\n好的，现在用户在重复", 1, true)
    -- 下一个用户对话的起始
    local next_user_start = string.find(potential_response, "\n[USER]", 1, true)

    local end_of_response_index = #potential_response + 1 -- 默认到字符串末尾

    if monologue_start then
        end_of_response_index = math.min(end_of_response_index, monologue_start)
    end
    if next_user_start then
        end_of_response_index = math.min(end_of_response_index, next_user_start)
    end

    local extracted_content = string.sub(potential_response, 1, end_of_response_index - 1)

    -- 移除提取内容前后的空白字符和换行符
    extracted_content = string.gsub(extracted_content, "^%s*(.-)%s*$", "%1")

    return extracted_content
end

local function convert_internal_to_openai(internal_response)
    ngx.log(ngx.DEBUG, "[convert_internal_to_openai] 入参: " .. cjson.encode(internal_response))
    local responses = internal_response.responses or internal_response.results
    if not responses or #responses == 0 then
        ngx.log(ngx.ERR, "[convert_internal_to_openai] 无有效 responses/results 字段")
        return {
            error = {
                message = "No response generated",
                type = "server_error"
            }
        }
    end

    local full_llm_response_text = responses[1].text or ""
    local content_to_use = extract_latest_assistant_response(full_llm_response_text)

    local result = {
        id = "chatcmpl-" .. ngx.now() * 1000,
        object = "chat.completion",
        created = ngx.time(),
        model = "local-model",
        usage = {
            prompt_tokens = -1,  -- 这里可以添加实际的 token 计数
            completion_tokens = -1,
            total_tokens = -1
        },
        choices = {
            {
                message = {
                    role = "assistant",
                    content = content_to_use -- 使用提取后的内容
                },
                finish_reason = "stop",
                index = 0
            }
        }
    }
    ngx.log(ngx.DEBUG, "[convert_internal_to_openai] 出参: " .. cjson.encode(result))
    return result
end

local function handle_health_check()
    local httpc = http.new()
    local res, err = httpc:request_uri(LLM_SERVICE_URL .. "/health", {
        method = "GET",
        headers = {{"Content-Type", "application/json"}},
        read_timeout = 5000,
        connect_timeout = 2000
    })

    if not res then
        ngx.status = ngx.HTTP_SERVICE_UNAVAILABLE
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({status = "LLM service not reachable or unhealthy.", error = tostring(err)}))
        return
    end

    ngx.status = res.status
    ngx.header["Content-Type"] = "application/json"
    ngx.say(res.body)
end

local function handle_chat_completion()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    ngx.log(ngx.DEBUG, "[chat_completion] 原始请求体: " .. tostring(data))

    if not data then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({
            error = {
                message = "No request body provided.",
                type = "invalid_request_error"
            }
        }))
        return
    end

    local openai_request, err = cjson.decode(data)
    if not openai_request then
        ngx.log(ngx.ERR, "[chat_completion] JSON 解析失败: " .. tostring(err))
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({
            error = {
                message = "Invalid JSON in request body: " .. err,
                type = "invalid_request_error"
            }
        }))
        return
    end

    ngx.log(ngx.DEBUG, "[chat_completion] 解析后 openai_request: " .. cjson.encode(openai_request))
    -- 转换请求格式
    local internal_request, convert_err = convert_openai_to_internal(openai_request)
    if not internal_request then
        ngx.log(ngx.ERR, "[chat_completion] OpenAI->内部格式转换失败: " .. tostring(convert_err))
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({
            error = {
                message = convert_err,
                type = "invalid_request_error"
            }
        }))
        return
    end

    ngx.log(ngx.DEBUG, "[chat_completion] 转换后 internal_request: " .. cjson.encode(internal_request))
    local httpc = http.new()
    local res, err = httpc:request_uri(LLM_SERVICE_URL .. "/generate", {
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        body = cjson.encode(internal_request),
        read_timeout = 60000,
        connect_timeout = 5000
    })

    if not res then
        ngx.log(ngx.ERR, "[chat_completion] LLM 服务调用失败: " .. tostring(err))
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({
            error = {
                message = "Error communicating with LLM service: " .. tostring(err),
                type = "server_error"
            }
        }))
        return
    end

    ngx.log(ngx.DEBUG, "[chat_completion] LLM 服务原始响应状态: " .. tostring(res.status))
    ngx.log(ngx.DEBUG, "[chat_completion] LLM 服务原始响应体: " .. tostring(res.body))
    -- 转换响应格式
    local internal_response = cjson.decode(res.body)
    ngx.log(ngx.DEBUG, "[chat_completion] LLM 服务响应解析为 internal_response: " .. cjson.encode(internal_response))
    local openai_response = convert_internal_to_openai(internal_response)

    ngx.status = res.status
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode(openai_response))
end

local uri = ngx.var.uri

if uri == "/health" then
    handle_health_check()
elseif uri == "/v1/chat/completions" then
    handle_chat_completion()
else
    ngx.status = ngx.HTTP_NOT_FOUND
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        error = {
            message = "Not Found",
            type = "invalid_request_error"
        }
    }))
end