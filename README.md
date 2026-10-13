# 单音 · Godot 安卓 App

Godot 4.7.2 / GDScript 原生项目。入口是 `main.tscn`，界面和逻辑在 `main.gd`。

## 功能

- 完全离线的钢琴单音听辨，36 个采样，范围 C3–B5。
- 入门、进阶、自然音、全部半音和自定义音名。
- 无限练习或固定题数、随机八度或固定音区、重听、自动下一题、音量设置。
- 首次作答统计；重试不重复计数，跳过计为错误。
- 本机设置和最近 100 次练习记录，应用退到后台时停止播放。
- 支持安卓返回键；无需账号、广告或网络、录音、存储权限。

## 安装

将随附的 `SingleNote-1.0.apk` 传到安卓手机，在手机中打开并按系统提示安装。最低 Android 7.0（API 24），支持 ARM64 和 ARMv7。

APK 是签名后的个人安装版本，不是 Google Play 上架包。实际手机上的声音、手势和设备兼容性仍需真机确认。

## 打开项目和测试

在 Godot 项目管理器中导入 `project.godot`，然后运行主场景。

```powershell
& 'E:/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script tests/smoke.gd
```

已检查 36 个音频可解码，以及首次正确、错题重试、跳过、有限题数、随机音区、无限练习、自动进入下一题和结束后取消计时器。

安卓导出预设为 `Android`。导出需要 OpenJDK 17、Android SDK 和匹配的 Godot 导出模板。这个电脑的 Java 和 SDK 配置已设为本任务 `work/android-tools` 中的路径。

发布签名密钥和密码保存在相邻的 `SingleNote-signing` 文件夹中。它们不包含在项目源码压缩包或网页下载中；后续更新同一 App 时请保留该密钥。

## 资源

钢琴采样来自：https://tonedear.com/ear-training/absolute-perfect-pitch-test ，供本人的练习使用。

字体：Noto Sans SC，按本界面的字符集做了子集处理，静态字重 450 和 650。SIL OFL 1.1 许可证见 `assets/OFL-NotoSansSC.txt`。后续添加新的中文文本时，应重新生成对应字体子集或替换完整字体。

Godot Engine 使用 MIT 许可证，见 `assets/GODOT-LICENSE.txt`；相关第三方组件版权见 `assets/GODOT-COPYRIGHT.txt`。
