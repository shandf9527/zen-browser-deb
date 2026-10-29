# zen-browser-deb

把官方 [Zen Browser](https://zen-browser.app) 的 Linux 构建自动打成 Debian 软件包的私有仓库。

每天一次 GitHub Actions 检查官方最新 release，如果没有打包过，就生成 `.deb` 并附到本仓库的 Release 里。

## 构建的是什么（以及不是什么）

这个仓库**不编译源码**。Firefox/Zen 源码构建需要 30–40 GB 磁盘和数小时 CPU（官方 CI 用的是
`blacksmith-16vcpu` 这类付费大机器，还要跑 PGO 插桩），免费 hosted runner 只有 4 vCPU / 16 GB 内存 /
约 14 GB 可用磁盘、单 job 上限 6 小时，跑不下来。

所以流程是下载官方 Linux tar 包（`zen.linux-x86_64.tar.xz`、`zen.linux-aarch64.tar.xz`）后重新封装：

| 由本仓库添加 | 内容 |
|---|---|
| 程序本体 | 官方原封不动，装到 `/opt/zen-browser` |
| 启动器 | `/usr/bin/zen-browser` → `/opt/zen-browser/zen` |
| 桌面项 | `/usr/share/applications/zen-browser.desktop`（含新建窗口 / 隐私窗口动作） |
| 图标 | hicolor 16/32/48/64/128 px |
| 依赖 | 仅 Gecko 运行时链接的库（GTK3、X11、ALSA、Pulse 等） |

## 安装与升级

从最新 Release 下载对应架构的 deb，然后：

```bash
sudo apt install ./zen-browser_<版本>_amd64.deb
```

`apt` 会自动补齐缺少的运行时库。升级就是下载新版本后重复同一条命令；配置目录 `~/.zen` 不受影响。

卸载：

```bash
sudo apt remove zen-browser
```

## 触发方式

- **定时**：每天 03:17 UTC（北京时间 11:17）自动跑一次。
- **手动**：`workflow_dispatch`，可以指定版本（如 `1.23.4b`），也可以勾选 `force` 强制重打已发布的版本。

版本号重复时任务会自动跳过，所以官方没发新版时，每日定时任务基本是空跑，不产生新 Release。

## 本地构建

```bash
curl -LO https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz
./build-deb.sh --version 1.23.4b --arch amd64 --tarball zen.linux-x86_64.tar.xz --outdir dist
```

只需要 `dpkg-deb` 和 `xz-utils`，不需要 fakeroot，也不需要编译工具链。

## 说明

- Zen 自带的更新器保留未动，但建议通过 `apt` 升级，避免包数据库与实际文件不一致。
- 非官方打包。打包本身的问题提到本仓库；浏览器本身的 bug 提给
  [zen-browser/desktop](https://github.com/zen-browser/desktop/issues)。
- 仓库是私有的，Release 资产需要登录后才能下载（网页下载即可，或 `gh release download`）。
