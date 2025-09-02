#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(CellCounterModule, NSObject)

RCT_EXTERN_METHOD(detectGridAndCorners:(NSString *)inputUri
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(perspectiveCorrect:(NSString *)inputUri
                  corners:(NSArray *)corners
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(runCoreMLSegmentation:(NSString *)correctedImageUri
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
