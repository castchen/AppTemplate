# AppTemplate

可复用的 iOS CI/CD 模板。日常改 Swift 源码，GitHub Actions 在 macOS runner 上用 XcodeGen 生成工程并编译；要出包时再手动跑 Fastlane Match 签名并上传 TestFlight。

本仓库不提交 `.xcodeproj`（CI 每次生成），也不假设你手头有 Mac。占位符只有这三个：`AppTemplate`、`com.example.apptemplate`、`YOUR_TEAM_ID`。

## 目录

| 路径 | 作用 |
|------|------|
| `project.yml` | XcodeGen 规格，工程的唯一来源 |
| `Sources/` | SwiftUI 占位 App：Hello 页和 Settings 页 |
| `Resources/` | Info.plist、图标、隐私清单 |
| `fastlane/` | `Fastfile`、`Appfile`、`Matchfile` |
| `Gemfile`、`.ruby-version` | Fastlane 的 Ruby 依赖（3.3.6）。CI 按 Gemfile 约束安装，不提交 `Gemfile.lock` |
| `.github/workflows/pr.yml` | PR：生成工程 + 模拟器编译，不签名 |
| `.github/workflows/beta.yml` | 手动：Match → gym → TestFlight |
| `scripts/rename-template.sh` | 一次性替换占位符 |

## 替换 Bundle ID 和 Team ID

复制本模板到新仓库后，在仓库根目录执行：

```bash
scripts/rename-template.sh MyApp com.example.myapp ABCDE12345
```

三个参数依次是：工程名（字母开头的标识符）、Bundle ID、10 位 Team ID。Team ID 还没确定时，第三个参数填 `YOUR_TEAM_ID`。

脚本会改文本里的占位符，并把 `Sources/AppTemplateApp.swift` 重命名。它不会改 Match 证书仓地址。改完看一遍 diff 再提交。

不想用脚本时，按下面清单手改：

| 查找 | 换成 | 主要位置 |
|------|------|----------|
| `AppTemplate` | 新工程名 | `project.yml`、`Sources/`、`fastlane/Fastfile`、`.github/workflows/pr.yml` |
| `com.example.apptemplate` | 新 Bundle ID | `project.yml`、`fastlane/Appfile`、`fastlane/Matchfile`、`fastlane/Fastfile`、`Sources/SettingsView.swift` |
| `YOUR_TEAM_ID` | Apple Team ID | `project.yml` 的 Release 配置、`fastlane/Appfile`、`fastlane/Matchfile` |
| `https://github.com/YOUR_ORG/apptemplate-match.git` | 证书私有仓 URL | `fastlane/Matchfile`（也可用 Secret `MATCH_GIT_URL` 覆盖，不必改文件） |

Team ID 在 [Apple Developer 会员页](https://developer.apple.com/account) 的 Membership 里，是 10 位字母数字。Bundle ID 要先在 Developer 后台登记，并和 Match 里的描述文件一致。上 TestFlight 之前可以继续用 `com.example.apptemplate`，正式上架前再换。

Release 签名读的是 GitHub Secret `APPLE_TEAM_ID`，会覆盖工程里的 `YOUR_TEAM_ID`。Secret 没配之前，不要跑 Beta workflow。

## GitHub Secrets

只在仓库 Settings → Secrets and variables → Actions 里配置。不要把值写进文件，不要提交 `.p8`、`.p12`、`.cer`、描述文件。

| Secret | 内容 |
|--------|------|
| `APPLE_TEAM_ID` | 10 位 Team ID |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key 的 Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | API Key 的 Issuer ID |
| `APP_STORE_CONNECT_API_KEY_KEY` | `.p8` 全文（含 `BEGIN PRIVATE KEY` / `END PRIVATE KEY` 行） |
| `MATCH_PASSWORD` | 加密 Match 仓库的口令 |
| `MATCH_GIT_URL` | 证书私有仓的 HTTPS 地址 |
| `MATCH_GIT_BASIC_AUTHORIZATION` | 访问该私有仓的 Basic 认证，见下一节 |

API Key 在 App Store Connect → 用户和访问 → 集成 → App Store Connect API 创建。模板按「原文 .p8」读取，不是 Base64。权限用 App Manager 即可，用完可以吊销。

PR workflow 不读任何 Secret。

## 准备 Match 私有仓

证书和描述文件只放在单独的私有 Git 仓库里。应用仓库保持没有签名材料。

1. 新建一个空的私有仓库，例如 `apptemplate-match`。不要往里面手工提交 `.p12`。
2. 准备 Match 加密口令，存成 Secret `MATCH_PASSWORD`。丢了口令就解不开已有证书。
3. 给这个私有仓发一个只含 `repo` 权限的 Personal Access Token（或 fine-grained token，内容权限为证书仓的读写）。
4. 生成 Basic 认证并写入 `MATCH_GIT_BASIC_AUTHORIZATION`（整行是 Base64，不要换行）：

   ```bash
   printf '%s' 'YOUR_GITHUB_USERNAME:YOUR_PAT' | base64
   ```

5. 把证书仓 HTTPS 地址写入 `MATCH_GIT_URL`。`Matchfile` 里的 `https://github.com/YOUR_ORG/apptemplate-match.git` 只是占位，Secret 会覆盖它。
6. 在 App Store Connect 为 Bundle ID 建好 App 记录（TestFlight 上传需要它）。
7. 冷启动只做一次：Actions → Beta → Run workflow，把 command 选成 `certificates`。这一步只跑可写 Match：创建或复用 Distribution 证书，并为 `com.example.apptemplate` 生成描述文件，写进证书仓，不归档、不上传。已有 Distribution 证书时 Match 会尽量复用。
8. 之后上传选默认的 `beta`。它只读拉取证书，再 `gym` 上传 TestFlight，不改证书仓。

## PR 和 TestFlight 怎么触发

| Workflow | 文件 | 何时跑 | 做什么 |
|----------|------|--------|--------|
| PR | `.github/workflows/pr.yml` | 每个 pull request，也可手动 | `xcodegen generate`，再用 `generic/platform=iOS Simulator` 做 Debug 编译。关闭签名，不需要 Apple 账号 |
| Beta | `.github/workflows/beta.yml` | 仅 `workflow_dispatch`（Actions 页手动） | 默认 `beta`：只读 Match → `gym` → TestFlight，构建号用 `GITHUB_RUN_NUMBER`，上传成功即结束。`certificates` 只做一次可写同步 |

PR 不负责出包。TestFlight 不跟每次 push 走，避免公开仓阶段空跑，也避免以后改成私有仓时每次提交都消耗 macOS 分钟。

Runner 固定为 `macos-26`，使用该镜像默认的 Xcode 26，满足 App Store 对 iOS 26 SDK 的要求。

## 先公开，再改私有

当前阶段保持应用仓库公开：GitHub 托管的 macOS runner 对公开仓库不扣私有仓库的免费分钟额度，用来把「生成工程 → 模拟器编译」跑通。

公开期间不要提交业务代码、密钥和证书。Match 证书仓从第一天起就是私有的。

流水线跑通、要写正式产品时，再把应用仓库改成私有。私有仓库的 macOS 分钟大约按 10 倍计费，所以 TestFlight 继续只用手动触发，不要改成每次 push 都上传。

## 不会进 Git 的东西

`.gitignore` 排除了生成的 `*.xcodeproj`、`build/`、`DerivedData/`、`.env`、`*.p8`、`*.p12`、`*.cer`、`*.mobileprovision`。签名只存在于 GitHub Secrets 和 Match 私有仓。
