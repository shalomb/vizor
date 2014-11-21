Set-StrictMode -Version 2

# CurrentCulture
# CurrentUICulture
#
# LCID to Culture
# [System.Globalization.CultureInfo]::GetCultureInfo( $LCID )
# Locale Name to Culture
# [System.Globalization.CultureInfo]::GetCultureInfo( $LocaleName )
#
# List all Cultures, LCIDs, Names on system
# [System.Globalization.CultureInfo]::GetCultures( [System.Globalization.CultureTypes]::FrameworkCultures )
# [System.Globalization.CultureInfo]::GetCultures( [System.Globalization.CultureTypes]::AllCultures )
# [System.Globalization.CultureInfo]::GetCultures( [System.Globalization.CultureTypes]::InstalledWin32Cultures )
#
# Language Identifiers and Locales
# http://msdn.microsoft.com/en-us/library/aa912040.aspx
#
# Table of Geographical Locations
# http://msdn.microsoft.com/en-gb/library/windows/desktop/dd374073(v=vs.85).aspx
#
# You can fetch the LangID like this:
# int LangId = LCID & 0xFFFF
#
# [System.Globalization.RegionInfo]::CurrentRegion
## http://superuser.com/questions/353752/windows-7-change-region-and-language-settings-using-a-script
# function Get-CurrentRegion {
#   [CmdletBinding()] Param()
#   [System.Globalization.RegionInfo]::CurrentRegion
#   # Get-Culture
# }

Function Set-KeyboardLayout() {
  [CmdletBinding()] Param(
    $Layout    
  )
  $signature = @"
    [DllImport("user32.dll")]
    public static extern uint ActivateKeyboardLayout(uint hkl, uint Flags);

  [DllImport ("user32.dll")]
  private static extern int LoadKeyboardLayout (string pwszKLID, int Flags);
"@
    # public static extern bool ActivateKeyboardLayout(IntPtr hWnd, int nCmdShow);

    $LANG_EN_US = "1033";
    
    $_ActivateKeyboardLayout = Add-Type -memberDefinition $signature -name "Win32ActivateKeyboardLayout_${PID}" -namespace Win32Functions -passThru

    $_ActivateKeyboardLayout::ActivateKeyboardLayout($LANG_EN_US, 0)
    #$_ActivateKeyboardLayout::LoadKeyboardLayout($LANG_EN_US, 0)
}

function Get-KeyBoardLayout {
  [CmdletBinding()] Param()
  Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\*" | %{
    New-Object -Type PSObject -Property @{ 'Name' = $_."Layout Text"; 'LCID' = $_.PSChildName; }
  }
}
