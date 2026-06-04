Put bundled third-party installers here before creating the distribution zip.

Expected optional file pattern:

PortableGit-*-64-bit.7z.exe

Example download:
https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/PortableGit-2.54.0-64-bit.7z.exe

If one or more matching files are present, scripts/bootstrap-deps.ps1 uses the newest local file instead of downloading PortableGit at startup.
