// ChatBox JavaScript 功能实现

class ChatBox {
    constructor() {
        this.config = window.ChatBoxConfig || {};
        this.logLevel = this.config.logging?.level || 'debug';
        this.logDebug('ChatBox: 构造函数初始化...');
        this.apiUrl = this.config.api?.endpoint || '/v1/chat/completions';
        this.messages = []; // 存储对话历史
        this.isLoading = false;
        this.currentTheme = localStorage.getItem('theme') || (this.config.ui?.defaultTheme || 'light');
        this.settings = {};
        
        this.init();
    }

    // 日志辅助函数
    _log(level, ...args) {
        const levels = { 'debug': 0, 'info': 1, 'warn': 2, 'error': 3, 'silent': 4 };
        if (levels[level] >= levels[this.logLevel]) {
            if (level === 'error') console.error(...args);
            else if (level === 'warn') console.warn(...args);
            else if (level === 'info') console.info(...args);
            else if (level === 'debug') console.log(...args);
        }
    }

    logDebug(...args) { this._log('debug', ...args); }
    logInfo(...args) { this._log('info', ...args); }
    logWarn(...args) { this._log('warn', ...args); }
    logError(...args) { this._log('error', ...args); }

    init() {
        this.logDebug('ChatBox: 初始化...');
        this.loadSettings();
        this.setupEventListeners();
        this.applyTheme();
        this.loadChatHistory();
        this.addWelcomeMessage();
        this.initSettingsPanel();
    }

    setupEventListeners() {
        this.logDebug('ChatBox: 设置事件监听器...');
        // 主题切换按钮
        const themeToggle = document.getElementById('toggle-theme');
        themeToggle.addEventListener('click', () => this.toggleTheme());

        // 清空聊天按钮
        const clearChatBtn = document.getElementById('clear-chat');
        clearChatBtn.addEventListener('click', () => {
            if (confirm('确定要清空聊天记录吗？')) {
                this.logInfo('ChatBox: 清空聊天记录确认...');
                this.clearChatHistory();
            }
        });

        // 聊天表单
        const chatForm = document.getElementById('chat-form');
        chatForm.addEventListener('submit', (e) => this.handleSubmit(e));

        // 输入框回车发送
        const userInput = document.getElementById('user-input');
        userInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.logDebug('ChatBox: 用户按Enter发送消息');
                this.handleSubmit(e);
            }
        });

        // 自动滚动到底部
        const chatWindow = document.getElementById('chat-window');
        chatWindow.addEventListener('scroll', () => {
            this.isNearBottom = this.isScrolledToBottom(chatWindow);
        });

        // 添加快捷键支持
        document.addEventListener('keydown', (e) => {
            // Ctrl/Cmd + , 打开设置
            if ((e.ctrlKey || e.metaKey) && e.key === ',') {
                e.preventDefault();
                this.logInfo('ChatBox: 快捷键 Ctrl/Cmd + , 打开设置');
                if (window.settingsPanel) {
                    window.settingsPanel.toggleSettings();
                }
            }
            
            // Ctrl/Cmd + I 聚焦输入框
            if ((e.ctrlKey || e.metaKey) && e.key === 'i') {
                e.preventDefault();
                this.logInfo('ChatBox: 快捷键 Ctrl/Cmd + I 聚焦输入框');
                document.getElementById('user-input').focus();
            }
        });
    }

    toggleTheme() {
        this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light';
        this.logInfo(`ChatBox: 切换主题到 ${this.currentTheme}`);
        this.applyTheme();
        localStorage.setItem('theme', this.currentTheme);
        
        const themeToggle = document.getElementById('toggle-theme');
        themeToggle.innerHTML = this.currentTheme === 'light' ? '🌙 夜间模式' : '☀️ 白天模式';
    }

    applyTheme() {
        document.documentElement.setAttribute('data-theme', this.currentTheme);
        document.body.className = this.currentTheme;
        this.logDebug(`ChatBox: 应用主题 ${this.currentTheme}`);
    }

    async handleSubmit(e) {
        e.preventDefault();
        this.logDebug('ChatBox: 处理表单提交...');
        
        const userInput = document.getElementById('user-input');
        const message = userInput.value.trim();
        this.logInfo(`ChatBox: 用户输入: ${message}`);
        
        if (!message || this.isLoading) {
            this.logDebug('ChatBox: 输入为空或正在加载，取消发送。');
            return;
        }

        // 添加用户消息
        this.addMessage('user', message);
        userInput.value = '';

        // 显示加载状态
        this.showTypingIndicator();

        try {
            this.logDebug('ChatBox: 调用 API...');
            // 调用 API
            const response = await this.callAPI(message);
            this.hideTypingIndicator();
            this.logDebug('ChatBox: API 响应:', response);
            
            if (response && response.choices && response.choices[0]) {
                const assistantMessage = response.choices[0].message.content;
                this.addMessage('assistant', assistantMessage);
            } else {
                this.addErrorMessage(this.config.errorMessages?.invalidResponse || '服务器响应格式错误');
                this.logError('ChatBox: 服务器响应格式错误:', response);
            }
        } catch (error) {
            this.hideTypingIndicator();
            this.logError('ChatBox: API 调用错误:', error);
            this.addErrorMessage(this.config.errorMessages?.apiError || `请求失败: ${error.message}`);
        }
    }

    async callAPI(message) {
        this.logDebug('ChatBox: 准备 API 请求...');
        // 构建 OpenAI 格式的请求
        const requestBody = {
            model: this.settings.modelName || this.config.model?.name || "local-model",
            messages: [
                ...this.messages.map(msg => ({
                    role: msg.role,
                    content: msg.content
                })),
                {
                    role: "user",
                    content: message
                }
            ],
            temperature: this.settings.temperature || this.config.model?.temperature || 0.7,
            max_tokens: this.settings.maxTokens || this.config.model?.maxTokens || 1000,
            top_p: this.config.model?.topP || 1.0,
            frequency_penalty: this.config.model?.frequencyPenalty || 0.0,
            presence_penalty: this.config.model?.presencePenalty || 0.0,
            stream: false
        };
        this.logDebug('ChatBox: API 请求体:', requestBody);

        const apiUrl = this.settings.apiUrl ? 
            this.settings.apiUrl + (this.config.api?.endpoint || '/v1/chat/completions') : 
            this.apiUrl;
        this.logInfo(`ChatBox: 最终 API URL: ${apiUrl}`);

        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.getApiKey()}`
            },
            body: JSON.stringify(requestBody)
        });

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            this.logError('ChatBox: API 响应非 OK:', response.status, errorData);
            // 更具体的错误消息
            if (response.status === 401) {
                throw new Error(this.config.errorMessages?.unauthorized || `HTTP 401: Unauthorized`);
            } else if (response.status === 429) {
                throw new Error(this.config.errorMessages?.rateLimited || `HTTP 429: Rate Limited`);
            } else {
                throw new Error(errorData.error?.message || `HTTP ${response.status}: ${response.statusText}`);
            }
        }
        this.logDebug('ChatBox: API 响应 OK.');
        return await response.json();
    }

    getApiKey() {
        const apiKey = this.settings.apiKey || localStorage.getItem('apiKey') || new URLSearchParams(window.location.search).get('apiKey') || '';
        this.logDebug(`ChatBox: 获取到 API Key (部分): ${apiKey.substring(0, 5)}...`);
        return apiKey;
    }

    addMessage(role, content) {
        this.logDebug(`ChatBox: 添加消息 - 角色: ${role}, 内容: ${content.substring(0, 50)}...`);
        const message = {
            role,
            content,
            timestamp: new Date()
        };

        this.messages.push(message);
        this.displayMessage(message);
        this.saveChatHistory();
        this.scrollToBottom();
    }

    displayMessage(message) {
        this.logDebug('ChatBox: 显示消息...');
        const chatWindow = document.getElementById('chat-window');
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${message.role}`;

        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';
        
        // 处理 Markdown 格式（简单的实现）
        contentDiv.innerHTML = this.formatMessage(message.content);

        messageDiv.appendChild(contentDiv);

        // 根据设置决定是否显示时间戳
        if (this.settings.showTimestamps !== false) {
            const timeDiv = document.createElement('span');
            timeDiv.className = 'message-time';
            timeDiv.textContent = this.formatTime(message.timestamp);
            messageDiv.appendChild(timeDiv);
        }

        chatWindow.appendChild(messageDiv);
    }

    formatMessage(content) {
        // this.logDebug('ChatBox: 格式化 Markdown...'); // Too frequent
        // 简单的 Markdown 格式化
        return content
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            .replace(/`(.*?)`/g, '<code>$1</code>')
            .replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
            .replace(/\n/g, '<br>');
    }

    formatTime(date) {
        return date.toLocaleTimeString('zh-CN', {
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    showTypingIndicator() {
        this.isLoading = true;
        this.logDebug('ChatBox: 显示打字指示器...');
        const chatWindow = document.getElementById('chat-window');
        
        const typingDiv = document.createElement('div');
        typingDiv.className = 'typing-indicator';
        typingDiv.id = 'typing-indicator';
        
        for (let i = 0; i < 3; i++) {
            const dot = document.createElement('div');
            dot.className = 'typing-dot';
            typingDiv.appendChild(dot);
        }
        
        chatWindow.appendChild(typingDiv);
        this.scrollToBottom();
    }

    hideTypingIndicator() {
        this.isLoading = false;
        this.logDebug('ChatBox: 隐藏打字指示器...');
        const typingIndicator = document.getElementById('typing-indicator');
        if (typingIndicator) {
            typingIndicator.remove();
        }
    }

    addErrorMessage(message) {
        this.logError(`ChatBox: 添加错误消息: ${message}`);
        const chatWindow = document.getElementById('chat-window');
        const errorDiv = document.createElement('div');
        errorDiv.className = 'alert alert-danger'; // Use Bootstrap alert class
        errorDiv.setAttribute('role', 'alert');
        errorDiv.textContent = message;
        chatWindow.appendChild(errorDiv);
        this.scrollToBottom();
    }

    addWelcomeMessage() {
        this.logInfo('ChatBox: 添加欢迎消息...');
        const welcomeMessage = {
            role: 'assistant',
            content: this.config.welcomeMessage || '你好！我是 AI 助手，有什么可以帮助你的吗？',
            timestamp: new Date()
        };
        this.messages.push(welcomeMessage);
        this.displayMessage(welcomeMessage);
    }

    scrollToBottom() {
        if (this.settings.autoScroll !== false) {
            this.logDebug('ChatBox: 滚动到底部...');
            const chatWindow = document.getElementById('chat-window');
            chatWindow.scrollTop = chatWindow.scrollHeight;
        }
    }

    isScrolledToBottom(element) {
        return element.scrollHeight - element.scrollTop <= element.clientHeight + 100;
    }

    saveChatHistory() {
        try {
            localStorage.setItem(this.config.storage?.chatHistoryKey || 'chatHistory', JSON.stringify(this.messages));
            this.logDebug('ChatBox: 聊天历史已保存。');
        } catch (error) {
            this.logWarn('ChatBox: 保存聊天历史失败:', error);
        }
    }

    loadChatHistory() {
        try {
            const saved = localStorage.getItem(this.config.storage?.chatHistoryKey || 'chatHistory');
            if (saved) {
                this.messages = JSON.parse(saved);
                this.logInfo(`ChatBox: 加载到 ${this.messages.length} 条聊天历史。`);
                this.messages.forEach(msg => {
                    msg.timestamp = new Date(msg.timestamp);
                    this.displayMessage(msg);
                });
            } else {
                this.logInfo('ChatBox: 没有找到聊天历史，添加欢迎消息。');
            }
        } catch (error) {
            this.logWarn('ChatBox: 加载聊天历史失败:', error);
        }
    }

    clearChatHistory() {
        this.messages = [];
        const chatWindow = document.getElementById('chat-window');
        chatWindow.innerHTML = '';
        localStorage.removeItem(this.config.storage?.chatHistoryKey || 'chatHistory');
        this.addWelcomeMessage();
        this.logInfo('ChatBox: 聊天历史已清空。');
    }

    loadSettings() {
        try {
            const stored = localStorage.getItem(this.config.storage?.settingsKey || 'chatboxSettings');
            this.settings = stored ? JSON.parse(stored) : {};
            this.logDebug('ChatBox: 加载到设置:', this.settings);
        } catch (error) {
            this.logWarn('ChatBox: 加载设置失败:', error);
            this.settings = {};
        }
    }

    updateSettings(newSettings) {
        this.logInfo('ChatBox: 更新设置:', newSettings);
        this.settings = { ...this.settings, ...newSettings };
        
        // 更新 API URL
        if (newSettings.apiUrl) {
            this.apiUrl = newSettings.apiUrl + (this.config.api?.endpoint || '/v1/chat/completions');
            this.logInfo(`ChatBox: API URL 更新为: ${this.apiUrl}`);
        } else {
            this.apiUrl = this.config.api?.endpoint || '/v1/chat/completions';
            this.logInfo(`ChatBox: API URL 重置为默认: ${this.apiUrl}`);
        }

        // 重新应用主题以防主题设置有变化 (虽然主题切换在toggleTheme中处理)
        if (newSettings.defaultTheme && this.currentTheme !== newSettings.defaultTheme) {
            this.currentTheme = newSettings.defaultTheme;
            this.applyTheme();
        }
    }

    initSettingsPanel() {
        this.logDebug('ChatBox: 初始化设置面板...');
        if (window.SettingsPanel) {
            window.settingsPanel = new SettingsPanel(this.logLevel); // Pass log level to settings panel
        } else {
            this.logWarn('ChatBox: SettingsPanel 未加载。');
        }
    }
}

// 工具函数
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', () => {
    console.log('DOMContentLoaded: 初始化 ChatBox...');
    window.chatBox = new ChatBox();
    
    // 添加键盘快捷键
    document.addEventListener('keydown', (e) => {
        // Ctrl/Cmd + K 清空聊天
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
            e.preventDefault();
            console.log('DOMContentLoaded: 快捷键 Ctrl/Cmd + K 触发清空聊天。');
            if (confirm('确定要清空聊天记录吗？')) {
                window.chatBox.clearChatHistory();
            }
        }
        
        // Ctrl/Cmd + L 切换主题
        if ((e.ctrlKey || e.metaKey) && e.key === 'l') {
            e.preventDefault();
            console.log('DOMContentLoaded: 快捷键 Ctrl/Cmd + L 触发主题切换。');
            window.chatBox.toggleTheme();
        }
    });
});

// 错误处理
window.addEventListener('error', (e) => {
    console.error('全局错误:', e.error);
});

window.addEventListener('unhandledrejection', (e) => {
    console.error('未处理的 Promise 拒绝:', e.reason);
}); 