//
//  UdpSockets.m
//  react-native-udp
//
//  Created by Mark Vayngrib on 5/8/15.
//  Copyright (c) 2015 Tradle, Inc. All rights reserved.
//

#import <React/RCTAssert.h>
#import <React/RCTBridge+Private.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>
#import "UdpSockets.h"
#import "UdpSocketClient.h"
#import <jsi/jsi.h>
#import "../cpp/utils/TypedArray.h"

using namespace facebook::jsi;
using namespace std;

@implementation UdpSockets
{
    NSMutableDictionary<NSNumber *, UdpSocketClient *> *_clients;
    NSMutableDictionary<NSNumber *, NSData *> *_framesData;
    NSMutableArray *_framesNumbers;
    NSNumber *_NUMBER_OF_MEMORISED_FRAMES;
}

@synthesize bridge = _bridge;
@synthesize methodQueue = _methodQueue;

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup {

    return YES;
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(install)
{
    RCTBridge* bridge = [RCTBridge currentBridge];
    RCTCxxBridge* cxxBridge = (RCTCxxBridge*)bridge;
    if (cxxBridge == nil) {
        return @false;
    }

    auto jsiRuntime = (facebook::jsi::Runtime*) cxxBridge.runtime;
    if (jsiRuntime == nil) {
        return @false;
    }

    _framesData = [NSMutableDictionary new];
    _framesNumbers = [NSMutableArray new];
    _NUMBER_OF_MEMORISED_FRAMES = @(225);

    install(*(facebook::jsi::Runtime *)jsiRuntime, self);
    return @true;
}

- (void)dealloc
{
    for (NSNumber *cId in _clients.allKeys) {
        [self closeClient:cId callback:nil];
    }
}

- (void)addFrameData:(NSNumber*)key data:(NSData*) data {
    if([_framesNumbers count] >= [_NUMBER_OF_MEMORISED_FRAMES intValue]) {
        NSNumber *keyToRemove = [_framesNumbers objectAtIndex:0];
        [_framesNumbers removeObjectAtIndex:0];
        [_framesData removeObjectForKey:keyToRemove];
    }

    [_framesNumbers addObject:key];
    _framesData[key] = data;
}

- (NSData *)getFrameDataByFrameNo:(NSNumber*)key {
    return _framesData[key] ?: [NSData data];
}

-(NSNumber *) getFirstMemorisedFrameNo {
    if(![_framesNumbers count]) {
        return @(-1);
    }

    return [_framesNumbers objectAtIndex:0];
}

-(NSNumber *) getLastMemorisedFrameNo {
    if(![_framesNumbers count]) {
        return @(-1);
    }

    return [_framesNumbers lastObject];
}

-(NSNumber *) getCountOfMemorisedFrames {
    return [NSNumber numberWithInteger:[_framesNumbers count]];
}

static void install(facebook::jsi::Runtime &jsiRuntime, UdpSockets *udpSockets) {
    auto JSI_RN_UDP_getFrameDataByFrameNo = Function::createFromHostFunction(jsiRuntime,
                                                          PropNameID::forAscii(jsiRuntime,
                                                                               "JSI_RN_UDP_getFrameDataByFrameNo"),
                                                          1,
                                                          [udpSockets](Runtime &runtime,
                                                                   const Value &thisValue,
                                                                   const Value *arguments,
                                                                   size_t count) -> Value {
        int key = arguments[0].getNumber();
        NSData *data = [udpSockets getFrameDataByFrameNo:[NSNumber numberWithInt:key]];

        auto typedArray = TypedArray<TypedArrayKind::Uint8Array>(runtime, data.length);
        auto arrayBuffer = typedArray.getBuffer(runtime);
        memcpy(arrayBuffer.data(runtime), (const uint8_t *)data.bytes, data.length);

        return typedArray;
    });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getFrameDataByFrameNo", move(JSI_RN_UDP_getFrameDataByFrameNo));

    auto JSI_RN_UDP_getFirstMemorisedFrameNo = Function::createFromHostFunction(jsiRuntime,
                                                                 PropNameID::forAscii(jsiRuntime,
                                                                                      "JSI_RN_UDP_getFirstMemorisedFrameNo"),
                                                                 0,
                                                                 [udpSockets](Runtime &runtime,
                                                                    const Value &thisValue,
                                                                    const Value *arguments,
                                                                    size_t count) -> Value {
        int frameNo = [[udpSockets getFirstMemorisedFrameNo] intValue];

        return Value(frameNo);
                                                                 });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getFirstMemorisedFrameNo", std::move(JSI_RN_UDP_getFirstMemorisedFrameNo));

    auto JSI_RN_UDP_getLastMemorisedFrameNo = Function::createFromHostFunction(jsiRuntime,
                                                                  PropNameID::forAscii(jsiRuntime,
                                                                                       "JSI_RN_UDP_getLastMemorisedFrameNo"),
                                                                  0,
                                                                  [udpSockets](Runtime &runtime,
                                                                     const Value &thisValue,
                                                                     const Value *arguments,
                                                                     size_t count) -> Value {
        int frameNo = [[udpSockets getLastMemorisedFrameNo] intValue];

        return Value(frameNo);
                                                                  });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getLastMemorisedFrameNo", std::move(JSI_RN_UDP_getLastMemorisedFrameNo));

    auto JSI_RN_UDP_getCountOfMemorisedFrames = Function::createFromHostFunction(jsiRuntime,
                                                                 PropNameID::forAscii(jsiRuntime,
                                                                                      "JSI_RN_UDP_getCountOfMemorisedFrames"),
                                                                 0,
                                                                 [udpSockets](Runtime &runtime,
                                                                    const Value &thisValue,
                                                                    const Value *arguments,
                                                                    size_t count) -> Value {
        int framesCount = [[udpSockets getCountOfMemorisedFrames] intValue];

        return Value(framesCount);
                                                                 });

    jsiRuntime.global().setProperty(jsiRuntime, "JSI_RN_UDP_getCountOfMemorisedFrames", std::move(JSI_RN_UDP_getCountOfMemorisedFrames));

}

RCT_EXPORT_METHOD(createSocket:(nonnull NSNumber*)cId withOptions:(NSDictionary*)options)
{
    if (!cId) {
        RCTLogError(@"%@.createSocket called with nil id parameter.", [self class]);
        return;
    }

    if (!_clients) {
        _clients = [NSMutableDictionary new];
    }

    if (_clients[cId]) {
        RCTLogError(@"%@.createSocket called twice with the same id.", [self class]);
        return;
    }

    _clients[cId] = [UdpSocketClient socketClientWithConfig:self];
}

RCT_EXPORT_METHOD(bind:(nonnull NSNumber*)cId
                  port:(int)port
                  address:(NSString *)address
                  options:(NSDictionary *)options
                  callback:(RCTResponseSenderBlock)callback)
{
    UdpSocketClient* client = [self findClient:cId callback:callback];
    if (!client) return;

    NSError *error = nil;
    if (![client bind:port address:address options:options error:&error])
    {
        NSString *msg = error.localizedFailureReason ?: error.localizedDescription;
        callback(@[msg ?: @"unknown error when binding"]);
        return;
    }

    callback(@[[NSNull null], [client address]]);
}

RCT_EXPORT_METHOD(send:(nonnull NSNumber*)cId
                  string:(NSString*)base64String
                  port:(int)port
                  address:(NSString*)address
                  callback:(RCTResponseSenderBlock)callback) {
    UdpSocketClient* client = [self findClient:cId callback:callback];
    if (!client) return;

    // iOS7+
    // TODO: use https://github.com/nicklockwood/Base64 for compatibility with earlier iOS versions
    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    [client send:data remotePort:port remoteAddress:address callback:callback];
}

RCT_EXPORT_METHOD(close:(nonnull NSNumber*)cId
                  callback:(RCTResponseSenderBlock)callback) {
    [self closeClient:cId callback:callback];
}

RCT_EXPORT_METHOD(setBroadcast:(nonnull NSNumber*)cId
                  flag:(BOOL)flag
                  callback:(RCTResponseSenderBlock)callback) {
    UdpSocketClient* client = [self findClient:cId callback:callback];
    if (!client) return;

    NSError *error = nil;
    if (![client setBroadcast:flag error:&error])
    {
        NSString *msg = error.localizedFailureReason ?: error.localizedDescription;
        callback(@[msg ?: @"unknown error when setBroadcast"]);
        return;
    }
    callback(@[[NSNull null]]);
}

RCT_EXPORT_METHOD(addMembership:(nonnull NSNumber*)cId
                  multicastAddress:(NSString *)address) {
     UdpSocketClient *client = _clients[cId];

    if (!client) return;

    NSError *error = nil;
    [client joinMulticastGroup:address error:&error];
}

RCT_EXPORT_METHOD(dropMembership:(nonnull NSNumber*)cId
                  multicastAddress:(NSString *)address) {
    UdpSocketClient *client = _clients[cId];

    if (!client) return;

    NSError *error = nil;
    [client leaveMulticastGroup:address error:&error];
}

- (void) onData:(UdpSocketClient*) client data:(NSData *)data host:(NSString *)host port:(uint16_t)port
{
    long ts = (long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSNumber *clientID = [[_clients allKeysForObject:client] objectAtIndex:0];

    const uint8_t *bytes = (uint8_t *)data.bytes;

    NSNumber *frameNo = [NSNumber numberWithInt:bytes[5] + bytes[6] * 256 + bytes[7] * 65536];
    [self addFrameData:frameNo data:data];

    NSData * firstByteData = [data subdataWithRange:NSMakeRange(0, 1)];
    NSString *base64String = [firstByteData base64EncodedStringWithOptions:0];

    [self.bridge.eventDispatcher sendDeviceEventWithName:[NSString stringWithFormat:@"udp-%@-data", clientID]
                                                    body:@{
                                                           @"data": base64String,
                                                           @"address": host,
                                                           @"frameNo": frameNo,
                                                           @"port": [NSNumber numberWithInt:port],
                                                           @"ts": [[NSNumber numberWithLong: ts] stringValue]
                                                           }
     ];
}

-(UdpSocketClient*)findClient:(nonnull NSNumber*)cId callback:(RCTResponseSenderBlock)callback
{
    UdpSocketClient *client = _clients[cId];
    if (!client) {
        if (!callback) {
            RCTLogError(@"%@.missing callback parameter.", [self class]);
        }
        else {
            callback(@[[NSString stringWithFormat:@"no client found with id %@", cId]]);
        }

        return nil;
    }

    return client;
}

-(void) closeClient:(nonnull NSNumber*)cId
           callback:(RCTResponseSenderBlock)callback
{
    UdpSocketClient* client = [self findClient:cId callback:callback];
    if (!client) return;

    client.clientDelegate = nil;
    [client close];
    [_clients removeObjectForKey:cId];

    [_framesData removeAllObjects];
    [_framesNumbers removeAllObjects];

    if (callback) callback(@[]);
}

@end
