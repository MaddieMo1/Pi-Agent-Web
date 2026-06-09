这里用于放置随压缩包一起分发的第三方便携安装包。

当前可选文件名格式：

PortableGit-*-64-bit.7z.exe

示例下载地址：
https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/PortableGit-2.54.0-64-bit.7z.exe

如果这里存在一个或多个匹配文件，scripts/bootstrap-deps.ps1 会在启动时优先使用最新的本地 PortableGit 文件，而不是联网下载。

打包给其他人之前，可以把 PortableGit-*-64-bit.7z.exe 放到这个目录，方便没有 Git 的 Windows 电脑离线启动。
