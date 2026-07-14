$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$current_dir = (Get-Location).ProviderPath
Set-Location $PSScriptRoot

$bat_dir = $args[0]
$bat_file = $args[1]
$bat_path = $args[2]
$arg_dir = $args[3]
$arg_file = $args[4]
$arg_path = $args[5]

Set-Variable -Name DOCS_DIR_NAME -Value 'docs' -Option Constant
Set-Variable -Name API_REFERENCE_DIR_NAME -Value 'api-reference' -Option Constant
Set-Variable -Name ARCHIVE -Value $true -Option Constant

function Get-RequiredDirectoryTarget {
    param(
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Description is empty."
    }

    $resolved_path = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $item = Get-Item -LiteralPath $resolved_path -ErrorAction Stop
    if (-not $item.PSIsContainer) {
        throw "$Description must be a directory: $resolved_path"
    }

    return $item
}

function Get-VbaSourceFilePaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceSetPath
    )

    Get-ChildItem -LiteralPath $SourceSetPath -File | Where-Object {
        $_.Extension -in @('.bas', '.cls', '.frm')
    } | Sort-Object -Property Name | ForEach-Object { $_.FullName }
}

function Get-DocumentationContext {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$SourceDirectory
    )

    $source_parent = $SourceDirectory.Parent
    if ($null -eq $source_parent) {
        throw "Documentation owner directory could not be resolved for: $($SourceDirectory.FullName)"
    }

    if ([string]::Equals($SourceDirectory.Name, 'src', [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Warning "Source directory is named 'src', which is normally a container directory. Treating it as an owner-level source set."
        $owner_directory = $source_parent
        $project_name = $owner_directory.Name
        $output_directory = Join-Path (Join-Path $owner_directory.FullName $DOCS_DIR_NAME) $API_REFERENCE_DIR_NAME
    }
    elseif ([string]::Equals($source_parent.Name, 'src', [System.StringComparison]::OrdinalIgnoreCase)) {
        $owner_directory = $source_parent.Parent
        if ($null -eq $owner_directory) {
            throw "Documentation owner directory could not be resolved for: $($SourceDirectory.FullName)"
        }
        $project_name = $SourceDirectory.Name
        $output_directory = Join-Path (Join-Path (Join-Path $owner_directory.FullName $DOCS_DIR_NAME) $SourceDirectory.Name) $API_REFERENCE_DIR_NAME
    }
    else {
        $owner_directory = $source_parent
        $project_name = $owner_directory.Name
        $output_directory = Join-Path (Join-Path $owner_directory.FullName $DOCS_DIR_NAME) $API_REFERENCE_DIR_NAME
    }

    return [pscustomobject]@{
        SourceSetPath = $SourceDirectory.FullName
        OwnerDirectory = $owner_directory.FullName
        ProjectName = $project_name
        OutputDirectory = $output_directory
    }
}

function ConvertTo-DoxyfileValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return '"' + $Value + '"'
}

function Set-DoxyfileSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigText,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $replacement = $Name.PadRight(22) + '= ' + (ConvertTo-DoxyfileValue -Value $Value)
    $pattern = '(?m)^' + [System.Text.RegularExpressions.Regex]::Escape($Name) + '\s*=.*$'
    if ($ConfigText -match $pattern) {
        return $ConfigText -replace $pattern, $replacement
    }

    return $ConfigText.TrimEnd() + "`r`n" + $replacement + "`r`n"
}

function Get-DoxygenCommandPath {
    $path_entries = @($env:PATH -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $candidate_names = @('doxygen.exe', 'doxygen.cmd', 'doxygen.bat', 'doxygen')

    foreach ($path_entry in $path_entries) {
        $directory = $path_entry.Trim('"')
        foreach ($candidate_name in $candidate_names) {
            $candidate_path = Join-Path $directory $candidate_name
            if (Test-Path -LiteralPath $candidate_path -PathType Leaf) {
                return $candidate_path
            }
        }
    }

    return $null
}

$tmp_root = $null

try {
    $source_directory = Get-RequiredDirectoryTarget -Path $arg_path -Description 'source directory'
    $source_files = @(Get-VbaSourceFilePaths -SourceSetPath $source_directory.FullName)
    if ($source_files.Count -eq 0) {
        throw "No VBA source files were found in source directory: $($source_directory.FullName)"
    }

    $documentation_context = Get-DocumentationContext -SourceDirectory $source_directory
    $dst_dir = $documentation_context.OutputDirectory
    $archive_file = $dst_dir + '.zip'

    $tmp_root = Join-Path ([System.IO.Path]::GetTempPath()) ('gen-doc-' + [System.Guid]::NewGuid().ToString('N'))
    $tmp_src_dir = Join-Path $tmp_root 'source'
    $tmp_dst_dir = Join-Path $tmp_root $API_REFERENCE_DIR_NAME

    $doxyvb6_dir = Join-Path $PSScriptRoot 'DoxyVB6'
    $filter_file = Join-Path $doxyvb6_dir 'DoxyVB6.exe'
    $confbase_file = Join-Path $doxyvb6_dir 'Doxyfile'
    $conf_file = Join-Path $tmp_root 'Doxyfile'

    if (-not (Test-Path -LiteralPath $filter_file -PathType Leaf)) {
        throw "DoxyVB6 input filter was not found: $filter_file"
    }
    if (-not (Test-Path -LiteralPath $confbase_file -PathType Leaf)) {
        throw "Doxygen base configuration was not found: $confbase_file"
    }

    $doxygen_command_path = Get-DoxygenCommandPath
    if ($null -eq $doxygen_command_path) {
        throw 'Doxygen must be installed and available on PATH.'
    }

    # DoxyVB6 receives only the VBA text files that Doxygen should parse.
    # Binary form sidecars such as .frx are not useful for API reference generation.
    New-Item -ItemType Directory -Path $tmp_src_dir -Force | Out-Null
    foreach ($source_file in $source_files) {
        Copy-Item -LiteralPath $source_file -Destination $tmp_src_dir -Force
    }

    # Doxygen writes to a temporary output folder first, so a failed run does not
    # replace the existing API reference directory with partial output.
    New-Item -ItemType Directory -Path $tmp_dst_dir -Force | Out-Null

    # The repository-local Doxyfile is the template; this run only patches the
    # paths and display name that vary by source directory.
    $config_text = Get-Content -LiteralPath $confbase_file -Raw
    $config_text = Set-DoxyfileSetting -ConfigText $config_text -Name 'OUTPUT_DIRECTORY' -Value $tmp_dst_dir
    $config_text = Set-DoxyfileSetting -ConfigText $config_text -Name 'INPUT' -Value $tmp_src_dir
    $config_text = Set-DoxyfileSetting -ConfigText $config_text -Name 'INPUT_FILTER' -Value $filter_file
    $config_text = Set-DoxyfileSetting -ConfigText $config_text -Name 'PROJECT_NAME' -Value $documentation_context.ProjectName
    [System.IO.File]::WriteAllText($conf_file, $config_text, [System.Text.UTF8Encoding]::new($false))

    & $doxygen_command_path $conf_file
    if ($LASTEXITCODE -ne 0) {
        throw "doxygen failed with exit code $LASTEXITCODE."
    }

    # Only the resolved API reference target is replaced. Other documentation
    # targets under docs/ are intentionally left untouched.
    if (Test-Path -LiteralPath $dst_dir) {
        Remove-Item -LiteralPath $dst_dir -Recurse -Force
    }
    if (Test-Path -LiteralPath $archive_file -PathType Leaf) {
        Remove-Item -LiteralPath $archive_file -Force
    }

    $dst_parent_dir = Split-Path -Parent $dst_dir
    if (-not (Test-Path -LiteralPath $dst_parent_dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dst_parent_dir -Force | Out-Null
    }
    Move-Item -LiteralPath $tmp_dst_dir -Destination $dst_dir
    if ($ARCHIVE) {
        Compress-Archive -Path $dst_dir -DestinationPath $archive_file -Force
    }
}
finally {
    if ($null -ne $tmp_root -and (Test-Path -LiteralPath $tmp_root)) {
        Remove-Item -LiteralPath $tmp_root -Recurse -Force
    }
    Set-Location $current_dir
}
