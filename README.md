# 🔒 Secure Terminal Authentication System 🔒

*A robust Linux authentication system that combines OTP verification with process restrictions for maximum security*

## 🌟 Features

### 🔐 Two-Factor Authentication
- **OTP Verification** using Google Authenticator secrets (`pyotp` integration)
- 🚨 Immediate logout on failed attempts
- ⏳ 10-second timeout for authentication

### 🛡️ Process Control
- 🔥 Background process killer prevents new applications during auth
- ⚡ Whitelists system processes to avoid crashes
- 🛑 Graceful handling of `Ctrl+C`

### 🎯 User Experience
- 🖥️ Zenity GUI for OTP input
- ✅ Clear success/failure notifications
- ⚠️ Automatic logout protection

## 🛠️ Technical Components

```bash
├── auth_functions.sh         # Core authentication logic
├── process_monitor.sh        # Background process killer
├── timeout_watcher.sh        # 10-second logout timer
└── .google_authenticator     # Secret key file (secured)
```
