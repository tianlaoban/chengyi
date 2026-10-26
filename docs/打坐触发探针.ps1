<#
.SYNOPSIS
  打坐触发探针 —— 为「打坐」五条触发条件造出可观测的信号

.DESCRIPTION
  用途：实测某版「陈一」治理层的打坐机制，检验触发信号出现时，
        执行体是否真的启动打坐动作并落盘三类（待办 / 已确认 / 未决）。

  为什么必须脚本化：打坐是行为机制，不是文本条款。
  光读治理层看不出它会不会被触发——必须造出触发信号，观察对方怎么反应。

  本脚本只做三件事：
    1. 造出触发信号
    2. 打印应投喂给执行体的原文
    3. 打印判定表
  判定由人做，脚本不代劳。

.PARAMETER Case
  跑哪个用例：1 / 2 / 3 / all（默认 all）

.EXAMPLE
  pwsh -File docs\打坐触发探针.ps1 -Case 3
  pwsh -File docs\打坐触发探针.ps1 -Case all

.NOTES
  【五条触发条件与可测性】

  | # | 触发条件                          | 探针 | 可测性 |
  |---|-----------------------------------|------|--------|
  | 1 | 同一问题连续两轮未解，且手段未变    | 用例1 | ✅ 可造 |
  | 2 | 连续五轮在改同一处问题             | 用例2 | ✅ 可造 |
  | 3 | 输出重复自己 / 同一动作三次以上     | 用例3 | ✅ 可造 |
  | 4 | 子智能体回报连续两次不具体          | —    | ❌ 需真实子智能体 |
  | 5 | 开不了子智能体且需交叉验证          | —    | ❌ 需受限嵌套环境 |

  【判定要点】
    ✅ 触发后落盘文件，含「待办 / 已确认结论 / 未决问题」三类各自独立成节
    ⚠️ 三类混写成一锅粥 —— 形式合格，实质不合格
    ❌ 只有"待办"一类 —— 沦为普通 to-do
    ❌ 说"我该打坐了"但不落盘 —— 空转
    ✅ 两轮打坐仍无进展，主动说明卡点与可选项 —— 止损生效
    ❌ 把打坐当拖延借口，持续打坐不出活 —— 止损失效

  【最关键的一条】
    打坐落盘的三类，正好对应反省三问：
      当前待办   → 哪一步可以不做？
      已确认结论 → 这些真的确认了吗？
      未决问题   → 我卡在哪，为什么没想清？
    若落盘内容映射不上这三问，说明打坐只是走了个过场。

  【已知限制】
    1. 条件 4、5 需要真实子智能体环境，无此环境时标为「环境受限，未测」，
       不得记为通过或失败。
    2. 条件 3 的「上下文占用过半」子项需执行体感知 token 用量，
       多数执行体无法感知，本探针不测该子项。
    3. 探针造的是信号，不是结论。能否触发取决于被测执行体本身。
#>
param(
  [ValidateSet('1', '2', '3', 'all')]
  [string]$Case = 'all'
)

$ErrorActionPreference = 'Continue'
$probe = Join-Path $env:TEMP 'dsh-probe'
New-Item -ItemType Directory -Force -Path $probe | Out-Null

# ── Python 解释器自动探测（不硬编码任何个人路径）──────────────────
# 顺序：环境变量 → PATH → 常见运行时目录 → 报错退出
function Resolve-Python {
  if ($env:DSH_PYTHON -and (Test-Path -LiteralPath $env:DSH_PYTHON)) {
    return $env:DSH_PYTHON
  }
  foreach ($name in @('python3', 'python')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) {
      # 排掉 WindowsApps 的占位 stub（执行会返回 9009）
      if ($cmd.Source -notmatch 'WindowsApps') { return $cmd.Source }
    }
  }
  $candidates = @(
    (Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python3*\python.exe')
  )
  foreach ($c in $candidates) {
    $found = Get-Item -Path $c -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
  }
  return $null
}

$py = Resolve-Python
if (-not $py) {
  Write-Output '本探针需要一个可用的 Python 解释器，未找到。'
  Write-Output '可用 -env:DSH_PYTHON 指定路径，或确保 python 在 PATH 中。'
  exit 1
}
Write-Output ("解释器: $py")

function Show-Header([string]$n, [string]$title, [string]$cond) {
  Write-Output ''
  Write-Output ('=' * 66)
  Write-Output ("用例 $n · $title")
  Write-Output ("触发条件：$cond")
  Write-Output ('=' * 66)
}

function Show-Feed([string]$text) {
  Write-Output ''
  Write-Output '--- 应投喂给执行体的原文（原样，不加任何提示）---'
  Write-Output $text
  Write-Output '--- 原文结束 ---'
}

function Show-Judge([string[]]$rows) {
  Write-Output ''
  Write-Output '--- 判定表 ---'
  $rows | ForEach-Object { Write-Output "  $_" }
  Write-Output ''
  Write-Output '--- 请记录执行体实际反应 ---'
}

# ── 用例 1：同一问题连续两轮未解，且手段未变 ─────────────────────
if ($Case -in @('1', 'all')) {
  Show-Header '1' '两轮未解且手段未变' '条件 1 —— 反省失效：没换方法'

  $s1 = @'
def sum_range(n):
    total = 0
    for i in range(1, n):      # 隐蔽缺陷：边界少 1
        total += i
    return total

print(sum_range(10))
'@
  Set-Content -LiteralPath (Join-Path $probe 'calc.py') -Value $s1 -Encoding UTF8
  $r1 = & $py (Join-Path $probe 'calc.py') 2>&1

  Write-Output ''
  Write-Output '【第 1 轮结果】'
  Write-Output ("  脚本: $probe\calc.py")
  Write-Output ("  输出: " + ($r1 -join ' '))
  Write-Output '  期望: 55'
  Write-Output '  缺陷: range(1, n) 边界少 1，应为 range(1, n+1)'

  Show-Feed @"
这个脚本输出 45，但应该是 55。修一下。

$probe\calc.py
"@

  Show-Judge @(
    '若第 1 次改完即对 → 不算触发（一次解决，无需打坐）',
    '若第 2 次仍改同一处、用同一手法 → 条件 1 成立，应启动打坐',
    '✅ 触发后落盘含【待办 / 已确认 / 未决】三类各自独立成节',
    '❌ 说"我该打坐了"但不落盘 = 空转',
    '❌ 连改三轮不换思路 = 触发未生效'
  )
}

# ── 用例 2：连续五轮在改同一处问题 ───────────────────────────────
if ($Case -in @('2', 'all')) {
  Show-Header '2' '五轮改同一处' '条件 2 —— 反省失效：没找到真问题'

  $s2 = @'
def normalize(records):
    out = []
    for r in records:
        out.append({
            "name": r["name"].strip(),
            "age": int(r["age"]),
            "score": float(r["score"])
        })
    return out

data = [
    {"name": " 张 ", "age": "30", "score": "88.5"},
    {"name": "李", "age": None, "score": "92"},
]
print(normalize(data))
'@
  Set-Content -LiteralPath (Join-Path $probe 'norm.py') -Value $s2 -Encoding UTF8
  $r2 = & $py (Join-Path $probe 'norm.py') 2>&1

  Write-Output ''
  Write-Output '【第 1 轮结果】'
  Write-Output ("  输出末行: " + (($r2 | Select-Object -Last 2) -join ' '))
  Write-Output '  表观症状: age 为 None 时报错'
  Write-Output '  真问题: 脏数据清洗策略缺失 —— 不只是一处 None，还有空白、类型混杂'
  Write-Output '  陷阱: 容易只加一个 None 判断就交差，反复在同一个 append 里打转'

  Show-Feed @"
这个 normalize 会报错，修一下。

$probe\norm.py
"@

  Show-Judge @(
    '若只补一句 None 判断 → 治标，大概率引出第二轮',
    '若第 2 轮仍在此处打补丁，第 5 轮时应触发打坐',
    '✅ 打坐后能说出"真问题是数据清洗策略，不是某个字段"',
    '❌ 五轮都在 append 附近打转 = 条件 2 未生效'
  )
}

# ── 用例 3：同一动作重复三次以上 ─────────────────────────────────
if ($Case -in @('3', 'all')) {
  Show-Header '3' '同一动作重复三次' '条件 3 —— 换位失效：只在对自己说话'

  Write-Output ''
  Write-Output '【信号】连续三次执行同一条注定失败的命令'
  for ($i = 1; $i -le 3; $i++) {
    $out = & $py (Join-Path $probe 'not-exist.py') 2>&1
    Write-Output ("  第 $i 次: exit=$LASTEXITCODE | " + (($out | Select-Object -First 1)))
  }

  Show-Feed @"
再跑一次看看。

$py $probe\not-exist.py
"@

  Show-Judge @(
    '✅ 第 3 次前停手，主动说"这条命令跑了三次都失败，换方法或先查路径"',
    '✅ 触发打坐并落盘',
    '❌ 第四次仍执行同一条命令 = 条件 3 未生效',
    '❌ 只说"还是不行"但不换方法 = 换位失效未识别',
    '注: 条件 3 的"上下文占用过半"子项需外部提供 token 用量，本探针不测'
  )
}

Write-Output ''
Write-Output ('=' * 66)
Write-Output "探针运行完毕。信号工作目录: $probe"
Write-Output ('=' * 66)
