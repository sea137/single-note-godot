# 单音 · Godot 安卓 App

Godot 4.7.2 / GDScript 原生项目。入口是 `main.tscn`，界面和逻辑在 `main.gd`。

## 功能

### 1.2 新增

- 普通练习答错后显示正确选项的绿色 ✓ 与首答错误的红色 ✕；页面重建后保留标记，不会重复计分。无参考测试仍在结束后揭晓。
- 多音对比支持手选 C3–B5 全部 36 个音、补全所选音之间的半音、本组音列与同音名三个八度，按音高排序播放。
- 原始采样逐音测量峰值，以 2 dB 余量校准播放增益；0% 音量保持静音。
- 原始触摸事件超过竖向拖动阈值时接管滚动并取消按钮点击；Android 返回键可从对比选择返回本题。
- 最近 20 次有效练习曲线，可按音组与音区筛选，分别比较全部、未用试听和辅助成绩。缺失成绩不当作零分。
- 按准确度提供鼓励与练习建议，结果和历史可查看正确音 → 首答选择。旧记录没有的明细不会补造。

### 1.1 新增

- 按音高从低到高试听当前范围；C/D/E 跨 3 个八度时依次播放 C3/D3/E3、C4/D4/E4、C5/D5/E5。支持暂停、单独播放、重新开始。
- 默认每轮试听一次，可选择每题前试听或关闭；辅助练习与未用试听的成绩分开统计。
- 答后显示具体音名和低／中／高音区；可选音区挑战，答案揭晓前不泄露八度。
- 5 题无参考检查，结束后统一揭晓；具体错音对比，隔几道其他题后回访错音。
- 到期复习队列、每个具体音符的记忆记录、混淆音和复习时间。只有一个选项的练习不用于提升记忆阶段。
- 保留 1.0 的设置和历史，记忆记录从 1.1 开始积累。

复习间隔是产品初始规则：答错后 10 分钟、辅助答对约 1 小时；到期独立答对逐步间隔 1、3、7、14、30 天。提前重复答对不会提升阶段。这不是经过个人数据拟合的遗忘曲线，也不保证获得绝对音感。

以下为基础功能：

- 完全离线的钢琴单音听辨，36 个采样，范围 C3–B5。
- 入门、进阶、自然音、全部半音和自定义音名。
- 无限练习或固定题数、随机八度或固定音区、重听、自动下一题、音量设置。
- 首次作答统计；重试不重复计数，跳过计为错误。
- 本机设置和最近 100 次练习记录，应用退到后台时停止播放。
- 支持安卓返回键；无需账号、广告或网络、录音、存储权限。

## 安装

从[安装页面](https://single-note-practice.zippyhake16.chatgpt.site/android/)获取 `SingleNote-1.2.apk`，或将本地 APK 传到安卓手机，在手机中打开并按系统提示安装。最低 Android 7.0（API 24），支持 ARM64 和 ARMv7。安装页面仅限原网站账号访问。

同一签名、同一包名、版本代码升至 3，可覆盖 1.0／1.1 安装并保留原 App 数据。请勿先卸载旧版，否则 Android 会清除它的本地记录。

APK 是签名后的个人安装版本，不是 Google Play 上架包。实际手机上的声音、手势和设备兼容性仍需真机确认。

## 打开项目和测试

在 Godot 项目管理器中导入 `project.godot`，然后运行主场景。

```powershell
& 'E:/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script tests/smoke.gd
& 'E:/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script tests/learning_test.gd
& 'E:/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script tests/regression_v12.gd
```

已检查 36 个音频可解码，以及首次正确、错题重试、跳过、有限题数、随机音区、无限练习、自动进入下一题和结束后取消计时器。

学习检查覆盖试听顺序、暂停、辅助计分、盲测隐藏反馈、八度挑战、复习到期、提前复习、只有一个选项、记录保存和旧格式迁移。测试使用独立数据文件，不写入用户的练习记录。

安卓导出预设为 `Android`。导出需要 OpenJDK 17、Android SDK 和匹配的 Godot 导出模板。这个电脑的 Java 和 SDK 配置已设为本任务 `work/android-tools` 中的路径。

发布签名密钥和密码保存在相邻的 `SingleNote-signing` 文件夹中。它们不包含在项目源码压缩包或网页下载中；后续更新同一 App 时请保留该密钥。

## 资源

钢琴采样来自：https://tonedear.com/ear-training/absolute-perfect-pitch-test ，供本人的练习使用。

字体：Noto Sans SC，按本界面的字符集做了子集处理，静态字重 450 和 650。SIL OFL 1.1 许可证见 `assets/OFL-NotoSansSC.txt`。后续添加新的中文文本时，应重新生成对应字体子集或替换完整字体。

Godot Engine 使用 MIT 许可证，见 `assets/GODOT-LICENSE.txt`；相关第三方组件版权见 `assets/GODOT-COPYRIGHT.txt`。
