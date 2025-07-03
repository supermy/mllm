// ChatBox 配置文件

const ChatBoxConfig = {
    // API 配置
    api: {
        baseUrl: window.location.origin, // 自动检测当前域名
        endpoint: '/v1/chat/completions',
        timeout: 60000, // 60秒超时
        retryAttempts: 3,
        retryDelay: 1000
    },

    // 模型配置
    model: {
        name: 'local-model',
        temperature: 0.7,
        maxTokens: 1000,
        topP: 1.0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0
    },

    // UI 配置
    ui: {
        defaultTheme: 'light',
        autoScroll: true,
        showTimestamps: true,
        maxMessageLength: 4000,
        typingIndicatorDelay: 300
    },

    // 本地存储配置
    storage: {
        chatHistoryKey: 'chatHistory',
        themeKey: 'theme',
        apiKeyKey: 'apiKey',
        settingsKey: 'chatboxSettings'
    },

    // 日志配置
    logging: {
        level: 'debug' // 'debug', 'info', 'warn', 'error', 'silent'
    },

    // 默认欢迎消息
    welcomeMessage: '你好！我是 AI 助手，有什么可以帮助你的吗？',

    // 错误消息
    errorMessages: {
        networkError: '网络连接错误，请检查网络连接',
        apiError: 'API 调用失败',
        timeoutError: '请求超时，请稍后重试',
        invalidResponse: '服务器响应格式错误',
        unauthorized: '认证失败，请检查 API Key',
        rateLimited: '请求过于频繁，请稍后重试'
    },

    // 快捷键配置
    shortcuts: {
        toggleTheme: 'Ctrl+L',
        clearChat: 'Ctrl+K',
        focusInput: 'Ctrl+I'
    }
};

// 导出配置
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ChatBoxConfig;
} else {
    window.ChatBoxConfig = ChatBoxConfig;
} 