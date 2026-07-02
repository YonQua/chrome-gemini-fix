# Chrome Gemini Auto Browse Enabler

[English](#english) | [中文说明](#chinese)

---

<a name="chinese"></a>

## 🇨🇳 中文说明

通过强制开启资格标志和地区设置，解锁 Google Chrome (v144+) 中隐藏的 "Auto Browse" (AI Agent) 功能。

### 🚀 功能特性

- **强制开启 AI 资格**：修改 `Local State` 配置文件，将 `is_glic_eligible` 强制设为 `true`。
- **地区伪装**：将 Chrome 的 variations country 和 permanent consistency country 设置为 `us` (美国)。
- **语言配置**：将 Chrome 内部 `app_locale` 与默认 Profile 的网页语言偏好设置为 `en-US` / `en-US,en`，同时清除 macOS 单应用语言覆盖，让界面语言跟随系统。
- **持久化配置**：使用 macOS `defaults` 命令写入地区限制参数，防止重启后配置被重置。
- **自动备份**：在修改前自动备份您的 `Local State` 和默认 Profile `Preferences` 文件。
- **一键回滚**：通过 `--restore` 参数从最近备份恢复上述配置文件。
- **Canary 支持**：同时支持标准 Chrome 和 Chrome Canary。

### 🛠 使用方法

1. **下载脚本**：

   ```bash
   git clone https://github.com/YonQua/chrome-gemini-fix.git
   cd chrome-gemini-fix
   ```

2. **运行安装脚本**：

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **命令行选项**：

   | 选项            | 说明                                         |
   | --------------- | -------------------------------------------- |
   | `--help`        | 显示帮助信息                                 |
   | `--restore`     | 从最近的备份恢复配置文件                     |
   | `--chrome NAME` | 指定 Chrome 版本（默认 Chrome，可选 Canary） |

4. **安装后步骤**：
   - 将您的 VPN 连接到 **美国 (United States)** 节点。
   - 在浏览器地址栏输入 `chrome://flags`，搜索并启用所有与 **Glic** 相关的选项（如 Glic、Glic Actor、Glic Pre-Warming）。
   - 重启 Chrome。
   - 本脚本不会修改系统时区或 Emoji/Canvas 渲染特征；网页指纹检测仍可能通过这些系统级信号识别地区。

### ⚠️ 系统要求

- Google Chrome v144 或更高版本。
- macOS（本脚本目前专为 macOS 优化）。
- 拥有 Gemini Pro 订阅的 Google 账号（推荐，以获得完整体验）。

### 📄 免责声明

本工具会修改您的 Chrome 配置文件。虽然脚本会自动创建备份，但请自行承担使用风险。这是一个非官方补丁，与 Google 无关。

---

<a name="english"></a>

## 🇺🇸 English

Unlock the hidden "Auto Browse" (AI Agent) features in Google Chrome (v144+) by forcing eligibility flags and region settings.

### 🚀 Features

- **Force Enable AI Eligibility**: Patches `Local State` to set `is_glic_eligible` to `true`.
- **Region Spoofing**: Sets Chrome variations country and permanent consistency country to `us` (United States).
- **Language Handling**: Sets Chrome's internal `app_locale` and the default Profile web language preferences to `en-US` / `en-US,en` while clearing the macOS per-app language override so the UI follows the system language.
- **Persistence**: Uses macOS `defaults` to persist the region restriction parameter.
- **Backup & Restore**: Automatically backs up `Local State` and the default Profile `Preferences` before changes; `--restore` reverts those files.
- **Canary Support**: Supports standard Chrome and Chrome Canary.

### 🛠 Usage

1. **Download the script**:

   ```bash
   git clone https://github.com/YonQua/chrome-gemini-fix.git
   cd chrome-gemini-fix
   ```

2. **Run the installer**：

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Command-line options**:

   | Option          | Description                                            |
   | --------------- | ------------------------------------------------------ |
   | `--help`        | Show help message                                      |
   | `--restore`     | Restore from latest backup                             |
   | `--chrome NAME` | Specify Chrome variant (default: Chrome, also: Canary) |

4. **Post-Installation Steps**:
   - Connect your VPN to **United States**.
   - Open `chrome://flags` and enable all flags related to **Glic** (e.g., Glic, Glic Actor, Glic Pre-Warming).
   - Restart Chrome.
   - This script does not modify the system time zone or Emoji/Canvas rendering; browser fingerprint checks may still infer region from those system-level signals.

### ⚠️ Requirements

- Google Chrome v144 or higher.
- macOS (This script is currently optimized for macOS).
- A Google Account with Gemini Pro (recommended for full access).

### 📄 Disclaimer

This tool modifies your Chrome configuration files. While it creates a backup, use it at your own risk. This is an unofficial patch and not affiliated with Google.
