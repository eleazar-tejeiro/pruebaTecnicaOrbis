/**
 * Script to execute Device API synchronization
 * Run this in Developer Console or via SFDX CLI
 */

System.debug('========================================');
System.debug('INICIANDO SINCRONIZACIÓN DE DISPOSITIVOS');
System.debug('========================================');

try {
    List<Device__c> result = DeviceApiService.fetchAndInsertDevices();
    
    System.debug(' SINCRONIZACIÓN COMPLETADA EXITOSAMENTE');
    System.debug(' Dispositivos procesados: ' + result.size());
    
    // Query final results for verification
    List<Device__c> allDevices = [SELECT Id, Name__c, Color__c, Capacity__c, Price__c 
                                  FROM Device__c 
                                  ORDER BY CreatedDate DESC 
                                  LIMIT 10];
    
    System.debug(' ÚLTIMOS DISPOSITIVOS INSERTADOS:');
    for (Device__c device : allDevices) {
        System.debug('   • ' + device.Name__c + ' | ' + device.Color__c + ' | ' + device.Capacity__c + ' | $' + device.Price__c);
    }
    
    // Check capacity updates
    List<Device__c> updatedCapacityDevices = [SELECT Id, Name__c, Capacity__c 
                                              FROM Device__c 
                                              WHERE Capacity__c = '46GB'];
    
    System.debug(' DISPOSITIVOS CON CAPACIDAD ACTUALIZADA (46GB): ' + updatedCapacityDevices.size());
    
    // Show statistics
    List<AggregateResult> stats = [SELECT COUNT(Id) totalRecords, 
                                          COUNT(Color__c) recordsWithColor,
                                          COUNT(Capacity__c) recordsWithCapacity
                                   FROM Device__c];
    
    if (!stats.isEmpty()) {
        AggregateResult stat = stats[0];
        System.debug('   ESTADÍSTICAS FINALES:');
        System.debug('   • Total de dispositivos: ' + stat.get('totalRecords'));
        System.debug('   • Dispositivos con color: ' + stat.get('recordsWithColor'));
        System.debug('   • Dispositivos con capacidad: ' + stat.get('recordsWithCapacity'));
    }
    
} catch (Exception e) {
    System.debug(' ERROR EN SINCRONIZACIÓN: ' + e.getMessage());
    System.debug(' STACK TRACE: ' + e.getStackTraceString());
}

System.debug('========================================');
System.debug('SINCRONIZACIÓN FINALIZADA');
System.debug('========================================'); 