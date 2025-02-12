<#
.SYNOPSIS
This PowerShell script generates a summary of the directory structure and file contents for a specified folder, filtering out items based on a provided .gitignore file. It supports specifying file extensions to include and handles both hidden and visible files.

.PARAMETER folder
The root folder to analyze.

.PARAMETER exts
Comma-separated list of file extensions to include in the summary.

.PARAMETER files
Specific files to summarize if not analyzing a folder.

.PARAMETER ignore
Path to a .gitignore file to use for filtering out items.

.EXAMPLE
.\summarize_files.ps1 -folder 'C:\path\to\folder' -exts 'py,txt' -ignore 'C:\path\to\.gitignore'

.EXAMPLE
.\summarize_files.ps1 -files 'C:\path\to\file1', 'C:\path\to\file2'
#>

param(
    [string]$folder,
    [string]$exts,
    [string[]]$files,
    [string]$ignore
)

function Get-DateTimeStamp {
    return (Get-Date -Format "yyMMdd_HHmmss")
}

function Get-FolderTree {
    param (
        [string]$folder,
        [string[]]$extensions,
        [string[]]$ignorePatterns,
        [int]$depth = 5,
        [string]$prefix = ""
    )
    $tree = ""
    $filePaths = @()

    if ($depth -le 0) {
        return @{ Tree = $tree; FilePaths = $filePaths }
    }

    $items = Get-ChildItem -Path $folder | Where-Object { $_.PSIsContainer -or $extensions -contains $_.Extension.TrimStart('.') }

    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($folder.Length + 1).Replace("\", "/")
        $ignored = $false
        
        foreach ($pattern in $ignorePatterns) {
            if ($relativePath -like $pattern -or $item.FullName -like $pattern) {
                $ignored = $true
                break
            }
        }

        if ($ignored) {
            continue
        }

        if ($item.PSIsContainer) {
            $tree += "$prefix├── $($item.Name)`n"
            $result = Get-FolderTree -folder $item.FullName -extensions $extensions -ignorePatterns $ignorePatterns -depth ($depth - 1) -prefix "$prefix│   "
            $tree += $result.Tree
            $filePaths += $result.FilePaths
        } else {
            $tree += "$prefix├── $($item.Name)`n"
            $filePaths += $item.FullName
        }
    }

    return @{ Tree = $tree; FilePaths = $filePaths }
}

function Summarize-Files {
    param (
        [string[]]$filePaths,
        [string]$outputFile,
        [string]$baseFolder
    )

    foreach ($filePath in $filePaths) {
        # Check if the file path length is greater than the base folder length
        if ($filePath.Length -gt $baseFolder.Length) {
            $relativePath = $filePath.Substring($baseFolder.Length ).Replace("\", "/")
        } else {
            # Handle cases where the file path is shorter or base folder is incorrect
            $relativePath = $filePath.Replace("\", "/")
        }
        
        Add-Content -Path $outputFile -Value "------"
        Add-Content -Path $outputFile -Value "$relativePath"
        if (Test-Path $filePath) {
            Get-Content -Path $filePath | Add-Content -Path $outputFile
        } else {
            Add-Content -Path $outputFile -Value "File not found."
        }
        Add-Content -Path $outputFile -Value ""
    }
}

function Get-GitIgnorePatterns {
    param (
        [string]$gitIgnorePath
    )
    $patterns = @()
    if (Test-Path $gitIgnorePath) {
        $patterns = Get-Content -Path $gitIgnorePath | Where-Object { $_ -and $_ -notmatch '^#' } | ForEach-Object { $_.Trim() }
        # Convert the patterns to proper wildcards for use with -like
        $patterns = $patterns | ForEach-Object {
            $_ = $_ -replace "/", "\"
            if ($_ -like "*\") {
                "*$($_)*"
            } elseif ($_ -like "\*") {
                "*$($_)*" 
            } else {
                $_ -replace "\*", "*" -replace "\?", "?"
            }
        }
    }
    return $patterns
}

$timestamp = Get-DateTimeStamp
$outputFile = "$PWD\$timestamp-summary.txt"

$ignorePatterns = @()
if ($ignore) {
    $ignorePatterns = Get-GitIgnorePatterns -gitIgnorePath $ignore
}

if ($folder -and $exts) {
    if (-Not (Test-Path $folder)) {
        Write-Output "Error: The specified folder does not exist."
        exit 1
    }
    $extensions = $exts -split ","
    $result = Get-FolderTree -folder $folder -extensions $extensions -ignorePatterns $ignorePatterns
    $result.Tree | Out-File -FilePath $outputFile

    $filePaths = $result.FilePaths
    if ($filePaths.Length -eq 0) {
        Write-Output "Error: No files found with the specified extensions."
        exit 1
    }
    Summarize-Files -filePaths $filePaths -outputFile $outputFile -baseFolder $folder

} elseif ($files) {
    if ($files.Length -eq 0) {
        Write-Output "Error: No files specified."
        exit 1
    }
    Summarize-Files -filePaths $files -outputFile $outputFile -baseFolder (Get-Location)

} else {
    Write-Output "Error: Incorrect arguments. Usage:"
    Write-Output "To summarize files in a folder with specific extensions:"
    Write-Output ".\summarize_files.ps1 -folder 'C:\path\to\folder' -exts 'ext1,ext2' [-ignore 'C:\path\to\.gitignore']"
    Write-Output "To summarize specific files:"
    Write-Output ".\summarize_files.ps1 -files 'C:\path\to\file1', 'C:\path\to\file2'"
    exit 1
}

Write-Output "Summary written to $outputFile"
