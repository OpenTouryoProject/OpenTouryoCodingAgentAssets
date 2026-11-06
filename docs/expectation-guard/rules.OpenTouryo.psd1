# OpenTouryo の rules.psd1 の下書き（OpenTouryo#657 で root/programs/rules.psd1 として置く想定）。
#   今の root/programs/CheckExpectationChange.ps1（origin/5th_agent、2026-11-05）の、OpenTouryo に固有の部分を移したもの。
#   docs/expectation-guard.md の「置き換えの前後の比較」で、導入の後の全コミットの判定が同じであることを確かめた。
@{
    Reference    = 'QUALITY.md 3 節'
    IntroducedBy = 'root/programs/CheckExpectationChange.ps1'
    DiffScope    = @('root/programs/')

    Guard = @(
        '^root/programs/(CheckExpectationChange|CompareResult|CompareGolden)\.ps1$'
    )

    FileRules = @(
        @{
            Name           = 'Golden'
            Paths          = @('^root/programs/[^/]+/Frameworks/Tests/Golden/.+/Result[^/]*\.txt$')
            Comparer       = 'root/programs/CompareGolden.ps1'
            CommandPattern = 'Tests[\\/]+Golden'
        }
    )

    LineRules = @(
        @{
            Name  = 'テストの削除'
            Paths = @('^root/programs/[^/]+/Frameworks/Tests/NUnit/.+\.cs$')
            Count = 'Removed'
            Match = @( @{ Pattern = '[\[,]\s*(Test|TestCase|TestCaseSource)\s*[\],(]' } )
        }
        @{
            Name  = 'Ignore の追加'
            Paths = @('^root/programs/[^/]+/Frameworks/Tests/NUnit/.+\.cs$')
            Count = 'Added'
            Match = @( @{ Pattern = '[\[,]\s*(Ignore|Explicit)\s*[\],(]|\bAssert\s*\.\s*Ignore\s*\(' } )
        }
        @{
            Name  = '根拠の削除'
            Paths = @('^root/programs/[^/]+/Frameworks/Tests/NUnit/.+\.cs$')
            Count = 'Removed'
            Match = @( @{ Pattern = '[\[,]\s*Basis\s*\(' } )
        }
    )
}
