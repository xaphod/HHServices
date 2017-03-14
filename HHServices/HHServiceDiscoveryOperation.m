//
//  HHServiceDiscoveryOperation.m
//  Part of Hejsan-Hoppsan-Services : http://www.github.com/tolo/HHServices
//
//  Copyright (c) Tobias Löfstrand, Leafnode AB.
//  License: MIT - https://github.com/tolo/HHServices/blob/master/LICENSE
//

#import "HHServiceDiscoveryOperation.h"

#import "HHServiceDiscoveryOperation+Private.h"
#import <dns_sd.h>


@implementation HHServiceDiscoveryOperationCallbackContext

- (id) initWithServiceDiscoveryOperation:(HHServiceDiscoveryOperation*)operation {
    if (self = [super init]) {
        _operation = operation;
    }
    return self;
}

@end



@implementation HHServiceDiscoveryOperation

- (void) HHLogDebug:(NSString*)format, ... {
#ifdef DEBUG
    va_list vl;
    va_start(vl, format);
    NSString* logMessage = [[NSString alloc] initWithFormat:format arguments:vl];
    NSLog(@"[DEBUG] %@ - %@", self, logMessage);
    va_end(vl);
#endif
}


#pragma mark - Creation and destruction


- (id) init {
    self = [super init];
    if (self) {
        _sdDispatchQueue = dispatch_queue_create("se.leafnode.HHServices.sdDispatchQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void) dealloc {
    if( self.currentCallbackContext ) {
        self.currentCallbackContext.operation = nil;
        
        // Setup dispatch queue finalizer to make sure currentCallbackContext is destroyed only after last operation finished executing.
        void* context = (void*)CFBridgingRetain(self.currentCallbackContext);
        dispatch_set_context(self.sdDispatchQueue, context);
        dispatch_set_finalizer_f(self.sdDispatchQueue, sdDispatchQueueFinalizer);
    }
    
    [self killMyRef];
}

void sdDispatchQueueFinalizer(void* contextWrapper) {
    CFBridgingRelease(contextWrapper);
}


#pragma mark - "Protected" methods

- (void) dnsServiceError:(DNSServiceErrorType)error {
    [self HHLogDebug:@"Error: %d", error];
    self.lastError = error;
}


#pragma mark - HHServiceDiscoveryOperation

- (BOOL) setServiceRef:(DNSServiceRef)serviceRef {
    if( _serviceRef ) DNSServiceRefDeallocate(_serviceRef);
    _serviceRef = serviceRef;
    DNSServiceErrorType err = DNSServiceSetDispatchQueue(_serviceRef, self.sdDispatchQueue);
    if( err != kDNSServiceErr_NoError ) {
        [self dnsServiceError:err];
        return NO;
    } else {
        return YES;
    }
}

- (void) resetServiceRef {
    self.currentCallbackContext.operation = nil;
    
    [self killMyRef];
}

- (void)killMyRef {
    if ( _serviceRef != NULL ) {
        DNSServiceRef refToKill = _serviceRef;
        _serviceRef = NULL;
        dispatch_async([self effectiveMainDispatchQueue], ^{
            DNSServiceRefDeallocate(refToKill);
        });
    }
}

- (BOOL) hasFailed {
    return self.lastError != kDNSServiceErr_NoError;
}

- (HHServiceDiscoveryOperationCallbackContext*) setCurrentCallbackContextWithSelf {
    self.currentCallbackContext = [[HHServiceDiscoveryOperationCallbackContext alloc] initWithServiceDiscoveryOperation:self];
    return self.currentCallbackContext;
}

- (dispatch_queue_t) effectiveMainDispatchQueue {
    return _mainDispatchQueue ?: dispatch_get_main_queue();
}

@end



#pragma mark - Utility categories

@implementation NSDictionary (HHServices)

- (NSData*) dataFromTXTRecordDictionary {
    return [NSNetService dataFromTXTRecordDictionary:self];
}

@end


@implementation NSData (HHServices)

- (NSDictionary*) dictionaryFromTXTRecordData {
    return [NSNetService dictionaryFromTXTRecordData:self];
}

@end
