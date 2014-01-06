//
//  FirstViewController.m
//
//  Created by Michael Marceau on 1/4/14.
//  Copyright (c) 2014 Michael Marceau. All rights reserved.
//

#import "FirstViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "NSData+Hex.h"

@interface FirstViewController ()

@property (weak, nonatomic) IBOutlet UITableView *deviceTable;
@property (weak, nonatomic) IBOutlet UILabel *labelBatteryLevel;
@property (weak, nonatomic) IBOutlet UIView *detailView;
@property (weak, nonatomic) IBOutlet UILabel *labelManufacturer;
@property (weak, nonatomic) IBOutlet UIView *scanningViewContainer;
@property (nonatomic, retain) NSMutableArray *peripherals;
@property (nonatomic, retain) NSDictionary *rssiDict;
@property (nonatomic, retain) CBCentralManager *centralManager;
@property (nonatomic, assign) bool isScanning;

@end

@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.peripherals = [[NSMutableArray alloc] init];
    self.rssiDict = [[NSMutableDictionary alloc] init];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    (central.state == CBCentralManagerStatePoweredOn) ? [self startScanning] : [self stopScanning];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [peripheral discoverServices:nil];
    [self.deviceTable reloadData];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.deviceTable reloadData];
}


- (void)centralManager:(CBCentralManager *)central
didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    
    
    // Update signal strength dictionary
    [self.rssiDict setValue:RSSI forKey:peripheral.identifier.description];
    
    if (![self.peripherals containsObject:peripheral])
    {
        peripheral.delegate = self;
        [self.peripherals addObject:peripheral];
    }
    
    [self.deviceTable reloadData];
}

#pragma mark -
#pragma mark CBPeripheralDelegate


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    for(CBService *service in peripheral.services)
    {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        [peripheral discoverDescriptorsForCharacteristic:characteristic];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {

    NSString *udid = [characteristic.UUID.data hexadecimalString];
  
    // Battery Level
    if ([udid isEqualToString:@"2a19"])
    {
        unsigned intValue = 0;
        NSScanner *scanner = [NSScanner scannerWithString:[characteristic.value hexadecimalString]];
        [scanner scanHexInt:&intValue];
        
        self.detailView.hidden = NO;
        self.labelBatteryLevel.text = [NSString stringWithFormat:@"%d %%", intValue];
    }
    // Manufacturer name
    else if ([udid isEqualToString:@"2a29"])
    {
        self.detailView.hidden = NO;
        self.labelManufacturer.text = [[NSString alloc] initWithData:characteristic.value encoding:NSASCIIStringEncoding];
    }
 
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    for (CBDescriptor *descriptor in characteristic.descriptors)
    {
        [peripheral readValueForDescriptor:descriptor];
    }
    
    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (self.peripherals != nil) ? self.peripherals.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    CBPeripheral *peripheral = [self.peripherals objectAtIndex:indexPath.row];
    static NSString *cellIdentifier = @"DeviceCell";

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
   
    NSNumber *signal = [self.rssiDict valueForKey:peripheral.identifier.description];
    [[cell textLabel] setText:[NSString stringWithFormat:@"%@ : %ld",[peripheral name], [signal longValue]]];
    [[cell detailTextLabel] setText: [self getPeripheralStatus:peripheral]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBPeripheral *peripheral = [self.peripherals objectAtIndex:indexPath.row];
    
    if (peripheral.state == CBPeripheralStateDisconnected) {
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
    else if (peripheral.state == CBPeripheralStateConnected) {
        [self.centralManager cancelPeripheralConnection:peripheral];
        self.detailView.hidden = YES;
    }
    
}

- (NSString*)getPeripheralStatus:(CBPeripheral*)peripheral {
    
    NSString *status = nil;
    switch (peripheral.state)
    {
        case CBPeripheralStateConnected:
            status = @"Connected";
            break;
        case CBPeripheralStateConnecting:
            status = @"Connecting";
            break;
        case CBPeripheralStateDisconnected:
            status = @"Disconnected";
            break;
    }
    return status;
}

- (void) startScanning {
    self.isScanning = true;
    self.scanningViewContainer.hidden = NO;
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
}

- (void) stopScanning {
    self.isScanning = false;
    self.scanningViewContainer.hidden = YES;
    [self.centralManager stopScan];
    [self.peripherals removeAllObjects];
    [self.deviceTable reloadData];
}


@end
