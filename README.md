# BilibiliSpeed

BilibiliSpeed 是基于 [Bilibili NEXT](https://github.com/wzk112/Bilibili-NEXT)（MIT）的非官方哔哩哔哩客户端，面向 macOS 26+ 与 iOS / iPadOS 26+。本项目面向个人学习与研究，与哔哩哔哩官方及 Bilibili NEXT 作者无关联。

与上游的主要区别：播放已下载的缓存视频时可选 22 档倍速：

```
0.25, 0.5, 0.75, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 32, 64, 128
```

- Mac：播放页倍速菜单。iPhone／iPad：点视频画面左上角的倍速（如“1×”），或播放选项 → 播放速度。
- 在线播放保留上游的 0.5×–2× 六档；在线与缓存的倍速分别记住。
- 长按临时加速仍为在线 2×、本地 3×，松开后回到所选倍速。
- 本机 AVPlayer 实测 22 档均被接受，实际推进约为设定值的 92%–94%（128× 约 117×）；高倍速下音画与弹幕表现、真机效果尚未验收。需求、设计与验证记录见 [BILIBILISPEED_SPEC.md](BILIBILISPEED_SPEC.md)。

BilibiliSpeed 使用独立的 bundle ID（Mac `com.iosdevlog.BilibiliSpeed`，iOS `com.iosdevlog.BilibiliSpeed.iOS`）、钥匙串服务和缓存目录，可与 Bilibili NEXT 同时安装；登录、设置和下载不互通，首次使用需要重新扫码登录。

其余功能沿用上游 Bilibili NEXT 1.1.4 / iOS 0.1.4，功能说明见上游 README。仓库内 `QA.md`、`IOS_STATUS.md`、`RELEASE_NOTES.md` 等为上游记录，未针对本项目重新验收。

## 构建

需要 macOS 26+、Xcode 26+（iOS 需 Xcode 27+）与 Swift 6.2+。

```sh
swift test
swift test --package-path Vendor/BiliKitCore
Scripts/build-app.sh            # 默认输出 ../BilibiliSpeed.app，可用 APP_DIR 指定
Scripts/build-ios.sh            # 未签名的 iOS 模拟器构建
IOS_PLATFORM=device DEVELOPMENT_TEAM=YOUR_TEAM IOS_DEVICE_ID=YOUR_UDID Scripts/build-ios.sh
```

iOS 工程为 `Apps/iOS/BilibiliSpeed.xcodeproj`（Scheme `BilibiliSpeed`），由 `python3 Scripts/generate-ios-project.py` 生成，请勿在 Xcode 中直接修改工程设置。开发约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可与致谢

源码采用 [MIT License](LICENSE)，保留上游 Bilibili NEXT 的版权声明。内含 BiliKit-Mac 的 MIT 播放组件，第三方来源与改动见 [THIRD_PARTY.md](THIRD_PARTY.md)。媒体和商标归各自权利人所有。
