-- api_gateway.lua

local cjson = require "cjson"
local http = require "resty.http"

local LLM_SERVICE_URL = "http://127.0.0.1:5002"
local LLM_SERVICE_URL_0 = "http://127.0.0.1"

local function handle_health_check()
    local httpc = http.new()
    local res, err = httpc:request_uri(LLM_SERVICE_URL .. "/health", {
        method = "GET",
        headers = {{"Content-Type", "application/json"}},
        read_timeout = 5000, -- 5 seconds
        connect_timeout = 2000 -- 2 seconds
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

local function handle_generate_text()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()

    if not data then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({error = "No request body provided."}))
        return
    end

    local req_body_json, err = cjson.decode(data)
    if not req_body_json then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({error = "Invalid JSON in request body: " .. err}))
        return
    end

    if not req_body_json.prompts then
        ngx.status = ngx.HTTP_BAD_REQUEST
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({error = "No prompts provided."}))
        return
    end

    local httpc = http.new()
    -- local res, err = httpc:request_uri(LLM_SERVICE_URL_0 .. "/generate", {
    local res, err = httpc:request_uri(LLM_SERVICE_URL .. "/generate", {
        method = "POST",
        -- headers = {{"Content-Type", "application/json"}},
        headers = { ["Content-Type"] = "application/json" },
        body = data, -- 直接转发原始 JSON body
        read_timeout = 60000, -- 60 seconds
        connect_timeout = 5000 -- 5 seconds
    })

    if not res then
        ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({error = "Error communicating with LLM service: " .. tostring(err)}))
        return
    end

    ngx.status = res.status
    ngx.header["Content-Type"] = "application/json"
    ngx.say(res.body)
end

local uri = ngx.var.uri

if uri == "/health" then
    handle_health_check()
elseif uri == "/generate" then
    handle_generate_text()
else
    ngx.status = ngx.HTTP_NOT_FOUND
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({error = "Not Found"}))
end