# Open in T3 Code

访达工具栏按钮：在 T3 Code 中打开当前文件夹。公开仓库。

## 结构

- `src/`：源码。`Launcher.m` 是可测试的逻辑，`main.m` 只管访达、系统事件和弹窗。
- `resources/`：`Info.plist` 和图标。图标是 T3 字标加克莱因蓝渐变底（源文件 `AppIcon.svg`，中段主色 `#002FA7`，上亮下深）。不要改成官方已用的黑、浅蓝网格、深紫星空，渐变亮端也不要浅到接近官方 Dev。保留 `THIRD_PARTY_NOTICES.md` 和 README 里的非官方声明。
- `tests/`：`./tests/run.sh`，不会打开真实的 T3 Code。
- `Open in T3 Code.app/`：`./build.sh` 的产物，随仓库分发，不手改。

## 规则

- 不放本机路径、个人项目名、邮箱、密钥。
- 不写死 App 路径、App 名或 `t3` 路径。不修改用户的任何设置和权限。
- 必须是 arm64 + x86_64，最低 macOS 13。不用 `osacompile`：它会把最低系统版本设成编译机的版本。
- 改动后先 `./tests/run.sh` 再 `./build.sh`。源码和产物一起提交。
- 中英文 README 同步改。push 和发版前先问维护者。
