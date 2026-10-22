#!/usr/bin/env python3
"""Generates Spolo's pages for tang-spark.no in English, Simplified and Traditional Chinese.

    website/generate.py            # writes website/dist/*.html

The pages use the site's own styles.css (the Plakat layout shared with Rydd, Kvikkshot and Glimt).
The version comes from project.yml. Set APP_STORE_URL once the app is live to show the
Mac App Store button; the download button appears when publish-website.sh copies a notarized disk image.
"""
import html
import os
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "website" / "dist"
VERSION = re.search(r'MARKETING_VERSION: "([^"]+)"', (ROOT / "project.yml").read_text()).group(1)
APP_STORE_URL = ""
# scripts/publish-website.sh sets this when it copies a notarized disk image to the site.
DOWNLOAD_URL = os.environ.get("SPOLO_DOWNLOAD_URL", "")
GITHUB = "https://github.com/tangfy97/Spolo"

LANGS = {
    "en": {"suffix": "", "html": "en", "other": [("zh-cn", "中文")]},
    "zh-cn": {"suffix": "-zh-cn", "html": "zh-Hans", "other": [("en", "EN"), ("zh-tw", "繁體")]},
    "zh-tw": {"suffix": "-zh-tw", "html": "zh-Hant", "other": [("en", "EN"), ("zh-cn", "简体")]},
}

COPY = {
    "en": {
        "title": "Spolo — Photos and videos, one video.",
        "description": "Spolo merges photos and videos into one video, right on your Mac. Put them in order, trim, pick a shape and export, with no upload, no watermark and no limits. Free, private and offline.",
        "label": "macOS 14+ · Free · Open source",
        "headline": "Photos and videos, one video.",
        "lead": "Drop in clips from your phone, camera or screen, in any mix of shapes and formats. Put them in order, trim the ends and export one MP4 or MOV, right on your Mac. Spole is Norwegian for a reel of film.",
        "facts": [("Platform", "macOS 14 or later"), ("Price", "Free, Apache 2.0"), ("Network", "None at all"), ("Languages", "EN, 简体, 繁體")],
        "shot_alt": "Spolo merging seven photos and videos, with one clip selected for trimming",
        "what": "What it does",
        "features": [
            ("Any mix", "Photos and videos in any shape and format. Upright phone videos, HDR and clips without sound all come out right."),
            ("In order", "Drag to reorder, or sort by date taken, file name or the order you added them."),
            ("Each clip", "Trim, change the speed with the pitch kept, mute and rotate. Set how long each photo stays."),
            ("One shape", "Auto, 16:9, 9:16, 1:1 or 4:5, with black bars or filled and cropped."),
            ("Fast and private", "No upload, no watermark, no limits. Matching clips are joined without re-encoding."),
        ],
        "get": "Get Spolo",
        "get_text_store": "Free on the Mac App Store, and as a signed, notarized download.",
        "get_text_download": "Free, as a signed and notarized download. Coming soon to the Mac App Store.",
        "get_text_soon": "Free and open source. Coming soon to the Mac App Store; until then, Spolo can be built from the source on GitHub.",
        "btn_store": "Mac App Store", "btn_download": "Download for Mac", "btn_source": "Source on GitHub", "btn_support": "Support & privacy",
        "nav_apps": "Apps", "nav_support": "Support",
        # support page
        "s_title": "Spolo support, privacy and terms",
        "s_hero": "Support",
        "s_headline": "Support, privacy and terms.",
        "s_lead": "Answers to common questions, the privacy policy and the terms. If something isn't covered here, write to us and we'll reply.",
        "s_facts": [("Version", VERSION), ("Data collected", "None"), ("Network", "None at all"), ("Contact", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "Getting started"), ("faq", "Questions"), ("privacy", "Privacy"), ("terms", "Terms"), ("release-notes", "Release notes"), ("contact", "Contact")],
        "start": [
            "Drag photos and videos onto the Spolo window, or choose File › Add… or Add from Photos….",
            "Drag the clips into order, or use Sort By in the toolbar. Click a clip to trim it, change its speed, mute or rotate it in the inspector.",
            "Pick a shape and Fit or Fill with the frame button in the toolbar (it reads Auto · Fit at first), then click Export.",
        ],
        "faq": [
            ("Which formats can Spolo open?", "Anything macOS can play or show: MOV, MP4 and M4V video in H.264, HEVC or ProRes, and JPEG, PNG, HEIC, TIFF, WebP, AVIF and RAW photos. macOS can't read MKV, WebM, AVI and a few other formats; Spolo shows them greyed out rather than leaving them out silently."),
            ("Why is the export sometimes instant?", "When every clip is a video with the same encoding, size and frame rate, none is sped up or turned, and the shape matches, Spolo joins them without re-encoding. The export sheet says Fast export when this applies, with the quality set to Original."),
            ("What do Original, High and Smaller File mean?", "Original keeps the full size, up to 4K. High is up to 1080p in H.264, which plays everywhere. Smaller File is up to 1080p in HEVC at a lower bit rate."),
            ("What happens to HDR video?", "Spolo exports in standard dynamic range, so HDR and SDR clips look the same side by side. macOS tone-maps the HDR clips."),
            ("Does Spolo copy my files?", "No. It remembers where your clips are, so they're there when you open Spolo again, but it doesn't copy them. Items added from Photos are the exception: they have no file of their own, so Spolo keeps a copy in its own folder until they're no longer among your clips."),
            ("How do I start again with an empty window?", "Choose File › Start Over (⌘N). Every change can be undone with the arrow beside the title, Start Over included."),
            ("Is there a limit or a watermark?", "No. There's no limit on the number of clips or their length, and no watermark."),
            ("How do I update?", "The Mac App Store version updates through the App Store. In the downloaded version, choose Help › Check for a New Version…; it opens this website in your browser, because Spolo itself never goes online."),
            ("How do I uninstall it?", "Quit Spolo and drag it from Applications to the Bin. Its last session and any items added from Photos are in ~/Library/Containers/com.feiyangtang.Spolo, which you can delete too."),
        ],
        "privacy_title": "Privacy policy",
        "privacy": [
            "Last updated 22 October 2026. This policy covers the Mac App Store version and the version downloaded from this website.",
            "<b>Spolo collects no data.</b> It has no network access: the App Sandbox does not let it connect to the internet. There are no accounts, analytics, telemetry, crash reporting, advertising or update checks, and no third-party code.",
            "Spolo reads the photos and videos you add, to show them and merge them. To bring your clips back the next time you open it, it remembers which files you added and how you edited them, as bookmarks to those files; it does not copy them.",
            "Photos and videos you add from your Photos library are chosen in the system's photo picker, so Spolo never has access to the library itself. The items you pick are copied into Spolo's own folder, because they have no file of their own; once they are no longer among your clips, they are deleted the next time Spolo opens.",
            "Spolo writes files only where you ask: the place you save the merged video. Links in the Help menu open in your browser, outside Spolo. Check for a New Version tells this website which version you have, so it can say whether a newer one exists.",
            "Spolo is suitable for all ages and collects nothing from anyone, including children. Questions about privacy: support@tang-spark.no.",
        ],
        "terms_title": "Terms",
        "terms": [
            "Spolo is free. You may use it for personal and commercial work.",
            "It is provided as is, without warranty. Spolo never changes the files you add, but TangSpark is not liable for loss of data or other damages from using it, as far as the law allows.",
            "You are responsible for having the rights to the photos and videos you merge. Mac App Store downloads are also covered by Apple's standard licence agreement.",
        ],
        "notes_title": "Release notes",
        "notes": [
            ("Version 1.0.1", "22 October 2026", "A cleaner window: Undo and Redo beside the title, labelled toolbar buttons, and Start Over to go back to an empty window. With no clip selected, the inspector shows the merged video. Files opened while Spolo starts now appear straight away."),
            ("Version 1.0.0", "22 October 2026", "First release: merge photos and videos into one MP4 or MOV; trim, speed, mute and rotate; five shapes with fit or fill; fast export without re-encoding; four languages."),
        ],
        "contact_title": "Contact",
        "contact": "Write to <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>. It helps to include your macOS version and the Spolo version (Spolo menu › About Spolo).",
        "footer_support": "Support & privacy",
    },
    "zh-cn": {
        "title": "Spolo — 照片和视频，合成一个视频。",
        "description": "Spolo 把照片和视频合成一个视频，全部在你的 Mac 上完成。排好顺序、剪好、选好比例就能导出，不上传、没有水印、不限数量。免费、私密、离线。",
        "label": "macOS 14+ · 免费 · 开源",
        "headline": "照片和视频，合成一个视频。",
        "lead": "手机、相机拍的片段，或者录屏，不管什么比例、什么格式，拖进来就行。排好顺序，剪掉头尾，在你的 Mac 上导出一个 MP4 或 MOV。Spole 是挪威语里“胶片卷轴”的意思。",
        "facts": [("平台", "macOS 14 或更新版本"), ("价格", "免费，Apache 2.0"), ("网络", "完全不联网"), ("语言", "EN, 简体, 繁體")],
        "shot_alt": "Spolo 正在合并七段照片和视频，选中了一段准备修剪",
        "what": "它能做什么",
        "features": [
            ("随便混搭", "任意比例、任意格式的照片和视频。竖拍的手机视频、HDR、没有声音的片段，都能正确合成。"),
            ("排好顺序", "拖动排序，或按拍摄时间、文件名、添加顺序一键排好。"),
            ("每段都能调", "修剪、调速（声音不变调）、静音、旋转，设定每张照片停留多久。"),
            ("统一画面", "自动、16:9、9:16、1:1 或 4:5，加黑边或填满裁切。"),
            ("又快又私密", "不上传、没有水印、不限数量。片段一致时直接拼接，不重新编码。"),
        ],
        "get": "获取 Spolo",
        "get_text_store": "可在 Mac App Store 免费获取，也可以下载经过签名和公证的版本。",
        "get_text_download": "免费下载，经过签名和公证。即将登陆 Mac App Store。",
        "get_text_soon": "免费、开源。即将登陆 Mac App Store；在那之前，可以从 GitHub 上的源代码构建。",
        "btn_store": "Mac App Store", "btn_download": "下载 Mac 版", "btn_source": "GitHub 源代码", "btn_support": "支持与隐私",
        "nav_apps": "Apps", "nav_support": "支持",
        "s_title": "Spolo 支持、隐私与条款",
        "s_hero": "支持",
        "s_headline": "支持、隐私与条款。",
        "s_lead": "常见问题、隐私政策和使用条款。如果这里没有你要的答案，请写信给我们。",
        "s_facts": [("版本", VERSION), ("收集的数据", "无"), ("网络", "完全不联网"), ("联系", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "开始使用"), ("faq", "常见问题"), ("privacy", "隐私"), ("terms", "条款"), ("release-notes", "更新说明"), ("contact", "联系")],
        "start": [
            "把照片和视频拖到 Spolo 窗口里，或者选择“文件 › 添加…”或“从‘照片’添加…”。",
            "拖动片段排好顺序，或用工具栏里的“排序方式”。点按一段片段，在检查器里修剪、调速、静音或旋转。",
            "用工具栏里的画面按钮（一开始显示“自动 · 适合”）选好比例和“适合”或“填满”，然后点“导出”。",
        ],
        "faq": [
            ("Spolo 能打开哪些格式？", "macOS 能播放或显示的都可以：H.264、HEVC、ProRes 编码的 MOV、MP4、M4V 视频，以及 JPEG、PNG、HEIC、TIFF、WebP、AVIF 和 RAW 照片。MKV、WebM、AVI 等少数格式 macOS 读不了；Spolo 会把它们灰显出来，而不是悄悄丢掉。"),
            ("为什么有时候导出一下子就好了？", "当所有片段都是编码、尺寸、帧率相同的视频，没有调速或旋转，画面比例也一致时，Spolo 会直接拼接，不重新编码。这时导出表单会显示“快速导出”，质量要选“原画质”。"),
            ("原画质、高、较小文件有什么区别？", "原画质保持原始尺寸，最高 4K。“高”最高 1080p、H.264 编码，到处都能播放。“较小文件”最高 1080p、HEVC 编码，码率更低。"),
            ("HDR 视频会怎样？", "Spolo 导出标准动态范围的视频，所以 HDR 和普通视频放在一起看起来一致。HDR 片段由 macOS 做色调映射。"),
            ("Spolo 会复制我的文件吗？", "不会。它只记住片段在哪里，下次打开时片段还在，但不会复制文件。从“照片”里添加的项目例外：它们没有自己的文件，所以 Spolo 会在自己的文件夹里保留一份副本，直到它们不再在片段里。"),
            ("怎么清空，重新开始？", "选择“文件 › 从头开始”（⌘N）。每一步都可以用标题旁的箭头撤销，“从头开始”也一样。"),
            ("有数量限制或水印吗？", "没有。片段数量和时长都不限，也没有水印。"),
            ("怎么更新？", "Mac App Store 版本通过 App Store 更新。下载版请选择“帮助 › 检查新版本…”，它会在浏览器中打开这个网站，因为 Spolo 自己从不联网。"),
            ("怎么卸载？", "退出 Spolo，把它从“应用程序”拖到废纸篓。它的上次会话和从“照片”添加的项目在 ~/Library/Containers/com.feiyangtang.Spolo，也可以一起删除。"),
        ],
        "privacy_title": "隐私政策",
        "privacy": [
            "最后更新：2026 年 10 月 22 日。本政策适用于 Mac App Store 版本和从本网站下载的版本。",
            "<b>Spolo 不收集任何数据。</b>它完全没有网络权限：App 沙盒不允许它连接互联网。没有账号、统计、遥测、崩溃报告、广告或更新检查，也没有任何第三方代码。",
            "Spolo 读取你添加的照片和视频，用来显示和合并。为了下次打开时片段还在，它会以书签的方式记住你添加了哪些文件、怎么调整的；它不会复制这些文件。",
            "从“照片”图库添加的照片和视频是在系统的照片选择器里挑选的，Spolo 从来无法访问图库本身。挑选的项目没有自己的文件，所以会复制到 Spolo 自己的文件夹里；当它们不再在片段里时，下次打开 Spolo 就会删除。",
            "Spolo 只在你指定的地方写入文件：你保存合并视频的位置。“帮助”菜单中的链接会在浏览器中打开，与 Spolo 无关。“检查新版本”会把你的版本号告诉本网站，以便显示是否有新版本。",
            "Spolo 适合所有年龄，不收集任何人的数据，包括儿童。隐私相关问题：support@tang-spark.no。",
        ],
        "terms_title": "使用条款",
        "terms": [
            "Spolo 免费，可用于个人和商业用途。",
            "Spolo 按“现状”提供，不附带任何保证。Spolo 从不修改你添加的文件；但在法律允许的范围内，TangSpark 不对因使用本软件造成的数据丢失或其他损失负责。",
            "你需要拥有所合并照片和视频的相应权利。从 Mac App Store 下载的版本同时适用 Apple 的标准许可协议。",
        ],
        "notes_title": "更新说明",
        "notes": [
            ("版本 1.0.1", "2026 年 10 月 22 日", "更清爽的窗口：标题旁有撤销和重做，工具栏按钮带文字，“从头开始”可以回到空白窗口。没有选中片段时，检查器显示整个视频的设置。启动时打开的文件会马上显示出来。"),
            ("版本 1.0.0", "2026 年 10 月 22 日", "首次发布：把照片和视频合成一个 MP4 或 MOV；修剪、调速、静音、旋转；五种画面比例，适合或填满；片段一致时快速导出、不重新编码；四种语言。"),
        ],
        "contact_title": "联系",
        "contact": "请写信至 <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>。附上 macOS 版本和 Spolo 版本（Spolo 菜单 › 关于 Spolo）会很有帮助。",
        "footer_support": "支持与隐私",
    },
    "zh-tw": {
        "title": "Spolo — 照片和影片，合成一部影片。",
        "description": "Spolo 把照片和影片合成一部影片，全部在你的 Mac 上完成。排好順序、剪好、選好比例就能匯出，不上傳、沒有浮水印、不限數量。免費、私密、離線。",
        "label": "macOS 14+ · 免費 · 開源",
        "headline": "照片和影片，合成一部影片。",
        "lead": "手機、相機拍的片段，或螢幕錄影，不管什麼比例、什麼格式，拖進來就行。排好順序，剪掉頭尾，在你的 Mac 上匯出一個 MP4 或 MOV。Spole 是挪威語「膠片捲軸」的意思。",
        "facts": [("平台", "macOS 14 或以上版本"), ("價格", "免費，Apache 2.0"), ("網路", "完全不連網"), ("語言", "EN, 简体, 繁體")],
        "shot_alt": "Spolo 正在合併七段照片和影片，選取了一段準備修剪",
        "what": "它能做什麼",
        "features": [
            ("隨意混搭", "任意比例、任意格式的照片和影片。直拍的手機影片、HDR、沒有聲音的片段，都能正確合成。"),
            ("排好順序", "拖移排序，或按拍攝日期、檔案名稱、加入順序一鍵排好。"),
            ("每段都能調", "修剪、調速（聲音不變調）、靜音、旋轉，設定每張照片停留多久。"),
            ("統一畫面", "自動、16:9、9:16、1:1 或 4:5，加上黑邊或填滿裁切。"),
            ("又快又私密", "不上傳、沒有浮水印、不限數量。片段一致時直接拼接，不重新編碼。"),
        ],
        "get": "取得 Spolo",
        "get_text_store": "可在 Mac App Store 免費取得，也可以下載經過簽署和公證的版本。",
        "get_text_download": "免費下載，經過簽署和公證。即將登上 Mac App Store。",
        "get_text_soon": "免費、開源。即將登上 Mac App Store；在那之前，可以從 GitHub 上的原始碼建置。",
        "btn_store": "Mac App Store", "btn_download": "下載 Mac 版", "btn_source": "GitHub 原始碼", "btn_support": "支援與隱私",
        "nav_apps": "Apps", "nav_support": "支援",
        "s_title": "Spolo 支援、隱私與條款",
        "s_hero": "支援",
        "s_headline": "支援、隱私與條款。",
        "s_lead": "常見問題、隱私權政策和使用條款。如果這裡沒有你要的答案，請寫信給我們。",
        "s_facts": [("版本", VERSION), ("收集的資料", "無"), ("網路", "完全不連網"), ("聯絡", '<a href="mailto:support@tang-spark.no">support@tang-spark.no</a>')],
        "toc": [("start", "開始使用"), ("faq", "常見問題"), ("privacy", "隱私"), ("terms", "條款"), ("release-notes", "版本說明"), ("contact", "聯絡")],
        "start": [
            "把照片和影片拖到 Spolo 視窗裡，或選擇「檔案 › 加入…」或「從『照片』加入…」。",
            "拖移片段排好順序，或使用工具列中的「排序方式」。按一下片段，在檢閱器中修剪、調速、靜音或旋轉。",
            "用工具列中的畫面按鈕（一開始顯示「自動 · 符合」）選好比例和「符合」或「填滿」，然後按「匯出」。",
        ],
        "faq": [
            ("Spolo 能打開哪些格式？", "macOS 能播放或顯示的都可以：H.264、HEVC、ProRes 編碼的 MOV、MP4、M4V 影片，以及 JPEG、PNG、HEIC、TIFF、WebP、AVIF 和 RAW 照片。MKV、WebM、AVI 等少數格式 macOS 讀不了；Spolo 會把它們以灰色顯示，而不是悄悄略過。"),
            ("為什麼有時候匯出一下子就好？", "當所有片段都是編碼、尺寸、影格速率相同的影片，沒有調速或旋轉，畫面比例也一致時，Spolo 會直接拼接，不重新編碼。這時匯出表單會顯示「快速匯出」，品質要選「原始畫質」。"),
            ("原始畫質、高、較小檔案有什麼不同？", "原始畫質保持原始尺寸，最高 4K。「高」最高 1080p、H.264 編碼，到處都能播放。「較小檔案」最高 1080p、HEVC 編碼，位元率更低。"),
            ("HDR 影片會怎樣？", "Spolo 匯出標準動態範圍的影片，所以 HDR 和一般影片放在一起看起來一致。HDR 片段由 macOS 做色調對應。"),
            ("Spolo 會複製我的檔案嗎？", "不會。它只記住片段在哪裡，下次打開時片段還在，但不會複製檔案。從「照片」加入的項目例外：它們沒有自己的檔案，所以 Spolo 會在自己的檔案夾中保留一份副本，直到它們不再在片段中。"),
            ("怎麼清空，重新開始？", "選擇「檔案 › 從頭開始」（⌘N）。每一步都可以用標題旁的箭頭還原，「從頭開始」也一樣。"),
            ("有數量限制或浮水印嗎？", "沒有。片段數量和長度都不限，也沒有浮水印。"),
            ("怎麼更新？", "Mac App Store 版本透過 App Store 更新。下載版請選擇「輔助說明 › 檢查新版本…」，它會在瀏覽器中打開這個網站，因為 Spolo 本身從不連網。"),
            ("怎麼解除安裝？", "結束 Spolo，把它從「應用程式」拖到垃圾桶。它的上次工作階段和從「照片」加入的項目在 ~/Library/Containers/com.feiyangtang.Spolo，也可以一併刪除。"),
        ],
        "privacy_title": "隱私權政策",
        "privacy": [
            "最後更新：2026 年 10 月 22 日。本政策適用於 Mac App Store 版本和從本網站下載的版本。",
            "<b>Spolo 不收集任何資料。</b>它完全沒有網路權限：App 沙盒不允許它連上網際網路。沒有帳號、統計、遙測、當機報告、廣告或更新檢查，也沒有任何第三方程式碼。",
            "Spolo 讀取你加入的照片和影片，用來顯示和合併。為了下次打開時片段還在，它會以書籤的方式記住你加入了哪些檔案、怎麼調整的；它不會複製這些檔案。",
            "從「照片」圖庫加入的照片和影片是在系統的照片選擇器中挑選的，Spolo 從來無法取用圖庫本身。挑選的項目沒有自己的檔案，所以會複製到 Spolo 自己的檔案夾中；當它們不再在片段中時，下次打開 Spolo 就會刪除。",
            "Spolo 只在你指定的地方寫入檔案：你儲存合併影片的位置。「輔助說明」選單中的連結會在瀏覽器中打開，與 Spolo 無關。「檢查新版本」會把你的版本號碼告訴本網站，以便顯示是否有新版本。",
            "Spolo 適合所有年齡，不收集任何人的資料，包括兒童。隱私相關問題：support@tang-spark.no。",
        ],
        "terms_title": "使用條款",
        "terms": [
            "Spolo 免費，可用於個人和商業用途。",
            "Spolo 依「現狀」提供，不附帶任何保證。Spolo 從不修改你加入的檔案；但在法律允許的範圍內，TangSpark 不對因使用本軟體造成的資料遺失或其他損失負責。",
            "你需要擁有所合併照片和影片的相應權利。從 Mac App Store 下載的版本同時適用 Apple 的標準授權協議。",
        ],
        "notes_title": "版本說明",
        "notes": [
            ("版本 1.0.1", "2026 年 10 月 22 日", "更清爽的視窗：標題旁有還原和重做，工具列按鈕附上文字，「從頭開始」可以回到空白視窗。沒有選取片段時，檢閱器顯示整部影片的設定。啟動時打開的檔案會馬上顯示。"),
            ("版本 1.0.0", "2026 年 10 月 22 日", "首次發佈：把照片和影片合成一個 MP4 或 MOV；修剪、調速、靜音、旋轉；五種畫面比例，符合或填滿；片段一致時快速匯出、不重新編碼；四種語言。"),
        ],
        "contact_title": "聯絡",
        "contact": "請寫信至 <a href=\"mailto:support@tang-spark.no\">support@tang-spark.no</a>。附上 macOS 版本和 Spolo 版本（Spolo 選單 › 關於 Spolo）會很有幫助。",
        "footer_support": "支援與隱私",
    },
}

e = html.escape


def head(lang, title, description, page):
    alternates = "".join(
        f'<link rel="alternate" hreflang="{LANGS[k]["html"]}" href="https://tang-spark.no/{page}{LANGS[k]["suffix"]}.html">'
        for k in LANGS)
    return (f'<!doctype html>\n<html lang="{LANGS[lang]["html"]}"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f'<title>{e(title)} | TangSpark</title><meta name="description" content="{e(description)}">\n'
            f'{alternates}\n<link rel="icon" type="image/svg+xml" href="./favicon.svg"><link rel="stylesheet" href="./styles.css"></head>\n'
            f'<body><div class="wrap">\n')


def nav(lang, page, items):
    langs = "".join(f'<a href="./{page}{LANGS[k]["suffix"]}.html" hreflang="{LANGS[k]["html"]}">{label}</a>'
                    for k, label in LANGS[lang]["other"])
    return f'<header><a class="mark" href="./index.html">TangSpark</a><nav>{items}{langs}</nav></header>\n'


def facts(rows):
    return '<div class="facts">' + "".join(f"<div><span>{e(k)}</span><span>{v}</span></div>" for k, v in rows) + "</div>"


def product(lang):
    c, s = COPY[lang], LANGS[lang]["suffix"]
    support = f"./spolo-support{s}.html"
    if APP_STORE_URL or DOWNLOAD_URL:
        text = c["get_text_store"] if APP_STORE_URL else c["get_text_download"]
        buttons = (f'<a class="btn red" href="{APP_STORE_URL}">{e(c["btn_store"])}</a>' if APP_STORE_URL else "") + \
                  (f'<a class="btn{"" if APP_STORE_URL else " red"}" href="{DOWNLOAD_URL}">{e(c["btn_download"])}</a>' if DOWNLOAD_URL else "")
    else:
        text, buttons = c["get_text_soon"], f'<a class="btn red" href="{GITHUB}">{e(c["btn_source"])}</a>'
    buttons += f'<a class="btn" href="{support}">{e(c["btn_support"])}</a>'
    shot = "img/spolo-shot.jpg" if lang == "en" else f"img/spolo-shot{s}.jpg"
    features = "".join(f"<li><b>{e(a)}</b><span>{e(b)}</span></li>" for a, b in c["features"])
    return (head(lang, c["title"], c["description"], "spolo")
            + nav(lang, "spolo", f'<a href="./index.html#apps">{c["nav_apps"]}</a><a href="{support}">{c["nav_support"]}</a>')
            + f'<div class="title"><img src="img/spolo-icon.png" alt=""><span class="label">{e(c["label"])}</span></div>\n'
            + '<div class="hero-name">Spolo</div>\n'
            + f'<section class="grid poster"><div class="block"><h1 class="cond">{e(c["headline"])}</h1><p>{e(c["lead"])}</p></div>\n{facts([(k, e(v)) for k, v in c["facts"]])}</section>\n'
            + f'<section class="grid"><div class="big"><img src="{shot}" alt="{e(c["shot_alt"])}"></div></section>\n'
            + f'<section class="part rule grid cols"><h2 class="cond">{e(c["what"])}</h2><ul class="list">{features}</ul></section>\n'
            + f'<section id="download" class="part rule grid cols"><h2 class="cond">{e(c["get"])}</h2><div style="grid-column: 5 / span 8"><p>{e(text)}</p><div class="cta">{buttons}</div></div></section>\n'
            + f'<footer><span>© 2026 TangSpark</span><a href="{support}">{e(c["footer_support"])}</a></footer>\n</div></body></html>\n')


def support(lang):
    c, s = COPY[lang], LANGS[lang]["suffix"]
    section = lambda id, title, body: f'<section id="{id}" class="part rule grid cols"><h2 class="cond">{e(title)}</h2><div class="doc">{body}</div></section>\n'
    toc = "".join(f'<a href="#{id}">{e(t)}</a>' for id, t in c["toc"])
    start = "<ol class=\"steps\">" + "".join(f"<li>{e(x)}</li>" for x in c["start"]) + "</ol>"
    faq = "".join(f"<h3>{e(q)}</h3><p>{e(a)}</p>" for q, a in c["faq"])
    privacy = "".join(f"<p>{p}</p>" for p in c["privacy"])
    terms = "".join(f"<p>{e(p)}</p>" for p in c["terms"])
    notes = "".join(f"<h3>{e(v)}</h3><p class=\"meta\">{e(d)}</p><p>{e(t)}</p>" for v, d, t in c["notes"])
    return (head(lang, c["s_title"], c["s_lead"], "spolo-support")
            + nav(lang, "spolo-support", f'<a href="./spolo{s}.html">Spolo</a><a href="#privacy">{e(c["toc"][2][1])}</a><a href="#terms">{e(c["toc"][3][1])}</a>')
            + f'<div class="title"><img src="img/spolo-icon.png" alt=""><span class="label">Spolo {VERSION}</span></div>\n'
            + f'<div class="hero-name">{e(c["s_hero"])}</div>\n'
            + f'<section class="grid poster"><div class="block"><h1 class="cond">{e(c["s_headline"])}</h1><p>{e(c["s_lead"])}</p></div>{facts(c["s_facts"])}</section>\n'
            + f'<nav class="toc">{toc}</nav>\n'
            + section("start", c["toc"][0][1], start)
            + section("faq", c["toc"][1][1], faq)
            + section("privacy", c["privacy_title"], privacy)
            + section("terms", c["terms_title"], terms)
            + section("release-notes", c["notes_title"], notes)
            + section("contact", c["contact_title"], f"<p>{c['contact']}</p>")
            + f'<footer><span>© 2026 TangSpark</span><a href="./spolo{s}.html">Spolo</a></footer>\n</div></body></html>\n')


if __name__ == "__main__":
    DIST.mkdir(parents=True, exist_ok=True)
    for lang in LANGS:
        s = LANGS[lang]["suffix"]
        (DIST / f"spolo{s}.html").write_text(product(lang))
        (DIST / f"spolo-support{s}.html").write_text(support(lang))
    print(f"wrote {len(LANGS) * 2} pages for Spolo {VERSION} to {DIST.relative_to(ROOT)}")
