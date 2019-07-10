Function handleVaultFolderMapping
{
    param($object, $fileRoot, [System.Collections.ArrayList]$vaultFolderCSV, $vaultFolderCSVPath)

    $vaultId = $object.objidOriginal.vault;

    $vaultIdIndex=-1;
    if($vaultFolderCSV.vaultId -ne $null)
    {
        $vaultIdIndex = $vaultFolderCSV.vaultId.IndexOf($vaultId);
    }    


    if($vaultIdIndex -eq -1)
    {
        $vaultRename= "Temp_$($vaultFolderCSV.Count + 3)";
        $folderPath = "$fileRoot\Files\$vaultRename";
        
        $vaultFolderCSV.add($(New-Object psobject -Property @{'vaultId'=$vaultId; 'folderName'=$vaultRename; 'folderPath'=$folderPath}));
        
        $cleanedId = $vaultId.Substring(1,$vaultId.Length-2);
        
        Rename-Item -Path "$fileRoot\Files\$cleanedId" -NewName $vaultRename;
        $vaultFolderCSV | Export-Csv -Path $vaultFolderCSVPath -NoTypeInformation;
        
        return $folderPath;
    }
    return $vaultFolderCSV[$vaultIdIndex].folderPath;    
}


Function parseMFileObject{
    param($mfileObject, $folderPath)

    #$vaultId = $mfileObject.objidOriginal.vault;
    #$vaultIdIndex = $vaultFolderCSV.vaultId.IndexOf($vaultId)
    #if($vaultIdIndex -eq -1)
    #{
    #    $vaultRename='Temp_$($vaultMap.Count + 1)'
    #    $vaultFolderCSV.add($(New-Object psobject -Property @{vaultId=$vaultId; folderName=$vaultRename}));
    #}
    #$newFolderName = $vaultFolderCSV.folderPath[$vaultIdIndex];
    #
    ##Rename-Item '..\Files\$vaultId'
    #New-Item -Path '..\Files\$newFolderName' -ItemType SymbolicLink -Value '..\Files\$vaultId'


    #get latest version
    

    $mfileObjectVersion = $null;
    if($mfileObject.version[0] -eq $null)
    {
        $mfileObjectVersion = $mfileObject.version;
    }
    else
    {
        $mfileObjectVersion = $mfileObject.version[0];
    }

    $indexofClass = $mfileObjectVersion.properties.property.name.IndexOf('Class');

    $className = $mfileObjectVersion.properties.property[$indexofClass];

    $pathFromBase = $mfileObjectVersion.docfiles.docfile.pathfrombase;
    $pathFromBaseSplit = $pathFromBase.split('\');
    $pathFromBaseSliced = $pathFromBaseSplit[2..$pathFromBaseSplit.count];
    
    $pathFromRoot = $folderPath + '\' + $($pathFromBaseSliced -join '\')

    $size = $mfileObjectVersion.docfiles.size

    return New-Object psobject -Property @{'PathOnClient'=$pathFromRoot; 'Type'=$className}
}

#main
Function generateUploadCsvForContentVer
{
    param($metaDataDir, $fileRoot, $vaultFolderCSVPath)

    $accountsPath = 'C:\Users\dcurtin\Desktop\Account exports\Retirement_accounts.csv';
    $accountCsv = Import-csv -Path $accountsPath;
    #$accountsNameToIdMap=$null;
    [System.Collections.ArrayList] $recordsCsv = @();
    $accountsNameToIdMap = @{};
    echo 'Generating Map';
    $accountCsv.ForEach({$accountsNameToIdMap.add($_.Name, $_.Id)}) >$null;
    
    $pathFolder1 = 'F:\M-Files Exports\Trust Archive\folder\Files';
    $pathFolder2 = 'F:\M-Files Exports\Trust Archive\folder\Files\folder2';
    $indexCount = 0;
    
    $csvOfFiles = @();
    echo 'Getting all Pdfs';

    [System.Collections.ArrayList] $vaultFolderCSV = @();
    if([System.IO.File]::Exists($vaultFolderCSVPath))
    {
        $vaultFolderCSV = Import-Csv $vaultFolderCSVPath;
    }
    
    Get-ChildItem -Path $metaDataDir -Filter 'Content*.xml' | ForEach-Object -Process ({
        [xml]$currentContentDocument = Get-Content $_.FullName;
        #echo $currentContentDocument.content.object;
        $currentContentDocument.content.object | ForEach-Object -Process ({
            
            $path = handleVaultFolderMapping -object $_ -fileRoot $fileRoot -vaultFolderCSV $vaultFolderCSV -vaultFolderCSVPath $vaultFolderCSVPath
            $record = parseMFileObject -mfileObject $_ -folderPath $path
            $recordsCsv.add($record);
            #echo $record;
            
        })
    })

    $recordsCsv | Export-Csv -Path C:\Users\dcurtin\Desktop\testCsv.csv -NoTypeInformation
    <#Get-ChildItem -Recurse -Path $pathFolder1 -Filter '*.pdf' | ForEach-Object -Process (
    {
        $nameFirstPart=($_.Name -split ".pdf")[0];
        $nameList=$nameFirstPart.split(' ');
        $name=[String]::Join(' ', $nameList[1..($nameList.length - 1)]);
        $accountName = $nameList[0];
        $fullPath = $_.FullName;
        $accountId = $accountsNameToIdMap[$accountName];
    
        #[psobject] $newItem = New-Object PSObject -Property @{'Title'=$name; 'First Pub'=$accountId ;'VersionData'=$fullPath ;'PathOnClient'=$fullPath };
        $indexCount = $csvOfFiles.add($(New-Object PSObject -Property @{'Title'=$name; 'First Pub'=$accountId ;'VersionData'=$fullPath ;'PathOnClient'=$fullPath; 'Type'='Legacy Document' }));
        
        if($indexCount % 1000 -eq 0)
        {
            echo $indexCount 'Complete';
        }
    });

    echo 'Generating csv';
    $csvOfFiles | Export-Csv -Path '.\UploadFileProd.csv' -NoTypeInformation#>

}