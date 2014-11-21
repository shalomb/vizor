$code = @{}
$ScriptBlock = { cmd /c exit 42 }

$job = [PowerShell]::Create().AddScript({
  param($ScriptBlock, $Result)
  & $ScriptBlock
  $Result.Value = $LASTEXITCODE
  'some output'
}).AddArgument($ScriptBlock).AddArgument($code)

# start thee job
$async = $job.BeginInvoke()

# do some other work while $job is working
#.....

# end the job, get results
$job.EndInvoke($async)

# the exit code is $code.Value
"Code = $($code.Value)"
