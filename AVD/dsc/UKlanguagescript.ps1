$GlobalizationUnattendXML = "UKRegion.xml"
# Set Locale, language etc. 
& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"$GlobalizationUnattendXML`""
 
# Set Timezone
<#
Get a list of time zones with the command "tzutil /l"

Répertorie tous les ID de fuseau horaire valides et les noms d’affichage. La sortie sera :
       <nom d’affichage>
       <ID de fuseau horaire>

For en-GB would be 
(UTC+00:00) Dublin, Édimbourg, Lisbonne, Londres
GMT Standard Time

# & tzutil /s "GMT Standard Time"

On a computer you can get the current time zone with  "tzutil /g"
Romance Standard Time
#>
# Paris Time Zone would be "Romance Standard Time"

& tzutil /s "GMT Standard Time"


# Set languages/culture
Set-Culture en-GB
