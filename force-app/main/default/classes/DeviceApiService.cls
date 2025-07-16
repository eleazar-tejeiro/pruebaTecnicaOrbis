/**
 * @description Service class to consume the REST API and manage Device records
 * @author Uriel
 */
public with sharing class DeviceApiService {
    
    private static final String API_ENDPOINT = 'https://api.restful-api.dev/objects';
    private static final Decimal DEFAULT_PRICE = 2025.07;
    
    /**
     * @description Main method to fetch devices from API and insert them into Salesforce
     * @return List<Device__c> List of inserted devices
     */
    public static List<Device__c> fetchAndInsertDevices() {
        try {
            // Fetch data from external API
            List<DeviceWrapper> apiDevices = callExternalAPI();
            
            if (apiDevices.isEmpty()) {
                System.debug('No devices received from API');
                return new List<Device__c>();
            }
            
            // Convert API data to Salesforce records
            List<Device__c> devicesToInsert = convertToDeviceRecords(apiDevices);
            
            // Remove duplicates based on name
            List<Device__c> uniqueDevices = removeDuplicatesByName(devicesToInsert);
            
            // Insert records
            List<Device__c> insertedDevices = insertDeviceRecords(uniqueDevices);
            
            // Update capacity from 64 GB to 46GB
            updateCapacityRecords(insertedDevices);
            
            return insertedDevices;
            
        } catch (Exception e) {
            System.debug('Error in fetchAndInsertDevices: ' + e.getMessage());
            throw new DeviceApiException('Failed to process devices: ' + e.getMessage());
        }
    }
    
    /**
     * @description Calls the external REST API to fetch device data
     * @return List<DeviceWrapper> List of devices from API
     */
    @TestVisible
    private static List<DeviceWrapper> callExternalAPI() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(API_ENDPOINT);
        request.setMethod('GET');
        request.setTimeout(10000); // 10 seconds timeout
        
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() != 200) {
            throw new DeviceApiException('API call failed with status: ' + response.getStatusCode());
        }
        
        String jsonResponse = response.getBody();
        return parseApiResponse(jsonResponse);
    }
    
    /**
     * @description Parses JSON response from API
     * @param jsonResponse String JSON response from API
     * @return List<DeviceWrapper> Parsed device data
     */
    @TestVisible
    private static List<DeviceWrapper> parseApiResponse(String jsonResponse) {
        List<DeviceWrapper> devices = new List<DeviceWrapper>();
        
        try {
            List<Object> jsonData = (List<Object>) JSON.deserializeUntyped(jsonResponse);
            
            for (Object item : jsonData) {
                Map<String, Object> deviceMap = (Map<String, Object>) item;
                DeviceWrapper device = new DeviceWrapper();
                
                device.name = (String) deviceMap.get('name');
                
                // Handle nested data object (can be null)
                Map<String, Object> dataMap = (Map<String, Object>) deviceMap.get('data');
                if (dataMap != null) {
                    device.color = extractColorFromData(dataMap);
                    device.capacity = extractCapacityFromData(dataMap);
                }
                
                if (String.isNotBlank(device.name)) {
                    devices.add(device);
                }
            }
        } catch (Exception e) {
            throw new DeviceApiException('Failed to parse API response: ' + e.getMessage());
        }
        
        return devices;
    }
    
    /**
     * @description Extracts color from data map handling different field names
     * @param dataMap Map containing device data
     * @return String Color value or null
     */
    @TestVisible
    private static String extractColorFromData(Map<String, Object> dataMap) {
        // Try different possible color field names
        List<String> colorFields = new List<String>{
            'color', 'Color', 'Colour', 'Strap Colour', 'strap_colour'
        };
        
        for (String fieldName : colorFields) {
            if (dataMap.containsKey(fieldName)) {
                Object colorValue = dataMap.get(fieldName);
                if (colorValue != null) {
                    return String.valueOf(colorValue);
                }
            }
        }
        
        return null;
    }
    
    /**
     * @description Extracts capacity from data map handling different field names and types
     * @param dataMap Map containing device data
     * @return String Capacity value or null
     */
    @TestVisible
    private static String extractCapacityFromData(Map<String, Object> dataMap) {
        // Try different possible capacity field names
        List<String> capacityFields = new List<String>{
            'capacity', 'Capacity', 'capacity GB', 'Capacity GB', 'storage', 'Storage'
        };
        
        for (String fieldName : capacityFields) {
            if (dataMap.containsKey(fieldName)) {
                Object capacityValue = dataMap.get(fieldName);
                if (capacityValue != null) {
                    // Handle both string and numeric values
                    if (capacityValue instanceof String) {
                        return (String) capacityValue;
                    } else if (capacityValue instanceof Integer || capacityValue instanceof Decimal) {
                        // Convert numeric capacity to string with GB suffix
                        return String.valueOf(capacityValue) + ' GB';
                    } else {
                        return String.valueOf(capacityValue);
                    }
                }
            }
        }
        
        return null;
    }
    
    /**
     * @description Converts API wrapper objects to Salesforce Device records
     * @param apiDevices List of DeviceWrapper from API
     * @return List<Device__c> Salesforce records ready for insertion
     */
    @TestVisible
    private static List<Device__c> convertToDeviceRecords(List<DeviceWrapper> apiDevices) {
        List<Device__c> devices = new List<Device__c>();
        
        for (DeviceWrapper apiDevice : apiDevices) {
            Device__c device = new Device__c();
            device.Name__c = apiDevice.name;
            device.Color__c = apiDevice.color;
            device.Capacity__c = apiDevice.capacity;
            device.Price__c = DEFAULT_PRICE;
            
            devices.add(device);
        }
        
        return devices;
    }
    
    /**
     * @description Removes duplicate devices based on Name field
     * @param devices List of Device records
     * @return List<Device__c> List without duplicates
     */
    @TestVisible
    private static List<Device__c> removeDuplicatesByName(List<Device__c> devices) {
        Map<String, Device__c> uniqueDevicesMap = new Map<String, Device__c>();
        
        // Get existing devices to avoid duplicates with existing records
        Set<String> existingNames = getExistingDeviceNames();
        
        for (Device__c device : devices) {
            String deviceName = device.Name__c;
            
            // Skip if name already exists in Salesforce or in current batch
            if (!existingNames.contains(deviceName) && !uniqueDevicesMap.containsKey(deviceName)) {
                uniqueDevicesMap.put(deviceName, device);
            }
        }
        
        return uniqueDevicesMap.values();
    }
    
    /**
     * @description Gets existing device names from Salesforce
     * @return Set<String> Set of existing device names
     */
    @TestVisible
    private static Set<String> getExistingDeviceNames() {
        Set<String> existingNames = new Set<String>();
        
        for (Device__c device : [SELECT Name__c FROM Device__c WHERE Name__c != NULL]) {
            existingNames.add(device.Name__c);
        }
        
        return existingNames;
    }
    
    /**
     * @description Inserts Device records with proper error handling
     * @param devices List of Device records to insert
     * @return List<Device__c> Successfully inserted devices
     */
    @TestVisible
    private static List<Device__c> insertDeviceRecords(List<Device__c> devices) {
        if (devices.isEmpty()) {
            return new List<Device__c>();
        }
        
        List<Database.SaveResult> results = Database.insert(devices, false);
        List<Device__c> insertedDevices = new List<Device__c>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                insertedDevices.add(devices[i]);
            } else {
                System.debug('Failed to insert device: ' + devices[i].Name__c + 
                           '. Error: ' + results[i].getErrors()[0].getMessage());
            }
        }
        
        System.debug('Successfully inserted ' + insertedDevices.size() + ' devices');
        return insertedDevices;
    }
    
    /**
     * @description Updates capacity from "64 GB" to "46GB" for all devices
     * @param insertedDevices List of recently inserted devices
     */
    @TestVisible
    private static void updateCapacityRecords(List<Device__c> insertedDevices) {
        List<Device__c> devicesToUpdate = new List<Device__c>();
        
        // Query all devices to update capacity
        for (Device__c device : [SELECT Id, Capacity__c FROM Device__c WHERE Capacity__c = '64 GB']) {
            device.Capacity__c = '46GB';
            devicesToUpdate.add(device);
        }
        
        if (!devicesToUpdate.isEmpty()) {
            List<Database.SaveResult> updateResults = Database.update(devicesToUpdate, false);
            
            Integer successCount = 0;
            for (Database.SaveResult result : updateResults) {
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    System.debug('Failed to update device capacity. Error: ' + 
                               result.getErrors()[0].getMessage());
                }
            }
            
            System.debug('Successfully updated capacity for ' + successCount + ' devices');
        }
    }
    
    /**
     * @description Wrapper class for API response data
     */
    public class DeviceWrapper {
        public String name { get; set; }
        public String color { get; set; }
        public String capacity { get; set; }
    }
    
    /**
     * @description Custom exception class for Device API operations
     */
    public class DeviceApiException extends Exception {}
} 