// 设置面板组件

class SettingsPanel {
    constructor(logLevel = 'debug') {
        this.logLevel = logLevel;
        this.logDebug('SettingsPanel: 构造函数初始化...');
        this.isOpen = false;
        this.init();
    }

    // 日志辅助函数 (复制自 ChatBox，保持一致性)
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
        this.logDebug('SettingsPanel: 初始化...');
        this.createSettingsPanel();
        this.setupEventListeners();
        this.loadSettings();
    }

    createSettingsPanel() {
        this.logDebug('SettingsPanel: 创建设置面板元素...');
        // 创建设置面板 (modal 结构已在 index.html 中)
        const settingsPanel = document.getElementById('settingsModal');
        if (!settingsPanel) {
            this.logError('SettingsPanel: settingsModal 元素未找到，无法初始化 Bootstrap Modal。');
            return;
        }
        
        // Initialize Bootstrap Modal
        this.settingsModalInstance = new bootstrap.Modal(settingsPanel);

        this.logDebug('SettingsPanel: 设置面板元素创建完成。');
    }

    setupEventListeners() {
        this.logDebug('SettingsPanel: 设置事件监听器...');
        // 设置按钮
        document.getElementById('settings-btn').addEventListener('click', () => {
            this.logInfo('SettingsPanel: 设置按钮点击。');
            this.toggleSettings();
        });

        // 关闭设置 (Bootstrap Modal 自身会处理 close button)
        document.getElementById('settingsModal').addEventListener('hide.bs.modal', () => {
            this.logDebug('SettingsPanel: Modal 隐藏事件。');
            this.isOpen = false;
        });
        document.getElementById('settingsModal').addEventListener('show.bs.modal', () => {
            this.logDebug('SettingsPanel: Modal 显示事件。');
            this.isOpen = true;
            this.loadSettings(); // 每次打开都重新加载，确保最新值
        });

        // 保存设置
        document.getElementById('save-settings').addEventListener('click', () => {
            this.logInfo('SettingsPanel: 保存设置按钮点击。');
            this.saveSettings();
        });

        // 重置设置
        document.getElementById('reset-settings').addEventListener('click', () => {
            this.logInfo('SettingsPanel: 重置设置按钮点击。');
            this.resetSettings();
        });

        // 温度滑块
        const temperatureSlider = document.getElementById('temperature');
        const temperatureValue = document.getElementById('temperature-value');
        temperatureSlider.addEventListener('input', (e) => {
            temperatureValue.textContent = e.target.value;
            this.logDebug(`SettingsPanel: 温度滑块值: ${e.target.value}`);
        });

        // ESC 键关闭设置 (Bootstrap Modal 自身已处理)
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen) {
                this.logDebug('SettingsPanel: ESC 键关闭 Modal。');
                // this.closeSettings(); // Bootstrap modal handles this
            }
            // Ctrl+, 快捷键已经在 ChatBox 中处理，并调用了 toggleSettings
        });

        // 监听表单输入变化以实时更新 ChatBox 配置 (可选，如果不需要实时更新，只在保存时更新)
        document.getElementById('settings-form').addEventListener('input', debounce(() => {
            // this.saveSettings(); // 不实时保存，只在点击保存时才保存
        }, 500));
    }

    toggleSettings() {
        this.logInfo('SettingsPanel: 切换设置面板。');
        if (this.isOpen) {
            this.settingsModalInstance.hide();
        } else {
            this.settingsModalInstance.show();
        }
    }

    openSettings() {
        this.logInfo('SettingsPanel: 打开设置面板。');
        this.settingsModalInstance.show();
    }

    closeSettings() {
        this.logInfo('SettingsPanel: 关闭设置面板。');
        this.settingsModalInstance.hide();
    }

    loadSettings() {
        this.logDebug('SettingsPanel: 加载设置到表单...');
        const settings = this.getStoredSettings();
        
        // 加载设置到表单
        document.getElementById('api-key').value = settings.apiKey || '';
        document.getElementById('api-url').value = settings.apiUrl || '';
        document.getElementById('model-name').value = settings.modelName || ChatBoxConfig.model.name;
        document.getElementById('temperature').value = settings.temperature || ChatBoxConfig.model.temperature;
        document.getElementById('temperature-value').textContent = settings.temperature || ChatBoxConfig.model.temperature;
        document.getElementById('max-tokens').value = settings.maxTokens || ChatBoxConfig.model.maxTokens;
        document.getElementById('auto-scroll').checked = settings.autoScroll !== undefined ? settings.autoScroll : ChatBoxConfig.ui.autoScroll;
        document.getElementById('show-timestamps').checked = settings.showTimestamps !== undefined ? settings.showTimestamps : ChatBoxConfig.ui.showTimestamps;
        this.logDebug('SettingsPanel: 设置加载完成。', settings);
    }

    saveSettings() {
        this.logInfo('SettingsPanel: 保存设置...');
        const settings = {
            apiKey: document.getElementById('api-key').value,
            apiUrl: document.getElementById('api-url').value,
            modelName: document.getElementById('model-name').value,
            temperature: parseFloat(document.getElementById('temperature').value),
            maxTokens: parseInt(document.getElementById('max-tokens').value),
            autoScroll: document.getElementById('auto-scroll').checked,
            showTimestamps: document.getElementById('show-timestamps').checked
        };

        localStorage.setItem(ChatBoxConfig.storage.settingsKey, JSON.stringify(settings));
        this.logInfo('SettingsPanel: 设置已保存到 localStorage。', settings);
        
        // 更新全局配置
        if (window.chatBox) {
            window.chatBox.updateSettings(settings);
            this.logInfo('SettingsPanel: 已通知 ChatBox 更新设置。');
        }

        this.showNotification('设置已保存');
        this.closeSettings();
    }

    resetSettings() {
        this.logInfo('SettingsPanel: 重置设置为默认值...');
        if (confirm('确定要重置所有设置为默认值吗？')) {
            localStorage.removeItem(ChatBoxConfig.storage.settingsKey);
            this.loadSettings();
            this.showNotification('设置已重置');
            this.logInfo('SettingsPanel: 设置已重置为默认值。');
            
            // 也通知 ChatBox 更新配置
            if (window.chatBox) {
                window.chatBox.loadSettings(); // 重新加载全局设置
                window.chatBox.updateSettings({}); // 触发更新，但传递空对象，使其使用默认值
            }
        }
    }

    getStoredSettings() {
        try {
            const stored = localStorage.getItem(ChatBoxConfig.storage.settingsKey);
            return stored ? JSON.parse(stored) : {};
        } catch (error) {
            this.logWarn('SettingsPanel: 从 localStorage 加载设置失败:', error);
            return {};
        }
    }

    showNotification(message) {
        this.logInfo(`SettingsPanel: 显示通知: ${message}`);
        const notification = document.createElement('div');
        notification.className = 'alert alert-success notification position-fixed bottom-0 end-0 m-3'; // Bootstrap alert class
        notification.setAttribute('role', 'alert');
        notification.textContent = message;
        document.body.appendChild(notification);

        setTimeout(() => {
            notification.classList.add('show');
        }, 100);

        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => {
                document.body.removeChild(notification);
            }, 300);
        }, 2000);
    }
}

// 导出设置面板
if (typeof module !== 'undefined' && module.exports) {
    module.exports = SettingsPanel;
} else {
    window.SettingsPanel = SettingsPanel;
} 