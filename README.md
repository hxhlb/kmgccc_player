<p align="center">
  <img src="screenshots/Icon-iOS-Default-1024x1024@1x.png" width="192" alt="kmgccc_player Icon" />
</p>

<h1 align="center">kmgccc_player</h1>

<p align="center">
  面向 <strong>macOS 26</strong> 的本地音乐播放器<br>
  专注于清晰的界面设计、沉浸式播放体验以及对本地音乐与歌词的良好支持
</p>


> [!WARNING]
> kmgccc_player 为个人项目，可能存在 Bug、未完成特性或行为变动。  
> 不建议在重要环境中作为唯一播放器使用，欢迎通过 Issue 反馈问题。
> 代码使用 AI 生成，可能存在问题。


## 特性
- ### **Liquid Glass 风格**  
  应用整体使用 Liquid Glass 设计语言，界面通透、克制，贴近原生系统体验，并在深色与浅色模式下保持一致的视觉表现。
  
  <img src="screenshots/main.png" width="520" alt="Main UI" /> <img src="screenshots/glass.png" width="520" alt="Mini Player" />

- ### **磁带式播放界面 + 实时频谱可视化**  
  加入独立的"正在播放"视图，采用磁带外观设计。  
  磁带轮会随音乐播放实时转动，并基于音频频谱算法将音乐能量映射到磁带与指示元素上，在现代界面中保留实体播放设备的仪式感。
  
  <img src="screenshots/tape.png" width="640" alt="Cassette Player" />

- ### **全屏播放体验**  
  全新的全屏播放界面，支持独立窗口管理、多种皮肤切换、频谱可视化与歌词视图的顺畅协作，带来更沉浸的聆听方式。

  <img src="screenshots/fs1.png" width="360" alt="Fullscreen 1" /> <img src="screenshots/fs2.png" width="360" alt="Fullscreen 2" />
  
  <img src="screenshots/fs3.png" width="360" alt="Fullscreen 3" /> <img src="screenshots/fs4.png" width="360" alt="Fullscreen 4" />

- ### **艺术背景 (Beta)**  
  将当前播放曲目的封面色彩进行风格化解析与图案拼贴展示，作为"正在播放"视图的动态背景。通过提取封面色彩特征，提供更具沉浸感的视觉反馈。
  
  <img src="screenshots/tape2.png" width="640" alt="Art Background" />

- ### **AMLL 歌词组件集成**  
  集成 **AppleMusic-Like Lyrics (AMLL)** 歌词渲染组件，支持高质量逐行歌词显示与平滑滚动效果，同时加入动态封面取色，加强歌词表现力。
  
  <img src="screenshots/color.png" width="640" alt="Color" />

- ### **便捷的本地音乐资料库**  
  集成 **LDDC (Lyrics Data Digging Core)** 用于歌词搜索与匹配。支持直接导入网易云音乐 NCM 加密格式，歌曲信息与封面自动保留。内置封面获取功能，可从多个来源自动补全缺失的专辑封面。
  
  <img src="screenshots/lddc.png" width="380" alt="LDDC" /> <img src="screenshots/ncm.png" width="420" alt="NCM Import" />
  
  <img src="screenshots/batch_edit.png" width="800" alt="Batch Edit" />


## 构建与运行 (Build)

由于使用了 macOS 26 的新系统特性，构建环境要求如下：

- **系统要求**：macOS 26.0 或更新版本  
- **开发工具**：建议使用最新版本的 Xcode

**构建步骤：**

1. 克隆本仓库代码  
2. 使用 Xcode 打开 `kmgccc_player.xcodeproj`  
3. 打包外部工具（如需完整功能）：
   - **LDDC Server**：使用脚本打包，输出到 `Tools/lddc-server`
   - **ncmdump**：从 [taurusxin/ncmdump](https://github.com/taurusxin/ncmdump) 下载 Universal Binary，放入 `Tools/ncmdump/`
   - **sacad**：从 [desbma/sacad](https://github.com/desbma/sacad) 下载或通过 `cargo install sacad` 安装
4. 选择 `kmgccc_player` Scheme 并运行

## 注意事项

- app的数据文件存放在`/Users/username/Music/kmgccc_player Library`中, 删除、替换 app 不会删除数据文件

- 可以使用 `AMLL TTML Tool` 手动编辑 ttml 格式的歌词，操作更精准且可以启用 amll 的高级功能如背景歌词、对唱歌词。
项目地址：https://github.com/amll-dev/amll-ttml-tool 
在线使用：https://amll-ttml-tool.stevexmh.net/ 
也欢迎给 AMLL DB 贡献歌词。


## 致谢

本项目在开发过程中使用并修改了以下开源项目：

- **applemusic-like-lyrics (AMLL)**  
  提供歌词渲染能力，实现类 Apple Music 的歌词显示效果。  
  https://github.com/amll-dev/applemusic-like-lyrics  
  AMLL DB 歌词库：https://github.com/amll-dev/amll-ttml-db

- **LDDC (Lyrics Data Digging Core)**  
  提供歌词获取与匹配能力。  
  https://github.com/chenmozhijin/LDDC

- **apple-audio-visualization**  
  提供音频频谱分析与可视化算法，本项目在播放界面与磁带视图中使用并修改了其部分实现。  
  https://github.com/taterboom/apple-audio-visualization

- **ncmdump**  
  提供 NCM 格式解密能力，支持导入网易云音乐加密文件。  
  https://github.com/taurusxin/ncmdump

- **sacad**  
  提供专辑封面搜索与下载能力。  
  https://github.com/desbma/sacad

- **WhatsNewKit**  
  提供应用更新说明展示组件。  
  https://github.com/SvenTiigi/WhatsNewKit


## 美术素材版权声明

除代码及另有说明的第三方内容外，本项目相关的美术素材，包括但不限于界面插画、UI 装饰、皮肤、贴图、角色设计、图形元素、图像资源及其他视觉素材，均为作者原创作品，其著作权及其他相关权利均由作者保留。

前述美术素材**不构成本项目开源代码的一部分**，**亦不适用本仓库所采用的 AGPL-3.0 或其他任何开源许可证**。任何个人或组织，未经作者事先书面授权，不得以**任何形式**对该等素材进行复制、转载、分发、修改、改编、商用、二次创作、数据集收录、抓取、提取，或用于机器学习、生成式 AI 训练、微调、推理输入集构建及其他类似用途。

本仓库当前不包含上述原创美术素材。任何需要相关素材的使用者，均应自行制作或另行取得作者的明确书面许可。

保留一切权利。
Copyright © kmg. All rights reserved.

## 许可证 (License)

本项目为开源软件，**代码** 基于 **GNU Affero General Public License v3.0 (AGPL-3.0)** 发布。  
项目中所使用的第三方组件遵循其各自的开源许可证，详见应用内 About 页面及 `Licenses` 目录。
