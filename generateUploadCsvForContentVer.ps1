
Function addUniqueRecordsToList {
    param($recordsMap)

    if($recordsMap['Transaction'].count -ne 0)
    {
        return @{'records'=$recordsMap['Transaction']; 'fieldName'='transName'; 'type'='Transaction'}
    }

    if($recordsMap['RE Transaction'].count -ne 0)
    {
        return @{'records'=$recordsMap['RE Transaction']; 'fieldName'='reTransName'; 'type'='RE Transaction'}
    }

    if($recordsMap['CUSIP'].count -ne 0)
    {
        return @{'records'=$recordsMap['CUSIP']; 'fieldName'='assetName'; 'type'='CUSIP'}
    }

    if($recordsMap['Account'].count -ne 0)
    {
        return @{'records'=$recordsMap['Account']; 'fieldName'='accountName'; 'type'='Account'}
    }
    # 'accountName'=$accountName; 'transName'=$transName; 'reTransName'=$reTransName;
    return $null;
}

Function mapAccountToId
{
    param($recordType, $type, $recordsMap, $recordLookupMaps, $mappedList, $noMappingList, $canNotMap)
    mapObjectMapToId -recordType $recordType -objectType 'Account' -fieldName 'accountName' -recordsMap $recordsMap -type $type -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMap $canNotMap
}

Function mapAssettToId
{
    param($recordType, $type, $recordsMap, $recordLookupMaps, $mappedList, $noMappingList, $canNotMap)
    mapObjectMapToId -recordType $recordType -objectType 'CUSIP' -fieldName 'assetName' -recordsMap $recordsMap -type $type -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMap $canNotMap
}

Function mapRETransactionToId
{
    param($recordType, $type, $recordsMap, $recordLookupMaps, $mappedList, $noMappingList, $canNotMap)
    mapObjectMapToId -recordType $recordType -objectType 'RE Transaction' -fieldName 'reTransName' -recordsMap $recordsMap -type $type -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMap $canNotMap
}

Function mapTransactionToId
{
    param($recordType, $type, $recordsMap, $recordLookupMaps, $mappedList, $noMappingList, $canNotMap)
    try{
        mapObjectMapToId -recordType $recordType -objectType 'Transaction' -fieldName 'transName' -recordsMap $recordsMap  -type $type -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMap $canNotMap
        }catch
        {
            write-host 'thing'
        }
}

Function mapObjectMapToId
{
    param($recordType, $type, $objectType, $fieldName, $recordsMap, $recordLookupMaps, $mappedList, $noMappingList, $canNotMap)

    if($recordsMap[$objectType].count -ne 0)
    {
        mapRecordMapToId -recordsMap $recordsMap -type $type -fieldName $fieldName -assignedTo $recordsMap['AssignToName'] -dateComplete $recordsMap['dateComplete'] -status $recordsMap['status'] -state $recordsMap['state'] -objectType $objectType -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList
    }else
    {
        $recordListFieldNameAndType = addUniqueRecordsToList -recordsMap $recordsMap

        if($recordListFieldNameAndType -ne $null){
            mapObjectListToId -recordList $recordListFieldNameAndType['records'] -objectType $recordListFieldNameAndType['type'] -type $type -fieldName $recordListFieldNameAndType['fieldName'] -assignedTo $recordsMap['AssignToName'] -dateComplete $recordsMap['dateComplete'] -status $recordsMap['status'] -state $recordsMap['state'] -recordLookupMaps $recordLookupMaps -mappedLis $mappedList -noMappingList $noMappingList
        }
        else{
            addToCannotMap -recordsMap $recordsMap -canNotMap $canNotMap -type $type
        }
    }
}

Function addToCannotMap
{
    param($recordsMap, $canNotMap, $type)
    $recordsMap.Paths | ForEach-Object -Process ({
        $object = @{};
        $null = $object.add('Class', $recordsMap['Class']);
        $null = $object.add('Status', $recordsMap['Status']);
        $null = $object.add('AssignToName', $recordsMap['AssignToName']);
        $null = $object.add('Type', $type);
        $null = $object.add('Path',$_.fullPath);
        $null = $object.add('dateComplete', $recordsMap['dateComplete']);
        $null=$canNotMap.add($object); 
    })
}

Function mapRecordMapToId
{
    param($recordsMap, $type, $objectType, $fieldName, $assignedTo, $dateComplete, $status, $state, $recordLookupMaps, $mappedList, $noMappingList)
    mapObjectListToId -recordList $recordsMap[$objectType] -objectType $objectType -type $type -fieldName $fieldName -assignedTo $assignedTo -dateComplete $dateComplete -status $status -state $state -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList
}

Function mapObjectListToId
{
    param($recordList, $objectType, $type, $assignedTo, $dateComplete, $status, $state, $fieldName, $recordLookupMaps, $mappedList, $noMappingList)

    $recordList | ForEach-Object -Process ({

            if($_[$fieldName] -eq '' -or $_[$fieldName] -eq $null)
            {
                #Write-Host $_.values
                $callstack = get-pscallstack
                Write-Host '*~~~~*'
                Write-Host $callstack
                Write-Host '~~~~'
                write-host $recordList.keys;
                Write-Host '~~~~'
                write-host $recordList.values;
                Write-Host '~~~~'
                write-host $fieldName;
                Write-Host '*~~~~*'
            }
            $team = '';
            $userId = '';
            if($($assignedTo -match 'Sales Team') -or $($assignedTo -match 'Processors') -or $($assignedTo -match 'Secure Uploads'))
            {
                $team = $assignedTo;
            }else
            {
                if($assignedTo -ne $null)
                {
                    $userId = $recordLookupMaps['User'][$assignedTo];
                    if($userId -eq '')
                    {
                        write-host($assignedTo);
                    }
                }
            }

            mapObjectToId -object $_ -type $type -objectName $_[$fieldName] -team $team -userId $userId -dateComplete $dateComplete -status $status -state $state -objectNameMap $recordLookupMaps[$objectType] -mappedList $mappedList -noMappingList $noMappingList
        })
}

Function mapObjectToId
{
    param($object, $type, $objectName, $team, $userId, $dateComplete, $status, $state, $objectNameMap, $mappedList, $noMappingList)
    
    $null = $object.add('Type', $type);
    $null = $object.add('Status', $status);
    $null = $object.add('State', $state);
    $null = $object.add('AssignedToUserId', $userId);
    $null = $object.add('Team', $team);
    #$null = $object.add('dateComplete', $dateComplete)
   
    if($objectName -ne '' -and $objectName -ne $null -and $objectNameMap.ContainsKey($objectName))
    {
        #$accountName = $matches[0];
        $objectId = $objectNameMap[$objectName];
        $null = $object.add('FirstPublishLocationId', $objectId);
        #$null = $object.add('Type', $type);
        #$null = $object.add('Status', $status);
        #$null = $object.add('State', $state);
        #$null = $object.add('AssignedToUserId', $userId);
        #$null = $object.add('Team', $team);
        $null = $mappedList.add($object);
       
    }else
    {
        
        $null = $noMappingList.add($object);   
    }
     
    return;
}



Function getAccountNameFromMeta
{
    param($index, $mfileObjectVersion, $arrayList)

    #[System.Collections.ArrayList] $propertyList = @();
    #Write-Host $mfileObjectVersion.properties;
    $propertyNameString = $mfileObjectVersion.properties.property[$index].'#text';


    if($propertyNameString -eq $null -or $propertyNameString -eq '')
    {
        return;
    }

    $propertyNameString.split(';') | ForEach-Object -Process ({
        if($_ -match '\d{7}')
        {
            $arrayList.add($matches[0]);
        }
    })
    return;
    #
    #if(-not $($propertyNameString -match '\d{7}'))
    #{
    #    return;
    #}
    ##Write-Host $propertyNameString;
    ##$propertyNameStringSplit = $propertyNameString.split(';');
    #$matches.Values | ForEach-Object -Process ({ $null=$arrayList.add($_);
    #})
    #
    
    #return [System.Collections.ArrayList] $arrayList;
}

Function getNamesFromMetaRegex
{
    param($index, $mfileObjectVersion, $arrayList, $regex)

    #[System.Collections.ArrayList] $propertyList = @();
    #Write-Host $mfileObjectVersion.properties;
    $propertyNameString = $mfileObjectVersion.properties.property[$index].'#text';

    
    if($propertyNameString -eq $null -or $propertyNameString -eq '')
    {
        return;
    }

    $propertyNameString.split(';') | ForEach-Object -Process ({
        if($_ -cmatch $regex)
        {
            #Write-Host $matches[0]
            $null = $arrayList.add($matches[0]);
        }
    })
    return;
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
    param($recordsMap, $usersMap, $accountMap, $transactionMap, $assetMap, $reTransMap)
    $recordMapOfLists = @{};
    [System.Collections.ArrayList] $noMappingList = @();
    [System.Collections.ArrayList] $mappedList = @();
    [System.Collections.ArrayList] $driveList = @();
    [System.Collections.ArrayList] $deleteList = @();
    [System.Collections.ArrayList] $canNotMap = @();

    $recordLookupMaps = @{  'Account'=$accountMap;
                            'Transaction'=$transactionMap;
                            'CUSIP'=$assetMap;
                            'RE Transaction'=$reTransMap;
                            'User'=$usersMap;};

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
                               'Deposit Recurring'           ='RE Transaction';
                               'Distribution Recurring'      ='RE Transaction';
                               'Payment Auth Recurring'      ='RE Transaction';
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
        mapAccountToId -recordsMap $recordsMap -type $type -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMap $canNotMap
    }

    if($mappingObject -eq 'Transaction')
    {

        mapTransactionToId -recordsMap $recordsMap -type $type -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMap $canNotMap

  
    }

    if($mappingObject -eq 'CUSIP')
    {
        mapAssettToId -recordsMap $recordsMap -type $type -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMap $canNotMap
    }

    if($mappingObject -eq 'RE Transaction')
    {
        mapRETransactionToId  -recordsMap $recordsMap -type $type -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList -canNotMap $canNotMap
    }

    if($mappingObject -eq 'Other')
    {
        $mappingCount = $($recordsMap['Account'].count) + $($recordsMap['RE Transaction'].count) + $($recordsMap['Transaction'].count) + $($recordsMap['CUSIP'].count) 

        if($recordsMap['Account'].count -ne 0)
        {
            mapRecordMapToId -recordsMap $recordsMap -type $type -objectType 'Account' -fieldName 'accountName' -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList
        }

        if($recordsMap['RE Transaction'].count -ne 0)
        {
            mapRecordMapToId -recordsMap $recordsMap -type $type -objectType 'RE Transaction' -fieldName 'reTransName' -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList
        }

        if($recordsMap['Transaction'].count -ne 0)
        {
            mapRecordMapToId -recordsMap $recordsMap -type $type -objectType 'Transaction' -fieldName 'transName' -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList
        }

        if($recordsMap['CUSIP'].count -ne 0)
        {
            mapRecordMapToId -recordsMap $recordsMap -type $type -objectType 'CUSIP' -fieldName 'assetName' -recordLookupMaps $recordLookupMaps -mappedList $mappedList -noMappingList $noMappingList
        }

        if($mappingCount -eq 0)
        {
            addToCannotMap -recordsMap $recordsMap -canNotMap $canNotMap
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
        $driveList = $(addUniqueRecordsToList -recordsMap $recordsMap)['records'];
    }

    if($mappingObject -eq '' -or $mappingObject -eq $null)
    {
        addToCannotMap -recordsMap $recordsMap -canNotMap $canNotMap   
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

    $indexOfStatus = $mfileObjectVersion.properties.property.name.IndexOf('Status');
    $status = $mfileObjectVersion.properties.property[$indexOfStatus].'#text';

    

    $indexOfState = $mfileObjectVersion.properties.property.name.IndexOf('State');
    $state = $mfileObjectVersion.properties.property[$indexOfState].'#text';

    $indexOfAssignedTo = $mfileObjectVersion.properties.property.name.IndexOf('Assigned to');
    $assignedTo = $mfileObjectVersion.properties.property[$indexOfAssignedTo].'#text';


    [System.Collections.ArrayList] $transactionList = @();
    $transactionNameIndex = $mfileObjectVersion.properties.property.name.IndexOf('Transaction');
    if($transactionNameIndex -ne -1)
    {
        getNamesFromMetaRegex -index $transactionNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $transactionList -regex 'TRANS-[0-9]{6}'
    }

    [System.Collections.ArrayList] $accountList = @();
    $accountNameIndex  = $mfileObjectVersion.properties.property.name.IndexOf('Account Name');
    if($accountNameIndex -ne -1)
    {
        getNamesFromMetaRegex -index $accountNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $accountList -regex '\d{7}';
        #Write-Host $accountList.Count
    }

    [System.Collections.ArrayList] $assetList = @();
    $assetNameIndex = $mfileObjectVersion.properties.property.name.IndexOf('Asset'); 
    if($assetNameIndex -ne -1)
    {
        getNamesFromMetaRegex -index $assetNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $assetList -regex '[A-Z0-9]{9}'
    }

    [System.Collections.ArrayList] $reTransList = @();
    $reTransNameIndex = $mfileObjectVersion.properties.property.name.IndexOf('Recurring Transaction'); 
    if($reTransNameIndex -ne -1)
    {
        getNamesFromMetaRegex -index $reTransNameIndex -mfileObjectVersion $mfileObjectVersion -arrayList $reTransList -regex 'R-\d{4}'
    }

    if($state -eq 'Active' -or $state -eq 'Posted' -or $state -eq 'Complete')
    {
        $status = 'Complete';
    }

    if($status -eq '')
    {
        $status = 'No Status'
    }

    [Hashtable]$recordsMap = @{};
    $recordsMap.add('Class', $className);
    $recordsMap.add('Transaction', [System.Collections.ArrayList] @());
    $recordsMap.add('RE Transaction', [System.Collections.ArrayList] @());
    $recordsMap.add('Account', [System.Collections.ArrayList] @());
    $recordsMap.add('CUSIP', [System.Collections.ArrayList] @());
    $recordsMap.add('Paths', [System.Collections.ArrayList] @());
    $recordsMap.add('Status', $status);
    $recordsMap.add('State', $state);
    $recordsMap.add('AssignToName', $assignedTo);
    $recordsMap.add('dateComplete', $dateComplete);

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
                $record = generateRecordAddRelatedObject -accountName $_ -fileName $pathFromRoot.fileName -className $className -pathFromRoot $pathFromRoot.fullPath -size $size -dateComplete $dateComplete
                $null = $recordsMap['Account'].add($record);
            })
        }

        if($transactionList.count -ne 0){
            $transactionList | ForEach-Object -Process ({
                    $record = generateRecordAddRelatedObject -transName $_ -fileName $pathFromRoot.fileName -className $className -pathFromRoot $pathFromRoot.fullPath -size $size -dateComplete $dateComplete
                    $null = $recordsMap['Transaction'].add($record);
                })
        
        }
        
        if($assetList.count -ne 0){
            $assetList | ForEach-Object -Process ({
                    $record = generateRecordAddRelatedObject -assetName $_ -fileName $pathFromRoot.fileName -className $className -pathFromRoot $pathFromRoot.fullPath -size $size -dateComplete $dateComplete
                    $null = $recordsMap['CUSIP'].add($record);
                })
        
        }

        if($reTransList.count -ne 0){
            $reTransList | ForEach-Object -Process ({
                    $record = generateRecordAddRelatedObject -reTransName $_ -fileName $pathFromRoot.fileName -className $className -pathFromRoot $pathFromRoot.fullPath -size $size -dateComplete $dateComplete
                    $null = $recordsMap['RE Transaction'].add($record);
                })
        }
        # return @{'fileName'=$fileName; 'fullPath'=$pathFromRoot};
        #$fileName = "$dateComplete-$($pathFromBaseSplit[$pathFromBaseSplit.count - 1].split('.')[0])";
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


Function generateCsvJob
{
    [CmdletBinding()]
    

    param ([Parameter(ValueFromPipeline)] $someVar)

    #Write-Host $Input.doc;
    [System.Collections.ArrayList] $recordsCsv = @();
    [System.Collections.ArrayList] $recordsCsvToBig = @();
    [System.Collections.ArrayList] $recordsCsvNoAccount = @();
    [System.Collections.ArrayList] $googleDriveCSV = @();
    [System.Collections.ArrayList] $deleteCSV = @();
    [System.Collections.ArrayList] $unMappable = @();
    #@{'doc'=$_; 'accountsNameToIdMap'=$accountsNameToIdMap; 'assetNameToIdMap'=$assetNameToIdMap; 'transactionsNameToIdMap'=$transactionsNameToIdMap; 'reTransactionsNameToIdMap'=$reTransactionsNameToIdMap; 'fileRoot'=$fileRoot; 'vaultFolderCSVPath'=$vaultFolderCSVPath};
    $userNameToIdMap = $someVar.userNameToIdMap;
    $accountsNameToIdMap = $someVar.accountsNameToIdMap;
    $assetNameToIdMap = $someVar.assetNameToIdMap;
    $transactionsNameToIdMap = $someVar.transactionsNameToIdMap;
    $reTransactionsNameToIdMap = $someVar.reTransactionsNameToIdMap;
    $fileRoot=$someVar.fileRoot;
    $vaultFolderCSVPath=$someVar.vaultFolderCSVPath;
    $vaultFolderCSV=$someVar.vaultFolderCSV;

    [xml]$currentContentDocument = Get-Content $someVar.doc;
    #echo $currentContentDocument.content.object;
    $currentContentDocument.content.object | ForEach-Object -Process ({
        
        $path = handleVaultFolderMapping -object $_ -fileRoot $fileRoot -vaultFolderCSV $vaultFolderCSV -vaultFolderCSVPath $vaultFolderCSVPath

        $recordsMap = parseMFileObject -mfileObject $_ -folderPath $path

        $noDocs += $recordsMap['nullDoc'];
       
        
        $recordMapOfLists = mapFirstPublisherLocationAndNameFile -recordsMap $recordsMap -usersMap $userNameToIdMap -accountMap $accountsNameToIdMap -transactionMap $transactionsNameToIdMap -reTransMap $reTransactionsNameToIdMap -assetMap $assetNameToIdMap
            
        
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

        })
        return @{'mapped'=$recordsCsv; 'toBig'=$recordsCsvToBig; 'nonMapped'=$recordsCsvNoAccount; 'unmappable'=$unMappable; 'deleteList'=$deleteCSV; 'driveList'=$googleDriveCSV}
    }

    #

#main
Function generateUploadCsvForContentVer
{
    param($fileRoot, $paralell=-1)

    $metaDataDir = "$fileRoot\Metadata";
    $vaultFolderCSVPath = "$fileRoot\vaultfolder.csv";

    $accountsPath = 'C:\Users\dcurtin\Desktop\Mapping Records Export\Retirement_accounts_v2.csv';
    $transactionsPath = 'C:\Users\dcurtin\Desktop\Mapping Records Export\transactions_v2.csv';
    $reTransactionPath = 'C:\Users\dcurtin\Desktop\Mapping Records Export\reTransactions_v2.csv';
    $assetsPath = 'C:\Users\dcurtin\Desktop\Mapping Records Export\asset_v2.csv';
    $userPath = 'C:\Users\dcurtin\Desktop\Mapping Records Export\users.csv';

    Write-Host 'Importing Accounts';
    $accountCsv = Import-csv -Path $accountsPath;
    
    Write-Host 'Importing Transactions';
    $transactionsCSV = Import-csv -Path $transactionsPath;

    Write-Host 'Importing RE-Transactions';
    $reTransactionCSV = Import-Csv -Path $reTransactionPath;

    Write-Host 'Importing Assets';
    $assetsCSV = Import-Csv -Path $assetsPath;

    Write-Host 'Importing Users';
    $usersCSV = Import-Csv -path $userPath;

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

    $userNameToIdMap = @{};
    echo 'Generating user Map';
    $usersCSV.ForEach({$userNameToIdMap.add($_.Name, $_.Id)}) >$null;
    #~~~~~~~~~~~~~~~~~~~~~~~

    #$accountsNameToIdMap=$null;
    [System.Collections.ArrayList] $recordsCsv = @();
    [System.Collections.ArrayList] $recordsCsvToBig = @();
    [System.Collections.ArrayList] $recordsCsvNoAccount = @();
    [System.Collections.ArrayList] $googleDriveCSV = @();
    [System.Collections.ArrayList] $deleteCSV = @();
    [System.Collections.ArrayList] $unMappable = @();
    
    $csvOfFiles = @();
    echo 'Getting all Pdfs';

    [System.Collections.ArrayList] $vaultFolderCSV = @();
    if([System.IO.File]::Exists($vaultFolderCSVPath))
    {
        $vaultFolderCSV = @(Import-Csv $vaultFolderCSVPath);
    }

    $noDocs = 0;
    $maxJobCount = 2;
    [System.Collections.ArrayList] $contentFiles = Get-ChildItem -Path $metaDataDir -Filter 'Content*.xml' 
    $jobObjects = @{};

    #$contentFiles | ForEach-Object -Process ({
    #    #Write-Host $_.FullName
    #    $job = Start-Job -InitializationScript {Import-Module C:\Users\dcurtin\Desktop\GenerateCsvForContentVersion\generateUploadCsvForContentVer.ps1} -scriptBlock { $Input | generateCsvJob } -InputObject $(@{'doc'=$_.FullName; 'accountsNameToIdMap'=$accountsNameToIdMap; 'assetNameToIdMap'=$assetNameToIdMap; 'transactionsNameToIdMap'=$transactionsNameToIdMap; 'reTransactionsNameToIdMap'=$reTransactionsNameToIdMap; 'fileRoot'=$fileRoot; 'vaultFolderCSVPath'=$vaultFolderCSVPath; 'vaultFolderCSV'=$vaultFolderCSV});
    #    $null = $jobObjects.add($job.Id, $job);
    #})

    $completedJobsCount = 0;
    $failedJobsCount = 0;
    
    if($paralell -gt 0)
    {
        while($contentFiles.Count -gt 0 -or $jobObjects.Count -gt 0)
        {
            while($jobObjects.Count -lt $paralell -and $contentFiles.Count -ne 0)
            {
                $file = $contentFiles[0];
                $contentFiles.removeAt(0);

                $job = Start-Job -InitializationScript {Import-Module C:\Users\dcurtin\Desktop\GenerateCsvForContentVersion\generateUploadCsvForContentVer.ps1} -scriptBlock { $Input | generateCsvJob } -InputObject $(@{'doc'=$file.FullName; 'userNameToIdMap'=$userNameToIdMap; 'accountsNameToIdMap'=$accountsNameToIdMap; 'assetNameToIdMap'=$assetNameToIdMap; 'transactionsNameToIdMap'=$transactionsNameToIdMap; 'reTransactionsNameToIdMap'=$reTransactionsNameToIdMap; 'fileRoot'=$fileRoot; 'vaultFolderCSVPath'=$vaultFolderCSVPath; 'vaultFolderCSV'=$vaultFolderCSV});
                $null = $jobObjects.add($job.Id, $job);
            }

            [System.Collections.ArrayList] $completedJobs = @();
            [System.Collections.ArrayList] $failedJobs = @();
            [System.Collections.ArrayList]$jobKeys = @();
            $jobKeys.AddRange($jobObjects.Keys);
            $jobKeys | ForEach-Object -Process ({
                $updatedJob = Get-Job -id $_;
                if($updatedJob.State -eq 'Completed')
                {
                    $null = $completedJobs.add($updatedJob);
                    $jobObjects.Remove($_);
                    $completedJobsCount += 1;
                }
                if($updatedJob.State -ne 'Completed' -and $updatedJob.State -ne 'Running')
                {
                    Write-Host "State: $($updatedJob.State)"
                    $null = $failedJobs.add($updatedJob);
                    $jobObjects.Remove($_);
                    $failedJobsCount += $failedJobs.Count;
                }
            })
            if($completedJobs.Count -ne 0)
            {
                $completedJobs | ForEach-Object -Process ({
                    $result = Receive-Job -id $_.Id
                    $recordsCsv.AddRange($result['mapped']);
                    $recordsCsvNoAccount.AddRange($result['nonMapped']);
                    $recordsCsvToBig.AddRange($result['toBig']);
                    $deleteCSV.AddRange($result['deleteList']);
                    $unMappable.AddRange($result['unmappable']);
                    $googleDriveCSV.AddRange($result['driveList']);

                    #'mapped'=$recordsCsv; 'toBig'=$recordsCsvToBig; 'nonMapped'=$recordsCsvNoAccount; 'unmappable'=$unMappable; 'deleteList'=$deleteCSV; 'driveList'=$googleDriveCSV
                })
                
                write-host "$($completedJobsCount) Finished"
            }else
            {
                Start-Sleep -Seconds 1
            }
            
        
        }
    }else
    {
        $contentFiles | ForEach-Object -Process({
            $result = $( generateCsvJob -someVar $(@{'doc'=$_.FullName; 'userNameToIdMap'=$userNameToIdMap; 'accountsNameToIdMap'=$accountsNameToIdMap; 'assetNameToIdMap'=$assetNameToIdMap; 'transactionsNameToIdMap'=$transactionsNameToIdMap; 'reTransactionsNameToIdMap'=$reTransactionsNameToIdMap; 'fileRoot'=$fileRoot; 'vaultFolderCSVPath'=$vaultFolderCSVPath; 'vaultFolderCSV'=$vaultFolderCSV}))
            $recordsCsv.AddRange($result['mapped']);
            $recordsCsvNoAccount.AddRange($result['nonMapped']);
            $recordsCsvToBig.AddRange($result['toBig']);
            $deleteCSV.AddRange($result['deleteList']);
            $unMappable.AddRange($result['unmappable']);
            $googleDriveCSV.AddRange($result['driveList']);
            $completedJobsCount+=1;
            write-host "$completedJobsCount Finished"
        })
    }

    if(-not $(test-path "$fileRoot\output"))
    {
        mkdir "$fileRoot\output";
    }
    $recordsCsv | Export-Csv -Path "$fileRoot\output\filesToUpload.csv" -NoTypeInformation
    $recordsCsvNoAccount | Export-Csv -Path "$fileRoot\output\noMappingFound.csv" -NoTypeInformation
    $recordsCsvToBig | Export-Csv -Path "$fileRoot\output\filesToBigToUpload.csv" -NoTypeInformation
    $googleDriveCSV | Export-Csv -Path "$fileRoot\output\googleDrive.csv" -NoTypeInformation
    $deleteCSV | Export-Csv -Path "$fileRoot\output\deleteCsv.csv" -NoTypeInformation
    $unMappable | Export-Csv -Path "$fileRoot\output\noAssociatedRecord.csv" -NoTypeInformation
    Get-Job | Remove-Job -Force
}

