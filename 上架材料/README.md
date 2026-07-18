# TaoMind 上架材料总览

此目录包含将 TaoMind 提交至 App Store 所需的全部材料。

## 📄 文件清单

| 文件 | 内容 |
|------|------|
| `privacy_policy.md` | 隐私政策（可托管至 GitHub Pages） |
| `terms_of_service.md` | 服务条款（托管在隐私政策同域名下） |
| `ASO_元数据.md` | App Store 标题/描述/关键词/截图方案 |
| `上架前检查清单.md` | 上架前需修复的问题 + 完整步骤 |

## 🚀 最快上架路径

### 从 Windows 就能做的（不需要 Mac）：

1. **托管隐私政策** → 用 GitHub Pages 免费托管 `privacy_policy.md`
2. **更新代码中的链接** → 把 `taomind.app` 改成你的 GitHub Pages 地址
3. **修复 Info.plist ATS** → 限制 HTTP 只对你的 API 域名开放
4. **注释未实现功能** → 收藏按钮 / Save Notes / Restore
5. **提交 GitHub → CI 自动构建上传**

### 需要 Mac 做的：

1. **添加 AppIcon**（1024×1024 PNG）
2. **截取 App Store 截图**（模拟器 + Xcode 截图工具）
3. 提交审核

> 所有文件放在 `TaoMind-iOS/上架材料/` 目录下
