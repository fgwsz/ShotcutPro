~/Videos/ShotcutPro/       # 总项目目录
├── Assets/                # 【您的核心资产库】
│   ├── Video/            # 视频素材
│   ├── Audio/            # 音乐音效
│   └── Graphics/         # 图片图形
├── Projects/             # 存放所有 .mlt 项目文件
│   ├── Project_2024_Summer.mlt
│   └── Project_2024_Fall.mlt
├── Exports/              # 存放导出成品
├── Proxies/              # 代理素材缓存目录
├── clean_assets_video.sh # 清理Assets/Video中未被项目引用的视频文件
└── rebuild_projects.sh   # 复制Projects/下的所有.mlt文件中的资源路径到Assets/Video下
                          # 并更新所有mlt中的资源路径为Assets/Video目录下的资源路径

项目约定:
    项目新建统一存放在~/Videos/ShotcutPro/Projects目录下
    项目名称的命名
        [Video/Audio/PMV]-[Number ID]
    项目代理素材目录
        设置为~/Videos/ShotcutPro/Proxies
    项目导出目录
        设置为~/Videos/ShotcutPro/Exports
    项目素材
        一律拷贝到~/Videos/ShotcutPro/Assets目录中
        然后再从~/Videos/ShotcutPro/Assets目录导入项目
    项目视频模式
        横版视频 HD 1080p 30fps
        竖版视频 720x1280 9:16 30fps
    项目导出
        视频
            内建->H.264 High Profile
