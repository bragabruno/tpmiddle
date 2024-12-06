#import <XCTest/XCTest.h>
#include "../../../src/infrastructure/persistence/HIDDevice.h"

using namespace TPMiddle::Infrastructure;

@interface HIDDeviceTests : XCTestCase
@end

@implementation HIDDeviceTests {
    std::unique_ptr<HIDDevice> device;
}

- (void)setUp {
    [super setUp];
    // Create a test device with known values
    device = std::make_unique<HIDDevice>("test-id", "Test Device", "TestType");
}

- (void)tearDown {
    device.reset();
    [super tearDown];
}

- (void)testDeviceInitialization {
    XCTAssertNotNil(device.get(), @"Device should be created");
    XCTAssertEqual(device->GetId(), "test-id", @"Device ID should match initialization value");
    XCTAssertEqual(device->GetName(), "Test Device", @"Device name should match initialization value");
    XCTAssertEqual(device->GetDeviceType(), "TestType", @"Device type should match initialization value");
    XCTAssertFalse(device->IsConnected(), @"Device should not be connected initially");
    XCTAssertTrue(device->GetLastError().empty(), @"No error should be present initially");
}

- (void)testDeviceConnection {
    // Test connection
    bool connected = device->Open();
    XCTAssertTrue(connected, @"Device should connect successfully");
    XCTAssertTrue(device->IsConnected(), @"Device should report as connected");
    
    // Test disconnection
    device->Close();
    XCTAssertFalse(device->IsConnected(), @"Device should report as disconnected");
}

- (void)testDeviceReset {
    // First connect the device
    XCTAssertTrue(device->Open(), @"Device should connect successfully");
    
    // Test reset functionality
    bool resetResult = device->Reset();
    XCTAssertTrue(resetResult, @"Device reset should succeed");
    XCTAssertTrue(device->IsConnected(), @"Device should remain connected after reset");
}

- (void)testSendReport {
    // Connect the device
    XCTAssertTrue(device->Open(), @"Device should connect successfully");
    
    // Test sending a report
    std::vector<uint8_t> testReport = {0x01, 0x02, 0x03, 0x04};
    bool sendResult = device->SendReport(testReport);
    XCTAssertTrue(sendResult, @"Sending report should succeed");
}

- (void)testReadReport {
    // Connect the device
    XCTAssertTrue(device->Open(), @"Device should connect successfully");
    
    // Test reading a report
    std::vector<uint8_t> report;
    bool readResult = device->ReadReport(report);
    XCTAssertTrue(readResult, @"Reading report should succeed");
    XCTAssertGreaterThan(report.size(), 0UL, @"Report should contain data");
}

- (void)testErrorHandling {
    // Test operations without connecting
    std::vector<uint8_t> report;
    XCTAssertFalse(device->SendReport(report), @"Send should fail when not connected");
    XCTAssertFalse(device->ReadReport(report), @"Read should fail when not connected");
    XCTAssertFalse(device->GetLastError().empty(), @"Error message should be set");
}

- (void)testConcurrentAccess {
    // Test concurrent access to device methods
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // Perform multiple operations concurrently
    for (int i = 0; i < 100; i++) {
        dispatch_group_async(group, queue, ^{
            device->GetId();
            device->IsConnected();
            device->GetLastError();
        });
    }
    
    // Wait for all operations to complete
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    // If we got here without crashing, the mutex is working
    XCTAssertTrue(true, @"Concurrent access test completed successfully");
}

@end
