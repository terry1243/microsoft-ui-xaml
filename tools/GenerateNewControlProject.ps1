[CmdLetBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$controlName
)

function FindAndReplaceInFile
{
    Param($file, $regex, $replace)

    $content = Get-Content $file -Raw

    [regex]$pattern = $regex
    $content = $pattern.replace($content, $replace, 1)

    Set-Content -Path $file -Value $content

}

function AddAttribute
{
    Param([xml]$xml, $element, $attrName, $attrValue)

    $attribute = $xml.CreateAttribute($attrName)
    $attribute.Value = $attrValue;
    $element.Attributes.Append($attribute)
}

$toolsDir = Split-Path -Path $MyInvocation.MyCommand.Path;
$muxControlsDir = Split-Path $toolsDir -Parent
$controlDir = $muxControlsDir + "\dev\$controlName"

$newDir = New-Item $controlDir -ItemType Directory
if (!$newDir)
{
    Write-Error "Control directory could not be created."
    exit 1
}

$from = $toolsDir + "\GenerateNewControlProjectFiles\*"
Copy-Item $from $controlDir -Recurse

# Replace NEWCONTROL with $controlName in file names
Get-ChildItem -Path $controlDir -Filter "*NEWCONTROL*" -Recurse | Rename-Item -NewName {$_.name -replace 'NEWCONTROL', $controlName }

# Replace NEWCONTROL with $controlName in file contents
$files = Get-ChildItem -Path $controlDir -Recurse -File
foreach ($file in $files)
{
    (Get-Content $file.PSPath) | Foreach-Object { 
        $_ -replace "NEWCONTROLUPPERCASE", $controlName.ToUpper() `
           -replace "NEWCONTROL", $controlName
    } | Set-Content $file.PSPath
}

# Add project to FeatureAreas.props
$featureAreasProps = $muxControlsDir + "\FeatureAreas.props";
[xml]$xml = Get-Content $featureAreasProps
foreach ($group in $xml.Project.PropertyGroup)
{
    if ($group.Attributes['Condition'].Value -ne $null -and $group.Attributes['Condition'].Value.Contains("(SolutionName) != 'MUXControlsInnerLoop'"))
    {
        $featureEnabledName = "Feature" + $controlName + "Enabled"
        $enabled = $xml.CreateElement($featureEnabledName, $xml.Project.NamespaceURI);
        $enabled.AppendChild($xml.CreateTextNode("true"))
        $group.AppendChild($enabled);
    }
}
$xml.Save($featureAreasProps)

# Add project to MUX.vcxproj
$muxProject = $muxControlsDir + "\dev\dll\Microsoft.UI.Xaml.vcxproj";
[xml]$xml = Get-Content $muxProject
foreach ($group in $xml.Project.ImportGroup)
{
    if ($group.Attributes['Label'].Value.Equals("Shared"))
    {
        $import = $xml.CreateElement("Import", $xml.Project.NamespaceURI);
        AddAttribute $xml $import "Project" "..\$controlName\$controlName.vcxitems"
        AddAttribute $xml $import "Label" "Shared"
        $group.AppendChild($import);
    }
}
$xml.Save($muxProject)

# Add tests to MUXControls.Test.Shared.targets
$testProject = $muxControlsDir + "\test\MUXControls.Test\MUXControls.Test.Shared.targets";
[xml]$xml = Get-Content $testProject
$import = $xml.CreateElement("Import", $xml.Project.NamespaceURI);
AddAttribute $xml $import "Project" "`$(MSBuildThisFileDirectory)\..\..\dev\$controlName\InteractionTests\$($controlName)_InteractionTests.projitems" 
AddAttribute $xml $import "Label" "Shared"
AddAttribute $xml $import "Condition" "`$(Feature$($controlName)Enabled) == 'true'"
$xml.Project.AppendChild($import);
$xml.Save($testProject)

# Add test page to MUXControlsTestApp.Shared.targets
$testAppProject = $muxControlsDir + "\test\MUXControlsTestApp\MUXControlsTestApp.Shared.targets";
[xml]$xml = Get-Content $testAppProject
$import = $xml.CreateElement("Import", $xml.Project.NamespaceURI);
AddAttribute $xml $import "Project" "`$(MSBuildThisFileDirectory)\..\..\dev\$controlName\TestUI\$($controlName)_TestUI.projitems"
AddAttribute $xml $import "Label" "Shared"
AddAttribute $xml $import "Condition" "`$(Feature$($controlName)Enabled) == 'true'"
$xml.Project.AppendChild($import);
$xml.Save($testAppProject)

# Add new profiler id to RuntimeProfiler.h
FindAndReplaceInFile ($muxControlsDir + "\dev\Telemetry\RuntimeProfiler.h") "(\s*ProfId_Size.*\s*})" @"

        ProfId_$controlName,`$1
"@
# Randomize class name for multiple use of class in one powershell
$id = get-random

# We need double backslash for C# strings below
$cleanMuxControlsDir = $muxControlsDir.Replace("\","\\") + "\\"

echo "$cleanMuxControlsDir"

$assemblies=(
	"System","EnvDTE","EnvDTE80"
)

$source=@"
using System;
using EnvDTE;
using EnvDTE80;
using System.Collections.Generic;
namespace SolutionHelper
{
    public static class SolutionRegister$id{
        public static void Main(){
            Console.WriteLine("Started script");
            var dteType = Type.GetTypeFromProgID("VisualStudio.DTE.16.0", true);
            if(dteType == null)
            {
                Console.WriteLine("You need to install Visual Studio to add projects to the solution");
                return;
            }
            var dte = (EnvDTE.DTE)System.Activator.CreateInstance(dteType);
            var sln = (SolutionClass)dte.Solution;
            Solution2 solution = (Solution2)dte.Solution;
            Console.WriteLine("Got solution class");

            var solutionNames = new List<string>(){"MUXControls.sln","MUXControlsInnerLoop.sln"};
            foreach(var solutionName in solutionNames)
            {
                Console.WriteLine("Opening solution: $($cleanMuxControlsDir)" + solutionName);
                solution.Open("$cleanMuxControlsDir" + solutionName);
                Console.WriteLine("Opened solution");
                var devFolder = solution.Projects.Item(1);
    
                // Get correct reference here:
                Console.WriteLine("Get dev folder");
                var devSolutionFolder = (SolutionFolder)devFolder.Object;
                Console.WriteLine("Add folder");
                SolutionFolder newControlFolder = (SolutionFolder)devSolutionFolder.AddSolutionFolder("$controlName").Object;

                Console.WriteLine("Adding projects:");
                Console.WriteLine("Adding source");
                newControlFolder.AddFromFile("$($cleanMuxControlsDir)dev\\$($controlName)\\$($controlName).vcxitems");
                Console.WriteLine("Adding test UI");
                newControlFolder.AddFromFile("$($cleanMuxControlsDir)dev\\$($controlName)/TestUI/$($controlName)_TestUI.shproj");
                Console.WriteLine("Adding interactions test");
                newControlFolder.AddFromFile("$($cleanMuxControlsDir)dev\\$($controlName)\\InteractionTests\\$($controlName)_InteractionTests.shproj");
                Console.WriteLine("Finished adding projects, saving solution");

                solution.Close(true);
                Console.WriteLine("Saved solution" + solutionName);
            }
        }
    }
}
"@


Add-Type -ReferencedAssemblies $assemblies -TypeDefinition $source -Language CSharp

iex "[SolutionHelper.SolutionRegister$id]::Main()"