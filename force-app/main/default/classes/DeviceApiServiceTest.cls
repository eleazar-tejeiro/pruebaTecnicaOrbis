/**
 * @description Test class for DeviceApiService
 * @author Uriel
 */
@IsTest
private class DeviceApiServiceTest {
    
    private static final String MOCK_API_RESPONSE = '[' +
        '{' +
            '"id": "1",' +
            '"name": "Google Pixel 6 Pro",' +
            '"data": {' +
                '"color": "Cloudy White",' +
                '"capacity": "128 GB"' +
            '}' +
        '},' +
        '{' +
            '"id": "2",' +
            '"name": "Apple iPhone 12 Mini, 256GB, Blue",' +
            '"data": null' +
        '},' +
        '{' +
            '"id": "3",' +
            '"name": "Apple iPhone 12 Pro Max",' +
            '"data": {' +
                '"color": "Cloudy White",' +
                '"capacity GB": 512' +
            '}' +
        '},' +
        '{' +
            '"id": "4",' +
            '"name": "Apple iPhone 11, 64GB",' +
            '"data": {' +
                '"price": 389.99,' +
                '"color": "Purple"' +
            '}' +
        '},' +
        '{' +
            '"id": "5",' +
            '"name": "Beats Studio3 Wireless",' +
            '"data": {' +
                '"Color": "Red",' +
                '"Description": "High-performance wireless noise cancelling headphones"' +
            '}' +
        '},' +
        '{' +
            '"id": "6",' +
            '"name": "Apple iPad Mini 5th Gen",' +
            '"data": {' +
                '"Capacity": "64 GB",' +
                '"Screen size": 7.9' +
            '}' +
        '},' +
        '{' +
            '"id": "7",' +
            '"name": "Apple Watch Series 8",' +
            '"data": {' +
                '"Strap Colour": "Elderberry",' +
                '"Case Size": "41mm"' +
            '}' +
        '}' +
    ']';
    
    private static final String MOCK_API_RESPONSE_EMPTY = '[]';
    
    private static final String MOCK_API_RESPONSE_INVALID = 'invalid json';
    
    /**
     * @description Test setup method to create test data
     */
    @TestSetup
    static void setupTestData() {
        // Create existing device to test duplicate prevention
        Device__c existingDevice = new Device__c(
            Name__c = 'Existing Device',
            Color__c = 'White',
            Capacity__c = '32 GB',
            Price__c = 1500.00
        );
        insert existingDevice;
    }
    
    /**
     * @description Test successful API call and device insertion
     */
    @IsTest
    static void testFetchAndInsertDevicesSuccess() {
        // Set up mock HTTP response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, MOCK_API_RESPONSE));
        
        Test.startTest();
        List<Device__c> result = DeviceApiService.fetchAndInsertDevices();
        Test.stopTest();
        
        // Verify results
        System.assertNotEquals(null, result, 'Result should not be null');
        
        // Query inserted devices
        List<Device__c> insertedDevices = [SELECT Id, Name__c, Color__c, Capacity__c, Price__c FROM Device__c 
                                          WHERE Name__c IN ('Google Pixel 6 Pro', 'Apple iPhone 12 Mini, 256GB, Blue', 
                                                           'Apple iPhone 12 Pro Max', 'Apple iPhone 11, 64GB',
                                                           'Beats Studio3 Wireless', 'Apple iPad Mini 5th Gen',
                                                           'Apple Watch Series 8')];
        
        System.assertEquals(7, insertedDevices.size(), 'Should insert 7 unique devices');
        
        // Verify price is set correctly
        for (Device__c device : insertedDevices) {
            System.assertEquals(2025.07, device.Price__c, 'Price should be set to default value');
        }
        
        // Verify capacity update (64 GB should be updated to 46GB)
        List<Device__c> devicesWithUpdatedCapacity = [SELECT Id FROM Device__c WHERE Capacity__c = '46GB'];
        System.assert(devicesWithUpdatedCapacity.size() > 0, 'At least one device should have updated capacity');
    }
    
    /**
     * @description Test API call failure
     */
    @IsTest
    static void testApiCallFailure() {
        // Set up mock HTTP response with error
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, 'Internal Server Error'));
        
        Test.startTest();
        try {
            DeviceApiService.fetchAndInsertDevices();
            System.assert(false, 'Should have thrown an exception');
        } catch (DeviceApiService.DeviceApiException e) {
            System.assert(e.getMessage().contains('API call failed'), 'Should contain API error message');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test empty API response
     */
    @IsTest
    static void testEmptyApiResponse() {
        // Set up mock HTTP response with empty array
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, MOCK_API_RESPONSE_EMPTY));
        
        Test.startTest();
        List<Device__c> result = DeviceApiService.fetchAndInsertDevices();
        Test.stopTest();
        
        System.assertEquals(0, result.size(), 'Should return empty list for empty API response');
    }
    
    /**
     * @description Test invalid JSON response
     */
    @IsTest
    static void testInvalidJsonResponse() {
        // Set up mock HTTP response with invalid JSON
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, MOCK_API_RESPONSE_INVALID));
        
        Test.startTest();
        try {
            DeviceApiService.fetchAndInsertDevices();
            System.assert(false, 'Should have thrown an exception');
        } catch (DeviceApiService.DeviceApiException e) {
            System.assert(e.getMessage().contains('Failed to parse'), 'Should contain parse error message');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test duplicate prevention
     */
    @IsTest
    static void testDuplicatePrevention() {
        // Create device with same name as in setup data
        String duplicateResponse = '[{' +
            '"id": "1",' +
            '"name": "Existing Device",' +
            '"data": {' +
                '"color": "Blue",' +
                '"capacity": "64 GB"' +
            '}' +
        '}]';
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, duplicateResponse));
        
        Test.startTest();
        List<Device__c> result = DeviceApiService.fetchAndInsertDevices();
        Test.stopTest();
        
        // Should not insert duplicate
        System.assertEquals(0, result.size(), 'Should not insert duplicate device');
        
        // Verify only one device with this name exists
        List<Device__c> existingDevices = [SELECT Id FROM Device__c WHERE Name__c = 'Existing Device'];
        System.assertEquals(1, existingDevices.size(), 'Should only have one device with this name');
    }
    
    /**
     * @description Test parseApiResponse method directly
     */
    @IsTest
    static void testParseApiResponse() {
        Test.startTest();
        List<DeviceApiService.DeviceWrapper> result = DeviceApiService.parseApiResponse(MOCK_API_RESPONSE);
        Test.stopTest();
        
        System.assertEquals(7, result.size(), 'Should parse 7 devices from response');
        
        // Test first device (normal case)
        DeviceApiService.DeviceWrapper firstDevice = result[0];
        System.assertEquals('Google Pixel 6 Pro', firstDevice.name, 'First device name should match');
        System.assertEquals('Cloudy White', firstDevice.color, 'First device color should match');
        System.assertEquals('128 GB', firstDevice.capacity, 'First device capacity should match');
        
        // Test device with null data
        DeviceApiService.DeviceWrapper nullDataDevice = result[1];
        System.assertEquals('Apple iPhone 12 Mini, 256GB, Blue', nullDataDevice.name, 'Null data device name should match');
        System.assertEquals(null, nullDataDevice.color, 'Null data device color should be null');
        System.assertEquals(null, nullDataDevice.capacity, 'Null data device capacity should be null');
        
        // Test device with numeric capacity
        DeviceApiService.DeviceWrapper numericCapacityDevice = result[2];
        System.assertEquals('Apple iPhone 12 Pro Max', numericCapacityDevice.name, 'Numeric capacity device name should match');
        System.assertEquals('Cloudy White', numericCapacityDevice.color, 'Numeric capacity device color should match');
        System.assertEquals('512 GB', numericCapacityDevice.capacity, 'Numeric capacity should be converted to string with GB');
        
        // Test device with different color field name
        DeviceApiService.DeviceWrapper differentColorFieldDevice = result[4];
        System.assertEquals('Beats Studio3 Wireless', differentColorFieldDevice.name, 'Different color field device name should match');
        System.assertEquals('Red', differentColorFieldDevice.color, 'Color with capital C should be found');
    }
    
    /**
     * @description Test convertToDeviceRecords method
     */
    @IsTest
    static void testConvertToDeviceRecords() {
        // Create test wrapper data
        List<DeviceApiService.DeviceWrapper> wrappers = new List<DeviceApiService.DeviceWrapper>();
        DeviceApiService.DeviceWrapper wrapper = new DeviceApiService.DeviceWrapper();
        wrapper.name = 'Test Device';
        wrapper.color = 'Green';
        wrapper.capacity = '256 GB';
        wrappers.add(wrapper);
        
        Test.startTest();
        List<Device__c> result = DeviceApiService.convertToDeviceRecords(wrappers);
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should convert 1 wrapper to Device record');
        
        Device__c device = result[0];
        System.assertEquals('Test Device', device.Name__c, 'Name should match');
        System.assertEquals('Green', device.Color__c, 'Color should match');
        System.assertEquals('256 GB', device.Capacity__c, 'Capacity should match');
        System.assertEquals(2025.07, device.Price__c, 'Price should be default value');
    }
    
    /**
     * @description Test removeDuplicatesByName method
     */
    @IsTest
    static void testRemoveDuplicatesByName() {
        // Create test devices with duplicates
        List<Device__c> testDevices = new List<Device__c>();
        
        Device__c device1 = new Device__c(Name__c = 'Device A', Color__c = 'Red');
        Device__c device2 = new Device__c(Name__c = 'Device B', Color__c = 'Blue');
        Device__c device3 = new Device__c(Name__c = 'Device A', Color__c = 'Green'); // Duplicate
        Device__c device4 = new Device__c(Name__c = 'Existing Device', Color__c = 'White'); // Exists in setup
        
        testDevices.add(device1);
        testDevices.add(device2);
        testDevices.add(device3);
        testDevices.add(device4);
        
        Test.startTest();
        List<Device__c> result = DeviceApiService.removeDuplicatesByName(testDevices);
        Test.stopTest();
        
        System.assertEquals(2, result.size(), 'Should return 2 unique devices (excluding existing)');
        
        Set<String> resultNames = new Set<String>();
        for (Device__c device : result) {
            resultNames.add(device.Name__c);
        }
        
        System.assert(resultNames.contains('Device A'), 'Should contain Device A');
        System.assert(resultNames.contains('Device B'), 'Should contain Device B');
        System.assert(!resultNames.contains('Existing Device'), 'Should not contain existing device');
    }
    
    /**
     * @description Test getExistingDeviceNames method
     */
    @IsTest
    static void testGetExistingDeviceNames() {
        Test.startTest();
        Set<String> result = DeviceApiService.getExistingDeviceNames();
        Test.stopTest();
        
        System.assert(result.contains('Existing Device'), 'Should contain existing device name');
        System.assertEquals(1, result.size(), 'Should return 1 existing device name');
    }
    
    /**
     * @description Test insertDeviceRecords method with empty list
     */
    @IsTest
    static void testInsertDeviceRecordsEmpty() {
        List<Device__c> emptyList = new List<Device__c>();
        
        Test.startTest();
        List<Device__c> result = DeviceApiService.insertDeviceRecords(emptyList);
        Test.stopTest();
        
        System.assertEquals(0, result.size(), 'Should return empty list for empty input');
    }
    
    /**
     * @description Test updateCapacityRecords method
     */
    @IsTest
    static void testUpdateCapacityRecords() {
        // Create devices with 64 GB capacity
        List<Device__c> testDevices = new List<Device__c>();
        testDevices.add(new Device__c(Name__c = 'Test Device 1', Capacity__c = '64 GB', Price__c = 100.00));
        testDevices.add(new Device__c(Name__c = 'Test Device 2', Capacity__c = '64 GB', Price__c = 200.00));
        testDevices.add(new Device__c(Name__c = 'Test Device 3', Capacity__c = '128 GB', Price__c = 300.00));
        insert testDevices;
        
        Test.startTest();
        DeviceApiService.updateCapacityRecords(testDevices);
        Test.stopTest();
        
        // Verify updates
        List<Device__c> updatedDevices = [SELECT Id, Capacity__c FROM Device__c WHERE Capacity__c = '46GB'];
        System.assertEquals(2, updatedDevices.size(), 'Should update 2 devices with 64 GB capacity');
        
        List<Device__c> unchangedDevices = [SELECT Id, Capacity__c FROM Device__c WHERE Capacity__c = '128 GB'];
        System.assertEquals(1, unchangedDevices.size(), 'Should not update devices with other capacities');
    }
    
    /**
     * @description Test DeviceWrapper class
     */
    @IsTest
    static void testDeviceWrapper() {
        Test.startTest();
        DeviceApiService.DeviceWrapper wrapper = new DeviceApiService.DeviceWrapper();
        wrapper.name = 'Test Name';
        wrapper.color = 'Test Color';
        wrapper.capacity = 'Test Capacity';
        Test.stopTest();
        
        System.assertEquals('Test Name', wrapper.name, 'Name should be set correctly');
        System.assertEquals('Test Color', wrapper.color, 'Color should be set correctly');
        System.assertEquals('Test Capacity', wrapper.capacity, 'Capacity should be set correctly');
    }
    
    /**
     * @description Test DeviceApiException
     */
    @IsTest
    static void testDeviceApiException() {
        Test.startTest();
        try {
            throw new DeviceApiService.DeviceApiException('Test exception message');
        } catch (DeviceApiService.DeviceApiException e) {
            System.assertEquals('Test exception message', e.getMessage(), 'Exception message should match');
        }
        Test.stopTest();
    }
    
    /**
     * @description Test extractColorFromData method with different field names
     */
    @IsTest
    static void testExtractColorFromData() {
        Test.startTest();
        
        // Test lowercase 'color'
        Map<String, Object> dataMap1 = new Map<String, Object>{'color' => 'Blue'};
        String result1 = DeviceApiService.extractColorFromData(dataMap1);
        System.assertEquals('Blue', result1, 'Should extract lowercase color');
        
        // Test uppercase 'Color'
        Map<String, Object> dataMap2 = new Map<String, Object>{'Color' => 'Red'};
        String result2 = DeviceApiService.extractColorFromData(dataMap2);
        System.assertEquals('Red', result2, 'Should extract uppercase Color');
        
        // Test 'Strap Colour'
        Map<String, Object> dataMap3 = new Map<String, Object>{'Strap Colour' => 'Elderberry'};
        String result3 = DeviceApiService.extractColorFromData(dataMap3);
        System.assertEquals('Elderberry', result3, 'Should extract Strap Colour');
        
        // Test null value
        Map<String, Object> dataMap4 = new Map<String, Object>{'color' => null};
        String result4 = DeviceApiService.extractColorFromData(dataMap4);
        System.assertEquals(null, result4, 'Should return null for null color value');
        
        // Test missing field
        Map<String, Object> dataMap5 = new Map<String, Object>{'price' => 100};
        String result5 = DeviceApiService.extractColorFromData(dataMap5);
        System.assertEquals(null, result5, 'Should return null when no color field exists');
        
        Test.stopTest();
    }
    
    /**
     * @description Test extractCapacityFromData method with different field names and types
     */
    @IsTest
    static void testExtractCapacityFromData() {
        Test.startTest();
        
        // Test lowercase 'capacity' string
        Map<String, Object> dataMap1 = new Map<String, Object>{'capacity' => '128 GB'};
        String result1 = DeviceApiService.extractCapacityFromData(dataMap1);
        System.assertEquals('128 GB', result1, 'Should extract lowercase capacity string');
        
        // Test uppercase 'Capacity'
        Map<String, Object> dataMap2 = new Map<String, Object>{'Capacity' => '64 GB'};
        String result2 = DeviceApiService.extractCapacityFromData(dataMap2);
        System.assertEquals('64 GB', result2, 'Should extract uppercase Capacity');
        
        // Test 'capacity GB' with numeric value
        Map<String, Object> dataMap3 = new Map<String, Object>{'capacity GB' => 512};
        String result3 = DeviceApiService.extractCapacityFromData(dataMap3);
        System.assertEquals('512 GB', result3, 'Should convert numeric capacity to string with GB');
        
        // Test decimal value
        Map<String, Object> dataMap4 = new Map<String, Object>{'capacity' => 256.5};
        String result4 = DeviceApiService.extractCapacityFromData(dataMap4);
        System.assertEquals('256.5 GB', result4, 'Should convert decimal capacity to string with GB');
        
        // Test null value
        Map<String, Object> dataMap5 = new Map<String, Object>{'capacity' => null};
        String result5 = DeviceApiService.extractCapacityFromData(dataMap5);
        System.assertEquals(null, result5, 'Should return null for null capacity value');
        
        // Test missing field
        Map<String, Object> dataMap6 = new Map<String, Object>{'price' => 100};
        String result6 = DeviceApiService.extractCapacityFromData(dataMap6);
        System.assertEquals(null, result6, 'Should return null when no capacity field exists');
        
        Test.stopTest();
    }
    
    /**
     * @description Mock HTTP response class for testing
     */
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        
        public MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(this.statusCode);
            response.setBody(this.body);
            response.setHeader('Content-Type', 'application/json');
            return response;
        }
    }
} 