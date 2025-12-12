ShotcutPro/               # 项目管理根目录
├── Assets/               # 核心资源库
├── Projects/             # 存放所有 .mlt 项目文件
├── Exports/              # 存放导出成品
├── Proxies/              # 代理素材缓存目录
├── clean_assets.sh       # 清理Assets/中未被项目引用的资源文件
└── rebuild_projects.sh   # 智能查找并复制Projects/下的所有.mlt文件中的资源路径指向的非Assets/下资源到Assets/下
                          # 并更新所有mlt中的资源路径为Assets/目录下的资源路径

项目约定:
    项目新建统一存放在Projects/目录下
    项目名称的命名
        [Video/Audio/Plan Name]-[Number ID]
    项目代理素材目录
        设置为Proxies/
    项目导出目录
        设置为Exports/
    项目素材
        一律拷贝到Assets/目录中
        然后再从Assets/目录导入项目
    项目视频模式
        横版视频 HD 1080p 30fps
        竖版视频 720x1280 9:16 30fps
    项目导出
        视频
            内建->H.264 High Profile
