<#
.SYNOPSIS
  治理层正文字数统计（唯一权威口径）

.DESCRIPTION
  为什么有这个脚本：v3.3.8 ~ v4.0.1 连续三版，文件头写的字数都是估算值，
  与实测差 258~289 字。「治理层太长了要精简」这类判断，曾建立在错数上。
  从 v4.0.3 起：字数一律用本脚本实测后写入，不再估算。

  【口径定义】

  | 项               | 处理                                            |
  |------------------|-------------------------------------------------|
  | 起点             | 从「### 一、身份」那一行开始，不含文件头          |
  | 空白             | 全部去掉（空格、换行、制表符）                    |
  | Markdown 语法字符 | 全部去掉：# * \| ` > -                          |
  | 中文标点         | 计入（，。：；「」等）                            |
  | 英文单词         | 按字符计（每个字母算 1）                          |
  | 数字             | 按字符计                                          |
  | 标题             | 计入（去掉 ### 后，标题文字算）                   |
  | 表头分隔行       | 去掉 \| 和 - 后只剩空白 → 归零                    |

  口径目的：衡量「实际要读多少字」，不是「文件多大」。
  所以排版符号不算，内容字符全算。

  【为什么起点要跳过文件头】
  原实现用 -Path 调用时从第 1 行开始统计，把版本头也算进去了；
  只有 -All 模式才跳到正文。同一文件因此报出两个数
  （-Path 报 2404，正文实为 2274）。现已修正。

.PARAMETER Path
  单个文件的路径

.PARAMETER FromLine
  手动指定起始行，1 为基准。不给则自动跳到正文起点。

.PARAMETER All
  统计 versions/ 下所有版本正文

.EXAMPLE
  pwsh -File docs\count-governance-chars.ps1 -Path versions\v4.0.3-正文.md
  pwsh -File docs\count-governance-chars.ps1 -All
#>
param(
  [string]$Path,
  [int]$FromLine = 0,
  [switch]$All
)

# 统计口径（唯一权威）：
#   起点 = 「### 一、身份」那一行（不含文件头）
#   去除 = 空白 + Markdown 语法字符 # * | ` > -
# 任何统计都必须走这个函数，不准另算。

function Get-GovChars {
  param([string[]]$Lines)
  $t = $Lines -join "`n"
  $t = $t -replace '[#*|`>\-]', ''
  $t = $t -replace '\s', ''
  return $t.Length
}

function Find-BodyStart {
  param([string[]]$Lines)
  # 兼容 ## 与 ### 两种标题层级（v3.3.8 用 ##，v4.x 用 ###）
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match '^#{2,3}\s*一、身份') { return $i }
  }
  return 0
}

if ($All) {
  # 正文文件现在统一在 versions/ 下，后缀 -正文.md
  $dir = Join-Path $PSScriptRoot '..\versions'
  $files = Get-ChildItem -LiteralPath $dir -Filter '*-正文.md' | Sort-Object Name
  if (-not $files) { Write-Output '未找到任何 *-正文.md 文件'; exit 1 }
  '{0,-32} {1,8}' -f '文件', '正文字数'
  '{0,-32} {1,8}' -f ('-' * 32), ('-' * 8)
  foreach ($f in $files) {
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    $start = Find-BodyStart -Lines $lines
    $n = Get-GovChars -Lines $lines[$start..($lines.Count - 1)]
    '{0,-32} {1,8}' -f $f.Name, $n
  }
  exit
}

if (-not $Path) { Write-Error '需要 -Path 或 -All'; exit 1 }
if (-not (Test-Path -LiteralPath $Path)) { Write-Error "文件不存在: $Path"; exit 1 }

$fileLines = Get-Content -LiteralPath $Path -Encoding UTF8

# 未显式指定 FromLine 时，自动跳到正文起点（修掉"含文件头"的口径漂移）
$startIdx = if ($FromLine -gt 0) { $FromLine - 1 } else { Find-BodyStart -Lines $fileLines }
$slice = $fileLines[$startIdx..($fileLines.Count - 1)]
$count = Get-GovChars -Lines $slice

Write-Output ("{0}: {1} 字（正文，去空白 + 去 Markdown 语法字符）" -f (Split-Path $Path -Leaf), $count)
