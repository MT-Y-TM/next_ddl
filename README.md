# Next DDL

一个面向 Windows 和 Android 的本地优先死线管理应用。它将每个任务拆分为最终截止时间与可选的中间节点，用秒级倒计时帮助你看清“下一步是什么”和“距离最终截止还有多久”。

## 已有功能

- 任务与节点：创建多个任务，记录备注、最终截止时间及任意数量的中间节点；节点名称可以留空。
- 倒计时视图：首页区分进行中与已过期任务，按当前关键时间点排序；详情页展示完整时间线和秒级倒计时。
- 节点辅助：可按剩余区间自动生成 25%、50%、75% 三个节点，之后仍可自由编辑、删除或调整时间。
- 任务提醒：每个任务可配置多个提醒提前量，包括到点、10 分钟、30 分钟、1 小时、1 天或自定义时长。
- 常驻消息栏：Android 可显示最接近的任务关键点和紧凑剩余时间，并可在设置中选择按天或按小时显示。
- Android 闹钟：可为任务提醒启用响铃，支持全局或任务级音频列表、随机铃声、随机起播点、通知栏停止和最长 5 分钟自动停止。
- 多语言与时区：支持简体中文、English、日本語及跟随系统；可选择 IANA 时区，时间统一以 UTC 保存并按选定时区展示。
- 主题定制：可调整主色、控件圆角和纯色/渐变/图片背景；图片背景支持缩放、位置、旋转、遮罩和模糊编辑。
- 数据安全：全部任务和全局设置保存于本机，支持完整 JSON 导入与导出。导入会替换本地现有数据。
- 应用更新：应用可检查 GitHub Release。Android 可下载 ARM64 APK、显示下载进度并复用已下载的安装包；Windows 可跳转至对应 Release 页面。

## 平台说明

| 能力 | Android | Windows |
| --- | --- | --- |
| 任务、节点、倒计时、导入导出、主题、三语 | 支持 | 支持 |
| 本地普通通知 | 支持 | 支持 |
| 常驻消息栏 | 支持 | 不显示 |
| 后台精确闹钟与响铃 | 支持，需系统授权 | 仅在应用进程运行时提供响铃能力 |
| 应用内更新 | 下载 APK 并交给系统安装器 | 跳转 GitHub Release 页面 |

Android 的精确闹钟、通知、后台运行和“允许此来源安装应用”等权限可能被系统厂商额外限制。尤其在 MIUI/HyperOS 等系统上，请在系统设置中允许通知、精确闹钟和必要的后台运行权限；应用无法静默安装更新，最终安装仍必须由系统确认。

## 使用方法

1. 在首页点击新增按钮，填写任务标题、最终截止时间和可选备注。
2. 按需添加中间节点；节点时间必须早于最终截止时间。也可以使用“自动生成节点”快速生成三个阶段节点。
3. 为任务添加提醒提前量。若希望提醒时播放铃声，在任务编辑页开启闹钟并选择任务专属播放列表，或在设置中配置全局播放列表。
4. 在设置页管理五类内容：任务与数据、主题设置、通知与闹钟、语言与时区、关于应用。
5. 如需迁移数据，先在“任务与数据”中导出 JSON；导入 JSON 时会替换当前设备上的全部任务与设置。

## 本地开发

项目使用 [FVM](https://fvm.app/) 固定 Flutter `3.38.3` / Dart `3.10.1`。请先准备 Flutter Windows 与 Android 的本地构建环境。

```powershell
fvm flutter pub get
fvm flutter analyze
fvm flutter test
```

运行应用：

```powershell
fvm flutter run -d windows
fvm flutter run -d android
```

构建发布包：

```powershell
fvm flutter build windows --release
fvm flutter build apk --release --target-platform android-arm64
```

Windows 产物位于 `build/windows/x64/runner/Release/`，Android ARM64 APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。

## Android 签名与发布

发布 APK 使用本地 keystore 签名。keystore 和 `android/key.properties` 不应提交到仓库。推荐将 keystore 放在 `%USERPROFILE%\\.next_ddl\\signing\\next_ddl-upload.jks`，并在本地 `android/key.properties` 中配置对应路径、别名和密码。

GitHub Actions 从以下 Repository Secrets 读取同一份签名材料：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

推送语义化版本标签会触发 CI：先执行依赖安装、静态检查和测试，再构建 Windows ZIP 与 Android ARM64 APK，并发布到 GitHub Release。例如：

```powershell
git push origin main
git tag v1.1.16
git push origin v1.1.16
```

## 数据与隐私

- 任务数据默认仅保存在当前设备的本地存储中。
- JSON 备份可能包含任务标题、备注、时间、通知、主题与设置，请自行保管。
- 背景图片会复制到应用私有目录；闹钟音频保存的是设备文件引用。将 JSON 导入另一台设备后，如资源不可访问，需要重新选择图片或音频。
- 更新检查只访问本项目的 GitHub Release API；更新 APK 仅在 Android 上下载到临时更新缓存。

## 后续计划

- 优化背景图片的编辑与渲染性能，并继续完善不同 Android 厂商系统下的后台体验。
- 增加更灵活的任务筛选、归档、搜索和批量管理能力。
- 扩展闹钟播放策略，例如更丰富的播放队列和可靠性状态提示。
- 改进更新体验，例如下载完整性校验、发布说明展示和更明确的失败恢复路径。
- 评估可选的跨设备同步方案，同时保持本地优先和用户可控的数据迁移能力。

## 许可证

当前项目未声明开源许可证。使用、分发或复用前，请先取得仓库所有者授权。
