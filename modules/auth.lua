-- AppKey 认证模块
local cjson = require "cjson"

local _M = {
    version = "1.0"
}

local appkeys = require "conf.appkeys"

-- 从请求头获取 AppKey
local function get_appkey_from_header()
    local auth_header = ngx.req.get_headers()["Authorization"]
    if not auth_header then
        return nil
    end
    
    -- 支持 Bearer sk-xxx 和 sk-xxx 两种格式
    local appkey = string.match(auth_header, "^Bearer%s+(.+)$") or auth_header
    return appkey
end

-- 验证 AppKey
function _M.authenticate()
    local appkey = get_appkey_from_header()
    
    if not appkey then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({
            error = {
                message = "No API key provided. Include it in 'Authorization' header",
                type = "auth_error"
            }
        }))
        return false
    end

    local key_info = appkeys.keys[appkey]
    if not key_info then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({
            error = {
                message = "Invalid API key",
                type = "auth_error"
            }
        }))
        return false
    end

    -- 请求频率限制（QPS）
    local current_qps = key_info.qps or 10  -- 默认 10 QPS
    local key_prefix = "qps:" .. appkey
    
    -- 使用共享内存字典进行限流（也可以改用 Redis 实现分布式限流）
    local limit_store = ngx.shared.limit_store
    local current = limit_store:incr(key_prefix, 1, 0, 1)  -- 1秒过期
    
    if current and current > current_qps then
        ngx.status = 429
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({
            error = {
                message = "API rate limit exceeded",
                type = "rate_limit_error"
            }
        }))
        return false
    end

    -- 验证通过
    return true
end

return _M
