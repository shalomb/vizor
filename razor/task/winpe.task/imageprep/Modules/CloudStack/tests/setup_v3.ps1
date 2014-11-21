# Powershell


$MediumOfferingVMs = @(
  'ASFController' = @{ 'serviceoffering' = 'medium'; 'network' = 'ASFUsers'; 'template' = '2008R2..'; };
);

$SmallOfferingVMs = @(
  'ASFSUT1'       = @{ 'serviceoffering' = 'small'; 'network' = 'ASFUsers'; 'template' = '2008R2..'; };
  'ASFSUT2'       = @{ 'serviceoffering' = 'small'; 'network' = 'ASFUsers'; 'template' = '2008R2..'; };
  'ASFSUT3'       = @{ 'serviceoffering' = 'small'; 'network' = 'ASFUsers'; 'template' = '2008R2..'; };
  'ASFSUT4'       = @{ 'serviceoffering' = 'small'; 'network' = 'ASFUsers'; 'template' = '2008R2..'; };
  'ASFSUT5'       = @{ 'serviceoffering' = 'small'; 'network' = 'ASFUsers'; 'template' = '2008R2..'; };
);


foreach ( $vm in $Vms ) {
  Add-AsfRoleHole -NameLabel 
}
