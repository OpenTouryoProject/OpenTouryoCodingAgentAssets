# 期待値の変更の検出器の、共通の規則（OpenTouryoCodingAgentAssets#3）。
#   原本は OpenTouryoCodingAgentAssets の src/quality/ExpectationGuard/。導入先では写しであり、直さない。
#   リポジトリごとの規則は rules.psd1（見本は rules.sample.psd1）。配列はここに足され、値は rules.psd1 で上書きされる。
@{
    # 承認のトレーラー
    ApprovalTrailer = 'Expectation-Change'

    # 数えない行（コメント。コメント アウトは「消えた」と数える）
    CommentLine = '^\s*//'

    # 仕組み自体のファイル（変更・削除・名前の変更を、期待値の変更と同じに扱う。追加は数えない）。
    #   本体（CheckExpectationChange.ps1）と規則のファイル（本ファイル・rules.psd1）は、本体が自分で加える。
    Guard = @(
        '^\.githooks/'
        '^\.claude/settings\.json$'
        '^\.claude/hooks/'
        '^\.github/workflows/expectation-change\.yml$'
    )

    # 段 1：コマンドで書き換えそうな操作（2>$null・*>&1 のような、捨てるだけのリダイレクトは除く）。
    #   FileRules・GeneratedRules の CommandPattern と両方に当たると、人の確認付きにする（**推測である。** 漏れは段 2・段 3 が塞ぐ）。
    WriteInCommand = '(?<![0-9*])>(?!\s*(\$null|/dev/null|&))|\b(Set-Content|Add-Content|Out-File|Copy-Item|Move-Item|Remove-Item|Rename-Item|WriteAll(Text|Bytes|Lines))\b|(^|[\s;|&(])(cp|mv|rm|copy|move|del|tee)\s|\bsed\s+(-\w*\s+)*-i|\bgit\s+(checkout|restore|reset|stash|apply|am|cherry-pick)\b'
}
