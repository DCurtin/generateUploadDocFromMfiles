Function getNamesFromMeta
{
    param($index, $mfileObjectVersion, $arrayList)

    #[System.Collections.ArrayList] $propertyList = @();

    $propertyNameString = $mfileObjectVersion.properties.property[$index].'#text';
    #Write-Host $propertyNameString;
    $propertyNameStringSplit = $propertyNameString.split(';');
    $propertyNameStringSplit | ForEach-Object -Process ({ $null=$arrayList.add($_.split(' ')[0]);
    })
    #return [System.Collections.ArrayList] $arrayList;
}

Function generateRecordAddRelatedObject
{
    param($folderPath, $pathFromBase, $className, $size, $dateComplete, $accountName='', $transName='', $assetName='')

    $pathFromBaseSplit = $pathFromBase.split('\');
    $pathFromBaseSliced = $pathFromBaseSplit[2..$($pathFromBaseSplit.count - 1)];
    $fileName = "$dateComplete-$($pathFromBaseSplit[$pathFromBaseSplit.count - 1].split('.')[0])";
    
    $pathFromRoot = $folderPath + '\' + $($pathFromBaseSliced -join '\')

    $record = [ordered] @{'PathOnClient'=$pathFromRoot; 'Class'=$className; 'Name'=$fileName; 'Size'=$size; 'dateComplete'=$dateComplete; 'accountName'=$accountName; 'transName'=$transName; 'assetName'=$assetName;} #New-Object psobject -Property @{'PathOnClient'=$pathFromRoot; 'Class'=$className; 'DateComplete'=$dateComplete; 'Name'=$fileName
    return $record;
}

Function mapFirstPublisherLocationAndNameFile
{
    param($recordList, $classMappingCSV, $accountMap, $transactionMap, $assetMap)
    $recordMapOfLists = @{};
    [System.Collections.ArrayList] $noMappingList = @();
    [System.Collections.ArrayList] $mappedList = @();

    $recordList | ForEach-Object -Process (
    {
        #Write-Host $_.values
        if($_.Class -eq 'Legacy Document')
        {
            #Add-Member -NotePropertyName 'Type' -NotePropertyValue 'Legacy Document' -InputObject $psobject
        
            if($_.Name -match '\d{7}' -and $accountMap.ContainsKey($matches[0]))
            {
                $accountName = $matches[0];

                $accountId = $accountMap[$accountName];
                $_.add('FirstPub', $accountId);
                $null = $mappedList.add($_);
            }else
            {
                #Write-Host 'No Account'
                $null = $noMappingList.add($_);
            }
        }
    })

    $null = $recordMapOfLists.add('mappedRecords', $mappedList);
    $null = $recordMapOfLists.add('nonMappedRecords', $noMappingList);

    return $recordMapOfLists;
}

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
    $className = $mfileObjectVersion.properties.property[$indexofClass].'#text';

    $indexOfDateComplete = $mfileObjectVersion.properties.property.name.IndexOf('Date Completed');
    $dateComplete = $mfileObjectVersion.properties.property[$indexOfDateComplete].'#text';

    [System.Collections.ArrayList] $transactionList = @();
    $transactionNameIndex = $mfileObjectVersion.properties.property.name.IndexOf('Transaction');
    if($transactionNameIndex -ne -1)
    {
        getNamesFromMeta -index $transactionNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $transactionList
    }

    [System.Collections.ArrayList] $accountList = @();
    $accountNameIndex  = $mfileObjectVersion.properties.property.name.IndexOf('Account Name');
    if($accountNameIndex -ne -1)
    {
        getNamesFromMeta -index $accountNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $accountList;
        #Write-Host $accountList.Count
    }

    [System.Collections.ArrayList] $assetList = @();
    $assetNameIndex = $mfileObjectVersion.properties.property.name.IndexOf('Asset'); 
    if($assetNameIndex -ne -1)
    {
        getNamesFromMeta -index $assetNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $assetList
    }

    [System.Collections.ArrayList] $recordList = @();

    $docfiles = $($mfileObjectVersion.docfiles.docfile);
    $docfiles | ForEach-Object -Process (
    {
        $pathFromBase = $_.pathfrombase;
        $size = $_.Size

        if($accountList.count -ne 0){ 
            $accountList | ForEach-Object -Process ({
                $record = generateRecordAddRelatedObject -accountName $_ -className $className -pathFromBase $pathFromBase -folderPath $folderPath -size $size -dateComplete $dateComplete
                $null = $recordList.add($record);
            })
        }

        if($transactionList.count -ne 0){
            $transactionList | ForEach-Object -Process ({
                    $record = generateRecordAddRelatedObject -transName $_ -className $className -pathFromBase $pathFromBase -folderPath $folderPath -size $size -dateComplete $dateComplete
                    $null = $recordList.add($record);
                })
        
        }
        
        if($assetList.count -ne 0){
            $assetList | ForEach-Object -Process ({
                    $record = generateRecordAddRelatedObject -assetName $_ -className $className -pathFromBase $pathFromBase -folderPath $folderPath -size $size -dateComplete $dateComplete
                    $null = $recordList.add($record);
                })
        
        }

        $pathFromBase = $mfileObjectVersion.docfiles.docfile.pathfrombase;
        $pathFromBaseSplit = $pathFromBase.split('\');
        $pathFromBaseSliced = $pathFromBaseSplit[2..$($pathFromBaseSplit.count - 1)];
        $fileName = "$dateComplete-$($pathFromBaseSplit[$pathFromBaseSplit.count - 1].split('.')[0])";
        
        $pathFromRoot = $folderPath + '\' + $($pathFromBaseSliced -join '\')

        $size = $mfileObjectVersion.docfiles.size#>
    })
    

    return $recordList; #@{'PathOnClient'=$pathFromRoot; 'Class'=$className; 'DateComplete'=$dateComplete; 'Name'=$fileName} #New-Object psobject -Property @{'PathOnClient'=$pathFromRoot; 'Class'=$className; 'DateComplete'=$dateComplete; 'Name'=$fileName}
}

#main
Function generateUploadCsvForContentVer
{
    param($metaDataDir, $fileRoot, $vaultFolderCSVPath)

    $accountsPath = 'C:\Users\dcurtin\Desktop\Account exports\Retirement_accounts.csv';
    $accountCsv = Import-csv -Path $accountsPath;
    #$accountsNameToIdMap=$null;
    [System.Collections.ArrayList] $recordsCsv = @();
    [System.Collections.ArrayList] $recordsCsvToBig = @();
    [System.Collections.ArrayList] $recordsCsvNoAccount = @();
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
    $someNum = 0;
    Get-ChildItem -Path $metaDataDir -Filter 'Content*.xml' | ForEach-Object -Process ({
        [xml]$currentContentDocument = Get-Content $_.FullName;
        #echo $currentContentDocument.content.object;
        $currentContentDocument.content.object | ForEach-Object -Process ({
            
            $path = handleVaultFolderMapping -object $_ -fileRoot $fileRoot -vaultFolderCSV $vaultFolderCSV -vaultFolderCSVPath $vaultFolderCSVPath

            <#$vaultId = $_.objidOriginal.vault;

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
                
                #return $folderPath;
                $path = $folderPath;
            }
            #return $vaultFolderCSV[$vaultIdIndex].folderPath;    
            $path = $vaultFolderCSV[$vaultIdIndex].folderPath;#
            #>
            $recordList = parseMFileObject -mfileObject $_ -folderPath $path
            
            $recordMapOfLists = mapFirstPublisherLocationAndNameFile -recordList $recordList -accountMap $accountsNameToIdMap

            #Write-Host $recordMapOfLists['mappedRecords'].Class;
            $recordMapOfLists['mappedRecords'] | ForEach-Object -Process ({
                #Write-Host $_.Size
                if($_.PathOnClient -match '.css' -or $_.PathOnClient -match '.gif')
                {
                    return;
                }


                if([int]$_.Size -ge 30000000)
                {
                    $null = $recordsCsvToBig.add($(New-Object Psobject -Property $_));
                }else
                {
                    $null = $recordsCsv.add($(New-Object Psobject -Property $_));
                }
            })
            $recordsCsvNoAccount=$recordMapOfLists['nonMappedRecords'];
            <#
                Decide which object is related
            
            #$record = mapFirstPublisherLocationAndNameFile -recordMap $record -accountMap $accountCsv

            if($record['Class'] -eq 'Legacy Document')
            {
                #Add-Member -NotePropertyName 'Type' -NotePropertyValue 'Legacy Document' -InputObject $psobject
            
               if($record['Name'] -match '\d{7}')
                {
                    $accountName = $matches[0];
            
                    $accountId = $accountsNameToIdMap[$accountName];
                    if($accountId -eq $null)
                    {
                        #could not map
                        $null = $recordsCsvNoAccount.add($(New-Object Psobject -Property $record));
                    }

                    $record.add('FirstPub', $accountId);
                    #$null = $recordsCsv.add($(New-Object Psobject -Property $record));
                }
            }
            try {
            #Write-Host $record['Size']
            if([int]$($record['Size']) -ge 30000000)
            {
                #Write-Host $record['Size']
                $null = $recordsCsvToBig.add($(New-Object Psobject -Property $record));
            }else
            {
                $null = $recordsCsv.add($(New-Object Psobject -Property $record));
            }
            }catch
            {
                Write-Host $record.Values
            }

            #$recordsCsv.add($(New-Object Psobject -Property $record));
            #echo $record;
            
            #>
            $someNum++;
            
            if($someNum % 1000 -eq 0)
            {
                echo $someNum;    
            }
            #$record = mapFirstPublisherLocationAndNameFile -recordMap $record -accountMap $accountsNameToIdMap
            #$null = $recordsCsv.add($(New-Object Psobject -Property $record));
        })
    })

    $recordsCsv | Export-Csv -Path C:\Users\dcurtin\Desktop\testCsv.csv -NoTypeInformation
    $recordsCsvNoAccount | Export-Csv -Path C:\Users\dcurtin\Desktop\noAccounttestCsv.csv -NoTypeInformation
    $recordsCsvToBig | Export-Csv -Path C:\Users\dcurtin\Desktop\ToBigtestCsv.csv -NoTypeInformation
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