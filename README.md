# Next DDL

<img src="asset/launcher_icon.png" alt="Next DDL 应用图标" width="128" height="128" />

> 当前版本：1.2.26
> Windows + Android 的本地优先截止时间管理应用

Next DDL 用任务、里程碑和最终截止时间管理复杂的 deadline。首页直接回答两个问题：**下一个节点是什么、还剩多久**，以及**最终截止是什么、还剩多久**。

## 功能概览

### 任务管理

- 支持多个任务、备注、标签、最终截止时间和任意数量的中间节点。
- 中间节点名称可以留空；节点时间必须早于最终截止时间。
- 支持自动生成 25% / 50% / 75% 三个阶段节点，生成后仍可手动修改或删除。
- 首页分为“进行中”“已过期”“已归档”三个 Tab，并按当前关键截止点排序。
- 支持完成、恢复、删除、延期 1 小时、延期 1 天和自定义延期。
- 延期时可以同步平移未来未完成的中间节点，并支持撤销操作。

### 搜索、标签和计划

- 支持按标题和备注搜索。
- 支持按标签、未分类任务筛选，标签可以在输入时按回车快速创建。
- 支持标签重命名、删除和单个标签编辑。
- 支持保存任务模板。
- 支持每日、每周指定星期、每月指定日期的重复任务系列。
- 支持暂停、恢复、终止、跳过单次实例和预览未来生成结果。

### 通知和闹钟

- 每个任务可以配置多个提醒提前量：到点、10 分钟、30 分钟、1 小时、1 天或自定义时长。
- Android 常驻消息栏显示最紧急任务的当前关键节点和紧凑剩余时间，可选择按天或按小时显示。
- Android 闹钟支持全局播放列表和任务级播放列表覆盖。
- 闹钟会随机选择音频，并在音频较长时随机选择起播位置。
- 单次响铃最长 5 分钟，Android 通知栏和 Windows 托盘菜单都可以停止当前响铃。
- 设置页提供通知、精确闹钟、下一次提醒、登记数量和测试响铃诊断。

### 主题和背景

- 支持主色、控件圆角、纯色背景、渐变背景和图片背景。
- 背景编辑器支持完整显示原图、缩放、拖动、旋转、遮罩和模糊调整。
- 保存最近 5 张背景及其编辑参数，支持点击恢复；Windows 支持右键菜单，移动端支持长按删除。
- 背景不会因为进入其他页面、调整圆角或切换主题而丢失。
- 根据背景实际亮度和对比度自动调整透明区域的文字与图标颜色，不添加文字描边或光晕。
- Windows 可以选择系统已安装字体，并将字体应用到整个应用界面。
- 可选液态玻璃输入框，默认关闭；支持六项参数调节、实时预览、保存和恢复默认值。

### 智能能力

- 本地截止时间预测根据历史任务、标题和标签相似度给出建议。
- 历史样本不足时使用稳定的三天默认截止时间。
- 可选大模型增强，支持 Chat Completions、Responses 和 Anthropic Messages。
- 用户可以配置 Base URL、模型、API Key 和自定义提示词。
- 大模型可以辅助润色标题、备注、标签，并推荐中间节点和分步骤结果。
- API Key 使用系统安全存储，不会写入任务 JSON 或备份文件。

### Android 桌面小组件

- 以任务卡片展示标题、进行状态、进度、最终截止时间和 X天X小时 剩余时间。
- 支持响应式布局，默认参考尺寸为 3 列 × 2 行，调整大小后自动改变信息密度。
- 点击右上角按钮可直接在桌面打开任务选择列表，无需进入应用。
- 在首页或详情页点击星标，可以指定小组件默认展示任务；同一时间只保留一个星标任务。
- 桌面手动切换任务后会保持选择，直到再次切换或当前任务失效。
- 小组件支持点击卡片进入任务详情。

### 数据、语言和更新

- 所有任务和全局设置默认保存在本机。
- 支持完整 JSON 导入和导出；导入会替换当前设备上的全部数据。
- 导入前会自动创建本地备份，并保留最近 5 份备份用于恢复。
- 支持简体中文、English、日本語和跟随系统语言。
- 支持选择 IANA 时区，持久化时间统一保存为 UTC。
- 应用可以检查 GitHub Release，并缓存当前版本的中英文更新说明。
- Android 可以下载 ARM64 APK、显示进度、复用完整的本地安装包并交给系统安装器。
- Windows 更新会打开 GitHub Release 页面，不执行 ZIP 自动安装。

## 平台差异和限制

| 能力 | Android | Windows |
| --- | --- | --- |
| 任务、节点、搜索、标签、模板、重复计划 | 支持 | 支持 |
| 主题、图片背景、字体、液态玻璃输入框 | 支持 | 支持 |
| 普通本地通知 | 支持 | 支持，由 Windows 原生托盘通知管理 |
| 常驻消息栏 | Android 通知栏 | 不显示，改为系统托盘截止摘要 |
| 后台闹钟 | 精确闹钟 + 前台播放服务 | 窗口隐藏到托盘后继续运行原生闹钟 |
| Android 桌面小组件 | 支持 | 不适用 |
| 应用内更新 | 下载并拉起系统 APK 安装器 | 打开 GitHub Release 页面 |

Android 的通知、精确闹钟、后台运行和安装未知来源权限可能受到 MIUI、HyperOS 或其他厂商系统限制。应用无法静默安装 APK，最终安装必须由系统确认。Windows ZIP 版本不使用 MSIX，因此已显示的系统通知可能无法被所有系统版本可靠撤销。

## 快速使用

1. 在首页点击新增按钮，填写标题、备注和最终截止时间。
2. 按需添加中间节点，或使用自动生成节点快速建立阶段时间线。
3. 在提醒规则中选择到点或提前量；需要响铃时，在任务编辑页开启闹钟。
4. 进入设置管理任务与数据、主题、通知与闹钟、语言与时区、智能任务建议和关于应用。
5. 使用任务与数据导出 JSON 进行备份；导入 JSON 会替换当前全部任务与设置。
6. 点击任务卡片进入详情页，可以完成节点、完成任务、延期或编辑任务。
7. 在任务与数据中管理模板和重复任务系列。
8. 在 Android 桌面添加 Next DDL 小组件，通过星标或小组件右上角的选择按钮切换展示任务。
9. 在关于应用中检查更新；Android 下载完成后需要按系统提示确认安装。

图片背景在“设置 → 主题设置”中选择并保存。点击最近背景缩略图可以恢复图片和编辑参数；取消替换不会影响当前背景。将 JSON 导入其他设备后，如果原图片文件不存在，需要重新选择图片。

## 性能优化

- Windows 鼠标滚轮和触控板滚动会合并同一帧内的多个滚轮事件，避免重复创建动画。
- Windows 滚动液态玻璃输入框时只更新目标几何，不重复读取整张背景图。
- 首页秒级倒计时刷新下沉到单张任务卡片，避免每秒重建整个任务列表。
- 液态玻璃 shader 在启用后会于空闲期预热，降低首次打开输入页面的卡顿。
- Windows 页面切换使用即时透明过渡，背景层在路由切换时保持稳定。

## 本地开发

项目使用 FVM 固定 Flutter 3.38.3 和 Dart 3.10.1。

~~~powershell
fvm flutter pub get
fvm flutter analyze
fvm flutter test
~~~

运行：

~~~powershell
fvm flutter run -d windows
fvm flutter devices
fvm flutter run -d <android-device-id>
~~~

构建：

~~~powershell
# Windows release
fvm flutter build windows --release

# 仅构建 Android ARM64 / V8A APK
fvm flutter build apk --release --target-platform android-arm64
~~~

产物位置：

- Windows：build/windows/x64/runner/Release/
- Android：build/app/outputs/flutter-apk/app-release.apk

## Android 签名和 GitHub Actions

正式 Android 构建使用本地 keystore 签名。keystore 和 android/key.properties 已被排除在 Git 之外，不应提交到仓库。推荐的本地 keystore 路径为：

~~~text
%USERPROFILE%/.next_ddl/signing/next_ddl-upload.jks
~~~

GitHub Actions 使用同一份密钥的 Repository Secrets：

- ANDROID_KEYSTORE_BASE64
- ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_ALIAS
- ANDROID_KEY_PASSWORD

推送任意语义化 tag 会触发 .github/workflows/release.yml：

1. 执行 flutter analyze 和 flutter test。
2. 构建 Windows release 并打包 windows-release.zip。
3. 构建 Android ARM64 release APK。
4. 校验 APK ABI 和 SHA-256。
5. 创建 GitHub Release 并上传 Windows ZIP、Android APK 和校验文件。

发版前请同步更新 pubspec.yaml 与 asset/release_notes.json 的版本号和中英文说明：

~~~powershell
git push origin main
git tag vX.Y.Z
git push origin vX.Y.Z
~~~

## 数据与隐私

- 任务、主题和应用设置默认只保存在当前设备。
- JSON 备份可能包含标题、备注、标签、时间、通知、主题和设置，请自行保管。
- 背景图片会复制到应用私有目录；闹钟音频保存设备文件引用。
- 大模型增强默认关闭。启用后，当前编辑内容和本地预测摘要可能发送到用户配置的服务。
- API Key 使用系统安全存储，不会进入任务 JSON、备份或日志。
- 更新检查只访问本项目的 GitHub Release API，Android 安装包下载到应用更新缓存目录。

## 项目结构

~~~text
lib/app                  应用壳、主题、背景、液态玻璃和反馈
lib/features/tasks       任务、节点、搜索、标签和计划
lib/features/settings    设置、主题、闹钟、时区、预测和更新入口
lib/services              本地存储、通知、闹钟、更新和平台服务
lib/models                手写不可变模型及 JSON 序列化
android                   Android 原生闹钟、小组件和安装能力
windows                   Windows 托盘、通知、字体和闹钟能力
~~~

## 后续计划

- 继续优化 Windows 和 Android 的背景渲染、液态玻璃和低端设备性能。
- 改进 MIUI/HyperOS 等厂商系统上的后台闹钟可靠性提示和权限引导。
- 完善批量任务操作、重复计划管理和提醒诊断。
- 评估可选的跨设备同步方案，同时保持本地优先和用户可控的数据迁移能力。
- 继续改进更新下载恢复、发布说明和 Windows 自更新体验。

## 许可证

本项目采用 [MIT License](LICENSE)。

液态玻璃能力基于 [liquid-glass-flutter](https://github.com/xiaomanjun233/liquid-glass-flutter)，固定源码位于 third_party/kyant_glass，采用 Apache-2.0 许可证并保留原作者声明。
