# DSH手机版 · O泡果奶（安卓）

一个**整蛊**小应用：循环播放一段广告曲、锁死媒体音量、用全屏透明窗口占住触摸，
屏幕上看不出任何东西，所以"关不掉"。

> ⚠️ 只适合**知情的朋友之间**开玩笑。别装到不知情的人手机上，别用于骚扰、报复、公共场合。
> 应用里留了明确的退出方式（见下），也随时可以从系统设置卸载。

- 包名 `com.edu.math`　版本 1.1（versionCode 2）
- minSdk 26（Android 8.0+）/ targetSdk 34
- 纯 Java，无 AndroidX、无第三方依赖，APK 约 2.5 MB（其中 2.5 MB 是音频）

## 功能

| 功能 | 实现 |
| --- | --- |
| 循环播放 | `MediaPlayer` + `res/raw` 内置音频，不受外部文件路径影响 |
| 锁死音量 | 每 80 ms 检查 `STREAM_MUSIC`，低于最大值立刻顶回去；点按、长按都无效 |
| 全屏透明 | `TYPE_APPLICATION_OVERLAY` 窗口，`MATCH_PARENT` + 透明背景，吃掉所有触摸 |
| 退出暗号 | **两指同时连点 5 次**（5 秒内），音量还原到 30% 并结束 |
| 嘲讽 | 单指乱点 9 次 / 音量被按低 6 次 → 屏幕弹字 + 震动 + TTS 念出来；两套语录，`{n}` 显示第几次 |

## 安装

1. 下载 [release/DSH手机版.apk](release/DSH手机版.apk)
2. 安装（需允许"安装未知来源应用"）
3. 首次启动会跳「显示在其他应用上层」授权页 —— 这是安卓硬性要求，随便哪个悬浮窗应用都要
4. 授权后返回，再点一次图标即可

也可以用 adb 预先授权，手机端就完全不弹窗：

```bash
adb install -r "DSH手机版.apk"
adb shell appops set com.edu.math SYSTEM_ALERT_WINDOW allow
```

## 退出方式（重要）

- **两指同时连点 5 次** —— 两根手指要同时在屏幕上，先松一根再按另一根不算
- 通知栏里的「停止」
- 直接卸载，或者重启手机

## 构建

不需要 Gradle，也不需要 Android Studio。装好 JDK 17+ 和 Android SDK（`build-tools` + `platforms`）即可：

```powershell
.\build.ps1                                        # 默认找 F:\Android\Sdk
.\build.ps1 -Sdk "C:\Android\Sdk" -Jdk "C:\Program Files\Java\jdk-21"
```

脚本直接调 `aapt2 → javac → d8 → zipalign → apksigner`，十几秒出包。

两个坑（脚本里已处理）：

1. `aapt2` 不认带中文的绝对路径 → 全程用相对路径执行
2. `apksigner` 处理中文文件名会报 `Bad pathname` → 先签成 `signed.apk` 再改名

另外本机 d8 8.2 在降级**匿名内部类**时会抛 NPE，所以源码里没有匿名内部类，全部用命名嵌套类。

## 目录

```
AndroidManifest.xml
build.ps1                    一键构建
java/com/edu/math/
    MainActivity.java        入口：查悬浮窗权限 → 起服务 → 自己退出
    PrankService.java        全部逻辑（播放/锁音量/占屏/暗号/嘲讽）
    Taunts.java              嘲讽语录
res/
    raw/o_paoguonai.wav      音频
    mipmap-*/ic_launcher.png
    values/strings.xml
release/DSH手机版.apk         已签名的安装包
```

## 更新记录

- **v1.1**：修复 TTS 不出声（补 `setLanguage`、固定 `AudioAttributes`、失败时不再白停音乐）；新增可选的"启动后隐藏图标"开关
- **v1.0**：首个版本

## 致谢

本项目的安卓移植**由 DeepSeek Harness（DSH）辅助完成**，包括：

- 原生工程搭建（`AndroidManifest.xml`、资源、图标生成）
- 全部 Java 代码、UI 与触摸逻辑、音量守护、TTS/震动/语录系统
- 免 Gradle 的构建脚本，以及上面那两个中文路径坑、d8 匿名类坑的排查
- 打包、签名、清单与产物校验

思路起点是一段 Windows 上的 Python 整蛊脚本（`pygame` 播放 + `ctypes` 调系统音量 + `pynput` 监听），
移植时因为安卓侧的权限与路径限制踩了很多坑，最后改为原生实现。

## License

[MIT](LICENSE)