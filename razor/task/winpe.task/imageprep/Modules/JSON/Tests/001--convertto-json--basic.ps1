# PowerShell Script

# Basic Test Cases for JSON\ConvertTo-JSON

# Test-Cases
[CmdletBinding()] Param(
    [Switch] $Force = $False
)

Import-Module JSON -Force:$Force

$Expects = @{
  1 = @( { "a" | ConvertTo-JSON },                              { return '"a"' } );
  2 = @( { dir \ | ConvertTo-JSON },                            {} );
  3 = @( { (get-date) | ConvertTo-JSON },                       { [String](Get-Date -UFormat '"%Y-%m-%dT%T"') } );
  4 = @( { (dir \)[0] | ConvertTo-JSON -MaxDepth 1 },           {} );
  5 = @( { @{ "asd" = "sdfads" ; "a" = 2 } | ConvertTo-JSON },  {} );
};

$Expects.Keys | sort | %{
  ($k, $v) = $Expects.$_[0,1]
  $a = $False
  try { 
    $a = [String]($k.Invoke())
    $b = [String]($v.Invoke())
    $c = $a -eq $b
  } catch { }
  "  {0,5} {1,20}  {2,20}" -f $c, $a, $b
  # "{0,20} {1} => {2}" -f $k, $v, $a
};


# "a" | ConvertTo-JSON
# dir \ | ConvertTo-JSON
# (get-date) | ConvertTo-JSON
# (dir \)[0] | ConvertTo-JSON -MaxDepth 1
# @{ "asd" = "sdfads" ; "a" = 2 } | ConvertTo-JSON

