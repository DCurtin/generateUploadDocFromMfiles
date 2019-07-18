Function addUniqueRecordsToList {
    param($recordsMap)

    if($recordsMap['Transaction'].count -ne 0)
    {
        return @{'records'=$recordsMap['Transaction']; 'nameField'='transName'; 'type'='Transaction'}
    }

    if($recordsMap['RE Transaction'].count -ne 0)
    {
        return @{'records'=$recordsMap['RE Transaction']; 'nameField'='reTransName'; 'type'='RE Transaction'}
    }

    if($recordsMap['CUSIP'].count -ne 0)
    {
        return @{'records'=$recordsMap['CUSIP']; 'nameField'='assetName'; 'type'='CUSIP'}
    }

    if($recordsMap['Account'].count -ne 0)
    {
        return @{'records'=$recordsMap['Account']; 'nameField'='accountName'; 'type'='Account'}
    }
    return $null;
}
#@{'PathOnClient'=$pathFromRoot; 'VersionData'=$pathFromRoot; 'Class'=$className; 'Title'=$fileName; 'Size'=$size; 'dateComplete'=$dateComplete; 'accountName'=$accountName; 'transName'=$transName; 'reTransName'=$reTransName; 'assetName'=$assetName;} #New-Object psobject -Property @{'PathOnClient'=$pathFromRoot; 'Class'=$className; 'DateComplete'=$dateComplete; 'Name'=$fileName
Function mapAccount
{
    param($recordsMap, $recordLookupMaps, $mappedList, $noMappingList)

    if($recordsMap['Account'].count -ne 0)
    {
        mapRecordMap -recordsMap $recordsMap -fieldName 'accountName' -objectType 'Account' -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList
    }else
    {
        $recordListFieldNameAndType = addUniqueRecordsToList -recordsMap $recordsMap

        if($recordListFieldNameAndType -ne $null){
            mapRecordMap -recordsMap $recordListFieldNameAndType['records'] -objectType $recordListFieldNameAndType['type'] -fieldName $recordListFieldNameAndType['nameField'] -recordLookupMaps $recordLookupMaps -mappedLis $mappedList -noMappingList $noMappingList

            $recordListFieldNameAndType['records'] | ForEach-Object -Process ({ 
                mapObject -object $_ -objectName $_[$recordListFieldNameAndType['nameField']] -objectNameMap $recordLookupMaps[$recordListFieldNameAndType['type']] -mappedList $mappedList -noMappingList $noMappingList
                })
        }
        else{
            $recordsMap.Paths | ForEach-Object -Process ({
                $null=$canNotMap.add(@{'Class'=$recordsMap['Class']; 'Path'=$_.fullPath}); 
            })
        }
    }
}

Function mapObject
{
    param($object, $objectName, $objectNameMap, $mappedList, $noMappingList)

    if($objectName -ne '' -and $objectName -ne $null -and $objectNameMap.ContainsKey($objectName))
    {
        #$accountName = $matches[0];
        $objectId = $objectNameMap[$objectName];
        $object.add('FirstPublishLocationId', $objectId);
        $null = $mappedList.add($object);
    }else
    {
        $null = $noMappingList.add($object);
        
    }
    return;
}

Function mapRecordMap
{
    param($recordsMap, $objectType, $fieldName, $recordLookupMaps, $mappedList, $noMappingList)
    $recordsMap[$objectType] | ForEach-Object -Process ({
            mapObject -object $_ -objectName $_[$fieldName] -objectNameMap $recordLookupMaps[$objectType] -mappedList $mappedList -noMappingList $noMappingList
        })
}

Function getAccountNameFromMeta
{
    param($index, $mfileObjectVersion, $arrayList)

    #[System.Collections.ArrayList] $propertyList = @();
    #Write-Host $mfileObjectVersion.properties;
    $propertyNameString = $mfileObjectVersion.properties.property[$index].'#text';
    if(-not $($propertyNameString -match '\d{7}'))
    {
        return;
    }
    #Write-Host $propertyNameString;
    #$propertyNameStringSplit = $propertyNameString.split(';');
    $matches.Values | ForEach-Object -Process ({ $null=$arrayList.add($_);
    })
    #return [System.Collections.ArrayList] $arrayList;
}

Function getNamesFromMeta
{
    param($index, $mfileObjectVersion, $arrayList)

    #[System.Collections.ArrayList] $propertyList = @();
    #Write-Host $mfileObjectVersion.properties;
    $propertyNameString = $mfileObjectVersion.properties.property[$index].'#text';
    if($propertyNameString -eq '' -or $propertyNameString -eq $null)
    {
        return;
    }
    #Write-Host $propertyNameString;
    $propertyNameStringSplit = $propertyNameString.split(';');
    $propertyNameStringSplit | ForEach-Object -Process ({ $null=$arrayList.add($_.split(' ')[0]);
    })
    #return [System.Collections.ArrayList] $arrayList;
}

Function getFileNameAndFullPath
{
    param($folderpath, $pathFromBase, $dateComplete)

    $pathFromBaseSplit = $pathFromBase.split('\');
    $pathFromBaseSliced = $pathFromBaseSplit[2..$($pathFromBaseSplit.count - 1)];

    $fileName = '';
    if($dateComplete -ne $null -and $dateComplete -ne '')
    {
        $fileName = "$dateComplete-$($pathFromBaseSplit[$pathFromBaseSplit.count - 1].split('.')[0])";
    }else
    {
        $fileName = "$($pathFromBaseSplit[$pathFromBaseSplit.count - 1].split('.')[0])";
    }
    
    $pathFromRoot = $folderPath + '\' + $($pathFromBaseSliced -join '\')

    return @{'fileName'=$fileName; 'fullPath'=$pathFromRoot};
}

Function generateRecordAddRelatedObject
{
    param($pathFromRoot, $fileName, $className, $size, $dateComplete, $accountName='', $transName='', $reTransName, $assetName='')

    $record = [ordered] @{'PathOnClient'=$pathFromRoot; 'VersionData'=$pathFromRoot; 'Class'=$className; 'Title'=$fileName; 'Size'=$size; 'dateComplete'=$dateComplete; 'accountName'=$accountName; 'transName'=$transName; 'reTransName'=$reTransName; 'assetName'=$assetName;} #New-Object psobject -Property @{'PathOnClient'=$pathFromRoot; 'Class'=$className; 'DateComplete'=$dateComplete; 'Name'=$fileName
    return $record;
}

Function mapFirstPublisherLocationAndNameFile
{
    param($recordsMap, $classMappingCSV, $accountMap, $transactionMap, $assetMap, $reTransMap)
    $recordMapOfLists = @{};
    [System.Collections.ArrayList] $noMappingList = @();
    [System.Collections.ArrayList] $mappedList = @();
    [System.Collections.ArrayList] $driveList = @();
    [System.Collections.ArrayList] $deleteList = @();
    [System.Collections.ArrayList] $canNotMap = @();

    $recordLookupMaps = @{  'Account'=$accountMap;
                            'Transaction'=$transactionMap;
                            'CUSIP'=$assetMap;
                            'RE Transaction'=$reTransMap;};

    $classToMappingTable = @{  'Account Agreement'           ='Account';
                               'Application'                 ='Account';
                               'Change of Address'           ='Account';
                               'Change of Beneficiary'       ='Account';
                               'Fee Payment Autopay Auth'    ='Account';
                               'Fee Payment One-Time Auth'   ='Account';
                               'Fee Schedule'                ='Account';
                               'Interested Party/POA'        ='Account';
                               'Keep on File'                ='Account';
                               'Legacy Document'             ='Account';
                               'Legal Document'              ='Account';
                               'Notice Rcvd - Forward'       ='Account';
                               'Notice Sent'                 ='Account';
                               'Payment Auth Periodic'       ='Account';
                               'Resignation Docuemnts'       ='Account';
                               'Returned Mail'               ='Account';
                               'Security Deposit Account'    ='Account';
                               'Signature Card'              ='Account';
                               'Resignation Documents'       ='Account';
                               'Check Pickup Confirmation'   ='Transaction';
                               'Deposit'                     ='Transaction';
                               'Distribution Request CASH'    ='Transaction';
                               'Distribution Request IN-KIND' ='Transaction';
                               'Non-Cash Asset Change'       ='Transaction';
                               'Payment Auth One-Time'       ='Transaction';
                               'Post-Transaction Document'   ='Transaction';
                               'Purchase Authorization'      ='Transaction';
                               'Rollover In Cash'            ='Transaction';
                               'Rollover In IN-KIND'         ='Transaction';
                               'Roth Conversion'             ='Transaction';
                               'Sale Authorization'          ='Transaction';
                               'Trading/Bank Withdrawal'     ='Transaction';
                               'Transfer In CASH'            ='Transaction';
                               'Transfer In IN-KIND'         ='Transaction';
                               'Transfer Out CASH'           ='Transaction';
                               'Transfer Out IN-KIND'        ='Transaction';
                               'Default Note Authorization'  ='CUSIP';
                               'FMV: Group (Same CUSIP)'     ='CUSIP';
                               'FMV: Single Account'         ='CUSIP';
                               'Ownership Doc Copy'          ='CUSIP';
                               'Ownership Doc Original'      ='CUSIP';
                               'Cash Report'                 ='Delete';
                               'Closed Account Approval Form'='Delete';
                               'Daily Checklist'             ='Delete';
                               'Signed Checks'               ='Delete';
                               'Deposit Recurring'           ='RE Transaciton';
                               'Distribution Recurring'      ='RE Transaciton';
                               'Payment Auth Recurring'      ='RE Transaciton';
                               'Tax Correction'              ='Other';
                               'Other document'              ='Other';
                               'Document'                    ='Other';
                               'Account Approvals'           ='Drive';
                               'FMV: Brokerage Statements'   ='Drive';
                               'FMV: Bulk Processing'        ='Drive';
                               'Original Transmittal Report' ='Drive';
                               'Payment Auth Bulk Process'   ='Drive';
                               'TNET Posting'                ='Drive';}

$classToTypeMappingTable = @{  'Account Agreement'           ='Legacy Document';
                               'Application'                 ='Application';
                               'Change of Address'           ='Change of Address';
                               'Change of Beneficiary'       ='Change of Benficiary';
                               'Fee Payment Autopay Auth'    ='Fee Payment Autopay Auth';
                               'Fee Payment One-Time Auth'   ='Fee Payment One-Time Auth';
                               'Fee Schedule'                ='Fee Schedule';
                               'Interested Party/POA'        ='Interested Party/POA';
                               'Keep on File'                ='Keep on File';
                               'Legacy Document'             ='Legacy Document';
                               'Legal Document'              ='Legal Document';
                               'Notice Rcvd - Forward'       ='Notice Rcvd - Forward';
                               'Notice Sent'                 ='Notice Sent';
                               'Payment Auth Periodic'       ='Payment Auth Periodic';
                               'Resignation Docuemnts'       ='Resignation Docuemnts';
                               'Returned Mail'               ='Returned Mail';
                               'Security Deposit Account'    ='Transaction Doc';
                               'Signature Card'              ='Signature Card';
                               'Check Pickup Confirmation'   ='Check Pickup Confirmation';
                               'Deposit'                     ='Transaction Doc';
                               'Distribution Request CASH'   ='Transaction Doc';
                               'Distribution Request IN-KIND'='Transaction Doc';
                               'Non-Cash Asset Change'       ='Transaction Doc';
                               'Payment Auth One-Time'       ='Transaction Doc';
                               'Post-Transaction Document'   ='Transaction Doc';
                               'Purchase Authorization'      ='Transaction Doc';
                               'Rollover In Cash'            ='Transaction Doc';
                               'Rollover In IN-KIND'         ='Transaction Doc';
                               'Roth Conversion'             ='Transaction Doc';
                               'Sale Authorization'          ='Transaction Doc';
                               'Trading/Bank Withdrawal'     ='Transaction Doc';
                               'Transfer In CASH'            ='Transaction Doc';
                               'Transfer In IN-KIND'         ='Transaction Doc';
                               'Transfer Out CASH'           ='Transaction Doc';
                               'Transfer Out IN-KIND'        ='Transaction Doc';
                               'Default Note Authorization'  ='Default Note Auth';
                               'FMV: Group (Same CUSIP)'     ='CUSIP';
                               'FMV: Single Account'         ='FMV';
                               'Ownership Doc Copy'          ='Ownership Doc Copy';
                               'Ownership Doc Original'      ='Ownership Doc Original';
                               'Cash Report'                 ='Delete';
                               'Closed Account Approval Form'='Delete';
                               'Daily Checklist'             ='Delete';
                               'Signed Checks'               ='Delete';
                               'Deposit Recurring'           ='Recurring Transaction Doc';
                               'Distribution Recurring'      ='Recurring Transaction Doc';
                               'Payment Auth Recurring'      ='Recurring Transaction Doc';
                               'Tax Correction'              ='Tax Correction';
                               'Other document'              ='Other Document';
                               'Document'                    ='Other Document';
                               'Account Approvals'           ='Drive';
                               'FMV: Brokerage Statements'   ='Drive';
                               'FMV: Bulk Processing'        ='Drive';
                               'Original Transmittal Report' ='Drive';
                               'Payment Auth Bulk Process'   ='Drive';
                               'TNET Posting'                ='Drive';}

    #Write-Host $recordList;
    #$recordsMap

    #if($_ -eq $null)
    #{
    #    return;
    #}
    #Write-Host $_.values

    if($recordsMap['Paths'] -eq $null -or $recordsMap['Paths'].count -eq 0)
    {
        $null = $recordMapOfLists.add('mappedRecords', $mappedList);
        $null = $recordMapOfLists.add('nonMappedRecords', $noMappingList);
        $null = $recordMapOfLists.add('driveList',$driveList);
        $null = $recordMapOfLists.add('deleteList',$deleteList);
        $null = $recordMapOfLists.add('unmappable', $canNotMap);

        return $recordMapOfLists;
    }

    <#if($recordsMap['Paths'].fullPath -match '0\\0-999\\45\\L\\L\\0231290 Beckley Distribution Request IN-KIND 264635 (ID 45)\\FMV.pdf')
    {
        write-host 'path'
    }#>


    if($recordsMap['Class'] -eq 'Legacy Document')
    {
        $recordsMap['Account'] | ForEach-Object -Process ({
        #Add-Member -NotePropertyName 'Type' -NotePropertyValue 'Legacy Document' -InputObject $psobject
    
            if($_.Title -match '\d{7}' -and $accountMap.ContainsKey($matches[0]))
            {
                #Write-Host $_.Title
                $accountName = $matches[0];

                $accountId = $accountMap[$accountName];
                $_.add('FirstPublishLocationId', $accountId);
                $null = $mappedList.add($_);
            }else
            {
                #Write-Host 'No Account'
                $null = $noMappingList.add($_);
            }
        })
    }

    #Write-Host $_.Class

    #return;
    $type  = $classToTypeMappingTable[$recordsMap['Class']];
    $mappingObject = $classToMappingTable[$recordsMap['Class']];

    if($mappingObject -eq 'Account')
    {

        mapAccount -recordsMap $recordsMap -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMapList $canNotMap

        <#if($recordsMap['Account'].count -ne 0)
        {
            $recordsMap['Account'] | ForEach-Object -Process ({
                mapObject -object $_ -objectName $_.accountName -objectNameMap $accountMap -mappedList $mappedList -noMappingList $noMappingList
            })
        }else
        {
            $recordListFieldNameAndType = addUniqueRecordsToList -recordsMap $recordsMap

            if($recordListFieldNameAndType -ne $null){
                $recordListFieldNameAndType['records'] | ForEach-Object -Process ({ 
                    mapObject -object $_ -objectName $_[$recordListFieldNameAndType['nameField']] -objectNameMap $recordLookupMaps[$recordListFieldNameAndType['type']] -mappedList $mappedList -noMappingList $noMappingList
                    })
            }
            else{
                $recordsMap.Paths | ForEach-Object -Process ({
                    $null=$canNotMap.add(@{'Class'=$recordsMap['Class']; 'Path'=$_.fullPath}); 
                })
            }
        }#>
        
        #mapObject -object $_ -objectName $_.accountName -objectNameMap $accountMap -mappedList $mappedList -noMappingList $noMappingList
        #return;
    }

    if($mappingObject -eq 'Transaction')
    {
        if($recordsMap['Transaction'].count -ne 0)
        {
            $recordsMap['Transaction'] | ForEach-Object -Process ({
                mapObject -object $_ -objectName $_.transName -objectNameMap $transactionMap -mappedList $mappedList -noMappingList $noMappingList
            })
        }else
        {

            if($recordsMap['Class'] -eq 'Distrubtion Request IN-KIND')
            {
                Write-Host 'test'
            }
            $recordListFieldNameAndType = addUniqueRecordsToList -recordsMap $recordsMap

            if($recordListFieldNameAndType -ne $null){
                $recordListFieldNameAndType['records'] | ForEach-Object -Process ({ 
                    mapObject -object $_ -objectName $_[$recordListFieldNameAndType['nameField']] -objectNameMap $recordLookupMaps[$recordListFieldNameAndType['type']] -mappedList $mappedList -noMappingList $noMappingList
                    })
            }
            else{
                $recordsMap.Paths | ForEach-Object -Process ({
                    $null=$canNotMap.add(@{'Class'=$recordsMap['Class']; 'Path'=$_.fullPath}); 
                })
            }
        }
        
        #mapObject -object $_ -objectName $_.accountName -objectNameMap $accountMap -mappedList $mappedList -noMappingList $noMappingList
        #return;
    }

    if($mappingObject -eq 'CUSIP')
    {
        if($recordsMap['CUSIP'].count -ne 0)
        {
            $recordsMap['CUSIP'] | ForEach-Object -Process ({
                mapObject -object $_ -objectName $_.assetName -objectNameMap $assetMap -mappedList $mappedList -noMappingList $noMappingList
            })
        }else
        {
            $recordListFieldNameAndType = addUniqueRecordsToList -recordsMap $recordsMap

            if($recordListFieldNameAndType -ne $null){
                $recordListFieldNameAndType['records'] | ForEach-Object -Process ({ 
                    mapObject -object $_ -objectName $_[$recordListFieldNameAndType['nameField']] -objectNameMap $recordLookupMaps[$recordListFieldNameAndType['type']] -mappedList $mappedList -noMappingList $noMappingList
                    })
            }
            else{
                $recordsMap.Paths | ForEach-Object -Process ({
                    $null=$canNotMap.add(@{'Class'=$recordsMap['Class']; 'Path'=$_.fullPath}); 
                })
            }
        }
        
        #mapObject -object $_ -objectName $_.accountName -objectNameMap $accountMap -mappedList $mappedList -noMappingList $noMappingList
        #return;
    }

    if($mappingObject -eq 'RE Transaciton')
    {
        if($recordsMap['RE Transaciton'].count -ne 0)
        {
            $recordsMap['RE Transaciton'] | ForEach-Object -Process ({
                mapObject -object $_ -objectName $_.reTransName -objectNameMap $reTransMap -mappedList $mappedList -noMappingList $noMappingList
            })
        }else
        {
            $recordListFieldNameAndType = addUniqueRecordsToList -recordsMap $recordsMap

            if($recordListFieldNameAndType -ne $null){
                $recordListFieldNameAndType['records'] | ForEach-Object -Process ({ 
                    mapObject -object $_ -objectName $_[$recordListFieldNameAndType['nameField']] -objectNameMap $recordLookupMaps[$recordListFieldNameAndType['type']] -mappedList $mappedList -noMappingList $noMappingList
                    })
            }
            else{
                $recordsMap.Paths | ForEach-Object -Process ({
                    $null=$canNotMap.add(@{'Class'=$recordsMap['Class']; 'Path'=$_.fullPath}); 
                })
            }
        }
        
        #mapObject -object $_ -objectName $_.accountName -objectNameMap $accountMap -mappedList $mappedList -noMappingList $noMappingList
        #return;
    }

    if($mappingObject -eq 'Other')
    {
        if($recordsMap['Account'].count -ne 0)
        {
            $recordsMap['Account'] | ForEach-Object -Process ({
                mapObject -object $_ -objectName $_.accountName -objectNameMap $accountMap -mappedList $mappedList -noMappingList $noMappingList
            })
        }

        if($recordsMap['RE Transaciton'].count -ne 0)
        {
            $recordsMap['RE Transaciton'] | ForEach-Object -Process ({
                mapObject -object $_ -objectName $_.reTransName -objectNameMap $reTransMap -mappedList $mappedList -noMappingList $noMappingList
            })
        }

        if($recordsMap['Transaction'].count -ne 0)
        {
            $recordsMap['Transaction'] | ForEach-Object -Process ({
                mapObject -object $_ -objectName $_.transName -objectNameMap $transactionMap -mappedList $mappedList -noMappingList $noMappingList
            })
        }

        if($recordsMap['CUSIP'].count -ne 0)
        {
            $recordsMap['CUSIP'] | ForEach-Object -Process ({
                mapObject -object $_ -objectName $_.assetName -objectNameMap $assetMap -mappedList $mappedList -noMappingList $noMappingList
            })
        }
        #mapObject -object $_ -objectNameMap 
        #return;
    }

    if($mappingOjbect -eq 'Delete')
    {
        $deleteList = $(addUniqueRecordsToList -recordsMap $recordsMap)['records'];
    }

    if($mappingOjbect -eq 'Drive')
    {
        $deleteList = $(addUniqueRecordsToList -recordsMap $recordsMap)['records'];
    }

    if($mappingObject -eq '' -or $mappingObject -eq $null)
    {

        $recordsMap.Paths | ForEach-Object -Process ({
            $null = $canNotMap.add(@{'Class'=$recordsMap['Class']; 'Path'=$_.fullPath}); 
        })
        
    }

    $null = $recordMapOfLists.add('mappedRecords', $mappedList);
    $null = $recordMapOfLists.add('nonMappedRecords', $noMappingList);
    $null = $recordMapOfLists.add('driveList',$driveList);
    $null = $recordMapOfLists.add('deleteList',$deleteList);
    $null = $recordMapOfLists.add('unmappable', $canNotMap);

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
        
        $null = $vaultFolderCSV.add($(New-Object psobject -Property @{'vaultId'=$vaultId; 'folderName'=$vaultRename; 'folderPath'=$folderPath}));
        
        $cleanedId = $vaultId.Substring(1,$vaultId.Length-2);
        
        Rename-Item -Force -Path "$fileRoot\Files\$cleanedId" -NewName $vaultRename;
        $vaultFolderCSV | Export-Csv -Path $vaultFolderCSVPath -NoTypeInformation;
        
        return $folderPath;
    }
    return $vaultFolderCSV[$vaultIdIndex].folderPath;    
}


Function parseMFileObject{
    param($mfileObject, $folderPath)
    

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
        getAccountNameFromMeta -index $accountNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $accountList;
        #Write-Host $accountList.Count
    }

    [System.Collections.ArrayList] $assetList = @();
    $assetNameIndex = $mfileObjectVersion.properties.property.name.IndexOf('Asset'); 
    if($assetNameIndex -ne -1)
    {
        getNamesFromMeta -index $assetNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $assetList
    }

    [System.Collections.ArrayList] $reTransList = @();
    $reTransNameIndex = $mfileObjectVersion.properties.property.name.IndexOf('Recurring Transaction'); 
    if($reTransNameIndex -ne -1)
    {
        getNamesFromMeta -index $reTransNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $reTransList
    }

    [Hashtable]$recordsMap = @{};
    $recordsMap.add('Class', $className);
    $recordsMap.add('Transaction', [System.Collections.ArrayList] @());
    $recordsMap.add('RE Transaciton', [System.Collections.ArrayList] @());
    $recordsMap.add('Account', [System.Collections.ArrayList] @());
    $recordsMap.add('CUSIP', [System.Collections.ArrayList] @());
    $recordsMap.add('Paths', [System.Collections.ArrayList] @());

    $docfiles = @($mfileObjectVersion.docfiles.docfile);
    $noDocFile = 0;
    $docfiles | ForEach-Object -Process (
    {
        if($_ -eq $null)
        {
            $noDocFile +=1;
            #Write-Host $noDocFile
            return;
        }

        $pathFromRoot = getFileNameAndFullPath -pathFromBase $_.pathfrombase -folderpath $folderPath  -dateComplete $dateComplete

        $null = $recordsMap['Paths'].add($pathFromRoot);

        $size = $_.Size

        if($accountList.count -ne 0){ 
            $accountList | ForEach-Object -Process ({
                $record = generateRecordAddRelatedObject -accountName $_ -className $className -pathFromRoot $pathFromRoot.fullPath -size $size -dateComplete $dateComplete
                $null = $recordsMap['Account'].add($record);
            })
        }

        if($transactionList.count -ne 0){
            $transactionList | ForEach-Object -Process ({
                    $record = generateRecordAddRelatedObject -transName $_ -className $className -pathFromRoot $pathFromRoot.fullPath -size $size -dateComplete $dateComplete
                    $null = $recordsMap['Transaction'].add($record);
                })
        
        }
        
        if($assetList.count -ne 0){
            $assetList | ForEach-Object -Process ({
                    $record = generateRecordAddRelatedObject -assetName $_ -className $className -pathFromRoot $pathFromRoot.fullPath -size $size -dateComplete $dateComplete
                    $null = $recordsMap['CUSIP'].add($record);
                })
        
        }

        if($reTransList.count -ne 0){
            $reTransList | ForEach-Object -Process ({
                    $record = generateRecordAddRelatedObject -reTransName $_ -className $className -pathFromRoot $pathFromRoot.fullPath -size $size -dateComplete $dateComplete
                    $null = $recordsMap['RE Transaciton'].add($record);
                })
        }

        <#$pathFromBase = $mfileObjectVersion.docfiles.docfile.pathfrombase;
        $pathFromBaseSplit = $pathFromBase.split('\');
        $pathFromBaseSliced = $pathFromBaseSplit[2..$($pathFromBaseSplit.count - 1)];
        $fileName = "$dateComplete-$($pathFromBaseSplit[$pathFromBaseSplit.count - 1].split('.')[0])";
        
        $pathFromRoot = $folderPath + '\' + $($pathFromBaseSliced -join '\')

        $size = $mfileObjectVersion.docfiles.size#>
    })
    $null = $recordsMap.add('nullDoc', $noDocFile);

    return [hashtable] $recordsMap; #@{'PathOnClient'=$pathFromRoot; 'Class'=$className; 'DateComplete'=$dateComplete; 'Name'=$fileName} #New-Object psobject -Property @{'PathOnClient'=$pathFromRoot; 'Class'=$className; 'DateComplete'=$dateComplete; 'Name'=$fileName}
}

#main
Function generateUploadCsvForContentVer
{
    param($metaDataDir, $fileRoot, $vaultFolderCSVPath)

    $accountsPath = 'C:\Users\dcurtin\Desktop\Account exports\Retirement_accounts.csv';
    $transactionsPath = 'C:\Users\dcurtin\Desktop\Account exports\transactions.csv';
    $reTransactionPath = 'C:\Users\dcurtin\Desktop\Account exports\reTransactions.csv';
    $assetsPath = 'C:\Users\dcurtin\Desktop\Account exports\asset.csv';

    Write-Host 'Importing Accounts';
    $accountCsv = Import-csv -Path $accountsPath;
    
    Write-Host 'Importing Transactions';
    $transactionsCSV = Import-csv -Path $transactionsPath;

    Write-Host 'Importing RE-Transactions';
    $reTransactionCSV = Import-Csv -Path $reTransactionPath;

    Write-Host 'Importing Assets';
    $assetsCSV = Import-Csv -Path $assetsPath;

    #~~~~~~~~~~~~~~~~~~~~~~~
    $accountsNameToIdMap = @{};
    echo 'Generating Accounts Map';
    $accountCsv.ForEach({$accountsNameToIdMap.add($_.Name, $_.Id)}) >$null;

    $transactionsNameToIdMap = @{};
    echo 'Generating Transactions Map';
    $transactionsCSV.ForEach({$transactionsNameToIdMap.add($_.Name, $_.Id)}) >$null;

    $reTransactionsNameToIdMap = @{};
    echo 'Generating RE-Transactions Map';
    $reTransactionCSV.ForEach({$reTransactionsNameToIdMap.add($_.Name, $_.Id)}) >$null;

    $assetNameToIdMap = @{};
    echo 'Generating asset Map';
    $assetsCSV.ForEach({$assetNameToIdMap.add($_.Name, $_.Id)}) >$null;
    #~~~~~~~~~~~~~~~~~~~~~~~

    #$accountsNameToIdMap=$null;
    [System.Collections.ArrayList] $recordsCsv = @();
    [System.Collections.ArrayList] $recordsCsvToBig = @();
    [System.Collections.ArrayList] $recordsCsvNoAccount = @();
    [System.Collections.ArrayList] $googleDriveCSV = @();
    [System.Collections.ArrayList] $deleteCSV = @();
    [System.Collections.ArrayList] $unMappable = @();
    

    
    
    $pathFolder1 = 'F:\M-Files Exports\Trust Archive\folder\Files';
    $pathFolder2 = 'F:\M-Files Exports\Trust Archive\folder\Files\folder2';
    $indexCount = 0;
    
    $csvOfFiles = @();
    echo 'Getting all Pdfs';

    [System.Collections.ArrayList] $vaultFolderCSV = @();
    if([System.IO.File]::Exists($vaultFolderCSVPath))
    {
        $vaultFolderCSV = @(Import-Csv $vaultFolderCSVPath);
    }
    $someNum = 0;
    $noDocs = 0;
    Get-ChildItem -Path $metaDataDir -Filter 'Content*.xml' | ForEach-Object -Process ({
        [xml]$currentContentDocument = Get-Content $_.FullName;
        #echo $currentContentDocument.content.object;
        $currentContentDocument.content.object | ForEach-Object -Process ({
            
            $path = handleVaultFolderMapping -object $_ -fileRoot $fileRoot -vaultFolderCSV $vaultFolderCSV -vaultFolderCSVPath $vaultFolderCSVPath

            $recordsMap = parseMFileObject -mfileObject $_ -folderPath $path

            $noDocs += $recordsMap['nullDoc'];
            
            $recordMapOfLists = mapFirstPublisherLocationAndNameFile -recordsMap $recordsMap -accountMap $accountsNameToIdMap -transactionMap $transactionsNameToIdMap -reTransMap $reTransactionsNameToIdMap -assetMap $assetNameToIdMap

            #Write-Host $recordMapOfLists['mappedRecords'].Class;
            try{
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
                    #write-host $_
                    $null = $recordsCsv.add($(New-Object Psobject -Property $_));
                }
            })}
            catch{
                Write-Host 'Error'
            }

            if($recordMapOfLists['nonMappedRecords'].count -ne 0)
            {
                $recordMapOfLists['nonMappedRecords'] | ForEach-Object -Process ({
                    $null = $recordsCsvNoAccount.add($(New-Object Psobject -Property $_));
                })
                #Write-host $recordsCsvNoAccount
                #$recordsCsvNoAccount += @($recordMapOfLists.nonMappedRecords);
            }

            if($recordMapOfLists['driveList'].count -ne 0)
            {
                $recordMapOfLists['driveList'] | ForEach-Object -Process ({
                        $null = $googleDriveCSV.add($(New-Object psobject -Property $_));
                    })
            }
            
            if($recordMapOfLists['deleteList'].count -ne 0)
            {
                $recordMapOfLists['deleteList'] | ForEach-Object -Process ({
                        $null = $deleteCSV.add($(New-Object psobject -Property $_));
                    })
            }

            if($recordMapOfLists['unmappable'].count -ne 0)
            {
                $recordMapOfLists['unmappable'] | ForEach-Object -Process ({
                        $null = $unMappable.add($(New-Object psobject -Property $_));
                    })
            }

            $someNum++;
            
            if($someNum % 1000 -eq 0)
            {
                echo 'Records processed' $someNum;    
                echo 'Null docs' $noDocs;
            }
        })
        
    })

    $recordsCsv | Export-Csv -Path C:\Users\dcurtin\Desktop\testCsv.csv -NoTypeInformation
    $recordsCsvNoAccount | Export-Csv -Path C:\Users\dcurtin\Desktop\noAccounttestCsv.csv -NoTypeInformation
    $recordsCsvToBig | Export-Csv -Path C:\Users\dcurtin\Desktop\ToBigtestCsv.csv -NoTypeInformation
    $googleDriveCSV | Export-Csv -Path C:\Users\dcurtin\Desktop\googleDrive.csv -NoTypeInformation
    $deleteCSV | Export-Csv -Path C:\Users\dcurtin\Desktop\deleteCsv.csv -NoTypeInformation
    $unMappable | Export-Csv -Path C:\Users\dcurtin\Desktop\unMappable.csv -NoTypeInformation

}