# macOS 移植记录（2026-10-18）

本次把 `native/` 的输入引擎接到 macOS InputMethodKit，并完成候选窗、两套方案和整句解码。
当前版本 **0.3.4**，安装位置 `/Library/Input Methods/Tigirl.app`
（Bundle ID `com.viui.inputmethod.Tigirl`，显示名 虎娘 / Tigirl）。

## 当前能力

- 普通字词（`虎码字词`）：四码自动上屏（`maxCodeLength = 4` + `maxCodeAutoCommit = true`），
  编码组合、候选窗、空格/数字/分号/引号选词、鼠标点选、翻页（`-` `=`、↑ ↓）；
- 整句（`虎整句`）：连续编码交给我本地五 gram 模型组句，候选随输入实时更新；
- 方案菜单（输入法菜单 → 虎娘）：虎码字词 / 虎整句，选择写入
  `~/Library/Preferences/com.viui.inputmethod.Tigirl.plist`，下次激活沿用；
- 候选窗跟随光标：优先 `attributesForCharacterIndex:lineHeightRectangle:`（鼠须管同款），
  其次 `firstRectForCharacterRange:actualRange:`，最后回退鼠标位置。

## 目录结构

| 文件 | 职责 |
|---|---|
| `macos/TigirlInputMethod.mm` | `IMKServer` 启动、`--register-input-source` / `--enable-input-source` |
| `macos/TigirlInputController.mm` | 按键处理、组合文本、候选窗、方案切换、整句调度 |
| `macos/TigirlCandidateWindow.mm` | 非激活候选面板、鼠标点选 |
| `macos/TigirlKeyMap.mm` | `NSEvent` keyCode → Windows VK |
| `macos/TigirlSentence.mm` | 按码表缓存 `SentenceResources`（405 MB 模型只映射一次） |
| `macos/lexicon_import_main.cpp` | 生成 `.tcd` 及 `.sentence.tcd` / `.supplement.tcd` sidecar |

整句链路：

```
Engine::process
  → sentenceRequest() 取得待解码 ticket
  → SentenceDecoder::decode(raw, 20, evidence, requiredPrefix, lockedPrefix)
  → Engine::applySentenceResult(ticket, result)
  → Snapshot::candidates 交给候选窗
```

`虎码字词` 不启用 `enableSentenceInput`，只走普通引擎，因此四码上屏不受影响。

## 今天踩到并修掉的问题

1. **启动即崩溃**：`initWithName:controllerClass:delegateClass:` 在 macOS 14 SIGSEGV，
   改用 `initWithName:bundleIdentifier:`，并在 `IMKServer` 之前初始化 `NSApplication`。
2. **系统不识别输入法**：Bundle ID 必须是 `<厂商>.inputmethod.<名称>`；
   `com.viui.tigirl.inputmethod` 会被静默忽略，改为 `com.viui.inputmethod.Tigirl`。
3. **签名失效**：资源加入后再签名；`build-pkg.sh` 之前打包的是未签名产物。
4. **没有候选窗**：IMK 的 `inputText:` 与 `handleEvent:` 互斥，实现了前者就不会调用后者；
   改为只实现 `handleEvent:`，方向键/翻页键才能进输入法。
5. **每次按键抛异常**：`setMarkedText:selection:replacementRange:` 方法名错误，
   正确是 `setMarkedText:selectionRange:replacementRange:`。
6. **`NSPanel` 永不显示**：默认 `hidesOnDeactivate`，输入法不是激活 App；
   加 `hidesOnDeactivate = NO` 与 `NSWindowStyleMaskNonactivatingPanel`。
7. **按键映射整体错位**：ANSI 表中漏了 keyCode 10/36/48/49，导致 `j`→`k`；
   重写为完整 51 项表。
8. **分号/引号次选失效**：标点必须映射到 Windows VK（`;`=186、`'`=222），
   不能传 ASCII 字符码。
9. **候选窗不跟光标**：WebView 不返回插入点，改用
   `attributesForCharacterIndex:lineHeightRectangle:`（鼠须管方案）。
10. **安装器重定位**：存在同名/同 ID 的 App 时 PackageKit 会装进 `.localized/`；
    安装包加入 `preinstall` 清理并改用唯一 bundle 名 `Tigirl.app`。
11. **TIS/LaunchServices 残留**：旧记录让输入源变灰不可选；
    `lsregister -u` 后重新注册，必要时注销重登。
12. **字词方案误走整句**：整句解码只对 `虎整句` 开启，`虎码字词` 保持四码上屏。

## 资源

| 文件 | 大小 | 说明 |
|---|---|---|
| `tiger-v2.tcd` | 41.9 MB | 虎码字词主码表 |
| `tiger-v2.tcd.sentence.tcd` | 34.2 MB | 字词方案的整句索引 sidecar |
| `tiger-v2-sentence.tcd` | 16.0 MB | 虎整句码表 |
| `Models/sentence-fivegram-mobile.bin` | 405.7 MB | TCSKNM03 v2 Q8 五 gram 模型（SHA256 `756f6c92…`） |
| `Models/sentence-lexical-v1.bin` | 150 KB | 词法先验（SHA256 `8dbc884b…`） |

生成码表与 sidecar：

```sh
build-macos/TigirlLexiconImport \
  "$PWD/resources/DefaultData/码表/虎码字词" \
  "$PWD/resources/DefaultData/拼音反查码表" \
  "$PWD/build/ARM64/Release/tiger-v2.tcd" \
  "$PWD/resources/DefaultData/码表/虎整句/补充语料.txt"
```

## 构建

```sh
export TIGIRL_SENTENCE_MODEL=/path/to/sentence-fivegram-mobile.bin
cmake -S macos -B build-macos -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE=Release \
  -DTIGIRL_DICTIONARY="$PWD/build/ARM64/Release/tiger-v2.tcd" \
  -DTIGIRL_SENTENCE_DICTIONARY="$PWD/build/ARM64/Release/tiger-v2-sentence.tcd" \
  -DTIGIRL_SENTENCE_MODEL="$TIGIRL_SENTENCE_MODEL"
cmake --build build-macos --target TigirlInputMethod -j4
macos/build-pkg.sh          # 输出 build/Tigirl-macOS-<version>.pkg
```

## 已知限制

- 切换输入法/登录后**第一次按键**可能被系统吞掉（进程按需启动）；预启动或登录项可缓解。
- 部分客户端（如 WebView）不提供光标几何，候选窗退到鼠标位置。
- ad-hoc 签名下 Accessibility 权限对输入法进程无效，AX 兜底实际不可用。
- 安装包未签名：Installer 会提示脚本、且不显示自动注销按钮。
- 用户词库/配置/皮肤、五笔方案、标点细节尚未移植。

## 版本

`0.1.4` → `0.3.4` 均为 2026-10-18 当天迭代：先打通启动与注册，再补候选窗、
键映射、方案切换，最后接入五 gram 整句。
