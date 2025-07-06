//
//  ScreenBroadcastPicker.m
//  bigbluebuttontablet
//
//  Created by Tiago Daniel Jacobs on 06/07/25.
//

#import "React/RCTBridgeModule.h"

@interface
RCT_EXTERN_MODULE(ScreenBroadcastPicker, NSObject)

/**
 * Promise-based methods
 */
RCT_EXTERN_METHOD(start:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(stop:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

@end
