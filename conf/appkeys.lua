-- AppKey 配置
local _M = {
    version = "1.0"
}

-- AppKey 列表，格式：[appkey] = {name = "应用名称", qps = 最大请求频率}
_M.keys = {
    ["sk-test123456"] = { name = "测试应用", qps = 10 },
    -- 在此添加更多 AppKey
}

-- Redis 配置（可选，用于分布式限流）
_M.redis = {
    host = "127.0.0.1",
    port = 6379,
    timeout = 1000,  -- 毫秒
    password = nil
}

return _M
