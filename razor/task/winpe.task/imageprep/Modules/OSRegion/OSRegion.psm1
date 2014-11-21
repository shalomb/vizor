Set-StrictMode -Version 2

function Get-SystemCulture {
  [CmdletBinding()]Param(
    [Double]$KeyboardLayoutID,
    [Double]$LCID,
    [String]$CountryRegex,
    [String]$IETFLanguageTag,
    [String]$LanguageRegex,
    [String]$Name,
    [String]$ThreeLetterISOLanguageName,
    [String]$TwoLetterISOLanguageName
  )

  $FilteredCollection = [System.Globalization.CultureInfo]::GetCultures( [System.Globalization.CultureTypes]::AllCultures ) 

  if ( $Name ) {
    $FilteredCollection = $FilteredCollection | ?{ $_.Name -eq $Name }
  }
  if ( $IETFLanguageTag ) {
    $FilteredCollection = $FilteredCollection | ?{ $_.IetfLanguageTag -eq $IETFLanguageTag }
  } 
  if ( $TwoLetterISOLanguageName ) {
    $FilteredCollection = $FilteredCollection | ?{ $_.TwoLetterISOLanguageName -eq $TwoLetterISOLanguageName }
  } 
  if ( $ThreeLetterISOLanguageName ) {
    $FilteredCollection = $FilteredCollection | ?{ $_.ThreeLetterISOLanguageName -eq $ThreeLetterISOLanguageName }
  } 
  if ( $LanguageRegex ) {
    $FilteredCollection = $FilteredCollection | ?{ 
      $language = ([Regex]::match($_.DisplayName, "^([^\(]+)\s*\(?")).Groups[1].Value
      $language -imatch $LanguageRegex 
    }
  }
  if ( $CountryRegex ) {
    $FilteredCollection = $FilteredCollection | ?{ 
      $country = ([Regex]::match($_.DisplayName, "\((.+?)\)")).Groups[1].Value
      $country -imatch $CountryRegex 
    }
  }
  if ( $LCID ) {
    $FilteredCollection = $FilteredCollection | ?{ $_.LCID -eq $LCID }
  } 
  if ( $KeyboardLayoutID ) {
    $FilteredCollection = $FilteredCollection | ?{ $_.KeyboardLayoutID -eq $KeyboardLayoutID }
  } 

  $FilteredCollection
}

function Set-KeyboardLayout {
  [CmdletBinding()]Param (
    [Int32]$KeyboardLayoutID,
    [String]$CultureName
  )

  if ( $CultureName ) {
    $KeyboardLayoutID = Get-SystemCulture -Name $CultureName | %{ $_.KeyboardLayoutID }
  }
  if ( $KeyboardLayoutID ) {
    $KeyboardLayoutIDXForm = "{0:X4}:{0:X8}" -f $KeyboardLayoutID
    " KeyboardLayoutID : $KeyboardLayoutID $KeyboardLayoutIDXForm"
  } 

$PrefXMLTemplate = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
<!--User List-->
<gs:UserList>
<gs:User UserID="Current"/>
</gs:UserList>
<!--input preferences-->
<gs:InputPreferences>
<!--en-US-->
<gs:InputLanguageID Action="add" ID="0409:00000409"/> 
<!--cy-GB-->
<gs:InputLanguageID Action="add" ID="0452:00000452"/> 
<gs:InputLanguageID Action="add" ID="$KeyboardLayoutIDXForm" Default="true"/>
</gs:InputPreferences>
</gs:GlobalizationServices>
"@

  $TempFile = (Join-Path $Env:TEMP "userpref-$(([DateTime]::Now).Ticks).xml")
  $TempFile = (Join-Path $Env:TEMP "userpref.xml")
  $PrefXMLTemplate  | Out-File -Encoding ASCII $TempFile

  "control intl.cpl,, /f:'$TempFile'"
  cat $TempFile
  & (Join-Path $Env:WINDIR "System32\control.exe") "intl.cpl,, /f:'$TempFile'"
  
}

# function Get-SystemLocales {
# 
# $localeCollector = @{};
# 
# 0x01 .. 0x99999 | %{
#   try { 
#     $x="{0:x}" -f $_; $o=[System.Globalization.CultureInfo]::GetCultureInfo($_); 
#     if ($o) { 
#       $properties = gm | ?{ $_.MemberType -eq 'Property' } | %{ $_.Name }
#       $localeCollector.$($o.Name) = @{};
#       $localeCollector.$($o.Name)."KeyboardLayoutID"
#       "{0,4} {1,6} {2,5} {3,10} {4}" -f $x, $o.LCID, $o.KeyboardLayoutID, $o.Name, $o.DisplayName 
#     }   
#   } catch [Exception] {}  
# }
# 
# }

# Language Identifiers and Locales 
# http://msdn.microsoft.com/en-gb/library/aa912040.aspx

function Get-GeoID {
  [CmdletBinding()]Param(
    [String]$CountryNameRegex,
    [Int]$GeoID
  )

  # Table of Geographical Locations
  # http://msdn.microsoft.com/en-gb/library/windows/desktop/dd374073(v=vs.85).aspx
  $GeoIDs = @{
          '0x2'='Antigua and Barbuda';
          '0x3'='Afghanistan';
          '0x4'='Algeria';
          '0x5'='Azerbaijan';
          '0x6'='Albania';
          '0x7'='Armenia';
          '0x8'='Andorra';
          '0x9'='Angola';
          '0xA'='American Samoa';
          '0xB'='Argentina';
          '0xC'='Australia';
          '0xE'='Austria';
         '0x11'='Bahrain';
         '0x12'='Barbados';
         '0x13'='Botswana';
         '0x14'='Bermuda';
         '0x15'='Belgium';
         '0x16'='Bahamas, The';
         '0x17'='Bangladesh';
         '0x18'='Belize';
         '0x19'='Bosnia and Herzegovina';
         '0x1A'='Bolivia';
         '0x1B'='Myanmar';
         '0x1C'='Benin';
         '0x1D'='Belarus';
         '0x1E'='Solomon Islands';
         '0x20'='Brazil';
         '0x22'='Bhutan';
         '0x23'='Bulgaria';
         '0x25'='Brunei';
         '0x26'='Burundi';
         '0x27'='Canada';
         '0x28'='Cambodia';
         '0x29'='Chad';
         '0x2A'='Sri Lanka';
         '0x2B'='Congo';
         '0x2C'='Congo (DRC)';
         '0x2D'='China';
         '0x2E'='Chile';
         '0x31'='Cameroon';
         '0x32'='Comoros';
         '0x33'='Colombia';
         '0x36'='Costa Rica';
         '0x37'='Central African Republic';
         '0x38'='Cuba';
         '0x39'='Cape Verde';
         '0x3B'='Cyprus';
         '0x3D'='Denmark';
         '0x3E'='Djibouti';
         '0x3F'='Dominica';
         '0x41'='Dominican Republic';
         '0x42'='Ecuador';
         '0x43'='Egypt';
         '0x44'='Ireland';
         '0x45'='Equatorial Guinea';
         '0x46'='Estonia';
         '0x47'='Eritrea';
         '0x48'='El Salvador';
         '0x49'='Ethiopia';
         '0x4B'='Czech Republic';
         '0x4D'='Finland';
         '0x4E'='Fiji Islands';
         '0x50'='Micronesia';
         '0x51'='Faroe Islands';
         '0x54'='France';
         '0x56'='Gambia, The';
         '0x57'='Gabon';
         '0x58'='Georgia';
         '0x59'='Ghana';
         '0x5A'='Gibraltar';
         '0x5B'='Grenada';
         '0x5D'='Greenland';
         '0x5E'='Germany';
         '0x62'='Greece';
         '0x63'='Guatemala';
         '0x64'='Guinea';
         '0x65'='Guyana';
         '0x67'='Haiti';
         '0x68'='Hong Kong S.A.R.';
         '0x6A'='Honduras';
         '0x6C'='Croatia';
         '0x6D'='Hungary';
         '0x6E'='Iceland';
         '0x6F'='Indonesia';
         '0x71'='India';
         '0x72'='British Indian Ocean Territory';
         '0x74'='Iran';
         '0x75'='Israel';
         '0x76'='Italy';
         '0x77'='Côte d''Ivoire';
         '0x79'='Iraq';
         '0x7A'='Japan';
         '0x7C'='Jamaica';
         '0x7D'='Jan Mayen';
         '0x7E'='Jordan';
         '0x7F'='Johnston Atoll';
         '0x81'='Kenya';
         '0x82'='Kyrgyzstan';
         '0x83'='North Korea';
         '0x85'='Kiribati';
         '0x86'='Korea';
         '0x88'='Kuwait';
         '0x89'='Kazakhstan';
         '0x8A'='Laos';
         '0x8B'='Lebanon';
         '0x8C'='Latvia';
         '0x8D'='Lithuania';
         '0x8E'='Liberia';
         '0x8F'='Slovakia';
         '0x91'='Liechtenstein';
         '0x92'='Lesotho';
         '0x93'='Luxembourg';
         '0x94'='Libya';
         '0x95'='Madagascar';
         '0x97'='Macao S.A.R.';
         '0x98'='Moldova';
         '0x9A'='Mongolia';
         '0x9C'='Malawi';
         '0x9D'='Mali';
         '0x9E'='Monaco';
         '0x9F'='Morocco';
         '0xA0'='Mauritius';
         '0xA2'='Mauritania';
         '0xA3'='Malta';
         '0xA4'='Oman';
         '0xA5'='Maldives';
         '0xA6'='Mexico';
         '0xA7'='Malaysia';
         '0xA8'='Mozambique';
         '0xAD'='Niger';
         '0xAE'='Vanuatu';
         '0xAF'='Nigeria';
         '0xB0'='Netherlands';
         '0xB1'='Norway';
         '0xB2'='Nepal';
         '0xB4'='Nauru';
         '0xB5'='Suriname';
         '0xB6'='Nicaragua';
         '0xB7'='New Zealand';
         '0xB8'='Palestinian Authority';
         '0xB9'='Paraguay';
         '0xBB'='Peru';
         '0xBE'='Pakistan';
         '0xBF'='Poland';
         '0xC0'='Panama';
         '0xC1'='Portugal';
         '0xC2'='Papua New Guinea';
         '0xC3'='Palau';
         '0xC4'='Guinea-Bissau';
         '0xC5'='Qatar';
         '0xC6'='Reunion';
         '0xC7'='Marshall Islands';
         '0xC8'='Romania';
         '0xC9'='Philippines';
         '0xCA'='Puerto Rico';
         '0xCB'='Russia';
         '0xCC'='Rwanda';
         '0xCD'='Saudi Arabia';
         '0xCE'='St. Pierre and Miquelon';
         '0xCF'='St. Kitts and Nevis';
         '0xD0'='Seychelles';
         '0xD1'='South Africa';
         '0xD2'='Senegal';
         '0xD4'='Slovenia';
         '0xD5'='Sierra Leone';
         '0xD6'='San Marino';
         '0xD7'='Singapore';
         '0xD8'='Somalia';
         '0xD9'='Spain';
         '0xDA'='St. Lucia';
         '0xDB'='Sudan';
         '0xDC'='Svalbard';
         '0xDD'='Sweden';
         '0xDE'='Syria';
         '0xDF'='Switzerland';
         '0xE0'='United Arab Emirates';
         '0xE1'='Trinidad and Tobago';
         '0xE3'='Thailand';
         '0xE4'='Tajikistan';
         '0xE7'='Tonga';
         '0xE8'='Togo';
         '0xE9'='São Tomé and Príncipe';
         '0xEA'='Tunisia';
         '0xEB'='Turkey';
         '0xEC'='Tuvalu';
         '0xED'='Taiwan';
         '0xEE'='Turkmenistan';
         '0xEF'='Tanzania';
         '0xF0'='Uganda';
         '0xF1'='Ukraine';
         '0xF2'='United Kingdom';
         '0xF4'='United States';
         '0xF5'='Burkina Faso';
         '0xF6'='Uruguay';
         '0xF7'='Uzbekistan';
         '0xF8'='St. Vincent and the Grenadines';
         '0xF9'='Venezuela';
         '0xFB'='Vietnam';
         '0xFC'='Virgin Islands';
         '0xFD'='Vatican City';
         '0xFE'='Namibia';
        '0x101'='Western Sahara (disputed)';
        '0x102'='Wake Island';
        '0x103'='Samoa';
        '0x104'='Swaziland';
        '0x105'='Yemen';
        '0x107'='Zambia';
        '0x108'='Zimbabwe';
        '0x10D'='Serbia and Montenegro (Former)';
        '0x10E'='Montenegro';
        '0x10F'='Serbia';
        '0x111'='Curaçao';
        '0x114'='South Sudan';
        '0x12C'='Anguilla';
        '0x12D'='Antarctica';
        '0x12E'='Aruba';
        '0x12F'='Ascension Island';
        '0x130'='Ashmore and Cartier Islands';
        '0x131'='Baker Island';
        '0x132'='Bouvet Island';
        '0x133'='Cayman Islands';
        '0x135'='Christmas Island';
        '0x136'='Clipperton Island';
        '0x137'='Cocos (Keeling) Islands';
        '0x138'='Cook Islands';
        '0x139'='Coral Sea Islands';
        '0x13A'='Diego Garcia';
        '0x13B'='Falkland Islands (Islas Malvinas)';
        '0x13D'='French Guiana';
        '0x13E'='French Polynesia';
        '0x13F'='French Southern and Antarctic Lands';
        '0x141'='Guadeloupe';
        '0x142'='Guam';
        '0x143'='Guantanamo Bay';
        '0x144'='Guernsey';
        '0x145'='Heard Island and McDonald Islands';
        '0x146'='Howland Island';
        '0x147'='Jarvis Island';
        '0x148'='Jersey';
        '0x149'='Kingman Reef';
        '0x14A'='Martinique';
        '0x14B'='Mayotte';
        '0x14C'='Montserrat';
        '0x14E'='New Caledonia';
        '0x14F'='Niue';
        '0x150'='Norfolk Island';
        '0x151'='Northern Mariana Islands';
        '0x152'='Palmyra Atoll';
        '0x153'='Pitcairn Islands';
        '0x154'='Rota Island';
        '0x155'='Saipan';
        '0x156'='South Georgia and the South Sandwich Islands';
        '0x157'='St. Helena';
        '0x15A'='Tinian Island';
        '0x15B'='Tokelau';
        '0x15C'='Tristan da Cunha';
        '0x15D'='Turks and Caicos Islands';
        '0x15F'='Virgin Islands, British';
        '0x160'='Wallis and Futuna';
       '0x3B16'='Man, Isle of';
       '0x4CA2'='Macedonia, Former Yugoslav Republic of';
       '0x52FA'='Midway Islands';
       '0x78F7'='Sint Maarten (Dutch part)';
       '0x7BDA'='Saint Martin (French part)';
     '0x6F60E7'='Democratic Republic of Timor-Leste';
     '0x9906F5'='Åland Islands';
    '0x9A55C4F'='Saint Barthélemy';
    '0x9A55D40'='U.S. Minor Outlying Islands';
    '0x9A55D42'='Bonaire, Saint Eustatius and Saba';
  }

  $FilteredCollection = $GeoIDs.keys | %{
    $Country = New-Object -Type PSObject
    $Country = Add-Member -PassThru -InputObject $Country -MemberType NoteProperty -Name 'CountryName' -Value $GeoIDs[$_]
    $Country = Add-Member -PassThru -InputObject $Country -MemberType NoteProperty -Name 'GeoID' -Value $_
    $Country = Add-Member -PassThru -InputObject $Country -MemberType NoteProperty -Name 'GeoIDInt' -Value ([Int]$_)
    return $Country
  }
  
  if ( $CountryNameRegex ) {
    $FilteredCollection = $FilteredCollection | ?{ $_.CountryName -imatch $CountryNameRegex }
  }

  if ( $GeoID ) {
    $FilteredCollection = $FilteredCollection | ?{ ([Int]$_.GeoID) -eq ([Int]$GeoID) }
  }
  
  return $FilteredCollection
}
